# Panduan Tes Manual

Aplikasi selalu memakai backend **QA**. Pilihan DEV/QA disembunyikan dari layar masuk dan daftar, jadi tidak ada langkah memilih environment. Preferensi DEV lama otomatis dikembalikan ke QA dan sesi DEV tidak dipakai ulang.

Gunakan akun dan proyek tes sementara. Jangan pakai data produksi. Proyek QA lama bernama `Smoke project` dan dua akun tes sudah ada; jangan hapus jika bukan milikmu.

Ikuti urutan ini. Cocokkan hasil setelah setiap langkah.

1. **Daftar akun** — Di layar **Masuk**, tekan **Daftar baru**. Buat dua akun tes dengan email berbeda. Harapan: setiap pendaftaran berhasil dan kembali ke layar masuk. Tidak ada pilihan environment di layar masuk maupun daftar.
2. **Masuk dan keluar** — Masuk dengan akun tes pertama. Tutup lalu buka aplikasi. Harapan: sesi tetap masuk. Tekan ikon akun, lalu pilih **Logout**. Harapan: layar masuk tampil dan tombol Kembali tidak membuka Home. Masuk lagi dengan akun tes pertama.
3. **Buat dan cari proyek** — Tekan **Buat proyek baru**. Isi nama unik, deskripsi, dan tenggat, lalu **Simpan**. Cari nama proyek itu di kolom **Cari proyek**, lalu hapus pencarian. Harapan: proyek muncul dan pencarian menampilkan hasil yang cocok.
4. **Buka proyek** — Tekan **Detail proyek** pada daftar. Buka bagian **Detail proyek** di halaman proyek. Harapan: nama, deskripsi, tanggal dibuat, tenggat, dan papan proyek tampil.
5. **Kelola kolom dan tugas** — Tekan **Tambah kolom** dua kali. Tekan **Tambah tugas** pada satu kolom, isi judul, deskripsi, dan tenggat, lalu **Buat tugas**. Buka tugas, ubah judul atau deskripsi, tekan **Simpan perubahan**, lalu buka lagi. Harapan: perubahan tersimpan.
6. **Pindahkan tugas** — Buka tugas, pilih kolom kosong pada **Pindahkan tugas**. Coba juga tahan kartu tugas lalu seret ke kolom lain. Harapan: tugas muncul di kolom tujuan dan tetap di sana setelah dimuat ulang.
7. **Kelola anggota dan penanggung jawab** — Tekan **Anggota**, cari akun tes kedua, centang, lalu **Tambah (1)**. Buka tugas, centang anggota di **Penanggung jawab**, lalu **Tugaskan (1)**. Harapan: anggota dan penanggung jawab terlihat setelah dibuka lagi. Hapus penugasan dan anggota tes.
8. **Periksa ringkasan dan analitik** — Buka **Ringkasan** pada papan, lalu kembali ke Home dan buka **Analitik global**. Ubah penanggung jawab tugas, kembali ke Home, lalu buka analitik lagi. Harapan: hitungan analitik berubah setelah dimuat ulang. Jumlah **Belum ditugaskan** tampil sebagai angka.
9. **Coba tema dan ukuran layar** — Tekan ikon tema di kanan atas (juga tersedia di layar masuk dan daftar). Pilih **Sistem**, **Terang**, lalu **Gelap**; setiap pilihan langsung berlaku. Tutup dan buka aplikasi. Harapan: pilihan terakhir tetap aktif. Pilih **Sistem** dan ubah mode gelap Android; tampilan mengikuti. Pada layar kecil atau teks besar, buka proyek dan dialog anggota. Harapan: teks dan tombol tetap terbaca serta bisa dipakai.
10. **Bersihkan data tes** — Hapus tugas, kolom, dan proyek yang kamu buat. Harapan: hanya data tes milikmu yang terhapus.

## Catatan

Fitur yang perlu backend QA aktif: daftar/masuk, proyek, papan, tugas, anggota, penanggung jawab, dan analitik. Tes otomatis sudah mencakup validasi formulir, penanganan sesi/401, kegagalan dan coba lagi, batas layar kecil, serta alur login ke papan. Tes otomatis tidak menggantikan pengecekan langsung di aplikasi.

Backend belum memakai HTTPS dan belum memeriksa izin akses per proyek. Respons anggota juga berisi hash kata sandi. Jangan gunakan akun atau data produksi.
