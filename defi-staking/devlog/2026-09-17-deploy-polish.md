# 17 Sep 2026 - Project 1: Deploy + Polish

> Task roadmap: "Deploy RewardToken + StakingPool ke Sepolia. Verify di Etherscan. Deploy frontend ke Vercel. Test full flow: connect wallet, stake, tunggu reward, claim. Buat Loom demo video 3 menit."

## Apa yang dikerjakan

- `script/DeployStaking.s.sol`: deployment lengkap dalam satu run sesuai urutan SPEC §9 (RewardToken dengan pre-mint bootstrap 1.000.000 RWT, StakingPool, `setStakingPool()` sekali, `setRewardRate(1e18)` terakhir).
- Script menulis `deployments/<chainId>.json` (chainId, deployedAt, deployer, contracts) supaya frontend gak perlu hardcode address.
- `foundry.toml` ditambah `fs_permissions` read-write (dibutuhkan cheatcode `vm.writeFile`, penjelasan di bawah).
- Verifikasi penuh di anvil lokal: broadcast sukses, lalu `cast call` untuk assert wiring.
- Slither check ulang: BELUM bisa dijalankan (slither gak ter-install di environment sekarang; hasil scan terakhir ada di `../security/SLITHER-REPORT.md` tanggal 30 Aug untuk project security). Instal ulang: `pip install slither-analyzer`, lalu `slither .` di root project. Ini masuk gate DoD SPEC §10.

## Masalah & Solusi

### fs_permissions: default Foundry cuma boleh baca

- Masalah: script sukses broadcast 3 transaksi, tapi di akhir revert dengan `vm.createDir: the path deployments is not allowed to be accessed for write operations`. File deployments JSON gak jadi ditulis.
- Kenapa: Foundry punya sandbox filesystem sendiri. Default `fs_permissions` hanya `read` pada project root, jadi cheatcode `vm.createDir` / `vm.writeFile` dari script di-reject. Ini bukan permission OS, tapi konfigurasi foundry.toml, desainnya biar script gak seenaknya nulis file di mesin lo.
- Solusi: tambah `fs_permissions = [{ access = "read-write", path = "./" }]` di `foundry.toml`. Scope-nya masih project dir, bukan full disk.
- Pelajaran: "permission denied" di forge script cek dulu foundry.toml, bukan asumsi masalah OS.

### Script "failed" padahal transaksinya sudah on-chain

- Masalah: setelah revert di bagian penulisan JSON, forge melaporkan `Error: script failed`, tapi ketiga kontrak SUDAH terdeploy di anvil (bisa di-cast call).
- Kenapa: revert yang terjadi di luar blok `vm.startBroadcast()` / `vm.stopBroadcast()` cuma membatalkan konteks eksekusi script, bukan transaksi yang sudah terkirim. Transaksi broadcast itu irrevocable, sama seperti mainnet.
- Solusi: dua hal. Pertama, urutan diperbaiki: semua operasi yang bisa gagal (penulisan JSON) tetap di akhir, tapi sekarang dipastikan tidak ada asumsi "script gagal berarti tidak ada yang terdeploy". Kedua, assert pasca-deploy dilakukan via `cast call` terpisah, bukan percaya exit code script saja.
- Pelajaran: exit code script ≠ state chain. Selalu verifikasi state on-chain setelah deploy.

### Metadata deployer salah: msg.sender di script bukan address dari PRIVATE_KEY

- Masalah: field `deployer` di deployments JSON pertama menunjuk `0x1804c8AB...` (default sender cheatcode), padahal tx benar-benar dikirim dari address `0xf39Fd6e5...` (yang di-derive dari PRIVATE_KEY).
- Kenapa: forge script menjalankan `run()` dengan `msg.sender` = default sender (biasanya `0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38`). Flag `--private-key` hanya menentukan `tx.from` saat broadcast, bukan `msg.sender` di konteks script.
- Solusi: derive eksplisit `address deployer = vm.addr(deployerKey)` di `run()` dan pass sebagai parameter ke `_writeDeploymentJson()` (sekaligus belajar: variabel lokal `run()` gak kelihatan di fungsi lain, awalnya error `Undeclared identifier` karena lupa pass parameter).
- Pelajaran: `tx.from` ≠ `msg.sender` di konteks script; kalau butuh identitas deployer yang benar, derive dari key atau `vm.envAddress("DEPLOYER")`.

### console.log tidak otomatis tersedia di script

- Masalah: kompilasi script gagal `Undeclared identifier` di baris `console.log(...)`, padahal `Script` sudah di-import.
- Kenapa: `forge-std/Script.sol` meng-import `console` untuk pemakaian internalnya, tapi import Solidity tidak bersifat re-export. Script yang meng-import `Script` tidak mewarisi simbol `console`.
- Solusi: `import {console} from "forge-std/console.sol";` eksplisit di script.
- Pelajaran: di Solidity, import itu file-scoped, bukan transitif.

### Reward window mulai berjalan saat setRewardRate, bukan saat user stake

- Masalah: desain kontrak (SPEC §4) memulai periode 7 hari tepat di `setRewardRate`. Kalau deploy hari ini tapi user baru stake besok, reward sehari penuh hangus (edge case E10: pool kosong, akumulasi diam, reward gak diakumulasi ke siapa pun).
- Kenapa: `periodFinish = block.timestamp + DURATION` di-set saat rate ditetapkan; kontrak v1 sengaja simpel tanpa `notifyRewardAmount` stretch-goal.
- Solusi: di deploy script, `setRewardRate` dipanggil terakhir (setelah wiring), dan README memberi tahu opsionalnya: untuk demo, jalankan deploy lalu segera stake; untuk produksi, panggil ulang `setRewardRate` di momen launch. Trade-off eksplisit, bukan bug.
- Pelajaran: timing parameter ekonomi (reward window) adalah keputusan operasional, bukan sekadar urutan deployment.

## Status jujur

Done dan terverifikasi:
- `forge build` exit 0.
- Deploy di anvil (port 8545, private key default anvil): `RewardToken: 0x5FbDB2315678afecb367f032d93F642f64180aa3`, `StakingPool: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512`.
- Assert via cast: `rewardToken.stakingPool()` = address pool (wiring benar), `rewardRate()` = 1e18 wei/detik, `periodFinish()` = deploy time + 604.800 detik, `owner()` = deployer, balance deployer = 1.000.000 RWT.
- `deployments/31337.json` tertulis dan isinya konsisten dengan assert.

Belum / butuh aksi manual (butuh kredensial yang cuma gw yang punya):
- Deploy Sepolia: siapkan `.env` dengan `PRIVATE_KEY`, `SEPOLIA_RPC_URL`, lalu `forge script script/DeployStaking.s.sol:DeployStaking --rpc-url $SEPOLIA_RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY`. Jangan pakai key dengan dana besar.
- Deploy frontend ke Vercel: menunggu frontend (16 Sep) dan address Sepolia.
- Loom demo 3 menit: setelah frontend live.
- Slither re-run (lihat catatan di atas).
