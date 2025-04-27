#!/bin/bash

# Configuration
BACKUP_DIR="/sata/backup/n8n"
DATA_DIR="/sata/dk/n8n"
RETENTION_DAYS=10

# Création du nom de fichier avec la date (ajout des secondes)
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
BACKUP_FILE="${BACKUP_DIR}/${TIMESTAMP}_n8n_data"

# Fonction de log
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /sata/admin/logs/n8n_backup_data.log
    echo "$1"
}

# Vérification du dossier de backup
if [ ! -d "$BACKUP_DIR" ]; then
    log_message "Création du dossier de backup $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
fi

# Backup des données
log_message "Démarrage du backup des données n8n..."

# Création d'une archive des données
cd /sata/dk && zip -r "${BACKUP_FILE}.zip" n8n/

if [ $? -eq 0 ]; then
    # Nettoyage des anciens backups
    log_message "Nettoyage des backups de plus de $RETENTION_DAYS jours..."
    find "$BACKUP_DIR" -name "*_n8n_data.zip" -mtime +$RETENTION_DAYS -exec rm {} \;
    
    log_message "Backup terminé avec succès : ${BACKUP_FILE}.zip"
else
    log_message "ERREUR: Échec du backup des données"
    exit 1
fi
