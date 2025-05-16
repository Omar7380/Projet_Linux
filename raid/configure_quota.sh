#!/bin/bash
# Script de configuration des quotas disque
# Auteur: [Votre Nom]
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/quota_setup.log"

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

log "Démarrage de la configuration des quotas disque"

# Installation du paquet quota
log "Installation du paquet quota"
dnf install -y quota

# Vérifier si les partitions /users, /var/www et /var/mysql existent
if ! mountpoint -q /users || ! mountpoint -q /var/www || ! mountpoint -q /var/mysql; then
    log "Erreur: Les points de montage requis n'existent pas"
    echo "Erreur: Assurez-vous que /users, /var/www et /var/mysql sont des points de montage valides" >&2
    echo "Exécutez d'abord le script de configuration RAID" >&2
    exit 1
fi

# Modifier /etc/fstab pour activer les quotas sur les partitions
log "Modification de /etc/fstab pour activer les quotas"
cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d%H%M%S)

# Ajout de l'option usrquota pour les points de montage
awk '{
    if ($2 == "/users") {
        if ($4 ~ /noexec/) {
            sub(/noexec/, "noexec,usrquota", $4);
        } else {
            sub(/defaults/, "defaults,usrquota", $4);
        }
    }
    if ($2 == "/var/www") {
        sub(/defaults/, "defaults,usrquota", $4);
    }
    if ($2 == "/var/mysql") {
        sub(/defaults/, "defaults,usrquota", $4);
    }
    print $0;
}' /etc/fstab.backup.$(date +%Y%m%d%H%M%S) > /etc/fstab

# Remontage des partitions avec les nouvelles options
log "Remontage des partitions avec les options de quota"
mount -o remount /users
mount -o remount /var/www
mount -o remount /var/mysql

# Création des fichiers aquota.user
log "Initialisation des quotas sur /users"
quotacheck -cum /users
log "Initialisation des quotas sur /var/www"
quotacheck -cum /var/www
log "Initialisation des quotas sur /var/mysql"
quotacheck -cum /var/mysql

# Activation des quotas
log "Activation des quotas"
quotaon /users
quotaon /var/www
quotaon /var/mysql

# Vérification des quotas
log "Vérification des quotas"
echo "=== Quotas sur /users ==="
repquota /users
echo "=== Quotas sur /var/www ==="
repquota /var/www
echo "=== Quotas sur /var/mysql ==="
repquota /var/mysql

log "Configuration des quotas disque terminée avec succès"
echo "
=========================================================
Configuration des quotas disque terminée avec succès

Quotas activés sur :
- /users
- /var/www
- /var/mysql

Pour définir des quotas pour un utilisateur, utilisez :
setquota -u <utilisateur> <soft-block> <hard-block> <soft-inode> <hard-inode> <système-fichiers>

Exemple :
setquota -u utilisateur1 500000 600000 0 0 /users
(500MB soft limit, 600MB hard limit)
=========================================================
" 