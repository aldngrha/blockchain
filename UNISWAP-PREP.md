# Uniswap intro call prep (10 Nov 2026, 21:00 WIB)

Call 30 menit dengan Thalita Ferreira, Calendly-nya tertulis "Meeting with Project Manager, Uniswap Labs". Bahasa Inggris. Ini bukan technical interview: yang dinilai komunikasi, sinyal senioritas, motivasi, dan kelayakan logistik.

Cara pakai dokumen ini: baca sekali dari atas ke bawah, lalu latihan cuma pakai Bagian 10 (kartu ringkas). Jangan hafal seluruh kalimat, hafal alurnya.

Kalimat bertanda [ ] harus lo isi sendiri karena itu fakta lo, bukan fakta yang gue tahu. Jangan diucapkan apa adanya.

## 1. Referensi yang dipakai

- TechPrep, "Uniswap's Interview Process (2026)". Recruiter screen 30 sampai 45 menit, fokus background, minat DeFi, motivational fit. Total proses 5 sampai 6 tahap. Blog pihak ketiga, bukan sumber resmi.
- Glassdoor, Uniswap Labs interview questions. Rata-rata proses sekitar 16 hari dari 10 laporan user.
- Blind, "Interview experience at notable blockchain companies". Format yang disebut: LC, system design, behavioral, OO.
- Uniswap tidak punya halaman proses interview publik. Semua di atas adalah pola, bukan jadwal pasti.

## 2. Yang perlu lo tahu sebelum mulai

Balasan recruiter lo menyebut dua hal dari CV: dApp Solana (Next.js, wallet, tx signing, React Query) dan lead frontend web dan mobile di Newus. Dia tidak menyebut monorepo, CI/CD, atau traceability platform.

Artinya dia melihat lo sebagai frontend web3, bukan orang platform. Tugas lo di call ini adalah membawa sendiri materi monorepo dan CI/CD, karena kalau tidak, ringkasan yang dia kirim ke hiring manager akan berisi dua hal yang dia sebut tadi.

Aturan teknis:
- Satu jawaban maksimal 90 detik. Kalau lebih, dia akan memotong.
- Sebut satu angka per jawaban. Angka membuat klaim jadi fakta.
- Setiap kali menyebut teknologi, harus ada satu kalimat akibat. Kalau tidak ada akibatnya, buang nama teknologinya.
- Kalau tidak tahu, bilang tidak tahu lalu sebut hal terdekat yang pernah lo kerjakan. Jangan mengarang.

## 3. Kalimat untuk urusan NDA

Ucapkan sekali di awal, jangan diulang tiap pertanyaan.

> "Most of what I can go into is architecture-level rather than business-level, since some of it is under NDA. Happy to go deeper on the technical decisions."

Kalau dia menanyakan hal yang kelewat batas:

> "That part I can't share, but the technical shape of it was..."

Yang aman: apa yang lo bangun, peran lo, stack, ukuran tim, timeline, hasil tanpa angka komersial. Yang tidak: nama klien, nilai kontrak, roadmap belum rilis, detail proprietary.

Untuk SKA aman dibicarakan karena itu produk employer lo dan sudah disebut recruiter sendiri di cold email-nya. Untuk dApp Solana, sebut chain, stack, dan peran, tanpa nama klien.

## 4. Pembuka: 90 detik

Ini jawaban yang paling sering dipakai dan paling menentukan kesan pertama.

> "Thanks for making the time. Short version: I'm a software engineer in Indonesia, about four years in, and what I like building is the shared layer underneath a product. The part nobody sees until it breaks.
>
> Right now I'm at a coffee export company. I architected a monorepo that serves three connected products: an EUDR traceability platform, a B2B marketplace for green coffee, and an event site. They share schema, validation, auth and UI primitives across SvelteKit and React, and I own the CI/CD that deploys all three. So my actual users are the other parts of the system, which I think is the closest thing I've done to the Apps Infra job.
>
> Before that I was frontend on a Solana dApp: Next.js, wallet connection, transaction signing, React Query over on-chain data. Before that I led frontend at Newus across web and React Native. And before all of that I freelanced for about a year and a half, which is where I learned to work without anyone handing me a spec.
>
> The thread is that all of it was data that had to stay honest. Field staff with no signal, RPC endpoints that fail. I like problems where the interface has to be honest about what the system actually knows."

