#!/bin/bash
# Script de suppression d'utilisateur complet avec intégration
# - Utilisateur système (/users)
# - Samba
# - FTP
# - DNS
# - Apache
# - MariaDB
# - Quota
# Date: Mai 2025
# === Vérification des droits ===
if [[ $EUID -ne 0 ]]; then
  echo "Ce script doit être exécuté en tant que root." >&2
  exit 1
fi

read -p "Nom de l'utilisateur à supprimer : " USERNAME
USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]')
read -p "Nom de domaine principal (ex: test.lan) : " DOMAIN
read -p "IP associée au domaine (ex: 10.42.0.100) : " USER_IP
read -s -p "Mot de passe root MariaDB : " ROOT_PASS
echo

# === Supprimer l'utilisateur Linux ===
id "$USERNAME" &>/dev/null && userdel -r "$USERNAME"

# === Supprimer le dossier web ===
WEBROOT="/var/www/$USERNAME"
[[ -d "$WEBROOT" ]] && rm -rf "$WEBROOT"

# === Supprimer bloc Samba ===
SMB_CONF="/etc/samba/smb.conf"
grep -q "^\[$USERNAME\]" "$SMB_CONF" && sed -i "/^\[$USERNAME\]/,/^$/d" "$SMB_CONF"
systemctl restart smb nmb

# === Supprimer vhost Apache ===
VHOST="/etc/httpd/conf.d/$USERNAME.conf"
[[ -f "$VHOST" ]] && rm -f "$VHOST"
systemctl restart httpd

# === Supprimer base SQL ===
mysql -u root -p"$ROOT_PASS" <<EOF
DROP DATABASE IF EXISTS $USERNAME;
DROP USER IF EXISTS '$USERNAME'@'localhost';
FLUSH PRIVILEGES;
EOF

# === DNS suppression ===
ZONE_FILE="/var/named/$DOMAIN.zone"
REV_FILE="/var/named/$(echo $USER_IP | awk -F. '{print $3"."$2"."$1}').rev"
LAST_OCTET=$(echo "$USER_IP" | awk -F. '{print $4}')

sed -i "/^$USERNAME\s\+IN\s\+A\s\+$USER_IP$/d" "$ZONE_FILE"
sed -i "/^$LAST_OCTET\s\+IN\s\+PTR\s\+$USERNAME\.$DOMAIN\.$/d" "$REV_FILE"

SERIAL=$(grep -E '[0-9]{10} ; Serial' "$ZONE_FILE" | awk '{print $1}')
NEW_SERIAL=$((SERIAL + 1))
sed -i "s/$SERIAL ; Serial/$NEW_SERIAL ; Serial/" "$ZONE_FILE"
systemctl restart named

echo ""
echo "✅ Suppression complète de l'utilisateur $USERNAME effectuée."