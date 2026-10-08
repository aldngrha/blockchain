# 1 Okt 2026 - AMM Design + Spec

> Task roadmap: "Design SimpleDex: LiquidityPool contract untuk 2-token pair. Fungsi: addLiquidity, removeLiquidity, swapExactTokensForTokens. LP tokens sebagai proof of liquidity. Tulis spec lengkap."

## Apa yang dikerjakan

- Design SimpleDex dari hasil riset 30 Sep: satu pair 2 token, tiga fungsi inti (addLiquidity, removeLiquidity, swapExactTokensForTokens), LP token ERC-20 sebagai bukti porsi pool.
- Tentukan arsitektur: AMMLibrary (pure math) + DexPair (pool sekaligus LP token, ala v2), OZ v5, custom errors, events Mint/Burn/Swap/Sync.
- Tulis `SPEC.md` lengkap: goal & non-goals, arsitektur dengan diagram, tabel functions/errors/events, LP math (first provision sqrt + min-formula provision berikutnya), 14 edge case (E1-E14), invariant I-a..I-d, test plan per tanggal, rencana deployment.
- Kunci non-goals v1 secara eksplisit: no factory, no TWAP oracle, no fee-on-transfer support, no protocol fee, no flash swap, no frontend dulu.

## Masalah & Solusi

### API: "kirim token dulu" ala v2 atau approve + call

- Masalah: Uniswap v2 pakai alur optimistic (user kirim token dulu ke pair, baru panggil mint/swap, pair menghitung dari saldo masuk). Aman dari front-run, tapi aneh bagi user modern dan butuh factory/skim untuk recover dust.
- Kenapa: pilihan API menentukan hampir semua hal lain: cara reentrancy di-handle, cara dust ditangani, dan apakah butuh factory.
- Solusi: pilih explicit-amount API (deviasi disengaja dari v2, didokumentasikan di SPEC section 2 poin 1): user `approve` lalu panggil fungsi, `transferFrom` dilakukan DI DALAM pair dengan verifikasi saldo aktual. Konsekuensi yang diterima: gak ada flash swap di v1. Bayarannya UX lebih jelas dan dust recovery gak dibutuhkan.
- Pelajaran: menyalin desain protocol tanpa menilai ulang trade-off-nya justru menghilangkan kesempatan belajar; yang penting deviasinya disengaja dan didokumentasikan.

### OZ v5 melarang mint ke address(0), MINIMUM_LIQUIDITY harus tetap terkunci

- Masalah: resep v2 me-mint 1000 wei LP pertama ke `address(0)`. OZ v5 (yang dipakai) revert kalau mint ke zero address.
- Kenapa: tujuan MINIMUM_LIQUIDITY cuma satu, 1000 wei LP yang gak bisa diklaim siapapun selamanya, supaya share tidak pernah 100% dan reserves tidak pernah 0. Destinasi mintnya detail implementasi, bukan esensinya.
- Solusi: mint 1000 wei ke `address(this)` (pair sendiri). Verifikasi gak ada jalur burn LP milik pair: `removeLiquidity` cuma membakar `msg.sender`-nya. Efek identik dengan v2, didokumentasikan SPEC poin 3 dan di-commit test `test_FirstProvision_MinimumLiquidityLockedForever` (3 Okt).
- Pelajaran: saat dependency baru melarang pola lama, pahami dulu INVARIAN yang dijaga pola lama, baru cari cara lain menjaga invarian yang sama.

### Fee-on-transfer: diakomodasi atau ditolak

- Masalah: token FoT membuat pair menerima lebih sedikit dari `amount` sementara pembukuan mencatat penuh. Mengakomodasi berarti mengukur saldo aktual tiap kali (kompleks); mengabaikan berarti pembukuan bocor dan bisa dieksploitasi.
- Kenapa: untuk project belajar, dukungan FoT menambah complexity di jalur paling kritis (pembukuan reserves) dengan manfaat kecil.
- Solusi: v1 menolak aktif: setiap input lewat `_pullToken` yang membandingkan `balanceOf(pair)` sebelum vs sesudah transfer; delta != amount berarti revert `DexPair__FeeOnTransferNotSupported`. Berlaku di addLiquidity DAN swap. Ditulis SPEC poin 4 + edge case E13.
- Pelajaran: menolak fitur secara eksplisit (dengan guard yang fail loud) lebih aman daripada diam-diam salah hitung.

### Satu kontrak atau dua (pool + LP token terpisah)

- Masalah: LP token bisa jadi kontrak terpisah atau menyatu dengan pool. Kontrak terpisah lebih "bersih" secara SOLID, tapi menambah wiring (pair -> lpToken address) dan permukaan error baru.
- Kenapa: v2 membuktikan satu kontrak cukup: ERC20 LP hanyalah ledger share atas reserves yang ada di kontrak yang sama.
- Solusi: `DexPair is ERC20`, name "SimpleDex LP Token", symbol "SDX-LP". Hemat kontrak, `totalSupply()` selalu available lokal untuk LP math, persis pola v2 yang jadi acuan audit.
- Pelajaran: untuk komponen inti DeFi, kesederhanaan jumlah kontrak adalah fitur keamanan.

## Status jujur

Done:
- `SPEC.md` status FINAL: arsitektur, math, 14 edge case, invariant, test plan, rencana deploy semuanya terdefinisi.
- Semua keputusan desain besar (4 deviasi dari v2) didokumentasikan dengan alasannya.

Belum / menunggu:
- Belum ada kode (implementasi mulai Jum 2 Okt). SPEC adalah kontrak dengan diri sendiri: test plan di SPEC jadi checklist 2-5 Okt.
- DoD SPEC menyebut deploy Arbitrum Sepolia sebagai item terbuka; itu butuh kredensial manual gw (RPC + private key), bukan hal yang bisa diotomasi hari ini.
