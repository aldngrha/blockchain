# Blockchain Engineer — Jadwal Lengkap (3 Agustus 2026 s/d Selesai)

Satu file utuh, dari titik lanjut lo (setelah Cyfrin Section 3 kelar) sampe seluruh silabus beres. Tiap hari ada materi + penjelasan konkret apa yang dikerjain.

**Catatan:**
- Badminton udah dihapus total — semua hari (Sen–Min) 1 sesi belajar per hari, gak ada slot kosong.
- Gym Senin/Rabu tetap fleksibel (gym atau workout rumah, sama aja).
- Total **172 hari belajar**, mulai 3 Agustus 2026, selesai **21 Januari 2027**.
- Nama-nama milestone review ("MEI FINAL REVIEW", dst) itu nama asli dari silabus lama — abaikan aja nama bulannya, fokus ke tanggal aktual di tabel.

---

## Ags 2026

**Sen 3 Ags — GYM HARI — Proxy Pattern Intro**
Upgradeable contracts: kenapa dibutuhkan, trade-off (centralization). Transparent Proxy vs UUPS Proxy. Implementasi UUPS proxy sederhana dengan OpenZeppelin. Pahami storage collision problem.

**Sel 4 Ags — BELAJAR — Foundry Advanced: Fuzz Testing**
Fuzz testing di Foundry: apa itu property-based testing. Tulis fuzz test untuk ERC-20 dan FundMe — let Foundry generate random inputs untuk temukan edge cases. Pahami stateful vs stateless fuzzing.

**Rab 5 Ags — GYM HARI — Cyfrin Section 4: Lottery**
Cyfrin Section 4: Smart Contract Lottery dengan Chainlink VRF (Verifiable Random Function). Ini solusi proper untuk on-chain randomness. Build along, pahami cara Chainlink VRF bekerja.

**Kam 6 Ags — BELAJAR — Lottery Tests + Review**
Tulis comprehensive test untuk Lottery: unit tests, integration tests. Review semua minggu ini. Identifikasi pattern mana yang paling sering dipakai — Ownable, AccessControl, Pull Payment, Proxy.

**Jum 7 Ags — BELAJAR — ERC-1155 Multi-Token Standard**
Baca EIP-1155: fungible + non-fungible dalam 1 kontrak. Buat contract sederhana: mint batch tokens, safeTransferFrom. Pahami kapan pakai ERC-1155 vs ERC-20+ERC-721 terpisah (gas efficiency).

**Sab 8 Ags — SABTU — Events & Logs Deep Dive**
Events vs storage: kapan lebih hemat pakai events. Indexed parameters — maksimal 3 per event. Cara filter events off-chain dengan ethers.js: provider.getLogs(), contract.queryFilter(). Build event indexer sederhana.

**Min 9 Ags — MINGGU — Assembly & Low-Level Calls**
Inline assembly di Solidity (yul): kapan dibutuhkan dan risikonya. Low-level calls: call(), delegatecall(), staticcall(). Pahami perbedaan ketiganya — kenapa delegatecall bisa berbahaya jika salah.

**Sen 10 Ags — GYM HARI — Cyfrin Section 5: ERC20 + DeFi**
Cyfrin Section 5: membuat ERC-20 token dan intro DeFi concepts. Build along. Pahami token economics: total supply, minting, burning. Review semua ERC standards yang sudah dipelajari.

**Sel 11 Ags — BELAJAR — Cyfrin Section 6: NFT**
Cyfrin Section 6: NFT contract lengkap dengan on-chain SVG metadata dan IPFS metadata. Pahami perbedaan on-chain vs off-chain metadata. Build both versions.

**Rab 12 Ags — GYM HARI — Project Prep: DeFi Staking Design**
Mulai design Project 1 (Juli nanti): DeFi Staking Protocol. Baca source code Synthetix staking rewards contract. Sketch arsitektur: RewardToken + StakingPool. Tulis spec: semua fungsi, parameter, edge cases.

**Kam 13 Ags — BELAJAR — Cyfrin Section 7 + Review**
Cyfrin Section 7: DeFi — Stablecoins. Review seluruh Mei minggu 1-2. Quiz diri: bisa implement Ownable, Pausable, AccessControl, Proxy dari ingatan? Catat gap yang masih ada.

**Jum 14 Ags — BELAJAR — Cyfrin Section 8: Merkle Trees**
Cyfrin Section 8: Merkle trees dan signatures. Implementasi Merkle tree untuk whitelist (lebih hemat gas dari mapping). Pahami EIP-712: structured data signing untuk UX yang lebih aman.

**Sab 15 Ags — SABTU — Cyfrin Section 9: Upgrades**
Cyfrin Section 9: Upgradeable contracts lengkap — UUPS, Transparent, Diamond proxy. Kapan upgrade pattern boleh dipakai dan kapan tidak (trustless protocol). Latihan upgrade dari v1 ke v2.

**Min 16 Ags — MINGGU — Cyfrin Section 10: DAO**
Cyfrin Section 10: DAO governance — Governor contract, TimelockController, voting. Ini preview untuk Project 2 (Agustus). Pahami full flow: proposal → vote → timelock → execute.

**Sen 17 Ags — GYM HARI — Gas Optimization Advanced**
Advanced gas tricks: bitmap untuk boolean flags, packed structs, short-circuit evaluation. SSTORE2 untuk menyimpan data besar. Tulis before/after benchmark. Target: kurangi gas 30%+ dari versi naif.

**Sel 18 Ags — BELAJAR — Cyfrin Section 11: Security**
Cyfrin Section 11: Security & Auditing intro. Ikuti semua materi Cyfrin tentang security. Ini preview untuk bulan Juni. Catat semua vulnerability pattern yang disebutkan.

**Rab 19 Ags — GYM HARI — Cyfrin Section 12 + Grand Review**
Selesaikan sisa Cyfrin sections. Grand review seluruh Mei: tulis 1 halaman 'Solidity patterns yang gw kuasai'. Deploy ulang FundMe + Lottery ke Sepolia dengan clean codebase.

**Kam 20 Ags — BELAJAR — MEI FINAL REVIEW**
Review total bulan Mei. Buat GitHub repo 'solidity-patterns' — kumpulkan semua pattern yang sudah dipelajari dengan README untuk tiap pattern. Ini akan jadi referensi kamu sendiri.

**Jum 21 Ags — BELAJAR — ethers.js v6 Fundamentals**
Setup Next.js + ethers.js v6. Connect MetaMask ke app. Read dari kontrak: panggil fungsi view/pure. Pahami: provider vs signer, JSON-RPC calls. Buat halaman yang nampilin ETH balance dari input address.

