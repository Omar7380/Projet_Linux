#!/bin/bash
# Script d'installation et configuration d'Apache et PHP
# Auteur: [Votre Nom]
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/apache_setup.log"

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

log "Démarrage de l'installation et configuration d'Apache et PHP"

# Installation d'Apache
log "Installation d'Apache"
dnf install -y httpd

# Installation de PHP et des extensions courantes
log "Installation de PHP et des extensions courantes"
dnf install -y php php-mysqli php-mbstring php-json php-xml php-gd php-zip php-intl php-curl

# Sauvegarde de la configuration existante
log "Sauvegarde de la configuration Apache existante"
if [ -f /etc/httpd/conf/httpd.conf ]; then
    cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.backup.$(date +%Y%m%d%H%M%S)
fi

# Configuration d'Apache
log "Configuration d'Apache"
cat > /etc/httpd/conf.d/security.conf <<EOF
# Configuration de sécurité Apache
# Généré le $(date)

# Masquer la version d'Apache
ServerTokens Prod
ServerSignature Off

# Désactiver les listings de répertoires
<Directory />
    Options -Indexes
</Directory>

# Protection contre les attaques XSS
Header set X-XSS-Protection "1; mode=block"
Header set X-Content-Type-Options "nosniff"
Header set X-Frame-Options "SAMEORIGIN"

# Restriction des méthodes HTTP
<LimitExcept GET POST HEAD>
    deny from all
</LimitExcept>
EOF

# Configuration de PHP
log "Configuration de PHP"
cat > /etc/php.ini.custom <<EOF
; Configuration PHP personnalisée
; Généré le $(date)

; Sécurité
expose_php = Off
display_errors = Off
log_errors = On
error_log = /var/log/php_errors.log
allow_url_fopen = Off
allow_url_include = Off
max_execution_time = 30
max_input_time = 60
memory_limit = 128M
post_max_size = 20M
upload_max_filesize = 10M
date.timezone = Europe/Paris
EOF

# Fusionner les configurations PHP
log "Fusion des configurations PHP"
cp /etc/php.ini /etc/php.ini.backup.$(date +%Y%m%d%H%M%S)
cat /etc/php.ini.custom >> /etc/php.ini

# Création d'une page d'accueil de test
log "Création d'une page d'accueil de test"
mkdir -p /var/www/html
cat > /var/www/html/index.php <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Serveur Web Apache/PHP</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            line-height: 1.6;
        }
        h1 {
            color: #444;
            border-bottom: 1px solid #ddd;
            padding-bottom: 10px;
        }
        .info {
            background: #f8f8f8;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <h1>Serveur Web Apache/PHP</h1>
    <p>Si vous voyez cette page, cela signifie que votre serveur Apache fonctionne correctement.</p>
    
    <div class="info">
        <h2>Informations sur le serveur</h2>
        <ul>
            <li><strong>Date et heure du serveur :</strong> <?php echo date('Y-m-d H:i:s'); ?></li>
            <li><strong>Version de PHP :</strong> <?php echo phpversion(); ?></li>
            <li><strong>Système d'exploitation :</strong> <?php echo php_uname(); ?></li>
            <li><strong>Serveur Web :</strong> <?php echo \$_SERVER['SERVER_SOFTWARE']; ?></li>
        </ul>
    </div>
    
    <p>Cette page est générée dynamiquement par PHP.</p>
</body>
</html>
EOF

# Configuration du pare-feu pour HTTP/HTTPS
log "Configuration du pare-feu pour HTTP/HTTPS"
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

# Activation et démarrage du service
log "Activation et démarrage du service Apache"
systemctl enable --now httpd

# Vérification de l'état du service
log "Vérification de l'état du service Apache"
systemctl status httpd

log "Installation et configuration d'Apache et PHP terminées avec succès"
echo "
=========================================================
Configuration du serveur Web terminée
Page de test : http://$(hostname -I | awk '{print $1}')/
=========================================================
" 