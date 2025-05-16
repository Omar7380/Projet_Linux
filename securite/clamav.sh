#!/bin/bash
# Script d'installation et configuration de ClamAV
# Auteur: [Votre Nom]
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/clamav_setup.log"
SCRIPT_DIR="/opt/scripts"
SCAN_SCRIPT="$SCRIPT_DIR/scan_clamav.sh"

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

log "Démarrage de l'installation de ClamAV"

# Installation ClamAV
log "Installation des paquets ClamAV"
dnf install -y clamav clamav-update

# Préparation des dossiers
log "Création du dossier scripts"
mkdir -p "$SCRIPT_DIR"

# Mise à jour des signatures
log "Mise à jour des signatures ClamAV"
freshclam

# Création du script de scan
log "Création du script de scan ClamAV"
cat > "$SCAN_SCRIPT" <<EOF
#!/bin/bash
# Script de scan ClamAV
# Date: $(date +"%Y-%m-%d")

# Définir les répertoires à scanner (sauf /backup pour économiser du temps)
SCAN_DIR="/srv /var/www /var/mysql /users"
LOG_FILE="/var/log/clamav_scan.log"

echo "[$(date +"%Y-%m-%d %H:%M:%S")] Démarrage du scan ClamAV" | tee -a "\$LOG_FILE"

# Exécuter ClamAV pour scanner les répertoires définis
clamscan -r \$SCAN_DIR --exclude-dir="*/.cache" --move=/var/quarantine | tee -a "\$LOG_FILE"

# Résumé des résultats
INFECTED=\$(grep "Infected files" "\$LOG_FILE" | tail -1 | awk '{print \$3}')
if [ "\$INFECTED" != "0" ]; then
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] ⚠️ \$INFECTED fichiers infectés trouvés !" | tee -a "\$LOG_FILE"
    echo "Les fichiers infectés ont été déplacés vers /var/quarantine" | tee -a "\$LOG_FILE"
else
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] ✅ Aucun fichier infecté trouvé." | tee -a "\$LOG_FILE"
fi
EOF

# Rendre le script exécutable
chmod +x "$SCAN_SCRIPT"

# Créer le dossier de quarantaine
log "Création du dossier de quarantaine"
mkdir -p /var/quarantine
chmod 700 /var/quarantine

# Ajouter à crontab
log "Configuration des scans programmés"
(crontab -l 2>/dev/null | grep -v "scan_clamav.sh"; 
 echo "0 12 * * * $SCAN_SCRIPT > /dev/null 2>&1";
 echo "0 23 * * * $SCAN_SCRIPT > /dev/null 2>&1") | crontab -

# Vérification de l'installation
log "Vérification de l'installation ClamAV"
CLAMSCAN_VERSION=$(clamscan --version)
log "ClamAV installé : $CLAMSCAN_VERSION"

log "Installation et configuration de ClamAV terminées avec succès"
echo "
=========================================================
Installation ClamAV terminée
Scanner disponible : $SCAN_SCRIPT
Exécution programmée : 12h00 et 23h00 chaque jour
=========================================================
"

# Exécuter un premier scan pour vérifier
log "Lancement d'un premier scan de test"
"$SCAN_SCRIPT" 