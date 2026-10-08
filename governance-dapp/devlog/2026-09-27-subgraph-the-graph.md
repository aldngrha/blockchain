# 27 Sep 2026: The Graph Subgraph (code only)

> Task roadmap: "Min 27 Sep, MINGGU, Project 2: The Graph untuk Governance. Setup subgraph untuk governance: index ProposalCreated, VoteCast, ProposalExecuted events. Query dari frontend untuk tampilkan proposal history dan vote history per user."

## Apa yang dikerjakan

- `subgraph/subgraph.yaml`: manifest network Sepolia, data source tunggal `GovernorContract` (5 event handler), address + startBlock placeholder jelas.
- `subgraph/schema.graphql`: 3 entity: `Proposal`, `Vote`, `Voter`.
- `subgraph/src/governance.ts`: 5 handler (ProposalCreated, VoteCast, ProposalQueued, ProposalExecuted, ProposalCanceled) dengan tally for/against/abstain dan agregat per voter.
- `subgraph/abis/Governor.json`: generate via `forge inspect GovernorContract abi --json`.
- `subgraph/package.json` + `subgraph/README.md`: perintah persis codegen/auth/deploy.

## Masalah & Solusi

### Kenapa governance butuh indexer: event history gak bisa dibaca dari state

- Masalah: frontend butuh "daftar semua proposal + riwayat vote per user". State kontrak cuma menyimpan tally + flag (`executed`, `canceled`). Daftar proposalId, siapa vote apa, dan alasan vote itu cuma ada di event. `eth_getLogs` manual berarti handle range, chunking, dan reorder sendiri.
- Kenapa: EVM state itu keadaan sekarang; riwayat itu log. Aplikasi riwayat = aplikasi index.
- Solusi: subgraph dengan 5 event. `Proposal` dari ProposalCreated, tally diupdate di VoteCast, lifecycle diupdate di Queued/Executed/Canceled. Frontend cukup GraphQL satu query.
- Pelajaran: kontrak yang baik meng-emit event yang cukup buat rekonstruksi semuanya. Semua data yang diindex di sini datang dari event bawaan OZ, tanpa nambah event custom.

### Status proposal di subgraph itu event-driven, Active/Defeated gak punya event

- Masalah: frontend butuh badge status Active/Defeated, tapi on-chain gak ada event yang menyatakan keduanya. Subgraph gak bisa tahu proposal "kalah" tanpa ngecall kontrak.
- Kenapa: Governor cuma meng-emit lifecycle event (created, queued, executed, canceled). Penilaian Succeeded/Defeated itu hasil perhitungan state saat dibaca, bukan state yang tersimpan.
- Solusi: field `status` di schema cuma ngikutin yang punya event (Pending/Queued/Executed/Canceled), dan README subgraph nyatakan eksplisit bahwa Active/Defeated harus dihitung frontend dari `voteEnd` + tallies (atau `governor.state()`). Gw gak mau ngefake status dengan timestamp guessing.
- Pelajaran: jangan biarkan indexer mengarang state yang gak didukung sumbernya. Skema yang jujur lebih murah daripada skema yang menggoda bug.

### Signature event OZ v5.4: cuma `voter` di VoteCast yang indexed

- Masalah: contoh subgraph yang beredar umumnya menulis `VoteCast(indexed address,indexed uint256,...)` ala versi OZ lama. Kalau signature di `subgraph.yaml` gak persis sama dengan ABI, `graph codegen`/deploy menolak.
- Kenapa: di v5.4 hanya `voter` yang indexed. `ProposalCreated`, `ProposalQueued`, `ProposalExecuted`, `ProposalCanceled` gak punya parameter indexed sama sekali (diverifikasi dari `forge inspect GovernorContract abi --json` + source `IGovernor.sol`).
- Solusi: signature di manifest ditulis persis: `ProposalCreated(uint256,address,address[],uint256[],string[],bytes[],uint256,uint256,string)` dst, dengan `indexed` cuma di voter.
- Pelajaran: generate ABI dari build artifacts (`forge inspect ... --json`), jangan salin dari blog.forge inspect di 1.5.1 default-nya ngeprint tabel cantik; tanpa `--json` output-nya bukan JSON (gw sempat kejadian, file pertama gak bisa di-parse).

### Versi graph-cli/graph-ts: pakai angka real, bukan asumsi

- Masalah: package.json subgraph butuh versi yang masuk akal. Nulis `^latest` atau versi karangan gak bisa dipertanggungjawabkan.
- Kenapa: gw gak menjalankan npm install (butuh akun Studio dan memang scope-nya code only), jadi satu-satunya jaminan adalah angka yang dicek langsung.
- Solusi: `npm view @graphprotocol/graph-cli version` -> 0.98.1, `@graphprotocol/graph-ts` -> 0.38.2. Kedua angka itu yang masuk package.json, dengan catatan di README buat cek ulang saat install.
- Pelajaran: angka di file yang gak dijalankan pun harus verifiable. Itu bedanya placeholder jujur dan data karangan.

## Status jujur

- Done: code lengkap (manifest, schema, handler, ABI, package.json, README dengan langkah deploy), placeholder address/startBlock jelas bertulisan "GANTI SETELAH DEPLOY SEPOLIA".
- BELUM dideploy dan BELUM pernah dicodegen. Butuh akun The Graph Studio + deploy key milik user. Langkah manual ada di `subgraph/README.md` (npm install -> codegen -> build -> auth -> deploy).
