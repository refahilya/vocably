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

## 0. Arah Visual: Buku Latihan

Vocably adalah buku latihan siswa SMK: **sampul navy, halaman kertas dingin,
dan satu stabilo** yang menandai hal terpenting di halaman. Arah ini
mempertahankan identitas navy dari versi pertama, dan datang dari fitur
intinya, yaitu kata yang ditandai di dalam cerita.

Prinsip yang mengikat semua layar:

- **Stabilo adalah satu-satunya elemen keras.** Kuning hanya untuk fokus saat
  ini: kata target, langkah aktif, destinasi aktif. Selain itu warnanya tenang.
- **Hierarki lewat bentuk, bukan dekorasi.** Tidak ada gradien, bayangan kartu,
  atau animasi hias. Permukaan dipisahkan oleh garis tipis.
- **Radius mengikuti ukuran.** Kontrol kecil tetap tegas; hanya pill yang bulat.
- **Teks untuk dibaca memakai serif, teks antarmuka memakai sans.**
- **Layar tes tetap netral.** Semua opsi tampil sama sampai dipilih, termasuk
  "Saya tidak tahu"; tidak ada warna atau urutan yang mengarahkan jawaban.

## 1. Palet Warna

Nilai di bawah adalah token di `lib/theme/theme.dart` (`AppColors`). Kontras teks
dikunci oleh `test/theme/theme_tokens_test.dart` pada WCAG AA (4.5:1).

| Peran | Token | Warna | Kegunaan |
|---|---|---|---|
| Sampul | `primary` | `#1B1F5C` | App bar, tombol utama, stepper, chip terpilih |
| Punggung buku | `primaryDeep` | `#14173F` | Rail navigasi, snackbar |
| Tint navy | `primaryTint`, `primaryTintStrong` | `#E8EAF6`, `#CFD3EC` | Opsi terpilih, bubble siswa, soal terjawab, anak tangga level |
| Stabilo | `marker`, `markerSoft` | `#FFCF56`, `#FFF1C9` | Kata target, langkah/destinasi aktif, saran menulis |
| Teal | `accentStrong` | `#0B7285` | Avatar AI |
| Kertas | `paper` | `#F2F4FA` | Latar semua halaman |
| Lembar | `surface` | `#FFFFFF` | Lembar, field, bar bawah |
| Garis | `line`, `lineStrong` | `#DADEEC`, `#8E93B2` | Pemisah; outline field dan opsi |
| Tinta | `ink`, `inkMuted`, `inkFaint` | `#1A1D3A`, `#555A78`, `#5F6484` | Teks utama, sekunder, nonaktif |
| Success | `success` + latar | `#1F7A3A`, `#E5F4E9` | Jawaban benar, "Selesai", mastery `mastered` |
| Error | `error` + latar | `#B3261E`, `#FBE9E7` | Jawaban salah, error form |
| Warning | `warning` + latar | `#8F5500`, `#FFF4DC` | Feedback "Perlu perbaikan" |
| Info | `info` + latar | `#1558A8`, `#E4EFFB` | Feedback "Pengingat", instruksi |
| Mastery `difficult` | `masteryDifficult` | `#E07A00` | Penanda kata difficult (§5.3) |
| Nonaktif | `disabledBackground` | `#E6E8F1` | Tombol nonaktif, level C2 |

## 2. Tipografi

Dua keluarga huruf (lisensi SIL OFL), dibundel di `assets/fonts/` sebagai subset
Latin + IPA supaya tidak perlu unduhan dari luar:

- **Plus Jakarta Sans** (`AppFonts.ui`, karya Tokotype, Indonesia) untuk
  antarmuka: label, tombol, form, teks isi.
- **Literata** (`AppFonts.reading`) untuk bacaan: cerita, judul halaman, kata.

