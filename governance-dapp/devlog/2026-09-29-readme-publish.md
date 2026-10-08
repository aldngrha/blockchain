# 29 Sep 2026 - Project 2: README + Publish

> Task roadmap: "Tulis README governance: cara kerja, parameter yang dipilih dan kenapa, cara buat proposal via frontend. Publish ke Twitter/X + Mirror.xyz. Ini portfolio item ke-2."

## Apa yang dikerjakan

- `README.md` governance-dapp selesai (bagian kontrak ditulis bareng penyelesaian kontrak 24-28 Sep, dirapikan hari ini): arsitektur, parameter beserta alasan angkanya, quickstart (build/test/deploy lokal/frontend), hasil test nyata, status deploy jujur (belum ke Sepolia, command persis sudah tersedia), catatan keamanan (timelock, quorum, renounce admin).
- Section frontend mengarah ke `frontend/README.md` (dikerjakan 25-26 Sep).
- Sama seperti Project 1: publish ke X + Mirror sengaja ditunda sampai repo public ada, karena angka test tanpa link repo = klaim kosong.

## Masalah & Solusi

### README default Foundry nyaris keulang lagi

- Masalah: pola yang sama dengan Project 1 nyaris kejadian lagi: `forge init` meninggalkan README template dan tanpa disiplin, project kedua bakal ke-bagian "README menyusul".
- Kenapa: tumpukan kerja teknis (kontrak, test, wiring) memang lebih menarik daripada dokumentasi, dan template default gak pernah kerasa seperti "utang".
- Solusi: kali ini README jadi bagian dari checklist tugas harian (28-29 Sep), bukan afterthought. DoD di SPEC juga sudah mencantumkannya sejak SPEC ditulis.
- Pelajaran: utang dokumentasi harus masuk DoD di awal project, bukan ditagih di akhir, kalau tidak dia selalu kalah prioritas.

### Menjelaskan parameter governance tanpa terlihat seperti angka arbitrer

- Masalah: "quorum 4%, voting delay 1 hari, voting period 1 minggu" tanpa penjelasan bakal dibaca pembaca sebagai angka acak, padahal itu keputusan desain paling penting di sistem governance.
- Kenapa: angka governance punya trade-off konkret: quorum terlalu rendah = mudah di-takeover proposal kecil, terlalu tinggi = jalan di tempat; delay mem-buffers sistem dari proposal serangan yang di-farm dalam satu transaksi.
- Solusi: di README tiap parameter dipasangkan dengan alasan + referensi praktik yang dipakai protocol besar (angka default ala Compound Governor Bravo), plus section trade-off singkat. Pembaca bisa tak setuju, tapi paham kenapa.
- Pelajaran: parameter governance itu kebijakan, bukan konstanta teknis; dokumentasinya harus membahas kenapa, bukan cuma apa.

### Publish portfolio item kedua tapi belum ada tempat menunjuk

- Masalah: task menyebut publish, tapi dengan pola yang sama dengan Project 1: konten yang mengeklaim kualitas tanpa link repo itu lemah, dan repo belum di-push.
- Kenapa: urutan yang benar adalah repo public dulu, baru konten; kebalikannya mengundang pertanyaan "show me the code" yang gak bisa dijawab.
- Solusi: README selesai dan jadi bahan publish; publish sendiri jadi langkah manual setelah push GitHub (gabung dengan konten Project 1 di `defi-staking/content/` supaya satu gelombang).
- Pelajaran: portfolio itu rantai: repo, lalu konten. Gak bisa dilompati.

## Status jujur

Done:
- README.md governance lengkap dengan alasan parameter, hasil test nyata (33 test), dan status deploy yang jujur.

Belum / butuh aksi manual:
- Push repo ke GitHub, lalu publish ke X + Mirror (bisa digabung dengan draft Project 1 di `defi-staking/content/`).
