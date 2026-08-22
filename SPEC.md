# Vocably — Functional Specification (versi 6)

Dokumen ini adalah spesifikasi fungsional terstruktur. Rujukan lain: `CLAUDE.md`
(context project & aturan kerja), `DATA_MODEL.md` (skema Firestore),
`DESIGN_REFERENCE.md` (acuan visual).

> **Perubahan di versi 6** (hasil review konsistensi dokumentasi — semua
> sudah diputuskan, jangan ditanyakan ulang):
> 1. **Pelajari ulang kata `difficult` menjalankan 3 fase penuh**, bukan
>    fase 2–3 (§3.6, §5).
> 2. **Cerita dari AI datang dengan penanda kata target** `[[kata|bentuk]]`
>    — highlight & cloze tidak lagi mengandalkan pencarian string (§5.1,
>    §5.2).
> 3. **Aturan mastery final:** default `difficult`, dan `mastered` bersifat
>    permanen (§6).
> 4. **Siswa tidak pernah menulis ke bank kosakata** — terjemahan yang
>    kosong hanya ditampilkan, tidak disimpan (§3.5).
> 5. **Fallback DictionaryAPI** ditetapkan berlapis (§3.5).
> 6. **Riwayat Pembelajaran jadi dua tab**: per kata & per sesi (§3.6).
> 7. **Navigasi tunggal responsif** (rail kiri di layar lebar, tab atas di
>    HP) menggantikan bottom nav; struktur menu dashboard diselaraskan
>    (§3.2).
> 8. **Bank kosakata dibaca dari aset statis per level**, bukan query
>    Firestore (§3.3, §7).
> 9. Placement test hanya ditawarkan otomatis **sekali** (§3.1).

## 1. Ringkasan

