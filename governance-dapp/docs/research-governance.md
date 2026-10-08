# Research Governance: Compound Bravo vs OpenZeppelin Governor

> Task roadmap (Min 20 Sep): "Research untuk Project 2. Baca Compound Governor Bravo source code. Pahami full governance lifecycle: propose -> voting period -> timelock -> execute. Identifikasi semua parameter: quorum, threshold, voting period."

Catatan ini acuan buat SPEC. Sumber utama: source code Compound Bravo (compound protocol, kontrak `GovernorBravoDelegate.sol`) dan OpenZeppelin Contracts v5.4 (`governance/`), yang dua-duanya gw baca langsung dari source, bukan dari tutorial.

---

## 1. Lifecycle: propose -> vote -> queue -> execute

Semua sistem Governor modern (Bravo maupun OZ) ngikutin lifecycle yang sama:

```
                 propose()
                    │
                    ▼
   ┌───────── Pending ─────────┐
   │  (menunggu votingDelay)   │      cancel() oleh proposer
   ▼                           ▼   (hanya saat Pending di OZ)
 Active ────(vote window)──── Canceled
   │  vote: FOR/AGAINST/ABSTAIN
   │
   ├─ quorum gak tercapai ────────────────► Defeated (dead end)
   ├─ FOR <= AGAINST ─────────────────────► Defeated (dead end)
   │
   ▼ Succeeded
  queue()  ──── timelock minDelay berjalan ────►  execute()
   │                                                │
   │                                                ▼
   └─ gak dieksekusi sampai Expired ──────►  Executed (dead end)
```

Detail per fase:

- **propose()**: propose bikin proposal dari daftar operasi: `targets[]`, `values[]`, `calldatas[]` + `description`. Proposal id = hash dari semua operasi itu. Di Bravo, snapshot voteStart = block sekarang + votingDelay. Cek threshold: proposer harus punya voting power >= proposalThreshold.
- **vote()**: sementara `Active` (setelah snapshot, sebelum deadline). Bobot vote diambil dari snapshot, bukan saldo sekarang. 3 pilihan ala Bravo: `Against=0, For=1, Abstain=2`. Abstain ikut quorum tapi gak ikut majority.
- **queue()**: proposal yang Succeeded masuk timelock: operasi di-schedule, gak bisa dieksekusi sebelum `minDelay`. Ini titik paling penting buat keamanan: ada jeda antara "suara sudah menang" dan "dana gerak".
- **execute()**: setelah delay lewat, siapa pun boleh mengeksekusi. Kalau terlalu lama dibiarkan (di Bravo: `GRACE_PERIOD` 14 hari), proposal jadi `Expired`.

Bedanya dengan project 1 (staking): di sini state machine-nya penuh jebakan. Snapshot itu block-based, timelock itu timestamp-based, dan quorum dihitung terhadap supply LAMAU. Semua ini jadi sumber bug kalau gak dibaca source-nya.

## 2. Compound Bravo: struktur dan keputusan desainnya

Bravo (dan pendahulunya Alpha) adalah implementasi referensi. Poin penting yang gw catat dari source-nya:

- **Sistem delegate + checkpoint ala COMP**: voting power disimpan sebagai checkpoint `(blockNumber, votes)` per address. `getPriorVotes(addr, blockNumber)` melakukan binary search di checkpoint, dan WAJIB `blockNumber < current`, karena di EVM lo gak bisa baca state masa depan/dead-reckon state block sekarang di tengah transaksi.
- **Voting power = delegated balance**, bukan balance. Token yang gak di-delegate itu "mati" secara politis.
- **Quorum Bravo**: `quorumVotes = 2.5% dari supply` (dari ` GovernorBravoDelegate` real Compound: 250_000 COMP dari 10 juta). Konstanta statis, di-hardcode di impl.
- **Proposal threshold Bravo**: 25_000 COMP (0.25% supply) buat boleh propose. Ini filter anti-spam.
- **votingDelay Bravo = 1 block** di implementasinya lama, lalu Compound naikkan ke 13.146 block (2 hari) setelah beberapa insiden. Pelajaran: delay kecil = pemilik token bisa beli voting power PASANG proposal di block yang sama (flash-loan governance attack).
- **`castVoteWithReason`** ada sejak Bravo: alasan vote dikirim on-chain, berguna buat indexer.
- **Whitelist/cancel oleh guardian**: Bravo punya `cancel()` yang bisa dipanggil guardian (multisig) untuk proposal jahat. Fitur kontroversial: centralization untuk safety. OZ versi 5 default-nya cuma proposer bisa cancel saat Pending, dan guardian-nya opsional.

