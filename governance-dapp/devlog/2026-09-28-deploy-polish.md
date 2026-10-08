# 28 Sep 2026: Deploy + Polish (anvil verified)

> Task roadmap: "Sen 28 Sep, GYM HARI, Project 2: Deploy + Polish. Deploy semua governance contracts ke Sepolia. Verify di Etherscan. Deploy frontend ke Vercel. Full end-to-end test: buat proposal, vote, tunggu timelock, execute. Buat demo video Loom."

## Apa yang dikerjakan

- `script/DeployGovernance.s.sol`: token -> timelock (admin sementara deployer) -> governor -> grant roles -> renounce -> treasury payable + fund 0.1 ETH -> `token.delegate(deployer)` -> tulis `deployments/<chainId>.json` + sanity assert.
- Verifikasi penuh di anvil port 8547 (port khusus): broadcast sukses, state diverifikasi via `cast call`.
- README dengan hasil nyata + langkah Sepolia manual.

## Masalah & Solusi

### GOVERNOR GAGAL DEPLOY: EIP-170, 28857 bytes > 24576 (temuan paling penting minggu ini)

- Masalah: broadcast pertama bilang `Script ran successfully` dengan address cantik, tapi `cast code <governor>` mengembalikan `0x`. Anvil mencatat: `Error: 'Unknown1' is above the contract size limit (28857 > 24576)`. Governor LITERALLY gak ada kode di chain, dan transaksi setelahnya (grant, treasury, delegate) ikut gagal karena nonce bolong.
- Kenapa: stack Governor OZ v5 + 4 extension dicompile tanpa via-ir menghasilkan runtime 28.857 bytes, melebihi limit EIP-170 (24.576 bytes) yang ditegakkan anvil DAN akan ditegakkan Sepolia/mainnet. `forge script` menampilkan sukses karena simulasi (eth_call) gak menegakkan limit itu; kegagalan baru muncul saat broadcast nyata. Ini jebakan klasik "simulasi lolos, eksekusi mati".
- Solusi iterasi:
  1. `via_ir = true` saja: runtime malah BESAR jadi 31.245 bytes (via-ir + optimizer 200 runs lebih agresif di gas, bukan size).
  2. Tambah `optimizer_runs = 1000`: runtime jadi 16.405 bytes. Jauh di bawah limit.
  3. `cast codesize` setelah deploy ulang: 16.404 bytes.
- Pelajaran: untuk kontrak besar, cek ukuran bytecode sebagai bagian dari CI (`forge inspect <C> abi` gak cukup; pakai `deployedBytecode` dari artifact atau `cast codesize` setelah deploy lokal). Dan jangan percaya "Script ran successfully" tanpa cek kode kontrak di chain.

### via-ir "memutar balik" nilai turunan `block.number` di test: `ERC5805FutureLookup(2,2)` lalu `(4,4)`

- Masalah: setelah ganti compiler pipeline, `test_PastVotesAtHistoricBlocks` gagal dengan error lookup checkpoint di masa depan. Trace menunjukkan `VM::roll(2)` dipanggil DUA KALI (harusnya roll 2 lalu 3), dan setelah refactor pakai local variable, `VM::roll(4)` muncul padahal kodenya `vm.roll(transferBlock + 1)` dengan transferBlock = 2.
- Kenapa: via-ir memperlakukan `block.*` sebagai invariant dalam satu transaksi (secara EVM spec memang benar), jadi ekspresi yang di-root ke `block.number` di-re-derive di titik PEMAKAIAN, bukan dievaluasi di titik assignment. Local variable `b = block.number` secara efektif "berubah" setelah `vm.roll`. cheatcode vm.roll mutasi konteks yang tidak diketahui optimizer.
- Solusi: test historis pakai target block ABSOLUT (forge mulai di block 1, jadi roll(2), roll(3)) dengan assert awal `block.number == 1` sebagai guard, dan nilai yang direcord jadi konstanta lokal literal. Test lain yang roll-nya satu kali per ekspresi gak terganggu (diverifikasi: 33/33 hijau).
- Pelajaran: ganti pipeline compiler itu bukan ganti kecepatan doang, tapi ganti asumsi yang boleh dilakukan optimizer. Test yang bergantung pada cheatcode mutasi harus gak punya nilai turunan `block.*` yang dipakai ulang.

### Deployer HARUS di-derive dari PRIVATE_KEY, bukan msg.sender

- Masalah: metadata deployer di JSON awalnya pakai `msg.sender`. Di konteks script, `msg.sender` itu default sender cheatcode (`0x1804c8AB1F6E56ab2FDea9902867ca2cA9Ce33d` atau yang diset vm), BUKAN address dari PRIVATE_KEY yang dibroadcast.
- Kenapa: forge menjalankan script dengan sender virtual; hanya `vm.startBroadcast(privateKey)` yang mengubah sender tx jadi address hasil derive key.
- Solusi: `address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));` persis pola yang sama di project 1 (`DeployStaking.s.sol`), dipakai untuk metadata JSON dan renounce timelock.
- Pelajaran: di script, `msg.sender` itu kecuali kasus; derive dari key itu norma. Sama-sama belajar paham saat Project 1, sekarang kelihatan kenapa.

### Verifikasi penuh, bukan cuma "script sukses"

- Masalah: sukses broadcast itu bukan bukti wiring benar. Banyak titik gagal senyap: role salah target, admin lupa renounce, treasury kosong, supply salah, delegate lupa.
- Kenapa: semua langkah itu kalau dilewat bakal ketahuan pas demo (atau lebih buruk, pas produksi).
- Solusi: sanity assert di akhir script (PROPOSER/CANCELER di governor, admin deployer sudah renounce, saldo treasury, supply) + verifikasi manual via cast setelah broadcast:
  - `cast codesize <governor>` = 16404
  - `hasRole(PROPOSER_ROLE, governor)` = true, `hasRole(CANCELLER_ROLE, governor)` = true
  - `hasRole(EXECUTOR_ROLE, address(0))` = true, `hasRole(DEFAULT_ADMIN_ROLE, deployer)` = false
  - `getMinDelay()` = 86400, treasury balance = 0.1 ETH
  - `totalSupply()` = 1e24, `getVotes(deployer)` = 1e24
  - `votingDelay()` = 7200, `votingPeriod()` = 50400, `quorumNumerator()` = 4
  - `deployments/31337.json` terisi format yang disepakati frontend.
- Pelajaran: "deploy sukses" itu properti tx; "deployment benar" itu properti state. Verifikasi yang kedua.

## Status jujur

- Done lokal: anvil 8547 (chainId 31337), 4 kontrak terdeploy dan terverifikasi (tabel di README), deployments JSON benar, test suite 33/33 hijau dengan build final (via_ir + optimizer_runs 1000).
- BELUM dikerjakan dari roadmap hari ini (butuh akses yang cuma user punya):
  - Deploy Sepolia + verify Etherscan: butuh PRIVATE_KEY user + RPC. Perintah persis ada di README.
  - Full end-to-end di Sepolia (propose -> vote -> timelock 1 hari -> execute) yang butuh jeda nyata 1 hari.
  - Deploy frontend ke Vercel + video Loom: bagian frontend dikerjakan agent terpisah.
