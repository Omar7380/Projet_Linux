#!/bin/bash
# Script de sauvegarde quotidienne du système
# Auteur: [Votre Nom]
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/backup.log"
DATE=$(date +"%d-%m-%Y_%H-%M-%S")
TMP_DIR="/backup/tmp_$DATE"
ARCHIVE_DIR="/backup/archives"
ARCHIVE_NAME="backup_${DATE}.tar.gz"
ARCHIVE_PATH="${ARCHIVE_DIR}/${ARCHIVE_NAME}"
RETENTION_DAYS=7  # Nombre de jours de conservation des archives

# Vérifier mot de passe root MariaDB
if [ -z "$1" ]; then
    echo "Utilisation: $0 <mot_de_passe_root_mariadb>"
    exit 1
fi
DB_ROOT_PASS="$1"

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

log "Démarrage de la sauvegarde quotidienne"

# Création des répertoires
log "Création des répertoires temporaires"
mkdir -p "$TMP_DIR/www" "$TMP_DIR/conf" "$TMP_DIR/db" "$TMP_DIR/users"
mkdir -p "$ARCHIVE_DIR"

# Sauvegarde des sites web
log "Sauvegarde des sites web"
rsync -a --delete /var/www/ "$TMP_DIR/www"

# Sauvegarde des fichiers de configuration
log "Sauvegarde des fichiers de configuration"
mkdir -p "$TMP_DIR/conf/samba" "$TMP_DIR/conf/apache" "$TMP_DIR/conf/dns" "$TMP_DIR/conf/vsftpd" "$TMP_DIR/conf/fail2ban"

# Samba
cp /etc/samba/smb.conf "$TMP_DIR/conf/samba/"

# Apache
cp -r /etc/httpd/conf.d/ "$TMP_DIR/conf/apache/"

# DNS
cp /etc/named.conf "$TMP_DIR/conf/dns/"
cp /var/named/*.zone "$TMP_DIR/conf/dns/" 2>/dev/null
cp /var/named/*.rev "$TMP_DIR/conf/dns/" 2>/dev/null

# VSFTPD
cp /etc/vsftpd/vsftpd.conf "$TMP_DIR/conf/vsftpd/"

# Fail2ban
cp -r /etc/fail2ban/jail.d/ "$TMP_DIR/conf/fail2ban/" 2>/dev/null
cp /etc/fail2ban/jail.local "$TMP_DIR/conf/fail2ban/" 2>/dev/null

# Sauvegarde des bases de données SQL valides
log "Sauvegarde des bases de données SQL"
DB_LIST=$(mysql -u root -p"$DB_ROOT_PASS" -e "SHOW DATABASES;" 2>/dev/null | grep -Ev "Database|information_schema|performance_schema|mysql|sys")

for DB in $DB_LIST; do
    if [ -d "/var/www/$DB" ] || true; then
        log "  - dump de $DB"
        mysqldump -u root -p"$DB_ROOT_PASS" "$DB" > "$TMP_DIR/db/$DB.sql" 2>/dev/null
    fi
done

# Sauvegarde des comptes utilisateurs dans /users
log "Sauvegarde des comptes utilisateurs"
rsync -a --delete /users/ "$TMP_DIR/users"

# Création de l'archive
log "Création de l'archive : $ARCHIVE_PATH"
tar -czf "$ARCHIVE_PATH" -C "$TMP_DIR" .

# Nettoyage temporaire
log "Nettoyage des fichiers temporaires"
rm -rf "$TMP_DIR"

# Suppression des archives anciennes
log "Suppression des archives de plus de $RETENTION_DAYS jours"
find "$ARCHIVE_DIR" -type f -name "backup_*.tar.gz" -mtime +$RETENTION_DAYS -exec rm -f {} \;

# Liste des archives disponibles
log "Archives disponibles :"
ls -lh $ARCHIVE_DIR | grep "backup_" | awk '{print $9 " (" $5 ")"}'

log "Sauvegarde quotidienne terminée avec succès : $ARCHIVE_PATH"
echo "
=========================================================
Sauvegarde quotidienne terminée
Archive créée : $ARCHIVE_PATH
Rétention : $RETENTION_DAYS jours
=========================================================
" 