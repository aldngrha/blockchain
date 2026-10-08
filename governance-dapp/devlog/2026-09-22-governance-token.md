# 22 Sep 2026: GovernanceToken

> Task roadmap: "Sel 22 Sep, BELAJAR, Project 2: GovernanceToken. Implement GovernanceToken: ERC-20 + ERC-20Votes. Pahami votes checkpoint system, ini berbeda dari ERC-20 biasa. Test: delegate, checkpoints, past votes. Votes bisa delegate ke address lain."

## Apa yang dikerjakan

- `src/GovernanceToken.sol`: ERC20 + ERC20Permit + ERC20Votes, name "Governance Token", symbol "GT", fixed supply 1.000.000e18 ke deployer, tanpa owner.
- `test/GovernanceToken.t.sol`: 14 test termasuk 2 fuzz. Delegate self/other, voting power baru aktif setelah delegate, transfer hanya mindah power kalau kedua pihak delegate, `getPastVotes`/`getPastTotalSupply` di blok lampau dengan vm.roll, future lookup revert.
- Build pertama dengan OZ v5.4 + solc 0.8.28.

## Masalah & Solusi

### OZ v5 wajib override `_update`, bukan `_beforeTokenTransfer`

- Masalah: semua materi lama (v4) bilang override `_beforeTokenTransfer`. Di v5.4 hook itu udah gak ada. ERC20Votes v5.4 meng-override `_update(address,address,uint256)` dan minta turunannya menggabungkan versi ERC20 + ERC20Votes. First build langsung gagal kalau gak ditulis.
- Kenapa: OZ v5 merombak arsitektur hooks jadi satu internal function `_update`. Semua ekstensi yang nempel di pergerakan token numpang di situ.
- Solusi: tulis persis seperti panduan OZ v5:
  ```solidity
  function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
      super._update(from, to, value);
  }
  ```
- Pelajaran: migrasi major version OZ itu breaking. Selalu buka source yang terinstall di `lib/`, jangan karang dari ingatan versi 4.

### `nonces` bentrok antara ERC20Permit dan Votes

- Masalah: `ERC20Permit` dan `Votes` dua-duanya mewarisi `Nonces`, jadi `nonces(address)` terdefinisi dua kali di DAG. Compiler minta resolusi eksplisit di kontrak final.
- Kenapa: kedua fitur (permit dan delegateBySig) butuh nonce tracking, dan OZ memilih menyatukan base-nya di v5, tapi kelas turunan tetap harus menyelesaikan diamond lookup.
- Solusi:
  ```solidity
  function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
      return super.nonces(owner);
  }
  ```
  Perlu import `Nonces` eksplisit karena dia gak jadi base langsung di daftar `is`.
- Pelajaran: diamond inheritance di Solidity itu mekanis dan bisa ditebak, tapi compiler yang akhirnya menentukan. Baca error-nya, dia menunjuk kontrak yang bentrok satu per satu.

### Voting power "hancur" saat transfer ke penerima yang belum delegate

- Masalah: test `test_TransferToNonDelegatedReceiverDestroysWeight` awalnya gw tulis dengan asumsi transfer memindahkan voting power tanpa syarat. Ternyata power penerima = 0 sampai dia `delegate()`. Power yang keluar dari pengirim "menghilang" untuk sementara.
- Kenapa: `Votes._transferVotingUnits` hanya memindahkan checkpoint kalau penerima sudah punya delegatee. Ini desain ERC20Votes (transfer lebih murah, delegation opt-in), bukan bug.
- Solusi: test dibalik jadi dokumentasi perilaku: assert balance penerima 60 GT tapi `getVotes` 0, lalu setelah dia delegate, votes = 60. Dengan catatan bahwa aktivasi itu sejak block delegate, bukan retroaktif.
- Pelajaran: ini PR banget buat UX frontend: user yang nerima token tanpa delegate gak bisa vote, dan delegate setelahnya gak mengembalikan riwayat proposal yang sudah lewat.

### Lookup checkpoint di block sekarang itu revert

- Masalah: `token.getPastVotes(alice, block.number)` revert `ERC5805FutureLookup(timepoint, clock)`. Gw pikir "past" termasuk block sekarang.
- Kenapa: checkpoint disimpan per block dan EVM gak bisa membaca state block yang belum selesai. OZ menegaskan: `timepoint` harus `< clock()`.
- Solusi: test `test_FutureLookupReverts` dan `test_FutureTotalSupplyLookupReverts` ditulis eksplisit expect revert, plus semua assert historis pakai target block yang sudah digali (`vm.roll` dulu, baru lookup).
- Pelajaran: "past" di ERC20Votes itu strictly `< clock()`. Governor sendiri mengambil bobot di `proposalSnapshot` yang minimal 1 block di masa depan saat propose, jadi delegate setelah propose gak mengubah proposal yang sudah ada.

## Status jujur

- Done: GovernanceToken selesai, 14 test hijau (semua suite, termasuk milik hari-hari berikutnya, total 33 pass di akhir minggu).
- Perlu aksi manual (kalau mau ganti desain): kalau mau distribusi awal beda dari "semua ke deployer", constructor perlu parameter. Untuk roadmap ini fixed ke deployer sudah sesuai spec.
