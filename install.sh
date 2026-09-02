#!/usr/bin/env bash
set -e

# ==============================================================================
#  myf-damx - Interactive Modular Installer with Detailed Explanations
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

echo "=================================================================="
echo "  🎮 myf-damx - Div Acer Manager Max Modular Installer"
echo "  Author: @bymayfe | License: GPL-3.0"
echo "=================================================================="
echo ""

# ------------------------------------------------------------------------------
# 0. Kernel Driver Check & Auto-Install
# ------------------------------------------------------------------------------
echo "🔍 Checking for required kernel driver..."
if lsmod | grep -q "linuwu_sense" || [ -d "/sys/module/linuwu_sense" ]; then
  echo "✓ linuwu_sense kernel driver is detected and active."
  echo ""
else
  echo "⚠️  Warning: 'linuwu_sense' kernel driver was not detected on your system!"
  echo "   ℹ️  What this means:"
  echo "       • DAMX relies on the 'linuwu_sense' driver (provided by myf-linuwu) to"
  echo "         communicate with the laptop's Embedded Controller (EC) and ACPI WMI."
  echo "       • Without this driver, fan speed control and thermal profiles will not function."
  echo ""
  if ask_user "👉 Automatically download, build and install 'myf-linuwu' kernel driver now?" "Y"; then
    echo "📦 Cloning and installing myf-linuwu kernel driver..."
    TMP_LINUWU_DIR="$(mktemp -d)"
    if git clone https://github.com/bymayfe/myf-linuwu.git "$TMP_LINUWU_DIR"; then
      cd "$TMP_LINUWU_DIR"
      chmod +x install.sh
      ./install.sh -y
      cd "$SCRIPT_DIR"
      rm -rf "$TMP_LINUWU_DIR"
      echo "✓ myf-linuwu kernel driver installed and activated successfully!"
    else
      echo "❌ Failed to clone myf-linuwu. Please install it manually from https://github.com/bymayfe/myf-linuwu"
    fi
  else
    echo "ℹ️  Continuing DAMX setup without driver. You can install myf-linuwu later."
  fi
  echo ""
fi

# ------------------------------------------------------------------------------
# 1. Daemon & Smart Fan
# ------------------------------------------------------------------------------
echo "📌 [Component 1/4] Background Daemon & AI Smart Fan Engine"
echo "   ℹ️  What this does:"
echo "       • Enables the full 5-Mode thermal cycle (Quiet ➔ Balanced ➔ AI Smart ➔ Perf ➔ Turbo)."
echo "       • FIXES the fan-fighting / hunting bug using intelligent temperature hysteresis."
echo "       • Runs the dynamic 'Ice Curve' (<55°C whisper silent, 55-68°C 45%, 68-78°C 65%, >85°C 100%)."
echo "       • Triggers a 2-pulse Electric Blue keyboard flash and restores your custom RGB colors."
echo ""
INSTALL_DAEMON=true
if ! ask_user "👉 Install DAMX Background Daemon & AI Smart Fan Engine?" "Y"; then
  INSTALL_DAEMON=false
fi
echo ""

# ------------------------------------------------------------------------------
# 2. Avalonia C# GUI
# ------------------------------------------------------------------------------
echo "📌 [Component 2/4] DivAcerManagerMax GUI (.NET 9 Avalonia)"
echo "   ℹ️  What this does:"
echo "       • Modern desktop GUI with real-time temperature, fan RPM, and sensor monitoring."
echo "       • Adds the new 'AI Smart' button (Neon Cyan / Brain icon) to the UI."
echo "       • FIXES UI desync: Physical button presses update the GUI radio buttons LIVE in real-time."
echo "       • Creates the '/usr/bin/damx' system command shortcut."
echo ""
INSTALL_GUI=true
if ! ask_user "👉 Build and install DivAcerManagerMax GUI (.NET 9)?" "Y"; then
  INSTALL_GUI=false
fi
echo ""

# ------------------------------------------------------------------------------
# 3. HWDB Keymaps
# ------------------------------------------------------------------------------
echo "📌 [Component 3/4] Hardware Keyboard Keymaps (udev hwdb)"
echo "   ℹ️  What this does:"
echo "       • FIXES non-working Fn+F11 (keyboard brightness down) and Fn+F12 (brightness up)."
echo "       • Maps the dedicated NitroSense key (scancode 0xf5) to prog1 for instant DAMX launching."
echo "       • Applies udev rules for Acer Nitro 16 (AN16-42 & compatible models)."
echo ""
INSTALL_HWDB=true
if ! ask_user "👉 Install Acer Nitro 16 Hardware Keymaps (Fn+F11/F12 & Nitro key)?" "Y"; then
  INSTALL_HWDB=false
fi
echo ""

# ------------------------------------------------------------------------------
# 4. Wayland/KDE Touchpad Integration
# ------------------------------------------------------------------------------
echo "📌 [Component 4/4] Wayland & KDE Plasma 6 Touchpad Integration"
echo "   ℹ️  What this does:"
echo "       • FIXES touchpad toggle failures under Wayland and KDE Plasma 6."
echo "       • Simultaneously syncs kcminputrc and KWin D-Bus for instant, persistent disable/enable."
echo "       • Displays an on-screen desktop OSD notification indicating Touchpad Active / Disabled."
echo ""
INSTALL_TOUCHPAD=true
if ! ask_user "👉 Install Wayland & KDE Plasma 6 Touchpad toggle integration?" "Y"; then
  INSTALL_TOUCHPAD=false
fi
echo ""

echo "=================================================================="
echo "🚀 Proceeding with installation..."
echo "=================================================================="

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
  echo "✓ DAMX Daemon service is active and enabled on boot."
fi

# 2. GUI compilation and deployment
if [ "$INSTALL_GUI" = true ]; then
  echo "🔨 [2/4] Building DivAcerManagerMax GUI with .NET 9..."
  cd "${SCRIPT_DIR}/DivAcerManagerMax"
  dotnet publish -c Release -r linux-x64 --self-contained false
  cp -rfv bin/Release/net9.0/linux-x64/publish/* "${OPT_DIR}/gui/"
  chmod +x "${OPT_DIR}/gui/DivAcerManagerMax"
  ln -sf "${OPT_DIR}/gui/DivAcerManagerMax" /usr/bin/damx
  echo "✓ GUI deployed. Launch anytime by typing 'damx' in your terminal."
fi

# 3. HWDB Keymaps
if [ "$INSTALL_HWDB" = true ]; then
  echo "⌨️ [3/4] Installing HWDB keymaps..."
  if [ -f "${SCRIPT_DIR}/configs/90-acer-nitro-an16.hwdb" ]; then
    cp -fv "${SCRIPT_DIR}/configs/90-acer-nitro-an16.hwdb" /etc/udev/hwdb.d/
    systemd-hwdb update || true
    udevadm trigger /dev/input/event* 2>/dev/null || true
    echo "✓ HWDB keymap active: Fn+F11/F12 brightness and NitroSense key working."
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

echo "=================================================================="
echo "✅ [myf-damx] Installation successfully completed!"
echo "📌 To launch the GUI: damx"
echo "📌 Service status: systemctl status damx-daemon.service"
echo "=================================================================="
