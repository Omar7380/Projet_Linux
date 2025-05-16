# Projet Linux 2024-2025

## Présentation du projet
Ce projet a été développé dans le cadre du cours Linux à la Haute École en Hainaut (HEH). Il consiste en un ensemble de scripts bash permettant la mise en place et la gestion d'un serveur Linux complet avec services intégrés.

## Structure du projet
Le projet est organisé de manière modulaire pour faciliter la maintenance et l'évolutivité :

- **📁 raid/** : Scripts de configuration RAID et partitionnement
- **📁 services/** : Scripts d'installation et configuration des services (DNS, Samba, Web, FTP, NTP...)
- **📁 reseau/** : Scripts de configuration réseau
- **📁 utilisateurs/** : Scripts de gestion des utilisateurs
- **📁 securite/** : Scripts de sécurisation du système
- **📁 backup/** : Scripts de sauvegarde et restauration
- **📁 monitoring/** : Scripts d'installation et configuration des outils de surveillance

## Fonctionnalités principales

### 1. Configuration RAID et partitionnement
- Configuration RAID 1 avec mdadm
- Partitionnement automatisé (points de montage : /srv, /var/www, /backup, /var/mysql, /users)
- Configuration des quotas disque

### 2. Services
- **Samba** : Partage de fichiers Windows avec gestion des utilisateurs
- **DNS (BIND)** : Serveur DNS avec zones personnalisables
- **FTP (VSFTPD)** : Accès sécurisé aux fichiers via FTP
- **Web (Apache)** : Serveur web avec support vhosts et PHP
- **MariaDB** : Gestion des bases de données
- **NTP (Chrony)** : Synchronisation du temps

### 3. Sécurité
- Configuration SSH sécurisée
- Pare-feu avec firewalld
- SELinux en mode enforcing
- Fail2ban pour la protection contre les attaques par force brute
- ClamAV pour la détection de virus
- Rkhunter pour la détection de rootkits

### 4. Gestion des utilisateurs
- Création d'utilisateurs avec intégration complète (système, Samba, FTP, DNS, web, base de données)
- Quotas disque automatiques

### 5. Sauvegarde et restauration
- Sauvegarde quotidienne automatisée
- Sauvegarde des configurations, fichiers et bases de données
- Système de restauration complet

### 6. Monitoring
- Netdata pour la surveillance en temps réel
- Configuration client/serveur pour surveillance centralisée

## Prérequis
- Amazon Linux 2 / RHEL-compatible OS
- Deux disques pour le RAID 1
- Accès root

## Installation

1. Cloner le dépôt :
```bash
git clone https://github.com/votre-utilisateur/projet-linux.git
cd projet-linux
```

2. Configuration initiale du système :
```bash
sudo bash raid/configure_raid_partitions.sh
sudo bash raid/configure_quota.sh
```

3. Installation des services de base :
```bash
sudo bash services/install_services.sh
```

4. Configuration de la sécurité :
```bash
sudo bash securite/ssh_firewall_config.sh
sudo bash securite/configure_selinux.sh
sudo bash securite/install_configure_fail2ban.sh
sudo bash securite/clamav.sh
```

5. Mise en place des sauvegardes :
```bash
sudo bash backup/backup_daily.sh <mot-de-passe-root-mariadb>
```

## Auteur
Ce projet a été développé pour la Haute École en Hainaut dans le cadre du cours Linux.

