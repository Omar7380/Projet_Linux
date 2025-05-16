#!/bin/bash
# Script d'installation et configuration de Fail2ban
# Auteur: [Votre Nom]
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/fail2ban_setup.log"
TRUSTED_IP="10.42.0.24"  # IP de confiance à ne jamais bannir

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

log "Démarrage de l'installation et configuration de Fail2ban"

# Installation de Fail2ban
log "Installation du paquet Fail2ban"
dnf install -y fail2ban

# Création du fichier de configuration personnalisé
log "Création du fichier de configuration personnalisé"
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
# "ignoreip" peut être une liste d'adresses IP, de CIDR ou de DNS
ignoreip = 127.0.0.1/8 ::1 $TRUSTED_IP
# Temps de bannissement (en secondes)
bantime = 1h
# Durée (en secondes) pendant laquelle Fail2ban recherche les tentatives ratées
findtime = 10m
# Nombre de tentatives avant bannissement
maxretry = 3
# Backend pour obtenir les informations de fichier (syslog, systemd, etc.)
backend = systemd
# Action à effectuer (bannissement via firewalld)
banaction = firewallcmd-ipset
# Action complète (ban + mail)
action = %(action_mwl)s

# === JAILS ===

# Protection SSH
[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = systemd
maxretry = 3

# Protection Apache (authentification)
[apache-auth]
enabled = true
port = http,https
logpath = /var/log/httpd/error_log
maxretry = 3

# Protection Apache (scripts de scan)
[apache-badbots]
enabled = true
port = http,https
logpath = /var/log/httpd/access_log
bantime = 2h
maxretry = 2

# Protection VSFTPD
[vsftpd]
enabled = true
port = ftp,ftp-data,ftps,ftps-data
logpath = /var/log/vsftpd.log
maxretry = 3

# Protection MariaDB
[mysqld-auth]
enabled = true
port = 3306
logpath = /var/log/mysql/error.log
maxretry = 5
EOF

# Configuration de l'action mail (facultatif)
log "Configuration de l'action mail"
if [ -f /etc/fail2ban/action.d/sendmail-common.local ]; then
    cp /etc/fail2ban/action.d/sendmail-common.local /etc/fail2ban/action.d/sendmail-common.local.backup.$(date +%Y%m%d%H%M%S)
fi

cat > /etc/fail2ban/action.d/sendmail-common.local <<EOF
[Definition]
# Configuration d'envoi de mail
actionstart =
actionstop =
actioncheck =
actionban = printf %%b "Subject: [Fail2Ban] <name>: banned <ip> from <host>
            Date: `LC_ALL=C date +"%%a, %%d %%h %%Y %%T %%z"`
            From: <sendername> <<sender>>
            To: <dest>

            The IP <ip> has just been banned by Fail2Ban after
            <failures> attempts against <name>.
            
            Server: <host>
            Time: `date`
            Details:
            - <name> service
            - <ip> source IP
            - <failures> failures
            - <failtime> seconds time window
            " | /usr/sbin/sendmail -f <sender> <dest>
actionunban =
EOF

# Activation et démarrage du service
log "Activation et démarrage du service Fail2ban"
systemctl enable --now fail2ban

# Vérification de l'état du service
log "Vérification de l'état du service Fail2ban"
systemctl status fail2ban

# Vérification des jails actifs
log "Vérification des jails actifs"
fail2ban-client status

# Vérification du jail SSH
log "Vérification du jail SSH"
fail2ban-client status sshd

log "Installation et configuration de Fail2ban terminées avec succès"
echo "
=========================================================
Configuration de Fail2ban terminée
IP de confiance : $TRUSTED_IP (ne sera jamais bannie)
Temps de bannissement : 1 heure
Jails activés : sshd, apache-auth, apache-badbots, vsftpd, mysqld-auth

Commandes utiles :
  - fail2ban-client status
  - fail2ban-client status <jail>
  - fail2ban-client set <jail> unbanip <ip>
=========================================================
" 