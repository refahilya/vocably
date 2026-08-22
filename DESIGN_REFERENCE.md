# Vocably — Design Reference (versi 6)

Dokumen ini adalah **referensi identitas visual** untuk rebuild Vocably.
Diambil dari screenshot aplikasi versi pertama (**native Flutter for
Android**, deprecated).

> **Cara memakai dokumen ini.** Yang dipertahankan dari versi pertama hanya
> **identitas warna dan sifat visual** — palet warna, shape language
> (rounded corner, pill chip), pola highlight/badge, dan "kepribadian"
> visual secara umum. **Layout, ukuran komponen, dan struktur halaman TIDAK
> disalin** dari screenshot Android — versi ini web dan responsif, jadi
> semuanya disesuaikan (lihat §6). Bagian 3 dipakai sebagai starting point
> pola komponen, tapi perlakukan sebagai **inspirasi**, bukan cetak biru.
>
> Yang TIDAK dipertahankan sama sekali: arsitektur kode dan business logic
> di balik UI lama — itu dibangun ulang sesuai `SPEC.md` dan `DATA_MODEL.md`.

> **Perubahan di versi 6:**
> 1. **Bottom nav diganti navigasi tunggal responsif** — rail kiri di layar
>    lebar, tab atas di HP (§6). Ini menyentuh §3.2, §5.1, dan §5.4.
> 2. **Bagian baru §5.7** — desain 3 mode browse kosakata (abjad/tema/POS).
>    Fitur ini **tidak ada sama sekali** di versi lama, jadi tidak ada
>    acuan visualnya; didesain dari nol.
> 3. **Bagian baru §5.8** — empty state & fallback kamus detail.
> 4. **Bagian baru §6** — aturan navigasi & responsif.
> 5. **§3.4 & §3.5 diperbarui** mengikuti cerita bertanda dari Worker.
> 6. **§3.3 jadi dua tab** (per kata / per sesi).
> 7. **§3.6** — keraguan soal penanda used/unused **dihapus**; SPEC §5.3
>    sudah mewajibkannya.

> Catatan: nilai hex di bawah adalah estimasi visual dari screenshot, bukan
> nilai exact dari kode lama. Sesuaikan dengan mata/color picker saat
> implementasi kalau ada referensi yang lebih presisi.

## 1. Palet Warna

| Peran | Warna (estimasi) | Kegunaan |
|---|---|---|
| Primary (navy) | `#1B1F5C` – `#26307A` (indigo tua) | App bar, tombol utama, header stepper, item navigasi aktif, avatar user di chat |
| Accent / secondary | Teal/cyan muda | Avatar AI di co-write, aksen ikon |
| Success / correct | Hijau (`#2E7D32`-ish) + latar hijau muda | Jawaban benar di cloze test, banner "semua kata target sudah digunakan", badge mastery `mastered` |
| Error / salah | Merah/pink (`#C62828`-ish) + latar pink muda | Jawaban salah di cloze test, inline error form |
| Warning | Kuning/oranye muda | Feedback grammar di co-write |
| Mastery `difficult` | Amber/oranye solid | Dot penanda kata difficult (§5.3) |
| Highlight kata target | Oranye/tan muda dengan teks oranye tua | Highlight target word di dalam cerita (Baca Cerita) |
| Background utama | Putih / abu sangat muda | Body screen |
| Chip/pill tidak aktif | Putih dengan border tipis abu | Chip kata belum dipilih |
| Chip/pill aktif/dipilih | Navy solid dengan teks putih + centang hijau kecil | Kata yang sudah dipilih ke keranjang |
| Netral/disabled | Abu muda | Entry point "Segera" (pre/post test), tombol disabled, pill C2 |

## 2. Tipografi

- Header/app bar: bold, putih, di atas background navy (contoh: "Vocably",
  "Baca Cerita", "Cloze Test", "Tulis Bersama AI", "Riwayat Belajar").
