# Demo Script: SimpleDex Loom (3-5 menit)

> Catatan: perekaman video dan upload Loom adalah aksi manual user. File ini script-nya saja: blok waktu, langkah klik, dan kalimat yang bisa dibacakan. Semua angka di bawah dihitung dari mirror JS frontend (tervalidasi 26 vektor eksak dari test suite Solidity, plus smoke test on-chain yang bit-exact), untuk urutan aksi yang PERSIS seperti di script ini. Kalau urutan atau jumlah swap-nya lo ubah, angka di layar akan beda dari yang tertulis, dan itu normal: sebut saja angka di layar saat rekam.

## Prasyarat sebelum rekam (checklist)

- [ ] `anvil -p 8548` jalan (terminal 1).
- [ ] Deploy script sudah dijalankan dari root repo: `forge script script/DeploySimpleDex.s.sol:DeploySimpleDex --rpc-url http://127.0.0.1:8548 --broadcast` (pool ter-seed 1000 SDA + 1000 SDB).
- [ ] `npm run dev` di `frontend/`, buka `http://localhost:5173`.
- [ ] MetaMask sudah import private key anvil pertama (`0xac09...`), wallet terhubung dan berada di network Anvil (31337). Deployer punya sekitar 10.000 SDA + 10.000 SDB.
- [ ] Layar rekam 1280x720 atau lebih besar; zoom browser 100%.

## 0:00-0:45 - Konsep AMM dalam 45 detik

Tampilan: halaman Swap, belum ada input.

Kalimat pembacaan:

"Ini SimpleDex, AMM dua token yang gw implement dari scratch. Konsepnya satu persamaan: x kali y = k. Pool simpan 1000 token A dan 1000 token B, jadi k = 1 juta (dalam satuan token). Swap gak nambah likuiditas: dia cuma geser pool di sepanjang kurva itu. Makanya makin besar swap lo, makin jelek harga yang lo dapat, dan itu kelihatan langsung di demo sebentar lagi. Fee 0.3% dipotong dari input, dikodekan 997 per 1000, dan fee itu mengendap di pool: itulah pendapatan liquidity provider."

## 0:45-2:30 - Demo swap di anvil

Langkah:

1. Isi "You pay" dengan `10`, arah SDA ke SDB (default).
2. Arahkan kursor ke kotak quote: "Pool price: 1 SDA = 1 SDB", "Price impact (execution): 1.28%", "Minimum received: 9.82222442250759923 SDB (slippage 0.5%)".

Kalimat: "Output dihitung di browser dengan rumus yang sama persis dengan kontrak: output = (in kali 997 kali reserveOut) dibagi (reserveIn kali 1000 plus in kali 997). Swap 10 SDA di pool 1000/1000 menghasilkan 9.871580343970612988 SDB. Bukan 9.9, karena fee 0.3% dan kurva produk konstan."

3. Klik "Approve SDA, then swap". Karena allowance masih nol, ini dua transaksi: approve dulu, lalu swap. Tunjukkan MetaMask mengonfirmasi dua kali, tombol menampilkan status step ("Approving SDA (1/2)..." lalu "Swapping (2/2)...").
4. Setelah konfirmasi: banner "Swap confirmed", balance SDB bertambah 9.871580343970612988, reserve berubah jadi 1010 SDA / 990.128419656029387012 SDB.

Kalimat: "Perhatikan harga pool sekarang: 990.128 dibagi 1010, sekitar 0.9803 SDB per SDA. Pool bergerak sepanjang kurva, itu yang dijaga event Sync."

5. Sekarang swap besar: isi `300`.
6. Tunjukkan angka quote: "Price impact (execution): 23.07%", "Marginal price after: ... (impact 40.51%)".

Kalimat: "Ini beda dua definisi impact yang sering bikin bingung. Yang execution, 23.07%, itu seberapa jelek harga rata-rata trade ini dibanding pool price sebelum swap. Yang marginal, 40.51%, itu seberapa jauh pool price pindah SETELAH swap ini: harga untuk wei berikutnya. Marginal selalu lebih besar karena kurva makin curam sepanjang eksekusi. Swap 300 SDA dapat sekitar 226.22 SDB, bukan 300: itu konsekuensi x*y=k."

