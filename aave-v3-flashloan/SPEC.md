# SPEC: Flash Loan Receiver Aave v3

> Task roadmap: **Sab 31 Okt 2026**. "Flash loan di Aave v3: cara kerja, fee structure, use cases legitimate (arbitrage, collateral swap). Implement flash loan receiver contract sederhana di Foundry. Test di fork mainnet dengan anvil --fork-url."
>
> Materi pendukung: [`docs/aave-v3-liquidation-sim.md`](../docs/aave-v3-liquidation-sim.md) dan [`docs/defi-protocol-onepager.md`](../docs/defi-protocol-onepager.md).

## 1. Tujuan

Membuat receiver flash loan yang bisa dipakai untuk menjalankan satu strategi di dalam callback, dengan dua hal yang diuji secara eksplisit:

1. **Dana harus kembali dalam transaksi yang sama.** Kalau tidak, seluruh transaksi batal, termasuk efek strateginya.
2. **Callback tidak boleh bisa dipicu pihak lain.** Receiver memegang dana dan allowance, jadi jalur masuknya harus sempit dan jelas.

## 2. Scope

### Masuk scope

- `FlashLoanReceiver`: minta pinjaman ke Pool, jalankan action dari allowlist, bayar `amount + premium`.
- Plugin `IFlashLoanAction` supaya strategi tidak menumpuk di dalam receiver.
- `RecordAction`: action minimal untuk membuktikan dana benar-benar ada di callback.
- `MintProfitAction`: simulasi action yang menghasilkan profit, khusus test lokal.
- Test lokal dengan `MockPool` (alur lengkap: kirim, callback, tarik kembali).
- Test fork mainnet melawan Pool Aave v3 asli dan USDC asli.
- Deploy script yang menulis `deployments/<chainId>.json`.

### Di luar scope

- Strategi arbitrase atau collateral swap yang nyata. Itu butuh integrasi DEX dan perhitungan profit, dan bukan inti materi flash loan.
- `flashLoan` multi-asset (`flashLoan` dengan array asset). Yang dipakai `flashLoanSimple`.
- Fee token LINK atau referral program.
- Frontend dan bot likuidasi.

## 3. Kontrak

### 3.1 `FlashLoanReceiver`

| Fungsi | Akses | Keterangan |
|---|---|---|
| `requestFlashLoan(address asset, uint256 amount, address action, bytes params)` | owner | Minta pinjaman, action harus ada di allowlist |
| `executeOperation(address, uint256, uint256, address, bytes)` | **hanya Pool** | Callback. Jalankan action, cek saldo cukup, approve Pool |
| `setActionAllowed(address, bool)` | owner | Allowlist action |
| `sweep(address asset, address to, uint256 amount)` | owner | Tarik sisa dana |
| `POOL()` / `ADDRESSES_PROVIDER()` | view | Immutable, dibaca sekali saat deploy |

State: `lastAmount`, `lastPremium`, `lastAction`, `isActionAllowed`.

### 3.2 `IFlashLoanAction`

```solidity
function onFlashLoan(address asset, uint256 amount, bytes calldata params) external;
```

Satu fungsi, tanpa nilai balik. Alasannya: keputusan lulus atau gagal ada di receiver (cek saldo), bukan di action. Action yang mau melaporkan hasil bisa menyimpannya sendiri atau emit event.

### 3.3 `MockPool`

Meniru urutan Aave: hitung premium, transfer `amount` ke receiver, panggil `executeOperation`, lalu `transferFrom` sebesar `amount + premium`, dan cek saldo akhir. Tanpa langkah `transferFrom` terakhir, mock tidak menguji apa pun soal pembayaran.

## 4. Invariants

- **I-1:** `executeOperation` hanya bisa dipanggil `POOL`. Selain itu revert `NotPool`.
- **I-2:** `initiator` harus `address(this)`. Pinjaman yang dimulai pihak lain ditolak `NotSelfInitiated`, walaupun pemanggilnya Pool.
- **I-3:** Action yang dijalankan harus ada di allowlist, dicek dua kali: di `requestFlashLoan` dan di `executeOperation`. Cek kedua penting karena `params` datang dari luar.
- **I-4:** Saldo aset di receiver setelah action harus minimal `amount + premium`. Kalau tidak, revert sebelum Pool sempat mencoba menarik.
- **I-5:** Allowance ke Pool selalu tepat `amount + premium`, dan habis terpakai setelah transaksi. Tidak ada allowance menganggur.
- **I-6:** Kalau satu langkah gagal, seluruh transaksi batal. Tidak ada state yang tersisa setengah jalan.

## 5. Edge cases

| # | Kasus | Perilaku |
|---|---|---|
| E1 | `pool == address(0)` saat deploy | revert `ZeroAddress` |
| E2 | Action tidak di allowlist | revert `ActionNotAllowed(action)` |
| E3 | Pemanggil `requestFlashLoan` bukan owner | revert `OwnableUnauthorizedAccount` |
| E4 | `executeOperation` dipanggil langsung oleh EOA | revert `NotPool(caller)` |
| E5 | `initiator` bukan receiver | revert `NotSelfInitiated(initiator)` |
| E6 | Saldo tidak cukup untuk premium | revert `InsufficientRepayment(available, required)` |
| E7 | Action menghasilkan profit lebih besar dari premium | sisa profit tinggal di receiver, bisa di-`sweep` |
| E8 | Pinjaman kedua berturut-turut | jalan, karena `forceApprove` menimpa allowance, bukan menambah |
| E9 | `params` kosong | boleh, action yang menentukan artinya |

## 6. Keamanan: tiga hal yang menentukan

1. **Siapa yang bisa memicu pinjaman.** Kalau `requestFlashLoan` terbuka untuk umum, siapa pun bisa memilih action dan `params`. Walaupun dana harus kembali, pemanggil bisa memakai allowance dan saldo receiver untuk kepentingannya. Karena itu `onlyOwner` bukan formalitas.
2. **Eksekusi kode dari `params`.** Desain alternatif yang populer adalah `params` berisi `(target, calldata)` lalu receiver melakukan `call` bebas. Itu pola yang sering berakhir jadi Lubian atau rug: receiver jadi proxy yang bisa disuruh memanggil apa saja. Di sini `params` hanya diteruskan ke action yang **sudah** di allowlist, jadi permukaan serangnya satu lapis lebih kecil.
3. **Sumber premium.** Flash loan bukan uang gratis. `amount + premium` harus ada di akhir callback. Kalau action tidak menghasilkan profit, premium diambil dari saldo sendiri. Ini yang membuat test tanpa pre-funding gagal, dan kegagalan itu benar.

## 7. Rencana verifikasi

- `forge test` lokal: 10 test (termasuk 1 fuzz test) dengan `MockPool`.
- Fork mainnet: 2 test melawan Pool `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2` dan USDC asli, dijalankan dengan `FORK_RPC_URL`. Tanpa env itu, test di-skip supaya suite tetap bisa jalan offline.
- Deploy lokal di anvil fork: memastikan script jalan dan `deployments/31337.json` tertulis.
- Deploy testnet sungguhan: **langkah manual user**, butuh dana gas, RPC, dan private key. Tidak ada address atau tx hash testnet yang ditulis di dokumen ini.
