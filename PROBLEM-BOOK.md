# PROBLEM BOOK: 98 Masalah Nyata dari 3 Project Blockchain

Ini index dari semua catatan "Masalah & Solusi" di devlog tiga project belajar: **defi-staking** (17 entri, 16-19 Sep), **governance-dapp** (39 entri, 20-29 Sep), dan **simple-dex** (42 entri, 30 Sep-9 Okt). Total 98 masalah yang beneran kejadian, bukan hipotesis: compile error, revert, jebakan OZ v5, salah config, sampai godaan nulis angka yang belum di-run. Tiap entri ada link ke devlog aslinya, dan detail lengkapnya (repro, langkah debug, status jujur) selalu di sana.

Cara pakai: pasangkan dengan **STUDY-GUIDE.md**. Loop belajar per unit jalan di STUDY-GUIDE, buku ini jadi daftar isi semua unit. Baca entri di buku ini sebelum nyentuh kodenya biar tahu jebakannya, atau sesudahnya biar bisa bandingkan dengan kejadian asli. Kalau ada yang terasa kurang jelas di sini, buka link devlognya.

---

# Project 1: defi-staking (17 masalah, 16-19 Sep 2026)

Project pertama: staking dApp sederhana. Kontraknya RewardToken (ERC20) + StakingPool yang mengakumulasi reward per detik selama reward window 7 hari, dengan mint-on-claim dan emergencyWithdraw yang forfeit. Frontend-nya dashboard Vite + React 19 + wagmi v3 + RainbowKit v2 untuk stake, unstake, dan claim. Arsitekturnya: read via useReadContract dengan polling ringan, write via runner transaksi sekuensial (approve dulu kalau allowance kurang, lalu aksi utama), dan event Staked/Unstaked/RewardPaid memicu invalidateQueries.

## Tema A: Stack Frontend & Tooling

### 1. Roadmap bilang Next.js, tapi gw pakai Vite
- Masalah: Task roadmap 16 Sep nulis "Build Next.js dashboard", tapi satu-satunya stack frontend yang pernah gw buktikan bisa build adalah Vite + React 19 + wagmi v3 + RainbowKit v2 dari nft-minting-dapp.
- Solusi inti: Pakai Vite yang identik dengan project nft (versi dependency sama persis, struktur config sama) supaya yang dilatih tetap materi task ini, dengan trade-off dicatat: pindah Next.js kalau nanti butuh SSR atau SEO.
- Pelajaran: konsistensi stack antar project latihan lebih bernilai daripada ikut nama framework di roadmap; yang penting deliverable-nya jalan dan pattern-nya nempel.
- Sumber: [devlog 2026-09-16](defi-staking/devlog/2026-09-16-frontend-dashboard.md)

### 2. npm install ditolak: ERESOLVE rainbowkit vs wagmi 3
- Masalah: npm install gagal ERESOLVE karena peer wagmi@"^2.9.0" dari rainbowkit@2.2.11 bentrok dengan wagmi@3.7.7, padahal runtime API-nya kompatibel dan kombinasi ini terbukti jalan di node_modules project nft.
- Solusi inti: .npmrc berisi legacy-peer-deps=true di folder frontend, jadi npm install polos jalan tanpa flag yang gampang lupa (74 packages, 0 vulnerabilities).
- Pelajaran: peer range yang ketinggalan bukan bukti inkompatibilitas runtime; cek dulu kombinasi yang udah proven, terus yang bikin reproducible (.npmrc), bukan flag di command yang gampang lupa.
- Sumber: [devlog 2026-09-16](defi-staking/devlog/2026-09-16-frontend-dashboard.md)

### 3. `define` custom di Vite 8 cuma jalan di build, gak di dev
- Masalah: address dari deployments/31337.json disuntik lewat define di vite.config.ts; ke-bake di npm run build tapi identifier tetap utuh di dev server, jadi npm run dev selalu bilang "address belum dikonfigurasi" walau deployment file ada.
- Solusi inti: ganti mekanisme jadi virtual module plugin (resolveId + load untuk id virtual:local-deployment) yang jalan identik di dev dan build, keduanya terverifikasi.
- Pelajaran: verifikasi injeksi build-time di KEDUA mode (dev dan build), jangan asumsikan satu mekanisme berlaku ke dua-duanya.
- Sumber: [devlog 2026-09-16](defi-staking/devlog/2026-09-16-frontend-dashboard.md)

### 4. Chain `localhost` bawaan wagmi itu 1337, anvil itu 31337
- Masalah: chain localhost dari wagmi/viem didefinisikan dengan id 1337 (warisan hardhat lama), sedangkan anvil default 31337, jadi kalau ikut insting, dashboard target chain yang salah dan kontrak anvil gak pernah kebaca.
- Solusi inti: bikin chain sendiri pakai defineChain({ id: 31337, rpcUrls ke 127.0.0.1:8545 }) di src/config.js, dipakai di getDefaultConfig bareng Sepolia; bonusnya banner salah chain bisa nawarin tombol switch yang benar.
- Pelajaran: nama chain "localhost" gak menjamin id-nya cocok dengan client yang lo jalanin; selalu cocokkan chain id eksplisit.
- Sumber: [devlog 2026-09-16](defi-staking/devlog/2026-09-16-frontend-dashboard.md)

## Tema B: Parsing, Validasi & Error Handling

### 5. `parseUnits` diam-diam nge-bulat, dan custom error viem gak ada di `error.name`
- Masalah: dua temuan dari unit check buatan sendiri: parseUnits("1.123...", 18) gak throw tapi nge-round ke unit terdekat (amount yang dikirim bisa beda tipis dari yang user ketik), dan parser error cuma dapat pesan generik karena custom error StakingPool ke-decode di ContractFunctionRevertedError dalam rantai cause (node.data.errorName), bukan di error.name layer atas.
- Solusi inti: validateAmount ngecek panjang fraksi sebelum parse, dan parseTxError menyusuri cause sampai 10 level mencari data.errorName plus user rejection (code 4001) dan ChainMismatchError; 18 unit check PASS terhadap viem asli pakai encodeErrorResult/decodeErrorResult.
- Pelajaran: helper parsing itu kontrak perilakunya harus diuji: rounding diam-diam dan error yang ke-bungkus berlapis adalah dua tempat bug yang gak kelihatan dari build sukses.
- Sumber: [devlog 2026-09-16](defi-staking/devlog/2026-09-16-frontend-dashboard.md)

## Tema C: Deploy & Script Foundry

### 6. fs_permissions: default Foundry cuma boleh baca
- Masalah: script sukses broadcast 3 transaksi tapi revert di akhir dengan vm.createDir: the path deployments is not allowed to be accessed for write operations, jadi file deployments JSON gak jadi ditulis.
- Solusi inti: tambah fs_permissions = [{ access = "read-write", path = "./" }] di foundry.toml, scope masih project dir bukan full disk.
- Pelajaran: "permission denied" di forge script cek dulu foundry.toml, bukan asumsi masalah OS.
- Sumber: [devlog 2026-09-17](defi-staking/devlog/2026-09-17-deploy-polish.md)

### 7. Script "failed" padahal transaksinya sudah on-chain
- Masalah: setelah revert di bagian penulisan JSON, forge melapor "Error: script failed", tapi ketiga kontrak SUDAH terdeploy di anvil dan bisa di-cast call.
- Solusi inti: pahami bahwa revert di luar blok vm.startBroadcast()/stopBroadcast() cuma membatalkan konteks eksekusi script, bukan transaksi yang sudah terkirim; assert pasca-deploy dilakukan via cast call terpisah, bukan percaya exit code script.
- Pelajaran: exit code script != state chain. Selalu verifikasi state on-chain setelah deploy.
- Sumber: [devlog 2026-09-17](defi-staking/devlog/2026-09-17-deploy-polish.md)

### 8. Metadata deployer salah: msg.sender di script bukan address dari PRIVATE_KEY
- Masalah: field deployer di deployments JSON pertama menunjuk default sender cheatcode (0x1804c8AB...), padahal tx benar-benar dikirim dari address hasil derive PRIVATE_KEY; flag --private-key cuma menentukan tx.from saat broadcast.
- Solusi inti: derive eksplisit address deployer = vm.addr(deployerKey) di run() dan pass sebagai parameter ke _writeDeploymentJson() (plus belajar: variabel lokal run() gak kelihatan di fungsi lain).
- Pelajaran: tx.from != msg.sender di konteks script; kalau butuh identitas deployer yang benar, derive dari key atau vm.envAddress("DEPLOYER").
- Sumber: [devlog 2026-09-17](defi-staking/devlog/2026-09-17-deploy-polish.md)

### 9. console.log tidak otomatis tersedia di script
- Masalah: kompilasi script gagal "Undeclared identifier" di baris console.log(...) padahal forge-std/Script.sol sudah di-import, karena import Solidity tidak bersifat re-export.
- Solusi inti: import {console} from "forge-std/console.sol"; eksplisit di script.
- Pelajaran: di Solidity, import itu file-scoped, bukan transitif.
- Sumber: [devlog 2026-09-17](defi-staking/devlog/2026-09-17-deploy-polish.md)

### 10. Reward window mulai berjalan saat setRewardRate, bukan saat user stake
- Masalah: desain kontrak (SPEC paragraf 4) memulai periode 7 hari tepat di setRewardRate, jadi kalau deploy hari ini tapi user baru stake besok, reward sehari penuh hangus (edge case E10: pool kosong, akumulasi diam).
- Solusi inti: setRewardRate dipanggil terakhir di deploy script (setelah wiring), dan README memberi tahu opsionalnya: untuk demo deploy lalu segera stake, untuk produksi panggil ulang setRewardRate di momen launch; trade-off eksplisit, bukan bug.
- Pelajaran: timing parameter ekonomi (reward window) adalah keputusan operasional, bukan sekadar urutan deployment.
- Sumber: [devlog 2026-09-17](defi-staking/devlog/2026-09-17-deploy-polish.md)

## Tema D: Dokumentasi, Kredibilitas & Konten

### 11. README default Foundry masih tertinggal sejak `forge init`
- Masalah: README masih 100% template default Foundry, termasuk instruksi deploy Counter.s.sol yang tidak pernah ada di project ini; calon recruiter yang buka repo langsung tahu itu project hasil forge init yang belum dirapikan.
- Solusi inti: rewrite penuh dengan struktur: apa ini, arsitektur, trade-off, angka test nyata, cara jalanin, status deploy; semua angka hasil run sendiri.
- Pelajaran: README bukan dokumentasi opsional di akhir; ia bagian dari definisi "selesai" karena mengubah project dari latihan jadi portfolio.
- Sumber: [devlog 2026-09-18](defi-staking/devlog/2026-09-18-readme-github.md)

### 12. Godaan menulis angka yang belum di-run
- Masalah: dari SPEC target coverage 95%, dan sangat menggoda menulis "coverage > 95%" tanpa bukti; sama dengan jumlah test yang berubah-ubah sepanjang 12-15 Sep.
- Solusi inti: jalankan forge test dan forge coverage hari itu juga, tulis hasil persisnya (75 test, 100% di kedua kontrak utama, 86.81% total karena file script/mocks ikut terhitung) plus perintahnya biar bisa direproduksi.
- Pelajaran: untuk portfolio, angka yang bisa direproduksi dengan satu command lebih bernilai daripada angka besar yang tidak bisa diverifikasi.
- Sumber: [devlog 2026-09-18](defi-staking/devlog/2026-09-18-readme-github.md)

