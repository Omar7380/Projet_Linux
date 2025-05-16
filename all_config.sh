**Projet Linux – Amazon Linux 2**

## RAID 1 et partitionnement

```bash
 #Intaller le service
 dnf install mdadm
 
 #### Crée le RAID 1 global sur les disques entiers :
sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/nvme1n1 /dev/nvme2n1

#### Patiente que le RAID se synchronise (facultatif mais conseillé) :
watch cat /proc/mdstat

#### Crée une table GPT sur `/dev/md0` :
sudo parted /dev/md0 --script mklabel gpt

#### Crée les **5 partitions** sur `/dev/md0` :
sudo parted /dev/md0 --script mkpart primary ext4 1MiB 501MiB    
parted /dev/md0 --script mkpart primary ext4 501MiB 701MiB   
parted /dev/md0 --script mkpart primary ext4 701MiB 851MiB   
parted /dev/md0 --script mkpart primary ext4 851MiB 1751MiB 
parted /dev/md0 --script mkpart primary ext4 1751MiB 100%


### Formater les nouvelles partitions**
mkfs.ext4 /dev/md0p1 
mkfs.ext4 /dev/md0p2 
mkfs.ext4 /dev/md0p3  
mkfs.ext4 /dev/md0p4  
mkfs.ext4 /dev/md0p5

### Créer les points de montage**
mkdir -p /srv /var/www /backup /var/mysql /users

### Monter les partitions**
mount /dev/md0p1 /srv 
mount /dev/md0p2 /var/www 
mount /dev/md0p3 /backup 
mount /dev/md0p4 /var/mysql 
mount /dev/md0p5 /users

### Afficher les UUID des partition crée
blkid /dev/md0p1 /dev/md0p2 /dev/md0p3 /dev/md0p4 /dev/md0p5

### Configurer le montage automatique (fstab)
UUID=64bc6d74-0caa-430a-80e0-d3d4bbc48125  /srv        ext4  defaults 0 2
UUID=92266adc-1df6-4683-8234-7ada1b526f4e  /var/www    ext4  defaults 0 2
UUID=def3051c-5a38-4f53-83cf-d343e8a45a83  /backup     ext4  defaults 0 2
UUID=11b3ce98-6e1a-4976-aa22-1cb24bbae4f1  /var/mysql  ext4  defaults 0 2
UUID=ee2325c5-fc0d-4170-9b1a-b3bdc47419ae  /users      ext4  defaults 0 2
```

## Quota
```bash 
sudo dnf install quota -y

# 1. Modifier /etc/fstab (ajouter usrquota sur les 2 lignes)
sudo nano /etc/fstab

# 2. Monter les partitions si besoin
sudo mount -a

# 3. Vérification et initialisation
sudo quotacheck -cum /users
sudo quotacheck -cum /var/www
sudo quotacheck -cum /var/mysql
sudo quotaon /users
sudo quotaon /var/www
sudo quotaon /var/mysql

# 5. Vérifier
sudo repquota /users
sudo repquota /var/www
sudo repquota /var/mysql
```
## Mise à jour et dépôts ,dépendace

```bash
dnf update -y
dnf install epel-release -y
sudo dnf install quota -y
sudo dnf install cronie -y
```

## Installer Crontab
```bash
sudo dnf install cronie -y
sudo systemctl enable crond
sudo systemctl start crond

```
## SSH (/etc/ssh/sshd_config)
```bash
LogLevel Verbose
PermitRootLogin no 
PasswordAuthentication no
X11Forwarding no 
TCPKeepAlive no
AllowTcpForwarding no 
PermitEmptyPasswords no 
LoginGraceTime 30
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 2
```
## Firewall & SELinux

```bash
# Activer le firewall
dnf install firewalld -y
systemctl enable --now firewalld
#déactiver SELinux
nano /etc/selinux/config
	SELINUX=permissive

#Activer Firewalld
sudo systemctl enable firewalld
sudo systemctl start firewalld

# Autoriser services de base
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
# SELinux en mode enforcing (vérifier)
sestatus
```

