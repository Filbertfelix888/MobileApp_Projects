# Panduan Demo

Panduan singkat untuk presentasi aplikasi **Project Management Mobile App**. Semua langkah sudah dicoba di emulator Android dengan backend QA.

## 1. Pengantar Singkat

Aplikasi ini adalah versi mobile dari sistem manajemen proyek. Pengguna bisa membuat proyek, mengatur tugas di papan Kanban, menambah anggota, menugaskan tugas, dan melihat ringkasan beban kerja. Aplikasi memakai backend yang sudah ada, jadi data sama dengan aplikasi web.

Fitur utama:

| Fitur | Gunanya |
| --- | --- |
| Masuk, daftar, keluar | Mengamankan akses; sesi tetap tersimpan setelah aplikasi ditutup |
| Daftar proyek | Mencari, membuat, dan menghapus proyek |
| Papan Kanban | Membagi pekerjaan ke kolom, misalnya Todo dan Doing |
| Tugas | Judul, deskripsi, dan tenggat; bisa dipindah antar kolom |
| Anggota dan penanggung jawab | Menentukan siapa mengerjakan tugas apa |
| Ringkasan papan | Jumlah tugas per kolom dan beban per orang |
| Analitik global | Jumlah penugasan dari seluruh proyek |
| Tema Sistem/Terang/Gelap | Tampilan nyaman di kondisi cahaya berbeda |

## 2. Persiapan Sebelum Demo

1. Pastikan HP atau emulator tersambung ke internet. Backend QA ada di `http://43.173.10.180:3030`.
2. Pasang aplikasi. APK debug ada di `build\app\outputs\flutter-apk\app-debug.apk` (tidak ikut disimpan di Git; buat ulang dengan `flutter build apk --debug --no-pub`). Contoh pemasangan: `adb install -r build\app\outputs\flutter-apk\app-debug.apk`.
3. Siapkan **dua akun tes**. Buat sendiri lewat **Daftar baru**, atau pakai akun yang memang boleh dipakai di QA. Jangan menulis kata sandi di dokumen atau di slide.
4. Aplikasi otomatis memakai backend QA. Tidak ada pilihan DEV/QA di layar masuk.

## 3. Langkah Demo

Urutan: Masuk → Proyek → Kanban → Tugas → Pindah → Tugaskan → Analitik → Tema → Keluar.

1. **Masuk.** Di layar **Masuk**, isi email dan password akun pertama, lalu tekan **Masuk ke akun Anda**. Jika belum punya akun, tekan **Daftar baru** dulu. Hasil: daftar proyek tampil.
2. **Proyek.** Tekan **Buat proyek baru**, isi nama, deskripsi, dan tenggat, lalu **Simpan**. Ketik nama proyek di **Cari proyek** untuk menunjukkan pencarian. Tekan **Detail proyek**.
3. **Kanban.** Di halaman proyek, tekan **Tambah kolom** dan buat `Todo`, lalu `Doing`. Bagian **Detail proyek** (panah) menampilkan deskripsi dan tanggal.
4. **Tugas.** Tekan **Tambah tugas** pada kolom Todo, isi judul dan deskripsi, pilih tenggat, lalu **Buat tugas**. Buka tugas, ubah deskripsi, tekan **Simpan perubahan**.
5. **Pindah.** Di tugas, buka **Pindahkan tugas** dan pilih **Doing**. Atau tahan kartu tugas lalu seret ke kolom lain.
6. **Tugaskan.** Tekan **Anggota**, cari akun kedua, centang, lalu **Tambah (1)**. Buka tugas, centang anggota di **Penanggung jawab**, lalu **Tugaskan (1)**.
7. **Analitik.** Buka tab **Ringkasan** untuk melihat jumlah tugas per kolom dan beban per orang. Kembali ke daftar proyek, buka **Analitik global** untuk melihat total penugasan.
8. **Tema.** Tekan ikon tema di kanan atas, pilih **Gelap**, lalu **Terang**, lalu **Sistem**. Tutup dan buka aplikasi untuk menunjukkan pilihan tersimpan.
9. **Keluar.** Tekan ikon akun, pilih **Logout**. Layar masuk tampil; tombol Kembali tidak membuka halaman proyek.

Setelah demo, hapus proyek tes lewat ikon tempat sampah di daftar proyek agar data QA tetap rapi.

## 4. Penjelasan Teknologi

