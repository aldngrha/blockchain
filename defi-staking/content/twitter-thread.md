# Draft Thread X: Project 1 DeFi Staking (publish setelah repo di-push)

Catatan sebelum publish: draft ini bahasa Indonesia; kalau target audiensnya juga dev global, terjemahkan ke English sebelum post. Gak ada angka metrik di thread karena repo belum public saat draft ini ditulis; setelah repo live, boleh tambah link di tweet terakhir.

---

T1/7
3 minggu lalu gw mulai project pertama gw di blockchain: DeFi Staking Protocol.
Bukan yang fancy: 1 pool, 1 token, reward per detik pola Synthetix.
Tapi gw memaksakan diri: 75 test, invariant testing, dan frontend lengkap.
Thread: 4 masalah nyata yang gw temui (dan cara nyelesainnya).

T2/7
Masalah 1: deploy script gw "gagal", tapi kontraknya ternyata udah terdeploy.
Kenapa? Revert yang kejadian di luar blok broadcast cuma matiin konteks eksekusi script.
Transaksi yang udah kekirim itu irrevocable, sama kayak mainnet.
Pelajaran: exit code script =/= state chain. Selalu assert via cast call.

T3/7
Masalah 2: field "deployer" di metadata gw nunjuk address yang salah.
Turns out: msg.sender di konteks forge script itu default sender cheatcode, BUKAN address dari --private-key.
--private-key cuma nentuin tx.from saat broadcast.
Fix: derive eksplisit pake vm.addr(key).

T4/7
Masalah 3: cheatcode vm.writeFile gw di-revert: "path not allowed for write operations".
Bukan permission OS. Foundry punya sandbox file sendiri lewat fs_permissions di foundry.toml, default-nya read-only.
Pelajaran: "permission denied" di forge script, cek foundry.toml dulu.

T5/7
Masalah 4 (desain, bukan bug): reward window mulai jalan saat setRewardRate().
Kalau deploy terus user stake besok, reward sehari hangus (pool kosong = akumulasi diam, kayak Synthetix).
Trade-off simpel vs top-up mid-period (notifyRewardAmount). v1 gw pilih simpel, trade-off-nya gw dokumentasiin di README.

T6/7
Bagian yang paling worth it: invariant testing.
I-2: sum(stakedBalance) == totalStaked
I-4: total mint == total claim (gak ada mint bocor)
I-5: unstake all + claim = state bersih, gak ada stuck funds
75 test, coverage kontrak utama 100%.

T7/7
Next: Project 2, governance dApp (Governor + Timelock + ERC20Votes).
Gw dokumentasiin per-tanggal di devlog: masalah, kenapa, solusi.
(Link repo setelah push.)
