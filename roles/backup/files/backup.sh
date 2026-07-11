#!/bin/bash
# =============================================================================
# BACKUP SCRIPT — Lenny's Server
# Sauvegarde tout vers Google Drive via rclone
# Usage : ./backup.sh
# =============================================================================

set -euo pipefail

DATE=$(date +%Y%m%d_%H%M)
LOG="/root/backup.log"
REMOTE="googledrive:/backups"

log() {
    echo "[$DATE] $1" | tee -a "$LOG"
}

log "========================================"
log "Démarrage backup serveur"
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

# --- Arrêt propre des containers ---
log "Arrêt des containers..."
docker stop suwayomi seanime flaresolverr sonarr radarr prowlarr qbittorrent jellyfin bazarr uptime-kuma dashdot 2>/dev/null || true

# --- Backup fichiers de config ---
log "Backup compose files..."
rclone sync /root/compose/ "$REMOTE/compose/" \
    --log-file="$LOG" --log-level INFO

log "Backup portfolio..."
rclone sync /root/portfolio/ "$REMOTE/portfolio/" \
    --exclude "node_modules/**" \
    --exclude "dist/**" \
    --log-file="$LOG" --log-level INFO

# --- Backup données apps ---
OPT_SERVICES=(
    suwayomi
    seanime
    sonarr
    radarr
    prowlarr
    qbittorrent
    jellyfin
    bazarr
    uptime-kuma
    dashdot
)

for SERVICE in "${OPT_SERVICES[@]}"; do
    if [ -d "/opt/$SERVICE" ]; then
        log "Backup $SERVICE..."
        rclone sync "/opt/$SERVICE/" "$REMOTE/opt/$SERVICE/" \
            --log-file="$LOG" --log-level INFO
    else
        log "WARN: /opt/$SERVICE introuvable, ignoré"
    fi
done

# --- Backup volumes Docker ---
log "Backup volumes Docker..."

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
    if [ -d "$VOLUME_PATH" ]; then
        log "Backup volume: $VOLUME"
        rclone sync "$VOLUME_PATH" "$REMOTE/volumes/$VOLUME/" \
            --log-file="$LOG" --log-level INFO
    else
        log "WARN: Volume $VOLUME introuvable, ignoré"
    fi
done

# --- Redémarrage des containers ---
log "Redémarrage des containers..."
docker start suwayomi seanime flaresolverr sonarr radarr prowlarr qbittorrent jellyfin bazarr uptime-kuma dashdot 2>/dev/null || true

log "========================================"
log "Backup terminé avec succès"
log "========================================"