| Token `AppTextStyles` | Ukuran | Dipakai untuk |
|---|---|---|
| `pageTitle` | 26 serif tebal | Judul halaman |
| `wordTitle`, `assessmentSentence` | 24 serif | Kata pada detail/tes, kalimat soal |
| `statusTitle`, `storyTitle` | 22 serif tebal | Judul pesan status, judul cerita |
| `story`, `clozeStory` | 18 serif, baris 1,75 / 2,2 | Isi cerita, cerita dengan dropdown |
| `wordRow` | 18 serif tebal | Kata di dalam daftar |
| `sectionTitle` | 16 sans tebal | Judul bagian |
| `body`, `bodyStrong`, `bodyMuted` | 15 sans | Teks isi |
| `caption` | 13 sans | Keterangan |
| `badgeLabel` | 12 sans | Badge |

Judul kata di kartu detail tetap huruf besar semua (mis. "SOUVENIR").

## 3. Komponen & Pola Layout yang Berulang (starting point, bukan cetak biru)

### 3.1 Stepper 3-fase (dipakai di semua layar Storyfier flow)
Menyambung app bar navy pada layar Baca Cerita, Cloze Test, Tulis Bersama AI:
`1 Membaca — 2 Cloze Test — 3 Co-Write`. Step aktif = lingkaran stabilo dengan
nomor + label bold, step selesai = lingkaran putih dengan centang, step belum =
outline pucat, dan penghubung yang sudah dilewati berwarna stabilo. Di lebar
sempit barisnya mengecil utuh, jadi ketiga label selalu terbaca. **Jadikan satu
widget reusable**
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
- Saat filter "difficult" aktif, daftar menjadi **dapat dipilih**
  (`SPEC.md` §3.6):
  - Tiap baris adalah `CheckboxListTile` dengan badge mastery di kiri dan
    checkbox di kanan; awalnya tidak ada yang tercentang.
  - Di atas daftar: teks "N kata dipilih" dan dua tombol teks, **Pilih
    Semua** dan **Batalkan Pilihan** (dibungkus `Wrap` supaya tidak
    overflow di lebar HP).
  - Di bawah: tombol **"Pelajari Kembali (N kata)"** (`FilledButton` solid
    navy, full-width), nonaktif dengan label "Pelajari Kembali" bila belum
    ada yang dipilih.
  - Filter Semua/Mastered tetap berupa daftar biasa tanpa checkbox. Bila
    tidak ada kata difficult, hanya pesan "Tidak ada kata yang perlu
    diulang" yang tampil, tanpa kontrol pilihan.

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
- Input judul + "Generate" ada di atas cerita pada HP, dan di panel samping pada
  lebar ≥ 900 px, jadi lembar cerita tetap jadi pusat halaman. Sebelum ada
  cerita, lembar itu berisi petunjuk "Cerita akan muncul di sini".
- Setelah generate: judul story ditampilkan sebagai heading, isi cerita (serif,
  18 px, lebar baris nyaman) dengan target word di-highlight **stabilo kuning**
  dan teks navy tua tebal. Kata itu menampilkan kursor tangan di desktop.
- **Yang di-highlight adalah bentuk kata yang benar-benar dipakai di
  kalimat**, bukan bentuk dasarnya. Cerita datang dari Worker sudah bertanda
  `[[run|ran]]`, jadi yang tampil di layar adalah *ran* dengan highlight,
  sementara tap-nya membuka kamus detail untuk *run*. Jangan menampilkan
  penanda mentah ke siswa — selalu strip dulu. Detail di `DATA_MODEL.md` §4.
- Toggle terjemahan cerita: tombol outline "Terjemahan" di bawah cerita, di
  dalam lembar yang sama.
- **Generate ulang:** siswa bisa mengubah judul dan menekan "Generate" lagi
  berkali-kali — tiap generate ulang **menimpa** tampilan cerita sebelumnya
  di layar yang sama (bukan menambah cerita baru di bawahnya). Tombol
  "Generate" tetap aktif selama siswa belum menekan "Selanjutnya". Cerita
  yang sedang tampil **persis saat** "Selanjutnya" ditekan itulah yang jadi
  cerita resmi sesi ini.
- Bar bawah menempel: tombol solid navy "Selanjutnya →", penuh selebar layar di
  HP dan rata kanan di layar lebar.
- **Error state generate:** kalau Worker gagal (koneksi, OpenAI error, atau
  validasi penanda gagal), tampilkan pesan inline yang ramah + tombol "Coba
  lagi" — jangan layar kosong dan jangan pesan error mentah.

