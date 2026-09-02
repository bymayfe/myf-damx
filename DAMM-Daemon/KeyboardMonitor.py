#!/usr/bin/env bash
#!/usr/bin/env python3
"""
KeyboardMonitor - Built-in Acer Nitro/Predator Hotkey, Turbo Button & Smart Fan Monitor
Handles KEY_PROG1 (NitroSense Key, 148/425) and KEY_PROG2 (Gaming Turbo Key, 149/136)
Includes 🔵 Akıllı Fan Modu (Mavi / Smart Auto Curve) with dynamic temperature scaling.
"""

import os
import glob
import struct
import select
import subprocess
import threading
import logging
import time
from pathlib import Path

IS_64BIT = struct.calcsize("P") == 8
EVENT_SIZE = 24 if IS_64BIT else 16

# Event types
EV_KEY = 1
KEY_PRESS = 1

# Key codes
KEY_NITROSENSE = 148   # KEY_PROG1 (NitroSense 'N' button)
KEY_NITRO_ALT = 425    # Alternate vendor keycode
KEY_TURBO = 149        # KEY_PROG2 (Acer Gaming Turbo / Thermal mode button)


class KeyboardMonitor:
    def __init__(self, manager=None, logger=None):
        self.manager = manager
        self.log = logger or logging.getLogger("KeyboardMonitor")
        self.running = False
        self.monitor_thread = None
        self.smart_thread = None
        self.smart_fan_enabled = False
        self.last_smart_fan_level = -1
        self.lock = threading.Lock()
        self.last_press_time = {}

    def find_target_user(self):
        """Find the active logged-in desktop user."""
        try:
            # 1. Check loginctl sessions
            result = subprocess.run(
                ['loginctl', 'list-sessions', '--no-legend'],
                capture_output=True, text=True, timeout=2
            )
            for line in result.stdout.strip().splitlines():
                parts = line.split()
                if len(parts) >= 3 and parts[2] not in ('root', 'gdm', 'sddm', 'lightdm'):
                    return parts[2]
        except Exception:
            pass

        # 2. Fallback to SUDO_USER or who
        user = os.environ.get('SUDO_USER')
        if user and user != 'root':
            return user

        try:
            result = subprocess.run(['who'], capture_output=True, text=True, timeout=2)
            for line in result.stdout.splitlines():
                parts = line.split()
                if parts and parts[0] != 'root':
                    return parts[0]
        except Exception:
            pass

        return None

    def get_user_session_env(self, target_user):
        """Extract graphical environment variables for the target user."""
        env = {
            'DISPLAY': ':0',
            'WAYLAND_DISPLAY': 'wayland-0',
        }
        try:
            uid_res = subprocess.run(['id', '-u', target_user], capture_output=True, text=True)
            uid = uid_res.stdout.strip()
            env['XDG_RUNTIME_DIR'] = f"/run/user/{uid}"
            env['DBUS_SESSION_BUS_ADDRESS'] = f"unix:path=/run/user/{uid}/bus"
        except Exception:
            env['XDG_RUNTIME_DIR'] = "/run/user/1000"
            env['DBUS_SESSION_BUS_ADDRESS'] = "unix:path=/run/user/1000/bus"

        # Search /proc for running graphical user process
        try:
            pids = subprocess.run(['pgrep', '-u', target_user], capture_output=True, text=True).stdout.split()
            for pid in pids[:10]:
                environ_path = f"/proc/{pid}/environ"
                if os.path.exists(environ_path):
                    try:
                        with open(environ_path, 'rb') as f:
                            raw = f.read().split(b'\0')
                            for entry in raw:
                                if entry.startswith(b'WAYLAND_DISPLAY='):
                                    env['WAYLAND_DISPLAY'] = entry.decode('utf-8', errors='ignore').split('=', 1)[1]
                                elif entry.startswith(b'DISPLAY='):
                                    env['DISPLAY'] = entry.decode('utf-8', errors='ignore').split('=', 1)[1]
                                elif entry.startswith(b'DBUS_SESSION_BUS_ADDRESS='):
                                    env['DBUS_SESSION_BUS_ADDRESS'] = entry.decode('utf-8', errors='ignore').split('=', 1)[1]
                                elif entry.startswith(b'XDG_RUNTIME_DIR='):
                                    env['XDG_RUNTIME_DIR'] = entry.decode('utf-8', errors='ignore').split('=', 1)[1]
                    except Exception:
                        continue
        except Exception:
            pass

        return env

    def launch_or_toggle_gui(self):
        """Launch or bring DAMX GUI to foreground."""
        target_user = self.find_target_user()
        if not target_user:
            self.log.error("Could not find active desktop user to launch DAMX GUI")
            return

        env = self.get_user_session_env(target_user)
        self.log.info(f"Launching DAMX GUI for user '{target_user}'...")

        # Check if already running
        try:
            pgrep_res = subprocess.run(['pgrep', '-f', 'DivAcerManagerMax'], capture_output=True, text=True)
            if pgrep_res.returncode == 0:
                self.log.info("DivAcerManagerMax is already running in background.")
                return
        except Exception:
            pass

        cmd = [
            'systemd-run',
            f'--machine={target_user}@.host',
            '--user',
            '/usr/bin/damx'
        ]

        try:
            subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True
            )
            self.log.info("DAMX GUI process spawned successfully.")
        except Exception as e:
            self.log.error(f"Failed to launch DAMX GUI: {e}")

    def is_on_ac(self):
        """Check if laptop is connected to AC charger."""
        for path in glob.glob("/sys/class/power_supply/*/online"):
            if any(name in path for name in ("ACAD", "ADP", "AC0", "AC")):
                try:
                    with open(path, "r") as f:
                        if f.read().strip() == "1":
                            return True
                except Exception:
                    pass
        return False

    def get_max_temp(self):
        """Read maximum CPU temperature from hwmon sensors."""
        max_t = 40.0
        for hwmon in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
            try:
                with open(f"{hwmon}/name", "r") as f:
                    name = f.read().strip()
                if name in ("k10temp", "coretemp", "zenpower", "cpu_thermal", "acpitz"):
                    for temp_file in glob.glob(f"{hwmon}/temp*_input"):
                        with open(temp_file, "r") as tf:
                            val = float(tf.read().strip()) / 1000.0
                            if 20 <= val <= 115 and val > max_t:
                                max_t = val
            except Exception:
                continue
        return max_t

    def smart_fan_loop(self):
        """Background worker dynamically adjusting fan speeds in Smart (Mavi) Mode."""
        self.log.info("Smart Fan curve worker loop started.")
        while self.running:
            if self.smart_fan_enabled and self.manager:
                try:
                    temp = self.get_max_temp()

                    # Akıllı Dinamik Fan Eğrisi (Buz Eğrisi):
                    if temp < 55.0:
                        target = 0      # Sessiz / Fısıltı (~1800 RPM)
                    elif temp < 68.0:
                        target = 45     # Hafif Yük (~2800 RPM)
                    elif temp < 78.0:
                        target = 65     # Orta Yük (~3800 RPM)
                    elif temp < 85.0:
                        target = 80     # Yüksek Yük (~4800 RPM)
                    else:
                        target = 100    # Acil Tepe Soğutma (5900 RPM)

                    if target != self.last_smart_fan_level:
                        self.log.info(f"🔵 Akıllı Fan Ayarlaması: Sıcaklık={temp:.1f}°C -> Fan=%{target}")
                        if hasattr(self.manager, 'set_fan_speed'):
                            self.manager.set_fan_speed(target, target)
                        self.last_smart_fan_level = target
                except Exception as e:
                    self.log.error(f"Smart fan worker hatası: {e}")
            time.sleep(2.5)

    def cycle_thermal_profile(self):
        """Cycle thermal profiles & set fan speeds natively with Smart Blue Mode."""
        if not self.manager:
            self.log.error("No DAMXManager attached to KeyboardMonitor")
            return

        with self.lock:
            on_ac = self.is_on_ac()
            current = "smart" if self.smart_fan_enabled else (self.manager.get_thermal_profile() or "balanced").strip().lower()

            if not on_ac:
                # Battery rotation: low-power <-> balanced
                self.smart_fan_enabled = False
                if current == "low-power":
                    next_info = ("balanced", 0, 0, "Dengeli Mod", "battery-charging")
                else:
                    next_info = ("low-power", 0, 0, "ECO Modu (Pil Tasarrufu)", "battery-low")
            else:
                # AC rotation:
                # quiet (⚪ Beyaz) -> balanced (🟡 Turuncu) -> smart (🔵 Mavi AI Akıllı) -> balanced-performance (🔴 Kırmızı) -> performance (🟣 Mor) -> quiet
                rotations = {
                    "quiet": ("balanced", 0, 0, "Dengeli Mod (Turuncu)", "system-run"),
                    "balanced": ("smart", 0, 0, "AI Akıllı Fan Modu (Mavi)", "weather-snow"),
                    "smart": ("balanced-performance", 75, 75, "Performans Modu (Kırmızı)", "speedometer"),
                    "balanced-performance": ("performance", 100, 100, "Turbo Modu (Mor)", "dialog-warning"),
                    "performance": ("quiet", 0, 0, "Sessiz Mod (Beyaz)", "audio-volume-muted"),
                }
                next_info = rotations.get(current, ("balanced", 0, 0, "Dengeli Mod (Turuncu)", "system-run"))

            target_mode, fan_cpu, fan_gpu, title, icon = next_info

            if target_mode == "smart":
                self.smart_fan_enabled = True
                self.last_smart_fan_level = -1
                self.log.info("🔵 AI Akıllı Fan Modu (Mavi) Aktif Edildi!")
                self.manager.set_thermal_profile("smart")
                self.send_desktop_notification(f"Termal Mod: {title}", "Sıcaklığa Duyarlı Otomatik Soğutma (Buz Eğrisi)", icon)
                threading.Thread(target=self.flash_blue_animation, daemon=True, name="DAMX-BlueFlash").start()
            else:
                self.smart_fan_enabled = False
                self.log.info(f"Cycling Thermal Profile: '{current}' -> '{target_mode}' (Fans: {fan_cpu}%)")
                self.manager.set_thermal_profile(target_mode)
                if hasattr(self.manager, 'set_fan_speed'):
                    self.manager.set_fan_speed(fan_cpu, fan_gpu)

                self.send_desktop_notification(f"Termal Mod: {title}", f"Fanlar: %{fan_cpu if fan_cpu > 0 else 'Otomatik'}", icon)

    def flash_blue_animation(self):
        """Flash keyboard with a 2-pulse vibrant neon blue blink, then restore original lighting."""
        try:
            time.sleep(0.12)
            if not self.manager or not getattr(self.manager, 'has_four_zone_kb', False):
                return

            # Read current states before flashing
            old_per_zone = self.manager.get_per_zone_mode().strip()
            old_four_zone = self.manager.get_four_zone_mode().strip()

            # Pulse 1: Neon Cyan Blue ON
            self.manager.set_per_zone_mode("00E5FF", "00E5FF", "00E5FF", "00E5FF", 100)
            time.sleep(0.35)

            # Pulse 1: OFF
            self.manager.set_per_zone_mode("000000", "000000", "000000", "000000", 0)
            time.sleep(0.15)

            # Pulse 2: Bright Electric Blue ON
            self.manager.set_per_zone_mode("00FFFF", "00FFFF", "00FFFF", "00FFFF", 100)
            time.sleep(0.5)

            # Restore original state
            if old_four_zone and old_four_zone.startswith(("1,", "2,", "3,", "4,", "5,", "6,", "7,")):
                # Restore dynamic effect
                parts = old_four_zone.split(",")
                if len(parts) >= 7:
                    self.manager.set_four_zone_mode(
                        int(parts[0]), int(parts[1]), int(parts[2]),
                        int(parts[3]), int(parts[4]), int(parts[5]), int(parts[6])
                    )
            elif old_per_zone and "," in old_per_zone:
                # Restore per-zone colors
                parts = old_per_zone.split(",")
                if len(parts) >= 5:
                    self.manager.set_per_zone_mode(parts[0], parts[1], parts[2], parts[3], int(parts[4]))
            else:
                # Fallback: Default 4-zone Rainbow / Static
                self.manager.set_per_zone_mode("FF0055", "00FF55", "0055FF", "FF00FF", 100)
        except Exception as e:
            self.log.error(f"Error during flash_blue_animation: {e}")

    def toggle_touchpad(self):
        """Toggle touchpad state."""
        target_user = self.find_target_user()
        if not target_user:
            return

        cmd = [
            'systemd-run',
            f'--machine={target_user}@.host',
            '--user',
            '/usr/local/bin/toggle-touchpad.sh'
        ]
        try:
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as e:
            self.log.error(f"Failed to toggle touchpad: {e}")

    def send_desktop_notification(self, title, message, icon="preferences-system"):
        """Send OSD notification to desktop user."""
        target_user = self.find_target_user()
        if not target_user:
            return

        cmd = [
            'systemd-run',
            f'--machine={target_user}@.host',
            '--user',
            'notify-send',
            '-a', 'DivAcerManagerMax',
            '-u', 'normal',
            '-t', '2000',
            '-i', icon,
            title,
            message
        ]
        try:
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    def find_keyboard_devices(self):
        """Find all keyboard and hotkey input event devices."""
        devices = []
        try:
            devices_path = Path("/proc/bus/input/devices")
            if not devices_path.exists():
                return devices

            with open(devices_path, "r") as f:
                content = f.read()

            for device_block in content.split("\n\n"):
                lines = [l.strip() for l in device_block.split("\n") if l.strip()]
                name = ""
                handlers = ""
                for line in lines:
                    if line.startswith("N: Name="):
                        name = line.split("=", 1)[1].strip('"')
                    elif line.startswith("H: Handlers="):
                        handlers = line.split("=", 1)[1]

                # Match Acer WMI, AT Keyboard, or other keyboards
                if any(kw in name.lower() for kw in ("acer", "keyboard", "wmi")):
                    for token in handlers.split():
                        if token.startswith("event"):
                            dev_path = f"/dev/input/{token}"
                            if os.path.exists(dev_path) and dev_path not in devices:
                                devices.append(dev_path)
                                self.log.info(f"Found input device '{name}': {dev_path}")
        except Exception as e:
            self.log.error(f"Error finding keyboard devices: {e}")

        return devices

    def monitor_loop(self):
        """Main event loop monitoring input devices."""
        device_paths = self.find_keyboard_devices()
        if not device_paths:
            self.log.error("No input devices found for monitoring")
            return

        file_descriptors = {}
        for path in device_paths:
            try:
                fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
                file_descriptors[fd] = path
            except Exception as e:
                self.log.warning(f"Could not open device {path}: {e}")

        if not file_descriptors:
            self.log.error("Failed to open any input devices")
            return

        self.log.info(f"Monitoring {len(file_descriptors)} input devices for NitroSense/Turbo keys...")

        try:
            while self.running:
                rlist, _, _ = select.select(list(file_descriptors.keys()), [], [], 0.5)
                for fd in rlist:
                    try:
                        data = os.read(fd, EVENT_SIZE * 8)
                        for i in range(0, len(data), EVENT_SIZE):
                            chunk = data[i:i + EVENT_SIZE]
                            if len(chunk) != EVENT_SIZE:
                                continue

                            if IS_64BIT:
                                _, _, event_type, code, value = struct.unpack("QQHHi", chunk)
                            else:
                                _, _, event_type, code, value = struct.unpack("IIHHi", chunk)

                            if event_type == EV_KEY and value == KEY_PRESS:
                                now = time.time()
                                if now - self.last_press_time.get(code, 0) < 0.3:
                                    continue  # Debounce 300ms
                                self.last_press_time[code] = now

                                if code in (KEY_NITROSENSE, KEY_NITRO_ALT):
                                    self.log.info(f"NitroSense Key detected (code {code})!")
                                    self.launch_or_toggle_gui()
                                elif code in (KEY_TURBO, 202, 203):
                                    self.log.info(f"Gaming Turbo Key detected (code {code})!")
                                    self.cycle_thermal_profile()
                                elif code in (530, 531, 532):
                                    self.log.info(f"Touchpad Key detected (code {code})!")
                                    self.toggle_touchpad()

                    except BlockingIOError:
                        continue
                    except Exception as e:
                        self.log.error(f"Error reading from device {file_descriptors.get(fd)}: {e}")
        finally:
            for fd in file_descriptors:
                try:
                    os.close(fd)
                except Exception:
                    pass

    def start_monitoring(self):
        """Start background keyboard monitoring and smart fan worker threads."""
        if self.running:
            return True

        self.running = True
        self.monitor_thread = threading.Thread(target=self.monitor_loop, daemon=True, name="DAMX-KeyboardMonitor")
        self.monitor_thread.start()

        self.smart_thread = threading.Thread(target=self.smart_fan_loop, daemon=True, name="DAMX-SmartFanWorker")
        self.smart_thread.start()

        self.log.info("KeyboardMonitor and SmartFanWorker threads started successfully.")
        return True

    def stop_monitoring(self):
        """Stop background threads."""
        self.running = False
        if self.monitor_thread and self.monitor_thread.is_alive():
            self.monitor_thread.join(timeout=2.0)
        if self.smart_thread and self.smart_thread.is_alive():
            self.smart_thread.join(timeout=2.0)
        self.log.info("KeyboardMonitor and SmartFanWorker threads stopped.")