**Sab 22 Ags — SABTU — wagmi v2 Setup**
Install wagmi v2 + viem. Setup WagmiProvider dan QueryClientProvider di Next.js. Pahami hooks: useAccount, useBalance, useReadContract, useWriteContract. Refactor balance checker pakai wagmi.

**Min 23 Ags — MINGGU — RainbowKit + Wallet Connect**
Install RainbowKit: wallet connect UI yang sudah jadi dan proper. Setup ConnectButton. Konfigurasi supported chains (mainnet + Sepolia). Test connect dengan MetaMask, WalletConnect, Coinbase Wallet.

**Sen 24 Ags — GYM HARI — Transaction UX: States & Errors**
Handle semua transaction states: idle → pending → success → error. Tampilkan loading state yang proper. Handle rejection dari user, network error, revert error. Buat toast notification system.

**Sel 25 Ags — BELAJAR — Read Contract + Events**
useReadContract untuk read data. useWatchContractEvent untuk listen events real-time. Buat dashboard yang update otomatis kalau ada event Transfer dari ERC-20 kamu. Pahami polling vs WebSocket.

**Rab 26 Ags — GYM HARI — Write Contract + Full Flow**
useWriteContract + useWaitForTransactionReceipt. Build full flow: input form → submit tx → loading state → success/error → refresh data. Sambungkan ke ERC-20 dari bulan April.

**Kam 27 Ags — BELAJAR — Review Web3 Frontend Dasar**
Review semua yang dipelajari. Buat checklist: provider, signer, read, write, events, loading states, error handling. Identify gap. Persiapkan materi The Graph minggu depan.

**Jum 28 Ags — BELAJAR — The Graph: Indexing Events**
Apa itu indexer dan kenapa blockchain butuh indexing. Setup The Graph Studio. Buat subgraph pertama untuk ERC-20: index Transfer events. Deploy subgraph ke The Graph Studio testnet.

**Sab 29 Ags — SABTU — GraphQL Query dari Frontend**
Query subgraph dari Next.js pakai Apollo Client atau urql. Tampilkan riwayat transfer dari ERC-20 kamu di halaman frontend. Implement pagination. Pahami kenapa The Graph lebih efisien dari getLogs().

**Min 30 Ags — MINGGU — IPFS + Pinata**
Upload file ke IPFS via Pinata API. Upload JSON metadata (NFT standard). Simpan IPFS hash di smart contract. Buat NFT yang tokenURI-nya pointing ke Pinata. Test: mint NFT, cek metadata di OpenSea testnet.

**Sen 31 Ags — GYM HARI — Security: Reentrancy Attack**
Reentrancy attack: cara kerja lengkap, contoh nyata (The DAO hack 2016). Buat kontrak yang VULNERABLE terlebih dahulu. Exploit sendiri pakai Foundry. Lalu fix dengan checks-effects-interactions + ReentrancyGuard.


## Sep 2026

**Sel 1 Sep — BELAJAR — Security: tx.origin + Selfdestruct**
tx.origin vulnerability: phishing attack vector. Kapan boleh pakai tx.origin (tidak pernah untuk auth). Selfdestruct abuse: force-send ETH ke kontrak yang tidak expect. Buat exploit + fix keduanya.

**Rab 2 Sep — GYM HARI — Ethernaut Level 1-6**
Mulai Ethernaut OpenZeppelin challenges. Level 1 (Fallback), 2 (Fallout), 3 (Coin Flip), 4 (Telephone), 5 (Token), 6 (Delegation). Untuk setiap level: pahami vulnerability → tulis exploit di Foundry → solve.

**Kam 3 Sep — BELAJAR — Ethernaut Review + Write-up**
Tulis write-up singkat untuk setiap level Ethernaut yang sudah diselesaikan: vulnerability apa, cara exploit, cara fix. Ini akan jadi konten artikel pertama kamu di Mirror.xyz.

**Jum 4 Sep — BELAJAR — Security: Integer + Overflow**
Integer overflow/underflow: sebelum Solidity 0.8 (SafeMath era) vs sesudah. Flash loan attack konsep dasar: 1 transaksi borrow → manipulate → repay. Price oracle manipulation basics.

**Sab 5 Sep — SABTU — Ethernaut Level 7-10**
Ethernaut Level 7 (Force), 8 (Vault), 9 (King), 10 (Re-entrancy). Level 10 adalah reentrancy yang sebenarnya — ini yang paling penting. Tulis exploit yang bersih di Foundry untuk setiap level.

**Min 6 Sep — MINGGU — Ethernaut Level 11-13**
Level 11 (Elevator), 12 (Privacy), 13 (Gatekeeper One). Level 12 Privacy menunjukkan bahwa semua data di blockchain BISA dibaca — bahkan private variables. Pelajaran penting untuk developer.

**Sen 7 Sep — GYM HARI — Install Slither + Scan**
Install Slither: pip install slither-analyzer. Scan semua project yang sudah dibuat. Baca setiap warning dengan seksama. Buat tabel: warning apa, di kontrak mana, cara fix-nya. Fix semua high/medium findings.

**Sel 8 Sep — BELAJAR — Security Best Practices**
Baca Consensys Smart Contract Best Practices lengkap. Buat security checklist personal untuk review kontrak. Pelajari checks-effects-interactions pattern. Review OpenZeppelin contracts: bagaimana mereka handle security.

**Rab 9 Sep — GYM HARI — NFT Minting dApp — Full Build**
Build NFT minting dApp end-to-end: ERC-721 contract + IPFS metadata + Next.js frontend + RainbowKit + wagmi. User bisa connect wallet, klik mint, NFT muncul di wallet mereka. Deploy ke Sepolia.

**Kam 10 Sep — BELAJAR — JUNI REVIEW + Polish dApp**
Review seluruh Juni: Web3 frontend, security, Ethernaut. Polish NFT dApp: error handling yang baik, loading states, mobile responsive. Tulis README lengkap. Ini portfolio item pertama yang layak.

**Jum 11 Sep — BELAJAR — Project 1: Finalisasi Spec**
Finalisasi spec DeFi Staking Protocol. Detail: RewardToken (ERC-20, mintable oleh StakingPool), StakingPool (stake, unstake, claimReward, reward per second). Edge cases: stake 0, unstake lebih dari staked, emergency withdraw.

**Sab 12 Sep — SABTU — Project 1: RewardToken Contract**
Implement RewardToken: ERC-20 + Ownable + mint() hanya bisa dipanggil StakingPool. Tulis semua unit tests dulu (TDD approach) — test harus fail dulu sebelum implement. Target: 100% coverage RewardToken.

