# 21 Sep 2026: Spec + Architecture

> Task roadmap: "Sen 21 Sep, GYM HARI, Project 2: Spec + Architecture. Tulis spec lengkap Project 2 Governance dApp: GovernanceToken (ERC-20Votes), Governor, TimelockController. Architecture diagram. Define semua parameter: quorum 4%, voting delay 1 hari, voting period 1 minggu."

## Apa yang dikerjakan

- Tulis `SPEC.md` lengkap: goal/non-goal, diagram arsitektur 4 kontrak, tabel fungsi per kontrak, override matrix OZ v5, tabel edge case E1-E14, fuzz plan, deployment plan, definition of done.
- Fix angka parameter produksi: quorum 4%, voting delay 7200 block, voting period 50400 block, timelock 1 hari, supply 1.000.000 GT, threshold 0.
- Tentukan nilai test (delay 2 block, period 10 block, minDelay 1 detik) yang dipisah dari nilai produksi, dan deploy script yang menerima nilai produksi.

## Masalah & Solusi

### Quorum dihitung dari supply mana

- Masalah: `GovernorVotesQuorumFraction.quorum(timepoint)` menghitung `getPastTotalSupply(timepoint) * numerator / denominator`. Supply LAMA di snapshot, bukan supply sekarang. Salah paham di sini bikin proposal "gak lolos quorum padahal supplynya cukup" atau sebaliknya.
- Kenapa: checkpoint supply itu historis. Kalau ada burn setelah propose, quorum proposal itu gak ikut turun. Desainnya sengaja supaya quorum gak bisa dimanipulasi supply yang berubah di tengah jalan.
- Solusi: kontrak gak punya burn/mint setelah deploy, jadi past supply = 1M selalu, quorum konstan 40.000 GT. Tapi test tetap menulis `governor.quorum(snapshot)` dengan snapshot block, bukan angka literal sembarangan, biar semantiknya kebaca.
- Pelajaran: parameter yang kelihatan "4% dari supply" itu sebenarnya fungsi dari timepoint. Baca source quorum() sebelum nulis angka di spec.

### Delay/period test vs produksi, satu konfigurasi atau dua

- Masalah: kalau test pakai angka produksi (7200 + 50400 block), satu test butuh 57.600 vm.roll dan suite jadi lambat serta rapuh. Kalau kontrak test pakai angka kecil, ada risiko yang di-deploy adalah kontrak dengan angka kecil (lupa ganti).
- Kenapa: dua sumber kebenaran itu bug klasik.
- Solusi: satu kontrak yang sama, parameter masuk lewat constructor. Test hardcode nilai kecil di konstanta test, deploy script hardcode nilai roadmap. Gak ada kontrak kedua, gak ada flag. Ditambah test `test_GovernorParameters` yang assert parameter sesuai yang diberikan.
- Pelajaran: parameter = data, bukan kode. Semua angka governance masuk constructor, biar test dan produksi beda data doang.

### Ukuran kontrak Governor sudah kelihatan jadi risiko sejak spec

- Masalah: governor OZ dengan 5 mixin terkenal besar. Ada kemungkinan kena EIP-170 (24.576 bytes runtime) terutama tanpa via-ir.
- Kenapa: kalau baru sadar pas deploy, setting compiler jadi keputusan terburu-buru.
- Solusi: dicatat di SPEC section keamanan bahwa konfigurasi compiler (via-ir, optimizer_runs) adalah bagian dari deliverable, dan verifikasi ukuran bytecode jadi bagian dari gate deploy.
- Pelajaran: buat kontrak besar, ukuran bytecode itu persyaratan teknis di level spec, bukan detail opsional. (Ternyata di hari deploy ini benar-benar meledak, lihat devlog 28 Sep.)

## Status jujur

- Done: SPEC.md final dengan semua keputusan terdokumentasi, siap implementasi besok.
- Belum: belum ada kode, semua angka masih di atas kertas. Itu memang isi hari ini.
