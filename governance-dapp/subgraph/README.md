# Subgraph Governance dApp

Subgraph buat index riwayat governance: proposal dibuat, vote masuk, proposal masuk
timelock, dieksekusi, atau dibatalkan. Semua event diambil dari satu kontrak:
`GovernorContract` (OZ Governor v5.4).

## Status jujur

Code + konfigurasi SIAP, tapi BELUM pernah dicodegen, dibuild, atau dideploy.
Alasannya: deploy ke The Graph Studio butuh akun + API/deploy key milik lo.
Gw gak mau ngarang hasil. Langkah di bawah dijalankan manual sama lo.

## Isi folder

| File | Fungsi |
|---|---|
| `subgraph.yaml` | Manifest: data source GovernorContract di network Sepolia |
| `schema.graphql` | 3 entity: `Proposal`, `Vote`, `Voter` |
| `src/governance.ts` | 5 handler: ProposalCreated, VoteCast, ProposalQueued, ProposalExecuted, ProposalCanceled |
| `abis/Governor.json` | ABI hasil `forge inspect GovernorContract abi --json` |

## Yang wajib lo ganti dulu (2 titik di `subgraph.yaml`)

1. `source.address`: address Governor hasil deploy Sepolia. Ambil dari
   `deployments/11155111.json`, field `contracts.Governor`. Placeholder-nya
   address nol, sengaja bikin deploy gagal kalau lupa diganti.
2. `source.startBlock`: nomor block Sepolia saat Governor ter-deploy (cek output
   broadcast script atau Etherscan). Kalau dikasih `0`, indexing tetap jalan tapi
   sangat lambat.

## Langkah deploy (butuh akun The Graph Studio)

```bash
cd subgraph
npm install

# 1. Generate types dari schema + ABI (harus sukses sebelum lanjut)
npm run codegen

# 2. Sanity check manifest + mapping
npm run build

# 3. Deploy key dari dashboard The Graph Studio (Authorization: Bearer <key>)
npm run auth -- --studio <DEPLOY_KEY>

# 4. Deploy subgraph bernama "governance-dapp" ke akun Studio lo
npm run deploy
```

Versi yang dipakai di `package.json`: `@graphprotocol/graph-cli` 0.98.1 dan
`@graphprotocol/graph-ts` 0.38.2 (cek `npm view @graphprotocol/graph-cli version`
kalau mau update). Setelah deploy, Studio kasih endpoint GraphQL yang bisa
dipanggil dari frontend.

## Catatan desain

- **Status proposal di subgraph itu event-driven, bukan state penuh.** On-chain
  cuma emit event buat `Pending` (ProposalCreated), `Queued`, `Executed`, dan
  `Canceled`. State `Active` dan `Defeated` gak punya event, jadi frontend harus
  menghitungnya sendiri dari `voteEnd` + tallies (atau `governor.state()`).
  Field `status` di entity `Proposal` cuma ngikutin lifecycle yang punya event.
- **Signature event mengikuti OZ v5.4 persis.** Beda dengan versi lama: di v5.4
  cuma `voter` di `VoteCast` yang indexed. `ProposalCreated`, `ProposalQueued`,
  `ProposalExecuted`, dan `ProposalCanceled` gak punya parameter indexed.
- **Satu vote per voter per proposal** di-enforce kontrak
  (`GovernorAlreadyCastVote`), makanya id `Vote` boleh composite
  `<proposalId>-<voter>` tanpa risiko tabrakan.
- Entity `Voter` cuma tercatat buat address yang pernah vote. Ada beda tipis
  antara "voter" (yang vote) dan "delegator" (yang punya voting power). Kalau
  butuh data delegasi, tambahin data source kedua untuk `GovernanceToken`
  (event `DelegateChanged` dan `DelegateVotesChanged`) dan entity `Delegation`.

## Contoh query

```graphql
{
  proposals(first: 10, orderBy: createdAtBlock, orderDirection: desc) {
    id
    proposer
    description
    status
    forVotes
    againstVotes
    abstainVotes
    etaSeconds
    votes {
      voter { address }
      support
      weight
      reason
    }
  }
}
```

`proposer` bertipe `Bytes!` (alamat EOA/contract), bukan entity, karena data
proposer sudah cukup dari event. Kalau butuh riwayat delegasi (siapa punya
voting power), tambahin data source kedua untuk `GovernanceToken` (event
`DelegateChanged` dan `DelegateVotesChanged`) dan entity `Delegation`.
