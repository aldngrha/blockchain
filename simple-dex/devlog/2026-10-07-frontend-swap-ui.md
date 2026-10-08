# 7 Okt 2026 - AMM Frontend: Swap UI

> Task roadmap: "Build swap interface: token input/output dengan price impact display (pakai formula). Slippage tolerance setting. Deadline setting. Loading states yang proper saat transaksi pending."

## Apa yang dikerjakan

- Build `frontend/` lengkap dengan stack yang sama dengan `defi-staking/frontend` (Vite + React 19 + wagmi v3 + viem + RainbowKit v2 + TanStack Query 5 + oxlint), config virtual module yang membaca `deployments/31337.json` (kunci `TokenA`/`TokenB`/`DexPair`), override via `VITE_*`, anvil di port 8548 sesuai konvensi repo ini.
- `src/lib/amm.js`: mirror JS dari `AMMLibrary.getAmountOut`/`getAmountIn`/`quote`/`sqrt` + mirror math `DexPair.addLiquidity`/`removeLiquidity` (untuk tab liquidity besok). Semua BigInt, jadi pembagian truncating-nya identik dengan EVM.
- Dua definisi price impact dari `docs/uniswap-v2-research.md` section 4 diimplementasi berdampingan: impact eksekusi (utama) dan impact marginal (sekunder), plus penjelasan di elemen `<details>`.
- Slippage tolerance (default 0.5%, preset 0.1/0.5/1%, custom sampai 50%) dan deadline (default 20 menit, validasi 1 sampai 10080). `amountOutMin = floor(amountOut * (10000 - bps) / 10000)` dihitung dari output mirror, deadline dihitung di action layer saat submit.
- Flow swap: kalau allowance kurang, runner jalanin approve dulu lalu swap (pola sequential steps dari `useStakingActions`, diadaptasi jadi `useDexActions` dengan label step bernomor). States: idle, pending (tombol disabled + label step + status "confirm in wallet"/"waiting for block"), success (banner + reset input + invalidateQueries), error (parse custom error DexPair jadi pesan manusiawi, termasuk user rejection dan wrong chain).
- Verifikasi non-GUI: unit-check mirror vs 26 vektor eksak test suite (semua PASS, script temp dihapus), selector ABI viem vs `cast sig` (cocok semua), smoke test on-chain di anvil sementara port 8548 dari salinan repo di /tmp: swap 25 SDA menghasilkan reserves pasca-swap persis prediksi mirror.
- UI states: address belum configured (instruksi setup), wallet belum connect, salah chain (banner + tombol switch), read error, pool kosong (hint jalankan deploy script), loading, error tx. Keyboard accessible (semua kontrol native button/input, focus visible), tap target 44px, kontras WCAG AA.

## Masalah & Solusi

### oxlint menolak Date.now() di komponen swap

- Masalah: `npm run lint` menemukan 1 warning "Cannot call impure function during render" karena `Date.now()` dipanggil di dalam `onSubmit` yang didefinisikan di body `SwapPanel`. Deadline transaksi memang butuh waktu submit, tapi lint memandang semua kode di scope render sebagai impure.
- Kenapa: aturan purity React (yang oxlint turunkan) menandai `Date.now` karena nilainya berubah tiap panggilan; ia gak bisa membedakan bahwa fungsi ini cuma jalan di event handler, bukan saat render. Menambahkan suppress comment cuma memindahkan masalah.
- Solusi: pindahkan perhitungan deadline ke `useDexActions.swap`: komponen mengirim `deadlineMinutes` (angka murni dari state form), hook menghitung `BigInt(Math.floor(Date.now() / 1000) + minutes * 60)` saat submit. Lebih bersih secara arsitektur juga, karena deadline adalah keputusan tx-time, bukan state UI. Lint jadi 0 warning 0 error.
- Pelajaran: peringatan purity sering menunjuk desain yang bisa dibetulkan, bukan cuma gaya; kalau perhitungan bergantung waktu dipindah ke lapisan yang tepat, warning-nya hilang tanpa suppress.

### Dua definisi price impact, plus keputusan rounding yang bikin angka beda 0.01% dari docs

