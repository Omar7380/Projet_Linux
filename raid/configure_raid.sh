#!/bin/bash
# Script de configuration du RAID 1 et partitionnement
# Auteur: [Votre Nom]
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/raid_setup.log"

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

log "Démarrage de la configuration RAID 1"

# Installer mdadm si nécessaire
if ! rpm -q mdadm &>/dev/null; then
    log "Installation de mdadm..."
    dnf install -y mdadm
fi

# Créer le RAID 1
log "Création du RAID 1 sur /dev/nvme1n1 et /dev/nvme2n1"
mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/nvme1n1 /dev/nvme2n1

# Attendre la synchronisation
log "Attente de la synchronisation du RAID..."
cat /proc/mdstat
sleep 5

# Créer table de partitions GPT
log "Création de la table de partitions GPT sur /dev/md0"
parted /dev/md0 --script mklabel gpt

# Créer les 5 partitions
log "Création des 5 partitions sur /dev/md0"
parted /dev/md0 --script mkpart primary ext4 1MiB 501MiB
parted /dev/md0 --script mkpart primary ext4 501MiB 701MiB
parted /dev/md0 --script mkpart primary ext4 701MiB 851MiB
parted /dev/md0 --script mkpart primary ext4 851MiB 1751MiB
parted /dev/md0 --script mkpart primary ext4 1751MiB 100%

# Formater les partitions
log "Formatage des partitions en ext4"
mkfs.ext4 /dev/md0p1
mkfs.ext4 /dev/md0p2
mkfs.ext4 /dev/md0p3
mkfs.ext4 /dev/md0p4
mkfs.ext4 /dev/md0p5

# Créer les points de montage
log "Création des points de montage"
mkdir -p /srv /var/www /backup /var/mysql /users

# Monter les partitions
log "Montage des partitions"
mount /dev/md0p1 /srv
mount /dev/md0p2 /var/www
mount /dev/md0p3 /backup
mount /dev/md0p4 /var/mysql
mount /dev/md0p5 /users

# Afficher les UUID
log "UUID des partitions :"
blkid /dev/md0p1 /dev/md0p2 /dev/md0p3 /dev/md0p4 /dev/md0p5

# Configuration du fstab
log "Configuration du montage automatique dans /etc/fstab"
echo "# RAID partitions - Created $(date)" >> /etc/fstab
UUID1=$(blkid -s UUID -o value /dev/md0p1)
UUID2=$(blkid -s UUID -o value /dev/md0p2)
UUID3=$(blkid -s UUID -o value /dev/md0p3)
UUID4=$(blkid -s UUID -o value /dev/md0p4)
UUID5=$(blkid -s UUID -o value /dev/md0p5)

echo "UUID=$UUID1 /srv ext4 defaults 0 2" >> /etc/fstab
echo "UUID=$UUID2 /var/www ext4 defaults 0 2" >> /etc/fstab
echo "UUID=$UUID3 /backup ext4 defaults 0 2" >> /etc/fstab
echo "UUID=$UUID4 /var/mysql ext4 defaults 0 2" >> /etc/fstab
echo "UUID=$UUID5 /users ext4 defaults 0 2" >> /etc/fstab

log "Configuration RAID terminée avec succès" 