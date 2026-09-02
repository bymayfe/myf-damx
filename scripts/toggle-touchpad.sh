#!/usr/bin/env python3
import subprocess, os, time, fcntl, sys

# 800ms Atomik Dosya Kilidi
LOCK_FILE = "/tmp/.touchpad_toggle_lock"
lock_fd = open(LOCK_FILE, "a+")
try:
    fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
except IOError:
    sys.exit(0)

lock_fd.seek(0)
content = lock_fd.read().strip()
now = time.time()
if content:
    try:
        if now - float(content) < 0.8:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            sys.exit(0)
    except Exception:
        pass

lock_fd.seek(0)
lock_fd.truncate()
lock_fd.write(str(now))
lock_fd.flush()
fcntl.flock(lock_fd, fcntl.LOCK_UN)

env = os.environ.copy()
uid = 1000
env["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path=/run/user/{uid}/bus"

def run(cmd):
    return subprocess.run(cmd, env=env, capture_output=True, text=True).stdout.strip()

# 1. KWin Touchpad aygıtını bul
devices = run(["qdbus6", "org.kde.KWin", "/org/kde/KWin/InputDevice",
               "org.freedesktop.DBus.Properties.Get",
               "org.kde.KWin.InputDeviceManager", "devicesSysNames"])
dev_path = "event8"
for sys_name in devices.split():
    if "event" not in sys_name:
        continue
    name = run(["qdbus6", "org.kde.KWin", f"/org/kde/KWin/InputDevice/{sys_name}",
                "org.freedesktop.DBus.Properties.Get",
                "org.kde.KWin.InputDevice", "name"])
    if "Touchpad" in name or "FTCS" in name:
        dev_path = sys_name
        break

# 2. NaturalScroll tercihini oku
natural_scroll_pref = "true"
try:
    with open("/home/seyfettin/.config/kcminputrc", "r") as f:
        in_sec = False
        for line in f:
            if "Touchpad" in line:
                in_sec = True
            elif line.startswith("[") and in_sec:
                in_sec = False
            elif in_sec and line.strip().startswith("NaturalScroll="):
                natural_scroll_pref = line.strip().split("=")[-1].lower()
except Exception:
    pass

# 3. Mevcut durumu oku ve tersine çevir
curr = run(["qdbus6", "org.kde.KWin", f"/org/kde/KWin/InputDevice/{dev_path}",
            "org.freedesktop.DBus.Properties.Get",
            "org.kde.KWin.InputDevice", "enabled"])
is_enabled = (curr.lower() == "true")
new_status = not is_enabled

# 4. KWin üzerinde uygula
run(["qdbus6", "org.kde.KWin", f"/org/kde/KWin/InputDevice/{dev_path}",
     "org.freedesktop.DBus.Properties.Set",
     "org.kde.KWin.InputDevice", "enabled",
     "true" if new_status else "false"])

# 5. OSD Bildirimi (Kullanıcı donanım gözlemine göre %100 senkronize)
if new_status:
    run(["qdbus6", "org.kde.plasmashell", "/org/kde/osdService",
         "org.kde.osdService.showText", "input-touchpad-off", "🔴 TOUCHPAD DEVRE DIŞI (KAPALI)"])
else:
    run(["qdbus6", "org.kde.KWin", f"/org/kde/KWin/InputDevice/{dev_path}",
         "org.freedesktop.DBus.Properties.Set",
         "org.kde.KWin.InputDevice", "naturalScroll", natural_scroll_pref])
    run(["qdbus6", "org.kde.plasmashell", "/org/kde/osdService",
         "org.kde.osdService.showText", "input-touchpad-on", "🟢 TOUCHPAD ETKİN (AÇIK)"])
