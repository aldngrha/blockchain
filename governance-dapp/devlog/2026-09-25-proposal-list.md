# 25 Sep 2026: Frontend Proposal List

> Task roadmap: "Jum 25 Sep, BELAJAR, Project 2: Frontend, Proposal List. Build governance frontend: halaman proposal list dengan status badge (Active/Pending/Succeeded/Defeated/Executed). Tampilkan: proposer, deskripsi, for/against/abstain votes, deadline."

## Apa yang dikerjakan

- Frontend lengkap di `frontend/`: stack mirror `defi-staking/frontend` (Vite + React 19 + wagmi v3 + viem + RainbowKit v2 + TanStack Query 5 + oxlint, `.npmrc` legacy-peer-deps). Route detail pakai hash router kecil (`#/proposal/:id`), bukan react-router, biar dependency tetap sama persis dengan dua project sebelumnya.
- Sumber data list: scan event `ProposalCreated` via `getLogs` dari address governor, cache incremental di localStorage (key `governance-dapp-proposals-<chainId>-<governor>`), update live via `watchContractEvent` (5 event governance) + polling 15 detik.
- Badge 8 state (Pending/Active/Canceled/Defeated/Succeeded/Queued/Expired/Executed) dari `state()` governor, warna dipetakan ke arti state (amber nunggu, biru bisa aksi, hijau lolos, merah kalah, netral terminal).
- Tiap kartu: proposer, deskripsi, for/against/abstain (format 18 desimal), deadline (blok + estimasi tanggal dari sampel rata-rata block time), progress quorum.
- Halaman detail `/proposal/:id`, form delegate, form create payout proposal, UI states lengkap (address belum configured, gak connect, salah chain, loading scan, error scan + retry, list kosong).

## Masalah & Solusi

### `ProposalCreated` di OZ 5.4 punya field `signatures` yang gak disebut brief

- Masalah: gw mulai nulis ABI event dengan 8 field sesuai brief (`proposalId, proposer, targets, values, calldatas, voteStart, voteEnd, description`). Topic hash-nya beda dengan yang di-chain.
- Kenapa: OZ 5.4.0 yang ter-install (cek `out/GovernorContract.sol/GovernorContract.json`) masih mempertahankan field `signatures: string[]` di antara `values` dan `calldatas`, jadi signature event-nya 9 field. Banyak dokumentasi OZ v5 nampilin versi 8 field.
- Solusi: semua ABI frontend gw tulis dengan sumber kebenaran file hasil compile (`out/`), bukan ingatan. `cast keccak` dua signature itu: 9 field = `0x7d84a626...`, 8 field = `0x95f03e43...`. Satu field salah = filter log balikin nol hasil, tanpa error.
- Pelajaran: ABI hand-written harus diverifikasi ke artifact compile, apalagi buat event yang field-nya beda antar versi OZ.

### viem `getLogs` diam-diam mengabaikan `abi` + `eventName`

- Masalah: scan pertama balikin 6 log padahal di-chain cuma ada 1 `ProposalCreated`. Decode log-log itu hasilnya `args` kosong, jadi list bakal kosong atau berisi sampah, dan gak ada satu pun error di console.
- Kenapa: di viem 2.57.3, fungsi inti `getLogs` cuma nerima `event` / `events` (ABI item). Kombinasi `abi` + `eventName` itu gak ada di signature-nya dan diabaikan tanpa warning, jadi request terkirim tanpa filter topic dan balikin semua log di range. Kode gw file `.js` tanpa type check, jadi salah API ini lolos.
- Solusi: resolve event dulu sekali di module scope: `getAbiItem({ abi: GOVERNOR_ABI, name: "ProposalCreated" })`, lalu pass sebagai `event:` ke `getLogs` (plus `args` buat filter `VoteCast` per proposal). Setelah itu scan balikin tepat log yang dimaksud.
- Pelajaran: tanpa type checking, kesalahan bentuk API bisa nyaris invisible. Build pass bukan bukti jalur data jalan; smoke test runtime yang nangkep ini.

### Deskripsi proposal gak ada di view call, cuma di event log

- Masalah: roadmap minta deskripsi tampil di list, tapi gak ada view call yang balikin deskripsi dari proposal id. ID itu hash dari (targets, values, calldatas, descriptionHash), deskripsi plain-nya cuma lewat sebagai data event.
- Kenapa: kontrak sengaja gak nyimpen deskripsi di storage (hemat gas, deskripsi bisa panjang), jadi indexing deskripsi itu kerjaan indexer, bukan kontrak.
- Solusi: scan event jadi sumber kebenaran, hasilnya di-cache localStorage keyed `chainId + governor` dengan record per `proposalId` (proposer, targets, values, calldatas, description, voteStart, voteEnd). Form create proposal juga langsung nulis record dari receipt (`parseEventLogs` atas `ProposalCreated`) biar proposal sendiri tampil segera. Kalau deskripsi gak ada di cache, UI bilang apa adanya dan ngesuggest rescan/subgraph.
- Pelajaran: localStorage di sini cache, bukan database: data sumbernya tetap event log, dan cache-nya di-replace tiap rescan. Pola ini fragile karena range scan (first load dari blok 0 lambat di testnet), reorg (gw scan ulang 20 blok terakhir sebagai margin), dan pruning log oleh RPC. Solusi penuhnya subgraph yang udah disiapkan di `subgraph/` (task 27 Sep).

### `quorum(snapshot)` dan `getPastVotes(snapshot)` revert buat proposal Pending

- Masalah: progress bar quorum di list manggil `quorum(voteStart)` per proposal. Buat proposal Pending, call itu revert `ERC5805FutureLookup` karena `getPastTotalSupply` gak boleh dilihat di timepoint masa depan.
- Kenapa: `GovernorVotesQuorumFraction.quorum(timepoint)` guard `timepoint >= clock()` langsung revert, dan memang secocok itu: di snapshot masa depan total supply checkpoint-nya belum ada.
- Solusi: baca block head dulu, baru panggil `quorum` dan `getPastVotes` hanya kalau `snapshot < head`. UI Pending nampilin "not measurable yet" dengan penjelasan singkat, bukan angka palsu.
- Pelajaran: read on-chain bisa revert bukan karena bug tapi karena semantik waktu (ERC-6372). Gate read berdasarkan urutan blok, jangan telen errornya.

## Status jujur

- Done: `npm install` + `npm run build` exit 0, `npm run lint` 0 warning 0 error. Scan + decode event terverifikasi jalan (lihat devlog 26 Sep buat smoke test penuhnya).
- Verifikasi UI: build pass dan smoke test jalur RPC, tapi klik-klik halaman di browser dengan wallet asli butuh MetaMask manual (gw jalan tanpa browser GUI di environment ini). Yang perlu dicek manual user tercatat di `frontend/README.md`.
- UI tercatat sebagai draft tanpa arahan desain (gak ada DESIGN.md): ENERGY 1 / RHYTHM 1 / MOTION 1, tema terang fix, palet batu netral + aksen biru.
- Port anvil 8545 gw pakai buat smoke test sendiri; 8547 milik agent kontrak, gak disentuh.
