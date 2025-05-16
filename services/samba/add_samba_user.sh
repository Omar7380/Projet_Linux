#!/bin/bash
# Script d'ajout d'utilisateur avec accès Samba
# Auteur: [Votre Nom]
# Date: Mai 2025

# Vérifier les privilèges root
if [[ $EUID -ne 0 ]]; then
  echo "Ce script doit être exécuté en tant que root" >&2
  exit 1
fi

# Créer /users si inexistant
mkdir -p /users

# Récupère le nom d'utilisateur
if [ -n "$1" ]; then
  USERNAME="$1"
else
  read -p "Nom du nouvel utilisateur : " USERNAME
fi

# Vérifie si l'utilisateur existe déjà
if id "$USERNAME" &>/dev/null; then
  echo "Erreur : l'utilisateur '$USERNAME' existe déjà." >&2
  exit 2
fi

# Lecture du mot de passe (sans écho)
read -s -p "Mot de passe pour $USERNAME : " PASSWORD
echo
read -s -p "Confirmer le mot de passe : " PASSWORD_CONFIRM
echo

if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
  echo "Les mots de passe ne correspondent pas." >&2
  exit 3
fi

# Création de l'utilisateur avec home dir personnalisé dans /users
useradd -m -d /users/$USERNAME "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

# Ajouter au groupe wheel ?
read -p "Ajouter $USERNAME au groupe sudo (wheel) ? [y/N] : " ADD_SUDO
if [[ "$ADD_SUDO" =~ ^[Yy]$ ]]; then
  usermod -aG wheel "$USERNAME"
  echo "$USERNAME ajouté au groupe wheel."
fi

echo "Utilisateur système '$USERNAME' créé avec succès avec home dans /users/$USERNAME."

# Créer l'utilisateur Samba
echo "$PASSWORD" | smbpasswd -a "$USERNAME" >/dev/null 2>&1
echo "Utilisateur Samba '$USERNAME' ajouté."

# Créer le dossier privé Samba
SHARE_PATH="/srv/samba/$USERNAME"
mkdir -p "$SHARE_PATH"
chown "$USERNAME:$USERNAME" "$SHARE_PATH"
chmod 700 "$SHARE_PATH"

# Contexte SELinux (si applicable)
if command -v semanage &>/dev/null; then
  semanage fcontext -a -t samba_share_t "${SHARE_PATH}(/.*)?"
  restorecon -Rv "$SHARE_PATH"
fi

# Ajouter la section dans smb.conf si pas encore présente
if ! grep -q "^\[$USERNAME\]" /etc/samba/smb.conf; then
cat >> /etc/samba/smb.conf <<EOF

[$USERNAME]
   path = $SHARE_PATH
   browsable = yes
   writable = yes
   guest ok = no
   read only = no
   valid users = $USERNAME
   force user = $USERNAME
   force group = $USERNAME
EOF
  echo "Section Samba [$USERNAME] ajoutée à smb.conf."
else
  echo "La section [$USERNAME] existe déjà dans smb.conf."
fi

# Redémarrer Samba
systemctl restart smb nmb
echo "✅ Configuration terminée pour l'utilisateur '$USERNAME'." 