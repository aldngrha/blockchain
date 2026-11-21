# STUDY-GUIDE: How to read everything documented (Sep 16 to Oct 27)

> For when you did not write the code yourself (an agent did), and you have not read any of it.
> Principle: read what YOU already know first as a foothold, the order is arranged so each step rests on something you already understand, and each project ends with a break-it drill. Do not read everything linearly at once: 1 project = 1-2 sessions.
>
> Current coverage is 5 stages: Stages 1-4 = the Sep 16 to Oct 9 output (Foundry projects + frontends). Stage 5 = the Oct 10-27 batch (audit contests, L2, CCIP, Aave v3). Everything in Stage 5 is new material you have never read.

## How to learn: the per-unit loop (THIS is the way to learn)

Your learning unit = ONE problem in a devlog. There are 98 problems in total, all indexed in `PROBLEM-BOOK.md` (grouped by theme, a 1-2 line summary plus a link to the original devlog). Each unit goes through this 5-step loop, 20-30 minutes:

1. **Read the PROBLEM first** (in PROBLEM-BOOK or straight in the devlog). Read the Problem + Why sections, then BEFORE reading the Solution, stop and predict: "if it were me, where would I fix this? how?" A wrong prediction is the most valuable learning moment, because the gap between prediction and reality is your blind spot.
2. **Read the solution code, only that part.** Open the file/function named in the Solution section. Do not read the whole file from the top.
3. **Run the test on your machine** (`forge test` for contracts, `npm run build && npm run lint` for frontends). Green on your machine, not on someone's word. This is also real practice using the tooling.
4. **Break-it drill** (once per STAGE, not per unit; the list is under each stage below): break one thing on purpose, run the tests, see which one catches it, understand why, put it back.
5. **Checkpoint**: answer the checklist questions at the bottom of this file (out loud, without opening notes). Cannot answer = go back to step 1 for the related unit. Can answer = next unit.

Realistic rhythm: **3-5 units per session**. It does not have to be 100% in order, mood can be the compass (feel like frontend? take a frontend unit). What you MAY NOT skip: steps 3 and 4. That is the difference between "understood in the head" and "understood in the hands".

The 5-stage reading order below stays the big map: take units from Stage 1 first, then Stage 2, and so on. If you already went through Stages 1-4, go straight to Stage 5.

## Reading order (why this order)

### Stage 1: defi-staking frontend (lightest, you already know the contracts)

You wrote the staking contract yourself through Sep 15, so the only new material is the frontend pattern. It is also the foundation for the other two frontends.

1. `defi-staking/frontend/src/config.js` then `src/abi.js` (chain config, addresses from the deployments JSON)
2. `src/hooks/` (usePoolReads, usePoolEvents, useStakingActions): read pattern via wagmi, event watching for real time, tx states
3. `src/components/StakeForm.jsx` (2-step approve flow) and `ActionFeedback.jsx` (parse custom errors into human messages)
4. `devlog/2026-09-16-frontend-dashboard.md`
5. The `frontend/README.md` README, then run it: `anvil` + deploy script + `npm run dev`, connect a wallet, stake a small amount

Drill: make one of the validations in StakeForm wrong on purpose, see whether the error makes sense to a user; remove the event listener and feel how the data goes stale.

### Stage 2: governance-dapp (the biggest conceptual jump)

New material: checkpoint votes (ERC20Votes), proposal lifecycle, Timelock roles. This one needs the most time.

