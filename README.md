# 🎵 Zunify v1.0 — Standalone Aesthetic Music Player
**Crafted with ❤️ by Fannz** (`com.fannz.zunify`)

Aplikasi pemutar musik Android **100% Standalone (Tanpa Server / Tanpa Login)** dengan UI Vinyl Minimalis, Lirik Karaoke Sinkron + Terjemahan Bahasa Indonesia Otomatis, Hardware DSP Equalizer, Private Vault Offline Downloader, dan Rapot Mingguan.

---

## ✨ Fitur Lengkap Zunify v1.0

1. **100% Standalone & Tanpa Login (`ytmusic_service.dart`)**
   - Streaming langsung dari YouTube Music publik tanpa butuh akun atau server VPS.
   - **Algoritma Radio "Up Next"** ala Spotify yang otomatis menyambung lagu berikutnya dengan genre/vibe sejenis.
2. **Lirik Karaoke Sinkron + Terjemahan Indonesia Pintar (`lyrics_translation_service.dart`)**
   - Terintegrasi dengan **LRCLIB** untuk lirik ber-timestamp (`.lrc`) yang bergerak otomatis per detik.
   - Otomatis menerjemahkan lagu berbahasa asing (Inggris, Jepang, Korea, dll) ke **Bahasa Indonesia** di bawah lirik utama.
   - **Smart Bahasa Indonesia Detector:** Jika lagu aslinya sudah berbahasa Indonesia, baris terjemahan otomatis disembunyikan agar layar lirik tetap bersih!
3. **Private In-App Offline Downloader (`download_service.dart`)**
   - Lagu yang di-download tersimpan rapi di dalam **Private Vault internal Zunify** (tidak mengotori File Manager atau aplikasi pemutar musik bawaan HP).
   - Menyimpan file audio + cover art resolusi tinggi + lirik terjemahan sehingga **lirik tetap muncul saat 100% offline**.
   - **Toggle Mode Offline** langsung di pojok kanan atas Beranda.
4. **Audio Quality Selector (Hemat Kuota vs High Quality)**
   - **96 kbps (Hemat Data):** Irit kuota untuk streaming & download.
   - **160 kbps Opus/M4A (High Quality):** Suara jernih maksimal untuk earphone/headphone.
5. **Hardware DSP Equalizer (`MainActivity.kt` & `equalizer_service.dart`)**
   - Terhubung langsung ke chip audio Android (`Equalizer`, `BassBoost`, `Virtualizer`).
   - 6 Preset siap pakai (*Normal, Bass Boost 🔥, Pop Aesthetic, Vocal / Lirik Jernih, Rock & Energetic, Electronic / Night*) + 5-Band Custom Slider.
6. **Import Playlist Spotify & YouTube Music (`playlist_importer_service.dart`)**
   - Cukup tempel link playlist publik dari **Spotify** (`open.spotify.com/playlist/...`) atau **YouTube Music**, Zunify otomatis mencocokkan semua lagunya ke dalam koleksi lokalmu.
7. **Sleep Timer & Share Card Lirik Aesthetic (`sleep_timer_sheet.dart` & `share_card_modal.dart`)**
   - Setel waktu tidur otomatis (*15m, 30m, 45m, 60m*, atau *Selesai Lagu Ini*).
   - Buat gambar kartu lirik aesthetic ber-watermark **"Zunify • Crafted with ❤️ by Fannz"** untuk dibagikan ke Instagram Story atau WhatsApp.
8. **Rapot Mingguan Otomatis — Setiap Minggu Jam 18:00 WIB (`rapot_service.dart`)**
   - Mencatat durasi dengar di database lokal SQLite dan menjadwalkan notifikasi otomatis setiap **Minggu pukul 18:00 WIB** lengkap dengan kartu infografis *Top 5 Lagu, Top Artis, Total Jam Dengar*, dan *Vibe Persona*.

---

## 🚀 Cara Menghasilkan File `.apk` (Siap Bagi ke Teman-Teman)

### Cara 1: Otomatis via GitHub Cloud (Tanpa Install Android Studio di Laptop!)
Project ini sudah dilengkapi workflow otomatis di `.github/workflows/build-apk.yml`:
1. Buat repository baru di GitHub (boleh **Private** atau **Public**).
2. Upload/push seluruh isi folder `zunify` ini ke GitHub:
   ```bash
   git init
   git add .
   git commit -m "Initial release Zunify v1.0 by Fannz"
   git branch -M main
   git remote add origin https://github.com/USERNAME_LU/zunify.git
   git push -u origin main
   ```
3. Buka tab **Actions** di GitHub lu — dalam ~3 menit, GitHub akan selesai meng-compile file **`Zunify-v1.0-by-Fannz.apk`** yang siap lu download dan kirim ke grup WhatsApp temen-temen lu!

### Cara 2: Build Lokal di Windows
Jika di laptop sudah terpasang Flutter SDK, cukup klik 2x file **`build_apk_windows.bat`**.