### 3.5 Cloze Test
- Instruksi singkat di notice biru muda atas.
- Paragraf cerita dengan blank berupa **dropdown inline** (border rounded,
  warna netral sebelum dijawab), dengan jarak baris yang memberi ruang untuknya.
  Opsi panjang dipotong dengan elipsis agar tidak melewati lebar cerita.
- **Blank menggantikan bentuk terpakai** (*ran*), sementara **pilihan di
  dropdown adalah bentuk dasar** (*run*) — sama persis dengan daftar kata
  target sesi ini. Jadi siswa memilih *run* untuk blank yang tadinya *ran*.
- **Satu blank per kata target.** Kalau satu kata muncul lebih dari sekali
  di cerita, kemunculan berikutnya tetap tampil sebagai teks biasa (boleh
  tetap di-highlight, tidak jadi blank).
- Setelah submit: dropdown berubah hijau + ikon centang (benar) atau merah +
  ikon silang (salah), jadi maknanya tidak bergantung pada warna saja. Notice
  merah muda "Ada jawaban yang salah. Jawaban yang benar ditandai hijau." muncul
  di **atas** cerita, supaya terlihat tanpa menggulir di HP.
- Dropdown terbuka menampilkan daftar pilihan kata target sebagai list polos
  (bukan dropdown native OS — custom styled).
- Bar bawah: "Submit" (nonaktif sampai semua blank terisi), lalu "Selanjutnya →"
  setelah submit.

### 3.6 Tulis Bersama AI (Co-write)
- **Target words ditampilkan sebagai pill chip di bawah stepper, dengan
  penanda terpakai/belum terpakai.** Kata yang sudah dipakai ditandai jelas
  (mis. pill navy solid + centang) versus yang belum (pill outline pucat).
  Screenshot versi lama menampilkan semuanya berwarna sama, tapi
  `SPEC.md` §5.3 mewajibkan pembedaan ini — jadi ini elemen yang **ditambah**
  di versi baru, bukan hal yang perlu dikonfirmasi lagi.
- Chat bubble: siswa di kanan (tint navy, avatar navy), AI di kiri (lembar putih
  bergaris, avatar teal), selebar maks 760 px. Daftar percakapan mengikuti
  giliran terbaru secara otomatis.
- Feedback muncul sebagai kotak kecil di bawah bubble siswa yang dinilainya
  (bukan banner terpisah), dengan ikon + warna + label semantik sesuai
  jenisnya (CW-02, `SPEC.md` §5.3): ✓ hijau "Sudah tepat", 💡 amber "Perlu
  perbaikan", 💬 biru "Pengingat". Tidak ada lagi ikon peringatan ⚠️ untuk
  semua feedback, sehingga pujian tidak terlihat seperti teguran. Jenisnya
  ditentukan aplikasi dari hasil validasi, bukan dari bunyi teks.
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
- Ikon keluar — logout (kanan atas app bar di HP, dasar rail di layar lebar).
  Tidak ada layar pengaturan atau profil.
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
Isinya sapaan "Halo, {nama}", dua panel utama (bertumpuk di HP, berdampingan
mulai ~750 px), dan satu section Pre-Test/Post-Test di bawahnya:

- **Blok "Target Kata Hari Ini"** — satu-satunya blok navy di halaman, karena
  inilah alasan siswa membuka aplikasi: ikon target stabilo, judul serif putih,
  subtitle jumlah kata (mis. "5 kata dari Guru"), panah di kanan. **"dari Guru" adalah label generik
  tetap**, bukan nama guru yang sebenarnya — jangan membaca dokumen `users`
  guru untuk menampilkan namanya di sini. (Dokumen `users` dibatasi
  read-only untuk pemiliknya sendiri, lihat `DATA_MODEL.md` §1, justru
  karena menyimpan `teacherCodeInput`; menampilkan nama asli akan butuh
  melanggar batasan itu untuk manfaat yang kecil.) Tap → daftar kata target (list,
  bukan grid chip, karena urutannya ditentukan guru) dengan tombol CTA
  "Belajar Kata Ini dengan Cerita" di bawah.
  - Empty state kalau guru belum men-set target: pesan singkat, bukan card
    kosong (§5.8).
