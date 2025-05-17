#!/bin/bash
# Script d'installation et configuration de Netdata (serveur de monitoring)
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/netdata_server_setup.log"
STREAM_KEY="alicecaca"  # Clé d'API pour le streaming (à modifier pour la production)

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

log "Démarrage de l'installation et configuration de Netdata (serveur de monitoring)"

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
    exit 2
fi

# Configuration du streaming (parent)
log "Configuration du streaming (parent)"
cat > /etc/netdata/stream.conf <<EOF
# Netdata streaming configuration (parent/master)
# Généré le $(date)

# Activer le streaming depuis d'autres hôtes
[$STREAM_KEY]
    enabled = yes
    default history = 3600
    default memory mode = ram
    health enabled = auto
EOF

# Redémarrage de Netdata pour appliquer les changements
log "Redémarrage de Netdata pour appliquer les changements"
systemctl restart netdata

# Configuration du pare-feu
log "Configuration du pare-feu pour Netdata"
firewall-cmd --permanent --add-port=19999/tcp
firewall-cmd --reload

# Vérification que le service est en cours d'exécution
log "Vérification que le service est en cours d'exécution"
systemctl status netdata

# Affichage des informations importantes
SERVER_IP=$(hostname -I | awk '{print $1}')
log "Netdata est accessible sur http://$SERVER_IP:19999/"

log "Installation et configuration de Netdata (serveur de monitoring) terminées avec succès"
echo "
=========================================================
Configuration de Netdata (serveur de monitoring) terminée
URL d'accès : http://$SERVER_IP:19999/
Clé de streaming : $STREAM_KEY

Pour ajouter un client, exécutez sur le client:
1. Installez Netdata
2. Configurez stream.conf avec:
   [stream]
   enabled = yes
   destination = $SERVER_IP:19999
   api key = $STREAM_KEY
3. Redémarrez Netdata sur le client
=========================================================
"

# Création d'un script pour ajouter des clients facilement
log "Création d'un script pour ajouter des clients facilement"
cat > /root/add_netdata_client.sh <<EOF
#!/bin/bash
# Script pour générer la configuration client Netdata

if [ \$# -ne 1 ]; then
    echo "Usage: \$0 <nom_du_client>"
    exit 1
fi

CLIENT_NAME=\$1
SERVER_IP="$SERVER_IP"
STREAM_KEY="$STREAM_KEY"

echo "Configuration pour le client \$CLIENT_NAME:"
echo "----------------------------------------"
echo "Exécutez sur le client (\$CLIENT_NAME):"
echo "1. Installez Netdata:"
echo "   bash <(curl -SsL https://my-netdata.io/kickstart.sh) --dont-wait"
echo ""
echo "2. Configurez /etc/netdata/stream.conf avec:"
echo "[stream]"
echo "  enabled = yes"
echo "  destination = $SERVER_IP:19999"
echo "  api key = $STREAM_KEY"
echo ""
echo "3. Configurez /etc/netdata/netdata.conf avec:"
echo "[global]"
echo "  hostname = \$CLIENT_NAME"
echo ""
echo "4. Redémarrez Netdata:"
echo "   systemctl restart netdata"
echo "----------------------------------------"
EOF

chmod +x /root/add_netdata_client.sh
log "Script /root/add_netdata_client.sh créé pour faciliter l'ajout de clients" 