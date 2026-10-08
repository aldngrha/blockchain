# Project 1 — DeFi Staking Protocol: Spesifikasi Final

> Status: **FINAL** (Finalisasi Spec — Jum 11 Sep 2026)
> Implementasi mulai Sab 12 Sep (RewardToken, TDD) sesuai ROADMAP.md.
> Security review wajib pakai checklist di `../security/SECURITY-CHECKLIST.md` sebelum deploy.

---

## 1. Goal & Non-Goals

**Goal:** Protokol staking minimal tapi production-pattern: user stake RewardToken, earn reward per detik, claim kapan saja. Ini portfolio item pertama — kodenya harus layak dilihat recruiter.

**Non-Goals (v1):**
- Gak ada timelock / governance (itu Project 2).
- Gak ada multi-token pool — 1 pool, 1 token.
- Gak ada lock-up period / vesting.
- Gak ada frontend flash — dashboard datang Rab 16 Sep.

**Pola utama yang dilatih:** Ownable, ReentrancyGuard, checks-effects-interactions, reward-per-token accumulation (Synthetix pattern), custom errors, events.

---

## 2. Arsitektur

```
┌──────────────┐        mint()         ┌─────────────────┐
│ RewardToken  │◄──────────────────────│   StakingPool   │
│  (ERC-20)    │   saat claimReward()  │   (Ownable +    │
│  Ownable     │                       │  ReentrancyGuard)│
└──────────────┘                       └─────────────────┘
        ▲                                      │
        │            stake / unstake           │
        └──────────────── User (EOA) ──────────┘
```

- **RewardToken** = ERC-20 + Ownable. `mint()` hanya bisa dipanggil StakingPool.
- **StakingPool** = 1 kontrak, reward token = staking token (inflationary). Reward **di-mint saat claim**, bukan di-pre-fund — sesuai desain roadmap "RewardToken mintable oleh StakingPool".
- User stake RewardToken → balance tercatat di mapping pool → reward akumulasi per detik berdasarkan porsi kepemilikan → claim = mint baru ke user.

---

## 3. RewardToken

Solidity `^0.8.20`, OpenZeppelin v5 (`ERC20`, `Ownable`).

### State
| Var | Tipe | Catatan |
|---|---|---|
| `stakingPool` | `address` (immutable) | satu-satunya address yang boleh mint |

### Functions
| Signature | Access | Behavior |
|---|---|---|
| `constructor(string name, string symbol, address stakingPool_)` | — | Set `stakingPool = stakingPool_` |
| `mint(address to, uint256 amount)` | **onlyStakingPool** | `_mint(to, amount)` |

### Errors
- `RewardToken__Unauthorized()` — bukan stakingPool manggil `mint`.

### Events
- Standar ERC-20 (`Transfer`, `Approval`). Tidak ada event custom.

**Catatan deploy:** RewardToken dan StakingPool saling tergantung → deploy RewardToken dulu, lalu StakingPool dengan address RewardToken, lalu... `stakingPool` immutable berarti harus tahu address pool sebelum pool ada. Solusi: deploy StakingPool dengan address RewardToken yang belum punya minter, lalu panggil `setStakingPool(pool)` sekali di RewardToken (owner-only, satu kali, irreversible). *(Alternatif CREATE2 — skip, overkill.)* Jadi `stakingPool` **bukan** immutable: `address public stakingPool` + `setStakingPool()` owner-only dengan guard `stakingPool == address(0)`.

---

## 4. StakingPool

Solidity `^0.8.20`, OZ v5 (`ERC20` interface, `Ownable`, `ReentrancyGuard`).

### State
| Var | Tipe | Keterangan |
|---|---|---|
| `rewardToken` | `IERC20` (immutable) | Token yang distake & di-claim |
| `totalStaked` | `uint256` | Sum semua `stakedBalance` |
| `stakedBalance` | `mapping(address => uint256)` | Balance stake per user |
| `periodFinish` | `uint256` | Timestamp reward period berakhir |
| `rewardRate` | `uint256` | Reward per detik (wei/sec), dibagi proporsional |
| `lastUpdateTime` | `uint256` | Timestamp akumulasi terakhir |
| `rewardPerTokenStored` | `uint256` | Accumulator (scaled 1e18) |
| `userRewardPerTokenPaid` | `mapping(address => uint256)` | Checkpoint per user |
| `rewards` | `mapping(address => uint256)` | Earned yang belum di-claim |
| `MAX_REWARD_RATE` | `uint256` constant | Cap sanity: `1e24` (1 juta token/detik) — cegah overflow `rewardRate * elapsed * 1e18` |

### Functions