- **Panel "Level"** — 6 level CEFR (A1–C2) sebagai **tangga naik**, karena
  levelnya berurutan dan posisi siswa di tangga itulah informasinya. Level aktif
  (`users.resultLevel`, hasil placement test yang sudah dinilai) terisi navy, level
  di bawahnya tint lebih kuat, dan teks "Level kamu saat ini: X" di atasnya.
  **C2** selalu tampil pudar (tetap bisa di-tap, tapi mengarah ke empty
  state). Tap salah satu level → masuk ke browse kosakata (§5.7), di-scope
  ke level itu. Tiap pembukaan layar dimulai bersih: mode Abjad, halaman 1,
  tanpa filter.
  - Di dalam card ini juga ada **entry point Placement Test**: teks link
    kecil "Ambil Tes Penempatan" (kalau belum pernah) atau "Lihat Tes
    Penempatan" (kalau sudah) — style link/teks kecil, bukan
    tombol besar. Ini **satu-satunya** jalan masuk setelah tawaran otomatis
    pertama lewat (`SPEC.md` §3.1), jadi pastikan tetap mudah ditemukan
    meski kecil.
- **Section "Tes penelitian"** — di bawah kedua panel, dua baris Pre-Test dan
  Post-Test. Lihat §5.5.

**Riwayat Pembelajaran bukan card di layar ini** — dia destinasi navigasi
tersendiri (§6), dengan desain di §3.3.

### 5.2 Placement Test (PT-V1.1)

> Layar: `lib/screens/student/placement_test/placement_test_screen.dart`;
> perilaku: `SPEC.md` §3.1; status: `HANDOFF.md`. Komponen pesan, banner
> error, spinner dan kartu opsi dipakai bersama layar Pre/Post-Test
> (`lib/widgets/assessment_widgets.dart`).

- **Tawaran otomatis** (sekali seumur akun): layar sambutan dengan dua aksi
  setara "Mulai Tes" (solid navy) dan "Nanti Saja" (outline). "Mulai Tes"
  membuka layar tes, yang juga menampilkan pesan bila tes belum tersedia;
  "Nanti Saja" menuju dashboard. Setelah daftar atau masuk, layar auth yang
  di-push menutup sendiri supaya tawaran ini terlihat.
- **Petunjuk:** lembar putih berisi judul "Tes Penempatan Kosakata",
  paragraf pembuka, dan 8 butir "Petunjuk" — verbatim dari spesifikasi §3.3.
  Tombol "Mulai" (baru) atau "Lanjutkan" (melanjutkan attempt) di bar bawah.
- **Butir:** satu per layar, lebar maks 640 px di tengah; garis kemajuan tipis di
  bawah app bar; caption "Soal x
  dari 50"; kalimat regular (`AppTextStyles.assessmentSentence`) dengan hanya
  kata target **tebal + bergaris bawah** (`AppTextStyles.assessmentTarget`);
  kartu opsi penuh-lebar "A. …" s.d. "D. …" lalu "E. Saya tidak tahu"; status
  kecil "Menyimpan…"/"Tersimpan"; tombol "Sebelumnya" (outline) dan "Berikutnya"
  (navy; butir terakhir: "Ringkasan") di bar bawah yang selalu terlihat. Label
  band tidak pernah tampil.
- **Ringkasan:** teks spesifikasi §3.4 untuk soal yang belum dijawab, kisi
  tombol nomor 1–50 berukuran 48 px (yang terjawab berlatar tint navy, bisa
  diketuk untuk kembali), dan "Kirim jawaban" di bar bawah yang aktif hanya bila
  50 terjawab → dialog
  konfirmasi "Periksa lagi" / "Kirim".
- **Status lain:** "Tes belum dibuka. Tunggu arahan pengawas." · "Tes
  sedang ditutup. Jawabanmu tersimpan. Tunggu arahan pengawas." · "Mohon
  tunggu" (tinjauan, netral) · "Tes dihentikan" (gangguan teknis) ·
  "Hubungi peneliti" · "Jawabanmu sudah terkirim" + "Coba lagi" bila hasil
  belum bisa diproses. Mulai yang ditolak server menampilkan status yang
  sebenarnya; bila status itu masih "siap" (mis. jam perangkat berbeda dari
  server), layar petunjuk menampilkan banner "Tes belum dapat dimulai. Tunggu
  arahan pengawas."