**Min 13 Sep — MINGGU — Project 1: StakingPool Core**
Implement StakingPool: mapping staked amounts, stake(), unstake(). Belum ada reward dulu. Test semua: stake normal, unstake normal, unstake melebihi staked, stake dari multiple users.

**Sen 14 Sep — GYM HARI — Project 1: Reward Calculation**
Implement reward per-second accumulation: rewardPerTokenStored, userRewardPerTokenPaid, rewards mapping. Pahami math-nya — ini tricky. Test dengan multiple users stake/unstake di timing berbeda.

**Sel 15 Sep — BELAJAR — Project 1: Fuzz Testing**
Tulis fuzz tests untuk StakingPool: random amounts, random users, random timing. Cari edge cases yang tidak terpikirkan. Target: 95%+ coverage. Pastikan tidak ada integer overflow, tidak ada stuck funds.

**Rab 16 Sep — GYM HARI — Project 1: Frontend Dashboard**
Build Next.js dashboard: tampilkan staked amount per user, total TVL, APY estimate, claimable reward. Stake form + unstake form dengan input validation. Real-time update via event watching.

**Kam 17 Sep — BELAJAR — Project 1: Deploy + Polish**
Deploy RewardToken + StakingPool ke Sepolia. Verify di Etherscan. Deploy frontend ke Vercel. Test full flow: connect wallet → stake → tunggu reward → claim. Buat Loom demo video 3 menit.

**Jum 18 Sep — BELAJAR — Project 1: README + GitHub**
Tulis README comprehensive: arsitektur diagram, cara deploy lokal, cara run tests, cara interact dengan kontrak, screenshot frontend, link demo video. Ini yang dilihat recruiter/client pertama kali.

**Sab 19 Sep — SABTU — Mulai Build in Public**
Tulis thread Twitter/X tentang Project 1: apa yang dibangun, masalah yang ditemui, pelajaran. Buat artikel di Mirror.xyz versi panjang. Setup GitHub profile README yang menarik dan informatif.

**Min 20 Sep — MINGGU — Project 2: Governance Research**
Research untuk Project 2. Baca Compound Governor Bravo source code. Pahami full governance lifecycle: propose → voting period → timelock → execute. Identifikasi semua parameter: quorum, threshold, voting period.

**Sen 21 Sep — GYM HARI — Project 2: Spec + Architecture**
Tulis spec lengkap Project 2 Governance dApp: GovernanceToken (ERC-20Votes), Governor, TimelockController. Architecture diagram. Define semua parameter: quorum 4%, voting delay 1 hari, voting period 1 minggu.

**Sel 22 Sep — BELAJAR — Project 2: GovernanceToken**
Implement GovernanceToken: ERC-20 + ERC-20Votes. Pahami votes checkpoint system — ini berbeda dari ERC-20 biasa. Test: delegate, checkpoints, past votes. Votes bisa delegate ke address lain.

**Rab 23 Sep — GYM HARI — Project 2: Governor Contract**
Implement Governor pakai OpenZeppelin Governor framework. Configure: GovernorSettings (delay, period, threshold), GovernorCountingSimple (for/against/abstain), GovernorVotes, GovernorTimelockControl.

**Kam 24 Sep — BELAJAR — Project 2: TimelockController**
Setup TimelockController: minimum delay, proposers (Governor), executors. Integration test: full governance flow end-to-end — propose → vote → queue → execute. Test quorum tidak tercapai, vote kalah, cancel proposal.

**Jum 25 Sep — BELAJAR — Project 2: Frontend — Proposal List**
Build governance frontend: halaman proposal list dengan status badge (Active/Pending/Succeeded/Defeated/Executed). Tampilkan: proposer, deskripsi, for/against/abstain votes, deadline.

**Sab 26 Sep — SABTU — Project 2: Frontend — Voting**
Voting interface: For / Against / Abstain dengan tombol. Tampilkan voting power user (delegated tokens). Disable vote kalau sudah vote atau proposal tidak active. Konfirmasi transaksi dengan loading state.

**Min 27 Sep — MINGGU — Project 2: The Graph untuk Governance**
Setup subgraph untuk governance: index ProposalCreated, VoteCast, ProposalExecuted events. Query dari frontend untuk tampilkan proposal history dan vote history per user.

**Sen 28 Sep — GYM HARI — Project 2: Deploy + Polish**
Deploy semua governance contracts ke Sepolia. Verify di Etherscan. Deploy frontend ke Vercel. Full end-to-end test: buat proposal, vote, tunggu timelock, execute. Buat demo video Loom.

**Sel 29 Sep — BELAJAR — Project 2: README + Publish**
Tulis README governance: cara kerja, parameter yang dipilih dan kenapa, cara buat proposal via frontend. Publish ke Twitter/X + Mirror.xyz. Ini portfolio item ke-2.

**Rab 30 Sep — GYM HARI — AMM Research: Uniswap v2**
Baca Uniswap v2 whitepaper + core contracts. Pahami x*y=k formula secara mendalam. Simulasikan di spreadsheet: apa yang terjadi ke price dan liquidity saat ada swap besar? Pahami impermanent loss math.


## Okt 2026

**Kam 1 Okt — BELAJAR — AMM Design + Spec**
Design SimpleDex: LiquidityPool contract untuk 2-token pair. Fungsi: addLiquidity, removeLiquidity, swapExactTokensForTokens. LP tokens sebagai proof of liquidity. Tulis spec lengkap.

**Jum 2 Okt — BELAJAR — AMM: Core Math Implementation**
Implement fungsi math AMM: getAmountOut() dengan formula x*y=k dan fee 0.3%. Tulis fuzz tests untuk math — pastikan invariant k selalu terjaga setelah setiap swap. Ini bagian paling kritis.

**Sab 3 Okt — SABTU — AMM: addLiquidity + LP Tokens**
Implement addLiquidity(): calculate LP tokens to mint, handle first liquidity provision. LP token adalah ERC-20 yang represent share of pool. Test: add liquidity, cek LP balance, verifikasi ratio.

**Min 4 Okt — MINGGU — AMM: Swap + removeLiquidity**
Implement swap() dengan slippage protection (minimum output parameter). removeLiquidity(): burn LP tokens, kembalikan proportional token amounts. Test: swap → price berubah sesuai formula.

**Sen 5 Okt — GYM HARI — AMM: Security + Edge Cases**
Security review AMM: reentrancy di swap, price manipulation via flashloan, integer precision (pakai MINIMUM_LIQUIDITY). Fuzz test semua fungsi. Cek: tidak ada stuck funds, tidak ada drain pool.

