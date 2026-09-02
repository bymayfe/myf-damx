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

# 5. HWDB Tuş Eşlemesi (Fn+F11, Fn+F12, NitroSense tuşu)
if [ -f "${SCRIPT_DIR}/configs/90-acer-nitro-an16.hwdb" ]; then
    echo "⌨️ Klavye HWDB tuş eşlemeleri kuruluyor..."
    cp -fv "${SCRIPT_DIR}/configs/90-acer-nitro-an16.hwdb" /etc/udev/hwdb.d/
    systemd-hwdb update || true
    udevadm trigger /dev/input/event* 2>/dev/null || true
fi

# 6. Touchpad Toggle Betiği
if [ -f "${SCRIPT_DIR}/scripts/toggle-touchpad.sh" ]; then
    echo "🖱️ Touchpad geçiş betiği kuruluyor..."
    cp -fv "${SCRIPT_DIR}/scripts/toggle-touchpad.sh" /usr/local/bin/toggle-touchpad.sh
    chmod +x /usr/local/bin/toggle-touchpad.sh
fi

# 7. /usr/bin kısayolu ve desktop girişi
ln -sf "${OPT_DIR}/gui/DivAcerManagerMax" /usr/bin/damx

echo "✅ [myf-damx] Kurulum başarıyla tamamlandı!"
echo "📌 Çalıştırmak için: damx"
