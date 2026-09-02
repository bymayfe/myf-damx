# 📋 Değişiklik Günlüğü (CHANGELOG) - myf-damx vs Orijinal DAMX

Bu belge, **[myf-damx](https://github.com/bymayfe/myf-damx)** ile orijinal **[PXDiv / Div-Acer-Manager-Max](https://github.com/PXDiv/Div-Acer-Manager-Max)** arasındaki tüm mimari, kod, performans ve özellik farklarını detaylandırmaktadır.

---

## 🚀 Sürüm 2.5.0-myf (Özel Acer Nitro 16 Geliştirme Sürümü)

### 1. 🌡️ Termal Yönetim & 5 Modlu Döngü
- **[YENİ] 5'li Termal Profil Döngüsü (AC Şarjda):** Orijinal projede 4 mod varken (`quiet`, `balanced`, `performance`, `turbo`), araya **🔵 AI Akıllı Fan Modu** eklenerek 5'li tam döngü oluşturuldu:
  - ⚪ **Sessiz (Beyaz):** 0 RPM / Fısıltı devir.
  - 🟡 **Dengeli (Turuncu):** Acer standart fabrika eğrisi.
  - 🔵 **AI Akıllı Fan Modu (Mavi):** Sıcaklığa duyarlı dinamik kademeli akıllı fan motoru (Buz Eğrisi).
  - 🔴 **Performans (Kırmızı):** %75 Sabit Fan.
  - 🟣 **Turbo (Mor):** %100 Maksimum Devir Fan (5900 RPM).
- **[YENİ] `SmartFanWorker` Thread Motoru:** Arka planda CPU sıcaklığını `k10temp` / `hwmon` sensörlerinden 2.5 saniyede bir okuyarak fan hızlarını otomatik kademelendirir:
  - `< 55°C`: %0 Fan (~1800 RPM Fısıltı)
  - `55°C – 68°C`: %45 Fan (~2800 RPM)
  - `68°C – 78°C`: %65 Fan (~3800 RPM)
  - `78°C – 85°C`: %80 Fan (~4800 RPM)
  - `> 85°C`: %100 Fan (5900 RPM Acil Tepe Soğutma)
- **[DÜZELTME] Fan Titremesi & Hunting Önleme (Hysteresis):** Fanların sınır sıcaklıklarda sürekli hızlanıp yavaşlamasını ve EC ile aynı anda fan yönetmeye çalışıp çakışmasını (fighting) engelleyen histeresis koruması eklendi.

---

### 2. ⚡ Klavye Aydınlatması & RGB Animasyonları
- **[YENİ] 2'li Neon Mavi Yanıp Sönme Animasyonu (Pulse/Blink):**
  - AI Akıllı Fan Moduna geçildiğinde klavyenin 4 bölgesi anında **2 kez parlak Neon Mavi (Buz Mavisi)** olarak yanıp söner.
  - Animasyon bittiğinde klavye **kullanıcının kendi ayarladığı önceki renk döngüsüne / efektine otomatik olarak geri döner**.
- **[DÜZELTME] Donanımsal Turuncu Flaş Baskılama:** ACPI seviyesinde `balanced` moduna geçerken Acer BIOS/EC'nin zorla basmaya çalıştığı 1 saniyelik Turuncu donanım flaşı filtrelendi; mavi animasyonun kesintisiz ve net görünmesi sağlandı.

---

### 3. ⌨️ Donanım Tuşları, Wayland & Masaüstü Entegrasyonu
- **[YENİ] OSD Masaüstü Bildirimleri (`notify-send`):**
  - Fiziksel mod tuşuna veya NitroSense tuşuna basıldığında GUI kapalı olsa dahi masaüstünde şık OSD bildirimleri (`Termal Mod: 🔵 AI Akıllı Fan Modu (Mavi)` vb.) gösterilir.
- **[YENİ] Udev HWDB Tuş Eşlemesi (`90-acer-nitro-an16.hwdb`):**
  - `Fn + F11`: Klavye ışığı kısma (`kbdillumdown`)
  - `Fn + F12`: Klavye ışığı artırma (`kbdillumup`)
  - `0xf5`: NitroSense özel tuşu doğrudan `prog1` (`148`/`425`) olarak bağlandı.
- **[YENİ] Wayland & KDE Plasma 6 Uyumlu Touchpad Geçişi (`toggle-touchpad.sh`):**
  - `kcminputrc` ve KWin D-Bus arayüzünü aynı anda senkronize ederek touchpad'i anında devre dışı bırakan veya aktif eden akıllı betik eklendi.

---

### 4. 🖥️ GUI Arayüz Geliştirmeleri (Avalonia C# / .NET 9)
- **[YENİ] `AI Smart` Butonu:**
  - `MainWindow.axaml` içine Neon Cyan `#00D4FF` ve `Brain` ikonu ile **AI Smart** seçeneği eklendi.
  - `MainWindow.axaml.cs` ve `DAMXClient.cs` içindeki termal profil sözlüklerine `"smart"` anahtarı bağlanarak Release modunda derlendi.

---

### 5. 📦 Kurulum & Servis Otomasyonu
- **[YENİ] Tek Komutla Kurucu (`install.sh`):**
  - Daemon dosyalarını `/opt/damx/daemon/` dizinine yükler.
  - Systemd servisini (`damx-daemon.service`) otomatik kurar ve başlatır.
  - HWDB tuş eşlemelerini `/etc/udev/hwdb.d/` altına kopyalayıp `systemd-hwdb update` çalıştırır.
  - `.NET 9` GUI projesini derleyip `/opt/damx/gui/` altına kurar ve `/usr/bin/damx` kısayolunu oluşturur.
- **[YENİ] Temiz Kaldırıcı (`uninstall.sh`):**
  - Servisleri durdurur, devre dışı bırakır ve `/opt/damx` dosyalarını sistemden tamamen temizler.

---

## 📊 Özet Karşılaştırma Matrisi

| Kategori | Orijinal `DAMX` (PXDiv) | `myf-damx` (bymayfe) |
| :--- | :--- | :--- |
| **Termal Profil Sayısı** | 4 Mod | **5 Mod (AI Akıllı Fan Dahil)** |
| **Dinamik Fan Eğrisi** | ❌ Yok | **✅ Otomatik Sıcaklık Kontrollü (Buz Eğrisi)** |
| **Mavi Flaş Animasyonu** | ❌ Yok | **✅ 2'li Neon Mavi Pulse + Eski Renklere Dönüş** |
| **Fn+F11/F12 Klavye Işık Tuşları** | ❌ Yok | **✅ HWDB ile Tam Entegre** |
| **Touchpad Toggle D-Bus Sync** | ❌ Temel X11 | **✅ Wayland + KDE Plasma 6 Destekli** |
| **Kurulum Deneyimi** | Manuel / Çoklu Menü | **✅ Tek Tıkla `sudo ./install.sh`** |
