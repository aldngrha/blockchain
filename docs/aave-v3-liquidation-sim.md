# Aave v3: Interest Rate Model dan Simulasi Likuidasi

> Task roadmap: **Jum 30 Okt 2026** ("Baca Aave v3 documentation dan whitepaper. Pahami lending pool, interest rate model, health factor, liquidation. Simulasikan skenario liquidation di spreadsheet: kapan posisi jadi tidak aman?").
>
> Roadmap minta spreadsheet. Supaya bisa diulang dan tidak hilang, isinya ditulis sebagai tabel plus rumus di sini, dengan cara reproduksi di section 7. Angka parameter DEX diambil dari bacaan on-chain yang sudah ada di [`defi-protocol-onepager.md`](defi-protocol-onepager.md). Angka yang **ilustratif** (bukan bacaan on-chain) ditandai eksplisit.
>
> Dokumen pendamping: [`defi-protocol-onepager.md`](defi-protocol-onepager.md) (cara kerja Aave v3 dalam satu halaman).

---

## 1. Interest rate model: dua lereng

Setiap reserve punya satu titik optimal pemanfaatan (`Uoptimal`). Suku bunga pinjaman (`borrowRate`) adalah fungsi dari utilization `U`:

```
kalau U <= Uoptimal:
    borrowRate = baseRate + slope1 * (U / Uoptimal)

kalau U > Uoptimal:
    borrowRate = baseRate + slope1 + slope2 * ((U - Uoptimal) / (1 - Uoptimal))
```

Yang perlu dilihat: fungsi ini **kontinu** di `Uoptimal` (kedua cabang menghasilkan `baseRate + slope1`), tapi turunannya patah. Itu disengaja. Di bawah optimal, bunga naik pelan supaya biaya pinjam wajar. Di atas optimal, bunga naik tajam supaya ada insentif kuat untuk menambah setoran atau melunasi utang, karena kalau utilization mendekati 100% hampir tidak ada likuiditas yang bisa ditarik depositor.

Suku bunga supply tidak dihitung terpisah, tapi diturunkan:

```
supplyRate = borrowRate * U * (1 - reserveFactor)
```

Artinya depositor dapat bagian dari bunga yang dibayar peminjam, proporsional terhadap porsi yang benar-benar dipinjam, dikurangi potongan protokol.

**Tabel ilustratif** dengan `baseRate = 0`, `slope1 = 3,8%`, `slope2 = 80%`, `Uoptimal = 80%`. Angka ini pola umum Aave, bukan bacaan on-chain untuk reserve tertentu:

| Utilization `U` | Cabang | `borrowRate` |
|---|---|---|
| 0% | bawah | 0,00% |
| 40% | bawah | 1,90% |
| 80% | batas | 3,80% |
| 90% | atas | 43,80% |
| 95% | atas | 63,80% |
| 99% | atas | 79,80% |
| 100% | atas | 83,80% |

Perhatikan lompatan dari 3,80% ke 43,80% hanya karena `U` naik dari 80% ke 90%. Inilah "kink" yang sering dibicarakan: di atas optimal, setiap 1% utilization menambah bunga jauh lebih besar daripada di bawahnya.

## 2. Health factor: rumus dan arti tiap suku

```
HF = (sum(jaminan_i * harga_i * LT_i)) / (sum(utang_j * harga_j))
```

- `LT` = liquidation threshold, bukan LTV. LTV adalah batas saat **meminjam**, LT adalah batas saat **bisa dilikuidasi**. LT selalu lebih besar, dan selisihnya adalah bantalan.
- `HF > 1` aman. `HF = 1` tepat di batas. `HF < 1` bisa dilikuidasi.
- HF tidak punya satuan. `HF = 1,38` artinya nilai jaminan yang dihitung dengan LT masih 1,38 kali nilai utang.

Yang menggerakkan HF:

| Kejadian | Efek ke HF |
|---|---|
| Harga jaminan naik | naik |
| Harga jaminan turun | turun |
| Bunga berjalan menambah utang | turun pelan, terus-menerus |
| Peminjam melunasi sebagian | naik |
| Peminjam menambah jaminan | naik |
| Harga aset utang naik (kalau utang bukan stablecoin) | turun |

Poin yang sering terlewat: **bunga membuat HF turun tanpa transaksi apa pun.** Posisi yang "aman" di 1,02 bisa jatuh di bawah 1 dalam beberapa hari kalau tidak dipantau, walaupun harga tidak bergerak.

## 3. Berapa penurunan harga sampai HF jatuh ke 1

Dengan jaminan awal $10.000 ETH dan `LT = 83,00%` (nilai WETH yang dibaca on-chain di one-pager: `8300`), utang dalam stablecoin:

| Utang | HF awal | Harga jaminan harus turun ke | Penurunan yang memicu likuidasi |
|---|---|---|---|
| $2.000 | 4,1500 | 24,10% dari harga awal | 75,90% |
| $4.000 | 2,0750 | 48,19% | 51,81% |
| $6.000 | 1,3833 | 72,29% | 27,71% |
| $8.050 (LTV maksimum 80,50%) | 1,0311 | 96,99% | **3,01%** |

Baris terakhir itu inti pelajarannya. Di LTV maksimum, bantalan antara 80,50% dan 83,00% cuma **2,5 poin persentase**, jadi harga cukup turun sekitar 3% untuk masuk zona likuidasi. Inilah kenapa orang tidak meminjam sampai LTV maksimum kalau mau aman, dan kenapa E-Mode (yang menaikkan LTV dan LT untuk aset berkorelasi) berbahaya kalau korelasinya patah.

Rumus yang dipakai, dengan `f` = faktor harga tersisa:

```
HF = 1  =>  f = utang / (nilai_jaminkan_awal * LT)
penurunan = 1 - f
```

## 4. Tabel HF untuk skenario harga turun

Jaminan $10.000, `LT = 83,00%`:

| Penurunan harga | HF (utang $6.000) | HF (utang $8.050) |
|---|---|---|
| 5% | 1,3142 | 0,9795 |
| 10% | 1,2450 | 0,9280 |
| 20% | 1,1067 | 0,8248 |
| 27,8% | 0,9988 | 0,7444 |
| 30% | 0,9683 | 0,7217 |
| 40% | 0,8300 | 0,6186 |

Dua kolom itu menunjukkan hal yang sama dari sisi berbeda: posisi dengan utang lebih besar tidak hanya lebih cepat likuidasi, tapi **memperparah** kerugian karena likuidator mengambil bonus dari jaminan yang tersisa.

## 5. Likuidasi: matematikanya

Saat HF < 1, siapa pun boleh memanggil `liquidationCall`. Alurnya:

1. Likuidator membayar sebagian utang (`debtToCover`).
2. Likuidator menerima jaminan senilai `debtToCover * (1 + liquidationBonus)`.
3. Sisa posisi dihitung ulang. Kalau masih di bawah 1, bisa dilikuidasi lagi di blok berikutnya.

Batas `debtToCover` di Aave v3:

| Kondisi | Maksimum yang bisa dilikuidasi |
|---|---|
| `HF > 0,95` dan nilai jaminan >= $2.000 dan nilai utang >= $2.000 | 50% dari total utang |
| `HF <= 0,95` | 100% dari total utang |
| Nilai jaminan < $2.000 atau nilai utang < $2.000 | 100% dari total utang |

Ditambah aturan debu: likuidasi sebagian harus menyisakan minimal **$1.000** di jaminan dan **$1.000** di utang. Kalau tidak, posisinya harus dibersihkan penuh. Tanpa aturan ini, akan ada posisi sisa yang terlalu kecil untuk dilikuidasi lagi, dan itu menggantung selamanya di buku protokol.

**Contoh hitung, bonus 5%** (nilai WETH on-chain: `liquidationBonus = 10500`, artinya likuidator dapat 5%):

Posisi: jaminan $10.000 ETH, utang $8.050 USDC, `LT = 83%`, `HF = 1,0311`. Harga ETH turun 5%.