### 13. Status deploy yang belum ada (belum ke Sepolia)
- Masalah: recruiter suka link live, tapi deploy Sepolia butuh private key + RPC yang tidak boleh dibuat-buat dan memang belum dieksekusi; address palsu atau "coming soon" yang menggantung dua-duanya buruk.
- Solusi inti: section Deploy Sepolia menyimpan command persis yang dipakai nanti plus satu kalimat status eksplisit ("belum terdeploy, address ditulis setelah deploy sungguhan"), di-update setelah deploy.
- Pelajaran: placeholder yang jujur dan actionable lebih baik daripada konten yang menggantung atau mengarang.
- Sumber: [devlog 2026-09-18](defi-staking/devlog/2026-09-18-readme-github.md)

### 14. Screenshot frontend dan link demo video belum bisa dimasukkan
- Masalah: task roadmap menyebut screenshot frontend dan link demo video, tapi frontend baru selesai 16 Sep dan belum ada address Sepolia untuk deployment yang stabil.
- Solusi inti: demo lokal diarahkan ke frontend/README.md (reproducible via anvil), screenshot + link video dijadwalkan eksplisit setelah deploy Sepolia + Vercel.
- Pelajaran: deliverable yang bergantung ke infrastruktur live sebaiknya dijadwalkan eksplisit, bukan dihanguskan demi "selesai hari ini".
- Sumber: [devlog 2026-09-18](defi-staking/devlog/2026-09-18-readme-github.md)

### 15. Insting pertama adalah menulis thread marketing, padahal isinya belum cukup
- Masalah: draft awal thread cenderung jadi daftar fitur ("staking protocol dengan reentrancy guard dan fuzz testing!") yang semua orang bisa nulis dan gak punya bukti pendukung, padahal audiens build-in-public (dev blockchain) bukan target kata "seamless".
- Solusi inti: tiap tweet disusun ulang jadi format: situasi, error/perilaku nyata, root cause, solusi, pelajaran; sumbernya diambil langsung dari devlog 17 Sep yang mendokumentasikan kejadian asli.
- Pelajaran: devlog yang ditulis jujur otomatis jadi bahan konten; marketing yang jujur adalah efek samping, bukan tujuannya.
- Sumber: [devlog 2026-09-19](defi-staking/devlog/2026-09-19-build-in-public.md)

### 16. Belum ada angka publik yang boleh dipamerkan, jadi mana bagian yang layak disebut?
- Masalah: ada keinginan menyebut "100% coverage" atau "75 test" sebagai bukti kualitas, tapi angka itu tanpa link repo jadi klaim kosong, dan repo sendiri belum di-push.
- Solusi inti: thread tidak menyebut metrik (hanya proses), artikel menyebut angka sekaligus menandai "link menyusul setelah push", profile README menyebut status tanpa angka.
- Pelajaran: konten build-in-public yang belum punya repo publik harus aman terhadap pertanyaan "show me the code".
- Sumber: [devlog 2026-09-19](defi-staking/devlog/2026-09-19-build-in-public.md)

### 17. Tiga platform, tiga format, satu sumber: risiko-nya copy-paste membosankan
- Masalah: thread, artikel, dan profile README mudah berakhir jadi teks yang sama dengan panjang beda, dan audiens yang follow ketiganya langsung kerasan.
- Solusi inti: satu sumber (devlog) dengan tiga transformasi berbeda: thread satu masalah per tweet, artikel keputusan desain sebagai bab, profile README tanpa cerita proses.
- Pelajaran: "write once, publish everywhere" itu jebakan; yang benar "learn once, adapt everywhere".
- Sumber: [devlog 2026-09-19](defi-staking/devlog/2026-09-19-build-in-public.md)

---

# Project 2: governance-dapp (39 masalah, 20-29 Sep 2026)

Project kedua: governance dApp lengkap ala DAO. Kontraknya 4 lapis: GovernanceToken (ERC20Votes) lalu GovernorContract (5 mixin OZ v5.4) lalu TimelockController lalu Treasury, dan timelock jadi satu-satunya executor proposal (dana dan permission sengaja di timelock, bukan di governor). Frontend-nya proposal list + voting UI dengan stack sama seperti project 1 (Vite + React 19 + wagmi), data dari scan event ProposalCreated/VoteCast. Plus subgraph The Graph (code only) buat riwayat proposal dan vote.

## Tema A: Riset & Keputusan Desain

### 18. Pilih clock mode: block number atau timestamp
- Masalah: OZ v5 mendukung ERC-6372 dengan clock bisa block number atau timestamp, dan pilihan ini menentukan semua parameter lain (delay/period dalam block atau detik) serta cara test (vm.roll vs vm.warp).
- Solusi inti: pakai default ERC20Votes (block number) supaya angka roadmap (7200/50400) nyambung ke asumsi 12s/blok, dengan konsekuensi dicatat: timelock tetap timestamp-based, jadi test harus roll DAN warp.
- Pelajaran: dua domain waktu (block buat voting, timestamp buat timelock) itu desain bawaan OZ, bukan kecelakaan.
- Sumber: [devlog 2026-09-20](governance-dapp/devlog/2026-09-20-governance-research.md)

### 19. Threshold 0 atau di atas 0
- Masalah: proposalThreshold > 0 butuh distribusi token yang sehat, dan supply fixed 1M ke deployer berarti threshold apa pun bikin cuma deployer yang bisa propose di awal; demo governance yang cuma bisa dijalankan satu address gak menunjukkan apa-apa.
- Solusi inti: threshold 0, siapa pun boleh propose, dengan risiko spam diakui sebagai known trade-off di SPEC (naikkan lewat setProposalThreshold via proposal untuk produksi).
- Pelajaran: parameter governance itu trade-off UX vs keamanan, dan nilai "aman" untuk mainnet sering gak cocok buat demo.
- Sumber: [devlog 2026-09-20](governance-dapp/devlog/2026-09-20-governance-research.md)

### 20. Siapa yang pegang dana: governor atau timelock
- Masalah: desain naif naruh ETH di governor, padahal GovernorTimelockControl eksplisit mengarahkan agar dana dan permission ada di TimelockController; kalau dana di governor, eksekusi lewat Governor.execute() langsung dan exit window hilang.
- Solusi inti: bikin Treasury.sol terpisah yang execute()-nya di-guard msg.sender == timelock (immutable), dan timelock jadi satu-satunya executor proposal.
- Pelajaran: arsitektur governance yang benar itu 4 lapis (token lalu governor lalu timelock lalu target), bukan 3.
- Sumber: [devlog 2026-09-20](governance-dapp/devlog/2026-09-20-governance-research.md)

### 21. Quorum dihitung dari supply mana
- Masalah: GovernorVotesQuorumFraction.quorum(timepoint) menghitung dari getPastTotalSupply(timepoint) yaitu supply historis di snapshot, bukan supply sekarang; salah paham di sini bikin proposal "gak lolos quorum padahal supplynya cukup" atau sebaliknya.
- Solusi inti: kontrak tanpa burn/mint setelah deploy jadi past supply konstan (quorum 40.000 GT), tapi test tetap menulis governor.quorum(snapshot) dengan snapshot block biar semantiknya kebaca.
- Pelajaran: parameter yang kelihatan "4% dari supply" itu sebenarnya fungsi dari timepoint. Baca source quorum() sebelum nulis angka di spec.
- Sumber: [devlog 2026-09-21](governance-dapp/devlog/2026-09-21-spec-architecture.md)

### 22. Delay/period test vs produksi, satu konfigurasi atau dua
- Masalah: test dengan angka produksi (7200 + 50400 block) butuh 57.600 vm.roll dan suite jadi lambat serta rapuh; kalau kontrak test pakai angka kecil, ada risiko kontrak kecil itu yang ke-deploy (lupa ganti).
- Solusi inti: satu kontrak yang sama, parameter masuk lewat constructor; test hardcode nilai kecil di konstanta test, deploy script hardcode nilai roadmap, plus test_GovernorParameters yang assert parameternya.
- Pelajaran: parameter = data, bukan kode. Semua angka governance masuk constructor, biar test dan produksi beda data doang.
- Sumber: [devlog 2026-09-21](governance-dapp/devlog/2026-09-21-spec-architecture.md)

### 23. Ukuran kontrak Governor sudah kelihatan jadi risiko sejak spec
- Masalah: governor OZ dengan 5 mixin terkenal besar dan berpotensi kena EIP-170 (24.576 bytes runtime) terutama tanpa via-ir; kalau baru sadar pas deploy, setting compiler jadi keputusan terburu-buru.
- Solusi inti: dicatat di SPEC section keamanan bahwa konfigurasi compiler (via-ir, optimizer_runs) bagian dari deliverable, dan verifikasi ukuran bytecode jadi gate deploy.
- Pelajaran: buat kontrak besar, ukuran bytecode itu persyaratan teknis di level spec, bukan detail opsional. (Ternyata di hari deploy benar-benar meledak, lihat entri 50.)
- Sumber: [devlog 2026-09-21](governance-dapp/devlog/2026-09-21-spec-architecture.md)

## Tema B: Kontrak Token & Governor (OZ v5)

### 24. OZ v5 wajib override `_update`, bukan `_beforeTokenTransfer`
- Masalah: semua materi lama (v4) bilang override _beforeTokenTransfer, tapi hook itu udah gak ada di OZ v5.4; ERC20Votes v5.4 meng-override _update(address,address,uint256) dan minta turunannya menggabungkan versi ERC20 + ERC20Votes, jadi first build langsung gagal kalau gak ditulis.
- Solusi inti: tulis persis seperti panduan OZ v5: function _update(...) internal override(ERC20, ERC20Votes) yang manggil super._update(...).
- Pelajaran: migrasi major version OZ itu breaking. Selalu buka source yang terinstall di lib/, jangan karang dari ingatan versi 4.
- Sumber: [devlog 2026-09-22](governance-dapp/devlog/2026-09-22-governance-token.md)

### 25. `nonces` bentrok antara ERC20Permit dan Votes
- Masalah: ERC20Permit dan Votes dua-duanya mewarisi Nonces, jadi nonces(address) terdefinisi dua kali di DAG dan compiler minta resolusi eksplisit di kontrak final.
- Solusi inti: override nonces(address owner) dengan override(ERC20Permit, Nonces) yang manggil super.nonces(owner), plus import Nonces eksplisit karena dia gak jadi base langsung di daftar is.
- Pelajaran: diamond inheritance di Solidity itu mekanis dan bisa ditebak, tapi compiler yang akhirnya menentukan. Baca error-nya, dia menunjuk kontrak yang bentrok satu per satu.
- Sumber: [devlog 2026-09-22](governance-dapp/devlog/2026-09-22-governance-token.md)

### 26. Voting power "hancur" saat transfer ke penerima yang belum delegate
- Masalah: transfer ke penerima yang belum delegate bikin voting power penerima 0 sampai dia delegate(); power yang keluar dari pengirim "menghilang" sementara, dan test awal ditulis dengan asumsi transfer langsung memindahkan power.
- Solusi inti: test dibalik jadi dokumentasi perilaku: assert balance penerima 60 GT tapi getVotes 0, lalu setelah delegate votes = 60 (aktif sejak block delegate, bukan retroaktif).
- Pelajaran: ini PR banget buat UX frontend: user yang nerima token tanpa delegate gak bisa vote, dan delegate setelahnya gak mengembalikan riwayat proposal yang sudah lewat.
- Sumber: [devlog 2026-09-22](governance-dapp/devlog/2026-09-22-governance-token.md)

