#!/bin/bash
# Script de restauration de sauvegarde
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/backup_restore.log"
ARCHIVE_DIR="/backup/archives"
RESTORE_ROOT="/restore_tmp"

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

# Demander le mot de passe SQL root
read -s -p "Mot de passe root MariaDB : " ROOT_PASS
echo

# Vérification du mot de passe
if ! mysql -u root -p"$ROOT_PASS" -e "SELECT 1" &>/dev/null; then
    log "Mot de passe MariaDB incorrect"
    echo "Erreur : Mot de passe MariaDB incorrect" >&2
    exit 2
fi

log "Démarrage de la restauration d'une sauvegarde"

# Lister les archives disponibles
log "Analyse des sauvegardes disponibles dans $ARCHIVE_DIR"
ARCHIVES=($(ls -1t "$ARCHIVE_DIR"/backup_*.tar.gz 2>/dev/null))

if [ ${#ARCHIVES[@]} -eq 0 ]; then
    log "Aucune archive trouvée dans $ARCHIVE_DIR"
    echo "Erreur : Aucune archive trouvée dans $ARCHIVE_DIR" >&2
    exit 3
fi

echo "[+] Sauvegardes disponibles dans $ARCHIVE_DIR :"
for i in "${!ARCHIVES[@]}"; do
    fname=$(basename "${ARCHIVES[$i]}")
    fsize=$(du -h "${ARCHIVES[$i]}" | awk '{print $1}')
    fdate=$(stat -c "%y" "${ARCHIVES[$i]}" | cut -d. -f1)
    echo "$((i + 1)). $fname ($fsize) - $fdate"
done

# Choix utilisateur
read -p "Entrez le numéro de la sauvegarde à restaurer : " CHOICE
INDEX=$((CHOICE - 1))

if [ -z "${ARCHIVES[$INDEX]}" ]; then
    log "Numéro invalide : $CHOICE"
    echo "Erreur : Numéro invalide" >&2
    exit 4
fi

ARCHIVE="${ARCHIVES[$INDEX]}"
log "Archive sélectionnée : $ARCHIVE"

# Confirmer la restauration
echo "ATTENTION : Cette opération va écraser les données existantes !"
read -p "Êtes-vous sûr de vouloir continuer ? (oui/NON) : " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Oo][Uu][Ii]$ ]]; then
    log "Restauration annulée par l'utilisateur"
    echo "Restauration annulée."
    exit 5
fi

# Extraction dans dossier temporaire
TMP_DIR="${RESTORE_ROOT}/extract_$(date +%s)"
log "Extraction dans le dossier temporaire : $TMP_DIR"
mkdir -p "$TMP_DIR"
tar -xzf "$ARCHIVE" -C "$TMP_DIR"

# Restauration des fichiers web
log "Restauration des fichiers web"
rsync -a "$TMP_DIR/www/" /var/www/

# Restauration des comptes utilisateurs
log "Restauration des comptes dans /users"
rsync -a "$TMP_DIR/users/" /users/

# Restauration des configurations
log "Restauration des fichiers de configuration"

# Apache : uniquement les .conf (hors autres services)
find "$TMP_DIR/conf/apache" -name "*.conf" -exec cp -f {} /etc/httpd/conf.d/ \;

# Samba
if [ -f "$TMP_DIR/conf/samba/smb.conf" ]; then
    cp -f "$TMP_DIR/conf/samba/smb.conf" /etc/samba/smb.conf
fi

# BIND DNS
if [ -f "$TMP_DIR/conf/dns/named.conf" ]; then
    cp -f "$TMP_DIR/conf/dns/named.conf" /etc/named.conf
fi
cp -f "$TMP_DIR/conf/dns/"*.zone /var/named/ 2>/dev/null
cp -f "$TMP_DIR/conf/dns/"*.rev /var/named/ 2>/dev/null

# VSFTPD
if [ -f "$TMP_DIR/conf/vsftpd/vsftpd.conf" ]; then
    cp -f "$TMP_DIR/conf/vsftpd/vsftpd.conf" /etc/vsftpd/vsftpd.conf
fi

# Fail2ban
if [ -d "$TMP_DIR/conf/fail2ban/jail.d" ]; then
    cp -rf "$TMP_DIR/conf/fail2ban/jail.d/"* /etc/fail2ban/jail.d/ 2>/dev/null
fi
if [ -f "$TMP_DIR/conf/fail2ban/jail.local" ]; then
    cp -f "$TMP_DIR/conf/fail2ban/jail.local" /etc/fail2ban/jail.local
fi

# Restauration des bases de données
log "Restauration des bases de données"
for sqlfile in "$TMP_DIR/db/"*.sql; do
    if [ -f "$sqlfile" ]; then
        DBNAME=$(basename "$sqlfile" .sql)
        log "  - base : $DBNAME"
        mysql -u root -p"$ROOT_PASS" -e "DROP DATABASE IF EXISTS \`$DBNAME\`;"
        mysql -u root -p"$ROOT_PASS" -e "CREATE DATABASE \`$DBNAME\`;"
        mysql -u root -p"$ROOT_PASS" "$DBNAME" < "$sqlfile"
    fi
done

# Nettoyage temporaire
log "Nettoyage des fichiers temporaires"
rm -rf "$TMP_DIR"

# Redémarrage des services
log "Redémarrage des services"
systemctl restart named
systemctl restart httpd
systemctl restart smb nmb
systemctl restart vsftpd
systemctl restart fail2ban
systemctl restart mariadb

log "Restauration complète effectuée depuis : $(basename "$ARCHIVE")"
echo "
=========================================================
Restauration terminée avec succès !
Archive utilisée : $(basename "$ARCHIVE")
=========================================================
" 