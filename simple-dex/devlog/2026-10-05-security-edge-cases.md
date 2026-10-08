# 5 Okt 2026 - AMM: Security + Edge Cases

> Task roadmap: "Security review AMM: reentrancy di swap, price manipulation via flashloan, integer precision (pakai MINIMUM_LIQUIDITY). Fuzz test semua fungsi. Cek: tidak ada stuck funds, tidak ada drain pool."

## Apa yang dikerjakan

- Tulis invariant suite `test/invariant/DexPairHandler.t.sol` + `test/invariant/DexPairInvariantTest.t.sol`: handler dengan 3 aktor + 1 lpOwner, pool di-seed (1000e18, 1000e18), aksi acak add/remove/swap/warp, ghost variables untuk agregat yang tidak terlihat di pair, `fail_on_revert = true`.
- Lima invariant: I-a k tidak pernah turun lewat swap (dicek di handler setiap swap), I-b solvency (saldo aktual == reserves), I-c pembukuan LP supply (mint - burn), MINIMUM_LIQUIDITY terkunci, I-d payout proporsional eksak + LP backing (dust < 1 wei per holder).
- Melengkapi 2 test domain boundary di `test/AMMLibrary.t.sol` dari keputusan 2 Okt (outside-domain panic dengan counterexample asli + at-domain-edge round-trip), suite library 18 jadi 20, total suite 53.
- Tulis `docs/security-review.md`: 10 temuan dengan severity dan status (fixed / didokumentasikan / di luar scope v1), termasuk cerita overflow, LP inflation attack dengan sisa risikonya, dan rekomendasi uint112 reserves.

## Masalah & Solusi

### Config invariant: key TOML yang salah bikin assert handler ke-swallow

- Masalah: awalnya invariant suite "hijau" tapi terlalu hijau: assert di dalam handler ternyata tidak pernah digunakan sebagai failure. Penyebabnya ketahuan saat review config: yang ditulis di foundry.toml adalah `fail-on-revert` (kebab-case), key yang DIABAIKAN Foundry diam-diam; key yang benar `fail_on_revert` (snake_case).
- Kenapa: tanpa `fail_on_revert = true`, revert di handler cuma menghentikan aksi itu, dan assert yang revert (assert berjalan dengan revert di frame handler) ikut ter-swallow sebagai "aksi gagal yang wajar". Suite tampak lulus padahal pemeriksaannya mati.
- Solusi: perbaiki ke `fail_on_revert = true` di `[invariant]` foundry.toml dengan komentar penjelas, dan desain ulang handler supaya semua aksi di-bound atau di-skip (return awal), bukan revert: bound amount dengan `bound(...)`, skip config debu (`if (...) return`). Sekarang revert apapun di handler = FAIL beneran.
- Pelajaran: config yang salah bentuk (kebab vs snake) bisa membunuh pengujian tanpa warning; verifikasi bahwa guard uji benar-benar AKTIF, jangan percaya "suite hijau".

### Handler swap mentok stack limit EVM

- Masalah: fungsi `swap` di handler butuh menyimpan snapshot pre-state (reserves, saldo in/out, amount) untuk dicek sesudah swap, plus variabel lokal lain. Solc menolak kompilasi: stack too deep.
- Kenapa: EVM punya 16 slot stack; snapshot + parameter + variabel hasil melebihinya.
- Solusi: pindahkan snapshot swap ke storage ghost variables (`ghost_swapRIn`, `ghost_balInBefore`, dst di DexPairHandler), dan pecahkan pemeriksaan ke fungsi internal terpisah `_checkSwapOutcome` supaya frame swap muat. Bonus desain: ghost snapshot inilah yang memungkinkan echo I-a di `invariant_I5_KNeverDecreasedOnLastSwap` di akhir sequence.
- Pelajaran: invariant handler itu program juga; storage murah dipakai sebagai memori antar-fase, dan memecah fungsi buat keterbacaan sekaligus menyelesaikan stack.

