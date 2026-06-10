#!/usr/bin/env bash
set -e

# Setup .env kalau belum ada
if [ ! -f .env ]; then
    cp .env.example .env 2>/dev/null || touch .env
fi

# Generate APP_KEY (timeout 10 detik biar gak ngehang)
timeout 10 php artisan key:generate --force --no-interaction 2>/dev/null || true

# Migrasi (timeout 30 detik)
timeout 30 php artisan migrate --force 2>/dev/null || true

# Start Apache
exec apache2-foreground
