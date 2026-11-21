# Blockchain Learning Workspace

Blockchain engineering learning workspace, following [ROADMAP.md](ROADMAP.md) (Aug 3, 2026 to Jan 21, 2027, 172 days), one Solidity/Foundry project per topic. Every project has its own `SPEC.md`, `README.md`, `devlog/`, and test suite.

## Structure

### Projects

| Dir | Contents |
|---|---|
| [defi-staking/](defi-staking/) | **Project 1 - DeFi Staking Protocol.** Staking pool with Synthetix-style reward math (`rewardPerToken` accumulator, mint-on-claim). Foundry: 75/75 tests (unit + fuzz + handler-based invariant), 100% coverage. Frontend: Vite + React + wagmi + RainbowKit. |
| [governance-dapp/](governance-dapp/) | **Governance:** GovernanceToken (votes/delegation), GovernorContract (OZ v5 Governor), Treasury. Deploy + subgraph + frontend (proposal list, voting via `getPastVotes`, delegate). Foundry: 33/33 tests. |
| [simple-dex/](simple-dex/) | Minimal DEX: AMM core, with `SPEC.md`, `devlog/`, `deployments/`. |
| [ccip-crosschain/](ccip-crosschain/) | **Cross-chain (Oct 25):** `CrossChainSender` + `MessageReceiver` for Chainlink CCIP. 24/24 tests passing, local anvil deploy verified. No testnet deploy yet. |
| [aave-v3-flashloan/](aave-v3-flashloan/) | **Flash loan (Oct 31):** Aave v3 receiver with an allowlisted action plugin. 10 local tests + 2 mainnet fork tests against the real Aave v3 Pool (0.05% premium verified as a transfer to the aToken). Anvil fork deploy verified. |
| [nft-minting-dapp/](nft-minting-dapp/) | NFT minting + frontend. |
| [foundry-practice/](foundry-practice/) | Daily Foundry drills (fork tests, scripting, ds-test patterns). |
| [cyfrin-course/](cyfrin-course/) | Cyfrin Advanced Foundry coursework (sections 1 to 8). |
| [security/](security/) | Security material: Ethernaut review, Slither report, security checklist, best practices, audit finding template. |
| [web3-frontend/](web3-frontend/) | Frontend fundamentals: ethers, wagmi app, WETH event listener. |
| [docs/](docs/) | Cross-project notes: audit contests, L2 deep dive, Aave v3 one-pager, Aave v3 liquidation simulation, Uniswap v3 notes (tick, `sqrtPriceX96`, swap execution path), plus plans in `docs/plans/`. |

### Learning documents (root)

- **[ROADMAP.md](ROADMAP.md)**: full daily schedule, from the current position to the end of the syllabus.
- **[RESUME-HERE.md](RESUME-HERE.md)**: current status: progress position, catch-up results, next steps. **Start here when coming back after a long break.**
- **[STUDY-GUIDE.md](STUDY-GUIDE.md)**: concept summary per topic.
- **[PROBLEM-BOOK.md](PROBLEM-BOOK.md)**: problems hit so far plus their fixes (debugging knowledge base).

## Running tests

Each Foundry project is standalone (no root workspace build):

```bash
cd defi-staking && forge test        # or any other project
```

`lib/` (forge deps) is not committed, so a fresh clone needs `forge install` first (documented in each project README). Frontend: `npm install && npm run build` in `<project>/frontend/`.

## Conventions

- **Daily devlog** in `<project>/devlog/`: what was done, problems, fixes.
- **Publishable content** (threads, articles, drafts) in `<project>/content/`: drafts, not final.
- **Spec-first:** new features write `SPEC.md` first (edge cases E1 to E17, invariants I-1 to I-8), then code + TDD tests.
