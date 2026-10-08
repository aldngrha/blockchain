# 20 Sep 2026: Governance Research (Compound Bravo vs OZ Governor)

> Task roadmap: "Min 20 Sep, MINGGU, Project 2: Governance Research. Research untuk Project 2. Baca Compound Governor Bravo source code. Pahami full governance lifecycle: propose -> voting period -> timelock -> execute. Identifikasi semua parameter: quorum, threshold, voting period."

## Apa yang dikerjakan

- Baca source Compound Bravo (`GovernorBravoDelegate`) dan OZ Governor v5.4 (`governance/` di lib, bukan dari dokumentasi).
- Petakan lifecycle lengkap: propose -> Pending -> Active -> Succeeded/Defeated -> queue -> timelock delay -> execute, plus Canceled/Expired.
- Kumpulin parameter nyata dari protokol lain buat pembanding: Compound quorum 2.5% + threshold 25.000 COMP, Uniswap 4%, ENS 1%.
- Tulis `docs/research-governance.md` sebagai bahan SPEC besok.

## Masalah & Solusi

### Pilih clock mode: block number atau timestamp

- Masalah: OZ v5 mendukung ERC-6372, clock bisa block number atau timestamp. Bravo cuma block number. Pilihan ini menentukan semua parameter lain (delay/period dalam block atau detik) dan cara test (vm.roll vs vm.warp).
- Kenapa penting: kalau pilih timestamp, voting delay "1 hari" jadi 86400 detik dan gak perlu asumsi 12 detik/blok. Kalau pilih block number, angka roadmap (7200/50400) langsung nyambung ke asumsi 12s/blok dan bisa diwarp di test dengan vm.roll.
- Solusi: pakai default ERC20Votes (block number). Roadmap sudah menulis parameter dalam block, dan snapshot per block lebih granular buat demo. Konsekuensinya dicatat: timelock tetap timestamp-based, jadi test harus roll DAN warp untuk state beda.
- Pelajaran: dua domain waktu (block buat voting, timestamp buat timelock) itu desain bawaan OZ, bukan kecelakaan. Baca ini duluan menghemat bingung berjam-jam pas nulis test.

### Threshold 0 atau di atas 0

- Masalah: proposalThreshold > 0 butuh distribusi token yang sehat sebelum governance bisa dipakai. Supply fixed 1M ke deployer berarti threshold apa pun bikin cuma deployer yang bisa propose di awal.
- Kenapa: demo governance yang cuma bisa dijalankan satu address itu gak menunjukkan apa-apa.
- Solusi: threshold 0, siapa pun boleh propose. Risiko spam proposal diakui dan ditulis di SPEC sebagai known trade-off (naikkan lewat `setProposalThreshold` via proposal untuk produksi).
- Pelajaran: parameter governance itu trade-off UX vs keamanan, dan nilai "aman" untuk mainnet sering gak cocok buat demo. Tulis alasannya, jangan cuma angkanya.

### Siapa yang pegang dana: governor atau timelock

- Masalah: desain naif naruh ETH di governor, tapi `GovernorTimelockControl` secara eksplisit mengarahkan agar dana dan permission ada di timelock (dari doc-nya: "the assets and permissions must be attached to the TimelockController").
- Kenapa: kalau dana di governor, eksekusi lewat `Governor.execute()` langsung, dan timelock cuma formalitas. Exit window hilang.
- Solusi: bikin `Treasury.sol` terpisah yang `execute()`-nya di-guard `msg.sender == timelock` (immutable), dan timelock yang jadi satu-satunya executor proposal.
- Pelajaran: arsitektur governance yang benar itu 4 lapis (token -> governor -> timelock -> target), bukan 3. Lapis target (Treasury) yang di-guard ke timelock itu yang bikin keamanan real.

## Status jujur

- Done: research doc (`docs/research-governance.md`), semua parameter dipilih dengan alasan, keputusan arsitektur 4 kontrak final.
- Belum: SPEC belum ditulis (besok), belum ada satu baris Solidity pun. Itu sesuai jadwal.