## 3. OZ Governor (v5): apa yang berubah dari Bravo

Gw baca source v5.4 langsung (`lib/openzeppelin-contracts/contracts/governance/`). Perbedaan struktural:

| Aspek | Bravo | OZ Governor v5 |
|---|---|---|
| Monolitik | 1 kontrak besar (GovernorBravoDelegate) | Framework modul: core `Governor` + extension mixin |
| Clock | block number (hardcoded) | ERC-6372 `clock()`: block number atau timestamp, ngikutin token |
| Queue/execute | `queue`/`execute` publik di impl | internal `_queueOperations` / `_executeOperations`, modul timelock yang override |
| Param | getter/setter ala timelock sendiri | `GovernorSettings`, diubah lewat proposal sendiri (`onlyGovernance`) |
| Counting | hardcode for/against/abstain | `GovernorCountingSimple` (atau Fractional, Overridable, dst) |
| Quorum | konstanta statis | `GovernorVotesQuorumFraction`: % dari PAST total supply, bisa diupdate lewat proposal |
| Access timelock | timelock sebagai admin terpisah | `GovernorTimelockControl`: timelock pegang dana/roles, governor yang propose |

Modul yang gw pilih buat project 2 dan alasannya:

1. **GovernorSettings**: votingDelay/votingPeriod/threshold bisa diubah lewat proposal. Default-nya gak boleh diubah EOA langsung, cek `onlyGovernance`.
2. **GovernorCountingSimple**: for/against/abstain ala Bravo. Cukup buat demo. (Alternatif Fractional: bisa split bobot, overkill.)
3. **GovernorVotesQuorumFraction**: quorum dinamis % dari past supply. Ini yang bikin quorum ikut kehilangan/menang supply.
4. **GovernorTimelockControl**: eksekusi lewat TimelockController. Governor gak pegang dana, timelock yang pegang.

## 4. Parameter dan trade-off-nya

| Parameter | Nilai project 2 | Trade-off |
|---|---|---|
| Quorum | 4% dari past supply | Terlalu rendah: 1 whale bisa pass proposal. Terlalu tinggi: gak pernah ada quorum dan governance mati (apathy). Compound 2.5%, Uniswap 4%, ENS 1%. 4% = angka Uniswap, cukup tinggi buat mencegah spam di supply 1M token. |
| Voting delay | 1 hari (7200 block @ 12 s) | Delay sejak propose sampai snapshot. Semakin panjang, semakin kecil risiko flash-loan governance attack (beli token dalam 1 tx, vote, jual). Delay 0 = rentan penuh. |
| Voting period | 1 minggu (50400 block) | Lama jendela voting. Terlalu pendek: voter di zona waktu lain gak sempat. Terlalu panjang: keputusan gak ketutup. Umumnya 3-7 hari. |
| Proposal threshold | 0 | Kita set 0: siapa pun boleh propose. Trade-off: papan proposal bisa di-spam. Di protokol nyata sebaiknya > 0 (misal 0.1% supply). Karena supply 1M dan demo, 0 lebih gampang buat dites. |
| Timelock minDelay | 1 hari | Jeda antara queue dan execute. Ini window buat user keluar dana (exit window) kalau ada proposal jahat yang lolos vote. Compound pakai 2 hari. 1 hari cukup buat demo tapi prinsipnya tetap. |