Kenapa disusun begini: kalimat ketiga langsung menempatkan lo sebagai orang platform, bukan orang halaman. Freelance disebut sebagai bagian riwayat, bukan sebagai pembelaan. Dan paragraf terakhir memberi dia satu label untuk mengingat lo.

## 5. Pertanyaan per pertanyaan

### 5.1 "Tell me more about the monorepo at SKA."

> "The constraint was that three products needed to agree on the same farmer, the same plot, the same certification state. If those drift, an audit finding becomes unanswerable. So I put them in one repo with shared packages for types, Zod schemas, and API clients, and the products consume that instead of each calling the database their own way.
>
> The trade-off is that I chose SvelteKit for the public site and React for the app surfaces, so the repo carries two UI runtimes. That was right for speed at the time and it's the thing I'd reconsider now, because shared components don't travel between them cheaply.
>
> What I'm proudest of is boring. The import engine validates every row and records why a row is HOLD or DUPLICATE, so when an auditor asks about a farmer, the answer is a record and not someone's memory."

### 5.2 "Why Uniswap?" atau "Why crypto?"

Jangan bilang "I love DeFi". Balikin ke sifat pekerjaannya.

> "Two reasons, both about the work rather than the brand.
>
> First, the role is the same shape as what I already do, at a scale where the problems get real. I've built a shared layer for three products. You're building one for several product teams across web and mobile. What interests me is what changes when the consumer isn't you, because that's the part I've only seen from the small end.
>
> Second, I've spent my own time on the protocol side. Foundry, cross-chain messaging, AMM math, audit practice. Most frontend roles never touch that. Here the frontend sits on primitives that reorg, that cost gas, where state is eventually consistent. That's the constraint I actually want."

Kalau dia bertanya "does that help you as a frontend engineer?":

> "It makes me ask better questions earlier. When a swap flow shows a price, I know how stale it can be and why the UI shouldn't claim more certainty than the chain gives. And I don't need a translator when the contract changes."

### 5.3 "How much React Native have you done?"

JD minta "deep", CV lo Android saja. Jangan klaim deep.

> "'Deep' would be overstating it, so let me be precise. I've shipped Android apps in React Native at Newus, and I led frontend across both web and mobile there, so I know the platform-specific pain: navigation, list virtualization, and the fact that the debugging toolchain is completely different.
>
> What I haven't done is a single codebase shared between web and native at real scale, and I haven't shipped iOS or written native modules. I'd need to ramp on the Expo and iOS side. I'd rather say that now than in week two."

Kalau dia bertanya bagaimana lo akan menutup itu:

> "First two weeks I'd read how you structure navigation and list rendering, and get the iOS build running locally. That's where the differences actually live, not in the component syntax."

### 5.4 "What's your experience with design systems?"

> "I've built the consumer side fully and a lightweight version of the producer side. At SKA I built the primitives, mostly on top of shadcn, and at Newus I enforced a reusable component structure across teams so we stopped rebuilding the same table five times.
>
> What I haven't run is versioning and breaking-change policy for a library with real downstream consumers. Codemods, deprecation windows, the release discipline. I know what that costs, because I've mostly been the person on the receiving end of a bad upgrade."

### 5.5 "How do you test your code?"

Jujur, dan jangan mengaku lebih dari CV.

> "Testing is the weakest line on my CV and the thing I care most about, and those two facts are related. At SKA the automated coverage is on the import engine and the API contract, because that's where a silent wrong answer costs the most. UI coverage is thin, and it's thin because nobody is holding me to it.
>
> On my own time I work the other way. Foundry suites with fuzz and invariant tests. 161 tests across three projects, and I've had a fuzz run find an integer overflow that I would have shipped."

### 5.6 "How do you use AI in your workflow?"

Ini pertanyaan yang paling menguntungkan lo. Jangan jawab "I use Copilot".

> "Daily, and I've stopped trusting the output. My loop is: give the agent a spec and a way to check itself, then verify the claims myself.
>
> Concrete example. I was querying events through viem and getting wrong results. The library was silently ignoring the ABI and event name I passed instead of throwing, so I got logs that looked plausible and were the wrong set. It only surfaced because I compared the output against expected values instead of accepting a green run.
>
> So my rule is that the agent writes, but it doesn't get to grade its own work."

### 5.7 "Tell me about the hardest technical problem you've solved."

