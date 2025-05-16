#!/bin/bash
# Script de création d'utilisateur complet avec intégration
# - Utilisateur système (/users)
# - Samba
# - FTP
# - DNS
# - Apache
# - MariaDB
# - Quota
# Auteur: [Votre Nom]
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/user_creation.log"

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# === Vérification des droits ===
if [[ $EUID -ne 0 ]]; then
  log "Ce script doit être exécuté en tant que root"
  echo "Ce script doit être exécuté en tant que root." >&2
  exit 1
fi

# === Entrée utilisateur ===
read -p "Nom du nouvel utilisateur : " USERNAME
read -p "Nom de domaine principal (ex: test.lan) : " DOMAIN
read -p "IP à associer au sous-domaine $USERNAME.$DOMAIN : " USER_IP

# === Mot de passe UNIX ===
read -s -p "Mot de passe système pour $USERNAME : " PASSWORD
echo
read -s -p "Confirmer le mot de passe : " PASSWORD_CONFIRM
echo
if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
  log "Erreur : mots de passe non identiques"
  echo "❌ Mots de passe non identiques." >&2
  exit 1
fi

# === Mot de passe SQL ===
read -s -p "Mot de passe SQL pour $USERNAME : " DB_PASS
echo
read -s -p "Confirmer le mot de passe SQL : " DB_PASS_CONFIRM
echo
if [[ "$DB_PASS" != "$DB_PASS_CONFIRM" ]]; then
  log "Erreur : mots de passe SQL non identiques"
  echo "❌ Mots de passe SQL non identiques." >&2
  exit 1
fi

# === Mot de passe root SQL ===
read -s -p "Mot de passe root MariaDB : " ROOT_PASS
echo

log "Démarrage de la création de l'utilisateur $USERNAME"

# === Créer utilisateur Linux avec home personnalisé ===
log "Création de l'utilisateur système dans /users/$USERNAME"
useradd -m -d /users/$USERNAME "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

# Option sudo
read -p "Ajouter $USERNAME au groupe sudo (wheel) ? [y/N] : " ADD_SUDO
if [[ "$ADD_SUDO" =~ ^[Yy]$ ]]; then
  log "Ajout au groupe wheel"
  usermod -aG wheel "$USERNAME"
  echo "$USERNAME ajouté au groupe wheel."
fi

# === Dossier web ===
WEBROOT="/var/www/$USERNAME"
log "Création du dossier web $WEBROOT"
mkdir -p "$WEBROOT"
echo "<h1>Bienvenue sur le site de $USERNAME</h1>" > "$WEBROOT/index.html"
chown -R "$USERNAME:$USERNAME" "$WEBROOT"
chmod 755 "$WEBROOT"

# === Quota disque ===
log "Configuration du quota disque"
setquota -u "$USERNAME" 500000 600000 0 0 /users
setquota -u "$USERNAME" 200000 250000 0 0 /var/www

# === Samba ===
log "Configuration Samba pour $USERNAME"
echo "$PASSWORD" | smbpasswd -a "$USERNAME" >/dev/null 2>&1
if command -v semanage &>/dev/null; then
  semanage fcontext -a -t samba_share_t "$WEBROOT(/.*)?"
  restorecon -Rv "$WEBROOT"
fi
if ! grep -q "^\[$USERNAME\]" /etc/samba/smb.conf; then
cat >> /etc/samba/smb.conf <<EOF

[$USERNAME]
   path = $WEBROOT
   browsable = yes
   writable = yes
   guest ok = no
   read only = no
   valid users = $USERNAME
   force user = $USERNAME
   force group = $USERNAME
EOF
fi
systemctl restart smb nmb

# === Apache vhost ===
log "Configuration Apache vhost pour $USERNAME.$DOMAIN"
VHOST_CONF="/etc/httpd/conf.d/$USERNAME.conf"
cat > "$VHOST_CONF" <<EOF
<VirtualHost *:80>
    ServerName $USERNAME.$DOMAIN
    DocumentRoot $WEBROOT

    <Directory $WEBROOT>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog /var/log/httpd/${USERNAME}_error.log
    CustomLog /var/log/httpd/${USERNAME}_access.log combined
</VirtualHost>
EOF
systemctl restart httpd

# === Base de données MariaDB ===
log "Création de la base de données MariaDB pour $USERNAME"
mysql -u root -p"$ROOT_PASS" <<EOF
CREATE DATABASE $USERNAME;
CREATE USER '$USERNAME'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $USERNAME.* TO '$USERNAME'@'localhost';
FLUSH PRIVILEGES;
EOF

# === DNS zone ===
log "Configuration DNS pour $USERNAME.$DOMAIN"
ZONE_FILE="/var/named/$DOMAIN.zone"
REV_FILE="/var/named/$(echo $USER_IP | awk -F. '{print $3"."$2"."$1}').rev"
LAST_OCTET=$(echo "$USER_IP" | awk -F. '{print $4}')

# Incrémenter le serial
CURRENT_SERIAL=$(grep -E '[0-9]{10} ; Serial' "$ZONE_FILE" | awk '{print $1}')
NEW_SERIAL=$((CURRENT_SERIAL + 1))
sed -i "s/$CURRENT_SERIAL ; Serial/$NEW_SERIAL ; Serial/" "$ZONE_FILE"

# Enregistrement A
grep -q "^$USERNAME\s\+IN\s\+A" "$ZONE_FILE" || echo "$USERNAME IN A $USER_IP" >> "$ZONE_FILE"

# Enregistrement PTR
grep -q "^$LAST_OCTET\s\+IN\s\+PTR" "$REV_FILE" || echo "$LAST_OCTET IN PTR $USERNAME.$DOMAIN." >> "$REV_FILE"

systemctl restart named

# === Configuration FTP (si disponible) ===
if systemctl is-active --quiet vsftpd; then
    log "Configuration FTP pour $USERNAME"
    mkdir -p "$WEBROOT/ftp"
    chown "$USERNAME:$USERNAME" "$WEBROOT/ftp"
    chmod 755 "$WEBROOT/ftp"
    echo "Répertoire FTP créé : $WEBROOT/ftp"
fi

log "Création de l'utilisateur $USERNAME terminée avec succès"
echo "
=========================================================
✅ Utilisateur $USERNAME créé avec succès !

🌐 Site web      : http://$USERNAME.$DOMAIN
📁 Dossier web   : $WEBROOT
💾 Base de données : $USERNAME
🔑 Utilisateur SQL : $USERNAME / (mot de passe défini)
🔢 Quota /users   : 500MB (soft) / 600MB (hard)
🔢 Quota /var/www : 200MB (soft) / 250MB (hard)
=========================================================
" 