### 27. Lookup checkpoint di block sekarang itu revert
- Masalah: token.getPastVotes(alice, block.number) revert ERC5805FutureLookup karena "past" ternyata strictly < clock(), bukan termasuk block sekarang; EVM gak bisa membaca state block yang belum selesai.
- Solusi inti: test_FutureLookupReverts dan test_FutureTotalSupplyLookupReverts ditulis eksplisit expect revert, dan semua assert historis pakai target block yang sudah digali (vm.roll dulu, baru lookup).
- Pelajaran: "past" di ERC20Votes itu strictly < clock(). Governor sendiri mengambil bobot di proposalSnapshot yang minimal 1 block di masa depan saat propose.
- Sumber: [devlog 2026-09-22](governance-dapp/devlog/2026-09-22-governance-token.md)

### 28. Base constructor `GovernorVotes` gak ke-import, build pertama gagal
- Masalah: GovernorVotes(_votes) di daftar initializer error "Identifier not found" padahal GovernorVotesQuorumFraction jelas mewarisinya; initializer base butuh identifier yang in-scope di file kontrak.
- Solusi inti: tambah import {GovernorVotes} from "openzeppelin-contracts/governance/extensions/GovernorVotes.sol".
- Pelajaran: daftar import = daftar semua base yang di-initialize secara eksplisit, bukan cuma yang ada di is.
- Sumber: [devlog 2026-09-23](governance-dapp/devlog/2026-09-23-governor-contract.md)

### 29. Override matrix v5.4: `proposalThreshold` wajib, `votingDelay` gak
- Masalah: override lengkap ala wizard v5 tanpa votingDelay/votingPeriod/quorum terasa asimetris dan bikin penasaran; eksperimen compile menunjukkan proposalThreshold wajib re-override karena core punya DEFAULT BODY (return 0) jadi ada dua implementasi concrete di DAG (error 6480), sedangkan votingDelay/votingPeriod/quorum di core abstract murni tanpa body.
- Solusi inti: matrix final yang compile bersih: state, proposalNeedsQueuing, proposalThreshold, _queueOperations, _executeOperations, _cancel, _executor.
- Pelajaran: abstrak vs concrete di base menentukan kebutuhan override. Kata "ikuti contoh resmi" itu benar, tapi paham KENAPA matrix-nya segitu bikin gak goyah saat upgrade OZ.
- Sumber: [devlog 2026-09-23](governance-dapp/devlog/2026-09-23-governor-contract.md)

### 30. Access `VoteType` harus via kontrak yang mendeclare, bukan kontrak turunan
- Masalah: GovernorContract.VoteType.For di test error "Member VoteType not found" karena enum dideclare di GovernorCountingSimple dan Solidity gak mengizinkan akses member enum via kelas turunan.
- Solusi inti: pakai GovernorCountingSimple.VoteType.For plus import extension-nya di file test.
- Pelajaran: member enum diakses via kontrak yang secara literal mendeclare-nya; kecil tapi makan waktu kalau gak nyangka, dan pattern yang sama menimpa IERC20.transfer di calldata fuzz (abi.encodeCall(IERC20.transfer, ...)).
- Sumber: [devlog 2026-09-23](governance-dapp/devlog/2026-09-23-governor-contract.md)

### 31. Non-delegated voter: weight 0 tanpa revert
- Masalah: ekspektasi awal bahwa vote oleh holder tanpa delegation itu revert ternyata salah: _castVote sukses dengan weight 0 (bobot diambil dari checkpoint snapshot yang memang 0), karena core Governor gak punya aturan "harus punya bobot untuk vote".
- Solusi inti: test diubah jadi test_NonDelegatedHolderVotesWithZeroWeight: castVote oleh holder 5.000 GT (gak delegate) mengembalikan 0 dan tally gak berubah.
- Pelajaran: verifikasi klaim di source dulu sebelum menulis ekspektasi test. Ketahanan terhadap kegagalan gak sama dengan menolak input.
- Sumber: [devlog 2026-09-23](governance-dapp/devlog/2026-09-23-governor-contract.md)

## Tema C: Timelock & Test Full Flow

### 32. Chicken-and-egg: timelock butuh governor, governor butuh timelock
- Masalah: GovernorTimelockControl minta address timelock di constructor, tapi grant PROPOSER_ROLE ke governor cuma bisa sesudah governor ada, dan yang bisa grant harus admin timelock; dua kontrak saling refer.
- Solusi inti: deploy timelock dengan admin = deployer (proposers/executors kosong), deploy governor, grant roles, terakhir renounceRole(DEFAULT_ADMIN_ROLE); test_TimelockRoleWiring assert deployer gak punya admin lagi dan timelock self-administered.
- Pelajaran: urutan deploy itu bagian dari desain keamanan. Admin sementara itu jembatan yang HARUS dibongkar di transaksi yang sama dengan wiring.
- Sumber: [devlog 2026-09-24](governance-dapp/devlog/2026-09-24-timelock-integration.md)

### 33. `CANCELER_ROLE` double L: compile error yang memalukan tapi berguna
- Masalah: timelock.CANCELER_ROLE() error "Member not found" karena OZ v5.4 mendeclare keccak256("CANCELLER_ROLE") dengan double L (penulisan Inggris "canceller"), sementara brief dan ingatan pakai satu L.
- Solusi inti: grep source, ganti semua jadi CANCELLER_ROLE di test dan deploy script, plus catat sebagai komentar peringatan di deploy script.
- Pelajaran: konstanta role itu magic bytes. Satu huruf salah = error compile (untungnya), bukan bug runtime. Kalau mau aman bandingkan dengan cast keccak "CANCELLER_ROLE".
- Sumber: [devlog 2026-09-24](governance-dapp/devlog/2026-09-24-timelock-integration.md)

### 34. forge 1.5.1: `expectRevert` dengan selector telanjang gak match error ber-args
- Masalah: vm.expectRevert(IGovernor.GovernorUnexpectedProposalState.selector) gagal padahal revert-nya jelas error itu, karena forge 1.5.1 membandingkan revert data secara penuh dan error ber-parameter menghasilkan revert data > 4 bytes (raw bytes 0x31b75e4d... dibandingkan dengan expectation 4 byte telanjang).
- Solusi inti: semua expectRevert untuk error ber-args pakai encoding penuh abi.encodeWithSelector(...), dan untuk TimelockUnexpectedOperationState dibuat helper yang menghitung operationId persis seperti _timelockSalt di OZ.
- Pelajaran: upgrade tooling bikin pattern lama basi. Ketahuan dari error message forge yang nampilin decoder dua sisi; kalau ragu, tangkap raw bytes.
- Sumber: [devlog 2026-09-24](governance-dapp/devlog/2026-09-24-timelock-integration.md)

### 35. Bitmap sentinel `bytes32(0)` di duplicate propose
- Masalah: revert duplicate propose ternyata membawa bytes32(0) sebagai argumen ketiga (sentinel), bukan bitmap Succeeded seperti di jalur _validateStateBitmap; test full-encoding tetap gagal dengan actual 0x00...00 vs expected bitmap.
- Solusi inti: encode dengan bytes32(0) untuk duplicate propose, dan bitmap asli untuk queue/vote.
- Pelajaran: dua error yang sama bisa punya argumen ketiga beda tergantung jalur revert-nya. Baca call site-nya, jangan asumsikan dari nama error.
- Sumber: [devlog 2026-09-24](governance-dapp/devlog/2026-09-24-timelock-integration.md)

### 36. `isOperationPending` di v5.4 mencakup state Ready
- Masalah: setelah warp melewati minDelay, ada worry governor.state() bakal balik Canceled (cabang else di GovernorTimelockControl.state) dan execute bakal revert.
- Solusi inti: cek source: di v5.4 isOperationPending = Waiting || Ready, jadi operasi yang siap dieksekusi tetap dianggap pending, governor state tetap Queued, dan execute lolos validasi tanpa trik apa-apa.
- Pelajaran: cabang else yang tampak berbahaya di source itu sering gak terjangkau karena guard di atasnya lebih longgar dari dugaan. Selalu cek definisi fungsi yang dipanggil, bukan nama fungsinya.
- Sumber: [devlog 2026-09-24](governance-dapp/devlog/2026-09-24-timelock-integration.md)

## Tema D: Frontend & Event Log

### 37. `ProposalCreated` di OZ 5.4 punya field `signatures` yang gak disebut brief
- Masalah: ABI event ditulis dengan 8 field sesuai brief, tapi OZ 5.4.0 yang ter-install masih mempertahankan field signatures di antara values dan calldatas jadi signature event-nya 9 field; topic hash-nya beda dan satu field salah bikin filter log balikin nol hasil, tanpa error.
- Solusi inti: semua ABI frontend ditulis dengan sumber kebenaran file hasil compile (out/), diverifikasi via cast keccak dua signature (9 field = 0x7d84a626..., 8 field = 0x95f03e43...).
- Pelajaran: ABI hand-written harus diverifikasi ke artifact compile, apalagi buat event yang field-nya beda antar versi OZ.
- Sumber: [devlog 2026-09-25](governance-dapp/devlog/2026-09-25-proposal-list.md)

### 38. viem `getLogs` diam-diam mengabaikan `abi` + `eventName`
- Masalah: scan pertama balikin 6 log padahal di-chain cuma ada 1 ProposalCreated, decode hasilnya args kosong, dan gak ada satu pun error di console; di viem 2.57.3 fungsi inti getLogs cuma nerima event/events (ABI item), kombinasi abi + eventName gak ada di signature-nya dan diabaikan tanpa warning, jadi request terkirim tanpa filter topic dan balikin semua log di range.
- Solusi inti: resolve event dulu sekali di module scope via getAbiItem({ abi, name: "ProposalCreated" }), lalu pass sebagai event: ke getLogs (plus args buat filter VoteCast per proposal).
- Pelajaran: tanpa type checking, kesalahan bentuk API bisa nyaris invisible. Build pass bukan bukti jalur data jalan; smoke test runtime yang nangkep ini.
- Sumber: [devlog 2026-09-25](governance-dapp/devlog/2026-09-25-proposal-list.md)

### 39. Deskripsi proposal gak ada di view call, cuma di event log
- Masalah: proposal id itu hash dari (targets, values, calldatas, descriptionHash) dan deskripsi plain-nya cuma lewat sebagai data event, karena kontrak sengaja gak nyimpen deskripsi di storage (hemat gas); roadmap minta deskripsi tampil di list.
- Solusi inti: scan event jadi sumber kebenaran, hasilnya di-cache localStorage keyed chainId + governor dengan record per proposalId, dan form create proposal langsung nulis record dari receipt (parseEventLogs) biar proposal sendiri tampil segera; solusi penuhnya subgraph.
- Pelajaran: localStorage di sini cache, bukan database: data sumbernya tetap event log, dan cache-nya di-replace tiap rescan. Pola ini fragile (range scan lambat, reorg, pruning log oleh RPC).
- Sumber: [devlog 2026-09-25](governance-dapp/devlog/2026-09-25-proposal-list.md)

### 40. `quorum(snapshot)` dan `getPastVotes(snapshot)` revert buat proposal Pending
- Masalah: progress bar quorum manggil quorum(voteStart) per proposal, dan buat proposal Pending call itu revert ERC5805FutureLookup karena getPastTotalSupply gak boleh dilihat di timepoint masa depan.
- Solusi inti: baca block head dulu, panggil quorum dan getPastVotes hanya kalau snapshot < head; UI Pending nampilin "not measurable yet" dengan penjelasan singkat, bukan angka palsu.
- Pelajaran: read on-chain bisa revert bukan karena bug tapi karena semantik waktu (ERC-6372). Gate read berdasarkan urutan blok, jangan telen errornya.
- Sumber: [devlog 2026-09-25](governance-dapp/devlog/2026-09-25-proposal-list.md)