### SeLinux
```bash
#!/bin/bash
# 1. Activer SELinux en mode enforcing
echo "Activation de SELinux en mode enforcing..."
sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

# 2. Redémarrer le serveur pour appliquer la modification
echo "Redémarrage du serveur pour appliquer les modifications SELinux..."
sudo reboot

# ---------------------------------------------------------------------------
# Après le redémarrage, exécute les commandes suivantes une fois connecté.
# ---------------------------------------------------------------------------

# 3. Appliquer les paramètres SELinux pour Samba (autoriser les répertoires home dans Samba)
echo "Activation de samba_enable_home_dirs pour SELinux..."
sudo setsebool -P samba_enable_home_dirs on

# 4. Restaurer les contextes SELinux pour SSH
echo "Restauration des contextes SELinux pour /etc/ssh/..."
sudo restorecon -Rv /etc/ssh/

# 6. Activer le partage Samba en lecture-écriture
echo "Activation de samba_export_all_rw pour SELinux..."
sudo setsebool -P samba_export_all_rw on

# 7. Restaurer les contextes SELinux pour Fail2ban
echo "Restauration des contextes SELinux pour /etc/fail2ban/..."
sudo restorecon -Rv /etc/fail2ban/

# 8. Restaurer les contextes SELinux pour MariaDB
echo "Restauration des contextes SELinux pour /etc/my.cnf..."
# Si le fichier my.cnf n'existe pas, adapter le chemin en fonction de l'installation de MariaDB
sudo restorecon -Rv /etc/my.cnf.d/

# 9. Installer les outils nécessaires pour la gestion des politiques SELinux
echo "Installation de policycoreutils-python-utils..."
sudo yum install -y policycoreutils-python-utils

# 10. Générer un module SELinux basé sur les logs d'audit
echo "Génération du module SELinux à partir des logs d'audit..."
sudo cat /var/log/audit/audit.log | sudo audit2allow -M mon_module

# 11. Appliquer le module SELinux généré
echo "Application du module SELinux généré..."
sudo semodule -i mon_module.pp

# ---------------------------------------------------------------------------
# Les étapes jusqu'à l'étape 6 sont complétées. Le module SELinux a été généré et installé.
# Si tu veux supprimer le module, tu peux utiliser la commande

```

## Partage de fichiers (Samba)

###  installer Samba

```bash
#!/bin/bash

SHARE_NAME="partage"
SHARE_PATH="/srv/samba/$SHARE_NAME"

dnf update -y
dnf install -y samba samba-client samba-common

mkdir -p "$SHARE_PATH"
chmod -R 0775 "$SHARE_PATH"
chown -R nobody:nobody "$SHARE_PATH"

semanage fcontext -a -t samba_share_t "$SHARE_PATH(/.*)?"
restorecon -Rv "$SHARE_PATH"

cat >> /etc/samba/smb.conf <<EOF
[global]
   workgroup = WORKGROUP
   server string = Samba Server
   map to guest = Bad User
   
[$SHARE_NAME]
   path = $SHARE_PATH
   browsable = yes
   writable = yes
   guest ok = yes
   read only = no
   create mask = 0775
   force user = nobody
   force group = nobody
EOF

firewall-cmd --permanent --add-service=samba
firewall-cmd --reload

systemctl enable --now smb nmb
```

### Samba script (Validé)
```bash
#!/bin/bash
# Vérifie si exécuté en root
if [[ $EUID -ne 0 ]]; then
  echo "Ce script doit être exécuté en tant que root." >&2
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

```

### Si problème avec compte samba (windows)

Dans l'invite de commandes (CMD), exécute :

```powershell
net use * /delete /y
```
## Service DNS (Bind)

```bash
dnf install bind bind-utils -y

# /etc/named.conf
# attention bien inverser le 1 et 3 chiffre de l'ip du serv
cat >> /etc/named.conf <<EOF
options {
    listen-on port 53 { any; };
    directory "/var/named";
    dump-file "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    allow-query     { any; };
    forwarders      { 8.8.8.8; };
    recursion yes;
};
zone "sub.lan" IN {
  type master;
  file "/var/named/sub.lan.zone";
};

zone "0.42.10.in-addr.arpa" IN {
  type master;
  file "/var/named/0.42.10.rev";
};
EOF
# Fichier de zone directe
cat >> /var/named/sub.lan.zone <<EOF
$TTL 86400
@   IN  SOA ns1.sub.lan. root.sub.lan. (
        2025050301 ; Serial
        3600       ; Refresh
        1800       ; Retry
        604800     ; Expire
        86400 )    ; Minimum
    IN  NS  ns1.sub.lan.
ns1 IN  A   10.42.0.249
www IN  A   10.42.0.249
EOF
# Fichier de zone inverse
# pour les PRT c'est le dernier chiffre de l'ip serv
cat >> /var/named/0.42.10.rev <<EOF
$TTL 86400
@   IN  SOA ns1.sub.lan. root.sub.lan. (
        2025050301 ; Serial
        3600       ; Refresh
        1800       ; Retry
        604800     ; Expire
        86400 )    ; Minimum
    IN  NS  ns1.sub.lan.
249 IN  PTR ns1.sub.lan.
249 IN  PTR www.sub.lan.
EOF

systemctl enable --now named
firewall-cmd --permanent --add-service=dns
firewall-cmd --permanent --add-port=53/udp
firewall-cmd --permanent --add-port=53/tcp
firewall-cmd --reload
```