> "The Excel import engine. Field staff send files that are half-filled, duplicated, and then re-sent a week later. The naive version imports whatever parses.
>
> The version we shipped has explicit states and an audit trail, so a re-import can't silently double count a farmer. The hard part wasn't the code. It was deciding what 'duplicate' means when the name is spelled three ways and the plot coordinates overlap by ninety percent."

### 5.8 "Tell me about something you owned end to end."

> "The traceability platform. I owned it from schema to deploy: the import pipeline, the geospatial layer for plot polygons, the RBAC and the multi-level approval workflow, and the Docker and CI/CD setup.
>
> The part I'm proudest of is still boring. When an auditor asks why a farmer is on hold, the answer is a record, not a person's memory. That's what made the system usable across three branches and about a thousand farmers."

### 5.9 "Why are you leaving your current role?"

> "Nothing is broken there. I'm the most senior frontend person, which means there's no one above me to learn platform work from. I want to be on a team where the shared layer serves multiple product teams, because that's the feedback loop I'm missing."

### 5.10 "How many years of experience do you have?"

Ini pertanyaan paling berbahaya, karena CV lo hanya mencantumkan employment mulai 2024.

> "I'll be precise, because it isn't obvious from my CV. About four years of professional work, but only the last two and a half are employment. Before that I freelanced, mostly smaller projects and a few larger ones, starting while I was finishing my degree. The JD says five plus, so I'm about a year short and I'm not going to pad it.
>
> What I'd put next to it is scope. At SKA I architected a monorepo serving three products and owned deployment for all of them, with no senior engineer above me. If the bar is five years of being mentored by staff engineers on a large codebase, I'd be honest that I haven't had that. If it's whether I can be trusted to own a system and run a migration, I'd rather you judge that from the work."

Kenapa ini bekerja: lo menyebut celahnya sebelum dia menemukannya, angkanya bisa lo pertanggungjawabkan, dan lo berani memberi mereka jalan keluar. Itu terbaca sebagai percaya diri, bukan defensif.

### 5.11 "What are your salary expectations?"

Jangan sebut angka duluan.

> "I'd rather not anchor before I understand how you structure it. The posting shows 180 to 226 for New York, is that a global band or adjusted by location? Once I know that, I can give you an honest number."

Kalau dia mendesak minta angka sekarang:

> "Then give me a range and I'll tell you if it works, rather than inventing a number that isn't informed by anything."

### 5.12 "Where are you based, and what's your timezone?"

> "Bandar Lampung, Indonesia, GMT plus seven. Practically I can give you four to five hours of overlap with New York, which covers your whole morning. I've worked async heavy already, our field staff work offline, so I default to writing things down instead of needing to be live."

Lalu tanya balik:

> "And for hiring outside the US, is that direct or through an employer of record? I ask because it changes the shape of the contract, not because I have a preference."

### 5.13 "What's your notice period?"

> "One month, so realistically [bulan] if we move now. I'd rather tell you that than promise a date I can't control."

### 5.14 "Are you interviewing anywhere else?"

Jujur tapi tanpa tekanan.

> "I'm in conversations with [jumlah] other places, none of them at offer stage. Uniswap is the one I'd move fastest for, which is why I booked the earliest slot."

### 5.15 "Do you have questions for me?"

Pilih dua, maksimal tiga. Jangan borong, ini bukan sesi wawancara balik.

1. "The Tamagui to Tailwind migration, where is it now, and how do you define done per product team?"
2. "In the first 90 days, what would make you say this hire worked?"
3. "How much of the team's day is synchronous? That shapes how I'd want to work with you."
4. "Is the Apps Infra team measured on anything specific, or is it more about what the product teams report?"

Kenapa tiga yang pertama bagus: dua menunjukan lo sudah memikirkan kerjaannya, satu menunjukan lo memikirkan cara kerja lintas zona waktu. Pertanyaan soal benefit jangan ditaruh di sini.

### 5.16 "What have you built on the protocol side?"

Ini satu-satunya aset lo yang tidak bisa ditiru kandidat frontend lain. Tapi sebut artefaknya, jangan sebut proses belajarnya.

