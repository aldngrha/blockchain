# 25 Okt 2026 - CCIP: Cross-Chain Message

> Task roadmap: "Chainlink CCIP (Cross-Chain Interoperability Protocol) intro. Buat simple cross-chain message dari Sepolia ke Arbitrum Sepolia pakai CCIP. Pahami: bridge risk, why cross-chain is hard."
>
> Catatan: ini re-run dari batch 10-27 Okt. Vault punya catatan topik ini di Jul 2026, tapi artefaknya tidak ada, jadi dibangun ulang dari nol di repo ini.

## Apa yang dikerjakan

- Tulis `SPEC.md` dulu: scope, invariants I-1 sampai I-6, edge cases E1 sampai E11, dan bagian keamanan khusus receiver CCIP.
- Implementasi `CrossChainSender` (kirim data-only message, hitung fee, refund kelebihan) dan `MessageReceiver` (validasi router + allowlist sumber, simpan message terakhir).
- Vendor interface dan struct CCIP (`Client`, `IRouterClient`, `IAny2EVMMessageReceiver`) mengikuti API reference v1.5.1, supaya project self-contained dan bisa dites offline.
- Tulis `MockRouter` yang bisa deliver message dalam satu transaksi, jadi jalur sender -> router -> receiver bisa dites lokal tanpa jaringan.
- 24 test, termasuk 3 fuzz test. Semua hijau.
- `script/DeployCCIP.s.sol` + smoke test deploy di anvil lokal, terverifikasi lewat `cast`.

## Masalah & Solusi

### 1. Natspec bikin compile gagal karena karakter `@`

- Masalah: `forge build` gagal dengan `Documentation tag @chainlink/contracts-ccip not valid for contracts` di `src/libraries/Client.sol`.
- Kenapa: di dalam komentar natspec (`///`), Solidity menganggap `@kata` sebagai documentation tag. Jadi nama paket npm `@chainlink/contracts-ccip` yang ditulis di komentar dibaca sebagai tag `@chainlink`.
- Solusi: tulis nama paketnya tanpa karakter `@` di komentar natspec. Perilakunya tidak berubah, cuma teks komentarnya.
- Pelajaran: komentar natspec itu bukan teks bebas. Kalau nanti nulis dokumentasi kontrak yang menyebut handle atau nama paket, ini bakal kejadian lagi.

### 2. Error yang dideklarasikan di interface tidak bisa diakses lewat nama kontrak implementasinya

- Masalah: `abi.encodeWithSelector(MockRouter.UnsupportedDestinationChain.selector, ...)` gagal dengan `Member not found or not visible after argument-dependent lookup in type(contract MockRouter)`.
- Kenapa: `UnsupportedDestinationChain` dideklarasikan di `IRouterClient`. Kontrak yang mengimplementasikan interface mewarisi errornya untuk keperluan revert, tapi nama itu tidak jadi anggota `type(MockRouter)` untuk lookup statis.
- Solusi: referensikan lewat interface asalnya, `IRouterClient.UnsupportedDestinationChain.selector`.
- Pelajaran: di test Foundry, `expectRevert` untuk custom error yang berasal dari interface harus menunjuk interface-nya, bukan kontrak implementasinya. Errornya tetap muncul benar, cuma cara menyebutnya yang beda.

### 3. Refund jadi salah alamat kalau overload dipanggil lewat `this.`

- Masalah: rancangan awal bikin overload pendek `sendMessage(uint64, address, bytes)` dengan cara memanggil `this.sendMessage{value: msg.value}(...)`.
- Kenapa: `this.f()` itu external call ke diri sendiri. Di dalam frame itu, `msg.sender` berubah jadi `address(this)`. Akibatnya, kalau nanti ada refund, `payable(msg.sender).call` mengirim dana ke kontrak sendiri, bukan ke user yang memanggil.
- Solusi: kedua overload masuk ke satu fungsi `private _send(...)`, jadi `msg.sender` asli tidak pernah hilang. Ini dicatat sebagai design note di natspec kontraknya supaya tidak "diperbaiki" balik jadi `this.`.
- Pelajaran: pola `this.f()` untuk reuse kode kelihatan rapi tapi mengubah identitas pemanggil. Untuk fungsi yang menyentuh dana atau refund, itu bukan pilihan.

### 4. Mock router harus bisa memalsukan chain asal, kalau tidak testnya tidak menguji apa pun