- **Hasil:** ikon centang dalam lingkaran, "Terima kasih. Jawabanmu sudah tersimpan.", dan
  "Level kamu: **B1**" — tanpa skor, persentase, benar/salah, atau penanda.
  Tombol "Ulangi tes" hanya untuk tes ulang belajar yang sedang dibuka;
  bila belum boleh, teks kecil kapan bisa diulang.

### 5.3 Badge Mastery (mastered / difficult) pada Chip & Card Kata

Ditambahkan ke pola chip/card kata di §3.2 dan §3.3, **tanpa bentrok** dengan
centang hijau kecil yang menandai kata di keranjang pelajari:

- Indikator mastery ditaruh di **kiri** baris kata (posisi berbeda dari centang
  keranjang yang di kanan), dan bentuknya ikut berbeda supaya tetap terbaca oleh
  siswa buta warna:
  - Lingkaran hijau = `mastered`
  - Kotak amber = `difficult`
  - Tidak ada penanda = `belum_dipelajari` (default, tanpa penanda supaya UI
    tetap bersih untuk kata yang belum disentuh)
- Karena `mastered` bersifat permanen (`SPEC.md` §6), dot hijau tidak pernah
  berubah kembali jadi amber — tidak perlu memikirkan transisi visual mundur.
- Badge yang sama dipakai di Riwayat (§3.3) dan di semua mode browse (§5.7).

### 5.4 Dashboard Guru

Mengikuti identitas warna & shape language yang sama dengan dashboard siswa
(bukan berarti layout identik):

- Wordmark "Vocably" + aksi keluar, seperti siswa (§6.1).
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

### 5.5 Pre-Test & Post-Test

> Layar tes ada di `lib/screens/student/research_assessment/`; perilakunya
> diatur `SPEC.md` §3.7. Status implementasi dan verifikasi: `HANDOFF.md`.

- **Dashboard** ("Belajar", §5.1): section "Tes penelitian" di bawah dua panel
  utama, dua baris "Pre-Test" dan "Post-Test" (lembar putih) dengan badge
  status dari data server: "Belum tersedia" (bukan peserta, atau peserta
  tanpa band / dikeluarkan / dalam tinjauan), "Belum dibuka" (belum
  diotorisasi / posttest terkunci), "Ditutup" (jendela tahap ditutup
  peneliti), "Siap dikerjakan" (biru),
  "Lanjutkan" (kuning), "Selesai" (hijau), "Dibatalkan" / "Hubungi peneliti"
  (merah), "Gagal memuat". Baris itu selalu bisa diketuk; layar tes menjelaskan
  setiap status. Badge "Segera" lama sudah dihapus.
- **Petunjuk:** lembar putih berisi teks "Petunjuk" PDF §5 persis, lalu lembar
  tint berisi "Contoh butir (kata ini bukan bagian dari tes):", contoh *book
  (kata benda)* a)–e) statis, dan kalimat penjelasannya — semua verbatim dari PDF
  (`research_instructions.dart`). Tombol "Mulai" (baru) atau "Lanjutkan"
  (melanjutkan percobaan) di bar bawah.
- **Butir:** satu butir per layar, lebar maks 640 px di tengah; kata target
  **tebal** (gaya `wordTitle`) dengan "(kelas kata)" di sampingnya (PDF
  §4.5); 4 opsi berupa kartu penuh-lebar ber-label a)–d) dalam urutan acak
  yang tersimpan, "e) Saya tidak tahu kata ini" selalu terakhir; opsi
  terpilih = border navy 2 px + latar tint navy + ikon radio terisi.
  Tombol "Lanjut" (butir terakhir: "Kirim") di bar bawah, nonaktif sampai ada pilihan, dan
  menampilkan spinner sampai server mengonfirmasi jawaban. Gagal simpan =
  banner merah muda "Jawaban belum tersimpan…"; pilihan yang sudah dikirim
  tetap dan terkunci (opsi lain nonaktif) sampai tersimpan.
