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

1. Cloner ce dépôt :
   ```bash
   git clone https://github.com/votre-organisation/n8n-docker.git
   cd n8n-docker
   ```

2. Créer les répertoires nécessaires pour les données persistantes :
   ```bash
   mkdir -p /sata/dk/n8n/{db,data,files}
   ```

3. Configurer les permissions pour PostgreSQL :
   ```bash
   sudo chown -R 999:999 /sata/dk/n8n/db
   ```

4. Démarrer les conteneurs :
   ```bash
   cd docker
   docker compose up -d
   ```

5. Configurer les tâches cron pour les mises à jour et backups automatiques :
   ```bash
   # Copier les scripts dans /sata/admin/scripts/
   sudo mkdir -p /sata/admin/scripts
   sudo cp ../scripts/* /sata/admin/scripts/
   sudo chmod +x /sata/admin/scripts/*.sh
   
   # Configurer les tâches cron
   sudo mkdir -p /sata/admin/cron
   sudo cp ../cron/* /sata/admin/cron/
   
   # Ajouter les tâches au crontab système
   (sudo crontab -l 2>/dev/null; cat ../cron/*) | sudo crontab -
   ```

6. Créer les répertoires pour les backups :
   ```bash
   sudo mkdir -p /sata/backup/n8n
   ```

## Configuration

### Variables d'environnement

Les variables d'environnement principales sont définies dans le fichier `docker-compose.yml`. Voici les plus importantes :

- `N8N_BASIC_AUTH_ACTIVE`: Active l'authentification de base
- `N8N_BASIC_AUTH_USER`: Nom d'utilisateur pour l'authentification
- `N8N_BASIC_AUTH_PASSWORD`: Mot de passe pour l'authentification
- `N8N_HOST`: Nom d'hôte de n8n (pour les webhooks)
- `N8N_PORT`: Port sur lequel n8n écoute
- `N8N_PROTOCOL`: Protocole utilisé (http/https)
- `WEBHOOK_URL`: URL complète pour les webhooks
- `N8N_EDITOR_BASE_URL`: URL de base pour l'éditeur
- `N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE`: Permet l'utilisation des packages communautaires comme outils

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
sudo /sata/admin/scripts/update_n8n.sh
```

### Backups automatiques

Deux scripts de backup sont configurés :

1. `backup_n8n_db.sh` : Sauvegarde la base de données PostgreSQL (tous les jours à 4h)
   - Rétention : 30 jours
   - Emplacement : `/sata/backup/n8n/YYYY-MM-DD-HH-MM-SS_n8n_db_postgres.zip`

2. `backup_n8n_data.sh` : Sauvegarde les données n8n (tous les jours à 4h30)
   - Rétention : 10 jours
   - Emplacement : `/sata/backup/n8n/YYYY-MM-DD-HH-MM-SS_n8n_data.zip`

Pour exécuter un backup manuel :
```bash
sudo /sata/admin/scripts/backup_n8n_db.sh
sudo /sata/admin/scripts/backup_n8n_data.sh
```

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
   sudo chown -R 999:999 /sata/dk/n8n/db
   ```

2. **Les webhooks ne fonctionnent pas avec Cloudflare** :
   Vérifiez que les variables `WEBHOOK_URL` et `N8N_EDITOR_BASE_URL` sont correctement configurées.

3. **Échec de mise à jour automatique** :
   Vérifiez les logs dans `/sata/admin/logs/n8n_update.log`

4. **Échec de backup** :
   Vérifiez les logs dans `/sata/admin/logs/n8n_backup_*.log`

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