1. `governance-dapp/docs/research-governance.md` (why Governor + Timelock, lifecycle, parameter trade-offs)
2. `SPEC.md` (the final design)
3. Devlogs in order: `2026-09-20` (research), `21` (spec), `22` (token), `23` (governor), `24` (timelock). These devlogs were written from real problems during the build, so they are a shortcut to the traps
4. Code, in order: `src/GovernanceToken.sol` (note the `_update` override, votes only attach after delegate) then `src/GovernorContract.sol` (OZ v5 override matrix, note why via_ir is needed: EIP-170) then `src/Treasury.sol` (small)
5. `test/GovernorFullFlow.t.sol`: this full flow test is the best explanation of the propose-vote-queue-execute lifecycle, read it like a story
6. `script/DeployGovernance.s.sol`: the role wiring order and why the deployer renounces
7. Frontend: `src/hooks/useProposals.js` (ProposalCreated event scan, why it needs a cache, why The Graph is needed) + `devlog/2026-09-26-voting-ui.md` (voting power from the snapshot block, NOT the current balance: the classic ERC20Votes trap)

Drill: in a test, raise quorum to 51% and predict which path becomes Defeated before running it; try voting without delegating and read why the weight is 0 (not a revert).

### Stage 3: simple-dex (math-heavy but self-contained)