- **Tidak ada** tombol kembali ke butir sebelumnya, penghitung kemajuan
  ("Butir 7/20" — belum diputuskan peneliti), skor, atau feedback
  benar/salah. Layar selesai hanya "Pre-Test selesai" + "Terima kasih.
  Semua jawabanmu sudah tersimpan."

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
di ketiga mode: tombol "Lihat Keranjang Pelajari (N kata)", selalu bisa ditekan.
Tombol "Belajar Kata Ini dengan Cerita" ada di layar keranjang. Jangan sembunyikan
di balik ikon — keranjang adalah aksi utama layar ini.

Di lebar ≥ 900 px, pemilih level dan mode pindah ke panel kiri dan kata mengalir
menjadi beberapa kolom.

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

- **< 600 px (HP — target utama):** app bar navy dengan tab horizontal di
  bawahnya; tab aktif digaris bawahi stabilo. Rail vertikal memakan lebar yang
  sudah sempit, jadi tidak dipakai di sini.
- **600–1199 px (tablet):** rail navy tua di kiri, ikon + label bertumpuk, tanpa
  app bar supaya ruang vertikal tablet tidak terbuang. Item aktif ditandai
  stabilo, logout di dasar rail.
- **≥ 1200 px (desktop):** rail yang sama, melebar dengan label di samping ikon.

Isi destinasi yang sedang terbuka tetap hidup saat bentuknya berganti, misalnya
tablet diputar di tengah mengisi form.

Bangun sebagai **satu widget shell reusable** yang dipakai baik oleh siswa
(Belajar · Riwayat) maupun guru (Target Kata · Kosakata) — jangan dua
implementasi terpisah.

### 6.2 Aturan responsif

- **Desain kanonis di lebar ~390px.** Ini ukuran HP dan pengguna
  sesungguhnya ada di sini — layar sempit yang harus paling matang, bukan
  desktop.
- **Di layar lebar, jangan diregangkan, tapi juga jangan biarkan kosong.** Lebar
  ditentukan per jenis layar, bukan satu angka global, lewat widget di
  `lib/widgets/app_layout.dart`:

| Jenis layar | Lebar maks (`AppContentWidth`) | Perilaku di layar lebar |
|---|---|---|
| Form masuk/daftar | 440 | Sampul navy di samping form mulai 900 px |
| Pesan status | 480 | Terpusat |
| Tes (placement, pre/post) | 640 | Satu kolom; panjang baris dan posisi opsi tetap sama di semua perangkat |
| Bacaan (cerita, cloze) | 680 | Satu kolom bacaan; panel judul di samping pada Baca Cerita |
| Chat Co-Write | 760 | Satu kolom |
| Daftar (riwayat, keranjang, detail kata) | 960 | Dua kolom |
| Halaman (dashboard, guru, browse) | 1160 | Dua panel atau beberapa kolom |

- **Tindakan utama selalu terlihat.** Layar tugas memakai `AppBottomBar` yang
  menempel di bawah, jadi tombol berikutnya tidak tenggelam di bawah konten.
- **Jendela pendek (< 520 px, mis. HP dimiringkan)** tetap memprioritaskan isi:
  filter kosakata pindah ke panel samping, dan header Co-Write ikut tergulir
  bersama percakapan supaya kolom tulis tetap terlihat.
- **Daftar menambah kolom sendiri** lewat `AppResponsiveList`, tetap lazy.
- Target sentuh minimal 48 px untuk tombol dan ~44 px untuk kontrol kecil —
  chip kata, tombol (+) keranjang, dan dropdown cloze semuanya dipakai dengan
  jari di layar kecil.
- **Delapan ukuran acuan** (320×640 sampai 1920×1080) diuji di
  `test/responsive/responsive_screens_test.dart` dengan font asli dan konten
  terpanjang, termasuk teks 130% di lebar 320 px.
- Uji dengan `flutter run -d chrome` + Chrome DevTools device toolbar, bukan
  emulator Android (`CLAUDE.md` §2).