- Masalah: docs riset (section 4) mendefinisikan dua price impact: eksekusi (harga rata-rata trade vs spot awal) dan marginal (spot setelah swap vs spot awal). UI harus konsisten dengan definisi itu. Tambahan jebakan: untuk vektor swap 10% pool (9066108938801491315 wei dari pool 100/100), impact eksekusinya 9.3389...%, docs melaporkan 9.34% (dibulatkan 2 desimal), sedangkan UI gw menghitung basis point dengan floor division: 933 bps yang tampil sebagai 9.33%.
- Kenapa: bedanya bukan beda rumus, cuma beda arah pembulatan saat konversi ke persen. Floor menampilkan angka yang sedikit lebih buruk dari kenyataan, arah yang aman untuk angka risiko; docs memakai pembulatan biasa.
- Solusi: tampilkan keduanya dengan label eksplisit ("Price impact (execution)" dan "Marginal price after: ... (impact ...)"), rumus di komentari di `executionImpactBps`/`marginalImpactBps`, dan penjelasan dua definisi di `<details>` yang merujuk docs section 4. Unit-check mengunci floor-nya: 933 dan 1733 bps untuk vektor 10% pool (docs: 9.34% dan 17.33% versi pembulatan). Keputusan dicatat: semua persen di UI ini di-floor, konsisten dengan konvensi kontrak yang selalu menguntungkan pool.
- Pelajaran: dua definisi harga itu jebakan klasik UI AMM (gw sendiri sempat bingung waktu riset 30 Sep); satu kalimat definisi di dekat angka lebih berguna daripada tooltip kosong, dan arah pembulatan angka risiko harus keputusan eksplisit, bukan efek samping.

### Agregasi query state di usePairReads: Object.values mengambil nilai data, bukan objek query

- Masalah: versi pertama `usePairReads` mengumpulkan state loading/error dengan `...Object.values(tokenA)` ke array reads. Hasilnya `readsError` dan `readsLoading` tidak pernah akurat, karena yang masuk array adalah nilai mentah (string/bigint/undefined), bukan objek hasil `useReadContract` yang punya `isLoading`/`isError`.
- Kenapa: hook token gw mengembalikan satu objek campuran (data untuk UI + query results untuk agregasi). `Object.values` meratakan semuanya, jadi objek query-nya hilang di tengah nilai data.
- Solusi: hook `useTokenReads` mengembalikan data UI dan properti `queries` (array hasil `useReadContract` mentah) secara terpisah; agregasi pakai `allReads` yang eksplisit berisi objek query. Build dan lint lulus setelah itu.
- Pelajaran: jangan meratakan objek yang isinya campuran dua tipe; kalau butuh metadata query untuk agregasi, ekspos lewat field khusus agar intent-nya kelihatan.

### Urutan kanonik pair: TokenA bisa jadi token1, mapping-nya harus dibaca dari chain

- Masalah: frontend tahu address `TokenA`/`TokenB` dari deployment JSON, tapi DexPair mengurutkan token by address jadi token0/token1, dan semua fungsi pair (getReserves, swap dengan `zeroForOne`) bekerja di urutan kanonik. Mengasumsikan TokenA == token0 berarti UI bisa telat balik arah kalau urutan deploy berubah.
- Kenapa: ini persis pelajaran devlog 5 Okt ("tokenA bisa jadi token1") yang terjadi di test suite; di frontend risikonya sama, hanya gejalanya berbeda (swap ke arah yang salah).
- Solusi: UI membaca `token0()`/`token1()` dari pair dan memetakan ke label deploy dengan perbandingan address checksummed (`getAddress` dari viem, karena nilai chain dan konstanta config bisa beda case). Semua math dan arah swap memakai urutan kanonik ini; label symbol (SDA/SDB) dibaca dari `symbol()` chain, bukan di-hardcode. Pool stats menampilkan mapping aktual ("token0 = SDA") supaya user bisa lihat urutan sebenarnya.
- Pelajaran: properti yang ditentukan sistem harus dibaca dari sistem; di frontend, "sistem" termasuk normalisasi case address sebelum dibandingkan.

## Status jujur

Done:
- Build (`npm run build`) dan lint (`npm run lint`, 0 warning 0 error) lulus.
- Mirror math tervalidasi 26 vektor eksak dari test suite (getAmountOut 4 vektor, getAmountIn round-trip, quote 3, sqrt 2, addLiquidity on/off-ratio + first provision, removeLiquidity + dust, slippage, impact eksekusi/marginal). Script cek dihapus setelah lulus, tidak di-commit.
- Selector ABI terverifikasi viem vs `cast sig` (0xd8d44478, 0x9cd441da, 0x9c8f9f23; error `DexPair__Expired` ter-decode benar), dan smoke test on-chain: swap 25 SDA di anvil sementara (port 8548, salinan repo di /tmp, repo asli gak disentuh) menghasilkan reserves persis prediksi mirror: (1025000000000000000000, 975681147401029343611 wei), event `Swap` amountOut = 24318852598970656389 wei.

Menunggu / butuh aksi manual:
- Klik-through browser dengan MetaMask belum dilakukan: subagent ini gak punya GUI. Yang sudah terverifikasi non-GUI saja (build, lint, unit vektor, selector, smoke via cast). Sesi klik pertama milik lo; kalau ada yang melebar, perbaiki sebelum demo.
- Tab Liquidity baru selesai matang besok (8 Okt); hari ini fokus swap.
- Deploy Vercel (task besok) manual user.