**Sel 6 Okt — BELAJAR — AMM: Deploy ke L2**
Deploy SimpleDex ke Arbitrum Sepolia testnet. Bandingkan gas cost L1 (Ethereum Sepolia) vs L2 (Arbitrum). Pahami: kenapa L2 jauh lebih murah — Optimistic Rollup vs ZK-Rollup basics.

**Rab 7 Okt — GYM HARI — AMM Frontend: Swap UI**
Build swap interface: token input/output dengan price impact display (pakai formula). Slippage tolerance setting. Deadline setting. Loading states yang proper saat transaksi pending.

**Kam 8 Okt — BELAJAR — AMM Frontend: Liquidity**
Add/remove liquidity interface: tampilkan pool stats (reserves, your share %, your LP tokens). Position tracker untuk liquidity providers. Deploy frontend ke Vercel.

**Jum 9 Okt — BELAJAR — AMM: README + Demo**
Tulis README AMM yang comprehensive. Buat demo video Loom: explain AMM concept, demo swap, demo add/remove liquidity. Publish artikel teknis di Mirror.xyz tentang cara implement AMM.

**Sab 10 Okt — SABTU — Mulai Cari Client: Platform Setup**
Setup profil di CryptoJobsList, Contra, LinkedIn (update dengan blockchain skills). Buat bio yang kuat: 'SWE dengan 3 DeFi project di portfolio'. Pin 3 project terbaik di GitHub.

**Min 11 Okt — MINGGU — Artikel Mirror.xyz Pertama**
Tulis artikel teknis pertama di Mirror.xyz: 'Cara Implement AMM dari Scratch — Pelajaran dari Build SimpleDex'. Ini bukan tutorial copy-paste — share genuine insight dari proses build kamu.

**Sen 12 Okt — GYM HARI — Research Target Client**
Identifikasi 15 Web3 startup kecil yang aktif di Twitter/X. Cari yang: baru raise seed, active development, tim kecil. Pahami product mereka, tech stack mereka, apa yang sedang mereka build.

**Sel 13 Okt — BELAJAR — 5 Pitch Pertama**
Kirim 5 pitch pertama via DM Twitter/X ke founder Web3 yang sudah diresearch. Setiap pitch harus spesifik ke project mereka: sebut feature yang sedang mereka develop, tunjukkan kamu udah riset. Pantau response.

**Rab 14 Okt — GYM HARI — Gitcoin Bounty + Open Source**
Explore Gitcoin bounties. Pilih 1 bounty yang sesuai skill — sekecil apapun ok. Atau kontribusi ke project open source Web3: fix bug kecil, improve dokumentasi. Proof of real-world contribution.

**Kam 15 Okt — BELAJAR — AGUSTUS PREP + Review**
Review seluruh Juli: 3 project selesai, pitch terkirim. Identifikasi skill gap yang masih ada. Rencanakan: kalau ada yang response pitch, apa yang akan kamu offer? Buat 'service menu' sederhana.

**Jum 16 Okt — BELAJAR — Follow Up Pitch + Pitch Baru**
Follow up 5 pitch dari minggu lalu (kalau belum ada response setelah 1 minggu, 1x follow up ok). Kirim 5 pitch baru ke target berbeda. Mulai track semua pitch di spreadsheet: siapa, kapan, status.

**Sab 17 Okt — SABTU — Code4rena / Sherlock Intro**
Daftar di Code4rena dan Sherlock audit platform. Baca cara kerja audit contests: fixed timeline, submit findings, judging. Baca 2-3 write-up audit terbaru untuk pahami format dan level ekspektasi.

**Min 18 Okt — MINGGU — Audit Contest: Ikuti yang Aktif**
Join 1 audit contest aktif di Code4rena atau Sherlock (pilih yang scope-nya sesuai kemampuan). Baca semua dokumentasi project yang di-audit. Mulai manual review kodenya — cari vulnerability.

**Sen 19 Okt — GYM HARI — Audit: Submit Findings**
Lanjut review audit contest. Submit semua findings yang ditemukan, sekecil apapun — bahkan QA/low severity. Tulis setiap finding dengan format: description, impact, proof of concept, recommendation.

**Sel 20 Okt — BELAJAR — ETHGlobal Hackathon Daftar**
Cek jadwal ETHGlobal online hackathon berikutnya. Daftar sekarang. Research sponsor prizes: Chainlink, Uniswap, The Graph biasanya ada hadiah khusus. Brainstorm ide project yang bisa dibangun dalam 48 jam.

**Rab 21 Okt — GYM HARI — Portfolio Final Polish**
Polish semua 3 project: perbaiki README yang masih kurang, tambahkan architecture diagram, pastikan semua live link berjalan. Buat portfolio page sederhana di GitHub Pages atau Vercel yang list semua project.

**Kam 22 Okt — BELAJAR — SEPTEMBER FINAL REVIEW**
Review total journey April–September. Hitung: berapa jam yang sudah diinvestasikan, apa yang sudah dikuasai, apa yang masih perlu ditingkatkan. Buat rencana 3 bulan ke depan (Oktober–Desember).

**Jum 23 Okt — BELAJAR — Client Onboarding Prep**
Siapkan semua dokumen untuk terima client pertama: simple contract template (scope of work, payment terms, deliverables), invoice template, cara terima pembayaran crypto (USDC/ETH). Tidak perlu fancy — yang penting ada.

**Sab 24 Okt — SABTU — Layer 2 Deep Dive**
Deep dive Layer 2: Optimistic Rollups (Arbitrum, Optimism) vs ZK-Rollups (zkSync, StarkNet). Pahami: fraud proof vs validity proof, withdrawal period, bridging. Deploy 1 kontrak ke zkSync testnet.

**Min 25 Okt — MINGGU — Cross-chain Basics**
Chainlink CCIP (Cross-Chain Interoperability Protocol) intro. Buat simple cross-chain message dari Sepolia ke Arbitrum Sepolia pakai CCIP. Pahami: bridge risk, why cross-chain is hard.

**Sen 26 Okt — GYM HARI — DeFi Protocol Research**
Deep dive 1 DeFi protocol yang menarik: Aave, Compound, atau Uniswap v3. Baca dokumentasi, baca source code, pahami cara kerjanya. Buat summary: 'Cara kerja [protocol] dalam 1 halaman'.

**Sel 27 Okt — BELAJAR — Persiapan Client Pertama**
Jika ada yang response pitch — prepare untuk call pertama: siapkan pertanyaan untuk pahami scope, estimate waktu pengerjaan, propose rate. Jika belum ada response — kirim 10 pitch baru.

