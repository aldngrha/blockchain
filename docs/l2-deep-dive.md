# Layer 2 Deep Dive: Optimistic vs ZK Rollup

> Task roadmap: 24 Okt 2026. Ini deep dive yang dijanjikan di `simple-dex/devlog/2026-10-06-deploy-l2.md` ("Deep dive ZK dan zkSync testnet ada di roadmap 24 Okt").
>
> Devlog itu nutup bagian kualitatif dasar: kenapa L2 murah, dan kenapa angka gas L1 vs L2 sengaja tidak ditulis tanpa pengukuran. Dokumen ini nggak ngulang itu. Isinya yang lebih dalam: cara kerja pembuktian, trade-off nyata buat developer, dan cara baca tingkat kematangan L2.
>
> Sumber angka: Datawallet, "ZK Rollups vs Optimistic Rollups" (6 Agt 2026), yang datanya dari L2Beat. Angka itu snapshot awal Agustus 2026, bukan hasil ukur sendiri. Semua ditandai tanggalnya biar kelihatan kalau nanti basi.

## 1. Masalah yang diselesaikan rollup

Ethereum L1 mahal bukan karena komputasi, tapi karena setiap node harus menyimpan dan mengeksekusi semua transaksi. Rollup memindahkan eksekusi ke luar L1, lalu memposting hasilnya plus data transaksi kembali ke L1.

Dua konsekuensi penting:

- **Keamanan masih milik L1**, karena data-nya ada di L1. Siapa pun bisa merekonstruksi state L2 dari data itu, jadi kalau operator hilang, dana tetap bisa diambil lewat mekanisme escape.
- **Biaya turun drastis** karena yang dibayar cuma slot data di L1, bukan eksekusi penuh.

Yang membedakan dua keluarga rollup bukan tujuan, tapi **cara membuktikan bahwa batch yang diposting itu benar**.

## 2. Optimistic rollup: asumsi jujur dulu, sengketa belakangan

Batch diposting dengan asumsi benar. Kalau ada yang curang, siapa pun bisa mengajukan **fraud proof** selama dispute window, biasanya **7 hari**, dan L1 akan mengeksekusi ulang komputasi yang disengketakan untuk memutuskan siapa yang benar.

- **Kelebihan:** desainnya sederhana dan murah dijalankan, karena operasi normal tidak butuh generate proof apa pun.
- **Kelemahan:** pengguna yang menarik dana lewat bridge kanonik harus menunggu penuh masa sengketa 7 hari.
- **Asumsi tambahan yang sering dilupakan:** butuh **minimal satu pihak jujur yang mengawasi** dan siap mengajukan fraud proof sebelum window tutup. Kalau tidak ada yang mengawasi, batch curang bisa lolos. Ini yang tidak dimiliki ZK rollup.

Contoh: Base, Arbitrum One, OP Mainnet. Ketiganya optimistic, dan sampai awal Agustus 2026 mereka pegang mayoritas nilai di ekosistem.

## 3. ZK rollup: buktikan dulu, baru settle

Setiap batch disertai **validity proof**, sepotong data kriptografis kecil yang membuktikan semua transaksi di batch itu mengikuti aturan. L1 cukup memverifikasi proof-nya, tidak perlu mengeksekusi ulang.

- **Kelebihan:** finalitas keras tercapai cepat. Withdraw lewat bridge kanonik selesai begitu proof terverifikasi, biasanya **dalam hitungan menit sampai beberapa jam**, bukan seminggu.
- **Kelebihan kedua:** tidak butuh asumsi pengawas jujur. Selama sistem proof dan kontrak verifier-nya benar, state invalid tidak bisa difinalisasi.
- **Kelemahan:** biaya proving. Setiap batch harus dibayar proof-nya, dan dulu ini mahal. Sumber yang gue baca bilang biaya prover sudah turun sekitar **45 kali** seiring matangnya hardware dan sistem proving.
- **Kelemahan kedua:** keamanannya bergantung pada soundness sistem proof itu sendiri. Beberapa prover berbasis STARK mengandalkan konjektur matematis yang masih jadi bahan tekanan riset, dan itu sebabnya Ethereum mensyaratkan provable security 128-bit sebelum zkEVM menyentuh konsensus.

Contoh: Starknet, Linea, ZKsync Era, Scroll, Lighter.

## 4. Tabel perbandingan

| Dimensi | Optimistic | ZK |
|---|---|---|
| Validasi state | settle dulu, fraud proof menyusul | proof diverifikasi sebelum settle |
| Withdraw bridge kanonik | tunggu penuh dispute window, biasanya 7 hari | menit sampai jam |
| Asumsi keamanan | butuh pengawas jujur + proof system | hanya proof system dan verifier |
| Biaya operasional | tidak ada biaya proving | bayar proof setiap batch |
| Kompatibilitas EVM | pakai client Ethereum hampir apa adanya | dulu tertinggal, sekarang sudah tipis selisihnya |
| Kedalaman ekosistem | paling dalam | tertinggal, kecuali di use case tertentu |