- Judul kata di kartu detail (mis. "SOUVENIR", "DESTINATION"): huruf besar
  semua (uppercase), bold, ukuran besar, warna navy/gelap.
- Body text: regular weight, warna gelap netral di atas background terang.
- Label kecil (POS tag "noun"/"verb", info tambahan): badge kecil rounded
  dengan warna latar lembut (kuning muda untuk "noun", dst).

## 3. Komponen & Pola Layout yang Berulang (starting point, bukan cetak biru)

### 3.1 Stepper 3-fase (dipakai di semua layar Storyfier flow)
Muncul persis di bawah app bar pada layar Baca Cerita, Cloze Test, Tulis
Bersama AI: `● Membaca — ○ Cloze Test — ○ Co-Write`, step aktif ditandai
lingkaran solid + label bold, step selesai ditandai centang, step belum
ditandai lingkaran outline pucat. **Jadikan satu widget reusable**
(`StepperHeader`) dipakai di ketiga screen, bukan re-implementasi per layar.

> Stepper ini muncul sama persis di ketiga jalur masuk sesi belajar (Target
> Kata Hari Ini, Keranjang Pelajari, Pelajari Kembali) — semuanya menjalankan
> 3 fase penuh, jadi tidak ada varian stepper "2 fase".

### 3.2 Pola topic browser & card detail kata
Pola dari versi lama yang tetap dipakai sebagai dasar visual — tapi sekarang
ini **salah satu dari tiga mode browse**, bukan satu-satunya tampilan (lihat
§5.7 untuk ketiga mode).

- Dropdown "Pilih Topik" di atas (ikon topi wisuda kecil di kiri dropdown).
- Grid wrap chip kata per topik: tiap chip berisi kata Inggris (bold) +
  terjemahan Indonesia kecil di bawahnya. **Terjemahan yang ditampilkan di
  chip adalah terjemahan makna utama** (`meanings[0]` — lihat
  `DATA_MODEL.md` §2); semua makna lengkap ada di card detail.
- Tap chip → muncul card detail kata di bawah grid: nama kata besar +
  phonetic, tombol tambah (+) / hapus (x) di kanan atas card, lalu **satu
  blok per makna**: tiap blok berisi badge POS berwarna, badge bendera 🇮🇩 +
  terjemahan **khusus makna itu**, dan bullet definisi. Kalau kata cuma
  punya satu makna, cukup satu blok saja (tanpa garis pemisah yang
  mengganggu). Contoh "souvenir" jadi 2 blok: blok noun ("oleh-oleh") dan
  blok verb (terjemahan berbeda).
- **Cara memilih kata ke keranjang:** versi Android lama memakai long-press
  ("N kata dipilih (tekan lama untuk memilih/batal)"). **Untuk web, ganti
  dengan tap langsung pada ikon (+) di chip** — long-press tidak natural
  untuk pointer/mouse dan tidak punya afordans visual. Tetap tampilkan
  footer info jumlah kata terpilih.
- Tombol CTA besar full-width di bawah: "📖 Belajar Kata Baru dengan Cerita"
  — disabled/abu-abu kalau belum ada kata dipilih.

> Catatan topik jamak: `vocabWords.topics` bersifat array (satu kata bisa
> masuk beberapa topik). Kalau chip kata muncul dalam konteks satu topik,
> cukup tampilkan chip itu apa adanya — daftar lengkap topiknya bisa
> ditampilkan di card detail kalau relevan.

> Catatan level: pilihan level CEFR menampilkan 6 opsi A1–C2, tapi C2
> kemungkinan besar kosong (`SPEC.md` §3.2) — tampilkan empty state yang
> jelas, lihat §5.8.

### 3.3 Riwayat Belajar — dua tab

Riwayat punya dua tab (`SPEC.md` §3.6). Gunakan segmented control/tab di
bawah app bar, style konsisten dengan stepper §3.1 tapi versi 2 opsi.

**Tab "Per Kata"**
- List/grid chip kata yang sudah dipelajari, tiap kata membawa badge mastery
  (§5.3).