**Rab 28 Okt — GYM HARI — Uniswap v3 Deep Dive**
Baca Uniswap v3 whitepaper penuh. Pahami: concentrated liquidity, tick system, price range. Bandingkan dengan v2 yang sudah kamu implement — apa improvement utamanya? Buat diagram arsitektur sendiri.

**Kam 29 Okt — BELAJAR — Uniswap v3 Source Code**
Clone repo Uniswap v3-core. Baca PoolManager, TickMath, SqrtPriceMath. Jangan coba pahami semua — fokus di swap execution path saja. Tulis catatan: 'Yang paling berbeda dari v2 adalah...'

**Jum 30 Okt — BELAJAR — Aave v3 Architecture**
Baca Aave v3 documentation dan whitepaper. Pahami: lending pool, interest rate model, health factor, liquidation. Simulasikan skenario liquidation di spreadsheet — kapan posisi jadi tidak aman?

**Sab 31 Okt — SABTU — Aave v3 Flash Loans**
Flash loan di Aave v3: cara kerja, fee structure, use cases legitimate (arbitrage, collateral swap). Implement flash loan receiver contract sederhana di Foundry. Test di fork mainnet dengan anvil --fork-url.


## Nov 2026

**Min 1 Nov — MINGGU — Review DeFi Week 1**
Review Uniswap v3 + Aave v3 minggu ini. Tulis 1 halaman: 'Perbedaan arsitektur Uniswap vs Aave dan use case masing-masing.' Ini akan jadi bahan artikel teknis berikutnya.

**Sen 2 Nov — GYM HARI — Mainnet Fork: Interact Langsung**
Gunakan anvil --fork-url untuk fork Ethereum mainnet lokal. Interact langsung dengan Uniswap v3 dan Aave v3 yang real — swap token, supply collateral, borrow. Ini lebih valuable dari membaca docs.

**Sel 3 Nov — BELAJAR — GMX + Perp DEX Research**
GMX v2: perpetual trading protocol. Pahami: GLP pool, funding rate, liquidation. Baca juga dYdX dan Synthetix Perps. Identifikasi: apa risiko protocol-level yang paling besar di perp DEX?

**Rab 4 Nov — GYM HARI — MEV: Flashbots & Arbitrage**
MEV (Maximal Extractable Value): apa itu, siapa yang melakukannya, dampaknya ke user. Flashbots: cara kerja MEV protection. Pahami: sandwich attack, frontrunning, backrunning. Ini penting untuk security audit.

**Kam 5 Nov — BELAJAR — DeFi Security: Price Oracle**
Price oracle manipulation attack: TWAP vs spot price. Baca case study: Mango Markets exploit ($114M). Reconstruct serangan dalam pseudocode. Apa yang seharusnya protocol lakukan untuk prevent ini?

**Jum 6 Nov — BELAJAR — DeFi Security: Reentrancy Advanced**
Cross-function reentrancy dan cross-contract reentrancy — lebih subtle dari basic reentrancy. Read-only reentrancy: salah satu yang paling berbahaya dan sering di-miss. Buat exploit proof-of-concept.

**Sab 7 Nov — SABTU — Code4rena: Audit Contest**
Join audit contest aktif di Code4rena. Pilih yang scope-nya DeFi (sesuai yang baru dipelajari). Habiskan sesi ini untuk baca semua dokumentasi dan README protocol yang di-audit secara menyeluruh.

**Min 8 Nov — MINGGU — Review + Audit Progress**
Review progress audit contest. Identifikasi area yang paling suspicious — fungsi yang kompleks, external calls, state changes yang aneh. Buat checklist audit personal yang makin refined.

**Sen 9 Nov — GYM HARI — Audit Deep Session: Manual Review**
Deep session manual review untuk audit contest. Pakai checklist: reentrancy, oracle, access control, integer issues, logic bugs. Target: temukan minimal 1 finding yang layak disubmit hari ini.

**Sel 10 Nov — BELAJAR — Submit Audit Finding**
Polish dan submit semua findings ke Code4rena. Tulis setiap finding dengan format proper: title, severity, description, impact, proof of concept (Foundry test), recommendation. Kualitas > kuantitas.

**Rab 11 Nov — GYM HARI — Compound v3 (Comet) Architecture**
Compound v3 berbeda signifikan dari v2: single borrowable asset per market, supply-side yields. Baca whitepaper Comet. Pahami: mengapa desain ini lebih capital efficient dan lebih aman dari v2?

**Kam 12 Nov — BELAJAR — Curve Finance Deep Dive**
Curve: stableswap invariant (bukan x*y=k). Pahami matematikanya — mengapa lebih efisien untuk stablecoin? CRV tokenomics: vote-escrowed model (veCRV). Ini adalah salah satu tokenomics paling berpengaruh di DeFi.

**Jum 13 Nov — BELAJAR — Tokenomics Analysis Framework**
Buat framework analisis tokenomics sendiri: supply schedule, distribution, utility, value accrual, governance rights, vesting. Aplikasikan ke 3 protocol: UNI, AAVE, CRV. Mana yang paling sustainable?

**Sab 14 Nov — SABTU — Investor Mindset: Protocol Due Diligence**
Buat template due diligence protocol DeFi layaknya investor: TVL trend, revenue vs incentives, code quality (audit riwayat), team, roadmap, competitive moat. Aplikasikan ke 1 protocol baru yang menarik.

**Min 15 Nov — MINGGU — Artikel Mirror.xyz: DeFi Deep Dive**
Tulis artikel ke-2 di Mirror.xyz: pilih 1 topik dari yang dipelajari bulan ini (MEV, oracle security, atau tokenomics). Target 1000-1500 kata. Artikel ini positioning kamu sebagai DeFi specialist.

**Sen 16 Nov — GYM HARI — Sherlock Audit Contest**
Coba Sherlock sebagai alternatif Code4rena — model berbeda (judging pool, fixed prizes). Join 1 contest aktif. Deep session manual review. Fokus area yang menjadi spesialisasi: DeFi + access control.

**Sel 17 Nov — BELAJAR — Oktober Week 3 Review**
Review seluruh Oktober minggu 1-3. Buat scorecard: DeFi protocol yang sudah dipahami, findings yang disubmit, artikel yang dipublish. Identifikasi spesialisasi yang paling menarik dan paling menghasilkan.

**Rab 18 Nov — GYM HARI — EigenLayer & Restaking**
EigenLayer: restaking concept — pakai ETH yang sudah di-stake untuk secure additional services (AVS). Pahami: operator, delegator, slashing conditions. Ini adalah salah satu inovasi terpenting di 2024-2025.