Catatan yang sering bikin salah paham: **kompatibilitas EVM sudah bukan alasan lagi buat milih optimistic.** zkEVM modern sudah nutup hampir semua selisihnya. Yang masih jadi pembeda nyata: waktu finalitas, asumsi keamanan, dan kedalaman likuiditas.

## 5. Angka pasar (snapshot awal Agustus 2026)

Dari data L2Beat yang dikutip sumber:

- Total nilai yang diamankan jaringan scaling Ethereum: **$33,4 miliar**, dan **$26,8 miliar** di antaranya ada di rollup yang memposting data ke Ethereum.
- Pasar dua rantai: **Base $11,6 miliar** dan **Arbitrum One $10 miliar**, dua-duanya optimistic, dan kalau digabung sekitar **80%** dari seluruh nilai rollup.
- Rantai validity-proven terbesar justru bukan yang paling terkenal: **Mantle $1,2 miliar** (setelah pindah dari fraud proof), lalu **Lighter $849 juta**, lalu **Starknet $370 juta**.
- Aktivitas bisa kebalikan dari nilai: **Lighter** memproses sekitar **875 user operation per detik**, sementara **Base** sekitar **94**. Di use case yang butuh finalitas cepat, ZK menang.

Angka ini masuk akal dijelaskan begini: nilai ngumpul di tempat likuiditasnya udah dalam (optimistic, duluan rame), sementara aktivitas tinggi nyari finalitas cepat (ZK, atau appchain spesifik).

## 6. Cara baca kematangan L2: L2Beat stage

Ini bagian yang paling berguna buat developer, dan yang paling sering dilewatkan orang yang cuma hafal "optimistic vs ZK".

L2Beat menilai tiap rollup pakai sistem stage:

- **Stage 0:** tim masih pegang multisig yang bisa menimpa sistem. Artinya secara praktis masih ada trusted party.
- **Stage 1:** proof system jalan tanpa izin, pengguna bisa keluar ke Ethereum tanpa kooperasi operator, dan upgrade punya delay yang memberi waktu pengguna pergi.
- **Stage 2:** grade desentralisasi final. Yang sampai sini cuma sedikit.

Posisi awal Agustus 2026:

| Stage 1 | Stage 0 |
|---|---|
| Base, Arbitrum One, OP Mainnet, Ink, Unichain, Starknet | Linea, ZKsync Era, Scroll |

**Pelajaran paling penting dari tabel itu:** ZKsync Era, Linea, dan Scroll secara arsitektur punya proof yang lebih kuat, tapi masih Stage 0. Artinya **arsitektur proof saja belum menentukan keamanan praktis.** Kalau operator masih bisa menimpa sistem lewat multisig, keunggulan kriptografis itu belum kepakai. Ini yang bikin urutan prioritasnya jadi: stage dulu, baru jenis proof.

L2Beat melacak 23 rollup yang sudah matang, dan hanya rantai kecil seperti Facet dan Aztec yang sudah Stage 2.

## 7. Batas antara dua kubu ini sedang melebur

Ini perkembangan yang bikin label "optimistic vs ZK" mulai kurang relevan:

- **Base** sedang menambah ZK proof lewat upgrade Azul. Pakai SP1 dari Succinct, desain multi-proof: kalau kedua proof setuju, finalitas withdraw turun dari **7 hari jadi 1 hari**. Timnya menyebutnya tahap antara menuju ZK penuh.
- **Mantle dan Taiko** sudah benar-benar pindah dan sekarang settle pakai validity proof, padahal lahir sebagai rantai optimistic.
- **OP Succinct** memungkinkan rantai OP Stack menukar fraud proof jadi validity proof tanpa membangun ulang infrastrukturnya.
- **BOB**, rollup di ekosistem Bitcoin, pakai sistem hybrid: sengketa fraud diselesaikan dengan satu ZK proof, bukan challenge game panjang.

Sumbernya mencatat tidak ada contoh rantai validity-proven yang balik ke fraud proof. Jadi label itu makin mendeskripsikan **titik awal**, bukan arah tujuan.

## 8. Ethereum sendiri sedang jadi ZK

Sinyal terkuat: Ethereum mengerjakan ini di base layer-nya sendiri.

- Ethereum Foundation menargetkan **99% block mainnet bisa dibuktikan di bawah 10 detik**, cukup cepat supaya validator memverifikasi proof alih-alih mengeksekusi ulang.
- Target itu **tercapai Desember 2025**. Latensi proving turun dari **16 menit ke 16 detik**, biaya turun **45 kali**.
- **Fusaka** (Desember) memperkenalkan PeerDAS, yang bikin node memverifikasi ketersediaan data lewat sampling, bukan mengunduh semuanya. Fork blob lanjutannya melipatgandakan kapasitas data yang dipakai rollup.
- Fork berikutnya, **Glamsterdam**, merestrukturisasi produksi block supaya prover dapat beberapa detik buat generate proof, bukan satu dua detik.