- Masalah: test `test_Receiver_TrustedSenderIsPerChain` awalnya lulus-tidak-revert, padahal maksudnya menguji bahwa trust itu per chain. Test-nya sendiri yang salah: `setUp` sudah mentrust `(REMOTE_CHAIN, sender)`, jadi menambah trust untuk chain lain tidak menghapus yang lama. Dan mock-nya selalu mengirim `sourceChainSelector` yang sama, jadi tidak ada cara menyimulasikan message dari chain lain.
- Kenapa: bug ada di test dan di mock, bukan di kontrak. Mock yang tidak bisa memalsukan `sourceChainSelector` membuat properti "trust per chain" tidak bisa diuji sama sekali.
- Solusi: tambah `sourceChainSelectorForDelivery` di `MockRouter` plus setter-nya, lalu tulis ulang testnya: set source selector ke chain lain, expect revert `UntrustedSender`, baru trust chain itu, lalu expect sukses.
- Pelajaran: test yang hijau belum berarti yang diuji benar. Kalau sebuah properti tidak bisa dinyatakan sebagai skenario di test, kemungkinan mock-nya yang kurang mampu, bukan propertinya yang tidak penting.

### 5. Foundry script tidak bisa konek ke anvil lokal karena proxy environment

- Masalah: `forge script --rpc-url http://127.0.0.1:8549` gagal dengan `HTTP error 502 with body: upstream connect failed: Connection refused`.
- Kenapa: environment sesi ini punya `HTTP_PROXY` dan `HTTPS_PROXY` yang menunjuk ke proxy lokal. Request ke `127.0.0.1:8549` ikut dilewatkan ke proxy itu, padahal anvil-nya ada di mesin yang sama dan tidak butuh proxy.
- Solusi: jalankan dengan proxy di-unset: `env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy forge script ...`.
- Pelajaran: kalau RPC lokal tiba-tiba gagal konek padahal anvil jalan dan `curl` biasa berhasil, cek variabel proxy sebelum curiga ke anvil atau ke script.

### 6. Anvil yang dijalankan di dalam satu tool call mati saat call itu selesai

- Masalah: `anvil -p 8549 &` di dalam satu perintah Bash lalu tidur 3 detik: `eth_chainId` berhasil, tapi perintah berikutnya sudah `Connection refused`.
- Kenapa: proses latar yang di-spawn di dalam satu tool call ikut dimatikan saat tool call itu selesai.
- Solusi: jalankan anvil sebagai task latar yang persisten, baru jalankan deploy di tool call terpisah.
- Pelajaran: ini sama dengan jebakan port di devlog `simple-dex` (6 Okt), tapi beda penyebabnya. Di sana masalahnya tabrakan port, di sini siklus hidup proses. Dua-duanya berakhir sama: koneksi ditolak, dan yang salah bukan kontraknya.

## Status jujur

Done dan terverifikasi:

- `forge build` hijau.
- `forge test`: **24/24 hijau**, termasuk `testFuzz_ArbitraryPayloadRoundTrip`, `testFuzz_RefundIsExactlyTheSurplus`, dan `testFuzz_TwoSendersBothDeliver` (256 run masing-masing).
- Deploy lokal di anvil port 8549: `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL`, `deployments/31337.json` tertulis.
- Smoke test lewat `cast` terhadap kontrak yang sudah ter-deploy: `getRouter()` mengembalikan address router yang diberikan, `supportsInterface(0x85572ffb)` mengembalikan `true`, `defaultGasLimit()` mengembalikan `200000`, `messageCount()` mengembalikan `0`.

Belum / butuh aksi manual:

- Deploy ke Sepolia dan Arbitrum Sepolia BELUM dilakukan. Butuh RPC, address router dari CCIP directory resmi, chain selector, dana gas, dan private key khusus. Langkah lengkapnya ada di README.
- Verifikasi kontrak di explorer testnet belum.
- Transfer token lintas chain (`tokenAmounts` tidak kosong) di luar scope, dan mock sengaja revert untuk kasus itu.

Catatan soal angka yang tidak ditulis: fee CCIP, address router, dan chain selector tidak ada di dokumen ini karena semuanya bergantung pada chain dan waktu, dan belum ada yang diukur sendiri. Ambil dari CCIP directory resmi, jangan dari catatan ini.
