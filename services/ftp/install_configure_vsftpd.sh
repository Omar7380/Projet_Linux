#!/bin/bash
# Script d'installation et configuration du serveur FTP (VSFTPD)
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/vsftpd_setup.log"

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

log "Démarrage de l'installation et configuration du serveur FTP (VSFTPD)"

# Installation des paquets
log "Installation des paquets VSFTPD et OpenSSL"
dnf install -y vsftpd openssl

# Sauvegarde de la configuration existante
log "Sauvegarde de la configuration existante"
if [ -f /etc/vsftpd/vsftpd.conf ]; then
    cp /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.backup.$(date +%Y%m%d%H%M%S)
fi

# Génération du certificat SSL auto-signé
log "Génération du certificat SSL auto-signé"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/vsftpd/vsftpd.key \
    -out /etc/vsftpd/vsftpd.pem \
    -subj "/C=FR/ST=Paris/L=Paris/O=MonOrganisation/OU=IT/CN=$(hostname)"

# Ajustement des permissions des certificats
chmod 600 /etc/vsftpd/vsftpd.key
chmod 644 /etc/vsftpd/vsftpd.pem

# Configuration de VSFTPD
log "Configuration de VSFTPD"
cat > /etc/vsftpd/vsftpd.conf <<EOF
# Configuration VSFTPD 
# Généré le $(date)

# Paramètres généraux
listen=YES
listen_ipv6=NO
connect_from_port_20=YES
dirmessage_enable=YES
ftpd_banner=Bienvenue sur le serveur FTP sécurisé
xferlog_enable=YES
xferlog_std_format=YES
xferlog_file=/var/log/vsftpd.log

# Authentification
anonymous_enable=NO
local_enable=YES
pam_service_name=vsftpd
userlist_enable=YES
userlist_deny=YES
userlist_file=/etc/vsftpd/user_list

# Permissions
write_enable=YES
local_umask=022
chroot_local_user=YES
allow_writeable_chroot=YES
user_sub_token=\$USER
local_root=/var/www/\$USER

# Configuration SSL/TLS
ssl_enable=YES
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
rsa_cert_file=/etc/vsftpd/vsftpd.pem
rsa_private_key_file=/etc/vsftpd/vsftpd.key
require_ssl_reuse=NO
ssl_ciphers=HIGH

# Mode passif
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
pasv_address=$(hostname -I | awk '{print $1}')
EOF

# Création du fichier user_list
log "Création du fichier user_list"
cat > /etc/vsftpd/user_list <<EOF
# Liste des utilisateurs interdits (un par ligne)
root
bin
daemon
nobody
EOF

# Configuration du pare-feu
log "Configuration du pare-feu pour FTP"
firewall-cmd --permanent --add-service=ftp
firewall-cmd --permanent --add-port=40000-40100/tcp
firewall-cmd --reload

# Activation et démarrage du service
log "Activation et démarrage du service VSFTPD"
systemctl enable --now vsftpd

# Vérification de l'état du service
log "Vérification de l'état du service VSFTPD"
systemctl status vsftpd

log "Installation et configuration du serveur FTP (VSFTPD) terminées avec succès"
echo "
=========================================================
Configuration FTP terminée
Serveur FTP : $(hostname -I | awk '{print $1}')
Port : 21 (contrôle) / 40000-40100 (données)
SSL/TLS activé
=========================================================
" 