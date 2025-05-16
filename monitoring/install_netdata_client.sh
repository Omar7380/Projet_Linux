#!/bin/bash
# Script d'installation et configuration de Netdata (client à monitorer)
# Auteur: [Votre Nom]
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/netdata_client_setup.log"

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

# Demander les informations nécessaires
read -p "Adresse IP du serveur Netdata (ex: 10.42.0.185) : " NETDATA_SERVER
read -p "Clé API pour le streaming (ex: alicecaca) : " STREAM_KEY
read -p "Nom d'hôte pour ce client (ex: serveur1) : " HOSTNAME

# Validation des entrées
if [[ ! "$NETDATA_SERVER" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log "Format d'adresse IP invalide : $NETDATA_SERVER"
    echo "Erreur : Format d'adresse IP invalide" >&2
    exit 2
fi

if [[ -z "$STREAM_KEY" ]]; then
    log "Clé API non spécifiée"
    echo "Erreur : Vous devez spécifier une clé API" >&2
    exit 3
fi

if [[ -z "$HOSTNAME" ]]; then
    HOSTNAME=$(hostname)
    log "Nom d'hôte non spécifié, utilisation du nom actuel : $HOSTNAME"
fi

log "Démarrage de l'installation et configuration de Netdata (client)"

# Installation des dépendances
log "Installation des dépendances"
dnf install -y wget curl jq

# Installation de Netdata via le script d'installation officiel
log "Installation de Netdata via le script d'installation officiel"
bash <(curl -SsL https://my-netdata.io/kickstart.sh) --dont-wait

# Vérification de l'installation
if ! systemctl is-active --quiet netdata; then
    log "Erreur : Netdata n'a pas pu être installé correctement"
    echo "Erreur : Netdata n'a pas pu être installé correctement" >&2
    exit 4
fi

# Configuration du streaming (client/child)
log "Configuration du streaming (client/child)"
cat > /etc/netdata/stream.conf <<EOF
# Netdata streaming configuration (client/child)
# Généré le $(date)

[stream]
    enabled = yes
    destination = $NETDATA_SERVER:19999
    api key = $STREAM_KEY
EOF

# Configuration du nom d'hôte dans Netdata
log "Configuration du nom d'hôte dans Netdata"
cat > /etc/netdata/netdata.conf <<EOF
# Netdata configuration
# Généré le $(date)

[global]
    hostname = $HOSTNAME
    update every = 5
EOF

# Redémarrage de Netdata pour appliquer les changements
log "Redémarrage de Netdata pour appliquer les changements"
systemctl restart netdata

# Vérification que le service est en cours d'exécution
log "Vérification que le service est en cours d'exécution"
systemctl status netdata

log "Installation et configuration de Netdata (client) terminées avec succès"
echo "
=========================================================
Configuration de Netdata (client) terminée
Serveur parent : $NETDATA_SERVER:19999
Clé streaming : $STREAM_KEY
Nom d'hôte : $HOSTNAME

Surveillance de ce serveur disponible sur:
http://$NETDATA_SERVER:19999/host/$HOSTNAME/
=========================================================
" 