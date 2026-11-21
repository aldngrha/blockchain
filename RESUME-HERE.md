# RESUME-HERE: ROADMAP catch-up + syllabus continuation

> Session bookmark, last updated: Nov 18, 2026. Catch-up Sep 16 to Oct 6 DONE. Batch Oct 7-9 DONE. Batch Oct 10-27 DONE Oct 12. Batch Oct 28-31 DONE Nov 18 (artifacts followed later, the original slot was Oct 28-31). Vault NOT written for this batch, per the user's decision.

## Batch Oct 28-31: DONE (Nov 18, 2026)

Context: Oct 28-31 was missed and its artifacts did not exist. Done on Nov 18, everything verified locally on this machine.

| Date | Deliverable | Status |
|---|---|---|
| Oct 28-29 | `docs/uniswap-v3-notes.md` (concentrated liquidity, tick, `sqrtPriceX96`, architecture diagram, swap execution path, `TickMath`/`SqrtPriceMath`, fee growth, oracle, capital efficiency table) | done |
| Oct 30 | `docs/aave-v3-liquidation-sim.md` (two-slope interest rate model, HF vs price drop table, liquidator bonus math, how to reproduce in a spreadsheet) | done |
| Oct 31 | `aave-v3-flashloan/` (receiver + allowlisted action plugin + mock pool + SPEC + devlog + deploy script) | done, verified against a mainnet fork |

**Verification run by hand:** local `forge test` in aave-v3-flashloan **10/10 green** (including 1 fuzz test). Mainnet fork **2/2 green** against the real Aave v3 Pool `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2`: 1,000 USDC flash loan, 500,000 unit premium (0.05%), aUSDC balance up by exactly the premium. Anvil fork deploy on port 8550 worked, `deployments/31337.json` was written, and one real flash loan via `cast` succeeded (`lastAmount` 1e9, `lastPremium` 500000). The Uniswap v3 data in the notes was read on-chain at block 26439489, not from an article.

**Technical findings that went into the devlog:** (1) Aave v3 does not hold the underlying in `Pool`, it holds it in the aToken, so measuring the premium through the Pool balance is always zero; (2) `getTreasury()` reverts in the mainnet PoolAddressesProvider because the mainnet v3 version is newer; (3) the flash loan premium must already exist before the transaction, it is not paid out of the borrowed amount; (4) a mock pool without `transferFrom` means the test never exercises repayment at all.

**Next (Nov 1-8):** DeFi week 1 review, direct mainnet fork interaction (v3 swap + Aave supply/borrow), GMX/perp DEX research, MEV Flashbots, oracle security (Mango Markets), advanced reentrancy, Code4rena contest. No artifact exists yet for any of those dates.

## Batch Oct 10-27: REBUILT (Oct 12, 2026)

Context: the vault has notes for this syllabus slot dated Jul 2026, but the artifacts did not exist. The user decided to rebuild them in this repo. The client-search track stays skipped.

**Verified first (all green locally):** defi-staking 75/75, governance-dapp 33/33, simple-dex 53/53 = 161 tests. Lint 0 errors and build exit 0 for 3 frontends. Git clean and in sync with origin/main.

**What was built:**

| Date | Deliverable | Status |
|---|---|---|
| Oct 17 | `docs/how-audit-contests-work.md` (Code4rena vs Sherlock vs Codehawks vs Cantina, contest flow, severity, case study) | done |
| Oct 18-19 | `security/AUDIT-TEMPLATE.md` (finding template, severity guide, check-before-submit, anti-patterns) | done |
| Oct 24 | `docs/l2-deep-dive.md` (fraud vs validity proof, L2Beat numbers, stage framework, bridging, zkSync deploy steps) | done |
| Oct 25 | `ccip-crosschain/` (Foundry project: sender + receiver + 24 tests + SPEC + devlog + deploy script) | done, local deploy verified |
| Oct 26 | `docs/defi-protocol-onepager.md` (Aave v3, with data read straight from mainnet) | done |

**Skipped (not technical, or client-search track):** Oct 10, 12-16 (client search), Oct 11 (Mirror article, draft already exists), Oct 20 (ETHGlobal list), Oct 21 (portfolio polish), Oct 22 (monthly review), Oct 23 and 27 (client onboarding).

**Verification already run by hand:** `forge test` in ccip-crosschain 24/24 green. Local anvil deploy on port 8549 succeeded, `deployments/31337.json` written, checked via `cast` (getRouter, supportsInterface 0x85572ffb true, defaultGasLimit 200000). Aave data read on-chain from the mainnet Pool `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2` at block 26175066.

**User manual steps still piling up:** deploy ccip-crosschain to Sepolia + Arbitrum Sepolia (needs router addresses and chain selectors from the official CCIP directory, plus `setTrustedSender` on the receiver), deploy to zkSync Era testnet (needs `foundry-zksync`), and all the older items (Sepolia/Arbitrum Sepolia deploys for 3 projects, Vercel, Slither re-run, subgraph Studio, publish content).

**Oct 28-31:** DONE Nov 18, see the top section. Before that, this batch had been hanging for 19 days.

## Catch-up results (Sep 16 to Oct 6): DONE, final verification Oct 7