| Signature | Access | Behavior |
|---|---|---|
| `constructor(address rewardToken_)` | — | Init semua accumulator = 0 |
| `stake(uint256 amount)` | nonReentrant | `_updateReward(msg.sender)` → cek `amount > 0` → transferFrom user → update `stakedBalance`, `totalStaked` → event |
| `unstake(uint256 amount)` | nonReentrant | `_updateReward(msg.sender)` → cek `amount > 0` dan `amount <= stakedBalance` → update state → transfer balik → event |
| `claimReward()` | nonReentrant | `_updateReward(msg.sender)` → cek `rewards > 0` → effects dulu (`rewards = 0`) → `rewardToken.mint(msg.sender, earned)` → event |
| `unstakeAndClaim()` | nonReentrant | Kombinasi — convenience, 1 tx |
| `emergencyWithdraw()` | nonReentrant | **TANPA** `_updateReward` → ambil seluruh `stakedBalance` balik → **forfeit** `rewards[msg.sender] = 0`, reset `userRewardPerTokenPaid` → event. Escape hatch kalau ada bug di reward math |
| `setRewardRate(uint256 newRate)` | onlyOwner | `_updateReward(address(0))` → cek `newRate <= MAX_REWARD_RATE` → set rate + reset periode (lihat bawah) → event |
| `lastTimeRewardApplicable()` | view | `min(block.timestamp, periodFinish)` |
| `rewardPerToken()` | view | Rumus akumulasi (lihat §5) |
| `earned(address account)` | view | Rumus earned (lihat §5) |
| `getStakedBalance(address)` / `getTotalStaked()` | view | Untuk frontend |

**Semantik `setRewardRate`** (sederhana,决定的): set rate baru dan mulai periode baru **sekarang**:
```
_updateReward(address(0));
rewardRate    = newRate;
lastUpdateTime = block.timestamp;
periodFinish   = block.timestamp + 7 days;   // konstanta DURATION = 7 days
```
Top-up mid-period yang leftover-carrying (Synthetix `notifyRewardAmount`) = **stretch goal**, gak wajib v1. Kalau sempat, tambahkan sebagai fungsi terpisah `notifyRewardAmount(amount)` dengan semantics: active period → `rewardRate += amount / DURATION`, finish gak mundur.

### Access control
- Owner = deployer (multisig di mainnet — note di README).
- Tidak ada fungsi yang bisa dipanggil tanpa otorisasi yang mengubah rate atau mencuri stake.

---

## 5. Reward Math (bagian paling tricky — pahami sebelum ngoding)

Semua di-scale `1e18` untuk presisi. Urutan baca: ini persis pola Synthetix `StakingRewards`.

```solidity
function lastTimeRewardApplicable() public view returns (uint256) {
    return block.timestamp < periodFinish ? block.timestamp : periodFinish;
}

function rewardPerToken() public view returns (uint256) {
    if (totalStaked == 0) {
        return rewardPerTokenStored;          // GUARD: cegah div-by-zero
    }
    return rewardPerTokenStored +
        (rewardRate * (lastTimeRewardApplicable() - lastUpdateTime) * 1e18) / totalStaked;
}

function earned(address account) public view returns (uint256) {
    return (stakedBalance[account] *
        (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18) +
        rewards[account];
}
```

**Hook `_updateReward(address account)`** — WAJIB dipanggil di awal SETIAP fungsi yang mengubah `stakedBalance`, `totalStaked`, atau `rewardRate`:

```solidity
function _updateReward(address account) internal {
    rewardPerTokenStored = rewardPerToken();
    lastUpdateTime = lastTimeRewardApplicable();
    if (account != address(0)) {
        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
    }
}
```

**Kenapa checkpoint per user?** Tanpa `userRewardPerTokenPaid`, reward user lama "tercuci" saat user baru stake (karena `rewardPerTokenStored` naik dari 0 lagi relatif terhadap mereka). Checkpoint = hanya hitung delta sejak terakhir user berinteraksi.

**Trade-off yang harus dipahami (tulis di README):**
1. **Reward saat pool kosong hilang.** Kalau `totalStaked == 0` sementara rate jalan, reward detik itu gak diakumulasi ke siapa-siapa. Real protocols juga begitu (Synthetix).
2. **Rounding dust.** Pembagian integer → tiap user bisa "kehilangan" < 1 wei per operasi. Bounded, acceptable.
3. **Inflationary reward.** Supply naik tiap claim. Tokenomics belum di-governance-kan — disengaja, simpel.

---

## 6. Edge Cases (daftar wajib test — sesuai roadmap Jum 11 Sep)

