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
    POSTGRES_DB="n8n"
    POSTGRES_USER="n8nuser"
fi

# Configuration
BACKUP_DIR="${BACKUP_DIR}/n8n"
DOCKER_COMPOSE_DIR="${CONFIG_DIR}/n8n"
CONTAINER_NAME="n8n-DB"
DB_NAME="${POSTGRES_DB}"
DB_USER="${POSTGRES_USER}"
RETENTION_DAYS=30

# Création du nom de fichier avec la date (ajout des secondes)
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
BACKUP_FILE="${BACKUP_DIR}/${TIMESTAMP}_n8n_db_postgres"

# Fonction de log
log_message() {
    mkdir -p "${ADMIN_DIR}/logs"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${ADMIN_DIR}/logs/n8n_backup_db.log"
    echo "$1"
}

# Vérification du dossier de backup
if [ ! -d "$BACKUP_DIR" ]; then
    log_message "Création du dossier de backup $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
fi

# Backup de la base de données
log_message "Démarrage du backup de la base de données n8n..."
docker exec $CONTAINER_NAME pg_dump -U $DB_USER $DB_NAME > "${BACKUP_FILE}.sql"

if [ $? -eq 0 ]; then
    # Compression du fichier SQL
    log_message "Compression du fichier de backup..."
    zip "${BACKUP_FILE}.zip" "${BACKUP_FILE}.sql"
    
    if [ $? -eq 0 ]; then
        # Suppression du fichier SQL non compressé
        rm "${BACKUP_FILE}.sql"
        
        # Nettoyage des anciens backups
        log_message "Nettoyage des backups de plus de $RETENTION_DAYS jours..."
        find "$BACKUP_DIR" -name "*_n8n_db_postgres.zip" -mtime +$RETENTION_DAYS -exec rm {} \;
        
        log_message "Backup terminé avec succès : ${BACKUP_FILE}.zip"
    else
        log_message "ERREUR: Échec de la compression du backup"
        rm -f "${BACKUP_FILE}.sql"
        exit 1
    fi
else
    log_message "ERREUR: Échec du backup de la base de données"
    exit 1
fi