### 41. Voting power itu snapshot, bukan saldo sekarang (jebakan klasik ERC20Votes)
- Masalah: versi naif "voting power user" manggil token.getVotes(user), padahal GovernorVotes._getVotes menghitung weight PADA SNAPSHOT via token.getPastVotes(account, timepoint); delegasi setelah snapshot gak mengubah weight proposal yang lagi jalan.
- Solusi inti: UI menampilkan getPastVotes(user, snapshot) sebagai "the number the governor counts", dengan tiga sub-kasus voting power nol dibedakan di teks disable (gak punya GT, belum delegate, delegate setelah snapshot) dan hint bahwa checkpoint baru berlaku buat proposal berikutnya.
- Pelajaran: smoke test membuktikan bedanya: getPastVotes di snapshot = 1M GT pas, dan itu yang jadi forVotes di tally.
- Sumber: [devlog 2026-09-26](governance-dapp/devlog/2026-09-26-voting-ui.md)

### 42. State tetap Active walau quorum sudah tercapai
- Masalah: setelah vote For 1M GT (quorum 40k terlampaui jauh), state() masih balikin Active dan nyaris dianggap bug; keputusan Defeated/Succeeded di Governor.state() baru diambil kalau deadline < clock().
- Solusi inti: smoke test mine 50401 blok setelah vote baru lanjut; UI sudah benar dari awal (tombol vote cuma aktif saat Active), ini soal ekspektasi user bahwa proposal bisa "sudah pasti menang" tapi masih Active sampai deadline.
- Pelajaran: state machine OZ itu timing-based, bukan outcome-based. Jangan uji state outcome sebelum waktunya lewat.
- Sumber: [devlog 2026-09-26](governance-dapp/devlog/2026-09-26-voting-ui.md)

### 43. `TimelockUnexpectedOperationState` di OZ 5.4 parameternya bytes32 bitmap, bukan uint8
- Masalah: uji execute sebelum eta lewat, tx revert tapi error gak ke-decode ABI gw dan balikin raw selector 0x5ead8eb5; ABI error ditulis dari ingatan versi lama OZ (bytes32,uint8) padahal di OZ 5.4 parameternya bytes32 expectedStates (bitmap).
- Solusi inti: verifikasi cast keccak "TimelockUnexpectedOperationState(bytes32,bytes32)" = 0x5ead8eb5 cocok, lalu perbaiki ABI error di src/abi.js (error timelock harus ada di ABI UI karena subcall timelock di governor.execute gak di-wrap, revert data-nya nge-bubble mentah ke wallet).
- Pelajaran: error entry di ABI itu decoder, bukan formalitas. Selector gak cocok = pesan error mentah buat user. Sumber kebenaran itu source/artifact, bukan ingatan.
- Sumber: [devlog 2026-09-26](governance-dapp/devlog/2026-09-26-voting-ui.md)

### 44. Queue/execute/cancel gak bisa dipanggil dari proposal id doang
- Masalah: tombol Queue butuh queue(targets, values, calldatas, descriptionHash), tapi yang ada di halaman detail cuma id; governor nge-hash ulang payload buat derive id dan gak ada cara balik dari id ke payload.
- Solusi inti: ambil payload dari cache scan dengan descriptionHash = keccak256(toBytes(description)), dan smoke test membuktikan hasil hashProposal on-chain persis sama dengan id dari event; kalau payload gak ada di cache, tombol diganti penjelasan "rescan or use the subgraph" alih-alih tombol yang pasti gagal.
- Pelajaran: metadata dari event itu bagian dari state UI yang wajib ada, bukan sekadar keterangan. Subgraph jadi makin jelas kenapa dibutuhkan.
- Sumber: [devlog 2026-09-26](governance-dapp/devlog/2026-09-26-voting-ui.md)

### 45. Race read-setelah-write di smoke test (dan kenapa UI gak kena)
- Masalah: begitu tx queue sukses, re-read state() langsung masih balikin state lama (Succeeded) padahal beberapa detik kemudian on-chain udah Queued; script linear nulis dan baca nyaris di tick yang sama jadi read-nya bisa mendarat di blok sebelumnya.
- Solusi inti: re-read dengan retry pendek sampai state settle di smoke test; UI gak punya pola ini karena update lewat TanStack Query yang di-refetch oleh event watcher dan polling.
- Pelajaran: jangan bandingkan script uji linear dengan UI event-driven; yang perlu dijamin UI adalah refetch-nya terpicu, bukan kecepatan satu kali baca.
- Sumber: [devlog 2026-09-26](governance-dapp/devlog/2026-09-26-voting-ui.md)

## Tema E: Subgraph & Indexing

### 46. Kenapa governance butuh indexer: event history gak bisa dibaca dari state
- Masalah: state kontrak cuma menyimpan tally + flag (executed, canceled); daftar proposalId, siapa vote apa, dan alasan vote cuma ada di event, dan eth_getLogs manual berarti handle range, chunking, dan reorder sendiri.
- Solusi inti: subgraph dengan 5 event (ProposalCreated, VoteCast, ProposalQueued, ProposalExecuted, ProposalCanceled): Proposal dibuat di ProposalCreated, tally diupdate di VoteCast, lifecycle diupdate di Queued/Executed/Canceled, dan frontend cukup GraphQL satu query.
- Pelajaran: kontrak yang baik meng-emit event yang cukup buat rekonstruksi semuanya. Semua data yang diindex di sini datang dari event bawaan OZ, tanpa nambah event custom.
- Sumber: [devlog 2026-09-27](governance-dapp/devlog/2026-09-27-subgraph-the-graph.md)

### 47. Status proposal di subgraph itu event-driven, Active/Defeated gak punya event
- Masalah: frontend butuh badge Active/Defeated, tapi on-chain gak ada event yang menyatakan keduanya; subgraph gak bisa tahu proposal "kalah" tanpa ngecall kontrak karena penilaian itu hasil perhitungan state saat dibaca.
- Solusi inti: field status di schema cuma ngikutin yang punya event (Pending/Queued/Executed/Canceled), dan README subgraph nyatakan eksplisit bahwa Active/Defeated dihitung frontend dari voteEnd + tallies (atau governor.state()); gak ngefake status dengan timestamp guessing.
- Pelajaran: jangan biarkan indexer mengarang state yang gak didukung sumbernya. Skema yang jujur lebih murah daripada skema yang menggoda bug.
- Sumber: [devlog 2026-09-27](governance-dapp/devlog/2026-09-27-subgraph-the-graph.md)

### 48. Signature event OZ v5.4: cuma `voter` di VoteCast yang indexed
- Masalah: contoh subgraph yang beredar umumnya menulis signature ala OZ lama; kalau signature di subgraph.yaml gak persis sama dengan ABI, graph codegen/deploy menolak, dan di v5.4 cuma voter di VoteCast yang indexed (ProposalCreated, ProposalQueued, ProposalExecuted, ProposalCanceled gak punya parameter indexed sama sekali).
- Solusi inti: signature di manifest ditulis persis dari ABI, diverifikasi dari forge inspect GovernorContract abi --json plus source IGovernor.sol.
- Pelajaran: generate ABI dari build artifacts (forge inspect ... --json), jangan salin dari blog. forge inspect di 1.5.1 default-nya ngeprint tabel cantik; tanpa --json output-nya bukan JSON.
- Sumber: [devlog 2026-09-27](governance-dapp/devlog/2026-09-27-subgraph-the-graph.md)

### 49. Versi graph-cli/graph-ts: pakai angka real, bukan asumsi
- Masalah: package.json subgraph butuh versi yang masuk akal, tapi npm install gak dijalankan (butuh akun Studio dan scope-nya code only), jadi nulis ^latest atau versi karangan gak bisa dipertanggungjawabkan.
- Solusi inti: cek langsung npm view: graph-cli 0.98.1 dan graph-ts 0.38.2 masuk package.json, dengan catatan di README buat cek ulang saat install.
- Pelajaran: angka di file yang gak dijalankan pun harus verifiable. Itu bedanya placeholder jujur dan data karangan.
- Sumber: [devlog 2026-09-27](governance-dapp/devlog/2026-09-27-subgraph-the-graph.md)

## Tema F: Deploy & Compiler

### 50. GOVERNOR GAGAL DEPLOY: EIP-170, 28857 bytes > 24576 (temuan paling penting minggu ini)
- Masalah: broadcast pertama bilang "Script ran successfully" dengan address cantik, tapi cast code <governor> mengembalikan 0x; runtime Governor 28.857 bytes melebihi limit EIP-170 (24.576) dan forge script menampilkan sukses karena simulasi (eth_call) gak menegakkan limit itu, jadi kegagalan baru muncul saat broadcast nyata dan transaksi setelahnya (grant, treasury, delegate) ikut gagal karena nonce bolong.
- Solusi inti: iterasi compiler: via_ir = true saja malah bikin runtime BESAR (31.245 bytes, via-ir + optimizer 200 runs lebih agresif di gas bukan size), tambah optimizer_runs = 1000 menghasilkan 16.405 bytes; diverifikasi cast codesize = 16404 setelah deploy ulang.
- Pelajaran: cek ukuran bytecode sebagai bagian dari CI (forge inspect abi gak cukup; pakai deployedBytecode dari artifact atau cast codesize setelah deploy lokal). Dan jangan percaya "Script ran successfully" tanpa cek kode kontrak di chain.
- Sumber: [devlog 2026-09-28](governance-dapp/devlog/2026-09-28-deploy-polish.md)

### 51. via-ir "memutar balik" nilai turunan `block.number` di test: `ERC5805FutureLookup(2,2)` lalu `(4,4)`
- Masalah: setelah ganti compiler pipeline, test_PastVotesAtHistoricBlocks gagal dengan lookup checkpoint masa depan: VM::roll(2) dipanggil dua kali dan setelah refactor, vm.roll(transferBlock + 1) dengan transferBlock = 2 jadi roll(4); via-ir memperlakukan block.* sebagai invariant dalam satu transaksi, jadi ekspresi yang di-root ke block.number di-re-derive di titik PEMAKAIAN, bukan dievaluasi di titik assignment (cheatcode vm.roll mutasi konteks yang tidak diketahui optimizer).
- Solusi inti: test historis pakai target block ABSOLUT (roll(2), roll(3)) dengan assert awal block.number == 1 sebagai guard, dan nilai yang direcord jadi konstanta lokal literal; test lain yang roll-nya sekali per ekspresi gak terganggu (33/33 hijau).
- Pelajaran: ganti pipeline compiler itu bukan ganti kecepatan doang, tapi ganti asumsi yang boleh dilakukan optimizer. Test yang bergantung pada cheatcode mutasi harus gak punya nilai turunan block.* yang dipakai ulang.
- Sumber: [devlog 2026-09-28](governance-dapp/devlog/2026-09-28-deploy-polish.md)