### Script Sous domaine(Test)
```bash
#!/bin/bash

# === Paramètres ===
ZONE_FILE="/var/named/test.lan.zone"
REV_FILE="/var/named/0.42.10.rev"

# === Entrée utilisateur ===
read -p "Nom d'utilisateur à ajouter au DNS (ex: alice) : " USERNAME
read -p "Adresse IP à associer (ex: 10.42.0.100) : " USER_IP

# === Extraction de l’octet final pour la zone inverse ===
LAST_OCTET=$(echo "$USER_IP" | awk -F. '{print $4}')

# === Mise à jour du serial dans le fichier de zone directe ===
echo "[+] Mise à jour du serial DNS..."
CURRENT_SERIAL=$(grep -E '[0-9]{10} ; Serial' "$ZONE_FILE" | awk '{print $1}')
NEW_SERIAL=$((CURRENT_SERIAL + 1))
sed -i "s/$CURRENT_SERIAL ; Serial/$NEW_SERIAL ; Serial/" "$ZONE_FILE"

# === Ajout dans test.lan.zone ===
echo "[+] Ajout dans $ZONE_FILE : $USERNAME.test.lan → $USER_IP"
echo "$USERNAME IN A $USER_IP" >> "$ZONE_FILE"

# === Ajout dans zone inverse ===
echo "[+] Ajout dans $REV_FILE : $USER_IP → $USERNAME.test.lan."
echo "$LAST_OCTET IN PTR $USERNAME.test.lan." >> "$REV_FILE"

# === Redémarrer le service DNS ===
echo "[+] Redémarrage de named..."
systemctl restart named

echo "✅ Domaine $USERNAME.test.lan ajouté avec succès."
```


## VSFTPD (FTP)

```bash
sudo dnf install -y vsftpd
sudo dnf install openssl
sudo systemctl enable --now vsftpd

### Certificat SSL
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
-keyout /etc/vsftpd/vsftpd.key \
-out /etc/vsftpd/vsftpd.pem

### config /etc/vsftpd/vsftpd.conf
cat >> /etc/vsftpd/vsftpd.conf <<EOF
anonymous_enable=NO
local_enable=YES
write_enable=YES
ssl_enable=YES
rsa_cert_file=/etc/vsftpd/vsftpd.pem
rsa_private_key_file=/etc/vsftpd/vsftpd.key

# Chroot dans le dossier web utilisateur
chroot_local_user=YES
allow_writeable_chroot=YES
user_sub_token=$USER
local_root=/var/www/$USER

# Sécurité : on interdit les commandes de changement de dossier
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
EOF

### Ouvrir les ports FTP
systemctl restart vsftpd
firewall-cmd --permanent --add-service=ftp
firewall-cmd --permanent --add-port=40000-40100/tcp
firewall-cmd --reload
```
## Serveur Web,  & bases de données

### Installation d’Apache et MariaDB et phpmyadmin

### MariaDB
```

# 1. Importer la clé
sudo rpm --import https://rpm.mariadb.org/RPM-GPG-KEY-MariaDB

# 2. Ajouter le dépôt MariaDB (version 10.11 ici)
sudo tee /etc/yum.repos.d/MariaDB.repo > /dev/null <<EOF
[mariadb]
name = MariaDB
baseurl = https://rpm.mariadb.org/10.11/rhel9-amd64
gpgkey=https://rpm.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

# 3. Mettre à jour les métadonnées
sudo dnf clean all
sudo dnf makecache

# 4. Installer MariaDB Server
sudo dnf install -y MariaDB-server MariaDB-client
sudo systemctl enable --now mariadb
```

3. 🛠️ Modifier le fichier de configuration MariaDB

```bash
sudo nano /etc/my.cnf
```

Ajoute ou modifie la section `[mysqld]` :

```ini
[mysqld] datadir=/var/mysql socket=/var/mysql/mysql.sock
```

```ini
[client] socket=/var/mysql/mysql.sock
```

#### Modifier les permissions du nouveau dossier

```bash
sudo chown -R mysql:mysql /var/mysql
```
#### Pour config mysql
```bash
sudo mysql
```
```SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY 'UnMotDePasseFort123!';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host!='localhost';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EXIT;
```


```bash
sudo dnf install -y httpd
sudo systemctl enable --now httpd
sudo systemctl enable --now mariadb
```

### Installer PHP et les extensions nécessaires

```bash
`sudo dnf install -y php php-mysqli php-mbstring php-json php-xml sudo systemctl restart httpd

```
###  Télécharger phpMyAdmin manuellement
```bash
cd /var/www sudo wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz sudo tar -xzf phpMyAdmin-latest-all-languages.tar.gz sudo mv phpMyAdmin-*-all-languages phpmyadmin sudo rm phpMyAdmin-latest-all-languages.tar.gz
```
### Script pour config
```bash
#!/bin/bash

# === Variables ===
PHPMYADMIN_DIR="/var/www/phpmyadmin"
CONFIG_FILE="$PHPMYADMIN_DIR/config.inc.php"
SOCKET_PATH="/var/mysql/mysql.sock"

# === Vérification du fichier config.inc.php ===
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Le fichier $CONFIG_FILE est introuvable."
  exit 1
fi
# === Ajout ou mise à jour du socket personnalisé ===
if grep -q "\$cfg\['Servers'\]\[\$i\]\['socket'\]" "$CONFIG_FILE"; then
  sed -i "s|\(\$cfg\['Servers'\]\[\$i\]\['socket'\]\s*=\s*\).*|\1'$SOCKET_PATH';|" "$CONFIG_FILE"
else
  sed -i "/\$cfg\['Servers'\]\[\$i\]\['host'\]/a \$cfg['Servers'][\$i]['socket'] = '$SOCKET_PATH';" "$CONFIG_FILE"
fi

# === Vérification finale ===
echo "✅ Configuration de phpMyAdmin mise à jour avec succès."
echo "→ Socket : $SOCKET_PATH"

