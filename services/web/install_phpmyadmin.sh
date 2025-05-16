#!/bin/bash
# Script d'installation et configuration de phpMyAdmin
# Auteur: [Votre Nom]
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/phpmyadmin_setup.log"
PHPMYADMIN_DIR="/var/www/phpmyadmin"
PHPMYADMIN_DOWNLOAD="https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz"
MYSQL_SOCKET_PATH="/var/mysql/mysql.sock"  # Doit correspondre à la configuration MariaDB

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

log "Démarrage de l'installation et configuration de phpMyAdmin"

# Vérifier les prérequis
if ! systemctl is-active --quiet httpd; then
    log "Apache n'est pas en cours d'exécution. Veuillez l'installer et le démarrer d'abord."
    echo "Erreur : Apache n'est pas en cours d'exécution. Veuillez l'installer et le démarrer d'abord."
    exit 2
fi

if ! systemctl is-active --quiet mariadb; then
    log "MariaDB n'est pas en cours d'exécution. Veuillez l'installer et le démarrer d'abord."
    echo "Erreur : MariaDB n'est pas en cours d'exécution. Veuillez l'installer et le démarrer d'abord."
    exit 3
fi

# Téléchargement de phpMyAdmin
log "Téléchargement de phpMyAdmin"
cd /tmp
wget -O phpmyadmin.tar.gz $PHPMYADMIN_DOWNLOAD

# Création du répertoire de destination
log "Création du répertoire de destination : $PHPMYADMIN_DIR"
if [ -d "$PHPMYADMIN_DIR" ]; then
    mv "$PHPMYADMIN_DIR" "$PHPMYADMIN_DIR.backup.$(date +%Y%m%d%H%M%S)"
fi
mkdir -p $PHPMYADMIN_DIR

# Extraction de l'archive
log "Extraction de l'archive"
tar -xzf phpmyadmin.tar.gz -C $PHPMYADMIN_DIR --strip-components=1
rm -f phpmyadmin.tar.gz

# Création du fichier de configuration
log "Création du fichier de configuration phpMyAdmin"
cp $PHPMYADMIN_DIR/config.sample.inc.php $PHPMYADMIN_DIR/config.inc.php

# Générer un sel aléatoire (blowfish_secret)
BLOWFISH_SECRET=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9')

# Mise à jour du fichier de configuration
log "Mise à jour du fichier de configuration"
sed -i "s|\\\$cfg\['blowfish_secret'\] = ''|\\\$cfg\['blowfish_secret'\] = '$BLOWFISH_SECRET'|" $PHPMYADMIN_DIR/config.inc.php

# Configurer le socket MySQL personnalisé
if grep -q "\$cfg\['Servers'\]\[\$i\]\['socket'\]" $PHPMYADMIN_DIR/config.inc.php; then
  sed -i "s|\(\$cfg\['Servers'\]\[\$i\]\['socket'\]\s*=\s*\).*|\1'$MYSQL_SOCKET_PATH';|" $PHPMYADMIN_DIR/config.inc.php
else
  sed -i "/\$cfg\['Servers'\]\[\$i\]\['host'\]/a \$cfg['Servers'][\$i]['socket'] = '$MYSQL_SOCKET_PATH';" $PHPMYADMIN_DIR/config.inc.php
fi

# Créer le fichier de configuration pour Apache
log "Création du fichier de configuration Apache pour phpMyAdmin"
cat > /etc/httpd/conf.d/phpmyadmin.conf <<EOF
Alias /phpmyadmin $PHPMYADMIN_DIR

<Directory $PHPMYADMIN_DIR>
    Options -Indexes
    AllowOverride All
    Require all granted
    
    <IfModule mod_php.c>
        php_admin_value upload_max_filesize 64M
        php_admin_value post_max_size 64M
        php_admin_value max_execution_time 300
        php_admin_value memory_limit 128M
    </IfModule>
</Directory>

# Protection supplémentaire (accès par mot de passe)
<Directory $PHPMYADMIN_DIR/setup>
    <IfModule mod_authz_core.c>
        <IfModule mod_authn_file.c>
            AuthType Basic
            AuthName "phpMyAdmin Setup"
            AuthUserFile $PHPMYADMIN_DIR/setup/.htpasswd
            Require valid-user
        </IfModule>
    </IfModule>
</Directory>
EOF

# Création du répertoire temporaire pour phpMyAdmin
log "Création du répertoire temporaire pour phpMyAdmin"
mkdir -p $PHPMYADMIN_DIR/tmp
chown apache:apache $PHPMYADMIN_DIR/tmp
chmod 700 $PHPMYADMIN_DIR/tmp

# Ajustement des permissions
log "Ajustement des permissions"
chown -R apache:apache $PHPMYADMIN_DIR
find $PHPMYADMIN_DIR -type d -exec chmod 755 {} \;
find $PHPMYADMIN_DIR -type f -exec chmod 644 {} \;

# Configuration du contexte SELinux si nécessaire
if command -v semanage &>/dev/null; then
    log "Configuration du contexte SELinux pour phpMyAdmin"
    semanage fcontext -a -t httpd_sys_rw_content_t "$PHPMYADMIN_DIR/tmp(/.*)?"
    restorecon -Rv $PHPMYADMIN_DIR
    setsebool -P httpd_can_network_connect_db 1
fi

# Redémarrage d'Apache
log "Redémarrage d'Apache"
systemctl restart httpd

log "Installation et configuration de phpMyAdmin terminées avec succès"
echo "
=========================================================
Installation de phpMyAdmin terminée
URL d'accès : http://$(hostname -I | awk '{print $1}')/phpmyadmin/
Socket MySQL configuré : $MYSQL_SOCKET_PATH
=========================================================
" 