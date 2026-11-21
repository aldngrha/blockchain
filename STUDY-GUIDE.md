# STUDY-GUIDE: Cara baca semua yang terdokumentasi (16 Sep sampai 27 Okt)

> Buat yang ngerjain kodenya bukan lo (agent), dan lo belum baca sama sekali.
> Prinsip: baca yang LO sudah kuasai dulu sebagai pijakan, urutan disusun biar tiap langkah numpang di yang udah dipahami, dan tiap project ditutup dengan drill rusak-meniapkan sesuatu. Jangan baca linear semuanya sekaligus: 1 project = 1-2 sesi.
>
> Cakupan sekarang 5 tahap: Tahap 1-4 = hasil 16 Sep sampai 9 Okt (project Foundry + frontend). Tahap 5 = batch 10-27 Okt (audit contest, L2, CCIP, Aave v3). Tahap 5 materi baru semua, belum pernah lo baca.

## Cara belajar: loop per unit (INILAH cara belajarnya)

Unit belajar lo = SATU masalah di devlog. Ada 98 masalah total, semuanya terindeks di `PROBLEM-BOOK.md` (dikelompokkan per tema, ringkasan 1-2 baris + link ke devlog aslinya). Tiap unit lo lewatin loop 5 langkah ini, 20-30 menit:

1. **Baca MASALAHNYA dulu** (di PROBLEM-BOOK atau langsung devlog). Baca section Masalah + Kenapa, lalu SEBELUM baca Solusi, berhenti dan prediksi dulu: "kalau gwa, gwa fix di mana? gimana caranya?" Prediksi lo meleset justru momen belajar paling berharga, karena beda antara prediksi dan kenyataan = titik buta lo.
2. **Baca kode solusinya, cuma bagian itu.** Buka file/fungsi yang disebut di section Solusi. Jangan baca seluruh file dari atas.
3. **Jalankan test di mesin lo** (`forge test` untuk kontrak, `npm run build && npm run lint` untuk frontend). Hijau di mesin lo, bukan di omongan siapa pun. Ini juga latihan nyata memakai tooling.
4. **Drill rusak-meniapkan** (sekali per TAHAP, bukan per unit; daftarnya di tiap tahap di bawah): rusak satu hal sengaja, jalankan test, lihat yang mana yang nangkep, pahami kenapa, balikin lagi.
5. **Checkpoint**: jawab pertanyaan checklist di paling bawah file ini (suara keras, tanpa buka catatan). Gak bisa jawab = balik ke langkah 1 untuk unit yang terkait. Bisa jawab = unit berikutnya.

Ritme realistis: **3-5 unit per sesi**. Gak harus urut 100%, mood boleh jadi kompas (lagi pengin frontend? ambil unit frontend). Yang GAK BOLEH dilewati: langkah 3 dan 4. Itu bedanya "paham di kepala" dan "paham di tangan".

Urutan baca 5 tahap di bawah ini tetap jadi peta besar: unit-unitnya lo ambil dari Tahap 1 dulu, baru Tahap 2, dst. Kalau Tahap 1-4 sudah pernah lo lewatin, langsung ke Tahap 5.

## Urutan baca (kenapa urutan ini)

### Tahap 1: defi-staking frontend (paling ringan, lo udah hafal kontraknya)

Kontrak staking itu buatan lo sendiri sampai 15 Sep, jadi satu-satunya materi baru adalah pola frontend. Ini juga jadi modal buat dua frontend lain.

1. `defi-staking/frontend/src/config.js` lalu `src/abi.js` (config chains, address dari deployments JSON)
2. `src/hooks/` (usePoolReads, usePoolEvents, useStakingActions): pola read via wagmi, event watching buat real-time, tx states
3. `src/components/StakeForm.jsx` (flow approve 2 langkah) dan `ActionFeedback.jsx` (parse custom error jadi pesan manusiawi)
4. `devlog/2026-09-16-frontend-dashboard.md`
5. README `frontend/README.md` lalu jalankan: `anvil` + deploy script + `npm run dev`, connect wallet, stake kecil

Drill: ganti salah satu validasi di StakeForm jadi salah sengaja, lihat error-nya masuk akal gak buat user; hapus event listener, rasakan bedanya data jadi basi.

### Tahap 2: governance-dapp (lompatan konsep terbesar)

Materi baru: checkpoint votes (ERC20Votes), lifecycle proposal, role Timelock. Ini yang paling butuh waktu.