# Redémarrage Apache
systemctl restart httpd
echo "🔁 Apache redémarré."
```

### Script Site + DB
```bash
#!/bin/bash

# === Entrée utilisateur ===
read -p "Nom du client (username) : " USERNAME

# === Mot de passe base de données (saisi manuellement) ===
read -s -p "Mot de passe SQL pour $USERNAME : " DB_PASS
echo
read -s -p "Confirmer le mot de passe SQL : " DB_PASS_CONFIRM
echo

if [[ "$DB_PASS" != "$DB_PASS_CONFIRM" ]]; then
  echo "❌ Les mots de passe ne correspondent pas." >&2
  exit 1
fi

# === Création du dossier web ===
WEBROOT="/var/www/$USERNAME"
mkdir -p "$WEBROOT"
echo "<h1>Bienvenue sur le site de $USERNAME</h1>" > "$WEBROOT/index.html"
chown -R apache:apache "$WEBROOT"
chmod -R 755 "$WEBROOT"

# === Création du vhost Apache ===
VHOST_CONF="/etc/httpd/conf.d/$USERNAME.conf"
cat > "$VHOST_CONF" <<EOF
<VirtualHost *:80>
    ServerName $USERNAME.test.lan
    DocumentRoot /var/www/$USERNAME

    <Directory /var/www/$USERNAME>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog /var/log/httpd/${USERNAME}_error.log
    CustomLog /var/log/httpd/${USERNAME}_access.log combined
</VirtualHost>
EOF

# Redémarrer Apache
systemctl restart httpd

# === Création base de données + user MariaDB ===
mysql -u root -p <<EOF
CREATE DATABASE $USERNAME;
CREATE USER '$USERNAME'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $USERNAME.* TO '$USERNAME'@'localhost';
FLUSH PRIVILEGES;
EOF

echo ""
echo "✅ Provisioning terminé pour $USERNAME"
echo "Nom de domaine : http://$USERNAME.test.lan"
echo "Dossier web : $WEBROOT"
echo "Base de données : $USERNAME"
echo "Utilisateur SQL : $USERNAME"
echo "Mot de passe SQL : (fourni par l'utilisateur)"

```

### Scripts d’automatisation(ancien, apache only)
```bash
#!/bin/bash

# === Paramètres ===
ZONE_FILE="/var/named/test.lan.zone"
REV_FILE="/var/named/0.42.10.rev"

# === Entrée utilisateur ===
read -p "Nom d'utilisateur à ajouter au DNS: " USERNAME
read -p "Adresse IP à associer: " USER_IP

# === Extraction de l’octet final pour la zone inverse ===
LAST_OCTET=$(echo "$USER_IP" | awk -F. '{print $4}')

# === Mise à jour du serial dans le fichier de zone directe ===
echo "[+] Mise à jour du serial DNS..."
CURRENT_SERIAL=$(grep -E '[0-9]{10} ; Serial' "$ZONE_FILE" | awk '{print $1}')
NEW_SERIAL=$((CURRENT_SERIAL + 1))
sed -i "s/$CURRENT_SERIAL ; Serial/$NEW_SERIAL ; Serial/" "$ZONE_FILE"

# === Ajout dans test.lan.zone ===
echo "[+] Ajout dans $ZONE_FILE : $USERNAME.test.lan → $USER_IP"
echo "$USERNAME IN A $USER_IP" >> "$ZONE_FILE"

# === Ajout dans zone inverse ===
echo "[+] Ajout dans $REV_FILE : $USER_IP → $USERNAME.test.lan."
echo "$LAST_OCTET IN PTR $USERNAME.test.lan." >> "$REV_FILE"

# === Redémarrer le service DNS ===
echo "[+] Redémarrage de named..."
systemctl restart named

echo "Domaine $USERNAME.test.lan ajouté avec succès."

```
#### Création d’utilisateur (`create_user.sh`)

```bash
#!/bin/bash
# Vérifie si exécuté en root
if [[ $EUID -ne 0 ]]; then
  echo "Ce script doit être exécuté en tant que root." >&2
  exit 1
fi

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

# Création de l'utilisateur avec home dir
useradd -m "$USERNAME"

# Affectation du mot de passe
echo "$USERNAME:$PASSWORD" | chpasswd

# (Optionnel) Ajouter à wheel (sudo)
read -p "Ajouter $USERNAME au groupe sudo (wheel) ? [y/N] : " ADD_SUDO
if [[ "$ADD_SUDO" =~ ^[Yy]$ ]]; then
  usermod -aG wheel "$USERNAME"
  echo "$USERNAME ajouté au groupe wheel."
fi

