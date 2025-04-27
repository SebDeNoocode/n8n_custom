# n8n Docker avec mise à jour et backup automatiques

## Description
Configuration Docker complète pour n8n avec PostgreSQL, incluant des scripts de mise à jour automatique et de backup automatique. Cette configuration est optimisée pour une utilisation avec Cloudflare en tant que reverse proxy.

## Fonctionnalités

- **Conteneurisation complète** : n8n et PostgreSQL dans des conteneurs Docker séparés
- **Mise à jour automatique** : Script cron pour mettre à jour automatiquement n8n vers la dernière version
- **Backup automatique** : 
  - Sauvegarde quotidienne de la base de données PostgreSQL
  - Sauvegarde quotidienne des données n8n (workflows, credentials, etc.)
- **Persistance des données** : Volumes Docker pour assurer la persistance des données
- **Configuration sécurisée** : Authentification de base, isolation réseau
- **Support pour les nodes communautaires** : Configuration pour utiliser des nodes communautaires, notamment MCP

## Prérequis

- Docker et Docker Compose installés
- Accès root ou sudo sur le serveur
- Au moins 2 Go de RAM disponible
- Au moins 10 Go d'espace disque disponible

## Structure du projet

```
.
├── docker/
│   └── docker-compose.yml    # Configuration Docker pour n8n et PostgreSQL
├── scripts/
│   ├── update_n8n.sh         # Script de mise à jour automatique
│   ├── backup_n8n_db.sh      # Script de backup de la base de données
│   └── backup_n8n_data.sh    # Script de backup des données n8n
├── cron/
│   ├── n8n_update.cron       # Configuration cron pour la mise à jour
│   ├── n8n_backup_db.cron    # Configuration cron pour le backup de la base de données
│   └── n8n_backup_data.cron  # Configuration cron pour le backup des données
└── README.md                 # Documentation
```

## Installation

Pour installer cette configuration n8n sur votre serveur, suivez ces étapes :

1. Clonez ce dépôt :
   ```bash
   git clone https://github.com/votre-organisation/n8n-docker.git
   cd n8n-docker
   ```

2. (Optionnel) Personnalisez le fichier `.env.example` et renommez-le en `.env` :
   ```bash
   cp .env.example .env
   nano .env
   ```
   Ce fichier `.env` permet de personnaliser les variables d'environnement utilisées par la configuration Docker. Vous pouvez configurer les valeurs par défaut pour les chemins d'installation, les informations de la base de données et les identifiants n8n.

3. Exécutez le script d'installation :
   ```bash
   sudo ./install.sh
   ```
   Le script vous guidera pour configurer les chemins d'installation, les informations de la base de données et les identifiants n8n. Si vous avez déjà configuré un fichier `.env`, ces valeurs seront utilisées comme valeurs par défaut.