1. `governance-dapp/docs/research-governance.md` (kenapa Governor + Timelock, lifecycle, trade-off parameter)
2. `SPEC.md` (desain final)
3. Devlog berurutan: `2026-09-20` (research), `21` (spec), `22` (token), `23` (governor), `24` (timelock). Devlog ini ditulis dari masalah nyata saat build, jadi ini jalan pintas ke jebakannya
4. Kode, urutan: `src/GovernanceToken.sol` (perhatikan `_update` override, votes cuma nempel setelah delegate) lalu `src/GovernorContract.sol` (override matrix OZ v5, catat kenapa butuh via_ir: EIP-170) lalu `src/Treasury.sol` (kecil)
5. `test/GovernorFullFlow.t.sol`: test full flow ini adalah penjelasan terbaik lifecycle propose-vote-queue-execute, dibaca seperti cerita
6. `script/DeployGovernance.s.sol`: urutan wiring role dan kenapa deployer renounce
7. Frontend: `src/hooks/useProposals.js` (scan event ProposalCreated, kenapa butuh cache, kenapa The Graph dibutuhkan) + `devlog/2026-09-26-voting-ui.md` (voting power dari snapshot block, BUKAN balance sekarang: jebakan klasik ERC20Votes)

Drill: di test, naikkan quorum jadi 51% dan prediksi dulu path mana yang jadi Defeated baru jalankan; coba vote tanpa delegate dan baca kenapa weight-nya 0 (bukan revert).

### Tahap 3: simple-dex (math-heavy tapi self-contained)

1. `simple-dex/docs/uniswap-v2-research.md`: turunan x*y=k + tabel impermanent loss, kerjakan ulang satu angka pakai kalkulator/manual biar nempel
2. `SPEC.md`
3. `src/AMMLibrary.sol`: kecil dan pure, hafalkan getAmountOut dan arah pembulatan (output floor, input ceil, selalu menguntungkan pool)
4. `src/DexPair.sol`: perhatikan lock pattern, MINIMUM_LIQUIDITY, dan refund excess di addLiquidity
5. Cerita overflow (paling berharga): `test/AMMLibrary.t.sol` bagian domain + `devlog/2026-10-02-core-math.md`. Ini contoh nyata fuzz test nemuin batas domain, bukan bug
6. `devlog/2026-10-03` (first provision sqrt), `04` (slippage + deadline), `docs/security-review.md`
7. Frontend swap UI: `frontend/src` bagian yang mirror getAmountOut ke JS, bandingkan definisi price impact di docs

Drill (the best one): hapus `vm.assume(requiredIn <= type(uint112).max)` di test round-trip, jalankan `forge test`, dan tonton fuzz menemukan lagi overflow yang sama dalam hitungan detik. Itu cara paling cepat ngerasain kenapa invariant test itu kuat.

### Tahap 4: frontend AMM + konten (7-9 Okt), baca SETELAH Tahap 3

1. `simple-dex/frontend/src/lib/amm.js`: mirror JS dari getAmountOut/getAmountIn/quote. Baca sambil bandingkan langsung ke `src/AMMLibrary.sol`: BigInt dipakai biar presisinya sama, pembulatan harus identik, kalau beda 1 wei aja UI lo langsung bohong ke user. Testnya udah dibandingkan ke 26 vektor eksak suite Solidity, cari di devlog 7 Okt
2. Price impact dua definisi (execution vs marginal) di `SwapPanel.jsx` + `docs/uniswap-v2-research.md`: pahami kenapa angkanya beda (9.33% vs ~17% buat swap 10% pool) dan kenapa dua-duanya jujur
3. `LiquidityPanel.jsx` + `hooks/useDexActions.js`: guidance rasio via quote, perilaku refund yang sebenarnya (surplus GAK PERNAH ditarik, CEI: hitung dulu transferFrom sesuai rasio; ini beda dari intuisi pull-and-refund) dan temuan yang batalin brief: remove liquidity GAK butuh approve LP karena pair burn LP langsung via _burn
4. `devlog/2026-10-09-demo-readme-article.md` lalu `content/mirror-article-draft.md`: baca sebagai latihan mengajar, kalau urutan penjelasan artikelnya beda dari urutan lo ngerti, tulis versi lo sendiri
5. `content/demo-script.md`: dipakai buat rekam Loom (manual), semua angkanya dari simulasi sekuens eksak

Drill: ganti slippage default, PREDIKSI dulu swap mana yang bakal revert kena guard amountOutMin di kontrak, baru eksekusi di anvil; terus tukar urutan approve di hook dan lihat error apa yang muncul dari RPC.

### Tahap 5: batch 10-27 Okt (materi baru, belum pernah lo baca)

Semua di tahap ini baru: audit contest, L2, CCIP, dan Aave v3. Tidak ada yang numpang di kode yang lo tulis sendiri, jadi ini tahap yang paling butuh mode ketik ulang.