- Filter/sort by label di atas list (dropdown atau segmented control, style
  konsisten dengan dropdown "Pilih Topik").
- Saat filter "difficult" aktif, tombol **"Pelajari Kembali"** muncul (solid
  navy, full-width di bawah atau floating action button) untuk memulai sesi
  3 fase dengan kata-kata difficult yang dipilih.

**Tab "Per Sesi"**
- List card vertikal, tiap card = satu sesi belajar: tanggal & jam (format
  `d/M/yyyy HH:mm`) + badge jumlah kata (mis. "5 kata") di kanan atas, lalu
  wrap chip kata-kata yang dipelajari sesi itu (kata + terjemahan kecil,
  warna biru muda).
- Tap card → detail sesi, menampilkan cerita yang dipakai di sesi itu
  (dengan highlight kata target seperti §3.4 — cerita tersimpan bertanda,
  jadi bisa dirender ulang tanpa panggilan AI).

### 3.4 Baca Cerita (Story reading)
- Input judul cerita (text field dengan ikon pensil) + tombol "Generate"
  (berubah jadi disabled/loading state "Menghasilkan cerita..." dengan
  spinner titik saat proses).
  - **Catatan arsitektur:** generate lewat proxy Cloudflare Worker sebelum
    sampai ke ChatGPT API, jadi total waktu tunggu bisa sedikit lebih lama
    daripada panggilan langsung. Kalau memungkinkan, pertimbangkan
    menampilkan cerita secara bertahap (streaming) begitu teksnya mulai
    datang — bukan perubahan wajib untuk skripsi, tapi menghindari kesan
    "macet" kalau koneksi sekolah lambat.
- Setelah generate: judul story ditampilkan sebagai heading, isi cerita
  sebagai paragraf dengan target word di-highlight (background oranye muda,
  teks oranye tua, rounded).
- **Yang di-highlight adalah bentuk kata yang benar-benar dipakai di
  kalimat**, bukan bentuk dasarnya. Cerita datang dari Worker sudah bertanda
  `[[run|ran]]`, jadi yang tampil di layar adalah *ran* dengan highlight,
  sementara tap-nya membuka kamus detail untuk *run*. Jangan menampilkan
  penanda mentah ke siswa — selalu strip dulu. Detail di `DATA_MODEL.md` §4.
- Toggle terjemahan cerita (tombol outline "Terjemahan" di footer kiri).
- **Generate ulang:** siswa bisa mengubah judul dan menekan "Generate" lagi
  berkali-kali — tiap generate ulang **menimpa** tampilan cerita sebelumnya
  di layar yang sama (bukan menambah cerita baru di bawahnya). Tombol
  "Generate" tetap aktif selama siswa belum menekan "Selanjutnya". Cerita
  yang sedang tampil **persis saat** "Selanjutnya" ditekan itulah yang jadi
  cerita resmi sesi ini.
- Footer: tombol outline "Terjemahan" (kiri), tombol solid navy
  "Selanjutnya →" (kanan).
- **Error state generate:** kalau Worker gagal (koneksi, OpenAI error, atau
  validasi penanda gagal), tampilkan pesan inline yang ramah + tombol "Coba
  lagi" — jangan layar kosong dan jangan pesan error mentah.

### 3.5 Cloze Test
- Instruksi singkat di banner abu muda atas.
- Paragraf cerita dengan blank berupa **dropdown inline** (border rounded,
  warna netral sebelum dijawab).
- **Blank menggantikan bentuk terpakai** (*ran*), sementara **pilihan di
  dropdown adalah bentuk dasar** (*run*) — sama persis dengan daftar kata
  target sesi ini. Jadi siswa memilih *run* untuk blank yang tadinya *ran*.
- **Satu blank per kata target.** Kalau satu kata muncul lebih dari sekali
  di cerita, kemunculan berikutnya tetap tampil sebagai teks biasa (boleh
  tetap di-highlight, tidak jadi blank).