### 52. Deployer HARUS di-derive dari PRIVATE_KEY, bukan msg.sender
- Masalah: metadata deployer di JSON awalnya pakai msg.sender, yang di konteks script adalah default sender cheatcode, BUKAN address dari PRIVATE_KEY yang dibroadcast; forge menjalankan script dengan sender virtual.
- Solusi inti: address deployer = vm.addr(vm.envUint("PRIVATE_KEY")) dipakai untuk metadata JSON dan renounce timelock, pola persis sama dengan DeployStaking.s.sol di project 1.
- Pelajaran: di script, msg.sender itu kecuali kasus; derive dari key itu norma. Sama-sama belajar paham saat Project 1, sekarang kelihatan kenapa.
- Sumber: [devlog 2026-09-28](governance-dapp/devlog/2026-09-28-deploy-polish.md)

### 53. Verifikasi penuh, bukan cuma "script sukses"
- Masalah: sukses broadcast itu bukan bukti wiring benar; banyak titik gagal senyap: role salah target, admin lupa renounce, treasury kosong, supply salah, delegate lupa.
- Solusi inti: sanity assert di akhir script (PROPOSER/CANCELER di governor, admin sudah renounce, saldo treasury, supply) plus verifikasi manual via cast setelah broadcast: codesize, hasRole, getMinDelay, votingDelay/votingPeriod, quorumNumerator, getVotes(deployer), dan deployments JSON.
- Pelajaran: "deploy sukses" itu properti tx; "deployment benar" itu properti state. Verifikasi yang kedua.
- Sumber: [devlog 2026-09-28](governance-dapp/devlog/2026-09-28-deploy-polish.md)

## Tema G: README & Publish

### 54. README default Foundry nyaris keulang lagi
- Masalah: pola yang sama dengan Project 1 nyaris kejadian lagi: forge init meninggalkan README template, dan tumpukan kerja teknis (kontrak, test, wiring) lebih menarik daripada dokumentasi; template default gak pernah kerasa seperti "utang".
- Solusi inti: kali ini README jadi bagian dari checklist tugas harian (28-29 Sep), bukan afterthought; DoD di SPEC juga sudah mencantumkannya sejak SPEC ditulis.
- Pelajaran: utang dokumentasi harus masuk DoD di awal project, bukan ditagih di akhir, kalau tidak dia selalu kalah prioritas.
- Sumber: [devlog 2026-09-29](governance-dapp/devlog/2026-09-29-readme-publish.md)

### 55. Menjelaskan parameter governance tanpa terlihat seperti angka arbitrer
- Masalah: "quorum 4%, voting delay 1 hari, voting period 1 minggu" tanpa penjelasan bakal dibaca pembaca sebagai angka acak, padahal itu keputusan desain paling penting di sistem governance dengan trade-off konkret (quorum rendah = mudah di-takeover, tinggi = jalan di tempat; delay mem-buffers dari proposal serangan yang di-farm satu transaksi).
- Solusi inti: di README tiap parameter dipasangkan dengan alasan + referensi praktik protocol besar (angka default ala Compound Governor Bravo) plus section trade-off singkat.
- Pelajaran: parameter governance itu kebijakan, bukan konstanta teknis; dokumentasinya harus membahas kenapa, bukan cuma apa.
- Sumber: [devlog 2026-09-29](governance-dapp/devlog/2026-09-29-readme-publish.md)

### 56. Publish portfolio item kedua tapi belum ada tempat menunjuk
- Masalah: task menyebut publish, tapi dengan pola yang sama dengan Project 1: konten yang mengeklaim kualitas tanpa link repo itu lemah, dan repo belum di-push; urutan yang benar repo public dulu, baru konten.
- Solusi inti: README selesai jadi bahan publish, publish sendiri jadi langkah manual setelah push GitHub (digabung dengan konten Project 1 supaya satu gelombang).
- Pelajaran: portfolio itu rantai: repo, lalu konten. Gak bisa dilompati.
- Sumber: [devlog 2026-09-29](governance-dapp/devlog/2026-09-29-readme-publish.md)

---

# Project 3: simple-dex (42 masalah, 30 Sep-9 Okt 2026)

Project ketiga: AMM ala Uniswap v2 dibangun dari nol. Kontraknya AMMLibrary (pure math x*y=k dengan fee 0.3% on-input) + DexPair (pool sekaligus LP token ERC-20 "SDX-LP", API explicit-amount approve + call, CEI, fee-on-transfer ditolak aktif). Frontend-nya swap UI + liquidity UI dengan mirror math BigInt JS yang identik dengan pembagian EVM. Arsitektur pengujian: vektor eksak dari python sebagai oracle independen, fuzz domain-bounded, dan invariant suite dengan handler + ghost variables.

## Tema A: Riset & Math AMM

### 57. Fee dipotong di sisi mana: input atau output
- Masalah: waktu menurunkan rumus berfee, bingung fee 0.3% masuk sebagai faktor di mana; menaruhnya di output bikin rumus dua langkah dan pembulatannya rawan bocor ke trader.
- Solusi inti: ikut konvensi v2, fee dipotong dari INPUT: yang ikut persamaan produk cuma dx*997/1000 tapi pool menerima dx penuh, sehingga k tumbuh tiap swap dan itu persis pendapatan LP (bukti aljabar + angka nyata di docs/uniswap-v2-research.md section 3).
- Pelajaran: fee-on-input bukan sekadar konvensi, ia yang bikin fee otomatis mengendap di pool tanpa transfer tambahan.
- Sumber: [devlog 2026-09-30](simple-dex/devlog/2026-09-30-uniswap-v2-research.md)

### 58. Dua angka "price impact" untuk swap yang sama
- Masalah: simulasi swap 10% ke pool 100/100 menghasilkan dua angka dampak beda jauh: 9.34% (harga eksekusi out/in dibanding spot awal) dan 17.33% (harga marginal SESUDAH swap); marginal selalu lebih jelek karena kurva makin curam sepanjang swap.
- Solusi inti: dua-duanya didefinisikan eksplisit di tabel dengan kolom terpisah, dan harga eksekusi dipilih sebagai "price impact" yang ditampilkan ke user karena itu harga rata-rata yang benar-benar dia bayar (angka 9.34% jadi acuan vektor test).
- Pelajaran: angka dampak tanpa definisi itu setengah informasi; tulis rumusnya di sebelah angkanya.
- Sumber: [devlog 2026-09-30](simple-dex/devlog/2026-09-30-uniswap-v2-research.md)

### 59. Tabel IL yang beredar dikutip tanpa rumus
- Masalah: angka IL di artikel (1.25 jadi 0.6%, 2 jadi 5.7%, dst) dikutip bolak-balik tanpa derivasi, jadi gak bisa diverifikasi dan gak bisa dihitung untuk r lain.
- Solusi inti: turunkan sendiri dari definisi: pool rebalance ke x = 1/sqrt(r), y = sqrt(r), nilai LP = 2*sqrt(r), nilai HODL = 1 + r, jadi IL = 2*sqrt(r)/(1+r) - 1; tiap baris tabel dihitung di python dan cocok dengan angka umum yang beredar.
- Pelajaran: tabel yang gak bisa diturunkan ulang pembacanya gak layak dikutip; rumus dulu, tabel kemudian.
- Sumber: [devlog 2026-09-30](simple-dex/devlog/2026-09-30-uniswap-v2-research.md)

### 60. Kenapa first provision pakai sqrt, bukan rata-rata
- Masalah: LP pertama = sqrt(a0*a1) terlihat arbitrer; rata-rata aritmetika (a0+a1)/2 kelihatan lebih intuitif.
- Solusi inti: dicatat dua properti geometric mean: simetris terhadap urutan deposit DAN konsisten dengan formula share depositor berikutnya (amount * totalSupply / reserve), plus contoh eksak pool (4e18, 9e18) = 6e18 LP yang nanti dikunci test.
- Pelajaran: pilihan formula LP pertama menentukan fairness semua depositor setelahnya, bukan cuma kasus hari pertama.
- Sumber: [devlog 2026-09-30](simple-dex/devlog/2026-09-30-uniswap-v2-research.md)

## Tema B: Desain & SPEC

### 61. API: "kirim token dulu" ala v2 atau approve + call
- Masalah: Uniswap v2 pakai alur optimistic (user kirim token dulu ke pair, pair menghitung dari saldo masuk) yang aman dari front-run tapi aneh bagi user modern dan butuh factory/skim untuk recover dust; pilihan API menentukan cara reentrancy di-handle, cara dust ditangani, dan apakah butuh factory.
- Solusi inti: pilih explicit-amount API (deviasi disengaja dari v2, didokumentasikan di SPEC section 2): user approve lalu panggil fungsi, transferFrom dilakukan DI DALAM pair dengan verifikasi saldo aktual; konsekuensi diterima: gak ada flash swap di v1.
- Pelajaran: menyalin desain protocol tanpa menilai ulang trade-off-nya justru menghilangkan kesempatan belajar; yang penting deviasinya disengaja dan didokumentasikan.
- Sumber: [devlog 2026-10-01](simple-dex/devlog/2026-10-01-spec-design.md)

### 62. OZ v5 melarang mint ke address(0), MINIMUM_LIQUIDITY harus tetap terkunci
- Masalah: resep v2 me-mint 1000 wei LP pertama ke address(0) tapi OZ v5 (yang dipakai) revert kalau mint ke zero address; tujuan MINIMUM_LIQUIDITY cuma satu, 1000 wei LP yang gak bisa diklaim siapa pun selamanya supaya share tidak pernah 100% dan reserves tidak pernah 0.
- Solusi inti: mint 1000 wei ke address(this) (pair sendiri), dengan verifikasi gak ada jalur burn LP milik pair karena removeLiquidity cuma membakar msg.sender-nya; efek identik dengan v2, didokumentasikan di SPEC dan dikunci test MINIMUM_LIQUIDITY terkunci selamanya.
- Pelajaran: saat dependency baru melarang pola lama, pahami dulu INVARIAN yang dijaga pola lama, baru cari cara lain menjaga invarian yang sama.
- Sumber: [devlog 2026-10-01](simple-dex/devlog/2026-10-01-spec-design.md)

### 63. Fee-on-transfer: diakomodasi atau ditolak
- Masalah: token FoT bikin pair menerima lebih sedikit dari amount sementara pembukuan mencatat penuh; mengakomodasi berarti mengukur saldo aktual tiap kali (kompleks), mengabaikan berarti pembukuan bocor dan bisa dieksploitasi.
- Solusi inti: v1 menolak aktif: setiap input lewat _pullToken yang membandingkan balanceOf(pair) sebelum vs sesudah transfer, delta != amount revert DexPair__FeeOnTransferNotSupported; berlaku di addLiquidity DAN swap (edge case E13).
- Pelajaran: menolak fitur secara eksplisit (dengan guard yang fail loud) lebih aman daripada diam-diam salah hitung.
- Sumber: [devlog 2026-10-01](simple-dex/devlog/2026-10-01-spec-design.md)

### 64. Satu kontrak atau dua (pool + LP token terpisah)
- Masalah: LP token bisa jadi kontrak terpisah (lebih "bersih" secara SOLID) atau menyatu dengan pool; kontrak terpisah menambah wiring (pair lalu lpToken address) dan permukaan error baru.
- Solusi inti: DexPair is ERC20 (name "SimpleDex LP Token", symbol "SDX-LP"): hemat kontrak, totalSupply() selalu available lokal untuk LP math, persis pola v2 yang jadi acuan audit.
- Pelajaran: untuk komponen inti DeFi, kesederhanaan jumlah kontrak adalah fitur keamanan.
- Sumber: [devlog 2026-10-01](simple-dex/devlog/2026-10-01-spec-design.md)

## Tema C: Core Math Library & Fuzz

