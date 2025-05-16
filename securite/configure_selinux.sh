#!/bin/bash
# Script de configuration de SELinux
# Auteur: [Votre Nom]
# Date: Mai 2025

# Variables
LOG_FILE="/var/log/selinux_setup.log"

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   log "Ce script doit être exécuté en tant que root" 
   exit 1
fi

log "Démarrage de la configuration de SELinux"

# Installation des outils nécessaires
log "Installation des outils SELinux"
dnf install -y policycoreutils-python-utils

# Activer SELinux en mode enforcing
log "Activation de SELinux en mode enforcing"
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

# Vérification du mode SELinux actuel
CURRENT_MODE=$(getenforce)
log "Mode SELinux actuel : $CURRENT_MODE"

if [[ "$CURRENT_MODE" != "Enforcing" ]]; then
    log "Avertissement : SELinux n'est pas en mode Enforcing. Un redémarrage sera nécessaire pour appliquer les changements."
    echo -e "\nATTENTION : Le système doit être redémarré pour activer SELinux en mode enforcing.\n"
    
    # Configuration post-redémarrage
    cat > /root/selinux_post_reboot.sh <<EOF
#!/bin/bash
# Script post-redémarrage pour configurer SELinux

# Paramètres SELinux pour Samba
setsebool -P samba_enable_home_dirs on
setsebool -P samba_export_all_rw on

# Restaurer les contextes SELinux
restorecon -Rv /etc/ssh/
restorecon -Rv /etc/fail2ban/
restorecon -Rv /etc/my.cnf.d/

# Générer un module SELinux basé sur les logs d'audit (à exécuter après quelques jours d'utilisation)
# cat /var/log/audit/audit.log | audit2allow -M mon_module
# semodule -i mon_module.pp

echo "Configuration post-redémarrage SELinux terminée"
EOF
    chmod +x /root/selinux_post_reboot.sh
    log "Script post-redémarrage créé dans /root/selinux_post_reboot.sh"
else
    log "SELinux est déjà en mode Enforcing"
    
    # Application des paramètres SELinux
    log "Application des paramètres SELinux pour Samba"
    setsebool -P samba_enable_home_dirs on
    setsebool -P samba_export_all_rw on
    
    log "Restauration des contextes SELinux"
    restorecon -Rv /etc/ssh/
    restorecon -Rv /etc/fail2ban/
    restorecon -Rv /etc/my.cnf.d/
fi

log "Configuration SELinux terminée avec succès" 