# Blockchain Learning Workspace

Workspace belajar blockchain engineering — mengikuti [ROADMAP.md](ROADMAP.md) (3 Ags 2026 → 21 Jan 2027, 172 hari), satu proyek Solidity/Foundry per materi. Tiap proyek punya `SPEC.md`, `README.md`, `devlog/`, dan test suite sendiri.

## Struktur

### Proyek

| Dir | Isi |
|---|---|
| [defi-staking/](defi-staking/) | **Project 1 — DeFi Staking Protocol.** Staking pool dengan reward math pola Synthetix (`rewardPerToken` accumulator, mint-on-claim). Foundry: 75/75 test (unit + fuzz + invariant handler-based), coverage 100%. Frontend Vite + React + wagmi + RainbowKit. |
| [governance-dapp/](governance-dapp/) | **Governance:** GovernanceToken (votes/delegation), GovernorContract (OZ v5 Governor), Treasury. Deploy + subgraph + frontend (proposal list, voting via `getPastVotes`, delegate). Foundry: 33/33 test. |
| [simple-dex/](simple-dex/) | DEX minimal — AMM core, ada `SPEC.md`, `devlog/`, `deployments/`. |
| [nft-minting-dapp/](nft-minting-dapp/) | NFT minting + frontend. |
| [foundry-practice/](foundry-practice/) | Latihan Foundry harian (fork test, scripting, ds-test patterns). |
| [cyfrin-course/](cyfrin-course/) | Coursework Cyfrin Advanced Foundry (sections 1–8). |
| [security/](security/) | Materi keamanan: Ethernaut review, Slither report, security checklist, best practices. |
| [web3-frontend/](web3-frontend/) | Fundamentals frontend: ethers, wagmi app, WETH event listener. |
| [docs/](docs/) | Rencana & catatan lintas proyek (`docs/plans/`). |

### Dokumen belajar (root)

- **[ROADMAP.md](ROADMAP.md)** — jadwal harian lengkap, dari titik lanjut sampai silabus beres.
- **[RESUME-HERE.md](RESUME-HERE.md)** — status terkini: posisi progress, hasil catch-up, langkah berikutnya. **Mulai dari sini kalau balik lagi setelah lama nggak buka.**
- **[STUDY-GUIDE.md](STUDY-GUIDE.md)** — ringkasan konsep per topik.
- **[PROBLEM-BOOK.md](PROBLEM-BOOK.md)** — kumpulan masalah yang ketemu + solusinya (knowledge base debugging).

## Menjalankan test

Tiap proyek Foundry mandiri (tanpa workspace root build):

```bash
cd defi-staking && forge test        # atau proyek lain
```

`lib/` (forge deps) nggak di-commit — clone fresh = `forge install` dulu (terdokumentasi di README tiap proyek). Frontend: `npm install && npm run build` di `<project>/frontend/`.

## Konvensi

- **Devlog harian** di `<project>/devlog/` — apa yang dikerjain, masalah, solusi.
- **Konten publishable** (thread, artikel, draft) di `<project>/content/` — draft, bukan final.
- **Spec-first:** fitur baru nulis `SPEC.md` dulu (edge cases E1–E17, invariants I-1…I-8), baru kode + test TDD.
