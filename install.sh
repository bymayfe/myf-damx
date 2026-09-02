#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "⚠️ Lütfen bu scripti root (sudo) yetkisiyle çalıştırın."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPT_DIR="/opt/damx"

echo "🚀 [myf-damx] Kurulum başlatılıyor..."

# 1. Dizinleri oluştur
mkdir -p "${OPT_DIR}/daemon"
mkdir -p "${OPT_DIR}/gui"

# 2. Daemon dosyalarını kopyala
echo "📦 Daemon dosyaları yükleniyor..."
cp -fv "${SCRIPT_DIR}/DAMM-Daemon/DAMX-Daemon.py" "${OPT_DIR}/daemon/"
cp -fv "${SCRIPT_DIR}/DAMM-Daemon/KeyboardMonitor.py" "${OPT_DIR}/daemon/"

# 3. Systemd servisini kur
echo "⚙️ Systemd servisi yapılandırılıyor..."
cat << 'EOF' > /usr/lib/systemd/system/damx-daemon.service
[Unit]
Description=DAMX Daemon for Acer laptops
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/damx/daemon/DAMX-Daemon.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable damx-daemon.service
systemctl restart damx-daemon.service

# 4. GUI'yi derle ve yükle
echo "🔨 GUI derleniyor (.NET 9)..."
cd "${SCRIPT_DIR}/DivAcerManagerMax"
dotnet publish -c Release -r linux-x64 --self-contained false
cp -rfv bin/Release/net9.0/linux-x64/publish/* "${OPT_DIR}/gui/"
chmod +x "${OPT_DIR}/gui/DivAcerManagerMax"

# 5. /usr/bin kısayolu ve desktop girişi
ln -sf "${OPT_DIR}/gui/DivAcerManagerMax" /usr/bin/damx

echo "✅ [myf-damx] Kurulum başarıyla tamamlandı!"
echo "📌 Çalıştırmak için: damx"
