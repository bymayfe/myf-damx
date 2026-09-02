# myf-damx (DivAcerManagerMax) 🎮❄️

**myf-damx**, Acer Nitro ve Predator serisi oyuncu laptopları (özellikle **Acer Nitro 16 AN16-42 / AMD Zen 4 + RTX 40** serisi) için geliştirilmiş, **5 Modlu Termal Döngü**, **🔵 AI Akıllı Fan Motoru**, **Gelişmiş 4-Bölge RGB Kontrolü** ve **C# Avalonia GUI** içeren tam kapsamlı Linux kontrol merkezidir.

---

## ✨ Öne Çıkan Özellikler

- 🎮 **5'li Termal Profil Döngüsü (AC Şarjda):**
  1. ⚪ **Sessiz Mod (Beyaz):** 0 RPM / Fısıltı devir.
  2. 🟡 **Dengeli Mod (Turuncu):** Fabrika varsayılan Acer eğrisi.
  3. 🔵 **AI Akıllı Fan Modu (Mavi):** Sıcaklığa duyarlı dinamik kademeli fan motoru (Buz Eğrisi) + Klavyede 2'li Neon Mavi Yanıp Sönme (Pulse/Blink).
  4. 🔴 **Performans Modu (Kırmızı):** %75 Sabit Fan.
  5. 🟣 **Turbo Modu (Mor):** %100 Maksimum Fan (5900 RPM).
- 🔋 **Akıllı Pil Modu:** Pildeyken 🟢 **ECO Modu (`low-power`)** ⮀ 🟡 **Dengeli Mod (`balanced`)** otomatik geçişi.
- 🌈 **4-Bölgeli Klavye RGB:** Özel renkler, dalga, nefes alma ve dinamik geçiş efektleri.
- 🖥️ **Modern C# Avalonia Arayüzü:** Canlı sensör takibi, fan hızları ve tek tıkla mod seçimi.
- ⌨️ **Fiziksel Mod Tuşu & NitroSense Butonu Desteği:** Program kapalı olsa bile tuşlara basıldığında OSD bildirimleri ve mod geçişleri sorunsuz çalışır.

---

## 🛠️ Kurulum

### Gereksinimler
- `dotnet-sdk-9.0` veya `.NET Runtime 9.0`
- `python3`, `evdev`, `systemd`
- [myf-linuwu](https://github.com/KULLANICI_ADINIZ/myf-linuwu) çekirdek sürücüsü

### Tek Komutla Kurulum:
```bash
git clone https://github.com/KULLANICI_ADINIZ/myf-damx.git
cd myf-damx
chmod +x install.sh uninstall.sh
sudo ./install.sh
```

### Çalıştırma:
```bash
damx
```

### Kaldırma:
```bash
sudo ./uninstall.sh
```

---

## 📜 Lisans
Bu proje **GPL-3.0 Lisansı** ile lisanslanmıştır.