**Kam 19 Nov — BELAJAR — LRT (Liquid Restaking Tokens)**
Liquid restaking: eETH (ether.fi), rsETH (KelpDAO), ezETH (Renzo). Bandingkan mekanisme dan risk profile masing-masing. Pahami: smart contract risk berlapis di LRT vs direct staking.

**Jum 20 Nov — BELAJAR — Intent-based Architecture**
Intent-based transactions: UniswapX, CoW Protocol, SUAVE. Ini adalah paradigma baru — user declare 'apa yang mau dicapai', solver yang cari cara terbaik. Implikasinya ke UX dan MEV protection.

**Sab 21 Nov — SABTU — Validasi Ide Produk: User Research**
Saatnya mulai founder mode. Identifikasi 1 pain point nyata di DeFi/Web3 yang kamu temui selama belajar. Buat 5 pertanyaan interview. Reach out ke 3 orang di komunitas (Discord, Twitter) untuk ngobrol.

**Min 22 Nov — MINGGU — Review + Idea Pipeline**
Review semua ide yang muncul selama Oktober. Buat 'idea pipeline' — list ide dengan: problem, target user, solusi awal, mengapa sekarang. Filter ke 3 ide terkuat. Mana yang paling terasa urgent?

**Sen 23 Nov — GYM HARI — OKTOBER FINAL: Portfolio + Audit**
Final polish semua project portfolio. Cek semua link masih hidup, README up to date. Ikuti 1 audit contest lagi atau lanjut yang ongoing. Hitung income freelance bulan ini — sudah di target?

**Sel 24 Nov — BELAJAR — Oktober Review Total**
Review total Oktober: DeFi knowledge, audit findings, investor mindset, ide produk. Buat rencana November: 60% audit + freelance, 30% validasi produk, 10% investasi knowledge.

**Rab 25 Nov — GYM HARI — Audit Methodology: SAST Tools**
Static analysis advanced: Slither detectors custom, Mythril, Semgrep rules untuk Solidity. Buat custom Slither detector untuk pattern yang sering kamu temukan di audit. Ini differentiation yang kuat.

**Kam 26 Nov — BELAJAR — Audit Methodology: Fuzzing Advanced**
Echidna: property-based fuzzer untuk Solidity. Berbeda dari Foundry fuzz — lebih powerful untuk invariant testing. Install dan jalankan di salah satu project kamu. Bandingkan findings vs Foundry.

**Jum 27 Nov — BELAJAR — Halloeen Special: CTF Blockchain**
Damn Vulnerable DeFi: CTF challenges yang lebih advanced dari Ethernaut. Level 1-5: Unstoppable, Naive Receiver, Truster, Side Entrance, The Rewarder. Ini standard interview di security firm.

**Sab 28 Nov — SABTU — Damn Vulnerable DeFi: Lanjut**
DVDeFi Level 6-10: Selfie, Compromised, Puppet, Puppet v2, Free Rider. Setiap level tulis exploit yang bersih di Foundry dengan penjelasan vulnerability-nya. Ini menjadi portofolio security kamu.

**Min 29 Nov — MINGGU — User Interview: Validasi Produk**
Lakukan 3 user interview yang sudah dijadwalkan Oktober. Record dengan izin. Tanya: apa workflow mereka sekarang, apa yang paling menyakitkan, berapa mereka mau bayar untuk solusi. Dengarkan, jangan pitch.

**Sen 30 Nov — GYM HARI — Audit: Ikuti Contest Baru**
Join audit contest baru di Code4rena atau Sherlock. Pilih yang berkaitan DeFi lending atau DEX — area spesialisasi kamu. Target minggu ini: submit minimal 2 findings valid (medium atau high).


## Des 2026

**Sel 1 Des — BELAJAR — Analisis Interview: Problem Framing**
Analisis hasil 3 user interview. Cari pattern: apa yang 2-3 orang sebut sebagai pain point yang sama? Tulis 'Problem Statement' yang tajam: 'User X kesulitan Y saat melakukan Z, akibatnya A.' Satu kalimat.

**Rab 2 Des — GYM HARI — Competitor Analysis**
Riset: apakah sudah ada yang mencoba solve problem ini? Siapa? Bagaimana mereka monetize? Apa yang kurang dari solusi mereka? Ini bukan alasan untuk berhenti — justru validasi bahwa market ada.

**Kam 3 Des — BELAJAR — DVDeFi: Final Levels + Write-up**
DVDeFi Level 11-15. Tulis write-up komprehensif untuk semua 15 level — ini konten blog yang sangat valuable. Publish di Mirror.xyz atau dev.to sebagai bukti kemampuan security kamu.

**Jum 4 Des — BELAJAR — Prototype Idea: 1-Page Spec**
Tulis 1-page spec untuk ide produk terkuat: problem, solution, target user, differentiator, tech stack yang dibutuhkan, estimasi scope. Bukan business plan — ini untuk validasi teknis apakah feasible.

**Sab 5 Des — SABTU — ZK Proofs: Konsep Dasar**
Zero-knowledge proofs: apa itu, mengapa penting untuk privacy dan scalability. zk-SNARKs vs zk-STARKs — tradeoff. Circom dan Noir sebagai circuit languages. Kamu tidak perlu jadi ZK expert — cukup paham konsep.

**Min 6 Des — MINGGU — Account Abstraction (ERC-4337)**
ERC-4337: account abstraction tanpa consensus change. UserOperation, Bundler, Paymaster, EntryPoint. Implementasi smart wallet sederhana dengan ERC-4337. Ini adalah masa depan UX di Web3.

**Sen 7 Des — GYM HARI — Account Abstraction: Paymaster**
Paymaster pattern: sponsor gas untuk user (gasless tx). Buat Paymaster contract sederhana yang cover gas untuk specific contract calls. Ini sangat valuable untuk produk consumer Web3.

**Sel 8 Des — BELAJAR — Audit Contest: Submit Final**
Wrap up audit contest yang ongoing. Polish semua findings, pastikan setiap PoC berjalan clean. Tulis executive summary untuk setiap finding. Submit dan tunggu judging — ini proses yang membutuhkan kesabaran.

**Rab 9 Des — GYM HARI — Freelance: Naik Rate**
Evaluasi freelance progress: berapa client aktif, berapa total income September-November. Kalau sudah ada 2+ client, saatnya naik rate ke tier berikutnya ($60-80/jam). Buat email ke existing client.

**Kam 10 Des — BELAJAR — Build Prototype Produk**
Mulai build MVP sederhana dari ide yang sudah divalidasi. Bukan full product — cukup core feature yang membuktikan konsep berjalan. Target: sesuatu yang bisa di-demo ke calon user dalam 2-3 jam coding.

