# 24 Sep 2026: Timelock Integration (Full Flow Test)

> Task roadmap: "Kam 24 Sep, BELAJAR, Project 2: TimelockController. Setup TimelockController: minimum delay, proposers (Governor), executors. Integration test: full governance flow end-to-end, propose -> vote -> queue -> execute. Test quorum tidak tercapai, vote kalah, cancel proposal."

## Apa yang dikerjakan

- Wiring lengkap di test mirror deploy script: timelock (proposers/executors kosong, admin deployer) -> grant PROPOSER + CANCELER ke governor -> EXECUTOR ke address(0) -> deployer renounce DEFAULT_ADMIN.
- `test/GovernorFullFlow.t.sol`: 16 test. Happy path propose -> vote FOR/FOR/AGAINST -> Succeeded -> queue -> warp > minDelay -> execute -> saldo treasury turun 1 ETH. Negative: quorum gak tercapai, AGAINST > FOR padahal quorum cukup, abstain ikut quorum, vote sebelum aktif, double vote, execute tanpa queue, execute sebelum delay, cancel.

## Masalah & Solusi

### Chicken-and-egg: timelock butuh governor, governor butuh timelock

- Masalah: `GovernorTimelockControl` minta address timelock di constructor, tapi grant `PROPOSER_ROLE` ke governor cuma bisa dilakukan sesudah governor ada, dan yang bisa grant harus admin timelock.
- Kenapa: dua kontrak saling refer. Deploy governor duluan butuh address timelock yang belum ada (dan sebaliknya).
- Solusi: deploy timelock dengan `admin = deployer` (proposers/executors kosong), deploy governor, grant roles, terakhir `renounceRole(DEFAULT_ADMIN_ROLE)`. Test `test_TimelockRoleWiring` assert: deployer gak punya admin lagi, timelock self-administered, roles di governor ada.
- Pelajaran: urutan deploy itu bagian dari desain keamanan. Admin sementara itu jembatan yang HARUS dibongkar di transaksi yang sama dengan wiring.

### `CANCELER_ROLE` double L: compile error yang memalukan tapi berguna

- Masalah: `timelock.CANCELER_ROLE()` error `Member "CANCELER_ROLE" not found`. Brief dan ingatan gw pakai satu L.
- Kenapa: OZ v5.4 mendeclare `keccak256("CANCELLER_ROLE")` (double L, mengikuti penulisan Inggris "canceller"), sementara banyak artikel nulis CANCELER.
- Solusi: grep source, ganti semua jadi `CANCELLER_ROLE` di test dan deploy script. Catat di deploy script sebagai komentar peringatan.
- Pelajaran: konstanta role itu magic bytes. Satu huruf salah = error compile (untungnya), bukan bug runtime. Kalau mau aman bandingkan dengan `cast keccak "CANCELLER_ROLE"`.

### forge 1.5.1: `expectRevert` dengan selector telanjang gak match error ber-args

- Masalah: `vm.expectRevert(IGovernor.GovernorUnexpectedProposalState.selector)` gagal padahal revert-nya jelas error itu: `Error != expected error: GovernorUnexpectedProposalState(...) != custom error 0x31b75e4d`. Raw revert data yang gw tangkap (via low-level call + `console.logBytes`) literally `0x31b75e4d...`.
- Kenapa: forge 1.5.1 membandingkan revert data secara penuh. Error ber-parameter menghasilkan revert data > 4 bytes, jadi expectation 4 byte telanjang gak pernah match. Project 1 aman karena semua custom error-nya zero-args.
- Solusi: semua expectRevert untuk error ber-args pakai encoding penuh:
  ```solidity
  vm.expectRevert(abi.encodeWithSelector(
      IGovernor.GovernorUnexpectedProposalState.selector, p.id,
      uint8(IGovernor.ProposalState.Pending),
      bytes32(uint256(1) << uint8(IGovernor.ProposalState.Active))
  ));
  ```
  Buat `TimelockUnexpectedOperationState` (butuh operationId yang dihitung dari salt governor), gw buat helper `_timelockUnexpectedState(p)` yang menghitung `hashOperationBatch(targets, values, calldatas, 0, bytes20(governor) ^ descriptionHash)` persis seperti `_timelockSalt` di OZ.
- Pelajaran: upgrade tooling bikin pattern lama basi. Ketahuan dari error message forge yang nampilin decoder dua sisi; kalau ragu, tangkap raw bytes.

### Bitmap sentinel `bytes32(0)` di duplicate propose

- Masalah: pertama ngira revert duplicate `propose` membawa bitmap Succeeded sebagai `expectedStates`. Test full-encoding tetap gagal, beda cuma di argumen ketiga: actual `0x00...00`, expected `0x...10`.
- Kenapa: `_propose` di core v5.4 mervert dengan `bytes32(0)` sebagai sentinel (bukan state-gated call), beda dengan `_validateStateBitmap` yang membawa bitmap beneran.
- Solusi: encode dengan `bytes32(0)` untuk duplicate propose, bitmap asli untuk queue/vote.
- Pelajaran: dua error yang sama bisa punya argumen ketiga beda tergantung jalur revert-nya. Baca call site-nya, jangan asumsikan dari nama error.

### `isOperationPending` di v5.4 mencakup state Ready

- Masalah: setelah warp melewati minDelay, gw worry `governor.state()` bakal balik `Canceled` (di `GovernorTimelockControl.state`, cabang else kalau bukan pending dan bukan done). execute bakal revert.
- Kenapa: v5.4 `TimelockController.isOperationPending` = `Waiting || Ready` (dibaca langsung dari source). Jadi operasi yang "siap dieksekusi" tetap dianggap pending, governor state tetap `Queued`, dan `execute` lolos validasi.
- Solusi: test happy path assert state `Queued` sebelum dan sesudah warp, lalu execute sukses. Gak perlu trik apa-apa.
- Pelajaran: cabang `else` yang tampak berbahaya di source itu sering gak terjangkau karena guard di atasnya lebih longgar dari dugaan. Selalu cek definisi fungsi yang dipanggil, bukan nama fungsinya.

## Status jujur

- Done: 16 test flow hijau (wiring + happy path + semua negative path yang diminta roadmap: quorum gak tercapai, vote kalah, cancel). Suite penuh 33 test hijau.
- Belum: deploy script + verifikasi anvil (Sen 28 Sep), subgraph (Min 27 Sep).
