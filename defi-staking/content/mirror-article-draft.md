# Draft Artikel Mirror.xyz: "Membangun DeFi Staking Protocol: 5 Keputusan Desain yang Lebih Sulit dari Kodenya"

Status: DRAFT, untuk Mirror.xyz. Target panjang 900-1.100 kata. Semua kejadian di artikel ini berasal dari devlog project (devlog/17 Sep dst), jadi bisa ditrace. Publish setelah repo di-push supaya ada link.

Catatan gaya: first person, proses over hasil, tanpa klaim kualitas yang gak bisa dibuktikan pembaca. Angka hanya yang bisa direproduksi dari repo.

---

## Intro

Setelah 6 minggu belajar Solidity (Foundry, ERC standards, security basics), gw putuskan stop dulu dari tutorial dan build sesuatu yang utuh: DeFi Staking Protocol. Konsepnya sederhana: user stake token, reward akumulasi per detik, claim kapan aja.

Kode kontraknya bisa dibaca dalam 30 menit. Tapi keputusan di baliknya butuh waktu jauh lebih lama. Artikel ini bukan tutorial (udah banyak), ini catatan 5 keputusan yang paling bikin gw mikir, plus masalah build yang gak muncul di tutorial mana pun.

## 1. Kenapa reward di-mint saat claim, bukan di-pre-fund

Dua desain yang umum:
- Pre-fund: owner transfer reward ke pool duluan, pool membagikan dari saldo.
- Mint-on-claim: reward token inflationary, pool mint baru saat claim.

Gw pilih mint-on-claim karena pre-fund butuh sumber dana eksplisit dan memperkenalkan state "pool kurang dana" yang harus di-handle (gimana kalau reward akumulasi > saldo pool?). Dengan mint-on-claim, kontraknya jujur: reward memang gak ada sampai di-mint, dan invariant-nya bersih: saldo pool selalu == total staked, tidak pernah ada reward idle di pool.

Trade-off yang gw tanggung sadar: supply inflasi. Untuk v1 (belajar pattern), itu acceptable, dan di-dokumentasiin sebagai trade-off, bukan disembunyiin.

## 2. Checkpoint per user: kenapa accumulator aja gak cukup

Math reward-nya pola Synthetix: satu accumulator global (`rewardPerToken`, scaled 1e18), naik tiap detik sebanding `rewardRate / totalStaked`.

Bug klasik yang nyaris gw tulis: pakai accumulator global doang. Contoh: Alice stake hari 1, Bob stake hari 7. Accumulator global udah tinggi. Kalau reward Alice dihitung dari accumulator global langsung, Bob "ikutan menikmati" akumulasi hari 1-6 yang bukan haknya, dan Alice di-dilute.

Solusinya checkpoint: tiap user nyimpen `userRewardPerTokenPaid` (nilai accumulator saat terakhir interaksi). Reward user = `staked * (rewardPerTokenSekarang - checkpointUser)`. Delta sejak terakhir interaksi, bukan total.

Ini konsep 5 baris, tapi ngerusak semua kalau salah satu fungsi lupa manggil `_updateReward()` di awal. Makanya di StakingPool gw, entrypoint yang mengubah saldo/rate semua diawali `_updateReward`, dan invariants di-test pakai handler dengan warp acak.

## 3. emergencyWithdraw yang sengaja "merugikan" user

`emergencyWithdraw()` balikin 100% stake, tapi FORFEIT semua reward yang belum di-claim, dan reset checkpoint user.

Ini keputusan desain, bukan kelalaian. Fungsinya escape hatch kalau reward math-nya bermasalah: user harus punya jalan keluar yang gak bergantung pada logika yang (mungkin) buggy. Kalau emergencyWithdraw masih menghitung reward pake math yang sama, math yang buggy itu malah jadi jalur eksekusinya.

Yang tricky malah detailnya: forfeit reward tanpa menjaga konsistensi accumulator global bikin underflow di `earned()` user lain. Fix-nya: freeze accumulator global dulu (update `rewardPerTokenStored` + `lastUpdateTime`) SEBELUM saldo user dikurangi. Ada test khusus buat ini (E5, E6 di spec gw).

## 4. Deploy script yang "gagal" padahal kontraknya udah on-chain

Ini kejadian beneran pas 17 Sep. Deploy script gw revert di akhir: `vm.createDir: the path deployments is not allowed to be accessed for write operations`. Forge bilang "script failed".

Tapi `cast call` ke chain: kontraknya udah ada, wiring-nya bener.

Kenapa bisa? Karena revert yang terjadi di luar blok broadcast cuma nge-kill konteks eksekusi script. Transaksi yang udah kekirim itu irrevocable. Dan biang keroknya bukan permission OS: Foundry punya sandbox filesystem sendiri (`fs_permissions` di foundry.toml, default read-only).

Dua pelajaran dari satu kejadian: (1) exit code script =/= state chain, selalu assert on-chain pasca deploy; (2) "permission denied" di forge script, cek foundry.toml dulu.

Bonus masalah yang senada: field "deployer" di metadata gw salah address, karena `msg.sender` di konteks script itu default sender cheatcode, bukan address dari `--private-key`. Fix: `vm.addr(key)`.

## 5. Reward window mulai jalan saat setRewardRate (dan kenapa gw nerima itu)

Desain v1: `setRewardRate(newRate)` mulai periode 7 hari SEKARANG (`periodFinish = now + DURATION`). Kalau deploy, terus user baru stake besok, reward sehari penuh hangus: pool kosong = akumulasi diam (edge case E10 di spec gw).

Alternatifnya `notifyRewardAmount()` ala Synthetix yang bisa top-up mid-period tanpa mundurin finish. Itu stretch goal yang gw gak ambil di v1, dengan sadar. V1 ini untuk mastiin pattern dasar bener; kompleksitas tambahan harus beli sesuatu yang gw butuhkan, bukan sekadar biar keliatan lengkap.

Konsekuensi operasionalnya gw tulis di README: stake segera setelah deploy, atau delay `setRewardRate` sampai mau launch.

## Penutup

Total: 75 test, semua kontrak utama 100% coverage, invariant handler dengan warp acak, dan frontend lengkap dengan wagmi. Angka-angka itu bisa direproduksi di repo (link menyusul setelah push).

Yang paling gw ambil dari project ini bukan kontraknya, tapi cara kerjanya: spesifikasi dulu (tabel edge case + invariant sebelum ngoding), TDD, invariant testing buat property yang harus selalu bener, dan devlog yang jujur soal masalah.

Next project: governance dApp (Governor + Timelock + ERC20Votes). Devlog per tanggal lanjut di sana.