**Jum 11 Des — BELAJAR — Demo Produk ke 3 Orang**
Demo MVP ke 3 orang yang sudah diinterview Oktober. Observasi reaksi pertama mereka — apa yang mereka klik duluan, apa yang membingungkan. Catat semua tanpa defensif. Feedback negatif > pujian.

**Sab 12 Des — SABTU — Gas Optimization: Yul/Assembly**
Inline assembly untuk gas optimization ekstrem: custom storage packing, bitwise operations, skip Solidity overhead. Bukan untuk semua kasus — tapi penting dipahami untuk audit (exploit pakai assembly) dan DeFi protocol.

**Min 13 Des — MINGGU — Iterate Produk dari Feedback**
Ambil 3 feedback paling sering muncul dari demo kemarin. Fix atau simplify dalam 1 sesi. Tidak perlu sempurna — cukup cukup baik untuk demo berikutnya. Iterasi cepat > sempurna lambat.

**Sen 14 Des — GYM HARI — Audit: Private Audit Pertama?**
Reach out ke 3 project kecil di Twitter/X atau Discord yang baru deploy atau mau deploy contract. Tawarkan review sederhana — bukan full audit, tapi quick review dengan laporan. Rate: $500-1000 untuk project kecil.

**Sel 15 Des — BELAJAR — DeFi Investasi: Portfolio Strategy**
Buat DeFi investment framework personal: bagaimana evaluate protocol sebelum provide liquidity atau stake. Risk categories: smart contract risk, liquidity risk, regulatory risk. Buat scoring matrix.

**Rab 16 Des — GYM HARI — Mirror.xyz: Artikel Security**
Tulis artikel ke-3 di Mirror.xyz: 'Cara Saya Menemukan Bug di Smart Contract [nama contest]' — share genuine experience dari audit contest. Transparency tentang proses jauh lebih menarik dari tutorial generik.

**Kam 17 Des — BELAJAR — ETHGlobal Hackathon (jika ada)**
Jika ada ETHGlobal online hackathon bulan ini — ikuti. Jika tidak, gunakan weekend ini untuk build feature kedua dari MVP produk. Target: sesuatu yang bisa di-pitch ke seed investor dalam 5 menit.

**Jum 18 Des — BELAJAR — November Week 3 Review**
Review November: audit findings, produk iterasi, freelance income, artikel published. Buat 'anti-portfolio' — apa yang harusnya dikerjakan tapi tidak dikerjakan? Jujur dengan diri sendiri.

**Sab 19 Des — SABTU — Cosmos & Alt-L1 Landscape**
Selain Ethereum: Cosmos SDK (Golang!), Solana (Rust), Sui/Aptos (Move). Kamu tidak perlu master semua — tapi pahami trade-offs: throughput, security model, ecosystem maturity. Golang background berguna di sini.

**Min 20 Des — MINGGU — Cosmos SDK: Hello World**
Karena kamu bisa Golang — install Cosmos SDK, buat module sederhana. Ini bisa jadi differentiation unik: developer yang bisa Solidity DAN Cosmos SDK sangat langka dan dibayar premium.

**Sen 21 Des — GYM HARI — Audit: Review Findings dari Contest**
Cek hasil judging dari audit contest Oktober-November. Pelajari finding orang lain yang diterima — apa yang mereka lihat yang kamu miss? Ini cara paling efektif untuk improve audit skill.

**Sel 22 Des — BELAJAR — Produk: Landing Page + Waitlist**
Buat landing page sederhana untuk produk: problem statement, solution, 1 screenshot/demo GIF, waitlist form. Deploy ke Vercel. Mulai share ke komunitas — bukan pitching, tapi 'gw lagi build ini, feedback?'

**Rab 23 Des — GYM HARI — Review Q4 Progress**
Review seluruh Q4 sejauh ini. Hitung: total audit findings submitted, freelance income Oktober-November, user di waitlist produk, artikel published. Bandingkan dengan target awal — di mana kamu berdiri?

**Kam 24 Des — BELAJAR — NOVEMBER FINAL: Grand Review**
Grand review November. Semua deliverable: audit write-ups di-polish, freelance projects di-dokumenkan, produk landing page live, Cosmos module. Buat satu dokumen 'Achievement Log 2026' — semua yang sudah dicapai.

**Jum 25 Des — BELAJAR — Rencana Desember + 2027**
Plan Desember secara detail. Mulai draft 2027 roadmap: apakah mau focus freelance full, launch produk, atau apply full-time blockchain engineer? Decision ini akan shape seluruh strategi Desember.

**Sab 26 Des — SABTU — 2027 Vision: Apa yang Mau Dicapai?**
Sesi refleksi dan planning. Tulis jawaban jujur: di mana gw mau berada Desember 2027? Mundur dari sana — apa yang harus terjadi di Q1 2027 untuk menuju sana? Ini bukan motivasi — ini reverse engineering.

**Min 27 Des — MINGGU — Full-time Web3 vs Freelance vs Founder**
Research konkret: cek job listings blockchain engineer di web3.career, cryptojobslist. Berapa salary range? Apa requirements-nya? Bandingkan dengan freelance income proyeksi dan founder path risk/reward.

**Sen 28 Des — GYM HARI — Audit: Satu Contest Terakhir**
Join 1 audit contest terakhir di 2026. Ini bukan tentang winning — ini tentang konsistensi dan menjaga skill tetap tajam. Setiap contest yang diikuti = experience + networking dengan auditor lain.

**Sel 29 Des — BELAJAR — Produk: Ambil 5 Feedback Waitlist**
Reach out ke 5 orang di waitlist produk — minta 20 menit call. Pertanyaan fokus: apakah mereka akan pakai jika sudah launch? Apakah mereka akan bayar? Berapa? Ini validation call yang paling penting.

**Rab 30 Des — GYM HARI — Freelance: Year-End Client Review**
Kirim year-end update ke semua client: recap project yang dikerjakan, hasil yang dicapai, availability untuk 2027. Ini bukan basa-basi — ini relationship maintenance yang menghasilkan repeat business.

**Kam 31 Des — BELAJAR — Portfolio: Final Polish Semua**
Final pass semua 5+ project: README up-to-date, semua link hidup, test suite masih passing. Update GitHub profile README dengan achievements 2026. Ini yang dilihat investor dan employer pertama kali.


## Jan 2027

**Jum 1 Jan — BELAJAR — Desember Week 1 Review**
Review minggu pertama Desember. Sudah clear mau kemana 2027? Kalau masih ragu antara 2 opsi — itu normal. Yang penting: buat keputusan dan commit, karena clarity lebih valuable dari pilihan yang sempurna.