- Setelah submit: border dropdown berubah hijau (benar) atau merah (salah),
  dan banner muncul di bawah: "Ada jawaban yang salah. Jawaban yang benar
  ditandai hijau." (background pink muda, ikon info).
- Dropdown terbuka menampilkan daftar pilihan kata target sebagai list polos
  (bukan dropdown native OS — custom styled).
- Tombol "Submit" full-width abu (disabled sampai semua blank terisi);
  setelah submit, tombol "Selanjutnya →" solid navy di kanan bawah.

### 3.6 Tulis Bersama AI (Co-write)
- **Target words ditampilkan sebagai pill chip di bawah stepper, dengan
  penanda terpakai/belum terpakai.** Kata yang sudah dipakai ditandai jelas
  (mis. pill navy solid + centang) versus yang belum (pill outline pucat).
  Screenshot versi lama menampilkan semuanya berwarna sama, tapi
  `SPEC.md` §5.3 mewajibkan pembedaan ini — jadi ini elemen yang **ditambah**
  di versi baru, bukan hal yang perlu dikonfirmasi lagi.
- Chat bubble alternating: avatar bulat kecil di kiri tiap bubble — navy solid
  untuk user, teal/cyan untuk AI. Bubble user sedikit lebih terang/putih,
  bubble AI abu muda.
- Feedback grammar muncul sebagai banner kuning muda di atas tombol aksi
  (ikon warning ⚠️), contoh: "Kalimat tersebut tidak gramatikal karena perlu
  menggunakan preposisi."
- **Tombol "Saran menulis"** di dekat input chat, untuk siswa yang bingung
  mau menulis apa. Beri afordans visual bahwa ini bantuan opsional (mis.
  tombol outline kecil dengan ikon lampu, bukan CTA solid) — karena giliran
  yang memakai saran **tidak dihitung sebagai penggunaan mandiri** dan
  karenanya tidak menaikkan mastery (`SPEC.md` §5.3 & §6). Tidak perlu
  peringatan eksplisit yang menakut-nakuti; cukup jangan membuatnya terlihat
  seperti jalur utama.
- Saat semua target word terpakai: banner sukses hijau muda dengan ikon 🎉
  "Selamat! Semua kata target sudah digunakan!" dan tombol full-width hijau
  solid "✓ Selesai" menggantikan input chat.

## 4. Ikon & Aset

- Ikon topi wisuda (graduation cap) — destinasi "Belajar" dan label "Pilih
  Topik".
- Ikon jam (history/clock) — destinasi "Riwayat".
- Ikon target — destinasi "Target Kata" (guru).
- Ikon buku/plus — destinasi "Kosakata" (guru).
- Ikon gear — pengaturan (kanan atas app bar dashboard).
- Ikon panah kembali (back arrow) putih — app bar screen sekunder.
- Ikon centang hijau kecil — indikator kata sudah dipilih ke keranjang.
- Ikon speaker — tombol putar audio pengucapan.
- Bendera Indonesia kecil 🇮🇩 — penanda terjemahan Indonesia di card detail
  kata.

## 5. Desain Baru untuk Elemen yang Belum Ada di Versi Lama

Elemen-elemen ini tidak ada referensi visual dari versi lama — didesain baru
di bawah, tetap konsisten dengan identitas warna & shape language di bagian
1–4, tapi sudah dipikirkan sebagai layout **web responsif**, bukan port dari
Android.

### 5.1 Dashboard Siswa — destinasi "Belajar"

Destinasi "Belajar" **tidak langsung menampilkan browser kosakata**.
Isinya layar beranda dengan dua card menu besar (full-width, rounded, style
konsisten dengan card detail kata di §3.2), ditambah satu section
placeholder di bawahnya:

