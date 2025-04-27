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

# Chemin vers le docker-compose.yml
COMPOSE_FILE="${CONFIG_DIR}/n8n/docker/docker-compose.yml"

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

# Fonction pour redémarrer les conteneurs
restart_containers() {
    echo "Arrêt des conteneurs..."
    sudo docker compose -f "$COMPOSE_FILE" down
    
    echo "Téléchargement de la nouvelle image..."
    sudo docker compose -f "$COMPOSE_FILE" pull
    
    echo "Démarrage des conteneurs..."
    sudo docker compose -f "$COMPOSE_FILE" up -d
}

# Fonction principale
main() {
    echo "Vérification des mises à jour de n8n..."
    
    # Obtenir les versions
    current_version=$(get_current_version)
    latest_version=$(get_latest_version)
    
    echo "Version actuelle : $current_version"
    echo "Dernière version : $latest_version"
    
    # Comparer les versions
    if [ "$current_version" != "$latest_version" ]; then
        echo "Nouvelle version disponible !"
        echo "Mise à jour de $current_version vers $latest_version"
        
        # Créer une sauvegarde du docker-compose.yml
        cp "$COMPOSE_FILE" "${COMPOSE_FILE}.backup"
        
        # Mettre à jour le fichier
        update_compose_file "$latest_version"
        
        # Redémarrer les conteneurs
        restart_containers
        
        echo "Mise à jour terminée avec succès !"
    else
        echo "n8n est déjà à jour !"
    fi
}

# Exécution du script
main
