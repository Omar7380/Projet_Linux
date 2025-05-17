#!/bin/bash
# Script de check des services installés
# Date: Mai 2025

echo "===== ✅ VÉRIFICATION DES SERVICES SYSTÈME ====="

# 🔐 SELinux
echo -e "\n🔐 SELinux :"
sestatus | grep "Current mode"

# 📦 Quotas
echo -e "\n📦 Quotas utilisateurs (/var/www et /users) :"
for mount in /var/www /users; do
    echo -n "$mount : "
    repquota -u "$mount" 2>/dev/null | grep -v "^#"
done

# 🔥 Firewalld
echo -e "\n🔥 Firewalld :"
if systemctl is-active firewalld &>/dev/null; then
    echo "✅ Firewalld est actif"
    
    echo -e "\n🌐 Zone par défaut :"
    DEFAULT_ZONE=$(firewall-cmd --get-default-zone)
    echo "$DEFAULT_ZONE"

    echo -e "\n📋 Services autorisés dans $DEFAULT_ZONE :"
    firewall-cmd --zone=$DEFAULT_ZONE --list-services

    echo -e "\n📦 Ports autorisés dans $DEFAULT_ZONE :"
    firewall-cmd --zone=$DEFAULT_ZONE --list-ports

    echo -e "\n🚫 Ports explicitement bloqués :"
    BLOCKED=$(firewall-cmd --zone=$DEFAULT_ZONE --list-rich-rules | grep -E "reject|drop")
    [[ -z "$BLOCKED" ]] && echo "Aucun" || echo "$BLOCKED"

else
    echo "❌ Firewalld est inactif"
fi

# 📁 Samba
echo -e "\n📁 Samba (smb/nmb) :"
systemctl is-active smb && echo "smb : actif" || echo "smb : inactif"
systemctl is-active nmb && echo "nmb : actif" || echo "nmb : inactif"

# 📡 VSFTPD
echo -e "\n📡 VSFTPD :"
systemctl is-active vsftpd && echo "vsftpd : actif" || echo "vsftpd : inactif"

# 🌐 BIND / DNS
echo -e "\n🌐 DNS (named) :"
if systemctl is-active named &>/dev/null; then
  echo "named : actif"
else
  echo "named : inactif"
fi

# Vérifie la zone sub.lan et l'IP coco.sub.lan → 10.49.0.249
echo -e "\n📂 Vérification de la zone DNS : sub.lan"
if grep -q 'zone "sub.lan"' /etc/named.conf; then
  echo "✅ Zone sub.lan déclarée dans named.conf"
else
  echo "❌ Zone sub.lan ABSENTE dans named.conf"
fi

ZONE_FILE="/var/named/sub.lan.zone"
if [[ -f "$ZONE_FILE" ]]; then
  if grep -Eq "coco\s+IN\s+A\s+10\.49\.0\.249" "$ZONE_FILE"; then
    echo "✅ coco.sub.lan → 10.49.0.249 présent dans $ZONE_FILE"
  else
    echo "❌ Entrée coco.sub.lan IN A 10.49.0.249 absente dans $ZONE_FILE"
  fi
else
  echo "❌ Fichier $ZONE_FILE introuvable"
fi

# 🚨 Fail2Ban
echo -e "\n🚨 Fail2Ban :"
systemctl is-active fail2ban && echo "fail2ban : actif" || echo "fail2ban : inactif"
echo -e "\n🔍 Jails actives :"
fail2ban-client status 2>/dev/null | grep "Jail list" || echo "Aucune jail active ou Fail2Ban mal configuré"

# 🦠 ClamAV
echo -e "\n🦠 ClamAV :"
if systemctl list-units --type=service | grep -q clamd; then
    systemctl is-active clamd && echo "clamd : actif" || echo "clamd : inactif"
else
    echo "clamd non installé"
fi
echo -n "Version base de virus : "
freshclam --version 2>/dev/null | head -n1 || echo "freshclam non disponible"

# ⏱️ Crontabs
echo -e "\n⏱️ Tâches crontab (utilisateur root) :"
crontab -l 2>/dev/null || echo "Aucune tâche définie pour root"

echo -e "\n⏱️ Tâches crontab système (/etc/cron.*) :"
for f in /etc/cron.daily/* /etc/cron.hourly/* /etc/cron.weekly/* /etc/cron.d/*; do
    [[ -x "$f" ]] && echo "✓ $f"
done

echo -e "\n===== ✅ FIN DU DIAGNOSTIC ====="