echo "Utilisateur '$USERNAME' créé avec succès."
```

## Config auto (user,samba,dns)
````bash
#!/bin/bash
# === Vérification des droits ===
if [[ $EUID -ne 0 ]]; then
  echo "Ce script doit être exécuté en tant que root." >&2
  exit 1
fi

# === Variables globales DNS ===
ZONE_FILE="/var/named/test.lan.zone"
REV_FILE="/var/named/0.42.10.rev"

# === Demander le nom d'utilisateur ===
read -p "Nom du nouvel utilisateur : " USERNAME

# Vérifie s’il existe déjà
if id "$USERNAME" &>/dev/null; then
  echo "Erreur : l'utilisateur '$USERNAME' existe déjà." >&2
  exit 2
fi

# === Mot de passe ===
read -s -p "Mot de passe pour $USERNAME : " PASSWORD
echo
read -s -p "Confirmer le mot de passe : " PASSWORD_CONFIRM
echo

if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
  echo "Les mots de passe ne correspondent pas." >&2
  exit 3
fi

# === Créer l'utilisateur système avec home personnalisé ===
useradd -m -d /users/$USERNAME "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

# === Option sudo ===
read -p "Ajouter $USERNAME au groupe sudo (wheel) ? [y/N] : " ADD_SUDO
if [[ "$ADD_SUDO" =~ ^[Yy]$ ]]; then
  usermod -aG wheel "$USERNAME"
  echo "$USERNAME ajouté au groupe wheel."
fi

echo "✅ Utilisateur système '$USERNAME' créé avec succès."

# === Créer l'utilisateur Samba ===
smbpasswd -a "$USERNAME"

# === Créer dossier partagé privé Samba ===
SHARE_PATH="/srv/samba/$USERNAME"
mkdir -p "$SHARE_PATH"
chown "$USERNAME:$USERNAME" "$SHARE_PATH"
chmod 700 "$SHARE_PATH"

# === SELinux (si actif) ===
if command -v semanage &>/dev/null; then
  semanage fcontext -a -t samba_share_t "${SHARE_PATH}(/.*)?"
  restorecon -Rv "$SHARE_PATH"
fi

# === Ajouter bloc Samba dans smb.conf ===
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
  echo "✅ Bloc [$USERNAME] ajouté à smb.conf."
fi

# === Ajouter un sous-domaine DNS ===
read -p "Adresse IP à associer à $USERNAME.test.lan (ex: 10.42.0.100) : " USER_IP
LAST_OCTET=$(echo "$USER_IP" | awk -F. '{print $4}')

# Incrémenter le serial
CURRENT_SERIAL=$(grep -E '[0-9]{10} ; Serial' "$ZONE_FILE" | awk '{print $1}')
NEW_SERIAL=$((CURRENT_SERIAL + 1))
sed -i "s/$CURRENT_SERIAL ; Serial/$NEW_SERIAL ; Serial/" "$ZONE_FILE"

# Ajouter enregistrement A
echo "$USERNAME IN A $USER_IP" >> "$ZONE_FILE"

# Ajouter enregistrement PTR
echo "$LAST_OCTET IN PTR $USERNAME.test.lan." >> "$REV_FILE"

# Redémarrer Bind
systemctl restart named

# === Redémarrer Samba ===
systemctl restart smb nmb

echo "🎉 Utilisateur $USERNAME créé avec Samba + DNS : $USERNAME.test.lan → $USER_IP"
````

## Create_user.sh complet (user,samba,ftp,dns,apache,sql,quota)
	A executer avec bash pas sh sinon ça marche pas
```bash
#!/bin/bash

# === Vérification des droits ===
if [[ $EUID -ne 0 ]]; then
  echo "Ce script doit être exécuté en tant que root." >&2
  exit 1
fi

# === Entrée utilisateur ===
read -p "Nom du nouvel utilisateur : " USERNAME
read -p "Nom de domaine principal (ex: test.lan) : " DOMAIN
read -p "IP à associer au sous-domaine $USERNAME.$DOMAIN : " USER_IP

# === Mot de passe UNIX ===
read -s -p "Mot de passe système pour $USERNAME : " PASSWORD
echo
read -s -p "Confirmer le mot de passe : " PASSWORD_CONFIRM
echo
[[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]] && echo "❌ Mots de passe non identiques." && exit 1

# === Mot de passe SQL ===
read -s -p "Mot de passe SQL pour $USERNAME : " DB_PASS
echo
read -s -p "Confirmer le mot de passe SQL : " DB_PASS_CONFIRM
echo
[[ "$DB_PASS" != "$DB_PASS_CONFIRM" ]] && echo "❌ Mots de passe SQL non identiques." && exit 1

# === Mot de passe root SQL ===
read -s -p "Mot de passe root MariaDB : " ROOT_PASS
echo

# === Créer utilisateur Linux avec home personnalisé ===
useradd -m -d /users/$USERNAME "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

# === Dossier web ===
WEBROOT="/var/www/$USERNAME"
[[ ! -d "$WEBROOT" ]] && mkdir -p "$WEBROOT"
echo "<h1>Bienvenue sur le site de $USERNAME</h1>" > "$WEBROOT/index.html"
chown -R "$USERNAME:$USERNAME" "$WEBROOT"
chmod 755 "$WEBROOT"

# === Samba ===
smbpasswd -a "$USERNAME"
if command -v semanage &>/dev/null; then
  semanage fcontext -a -t samba_share_t "$WEBROOT(/.*)?"
  restorecon -Rv "$WEBROOT"
