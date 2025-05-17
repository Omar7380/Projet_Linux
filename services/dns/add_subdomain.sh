#!/bin/bash
# Script d'ajout de sous-domaine DNS
# Date: Mai 2025

# Variables
ZONE_FILE="/var/named/test.lan.zone"
REV_FILE="/var/named/0.42.10.in-addr.arpa.zone"
DOMAIN="test.lan"

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté en tant que root" >&2
   exit 1
fi

# Entrée utilisateur
read -p "Nom d'utilisateur/sous-domaine à ajouter au DNS (ex: alice) : " USERNAME
read -p "Adresse IP à associer (ex: 10.42.0.100) : " USER_IP

# Validation des entrées
if [[ ! "$USER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Erreur : Format d'adresse IP invalide" >&2
    exit 2
fi

# Extraction de l'octet final pour la zone inverse
LAST_OCTET=$(echo "$USER_IP" | awk -F. '{print $4}')

# Vérification de l'existence des fichiers de zone
if [[ ! -f "$ZONE_FILE" || ! -f "$REV_FILE" ]]; then
    echo "Erreur : Fichiers de zone DNS introuvables" >&2
    echo "  Zone directe : $ZONE_FILE" >&2
    echo "  Zone inverse : $REV_FILE" >&2
    exit 3
fi

# Mise à jour du serial dans le fichier de zone directe
echo "[+] Mise à jour du serial DNS..."
CURRENT_SERIAL=$(grep -E '[0-9]{10} ; Serial' "$ZONE_FILE" | awk '{print $1}')
if [[ -z "$CURRENT_SERIAL" ]]; then
    CURRENT_SERIAL=$(grep -E '[0-9]{8}[0-9]{2} ; Serial' "$ZONE_FILE" | awk '{print $1}')
fi

if [[ -z "$CURRENT_SERIAL" ]]; then
    echo "Erreur : Impossible de trouver le numéro de série dans $ZONE_FILE" >&2
    exit 4
fi

NEW_SERIAL=$((CURRENT_SERIAL + 1))
sed -i "s/$CURRENT_SERIAL ; Serial/$NEW_SERIAL ; Serial/" "$ZONE_FILE"

# Ajout de l'enregistrement dans la zone directe (A)
echo "[+] Ajout dans $ZONE_FILE : $USERNAME.$DOMAIN → $USER_IP"
if grep -q "^$USERNAME\s" "$ZONE_FILE"; then
    echo "Le sous-domaine $USERNAME existe déjà, mise à jour..."
    sed -i "/^$USERNAME\s/c\\$USERNAME IN A $USER_IP" "$ZONE_FILE"
else
    echo "$USERNAME IN A $USER_IP" >> "$ZONE_FILE"
fi

# Ajout de l'enregistrement dans la zone inverse (PTR)
echo "[+] Ajout dans $REV_FILE : $USER_IP → $USERNAME.$DOMAIN"
if grep -q "^$LAST_OCTET\s" "$REV_FILE"; then
    echo "L'enregistrement PTR pour $LAST_OCTET existe déjà, mise à jour..."
    sed -i "/^$LAST_OCTET\s/c\\$LAST_OCTET IN PTR $USERNAME.$DOMAIN." "$REV_FILE"
else
    echo "$LAST_OCTET IN PTR $USERNAME.$DOMAIN." >> "$REV_FILE"
fi

# Mettre à jour le serial dans la zone inverse également
CURRENT_SERIAL=$(grep -E '[0-9]{10} ; Serial' "$REV_FILE" | awk '{print $1}')
if [[ -n "$CURRENT_SERIAL" ]]; then
    NEW_SERIAL=$((CURRENT_SERIAL + 1))
    sed -i "s/$CURRENT_SERIAL ; Serial/$NEW_SERIAL ; Serial/" "$REV_FILE"
fi

# Redémarrer le service DNS
echo "[+] Redémarrage du service BIND..."
systemctl restart named

# Test de la nouvelle configuration
echo "[+] Test de la résolution DNS pour $USERNAME.$DOMAIN..."
sleep 2
dig @localhost $USERNAME.$DOMAIN
dig @localhost -x $USER_IP

echo "✅ Domaine $USERNAME.$DOMAIN ajouté avec succès et pointe vers $USER_IP" 