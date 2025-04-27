#!/bin/bash

# Script d'installation pour n8n avec mise à jour et backup automatiques
# Ce script configure l'environnement complet pour n8n

# Couleurs pour les messages
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Vérifier si l'utilisateur est root ou utilise sudo
if [ "$(id -u)" -ne 0 ]; then
    error "Ce script doit être exécuté en tant que root ou avec sudo"
fi

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
    error "Docker n'est pas installé. Veuillez installer Docker avant de continuer."
fi

# Vérifier si Docker Compose est installé
if ! command -v docker compose &> /dev/null; then
    error "Docker Compose n'est pas installé. Veuillez installer Docker Compose avant de continuer."
fi

# Créer les répertoires nécessaires
log "Création des répertoires pour les données persistantes..."
mkdir -p /sata/dk/n8n/{db,data,files}
mkdir -p /sata/admin/{scripts,cron,logs}
mkdir -p /sata/backup/n8n

# Configurer les permissions pour PostgreSQL
log "Configuration des permissions pour PostgreSQL..."
chown -R 999:999 /sata/dk/n8n/db

# Copier les scripts
log "Copie des scripts de maintenance..."
cp scripts/update_n8n.sh /sata/admin/scripts/
cp scripts/backup_n8n_db.sh /sata/admin/scripts/
cp scripts/backup_n8n_data.sh /sata/admin/scripts/
chmod +x /sata/admin/scripts/*.sh

# Copier les fichiers cron
log "Copie des fichiers cron..."
cp cron/n8n_update.cron /sata/admin/cron/
cp cron/n8n_backup_db.cron /sata/admin/cron/
cp cron/n8n_backup_data.cron /sata/admin/cron/

# Ajouter les tâches au crontab système
log "Configuration des tâches cron..."
(crontab -l 2>/dev/null; cat cron/*) | crontab -

# Démarrer les conteneurs
log "Démarrage des conteneurs Docker..."
cd docker
docker compose up -d

if [ $? -eq 0 ]; then
    log "Installation terminée avec succès !"
    log "n8n est accessible à l'adresse : http://localhost:5678"
    log "Utilisateur par défaut : user_n8n"
    log "Mot de passe par défaut : Voir dans docker-compose.yml (N8N_BASIC_AUTH_PASSWORD)"
    log "Les backups seront stockés dans /sata/backup/n8n/"
    log "Les logs de maintenance sont dans /sata/admin/logs/"
else
    error "Échec du démarrage des conteneurs Docker. Veuillez vérifier les logs."
fi
