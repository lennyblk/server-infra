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
    ├── yourdomain.com                      → portfolio
    ├── suwayomi.yourdomain.com             → suwayomi:4567
    ├── seanime.yourdomain.com              → seanime:43211
    ├── docmost.yourdomain.com              → docmost:3000
    ├── portainer.yourdomain.com            → portainer:9000
    ├── n8n.yourdomain.com                  → n8n:5678
    ├── sonarr.yourdomain.com               → sonarr:8989
    ├── prowlarr.yourdomain.com             → prowlarr:9696
    ├── qbittorrent.yourdomain.com          → qbittorrent:8080
    ├── dashdot.yourdomain.com              → dashdot:3001
    ├── radarr.yourdomain.com               → radarr:7878
    ├── jellyfin.yourdomain.com             → jellyfin:8096
    ├── bazarr.yourdomain.com               → bazarr:6767
    ├── yastream.yourdomain.com             → yastream:55913
    └── stremio.yourdomain.com              → stremio:8080
```

All services share a single Docker `proxy` network. No ports are exposed directly on the host except Caddy's 80/443.

## Services

| Service | URL | Description |
|---------|-----|-------------|
| Portfolio | yourdomain.com | Personal website |
| Suwayomi | suwayomi.yourdomain.com | Manga reader |
| FlareSolverr | internal | Cloudflare bypass for Suwayomi |
| Seanime | seanime.yourdomain.com | Anime manager |
| Docmost | docmost.yourdomain.com | Wiki / note-taking |
| Portainer | portainer.yourdomain.com | Docker UI |
| n8n | n8n.yourdomain.com | Workflow automation |
| Sonarr | sonarr.yourdomain.com | TV show manager |
| Prowlarr | prowlarr.yourdomain.com | Indexer manager |
| qBittorrent | qbittorrent.yourdomain.com | Torrent client |
| Dashdot | dashdot.yourdomain.com | Server metrics dashboard |
| Radarr | radarr.yourdomain.com | Movie manager |
| Jellyfin | jellyfin.yourdomain.com | Media server (Netflix-like) |
| Bazarr | bazarr.yourdomain.com | Automatic subtitles downloader |
| Yastream | yastream.yourdomain.com | Stremio addon — kdrama/asian drama streaming (no download) |
| Stremio | stremio.yourdomain.com | Self-hosted Stremio web client + streaming server |

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
3. Add the service to `roles/services/tasks/main.yml` (3 loops: folders, copy, start)
4. Add a route in `roles/caddy/templates/Caddyfile.j2`
5. Push to main — GitHub Actions deploys automatically

### Edit secrets

```bash
# On Linux/WSL only (Windows locale issue)
ansible-vault edit group_vars/all/vault.yml
```

## Fork & Deploy on your own server

1. **Update `inventory.ini`** with your server's IP or domain
2. **Create your own secrets** — delete `group_vars/all/vault.yml` and create a new one:
   ```bash
   ansible-vault create group_vars/all/vault.yml
   ```
3. **Update the Caddyfile** — replace domain names in `roles/caddy/templates/Caddyfile.j2`
4. **Run the playbook**:
   ```bash
   ansible-playbook -i inventory.ini playbook.yml --ask-vault-pass
   ```

For GitHub Actions, add these repository secrets:

| Secret | Value |
|--------|-------|
| `SSH_PRIVATE_KEY` | Content of your `~/.ssh/id_ed25519` |
| `VAULT_PASSWORD` | Your Ansible Vault password |
| `VPS_HOST` | Your server domain or IP |

## Security

- Secrets encrypted with Ansible Vault — never stored in plaintext
- UFW enabled: only ports 22, 80 and 443 open
- fail2ban installed
- No service exposes ports directly — all traffic goes through Caddy

## Backup

Automatic weekly backup to Google Drive via rclone.

Backed up:
- All compose files
- App data directories
- Docker named volumes