**Sab 2 Jan — SABTU — DeFi Investasi: Mulai dengan Kecil**
Jika belum punya DeFi position: mulai dengan jumlah yang sanggup hilang 100%. Provide liquidity di stable pool Curve atau Aave supply — bukan untuk profit, tapi untuk experience langsung sebagai user.

**Min 3 Jan — MINGGU — On-chain Analytics: Dune Dashboard**
Dune Analytics: query on-chain data dengan SQL. Buat dashboard untuk 1 protocol yang kamu sudah pahami (Uniswap atau Aave). Track: TVL, volume, user count. Ini skill yang sangat dicari di Web3.

**Sen 4 Jan — GYM HARI — Audit: Submit Final + Review Results**
Submit semua findings dari contest Desember. Review hasil judging dari semua contest 2026 — hitung total: berapa findings valid, berapa yang diterima, total earnings dari audit contest.

**Sel 5 Jan — BELAJAR — Produk: Keputusan Build or Kill**
Berdasarkan 5 validation call: apakah ada cukup signal untuk lanjut build? Kriteria: minimal 3 dari 5 bilang 'mau bayar' dengan angka spesifik. Kalau tidak — kill it gracefully, pivot, atau park untuk nanti.

**Rab 6 Jan — GYM HARI — Mirror.xyz: Artikel Akhir Tahun**
Tulis artikel refleksi: '9 Bulan Belajar Blockchain dari Nol sebagai SWE — Jujur'. Ceritakan perjalanan nyata: apa yang worked, apa yang tidak, berapa income, apa yang dibangun. Authenticity > perfection.

**Kam 7 Jan — BELAJAR — Networking: Web3 Community**
Hari khusus untuk networking: reply thread Twitter/X yang relevan dengan insight yang nyata, bantu 3 orang di Discord dengan masalah teknis, DM 2 orang yang perjalanannya menarik untuk connecting.

**Jum 8 Jan — BELAJAR — Review: Income Freelance 2026**
Hitung total income freelance September-Desember. Kalikan 12 untuk proyeksi tahunan. Bandingkan dengan gaji SWE sekarang + proyeksi kenaikan. Angka ini yang akan drive keputusan 2027.

**Sab 9 Jan — SABTU — Advanced: EIP Terbaru**
Baca 3 EIP yang paling banyak didiskusikan komunitas saat ini. Pahami: apa yang coba di-solve, mengapa controversial/exciting, dampaknya ke developer jika di-adopt. Ini menunjukkan kamu keep up dengan ekosistem.

**Min 10 Jan — MINGGU — Cosmos SDK: Module Lanjut**
Lanjut Cosmos SDK — build module yang lebih meaningful, misal: simple token transfer atau basic staking module. Dokumentasikan dengan baik. Ini bisa jadi differentiating portfolio item yang sangat jarang dimiliki orang.

**Sen 11 Jan — GYM HARI — Prepare: 2027 Learning Plan**
Draft learning plan 2027 berdasarkan path yang sudah dipilih. Kalau freelance: spesialisasi lebih dalam di security. Kalau founder: belajar fundraising + go-to-market. Kalau full-time: prep technical interview.

**Sel 12 Jan — BELAJAR — GitHub: Year-End Contribution**
Pastikan GitHub contribution graph green sepanjang 2026. Kontribusi ke minimal 1 project open source Web3 yang meaningful — bukan typo fix, tapi real contribution: bugfix, feature kecil, atau test coverage.

**Rab 13 Jan — GYM HARI — Freelance Pipeline 2027**
Buat pipeline freelance untuk Q1 2027: siapa yang mau di-reach out, project apa yang menarik, platform mana yang akan difokuskan. Freelance yang konsisten butuh pipeline yang selalu diisi.

**Kam 14 Jan — BELAJAR — 2026 GRAND FINALE: Semua Deliverable**
Hari paling penting: audit semua yang sudah dibuat selama 2026. Checklist: 5+ project live, artikel di Mirror, audit findings, Dune dashboard, landing page produk, Cosmos module. Screenshot semua untuk dokumentasi.

**Jum 15 Jan — BELAJAR — Syukur + Refleksi + Doa**
Hari istirahat total dari belajar dan coding. Sholat, bersyukur, renungkan perjalanan 9 bulan ini. Hubungi keluarga dan orang-orang yang mendukung. Istirahat yang cukup adalah bagian dari journey, bukan lawan darinya.

**Sab 16 Jan — SABTU — Recap: Semua yang Dipelajari 2026**
Tulis 'Master List' — semua teknologi, konsep, dan skill yang sudah dikuasai tahun ini. Dari blockchain fundamentals sampai ZK proofs, dari ERC-20 sampai Cosmos SDK. Ini akan mengejutkan kamu betapa jauhnya perjalanan.

**Min 17 Jan — MINGGU — Finalisasi: Semua Platform Profile**
Update semua platform: LinkedIn (achievements, skills, portfolio), Twitter/X bio, GitHub README, CryptoJobsList, Contra. Pastikan semuanya consistent dan mencerminkan level skill saat ini, bukan 9 bulan lalu.

**Sen 18 Jan — GYM HARI — 2027: Action Plan Konkret**
Buat action plan Q1 2027 yang sangat konkret: minggu pertama Januari mau ngapain, siapa yang mau di-contact, project apa yang mau distart. Dokumen ini yang dibuka pertama kali di 2 Januari 2027.

**Sel 19 Jan — BELAJAR — Buffer Day: Catch Up**
Hari buffer — selesaikan apapun yang masih tertinggal selama Desember. Tidak ada materi baru. Fokus: polish yang belum sempurna, atau istirahat jika semua sudah done. Fleksibilitas adalah tanda kematangan.

**Rab 20 Jan — GYM HARI — Planning 2027: OKR Personal**
Tulis OKR (Objectives & Key Results) personal untuk 2027. Objective: aspirasi besar. Key Results: angka konkret yang bisa diukur. Contoh — O: Jadi blockchain engineer yang diperhitungkan. KR1: $5000/bulan freelance. KR2: 1 protocol di-audit solo.

**Kam 21 Jan — BELAJAR — 2026 SELESAI — Sampai Jumpa 2027**
Hari terakhir plan resmi 2026. Baca ulang OKR 2027. Pastikan environment sudah siap untuk Januari: tools installed, workspace bersih, jadwal sudah di-set. Kamu sudah siap. Istiqomah adalah kuncinya.


Total hari: 172  Selesai: 2027-01-21