1. `simple-dex/docs/uniswap-v2-research.md`: the x*y=k derivation + impermanent loss table, redo one number with a calculator/by hand so it sticks
2. `SPEC.md`
3. `src/AMMLibrary.sol`: small and pure, memorise getAmountOut and the rounding direction (output floor, input ceil, always in the pool's favour)
4. `src/DexPair.sol`: note the lock pattern, MINIMUM_LIQUIDITY, and the excess refund in addLiquidity
5. The overflow story (the most valuable one): `test/AMMLibrary.t.sol` domain section + `devlog/2026-10-02-core-math.md`. This is a real example of a fuzz test finding a domain limit, not a bug
6. `devlog/2026-10-03` (first provision sqrt), `04` (slippage + deadline), `docs/security-review.md`
7. Frontend swap UI: the part of `frontend/src` that mirrors getAmountOut in JS, compare the price impact definitions in the docs

Drill (the best one): remove `vm.assume(requiredIn <= type(uint112).max)` in the round-trip test, run `forge test`, and watch the fuzz find the same overflow again within seconds. It is the fastest way to feel why invariant tests are strong.

### Stage 4: AMM frontend + content (Oct 7-9), read AFTER Stage 3

1. `simple-dex/frontend/src/lib/amm.js`: the JS mirror of getAmountOut/getAmountIn/quote. Read it while comparing directly with `src/AMMLibrary.sol`: BigInt is used so precision matches, rounding must be identical, a 1 wei difference and your UI lies to the user. Its tests were compared against 26 exact vectors from the Solidity suite, look for them in the Oct 7 devlog
2. The two price impact definitions (execution vs marginal) in `SwapPanel.jsx` + `docs/uniswap-v2-research.md`: understand why the numbers differ (9.33% vs ~17% for a 10% of pool swap) and why both are honest
3. `LiquidityPanel.jsx` + `hooks/useDexActions.js`: ratio guidance via quote, the actual refund behaviour (the surplus is NEVER pulled, CEI: compute transferFrom by ratio first; this differs from the pull-and-refund intuition) and the finding that overturned the brief: remove liquidity does NOT need an LP approve because the pair burns LP directly via _burn
4. `devlog/2026-10-09-demo-readme-article.md` then `content/mirror-article-draft.md`: read as a teaching exercise, if the article's explanation order differs from the order you understood it, write your own version
5. `content/demo-script.md`: used to record the Loom (manual), every number comes from an exact sequence simulation

Drill: change the default slippage, PREDICT first which swap will revert on the amountOutMin guard in the contract, then execute it on anvil; then swap the approve order in the hook and see which error comes back from the RPC.

### Stage 5: Oct 10-27 batch (new material, never read before)

Everything in this stage is new: audit contests, L2, CCIP, and Aave v3. None of it rests on code you wrote yourself, so this is the stage that most needs retype mode.

1. `docs/how-audit-contests-work.md`: Code4rena vs Sherlock vs Codehawks vs Cantina, the contest flow, severity, and the most important part: why contests do not prevent exploits. Read the Cork Protocol case study twice.
2. `security/AUDIT-TEMPLATE.md`: finding template, severity guide, the seven check-before-submit questions. The difference from `security/SECURITY-CHECKLIST.md`: the checklist is for finding, the template is for writing.
3. `docs/l2-deep-dive.md`: fraud proof vs validity proof, L2Beat numbers, and the L2 stage framework. Section 6 (how to read a stage) is the most useful long term.
4. `ccip-crosschain/docs/ccip-architecture.md` then `SPEC.md`. Read the architecture doc first until the 6-step flow makes sense, then open `SPEC.md` sections 6 and 7.
5. Code: `src/MessageReceiver.sol` first (small and dense), then `src/CrossChainSender.sol` (note the refund), then `test/mocks/MockRouter.sol` (understand why the mock needs `sourceChainSelectorForDelivery`).
6. `test/CrossChain.t.sol`: read it as a story. Each test is one security property or one edge case, not just test code.
7. `docs/defi-protocol-onepager.md`, then rerun the `cast call` commands in the "Measured data" section yourself. Read the real numbers in the terminal, do not just trust the table.
8. `ccip-crosschain/devlog/2026-10-25-ccip-crosschain.md`: six real problems, including the ones that made a test green while wrong.

Drill (Stage 5 has the second best drill after the AMM one):

- **CCIP, main drill.** Remove `onlyRouter` from `MessageReceiver.ccipReceive`, run `forge test`, see which test catches it. Put it back. Then remove the `trustedSender` check and run again. Those two drills are what make you feel for yourself why both validations are required, instead of being told to trust it.
- **CCIP, refund drill.** Change `MockRouter.getFee` to return 0, run the refund test. Then think: if the fee is 0, is the contract still correct? Why is the refund computed from `getFee`, not from a fixed number?
- **Aave, calculation drill.** With a calculator, without opening the docs: WETH LTV 80.50%, liquidation threshold 83%. If a position has health factor 1.2, what percentage WETH price drop pushes it below 1? Check it against the Oct 30 simulation afterwards.
- **L2, staleness drill.** Open L2Beat, check the stage of Base, Arbitrum One, and ZKsync Era now, compare with the table in `docs/l2-deep-dive.md` (Aug 2026 snapshot). If something moved, that is a good finding, and mark what changed.

## Ground rules so it actually sticks

- Do not just read: after each section, run `forge test` in that project, then BREAK one thing (put it back afterwards) and see which test catches it. If nothing catches it, that is a finding: the tests are thin.
- Realistic sizing: Stage 1 = 1 session, Stage 2 = 2-3 sessions, Stage 3 = 2 sessions, Stage 5 = 3-4 sessions (CCIP alone 1-2 sessions because the concepts are the newest). It does not have to be finished overnight, and you do not need to wait for everything to be done to start.
- If it feels like "reading alone does not stick", drop into retype mode: rewrite the core function (rewardPerToken, getAmountOut, or the lifecycle test) from memory, compare with the original.
- Read devlogs critically: "does the problem make sense? would I do it differently?" Disagreeing is good, write it in the idea pipeline.

## Understanding checklist (if you can answer, that stage is complete)

Stage 1: Why a 2-step approve? Why parse custom errors instead of string matching?
Stage 2: Why are votes zero even with tokens? Why is there a timelock? Why can only the proposer cancel while Pending? Why is quorum computed from for+abstain?
Stage 3: Derive getAmountOut from x*y=k without looking. Why MINIMUM_LIQUIDITY? Why is the overflow in getAmountOut a domain limit, not a bug, and when does it panic?
Stage 5: Why do audit contests not prevent exploits, and what are you actually buying by joining one? Why must a CCIP receiver check two things (router AND source), why is one alone not enough? Why does CCIP use a chain selector instead of a chain id? Why does the health factor use the liquidation threshold instead of LTV? Why must an overpaid CCIP fee be refunded yourself?
