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

# Demander les chemins d'installation
log "Configuration des chemins d'installation..."
read -p "Chemin pour les données (par défaut: /opt/data): " DATA_DIR
DATA_DIR=${DATA_DIR:-/opt/data}

read -p "Chemin pour les scripts admin (par défaut: /opt/admin): " ADMIN_DIR
ADMIN_DIR=${ADMIN_DIR:-/opt/admin}

read -p "Chemin pour les backups (par défaut: /opt/backup): " BACKUP_DIR
BACKUP_DIR=${BACKUP_DIR:-/opt/backup}

read -p "Chemin pour les configurations (par défaut: /opt/config): " CONFIG_DIR
CONFIG_DIR=${CONFIG_DIR:-/opt/config}

# Demander les informations de base de données
log "Configuration de la base de données..."
read -p "Nom de la base de données (par défaut: n8n): " POSTGRES_DB
POSTGRES_DB=${POSTGRES_DB:-n8n}

read -p "Utilisateur de la base de données (par défaut: n8nuser): " POSTGRES_USER
POSTGRES_USER=${POSTGRES_USER:-n8nuser}

read -p "Mot de passe de la base de données (par défaut: généré aléatoirement): " POSTGRES_PASSWORD
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$(openssl rand -base64 12)}

# Demander les informations d'authentification n8n
log "Configuration de l'authentification n8n..."
read -p "Utilisateur n8n (par défaut: admin): " N8N_BASIC_AUTH_USER
N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER:-admin}

read -p "Mot de passe n8n (par défaut: généré aléatoirement): " N8N_BASIC_AUTH_PASSWORD
N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD:-$(openssl rand -base64 12)}

read -p "Nom d'hôte n8n (par défaut: localhost): " N8N_HOST
N8N_HOST=${N8N_HOST:-localhost}

read -p "Port n8n (par défaut: 5678): " N8N_PORT
N8N_PORT=${N8N_PORT:-5678}

read -p "Protocole n8n (http/https) (par défaut: http): " N8N_PROTOCOL
N8N_PROTOCOL=${N8N_PROTOCOL:-http}

# Créer le fichier .env
log "Création du fichier .env..."
cat > .env << EOL
# Chemins de base pour l'installation
DATA_DIR=${DATA_DIR}
ADMIN_DIR=${ADMIN_DIR}
BACKUP_DIR=${BACKUP_DIR}
CONFIG_DIR=${CONFIG_DIR}

# Configuration PostgreSQL
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# Configuration n8n
N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
N8N_HOST=${N8N_HOST}
N8N_PORT=${N8N_PORT}
N8N_PROTOCOL=${N8N_PROTOCOL}
WEBHOOK_URL=${N8N_PROTOCOL}://${N8N_HOST}:${N8N_PORT}
N8N_EDITOR_BASE_URL=${N8N_PROTOCOL}://${N8N_HOST}:${N8N_PORT}

# Fuseaux horaires
TIMEZONE=Europe/Paris
EOL

# Créer les répertoires nécessaires
log "Création des répertoires pour les données persistantes..."
mkdir -p ${DATA_DIR}/n8n/{db,data,files}
mkdir -p ${ADMIN_DIR}/{scripts,cron,logs}
mkdir -p ${BACKUP_DIR}/n8n
mkdir -p ${CONFIG_DIR}/n8n

# Copier le fichier docker-compose.yml vers le répertoire de configuration
cp -r docker ${CONFIG_DIR}/n8n/

# Configurer les permissions pour PostgreSQL
log "Configuration des permissions pour PostgreSQL..."
chown -R 999:999 ${DATA_DIR}/n8n/db

# Copier les scripts
log "Copie des scripts de maintenance..."
cp scripts/update_n8n.sh ${ADMIN_DIR}/scripts/
cp scripts/backup_n8n_db.sh ${ADMIN_DIR}/scripts/
cp scripts/backup_n8n_data.sh ${ADMIN_DIR}/scripts/
chmod +x ${ADMIN_DIR}/scripts/*.sh

# Copier les fichiers cron et les adapter
log "Copie et adaptation des fichiers cron..."
for file in cron/*; do
    dest_file=${ADMIN_DIR}/cron/$(basename $file)
    cp $file $dest_file
    # Remplacer les variables dans les fichiers cron
    sed -i "s|\${ADMIN_DIR}|${ADMIN_DIR}|g" $dest_file
done

# Ajouter les tâches au crontab système
log "Configuration des tâches cron..."
(crontab -l 2>/dev/null; cat ${ADMIN_DIR}/cron/*) | crontab -

# Démarrer les conteneurs
log "Démarrage des conteneurs Docker..."
cd ${CONFIG_DIR}/n8n/docker

# Exporter les variables d'environnement pour docker-compose
set -a
source ../../.env
set +a

docker compose up -d

if [ $? -eq 0 ]; then
    log "Installation terminée avec succès !"
    log "n8n est accessible à l'adresse : ${N8N_PROTOCOL}://${N8N_HOST}:${N8N_PORT}"
    log "Utilisateur : ${N8N_BASIC_AUTH_USER}"
    log "Mot de passe : ${N8N_BASIC_AUTH_PASSWORD}"
    log "Les backups seront stockés dans ${BACKUP_DIR}/n8n/"
    log "Les logs de maintenance sont dans ${ADMIN_DIR}/logs/"
    log "Configuration enregistrée dans ${CONFIG_DIR}/.env"
else
    error "Échec du démarrage des conteneurs Docker. Veuillez vérifier les logs."
fi
