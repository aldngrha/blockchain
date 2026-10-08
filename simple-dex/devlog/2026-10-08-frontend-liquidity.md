# 8 Okt 2026 - AMM Frontend: Liquidity UI

> Task roadmap: "Add/remove liquidity interface: tampilkan pool stats (reserves, your share %, your LP tokens). Position tracker untuk liquidity providers. Deploy frontend ke Vercel."

## Apa yang dikerjakan

- Tab Liquidity di `frontend/`: PoolStats (reserves kedua token via `getReserves`, LP total supply via `totalSupply` di address pair), PositionCard (LP balance user, share % = `lp * 10000 / totalSupply` dalam basis point, estimasi holdings = payout eksak kalau ditarik sekarang), form Add (dua input + guidance rasio dari mirror `quote`, tombol "Use suggested", expected LP mint), form Remove (input LP + Max, estimasi payout dua token, peringatan pre-submit kalau debu).
- `addLiquidityOutcome` di `src/lib/amm.js`: mirror lengkap math `DexPair.addLiquidity`, termasuk cabang first provision (geometric mean `sqrt(a0*a1)` minus 1000 wei `MINIMUM_LIQUIDITY` yang terkunci di pair) dan cabang pool ter-seed (snap ke rasio pool, field `surplus0`/`surplus1` untuk menghitung kelebihan yang gak ditarik). UI memakai mirror ini untuk warning off-ratio dan estimasi LP sebelum submit.
- Approval flow add: runner membangun steps dinamis (approve token0 kalau allowance kurang, approve token1 kalau kurang, lalu `addLiquidity`), label step bernomor sesuai jumlah approve yang benar-benar dibutuhkan (1/2, 2/3, dst).
- Event watching `Mint`/`Burn`/`Swap`/`Sync` via `watchContractEvent` (pola proven defi-staking; getLogs viem 2.5x mengabaikan abi+eventName yang bukan event ABI item, jadi jangan pakai jalur itu) + polling ringan reserves/balances, supaya stats dan position update setelah tx konfirmasi maupun perubahan dari luar app.
- Vercel: belum dideploy, butuh aksi manual (lihat Status jujur). Build statik siap (`npm run build` lulus).

## Masalah & Solusi

### Brief bilang "approve 3 token", kontrak bilang remove gak butuh approve LP

- Masalah: instruksi awal menyebut approve tiga token (TokenA, TokenB, LP). Kalau diikuti mentah-mentah, UI remove liquidity bakal memaksa satu approve tx yang sia-sia, bahkan membingungkan (approve spender siapa, padahal LP dibakar di kontraknya sendiri).
- Kenapa: `removeLiquidity` memanggil `_burn(msg.sender, lpAmount)` langsung. `_burn` milik ERC20 mengurangi balance tanpa melihat allowance; allowance hanya relevan untuk `transferFrom` (jalur yang dipakai `addLiquidity` dan `swap` lewat `_pullToken`). LP token memang kontrak pair itu sendiri, jadi dia berhak membakar balance pemanggilnya tanpa izin tertulis.
- Solusi: UI remove tidak punya step approve, dan form menjelaskan ini ke user ("No approval is needed: the pair burns LP from your balance directly"). Add tetap approve dua token per-amount. Catatan ini juga masuk frontend README supaya gak dianggap lupa.
- Pelajaran: daftar integrasi yang ditulis dari luar kode perlu diverifikasi ke source sebelum jadi UI flow; satu bacaan `_burn` menghemat satu transaksi dan satu kebingungan per remove.

### Perilaku refund addLiquidity ternyata "gak pernah ditarik", bukan "ditarik lalu dikembalikan"

