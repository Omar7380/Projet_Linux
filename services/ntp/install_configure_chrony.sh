#!/bin/bash
# Script d'installation et configuration du serveur NTP (Chrony)
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/chrony_setup.log"
NETWORK="10.42.0.0/16"  # Réseau local à autoriser

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

log "Démarrage de l'installation et configuration du serveur NTP (Chrony)"

# Installation des paquets
log "Installation du paquet Chrony"
dnf install -y chrony

# Sauvegarde de la configuration existante
log "Sauvegarde de la configuration existante"
if [ -f /etc/chrony.conf ]; then
    cp /etc/chrony.conf /etc/chrony.conf.backup.$(date +%Y%m%d%H%M%S)
fi

# Configuration de Chrony en tant que serveur NTP
log "Configuration de Chrony en tant que serveur NTP"
cat > /etc/chrony.conf <<EOF
# Configuration du serveur NTP (Chrony)
# Généré le $(date)

# Serveurs NTP de référence externes
# Utiliser des serveurs de pool.ntp.org ou chrony.debian.net
server 0.fr.pool.ntp.org iburst
server 1.fr.pool.ntp.org iburst
server 2.fr.pool.ntp.org iburst
server 3.fr.pool.ntp.org iburst

# Enregistrer les mesures dans le fichier de dérive
driftfile /var/lib/chrony/drift

# Permettre au système d'horloge matérielle de se synchroniser
rtcsync

# Activer le serveur NTP
bindaddress 0.0.0.0
local stratum 10

# Autoriser les clients du réseau local
allow $NETWORK

# Fichier de clés pour l'authentification
keyfile /etc/chrony.keys

# Utilisateur chrony pour le mode non privilégié
makestep 1.0 3

# Journalisation
logdir /var/log/chrony
log measurements statistics tracking
EOF

# Configuration du pare-feu
log "Configuration du pare-feu pour NTP"
firewall-cmd --permanent --add-service=ntp
firewall-cmd --reload

# Activation et démarrage du service
log "Activation et démarrage du service Chrony"
systemctl enable --now chronyd

# Vérification de l'état du service
log "Vérification de l'état du service Chrony"
systemctl status chronyd

# Vérification de la synchronisation
log "Vérification de la synchronisation NTP"
chronyc tracking
log "Sources NTP configurées :"
chronyc sources
log "Vérification des connexions NTP actives :"
ss -ulpn | grep chrony

log "Installation et configuration du serveur NTP (Chrony) terminées avec succès"
echo "
=========================================================
Configuration du serveur NTP terminée
Serveur NTP : $(hostname -I | awk '{print $1}')
Réseau autorisé : $NETWORK
Vérifiez l'état avec : chronyc tracking
Vérifiez les sources avec : chronyc sources
=========================================================
" 