#!/bin/bash
# Script de configuration client NTP (Chrony)
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/chrony_client_setup.log"

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

# Demander l'adresse IP du serveur NTP
read -p "Adresse IP du serveur NTP (exemple: 10.42.0.249) : " NTP_SERVER

# Validation de l'adresse IP
if [[ ! "$NTP_SERVER" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log "Format d'adresse IP invalide : $NTP_SERVER"
    echo "Erreur : Format d'adresse IP invalide" >&2
    exit 2
fi

log "Démarrage de la configuration du client NTP (Chrony)"

# Installation de Chrony si nécessaire
if ! rpm -q chrony &>/dev/null; then
    log "Installation du paquet Chrony"
    dnf install -y chrony
fi

# Sauvegarde de la configuration existante
log "Sauvegarde de la configuration existante"
if [ -f /etc/chrony.conf ]; then
    cp /etc/chrony.conf /etc/chrony.conf.backup.$(date +%Y%m%d%H%M%S)
fi

# Configuration du client Chrony
log "Configuration du client Chrony pour utiliser le serveur $NTP_SERVER"
cat > /etc/chrony.conf <<EOF
# Configuration du client NTP (Chrony)
# Généré le $(date)

# Serveur NTP principal (interne)
server $NTP_SERVER iburst

# Enregistrer les mesures dans le fichier de dérive
driftfile /var/lib/chrony/drift

# Permettre au système d'horloge matérielle de se synchroniser
rtcsync

# Étape de temps si nécessaire
makestep 1.0 3

# Fichier de clés pour l'authentification
keyfile /etc/chrony.keys

# Journalisation
logdir /var/log/chrony
log measurements statistics tracking
EOF

# Activation et redémarrage du service
log "Activation et redémarrage du service Chrony"
systemctl enable --now chronyd

# Vérification de l'état du service
log "Vérification de l'état du service Chrony"
systemctl status chronyd

# Attendre quelques secondes pour la synchronisation
log "Attente de la synchronisation avec le serveur NTP..."
sleep 5

# Vérification de la synchronisation
log "Vérification de la synchronisation NTP"
chronyc tracking
log "Sources NTP configurées :"
chronyc sources

log "Configuration du client NTP (Chrony) terminée avec succès"
echo "
=========================================================
Configuration du client NTP terminée
Serveur NTP configuré : $NTP_SERVER
Vérifiez l'état avec : chronyc tracking
Vérifiez les sources avec : chronyc sources
=========================================================
" 