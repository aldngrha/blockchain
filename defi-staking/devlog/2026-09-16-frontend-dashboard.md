# 16 Sep 2026 - Project 1: Frontend Dashboard

> Task roadmap: Build Next.js dashboard: tampilkan staked amount per user, total TVL, APY estimate, claimable reward. Stake form + unstake form dengan input validation. Real-time update via event watching.

## Apa yang dikerjakan

Aplikasi lengkap di `frontend/`, mirror pattern frontend `nft-minting-dapp` (yang udah proven build 11 Sep). Struktur:

- `package.json`, `.npmrc`, `.oxlintrc.json`, `.gitignore`, `.env.example`, `index.html`
- `vite.config.ts`: virtual module `virtual:local-deployment` yang baca `../deployments/31337.json` (output deploy script) tiap dev server start / build, plus validasi format address
- `src/config.js`: chain Anvil custom (31337) + Sepolia, wagmi config via RainbowKit `getDefaultConfig`, resolusi address (env override, lalu deployment file)
- `src/abi.js`: ABI hand-written dari `src/StakingPool.sol` dan `src/RewardToken.sol`, termasuk 5 custom error StakingPool + error ERC20 OZ v5 biar viem bisa decode revert reason
- `src/lib/format.js`: format token (string-based, tanpa kehilangan presisi), `validateAmount` (regex, zero check, max check, panjang desimal), `formatApy` (BigInt, `n/a` kalau totalStaked 0)
- `src/lib/errors.js`: parser error yang jalan menyusuri `cause` chain viem sampai `data.errorName`, mapping ke pesan manusiawi, plus user rejection (code 4001) dan chain mismatch
- `src/hooks/usePoolReads.js`: semua read (getStakedBalance, earned, getTotalStaked, rewardRate, symbol, decimals, balanceOf, allowance) pakai `useReadContract`, earned/staked/TVL di-poll ringan (3-5 detik) karena reward jalan tiap detik
- `src/hooks/usePoolEvents.js`: `watchContractEvent` untuk Staked/Unstaked/RewardPaid/EmergencyWithdraw/RewardRateSet, tiap event `invalidateQueries()`
- `src/hooks/useStakingActions.js`: runner transaksi sekuensial pakai `writeContractAsync` + `waitForTransactionReceipt`; stake bisa 2 langkah (approve kalau allowance kurang, lalu stake), plus unstake/claim/emergencyWithdraw, state fase (`approve/stake/unstake/claim/emergency`) dan sub-state (`wallet`/`block`)
- `src/components/`: PositionCard (staked + claimable + tombol claim), PoolStats (TVL, APY estimate, wallet balance), StakeForm, UnstakeForm (tombol Max, validasi live), EmergencyZone (confirm dialog: Escape close, focus trap, fokus balik ke trigger), ActionFeedback (aria-live: fase, error, sukses, dismissable)
- `src/App.jsx`: gating state: address belum dikonfigurasi, belum connect, salah chain (tombol switch via `useSwitchChain`), read error, dashboard
- `frontend/README.md`: setup end-to-end anvil sampai claim

