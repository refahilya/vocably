# Vocably — Project Context untuk Claude

Baca file ini di awal SETIAP sesi sebelum mulai coding. Juga baca `SPEC.md` dan
`DATA_MODEL.md` di root repo untuk detail requirement dan skema data lengkap.

> **Semua dokumen sudah di versi 6.** Versi ini hasil review konsistensi
> menyeluruh atas dokumentasi v5 — 25 temuan (inkonsistensi, ambiguitas,
> requirement hilang, risiko teknis) sudah ditutup dan keputusannya
> tertulis di keempat dokumen. **Semua keputusan di bawah sudah final —
> jangan ditanyakan ulang, dan jangan diubah tanpa diskusi eksplisit.**

## 1. Ringkasan Aplikasi

Vocably adalah aplikasi web **responsif dengan desain mobile-first**
(mayoritas siswa mengaksesnya dari HP Android) untuk belajar kosakata bahasa
Inggris dari bahasa Indonesia. Fitur belajar utamanya diadaptasi dari
penelitian **Storyfier** (UIST '23): siswa belajar lewat 3 fase berurutan —
membaca cerita yang di-generate AI, cloze test, lalu co-write cerita bersama
AI — untuk sekumpulan kata target.

Vocably juga berfungsi ganda sebagai **instrumen penelitian skripsi** —
selain fitur belajar utama, ada modul Placement Test (personalisasi level) dan
modul riset Pre-Test/Post-Test (pengukuran data penelitian) yang statusnya
masih dalam perancangan — lihat bagian 10.

Ini adalah **pengembangan kedua** dari nol. Versi pertama (Flutter for Android,
~80% jadi) di-deprecate karena requirement berubah signifikan. Versi pertama
itu **native Android app**, sedangkan versi ini web — jadi identitas visual
(warna, sifat visual/shape language) dipertahankan, tapi layout & arsitektur
komponen disesuaikan untuk web, bukan disalin persis. Detail di
`DESIGN_REFERENCE.md`.

## 2. Tech Stack (final, jangan diubah tanpa diskusi eksplisit)

- **Framework:** Dart Flutter (target web, desain mobile-first & responsif)
- **Menjalankan & menguji saat dev:** `flutter run -d chrome`, lalu pakai
  **Chrome DevTools device toolbar** untuk mengemulasi viewport HP.
  **Bukan emulator Android** — itu warisan dari versi pertama yang native
  Android; Flutter web tidak dijalankan lewat emulator. Untuk konsistensi
  origin saat memanggil Worker, jalankan dengan port tetap:
  `flutter run -d chrome --web-port=5555` (lihat catatan CORS di
  `DATA_MODEL.md` §10.1).
- **Database & Auth:** Firebase (Firestore + Firebase Auth), **plan Spark
  (gratis)** — tidak perlu upgrade Blaze/billing account sama sekali.
- **Deployment app:** Firebase Hosting via `web.app` (free tier).
- **AI proxy: Cloudflare Workers** (bukan Firebase Cloud Functions — diganti
  karena kendala billing/kartu kredit untuk Blaze plan). Ini **repo/project
  terpisah** dari Flutter app (TypeScript, deploy sendiri via `wrangler`,
  free tier tanpa kartu kredit, 100.000 request/hari). Satu-satunya alasan
  butuh proxy ini: **API key ChatGPT tidak boleh ada di client**. Worker ini
  yang menyimpan `OPENAI_API_KEY` dan meneruskan panggilan AI. Detail
  arsitektur lengkap di `DATA_MODEL.md` §10.
- **AI generation:** ChatGPT API — **selalu dipanggil lewat Cloudflare
  Worker**. Endpoint yang tersedia: `POST /generate-story`,
  `POST /cowrite-turn`, `POST /translate` (kontrak lengkap di
  `DATA_MODEL.md` §10.2).
- **Dictionary/audio pengucapan:** `https://api.dictionaryapi.dev/api/v2/entries/en`
  — dipanggil langsung dari client, tidak perlu proxy (tidak ada secret).
  Punya fallback berlapis karena API ini sering tidak punya entri (terutama
  frasa) dan tidak punya jaminan uptime — lihat `SPEC.md` §3.5.
- **Bank kosakata dibaca dari aset statis, bukan Firestore.** File JSON per
  level CEFR (`assets/vocab/vocab_a1.json` dst) dimuat ke memori untuk
  semua kebutuhan browse. Firestore tetap sumber kebenaran; aset itu
  artefak turunan. Alasannya kuota baca plan Spark — detail di
  `DATA_MODEL.md` §11.

**Dependency yang belum dikonfirmasi:** text-to-speech untuk fallback audio
(kemungkinan `flutter_tts`) — belum disetujui, minta konfirmasi dulu sesuai
§6.

## 3. Struktur Folder

```
lib/
  models/          # data classes (User, VocabWord, LearningProgress, TargetWordSet, dll)
  services/        # Firebase, Cloudflare Worker (AI proxy) client, DictionaryAPI wrapper,
                   # vocab bundle loader — satu service per integrasi/sumber data eksternal
  providers/       # state management Riverpod (Provider/StateNotifierProvider/AsyncNotifierProvider)
  screens/
    auth/            # termasuk toggle "Daftar sebagai Guru" + input kode akses, lihat §8
    student/
      dashboard/
      vocab_browser/   # 3 mode: abjad, tema, POS — semua difilter di memori
      learning_flow/   # 3 fase: read, cloze, co-write
      history/         # 2 tab: per kata, per sesi
      placement_test/  # scaffold saja untuk sekarang — lihat bagian 10
      research_assessment/  # scaffold saja untuk sekarang — pre-test & post-test, lihat bagian 10
    teacher/
      dashboard/
      target_words/
      vocab_management/   # termasuk tambah kata & edit topik kata
  widgets/          # komponen UI reusable (button, card, word_chip, nav shell, dsb)
  theme/            # theme.dart — single source of truth warna, tipografi, spacing
  utils/            # normalizeWord(), parser penanda cerita, konstanta sentinel — lihat §8

assets/
  vocab/            # vocab_a1.json … vocab_c1.json — bundle bank kosakata (§11 DATA_MODEL)

# REPO TERPISAH (bukan bagian dari project Flutter di atas):
vocably-ai-worker/   # Cloudflare Worker (TypeScript) — proxy AI, lihat DATA_MODEL.md §10
```

Jangan buat struktur folder baru di luar ini tanpa alasan jelas — tanyakan
dulu kalau perlu penyesuaian.

## 4. Coding Conventions

- Naming: `camelCase` untuk variabel/fungsi, `PascalCase` untuk class/widget,
  `snake_case` untuk nama file.
- State management: **Riverpod, dengan code generation** (`@riverpod` /
  `riverpod_generator`, bukan penulisan manual `Provider`/
  `StateNotifierProvider`/`AsyncNotifierProvider`) — ini standar final sejak
  Milestone 1. Tetap satu ekosistem Riverpod di seluruh app — jangan campur
  dengan `setState` manual di luar widget-level UI state yang murni lokal
  (misal toggle animasi kecil). Lint tambahan `riverpod_lint` aktif lewat
  `analysis_options.yaml` (`plugins:`) — bukan lewat `custom_lint`, karena
  `riverpod_lint` sejak v3.1.0 sudah tidak bergantung padanya.
- Setiap widget yang dipakai lebih dari 1 layar harus jadi reusable widget di
  `widgets/`, bukan disalin-tempel.
- Setiap panggilan ke Firebase, Cloudflare Worker (AI), DictionaryAPI, atau
  pemuatan bundle kosakata HARUS lewat layer `services/`, tidak langsung dari
  dalam widget/screen.
- **Worker tidak pernah menulis ke Firestore.** Pola yang dipakai: client
  panggil Worker → Worker balikin hasil AI mentah → **client yang menulis
  hasilnya ke Firestore**, dengan integritas dijaga Firestore Security Rules.
- **Jangan hardcode nilai sentinel.** `kNoEndDate` dan `kAllStudents`
  (`DATA_MODEL.md` §5) hidup sebagai konstanta di `utils/`, dipakai di semua
  tempat yang menulis atau membaca `targetWordSets`.
- **Jangan pernah mencari kata target di teks cerita dengan pencarian
  string.** Cerita datang dari Worker sudah bertanda `[[kata|bentuk]]`;
  parsing penanda itu satu-satunya cara yang benar. Taruh parser-nya di
  `utils/` dan pakai fungsi yang sama di Fase 1, Fase 2, dan tampilan
  riwayat.
- Update `DATA_MODEL.md` setiap kali menambah/mengubah collection atau field
  di Firestore — dokumen itu harus selalu mencerminkan skema aktual. Kalau
  perubahannya menyentuh `vocabWords`, cek juga apakah bundle (§11) perlu
  di-regenerate atau strukturnya ikut berubah.

## 5. Design System (rujukan visual)

- Semua warna, font, radius, spacing didefinisikan di `lib/theme/theme.dart` —
  **jangan hardcode nilai style di widget individual**.
- Referensi visual dari Vocably versi pertama ada di `DESIGN_REFERENCE.md`
  (screenshot + nilai token). Karena versi pertama itu native Android app,
  **yang dipertahankan hanya identitas warna & sifat visual** (shape
  language, pola highlight, dsb) — layout dan komponen dibangun dari nol
  sesuai arsitektur web yang sesuai, bukan disalin 1:1 dari layout Android.
- **Navigasi tunggal & responsif:** `NavigationRail` di kiri untuk layar
  lebar, tab horizontal di atas untuk layar sempit/HP. **Bukan bottom nav**
  (itu pola versi Android lama). Bangun sebagai satu widget shell reusable
  yang dipakai baik oleh siswa maupun guru.
- **Responsif:** desain kanonis di lebar ~390px (ukuran HP, target
  sesungguhnya). Di layar lebar, jangan diregangkan — bungkus konten dengan
  max-width terpusat supaya terlihat sengaja, bukan melar.
- **Fitur browse kosakata (3 mode) tidak punya acuan visual dari versi
  lama** — versi pertama belum punya fitur ini sama sekali. Desain baru,
  konsisten dengan identitas visual yang ada.

## 6. Aturan Kerja dengan Claude

- Kerjakan **satu fitur/modul per request**, jangan minta banyak fitur besar
  sekaligus dalam satu prompt.
- Jangan install package/dependency baru tanpa menyebutkan alasan dan meminta
  konfirmasi terlebih dahulu.
- Jangan mengubah struktur folder, state management, atau skema Firestore yang
  sudah berjalan tanpa diskusi eksplisit — ini beberapa kali menyebabkan
  inkonsistensi di iterasi sebelumnya.
- Kalau requirement dari `SPEC.md` ambigu, tanyakan dulu sebelum berasumsi.
- **Jangan pernah mengasumsikan atau mengarang sistem skoring/algoritma
  penentuan level untuk Placement Test, atau instrumen/skema soal untuk
  Pre-Test/Post-Test** — keduanya berstatus TBD (lihat bagian 10). Kalau
  diminta implementasi bagian ini, tanyakan dulu apakah metodenya sudah
  diputuskan.
- **Jangan pernah memberi akun siswa izin tulis ke `vocabWords`.** Bank
  kosakata read-only total untuk siswa — lihat §8. Kalau ada task yang
  sepertinya butuh siswa menulis ke sana, itu tanda ada salah paham;
  tanyakan dulu.
- **Field `role` di dokumen `users` cuma boleh diisi lewat alur sign up yang
  sudah didesain** (default `"siswa"`, atau `"guru"` kalau disertai kode
  akses yang tervalidasi lewat Firestore Security Rules) — lihat §8. Setelah
  dokumen `users` dibuat, `role` tidak boleh diubah lagi lewat jalur mana
  pun di client.
- **Jangan menulis Security Rules yang mengharuskan iterasi per-elemen
  array.** Bahasa rules tidak punya perulangan — aturan semacam itu tidak
  bisa ditegakkan dan pernah salah dituliskan di v5. Kalau sebuah business
  rule butuh pemeriksaan per elemen, itu sinyal bahwa struktur datanya perlu
  diubah atau aturannya perlu didesain ulang — angkat sebagai diskusi,
  jangan tulis rule yang kelihatannya benar tapi tidak bekerja.
- **Worker (Cloudflare) itu kodebase terpisah (TypeScript), bukan bagian
  dari `lib/` Flutter.** Kalau diminta kerjakan fitur AI, cek dulu apakah
  yang dimaksud itu sisi client (services/ di Flutter, manggil Worker) atau
  sisi Worker (endpoint proxy-nya sendiri).
- Commit kecil per milestone selesai (lihat urutan build di §7), jangan
  tunggu banyak fitur menumpuk baru commit.

## 7. Urutan Pembangunan (milestone)

1. **Skeleton project + koneksi Firebase** (Auth + Firestore, plan Spark) —
   tanpa fitur.
2. **Auth:** sign up (client langsung buat dokumen `users` dengan `role:
   "siswa"` default, divalidasi Firestore Security Rules) + login + routing
   berdasarkan role. Termasuk alur "Daftar sebagai Guru" dengan kode akses
   (tervalidasi lewat security rules `exists()` check ke
   `teacherAccessCodes`, BUKAN Cloud Function) — lihat §8.
3. **Design system / theme layer** + shell navigasi responsif (rail/tab,
   lihat §5), berdasarkan `DESIGN_REFERENCE.md`.
4. **Modul kosakata dasar — TANPA Worker:**
   - Setup collection `vocabWords` dengan `docId = normalizeWord(word)`,
     struktur `meanings`, dan field `updatedAt` (lihat §8).
   - Import CSV Oxford 3000/5000 (skrip manual oleh dev **di laptop
     sendiri, pakai API key dev sendiri** — bukan tugas Claude, dan tidak
     lewat Worker karena ini proses one-off).
   - Generate bundle aset per level CEFR (`assets/vocab/`), juga skrip
     dev-side.
   - Siswa: browse kosakata 3 mode (abjad/tema/POS) **dari bundle di
     memori** + keranjang "pelajari".
   - Integrasi DictionaryAPI untuk kamus detail, termasuk fallback lapisan
     1 & 2 (`SPEC.md` §3.5).
   - **Catatan:** lazy display terjemahan yang kosong butuh Worker, jadi
     bagian itu menyusul di milestone 5.
5. **Setup Cloudflare Worker + fitur guru "Tambah Kosakata":**
   - Worker (`vocably-ai-worker/`, repo terpisah): endpoint
     `/generate-story`, `/cowrite-turn`, `/translate`; verifikasi Firebase
     ID token manual (library `jose`, bukan Admin SDK); CORS allowlist
     (produksi + dev, lihat `DATA_MODEL.md` §10.1); rate limiting pakai
     Cloudflare Rate Limiting binding native (bukan KV).
   - Guru "Tambah Kosakata" (initial translate generation lewat
     `/translate`), termasuk deteksi duplikat & opsi tambah makna baru.
   - Lazy display terjemahan kosong di kamus detail siswa (tampil saja,
     tidak disimpan).
6. **Dashboard siswa:** dua card (Target Kata Hari Ini, Level) di destinasi
   "Belajar" + destinasi "Riwayat" + **scaffold placeholder** untuk entry
   point Placement Test dan Pre-Test/Post-Test (lihat bagian 10 — jangan
   bangun logic penilaian/instrumennya dulu).
7. **Fitur utama 3 fase (Storyfier core):** reading story → cloze test →
   co-write AI (generate & feedback lewat Worker, client yang menulis hasil
   ke Firestore). Termasuk parser penanda `[[kata|bentuk]]` dan logic
   update mastery (§8).
8. **Guru:** set target kata per sesi/waktu + Edit Kata (edit topik kata
   yang sudah ada).

> **Kenapa milestone 4 & 5 disusun begini (perubahan v6):** versi lama
> menaruh "guru tambah kata (translate lewat Worker)" di milestone 4,
> padahal Worker-nya baru dibangun di milestone 5 — dependensi yang
> terbalik. Sekarang semua yang butuh Worker dikumpulkan di milestone 5.

## 8. Logic Penting yang Sering Disalahpahami

### Status kata (dua variabel independen)

- `learned_status`: `belum_dipelajari` | `sudah_dipelajari`
- `mastery_status`: `mastered` | `difficult` (hanya valid/aktif jika
  `learned_status = sudah_dipelajari`)

Empat aturan yang harus dipegang:

1. **Default `difficult`** — begitu kata jadi `sudah_dipelajari`, mastery-nya
   langsung `difficult`. Tidak pernah ada "sudah dipelajari tapi mastery
   kosong". Ini juga yang menangani sesi yang ditinggal di tengah jalan.
2. **Naik ke `mastered`** hanya kalau di sesi yang sama kata itu benar di
   cloze test DAN dipakai mandiri tanpa kesalahan di co-write.
3. **`mastered` permanen — tidak bisa turun.** Kalau siswa mempelajari ulang
   kata yang sudah `mastered` lalu salah, statusnya tetap `mastered`. Logic
   update harus eksplisit menolak penurunan.
4. **"Mandiri"** = siswa menulis giliran itu tanpa menekan "saran menulis".
   Kata yang dipakai pada giliran bersaran tidak dihitung mandiri.

Detail lengkap di `SPEC.md` §6 dan `DATA_MODEL.md` §3.

### Cerita bertanda dari Worker

`/generate-story` mengembalikan cerita dengan setiap kemunculan kata target
dibungkus `[[kataTarget|bentukTerpakai]]`, mis.
`Yesterday I [[run|ran]] to the park.`

- **Jangan pernah mencari kata target dengan pencarian string.** AI menulis
  natural, jadi kata muncul dalam bentuk infleksi (`run` → *ran*) yang tidak
  akan ketemu.
- Fase 1: highlight `bentukTerpakai`, `onTap` buka kamus untuk `kataTarget`.
- Fase 2: blank menggantikan `bentukTerpakai`, jawaban benar = `kataTarget`,
  dropdown berisi bentuk dasar.
- **Satu blank per kata target** — kalau satu kata muncul dua kali, hanya
  penanda pertama yang jadi blank.
- `storyContent` disimpan **dalam bentuk bertanda**, jadi riwayat bisa
  merender ulang highlight tanpa panggilan AI. Selalu strip penanda sebelum
  menampilkan teks polos.

### Level CEFR

Level yang punya kata terisi saat ini hanya **A1–C1** (Oxford 3000/5000
memang hanya sampai C1). C2 tetap tersedia sebagai pilihan di UI tapi kosong
sampai ada kata C2 yang diinput guru. Tampilkan empty state yang jelas.
Placement test tidak pernah menghasilkan C2.

### Sesi belajar

`learningSessions` mulai di-upsert **sejak generate cerita pertama** di Fase
1, dan field `currentPhase` menandai progres sesi (`membaca` → `clozeTest` →
`coWrite` → `selesai`). Cerita yang jadi bagian resmi sesi adalah cerita yang
sedang tampil **saat siswa menekan "Selanjutnya"** — bukan cerita hasil
generate sebelumnya yang sempat dibuang lewat regenerate.

**Ketiga jalur masuk menjalankan 3 fase penuh** — Target Kata Hari Ini,
Keranjang Pelajari, dan "Pelajari Kembali" kata `difficult`. Yang membedakan
cuma `sourceType` dan asal daftar kata. (Versi lama keliru menyebut re-learn
masuk "fase 2–3" — itu mustahil karena cloze test butuh cerita dari Fase 1.)
Detail di `DATA_MODEL.md` §4.

### Bank kosakata

**`vocabWords` docId = `normalizeWord(word)`** (lowercase + trim, bukan
auto-generated ID) — ini mekanisme utama mencegah duplikat kata. Di client
gunakan `set()` (SDK client tidak punya `create()`); sifat create-only
ditegakkan **security rules**, bukan kode client.

Satu kata bisa punya **lebih dari satu makna** — array `meanings`, dengan
**`meanings[0]` = makna utama** (dipakai untuk terjemahan ringkas di
chip/list). Field `posList` adalah **turunan otomatis** dari `meanings[].pos`
— jangan diisi manual, selalu sinkron ulang tiap `meanings` berubah. Field
`updatedAt` **wajib** diperbarui di setiap tulis, karena itu yang dipakai
query delta bundle.

**`vocabWords` read-only total untuk siswa.** Penulisnya hanya skrip dev dan
akun guru. Kalau terjemahan sebuah makna masih kosong, client siswa boleh
memanggil `/translate` untuk **menampilkannya di layar**, tapi **tidak
menyimpannya**. Alasannya: aturan pengaman yang dibutuhkan kalau siswa boleh
menulis ("hanya boleh mengisi yang masih kosong") tidak bisa ditegakkan
Security Rules, sehingga izin tulis apa pun berarti siswa bisa menimpa makna
kata apa pun. Detail di `DATA_MODEL.md` §2.

Browse membaca dari **bundle aset per level**, bukan Firestore
(`DATA_MODEL.md` §11).

### Target kata: sentinel, bukan null

`targetWordSets.endAt` tidak pernah `null` (pakai `kNoEndDate`) dan
`targetStudentIds` tidak pernah `null`/kosong (pakai `[kAllStudents]`).
Kalau satu dokumen lolos dengan `null`, dokumen itu **hilang diam-diam** dari
hasil query — tidak ada error, cuma target kata yang tidak muncul di layar
siswa. Tegakkan di security rules, bukan cuma di kode. Detail & query final
di `DATA_MODEL.md` §5.

### Role assignment (`users.role`) — TANPA Cloud Functions

- Setiap akun baru dibuat **langsung oleh client** saat sign up: client
  membuat dokumen `users/{uid}` dengan `role: "siswa"` — Firestore Security
  Rules yang menegakkan boleh/tidaknya.
- Untuk jadi guru, form sign up punya opsi "Daftar sebagai Guru" + input
  kode akses. Client mengirim `role: "guru"` **beserta** kode akses yang
  diketik (field `teacherCodeInput`), dan **Security Rules** memverifikasi
  kode itu valid dengan `exists()`/`get()` ke collection
  `teacherAccessCodes` — kalau valid & `active == true`, write diizinkan;
  kalau tidak, ditolak (permission-denied). Client harus menangkap error itu
  dan menampilkan "Kode akses tidak valid", bukan pesan mentah Firestore.
- **`teacherCodeInput` disimpan permanen** sebagai audit trail (Firestore
  tidak punya konsep "field yang divalidasi tapi tidak tersimpan"). Karena
  itu dokumen `users` hanya boleh dibaca pemiliknya sendiri.
- **Kode akses = 8 karakter acak** dari generator, bukan kata bermakna —
  Security Rules tidak punya rate limiting, jadi kode yang bisa ditebak
  berarti siswa bisa jadi guru dan mengontaminasi data penelitian.
- **Setelah dokumen `users` dibuat, `role` dan `teacherCodeInput` tidak
  boleh diubah lagi** lewat `update` apa pun dari client — tegakkan eksplisit
  di security rules.
- Field yang **boleh** di-update siswa atas dirinya sendiri: `name`,
  `cefrLevel`, `placementTestCompleted`, `placementTestPrompted`.
- **Satu akun = satu role, permanen** — terjaga otomatis oleh struktur ini +
  aturan immutability di atas.

### Placement test hanya ditawarkan sekali

Tawaran otomatis sebelum dashboard pertama muncul **sekali seumur akun**;
begitu ditampilkan, set `users.placementTestPrompted = true` apa pun pilihan
siswa. Kalau siswa menunda, tawaran itu tidak muncul lagi — jalan masuk
berikutnya hanya lewat entry point di dashboard. Field ini dibutuhkan karena
`placementTestCompleted` tetap `false` baik untuk "belum pernah ditawari"
maupun "sudah ditawari tapi menunda".

## 9. Referensi Eksternal

- Storyfier paper (UIST '23) — dasar konsep 3 fase belajar (read → cloze → co-write)
- Oxford 3000 / Oxford 5000 — sumber bank kosakata (CSV 4 kolom: `word`,
  `topics`, `pos`, `sumber`; cakupan A1–C1)
- Cloudflare Workers — dokumentasi resmi untuk referensi API (`fetch`,
  Request/Response Web-standard, Rate Limiting binding) saat implementasi
  Worker
- Firestore Security Rules — dokumentasi resmi, terutama `get()`/`exists()`
  di rules dan `diff().affectedKeys()` untuk validasi field-level

## 10. Placement Test & Modul Riset (Pre-Test/Post-Test) — Status: TBD

Dua fitur ini **berbeda tujuan** dan **berbeda posisi arsitektur**, jangan
disatukan atau ditukar-tukar pemahamannya:

- **Placement Test** — mekanisme aplikasi untuk personalisasi belajar
  (menentukan `users.cefrLevel`). Sudah punya alur/entry-point di
  `SPEC.md` §3.1 dan §3.2, tapi **detail teknis penilaian & algoritma
  penentuan level CEFR-nya masih TBD** — jangan diasumsikan atau dibuatkan
  sistem skoring sendiri. Begitu metodenya diputuskan, skoring **dihitung di
  client** (tidak ada logic rahasia yang perlu disembunyikan), dengan
  jawaban mentah tetap disimpan ke Firestore supaya bisa diverifikasi ulang
  saat analisis skripsi.
- **Pre-Test / Post-Test** — instrumen pengambilan data penelitian skripsi
  (mengukur kemampuan kosakata siswa sebelum & sesudah pakai Vocably),
  awalnya direncanakan pakai Google Forms tapi diarahkan pembimbing untuk
  jadi satu kesatuan di dalam aplikasi. **Instrumennya masih disusun &
  belum divalidasi** — lihat `SPEC.md` §3.7.

Untuk sekarang, kerjakan **hanya scaffolding**: routing, entry point di
dashboard, dan struktur data placeholder (lihat `DATA_MODEL.md` §6 & §6b) —
supaya saat metodenya sudah diputuskan, instrumen yang sudah divalidasi
tinggal dipasang tanpa perombakan arsitektur besar.

### Satu hal lain yang berstatus ditunda

**Fallback definisi Inggris via ChatGPT** (endpoint `/word-details`) —
**jangan dibangun sekarang**. Keputusannya menunggu data: saat menjalankan
skrip import CSV, sekalian hitung berapa kata yang tidak punya entri di
DictionaryAPI. Kalau jumlahnya kecil, lebih murah mengisinya manual daripada
membangun endpoint baru. Lihat `SPEC.md` §3.5 lapisan 3.