1. `docs/how-audit-contests-work.md`: beda Code4rena vs Sherlock vs Codehawks vs Cantina, alur contest, severity, dan bagian yang paling penting: kenapa contest tidak mencegah exploit. Baca studi kasus Cork Protocol dua kali.
2. `security/AUDIT-TEMPLATE.md`: template finding, panduan severity, tujuh pertanyaan uji-sebelum-submit. Bedanya dengan `security/SECURITY-CHECKLIST.md`: checklist buat nyari, template buat nulis.
3. `docs/l2-deep-dive.md`: fraud proof vs validity proof, angka L2Beat, dan framework stage L2. Bagian 6 (cara baca stage) yang paling berguna jangka panjang.
4. `ccip-crosschain/docs/ccip-architecture.md` lalu `SPEC.md`. Baca dokumen arsitekturnya dulu sampai paham alur 6 langkahnya, baru buka `SPEC.md` section 6 dan 7.
5. Kode: `src/MessageReceiver.sol` dulu (kecil dan padat makna), baru `src/CrossChainSender.sol` (perhatikan refund), lalu `test/mocks/MockRouter.sol` (pahami kenapa mock-nya butuh `sourceChainSelectorForDelivery`).
6. `test/CrossChain.t.sol`: baca sebagai cerita. Tiap test itu satu properti keamanan atau satu edge case, bukan sekadar kode uji.
7. `docs/defi-protocol-onepager.md`, lalu jalankan ulang sendiri perintah `cast call` yang ada di section "Data terukur". Baca angka aslinya di terminal, jangan cuma percaya tabelnya.
8. `ccip-crosschain/devlog/2026-10-25-ccip-crosschain.md`: enam masalah nyata, termasuk yang bikin test hijau padahal salah.

Drill (Tahap 5 punya drill terbaik kedua setelah AMM):

- **CCIP, drill utama.** Hapus `onlyRouter` dari `MessageReceiver.ccipReceive`, jalankan `forge test`, lihat test mana yang nangkep. Balikin. Lalu hapus cek `trustedSender`, jalankan lagi. Dua drill itu yang bikin lo ngerasain sendiri kenapa dua validasi itu wajib, bukan sekadar disuruh percaya.
- **CCIP, drill refund.** Ubah `MockRouter.getFee` supaya mengembalikan 0, jalankan test refund. Lalu pikirkan: kalau fee-nya 0, apakah kontraknya masih benar? Kenapa refund dihitung dari `getFee`, bukan dari angka tetap?
- **Aave, drill hitung.** Pakai kalkulator, tanpa buka dokumen: WETH LTV 80,50%, liquidation threshold 83%. Kalau posisi punya health factor 1,2, berapa persen penurunan harga WETH yang bikin dia jatuh di bawah 1? Cocokkan nanti dengan simulasi di 30 Okt.
- **L2, drill cek basi.** Buka L2Beat, cek stage Base, Arbitrum One, dan ZKsync Era sekarang, bandingkan dengan tabel di `docs/l2-deep-dive.md` (snapshot Agt 2026). Kalau ada yang bergerak, itu justru temuan bagus, dan tandai mana yang berubah.

## Aturan main biar beneran nyangkut

- Jangan cuma baca: tiap selesai satu bagian, jalankan `forge test` di project itu, lalu RUSAKIN satu hal (balikin lagi setelahnya) dan lihat test mana yang nangkep. Kalau gak ada yang nangkep, itu temuan: testnya kurang.
- Ukuran realistis: Tahap 1 = 1 sesi, Tahap 2 = 2-3 sesi, Tahap 3 = 2 sesi, Tahap 5 = 3-4 sesi (CCIP sendirian 1-2 sesi karena konsepnya paling baru). Gak harus habis semalam, dan gak perlu nunggu semuanya selesai buat mulai.
- Kalau ngerasa "baca doang gak nyangkut", turunkan ke mode ketik ulang: tulis ulang fungsi inti (rewardPerToken, getAmountOut, atau lifecycle test) dari ingatan, bandingkan dengan aslinya.
- Devlog itu dibaca dengan sikap kritis: "masalahnya masuk akal gak? gwa bakal ngerjain beda gak?" Beda pendapat = bagus, tulis di idea pipeline.

## Checklist paham (kalau bisa jawab, tahap itu tuntas)

Tahap 1: Kenapa approve 2 langkah? Kenapa parse custom error, bukan string match?
Tahap 2: Kenapa votes nol walau punya token? Kenapa timelock ada? Kenapa cancel cuma proposer saat Pending? Kenapa quorum dihitung dari for+abstain?
Tahap 3: Turunkan getAmountOut dari x*y=k tanpa lihat. Kenapa MINIMUM_LIQUIDITY? Kenapa overflow di getAmountOut itu domain, bukan bug, dan kapan dia panic?
Tahap 5: Kenapa audit contest tidak mencegah exploit, dan apa yang sebenarnya dibeli dari ikut contest? Kenapa receiver CCIP wajib cek dua hal (router DAN sumber), kenapa salah satu saja tidak cukup? Kenapa CCIP pakai chain selector, bukan chain id? Kenapa health factor pakai liquidation threshold, bukan LTV? Kenapa kelebihan bayar fee CCIP harus di-refund sendiri?
