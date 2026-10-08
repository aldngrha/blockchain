# 23 Sep 2026: Governor Contract

> Task roadmap: "Rab 23 Sep, GYM HARI, Project 2: Governor Contract. Implement Governor pakai OpenZeppelin Governor framework. Configure: GovernorSettings (delay, period, threshold), GovernorCountingSimple (for/against/abstain), GovernorVotes, GovernorTimelockControl."

## Apa yang dikerjakan

- `src/GovernorContract.sol`: 5 mixin (Governor, GovernorSettings, GovernorCountingSimple, GovernorVotesQuorumFraction, GovernorTimelockControl), name "Governance DApp Governor", threshold 0.
- Menentukan override matrix yang benar untuk OZ v5.4 dengan eksperimen compile, bukan tebakan.
- Test parameter + quorum: `test_GovernorParameters`, `test_QuorumIs4PercentOfPastSupply` (quorum 40.000 GT di snapshot).

## Masalah & Solusi

### Base constructor `GovernorVotes` gak ke-import, build pertama gagal

- Masalah: `GovernorVotes(_votes)` di daftar initializer error `Error (9582): Identifier not found`. Padahal `GovernorVotesQuorumFraction` jelas mewarisinya.
- Kenapa: initializer base di Solidity butuh identifier yang in-scope di file kontrak. Mewaris "via kelas lain" gak otomatis mengimpor nama kelasnya.
- Solusi: tambah `import {GovernorVotes} from "openzeppelin-contracts/governance/extensions/GovernorVotes.sol";`.
- Pelajaran: daftar import = daftar semua base yang di-initialize secara eksplisit, bukan cuma yang ada di `is`.

### Override matrix v5.4: `proposalThreshold` wajib, `votingDelay` gak

- Masalah: gw awalnya menulis override lengkap ala wizard v5 (state, proposalNeedsQueuing, proposalThreshold, _queueOperations, _executeOperations, _cancel, _executor) TANPA votingDelay/votingPeriod/quorum, terus ragu dan penasaran kenapa asimetris. Uji: hapus override `proposalThreshold`, compile.
- Kenapa (dari error compiler + source): core `Governor.proposalThreshold()` punya DEFAULT BODY (`return 0`), jadi ada dua implementasi concrete di DAG (core + GovernorSettings) dan turunan wajib re-override dengan `override(Governor, GovernorSettings)`. Sedangkan `votingDelay()`/`votingPeriod()`/`quorum()` di core abstract murni (tanpa body), linearization otomatis ambil versi modul.
- Solusi: matrix final: state, proposalNeedsQueuing, proposalThreshold, _queueOperations, _executeOperations, _cancel, _executor. Compile bersih. Error compiler yang jadi bukti:
  `Error (6480): Derived contract must override function "proposalThreshold". Two or more base classes define function with same name and parameter types.`
- Pelajaran: abstrak vs concrete di base menentukan kebutuhan override. Kata "ikuti contoh resmi" itu benar, tapi paham KENAPA matrix-nya segitu bikin gak goyah saat upgrade OZ.

### Access `VoteType` harus via kontrak yang mendeclare, bukan kontrak turunan

- Masalah: `GovernorContract.VoteType.For` di test error `Member "VoteType" not found`. Enum dideclare di `GovernorCountingSimple`, dan Solidity gak mengizinkan akses member enum via kelas turunan.
- Kenapa: member enum diakses via kontrak yang secara literal mendeclare-nya (atau via alias import-nya), meskipun turunan mewarisi enum itu.
- Solusi: `GovernorCountingSimple.VoteType.For` + import extension-nya di file test.
- Pelajaran: kecil, tapi makan waktu kalau gak nyangka. Pattern yang sama menimpa `IERC20.transfer` di calldata fuzz (`abi.encodeCall(IERC20.transfer, ...)`).

### Non-delegated voter: weight 0 tanpa revert

- Masalah: gw sempat nulis ekspektasi vote oleh holder tanpa delegation itu revert. Ternyata `_castVote` sukses dengan weight 0 (bobot diambil dari checkpoint snapshot yang memang 0).
- Kenapa: core Governor gak punya aturan "harus punya bobot untuk vote". Verifikasi di `_castVote`: ambil `totalWeight` dari `_getVotes`, lalu `_countVote` menambahkan apa adanya (0).
- Solusi: test diubah: `castVote` oleh holder 5.000 GT (gak delegate) mengembalikan 0, tally gak berubah. Jadi `test_NonDelegatedHolderVotesWithZeroWeight`.
- Pelajaran: verifikasi klaim di source dulu sebelum menulis ekspektasi test. Ketahanan terhadap kegagalan gak sama dengan menolak input.

## Status jujur

- Done: GovernorContract final, override matrix terbukti via compile error eksperimen, quorum 4% terassert di test.
- Catatan: test flow end-to-end belum jalan di hari ini (butuh timelock + treasury, besok). Suite GovernorFullFlow baru hijau pas hari Kamis.
