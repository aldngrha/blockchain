# Catch-up Implementation Plan: 16 Sep - 6 Okt 2026

> **Untuk agentic workers:** plan ini dieksekusi via 3 sub-agent paralel (A, B, D) + agent C, dengan verifikasi terpusat. Checkbox untuk tracking.

**Goal:** Menyelesaikan seluruh deliverable ROADMAP.md dari 16 Sep (Project 1 frontend) sampai 6 Okt (AMM deploy L2), termasuk devlog per tanggal (masalah / kenapa / solusi).

**Architecture:** 3 project Foundry + 2 frontend Vite. Project 1 (defi-staking) tinggal frontend + deploy script. Project 2 (governance-dapp) full baru: OZ Governor v5 stack. Project 3 (simple-dex) AMM x*y=k ala Uniswap v2.

**Tech Stack:** Foundry (forge 1.5.1), OpenZeppelin v5, Vite + React 19 + wagmi v3 + viem + RainbowKit v2 + TanStack Query 5 (mengikuti stack proven `nft-minting-dapp/frontend`), The Graph subgraph (code only).

## Global Constraints

- Kode & komentar kode: Inggris. Dokumen (README/SPEC/devlog): Indonesia santai (lo/gw), istilah teknis Inggris.
- DILARANG em dash (`—`) di semua teks baru. Pakai koma/titik/kurung.
- No AI slop: tanpa emoji di dokumen, tanpa klaim kosong, tanpa statistik palsu, tanpa bahasa marketing.
- Devlog JUJUR: hanya masalah yang benar-benar terjadi saat mengerjakan. Langkah yang butuh aksi manual user (private key, RPC, akun The Graph, video) ditandai jelas, tidak difabricate.
- Semua kontrak harus lulus `forge build` + `forge test`. Semua frontend harus lulus `npm run build`. Deploy script terverifikasi dengan `anvil` + `forge script --broadcast`.
- JANGAN init git, JANGAN deploy ke testnet sungguhan, JANGAN punya file di luar project masing-masing.

## Interfaces (kontrak antar-tim)

1. **Deployments JSON** (standar semua project, ditulis oleh deploy script):
   `deployments/<chainId>.json` dengan isi `{"chainId":31337,"deployedAt":"<ISO>","deployer":"0x..","contracts":{"RewardToken":"0x..","StakingPool":"0x.."}}`
   Frontend membacanya via `vite.config.ts` (`fs.readFileSync` kalau ada) sebagai default address; override via `.env`.
2. **Port anvil per worker:** orkestrator 8545, Agent A 8546, Agent B 8547, Agent D 8548 (`anvil -p <port>`).
3. **Governor ABI (dipakai Agent C):** OZ v5 standar: `propose(address[],uint256[],bytes[],string)`, `castVote(uint256,uint8)`, `queue(...description)`, `execute(...)`, `state(uint256)`, `proposalView`, `hasVoted`, `getVotes(address,uint256)`, `getProposalId` via event `ProposalCreated`. Event: `ProposalCreated`, `VoteCast`, `ProposalQueued`, `ProposalExecuted`, `ProposalCanceled`.

## Tasks

### Task 1 (Agent A): defi-staking frontend (Rab 16 Sep)
- Create: `defi-staking/frontend/**` (Vite + wagmi), `defi-staking/devlog/2026-09-16-frontend-dashboard.md`
- Fitur: staked balance, TVL (totalStaked), APY estimate, claimable (earned), form stake/unstake + claim + emergency withdraw dengan validasi, event-driven refresh, semua state (empty/loading/error/wrong-chain/tx pending-success-error).
- ABI sumber: baca `defi-staking/src/StakingPool.sol` + `src/RewardToken.sol` langsung.
- Verifikasi: `npm install && npm run build` di frontend (port anvil 8546 kalau perlu deploy lokal).

### Task 2 (Gue): deploy script defi-staking (Kam 17 Sep)
- Create: `defi-staking/script/DeployStaking.s.sol` (RewardToken -> StakingPool -> setStakingPool -> setRewardRate -> tulis deployments JSON), verifikasi via anvil 8545, `defi-staking/devlog/2026-09-17-deploy-polish.md`.

### Task 3 (Gue): README defi-staking + build in public (Jum-Sab 18-19 Sep)
- Modify: `defi-staking/README.md` (ganti template Foundry default: arsitektur, trade-off SPEC §5, quickstart, test/coverage/gas, status deploy jujur).
- Create: `defi-staking/devlog/2026-09-18-readme-github.md`, `devlog/2026-09-19-build-in-public.md`, `defi-staking/content/twitter-thread.md`, `content/mirror-article-draft.md`, `content/github-profile-readme.md`.

### Task 4 (Agent B): governance-dap contracts (Min-Sel 20-24 + Min-Sen 27-28 Sep)
- Create: `governance-dapp/` Foundry project: `src/GovernanceToken.sol` (ERC20Votes+ERC20Permit), `src/GovernorContract.sol` (Governor + Settings + CountingSimple + VotesQuorumFraction + TimelockControl), `src/Treasury.sol`, test lengkap (full flow propose->vote->queue->execute, defeated path, timelock delay, roles), `script/DeployGovernance.s.sol` (anvil port 8547), `subgraph/` (manifest+schema+mapping+abis, tanpa deploy), `SPEC.md`, `docs/research-governance.md`, README, devlog 20,21,22,23,24,27,28.
- Parameter roadmap: quorum 4%, voting delay 1 hari (7200 blok @12s), voting period 1 minggu (50400 blok), test pakai param kecil.

### Task 5 (Agent C): governance-dap frontend (Jum-Sab 25-26 Sep)
- Create: `governance-dapp/frontend/**` (stack sama Agent A), devlog 25,26, `frontend/README.md`.
- Fitur: proposal list (status badge 8 state, vote breakdown, deadline), detail + voting (For/Against/Abstain, voting power via getVotes di snapshot block, disable kalau voted/not active), delegate, create proposal (contoh: release ETH dari Treasury). Data proposal dari event scan `getLogs` (devlog: kenapa The Graph dibutuhkan, task 27).

### Task 6 (Agent D): simple-dex AMM (Rab 30 Sep - Sel 6 Okt)
- Create: `simple-dex/` Foundry project: `SPEC.md`, `docs/uniswap-v2-research.md`, `src/AMMLibrary.sol` (getAmountOut/In, sqrt), `src/DexPair.sol` (LP ERC20 + pool: addLiquidity/removeLiquidity/swap + slippage + deadline, MINIMUM_LIQUIDITY, lock pattern), mocks, test (math fuzz + liquidity + swap + invariant: k non-decreasing, solvency, no stuck funds), `script/DeploySimpleDex.s.sol` (anvil 8548) + flag Arbitrum Sepolia, `docs/security-review.md`, README, devlog 30 Sep, 1,2,3,4,5,6 Okt.

### Task 7 (Gue): Verifikasi akhir
- `forge build && forge test` di 3 project Foundry, `npm run build` di 2 frontend, review devlog (honesty + no slop + no em dash), perbaiki temuan, laporan akhir.

## Self-Review

- Coverage roadmap 16 Sep-6 Okt: Task 1(16), 2(17), 3(18-19), 4(20-24,27-28), 5(25-26), 6(30 Sep-6 Okt). Lengkap.
- Type consistency: deployments JSON sama format di semua project; ABI Governor mengikuti OZ v5 yang sama di Task 4/5.
- Semua deliverable punya verifikasi nyata (build/test), tidak ada placeholder diam-diam.
