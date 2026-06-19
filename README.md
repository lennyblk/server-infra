# server-infra

Infrastructure as Code for my personal VPS — rebuilds the entire environment with a single command.

## Stack

- **Ansible** — provisioning and deployment
- **Docker + Docker Compose** — containerization of all services
- **Caddy** — reverse proxy with automatic TLS (Let's Encrypt)
- **Ansible Vault** — secrets encryption
- **GitHub Actions** — automatic deployment on push
- **Tailscale** — mesh VPN for private access

## Architecture

```
Internet
    │
    ▼
 Caddy :443
    │  (Docker proxy network)
    ├── lennyblk.dev           → portfolio-app:4173
    ├── cinenode.lennyblk.dev  → cinenode-app:3636
    ├── jellyfin.lennyblk.dev  → jellyfin:8096
    ├── suwayomi.lennyblk.dev  → suwayomi:4567
    ├── seanime.lennyblk.dev   → seanime:43211
    ├── docmost.lennyblk.dev   → docmost:3000
    ├── portainer.lennyblk.dev → portainer:9000
    └── n8n.lennyblk.dev       → n8n:5678
```

All services share a single Docker `proxy` network. No ports are exposed directly on the host except Caddy's 80/443.

## Services

| Service | Description | Domain |
|---------|-------------|--------|
| Jellyfin | Media server | jellyfin.lennyblk.dev |
| Suwayomi | Manga reader | suwayomi.lennyblk.dev |
| FlareSolverr | Cloudflare bypass for Suwayomi | internal |
| Seanime | Anime manager | seanime.lennyblk.dev |
| Docmost | Wiki / note-taking | docmost.lennyblk.dev |
| Portainer | Docker UI | portainer.lennyblk.dev |
| n8n | Workflow automation | n8n.lennyblk.dev |
| Caddy | Reverse proxy | — |

## Repository structure

```
server-infra/
├── .github/workflows/
│   └── deploy.yml             # CI/CD pipeline
├── inventory.ini              # Server declaration
├── playbook.yml               # Ansible entry point
├── group_vars/
│   └── all/
│       └── vault.yml          # Encrypted secrets (Ansible Vault)
└── roles/
    ├── base/                  # System packages, Docker, UFW
    ├── caddy/                 # Reverse proxy config
    ├── services/              # Docker apps deployment
    └── backup/                # Backup script and cron job
```

## Prerequisites

- Python 3.x and pip
- SSH access to the VPS (Ed25519 key)
- Ansible installed locally

```bash
pip install ansible
ansible-galaxy collection install community.docker
```

## Usage

### First deployment

```bash
git clone git@github.com:lennyblk/server-infra.git
cd server-infra

# Test connection to the VPS
ansible vps -i inventory.ini -m ping

# Deploy the full infrastructure
ansible-playbook -i inventory.ini playbook.yml --ask-vault-pass
```

### Add a new service

1. Create `roles/services/files/<service-name>/`
2. Add a `docker-compose.yml` using the `proxy` network as external
3. Add the service to `roles/services/tasks/main.yml`
4. Add a route in `roles/caddy/templates/Caddyfile.j2`
5. Re-run the playbook

### Edit secrets

```bash
ansible-vault edit group_vars/all/vault.yml
```

## Fork & Deploy on your own server

This repo is designed to be reusable. To deploy on your own VPS:

1. **Update `inventory.ini`** with your server's IP or domain
2. **Create your own secrets** — delete `group_vars/all/vault.yml` and create a new one:
   ```bash
   ansible-vault create group_vars/all/vault.yml
   ```
   Fill it with your own values (passwords, rclone tokens, etc.)
3. **Update the Caddyfile** — replace `lennyblk.dev` with your own domain in `roles/caddy/templates/Caddyfile.j2`
4. **Run the playbook**:
   ```bash
   ansible-playbook -i inventory.ini playbook.yml --ask-vault-pass
   ```

For GitHub Actions, add these 3 repository secrets:

| Secret | Value |
|--------|-------|
| `SSH_PRIVATE_KEY` | Content of your `~/.ssh/id_ed25519` |
| `VAULT_PASSWORD` | Your Ansible Vault password |
| `VPS_HOST` | Your server domain or IP |

## Security

- Secrets are encrypted with Ansible Vault — never stored in plaintext in the repo
- UFW enabled: only ports 22, 80 and 443 are open
- fail2ban installed
- No service exposes ports directly — all traffic goes through Caddy

## Backup

Automatic backup every Sunday at 3am to Google Drive via rclone.

Backed up:
- `/root/compose/` — all compose files
- `/opt/suwayomi/`, `/opt/seanime/` — app data
- Docker volumes: `docmost`, `n8n_data`, `portainer_data`, `portfolio_caddy_data`