fi
if ! grep -q "^\[$USERNAME\]" /etc/samba/smb.conf; then
cat >> /etc/samba/smb.conf <<EOF

[$USERNAME]
   path = $WEBROOT
   browsable = yes
   writable = yes
   guest ok = no
   read only = no
   valid users = $USERNAME
   force user = $USERNAME
   force group = $USERNAME
EOF
fi
systemctl restart smb nmb

# === Apache vhost ===
VHOST_CONF="/etc/httpd/conf.d/$USERNAME.conf"
cat > "$VHOST_CONF" <<EOF
<VirtualHost *:80>
    ServerName $USERNAME.$DOMAIN
    DocumentRoot $WEBROOT

    <Directory $WEBROOT>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog /var/log/httpd/${USERNAME}_error.log
    CustomLog /var/log/httpd/${USERNAME}_access.log combined
</VirtualHost>
EOF
systemctl restart httpd

# === Base de données MariaDB ===
mysql -u root -p"$ROOT_PASS" <<EOF
CREATE DATABASE $USERNAME;
CREATE USER '$USERNAME'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $USERNAME.* TO '$USERNAME'@'localhost';
FLUSH PRIVILEGES;
EOF

# === DNS zone ===
ZONE_FILE="/var/named/$DOMAIN.zone"
REV_FILE="/var/named/$(echo $USER_IP | awk -F. '{print $3"."$2"."$1}').rev"
LAST_OCTET=$(echo "$USER_IP" | awk -F. '{print $4}')

# Enregistrement A
grep -q "^$USERNAME\s\+IN\s\+A" "$ZONE_FILE" || echo "$USERNAME IN A $USER_IP" >> "$ZONE_FILE"

# Enregistrement PTR
grep -q "^$LAST_OCTET\s\+IN\s\+PTR" "$REV_FILE" || echo "$LAST_OCTET IN PTR $USERNAME.$DOMAIN." >> "$REV_FILE"

# Serial
SERIAL=$(grep -E '[0-9]{10} ; Serial' "$ZONE_FILE" | awk '{print $1}')
NEW_SERIAL=$((SERIAL + 1))
sed -i "s/$SERIAL ; Serial/$NEW_SERIAL ; Serial/" "$ZONE_FILE"
systemctl restart named

# === Résumé ===
echo ""
echo "Utilisateur $USERNAME créé avec succès !"
echo "Domaine : http://$USERNAME.$DOMAIN"
echo "Web    : $WEBROOT"
echo "BDD    : $USERNAME"
echo "SQL    : $USERNAME / (défini)"