- Masalah: UI harus menjelaskan apa yang terjadi kalau user deposit dengan rasio off-pool. Dugaan awal (dan cara banyak protocol lama bekerja): kontrak menarik semuanya lalu mengirim kelebihannya balik. Kalau UI menjanjikan itu padahal kontraknya beda, copy-nya bohong.
- Kenapa: baca `DexPair.addLiquidity`: dia hitung `amount1Optimal = quote(amount0Desired, r0, r1)`; kalau muat di budget, token0 ditarik penuh dan token1 sebatas optimal; kalau gak muat, sisi token1 yang jadi binding dan token0 dihitung optimal (`amount0Optimal <= amount0Desired` dijaga assert). TransferFrom cuma dipanggil untuk `amount0`/`amount1` final, jadi surplus tidak pernah keluar dari wallet. Tidak ada refund tx, tidak ada dust transfer balik.
- Solusi: mirror `addLiquidityOutcome` menghitung amounts final plus `surplus0`/`surplus1`, dan warning off-ratio di UI menyebut angkanya eksplisit: "the pair will pull X token0 and Y token1; the surplus (A / B) stays in your wallet, it is never transferred". First provision diberi hint terpisah: semua ditarik penuh, LP = sqrt(a0*a1) minus 1000 wei terkunci.
- Pelajaran: perilaku refund yang akurat adalah properti urutan operasi (CEI: hitung dulu, tarik sesudahnya), dan itu bisa di-mirror 1:1 di frontend kalau mirror-nya ditulis dari source, bukan dari intuisi AMM umum.

### willRevert muncul padahal data masih loading

- Masalah: di kedua form liquidity, flag `willRevert` dihitung dari `outcome === null`. Saat halaman baru dibuka, reserves dan totalSupply masih `undefined`, mirror mengembalikan `null`, dan UI menampilkan error "the pair would revert" padahal belum ada yang salah, data-nya saja belum sampai.
- Kenapa: mirror sengaja mengembalikan `null` untuk dua kondisi berbeda (input belum siap vs input benar-benar akan revert), dan komponen awalnya menggabungkan keduanya jadi satu kesimpulan.
- Solusi: `willRevert` di-gate pada data yang sudah terdefinisi (`reserve0 !== undefined && reserve1 !== undefined && lpTotalSupply !== undefined`), jadi error pre-submit hanya muncul kalau angkanya sudah dihitung dari state pool yang nyata. Kasus debu (sisi payout floor ke 0, revert `DexPair__InsufficientLiquidityBurned`) tetap tertangkap sebelum user boros gas.
- Pelajaran: null sebagai sinyal "akan revert" hanya valid kalau input mirror-nya lengkap; pisahkan "belum tahu" dari "tahu bahwa gagal", dua state UI yang berbeda.

### Share % dan estimasi holdings: satu pembagi, dua arah floor

- Masalah: position tracker menampilkan share user dan estimasi payout. Keduanya pecahan, dan ada dua cara salah: menghitung share via floating point (kehilangan presisi untuk LP besar), atau menampilkan estimasi yang tidak sama dengan payout eksak kontrak.
- Kenapa: kontrak menghitung payout `(lp * reserve) / totalSupply` dengan floor terhadap supply SEBELUM burn (devlog 4 Okt). Estimasi UI harus memakai rumus dan arah pembulatan yang sama, kalau tidak, angka "Estimated holdings" bakal beda dari payout nyata dan user menganggapnya bug.
- Solusi: share dalam basis point BigInt (`(lp * 10000n) / totalSupply`), estimasi holdings memakai `removeLiquidityOutcome` yang sama dengan preview form remove, semua floor. Unit-check kemarin mengunci vektor remove (pool 4/9, supply 6, burn 3 = payout 2 dan 4.5 eksak).
- Pelajaran: di UI AMM, "estimasi" yang bagus adalah hasil rumus kontrak yang sama, bukan aproksimasi terpisah; konsistensi pembulatan antara preview dan eksekusi adalah bagian dari kebenaran UI.

## Status jujur

Done:
- Build dan lint lulus (0 warning 0 error) setelah semua perbaikan di atas.
- Mirror add/remove mengunci perilaku kontrak: off-ratio deposit (500, 100) ke pool (1000, 1000) menghasilkan pull (100, 100) + surplus (400, 0) + LP 100, first provision (4e18, 9e18) menghasilkan LP 5999999999999999000 untuk caller, dust remove mengembalikan null (revert). Semua di unit-check 7 Okt yang lulus penuh.
- Vercel: instruksi ada di frontend README (build statik + override `.env`), tapi eksekusi deploy-nya manual.

Menunggu / butuh aksi manual:
- Klik-through browser dengan MetaMask tetap belum dilakukan (gak ada GUI di sini); termasuk alur dua-tx approve + addLiquidity di wallet.
- Deploy Vercel (task roadmap hari ini): manual user. Frontend ini menunjuk node lokal `127.0.0.1:8548`, jadi deploy publik tanpa ganti chain/address ke Sepolia gak akan berguna; Sepolia sendiri belum dideploy kontraknya.
