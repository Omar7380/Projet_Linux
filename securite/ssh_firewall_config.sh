#!/bin/bash
# Script de configuration sécurisée de SSH et du pare-feu
# Auteur: [Votre Nom]
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/security_setup.log"
SSH_CONFIG="/etc/ssh/sshd_config"

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

log "Démarrage de la configuration de sécurité (SSH & Firewall)"

# Configuration de SSH
log "Configuration sécurisée de SSH"
cp "$SSH_CONFIG" "$SSH_CONFIG.backup.$(date +%Y%m%d%H%M%S)"

# Utiliser une nouvelle configuration sécurisée
cat > "$SSH_CONFIG" <<EOF
# Configuration SSH sécurisée - $(date)
Port 22
AddressFamily inet
ListenAddress 0.0.0.0

# Authentification
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Sécurité
LogLevel VERBOSE
X11Forwarding no
TCPKeepAlive no
AllowTcpForwarding no
PermitEmptyPasswords no
LoginGraceTime 30
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 2

# Autres paramètres
UsePAM yes
Subsystem sftp internal-sftp
EOF

log "Configuration SSH mise à jour, redémarrage du service"
systemctl restart sshd

# Installation et configuration du pare-feu
log "Installation et configuration du pare-feu (firewalld)"
if ! rpm -q firewalld &>/dev/null; then
    log "Installation de firewalld..."
    dnf install -y firewalld
fi

log "Activation de firewalld"
systemctl enable --now firewalld

# Configuration des services de base autorisés
log "Autorisation des services de base"
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https

# Rechargement de la configuration du pare-feu
log "Rechargement de la configuration du pare-feu"
firewall-cmd --reload

log "Configuration du pare-feu terminée"

# État SELinux
log "État actuel de SELinux"
sestatus

log "Configuration de sécurité (SSH & Firewall) terminée avec succès" 