```

#### Création de site web (`create_site.sh`)

````bash
#!/usr/bin/env bash
#!/bin/bash

# Récupère le nom d'utilisateur courant (non root, donc pas via sudo)
USER_NAME=$(whoami | tr '[:lower:]' '[:upper:]')

# Chemin racine pour les sites HTML simples
SITE_DIR="/var/www/$USER_NAME"

# Vérification droits
if [[ $EUID -eq 0 ]]; then
  echo "Ce script ne doit PAS être exécuté en tant que root." >&2
  exit 1
fi

# Crée le dossier du site
sudo mkdir -p "$SITE_DIR"

# Crée la page index.html
sudo tee "$SITE_DIR/index.html" > /dev/null <<EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Welcome</title>
</head>
<body>
  <h1>Welcome $USER_NAME</h1>
</body>
</html>
EOF

# Donne les droits à apache
sudo chown -R apache:apache "$SITE_DIR"

# Affiche l'URL
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "Site créé : http://$IP_ADDR/$USER_NAME/"
````


## Monitoring

### Netdata(Serveur à monitorer)

```bash
bash <(curl -SsL https://my-netdata.io/kickstart.sh) --dont-wait

# Ajouter la clé dans stream.conf
sudo nano /etc/netdata/stream.conf
[stream]
  enabled = yes
  destination = 10.42.0.185:19999
  api key = alicecaca
  
sudo nano /etc/netdata/netdata.conf
[global]
  hostname = serveur1
  update every = 5
sudo systemctl restart netdata
```
### Netdata(Serveur de Monitoring)

```bash
bash <(curl -SsL https://my-netdata.io/kickstart.sh) --dont-wait

# Ajouter la clé dans stream.conf
sudo nano /etc/netdata/stream.conf
[alicecaca]
  enabled = yes
  default history = 3600
  default memory mode = ram
  health enabled = auto
  
sudo systemctl restart netdata
sudo firewall-cmd --permanent --add-port=19999/tcp
sudo firewall-cmd --reload

```

## Config NTP

### Serveur NTP
```bash
sudo dnf install -y chrony

# Config NTP
sudo nano /etc/chrony.conf
bindaddress 0.0.0.0
allow 10.42.0.0/16
local stratum 10


# Activer NTP
sudo systemctl enable --now chronyd

#Vérifier que le serveur est actif et ecoute bien
chronyc tracking
ss -ulpn | grep chrony

# Règle firewall
sudo firewall-cmd --add-service=ntp --permanent
sudo firewall-cmd --reload
```

### Client NTP
```bash
sudo dnf install -y chrony

# Recuperer heure via serv NTP
sudo nano /etc/chrony.conf
server 10.42.0.212 iburst

# Lancer NTP
sudo systemctl enable --now chronyd
# Verfier les source NTP
chronyc sources
```

## Sécurisation avancée

### Fail2ban

```bash
dnf install fail2ban -y
systemctl enable --now fail2ban

sudo nano /etc/fail2ban/jail.local

[DEFAULT]
ignoreip = 10.42.0.24 ::1
bantime = 1h
findtime = 10m
maxretry = 3
backend = systemd
banaction = firewallcmd-ipset
action = %(action_mwl)s

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = systemd
maxretry = 3

[apache-auth]
enabled = true
port = http,https
logpath = /var/log/httpd/error_log
maxretry = 3

[vsftpd]
enabled = true
port = ftp
logpath = /var/log/vsftpd.log
maxretry = 3

sudo systemctl restart fail2ban
sudo fail2ban-client status
sudo fail2ban-client status sshd


```

### Rkhunter

```bash
dnf install rkhunter

sudo rkhunter --update
sudo rkhunter --propupd    # À exécuter juste après installation

#Scan régulier
sudo crontab -e
	0 2 * * * /usr/local/bin/rkhunter --check --sk > /var/log/rkhunter.log 2>&1

```

### ClamAV Antivirus
```bash
#!/bin/bash
# Installer ClamAV et les outils nécessaires pour la mise à jour
sudo dnf install -y clamav clamav-update

# Mettre à jour la base de données des signatures ClamAV
sudo freshclam

# Vérifier que ClamAV est correctement installé
clamscan --version

# Écrire le script scan_clamav.sh directement dans le fichier
echo "#!/bin/bash" | sudo tee /home/ec2-user/scripts/scan_clamav.sh > /dev/null
echo "" | sudo tee -a /home/ec2-user/scripts/scan_clamav.sh > /dev/null
echo "# Définir les répertoires à scanner (sauf /backup)" | sudo tee -a /home/ec2-user/scripts/scan_clamav.sh > /dev/null
echo "SCAN_DIR=\"/srv /var/www /var/mysql /users\"" | sudo tee -a /home/ec2-user/scripts/scan_clamav.sh > /dev/null
echo "" | sudo tee -a /home/ec2-user/scripts/scan_clamav.sh > /dev/null
echo "# Exécuter ClamAV pour scanner les répertoires définis" | sudo tee -a /home/ec2-user/scripts/scan_clamav.sh > /dev/null
echo "clamscan -r \$SCAN_DIR --exclude-dir=\"*/.cache\"" | sudo tee -a /home/ec2-user/scripts/scan_clamav.sh > /dev/null

# Rendre le script exécutable
sudo chmod +x /home/ec2-user/scripts/scan_clamav.sh

# Tester le script pour vérifier qu'il fonctionne correctement
sudo /home/ec2-user/scripts/scan_clamav.sh

# Ajouter automatiquement les cron jobs pour exécuter le script à 12h00 et 23h00
(crontab -l 2>/dev/null; echo "0 12 * * * /home/ec2-user/scripts/scan_clamav.sh") | sudo crontab -
(crontab -l 2>/dev/null; echo "0 23 * * * /home/ec2-user/scripts/scan_clamav.sh") | sudo crontab -

# Vérifier les cron jobs ajoutés
sudo crontab -l

```

## Plan sauvegarde

### Structure d'une archive
![[Pasted image 20250513111940.png]]

### Architecture & Fonctionnement
![[Pasted image 20250513112128.png]]

### Script Sauvegarde
```bash
#!/bin/bash

# === Configuration ===
DB_ROOT_PASS="votreMotDePasseSQLroot"
DATE=$(date +"%d-%m-%Y_%H-%M-%S")
TMP_DIR="/backup/tmp_$DATE"
ARCHIVE_DIR="/backup/archives"
ARCHIVE_NAME="backup_${DATE}.tar.gz"
ARCHIVE_PATH="${ARCHIVE_DIR}/${ARCHIVE_NAME}"

# === Création des répertoires ===
mkdir -p "$TMP_DIR/www" "$TMP_DIR/conf" "$TMP_DIR/db" "$TMP_DIR/users"
mkdir -p "$ARCHIVE_DIR"

echo "[+] Sauvegarde des sites web"
rsync -a --delete /var/www/ "$TMP_DIR/www"

echo "[+] Sauvegarde des fichiers de configuration"
cp /etc/samba/smb.conf "$TMP_DIR/conf/"
cp /etc/httpd/conf.d/"*.conf" "$TMP_DIR/conf/" 2>/dev/null
cp /etc/named.conf "$TMP_DIR/conf/"
cp /var/named/*.zone "$TMP_DIR/conf/" 2>/dev/null
cp /var/named/*.rev "$TMP_DIR/conf/" 2>/dev/null

echo "[+] Sauvegarde des bases de données SQL valides"
DB_LIST=$(mysql -u root -p"$DB_ROOT_PASS" -e "SHOW DATABASES;" | grep -Ev "Database|information_schema|performance_schema|mysql|sys")

for DB in $DB_LIST; do
    if [ -d "/var/www/$DB" ]; then
        echo "  - dump de $DB"
        mysqldump -u root -p"$DB_ROOT_PASS" "$DB" > "$TMP_DIR/db/$DB.sql"
    fi
done

echo "[+] Sauvegarde des comptes utilisateurs dans /users"
rsync -a --delete /users/ "$TMP_DIR/users"

echo "[+] Création de l'archive : $ARCHIVE_PATH"
tar -czf "$ARCHIVE_PATH" -C "$TMP_DIR" .

# Nettoyage temporaire
rm -rf "$TMP_DIR"

# Suppression des archives de +7 jours
find "$ARCHIVE_DIR" -type f -name "backup_*.tar.gz" -mtime +7 -exec rm -f {} +

echo "[✓] Archive sauvegardée avec succès : $ARCHIVE_PATH"
```

```bash
0 2 * * * /home/ec2-user/scripts/backup_daily.sh >> /var/log/backup.log 2>&1
```
### Script Recup
```bash
#!/bin/bash

ARCHIVE_DIR="/backup/archives"
RESTORE_ROOT="/restore_tmp"

# === Demander le mot de passe SQL root ===
read -s -p "Mot de passe root MariaDB : " ROOT_PASS
echo

# === Lister les archives disponibles ===
echo "[+] Sauvegardes disponibles dans $ARCHIVE_DIR :"
ARCHIVES=($(ls -1t "$ARCHIVE_DIR"/backup_*.tar.gz 2>/dev/null))

if [ ${#ARCHIVES[@]} -eq 0 ]; then
  echo "❌ Aucune archive trouvée dans $ARCHIVE_DIR."
  exit 1
fi

for i in "${!ARCHIVES[@]}"; do
  fname=$(basename "${ARCHIVES[$i]}")
  echo "$((i + 1)). $fname"
done

# === Choix utilisateur ===
read -p "Entrez le numéro de la sauvegarde à restaurer : " CHOICE
INDEX=$((CHOICE - 1))

if [ -z "${ARCHIVES[$INDEX]}" ]; then
  echo "❌ Numéro invalide."
  exit 2
fi

ARCHIVE="${ARCHIVES[$INDEX]}"
echo "[+] Archive sélectionnée : $ARCHIVE"

# === Extraction dans dossier temporaire ===
TMP_DIR="${RESTORE_ROOT}/extract_$(date +%s)"
mkdir -p "$TMP_DIR"
tar -xzf "$ARCHIVE" -C "$TMP_DIR"

# === Restauration des fichiers web ===
echo "[+] Restauration des fichiers web..."
rsync -a "$TMP_DIR/www/" /var/www/

# === Restauration des comptes utilisateurs ===
echo "[+] Restauration des comptes dans /users..."
rsync -a "$TMP_DIR/users/" /users/

# === Restauration des configurations ===
echo "[+] Restauration des fichiers de configuration..."

# Apache : uniquement les .conf (hors smb/named)
find "$TMP_DIR/conf" -name "*.conf" -not -name "smb.conf" -not -name "named.conf" -exec cp -f {} /etc/httpd/conf.d/ \;

# Samba
if [ -f "$TMP_DIR/conf/smb.conf" ]; then
  cp -f "$TMP_DIR/conf/smb.conf" /etc/samba/smb.conf
fi

# BIND DNS
if [ -f "$TMP_DIR/conf/named.conf" ]; then
  cp -f "$TMP_DIR/conf/named.conf" /etc/named.conf
fi
cp -f "$TMP_DIR/conf/"*.zone /var/named/ 2>/dev/null
cp -f "$TMP_DIR/conf/"*.rev /var/named/ 2>/dev/null

# === Restauration des bases de données ===
echo "[+] Restauration des bases de données..."
for sqlfile in "$TMP_DIR/db/"*.sql; do
    DBNAME=$(basename "$sqlfile" .sql)
    echo "  - base : $DBNAME"
    mysql -u root -p"$ROOT_PASS" -e "DROP DATABASE IF EXISTS \`$DBNAME\`;"
    mysql -u root -p"$ROOT_PASS" -e "CREATE DATABASE \`$DBNAME\`;"
    mysql -u root -p"$ROOT_PASS" "$DBNAME" < "$sqlfile"
done

# Nettoyage temporaire
rm -rf "$TMP_DIR"

# Redémarrage des services
echo "[+] Redémarrage des services..."
systemctl restart named
systemctl restart httpd
systemctl restart smb nmb

echo "[✓] Restauration complète effectuée depuis : $(basename "$ARCHIVE")"

```

## A faire 
fstab noexec sur /svr /backup /users

### forcer DNS 
```bash
ip a
# Créer un fichier /etc/systemd/network/10-ens5.network
sudo nano /etc/systemd/network/10-ens5.network

# Contenu à mettre dedans**
[Match]
Name=ens5

[Network]
DHCP=yes
DNS=10.42.0.249

[DHCP]
UseDNS=false

# Redémarrer les services
sudo systemctl restart systemd-networkd
sudo systemctl restart systemd-resolved

# Vérifier
systemd-resolve --status | grep DNS -A2
```