Vocably: aplikasi web (layout mobile/Android-first, responsif) untuk belajar
kosakata bahasa Inggris dari bahasa Indonesia. Dua role: **siswa** dan
**guru**. Fitur belajar utama mengadaptasi metode **Storyfier** (UIST '23):
3 fase berurutan — baca cerita ber-AI, cloze test, co-write dengan AI.

Vocably juga berfungsi sebagai instrumen penelitian skripsi: selain
Placement Test (personalisasi), ada modul Pre-Test/Post-Test terpisah untuk
pengambilan data penelitian (lihat 3.7).

Semua panggilan ke ChatGPT API (generate cerita, feedback co-write, generate
terjemahan) **melewati proxy Cloudflare Worker**, tidak pernah langsung dari
aplikasi Flutter — supaya API key tidak terekspos di client web. Ini tidak
mengubah fitur/alur yang dirasakan siswa/guru, cuma detail arsitektur di
baliknya. Detail teknis di `DATA_MODEL.md` §10.

## 2. Role & Autentikasi

- Sign up & login menggunakan Firebase Auth.
- **Role default: `siswa`.** Setiap akun baru otomatis dibuat dengan role
  `siswa` — tidak ada pilihan role di form sign up utama.
- **Menjadi guru** butuh langkah tambahan: ada opsi/toggle terpisah "Daftar
  sebagai Guru" di layar sign up, yang meminta input **kode akses guru**.
  Kode ini dibagikan oleh peneliti (kamu) ke guru-guru yang terlibat di
  penelitian (mis. guru SMK N 1 Sukoharjo) — **bukan** dikonfigurasi
  langsung lewat Firebase Console per akun, supaya prosesnya bisa dilakukan
  guru sendiri tanpa perlu minta bantuan developer tiap kali.
  - **Catatan teknis (tanpa server backend):** validasi kode akses ini
    ditangani sepenuhnya oleh **Firestore Security Rules** (bukan Cloud
    Function, karena project ini tidak pakai Cloud Functions — lihat
    `CLAUDE.md` §2) — client mengirim kode yang diketik bersamaan dengan
    permintaan pembuatan akun, dan rules yang memutuskan valid/tidaknya.
    Kalau kode salah, permintaan pembuatan akun **ditolak** (bukan
    fallback diam-diam jadi siswa). Detail lengkap di `DATA_MODEL.md` §1
    dan §2c.
  - **Kode akses harus 8 karakter acak dari generator** (mis. `k7Rq2mXf`),
    bukan kata bermakna seperti `guru2026` atau nama sekolah. Security
    Rules tidak punya rate limiting, jadi tidak ada yang mencegah orang
    mencoba menebak kode berulang kali lewat form sign up atau lewat skrip
    ke REST API. Kalau kode tertebak, siswa bisa jadi guru dan mengubah
    bank kosakata / target kata — artinya data penelitian terkontaminasi.
  - **Kode yang diketik disimpan permanen** di dokumen `users` guru
    tersebut sebagai audit trail (`teacherCodeInput`) — ini sekaligus jadi
    catatan guru mana memakai kode mana. Karena itu, dokumen `users` hanya
    boleh dibaca pemiliknya sendiri.
- **Satu akun = satu role, dan bersifat permanen** setelah dibuat. Karena
  email di Firebase Auth memang unik per akun dan tiap akun cuma punya satu
  field `role`, aturan "satu email satu role" ini otomatis terjaga selama
  tidak ada fitur untuk mengubah role sendiri lewat UI (tidak
  diimplementasikan untuk skripsi ini).
- Routing setelah login berbeda total antara siswa dan guru.

## 3. Alur Siswa

### 3.1 Login pertama kali → Placement Test

> **Status: sebagian TBD.** Alur/entry-point di bawah ini sudah final dan
> boleh diimplementasikan. **Detail teknis penilaian & algoritma penentuan
> level CEFR-nya belum ditentukan** — masih dicari metode yang punya dasar
> teori jelas dan sesuai kebutuhan riset Vocably. **Jangan buat asumsi atau
> sistem skoring sendiri.** Bagian ini akan direvisi begitu metodenya
> diputuskan. Untuk sekarang, implementasikan hanya scaffolding (routing,
> entry point, layar placeholder) — lihat `DATA_MODEL.md` §6 dan
> `DESIGN_REFERENCE.md` §5.2.

- Begitu siswa login pertama kali, ditawarkan placement test untuk
  menentukan level CEFR awal.
- Placement test **opsional saat itu juga** — bisa langsung dikerjakan atau
  ditunda ("nanti").
- **Tawaran otomatis hanya muncul SEKALI seumur akun.** Begitu tawaran itu
  ditampilkan, aplikasi menandainya (`users.placementTestPrompted = true`)
  apa pun pilihan siswa. Kalau siswa menunda, **tawaran itu tidak akan
  muncul lagi di login-login berikutnya** — bukan diulang tiap masuk.
  Penanda ini perlu karena `placementTestCompleted` tetap `false` baik
  untuk siswa yang belum pernah ditawari maupun yang sudah ditawari tapi
  menunda; tanpa penanda, aplikasi tidak bisa membedakan keduanya.
- **Entry point tersedia di dua tempat:**
  1. Ditawarkan otomatis **sebelum siswa pertama kali masuk dashboard**
     (sekali saja, seperti di atas).
  2. Tersedia **permanen di dalam dashboard** (lihat 3.2) — baik untuk
     siswa yang menunda tadi (belum pernah ambil), maupun untuk
     **mengambil ulang** placement test kapan saja siswa mau. Ini
     satu-satunya jalan masuk setelah tawaran otomatis lewat.
- Hasil placement test menentukan level CEFR siswa saat ini, ditandai secara
  visual di pilihan level (lihat 3.3).
- Begitu metode skoring sudah diputuskan: perhitungan level dilakukan
  **langsung di client** (tidak lewat Worker — tidak ada rahasia yang perlu
  disembunyikan di logic skoringnya), dan jawaban mentah siswa tetap
  disimpan ke Firestore supaya bisa diverifikasi ulang saat analisis
  skripsi.

### 3.2 Dashboard Siswa

**Struktur navigasi (klarifikasi v6).** Aplikasi punya **satu sistem
navigasi utama** yang responsif — bukan bottom nav:

- **Layar lebar (desktop/tablet):** `NavigationRail` di sisi kiri.
- **Layar sempit (HP — target utama):** tab horizontal di atas, di bawah
  app bar. Rail vertikal memakan lebar yang sudah sempit, jadi tidak
  dipakai di sini.

Dua destinasi navigasi untuk siswa: **Belajar** dan **Riwayat**.

**Isi destinasi "Belajar"** — dua card menu utama:

1. **Target Kata Hari Ini** — daftar kata target yang di-set oleh guru untuk
   siswa (lihat 4.1). Siswa bisa cek kamus detail tiap kata (klik kata →
   lihat 3.5), dan langsung mulai fitur utama 3-fase dari kata-kata ini.
2. **Level** — 6 pilihan CEFR (A1–C2) dalam satu kelompok pilihan. Semua
   level selalu terlihat/dipilih-bisa, tapi kalau placement test sudah
   dikerjakan, level tempat siswa berada sekarang ditandai secara visual.
   Memilih satu level → masuk ke browse kosakata level itu (lihat 3.3).
   - **Entry point Placement Test ada di dalam card ini** — "Ambil
     Placement Test" (kalau belum pernah) atau "Ambil Ulang Placement Test"
     (kalau sudah pernah), lihat 3.1.
   - **Catatan cakupan data:** sumber utama bank kosakata (Oxford
     3000/5000) hanya mencakup level **A1–C1**. Level **C2 tetap
     ditampilkan sebagai pilihan**, tapi kontennya kosong sampai ada kata
     level C2 yang ditambahkan guru lewat fitur Tambah Kosakata (4.1).
     Kosongkan dengan empty state yang jelas, bukan disembunyikan.

**Riwayat Pembelajaran** (3.6) bukan card di layar Belajar, melainkan
**destinasi navigasi tersendiri**. Secara fungsional ini tetap "menu ketiga"
yang disebut di versi sebelumnya — cuma posisinya di navigasi, bukan di
dalam layar Belajar.

Di bawah dua card di layar "Belajar", ada **section/menu tersendiri untuk
Pre-Test dan Post-Test** (lihat 3.7) — terpisah secara jelas dan visual dari
dua card di atas.

### 3.3 Menu Level → Browse Kosakata

**Sumber data (klarifikasi v6):** browse **tidak membaca dari Firestore**.
Bank kosakata dimuat dari aset statis per level CEFR, lalu semua
pengelompokan, filter, dan pencarian dijalankan **di memori**. Alasannya
kuota Firestore plan Spark — detail lengkap di `DATA_MODEL.md` §11. Dari
sisi siswa efeknya cuma satu: browse terasa instan.

- Setelah memilih level CEFR, kata-kata dalam level itu bisa di-sortir/
  dikelompokkan dengan 3 mode: **urut abjad**, **berdasarkan tema**, atau
  **berdasarkan POS (part of speech)**.
  - **Desain ketiga mode ini dibuat baru**, tidak ada acuan dari aplikasi
    versi pertama (versi lama belum punya fitur browse sama sekali). Dari
    `DESIGN_REFERENCE.md` yang diambil hanya identitas visualnya — warna,
    shape language, pola chip — bukan layoutnya.
- **Satu kata bisa punya lebih dari satu tema/topik** (field `topics` bersifat
  array — lihat `DATA_MODEL.md` §2). Saat mode "berdasarkan tema" dipilih,
  kata yang punya banyak topik akan muncul di setiap topik yang relevan
  (bukan cuma satu topik utama).
- **Satu kata juga bisa punya lebih dari satu makna** (mis. "souvenir" = noun
  & verb, dengan terjemahan Indonesia yang bisa berbeda per makna — lihat
  `DATA_MODEL.md` §2). Untuk mode "berdasarkan POS", kata dengan makna
  ber-POS berbeda akan muncul di setiap kelompok POS yang relevan, sama
  seperti pola multi-topik di atas.
- Di tampilan ringkas (chip/list), terjemahan yang ditampilkan adalah
  terjemahan **makna utama**, yaitu `meanings[0]` — semua makna lengkap ada
  di kamus detail (3.5).
- Siswa memilih kata-kata yang mau dipelajari via **"keranjang pelajari"**
  (pola shopping cart: tambah kata, kurangi kata, lalu proses semua kata yang
  sudah dipilih sekaligus untuk mulai belajar).
- Kata bisa punya salah satu dari 3 label status: `belum dipelajari`,
  `sudah dipelajari: mastered`, `sudah dipelajari: difficult` (detail state
  machine di bagian 6).

### 3.4 Keranjang Pelajari
- Fungsional: tambah kata (+), kurangi kata (–/x), lihat jumlah kata
  terpilih.
- Setelah siswa merasa cukup, gunakan tombol CTA untuk mulai fitur utama
  3-fase dengan kata-kata yang ada di keranjang.

### 3.5 Kamus Detail (dictionary lookup)
Diakses dengan klik kata mana pun (di browse kosakata, target kata hari ini,
riwayat, atau dari dalam cerita di Fase 1). Menampilkan:

- Arti (bisa lebih dari satu makna/POS dalam satu kata, mis. "souvenir" =
  noun & verb). **Terjemahan Indonesia ditampilkan per makna**, bukan satu
  terjemahan tunggal untuk seluruh kata — karena makna yang berbeda POS bisa
  punya terjemahan Indonesia yang berbeda pula (lihat `DATA_MODEL.md` §2,
  field `meanings`).
- Part of speech (POS) — ditampilkan per makna.
- Pronunciation (teks fonetik) + tombol putar audio.
- Contoh kalimat yang menggunakan kata tersebut.
- Sumber data (arti versi Inggris, POS, pronunciation, contoh kalimat):
  `https://api.dictionaryapi.dev/api/v2/entries/en` (dipanggil langsung dari
  client, bukan lewat Worker — tidak ada secret di API ini).

**Terjemahan Indonesia per makna** biasanya sudah tersedia instan
(di-generate otomatis sekali saat kata pertama masuk ke bank kosakata).
Kalau ada makna yang terjemahannya kosong, client memanggil Worker
`/translate` dan **menampilkan hasilnya di layar saja — tidak menyimpannya
ke Firestore**. Tampilkan loading/placeholder singkat untuk kasus ini.

> **Kenapa tidak disimpan (perubahan v6).** Menyimpan hasil itu
> mengharuskan akun siswa punya izin tulis ke bank kosakata, dan aturan
> pengaman yang dibutuhkan ("hanya boleh mengisi terjemahan yang masih
> kosong") ternyata tidak bisa ditegakkan Firestore Security Rules. Tanpa
> aturan itu, siswa mana pun bisa menimpa makna kata apa pun. Untuk
> penelitian yang datanya harus bersih, bank kosakata dibuat **read-only
> total untuk siswa**. Mengisi terjemahan yang kosong adalah tugas
> dev/guru. Detail di `DATA_MODEL.md` §2.

**Fallback kalau DictionaryAPI gagal atau tidak punya entri.** Ini sering
terjadi untuk frasa (mis. "wake up", "look after"), dan API tersebut adalah
layanan komunitas gratis tanpa jaminan uptime — jadi kegagalan harus
dianggap normal, bukan kasus tepi.

- **Lapisan 1 — degradasi rapi (wajib).** POS dan terjemahan Indonesia
  per makna selalu tersedia dari bank kosakata sendiri, jadi kamus detail
  tetap tampil dan tetap berguna. Bagian yang tidak tersedia (definisi
  Inggris, contoh kalimat) diganti pesan halus seperti "Definisi bahasa
  Inggris tidak tersedia untuk kata ini" — bukan layar error, bukan spinner
  yang menggantung.
- **Lapisan 2 — audio (wajib).** Kalau DictionaryAPI tidak menyediakan
  audio, pakai text-to-speech bawaan browser. Kualitasnya di bawah rekaman
  manusia, tapi jauh lebih baik daripada tombol putar yang mati. Ini
  kemungkinan butuh package tambahan — minta konfirmasi dulu sesuai
  `CLAUDE.md` §6.
- **Lapisan 3 — definisi via ChatGPT: JANGAN dibangun sekarang.**
  Keputusannya menunggu data: saat menjalankan skrip import CSV, sekalian
  hitung berapa kata yang tidak ada di DictionaryAPI. Kalau jumlahnya kecil
  (mis. ~30 kata), lebih murah mengisinya manual daripada membangun
  endpoint Worker baru.

### 3.6 Riwayat Pembelajaran

Riwayat punya **dua tab**, karena ada dua cara melihat data yang sama dan
keduanya dibutuhkan:

**Tab "Per Kata"**
- Daftar semua kata yang sudah dipelajari, dengan label `mastered` /
  `difficult`.
- Bisa difilter/di-sort berdasarkan label tersebut.
- Saat filter "difficult" aktif, ada opsi **"Pelajari Kembali"** untuk
  langsung memulai sesi belajar baru dengan kata-kata difficult yang dipilih.

**Tab "Per Sesi"**
- Daftar sesi belajar, satu card per sesi: tanggal & jam, jumlah kata, dan
  kata-kata yang dipelajari di sesi itu.
- Membuka satu sesi menampilkan cerita yang dipakai di sesi tersebut
  (cerita tersimpan lengkap, jadi bisa dibaca ulang tanpa memanggil AI
  lagi).

> Kenapa dipisah jadi dua tab: "sort by label mastery" dan "dikelompokkan
> per sesi" adalah dua sumbu yang tidak bisa digabung dalam satu daftar —
> satu berorientasi kata, satu berorientasi waktu.

**"Pelajari Kembali" menjalankan 3 fase penuh** — baca cerita baru → cloze
test → co-write, sama persis seperti sesi belajar biasa. Yang membedakan
hanya asal kata-katanya (kata berlabel `difficult` yang dipilih siswa dari
riwayat).

> **Koreksi dari versi sebelumnya:** dokumen lama menyebut re-learn masuk
> "fase 2–3". Itu tidak mungkin — cloze test diturunkan dari cerita yang
> dibuat di Fase 1, jadi tanpa Fase 1 tidak ada sumber blank sama sekali.

### 3.7 Pre-Test & Post-Test (Placeholder — Modul Riset)

> **Status: TBD sepenuhnya.** Bagian ini hanya konsep & entry point untuk
> sekarang. **Jangan tentukan/implementasikan instrumen, tipe soal, atau
> skema penilaian apa pun** — instrumennya masih disusun dan belum
> divalidasi oleh peneliti (kamu). Cukup siapkan ruang arsitektur (routing,
> entry point di dashboard, struktur data placeholder di
> `DATA_MODEL.md` §6b) supaya instrumen final bisa dipasang tanpa
> perombakan sistem.

- **Tujuan:** modul ini murni untuk kebutuhan **pengambilan data penelitian
  skripsi** — mengukur kemampuan kosakata siswa sebelum (Pre-Test) dan
  sesudah (Post-Test) menggunakan Vocably. Awalnya direncanakan lewat Google
  Forms terpisah, tapi atas saran dosen pembimbing dipindah jadi satu
  kesatuan di dalam aplikasi.
- **Beda dengan Placement Test (3.1) — jangan disamakan:**

  | | Placement Test | Pre-Test / Post-Test |
  |---|---|---|
  | Tujuan | Personalisasi konten belajar (tentukan `cefrLevel`) | Pengukuran data penelitian (kemampuan sebelum/sesudah) |
  | Sifat | Bagian dari mekanisme aplikasi, dipakai siswa manapun | Instrumen riset skripsi, terikat desain penelitian pretest-posttest |
  | Kapan diambil | Ditawarkan sekali sebelum dashboard pertama, bisa diambil/diulang kapan saja lewat dashboard | Pre-Test di awal (sebelum mulai belajar), Post-Test di akhir periode penelitian |
  | Hasil dipakai untuk | Menentukan level/kata yang ditampilkan ke siswa | Data analisis skripsi (dibandingkan pre vs post) |
  | Collection | `placementTestResults` | `researchAssessmentResults` |

- **Posisi di UI:** section tersendiri di layar "Belajar", **di bawah** dua
  card utama (3.2) — terpisah secara visual & struktural, bukan bagian dari
  card Level maupun destinasi Riwayat.
- Untuk sekarang: tampilkan entry point placeholder saja (lihat
  `DESIGN_REFERENCE.md` §5.5) — isi soal/instrumen menyusul setelah
  divalidasi.

## 4. Alur Guru

### 4.1 Dashboard Guru
Dua destinasi navigasi (pola navigasi responsif yang sama seperti siswa —
rail kiri di layar lebar, tab atas di HP):

1. **Set Target Kata** — guru pilih kata mulai dari level CEFR tertentu,
   cari kata yang diinginkan, lalu pakai pola "keranjang target kata" (mirip
   keranjang pelajari siswa tapi untuk tujuan target). Selain memilih kata,
   guru juga menentukan **kapan** kata-kata itu ditargetkan (rentang
   waktu/sesi).
   - **Catatan teknis:** rentang waktu tidak pernah disimpan sebagai
     "tanpa batas akhir yang kosong" — kalau guru tidak menentukan tanggal
     akhir, sistem mengisi nilai sentinel. Sama untuk sasaran siswa: target
     global disimpan sebagai penanda "semua siswa", bukan nilai kosong.
     Alasan & detailnya di `DATA_MODEL.md` §5.
2. **Kosakata** — mencakup dua sub-fitur:
   - **Tambah Kosakata** — guru bisa menambah kata baru yang belum ada di
     bank kosakata. Karena `docId` kata = kata itu sendiri yang
     dinormalisasi (lihat `DATA_MODEL.md` §2), sistem otomatis mencegah
     duplikat: kalau guru mencoba menambah kata yang **sudah ada**, guru
     akan diberi tahu ("Kata ini sudah ada") dan ditawari opsi untuk
     **menambahkan makna baru** ke kata tersebut (kalau memang makna yang
     mau ditambahkan belum ada) — bukan membuat entri kata duplikat.
     Terjemahan makna baru di-generate lewat Cloudflare Worker (§1
     "Ringkasan").
     - Saat mengisi beberapa makna sekaligus, **makna utama diletakkan
       paling atas** — urutan itu yang dipakai aplikasi untuk menentukan
       terjemahan ringkas di chip/list (3.3).
   - **Edit Kata** — guru bisa mengedit **topik** (`topics`) dari kata yang
     sudah ada di bank kosakata, dengan cara memilih dari topik yang sudah
     ada (master list, lihat `DATA_MODEL.md` §2b) atau menambah topik baru.
     **Hanya field `topics` yang bisa diedit guru** — field lain
     (arti/`meanings`, level CEFR, dsb) tidak bisa diubah lewat fitur ini.

**Catatan penulis data:** guru dan skrip dev adalah **satu-satunya** pihak
yang menulis ke bank kosakata. Siswa read-only (lihat 3.5).

### 4.2 Scope Guru saat ini (skripsi) vs. Pengembangan Lanjutan
Untuk skripsi, fitur guru dibatasi pada 4.1. **Sisakan ruang arsitektur**
(data model & routing) untuk pengembangan lanjutan: guru melihat progres
belajar siswa, baik per-siswa maupun per-kata/kelompok kata. Jangan
implementasikan fitur ini sekarang, tapi jangan buat keputusan desain data
yang mempersulit penambahannya nanti.

## 5. Fitur Utama: 3 Fase Belajar (Storyfier Core)

Diakses dari tiga tempat, dan **ketiganya menjalankan alur 3 fase yang sama
persis** — yang membedakan cuma asal daftar kata targetnya:

1. **Target Kata Hari Ini** (kata dari guru),
2. **Keranjang Pelajari** (kata pilihan siswa sendiri),
3. **Pelajari Kembali** dari Riwayat (kata berlabel `difficult`).

### 5.1 Fase 1 — Membaca Cerita
- Siswa memasukkan judul/konteks cerita (bahasa apa pun, contoh: "liburan").
- Generate cerita pendek 3–5 kalimat **lewat Cloudflare Worker** (endpoint
  `/generate-story`, lihat `DATA_MODEL.md` §10), WAJIB menggunakan semua
  kata target sesi ini.
- **Kata target datang sudah ditandai oleh Worker**, dalam format
  `[[kataTarget|bentukTerpakai]]` di dalam teks cerita. Contoh:
  `Yesterday I [[run|ran]] to the park.` Client tinggal mem-parsing penanda
  itu — **tidak boleh mencari kata target dengan pencarian string biasa**.
  - **Kenapa:** AI menulis kalimat natural, jadi kata target hampir selalu
    muncul dalam bentuk infleksi (`run` → *ran*, `souvenir` → *souvenirs*,
    `study` → *studied*). Mencari kata dasar di teks tidak akan menemukannya,
    dan akibatnya highlight tidak muncul serta blank di Fase 2 tidak
    terbentuk — justru untuk kata yang paling perlu dilatih. Memaksa AI
    memakai bentuk dasar bukan solusi: hasilnya kalimat yang salah
    gramatikal, yang buruk untuk aplikasi belajar bahasa.
- Kata target di-highlight dalam cerita (yang ditampilkan adalah bentuk
  terpakainya, mis. *ran*); klik kata → buka kamus detail (3.5) untuk
  bentuk dasarnya (*run*).
- Toggle untuk menampilkan/menyembunyikan terjemahan cerita.
- **Siswa boleh generate ulang berkali-kali** dengan judul berbeda-beda
  (tombol "Generate" bisa diklik ulang). Setiap generate ulang **menimpa**
  hasil generate sebelumnya di layar yang sama — cerita sebelumnya (mis.
  Story A, B) yang sudah ditinggalkan **tidak dianggap** sebagai cerita yang
  dipelajari/bagian resmi sesi ini.
- **Cerita yang jadi bagian resmi sesi belajar** adalah cerita yang sedang
  tampil di layar **pada saat siswa menekan tombol "Selanjutnya"** — itulah
  yang dipakai untuk Fase 2 (cloze test) dan seterusnya. Lihat detail
  implementasi state di `DATA_MODEL.md` §4 (field `currentPhase`).
- Lanjut ke Fase 2 lewat tombol "Selanjutnya".

### 5.2 Fase 2 — Cloze Test
- Cerita hasil generate ditampilkan lagi, tapi kata target dihilangkan jadi
  blank. **Tidak perlu panggilan AI tambahan** untuk fase ini — blank &
  pilihan jawaban diturunkan langsung dari penanda di cerita dan daftar kata
  target yang sudah ada di client.
- Blank dibuat dengan mengganti `bentukTerpakai` di penanda. **Jawaban
  benarnya adalah bentuk dasar** (`kataTarget`), dan dropdown berisi daftar
  kata target dalam bentuk dasar — jadi siswa yang melihat blank menggantikan
  *ran* tetap menjawab dengan memilih *run*.
- **Satu blank per kata target.** Kalau satu kata kebetulan muncul lebih
  dari sekali di cerita, hanya kemunculan pertama yang jadi blank; sisanya
  tetap tampil sebagai teks biasa.
- Siswa memilih/mengisi kata yang tepat untuk tiap blank (UI: dropdown
  inline berisi pilihan kata target — lihat `DESIGN_REFERENCE.md` §3.5).
- Setelah submit, sistem menandai jawaban benar/salah per blank (visual:
  hijau = benar, merah = salah) — perbandingan string sederhana di client,
  tidak perlu AI.
- Siswa bisa perbaiki jawaban yang salah secara iteratif.
- Hasil fase ini dipakai untuk update mastery status (bagian 6).

### 5.3 Fase 3 — Co-write dengan AI
- Format seperti chat: siswa dan AI bergantian menulis kalimat untuk
  membentuk cerita baru menggunakan kata target.
- Target words ditampilkan di atas percakapan; **ditandai terpakai/belum
  terpakai** seiring percakapan berjalan.
- Percakapan berhenti otomatis begitu semua kata target sudah dipakai.
- Setiap giliran siswa menulis, sistem beri feedback (grammar, typo, dsb) —
  **lewat Cloudflare Worker** (endpoint `/cowrite-turn`, lihat
  `DATA_MODEL.md` §10).
- Ada opsi **"saran menulis"** kalau siswa bingung mau menulis apa (bagian
  dari respons endpoint yang sama, lihat kontraknya di `DATA_MODEL.md`
  §10.2).
- **Definisi "mandiri":** giliran siswa dihitung mandiri kalau siswa menulis
  kalimatnya **tanpa menekan "saran menulis"** pada giliran itu. Kata yang
  dipakai pada giliran yang memakai saran **tidak** dihitung sebagai
  "dipakai mandiri", meskipun kalimatnya benar secara gramatikal. Ini
  berpengaruh langsung ke mastery (bagian 6).
- Respons Worker menyertakan penilaian terstruktur (kata mana yang dipakai
  dengan benar, dan apakah ada kesalahan) — bukan cuma teks feedback — supaya
  perhitungan mastery tidak perlu menebak-nebak dari kalimat feedback.
- Hasil fase ini juga dipakai untuk update mastery status (bagian 6).

## 6. State Machine: Status Kata

Dua variabel independen per kata per siswa:

- **`learned_status`**: `belum_dipelajari` → `sudah_dipelajari`
  - Berubah jadi `sudah_dipelajari` begitu kata itu **pernah dipakai** dalam
    salah satu dari fase 2 atau fase 3 (dipakai = muncul dalam sesi
    belajar), lalu otomatis masuk ke Riwayat Pembelajaran.
- **`mastery_status`**: `mastered` | `difficult`
  - **Hanya valid/aktif kalau `learned_status = sudah_dipelajari`.**

**Aturan mastery (final):**

1. **Default `difficult`.** Begitu sebuah kata jadi `sudah_dipelajari`,
   `mastery_status`-nya **langsung `difficult`**. Tidak pernah ada kondisi
   "sudah dipelajari tapi label mastery-nya kosong". Aturan ini sekaligus
   menyelesaikan kasus sesi yang ditinggal di tengah jalan — mis. siswa
   mengerjakan cloze test lalu keluar sebelum co-write: kata tetap tercatat
   dipelajari, berlabel `difficult`, dan bisa dinaikkan di sesi berikutnya.
2. **Naik ke `mastered`** hanya kalau di satu sesi yang sama kata itu
   dijawab benar di cloze test **DAN** dipakai mandiri tanpa kesalahan di
   co-write (definisi "mandiri" di 5.3).
3. **`mastered` bersifat permanen — tidak bisa turun jadi `difficult`.**
   Kalau siswa mempelajari ulang kata yang sudah `mastered` dan kali ini
   salah di cloze dan/atau co-write, statusnya **tetap `mastered`**.
   Penelitian ini belum punya desain untuk regresi mastery, jadi logic
   update harus eksplisit menolak penurunan status.
4. Kata berlabel `difficult` bisa dipelajari ulang berkali-kali (lewat
   "Pelajari Kembali", 3 fase penuh) sampai memenuhi syarat nomor 2.

Tracking mastery **terpisah** dari tracking learned/belum — implementasikan
sebagai dua field independen di data model (bukan satu enum gabungan), lihat
`DATA_MODEL.md` §3.

## 7. Bank Kosakata (sisi pengembang)

- Bank kosakata di-import ke Firestore lewat file CSV (proses manual oleh
  dev di laptop sendiri, pakai API key dev sendiri — bukan tugas Claude,
  dan tidak lewat Cloudflare Worker karena ini proses one-off, bukan
  traffic produksi dari user).
- Sumber: Oxford 3000 dan Oxford 5000, cakupan level **A1–C1** (lihat catatan
  di 3.2 soal level C2).
- **Format CSV sumber punya 4 kolom:** `word`, `topics`, `pos`, `sumber`.
  Karena topik ikut di CSV, `topics` sudah terisi sejak import — master
  list topik (`DATA_MODEL.md` §2b) juga langsung terbentuk dari kolom ini,
  jadi tidak ada kata tanpa topik dan mode browse tema tidak pernah kosong.
- **Setiap kata disimpan sebagai satu dokumen** dengan `docId` = kata itu
  sendiri yang dinormalisasi (lowercase + trim), bukan auto-generated ID —
  ini mencegah duplikat kata secara struktural. Kalau satu kata punya lebih
  dari satu makna (POS/terjemahan berbeda), makna-makna itu disimpan
  sebagai array di dalam satu dokumen yang sama (field `meanings`), **bukan
  dokumen terpisah**. Saat proses import CSV menemukan baris dengan kata
  yang sudah pernah diimport, baris itu harus digabung (merge) ke
  `meanings` dokumen yang sudah ada, bukan membuat dokumen baru — dan makna
  utama tetap di posisi pertama. Detail skema lengkap di `DATA_MODEL.md` §2.
- Setiap entri kata minimal punya: kata, level CEFR, **topics (array)**, dan
  satu atau lebih **meanings** (masing-masing dengan POS & terjemahan) —
  cukup untuk mendukung 3 mode browse (abjad/tema/POS) di 3.3.
- Terjemahan Indonesia per makna di-generate otomatis: **saat CSV import**,
  lewat skrip dev langsung (bukan Worker); **saat guru menambah kata baru
  atau makna baru**, lewat Cloudflare Worker. Terjemahan yang gagal
  di-generate tetap kosong dan **tidak diisi oleh siswa** (lihat 3.5) —
  mengisinya adalah tugas dev/guru.
- **Setelah import selesai, generate aset bundle bank kosakata per level
  CEFR** (`vocab_a1.json` dst) yang dipakai aplikasi untuk browse. Ini juga
  skrip dev-side, tanpa AI. Detail & alasannya di `DATA_MODEL.md` §11.
  Regenerate bundle sesekali setelah guru banyak menambah kata.
- **Sekalian saat import, ukur cakupan DictionaryAPI:** probe
  `api.dictionaryapi.dev` untuk semua kata dan catat berapa yang tidak
  punya entri. Angka ini yang menentukan apakah fallback definisi via
  ChatGPT (3.5 lapisan 3) perlu dibangun atau cukup diisi manual.

## 8. Daftar Fungsional Ringkas

**Siswa:** placement test (entry point saja, penilaian TBD), riwayat
pembelajaran (dua tab: per kata & per sesi), jelajah & cari kosakata (3 mode:
abjad/tema/POS), memilih kosakata, tambah/kurang kata di keranjang pelajari,
generate story dari judul/tema (berkali-kali, cerita saat "Selanjutnya"
ditekan yang dipakai), cloze test, co-write dengan AI, feedback saat
co-write, saran menulis saat co-write, pelajari ulang kata difficult (3 fase
penuh), pre-test & post-test (entry point saja, instrumen TBD).

**Guru:** tambah kata baru ke bank kosakata (dengan deteksi duplikat &
opsi tambah makna baru), edit topik kata yang sudah ada (pilih dari
topik existing atau tambah topik baru), set kata target (harian atau
sesi/waktu tertentu).

## 9. Referensi Eksternal

- ChatGPT API — generate cerita bertanda (fase 1), giliran + feedback +
  saran menulis di co-write (fase 3), generate terjemahan per makna kata
  (sisi bank kosakata) — **semua lewat proxy Cloudflare Worker**, tidak
  pernah dipanggil langsung dari Flutter client (lihat `DATA_MODEL.md` §10).
- `https://api.dictionaryapi.dev/api/v2/entries/en` — arti, POS,
  pronunciation + audio, contoh kalimat — dipanggil langsung dari client,
  dengan fallback berlapis di 3.5.
- Storyfier (UIST '23) — dasar konsep pedagogis 3 fase.
- Oxford 3000 / Oxford 5000 — sumber bank kosakata (CSV, cakupan A1–C1).