### 65. Fuzz round-trip gagal: panic 0x11 di getAmountOut (kejadian nyata, bukan hipotesis)
- Masalah: fuzz test round-trip gagal panic 0x11 (arithmetic overflow) dengan counterexample asli: reserveIn mungil (10756) relatif terhadap amountOut sekitar 2^120 membuat requiredIn meledak sekitar 7.17e39 dan perkalian internal di getAmountOut (sekitar 9.5e78) melewati 2^256 (1.158e77); konvensi v2 pakai reserves uint112 PERSIS supaya produk internal tidak pernah overflow, jadi rumusnya BENAR dalam domain, yang kurang adalah dokumentasi domain.
- Solusi inti: math TIDAK diubah; fuzz round-trip dibatasi domain (vm.assume requiredIn <= type(uint112).max), dua test corner baru mengunci perilaku di luar domain (counterexample asli) dan di tepi domain, plus natspec DOMAIN note di AMMLibrary; panic itu failure-safe (revert, gak ada state change).
- Pelajaran: fuzz failure di luar domain bukan bug math yang harus di-patch, tapi kontrak dokumentasi yang belum tertulis; kunci perilakunya dengan test eksplisit supaya tidak jadi skip yang diem-diem.
- Sumber: [devlog 2026-10-02](simple-dex/devlog/2026-10-02-core-math.md)

### 66. forge-std versi baru tidak lagi me-reexport StdError
- Masalah: mau pakai stdError.arithmeticError untuk expectRevert panic, kompilasi gagal karena stdError tidak dikenal walau forge-std/Test.sol sudah di-import.
- Solusi inti: tambah import {stdError} from "forge-std/StdError.sol"; eksplisit di test file.
- Pelajaran: upgrade dependency diam-diam mengubah apa yang diekspor; error kompilasi yang tampak aneh biasanya jujur bilang penyebabnya kalau kita baca simbol yang hilang.
- Sumber: [devlog 2026-10-02](simple-dex/devlog/2026-10-02-core-math.md)

### 67. Corner pertama untuk test domain boundary salah memilih angka
- Masalah: counterexample buatan pertama untuk domain boundary pakai amountOut == reserveOut, ekspektasinya sampai ke overflow tapi ternyata revert InsufficientLiquidity, jadi test menguji guard yang salah karena getAmountIn menolak amountOut >= reserveOut SEBELUM sempat menghitung requiredIn.
- Solusi inti: geser satu langkah: pakai amountOut = reserveOut - 2 (dari counterexample asli fuzz) yang lolos guard dan benar-benar menghasilkan requiredIn raksasa lalu panic di getAmountOut; itu yang dikunci test_RoundTripOutsideDomainPanics.
- Pelajaran: saat menulis test untuk mengunci satu perilaku, pastikan corner-nya lolos semua guard yang lebih dulu; revert di tempat lain berarti test menguji hal yang salah.
- Sumber: [devlog 2026-10-02](simple-dex/devlog/2026-10-02-core-math.md)

### 68. Jangan kutip vektor eksak dari run kontrak yang dites
- Masalah: godaan menulis vektor test dengan menjalankan fungsi library lalu menyalin hasilnya; itu memastikan test hijau tapi gak membuktikan apa-apa (testing the code against the code).
- Solusi inti: semua vektor (9066108938801491315, 987158034397061298, 1215942629948532819, round-trip getAmountIn = 10e18 persis) dihitung manual dengan python integer division SEBELUM test ditulis, dan natspec test mencatat asal hitungannya.
- Pelajaran: oracle independen (python isqrt/div) adalah syarat test yang bermakna; hijau dari sirkularitas itu palsu.
- Sumber: [devlog 2026-10-02](simple-dex/devlog/2026-10-02-core-math.md)

## Tema D: Liquidity & LP Token

### 69. Nilai return first provision: apakah 1000 wei terkunci ikut dihitung
- Masalah: first provision mint liquidity = sqrt(a0*a1) total tapi 1000 di antaranya masuk ke pair, jadi pertanyaan desain: fungsi return liquidity penuh atau liquidity - 1000; kalau return dipotong, formula share untuk kasus SELANJUTNYA jadi gak konsisten dan caller yang memakai return value buat akuntansi bisa salah hitung share-nya sendiri.
- Solusi inti: ikut v2, return value adalah LP PENUH termasuk porsi terkunci, caller menerima liquidity - MINIMUM_LIQUIDITY di balance; konvensi ini diulang konsisten di handler invariant (ghost_lpMinted di-seed dengan nilai penuh).
- Pelajaran: satu konvensi (full mint vs net payout) harus dipilih sekali dan diulang konsisten di return value, balance, dan ghost accounting, kalau tidak, setiap pemakai return value salah satu sisi.
- Sumber: [devlog 2026-10-03](simple-dex/devlog/2026-10-03-liquidity-lp-tokens.md)

### 70. Deposit tidak seimbang: tarik semua lalu refund, atau tidak ditarik sama sekali
- Masalah: user menawarkan (10e18, 5e18) ke pool 1:1 padahal pool cuma butuh (5e18, 5e18); opsi tarik-refund menambah dua transfer ekstra dan satu kondisi failure baru (refund bisa gagal kalau token jahat), padahal informasi kebutuhan pool sudah ada SEBELUM transfer pertama.
- Solusi inti: refund by not pulling: hitung amount1Optimal = quote(...), bandingkan dengan budget caller, tarik CUMA sisi optimal, kelebihan tidak pernah meninggalkan dompet caller; klaim amount0Optimal <= amount0Desired dijaga assert karena terjamin secara math, dikunci test dengan saldo eksak sebelum/sesudah.
- Pelajaran: transfer yang tidak perlu bukan cuma boros gas, ia permukaan error tambahan; efektivitas terbaik adalah tidak melakukan transfernya.
- Sumber: [devlog 2026-10-03](simple-dex/devlog/2026-10-03-liquidity-lp-tokens.md)

### 71. LP pertama terlalu kecil: di mana garis revert
- Masalah: first provision dengan deposit winy (mis. 1000+1000) menghasilkan sqrt(a0*a1) = 1000 == MINIMUM_LIQUIDITY, caller dapat 0 LP; kalau dibiarkan itu pemborosan senyap: 1000 LP terkunci dibayar penuh oleh depositnya.
- Solusi inti: guard eksplisit liquidity <= MINIMUM_LIQUIDITY revert DexPair__InsufficientLiquidityMinted SEBELUM transfer apapun, dikunci test_FirstProvision_TooSmallReverts (dua config: 1000+1000 dan 1+1) plus assert totalSupply dan reserves tetap 0 setelah revert.
- Pelajaran: revert lebih awal yang bisa dijelaskan (custom error) lebih baik daripada sukses yang membingungkan.
- Sumber: [devlog 2026-10-03](simple-dex/devlog/2026-10-03-liquidity-lp-tokens.md)

### 72. Mirror deposit harus memberi LP yang sama persis
- Masalah: cara membuktikan geometric mean benar-benar simetris, bukan hanya "kelihatannya simetris"; kalau LP minted bergantung urutan parameter, depositor bisa diuntungkan/dirugikan cuma dengan urutan argumen dan formula share selanjutnya jadi bias.
- Solusi inti: test_FirstProvision_GeometricMeanIsDepositOrderIndependent: pool yang sama di-seed dua kali, (4, 9) dan (9, 4), LP minted harus identik (6e18); simetri sqrt(a*b) jadi properti yang dijaga test, bukan asumsi.
- Pelajaran: properti matematis yang jadi dasar fairness sebaiknya dikunci sebagai test terpisah, sekecil apapun ketergantungannya pada implementasi.
- Sumber: [devlog 2026-10-03](simple-dex/devlog/2026-10-03-liquidity-lp-tokens.md)

## Tema E: Swap & removeLiquidity

### 73. Dust input: library balikin 0 tanpa revert, pair hampir kirim 0 wei
- Masalah: getAmountOut(1 wei, 1000e18, 1000e18) floor ke 0 TANPA revert (fungsi pure gak tahu konteks); kalau pair percaya buta ke library, dia menyetujui swap dengan output 0, user bayar input penuh dan terima nol.
- Solusi inti: pair menambah guard sendiri: amountOut == 0 revert DexPair__InsufficientOutput, dikunci test_Swap_DustInputRevertsAsInsufficientOutput dengan input 1 wei.
- Pelajaran: library pure dan kontrak stateful punya tanggung jawab beda; guard yang butuh konteks ekonomi (debu vs bukan) milik kontrak, bukan library.
- Sumber: [devlog 2026-10-04](simple-dex/devlog/2026-10-04-swap-remove-liquidity.md)

### 74. Semantik boundary slippage: satu wei bisa berarti kalah/menang
- Masalah: cek slippage amountOut < amountOutMin atau <=? Pakai <= berarti menolak eksekusi yang persis sesuai toleransi user (false negative), dan pilihan ini harus eksplisit dan teruji di boundary-nya karena bug off-by-one di guard perlindungan dana itu klasik.
- Solusi inti: pakai <; test mengunci tiga titik: min = output eksak + 1 wei HARUS revert, min yang optimistis jauh HARUS revert, min = output eksak PERSIS harus LOLOS dengan output eksak yang sama.
- Pelajaran: guard boundary diuji di tepinya (+1, eksak), bukan di tengah; kasus tengah lolos bahkan dengan guard yang salah arah.
- Sumber: [devlog 2026-10-04](simple-dex/devlog/2026-10-04-swap-remove-liquidity.md)

### 75. Deadline: strictly after atau at
- Masalah: apakah swap dengan block.timestamp == deadline masih valid? Deadline adalah janji "gak eksekusi SETELAH waktu ini", jadi pada timestamp yang sama user masih dalam janjinya.
- Solusi inti: block.timestamp > deadline revert DexPair__Expired (cocok konvensi v2); test_Swap_DeadlineReverts warp ke 1000: deadline 999 revert, deadline 1000 (persis) lolos.
- Pelajaran: inclusivity operator di parameter keamanan itu keputusan produk, tulis di natspec dan uji kedua sisinya.
- Sumber: [devlog 2026-10-04](simple-dex/devlog/2026-10-04-swap-remove-liquidity.md)

### 76. Payout remove dihitung terhadap supply sebelum atau sesudah burn
- Masalah: kalau payout removeLiquidity dihitung SETELAH _burn, totalSupply sudah mengecil dan payout jadi terlalu besar (user membayar share yang seharusnya tetap di pool); urutan read/burn menentukan denominator.
- Solusi inti: hitung amount0/amount1 = lp * r / totalSupply SEBELUM _burn, floor, plus guard payout 0 di salah satu sisi (DexPair__InsufficientLiquidityBurned) supaya debu gak nyangkut diam-diam; dikunci test dengan vektor eksak (1999999999999999666 / 4499999999999999250 untuk setengah LP di pool 4/9) dan test dust revert.
- Pelajaran: di operasi burn/mint, "snapshot state sebelum mutasi" adalah aturan pembacaan, bukan detail gaya.
- Sumber: [devlog 2026-10-04](simple-dex/devlog/2026-10-04-swap-remove-liquidity.md)