Catatan UI: ini draft tanpa arahan desain (gak ada DESIGN.md), jadi dials ENERGY 1 / RHYTHM 1 / MOTION 1: light theme, palet stone + satu aksen hijau + merah khusus destructive, tanpa gradient/glow/emoji, transisi hover 120ms doang. Kontras semua pasangan teks dihitung, terendah 5.08:1 (putih di tombol hijau #1a7f37), semua di atas WCAG AA 4.5:1. Semua kontrol min-height 44px, `:focus-visible` outline, form pakai label `htmlFor`, feedback pakai `role="alert"` dan `aria-live`.

## Masalah & Solusi

### Roadmap bilang Next.js, tapi gw pakai Vite

- Masalah: task roadmap 16 Sep nulis "Build Next.js dashboard", tapi satu-satunya stack frontend yang pernah gw buktikan bisa build dan gw kuasai adalah Vite + React 19 + wagmi v3 + RainbowKit v2 dari `nft-minting-dapp`.
- Kenapa: Next.js itu server rendering framework; buat dashboard yang 100% client-side read ke RPC lokal, dia nambah konsep baru (App Router, hydration, ssr config wagmi) yang bukan fokus task ini. Target task-nya wagmi pattern + event watching + form validation, bukan framework.
- Solusi: pilih Vite yang identik dengan project nft (versi dependency sama persis, struktur config sama, `getDefaultConfig` sama), sehingga gw latih materi yang memang mau dilatih. Trade-off-nya dicatat: kalau nanti butuh SSR atau SEO (misal landing page protocol), baru pindah Next.js.
- Pelajaran: konsistensi stack antar project latihan lebih bernilai daripada ikut nama framework di roadmap; yang penting deliverable-nya jalan dan pattern-nya nempel.

### npm install ditolak: ERESOLVE rainbowkit vs wagmi 3

- Masalah: `npm install` gagal dengan `ERESOLVE`: `peer wagmi@"^2.9.0" from @rainbow-me/rainbowkit@2.2.11` bentrok dengan `wagmi@3.7.7`.
- Kenapa: RainbowKit 2.2.11 belum update range peer dependency-nya buat wagmi 3.x, padahal runtime API yang dia pakai kompatibel. Project nft gw juga jalan pakai kombinasi ini, terbukti dari `node_modules` di sana yang punya rainbowkit 2.2.11 + wagmi 3.7.7 sekaligus.
- Solusi: `.npmrc` berisi `legacy-peer-deps=true` di folder frontend, jadi `npm install` polos jalan tanpa harus inget flag. Hasil: 74 packages, 0 vulnerabilities.
- Pelajaran: peer range yang ketinggalan bukan bukti inkompatibilitas runtime; cek dulu kombinasi yang udah proven, terus yang bikin reproducible (`.npmrc`), bukan flag di command yang gampang lupa.

### `define` custom di Vite 8 cuma jalan di build, gak di dev

- Masalah: awalnya address dari `deployments/31337.json` gw suntik lewat `define: { __LOCAL_DEPLOYMENT__: JSON.stringify(...) }` di `vite.config.ts`. Di `npm run build` address ter-bake ke dist, tapi pas gw curl module hasil transform dev server, identifier `__LOCAL_DEPLOYMENT__` masih utuh. Artinya `npm run dev` bakal selalu bilang "address belum dikonfigurasi" walau deployment file ada.
- Kenapa: Vite 8 (rolldown) ternyata cuma menerapkan define custom identifier di jalur build. Gw buktikan dengan probe kecil: module berisi `typeof __PROBE__` juga gak ke-replace di dev.
- Solusi: ganti mekanisme jadi virtual module plugin di `vite.config.ts`: `resolveId` + `load` yang serve `export default {...addresses...}` untuk id `virtual:local-deployment`, dan `src/config.js` tinggal `import localDeployment from "virtual:local-deployment"`. Plugin ini jalan identik di dev dan build. Terverifikasi dua-duanya: dev server serve address asli via `/@id/virtual:local-deployment`, dan kedua address ada di `dist/`.
- Pelajaran: verifikasi injeksi build-time di KEDUA mode (dev dan build), jangan asumsikan satu mekanisme berlaku ke dua-duanya.

### Chain `localhost` bawaan wagmi itu 1337, anvil itu 31337

- Masalah: kalau ikut insting dan import `localhost` dari `wagmi/chains`, dashboard bakal target chain id yang salah, dan kontrak yang dideploy anvil gak akan pernah kebaca.
- Kenapa: chain `localhost` di viem/wagmi didefinisikan dengan id 1337 (warisan hardhat lama), sedangkan anvil default ke 31337 (id hardhat baru). Gw konfirmasi langsung: `import { localhost } from "viem/chains"` memberi `{ id: 1337 }`.
- Solusi: `src/config.js` bikin chain sendiri pakai `defineChain({ id: 31337, ..., rpcUrls: { default: { http: ["http://127.0.0.1:8545"] } } })` dan pakai itu di `getDefaultConfig` bareng Sepolia. Bonusnya: banner salah chain jadi bisa nawarin tombol switch ke Anvil yang benar.
- Pelajaran: nama chain "localhost" gak menjamin id-nya cocok dengan client yang lo jalanin; selalu cocokkan chain id eksplisit.

### `parseUnits` diam-diam nge-bulat, dan custom error viem gak ada di `error.name`

- Masalah: dua temuan dari unit check yang gw tulis sendiri. Pertama, `parseUnits("1.123456789012345678901", 18)` gak throw; dia return `1123456789012345679` (dibulatkan), jadi amount yang dikirim bisa beda tipis dari yang user ketik. Kedua, pas gw tes `parseTxError` dengan error revert asli, pesan custom error StakingPool gak ke-mapping; parser cuma dapat pesan generik.
- Kenapa: `parseUnits` nge-round ke unit terdekat, bukan validasi. Untuk error: viem nge-decode custom error ke dalam `ContractFunctionRevertedError` yang tersimpan di rantai `cause` dengan bentuk `node.data.errorName`, bukan di `error.name` layer atas (yang isinya nama wrapper generik). Gw juga sempat salah konstruksi di test (nurunin objek hasil decode ke constructor), dan dari situ kebaca source viem: constructor maunya data hex mentah + abi, dia yang decode.
- Solusi: `validateAmount` sekarang ngecek panjang fraksi sebelum parse (`Too many decimal places (token uses N)`), dan `parseTxError` jalan menyusuri `cause` sampai 10 level buat nyari `data.errorName` plus `UserRejectedRequestError`/code 4001 dan `ChainMismatchError`. 18 unit check jalan semua PASS pakai `encodeErrorResult`/`decodeErrorResult` viem beneran, jadi jalur decode-nya keuji terhadap runtime viem, bukan stub.
- Pelajaran: helper parsing itu kontrak perilakunya harus diuji: rounding diam-diam dan error yang ke-bungkus berlapis adalah dua tempat bug yang gak kelihatan dari build sukses.

## Status jujur

Terverifikasi langsung:

- `npm install` exit 0 (74 packages, 0 vulnerabilities, via `.npmrc` legacy-peer-deps).
- `npm run lint` exit 0: 0 warnings, 0 errors (16 files).
- `npm run build` exit 0 (warning ukuran chunk >500 kB, sifatnya informatif dari walletconnect SDK, bukan error).
- 18 unit check PASS terhadap viem asli: decode custom error, mapping user rejection, fallback pesan, formatApy (n/a, rate 0, 2 desimal), formatToken, validateAmount (empty/letters/zero/max/excess decimals/valid).
- Injeksi address `deployments/31337.json` terverifikasi di dev (virtual module serve address asli) dan build (kedua address ada di `dist/`). Kebetulan positif: deploy script-nya udah nulis file itu, jadi gw uji pakai data asli, bukan mock.
- Dev server (`npm run dev`) nyaji halaman, semua module ke-transform 200 tanpa error di log.

Yang butuh aksi manual (gak bisa gw verifikasi di lingkungan ini karena butuh wallet browser):

- Alur interaktif end-to-end: connect RainbowKit, approve, stake, lihat angka update via event, claim, emergency withdraw. Semua path-nya dibangun dan keuji di level unit/logic, tapi belum pernah ada klik manusia + MetaMask. Ikuti langkah di `frontend/README.md` (anvil, deploy, import key anvil, setRewardRate, connect).
- State salah chain, SetupNotice, dan read-error banner: kodenya ada dan gating-nya sederhana, tapi gak tereksekusi di sesi ini (deployment file kebetulan udah ada, dan butuh wallet buat ganti chain). Path "deployment file gak ada" di plugin sudah dianalisis (try/catch ke string kosong) tapi belum dieksekusi runtime.
- UI tetap draft tanpa arahan desain: fungsional dan bersih, belum ada identitas visual yang disetujui owner.
