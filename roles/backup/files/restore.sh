#!/bin/bash
# =============================================================================
# RESTORE SCRIPT — Lenny's Server
# Restaure tout depuis Google Drive via rclone
# Usage : ./restore.sh
# =============================================================================
set -euo pipefail

DATE=$(date +%Y%m%d_%H%M)
LOG="/root/restore.log"
REMOTE="googledrive:/backups"

log() {
  echo "[$DATE] $1" | tee -a "$LOG"
}

log "========================================"
log "Démarrage restauration serveur"
log "========================================"

# --- Vérifications préalables ---
if ! command -v rclone &>/dev/null; then
  log "ERREUR: rclone n'est pas installé"
  exit 1
fi

if ! command -v docker &>/dev/null; then
  log "ERREUR: docker n'est pas installé"
  exit 1
fi

# --- Arrêt de tous les containers ---
log "Arrêt des containers..."
docker stop suwayomi seanime flaresolverr jellyfin docmost n8n portainer 2>/dev/null || true

# --- Restauration compose files ---
log "Restauration compose files..."
rclone sync "$REMOTE/compose/" /root/compose/ \
  --log-file="$LOG" --log-level INFO

# --- Restauration portfolio ---
log "Restauration portfolio..."
rclone sync "$REMOTE/portfolio/" /root/portfolio/ \
  --exclude "node_modules/**" \
  --exclude "dist/**" \
  --log-file="$LOG" --log-level INFO

# --- Restauration données apps ---
log "Restauration suwayomi..."
mkdir -p /opt/suwayomi
rclone sync "$REMOTE/opt/suwayomi/" /opt/suwayomi/ \
  --log-file="$LOG" --log-level INFO

log "Restauration seanime..."
mkdir -p /opt/seanime
rclone sync "$REMOTE/opt/seanime/" /opt/seanime/ \
  --log-file="$LOG" --log-level INFO

# --- Restauration volumes Docker ---
log "Restauration volumes Docker..."
VOLUMES=(
  "docmost_db_data"
  "docmost_docmost"
  "docmost_redis_data"
  "n8n_data"
  "portainer_data"
  "portfolio_caddy_data"
  "portfolio_caddy_config"
)

for VOLUME in "${VOLUMES[@]}"; do
  VOLUME_PATH="/var/lib/docker/volumes/$VOLUME/_data"
  log "Restauration volume: $VOLUME"
  mkdir -p "$VOLUME_PATH"
  rclone sync "$REMOTE/volumes/$VOLUME/" "$VOLUME_PATH/" \
    --log-file="$LOG" --log-level INFO
done

# --- Redémarrage des containers ---
log "Redémarrage des containers..."
docker start suwayomi seanime flaresolverr jellyfin docmost n8n portainer 2>/dev/null || true

log "========================================"
log "Restauration terminée avec succès"
log "========================================"
log "Pense à relancer le playbook Ansible pour vérifier l'état de l'infra"
log "ansible-playbook -i inventory.ini playbook.yml --ask-vault-pass"
log "========================================"