### 77. CEI vs pola optimistic transfer v2
- Masalah: v2 asli update reserves SETELAH transfer (optimistic, mengandalkan saldo aktual), dan pertanyaannya apakah disalin mentah; dengan API explicit-amount, jumlah in/out sudah diketahui SEBELUM transfer jadi menunda update state cuma memperpanjang jendela reentrancy tanpa manfaat.
- Solusi inti: CEI di swap dan remove (reserves final sebelum external call), lock modifier tetap ada sebagai defense in depth dengan paritas pola v2; deviasi ini sudah dijanjikan SPEC (poin 2) dan diimplementasi konsisten.
- Pelajaran: pola keamanan ikut API: API berubah, urutan state/interaction yang optimal ikut berubah, tapi lapisan kedua (lock) jangan dibuang.
- Sumber: [devlog 2026-10-04](simple-dex/devlog/2026-10-04-swap-remove-liquidity.md)

## Tema F: Invariant & Security Review

### 78. Config invariant: key TOML yang salah bikin assert handler ke-swallow
- Masalah: invariant suite "hijau" tapi terlalu hijau: assert di dalam handler tidak pernah jadi failure karena foundry.toml menulis fail-on-revert (kebab-case), key yang DIABAIKAN Foundry diam-diam; tanpa fail_on_revert = true, revert di handler cuma menghentikan aksi itu dan assert ikut ter-swallow sebagai "aksi gagal yang wajar".
- Solusi inti: perbaiki ke fail_on_revert = true di [invariant] foundry.toml dan desain ulang handler supaya semua aksi di-bound atau di-skip (return awal), bukan revert; sekarang revert apapun di handler = FAIL beneran.
- Pelajaran: config yang salah bentuk (kebab vs snake) bisa membunuh pengujian tanpa warning; verifikasi bahwa guard uji benar-benar AKTIF, jangan percaya "suite hijau".
- Sumber: [devlog 2026-10-05](simple-dex/devlog/2026-10-05-security-edge-cases.md)

### 79. Handler swap mentok stack limit EVM
- Masalah: fungsi swap di handler butuh menyimpan snapshot pre-state (reserves, saldo in/out, amount) untuk dicek sesudah swap plus variabel lokal lain, dan solc menolak: stack too deep (EVM punya 16 slot stack).
- Solusi inti: pindahkan snapshot swap ke storage ghost variables (ghost_swapRIn, ghost_balInBefore, dst) dan pecahkan pemeriksaan ke fungsi internal terpisah _checkSwapOutcome; bonus desain: ghost snapshot inilah yang memungkinkan echo invariant I-a di akhir sequence.
- Pelajaran: invariant handler itu program juga; storage murah dipakai sebagai memori antar-fase, dan memecah fungsi buat keterbacaan sekaligus menyelesaikan stack.
- Sumber: [devlog 2026-10-05](simple-dex/devlog/2026-10-05-security-edge-cases.md)

### 80. Guard harus jalan SEBELUM ghost snapshot di-update
- Masalah: di handler swap, snapshot pre-state di-set sebelum eksekusi; kalau guard (skip) ditaruh SETELAH snapshot, aksi yang di-skip meninggalkan snapshot basi dan echo I-a nantinya membandingkan dua titik waktu yang gak nyambung (early return yang "aman" secara lokal bisa korup secara global).
- Solusi inti: semua guard (rIn/100 < MIN_UNIT, saldo kurang) berjalan PALING AWAL di fungsi swap handler, snapshot hanya ditulis kalau aksi benar-benar akan dieksekusi (ada komentar eksplisit di DexPairHandler).
- Pelajaran: di stateful testing, urutan guard vs penulisan state bagian dari korektness, bukan gaya.
- Sumber: [devlog 2026-10-05](simple-dex/devlog/2026-10-05-security-edge-cases.md)

### 81. Pair mengurutkan token: tokenA bisa jadi token1
- Masalah: handler dan test deploy tokenA duluan, tapi constructor DexPair MENGURUTKAN token by address, jadi tokenA jadi token0 cuma kebetulan (tergantung hasil deploy address); test yang hardcode asumsi itu bisa balik arah tanpa kelihatan di mata.
- Solusi inti: helper _t0()/_t1() di kedua file test resolve sisi lewat pair.token0() perbandingan address, dipakai juga di invariant_I1_ReservesMatchActualBalances.
- Pelajaran: properti yang ditentukan sistem (sorting) harus dibaca dari sistem, bukan diasumsikan dari urutan pembuatan.
- Sumber: [devlog 2026-10-05](simple-dex/devlog/2026-10-05-security-edge-cases.md)

### 82. Rekap kejadian fuzz overflow + keputusan lock vs ReentrancyGuard
- Masalah: security review formal harus memvonis temuan overflow 2 Okt dan memutuskan bool lock cukup atau harus ganti OZ ReentrancyGuard; severity harus jujur dan mitigasi harus dibandingkan dengan alternatif standar.
- Solusi inti: overflow difonis Medium/didokumentasikan (domain uint112 konvensi v2, panic failure-safe, 2 test boundary + natspec; limitasi reserves uint256 dicatat Low dengan rekomendasi production-grade), bool lock dipertahankan (semantik sama dengan OZ: satu slot, lintas fungsi, revert custom error, paritas pola v2 yang dikenal auditor), dengan catatan jujur bahwa test reentrancy end-to-end belum ada.
- Pelajaran: memvonis temuan itu pekerjaan dua arah: severity atas dampak, status atas bukti; dan mitigasi standar (OZ) bukan otomatis pilihan benar kalau paritas pola justru nilainya.
- Sumber: [devlog 2026-10-05](simple-dex/devlog/2026-10-05-security-edge-cases.md)

## Tema G: Deploy & L2

### 83. msg.sender di konteks script bukan address dari PRIVATE_KEY
- Masalah: deployer yang mau dicatat di deployment JSON ternyata bukan address dari PRIVATE_KEY yang dipakai broadcast; di konteks script, msg.sender adalah default sender cheatcode Foundry, bukan address yang di-derive dari env PRIVATE_KEY.
- Solusi inti: derive eksplisit address deployer = vm.addr(vm.envUint("PRIVATE_KEY")) di run() (dengan komentar natspec), dan address itulah yang ditulis ke JSON dan menerima mint token.
- Pelajaran: di forge script, identitas "yang jalan" dan "yang tanda tangan" itu dua hal; metadata harus diambil dari key, bukan dari msg.sender.
- Sumber: [devlog 2026-10-06](simple-dex/devlog/2026-10-06-deploy-l2.md)

### 84. vm.writeFile deployments JSON revert karena fs_permissions default read
- Masalah: vm.createDir("deployments", true) dan vm.writeFile(...) revert saat script jalan, padahal logika deploy lancar sampai akhir; default fs_permissions Foundry cuma READ.
- Solusi inti: fs_permissions = [{ access = "read-write", path = "./" }] di foundry.toml dengan komentar yang menjelaskan alasannya; JSON hasilnya deployments/<chainId>.json dengan nested object contracts.
- Pelajaran: cheatcode yang menyentuh filesystem itu opt-in; error revert-nya jujur tapi maknanya (permission, bukan bug script) baru kelihatan kalau tahu defaultnya.
- Sumber: [devlog 2026-10-06](simple-dex/devlog/2026-10-06-deploy-l2.md)

### 85. Tabrakan port dengan anvil default
- Masalah: anvil default di 8545 sudah sering kepakai node/experiment lain, jadi deploy lokal rawan nyasar ke chain yang salah atau tabrakan state; chainId yang sama (31337) bikin salah target gak kelihatan dari address.
- Solusi inti: anvil khusus di port 8548 (argumen -p 8548), semua command deploy lokal menunjuk http://127.0.0.1:8548 (README + SPEC); deployments/31337.json tetap valid karena chainId sama, yang beda hanya port koneksi.
- Pelajaran: isolasi environment (port khusus) murah dan mencegah kelas salah yang mahal: broadcast ke node yang bukan target.
- Sumber: [devlog 2026-10-06](simple-dex/devlog/2026-10-06-deploy-l2.md)

### 86. Perbandingan gas L1 vs L2: baseline yang bisa diukur belum ada
- Masalah: task minta membandingkan gas L1 vs L2, tapi dua sumber angka ternyata kosong: broadcast run-*.json dari forge versi ini tidak menyimpan gasUsed per transaksi dan .gas-snapshot dari forge snapshot belum pernah di-commit; klaim "L2 X% lebih murah" tanpa pengukuran berpasangan (kontrak sama, RPC sama, waktu sama) itu fabricated.
- Solusi inti: TIDAK menulis angka L1/L2 di README maupun devlog; yang ditulis metode ukurnya (bandingkan field gas di run-*.json kedua chain setelah deploy sungguhan, atau ambil baseline dulu via forge snapshot) plus penjelasan kualitatif kenapa L2 murah, semua disebut eksplisit sebagai estimasi/metode, bukan hasil ukur.
- Pelajaran: ketika datanya belum ada, deliverable yang jujur adalah metode pengukurannya, bukan angka yang diisi supaya tabel kelihatan lengkap.
- Sumber: [devlog 2026-10-06](simple-dex/devlog/2026-10-06-deploy-l2.md)

### 87. Optimistic vs ZK: memilih frame yang benar buat catatan
- Masalah: materi rollup gampang jatuh jadi daftar fitur, padahal yang dibutuhkan catatan pribadi adalah trade-off yang berdampak ke developer yang mau deploy; dua keluarga rollup berbeda di BUKTI kebenaran (Optimistic: fraud proof + window challenge sekitar 7 hari; ZK: validity proof, finalitas cepat tapi prover mahal).
- Solusi inti: catatan singkat di SPEC section 9 dan README: SimpleDex cukup deploy standar forge ke Arbitrum Sepolia (EVM-equivalent, gak ada perubahan kode), pemahaman rollup dicatat kualitatif tanpa angka yang gak diukur; deep dive ZK dan zkSync testnet ada di roadmap 24 Okt.
- Pelajaran: deploy ke Optimistic Rollup hari ini praktisnya "Ethereum dengan biaya lain"; perbedaan filosofis rollup baru terasa saat menyangkut finalitas dan bridge, bukan saat deploy.
- Sumber: [devlog 2026-10-06](simple-dex/devlog/2026-10-06-deploy-l2.md)

## Tema H: Frontend AMM

### 88. oxlint menolak Date.now() di komponen swap
- Masalah: npm run lint menemukan warning "Cannot call impure function during render" karena Date.now() dipanggil di dalam onSubmit yang didefinisikan di body SwapPanel; aturan purity React gak bisa membedakan bahwa fungsi ini cuma jalan di event handler, bukan saat render, dan suppress comment cuma memindahkan masalah.
- Solusi inti: perhitungan deadline dipindah ke useDexActions.swap: komponen mengirim deadlineMinutes (angka murni dari state form), hook menghitung BigInt(Math.floor(Date.now() / 1000) + minutes * 60) saat submit; lebih bersih arsitekturnya karena deadline adalah keputusan tx-time, bukan state UI.
- Pelajaran: peringatan purity sering menunjuk desain yang bisa dibetulkan, bukan cuma gaya; kalau perhitungan bergantung waktu dipindah ke lapisan yang tepat, warning-nya hilang tanpa suppress.
- Sumber: [devlog 2026-10-07](simple-dex/devlog/2026-10-07-frontend-swap-ui.md)