> "On my own time I've been building on the protocol side rather than reading about it. Three Foundry projects with 161 tests between them, and a cross-chain messaging project on Chainlink CCIP with a sender, a receiver and a full test suite.
>
> The one that taught me the most was a minimal AMM. I had to mirror the swap math in JavaScript for the frontend, then verify the mirror against the contract with exact integer vectors, 26 of them, all matching on-chain after a real swap on a local fork. That's where I actually understood why routing and slippage are the hard part of a swap interface, and why the UI can't round anything it doesn't own."

Kenapa kalimat terakhir penting: dia menyambungkan karya lo ke produk Uniswap tanpa lo perlu menyebut Uniswap. Itu yang bikin recruiter mencatat.

**Jangan ucapkan:** "I made my own syllabus", "I'm learning blockchain", "I follow a roadmap I wrote". Semua itu membuat lo terbaca sebagai murid. Sebut hasilnya: jumlah proyek, jumlah test, apa yang berhasil diverifikasi.

### 5.17 "How do you learn something new?" atau "How do you work without direction?"

Di sinilah metode lo baru boleh disebut, dan di sini nilainya tinggi karena JD minta orang yang bisa "establish best practices where none exist".

> "When I want to learn something properly, I write the spec before the code. Edge cases with IDs, invariants, then tests, then implementation. I keep a decision log per project, mostly so that future me can argue with past me.
>
> That started as a personal habit and it's now how I work at SKA. If you gave me a new area with no conventions, the first thing I'd produce is a written spec and a way to check it, because otherwise you can't tell progress from motion."

Kalau dia bertanya seberapa jauh lo mengerjakan itu sendiri:

> "The largest thing I've owned is not one product, it's a sequence of them. I set myself a stretch of months, one shipped project per topic, and I finished with a written spec, a test suite and a decision log for each. Three of those are DeFi protocols. Nobody assigned that, which I think is the relevant part."

### 5.18 "What's hard about the data layer?" atau "How do you handle on-chain data fetching?"

Ini jawaban terpenting yang tadinya belum ada di dokumen ini, padahal data layer adalah tanggung jawab teknis terbesar di JD. On-chain data jauh lebih sulit dari REST, dan lo sudah merasakannya.

> "The data layer is the part I'd most want to work on, because on-chain data breaks the assumptions a normal React Query app makes.
>
> There's no server telling you what changed. You either poll or you subscribe to logs, and you reconstruct state from events. You submit a transaction and then you have three states that all look like success from a distance: pending, mined, and confirmed at depth. Invalidate at the wrong one and the interface shows a balance that isn't real yet.
>
> Cache keys have to be chain aware, because the same address on two chains is a different thing. And with rate limits you can't refetch on window focus the way you would against a REST API.
>
> At small scale I used a shared client, query keys built from chain id plus address, and invalidation tied to the transaction lifecycle instead of a timer. That works. It is also exactly where I'd expect the real design problems at your scale, because you have hundreds of hooks and several product teams that don't talk to each other."

Kenapa ini bekerja: lo mendemonstrasikan pemahaman masalah mereka, bukan pengetahuan lo. Kalimat terakhir secara sengaja menyerahkan panggung ke masalah mereka, dan itu membuat lo terdengar seperti rekan kerja, bukan pelamar.

## 6. Kalau ditanya hal yang lo tidak tahu

Jangan mengarang, dan jangan hanya bilang "I don't know". Pakai tiga langkah:

> "I haven't worked with that directly. The closest thing I've done is [X]. My guess at how I'd approach it is [Y], and I'd want to check that with whoever owns it."

Contoh untuk sesuatu seperti Detox atau Expo EAS:

> "I haven't used Detox. The closest thing is that I've written integration tests around data flows rather than UI, and set up CI that fails on them. My guess is the hard part with Detox is flakiness on device farms, not writing the first test, but I'd want to confirm that."

## 7. Yang jangan diucapkan

- "I'm a fast learner" sebagai jawaban utama. Itu jawaban default semua orang, dan nol informasi.
- Angka salary pertama.
- Klaim "deep" untuk React Native, design system, atau native mobile.
- "We used [teknologi]" tanpa akibat. Setiap nama teknologi butuh satu kalimat tentang apa yang jadi lebih baik atau lebih buruk karenanya.
- "I can't talk about that, NDA" tanpa lanjutan. Selalu ada lanjutan.
- Menjelekkan employer sekarang.
- Jawaban lebih dari 90 detik.
- Menunda pertanyaan soal kerjaan sampai menit terakhir. Sisakan minimal lima menit.