7. Klik swap (approve sudah cukup dari sebelumnya kalau jumlahnya lebih kecil; kalau diminta approve lagi, jalankan). Setelah konfirmasi, reserve jadi 1310 SDA / 763.906274427155817648 SDB.

## 2:30-4:00 - Demo add + remove liquidity

Langkah:

1. Pindah ke tab "Liquidity". Tunjukkan Pool stats: Reserve 1310 SDA, Reserve 763.906274427155817648 SDB, LP total supply 1000 SDX-LP. Position: 1000 SDX-LP, share 100%.

Kalimat: "Satu kontrak DexPair itu sekaligus pool DAN token LP-nya. 1000 wei LP pertama sengaja dikunci di pair selamanya (MINIMUM_LIQUIDITY), itu pertahanan terhadap inflation attack di provision pertama."

2. Di form Add, isi token0 `500`. Muncul guidance: "Pool ratio suggests 291.567280315708327346 SDB". Klik "Use suggested".
3. Tunjukkan "Expected LP mint: 381.679389312977099235 SDX-LP".

Kalimat: "Guidance rasio ini pakai rumus quote yang sama dengan kontrak. Kalau gw isi angka lain yang rasionya off, kontraknya tetap aman: dia cuma narik proporsi yang sesuai rasio pool dan kelebihannya gak pernah ditransfer, sisa saldo tetap di wallet. Itu perilaku refund yang asli dari implementasi addLiquidity-nya: bukan ditarik lalu dikembalikan, tapi tidak ditarik sama sekali."

4. Klik "Add liquidity" (kalau allowance SDB kurang, dua-tiga tx approve + add). Setelah konfirmasi: Position bertambah jadi sekitar 1381.679389312977099235 LP, share di bawah 100%, reserves naik.

5. Di form Remove, klik "Max" lalu kurangi menjadi setengah dari LP yang barusan didapat: `190.839694656488549617`.

6. Tunjukkan estimasi payout: "249.999999999999999998 SDA + 145.783640157854163672 SDB".

Kalimat: "Burn setengah dari LP yang barusan gw tambahkan, dapat balik setengah dari yang gw deposit: 250 SDA dan 145.78 SDB, dibulatkan ke bawah, debu pembulatannya tinggal di pool. Perhatikan gak ada tombol approve di form ini: pair membakar LP gw langsung lewat _burn, dan _burn gak butuh allowance."

7. Klik "Remove liquidity". Setelah konfirmasi: saldo dua token naik, LP berkurang, share turun.

## 4:00-4:30 - Penutup

Kalimat: "Itu dia: swap dengan slippage protection dan deadline, price impact dua definisi, dan liquidity provision dengan pembagian pro-rata yang eksak. Semua kontraknya gak diaudit dan ini jalan di chain lokal, jadi jangan pakai dana beneran. Kodenya dan catatan build-nya ada di repo simple-dex: 53 test termasuk fuzz dan invariant suite, plus devlog per hari. Terima kasih."

## Catatan produksi

- Durasi total target 3.5-4.5 menit. Kalau melebihi 5 menit, pangkas bagian konsep, bukan bagian demo.
- Kalau MetaMask meminta switch network, pakai banner di app (tombol "Switch to Anvil"), jangan manual dari extension, supaya terlihat states UI-nya.
- Angka yang dijamin muncul persis (urutan aksi persis seperti di atas): 9.871580343970612988, 1.28%, 1010 / 990.128419656029387012, 226.222145228873569364, 23.07%, 40.51%, 1310 / 763.906274427155817648, 291.567280315708327346, 381.679389312977099235, 190.839694656488549617, 249.999999999999999998, 145.783640157854163672.
- Yang TIDAK disebut di video: klaim keamanan ("audited", "production-ready"), angka gas, dan perbandingan dengan Uniswap produksi. Gak ada datanya, gak disebut.
