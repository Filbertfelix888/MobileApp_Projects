# Panduan Tes Manual

Gunakan **QA** dan akun/proyek tes sementara. Jangan pakai data produksi. Proyek QA lama bernama `Smoke project` dan dua akun tes sudah ada; jangan hapus jika bukan milikmu.

Ikuti urutan ini. Cocokkan hasil setelah setiap langkah.

1. **Daftar akun** — Di layar masuk, pilih QA. Buat dua akun tes dengan email berbeda. Harapan: setiap pendaftaran berhasil dan kembali ke layar masuk.
2. **Masuk dan keluar** — Masuk dengan akun tes pertama. Tutup lalu buka aplikasi. Harapan: sesi tetap masuk. Pilih **Keluar**. Harapan: layar masuk tampil. Masuk lagi dengan akun tes pertama.
3. **Buat dan cari proyek** — Buat proyek tes dengan nama unik, deskripsi, dan tenggat. Cari nama proyek itu, lalu hapus pencarian. Harapan: proyek muncul dan pencarian menampilkan hasil yang cocok.
4. **Buka proyek** — Tekan **Detail proyek**. Harapan: nama, deskripsi, tanggal, dan papan proyek tampil.
5. **Kelola kolom dan tugas** — Buat dua kolom. Buat tugas dengan judul, deskripsi, dan tenggat. Ubah tugas, simpan, lalu buka lagi. Harapan: perubahan tersimpan.
6. **Pindahkan tugas** — Gunakan **Pindahkan tugas** untuk memindahkannya ke kolom kosong. Harapan: tugas muncul di kolom tujuan setelah dimuat ulang.
7. **Kelola anggota dan penanggung jawab** — Cari akun tes kedua di **Anggota**, tambahkan ke papan, lalu tugaskan ke tugas. Harapan: anggota dan penanggung jawab terlihat setelah dibuka lagi. Hapus penugasan dan anggota tes.
8. **Periksa ringkasan dan analitik** — Buka **Ringkasan** pada papan, lalu kembali ke Home dan buka **Analitik global**. Ubah penanggung jawab tugas, kembali ke Home, lalu buka analitik lagi. Harapan: hitungan analitik berubah setelah dimuat ulang.
9. **Coba tema dan ukuran layar** — Ganti tema terang/gelap. Pada layar kecil atau teks besar, buka proyek dan dialog anggota. Harapan: teks dan tombol tetap terbaca serta bisa dipakai.
10. **Bersihkan data tes** — Hapus tugas, kolom, dan proyek yang kamu buat. Harapan: hanya data tes milikmu yang terhapus.

## Catatan

Fitur yang perlu backend QA aktif: daftar/masuk, proyek, papan, tugas, anggota, penanggung jawab, dan analitik. Tes otomatis sudah mencakup validasi formulir, penanganan sesi/401, kegagalan dan coba lagi, batas layar kecil, serta alur login ke papan. Tes otomatis tidak menggantikan pengecekan langsung di aplikasi.

Backend belum memakai HTTPS dan belum memeriksa izin akses per proyek. Respons anggota juga berisi hash kata sandi. Jangan gunakan akun atau data produksi.