- **Card "Target Kata Hari Ini"** — ikon target di kiri, judul bold, subtitle
  jumlah kata (mis. "5 kata dari Guru"). **"dari Guru" adalah label generik
  tetap**, bukan nama guru yang sebenarnya — jangan membaca dokumen `users`
  guru untuk menampilkan namanya di sini. (Dokumen `users` dibatasi
  read-only untuk pemiliknya sendiri, lihat `DATA_MODEL.md` §1, justru
  karena menyimpan `teacherCodeInput`; menampilkan nama asli akan butuh
  melanggar batasan itu untuk manfaat yang kecil.) Tap → daftar kata target (list,
  bukan grid chip, karena urutannya ditentukan guru) dengan tombol CTA
  "Belajar Kata Ini dengan Cerita" di bawah.
  - Empty state kalau guru belum men-set target: pesan singkat, bukan card
    kosong (§5.8).
- **Card "Level"** — menampilkan 6 pill CEFR (A1–C2) dalam satu baris/wrap di
  dalam card, level yang sedang aktif (hasil placement test) ditandai ring
  navy + badge kecil "Level kamu" di atasnya. Pill **C2** ditampilkan dengan
  style pudar/disabled ringan (tetap bisa di-tap, tapi mengarah ke empty
  state). Tap salah satu level → masuk ke browse kosakata (§5.7), di-scope
  ke level itu.
  - Di dalam card ini juga ada **entry point Placement Test**: teks link
    kecil "Ambil Placement Test" (kalau belum pernah) atau "Ambil Ulang
    Placement Test" (kalau sudah pernah) — style link/teks kecil, bukan
    tombol besar. Ini **satu-satunya** jalan masuk setelah tawaran otomatis
    pertama lewat (`SPEC.md` §3.1), jadi pastikan tetap mudah ditemukan
    meski kecil.
- **Section placeholder Pre-Test/Post-Test** — di bawah kedua card, dipisah
  garis tipis atau spacing yang lebih besar. Lihat §5.5.

**Riwayat Pembelajaran bukan card di layar ini** — dia destinasi navigasi
tersendiri (§6), dengan desain di §3.3.

### 5.2 Placement Test — Placeholder (bukan desain final)

> **Status: TBD.** Isi soal, jumlah soal, tipe soal, dan algoritma penentuan
> level **belum ditentukan** (lihat `SPEC.md` §3.1 dan `CLAUDE.md` §10).
> Desain di bawah **sengaja generik** — hanya mencakup bagian yang tidak
> bergantung pada metode tes (entry/exit point), bukan detail soal.

- App bar navy standar, judul "Tes Penempatan", tombol back / tombol "Lewati"
  (skip) di kanan atas app bar.
- **Tawaran otomatis (sebelum dashboard pertama)** berupa dialog/layar
  sambutan dengan dua aksi setara: "Mulai Tes" (solid navy) dan "Nanti Saja"
  (outline/teks). Jangan buat "Nanti Saja" terlihat seperti pilihan yang
  salah — tes ini memang opsional. Ingat: tawaran ini **hanya muncul sekali
  seumur akun**, jadi teksnya sebaiknya menyebutkan bahwa tes bisa diambil
  kapan saja lewat menu Level.
- Body layar tes: **placeholder** — pesan sederhana + ilustrasi ringan (mis.
  "Tes penempatan akan segera hadir") sampai metode tesnya diputuskan.
  **Jangan bangun UI soal spesifik** (pilihan jawaban, progress bar per soal,
  dsb) sebelum instrumennya jelas.
- Layar hasil: placeholder serupa, cukup pastikan ada tempat untuk
  menampilkan `resultLevel` setelah datanya ada, dan tombol CTA "Mulai
  Belajar" navy solid menuju dashboard (ini tidak bergantung metode tes, jadi
  boleh dibangun sekarang).

### 5.3 Badge Mastery (mastered / difficult) pada Chip & Card Kata

Ditambahkan ke pola chip/card kata di §3.2 dan §3.3, **tanpa bentrok** dengan
centang hijau kecil yang menandai kata di keranjang pelajari:

