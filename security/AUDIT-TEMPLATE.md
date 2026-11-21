# Audit Finding Template

> Task roadmap: 18-19 Okt 2026. Dipakai buat menulis finding waktu ikut audit contest.
>
> Bedanya sama `SECURITY-CHECKLIST.md`: checklist itu buat nyari, template ini buat nulis. Checklist dijawab sebelum mulai review, template ini diisi setelah nemu sesuatu.

## Cara pakai

1. Copy blok di bawah ke file baru, satu finding satu file.
2. Isi semua field. Kalau ada field yang tidak bisa diisi, itu tandanya finding-nya belum matang, bukan tandanya field-nya bisa dilewati.
3. Baca ulang pakai section "Uji sendiri sebelum submit" di bawah.
4. Submit, lalu update statusnya di tracker.

## Template

```markdown
# [Severity] Judul singkat dan spesifik

## Metadata

- Contest / protocol:
- Commit hash / scope file:
- Severity: High | Medium | Low | QA | Gas
- Status: draft | submitted | duplicate | valid | invalid
- Tanggal submit:

## Context

File: path/ke/File.sol
Baris: 123-145
Fungsi: namaFungsi()

```solidity
// potongan kode yang jadi akar masalah, jangan seluruh file
```

## Root cause

Kenapa bug ini ada. Rantai alasannya, bukan cuma gejalanya.

Sebutkan juga: kondisi apa yang harus terpenuhi supaya bug ini aktif. Kalau butuh 5 kondisi bersamaan, tulis kelimanya.

## Impact

Apa yang terjadi kalau dieksploitasi.

- Aset yang terdampak: sebut token/kontrak mana
- Besaran: angka atau persentase, atau "tidak terbatas" kalau memang
- Siapa yang bisa memicu: attacker mana pun, hanya owner, hanya reentrant caller
- Prasyarat: butuh flash loan? butuh jadi LP dulu? butuh waktu tertentu?

## Proof of Concept

Test Foundry yang jalan, atau langkah manual yang bisa direproduksi orang lain.

```solidity
function test_exploit() public {
    // setUp dulu state yang dibutuhkan
    // jalankan serangan
    // assert kerugian
}
```

Kalau PoC belum jalan, tulis eksplisit "PoC belum jalan, ini dugaan berbasis pembacaan kode". Jangan tulis seolah sudah terbukti.

## Recommendation

Fix yang spesifik. Kalau ada beberapa opsi, sebut trade-off-nya.

## Catatan kalau di-mark duplicate

Sebutkan finding siapa yang jadi duplikatnya, dan apa yang bikin versi ini berbeda (kalau memang berbeda).
```

## Severity: cara mutusin

Urutannya: **tentukan dampak dulu, baru cari alasan yang memberatkan atau meringankan.** Jangan mulai dari "ini kelihatan serius".

| Pertanyaan | Kalau ya | Kalau tidak |
|---|---|---|
| Dana bisa dicuri atau hilang? | High | lanjut |
| Protokol bisa insolvent? | High | lanjut |
| Fungsi inti bisa dibikin tidak jalan permanen oleh siapa pun? | High | lanjut |
| Ada value leak, walau kecil? | Medium | lanjut |
| Fungsi rusak sebagian, atau ada kondisi yang bikin rugi? | Medium | lanjut |
| Ada dampak eksternal? | Low | QA |
| Cuma kualitas kode, tidak ada dampak? | QA | Informational |

Catatan penting: **definisi resmi tiap platform beda.** Code4rena dan Sherlock punya definisi severity masing-masing, dan itu yang menang, bukan tabel di atas. Baca halaman severity contest yang sedang diikuti sebelum submit.

## Uji sendiri sebelum submit

Tujuh pertanyaan ini yang paling sering membedakan finding dibayar dan finding dibuang:

1. **Masuk scope?** File dan commit-nya benar? Fungsi yang kena ada di daftar scope?
2. **Root cause-nya satu, bukan tiga?** Kalau satu laporan isinya tiga bug berbeda, judge bakal minta dipecah, atau malah menolak semuanya.
3. **Impact-nya nyata atau cuma teori?** "Attacker bisa..." tanpa langkah konkret itu bukan impact.
4. **PoC-nya jalan?** Kalau tidak, apakah sudah dibilang jujur bahwa belum jalan?
5. **Sudah dicek ke kontrak lain?** Banyak finding gugur karena ternyata ada check di caller atau di kontrak lain yang nutup jalannya.
6. **Sudah baca dokumentasi protokolnya?** Ada kasus di mana perilaku yang kelihatan bug ternyata desain yang disengaja dan didokumentasikan. Contoh nyata: Venus Protocol (2026), contest menandai risikonya, tim bilang itu memang desain yang dipilih.
7. **Sudah cari duplikat di submission publik?** Kalau platformnya nampilin submission orang lain, cek dulu. Yang pertama submit biasanya menang.

## Anti-pattern yang bikin finding ditolak

- **Judul generik.** "Access control issue" tidak memberi judge alasan buat membaca.
- **Impact tanpa angka.** "Bisa rugi besar" tidak bisa dinilai. Sebut aset dan besaran.
- **PoC yang cuma `console.log`.** Itu bukan bukti.
- **Menyerang kode di luar scope.** Sepadan dengan tidak submit.
- **Menggabung banyak temuan jadi satu.** Turunkan severity, dan sering bikin semuanya ditolak.
- **Klaim yang tidak diverifikasi.** Kalau lo bilang "ini bisa dipanggil siapa pun", pastikan sudah dicoba dari akun lain.
- **Nyalahin hal yang sudah didokumentasikan sebagai known issue.** Baca README dan known-issues dulu.

## Workflow satu sesi contest

1. Baca semua dokumentasi protokol dan daftar scope. Belum review kode satu baris pun.
2. Gambar alur dana: uang masuk dari mana, keluar ke mana, siapa yang bisa memicu tiap fungsi.
3. Jalankan checklist di `SECURITY-CHECKLIST.md`, dicentang per fungsi yang menangani dana.
4. Tulis finding pakai template ini sambil jalan, jangan ditunda sampai akhir. Detail gampang lupa.
5. Sebelum submit, jalankan "Uji sendiri sebelum submit".
6. Submit, lalu lanjut cari lagi. Contest menang dari volume dan kualitas sekaligus, dan yang submit cuma satu finding hampir tidak pernah menang.

## Tracker

Simpan daftar finding di tabel ini biar tidak ada yang kelupaan:

| # | Judul | Severity | File | Status | PoC jalan? |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 | | | | | |
