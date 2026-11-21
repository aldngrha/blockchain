# Cara Kerja Audit Contest (Code4rena vs Sherlock)

> Task roadmap: 17 Okt 2026, "Code4rena / Sherlock Intro". Catatan riset, bukan hasil ikut contest.
>
> Sumber utama: guide perbandingan platform kompetitif (smartcontractaudit.com, diakses 12 Okt 2026) plus dokumentasi publik masing-masing platform. Angka yang ditulis di sini berasal dari sumber itu, bukan hasil pengukuran sendiri. Kalau nanti ikut contest beneran dan ketemu angka beda, catatan ini yang perlu diupdate.

## Konsep dasarnya

Competitive audit (audit contest) itu audit yang dijalankan banyak peneliti independen secara paralel dalam window waktu tetap. Semua orang baca codebase yang sama, cari bug, lalu submit finding. Setelah window tutup, finding dinilai (judging) dan yang valid dibagi ke prize pool sesuai bobot severity.

Bedanya sama private audit (model Spearbit, Trail of Bits, dsb): di private audit lo bayar satu tim untuk waktu mereka. Di contest, lo bayar satu prize pool dan dapat banyak mata. Trade-off-nya jelas: contest dapat breadth (banyak sudut pandang), private audit dapat depth (satu tim yang ngerti arsitektur sampai dalam).

Yang sering dilupain: dua-duanya best-effort. Contest yang rame bukan jaminan aman.

## Empat platform yang relevan

| Dimensi | Code4rena | Sherlock | Codehawks (Cyfrin) | Cantina (Spearbit) |
|---|---|---|---|---|
| Mulai | 2021 (pelopor) | - | 2023 | - |
| Kolam peneliti | 4.500+ warden, terbuka | Watsons terkurasi | Fokus kualitas | Aplikasi dulu, jaringan Spearbit 50+ |
| Model lead auditor | Judge saja | Ada lead Watson | Judge saja | Bisa lead Spearbit |
| Exploit coverage | Tidak | Ya (unik) | Tidak | Tidak |
| Transparansi harga | Tinggi | Lebih rendah | Tinggi | Menengah |
| Kedalaman rekam jejak | Paling panjang | Menengah | Paling baru | Menengah |

Dua yang paling sering dipakai buat mulai: **Code4rena** (paling banyak warden, jadi kompetisi paling keras tapi juga paling banyak data historis) dan **Sherlock** (model lead Watson plus exploit coverage).

Yang paling penting buat pemula dari tabel itu: **Codehawks punya First Flight**, program yang memang ditujukan buat peneliti baru. Code4rena dan Cantina cenderung lebih keras buat pemula.

## Alur satu contest

1. **Scope.** Platform publish repo, commit hash, dan daftar file yang masuk scope. Baca ini dulu sampai paham. File di luar scope bukan finding, mau sebagus apa pun.
2. **Window.** Biasanya 1 sampai 4 minggu, tergantung ukuran codebase. Setelah tutup, tidak ada submission baru.
3. **Submission.** Tiap finding masuk sebagai satu laporan terpisah, bukan satu dokumen gabungan.
4. **Judging.** Ada judge (C4) atau lead Watson (Sherlock) yang menilai tiap finding: valid atau tidak, severity-nya apa, dan duplikat atau bukan.
5. **Deduplikasi.** Kalau 5 orang nemu bug yang sama, yang dianggap cuma satu finding. Yang menentukan siapa dapat bagian biasanya yang submit pertama, atau kualitas PoC-nya.
6. **Payout.** Prize pool dibagi sesuai bobot severity dan jumlah finding valid. `High` dapat porsi jauh lebih besar dari `Medium`. `Low`/`QA` biasanya masuk pool kecil terpisah atau tidak dibayar sama sekali.

Konsekuensi praktis dari dedup: **kecepatan dan kualitas PoC itu dua hal yang bernilai uang.** Nemu bug duluan tapi laporannya cuma satu paragraf bisa kalah dari yang nemu belakangan tapi PoC-nya rapi.

## Severity: model umum

Definisi persisnya beda per platform, jadi **selalu baca definisi severity contest yang sedang diikuti**, jangan pakai hafalan. Tapi kerangkanya kurang lebih:

