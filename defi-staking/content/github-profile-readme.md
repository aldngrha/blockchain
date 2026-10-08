# Draft GitHub Profile README (repo <username>/<username>)

Status: DRAFT. Replace <username> dan sesuaikan sebelum push ke repo profile. Prinsip: cuma klaim yang bisa diklik buktinya; status project yang masih jalan ditulis sebagai status, bukan sebagai selesai.

---

Hi, gw <username>. SWE yang lagi transisi ke blockchain engineering. Latihan gw strukturnya bukan "nonton tutorial", tapi: spesifikasi dulu, TDD, invariant testing, dan devlog jujur per tanggal.

## Lagi dikerjakan (roadmap 9 bulan, devlog per tanggal)

- **Project 1: DeFi Staking Protocol** (Foundry, Solidity 0.8.20, OZ v5)
  Staking pool pola Synthetix dengan mint-on-claim. 75 test, coverage kontrak utama 100%, invariant suite (anti stuck funds, anti mint bocor), frontend wagmi.
  Status: kontrak + test + frontend done; deploy Sepolia menyusul.
- **Project 2: Governance dApp** (OZ Governor v5 + TimelockController + ERC20Votes)
  Full lifecycle: propose, vote, queue lewat timelock, execute.
  Status: in progress.
- **Project 3: SimpleDex (AMM)**
  Uniswap v2 style: x*y=k, LP token, slippage + deadline protection, invariant k non-decreasing.
  Status: in progress.

## Cara gw belajar (yang beda dari tutorial)

1. Spec dulu sebelum ngoding: tabel edge case dan invariant ditulis sebelum fungsi pertama.
2. Test yang bermakna: bukan cuma happy path; tiap revert punya test, tiap invariant punya handler.
3. Devlog jujur: tiap tanggal ada masalah nyata, root cause, dan solusi. Ini juga bahan artikel gw.

## Stack

Solidity (0.8.20+), Foundry (forge/anvil/cast), OpenZeppelin v5, EIP-2935.. belum, fokus dulu: ERC-20/721/1155, Governor, reentrancy & access control patterns, wagmi/viem/RainbowKit buat frontend. Background: software engineering (backend).

## Konten

- Mirror.xyz: artikel teknis dari project gw (link setelah publish).
- Devlog tiap project ada di foldernya masing-masing.

## Contact

DM terbuka di X untuk feedback soal project di atas.