- Indikator mastery ditaruh sebagai **dot kecil berwarna di pojok kiri atas**
  chip/card (posisi berbeda dari centang keranjang yang di kanan):
  - Hijau solid = `mastered`
  - Amber/oranye solid = `difficult`
  - Tidak ada dot = `belum_dipelajari` (default, tanpa penanda supaya UI
    tetap bersih untuk kata yang belum disentuh)
- Karena `mastered` bersifat permanen (`SPEC.md` §6), dot hijau tidak pernah
  berubah kembali jadi amber — tidak perlu memikirkan transisi visual mundur.
- Badge yang sama dipakai di Riwayat (§3.3) dan di semua mode browse (§5.7).

### 5.4 Dashboard Guru

Mengikuti identitas warna & shape language yang sama dengan dashboard siswa
(bukan berarti layout identik):

- App bar navy dengan judul "Vocably" + ikon gear kanan atas.
- **Navigasi yang sama polanya dengan siswa** (§6) dengan dua destinasi:
  **"Target Kata"** (ikon target) dan **"Kosakata"** (ikon buku/plus).
- **Destinasi "Target Kata":** tombol "+ Set Target Baru" di atas, lalu
  daftar target yang sudah pernah di-set sebagai card (rentang waktu, jumlah
  kata, level) — style card sama dengan card sesi di §3.3. Tap "+ Set Target
  Baru" → alur pilih level → cari & pilih kata (pola chip & keranjang sama
  seperti siswa) → set rentang waktu (date/time picker) → simpan.
  - Untuk target tanpa tanggal akhir, tampilkan sebagai "Tidak ada batas
    akhir" di UI — **jangan menampilkan tanggal sentinel** (2099) yang
    tersimpan di balik layar (`DATA_MODEL.md` §5).
- **Destinasi "Kosakata"** — dua sub-fitur, dipisah segmented control/sub-tab
  kecil (style sama dengan stepper §3.1 versi 2 opsi):
  - **"Tambah Kosakata"** — form tambah kata baru (input kata, level CEFR,
    topics multi-select chip, satu atau lebih **makna** — tiap makna berupa
    baris berisi input POS + preview terjemahan yang akan digenerate
    otomatis, dengan tombol "+ Tambah makna lain"). Tombol simpan solid navy
    di bawah, style form field sama dengan input judul cerita §3.4.
    - **Urutan makna bermakna:** makna pertama di form = makna utama, dan
      itu yang muncul di chip browse siswa. Beri petunjuk visual ringan
      (mis. label "Makna utama" pada baris pertama, atau kemampuan drag
      untuk mengurutkan).
    - **Deteksi duplikat:** begitu guru mengetik kata yang **sudah ada**
      (dicek saat field kehilangan fokus), tampilkan inline notice (style
      mirip banner info abu §3.5) "Kata ini sudah ada" dengan tombol kecil
      "Tambah makna baru ke kata ini" yang membuka form ringkas
      append-makna (cuma input POS).
  - **"Edit Kata"** — list semua kata di bank kosakata (bisa dicari/difilter
    by level atau topik), tap satu kata → layar edit: info kata read-only
    (kata, daftar makna dengan POS & terjemahan, level CEFR) + satu bagian
    yang **bisa diedit: `topics`**, berupa multi-select chip, plus input
    "+ Tambah topik baru". Tombol simpan solid navy, disabled kalau tidak
    ada perubahan.
    - Buat kejelasan visual bahwa bagian lain read-only (mis. warna teks
      lebih redup, tanpa border input) — supaya guru tidak mengira bisa
      mengedit arti lalu bingung kenapa tidak bisa.

### 5.5 Pre-Test & Post-Test — Placeholder (bukan desain final)

> **Status: TBD sepenuhnya.** Instrumen belum disusun/divalidasi (lihat
> `SPEC.md` §3.7). Desain di bawah murni untuk entry point di dashboard,
> bukan isi soal.

