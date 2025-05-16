#!/bin/bash
# Script de configuration RAID 1 et partitionnement
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

log "Démarrage de la configuration RAID 1 et partitionnement"

# Installation de mdadm
log "Installation de mdadm"
dnf install -y mdadm

# Vérifier les disques disponibles
log "Disques disponibles sur le système :"
DISKS=$(lsblk -d -o NAME,SIZE,TYPE | grep -v "loop\|sr0\|ram" | grep "disk")
echo "$DISKS"

# Demander les disques à utiliser
echo ""
echo "ATTENTION: Cette opération va détruire toutes les données sur les disques sélectionnés!"
echo "Format attendu des disques: /dev/nvme1n1 /dev/nvme2n1"
read -p "Entrez les 2 disques à utiliser pour le RAID 1 (séparés par un espace): " DISK1 DISK2

if [[ -z "$DISK1" || -z "$DISK2" ]]; then
    log "Erreur: vous devez spécifier 2 disques"
    echo "Erreur: vous devez spécifier 2 disques" >&2
    exit 1
fi

# Confirmation
echo -e "\nVous allez créer un RAID 1 avec:\nDisque 1: $DISK1\nDisque 2: $DISK2"
read -p "Êtes-vous sûr de vouloir continuer? (oui/NON): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Oo][Uu][Ii]$ ]]; then
    log "Opération annulée par l'utilisateur"
    echo "Opération annulée."
    exit 0
fi

# Création du RAID 1
log "Création du RAID 1 avec $DISK1 et $DISK2"
mdadm --create /dev/md0 --level=1 --raid-devices=2 "$DISK1" "$DISK2"

# Attendre que le RAID se synchronise
log "Synchronisation du RAID en cours"
echo "Synchronisation du RAID en cours. Veuillez patienter..."
cat /proc/mdstat
echo ""
read -p "Appuyez sur Entrée quand la synchronisation est terminée ou pour continuer immédiatement..." 

# Création d'une table GPT
log "Création d'une table de partitions GPT sur /dev/md0"
parted /dev/md0 --script mklabel gpt

# Création des 5 partitions
log "Création des 5 partitions sur /dev/md0"
parted /dev/md0 --script mkpart primary ext4 1MiB 501MiB
parted /dev/md0 --script mkpart primary ext4 501MiB 701MiB
parted /dev/md0 --script mkpart primary ext4 701MiB 851MiB
parted /dev/md0 --script mkpart primary ext4 851MiB 1751MiB
parted /dev/md0 --script mkpart primary ext4 1751MiB 100%

# Formatage des partitions
log "Formatage des partitions en ext4"
for i in {1..5}; do
    log "Formatage de /dev/md0p$i"
    mkfs.ext4 /dev/md0p$i
done

# Création des points de montage
log "Création des points de montage"
mkdir -p /srv /var/www /backup /var/mysql /users

# Montage des partitions
log "Montage des partitions"
mount /dev/md0p1 /srv
mount /dev/md0p2 /var/www
mount /dev/md0p3 /backup
mount /dev/md0p4 /var/mysql
mount /dev/md0p5 /users

# Affichage des UUID
log "Affichage des UUID des partitions créées"
UUID_INFO=$(blkid /dev/md0p1 /dev/md0p2 /dev/md0p3 /dev/md0p4 /dev/md0p5)
echo "$UUID_INFO"

# Extraction des UUID pour configuration fstab
UUID1=$(blkid -s UUID -o value /dev/md0p1)
UUID2=$(blkid -s UUID -o value /dev/md0p2)
UUID3=$(blkid -s UUID -o value /dev/md0p3)
UUID4=$(blkid -s UUID -o value /dev/md0p4)
UUID5=$(blkid -s UUID -o value /dev/md0p5)

# Configuration du montage automatique (fstab)
log "Configuration du montage automatique dans /etc/fstab"

# Sauvegarde du fichier fstab
cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d%H%M%S)

# Ajout des entrées dans fstab avec noexec pour /srv, /backup et /users
cat >> /etc/fstab <<EOF
UUID=$UUID1  /srv        ext4  defaults,noexec 0 2
UUID=$UUID2  /var/www    ext4  defaults 0 2
UUID=$UUID3  /backup     ext4  defaults,noexec 0 2
UUID=$UUID4  /var/mysql  ext4  defaults 0 2
UUID=$UUID5  /users      ext4  defaults,noexec 0 2
EOF

log "Configuration RAID 1 et partitionnement terminée avec succès"
echo "
=========================================================
Configuration RAID 1 terminée avec succès
Partitions créées :
1. /dev/md0p1 - /srv (noexec)
2. /dev/md0p2 - /var/www
3. /dev/md0p3 - /backup (noexec)
4. /dev/md0p4 - /var/mysql
5. /dev/md0p5 - /users (noexec)

Un redémarrage est recommandé pour tester le montage automatique.
=========================================================
" 