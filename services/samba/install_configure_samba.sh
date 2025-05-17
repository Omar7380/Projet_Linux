#!/bin/bash
# Script d'installation et configuration de Samba
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/samba_setup.log"
SHARE_NAME="partage"
SHARE_PATH="/srv/samba/$SHARE_NAME"

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

log "Démarrage de l'installation et configuration de Samba"

# Mise à jour des paquets
log "Mise à jour des paquets"
dnf update -y

# Installation de Samba
log "Installation des paquets Samba"
dnf install -y samba samba-client samba-common

# Création du dossier de partage
log "Création du dossier de partage : $SHARE_PATH"
mkdir -p "$SHARE_PATH"
chmod -R 0775 "$SHARE_PATH"
chown -R nobody:nobody "$SHARE_PATH"

# Configuration SELinux pour Samba
if command -v semanage &>/dev/null; then
    log "Configuration du contexte SELinux pour le partage Samba"
    semanage fcontext -a -t samba_share_t "$SHARE_PATH(/.*)?"
    restorecon -Rv "$SHARE_PATH"
fi

# Sauvegarde de la configuration existante
log "Sauvegarde de la configuration Samba existante"
if [ -f /etc/samba/smb.conf ]; then
    cp /etc/samba/smb.conf /etc/samba/smb.conf.backup.$(date +%Y%m%d%H%M%S)
fi

# Configuration de Samba
log "Écriture de la configuration Samba"
cat > /etc/samba/smb.conf <<EOF
[global]
    workgroup = WORKGROUP
    server string = Serveur Samba
    map to guest = Bad User
    log file = /var/log/samba/%m.log
    max log size = 50
    security = user
    encrypt passwords = yes
    passdb backend = tdbsam
    
# Partage public
[$SHARE_NAME]
    path = $SHARE_PATH
    browsable = yes
    writable = yes
    guest ok = yes
    read only = no
    create mask = 0775
    force user = nobody
    force group = nobody
EOF

# Configuration du pare-feu pour Samba
log "Configuration du pare-feu pour Samba"
firewall-cmd --permanent --add-service=samba
firewall-cmd --reload

# Activation et démarrage des services Samba
log "Activation et démarrage des services Samba"
systemctl enable --now smb
systemctl enable --now nmb

# Vérification de l'état du service
log "Vérification de l'état du service Samba"
systemctl status smb
systemctl status nmb

log "Installation et configuration de Samba terminées avec succès" 