## 8. Setelah call

Kirim di LinkedIn hari yang sama, maksimal tiga kalimat, sebut satu hal spesifik yang dia ucapkan.

> "Hi Thalita, thanks for the walkthrough, especially the point about tracking the migration per product team. That's the kind of problem I want to be working on. Happy to go deeper on the SKA monorepo or the dApp data layer whenever the team wants to."

Kalau nanti mereka minta dokumen untuk hiring manager, kirim CV versi yang sudah memuat freelance, dengan kalimat netral:

> "Here's the version that also lists my freelance work, so the timeline is complete."

Jangan pernah mengirim ulang CV tanpa diminta.

## 9. Rencana latihan 8 hari

- 2 Nov: rekam pembuka 90 detik pakai voice memo. Target di bawah 100 detik, kata pengisi maksimal tiga.
- 3-4 Nov: rekam 5.10 (durasi), 5.3 (React Native), 5.11 (salary). Ini tiga yang paling berisiko. Dengar ulang, buang kalimat yang kedengaran minta maaf.
- 5-6 Nov: minta orang lain menanyakan pertanyaan Bagian 5 secara acak, tanpa lo lihat daftarnya.
- 7 Nov: uji "so what". Setiap nama teknologi harus punya akibat. Kalau tidak ada, hapus.
- 8 Nov: latihan penuh 30 menit, direkam. Tonton tanpa suara dulu, cek postur dan ekspresi.
- 9 Nov: istirahat, cuma baca Bagian 10.
- 10 Nov pagi: baca Bagian 10 dan 5.10 saja. Kebanyakan hafalan bikin kaku.

## 10. Kartu ringkas

Sepuluh kalimat ini yang harus otomatis. Sisanya improvisasi.

1. "About four years in, and what I like building is the shared layer underneath a product."
2. "I architected a monorepo that serves three connected products, and I own the CI/CD for all three."
3. "So my actual users are the other parts of the system."
4. "The trade-off is that the repo carries two UI runtimes, and that's the thing I'd reconsider now."
5. "When an auditor asks, the answer is a record, not someone's memory."
6. "'Deep' would be overstating it, so let me be precise."
7. "What I haven't done is X. I'd need to ramp on Y. I'd rather say that now than in week two."
8. "The agent writes, but it doesn't get to grade its own work."
9. "The JD says five plus, so I'm about a year short and I'm not going to pad it."
10. "Three Foundry projects with 161 tests between them, and I verified the AMM math against the contract with exact integer vectors."
11. "In the first 90 days, what would make you say this hire worked?"

Nomor 6, 7, 9 adalah tiga kalimat yang paling sering menyelamatkan kandidat, karena semuanya adalah cara mengakui kekurangan tanpa kehilangan posisi.

## 11. Materi blockchain lo: mana yang relevan

Workspace lo isinya banyak, tapi yang relevan ke call frontend dan infra cuma sebagian. Urutannya begini.

### 11.0 Tiga file yang wajib dibaca ulang sebelum call

Kalau cuma ada waktu 30 menit, tiga ini saja.

1. [governance-dapp/frontend/src/hooks/useProposals.js](governance-dapp/frontend/src/hooks/useProposals.js). Ini jawaban 5.18 dalam bentuk kode: `queryKey: ["proposals", chainId, GOVERNOR_ADDRESS]` (sadar chain), `initialData` dari cache localStorage supaya daftar langsung tampil, scan log inkremental dari `lastScannedBlock` dengan margin reorg 20 blok, `refetchInterval` 15 detik, plus `watchContractEvent` terpisah untuk update live. Kalau dia bertanya "pernah bikin data layer on-chain?", lo bisa menyebut empat keputusan ini berturut-turut.
2. [governance-dapp/devlog/2026-09-25-proposal-list.md](governance-dapp/devlog/2026-09-25-proposal-list.md). Cerita viem `getLogs` yang mengabaikan `abi` dan `eventName` tanpa error. Ini bahan 5.6, dan satu-satunya bukti lo memverifikasi kerja agent, bukan percaya.
3. [simple-dex/frontend/src/lib/amm.js](simple-dex/frontend/src/lib/amm.js). Mirror BigInt dari AMMLibrary. Perhatikan komentar di kepala file: pembagian BigInt truncate ke arah nol persis seperti EVM, jadi hasilnya identik bit per bit. Dan satu keputusan desain yang bagus untuk diceritakan: fungsi ini mengembalikan `null` di tempat kontrak akan revert, supaya UI yang memutuskan pesan ke user, bukan exception.