4. Accédez à n8n via votre navigateur à l'adresse configurée (par défaut : `http://localhost:5678`)
   ```

5. Les tâches cron pour les mises à jour et backups automatiques sont configurées automatiquement par le script d'installation. Si vous souhaitez les configurer manuellement :
   ```bash
   # Copier les scripts dans ${ADMIN_DIR}/scripts/
   sudo mkdir -p ${ADMIN_DIR}/scripts
   sudo cp scripts/* ${ADMIN_DIR}/scripts/
   sudo chmod +x ${ADMIN_DIR}/scripts/*.sh
   
   # Configurer les tâches cron
   sudo mkdir -p ${ADMIN_DIR}/cron
   sudo cp cron/* ${ADMIN_DIR}/cron/
   
   # Remplacer les variables dans les fichiers cron
   for file in ${ADMIN_DIR}/cron/*; do
       sed -i "s|\${ADMIN_DIR}|${ADMIN_DIR}|g" $file
   done
   
   # Ajouter les tâches au crontab système
   (sudo crontab -l 2>/dev/null; cat ${ADMIN_DIR}/cron/*) | sudo crontab -
   ```

6. Les répertoires pour les backups sont créés automatiquement par le script d'installation. Si vous souhaitez les créer manuellement :
   ```bash
   sudo mkdir -p ${BACKUP_DIR}/n8n
   ```

## Configuration

### Variables d'environnement

Toutes les variables d'environnement sont maintenant centralisées dans le fichier `.env` à la racine du projet. Ce fichier est généré lors de l'installation, mais vous pouvez aussi le créer manuellement en vous basant sur le fichier `.env.example`.

#### Variables de chemins

- `DATA_DIR`: Répertoire pour les données persistantes (par défaut: `/opt/data`)
- `ADMIN_DIR`: Répertoire pour les scripts et crons (par défaut: `/opt/admin`)
- `BACKUP_DIR`: Répertoire pour les backups (par défaut: `/opt/backup`)
- `CONFIG_DIR`: Répertoire pour les configurations (par défaut: `/opt/config`)

#### Variables PostgreSQL

- `POSTGRES_DB`: Nom de la base de données (par défaut: `n8n`)
- `POSTGRES_USER`: Utilisateur PostgreSQL (par défaut: `n8nuser`)
- `POSTGRES_PASSWORD`: Mot de passe PostgreSQL (généré aléatoirement par défaut)

#### Variables n8n

- `N8N_BASIC_AUTH_ACTIVE`: Active l'authentification de base (par défaut: `true`)
- `N8N_BASIC_AUTH_USER`: Nom d'utilisateur pour l'authentification (par défaut: `admin`)
- `N8N_BASIC_AUTH_PASSWORD`: Mot de passe pour l'authentification (généré aléatoirement par défaut)
- `N8N_HOST`: Nom d'hôte de n8n (par défaut: `localhost`)
- `N8N_PORT`: Port sur lequel n8n écoute (par défaut: `5678`)
- `N8N_PROTOCOL`: Protocole utilisé (par défaut: `http`)
- `WEBHOOK_URL`: URL complète pour les webhooks (construit automatiquement à partir des variables précédentes)
- `N8N_EDITOR_BASE_URL`: URL de base pour l'éditeur (construit automatiquement à partir des variables précédentes)
- `N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE`: Permet l'utilisation des packages communautaires comme outils (par défaut: `true`)
- `TIMEZONE`: Fuseau horaire (par défaut: `Europe/Paris`)

### Personnalisation

Vous pouvez personnaliser cette configuration en modifiant les fichiers suivants :

- `docker-compose.yml` : Modifier les ports, les volumes, les variables d'environnement
- `update_n8n.sh` : Personnaliser la logique de mise à jour
- `backup_n8n_*.sh` : Personnaliser la logique de backup et la rétention
- `*.cron` : Modifier la planification des tâches

## Maintenance automatique

### Mises à jour automatiques

Le script `update_n8n.sh` vérifie la dernière version de n8n disponible sur GitHub et met à jour le conteneur si une nouvelle version est disponible. Par défaut, il s'exécute tous les dimanches à 3h du matin.

Pour exécuter une mise à jour manuelle :
```bash
sudo ${ADMIN_DIR}/scripts/update_n8n.sh
```
Remplacez `${ADMIN_DIR}` par le chemin que vous avez configuré dans le fichier `.env`.

### Backups automatiques

Deux scripts de backup sont configurés :

1. `backup_n8n_db.sh` : Sauvegarde la base de données PostgreSQL (tous les jours à 4h)
   - Rétention : 30 jours
   - Emplacement : `${BACKUP_DIR}/n8n/YYYY-MM-DD-HH-MM-SS_n8n_db_postgres.zip`

2. `backup_n8n_data.sh` : Sauvegarde les données n8n (tous les jours à 4h30)
   - Rétention : 10 jours
   - Emplacement : `${BACKUP_DIR}/n8n/YYYY-MM-DD-HH-MM-SS_n8n_data.zip`

Pour exécuter un backup manuel :
```bash
sudo ${ADMIN_DIR}/scripts/backup_n8n_db.sh
sudo ${ADMIN_DIR}/scripts/backup_n8n_data.sh
```
Remplacez `${ADMIN_DIR}` et `${BACKUP_DIR}` par les chemins que vous avez configurés dans le fichier `.env`.

## Utilisation avec MCP (Model Context Protocol)

Cette configuration inclut le support pour le node MCP, qui permet d'intégrer n8n avec des serveurs MCP pour l'IA et l'automatisation.

Pour utiliser MCP avec n8n :

1. Accéder à l'interface web n8n
2. Aller dans Settings > Community Nodes
3. Installer le package `n8n-nodes-mcp`
4. Configurer les credentials MCP dans Settings > Credentials
5. Utiliser le node MCP dans vos workflows

## Dépannage

### Problèmes courants

1. **Erreur de permission PostgreSQL** :
   ```bash
   sudo chown -R 999:999 ${DATA_DIR}/n8n/db
   ```
   Remplacez `${DATA_DIR}` par le chemin que vous avez configuré dans le fichier `.env`.

2. **Les webhooks ne fonctionnent pas avec Cloudflare** :
   Vérifiez que les variables `WEBHOOK_URL` et `N8N_EDITOR_BASE_URL` sont correctement configurées dans votre fichier `.env`.

3. **Échec de mise à jour automatique** :
   Vérifiez les logs dans `${ADMIN_DIR}/logs/n8n_update.log`
   Remplacez `${ADMIN_DIR}` par le chemin que vous avez configuré dans le fichier `.env`.

4. **Échec de backup** :
   Vérifiez les logs dans `${ADMIN_DIR}/logs/n8n_backup_*.log`

5. **Variables d'environnement non prises en compte** :
   Assurez-vous que le fichier `.env` est correctement chargé. Vous pouvez vérifier les valeurs actuelles avec :
   ```bash
   grep -v '^#' .env
   ```

## Sécurité

Cette configuration inclut plusieurs mesures de sécurité :

- Authentification de base pour l'accès à n8n
- Isolation réseau avec Docker
- Option `no-new-privileges` pour limiter les privilèges des conteneurs
- Limites de mémoire et de CPU pour éviter les abus de ressources

## Licence

Ce projet est distribué sous licence MIT. Voir le fichier LICENSE pour plus de détails.

## Contributeurs

- Votre nom/organisation

## Remerciements

- [n8n.io](https://n8n.io/) pour leur excellent outil d'automatisation
- La communauté Docker pour les meilleures pratiques de conteneurisation
