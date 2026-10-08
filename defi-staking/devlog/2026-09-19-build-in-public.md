# 19 Sep 2026 - Build in Public

> Task roadmap: "Tulis thread Twitter/X tentang Project 1: apa yang dibangun, masalah yang ditemui, pelajaran. Buat artikel di Mirror.xyz versi panjang. Setup GitHub profile README yang menarik dan informatif."

## Apa yang dikerjakan

Tiga draft di `content/` (semuanya siap edit + publish, bukan final tanpa review pemilik):

- `content/twitter-thread.md`: thread 7 tweet tentang Project 1, sudut pandang "masalah yang gw temui selama build" (fs_permissions, msg.sender script vs PRIVATE_KEY, reward window hangus), bukan brosur fitur.
- `content/mirror-article-draft.md`: artikel panjang Mirror.xyz, struktur problem-solution per keputusan desain (kenapa mint-on-claim, kenapa emergencyWithdraw forfeit, kenapa accumulator + checkpoint).
- `content/github-profile-readme.md`: profile README dengan tiga bagian: siapa gw (SWE yang lagi pindah ke blockchain), project yang lagi dikerjakan + status, dan stack yang lagi dilatih. Tanpa klaim skill yang belum terbukti.

## Masalah & Solusi

### Insting pertama adalah menulis thread marketing, padahal isinya belum cukup

- Masalah: draft awal thread cenderung jadi daftar fitur ("staking protocol dengan reentrancy guard dan fuzz testing!"). Masalahnya: semua orang bisa nulis itu, dan audiens build-in-public (dev blockchain) bukan target kata "seamless".
- Kenapa: build in public itu bernilai dari proses dan kegagalan yang spesifik, karena itu bagian yang gak bisa didapat orang dari dokumentasi resmi. Thread fitur juga gak punya bukti pendukung.
- Solusi: setiap tweet disusun ulang jadi format: situasi, error/perilaku nyata, root cause, solusi, pelajaran. Sumbernya diambil langsung dari `devlog/17 Sep` yang memang mendokumentasikan kejadian asli (fs_permissions revert, deployer metadata salah, reward window).
- Pelajaran: devlog yang ditulis jujur otomatis jadi bahan konten; marketing yang jujur adalah efek samping, bukan tujuannya.

### Belum ada angka publik yang boleh dipamerkan, jadi mana bagian yang layak disebut?

- Masalah: ada keinginan menyebut "100% coverage" atau "75 test" sebagai bukti kualitas, tapi angka itu tanpa link repo jadi klaim kosong, dan repo sendiri belum di-push.
- Kenapa: aturan pribadi yang dipegang dari sisi copywriting: angka tanpa sumber gak boleh dipublikasikan, empty is better than deceptive. Repo belum ada artinya angka belum punya rumah.
- Solusi: thread tidak menyebut metrik, hanya proses; artikel menyebut angka sekaligus menandai "angka bisa direproduksi di repo, link menyusul setelah push". Profile README menyebut status project yang sedang jalan tanpa angka.
- Pelajaran: konten build-in-public yang belum punya repo publik harus aman terhadap pertanyaan "show me the code".

### Tiga platform, tiga format, satu sumber: risiko-nya copy-paste membosankan

- Masalah: thread, artikel, dan profile README mudah berakhir jadi teks yang sama dengan panjang beda, dan audiens yang follow ketiganya langsung kerasan.
- Kenapa: tiap platform punya ekspektasi beda: thread = potongan cepat per masalah; artikel = alur naratif dengan kedalaman teknis; profile README = snapshot posisi sekarang, bukan cerita.
- Solusi: satu sumber (devlog) dengan tiga transformasi berbeda: thread pakai satu masalah per tweet, artikel pakai keputusan desain sebagai bab, profile README tidak menceritakan proses sama sekali.
- Pelajaran: "write once, publish everywhere" itu jebakan; yang benar "learn once, adapt everywhere".

## Status jujur

Done:
- Tiga draft konten selesai di `content/`, semuanya berasal dari kejadian yang terdokumentasi di `devlog/`.

Belum / butuh aksi manual:
- Publish thread (butuh akun X dan keputusan timing), publish artikel Mirror (butuh wallet connect ke Mirror), update profile GitHub (butuh push repo profile README ke repo `<username>/<username>`).
- Draft masih perlu dibaca ulang oleh pemilik sebelum publish: ini suara orangnya, bukan suara AI.
