#!/bin/bash
# Script d'installation et configuration du serveur DNS (BIND)
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/dns_setup.log"
DOMAIN="test.lan"
SERVER_IP="10.42.0.249"  # À modifier selon votre configuration
NETWORK="10.42.0"
REV_ZONE="0.42.10.in-addr.arpa"

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

log "Démarrage de l'installation et configuration du serveur DNS (BIND)"

# Installation des paquets BIND
log "Installation des paquets BIND"
dnf install -y bind bind-utils

# Sauvegarde de la configuration existante
log "Sauvegarde de la configuration BIND existante"
if [ -f /etc/named.conf ]; then
    cp /etc/named.conf /etc/named.conf.backup.$(date +%Y%m%d%H%M%S)
fi

# Configuration principale de BIND
log "Configuration principale de BIND"
cat > /etc/named.conf <<EOF
//
// Fichier de configuration BIND pour $DOMAIN
// Généré le $(date)
//

options {
    listen-on port 53 { any; };
    listen-on-v6 port 53 { ::1; };
    directory "/var/named";
    dump-file "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    
    // Permissions
    allow-query     { any; };
    recursion yes;
    
    dnssec-enable yes;
    dnssec-validation yes;
    
    // Forwarders (Google DNS)
    forwarders      { 8.8.8.8; 8.8.4.4; };
};

logging {
    channel default_debug {
        file "data/named.run";
        severity dynamic;
    };
};

zone "." IN {
    type hint;
    file "named.ca";
};

// Zone directe principale
zone "$DOMAIN" IN {
    type master;
    file "/var/named/$DOMAIN.zone";
    allow-update { none; };
};

// Zone inverse
zone "$REV_ZONE" IN {
    type master;
    file "/var/named/$REV_ZONE.zone";
    allow-update { none; };
};

include "/etc/named.rfc1912.zones";
EOF

# Création du fichier de zone directe
log "Création du fichier de zone directe : $DOMAIN.zone"
SERVER_LAST_OCTET=$(echo $SERVER_IP | cut -d. -f4)

cat > /var/named/$DOMAIN.zone <<EOF
\$TTL 86400
@   IN  SOA ns1.$DOMAIN. admin.$DOMAIN. (
        $(date +%Y%m%d)01 ; Serial
        3600       ; Refresh
        1800       ; Retry
        604800     ; Expire
        86400 )    ; Minimum TTL

; Serveurs de noms
@       IN  NS      ns1.$DOMAIN.

; Serveurs
ns1     IN  A       $SERVER_IP
www     IN  A       $SERVER_IP

; Autres enregistrements
@       IN  A       $SERVER_IP
EOF

# Création du fichier de zone inverse
log "Création du fichier de zone inverse : $REV_ZONE.zone"
cat > /var/named/$REV_ZONE.zone <<EOF
\$TTL 86400
@   IN  SOA ns1.$DOMAIN. admin.$DOMAIN. (
        $(date +%Y%m%d)01 ; Serial
        3600       ; Refresh
        1800       ; Retry
        604800     ; Expire
        86400 )    ; Minimum TTL

; Serveurs de noms
@       IN  NS      ns1.$DOMAIN.

; Réverse
$SERVER_LAST_OCTET  IN  PTR     ns1.$DOMAIN.
$SERVER_LAST_OCTET  IN  PTR     www.$DOMAIN.
EOF

# Ajustement des permissions
log "Ajustement des permissions des fichiers de configuration"
chown root:named /var/named/$DOMAIN.zone
chown root:named /var/named/$REV_ZONE.zone
chmod 640 /var/named/$DOMAIN.zone
chmod 640 /var/named/$REV_ZONE.zone

# Configuration du pare-feu
log "Configuration du pare-feu pour DNS"
firewall-cmd --permanent --add-service=dns
firewall-cmd --permanent --add-port=53/udp
firewall-cmd --permanent --add-port=53/tcp
firewall-cmd --reload

# Activation et démarrage du service
log "Activation et démarrage du service BIND"
systemctl enable --now named

# Vérification de l'état du service
log "Vérification de l'état du service BIND"
systemctl status named

log "Test de la résolution DNS locale"
dig @localhost ns1.$DOMAIN
dig @localhost -x $SERVER_IP

log "Installation et configuration du serveur DNS (BIND) terminées avec succès"
echo "
=========================================================
Configuration DNS terminée pour le domaine $DOMAIN
Serveur NS principal : ns1.$DOMAIN ($SERVER_IP)
=========================================================
" 