1. Nilai jaminan jadi $9.500. `HF = 9.500 * 0,83 / 8.050 = 0,9795`. Posisi likuidabel.
2. `HF = 0,9795 > 0,95`, dan kedua nilai di atas $2.000, jadi maksimum 50% utang = $4.025.
3. Likuidator membayar $4.025 utang, menerima jaminan senilai `4.025 * 1,05 = $4.226,25`.
4. Sisa jaminan: `9.500 - 4.226,25 = $5.273,75`. Sisa utang: `4.025`.
5. `HF` baru: `5.273,75 * 0,83 / 4.025 = 1,0875`. Aman lagi, tapi peminjam sudah kehilangan $226,25 nilai jaminan sebagai bonus likuidator, di luar kerugian karena harga turun.

Angka 1,0875 itu bisa diverifikasi ulang: `5.273,75 * 0,83 = 4.377,21`, dibagi `4.025` = `1,0875`.

## 6. Flash loan dan likuidasi: kaitannya

Likuidasi butuh modal untuk membayar utang orang lain. Flash loan menghilangkan kebutuhan modal itu: dalam satu transaksi, pinjam aset utang, panggil `liquidationCall`, jual jaminan yang didapat, lalu kembalikan flash loan. Karena semuanya satu transaksi, tidak ada risiko posisi terbuka.

Ini alasan likuidasi di Aave sangat kompetitif. Kalau ada peluang likuidasi yang menguntungkan, bot dengan flash loan akan mengambilnya di blok yang sama. Untuk peminjam, artinya tidak ada waktu untuk "menyelamatkan" posisi setelah HF tembus di bawah 1 kecuali menang gas race.

Ini juga alasan flash loan disebut **amplifier**, bukan celah: bug oracle atau bug perhitungan harga di protokol mana pun bisa dieksploitasi tanpa modal awal, karena penyerang tidak perlu punya dana untuk memanipulasi harga lalu meminjam melawannya.

## 7. Cara mereproduksi di spreadsheet

Kalau mau versi spreadsheet-nya (sesuai roadmap), susun begini. Kolom A sampai H, satu baris per skenario:

| Kolom | Isi | Rumus |
|---|---|---|
| A | Nilai jaminan awal (USD) | input, mis. 10000 |
| B | `LT` | input, mis. 0.83 |
| C | Utang (USD) | input, mis. 8050 |
| D | HF awal | `=A2*B2/C2` |
| E | Harga jaminan harus turun ke | `=C2/(A2*B2)` |
| F | Penurunan pemicu likuidasi | `=1-E2` |
| G | Nilai jaminan setelah penurunan | `=A2*(1-penurunan)` |
| H | HF setelah penurunan | `=G2*B2/C2` |

Buat satu baris per kombinasi utang (mis. 2.000, 4.000, 6.000, 8.050) dan satu blok kolom per tingkat penurunan harga (5%, 10%, 20%, 30%). Hasilnya harus cocok dengan tabel di section 3 dan 4. Kalau tidak cocok, yang salah biasanya pemakaian LTV (80,50%) padahal rumusnya butuh LT (83,00%).

## 8. Yang belum dikerjakan

- Belum membaca `LiquidationLogic.sol` dan `ValidationLogic.sol` sampai level eksekusi. Dokumen ini level rumus dan simulasi, belum level kode.
- Parameter `baseRate`, `slope1`, `slope2` di section 1 masih ilustratif. Kalau mau angka asli, harus dibaca dari kontrak interest rate strategy per reserve, dan alamat strategy itu diambil dari `getReserveData`. Belum dilakukan karena layout struct `getReserveData` berubah antar versi Aave v3.
- Belum menyertakan reserve factor dan protocol fee dalam contoh likuidasi, karena pengaruhnya kecil untuk keputusan "kapan posisi tidak aman".
- Flash loan receiver-nya ada di project terpisah: [`aave-v3-flashloan/`](../aave-v3-flashloan/README.md).