- **Flutter** adalah kerangka kerja untuk membuat aplikasi mobile dengan bahasa Dart. Satu kode dipakai untuk membangun tampilan; di proyek ini dijalankan di Android.
- **Go REST API** adalah server (backend) yang menerima permintaan dari aplikasi lewat alamat web (HTTP), memeriksa login, dan membaca atau menyimpan data. Aplikasi mengirim dan menerima data berbentuk JSON.
- **PostgreSQL** adalah basis data tempat server menyimpan akun, proyek, kolom, dan tugas.

Alurnya: aplikasi Flutter → Go REST API → PostgreSQL, lalu jawabannya kembali ke aplikasi. Flutter tidak mengakses basis data langsung. Server dan basis data bukan bagian dari repositori ini.

## 5. Pertanyaan yang Mungkin Muncul

**Mengapa memakai Flutter?**
Satu basis kode dengan tampilan Material 3 yang konsisten, dan tersedia widget serta alat uji bawaan. Pada proyek ini aplikasi dijalankan dan diuji di Android.

**Apakah aplikasi punya backend sendiri?**
Tidak. Aplikasi memakai Go REST API dan PostgreSQL yang sudah ada dan dikelola terpisah.

**Bagaimana login bekerja?**
Aplikasi mengirim email dan password ke server. Server membalas dengan token. Token disimpan di perangkat dan dikirim pada setiap permintaan berikutnya. Logout menghapus token itu.

**Apakah data aman?**
Belum cukup untuk produksi. Backend QA memakai HTTP biasa (tanpa enkripsi), belum membatasi akses per proyek, dan respons daftar anggota memuat hash kata sandi (aplikasi tidak menyimpan atau menampilkannya). Karena itu gunakan hanya data uji.

**Mengapa ada pilihan QA saja?**
Untuk demo, aplikasi dikunci ke backend QA agar tidak salah memilih server. Kode pilihan DEV masih ada di repositori.

**Bisakah urutan tugas diatur?**
Belum. Backend belum punya fitur mengurutkan; tugas yang dipindah selalu masuk di akhir kolom tujuan.

**Mengapa analitik global tidak per proyek?**
Backend menghitung penugasan dari semua proyek dan mengelompokkan berdasarkan nama. Aplikasi menampilkan apa adanya dan menuliskan cakupan itu di layar.

**Bagaimana kualitas aplikasi diuji?**
Pada 2026-11-08: analisis kode tanpa temuan, 187 tes otomatis lulus, dan build APK debug berhasil. Sepuluh skenario di `MANUAL_TESTING.md` dijalankan di emulator Android dengan backend QA pada 2026-11-07; perubahan kecil setelahnya (batas input dan ukuran tombol bilah atas) dicek lewat tangkapan layar dan pengukuran, bukan diulang penuh.

**Apa yang belum ada?**
Komentar, label, lampiran, daftar periksa, pengurutan, dan penghapusan akun. Build rilis belum ditandatangani.

## 6. Mengatasi Masalah

| Masalah | Penyebab umum | Cara mengatasi |
| --- | --- | --- |
| Gagal masuk atau pesan koneksi | Tidak ada internet atau server QA tidak aktif | Periksa koneksi, coba lagi, atau tanyakan pemilik server |
| Layar kembali ke Masuk | Sesi berakhir (token tidak berlaku) | Masuk lagi |
| Pesan "Urutan kolom belum tersedia" di proyek baru | Proyek belum punya kolom | Tekan **Tambah kolom** |
| Daftar proyek kosong | Akun baru belum punya proyek | Buat proyek dengan **Buat proyek baru** |
| Anggota tidak ditemukan | Akun belum terdaftar atau nama salah | Cari memakai nama atau email akun yang benar |
| Ringkasan belum lengkap | Sebagian data tugas gagal dimuat | Tekan **Coba lagi** |
| Teks terpotong | Ukuran font sistem sangat besar | Perkecil ukuran font di pengaturan Android |
| Aplikasi tidak terpasang | APK belum dibuat atau izin pemasangan | Jalankan `flutter build apk --debug --no-pub`, lalu pasang ulang |

## 7. Daftar Periksa Akhir

- [ ] HP atau emulator terhubung ke internet.
- [ ] Aplikasi terpasang dan terbuka di layar **Masuk**.
- [ ] Dua akun tes siap (kata sandi tidak ditampilkan).
- [ ] Sudah dilatih satu kali dari Masuk sampai Keluar.
- [ ] Tema diatur ke **Sistem** atau yang diinginkan.
- [ ] Baterai cukup dan notifikasi dimatikan.
- [ ] Setelah demo: proyek tes dihapus.