- Di layar "Belajar" (§5.1), section terpisah di bawah dua card utama:
  card/banner sederhana bertuliskan "Pre-Test" dan "Post-Test" (dua entri
  terpisah atau satu card dengan dua tombol kecil — pilih yang paling simpel),
  style rounded konsisten dengan card lain tapi dengan penanda visual "belum
  tersedia": badge kecil "Segera" atau ikon jam pasir, warna netral abu bukan
  navy solid, supaya jelas beda dari CTA aktif lain.
- Begitu instrumen final tersedia, section ini akan didesain ulang sesuai
  kebutuhan instrumen tersebut.

### 5.6 Registrasi Guru (kode akses) — pola minimal

- Form sign up standar (nama, email, password) dengan style field yang sama
  seperti field lain di app (rounded, border tipis, focus state navy).
- Di bawah tombol "Daftar", teks link kecil "Daftar sebagai Guru?" — tap
  membuka satu field tambahan: input "Kode Akses Guru" (style input sama,
  dengan ikon kunci kecil di kiri) yang muncul di bawah form utama sebelum
  submit.
- Kode akses berupa **8 karakter acak** (mis. `k7Rq2mXf`) — perlakukan
  field-nya sebagai teks case-sensitive; jangan auto-capitalize dan jangan
  auto-correct, karena itu bisa merusak kode yang diketik guru dari HP.
  Trim spasi di awal/akhir sebelum submit.
- Kalau kode salah atau kosong saat submit dengan opsi ini aktif, tampilkan
  inline error di bawah field itu (style error sama seperti validasi jawaban
  salah §3.5). Akun **tidak dibuat** sebagai guru sampai kode benar — tidak
  ada fallback diam-diam jadi siswa tanpa pemberitahuan.
- **Catatan arsitektur:** validasi kode ditegakkan Firestore Security Rules,
  bukan server function (`DATA_MODEL.md` §1) — artinya yang diterima client
  cuma error permission-denied generik. **Tangani ini di sisi client:**
  tangkap error itu dan tampilkan "Kode akses tidak valid", jangan pernah
  menampilkan pesan error mentah Firestore ke pengguna.
- Tidak perlu layar terpisah — cukup elemen tambahan di form sign up yang
  sudah ada, supaya tidak menambah friksi untuk siswa (mayoritas pengguna).

### 5.7 Browse Kosakata — 3 Mode (desain baru)

> **Tidak ada acuan visual dari versi lama** — versi pertama belum punya
> fitur browse sama sekali. Yang diambil dari §3.2 hanya pola chip kata dan
> card detail; struktur layarnya baru.

Diakses dari card "Level" (§5.1), sudah di-scope ke satu level CEFR. Header
layar menampilkan level yang aktif (mis. pill navy "A2") supaya siswa selalu
tahu sedang di mana.

**Pemilih mode** — segmented control 3 opsi di bawah header: **Abjad · Tema ·
POS**. Style konsisten dengan stepper §3.1. Mode yang dipilih tersimpan
selama sesi (kalau siswa kembali dari card detail, modenya tidak reset).

**Mode "Abjad"**
- Daftar kata urut A–Z, dikelompokkan per huruf awal dengan sticky header
  huruf (A, B, C, …).
- Tiap entri: chip/baris kata + terjemahan makna utama + badge mastery
  (§5.3) + tombol (+) keranjang.
- Sediakan **field pencarian** di atas (cari kata atau terjemahan) — karena
  filter jalan di memori, hasilnya instan.

**Mode "Tema"**
- Dropdown "Pilih Topik" seperti §3.2, lalu grid wrap chip kata untuk topik
  itu.
- **Satu kata bisa muncul di beberapa topik** — itu memang perilaku yang
  diinginkan, bukan duplikasi yang perlu disembunyikan.

**Mode "POS"**
- Kelompok per part of speech (noun, verb, adjective, …), tiap kelompok
  punya header dengan badge POS berwarna (warna badge sama dengan yang
  dipakai di card detail §3.2 — konsistensi warna POS penting supaya siswa
  membangun asosiasi).
- **Satu kata bisa muncul di beberapa kelompok POS** kalau maknanya
  ber-POS berbeda, sama seperti pola multi-topik.

