#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "⚠️ Lütfen bu scripti root (sudo) yetkisiyle çalıştırın."
  exit 1
fi

echo "🗑️ [myf-damx] Kaldırılıyor..."

systemctl stop damx-daemon.service 2>/dev/null || true
systemctl disable damx-daemon.service 2>/dev/null || true
rm -f /usr/lib/systemd/system/damx-daemon.service
systemctl daemon-reload

rm -rf /opt/damx
rm -f /usr/bin/damx

echo "✅ [myf-damx] Başarıyla kaldırıldı."