| # | Kasus | Expected |
|---|---|---|
| E1 | `stake(0)` | Revert `StakingPool__ZeroAmount` |
| E2 | `unstake(0)` | Revert `StakingPool__ZeroAmount` |
| E3 | `unstake` lebih dari staked | Revert `StakingPool__InsufficientStake` |
| E4 | `unstake` saat belum pernah stake | Revert `StakingPool__InsufficientStake` |
| E5 | `emergencyWithdraw` | Dapat 100% stake balik, `rewards` forfeit jadi 0, gak bisa claim lagi dari periode forfeit |
| E6 | `emergencyWithdraw` lalu stake lagi | Accounting fresh — gak ada phantom rewards |
| E7 | `claimReward` dengan earned 0 | Revert `StakingPool__NothingToClaim` |
| E8 | stake + unstake dalam block sama | 0 reward (delta waktu = 0) |
| E9 | 2+ user stake/unstake di timing beda | Reward proporsional terhadap `stakedBalance × waktu`, bukan terhadap urutan |
| E10 | Rate jalan saat `totalStaked == 0` | Tidak revert; `rewardPerToken()` diam; reward periode itu hilang |
| E11 | `setRewardRate` saat periode jalan | Akumulasi lama di-freeze properly (via `_updateReward(address(0))`), periode baru mulai sekarang |
| E12 | `setRewardRate(0)` | Valid — pause reward tanpa pause stake |
| E13 | `setRewardRate` melebihi `MAX_REWARD_RATE` | Revert `StakingPool__RewardRateTooHigh` |
| E14 | `setRewardRate` / `setStakingPool` oleh non-owner | Revert (Ownable `OwnableUnauthorizedAccount`) |
| E15 | Reentrancy di `claimReward` (mock token jahat) | Diblok `ReentrancyGuard` |
| E16 | `mint()` oleh bukan StakingPool | Revert `RewardToken__Unauthorized` |
| E17 | `unstakeAndClaim` saat saldo 0 | Revert dengan error yang tepat |
| E18 | Rounding dust di multi-user fuzz | Dust terbatas (lihat I-8), tidak ada stuck funds |

**Checks-effects-interactions:** state DIULI dulu baru transfer/mint. Non-negotiable, di semua fungsi eksternal.

---

## 7. Invariants (target fuzz tests — Sel 15 Sep)

Handler-based invariant suite (`forge invariant`), ghost variable `totalMinted` di handler untuk tracking:

- **I-1** — `earned(u)` monoton non-turun antara claim (selama rate ≥ 0).
- **I-2** — `sum(stakedBalance[u]) == totalStaked` setelah semua sequence.
- **I-3** — `rewardToken.balanceOf(pool) == totalStaked` (pool gak pegang token reward idle — mint-on-claim).
- **I-4** — `pool.totalMinted() == sum(claimed[u])` — tidak ada mint bocor.
- **I-5** — `unstake(all) + claimReward` → user bersih: `stakedBalance == 0`, `rewards == 0`, `earned == 0`. **Tidak ada stuck funds.**
- **I-6** — `rewardPerToken()` tidak pernah turun.
- **I-7** — `earned(u) <= totalMinted + rewardRate × time × something` — sanity bound (cegah mint tak terbatas via edge timing).
- **I-8** — dust: `|earned(u) eksak (matematika real) − earned(u) on-chain| < n_ops × 1e-17 token` per user.

Konfigurasi: `runs = 256`, `depth = 64`, handler dengan actor pool (5 address), warp/roll acak.

---

## 8. Test Plan (mapping ke jadwal)

**Sab 12 Sep — RewardToken (TDD, target 100% coverage):**
1. Metadata: name, symbol, decimals.
2. `mint` oleh pool → ok, oleh orang lain → revert E16.
3. Transfer/approve/transferFrom standar + insufficient balance.
4. Events standar ter-emit.
5. Tulis test DULU (fail merah) → baru implement → hijau.

**Min 13 Sep — StakingPool core (belum sentuh reward):**
- E1–E6, E17. Multi-user stake/unstake. TransferFrom approval flow.

**Sen 14 Sep — Reward calculation:**
- Test matematika eksak: set rate, warp waktu tertentu, bandingkan `earned()` dengan nilai yang dihitung manual (pakai `vm.warp` + `vm.roll`).
- E8–E12, E16. Timing matrix: stake awal / tengah / akhir periode.

**Sel 15 Sep — Fuzz + invariant:**
- Stateless fuzz untuk `earned`/`rewardPerToken` (random amount, warp).
- Invariant suite I-1…I-8.
- `forge coverage` ≥ 95% StakingPool (RewardToken 100%).

**Gate sebelum frontend:** `forge test -vvv` semua hijau + `forge snapshot` (simpan baseline gas) + Slither clean terhadap high/medium (pakai `../security/`).

---

## 9. Deployment (Kam 17 Sep — Sepolia)

1. Deploy `RewardToken` (owner = deployer).
2. Deploy `StakingPool(rewardToken)`.
3. `rewardToken.setStakingPool(pool)` — sekali.
4. Verify keduanya di Etherscan (flatten atau standard-json).
5. Smoke test EOA: approve → stake → warp 1 menit (anvil dulu, lalu tunggu real time di Sepolia) → claim.
6. Frontend (Rab 16 Sep) deploy Vercel — baca address dari deployment JSON.

**Parameter Sepolia:** `DURATION = 7 days`, `MAX_REWARD_RATE = 1e24`, reward awal 1 token/detik (kecil, cukup buat demo).

---

## 10. Definition of Done

- [ ] Semua test hijau, coverage sesuai target (RToken 100%, Pool ≥ 95%).
- [ ] Semua edge case E1–E18 punya test eksplisit.
- [ ] Invariant I-1…I-8 jalan di suite.
- [ ] Slither: 0 high, 0 medium ( atau terdokumentasi kenapa false positive).
- [ ] Gas snapshot committed + komentar untuk fungsi hot path.
- [ ] README: diagram arsitektur, cara run, cara deploy, trade-off §5, Loom 3 menit.
- [ ] Deploy Sepolia + verified + link di README.
