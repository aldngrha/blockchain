# 9 Okt 2026 - AMM: Demo Script + Draft Artikel Mirror

> Task roadmap: "Tulis README AMM yang comprehensive. Buat demo video Loom: explain AMM concept, demo swap, demo add/remove liquidity. Publish artikel teknis di Mirror.xyz tentang cara implement AMM."

## Apa yang dikerjakan

- `content/demo-script.md`: script rekaman Loom 3-5 menit dengan blok waktu (konsep AMM 45 detik, demo swap, demo add/remove liquidity), langkah klik yang konkret, dan kalimat yang bisa dibacakan langsung. Semua angka di script berasal dari simulasi sendiri: pool 1000/1000, swap 10 SDA = 9.871580343970612988 SDB (impact 1.28%), swap 300 SDA = 230.236317450542683396 SDB (impact eksekusi 23.25%, marginal 40.78%), plus state lanjutan dari smoke test 7 Okt (reserves 1025 / 975.681147401029343611) untuk skenario add 500 SDA (saran 475.942023122453338346 SDB, LP 487.804878048780487804) dan remove setengahnya (payout 249.999999999999999999 SDA + 237.971011561226669172 SDB). Angka-angka itu dihitung ulang dengan mirror JS yang sudah tervalidasi 26 vektor dan lulus smoke test on-chain.
- `content/mirror-article-draft.md`: draft artikel 1.018 kata berjudul "Cara Implement AMM dari Scratch: Pelajaran dari Build SimpleDex". First person, proses over hasil: turunan formula `dy = y*dx/(x+dx)` dengan fee 997/1000 di sisi input, cerita fuzz overflow 2 Okt (panic 0x11 dengan counterexample asli, keputusan dokumentasi domain bukan patch math), pembulatan yang selalu menguntungkan pool (floor output, ceil input +1, guard dust di pair), dan mirror frontend (BigInt JS = EVM division). Semua angka di artikel reproduce-able: vektor test yang ada di suite, counterexample fuzz yang tercatat di devlog, dan jumlah test (53).
- README root ("Tulis README AMM yang comprehensive") sudah dikerjakan agent lain dan ada di `README.md` root; tugas gw di sini cuma `frontend/README.md` (selesai 7-8 Okt) plus dua konten di atas, jadi tidak ada pekerjaan README yang diduplikasi.

## Masalah & Solusi

### Angka demo: godaan menulis angka yang "kelihatannya masuk akal"

- Masalah: script demo butuh angka untuk dibacakan (output swap, impact, payout). Cara cepatnya mengarang angka bulat yang meyakinkan, tapi itu melanggar aturan project: tanpa angka yang gak dihitung.
- Kenapa: angka demo dari karangan akan langsung kelihatan gak cocok saat user merekam (UI menampilkan angka asli dari chain), dan artikel yang mengutipnya ikut gak bisa direproduksi.
- Solusi: semua angka dihitung dari mirror JS yang sama yang dipakai UI (terverifikasi 26 vektor test + bit-exact vs on-chain di smoke test 7 Okt), lalu dicatat di script dengan konteks state pool-nya. Ada dua timeline pool yang disebut eksplisit di script: pool awal 1000/1000 (segar dari deploy) dan pool setelah smoke swap 25 SDA (1025 / 975.681...), supaya user yang merekam tahu skenario mana yang angkanya akan muncul persis.
- Pelajaran: angka demo itu artefak yang diuji, bukan copywriting; kalau angkanya gak bisa dihitung ulang dari state yang jelas, gak layak dibacakan di video.

### Rekam Loom dan publish Mirror: dua aksi yang gak bisa gw eksekusi

- Masalah: task roadmap 9 Okt adalah merekam video dan publish artikel. Subagent ini gak punya GUI, mikrofon, akun Loom, maupun wallet Mirror, jadi dua langkah terakhir dari task itu mustahil dieksekusi dari sini.
- Kenapa: keterbatasan environment, bukan kelengahan kerja. Yang bisa diproduksi tanpa GUI adalah artefak yang siap dieksekusi: script per menit + langkah klik + kalimat pembuka, dan draft artikel final yang tinggal di-paste.
- Solusi: kedua file ditulis dengan asumsi "perekam = user": demo script punya checklist prasyarat (anvil jalan di 8548, deploy script sudah dijalankan, wallet import key anvil) dan blok waktu dengan kata-kata yang bisa dibacakan; artikel draft sudah melewati hitungan kata dan cek gaya, tinggal review manual lalu publish. Status "butuh aksi manual" dicatat jujur di bawah.
- Pelajaran: kalau sebagian task di luar kendali, deliverable yang jujur adalah artefak eksekusi (script, draft, checklist), bukan klaim bahwa videonya sudah ada.

### Draft artikel: menahan diri dari klaim yang gak bisa dibuktikan

- Masalah: menulis artikel pengalaman gampang melorot ke klaim kosong ("production-ready", "amannya teruji", "gas efficient"). Semua itu gak bisa gw buktikan: kontraknya unaudited, gas snapshot L1 vs L2 belum diambil (devlog 6 Okt mencatat ini), dan "teruji" hanya sampai sejauh suite testnya.
- Kenapa: R-36 dan aturan project melarang klaim tanpa bukti; artikel yang menarik justru karena spesifik, bukan karena superlatif.
- Solusi: draft dibatasi ke tiga jenis kalimat: (1) apa yang benar-benar dikerjakan dengan angka yang bisa direproduksi (vektor 9066108938801491315, counterexample fuzz, 53 test), (2) keputusan beserta alasannya (domain uint112, floor/ceil, guard di pair bukan library), (3) batasan yang diakui eksplisit (gak ada audit, gak ada factory, gak ada TWAP, test reentrancy end-to-end belum ada). Kata "aman" hanya dipakai mengutip properti yang diuji (k gak pernah turun dalam domain), bukan menilai keseluruhan sistem.
- Pelajaran: proses over hasil bukan gaya penulisan semata, ia adalah mekanisme penyaring klaim: ceritakan keputusan dan buktinya, dan bagian yang belum dibuktikan sebut sebagai yang belum dibuktikan.

## Status jujur

Done:
- `content/demo-script.md` dan `content/mirror-article-draft.md` selesai, angka terverifikasi dari simulasi, gaya konsisten (Bahasa Indonesia santai, tanpa emoji, tanpa em dash, tanpa klaim tak terbukti).
- Verifikasi build/lint frontend masih lulus (tidak berubah dari 8 Okt).

Menunggu / butuh aksi manual (semuanya milik user):
- Rekam video Loom (ikuti `content/demo-script.md`), upload, dan taruh link di README root kalau mau.
- Review draft artikel, lalu publish ke Mirror.xyz.
- Deploy frontend ke Vercel dari task 8 Okt (masih tertunda, manual).
- Klik-through browser pertama dengan MetaMask sebelum merekam, supaya flow yang direkam sudah lewat satu sesi uji manusia.
