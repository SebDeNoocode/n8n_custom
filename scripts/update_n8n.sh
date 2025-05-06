#!/bin/bash

# Charger les variables d'environnement
if [ -f "../.env" ]; then
    source ../.env
else
    echo "Fichier .env non trouvé. Utilisation des valeurs par défaut."
    # Valeurs par défaut
    DATA_DIR="/opt/data"
    ADMIN_DIR="/opt/admin"
    BACKUP_DIR="/opt/backup"
    CONFIG_DIR="/opt/config"
fi

# Configuration
COMPOSE_FILE="${CONFIG_DIR}/n8n/docker/docker-compose.yml"
LOG_FILE="${ADMIN_DIR}/logs/n8n_update.log"
CONTAINER_NAME="n8n"
HEALTH_CHECK_URL="http://localhost:${N8N_PORT:-5678}/healthz"
MAX_RETRIES=10
RETRY_INTERVAL=15

# Fonction de log
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Fonction pour extraire la version actuelle du docker-compose.yml
get_current_version() {
    grep "image: n8nio/n8n:" "$COMPOSE_FILE" | cut -d":" -f3
}

# Fonction pour obtenir la dernière version disponible
get_latest_version() {
    curl -s https://api.github.com/repos/n8n-io/n8n/releases/latest | grep "tag_name" | cut -d'"' -f4 | sed 's/n8n@//'
}

# Fonction pour mettre à jour le fichier docker-compose.yml
update_compose_file() {
    local new_version=$1
    sed -i "s/n8nio\/n8n:[0-9.]\+/n8nio\/n8n:$new_version/" "$COMPOSE_FILE"
}

# Fonction pour effectuer les sauvegardes avant la mise à jour
perform_backups() {
    log_message "Exécution des sauvegardes avant la mise à jour..."
    
    # Sauvegarde de la base de données
    log_message "Sauvegarde de la base de données..."
    if ${ADMIN_DIR}/scripts/backup_n8n_db.sh; then
        log_message "Sauvegarde de la base de données réussie"
    else
        log_message "ERREUR: Échec de la sauvegarde de la base de données. Annulation de la mise à jour."
        return 1
    fi
    
    # Sauvegarde des données
    log_message "Sauvegarde des données..."
    if ${ADMIN_DIR}/scripts/backup_n8n_data.sh; then
        log_message "Sauvegarde des données réussie"
    else
        log_message "ERREUR: Échec de la sauvegarde des données. Annulation de la mise à jour."
        return 1
    fi
    
    # Sauvegarde du fichier docker-compose.yml
    log_message "Sauvegarde du fichier docker-compose.yml..."
    cp "$COMPOSE_FILE" "${COMPOSE_FILE}.backup.$(date +%Y-%m-%d-%H-%M-%S)"
    
    return 0
}

# Fonction pour vérifier la santé de l'application après redémarrage
check_application_health() {
    log_message "Vérification de la santé de l'application..."
    
    for i in $(seq 1 $MAX_RETRIES); do
        log_message "Tentative $i/$MAX_RETRIES..."
        
        # Vérifier si le conteneur est en cours d'exécution
        if ! docker ps | grep -q "$CONTAINER_NAME"; then
            log_message "Le conteneur $CONTAINER_NAME n'est pas en cours d'exécution"
            return 1
        fi
        
        # Vérifier l'endpoint de santé
        if curl -s -f -o /dev/null "$HEALTH_CHECK_URL"; then
            log_message "L'application répond correctement"
            return 0
        fi
        
        log_message "L'application ne répond pas encore, nouvelle tentative dans $RETRY_INTERVAL secondes..."
        sleep $RETRY_INTERVAL
    done
    
    log_message "ERREUR: L'application ne répond pas après $MAX_RETRIES tentatives"
    return 1
}

# Fonction pour restaurer la version précédente en cas d'échec
rollback() {
    log_message "ERREUR: La mise à jour a échoué, restauration de la version précédente..."
    
    # Restaurer le fichier docker-compose.yml
    local backup_file="${COMPOSE_FILE}.backup.$(date +%Y-%m-%d-%H-%M-%S)"
    if [ -f "$backup_file" ]; then
        log_message "Restauration du fichier docker-compose.yml..."
        cp "$backup_file" "$COMPOSE_FILE"
    fi
    
    # Redémarrer les conteneurs avec l'ancienne version
    log_message "Redémarrage des conteneurs avec l'ancienne version..."
    sudo docker compose -f "$COMPOSE_FILE" down
    sudo docker compose -f "$COMPOSE_FILE" pull
    sudo docker compose -f "$COMPOSE_FILE" up -d
    
    # Vérifier la santé après restauration
    if check_application_health; then
        log_message "Restauration réussie"
    else
        log_message "ERREUR CRITIQUE: La restauration a également échoué. Intervention manuelle requise !"
    fi
}

# Fonction pour redémarrer les conteneurs
restart_containers() {
    log_message "Arrêt des conteneurs..."
    sudo docker compose -f "$COMPOSE_FILE" down
    
    log_message "Téléchargement de la nouvelle image..."
    sudo docker compose -f "$COMPOSE_FILE" pull
    
    log_message "Démarrage des conteneurs..."
    sudo docker compose -f "$COMPOSE_FILE" up -d
}

# Fonction principale
main() {
    log_message "=== Début de la vérification des mises à jour de n8n ==="
    
    # Obtenir les versions
    current_version=$(get_current_version)
    latest_version=$(get_latest_version)
    
    log_message "Version actuelle : $current_version"
    log_message "Dernière version : $latest_version"
    
    # Comparer les versions
    if [ "$current_version" != "$latest_version" ]; then
        log_message "Nouvelle version disponible ! Mise à jour de $current_version vers $latest_version"
        
        # Effectuer les sauvegardes
        if ! perform_backups; then
            log_message "Mise à jour annulée en raison d'échecs de sauvegarde"
            return 1
        fi
        
        # Mettre à jour le fichier docker-compose.yml
        log_message "Mise à jour du fichier docker-compose.yml..."
        update_compose_file "$latest_version"
        
        # Redémarrer les conteneurs
        log_message "Redémarrage des conteneurs..."
        restart_containers
        
        # Vérifier la santé de l'application
        if check_application_health; then
            log_message "Mise à jour terminée avec succès ! n8n est maintenant en version $latest_version"
        else
            log_message "La mise à jour a échoué, l'application ne répond pas correctement"
            rollback
            return 1
        fi
    else
        log_message "n8n est déjà à jour (version $current_version)"
    fi
    
    log_message "=== Fin de la vérification des mises à jour de n8n ==="
    return 0
}

# Exécution du script
main