**Keranjang pelajari** (§3.4 SPEC) tampil sebagai bar sticky di bawah layar
di ketiga mode: jumlah kata terpilih + tombol CTA "Belajar Kata Ini dengan
Cerita" (disabled kalau kosong). Jangan sembunyikan di balik ikon —
keranjang adalah aksi utama layar ini.

### 5.8 Empty State & Fallback (desain baru)

Kumpulan kondisi "tidak ada data" yang harus punya tampilan sengaja, bukan
layar kosong atau spinner yang menggantung:

| Kondisi | Tampilan |
|---|---|
| Level C2 (atau level mana pun) tidak punya kata | Ilustrasi ringan + "Belum ada kata di level ini" + saran memilih level lain |
| Guru belum men-set target kata | "Belum ada target kata dari guru" + saran menjelajah level sendiri |
| Riwayat masih kosong | "Belum ada kata yang dipelajari" + CTA mulai belajar |
| Filter "difficult" tidak menghasilkan apa-apa | "Tidak ada kata yang perlu diulang" (nada positif, ini kabar baik) |
| DictionaryAPI tidak punya entri / gagal | POS & terjemahan Indonesia **tetap tampil** (datanya dari bank kosakata sendiri); bagian definisi Inggris & contoh kalimat diganti teks redup "Definisi bahasa Inggris tidak tersedia untuk kata ini". Bukan error screen |
| Audio tidak tersedia dari DictionaryAPI | Tombol speaker **tetap aktif**, memakai text-to-speech browser. Jangan tampilkan tombol mati |
| Terjemahan sebuah makna masih kosong | Placeholder/skeleton singkat saat client memanggil Worker, lalu tampilkan hasilnya. Kalau gagal juga, tampilkan "—" redup, bukan error |
| Generate cerita gagal | Pesan inline ramah + tombol "Coba lagi" (§3.4) |

Prinsipnya: **siswa tidak boleh pernah melihat pesan error mentah** dari
Firestore, Worker, atau DictionaryAPI.

## 6. Navigasi & Responsif (baru di versi 6)

### 6.1 Navigasi tunggal, dua bentuk

Versi Android lama memakai **bottom nav 2 tab**. Untuk versi web, itu
diganti **satu sistem navigasi yang berubah bentuk mengikuti lebar layar**:

- **Layar lebar (desktop/tablet):** `NavigationRail` di sisi kiri — ikon +
  label, item aktif ditandai navy.
- **Layar sempit (HP — target utama):** tab horizontal di atas, di bawah app
  bar. Rail vertikal memakan lebar yang sudah sempit, jadi tidak dipakai di
  sini.

Bangun sebagai **satu widget shell reusable** yang dipakai baik oleh siswa
(Belajar · Riwayat) maupun guru (Target Kata · Kosakata) — jangan dua
implementasi terpisah.

### 6.2 Aturan responsif

- **Desain kanonis di lebar ~390px.** Ini ukuran HP dan pengguna
  sesungguhnya ada di sini — layar sempit yang harus paling matang, bukan
  desktop.
- **Di layar lebar, jangan diregangkan.** Bungkus konten utama dengan
  max-width terpusat (sekitar 480–600px) supaya terlihat sebagai kolom
  aplikasi yang disengaja, bukan tombol yang melar selebar layar.
- **Breakpoint desktop yang sesungguhnya** (mis. grid kata jadi lebih banyak
  kolom, card detail muncul di panel samping alih-alih di bawah grid) adalah
  **nice-to-have**, bukan syarat skripsi. Kerjakan setelah alur mobile
  selesai.
- Target sentuh minimal ~44px untuk semua elemen yang bisa ditekan — chip
  kata, tombol (+) keranjang, dan dropdown cloze semuanya dipakai dengan
  jari di layar kecil.
- Uji dengan `flutter run -d chrome` + Chrome DevTools device toolbar, bukan
  emulator Android (`CLAUDE.md` §2).
