# 18 Sep 2026 - Project 1: README + GitHub

> Task roadmap: "Tulis README comprehensive: arsitektur diagram, cara deploy lokal, cara run tests, cara interact dengan kontrak, screenshot frontend, link demo video. Ini yang dilihat recruiter/client pertama kali."

## Apa yang dikerjakan

- `README.md` di-rewrite total. Sebelumnya isinya masih template default Foundry (penjelasan "Foundry is a blazing fast...", instruksi Counter.s.sol) yang tidak mengandung satu pun informasi tentang project-nya sendiri.
- Struktur README baru: deskripsi satu paragraf, diagram arsitektur, section "Desain dan trade-off" (dipromosikan dari SPEC §5, karena ini yang membedakan README bagus dari README tutorial), hasil test dengan angka nyata, quickstart, deploy lokal + frontend, deploy Sepolia, struktur repo.
- Angka yang ditulis semua dari run sungguhan hari ini: 75 test hijau (`forge test`), coverage `forge coverage`: RewardToken 100% (9/9 statement), StakingPool 100% (75/75 statement, 13/13 branch).
- Untuk GitHub repo + push: karena workspace ini tidak di-init git per project, langkah `git init`, commit, dan push ke GitHub adalah langkah manual (lihat Status jujur).

## Masalah & Solusi

### README default Foundry masih tertinggal sejak `forge init`

- Masalah: README masih 100% template default Foundry, termasuk instruksi deploy `Counter.s.sol` yang tidak pernah ada di project ini. Calon recruiter yang buka repo bakal langsung tahu itu "project hasil `forge init` yang belum dirapikan".
- Kenapa: `forge init` menghasilkan README generic dan sampai 15 Sep prioritas tetap di kontrak + test (sudah benar, DoD SPEC baru minta README hari ini), tapi jangan sampai lupa karena ini hal pertama yang dilihat orang.
- Solusi: rewrite penuh dengan struktur: apa ini, arsitektur, trade-off, angka test nyata, cara jalanin, status deploy. Semua angka hasil run sendiri, bukan dikopi.
- Pelajaran: README bukan dokumentasi opsional di akhir; ia bagian dari definisi "selesai" karena mengubah project dari latihan jadi portfolio.

### Godaan menulis angka yang belum di-run

- Masalah: dari SPEC, target coverage adalah 95%, dan sangat menggoda menulis "coverage > 95%" tanpa bukti. Sama dengan jumlah test yang berubah-ubah sepanjang 12-15 Sep.
- Kenapa: klaim tanpa run mudah keliru dan kalau ketahuan salah satu angka, kredibilitas seluruh README jatuh. Ini juga pola yang sama dengan klaim marketing palsu: angka tanpa sumber.
- Solusi: jalankan `forge test` dan `forge coverage` hari ini juga, tulis hasil persisnya (75 test, 100% di kedua kontrak utama, 86.81% total karena file script/mocks ikut terhitung), dan sebut perintahnya supaya bisa direproduksi.
- Pelajaran: untuk portfolio, angka yang bisa direproduksi dengan satu command lebih bernilai daripada angka besar yang tidak bisa diverifikasi.

### Status deploy yang belum ada (belum ke Sepolia)

- Masalah: recruiter suka link live, tapi deploy Sepolia butuh private key + RPC yang tidak boleh dibuat-buat dan memang belum dieksekusi. Menaruh address palsu atau "coming soon" yang menggantung dua-duanya buruk.
- Kenapa: mengarang address = fabricate; `0x0000...` = kelihatan broken. README yang jujur soal status justru menunjukkan proses kerja yang benar.
- Solusi: section Deploy Sepolia menyimpan command persis yang dipakai nanti dan satu kalimat status eksplisit ("belum terdeploy, address ditulis setelah deploy sungguhan"). Setelah deploy, tinggal update section itu.
- Pelajaran: placeholder yang jujur dan actionable lebih baik daripada konten yang menggantung atau mengarang.

### Screenshot frontend dan link demo video belum bisa dimasukkan

- Masalah: task roadmap menyebut screenshot frontend dan link demo video, tapi frontend baru selesai dibangun 16 Sep dan belum ada address Sepolia untuk deployment yang stabil.
- Kenapa: screenshot dari build lokal bisa saja, tapi gambar yang lebih bermakna adalah frontend yang terhubung ke kontrak ter-deploy, bukan ke anvil yang mati setelah laptop dimatikan.
- Solusi: README sekarang mengarah ke `frontend/README.md` untuk demo lokal (reproducible via anvil), screenshot + link video dijadwalkan setelah deploy Sepolia + Vercel (lanjutan task 17 Sep yang memang masih menunggu aksi manual).
- Pelajaran: deliverable yang bergantung ke infrastruktur live sebaiknya dijadwalkan eksplisit, bukan dihanguskan demi "selesai hari ini".

## Status jujur

Done dan terverifikasi:
- README.md baru selesai (66 baris template default diganti ~100 baris konten nyata).
- Angka test dan coverage berasal dari run hari ini, command tercantum di README.

Belum / butuh aksi manual:
- `git init` + repo GitHub + push pertama (workspace belum jadi git repo; keputusan nama repo, visibility, dan akun ada di tangan pemilik).
- Screenshot frontend + link Loom (setelah deploy Sepolia/Vercel).