Catatan tentang quorum di OZ: `GovernorVotesQuorumFraction.quorum(timepoint)` = `getPastTotalSupply(timepoint) * numerator / denominator`. Jadi quorum dihitung terhadap supply DI SNAPSHOT, bukan supply sekarang. Kalau ada burn setelah proposal dibuat, quorum proposal itu gak ikut turun. Ini penting dan sering disalahpahami.

## 5. Kenapa butuh timelock (dan kenapa dana ada di timelock, bukan di governor)

Skema kepemilikan yang benar:

```
  pemegang token ──vote──► Governor ──queue/execute──► TimelockController ──execute()──► Treasury / kontrak lain
     (vote)                 (logika voting)              (jeda + roles)                  (dana)
```

Alasan timelock wajib:

1. **Exit window.** Proposal jahat yang lolos vote tetap harus nunggu `minDelay`. Di jeda itu, user yang gak setuju bisa keluar dana dari protokol. Tanpa timelock, eksekusi = instan = rug pull yang legal.
2. **Proteksi dari governance attack multi-langkah.** Proposal pertama sering cuma "penyerang dapat kontrol parameter". Dengan timelock, perubahan aneh kelihatan sebelum aktif.
3. **Pemisahan hak eksekusi.** Timelock pegang `PROPOSER_ROLE`/`CANCELER_ROLE`/`EXECUTOR_ROLE` dengan AccessControl. Governor propose + cancel; eksekutor dibuka ke `address(0)` (siapa pun boleh mengeksekusi, ini gak meningkatkan risiko karena eksekusi cuma bisa buat operasi yang sudah dischedule).

Pola "chicken and egg" yang gw temukan waktu rancang deployment: timelock butuh address governor sebagai PROPOSER, tapi governor butuh address timelock di constructor. Solusi standar: deploy timelock dulu dengan deployer sebagai admin sementara, deploy governor, grant roles, lalu deployer `renounceRole(DEFAULT_ADMIN_ROLE)`. Setelah itu TIDAK ADA jalan pintas lagi: semua perubahan harus lewat proposal.

## 6. Catatan ERC20Votes checkpoint

Perbedaan `ERC20Votes` dengan ERC-20 biasa, dari source OZ v5:

- Voting power disimpan di `Checkpoints.Trace208` per account: daftar `(blockNumber, votes)` yang selalu naik.
- `_update` ERC-20 di-override supaya setiap transfer/mint/burn juga memindahkan voting units. Ini yang bikin di OZ v5 lo wajib menulis override `_update(address,address,uint256)` yang manggil `super._update` dua-duanya (ERC20 + ERC20Votes).
- **Balance != voting power.** Voting power cuma aktif setelah `delegate()`. Transfer ke address yang gak pernah delegate itu melempar voting power ke address yang gak bisa pakai (dihancurkan sampai dia delegate). Frontend harus kasih peringatan soal ini.
- `getPastVotes(addr, timepoint)` dan `getPastTotalSupply(timepoint)` valid cuma untuk `timepoint < clock()`. Di ERC-20 mode default (block number), lookup di block sekarang itu revert (`ERC5805FutureLookup`). Governor ambil bobot vote di `proposalSnapshot`, jadi delegate SETELAH propose gak memengaruhi proposal yang sudah jalan.
- Supply cap: `ERC20ExceededSafeSupply` kalau totalSupply lewat `2^208 - 1`, karena checkpoint pakai uint208. Untuk supply 1M token ini jauh dari limit.

## 7. Kesimpulan buat project 2

1. Pakai OZ v5 stack (5 mixin) + Treasury sederhana yang hanya bisa dipanggil timelock. Gak ada alasan menulis Governor dari nol, tapi WAJIB paham override matrix-nya.
2. Parameter: quorum 4%, delay 7200 block, period 50400 block, threshold 0, timelock 1 hari. Angka test dikecilkan, angka deploy sesuai roadmap.
3. Wiring roles: PROPOSER + CANCELER ke governor, EXECUTOR ke address(0), admin deployer renounce. Treasury pegang ETH, timelock yang nge-execute.
4. Semua yang di atas harus ketulis di test, bukan cuma di SPEC: full flow + negative paths (defeated, execute tanpa queue, vote sebelum active, non-delegate weight 0).