- **High.** Dana bisa hilang atau dicuri, protokol bisa insolvent, atau fungsi inti bisa dibikin tidak jalan permanen oleh siapa pun. Contoh: reentrancy yang bisa drain, access control bolong di fungsi penarik dana, oracle manipulation yang bisa dipakai buat mint gratis.
- **Medium.** Dana tidak langsung berisiko, tapi ada value leak, fungsi rusak sebagian, atau kondisi tertentu yang bisa bikin rugi. Contoh: pembulatan yang menguntungkan satu pihak, DoS yang butuh kondisi khusus, griefing yang murah.
- **Low / QA.** Tidak ada dampak eksternal. Contoh: state yang tidak pernah dibersihkan, event yang kurang parameter, kurang validasi input yang tidak bisa dieksploitasi.
- **Gas / Informational.** Optimasi dan saran gaya. Biasanya pool terpisah.

Satu pelajaran yang sering bikin kaget pemula: **yang menentukan severity itu dampak, bukan kerumitan.** Bug satu baris di access control bisa `High`. Refactor besar yang bikin kode lebih rapi bisa `Informational`.

## Format finding

Struktur yang diterima hampir semua platform:

1. **Title.** Satu baris, spesifik. "Missing access control on `withdraw()` lets anyone drain the vault", bukan "Access control issue".
2. **Severity.** High / Medium / Low, sesuai definisi platform.
3. **Context.** Path file plus nomor baris, dan commit hash. Tanpa ini finding susah diverifikasi.
4. **Description / Root cause.** Kenapa bug ini ada. Rantai alasannya, bukan cuma gejalanya.
5. **Impact.** Apa yang terjadi kalau dieksploitasi. Sebut aset mana dan berapa besar.
6. **Proof of Concept.** Test Foundry yang jalan, atau langkah manual yang bisa direproduksi. Ini yang paling sering membedakan finding yang dibayar dan yang dibuang.
7. **Recommendation.** Cara fix yang spesifik.

Template yang bisa langsung dipakai ada di `security/AUDIT-TEMPLATE.md`.

## Reality check: contest tidak mencegah exploit

Ini bagian yang paling penting dan paling sering dilewatkan. Tiga studi kasus dari sumber riset:

- **Euler Finance, $197 juta (2023).** Sherlock memberi exploit coverage, dan klaimnya dibayar sekitar $4,5 juta. Artinya coverage jalan, tapi artinya juga exploitnya kejadian.
- **KyberSwap, $48 juta (2023).** Sebuah edge case pembulatan tick math. Diatribusikan bersama dengan ChainSecurity.
- **Cork Protocol, $12 juta (2025).** Terjadi walaupun sudah lewat empat review independen, termasuk Spearbit dan bug bounty Cantina $100 ribu. Logic flaw yang dieksploitasi tidak ketemu di satu pun review itu.
- **Venus Protocol, $3,7 juta (2026).** Ini kebalikannya: contest Code4rena **berhasil** menandai risiko persis yang nanti dieksploitasi. Tim protokol memutuskan tidak memperbaiki, dengan alasan itu perilaku desain yang disengaja. Proses contest-nya jalan, keputusan risk acceptance-nya yang gagal.

Pola dari keempatnya: contest memindahkan risiko, tidak menghapusnya. Yang bisa diharapkan dari ikut contest adalah **skill** dan **rekam jejak**, bukan jaminan protokol jadi aman.

## Strategi buat yang baru mulai

1. **Mulai dari scope kecil dan codebase yang lo ngerti domainnya.** Codebase lending atau DEX lebih ramah buat lo yang udah bikin `defi-staking`, `governance-dapp`, dan `simple-dex` sendiri. Baca dulu dokumentasi protokolnya sampai paham alur dana, baru cari bug.
2. **Baca 2-3 write-up finding juara sebelum ikut.** Format dan level kedalaman yang diharapkan jadi jelas setelah baca, dan tidak jelas sebelum itu.
3. **Kejar `Medium` dulu, jangan `High`.** Finding `Medium` yang valid dan PoC-nya rapi jauh lebih sering dibayar daripada finding `High` yang cuma dugaan.
4. **Submit `Low`/`QA` juga.** Pool-nya kecil, tapi ini latihan menulis laporan dan bikin lo kebiasa nyisir detail.
5. **Catat semua yang lo periksa, termasuk yang bersih.** Yang bersih itu bahan checklist pribadi, dan checklist itu yang bikin putaran berikutnya lebih cepat.

## Yang belum dikerjakan

- Ikut contest sungguhan: butuh akun platform aktif dan pemilihan contest yang cocok. Ini aksi manual, tidak bisa diotomatiskan dari sini.
- Refinement checklist audit personal: nanti di `security/AUDIT-TEMPLATE.md` dan `security/SECURITY-CHECKLIST.md`.