### 11.1 Lapis 1: langsung kepakai, harus bisa lo jelaskan tanpa mikir

| Materi | Kenapa relevan |
|---|---|
| [simple-dex/frontend/src/components/SwapPanel.jsx](simple-dex/frontend/src/components/SwapPanel.jsx) | Price impact, slippage, deadline, dan state transaksi. Ini menempel langsung ke swap interface Uniswap. |
| [simple-dex/frontend/src/hooks/useDexActions.js](simple-dex/frontend/src/hooks/useDexActions.js) | Siklus transaksi: kirim, tunggu receipt, lalu invalidate. Bahan untuk argumen tiga keadaan di 5.18. |
| [simple-dex/frontend/src/hooks/usePairReads.js](simple-dex/frontend/src/hooks/usePairReads.js) | Cara lo membaca state kontrak dan menyusun cache key. |
| [defi-staking/frontend/src/hooks/usePoolReads.js](defi-staking/frontend/src/hooks/usePoolReads.js) | Stack yang sama dengan mereka, wagmi 3.7 dan TanStack Query 5.102, terverifikasi dari package.json. Bisa dibicarakan sebagai "saya sudah hidup dengan alat ini". |
| [governance-dapp/devlog/2026-09-27-subgraph-the-graph.md](governance-dapp/devlog/2026-09-27-subgraph-the-graph.md) | Kenapa event satu-satunya sumber kebenaran untuk daftar proposal, dan apa yang mahal kalau pakai `eth_getLogs` manual. Ini bahasa indexer, dan tim data berbicara dengan bahasa ini. |

### 11.2 Lapis 2: bagus untuk kredibilitas, maksimal satu kalimat masing-masing

| Materi | Kenapa |
|---|---|
| [simple-dex/docs/security-review.md](simple-dex/docs/security-review.md) | 10 temuan, menunjukkan lo berpikir adversarial. Budaya di perusahaan crypto sangat menghargai ini. |
| [simple-dex/docs/uniswap-v2-research.md](simple-dex/docs/uniswap-v2-research.md) | Tabel impermanent loss yang lo hitung sendiri dari rumus. Berguna kalau pembicaraan masuk ke LP. |
| [docs/how-audit-contests-work.md](docs/how-audit-contests-work.md) dan [security/AUDIT-TEMPLATE.md](security/AUDIT-TEMPLATE.md) | Kalau pembicaraan masuk ke security culture. Jangan dipaksakan. |
| [ccip-crosschain/SPEC.md](ccip-crosschain/SPEC.md) | Cross-chain disebut recruiter sebagai fokus org. Tapi ini proyek kontrak, bukan frontend, jadi sebut sebagai minat, bukan portofolio utama. |
| [docs/l2-deep-dive.md](docs/l2-deep-dive.md) | Unichain itu OP Stack. Cukup satu kalimat siap pakai kalau dia menyebut Unichain. |

### 11.3 Lapis 3: jangan dibawa

nft-minting-dapp, foundry-practice, cyfrin-course, Ethernaut, PROBLEM-BOOK, dan isi kontrak defi-staking seperti rewardPerToken. Semua ini materi latihan. Di call 30 menit, menyebutnya membuat lo terdengar seperti orang yang sedang kursus.

### 11.4 Tiga momen di mana materi ini berguna, dan tidak lebih

1. Saat ditanya kenapa tertarik crypto atau Uniswap. Pakai 5.16, terutama kalimat soal routing dan slippage.
2. Saat pembicaraan masuk ke data layer. Pakai 5.18. Ini panggung terbaik lo.
3. Saat ditanya bagaimana lo belajar atau bekerja tanpa arahan. Pakai 5.17.

Kalau dia menyebut Unichain dan lo perlu satu kalimat:

> "I've read up on the OP Stack side, mostly on how fraud proofs and the withdrawal window shape what an interface can promise about finality. That's the part that changes UX, not the throughput numbers."

Di luar tiga momen itu, biarkan materi ini diam. Kelebihan menyebut istilah crypto justru membuat interviewer mengira lo ingin jadi protocol engineer, dan itu bukan posisi yang sedang dibuka.
