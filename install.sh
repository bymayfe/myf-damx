#!/usr/bin/env bash
set -e

# ==============================================================================
#  myf-damx - Interactive Modular Installer (English)
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "⚠️ Error: Please run this installation script as root (sudo)."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPT_DIR="/opt/damx"
AUTO_YES=false

if [[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]]; then
  AUTO_YES=true
fi

ask_user() {
  local prompt="$1"
  local default="$2"
  if [ "$AUTO_YES" = true ]; then
    return 0
  fi

  while true; do
    read -rp "$prompt [$default]: " response
    response="${response:-$default}"
    case "$response" in
      [Yy]* ) return 0 ;;
      [Nn]* ) return 1 ;;
      * ) echo "Please answer y (yes) or n (no)." ;;
    esac
  done
}

echo "=========================================================="
echo "  🎮 myf-damx - Div Acer Manager Max Modular Installer"
echo "  Author: @bymayfe | License: GPL-3.0"
echo "=========================================================="
echo ""

# 1. Ask for Daemon & Smart Fan Worker
INSTALL_DAEMON=true
if ! ask_user "👉 1. Install DAMX Background Daemon & 5-Mode AI Smart Fan Engine?" "Y"; then
  INSTALL_DAEMON=false
fi

# 2. Ask for Avalonia C# GUI
INSTALL_GUI=true
if ! ask_user "👉 2. Build and install DivAcerManagerMax GUI (.NET 9 Avalonia)?" "Y"; then
  INSTALL_GUI=false
fi

# 3. Ask for HWDB Keymaps
INSTALL_HWDB=true
if ! ask_user "👉 3. Install Acer Nitro 16 Hardware Keymaps (Fn+F11/F12 brightness & Nitro key)?" "Y"; then
  INSTALL_HWDB=false
fi

# 4. Ask for Wayland/KDE Touchpad script
INSTALL_TOUCHPAD=true
if ! ask_user "👉 4. Install Wayland/KDE Plasma 6 Touchpad toggle integration?" "Y"; then
  INSTALL_TOUCHPAD=false
fi

echo ""
echo "🚀 Proceeding with installation..."
echo "----------------------------------------------------------"

# Target directories
mkdir -p "${OPT_DIR}/daemon"
mkdir -p "${OPT_DIR}/gui"

# 1. Daemon installation
if [ "$INSTALL_DAEMON" = true ]; then
  echo "📦 [1/4] Installing DAMX Daemon & Keyboard Monitor..."
  cp -fv "${SCRIPT_DIR}/DAMM-Daemon/DAMX-Daemon.py" "${OPT_DIR}/daemon/"
  cp -fv "${SCRIPT_DIR}/DAMM-Daemon/KeyboardMonitor.py" "${OPT_DIR}/daemon/"
  chmod +x "${OPT_DIR}/daemon/DAMX-Daemon.py"
  chmod +x "${OPT_DIR}/daemon/KeyboardMonitor.py"

  echo "⚙️ Configuring systemd service..."
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
  echo "✓ DAMX Daemon service active and enabled on boot."
fi

# 2. GUI compilation and deployment
if [ "$INSTALL_GUI" = true ]; then
  echo "🔨 [2/4] Building DivAcerManagerMax GUI with .NET 9..."
  cd "${SCRIPT_DIR}/DivAcerManagerMax"
  dotnet publish -c Release -r linux-x64 --self-contained false
  cp -rfv bin/Release/net9.0/linux-x64/publish/* "${OPT_DIR}/gui/"
  chmod +x "${OPT_DIR}/gui/DivAcerManagerMax"
  ln -sf "${OPT_DIR}/gui/DivAcerManagerMax" /usr/bin/damx
  echo "✓ GUI binary deployed. Command 'damx' created in /usr/bin."
fi

# 3. HWDB Keymaps
if [ "$INSTALL_HWDB" = true ]; then
  echo "⌨️ [3/4] Installing HWDB keymaps..."
  if [ -f "${SCRIPT_DIR}/configs/90-acer-nitro-an16.hwdb" ]; then
    cp -fv "${SCRIPT_DIR}/configs/90-acer-nitro-an16.hwdb" /etc/udev/hwdb.d/
    systemd-hwdb update || true
    udevadm trigger /dev/input/event* 2>/dev/null || true
    echo "✓ HWDB keymap installed (Fn+F11/F12 and NitroSense key active)."
  fi
fi

# 4. Touchpad Toggle Script
if [ "$INSTALL_TOUCHPAD" = true ]; then
  echo "🖱️ [4/4] Installing Touchpad toggle script..."
  if [ -f "${SCRIPT_DIR}/scripts/toggle-touchpad.sh" ]; then
    cp -fv "${SCRIPT_DIR}/scripts/toggle-touchpad.sh" /usr/local/bin/toggle-touchpad.sh
    chmod +x /usr/local/bin/toggle-touchpad.sh
    echo "✓ Touchpad toggle script installed to /usr/local/bin/toggle-touchpad.sh."
  fi
fi

echo "----------------------------------------------------------"
echo "✅ [myf-damx] Installation successfully completed!"
echo "📌 To launch the GUI: damx"
echo "📌 Service status: systemctl status damx-daemon.service"
