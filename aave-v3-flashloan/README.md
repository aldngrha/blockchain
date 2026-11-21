# Aave v3 Flash Loan Receiver

Project Foundry buat task roadmap 31 Okt 2026: implementasi flash loan receiver sederhana dan test di fork mainnet.

## Isi

| File | Keterangan |
|---|---|
| `src/FlashLoanReceiver.sol` | Receiver: minta pinjaman, jalankan action dari allowlist, bayar `amount + premium` |
| `src/actions/RecordAction.sol` | Action minimal: mencatat dana yang terlihat di callback |
| `src/actions/MintProfitAction.sol` | Simulasi action yang menghasilkan profit (khusus test lokal, profit dicetak) |
| `src/interfaces/IPool.sol` | Subset interface Pool Aave v3 |
| `src/interfaces/IFlashLoanSimpleReceiver.sol` | Interface callback yang dipanggil Pool |
| `src/interfaces/IFlashLoanAction.sol` | Interface plugin strategi |
| `test/mocks/MockPool.sol` | Tiruan alur flash loan: kirim, callback, tarik kembali |
| `test/mocks/MockERC20.sol` | Token mock dengan `mint` |
| `test/FlashLoanReceiver.t.sol` | 10 test lokal, termasuk 1 fuzz test |
| `test/ForkFlashLoan.t.sol` | 2 test fork melawan Pool Aave v3 mainnet |

Dokumen: `SPEC.md` (desain, invariants I-1..I-6, edge cases E1..E9), `devlog/` (catatan 30 dan 31 Okt). Materi Aave yang lebih luas ada di [`../docs/aave-v3-liquidation-sim.md`](../docs/aave-v3-liquidation-sim.md) dan [`../docs/defi-protocol-onepager.md`](../docs/defi-protocol-onepager.md).

## Jalanin

```bash
forge build
forge test
```

Dependency (`lib/forge-std`, `lib/openzeppelin-contracts`) tidak di-commit. Setelah clone:

```bash
forge install foundry-rs/forge-std
git clone --depth 1 --branch v5.1.0 https://github.com/OpenZeppelin/openzeppelin-contracts.git lib/openzeppelin-contracts
```

## Test fork mainnet (sudah dijalankan, hijau)

Butuh RPC. RPC publik cukup, dan tidak perlu API key:

```bash
FORK_RPC_URL=https://ethereum-rpc.publicnode.com forge test --match-path test/ForkFlashLoan.t.sol -vv
```

Tanpa `FORK_RPC_URL`, dua test itu di-skip, jadi `forge test` biasa tetap jalan offline.

Yang diuji: flash loan **1.000 USDC** dari Pool Aave v3 mainnet `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2`, lewat `deal` untuk menyiapkan premium, lalu:

- callback menerima `amount` dan premium terbaca dari `FLASHLOAN_PREMIUM_TOTAL()` (5 bps = 0,05%, jadi 0,5 USDC untuk 1.000 USDC).
- saldo aToken USDC naik tepat sebesar premium.
- saldo USDC milik Pool **tidak berubah** (lihat catatan di bawah).
- tanpa saldo untuk premium, seluruh transaksi revert dan tidak ada dana yang hilang.

## Deploy lokal di anvil fork (sudah diverifikasi)

Anvil di port khusus supaya tidak tabrakan dengan project lain (8550):

```bash
anvil --fork-url https://ethereum-rpc.publicnode.com -p 8550
```

Di terminal lain:

```bash
POOL=0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2 \
PRIVATE_KEY=<anvil key> \
env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
forge script script/DeployFlashLoan.s.sol:DeployFlashLoan \
  --rpc-url http://127.0.0.1:8550 --broadcast
```

Script menulis `deployments/31337.json` dan meng-allowlist `RecordAction`.

## Tiga hal yang bikin project ini berbeda dari "contoh flash loan" di blog

### 1. Premium tidak dibuat oleh protokol

Pool menarik `amount + premium`. Kalau action tidak menghasilkan apa pun, premium harus sudah ada di saldo receiver sebelum transaksi. Itu sebabnya test lokal yang lupa menyiapkan premium gagal dengan `InsufficientRepayment`, dan kegagalan itu benar.

### 2. Underlying tidak tinggal di Pool

Saat mengukur fee lewat `balanceOf(POOL)`, hasilnya nol. Setelah ditelusuri dengan `-vvvv`, USDC dikirim dari **aToken** (`transferUnderlyingTo`) dan dikembalikan ke aToken. Pool Aave v3 adalah kontrak logika, bukan kustodian aset. Yang bertambah adalah saldo USDC di `aEthUSDC` `0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c`, dan itu berarti premium masuk ke supplier.

### 3. `params` tidak dipakai untuk `call` bebas

Pola `(target, calldata)` dari `params` membuat receiver jadi proxy yang bisa disuruh memanggil kontrak apa pun. Di sini `params` hanya diteruskan ke action yang ada di allowlist, dan allowlist dicek dua kali (saat request dan saat callback).

## Yang belum / butuh aksi manual

- Deploy ke testnet (Sepolia) belum. Butuh RPC, private key berisi gas, dan address Pool Aave v3 di chain itu. Tidak ada address testnet yang ditulis di sini karena belum dijalankan.
- Verifikasi kontrak di explorer belum.
- Strategi nyata (arbitrase, collateral swap) belum. Action yang ada cuma untuk menguji mekanisme, dan `MintProfitAction` mencetak token, jadi tidak valid di mainnet.