### Guard harus jalan SEBELUM ghost snapshot di-update

- Masalah: di handler swap, snapshot pre-state di-set sebelum eksekusi. Kalau guard (skip) ditaruh SETELAH snapshot, aksi yang di-skip meninggalkan snapshot basi, dan echo I-a nantinya membandingkan dua titik waktu yang gak nyambung.
- Kenapa: early return yang "aman" secara lokal bisa korup secara global karena ghost variables lintas-aksi.
- Solusi: semua guard (rIn/100 < MIN_UNIT, saldo kurang) berjalan PALING AWAL di fungsi swap handler, snapshot hanya ditulis kalau aksi benar-benar akan dieksekusi (ada komentar eksplisit di DexPairHandler soal ini).
- Pelajaran: di stateful testing, urutan guard vs penulisan state bagian dari korektness, bukan gaya.

### Pair mengurutkan token: tokenA bisa jadi token1

- Masalah: handler dan test deploy `tokenA` duluan, tapi constructor DexPair MENGURUTKAN token by address. `tokenA` jadi token0 cuma kebetulan (tergantung hasil deploy address). Test yang hardcode asumsi itu bisa balik arah tanpa jelek di mata.
- Kenapa: urutan kanonik token0/token1 adalah detail yang disengaja ala v2; kebetulan deploy address bukan kontrak yang bisa diandalkan.
- Solusi: helper `_t0()`/`_t1()` di kedua file test resolve sisi lewat `pair.token0()` perbandingan address, dan `invariant_I1_ReservesMatchActualBalances` memakai resolusi yang sama. Ada komentar di kedua test file.
- Pelajaran: properti yang ditentukan sistem (sorting) harus dibaca dari sistem, bukan diasumsikan dari urutan pembuatan.

### Rekap kejadian fuzz overflow + keputusan lock vs ReentrancyGuard

- Masalah: security review formal harus memutuskan dua hal yang sebelumnya masih terbuka: bagaimana memvonis temuan overflow 2 Okt, dan apakah bool `lock` cukup atau harus ganti OZ `ReentrancyGuard`.
- Kenapa: keduanya menentukan sifat dokumen review: severity harus jujur, mitigasi harus dibandingkan dengan alternatif standar.
- Solusi: (1) overflow difonis Medium/didokumentasikan, bukan bug: domain uint112 konvensi v2, panic failure-safe, 2 test boundary + natspec domain; limitasi reserves uint256 dicatat Low dengan rekomendasi production-grade. (2) bool lock dipertahankan: semantik sama dengan OZ (satu slot, lintas fungsi, revert custom error), pilihannya paritas pola v2 yang dikenal auditor; perbandingannya ditulis di docs/security-review.md section 1, termasuk jujurnya bahwa belum ada test reentrancy end-to-end (mock token jahat belum ada).
- Pelajaran: memvonis temuan itu pekerjaan dua arah: severity atas dampak, status atas bukti; dan mitigasi standar (OZ) bukan otomatis pilihan benar kalau paritas pola justru nilainya.

## Status jujur

Done:
- Invariant suite hijau (5 invariant, 100 runs x 32 depth, fail_on_revert = true, 0 revert handler), total suite 53 test hijau (20 + 17 + 11 + 5, diverifikasi 6 Okt).
- `docs/security-review.md` selesai: 10 temuan, termasuk cerita overflow, dengan severity + status.
- Satu-satunya fuzz failure nyata di project ini (panic 0x11) ditemukan, dimengerti, dan dikunci perilakunya.

Belum / catatan:
- Test reentrancy exploit end-to-end belum ada (mock token jahat belum ditulis); mitigasi dinilai dari inspeksi CEI + lock, dicatat eksplisit di security review section 9.
- Slither/static analyzer belum di-run di repo ini (tool belum ter-install), direkomendasikan sebelum testnet publik.
- Deploy Arbitrum Sepolia masih butuh aksi manual gw (RPC + private key + faucet), bukan bagian hari ini.