Implikasinya: begitu Ethereum memverifikasi validity proof secara native, sistem fraud proof mulai terlihat seperti teknologi transisi. Semua stack optimistic besar sudah menaruh ZK proving di roadmap masing-masing.

## 9. Bridging: bagian yang paling berisiko

Ini sering luput dari pembahasan "rollup A vs rollup B", padahal ini yang paling sering jadi tempat kehilangan dana.

- **Bridge kanonik** itu bagian dari protokol rollup. Aman sesuai asumsi rollup-nya, tapi lambat (7 hari di optimistic, jam di ZK).
- **Bridge pihak ketiga** memberi likuiditas instan supaya lo tidak perlu nunggu. Yang lo tukar adalah **kecepatan dengan asumsi keamanan**: lo sekarang percaya pada operator bridge itu, bukan pada rollup-nya.

Pola yang berulang di insiden bridge bukanlah bug di rollup, tapi bug di kontrak bridge atau kunci yang dicuri. Buat latihan: kalau lo butuh pindah dana antar L2, bridge kanonik untuk jumlah besar, pihak ketiga cuma kalau memang tidak bisa nunggu.

## 10. Sisi Bitcoin (catatan pinggir)

Rollup tidak berhenti di Ethereum. Bitcoin secara historis susah karena scripting-nya tidak bisa memverifikasi proof kompleks. **BitVM** mengubah itu: sengketa fraud bisa diselesaikan di Bitcoin tanpa perubahan protokol, dan itu jadi dasar generasi pertama bridge Bitcoin yang trust-minimized. **Citrea** mengubah idenya jadi produksi akhir Januari sebagai ZK rollup pertama yang live di Bitcoin, memakai zkEVM berbasis RISC Zero dan menuliskan proof terkompresi ke Bitcoin, yang sekaligus jadi lapisan settlement dan data-nya. Bridge-nya, Clementine, cuma butuh satu peserta jujur supaya withdraw aman. Ekosistemnya masih kecil, tapi pertanyaan desainnya sama dengan yang Ethereum sudah lewati bertahun-tahun sebelumnya.

## 11. Buat lo yang mau deploy

Poin praktis, mengingat `simple-dex` sudah pernah deploy ke Arbitrum Sepolia dan sekarang mau coba zkSync:

1. **Deploy ke L2 EVM-equivalent praktisnya "Ethereum dengan biaya lain".** Tidak ada perubahan kode. Ini sudah dibuktikan sendiri waktu deploy `simple-dex`.
2. **Yang berubah cuma tiga: biaya, finalitas withdraw, dan tooling.** Kalau dApp lo tidak menyentuh tiga itu, pilihan L2 hampir tidak berpengaruh ke kode.
3. **Cek stage L2-nya sebelum percaya.** Jangan pilih rantai cuma karena arsitekturnya kelihatan lebih canggih.
4. **Tooling zkSync beda.** Butuh `foundry-zksync` (binary `forge-zksync`), bukan forge biasa. Di mesin ini belum terinstall, jadi ini langkah manual.
5. **Verifikasi kontrak di explorer L2** sering butuh API key terpisah dari Etherscan.

### Langkah manual deploy zkSync Era testnet (belum dijalankan)

```bash
# 1. Install foundry-zksync (ini yang belum ada di mesin)
foundryup-zksync

# 2. Kompilasi pakai compiler zksolc
forge build --zksync

# 3. Deploy ke zkSync Era Sepolia (butuh private key khusus, JANGAN key dana besar)
forge create src/DexPair.sol:DexPair \
  --rpc-url https://sepolia.era.zksync.dev \
  --private-key $ZKSYNC_DEPLOYER_KEY \
  --zksync
```

Yang **belum** dikerjakan dan sengaja tidak ditulis sebagai hasil: deploy zkSync-nya sendiri, address kontraknya, dan perbandingan gas L1 vs L2. Butuh faucet dan key, dan tidak ada satu pun angka yang boleh ditulis sebelum benar-benar diukur.

## Ringkasan satu paragraf

Optimistic rollup menang di adopsi (Base dan Arbitrum pegang mayoritas nilai) karena sederhana dan murah dijalankan, tapi menukar itu dengan withdraw 7 hari dan asumsi ada pengawas jujur. ZK rollup menang di argumen finalitas dan asumsi keamanan, tapi masih tertinggal di ekosistem dan sebagian masih Stage 0. Garis pemisahnya sedang melebur: Base menambah ZK proof, Mantle dan Taiko sudah pindah, Ethereum sendiri menargetkan jadi sistem ZK terverifikasi terbesar. Buat developer, urutan prioritas yang paling berguna bukan jenis proof, tapi **stage desentralisasi, waktu finalitas, dan kedalaman likuiditas**.