### 89. Dua definisi price impact, plus keputusan rounding yang bikin angka beda 0.01% dari docs
- Masalah: UI harus konsisten dengan dua definisi price impact di docs (eksekusi dan marginal), plus jebakan rounding: vektor swap 10% pool menghasilkan impact eksekusi 9.3389...%, docs melaporkan 9.34% (dibulatkan biasa), sedangkan UI menghitung basis point dengan floor division jadi 933 bps yang tampil sebagai 9.33%.
- Solusi inti: tampilkan keduanya dengan label eksplisit ("Price impact (execution)" dan "Marginal price after") plus penjelasan dua definisi di <details>; keputusan dicatat: semua persen di UI di-floor, arah yang aman untuk angka risiko, konsisten dengan konvensi kontrak yang selalu menguntungkan pool.
- Pelajaran: dua definisi harga itu jebakan klasik UI AMM; satu kalimat definisi di dekat angka lebih berguna daripada tooltip kosong, dan arah pembulatan angka risiko harus keputusan eksplisit, bukan efek samping.
- Sumber: [devlog 2026-10-07](simple-dex/devlog/2026-10-07-frontend-swap-ui.md)

### 90. Agregasi query state di usePairReads: Object.values mengambil nilai data, bukan objek query
- Masalah: versi pertama usePairReads mengumpulkan state loading/error dengan ...Object.values(tokenA) ke array reads; hasilnya readsError dan readsLoading tidak pernah akurat karena yang masuk array nilai mentah (string/bigint/undefined), bukan objek hasil useReadContract yang punya isLoading/isError.
- Solusi inti: hook useTokenReads mengembalikan data UI dan properti queries (array hasil useReadContract mentah) secara terpisah, dan agregasi pakai allReads yang eksplisit berisi objek query.
- Pelajaran: jangan meratakan objek yang isinya campuran dua tipe; kalau butuh metadata query untuk agregasi, ekspos lewat field khusus agar intent-nya kelihatan.
- Sumber: [devlog 2026-10-07](simple-dex/devlog/2026-10-07-frontend-swap-ui.md)

### 91. Urutan kanonik pair: TokenA bisa jadi token1, mapping-nya harus dibaca dari chain
- Masalah: frontend tahu address TokenA/TokenB dari deployment JSON, tapi DexPair mengurutkan token by address jadi token0/token1; mengasumsikan TokenA == token0 berarti UI bisa telat balik arah kalau urutan deploy berubah (gejala: swap ke arah yang salah).
- Solusi inti: UI membaca token0()/token1() dari pair dan memetakan ke label deploy dengan perbandingan address checksummed (getAddress dari viem, karena nilai chain dan konstanta config bisa beda case); symbol label dibaca dari symbol() chain, bukan di-hardcode, dan pool stats menampilkan mapping aktual.
- Pelajaran: properti yang ditentukan sistem harus dibaca dari sistem; di frontend, "sistem" termasuk normalisasi case address sebelum dibandingkan.
- Sumber: [devlog 2026-10-07](simple-dex/devlog/2026-10-07-frontend-swap-ui.md)

### 92. Brief bilang "approve 3 token", kontrak bilang remove gak butuh approve LP
- Masalah: instruksi awal menyebut approve tiga token (TokenA, TokenB, LP), tapi kalau diikuti mentah-mentah, UI remove liquidity bakal memaksa satu approve tx yang sia-sia; removeLiquidity memanggil _burn(msg.sender, lpAmount) langsung tanpa melihat allowance, karena LP token adalah kontrak pair itu sendiri.
- Solusi inti: UI remove tidak punya step approve, dan form menjelaskan ke user ("No approval is needed: the pair burns LP from your balance directly"); add tetap approve dua token per-amount, catatan masuk frontend README supaya gak dianggap lupa.
- Pelajaran: daftar integrasi yang ditulis dari luar kode perlu diverifikasi ke source sebelum jadi UI flow; satu bacaan _burn menghemat satu transaksi dan satu kebingungan per remove.
- Sumber: [devlog 2026-10-08](simple-dex/devlog/2026-10-08-frontend-liquidity.md)

### 93. Perilaku refund addLiquidity ternyata "gak pernah ditarik", bukan "ditarik lalu dikembalikan"
- Masalah: UI harus menjelaskan apa yang terjadi kalau user deposit dengan rasio off-pool; dugaan awal (dan cara banyak protocol lama) kontrak menarik semuanya lalu mengirim kelebihannya balik, dan kalau UI menjanjikan itu padahal kontraknya beda, copy-nya bohong.
- Solusi inti: baca source: transferFrom cuma dipanggil untuk amount final, jadi surplus tidak pernah keluar dari wallet; mirror addLiquidityOutcome menghitung amounts final plus surplus0/surplus1 dan warning off-ratio menyebut angkanya eksplisit, first provision diberi hint terpisah.
- Pelajaran: perilaku refund yang akurat adalah properti urutan operasi (CEI: hitung dulu, tarik sesudahnya), dan itu bisa di-mirror 1:1 di frontend kalau mirror-nya ditulis dari source, bukan dari intuisi AMM umum.
- Sumber: [devlog 2026-10-08](simple-dex/devlog/2026-10-08-frontend-liquidity.md)

### 94. willRevert muncul padahal data masih loading
- Masalah: flag willRevert dihitung dari outcome === null, dan saat halaman baru dibuka reserves dan totalSupply masih undefined sehingga UI menampilkan error "the pair would revert" padahal belum ada yang salah; mirror sengaja mengembalikan null untuk dua kondisi berbeda (input belum siap vs benar-benar akan revert) dan komponen menggabungkan keduanya.
- Solusi inti: willRevert di-gate pada data yang sudah terdefinisi (reserve0 !== undefined && reserve1 !== undefined && lpTotalSupply !== undefined), jadi error pre-submit hanya muncul kalau angkanya sudah dihitung dari state pool nyata; kasus debu tetap tertangkap sebelum user boros gas.
- Pelajaran: null sebagai sinyal "akan revert" hanya valid kalau input mirror-nya lengkap; pisahkan "belum tahu" dari "tahu bahwa gagal", dua state UI yang berbeda.
- Sumber: [devlog 2026-10-08](simple-dex/devlog/2026-10-08-frontend-liquidity.md)

### 95. Share % dan estimasi holdings: satu pembagi, dua arah floor
- Masalah: position tracker menampilkan share user dan estimasi payout, keduanya pecahan, dan ada dua cara salah: menghitung share via floating point (kehilangan presisi untuk LP besar) atau menampilkan estimasi yang tidak sama dengan payout eksak kontrak (kontrak menghitung payout terhadap supply SEBELUM burn, devlog 4 Okt).
- Solusi inti: share dalam basis point BigInt ((lp * 10000n) / totalSupply) dan estimasi holdings memakai removeLiquidityOutcome yang sama dengan preview form remove, semua floor; unit-check mengunci vektor remove (pool 4/9, supply 6, burn 3 = payout 2 dan 4.5 eksak).
- Pelajaran: di UI AMM, "estimasi" yang bagus adalah hasil rumus kontrak yang sama, bukan aproksimasi terpisah; konsistensi pembulatan antara preview dan eksekusi adalah bagian dari kebenaran UI.
- Sumber: [devlog 2026-10-08](simple-dex/devlog/2026-10-08-frontend-liquidity.md)

## Tema I: Demo & Artikel

### 96. Angka demo: godaan menulis angka yang "kelihatannya masuk akal"
- Masalah: script demo butuh angka untuk dibacakan (output swap, impact, payout) dan cara cepatnya mengarang angka bulat yang meyakinkan; angka demo dari karangan akan langsung kelihatan gak cocok saat user merekam (UI menampilkan angka asli dari chain) dan artikel yang mengutipnya ikut gak bisa direproduksi.
- Solusi inti: semua angka dihitung dari mirror JS yang sama yang dipakai UI (terverifikasi 26 vektor test + bit-exact vs on-chain), dicatat dengan konteks state pool-nya, termasuk dua timeline pool yang disebut eksplisit (pool awal 1000/1000 dan pool setelah smoke swap 25 SDA = 1025 / 975.681...).
- Pelajaran: angka demo itu artefak yang diuji, bukan copywriting; kalau angkanya gak bisa dihitung ulang dari state yang jelas, gak layak dibacakan di video.
- Sumber: [devlog 2026-10-09](simple-dex/devlog/2026-10-09-demo-readme-article.md)

### 97. Rekam Loom dan publish Mirror: dua aksi yang gak bisa gw eksekusi
- Masalah: task roadmap 9 Okt adalah merekam video dan publish artikel, tapi subagent gak punya GUI, mikrofon, akun Loom, maupun wallet Mirror, jadi dua langkah terakhir mustahil dieksekusi dari sana; itu keterbatasan environment, bukan kelengahan kerja.
- Solusi inti: yang bisa diproduksi tanpa GUI diproduksi penuh: demo script dengan checklist prasyarat dan blok waktu yang bisa dibacakan, plus draft artikel final yang tinggal di-paste, dengan status "butuh aksi manual" dicatat jujur.
- Pelajaran: kalau sebagian task di luar kendali, deliverable yang jujur adalah artefak eksekusi (script, draft, checklist), bukan klaim bahwa videonya sudah ada.
- Sumber: [devlog 2026-10-09](simple-dex/devlog/2026-10-09-demo-readme-article.md)

### 98. Draft artikel: menahan diri dari klaim yang gak bisa dibuktikan
- Masalah: menulis artikel pengalaman gampang melorot ke klaim kosong ("production-ready", "amannya teruji", "gas efficient"); semua itu gak bisa dibuktikan karena kontraknya unaudited, gas snapshot L1 vs L2 belum diambil, dan "teruji" hanya sampai sejauh suite testnya.
- Solusi inti: draft dibatasi ke tiga jenis kalimat: apa yang benar-benar dikerjakan dengan angka reproduce-able, keputusan beserta alasannya, dan batasan yang diakui eksplisit; kata "aman" hanya dipakai mengutip properti yang diuji (k gak pernah turun dalam domain), bukan menilai keseluruhan sistem.
- Pelajaran: proses over hasil bukan gaya penulisan semata, ia adalah mekanisme penyaring klaim: ceritakan keputusan dan buktinya, dan bagian yang belum dibuktikan sebut sebagai yang belum dibuktikan.
- Sumber: [devlog 2026-10-09](simple-dex/devlog/2026-10-09-demo-readme-article.md)

---

# Penutup: Rekap

| Project | Jumlah unit | Tema (jumlah entri) |
|---|---|---|
| defi-staking | 17 | Stack Frontend & Tooling (4), Parsing, Validasi & Error Handling (1), Deploy & Script Foundry (5), Dokumentasi, Kredibilitas & Konten (7) |
| governance-dapp | 39 | Riset & Keputusan Desain (6), Kontrak Token & Governor OZ v5 (8), Timelock & Test Full Flow (5), Frontend & Event Log (9), Subgraph & Indexing (4), Deploy & Compiler (4), README & Publish (3) |
| simple-dex | 42 | Riset & Math AMM (4), Desain & SPEC (4), Core Math Library & Fuzz (4), Liquidity & LP Token (4), Swap & removeLiquidity (5), Invariant & Security Review (5), Deploy & L2 (5), Frontend AMM (8), Demo & Artikel (3) |
| **Total** | **98** | |

Beberapa pola yang kelihatan kalau dibaca lewat: (1) sumber kebenaran itu source/artifact yang ter-install, bukan ingatan atau blog, pola ini muncul di OZ v5, ABI viem, sampai signature event subgraph; (2) verifikasi state on-chain selalu setelah "sukses" apapun (script success, broadcast success, build success); (3) angka tanpa sumber gak boleh ditulis, dari coverage, gas L1 vs L2, sampai angka demo; (4) devlog yang jujur otomatis jadi bahan konten dan bahan belajar.

Buku ini index. Detail lengkapnya (kenapa, langkah repro, status jujur) selalu di devlog asli lewat link di tiap entri.
