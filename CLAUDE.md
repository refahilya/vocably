# Vocably — Project Context untuk Claude

Baca file ini di awal SETIAP sesi sebelum mulai coding, lalu `HANDOFF.md`
(status terkini). Sesuai kebutuhan tugas, baca juga `SPEC.md` (perilaku),
`DATA_MODEL.md` (skema, rules, kontrak Worker), dan `DESIGN_REFERENCE.md` (UI).

> **Semua dokumen sudah di versi 6.** Versi ini hasil review konsistensi
> menyeluruh atas dokumentasi v5 — 25 temuan (inkonsistensi, ambiguitas,
> requirement hilang, risiko teknis) sudah ditutup dan keputusannya
> tertulis di keempat dokumen. **Semua keputusan di bawah sudah final —
> jangan ditanyakan ulang, dan jangan diubah tanpa diskusi eksplisit.**

## 0. Sumber Kebenaran, Dokumentasi, dan Batas Aman

**Hierarki kebenaran** — bila dua sumber berbeda, percayai urutan ini:

```
kode & tes repo  >  status/riwayat Git  >  bukti deploy terverifikasi  >  HANDOFF.md
    >  PROJECT_STATE.md / SPEC.md / DATA_MODEL.md / DESIGN_REFERENCE.md  >  percakapan sebelumnya
```

- **Kode dan tes** adalah otoritas utama untuk perilaku implementasi.
- **Periksa Git** (`git status`, `git log`, `git branch -vv`) sebelum
  melaporkan state commit/branch; jangan mengandalkan hash dari dokumen.
- **Klaim deploy** harus didukung bukti deploy yang tersedia; kalau tidak bisa
  diverifikasi, tulis begitu.

**Pemilik informasi (satu rumah per jenis informasi):**

| Informasi | Satu-satunya tempat |
|---|---|
| Aturan agen, batasan wajib, hierarki ini | `CLAUDE.md` |
| **Status terkini**: milestone, hasil tes terakhir, state Git/deploy, blocker, keputusan terbuka, known issues, langkah berikutnya | **`HANDOFF.md`** |
| Riwayat pengembangan & alasan keputusan (append-only) | `PROJECT_STATE.md` |
| Gambaran proyek, setup, langkah deploy, peta dokumen | `README.md` |
| Perilaku produk / skema, rules, kontrak Worker / UI & visual | `SPEC.md` / `DATA_MODEL.md` / `DESIGN_REFERENCE.md` |
| Perintah & keselamatan tooling | `tools/research/README.md`, `tools/vocab_import/README.md` |

**Aturan pemeliharaan dokumen:**
- Setelah perubahan implementasi, perbarui dokumen perilaku/skema/desain yang
  terdampak, dan `HANDOFF.md` bila status terkini berubah; tambahkan entri
  baru di `PROJECT_STATE.md` bila perubahannya layak dicatat sebagai riwayat.
- Ubah `CLAUDE.md` atau `README.md` hanya bila aturan durable atau panduan
  setup-nya memang berubah.
- **Status volatil** (jumlah tes, hash commit, versi deploy, tanggal
  verifikasi, "belum di-commit") **hanya** boleh ada di `HANDOFF.md` dan di
  entri riwayat `PROJECT_STATE.md`. Dokumen lain cukup menautkan ke
  `HANDOFF.md` — jangan ada salinan status yang bersaing.
- Bedakan dengan jelas: fakta terverifikasi, hasil yang dilaporkan pemilik
  proyek, fakta historis, asumsi, dan pertanyaan terbuka.

**Batas aman (wajib):**
- **Jangan pernah** commit, amend, reset, rebase, cherry-pick, stash, push,
  atau deploy kecuali pemilik proyek secara eksplisit mengizinkan tindakan itu.
  Commit dan push dilakukan pemilik proyek.
- **Jangan pernah** menulis ke produksi, mengubah Firebase rules, data
  produksi, atau deployment Worker sebagai bagian dari pekerjaan dokumentasi —
  dan untuk pekerjaan lain pun hanya dengan izin eksplisit.