- **defi-staking (Sep 16-19):** frontend dashboard + deploy script (verified on anvil) + README + 4 devlog files + content draft. `forge test`: **75/75**, coverage 100%/100%. Frontend build + lint green.
- **governance-dapp (Sep 20-29):** contracts (GovernanceToken/GovernorContract/Treasury, OZ v5, via_ir + optimizer 1000 because of EIP-170) + verified deploy + subgraph (code only) + SPEC + README + `docs/research-governance.md` + frontend (34 files: proposal list event scan, voting snapshot via getPastVotes, delegate, create proposal; full loop smoke test via cast) + 10 devlog files. `forge test`: **33/33**. Frontend build + lint green.
- **simple-dex (Sep 30 to Oct 6):** AMMLibrary + DexPair + 5 test suites + verified deploy (reserves 1000/1000, LP 1000e18) + SPEC + README + `docs/uniswap-v2-research.md` (IL table computed from the formula) + `docs/security-review.md` (10 findings, including the overflow fuzz story fixed with a uint112 domain + natspec) + 7 devlog files. `forge test`: **53/53**.
- **Total: 161 tests green, 2 frontend build+lint green, 21/21 dates have a devlog, 0 em dashes in all new documents.**

## END OF SESSION STATUS (Oct 7 evening, user resting)

Catch-up Sep 16 to Oct 6 DONE (see the section below). Batch Oct 7-9 ALSO DONE (AMM frontend + demo script + Mirror article draft, build+lint verification green, details in the "Batch Oct 7-9: DONE" section). Syllabus progress: **complete through Oct 9**. NO agent still running when the session closed.

## Technical lessons (do not repeat)

1. Large sub-agents: SERIAL, max 1. Parallel = dead (dynamic concurrency limit). Check disk before relaunching a dead/stopped agent.
2. Verification: never trust an agent's report, run it yourself (forge test, npm build). Agent B claimed success while EIP-170 made the anvil deploy fail, caught only by verification; viem 2.57 `getLogs` silently ignores `abi`+`eventName` (caught by agent C's smoke test).
3. Em dashes banned in all new files (antislop R-02). Indonesian docs use lo/gw, code in English. The original roadmap still has em dashes: quote devlogs only from the clean parts.
4. Foundry: fs_permissions read-write for vm.writeFile; explicit console.log import; deployer via vm.addr(PRIVATE_KEY) not msg.sender; new forge-std: import stdError explicitly from StdError.sol, Test no longer reverts on its own; OZ v5 Governor needs via_ir.
5. Standard deployments JSON: `{"chainId","deployedAt"(epoch ms),"deployer","contracts":{...}}`. Anvil ports: mine 8545, governance 8547, simple-dex 8548.
6. Proven frontend stack: Vite + React 19 + wagmi v3 + RainbowKit v2 + TanStack Query 5 + oxlint (mirrors nft-minting-dapp/defi-staking), NOT Next.js even though the roadmap says so.
7. No fabrication: testnet addresses, tx hashes, unmeasured gas numbers, deploy results. Mark them as user manual steps.

## Batch Oct 7-9: DONE (Oct 7, build+lint verified)

- `simple-dex/frontend/`: swap UI (mirror JS getAmountOut BigInt, 2 price impact definitions, slippage + deadline, tx states) + liquidity UI (pool stats, share %, position tracker, ratio guidance, remove payout estimate) + 3 devlogs (Oct 7/8/9) + `content/demo-script.md` + `content/mirror-article-draft.md` (1,018 words).
- Verification: build + lint green; mirror JS checked against 26 exact vectors from the Solidity suite (PASS); on-chain smoke test: swap via cast produced reserves bit-exact with the mirror prediction. Key findings: remove liquidity does NOT need an LP approve (the pair burns LP directly), addLiquidity refund = the surplus is never pulled (CEI), all recorded in the devlog.
- Manual user steps: MetaMask click-through session before recording the Loom, record the Loom + publish to Mirror, deploy to Vercel (needs Sepolia contracts first).
- `STUDY-GUIDE.md` already has Stage 4 for reading this material.

## After Oct 9: syllabus plan (artifact version), NOT STARTED

Start here tomorrow. Batch by batch, report before continuing (agreed with the user):
- **Next batch: Oct 17-31** (Oct 10-16 + Oct 20-23 = client-search track, SKIPPED per the user's decision; real-world items such as joining a contest or ETHGlobal = material only, manual execution): `docs/how-audit-contests-work.md` (Code4rena vs Sherlock, Oct 17), `docs/l2-deep-dive.md` + try a zkSync deploy (Oct 24), minimal CCIP receiver + research (Oct 25), protocol one-pager (Oct 26), `docs/uniswap-v3-notes.md` (Oct 28-29), Aave v3 + flash loan receiver with an anvil fork (Oct 30-31), devlog per date + notes on the skipped dates.
- Nov: MEV, oracle security, DVDeFi 15 levels (Foundry, doable in full), Echidna, user interview (manual).
- Dec-Jan: AA + paymaster, Cosmos SDK, Dune, and so on until the technical syllabus runs out.

## User manual steps (cumulative, documented honestly)

1. git init + push 3 projects; deploy Sepolia (staking + governance) and Arbitrum Sepolia (simple-dex); Vercel for 3 frontends; update the addresses in the README after deploy.
2. Slither re-install + re-run on 3 projects (no end-to-end reentrancy test in simple-dex yet, see security review section 9).
3. Subgraph: The Graph Studio account (code lives in governance-dapp/subgraph/).
4. Publish content: X thread + Mirror (drafts in defi-staking/content/ and simple-dex), Loom video, GitHub profile README.
5. Most important: re-read each project (SPEC, contracts, run the tests, break something, read the devlog) so the skill sticks, rather than only the dates being covered.
