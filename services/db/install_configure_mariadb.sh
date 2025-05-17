#!/bin/bash
# Script d'installation et configuration de MariaDB
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/mariadb_setup.log"
MYSQL_DATA_DIR="/var/mysql"
MYSQL_SOCKET_PATH="$MYSQL_DATA_DIR/mysql.sock"

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

log "Démarrage de l'installation et configuration de MariaDB"

# Importation de la clé GPG de MariaDB
log "Importation de la clé GPG de MariaDB"
rpm --import https://rpm.mariadb.org/RPM-GPG-KEY-MariaDB

# Création du fichier de dépôt MariaDB
log "Création du fichier de dépôt MariaDB"
cat > /etc/yum.repos.d/MariaDB.repo <<EOF
[mariadb]
name = MariaDB
baseurl = https://rpm.mariadb.org/10.11/rhel9-amd64
gpgkey=https://rpm.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

# Mise à jour des métadonnées
log "Mise à jour des métadonnées"
dnf clean all
dnf makecache

# Installation de MariaDB Server
log "Installation de MariaDB Server"
dnf install -y MariaDB-server MariaDB-client

# Création du répertoire de données
log "Création du répertoire de données : $MYSQL_DATA_DIR"
mkdir -p $MYSQL_DATA_DIR
chown -R mysql:mysql $MYSQL_DATA_DIR

# Sauvegarde de la configuration existante
log "Sauvegarde de la configuration existante"
if [ -f /etc/my.cnf ]; then
    cp /etc/my.cnf /etc/my.cnf.backup.$(date +%Y%m%d%H%M%S)
fi

# Configuration de MariaDB
log "Configuration de MariaDB"
cat > /etc/my.cnf <<EOF
[mysqld]
datadir=$MYSQL_DATA_DIR
socket=$MYSQL_SOCKET_PATH
character-set-server=utf8mb4
collation-server=utf8mb4_general_ci
log-error=/var/log/mysql/error.log
slow_query_log=1
slow_query_log_file=/var/log/mysql/slow.log
long_query_time=2

# Sécurité
symbolic-links=0
local-infile=0

# Performance
max_connections=150
query_cache_size=16M
query_cache_limit=1M
thread_cache_size=8
innodb_buffer_pool_size=128M
innodb_log_file_size=32M

[client]
socket=$MYSQL_SOCKET_PATH
default-character-set=utf8mb4

[mysql]
default-character-set=utf8mb4
EOF

# Création du répertoire pour les logs
log "Création du répertoire pour les logs"
mkdir -p /var/log/mysql
chown -R mysql:mysql /var/log/mysql

# Activation et démarrage du service
log "Activation et démarrage du service MariaDB"
systemctl enable --now mariadb

# Vérification de l'état du service
log "Vérification de l'état du service MariaDB"
systemctl status mariadb

# Création d'un script de sécurisation
log "Création d'un script de sécurisation pour MariaDB"
cat > /root/secure_mariadb.sh <<EOF
#!/bin/bash
# Script de sécurisation de MariaDB
# Modifiez le mot de passe root avant d'exécuter ce script

ROOT_PASS="\$1"

if [ -z "\$ROOT_PASS" ]; then
    echo "Usage: \$0 <nouveau_mot_de_passe_root>"
    exit 1
fi

mysql -u root <<MYSQL_SCRIPT
ALTER USER 'root'@'localhost' IDENTIFIED BY '\$ROOT_PASS';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "MariaDB sécurisé avec succès !"
EOF

chmod +x /root/secure_mariadb.sh

log "Installation et configuration de MariaDB terminées avec succès"
echo "
=========================================================
Configuration MariaDB terminée
Répertoire de données : $MYSQL_DATA_DIR
Socket : $MYSQL_SOCKET_PATH

IMPORTANT : Pour sécuriser l'installation :
  sudo /root/secure_mariadb.sh <votre_mot_de_passe_root>
=========================================================
" 