- Deploy Worker: **jangan pernah** `wrangler deploy` polos dari working copy
  yang memuat origin lokal (`localhost:5000`) di `wrangler.jsonc`; pakai
  override `--var ALLOWED_ORIGINS` (`README.md` "Deployment"). Jangan pernah
  membaca, mencetak, atau meng-commit `.dev.vars` atau secret apa pun.

## 1. Ringkasan Aplikasi

Vocably adalah aplikasi web **responsif dengan desain mobile-first**
(mayoritas siswa mengaksesnya dari HP Android) untuk belajar kosakata bahasa
Inggris dari bahasa Indonesia. Fitur belajar utamanya diadaptasi dari
penelitian **Storyfier** (UIST '23): siswa belajar lewat 3 fase berurutan —
membaca cerita yang di-generate AI, cloze test, lalu co-write cerita bersama
AI — untuk sekumpulan kata target.

Vocably juga berfungsi ganda sebagai **instrumen penelitian skripsi** —
selain fitur belajar utama, ada modul Placement Test (level belajar siswa
dan, untuk peserta riset, band riset — PT-V1.1) dan modul riset
Pre-Test/Post-Test (pengukuran data penelitian). Kedua instrumen berasal
dari dokumen peneliti dan bank soalnya tersedia sebagai aset tanpa kunci;
aturannya ada di bagian 10, status implementasinya di `HANDOFF.md`.

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
- **Deployment app:** Firebase Hosting via `web.app` (free tier). Butuh blok `"hosting"` (`public: "build/web"`, SPA rewrite ke `/index.html`) di `firebase.json` sebelum deploy hosting — contoh dan urutan deploy di `README.md` "Deployment"; apakah blok itu sudah ada: `HANDOFF.md`.
- **Perintah test wajib:** Selalu gunakan `flutter test --concurrency=1`. Jangan gunakan `flutter test` tanpa argumen karena runner bawaan secara tidak deterministik melewatkan test file di lingkungan ini.
- **Build web produksi:** `flutter build web --release --dart-define=WORKER_BASE_URL=https://vocably-ai-worker.refahilyaa.workers.dev`.
- **AI proxy: Cloudflare Workers** (bukan Firebase Cloud Functions — diganti karena kendala billing/kartu kredit untuk Blaze plan). Ini **repo/project terpisah** dari Flutter app (TypeScript, deploy sendiri via `wrangler`, free tier tanpa kartu kredit, 100.000 request/hari). Satu-satunya alasan butuh proxy ini: **API key ChatGPT tidak boleh ada di client**. Worker ini yang menyimpan `OPENAI_API_KEY` dan meneruskan panggilan AI. Detail arsitektur lengkap di `DATA_MODEL.md` §10.
- **AI generation:** ChatGPT API — **selalu dipanggil lewat Cloudflare Worker**. Endpoint yang tersedia: `POST /generate-story`, `POST /cowrite-turn`, `POST /translate` (kontrak lengkap di `DATA_MODEL.md` §10.2).
- **Dictionary/audio pengucapan:** `https://api.dictionaryapi.dev/api/v2/entries/en` — dipanggil langsung dari client, tidak perlu proxy (tidak ada secret). Punya fallback berlapis karena API ini sering tidak punya entri (terutama frasa) dan tidak punya jaminan uptime — lihat `SPEC.md` §3.5.
- **Text-to-speech fallback audio:** Menggunakan package `flutter_tts: ^4.2.5` (sudah terpasang). **Penting:** `flutter_tts` di platform web menggunakan JS interop legasi (`dart:js`/`package:js`), sehingga **tidak kompatibel dengan flag `--wasm`**. Web build harus menggunakan target JavaScript standar.
- **Bank kosakata dibaca dari aset statis, bukan Firestore.** File JSON per level CEFR (`assets/vocab/vocab_a1.json` dst) dimuat ke memori untuk semua kebutuhan browse. Firestore tetap sumber kebenaran; aset itu artefak turunan. Alasannya kuota baca plan Spark — detail di `DATA_MODEL.md` §11.

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
      placement_test/  # tawaran sekali + layar tes PT-V1.1 (riset & belajar) — lihat bagian 10
      research_assessment/  # layar pre-test & post-test, lihat bagian 10
    teacher/
      dashboard/
      target_words/
      vocab_management/   # termasuk tambah kata & edit topik kata
  widgets/          # komponen UI reusable (layout responsif, feedback, nav shell, dsb)
  theme/            # theme.dart — single source of truth warna, tipografi, spacing
  utils/            # normalizeWord(), parser penanda cerita, konstanta sentinel — lihat §8

assets/
  vocab/            # vocab_a1.json … vocab_c1.json — bundle bank kosakata (§11 DATA_MODEL)
  research/         # instrument_v1.json — bank soal Pre/Post Test, TANPA kunci jawaban (bagian 10)
  placement/        # placement_bank_pt_v1_1.json — bank Placement Test, TANPA kunci (bagian 10)
  fonts/            # Plus Jakarta Sans & Literata (subset, lisensi OFL)

tools/              # skrip sisi dev, tidak ikut ter-bundle ke app
  vocab_import/     # pipeline CSV Oxford → Firestore + bundle aset (§7 Milestone 4)
  research/         # instrumen → bank + kunci privat (pretest & placement); uji emulator; admin peneliti; ekspor & skoring (bagian 10)

# REPO TERPISAH (bukan bagian dari project Flutter di atas):
vocably-ai-worker/   # Cloudflare Worker (TypeScript) — proxy AI, lihat DATA_MODEL.md §10
```

Jangan buat struktur folder baru di luar ini tanpa alasan jelas — tanyakan
dulu kalau perlu penyesuaian.

> Folder sementara `lib/screens/placeholders/` (bukti routing Milestone 2)
> sudah dihapus setelah destinasi aslinya ada — jangan dibuat ulang.

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
- **Arah visual "buku latihan":** sampul navy, kertas dingin, dan satu stabilo
  yang hanya menandai fokus saat ini (`DESIGN_REFERENCE.md` §0). Tidak ada
  gradien, bayangan kartu, atau animasi hias.
- **Tata letak responsif lewat `widgets/app_layout.dart`** (`AppContent`,
  `AppScrollPage`, `AppBottomBar`, `AppTwoPane`, `AppResponsiveList`) dan
  feedback lewat `widgets/app_feedback.dart`; jangan membuat varian per layar.
- **Navigasi tunggal & responsif:** `NavigationRail` di kiri untuk layar
  lebar, tab horizontal di atas untuk layar sempit/HP. **Bukan bottom nav**
  (itu pola versi Android lama). Bangun sebagai satu widget shell reusable
  yang dipakai baik oleh siswa maupun guru.
- **Responsif:** desain kanonis di lebar ~390px (ukuran HP, target
  sesungguhnya). Di layar lebar, jangan diregangkan — tiap jenis layar punya
  lebar maksimum sendiri (`AppContentWidth`) dan layar yang cocok memakai kolom
  atau panel samping. Layar tes tetap satu kolom agar sama di semua perangkat.
  Layar baru wajib masuk `test/responsive/responsive_screens_test.dart`.
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
- **Aturan skoring Placement Test adalah K2 pilihan peneliti** (bagian 10)
  — jangan diubah, diganti, atau disebut tervalidasi tanpa keputusan
  eksplisit peneliti. Butir placement hanya di-generate ulang dari file
  peneliti lewat `tools/research/bin/build_placement.js`; jangan dikarang
  atau diparafrasekan. **Instrumen Pre-Test/Post-Test tidak boleh dikarang, diubah,
  atau diparafrasekan:** satu-satunya sumber adalah PDF peneliti
  (`Rancangan_Instrumen_Pretest_Vocably.pdf`), dan bank soalnya hanya
  di-generate ulang lewat `tools/research/bin/build_instrument.js`.
- **Kunci jawaban Pre/Post Test tidak boleh masuk repo, aset Flutter, kode
  app, Firestore, Worker, log, atau pesan test.** Bank aman-app
  (`assets/research/instrument_v1.json`) sengaja tanpa kunci; kunci privat
  hanya ditulis ke path eksplisit di luar repo & di luar OneDrive (lihat
  `tools/research/README.md`).
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
- Commit dilakukan pemilik proyek (§0). Saat melaporkan pekerjaan selesai,
  sarankan commit kecil per milestone (urutan build di §7) dan sebutkan
  ruang lingkup file-nya, jangan menumpuk banyak fitur.

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
   - Import CSV Oxford 3000/5000 via `tools/vocab_import/` (dibangun
     Claude, direvisi keputusan sejak Milestone 4 autonomous run). **Claude
     boleh menulis/memelihara skrip pipeline-nya** (parsing, merge,
     dry-run report, panggilan API terjemahan, seed Firestore, generate
     bundle) — tapi **secret tetap milik dev**: `OPENAI_API_KEY` dari
     `.env` root (bukan lewat Worker, karena ini proses one-off, bukan
     traffic user produksi) dan kredensial Admin SDK
     (`GOOGLE_APPLICATION_CREDENTIALS`) dari mesin dev sendiri. **Eksekusi
     nyata yang menulis ke Firestore produksi atau memanggil API
     berbayar dalam skala penuh tetap butuh keputusan/kredensial dev** —
     lihat `tools/vocab_import/README.md` untuk pembagian tepatnya.
   - Generate bundle aset per level CEFR (`assets/vocab/`) — bagian dari
     pipeline yang sama di atas, bukan skrip terpisah.
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
   point Placement Test dan Pre-Test/Post-Test (scaffold saja pada saat itu;
   modul riset kemudian dibangun bertahap — lihat bagian 10).
7. **Fitur utama 3 fase (Storyfier core):** reading story → cloze test →
   co-write AI (generate & feedback lewat Worker, client yang menulis hasil
   ke Firestore). Termasuk parser penanda `[[kata|bentuk]]` dan logic
   update mastery (§8). *(Selesai — riwayat: `PROJECT_STATE.md` §5j–§5k.)*
8. **Guru:** set target kata per sesi/waktu + Edit Kata (edit topik kata
   yang sudah ada). *(Selesai — riwayat: `PROJECT_STATE.md` §5l.)*

> **Status terkini** (milestone, modul riset, hasil tes, Git, deploy, blocker,
> keputusan terbuka, langkah berikutnya) **hanya ada di `HANDOFF.md`**.
> Riwayat dan alasan keputusan per milestone: `PROJECT_STATE.md`.

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
   cloze test DAN dipakai mandiri tanpa kesalahan di co-write. **"Tanpa
   kesalahan" = makna & pemakaian kosakata targetnya dapat diterima**
   (dipakai bermakna, dengan makna yang dimaksud tepat), **bukan**
   kalimat yang sempurna secara tata bahasa. Kesalahan grammar/tense/
   agreement — termasuk infleksi kata target yang salah, mis. "Yesterday
   the monster attack the village." — boleh diberi feedback, tapi tidak
   otomatis menghapus kredit kosakata (CW-05, `SPEC.md` §5.3).
3. **`mastered` permanen — tidak bisa turun.** Kalau siswa mempelajari ulang
   kata yang sudah `mastered` lalu salah, statusnya tetap `mastered`. Logic
   update harus eksplisit menolak penurunan.
4. **"Mandiri"** = siswa menulis giliran itu tanpa menekan "saran menulis"
   **dan** dalam bahasa Inggris. Kata yang dipakai pada giliran bersaran,
   atau pada giliran berbahasa Indonesia/campuran (mis. "aku attack
   temanku"), hanya dihitung untuk **cakupan sesi**, tidak mandiri. Bahasa
   giliran ditentukan **aplikasi** secara deterministik
   (`containsIndonesianWords`), bukan LLM; feedback-nya berupa pengingat
   singkat untuk menulis dalam bahasa Inggris, dan bot selalu menjawab dalam
   bahasa Inggris di dalam cerita — lihat `SPEC.md` §5.3.
5. **Kata yang dipakai bot** lewat fallback tiga giliran (kata dipilih acak
   oleh **aplikasi**, divalidasi dari teks yang dihasilkan) dihitung
   terpakai di tingkat sesi, tapi **tidak pernah** mandiri / mastery. Kata
   target yang kebetulan muncul di balasan bot biasa tidak dihitung sama
   sekali. LLM tidak pernah memilih kata, menghitung giliran, atau
   memutuskan sesi selesai — lihat `SPEC.md` §5.3.

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
cuma `sourceType` dan asal daftar kata. Untuk "Pelajari Kembali", daftar kata =
kata `difficult` yang **dicentang siswa** di Riwayat (bukan otomatis semuanya;
hanya yang masih `difficult` yang dikirim) — lihat `SPEC.md` §3.6. (Versi lama keliru menyebut re-learn
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
  **Kalau ditolak, akun Auth yang baru saja dibuat langsung dihapus
  (rollback)** — supaya kode salah tidak meninggalkan akun Auth tanpa
  profil. Kegagalan lain yang tidak bisa dipastikan sebagai "kode salah"
  (network drop, dll.) tidak memicu rollback ini — lihat poin orphaned
  account di bawah.
- **Akun Auth tanpa dokumen `users` ("orphaned account")** ditangani lewat
  layar "Lengkapi Pendaftaran" (`complete_registration_screen.dart` +
  `complete_registration_controller.dart`), yang **hanya pernah membuat
  profil `siswa` default** — tidak pernah, dan tidak bisa, memulihkan akun
  sebagai `guru`. Detail lengkap di `DATA_MODEL.md` §1 poin 7.
- **`teacherCodeInput` disimpan permanen** sebagai audit trail (Firestore
  tidak punya konsep "field yang divalidasi tapi tidak tersimpan"). Karena
  itu dokumen `users` hanya boleh dibaca pemiliknya sendiri.
- **Kode akses = 8 karakter acak** dari generator, bukan kata bermakna —
  Security Rules tidak punya rate limiting, jadi kode yang bisa ditebak
  berarti siswa bisa jadi guru dan mengontaminasi data penelitian.
- **Setelah dokumen `users` dibuat, `role` dan `teacherCodeInput` tidak
  boleh diubah lagi** lewat `update` apa pun dari client — tegakkan eksplisit
  di security rules.
- Field yang **boleh** di-update pemilik akun atas dirinya sendiri, per
  role: **siswa** — `name`, `cefrLevel` (legacy, tidak dipakai app),
  `placementTestPrompted`; **guru** — `name` saja. `resultLevel`/
  `resultAttemptId`/`placementTestCompleted` hanya berubah bersama attempt
  placement yang dinilai di batch yang sama. Field lain (`uid`, `email`,
  `role`, `createdAt`, `teacherCodeInput`) immutable untuk kedua role.
  Detail matriks lengkap di `DATA_MODEL.md` §1 poin 5.
- **Satu akun = satu role, permanen** — terjaga otomatis oleh struktur ini +
  aturan immutability di atas.

### Keputusan yang dikunci (jangan diubah tanpa persetujuan eksplisit)

- **Aturan Co-Write fase 2** (`SPEC.md` §5.3): aplikasi — bukan LLM —
  memegang penghitung, pemilihan kata, dan selesainya sesi; kata fallback bot
  dihitung di tingkat sesi tapi tidak pernah sebagai mastery; kata target
  yang kebetulan muncul di balasan bot biasa tidak pernah dikreditkan.
- **Paritas validator Dart ⇄ TypeScript** (`lib/utils/cowrite_validator.dart`
  ⇄ `vocably-ai-worker/src/cowriteValidator.ts`) — ubah keduanya, dengan tes
  yang sama.
- **Integritas `usedForm` di `/generate-story` dijaga lewat prompt saja** —
  tidak ada validator morfologi berbasis kode di sana.
- **Tidak ada resume** untuk sesi belajar yang ditinggal (keputusan Milestone 7
  no. 1); **keranjang pelajari baru dikosongkan setelah `/generate-story`
  pertama berhasil** (keputusan no. 4); **"Pelajari Kembali" hanya memakai kata
  difficult yang dicentang siswa** (menggantikan keputusan no. 2).

### Placement test hanya ditawarkan sekali

Tawaran otomatis sebelum dashboard pertama muncul **sekali seumur akun**;
begitu ditampilkan, set `users.placementTestPrompted = true` apa pun pilihan
siswa. Kalau siswa menunda, tawaran itu tidak muncul lagi — jalan masuk
berikutnya hanya lewat entry point di dashboard. Field ini dibutuhkan karena
`placementTestCompleted` tetap `false` baik untuk "belum pernah ditawari"
maupun "sudah ditawari tapi menunda".

## 9. Referensi Eksternal

- Storyfier paper (UIST '23) — dasar konsep 3 fase belajar (read → cloze → co-write)
- Oxford 3000 / Oxford 5000 — sumber bank kosakata (CSV 5 kolom: `word`,
  `cefrLevel`, `topics`, `pos`, `source` — header yang diwajibkan
  `tools/vocab_import/bin/merge.js`; cakupan A1–C1)
- Cloudflare Workers — dokumentasi resmi untuk referensi API (`fetch`,
  Request/Response Web-standard, Rate Limiting binding) saat implementasi
  Worker
- Firestore Security Rules — dokumentasi resmi, terutama `get()`/`exists()`
  di rules dan `diff().affectedKeys()` untuk validasi field-level

## 10. Placement Test & Modul Riset (Pre-Test/Post-Test)

Dua fitur ini **berbeda tujuan** dan **berbeda posisi arsitektur**, jangan
disatukan atau ditukar-tukar pemahamannya:

- **Placement Test PT-V1.1 — dibangun dan diverifikasi lokal (status
  terkini: `HANDOFF.md`).** Sumber: spesifikasi peneliti
  `Vocably_Spesifikasi_Placement_Test_v1.0.pdf` + `placement_items_v1.0.json`
  (di luar repo, memuat kunci). 50 butir, 5 band × 10, opsi A–D tetap + E.
  Perilaku: `SPEC.md` §3.1; skema & rules: `DATA_MODEL.md` §6/§6b.
  - **Skoring K2** (pilihan peneliti, **belum divalidasi ahli/pembimbing**
    — jangan sebut tervalidasi): band lolos bila ≥ 7, semua band di bawahnya
    ≥ 6, paling banyak satu tepat 6; level = band lolos tertinggi, atau A1*.
  - **Penilaian di Firestore Security Rules**, bukan di client dan bukan di
    Worker: kunci hanya di `placementKey/{version}` (tidak bisa dibaca
    client); rules menghitung ulang K2 dari jawaban beku dan hanya menerima
    hasil yang tepat, sekali. **Kunci placement tidak boleh masuk repo, aset,
    kode app, log, atau pesan test** — hanya file privat peneliti dan dokumen
    `placementKey` yang ditulis tooling. Tidak ada MAC, tidak ada tulisan
    Worker.
  - Hasil untuk siswa hanya **level** (`users.resultLevel`); skor band,
    total, dan penanda mutu tidak pernah disimpan atau ditampilkan —
    diturunkan offline (`bin/export_placement.js`).
  - Attempt **riset** (peserta tanpa band) mengisi band peserta otomatis;
    attempt **belajar** tidak pernah menyentuh data riset. Sinyal (penanda,
    `tabSwitchCount`) tidak pernah memicu tindakan; pembatalan integritas
    hanya setelah tinjauan manusia terkonfirmasi, tanpa attempt pengganti.
  - **Kebijakan riset yang belum final** (kriteria inklusi bersyarat untuk
    band manual, bukti yang sah, peninjau banding, dll.) tercatat di
    `HANDOFF.md` — jangan diputuskan sendiri; tooling menolak (fail
    closed) aksi yang bergantung padanya.
- **Pre-Test / Post-Test — instrumen sudah dirancang; fitur app dan
  tooling peneliti sudah dibangun (status terkini: `HANDOFF.md`).** Instrumen pengambilan data penelitian skripsi (mengukur
  kemampuan kosakata siswa sebelum & sesudah pakai Vocably), awalnya
  direncanakan pakai Google Forms tapi diarahkan pembimbing untuk jadi satu
  kesatuan di dalam aplikasi.
  - **Sumber tunggal instrumen:** PDF peneliti
    `Rancangan_Instrumen_Pretest_Vocably.pdf` (tidak disimpan di repo karena
    memuat kunci jawaban). 4 band (A2, B1, B2, C1) × 20 butir pilihan ganda:
    4 opsi arti bahasa Indonesia + "Saya tidak tahu kata ini". Pretest &
    posttest memakai 20 butir yang sama per siswa; posttest **segera setelah
    sesi treatment ke-4** (4 sesi × 5 kata, alur Storyfier → Cloze →
    Co-Write). Rencana sampel **35–40 siswa**.
  - **Validasi ahli & uji coba pada non-responden masih belum dilakukan** —
    jangan sebut instrumen ini valid/reliabel.
  - **Letak komponen:** bank soal aman-app `assets/research/instrument_v1.json`
    (tanpa kunci; hanya di-generate ulang lewat
    `tools/research/bin/build_instrument.js`); rules riset di
    `firestore.rules` (`DATA_MODEL.md` §6b), diuji di **emulator lokal**
    (project `demo-vocably-test`, `cd tools/research && npm run test:rules`,
    butuh Java 21+); kode app di `services/research_*`,
    `providers/research_assessment_providers.dart`,
    `screens/student/research_assessment/`; tooling peneliti (seed bank,
    enrol, otorisasi, void, retake) dan ekspor/skoring di `tools/research/`
    (lihat README-nya).
  - **Band & otorisasi tes hanya dari `researchParticipants`** (ditulis
    tooling peneliti, atau band otomatis dari attempt placement riset yang
    dinilai rules) — **`users.cefrLevel`/`users.resultLevel` tidak pernah
    dipakai** untuk band/kelayakan. Pretest/posttest juga butuh jendela
    tahap terbuka (`researchStudy/current`).
  - **Tooling peneliti menulis ke produksi hanya dengan izin eksplisit
    pemilik proyek dan kredensialnya sendiri**; default-nya dry-run terhadap
    emulator. Jangan pernah mencetak kunci jawaban, kredensial, atau data
    peserta.
  - **Jangan klaim penyelesaian sesi treatment ke-4 terverifikasi otomatis** —
    aplikasi belum melacak sesi treatment; pembukaan posttest adalah atestasi
    peneliti (`--confirm-session4-completed`).
  - **Keputusan riset yang belum final** (mis. review ahli B2-06, retensi data,
    prosedur retake, akses ekspor) tercatat di `HANDOFF.md` — jangan
    diputuskan sendiri.
  - **Skoring Pre/Post Test dilakukan offline oleh peneliti** (bukan di
    app), dengan kunci privat: B = 1, S/T/K = 0, skor maks 20, Gain = Post −
    Pre, N-gain = (Post − Pre)/(20 − Pre) dan tidak dihitung bila Pre = 20.
    Siswa tidak pernah melihat feedback benar/salah, skor, atau kunci.

Placement Test dan Pre/Post Test: dibangun bertahap per milestone yang
disetujui — jangan melompat ke milestone berikutnya (mis. tooling enrolmen
peserta tanpa band, deploy) tanpa persetujuan eksplisit.

### Satu hal lain yang berstatus ditunda

**Fallback definisi Inggris via ChatGPT** (endpoint `/word-details`) —
**jangan dibangun sekarang**. Keputusannya menunggu data: saat menjalankan
skrip import CSV, sekalian hitung berapa kata yang tidak punya entri di
DictionaryAPI. Kalau jumlahnya kecil, lebih murah mengisinya manual daripada
membangun endpoint baru. Lihat `SPEC.md` §3.5 lapisan 3.
