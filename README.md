# server-infra

Infrastructure as Code pour mon VPS personnel — recrée l'environnement complet en une commande.

## Stack

- **Ansible** — provisioning et déploiement
- **Docker + Docker Compose** — conteneurisation de tous les services
- **Caddy** — reverse proxy avec TLS automatique (Let's Encrypt)
- **Ansible Vault** — chiffrement des secrets
- **Tailscale** — VPN mesh pour accès privé

## Architecture

```
Internet
    │
    ▼
 Caddy :443
    │  (réseau Docker proxy)
    ├── lennyblk.dev          → portfolio-app:4173
    ├── cinenode.lennyblk.dev → cinenode-app:3636
    ├── jellyfin.lennyblk.dev → jellyfin:8096
    ├── suwayomi.lennyblk.dev → suwayomi:4567
    ├── seanime.lennyblk.dev  → seanime:43211
    ├── docmost.lennyblk.dev  → docmost:3000
    ├── portainer.lennyblk.dev→ portainer:9000
    └── n8n.lennyblk.dev      → n8n:5678
```

Tous les services partagent le réseau Docker `proxy`. Aucun port n'est exposé directement sur l'hôte sauf le 80/443 de Caddy.

## Services déployés

| Service | Description | Domaine |
|---------|-------------|---------|
| Jellyfin | Serveur média | jellyfin.lennyblk.dev |
| Suwayomi | Lecteur manga | suwayomi.lennyblk.dev |
| FlareSolverr | Bypass Cloudflare pour Suwayomi | interne |
| Seanime | Gestionnaire anime | seanime.lennyblk.dev |
| Docmost | Wiki / prise de notes | docmost.lennyblk.dev |
| Portainer | Interface Docker | portainer.lennyblk.dev |
| n8n | Automatisation de workflows | n8n.lennyblk.dev |
| Caddy | Reverse proxy | — |

## Prérequis

- Python 3.x et pip
- Accès SSH au VPS (clé Ed25519)
- Ansible installé en local

```bash
pip install ansible
ansible-galaxy collection install community.docker
```

## Structure du repo

```
server-infra/
├── inventory.ini              # Déclaration du VPS
├── playbook.yml               # Point d'entrée Ansible
├── group_vars/
│   └── all/
│       └── vault.yml          # Secrets chiffrés (Ansible Vault)
└── roles/
    ├── base/                  # Paquets système, Docker, UFW
    ├── caddy/                 # Config reverse proxy
    ├── services/              # Déploiement des apps Docker
    └── backup/                # Script de backup + cron (à venir)
```

## Utilisation

### Premier déploiement

```bash
git clone git@github.com:lennyblk/server-infra.git
cd server-infra

# Tester la connexion au VPS
ansible vps -i inventory.ini -m ping

# Déployer l'infrastructure complète
ansible-playbook -i inventory.ini playbook.yml --ask-vault-pass
```

### Ajouter un nouveau service

1. Créer le dossier `roles/services/files/<nom-service>/`
2. Y ajouter un `docker-compose.yml` avec le réseau `proxy` en external
3. Ajouter le service dans `roles/services/tasks/main.yml`
4. Ajouter une entrée dans `roles/caddy/templates/Caddyfile.j2`
5. Relancer le playbook

### Modifier un service existant

```bash
# Éditer le fichier concerné, puis :
ansible-playbook -i inventory.ini playbook.yml --ask-vault-pass
```

Ansible détecte automatiquement ce qui a changé et n'applique que le diff.

### Éditer les secrets

```bash
ansible-vault edit group_vars/all/vault.yml
```

## Sécurité

- Les secrets (mots de passe, tokens) sont chiffrés via Ansible Vault — jamais en clair dans le repo
- UFW actif : seuls les ports 22, 80 et 443 sont ouverts
- fail2ban installé
- Aucun service n'expose de port directement, tout passe par Caddy

## Backup

Backup automatique chaque dimanche à 3h vers Google Drive via rclone.

Éléments sauvegardés :
- `/root/compose/` — tous les compose files
- `/opt/suwayomi/`, `/opt/seanime/` — données des apps
- Volumes Docker : `docmost`, `n8n_data`, `portainer_data`, `portfolio_caddy_data`
