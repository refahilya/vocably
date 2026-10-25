# Vocably — Data Model (Firestore) (versi 6)

Skema ini turunan langsung dari `SPEC.md`. Update dokumen ini setiap kali ada
collection/field baru ditambahkan saat implementasi (lihat aturan di
`CLAUDE.md` §4 & §6).

Konvensi: nama field `camelCase`, nama collection jamak (`users`, bukan
`user`). Semua timestamp pakai Firestore `Timestamp`, bukan string.

> **Perubahan arsitektur di versi 5 (masih berlaku):** proyek ini **tidak
> memakai Firebase Cloud Functions** (kendala billing — tidak ada kartu
> kredit/debit untuk upgrade plan Blaze). Firebase tetap di **plan Spark
> (gratis)**. Konsekuensinya: semua yang sebelumnya "diatur lewat Cloud
> Function" sekarang **ditegakkan lewat Firestore Security Rules** (untuk
> validasi tulis) atau dipindah ke **Cloudflare Worker** (untuk panggilan
> yang butuh menyembunyikan API key, yaitu ChatGPT API). Lihat §10.

> **Perubahan di versi 6** (hasil review konsistensi dokumentasi — semua
> sudah diputuskan, jangan ditanyakan ulang):
> 1. **`vocabWords` sepenuhnya read-only untuk siswa.** Lazy retry
>    terjemahan tidak lagi menulis ke Firestore — lihat §2. Aturan
>    immutability per-elemen `meanings` yang direncanakan di v5 **dihapus**
>    karena tidak bisa ditegakkan Security Rules (rules tidak punya
>    perulangan untuk array of map).
> 2. **Bank kosakata didistribusikan sebagai aset statis per level CEFR**
>    untuk keperluan browse — Firestore tetap sumber kebenaran. Lihat §11
>    (bagian baru) dan konsekuensinya di §8.
> 3. **Field baru:** `vocabWords.updatedAt`, `users.teacherCodeInput`,
>    `users.placementTestPrompted`.
> 4. **Field dihapus:** `teacherAccessCodes.usedBy` (§2c).
> 5. **Sentinel menggantikan `null`** di `targetWordSets.endAt` dan
>    `targetWordSets.targetStudentIds` (§5).
> 6. **Kontrak Worker diperjelas:** `/generate-story` mengembalikan cerita
>    dengan penanda inline, `/cowrite-turn` mengembalikan field terstruktur
>    untuk perhitungan mastery (§10.2).
> 7. **Aturan mastery final:** default `difficult`, dan `mastered` bersifat
>    permanen (tidak bisa turun) — §3.

## 1. `users`

Satu dokumen per akun (siswa & guru sama-sama di collection ini, dibedakan
lewat field `role`), `docId` = Firebase Auth `uid`.

| Field | Tipe | Keterangan |
|---|---|---|
| `uid` | string | sama dengan `docId`, disimpan juga untuk query yang butuh field eksplisit |
| `email` | string | dari Firebase Auth |
| `name` | string | |
| `role` | string enum | `"siswa"` \| `"guru"` — **lihat alur assignment di bawah, ditegakkan lewat security rules, bukan server function** |
| `createdAt` | Timestamp | |
| `cefrLevel` | string enum \| null | **hanya untuk siswa** — hasil placement test (`A1`–`C2`, lihat catatan cakupan di §2), `null` kalau belum tes. **Hanya untuk tampilan/personalisasi**: siswa boleh mengubahnya sendiri (§1 poin 5), jadi **tidak pernah** menentukan band riset maupun kelayakan tes (band riset ada di `researchParticipants`, §6b) |
| `placementTestCompleted` | boolean | **hanya untuk siswa** — default `false` |
| `placementTestPrompted` | boolean | **hanya untuk siswa** — default `false`; di-set `true` begitu tawaran placement test otomatis pernah ditampilkan sekali. **Ini mekanisme yang menegakkan aturan "kalau siswa menunda, tawaran tidak muncul lagi"** (SPEC §3.1) — tanpa field ini, aplikasi tidak punya cara membedakan "belum pernah ditawari" dari "sudah ditawari tapi ditunda", karena `placementTestCompleted` tetap `false` di kedua kasus |
| `teacherCodeInput` | string \| absent | **hanya untuk guru** — kode akses yang diketik saat sign up, **disimpan permanen sebagai audit trail** (bukan field sementara). Lihat catatan di bawah |

> Kenapa satu collection untuk dua role, bukan dipisah `students`/`teachers`?
> Supaya query auth & profile tetap sederhana (satu lookup by `uid`). Field
> yang cuma relevan untuk satu role (`cefrLevel`, `teacherCodeInput`, dst)
> cukup dibiarkan `null`/absent untuk role lainnya — jangan buat collection
> terpisah kecuali nanti field spesifik-role bertambah banyak.
>
> **Catatan persiapan responden penelitian:** Skema `users` saat ini hanya
> mencatat `name` dan `email`. Jika analisis kohort skripsi membutuhkan data
> identifikasi spesifik (seperti kelas, NISN, atau asal sekolah), field ini
> perlu ditambahkan ke skema dan form pendaftaran sebelum 35–40 siswa
> responden didaftarkan.

> **Soal `teacherCodeInput` disimpan permanen:** di Firestore tidak ada
> mekanisme "field yang divalidasi tapi tidak ikut tersimpan" — apa pun yang
> dikirim di operasi `create` akan tersimpan. Jadi alih-alih berpura-pura
> field ini sementara, kita **memperlakukannya sebagai audit trail
> eksplisit**: dari collection `users` kita bisa langsung tahu guru mana
> memakai kode mana. Ini juga yang membuat field `usedBy` di
> `teacherAccessCodes` jadi tidak perlu (lihat §2c).
>
> Konsekuensi keamanannya kecil dan sudah diterima: kode akses guru
> tersimpan plaintext di dokumen `users` milik guru itu sendiri. Security
> rules harus memastikan **dokumen `users` hanya bisa dibaca oleh pemiliknya
> sendiri** (`request.auth.uid == uid`), sehingga siswa tidak bisa membaca
> dokumen guru dan memanen kodenya dari sana.

> **Alur assignment `role` (default siswa, guru via kode akses) — TANPA
> Cloud Function, murni Firestore Security Rules:**
> 1. **Client** (bukan server function) yang membuat dokumen `users/{uid}`
>    langsung setelah sign up berhasil di Firebase Auth. Security rules yang
>    menentukan apakah tulisan itu diterima.
> 2. **Skenario siswa (default):** client mengirim `create` ke `users/{uid}`
>    dengan `role: "siswa"`. Rule mengizinkan ini **selalu**, asal
>    `request.auth.uid == uid` (dokumen cuma boleh dibuat oleh pemilik akun
>    itu sendiri) dan field lain sesuai skema (tipe data benar, dll).
> 3. **Skenario guru:** client mengirim `create` ke `users/{uid}` dengan
>    `role: "guru"` **plus** field `teacherCodeInput` berisi kode yang
>    diketik user. Rule memvalidasi:
>    `exists(/databases/$(database)/documents/teacherAccessCodes/$(request.resource.data.teacherCodeInput))`
>    **dan** dokumen kode itu punya `active == true`. Kalau salah satu gagal,
>    seluruh write ditolak (permission-denied) — akun **tidak dibuat sama
>    sekali** dengan role guru (tidak ada fallback diam-diam jadi siswa;
>    kalau write-nya ditolak, client harus tampilkan error "Kode akses tidak
>    valid" dan minta user coba lagi atau mendaftar sebagai siswa).
>    - **Rollback akun Auth (diimplementasikan di Milestone 2):** karena
>      akun Firebase Auth sudah terlanjur dibuat *sebelum* penulisan profil
>      guru ditolak, client menghapus (rollback) akun Auth tersebut begitu
>      `permission-denied` ini **spesifik dikonfirmasi** berasal dari
>      percobaan `role: "guru"` — supaya kode akses yang salah ketik tidak
>      meninggalkan akun Auth menggantung tanpa profil. Kegagalan lain yang
>      tidak bisa dipastikan sebagai "kode salah" (mis. jaringan terputus,
>      Firestore sementara tidak bisa diakses) **tidak** memicu rollback ini
>      — lihat poin 7 di bawah untuk penanganan kasus tersebut.
>    - Karena `teacherCodeInput` sekarang bagian resmi dari skema, rule
>      validasi skema pada `create` harus **mengizinkan** field ini untuk
>      `role == "guru"` dan **menolaknya** untuk `role == "siswa"`.
>    - **Penting soal `get()`/`exists()` di security rules:** pemanggilan ini
>      dievaluasi di sisi server saat rules dijalankan, dan **tidak
>      memerlukan izin baca eksplisit milik user** ke collection yang dicek
>      — jadi `teacherAccessCodes` tetap bisa punya `allow read: if false`
>      untuk akses langsung, sementara rule `users` tetap bisa mengintip
>      keberadaannya lewat `exists()`. Ini pola standar Firestore Security
>      Rules, bukan celah keamanan.
> 4. **Field `role` immutable setelah dibuat:** rule `update` pada
>    `users/{uid}` HARUS memastikan
>    `request.resource.data.role == resource.data.role`. Terapkan hal yang
>    sama untuk `teacherCodeInput` (audit trail tidak boleh diubah setelah
>    dicatat).
> 5. **Field yang BOLEH di-update oleh pemilik akun, per role (final,
>    diimplementasikan & diverifikasi di Milestone 2):**
>    - **Siswa:** `name`, `cefrLevel`, `placementTestCompleted`,
>      `placementTestPrompted`.
>    - **Guru:** `name` saja — tidak ada field lain yang relevan untuk
>      diedit guru atas profilnya sendiri di milestone ini.
>    Field di luar daftar sesuai role masing-masing ditolak — termasuk
>    `uid`, `email`, `role`, `createdAt` (immutable untuk kedua role) dan
>    `teacherCodeInput` (immutable untuk guru, dan tidak pernah boleh ada
>    sama sekali di dokumen siswa). Field self-update siswa penting karena
>    skoring placement test dihitung di client (§6).
> 6. Karena tiap akun (`uid`) cuma punya satu dokumen `users` dengan satu
>    field `role`, dan email di Firebase Auth memang unik per akun, aturan
>    **"satu email = satu role"** otomatis terjaga oleh struktur ini +
>    aturan immutability di atas.
> 7. **Akun Auth tanpa dokumen `users` ("orphaned account") —
>    diimplementasikan di Milestone 2.** Bisa terjadi kalau sign up berhasil
>    membuat akun Firebase Auth tapi penulisan dokumen `users/{uid}`
>    gagal/terputus dengan cara yang **tidak** bisa dipastikan sebagai kode
>    akses guru yang salah (mis. koneksi putus tepat setelah Auth berhasil,
>    Firestore sementara tidak bisa diakses) — berbeda dari kasus poin 3,
>    yang justru menghapus akun Auth-nya. Klien menangani skenario ini
>    dengan layar "Lengkapi Pendaftaran"
>    (`screens/auth/complete_registration_screen.dart` +
>    `providers/complete_registration_controller.dart`): begitu Firebase
>    Auth punya user tapi `users/{uid}` tidak ditemukan, layar ini
>    ditampilkan dan **hanya pernah membuat profil `siswa` default** lewat
>    jalur `create` yang sama persis (dan divalidasi rule yang sama persis)
>    dengan sign up siswa biasa. Jalur ini **tidak pernah, dan secara
>    struktural tidak bisa**, membuat atau memulihkan akun sebagai `guru` —
>    ini murni defensive engineering untuk pendaftaran yang terinterupsi,
>    bukan cara baru untuk assignment role.

## 2. `vocabWords`

Bank kosakata master (bukan per-siswa). Di-import via CSV dari Oxford
3000/5000, dan bisa ditambah manual oleh guru (SPEC §4.1 "Tambah Kosakata").

> **Collection ini read-only untuk siswa.** Satu-satunya penulis adalah
> skrip import dev (lewat Admin SDK lokal) dan akun guru. Tidak ada alur
> apa pun di aplikasi siswa yang menulis ke sini — lihat "Alur generate
> translation" di bawah. Konsekuensinya untuk browse: karena bank
> kosakata praktis statis, browse **tidak membaca dari Firestore** melainkan
> dari aset statis per level (§11).

> **`docId` = `normalizeWord(word)`** — bukan auto-generated ID.
> `normalizeWord(raw) = raw.trim().toLowerCase()`. Contoh: kata "Apple" →
> `docId = "apple"`. Untuk frasa multi-kata (mis. "wake up", "look after" —
> ada beberapa di Oxford 3000/5000), spasi di tengah **tetap dipertahankan
> apa adanya** setelah trim+lowercase (Firestore docId mendukung spasi;
> yang tidak boleh cuma karakter `/`, dan docId tidak boleh persis `.`,
> `..`, atau match pola `__.*__` — kata bahasa Inggris normal tidak akan
> kena batasan ini). Taruh fungsi `normalizeWord()` di `utils/` dan pakai
> **fungsi yang sama persis** di mana pun docId perlu dihitung (CSV import
> script, generator bundle §11, fitur Tambah Kosakata guru, dan setiap kali
> kode perlu mencocokkan `wordId` ke suatu kata) — supaya tidak ada
> inkonsistensi normalisasi.
>
> **Kenapa docId = kata, bukan auto-ID?** Ini mekanisme utama yang mencegah
> duplikat kata secara struktural: docId di Firestore unik per collection,
> jadi kata yang sama tidak mungkin punya dua dokumen.
>
> **Cara menegakkannya di client (koreksi dari v5):** SDK client
> (`cloud_firestore`) **tidak punya method `create()`** — itu konsep di
> server SDK dan di bahasa Security Rules. Yang dipakai di Flutter tetap
> `set()`. Sifat "create-only" ditegakkan di **rules**, bukan di kode
> client: rule `allow create` pada `vocabWords` diizinkan untuk guru,
> sementara rule `allow update` hanya mengizinkan perubahan `topics` (+
> `updatedAt`). Karena `set()` ke docId yang sudah ada dievaluasi rules
> sebagai `update` (bukan `create`), percobaan menimpa kata yang sudah ada
> otomatis ditolak — efeknya sama dengan `create()` server-side, tanpa race
> condition antara cek dan tulis, dan tanpa perlu `get()` manual dulu.

| Field | Tipe | Keterangan |
|---|---|---|
| `word` | string | kata bahasa Inggris, **sama persis dengan `docId`** (sudah dinormalisasi) |
| `meanings` | array\<map\> | satu kata bisa punya beberapa makna — lihat struktur di bawah. **`meanings[0]` adalah makna utama** (dipakai untuk terjemahan singkat di chip grid, lihat `DESIGN_REFERENCE.md`) |
| `posList` | array\<string\> | **turunan otomatis** dari `meanings[].pos` (mis. `["noun", "verb"]`), **jangan diisi manual**, selalu re-sync tiap `meanings` berubah. Sejak v6 filter browse POS dijalankan di memori dari bundle (§11), jadi field ini tidak lagi dipakai untuk query Firestore — tetap dipertahankan karena ikut masuk ke bundle dan menjaga jalur query Firestore tetap mungkin kalau suatu saat dibutuhkan |
| `cefrLevel` | string enum | `A1`–`C2` — dipakai untuk filter di SPEC §3.3, dan **menentukan file bundle mana yang memuat kata ini** (§11). **Cakupan data aktual saat ini hanya A1–C1** (sumber Oxford 3000/5000); `C2` tetap valid sebagai nilai enum untuk kata yang mungkin ditambahkan guru nanti, tapi jangan diasumsikan selalu ada isinya — UI harus menangani state kosong. **Keputusan (v6, ditutup):** field ini tetap di level kata, bukan per-makna. Data CSV sumber memang punya kata yang makna/POS-nya jatuh di level CEFR berbeda (mis. "address" A1 sebagai noun, B2 sebagai verb) — kalau ini terjadi, **semua makna tetap disimpan** di `meanings` (tidak ada yang dibuang), dan `cefrLevel` dokumen diisi dengan **level terendah** dari seluruh baris/makna sumber untuk kata itu. Level ini murni dipakai untuk penempatan bundle & filter browse, bukan penanda level tiap makna individual |
| `topics` | array\<string\> | satu kata bisa punya lebih dari satu topik, berlaku untuk keseluruhan kata (bukan per-makna). Tiap nilai harus merujuk ke `name` yang ada di collection `topics` (§2b). Terisi sejak import karena CSV sumber memang punya kolom `topics` |
| `source` | string | `"oxford3000"` \| `"oxford5000"` \| `"guru"` — bedakan asal data untuk keperluan audit/filter. **Kata yang muncul di kedua CSV sumber** (Oxford 3000 dan Oxford 5000 punya irisan kecil setelah normalisasi): tetap satu dokumen (satu `docId`, makna dari kedua baris digabung ke `meanings` seperti kasus duplikat lain), dan `source` diisi `"oxford3000"` kalau kata itu ada di Oxford 3000 (dianggap lebih fundamental), kalau tidak baru `"oxford5000"` — tidak ada nilai enum baru yang ditambahkan |
| `addedByTeacherId` | string \| null | `uid` guru kalau `source = "guru"` |
| `createdAt` | Timestamp | |
| `updatedAt` | Timestamp | **(baru di v6)** diperbarui setiap kali dokumen berubah — termasuk saat dibuat (`updatedAt == createdAt` untuk dokumen baru). **Wajib**, karena ini yang dipakai query delta bundle (§11) untuk menangkap kata baru **dan** kata lama yang topiknya diedit guru. Tegakkan di rules: `request.resource.data.updatedAt == request.time` pada setiap `create`/`update` |

**Struktur `meanings` (array of map):**

| Field (di dalam tiap elemen `meanings`) | Tipe | Keterangan |
|---|---|---|
| `pos` | string | mis. `"noun"`, `"verb"` |
| `translation` | string \| null | terjemahan Indonesia **untuk makna ini secara spesifik** — nullable, lihat alur generate di bawah. **Rename (Milestone 4):** field ini sebelumnya bernama `translationId`, walau isinya selalu teks terjemahan itu sendiri (bukan ID/referensi ke collection lain — tidak pernah ada collection `translations` terpisah). Nama lama menyesatkan, jadi di-rename ke `translation` di seluruh model Dart, Firestore, skrip import, dan bundle sebelum ada data produksi yang ditulis — aman dilakukan karena `vocabWords` masih kosong saat rename ini terjadi |

> **Kenapa `meanings` (array of map), bukan `pos: array<string>` +
> `translation: string` tunggal?** Karena satu kata bisa punya makna
> berbeda dengan **informasi yang berbeda pula per makna** — contoh
> "souvenir" sebagai noun ("oleh-oleh") vs verb (makna & terjemahan
> berbeda). Dengan `meanings`, tiap kombinasi POS+terjemahan berdiri sendiri
> sebagai satu elemen array, di dalam **satu dokumen kata yang sama**.
>
> **Urutan array bermakna:** `meanings[0]` = makna utama/paling umum. Skrip
> import dan form guru harus menaruh makna utama di posisi pertama. Tidak
> ada field `isPrimary` — urutan array yang jadi konvensinya.

> **Definisi lengkap versi Inggris (arti, contoh kalimat, audio
> pronunciation) TIDAK disimpan di sini.** Data itu diambil live dari
> `https://api.dictionaryapi.dev/api/v2/entries/en/{word}` saat kamus detail
> dibuka (SPEC §3.5).
>
> **Fallback kalau DictionaryAPI gagal atau tidak punya entri** (umum
> terjadi untuk frasa seperti "wake up", dan API ini komunitas gratis tanpa
> SLA sehingga bisa lambat/down):
> - **Lapisan 1 — degradasi rapi (wajib):** POS dan terjemahan Indonesia
>   per makna **selalu tersedia dari Firestore/bundle**, jadi kamus detail
>   tetap tampil dan tetap berguna. Bagian yang tidak tersedia (definisi
>   Inggris, contoh kalimat) diganti pesan halus, bukan error screen atau
>   spinner yang menggantung.
> - **Lapisan 2 — audio (wajib):** kalau DictionaryAPI tidak menyediakan
>   audio, pakai text-to-speech bawaan browser (Web Speech API). Kualitasnya
>   di bawah rekaman manusia tapi jauh lebih baik daripada tombol putar yang
>   mati. **Catatan:** ini kemungkinan butuh package tambahan
>   (mis. `flutter_tts`) — **belum dikonfirmasi**, ikuti aturan
>   `CLAUDE.md` §6 (minta konfirmasi sebelum menambah dependency).
> - **Lapisan 3 — definisi via ChatGPT: DITUNDA, jangan dibangun sekarang.**
>   Keputusannya menunggu pengukuran: saat menjalankan skrip import CSV,
>   sekalian probe DictionaryAPI untuk semua kata dan hitung berapa yang
>   404. Kalau jumlahnya kecil (mis. ~30 kata), lebih murah mengisinya
>   manual daripada membangun endpoint Worker baru. Jangan tambahkan
>   endpoint `/word-details` sebelum angka ini ada.

> **Alur generate `meanings[].translation` (via ChatGPT API) — direvisi di
> v6:**
> 1. **Saat CSV import** (pipeline `tools/vocab_import/`, dijalankan dev di
>    laptop sendiri, pakai `OPENAI_API_KEY` dari `.env` root — bukan lewat
>    Worker karena ini bukan traffic dari user produksi): skrip generate
>    terjemahan untuk semua makna sekaligus (batched, di-cache lokal di
>    `output/translations_cache.json` supaya tidak digenerate ulang) lalu
>    menyimpan hasilnya ke Firestore lewat Admin SDK/service account milik
>    dev (`GOOGLE_APPLICATION_CREDENTIALS`). **Claude boleh menulis dan
>    memelihara kode pipeline ini**; menjalankannya untuk menulis ke
>    Firestore produksi tetap butuh kredensial dev sendiri — lihat
>    `tools/vocab_import/README.md`.
> 2. **Saat guru menambah kata baru / makna baru** lewat "Tambah Kosakata"
>    (SPEC §4.1): client (akun guru yang login) memanggil **Cloudflare
>    Worker** endpoint `/translate` (§10) dengan kata + POS. Worker balikin
>    teks terjemahan, lalu **client guru yang menulis** hasilnya ke
>    `vocabWords/{id}` di Firestore.
> 3. Kalau panggilan Worker gagal, `translation` makna itu tetap `null` —
>    tidak ada retry otomatis di background (tidak ada scheduler tanpa Cloud
>    Functions).
> 4. **Lazy display (menggantikan "lazy retry" v5):** saat siswa membuka
>    kamus detail kata yang punya `translation` masih `null`, client
>    memanggil Worker `/translate` untuk makna itu dan **menampilkan
>    hasilnya di layar saja — TIDAK menulis ke Firestore.** Hasilnya boleh
>    di-cache di memori selama sesi aplikasi berjalan supaya tidak dipanggil
>    berulang di layar yang sama.
>
> > **Kenapa berubah dari v5?** Rencana lama (siswa menulis balik hasil
> > terjemahan) mengharuskan akun siswa punya izin `update` ke
> > `vocabWords`, dan aturan pengamannya — "hanya boleh mengubah
> > `meanings[i].translation` dari `null` ke non-null" — **tidak bisa
> > ditulis di Security Rules**: bahasa rules tidak punya perulangan, jadi
> > tidak ada cara memeriksa elemen-per-elemen pada array yang panjangnya
> > berubah-ubah. Satu-satunya rule yang bisa ditulis adalah izin
> > all-or-nothing atas `meanings`, yang artinya siswa mana pun bisa
> > menimpa seluruh makna kata apa pun lewat panggilan REST langsung.
> > Untuk penelitian yang datanya harus bersih, risiko itu tidak sepadan
> > dengan penghematan beberapa panggilan API. Maka: **siswa read-only,
> > titik.**
>
> 5. Kekosongan `translation` yang bertahan adalah **tugas dev/guru**,
>    bukan siswa. Sediakan cara sederhana untuk menemukannya saat analisis
>    (mis. skrip dev yang men-scan `meanings[].translation == null`), dan
>    isi lewat jalur guru atau skrip.

> **Alur "kata sudah ada" saat guru Tambah Kosakata / saat CSV import
> menemukan duplikat** (SPEC §4.1, §7): karena `docId` = kata yang
> dinormalisasi, kata yang sudah ada tidak bisa dibuat ulang. Tangani ini
> sebagai **operasi tambah elemen ke `meanings`** pada dokumen yang sudah
> ada, bukan error mentah:
> - **CSV import** (`tools/vocab_import/lib/merge.js`): kalau baris CSV
>   berikutnya punya kata yang sama, gabungkan maknanya ke `meanings`
>   dokumen yang sama (dan jaga agar makna utama tetap di indeks 0).
> - **Guru "Tambah Kosakata"**: kalau kata yang diinput guru sudah ada,
>   beri tahu ("Kata ini sudah ada di bank kosakata") dan tawarkan opsi
>   "Tambah makna baru ke kata ini" yang membuka form ringkas (cuma input
>   POS, terjemahan digenerate lewat Worker) untuk append ke `meanings`
>   dokumen yang sudah ada.
> - **Catatan rules:** operasi append makna oleh guru adalah `update` yang
>   mengubah `meanings`, `posList`, dan `updatedAt` — jadi rule `update`
>   `vocabWords` untuk guru perlu mengizinkan **dua bentuk perubahan yang
>   terpisah**: (a) hanya `topics` + `updatedAt` (fitur "Edit Kata", §2b),
>   dan (b) `meanings` + `posList` + `updatedAt` (fitur append makna).
>   Keduanya hanya untuk `role == "guru"`; siswa tidak masuk keduanya.

### 2b. `topics` (master list topik)

Collection kecil berisi daftar topik kanonik yang bisa dipilih (bukan
diketik bebas) saat guru mengedit `vocabWords.topics` (SPEC §4.1 "Edit
Kata") atau menambah kata baru.

| Field | Tipe | Keterangan |
|---|---|---|
| `name` | string | nama topik, mis. `"Perjalanan"`, `"Aktivitas Harian"` — **unik**, dipakai juga sebagai nilai yang direferensikan di `vocabWords.topics` |

> **`docId` (klarifikasi Milestone 4):** dokumen ini tidak punya aturan
> normalisasi docId yang didokumentasikan sebelumnya (beda dengan
> `vocabWords` yang eksplisit pakai `normalizeWord(word)`). Pipeline
> import (`tools/vocab_import/lib/seedDecision.js`, fungsi `topicSlug()`)
> memakai slug deterministik (lowercase, spasi/simbol → `_`) supaya
> re-run pipeline idempoten. Kalau fitur guru "tambah topik baru" (§4.1)
> dibangun nanti, pakai fungsi slug yang sama persis — jangan pakai
> auto-generated ID.
| `createdBy` | string | `"csvImport"` \| `uid` guru — asal topik ini pertama kali dibuat |
| `createdAt` | Timestamp | |

> Kenapa collection terpisah, bukan derive dari nilai unik di
> `vocabWords.topics`? Firestore tidak punya query "distinct". Collection
> kecil ini membuat dropdown/chip "pilih topik" di UI cukup satu query
> ringan. Collection ini **tetap dibaca live dari Firestore** (bukan dari
> bundle) karena ukurannya kecil dan guru bisa menambah topik kapan saja.
>
> Topik awal terisi dari kolom `topics` di CSV sumber saat import, jadi
> master list tidak pernah kosong sejak hari pertama.
>
> Alur "tambah topik baru" (SPEC §4.1): saat guru mengetik topik yang belum
> ada di master list dan menyimpannya, aplikasi **membuat dokumen baru di
> `topics`** (validasi uniqueness di application layer sebelum create, dan
> idealnya juga dijaga rule) sebelum menambahkan nilainya ke
> `vocabWords.topics` kata yang sedang diedit.
>
> **Batasan edit guru:** fitur "Edit Kata" hanya boleh mengubah
> `vocabWords.topics` (+ `updatedAt`) pada dokumen kata yang sudah ada —
> field lain (`word`, `meanings`, `cefrLevel`, dst) read-only dari fitur
> ini. Terapkan di rules dengan
> `request.resource.data.diff(resource.data).affectedKeys().hasOnly(['topics', 'updatedAt'])`,
> bukan cuma di UI.

### 2c. `teacherAccessCodes`

Collection untuk mekanisme assignment role guru (lihat alur lengkap di §1).
**`docId` = kode akses itu sendiri** (bukan auto-ID) — supaya rule di §1
bisa langsung `exists(.../teacherAccessCodes/$(kodeYangDiinput))` tanpa
query.

**Tidak boleh dibaca atau ditulis oleh client** (`allow read, write: if
false;` eksplisit di security rules) — collection ini hanya "diintip" lewat
`exists()`/`get()` dari rule `users` di §1, yang tidak memerlukan izin baca
terpisah (lihat penjelasan di §1).

| Field | Tipe | Keterangan |
|---|---|---|
| `active` | boolean | default `true` — set `false` kalau kode mau dinonaktifkan tanpa menghapus dokumennya |
| `createdAt` | Timestamp | |

> **Field `usedBy` dihapus di v6.** Alasannya: audit "siapa memakai kode
> apa" sekarang sudah tercatat lewat `users.teacherCodeInput` (§1), jadi
> `usedBy` cuma duplikasi informasi. Menghapusnya juga menghilangkan
> kebutuhan akan rule `update` sempit pada collection yang seharusnya
> `write: if false` — collection ini jadi benar-benar tidak bisa ditulis
> client sama sekali, yang lebih sederhana dan lebih aman.

> **Dibuat manual oleh dev/peneliti** (via Firebase Console) — setup satu
> kali di awal penelitian.
>
> **Kode harus 8 karakter acak dari generator** (mis. `k7Rq2mXf`), bukan
> kata bermakna seperti `guru2026` atau nama sekolah. Alasannya: Security
> Rules tidak punya rate limiting, jadi tidak ada yang mencegah seseorang
> mencoba menebak kode berulang kali lewat form sign up atau lewat skrip ke
> REST API. Kode bermakna bisa ditebak; 8 karakter acak (≈62⁸ kemungkinan)
> tidak bisa ditebak lewat jaringan. Kalau kode sampai tertebak, siswa bisa
> menjadi guru dan mengubah bank kosakata / target kata — artinya data
> penelitian terkontaminasi.
>
> Operasional: bagikan kode langsung ke guru yang bersangkutan, jangan lewat
> grup yang ada siswanya. Set `active: false` setelah periode rekrutmen
> selesai.
>
> Kode ini **bisa dipakai berkali-kali oleh banyak guru** (bukan
> single-use) — satu kode dibagikan ke semua guru di satu sekolah. Kalau
> nanti butuh kode single-use atau per-guru, tinggal tambah field
> `maxUses`/`usedCount` atau buat satu dokumen kode per guru.

## 3. `learningProgress`

Satu dokumen per **pasangan (siswa, kata)** — status belajar personal siswa
terhadap satu kata. Ini implementasi dari state machine di SPEC §6.

`docId` = `{studentId}_{wordId}` (supaya lookup/upsert gampang tanpa query,
dan otomatis unik per pasangan).

| Field | Tipe | Keterangan |
|---|---|---|
| `studentId` | string | `uid` siswa |
| `wordId` | string | `docId` dari `vocabWords` — **yaitu kata yang sudah dinormalisasi** (§2), bukan auto-ID |
| `learnedStatus` | string enum | `"belumDipelajari"` \| `"sudahDipelajari"` |
| `masteryStatus` | string enum \| null | `"mastered"` \| `"difficult"` \| `null` — **wajib `null` kalau `learnedStatus = "belumDipelajari"`**; **wajib non-null kalau `learnedStatus = "sudahDipelajari"`** (lihat aturan default & permanensi di bawah) |
| `firstLearnedAt` | Timestamp \| null | diisi saat `learnedStatus` pertama kali jadi `sudahDipelajari` |
| `lastUpdatedAt` | Timestamp | update tiap kali status berubah |
| `lastSessionId` | string | referensi ke `learningSessions` terakhir yang mengubah status kata ini |

> **Aturan mastery — final, jangan diubah tanpa diskusi:**
>
> 1. **Default `difficult`.** Begitu `learnedStatus` jadi
>    `"sudahDipelajari"`, `masteryStatus` **langsung diisi `"difficult"`**.
>    Tidak pernah ada kondisi "sudah dipelajari tapi mastery-nya kosong".
>    Ini juga yang menyelesaikan kasus sesi yang ditinggal di tengah jalan
>    (siswa mengerjakan cloze lalu keluar sebelum co-write): kata tetap
>    tercatat sebagai dipelajari, dengan status `difficult`, dan bisa
>    dinaikkan di sesi berikutnya.
> 2. **Naik ke `mastered`** hanya kalau di satu sesi yang sama kata itu
>    benar di cloze test **DAN** dipakai mandiri tanpa kesalahan di
>    co-write (lihat definisi "mandiri" di §4). "Tanpa kesalahan" = makna
>    dan pemakaian kosakata targetnya dapat diterima, bukan kalimat yang
>    sempurna secara tata bahasa (CW-05, §10.2; `SPEC.md` §5.3).
> 3. **`mastered` bersifat permanen — tidak bisa turun.** Kalau siswa
>    mempelajari ulang kata yang sudah `mastered` dan kali ini salah di
>    cloze dan/atau co-write, statusnya **tetap `mastered`**. Penelitian
>    ini belum punya desain untuk regresi mastery, jadi logic update harus
>    eksplisit: kalau `masteryStatus` saat ini sudah `"mastered"`, jangan
>    tulis apa pun ke field itu.
> 4. Kata `difficult` bisa dipelajari ulang berkali-kali sampai memenuhi
>    syarat nomor 2.
>
> Tegakkan aturan ini di **application layer (services/providers)** dan
> **security rules** — dua lapis, karena tidak ada Cloud Function yang bisa
> jadi validator terpusat. Rule yang perlu ditulis:
> - `masteryStatus == null` jika `learnedStatus == "belumDipelajari"`;
> - transisi `"mastered"` → `"difficult"` **ditolak**;
> - dokumen hanya boleh ditulis oleh `request.auth.uid == studentId`.

> Catatan terkait `meanings`: status belajar tetap **per kata secara
> keseluruhan**, bukan per-makna — siswa belajar kata "souvenir" sebagai
> satu kesatuan lewat cerita/cloze/co-write.

### 3a. Integritas Data Sisi Klien — Trade-off yang Diterima

Karena tidak ada Cloud Functions (§10), tulisan ke `learningProgress`,
`placementTestResults`, dan `researchAssessmentResults` divalidasi Security
Rules hanya untuk **bentuk dan transisi** data (tipe field, larangan
transisi `mastered`→`difficult`, kepemilikan dokumen) — **bukan** untuk
**keaslian** data itu. Security Rules bisa memastikan sebuah tulisan *valid
secara bentuk* (mis. `masteryStatus` bertipe enum yang benar, tidak turun
dari `mastered`), tapi tidak bisa membuktikan bahwa nilai itu memang berasal
dari sesi belajar/tes yang sungguh-sungguh dikerjakan siswa. Seorang siswa
yang memanggil Firestore SDK/REST API secara langsung (di luar alur UI
aplikasi) bisa menulis `masteryStatus: "mastered"`, atau `cefrLevel`/
`placementTestCompleted` apa pun, tanpa benar-benar mengerjakan apa pun —
rules yang ada tidak berpura-pura mencegah ini, dan tidak boleh dibaca
sebagai jaminan bahwa data ini pasti sah.

**Ini diterima sebagai keterbatasan arsitektur** — sepadan dengan trade-off
yang sudah diterima di §10.5 untuk alasan yang sama (tidak ada billing untuk
Cloud Functions/App Check yang bisa memvalidasi keaslian sisi server). Skala
penelitian ini (~35–40 siswa di lingkungan kelas) membuat insentif untuk
melakukan ini rendah, dan memperbaikinya butuh infrastruktur server yang
saat ini di luar anggaran. Kalau validitas data ini kelak jadi masalah nyata
saat analisis skripsi, mitigasi paling ringan adalah audit manual (mis. cari
`masteryStatus: mastered` tanpa `learningSessions` yang cocok datanya) —
bukan redesain arsitektur.

## 4. `learningSessions`

Satu dokumen per sesi belajar 3-fase. Ini sumber data untuk Riwayat
Pembelajaran tab "per sesi" (SPEC §3.6).

> **`docId` (klarifikasi Milestone 7):** dokumen ini **tidak** punya
> aturan docId deterministik seperti `learningProgress`'s
> `{studentId}_{wordId}` (§3) — setiap sesi baru dibuat dengan
> auto-generated id (`.add()`), karena tidak ada kombinasi field yang
> secara alami unik per sesi (satu siswa bisa punya banyak sesi untuk
> kata target yang sama, kapan saja). **Tidak ada perilaku "resume"** —
> tiap kali salah satu dari tiga entry point (§5 di bawah) memulai alur
> 3 fase, selalu dibuat dokumen baru; sesi yang ditinggal di tengah jalan
> (lihat catatan TBD di bawah) tetap tersimpan apa adanya di fase
> terakhirnya, tidak pernah dilanjutkan ulang lewat query apa pun
> (keputusan eksplisit pemilik proyek, Milestone 7).

| Field | Tipe | Keterangan |
|---|---|---|
| `studentId` | string | |
| `wordIds` | array\<string\> | kata target sesi ini — tiap elemen kata yang sudah dinormalisasi, sama seperti `docId` di `vocabWords` (§2) |
| `sourceType` | string enum | `"keranjangPelajari"` \| `"targetGuru"` \| `"pelajariUlangDifficult"` — untuk bedakan asal sesi. **Ketiganya menjalankan alur 3 fase penuh** (lihat catatan di bawah) |
| `currentPhase` | string enum | `"membaca"` \| `"clozeTest"` \| `"coWrite"` \| `"selesai"` — default `"membaca"` |
| `storyTitle` | string | judul cerita — selalu berisi judul dari generate paling terakhir, ditimpa tiap generate ulang selama `currentPhase = "membaca"` |
| `storyContent` | string | isi cerita hasil generate lewat Worker (`/generate-story`, §10) — **disimpan dalam bentuk bertanda** `[[kataTarget\|bentukTerpakai]]`, bukan teks bersih (lihat catatan penanda di bawah). Ditimpa tiap generate ulang selama `currentPhase = "membaca"` |
| `storyTranslation` | string \| null | terjemahan cerita (bahasa Indonesia, **tanpa penanda** — penanda hanya relevan di teks Inggris), ditimpa dengan pola yang sama |
| `clozeTestResult` | map | `{ [wordId]: boolean }` — benar/salah per kata (dihitung di client, tanpa AI). **Satu entri per kata target**, karena by design hanya ada satu blank per kata (lihat catatan penanda) |
| `cowriteTranscript` | array\<map\> | list giliran: `{ sender: "siswa" \| "ai", text: string, feedback: string \| null, usedSuggestion: boolean }` |
| `cowriteWordsUsedCorrectly` | array\<string\> | wordId yang berhasil dipakai **mandiri** tanpa kesalahan (= dipakai bermakna dengan makna yang dapat diterima; kesalahan tata bahasa di kalimat tidak menggugurkan; mandiri = tanpa saran menulis **dan** dalam kalimat berbahasa Inggris, bukan Indonesia/campuran; kata yang dipakai bot tidak pernah masuk) — diisi client dari field terstruktur respons `/cowrite-turn` (§10.2), bukan hasil parsing teks feedback |
| `startedAt` | Timestamp | diisi saat dokumen pertama kali dibuat (generate pertama di Fase 1) |
| `completedAt` | Timestamp \| null | `null` kalau sesi belum selesai |

> **Penanda kata target di `storyContent` (baru di v6).**
>
> Worker mengembalikan cerita dengan tiap kemunculan kata target dibungkus
> penanda berformat `[[kataTarget|bentukTerpakai]]`. Contoh:
>
> ```
> Yesterday I [[run|ran]] to the park and bought two [[souvenir|souvenirs]].
> ```
>
> **Kenapa perlu:** AI menulis kalimat natural, jadi kata target hampir
> selalu muncul dalam bentuk infleksi (`run` → *ran*, `souvenir` →
> *souvenirs*, `study` → *studied*). Pencarian string sederhana untuk kata
> dasar tidak akan menemukannya — akibatnya highlight di Fase 1 tidak
> muncul dan blank di Fase 2 tidak terbentuk, justru untuk kata yang paling
> perlu dilatih. Memaksa AI memakai bentuk dasar bukan solusi: hasilnya
> kalimat yang salah secara gramatikal, yang buruk untuk aplikasi belajar
> bahasa.
>
> **Kenapa penanda inline, bukan daftar indeks karakter:** LLM sangat tidak
> akurat menghitung posisi karakter. Membungkus kata tidak butuh
> perhitungan apa pun dari model.
>
> **Cara client memakainya** (parsing regex sederhana, deterministik):
> - **Fase 1 (membaca):** render `bentukTerpakai` dengan highlight oranye;
>   `onTap` membuka kamus detail untuk `kataTarget` (bentuk dasar).
> - **Fase 2 (cloze):** ganti `bentukTerpakai` jadi blank; jawaban benar =
>   `kataTarget`; dropdown berisi daftar kata target dalam bentuk dasar.
> - **Kemunculan berulang:** kalau satu kata target muncul lebih dari
>   sekali, **hanya penanda pertama yang jadi blank**; sisanya dirender
>   sebagai teks biasa (tetap boleh di-highlight di Fase 1). Ini yang
>   menjaga `clozeTestResult` tetap satu entri per kata.
> - **Riwayat:** karena `storyContent` disimpan bertanda, tampilan riwayat
>   bisa merender ulang highlight tanpa perlu memanggil AI lagi. Selalu
>   strip penanda sebelum menampilkan teks polos di mana pun.
>
> Validasi ada di sisi Worker (§10.2): kalau ada kata target yang tidak
> bertanda dalam respons OpenAI, Worker retry sekali sebelum mengembalikan
> hasil.

> **Hati-hati: `clozeTestResult` memakai `wordId` sebagai key map.** Kata
> frasa mengandung spasi (`"wake up"`), dan field path Firestore
> memperlakukan karakter tertentu secara khusus. **Jangan** memakai operasi
> field-path parsial (mis. `update({'clozeTestResult.wake up': true})`) —
> selalu tulis map-nya utuh sekaligus.

> **Kapan dokumen ini dibuat & bagaimana "cerita final" ditentukan** (lihat
> `SPEC.md` §5.1):
>
> 1. Dokumen `learningSessions` **mulai dibuat/di-upsert sejak cerita
>    pertama berhasil di-generate** di Fase 1 (`currentPhase = "membaca"`).
>    Ini supaya progres tidak hilang kalau siswa keluar di tengah Fase 1.
> 2. Selama `currentPhase` masih `"membaca"`, tiap kali siswa menekan
>    "Generate" ulang, field `storyTitle`/`storyContent`/`storyTranslation`
>    **ditimpa langsung**. Cerita yang sempat tampil sebelumnya **tidak
>    disimpan di mana pun** — sengaja dibuang.
> 3. Begitu siswa menekan **"Selanjutnya"**, aplikasi meng-update
>    `currentPhase` jadi `"clozeTest"`. **Titik inilah yang mengunci cerita
>    final** — karena field cerita hanya boleh ditimpa selama
>    `currentPhase = "membaca"` (application layer **dan** security rules
>    menegakkan ini), nilai `storyContent` pada saat transisi otomatis
>    adalah cerita yang dipilih siswa. **Tidak perlu field/snapshot
>    terpisah.**
> 4. Pola yang sama berlaku untuk transisi `"clozeTest"` → `"coWrite"` →
>    `"selesai"`.

> **Sesi `pelajariUlangDifficult` menjalankan 3 fase penuh** (klarifikasi
> v6). Versi sebelumnya menyebut re-learn masuk "fase 2–3", tapi itu tidak
> mungkin: cloze test diturunkan dari cerita yang dibuat di Fase 1, jadi
> tanpa Fase 1 tidak ada sumber blank, tidak ada titik pembuatan dokumen
> sesi, dan tidak ada jalur `currentPhase` yang valid. Sesi re-learn
> berjalan identik dengan sesi biasa — yang membedakan hanya `sourceType`
> dan asal `wordIds` (kata berlabel `difficult` yang dipilih siswa dari
> Riwayat).
>
> Sejak 2026-10-16, `wordIds` sesi ini adalah **subset yang dicentang
> siswa**, bukan semua kata difficult, dan hanya kata yang masih
> `difficult` menurut data terbaru. Pilihan itu state UI in-memory
> (`HistoryDifficultSelection`), **tidak disimpan ke Firestore** — tidak ada
> perubahan skema atau rules. Tidak ada batas maksimal jumlah kata; rules
> tetap hanya mewajibkan `wordIds.size() > 0`.

> **Sesi yang ditinggal/tidak selesai — diputuskan di Milestone 7 (dulu
> TBD di v6).** Sebuah dokumen bisa tertinggal selamanya di `currentPhase
> = "membaca"` (atau fase lain) kalau siswa keluar di tengah jalan.
> **Keputusan final (pemilik proyek):** **tidak ada perilaku resume sama
> sekali** — entry point mana pun selalu membuat dokumen sesi baru,
> tidak pernah mencari/melanjutkan sesi lama yang belum selesai. Sesi
> yang tertinggal tetap tersimpan apa adanya di fase terakhirnya, dan
> tetap muncul di Riwayat tab "per sesi" **tanpa** penanda visual
> "belum selesai" terpisah — dirender sama seperti sesi yang sudah
> selesai. Konsekuensinya: **tidak ada query/index baru** untuk mencari
> sesi tak-selesai milik seorang siswa.

> **Perhitungan mastery dari sesi ini:** `clozeTestResult` dan
> `cowriteWordsUsedCorrectly` yang dipakai untuk menghitung `masteryStatus`
> di `learningProgress` (§3). Kata jadi `mastered` kalau `clozeTestResult[wordId] == true`
> **dan** `wordId` ada di `cowriteWordsUsedCorrectly`. Selain itu tetap
> `difficult` — kecuali kata itu sudah `mastered` sebelumnya, yang tidak
> pernah turun (§3 aturan 3).
>
> **Definisi "mandiri":** giliran siswa dihitung mandiri kalau siswa menulis
> kalimatnya **tanpa menekan tombol "saran menulis"** pada giliran tersebut.
> Karena itu tiap giliran di `cowriteTranscript` menyimpan
> `usedSuggestion: boolean` — kata yang dipakai pada giliran dengan
> `usedSuggestion == true` **tidak boleh** masuk `cowriteWordsUsedCorrectly`,
> meskipun kalimatnya benar secara gramatikal. Hal yang sama berlaku untuk
> giliran **berbahasa Indonesia/campuran** (ditentukan deterministik oleh
> client, `containsIndonesianWords`): kata sah di giliran itu (mis. `attack`
> di "aku attack temanku") hanya masuk cakupan sesi, **tidak** masuk
> `cowriteWordsUsedCorrectly`. Status bahasa giliran **tidak disimpan** di
> transcript (tidak ada field baru, tidak ada perubahan skema) — hanya
> memengaruhi state client saat sesi berjalan.
>
> **Pemakaian kata oleh bot (fallback tiga giliran, §10.2):** kata yang
> dipakai bot lewat fallback yang dipilih aplikasi dihitung terpakai di
> tingkat sesi (bisa menyelesaikan Fase 3) tetapi **tidak pernah** masuk
> `cowriteWordsUsedCorrectly`. Penghitung giliran
> (`consecutiveMissedStudentTurns`) hanya hidup di state client dan **tidak
> disimpan** di Firestore; giliran bot fallback tersimpan sebagai entri
> `sender: "ai"` biasa di `cowriteTranscript` (tanpa field tambahan) — tidak
> ada perubahan skema maupun Security Rules untuk fitur ini.

## 5. `targetWordSets`

Target kata yang di-set guru untuk siswa (SPEC §4.1). Untuk skripsi: target
berlaku global untuk semua siswa — tapi struktur sudah menyisakan ruang
untuk target per-siswa nanti.

| Field | Tipe | Keterangan |
|---|---|---|
| `teacherId` | string | `uid` guru yang membuat |
| `wordIds` | array\<string\> | kata target — kata yang sudah dinormalisasi (§2) |
| `cefrLevel` | string enum | level yang jadi dasar pemilihan kata |
| `startAt` | Timestamp | mulai berlaku |
| `endAt` | Timestamp | berakhir. **Tidak pernah `null`** — kalau tidak ada batas akhir, isi dengan sentinel tanggal jauh di masa depan (`kNoEndDate`, mis. `2099-12-31`) |
| `targetStudentIds` | array\<string\> | **Tidak pernah `null` dan tidak pernah kosong** — kalau berlaku untuk semua siswa, isi `["__all__"]` (`kAllStudents`); diisi array `uid` kalau nanti butuh target per-siswa/kelompok |
| `createdAt` | Timestamp | |

> **Kenapa sentinel, bukan `null` (baru di v6).** Query aslinya —
> `startAt <= now <= endAt` **dan** (`targetStudentIds == null` **atau**
> `array-contains studentId`) — sulit dieksekusi di Firestore: dua filter
> rentang pada field berbeda butuh index khusus dengan aturan `orderBy`
> yang ketat, dan OR antara `== null` dan `array-contains` menambah
> kerumitan di atasnya. Dengan menghapus `null`, tidak ada lagi
> percabangan, dan OR-nya bisa diungkapkan dengan satu operator.

**Query "Target Kata Hari Ini" siswa** (SPEC §3.2):

```dart
firestore.collection('targetWordSets')
  .where('targetStudentIds', arrayContainsAny: [kAllStudents, studentId])
  .where('endAt', isGreaterThanOrEqualTo: Timestamp.now())
  .orderBy('endAt')
```

Satu inequality (`endAt`) + satu filter array. Lalu **filter `startAt` di
client**:

```dart
final aktif = hasil.where((d) => d.startAt <= now).toList();
```

Filter sisa di client murah karena hasil query-nya kecil (guru menyimpan
puluhan set target sepanjang penelitian, bukan ribuan).

> **Wajib ditegakkan di rules:** `endAt` harus bertipe Timestamp (bukan
> `null`) dan `targetStudentIds` harus list non-kosong pada `create` dan
> `update`. Kalau satu dokumen saja lolos dengan `null`, dokumen itu akan
> **hilang diam-diam** dari hasil query — tidak ada error, cuma target kata
> yang tidak muncul di layar siswa, dan bug seperti ini sangat susah
> dilacak. Taruh `kNoEndDate` dan `kAllStudents` sebagai konstanta di
> `utils/` supaya tidak ada literal yang tersebar.
>
> Rules juga: `create`/`update` collection ini hanya boleh oleh user dengan
> `role == "guru"` (dicek lewat `get()` ke dokumen `users` milik
> `request.auth.uid`). Siswa `read`-only.

## 6. `placementTestResults` — Status: TBD (placeholder)

> **Jangan implementasikan skema detail di bawah ini sampai metode
> placement test diputuskan** (lihat `SPEC.md` §3.1 dan `CLAUDE.md` §10).
> Yang boleh dibangun sekarang cuma kontrak minimal yang dibutuhkan bagian
> lain aplikasi (`users.cefrLevel` perlu di-update dari suatu tempat) —
> field di bawah `resultLevel` dkk masih dugaan struktur, **bukan keputusan
> final**.

Collection ini nantinya menyimpan histori percobaan placement test siswa
(simpan semua percobaan, bukan cuma hasil terakhir), dan dipakai untuk
update `users.cefrLevel` + `users.placementTestCompleted`.

| Field | Tipe | Keterangan |
|---|---|---|
| `studentId` | string | stabil, tidak bergantung metode tes |
| `resultLevel` | string enum \| TBD | `A1`–`C1` — **sengaja tidak sampai C2** karena sumber bank kosakata baru mencakup A1–C1, jadi menempatkan siswa di C2 tidak ada gunanya (C2 tetap bisa dipilih manual di UI, lihat §2). Ini yang dipakai untuk update `users.cefrLevel` |
| `startedAt` | Timestamp | |
| `completedAt` | Timestamp | |
| *(TBD)* | *(TBD)* | Struktur soal/jawaban/skoring **menunggu keputusan metode** — jangan diasumsikan bentuknya sekarang |

> **Alur (tanpa Cloud Function):** skoring **dihitung di client** begitu
> metodenya diputuskan (tidak ada logic rahasia yang perlu disembunyikan —
> beda dengan panggilan ChatGPT API yang butuh proxy). Client yang menulis
> `resultLevel` ke collection ini **dan** meng-update `users.cefrLevel` +
> `users.placementTestCompleted`. Jawaban mentah tetap disimpan supaya skor
> bisa diverifikasi ulang saat analisis skripsi.
>
> **Soal `placementTestPrompted` (§1):** tawaran otomatis sebelum dashboard
> pertama hanya ditampilkan **sekali seumur akun**. Begitu ditampilkan,
> set `placementTestPrompted = true` — apa pun pilihan siswa (mengerjakan
> atau menunda). Kalau siswa menunda, tawaran itu **tidak muncul lagi**;
> satu-satunya jalan masuk berikutnya adalah entry point di dashboard, yang
> selalu tersedia baik untuk mengambil pertama kali maupun mengambil ulang.

## 6b. Riset Pre/Post Test — `researchParticipants`, `researchAssessmentResults`, `researchInstrument` (M2a: rules + uji emulator; BELUM di-deploy)

Collection untuk modul riset **Pre-Test & Post-Test** (SPEC §3.7) —
**terpisah total dari `placementTestResults`** (tujuan, alur, dan
kepemilikan data beda — lihat tabel perbandingan di `SPEC.md` §3.7).

> **Status (research Milestone 2a):** skema di bawah sudah **ditegakkan oleh
> `firestore.rules`** dan diuji otomatis terhadap **Firestore Emulator
> lokal** (`tools/research`, `npm run test:rules`, 70 test). **Rules ini
> belum di-deploy ke produksi**, dan **belum ada kode Flutter** yang membaca
> atau menulis collection ini (layar tes masih placeholder). Tooling peneliti
> yang menulis `researchParticipants`/`researchInstrument` di produksi juga
> **belum dibangun**. Placement test tetap ditunda. **M2b-1 (lokal, belum
> di-commit):** kode Dart murni untuk membentuk `itemOrder`/`optionOrder`
> (`utils/research_attempt_planner.dart`, `models/research_attempt_plan.dart`)
> sudah ada, tapi masih **tanpa** baca/tulis Firestore.

**Model kepercayaan (Spark, tanpa Cloud Functions):** dokumen
`researchParticipants` dan `researchInstrument` **hanya** ditulis oleh
tooling peneliti lokal (Admin SDK, melewati rules); client tidak pernah bisa
menulisnya. Siswa sendiri yang membuat dan mengisi `researchAssessmentResults`
miliknya, dengan setiap tulisan divalidasi rules. **Tidak pernah disimpan di
dokumen yang bisa dibaca client:** kunci jawaban, penanda benar/salah, kode
B/S/T/K, skor.

### `researchParticipants/{uid}` — hanya tooling peneliti yang menulis

| Field | Tipe | Keterangan |
|---|---|---|
| (docId) | uid Firebase | **Identitas yang bisa ditautkan ke orang** — tidak pernah diekspor |
| `researchId` | string | ID pseudonim acak; satu-satunya ID di ekspor |
| `band` | `"A2" \| "B1" \| "B2" \| "C1"` | Ditetapkan peneliti selama placement ditunda. **Bukan dari `users.cefrLevel`**, dan mapping level→band di PDF **tidak** diimplementasikan |
| `bandSource` | string | mis. `"researcher_assigned"` |
| `instrumentVersion` | string | `"v1"` |
| `authorizedAttempts` | map `{preTest: int, postTest: int}` | Otorisasi eksplisit per tahap: **0 = belum diizinkan**, *n* = percobaan ke-*n* boleh dibuat. Posttest dibuka peneliti setelah sesi treatment ke-4; retake = peneliti menaikkan angka ini |
| `cohort` | string | `study` / `pilot` / `test` |
| `createdAt`, `updatedAt` | Timestamp | |

Rules: pemilik boleh `get` dokumennya sendiri; tidak ada `list`; create /
update / delete dari client **selalu ditolak**.

### `researchInstrument/{version}_{band}` — data bank publik untuk rules

`{ instrumentVersion, band, optionIds: {itemId: [4 ID opsi]}, optionTexts:
{itemId: {optionId: teks}}, sourceBankSha256 }` — salinan data **publik** dari
`assets/research/instrument_v1.json` (§6c), dibangun oleh
`tools/research/lib/instrumentDocs.js`. **Tanpa kunci jawaban.** Dipakai rules
lewat `get()` untuk memvalidasi ID opsi dan teks opsi (literal sebesar ini di
dalam rules melampaui batas 1000 ekspresi per request). Client tidak boleh
membaca maupun menulisnya. Kalau dokumennya tidak ada, pembuatan percobaan
dan penyimpanan jawaban **gagal tertutup**. **Wajib di-seed oleh tooling
peneliti sebelum rules ini di-deploy.**

### `researchAssessmentResults/{uid}_{stage}_{n}` — satu percobaan tes

| Field | Tipe | Keterangan |
|---|---|---|
| `studentId` | string (uid) | Harus = `request.auth.uid` dan cocok dengan docId; tidak pernah diekspor |
| `stage` | `"preTest" \| "postTest"` | |
| `attemptNumber` | int ≥ 1 | Harus = `authorizedAttempts[stage]` milik peserta |
| `band`, `instrumentVersion` | string | Harus = milik peserta |
| `itemOrder` | list (20) | Urutan soal yang ditampilkan; tepat 20 butir band itu |
| `optionOrder` | map itemId → list (4) | Urutan 4 opsi yang ditampilkan; tiap list = permutasi 4 ID opsi bank untuk butir itu. `dont_know` tidak termasuk (selalu tampil terakhir) |
| `responses` | map itemId → `{optionId, optionText, displayPosition, answeredAt}` | `optionId` = ID opsi bank **atau** `"dont_know"` (posisi 5, teks "Saya tidak tahu kata ini"); `optionText` = teks bank persis; `answeredAt` = waktu server. **Butir yang tidak dijawab tidak punya entri** — ekspor nanti mengodekannya K |
| `lastAnsweredItemId` | string \| null | Butir yang ditulis pada tulisan terakhir (pembantu rules) |
| `status` | `"in_progress" \| "completed" \| "voided"` | `voided` hanya oleh tooling peneliti. "Tidak selesai" = tetap `in_progress` (tidak pernah otomatis `completed`) |
| `startedAt`, `updatedAt`, `completedAt` | Timestamp | Semua = `request.time` (waktu server); `completedAt` null sampai selesai |
| `voidReason`, `voidedAt` | string, Timestamp | Hanya tooling peneliti (insiden teknis) |

Yang ditegakkan rules:
- **Baca:** percobaan yang sudah ada hanya oleh UID yang tersimpan di
  dalamnya (`studentId`); percobaan yang belum ada hanya kalau docId-nya
  **persis** salah satu ID percobaan yang sedang diotorisasi untuk pemanggil
  (untuk cek "ada percobaan untuk dilanjutkan?"). UID tidak pernah dipakai
  sebagai regex atau prefix (audit keamanan 2026-10-24). Tidak ada `list`.
- **Buat:** hanya kalau tahap itu diotorisasi (`authorizedAttempts`), nomor
  percobaan = yang diotorisasi, band/versi = milik peserta, urutan soal &
  opsi valid terhadap bank, `responses` kosong, status `in_progress`,
  timestamp server, field persis sesuai daftar (field asing seperti `score`
  / `isCorrect` ditolak). Posttest juga mensyaratkan pretest yang
  diotorisasi sudah `completed`. Dokumen yang sudah ada tidak bisa ditimpa.
- **Jawab:** satu jawaban baru per tulisan, untuk butir percobaan ini yang
  **belum dijawab** (maju-saja: jawaban tersimpan tidak bisa diubah); ID
  opsi harus salah satu opsi yang ditampilkan untuk butir itu (atau
  `dont_know`), teks & posisi harus cocok; hanya selama `in_progress` dan
  hanya pada percobaan yang saat ini diotorisasi (percobaan lama membeku).
- **Selesai:** hanya kalau ke-20 butir sudah dijawab; `completedAt` waktu
  server; setelah `completed` tidak ada perubahan apa pun.
- **Hapus:** selalu ditolak.

Yang **tidak** bisa dijamin rules (client tidak dipercaya): keacakan
pengacakan, bahwa urutan yang tersimpan benar-benar yang ditampilkan,
siapa yang sebenarnya menjawab / tanpa bantuan, dan jeda posttest — diawasi
saat pelaksanaan dan ditandai saat ekspor.

> **Retensi data (D5):** kebijakan retensi serta penghapusan/pengarsipan
> data riset di Firestore **harus difinalkan sebelum pengambilan data
> responden sungguhan**. Belum ada data riset di produksi.

## 6c. Bank soal riset — aset statis, bukan Firestore (Milestone 1 modul riset)

Soal Pre/Post Test dibaca dari **`assets/research/instrument_v1.json`**,
bukan dari Firestore. File ini di-generate (dan divalidasi) dari PDF
instrumen peneliti oleh `tools/research/bin/build_instrument.js` —
jangan diedit manual. Skema lengkap & prosedurnya di
`tools/research/README.md`; ringkasnya:

| Field | Keterangan |
|---|---|
| `instrumentVersion` | `"v1"` |
| `source` | judul, nama file, dan SHA-256 PDF sumber |
| `dontKnowOption` | `{ id: "dont_know", text: "Saya tidak tahu kata ini" }` — pilihan terpisah, bukan salah satu opsi, tidak pernah jadi kunci |
| `items[]` | 80 butir: `id` (`A2-01` … `C1-20`), `band`, `number`, `word`, `pos` (`noun`/`verb`/`adjective`), `posLabel`, `options[4]` berisi `{ id, text }` |

- **ID opsi** = `opt_` + 12 hex dari SHA-256 (versi, ID butir, teks opsi) —
  stabil antar-build, tidak mengungkap huruf maupun kebenaran opsi.
- Opsi disimpan dalam urutan acuan PDF; pengacakan dilakukan saat runtime
  oleh `planResearchAttempt` (M2b-1): urutan butir dan 4 opsi tiap butir
  diacak dengan `Random` yang di-inject (app: `Random.secure()`), "tidak
  tahu" tidak ikut diacak dan selalu terakhir.
- **Loader app (M2b-1):** `ResearchInstrumentService.load(version)` membaca
  aset lewat `AssetBundle` yang bisa di-inject dan **gagal-tertutup**: aset
  hilang, JSON rusak, versi/`schemaVersion` tak didukung, field wajib
  hilang, field tak dikenal, ID butir/opsi ganda, atau band yang tidak tepat
  20 butir → `ResearchInstrumentException` (tidak ada nilai default).
- **Tanpa kunci jawaban** — tidak ada field correct/answer/key/letter/score.
  Kunci privat (ID butir → ID opsi benar) hanya ditulis ke path eksplisit
  di luar repo dan di luar OneDrive, dan tidak pernah dibaca oleh app.

## 7. Ringkasan Relasi

```
users (siswa) ──1:N── learningProgress ──N:1── vocabWords
users (siswa) ──1:N── learningSessions
users (siswa) ──1:N── placementTestResults        (TBD)
users (siswa) ──1:1── researchParticipants ──1:N── researchAssessmentResults  (rules M2a, belum deploy)
researchInstrument (data bank publik, per versi+band) ← dibaca rules lewat get()
users (guru)  ──1:N── targetWordSets ──N:N── vocabWords (via wordIds)
users (guru)  ──1:N── vocabWords (via addedByTeacherId, kalau source="guru")
vocabWords    ──N:N── topics (via vocabWords.topics, merujuk ke topics.name)
users (guru)  ──1:N── topics (via createdBy, kalau topik dibuat manual oleh guru)
teacherAccessCodes → users (guru): TIDAK ada relasi tersimpan dua arah.
    Kode hanya dicek lewat exists() di security rules saat sign up;
    jejaknya tercatat satu arah di users.teacherCodeInput (§1).
```

## 8. Catatan Index Firestore

Query yang kemungkinan butuh composite index (buat lazy — Firestore akan
kasih link auto-generate index saat query pertama gagal, cukup diikuti):

- `learningProgress` filter by `studentId` + `masteryStatus` (Riwayat tab
  "per kata", sort/filter by label)
- `learningSessions` filter by `studentId`, order by `startedAt` desc
  (Riwayat tab "per sesi")
- `targetWordSets` `targetStudentIds` array-contains-any + `endAt` range +
  order by `endAt` (lihat query di §5)
- `topics` order by `name` asc (daftar pilihan topik di UI guru)
- `vocabWords` filter by `updatedAt` range (query delta bundle, §11)
- `researchAssessmentResults` — **tidak butuh index**: dibaca per docId
  deterministik (`{uid}_{stage}_{n}`), query `list` ditolak rules.

> **Dihapus di v6:** index `vocabWords` untuk `cefrLevel + topics
> array-contains` dan `cefrLevel + posList array-contains`. Ketiga mode
> browse (abjad/tema/POS) sekarang dijalankan **di memori** dari bundle
> statis (§11), jadi tidak ada query Firestore yang membutuhkannya.

## 9. Ruang untuk Pengembangan Lanjutan (jangan implementasikan sekarang)

Sesuai SPEC §4.2 — jangan bangun sekarang, tapi struktur di atas sudah
kompatibel untuk ditambah nanti:

- Guru lihat progres per-siswa → query `learningProgress` filter
  `studentId`, tidak butuh perubahan skema.
- Guru lihat progres per-kata/kelompok kata → query `learningProgress`
  filter `wordId` atau join manual dengan `vocabWords.topics`.
- Target per-siswa individual → isi `targetWordSets.targetStudentIds`
  dengan daftar `uid` alih-alih `[kAllStudents]`; query di §5 sudah
  menanganinya tanpa perubahan.
- Placement Test → skema §6 sengaja generik (masih ditunda). Pre/Post Test
  → skema §6b sudah ditetapkan di rules (M2a).
- Kode akses guru per-individu / single-use → tinggal tambah
  `maxUses`/`usedCount` di §2c, atau satu dokumen kode per guru.
- Kalau suatu saat billing tersedia dan mau pindah ke Cloud Functions,
  perubahan **cuma di layer `services/`** sisi Flutter dan di security
  rules — struktur Firestore di dokumen ini tidak perlu berubah.

## 10. Arsitektur AI Proxy — Cloudflare Workers

Pengganti Firebase Cloud Functions untuk satu-satunya kebutuhan server yang
sesungguhnya wajib: **menyembunyikan `OPENAI_API_KEY`** (Flutter web bundle
bisa dibuka lewat DevTools). Ini **project/repo terpisah** dari Flutter app
— lihat `CLAUDE.md` §2 & §3.

### 10.1 Prinsip Utama

- **Worker tidak pernah menulis ke Firestore.** Alurnya selalu: client
  panggil Worker → Worker panggil OpenAI → Worker balikin hasil mentah →
  **client yang menulis ke Firestore**, dengan integritas dijaga Security
  Rules. Ini menghindari kerumitan Firestore REST API + service account JWT
  signing di dalam Worker.
- **Auth dicek manual**, karena Firebase Admin SDK tidak jalan di runtime
  Workers (Web-standard API, bukan Node.js). Verifikasi pakai library
  `jose`:
  1. Fetch public key Google dari
     `https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com`
     (cache hasilnya, rotasi key jarang).
  2. Verify signature JWT (RS256).
  3. Cek `aud` == project ID Firebase Vocably, `iss` ==
     `https://securetoken.google.com/{projectId}`, dan `exp` belum lewat.
     **Jangan skip validasi `aud`** — tanpa ini, token dari project Firebase
     lain bisa lolos.
  4. Ambil claim `sub` sebagai `uid` pemanggil.
- **Rate limiting**: pakai **Cloudflare Rate Limiting binding native**
  (bukan KV counter) — KV free plan cuma 1.000 write/hari yang terlalu
  ketat untuk counter per-request. Key rate limit = `uid` hasil verifikasi
  token (bukan IP, karena banyak siswa bisa satu jaringan sekolah).
- **CORS: allowlist origin, bukan `*`.** Worker membandingkan header
  `Origin` request dengan daftar yang diizinkan, lalu membalas dengan
  `Access-Control-Allow-Origin` berisi origin itu (bukan wildcard), plus
  menangani preflight `OPTIONS` — dengan Cloud Functions `onCall` ini
  otomatis, di Workers manual. Header yang perlu dibalas:

  ```
  Access-Control-Allow-Origin: <origin yang cocok dari allowlist>
  Access-Control-Allow-Methods: POST, OPTIONS
  Access-Control-Allow-Headers: Authorization, Content-Type
  Access-Control-Max-Age: 86400
  ```

  - **Produksi:** domain Firebase Hosting Vocably — ingat Firebase memberi
    **dua** domain (`https://<project>.web.app` dan
    `https://<project>.firebaseapp.com`), masukkan keduanya.
  - **Development:** origin `http://localhost:<port>` **hanya** diizinkan
    saat Worker jalan lewat `wrangler dev` atau saat env var dev aktif —
    deploy produksi tidak boleh pernah menerima localhost. Tanpa ini, tidak
    ada satu pun fitur AI yang bisa dites lokal, karena `flutter run -d
    chrome` berjalan di origin localhost, bukan domain hosting.
  - Praktik dev: jalankan `flutter run -d chrome --web-port=5555` supaya
    port-nya tetap dan cukup satu origin dev di allowlist.
  - **Catatan:** CORS bukan keamanan sesungguhnya — hanya browser yang
    menegakkannya, dan `curl` mengabaikannya. Yang benar-benar menjaga
    Worker adalah verifikasi ID token + rate limiting. CORS mencegah
    halaman web orang lain memakai Worker ini dari browser pengguna.

### 10.2 Endpoint

Semua endpoint mensyaratkan header `Authorization: Bearer <Firebase ID
token>`, diverifikasi seperti di §10.1 sebelum diteruskan ke OpenAI.

#### `POST /generate-story` — Fase 1 (SPEC §5.1)

Dipanggil saat generate & regenerate cerita.

**Input:** daftar kata target (bentuk dasar, sudah dinormalisasi) + judul/
konteks yang diketik siswa.

**Output:**

| Field | Tipe | Keterangan |
|---|---|---|
| `story` | string | cerita 3–5 kalimat, **dengan tiap kemunculan kata target dibungkus penanda** `[[kataTarget\|bentukTerpakai]]` |
| `translation` | string | terjemahan Indonesia cerita, **tanpa penanda** |

Contoh nilai `story`:

```
Yesterday I [[run|ran]] to the park and bought two [[souvenir|souvenirs]].
```

**Kewajiban Worker:**
- Cerita memiliki tepat N kalimat untuk N kata target (satu kata target per kalimat).
- Urutan kata target dalam cerita **bebas naratif (narrative-driven)** — model diinstruksikan menyusun urutan kemunculan kata berdasarkan alur narasi yang paling koheren dan alami, **bukan** mengikuti urutan daftar masukan, untuk mencegah kebocoran posisi (positional leakage) pada Fase 2 Cloze Test.
- Semua kata target **wajib** dipakai tepat satu kali dan **wajib** bertanda `[[kataTarget|bentukTerpakai]]`.
- Setelah menerima respons OpenAI, Worker **memvalidasi** (set-based via `validateMarkers()`) bahwa setiap kata target muncul tepat sekali sebagai `[[kataTarget|...]]`. Kalau ada yang hilang/duplikat/tidak sesuai, retry sekali ke OpenAI; kalau masih gagal, balikan error 502 yang bisa dibaca client (bukan cerita cacat).
- `kataTarget` di dalam penanda harus **persis** sama dengan kata yang dikirim client (sudah lewat `normalizeWord()`), supaya client bisa mencocokkannya tanpa normalisasi tambahan.
- AI **boleh dan seharusnya** memakai bentuk infleksi yang natural di `bentukTerpakai` dari leksem yang sama — jangan memaksa bentuk dasar (menghasilkan kalimat salah gramatikal) dan dilarang mengganti dengan kata/sinonim lain.

#### `POST /cowrite-turn` — Fase 3 (SPEC §5.3)

**Kepemilikan keputusan.** Flutter client memegang semua keputusan Co-Write
(penghitung giliran, kapan fallback jatuh tempo, pemilihan kata acak, update
status kata, tampil/tidaknya bubble bot, selesainya sesi). Worker memegang
*prompt builder* ketiga mode di bawah dan validasi deterministik output
model (`src/cowriteValidator.ts`, cermin dari `lib/utils/cowrite_validator.dart`).
Model tidak pernah memilih kata target, menghitung giliran, atau memutuskan
selesai — client menentukan mode lewat request.

**Input (JSON):**

| Field | Tipe | Keterangan |
|---|---|---|
| `transcript` | array\<{sender: "siswa"\|"ai", text}\> | percakapan sejauh ini. Untuk mode giliran biasa & `forcedWord`, **entri terakhir wajib giliran siswa saat ini** (400 kalau tidak) |
| `remainingWords` | array\<string\> | kata target (bentuk dasar) yang belum terpakai di tingkat sesi |
| `requestSuggestion` | boolean | `true` = mode saran menulis |
| `forcedWord` | string (opsional) | mode fallback: kata yang **dipilih client** (harus anggota `remainingWords`; tidak boleh digabung dengan `requestSuggestion`) |
| `studentTurnContainsIndonesian` | boolean (opsional, default `false`; 400 bila bukan boolean) | **diputuskan client** secara deterministik (`containsIndonesianWords`): giliran siswa terakhir berbahasa Indonesia/campuran. Worker tidak pernah mengklasifikasi ulang; dipakai mode 1 untuk meminta pengingat bahasa |

**Tiga mode:**

1. **Giliran biasa** (`requestSuggestion: false`, tanpa `forcedWord`). Worker
   mengirim ke model `storySoFar` (transcript tanpa entri terakhir) dan
   `currentStudentTurn` (entri terakhir) **secara terpisah**, supaya feedback
   hanya menilai kalimat saat ini. Model mengembalikan `wordsUsedCorrectly`
   (diputuskan lebih dulu), `hasError` (hanya untuk masalah **penting**:
   bentuk/makna kata target yang salah, atau kesalahan grammar/pilihan kata
   yang mengubah makna; kapital, tanda baca, apostrof, dan kesalahan kecil
   tidak dihitung), `feedback` (bahasa Indonesia, hanya tentang kalimat saat
   ini, dengan prioritas CW-02: kata target yang sah disebut secara spesifik
   → kata target yang dicoba tapi tidak sah dijelaskan masalahnya → tanpa
   kata target diberi dorongan memakai salah satu kata target; paling banyak
   satu masalah penting; tanpa kesalahan karangan dan tanpa pujian generik),
   dan `aiTurn` (satu kalimat
   lanjutan **berbahasa Inggris** yang menambah kejadian baru, tidak mengulang
   kalimat siswa, **tidak** memakai kata target tersisa, dan tidak menjawab
   pertanyaan/hitungan/permintaan di luar cerita — bila giliran siswa bukan
   bagian cerita, cerita dilanjutkan dari `storySoFar`). Payload ke model juga
   memuat `studentTurnContainsIndonesian` dari client; bila `true`, `feedback`
   wajib **satu kalimat singkat dan sopan berbahasa Indonesia** yang
   mengingatkan siswa menulis dalam bahasa Inggris (tanpa pelajaran tata
   bahasa), sedangkan `wordsUsedCorrectly` tetap dinilai seperti biasa.
   Rubrik `wordsUsedCorrectly`
   (CW-05): kata target yang dipakai **bermakna, dengan makna yang dimaksud
   dapat diterima**; kesalahan grammar/tense/agreement dan infleksi kata
   target yang salah **tidak** menggugurkan kredit (dilaporkan lewat
   `hasError`/`feedback`); kata lepas, daftar, fragmen, sekadar menyebut kata,
   kalimat tak bermakna, atau makna yang salah tidak dihitung. Worker menyaring
   `wordsUsedCorrectly` dengan `validateStudentTargetWords` (bentuk yang
   dilaporkan model seperti `attacked`, `Attack.`, `"ATTACKS"` dipetakan ke
   kata dasar `attack`, lalu kata itu wajib masih tersisa dan muncul di teks
   siswa sebagai kata utuh/infleksi yang valid). Maksimal 2
   generasi: diulang bila JSON rusak/bentuk salah, `aiTurn` kosong, `aiTurn`
   mengulang kalimat siswa (`isEchoOfStudentTurn`), `aiTurn` memakai kata
   target tersisa, atau `aiTurn` terdeteksi berbahasa Indonesia
   (`containsIndonesianWords`). **Penilaian giliran siswa (`feedback`, `hasError`,
   `wordsUsedCorrectly`) diambil dari percobaan pertama yang bentuknya valid
   dan dipertahankan**; retry hanya mengganti `aiTurn`, sehingga tidak pernah
   menghapus kredit kosakata siswa. Bila model mengklaim kata
   (`wordsUsedCorrectly` mentah tidak kosong) tetapi validasi tidak
   mengkreditkan satu pun, dan giliran bukan berbahasa Indonesia/campuran,
   `feedback` diganti teks tetap `UNCREDITED_CLAIM_FEEDBACK` ("Belum ada kata
   target yang terhitung di kalimat ini. …"; client punya salinan identik,
   `kCowriteUncreditedClaimFeedback`). **Bila tidak ada percobaan yang
   menghasilkan `aiTurn` yang dapat diterima, Worker menjawab 502** (CW-02) —
   `aiTurn` yang bentuk JSON-nya valid tetapi tidak dapat diterima (mengulang
   siswa, memakai kata target tersisa, berbahasa Indonesia) tidak pernah
   dikembalikan; client memperlakukannya sebagai giliran gagal (giliran
   siswa dibatalkan, "Gagal mengirim giliran. Coba lagi.").
   `aiUsedWords` selalu `[]` — giliran biasa **tidak pernah** menyelesaikan
   kata target. `assessedStudentTurn` = teks siswa persis yang dinilai.
2. **Giliran fallback** (`forcedWord`). Model diminta satu kalimat lanjutan
   dari `currentStudentTurn` yang **memakai `forcedWord`** dengan benar dan
   tidak memakai kata tersisa lain, berbahasa Inggris, dan tetap di dalam
   cerita. Worker menerima hasil hanya bila `forcedWord` terdeteksi di
   `aiTurn` (kata utuh/infleksi), tidak ada kata tersisa lain, bukan
   pengulangan kalimat siswa, dan tidak terdeteksi berbahasa Indonesia;
   maksimal 2 generasi,
   lalu **502** — Worker tidak pernah melaporkan kata yang belum tervalidasi.
   Sukses: `aiUsedWords = [forcedWord]`, field penilaian kosong/null.
3. **Saran menulis** (`requestSuggestion: true`). Model mengembalikan satu
   kalimat bahasa Inggris; Worker membuang awalan instruksi ("Try to
   write:", "You could write:", "Coba tulis") dan tanda kutip
   (`extractSuggestedSentence`), diulang sekali bila kalimat tidak memakai
   kata tersisa atau berupa fragmen. `aiTurn` = `""`. Instruksi berbahasa
   Indonesia (`Coba tulis "..."`) ditambahkan client
   (`lib/utils/cowrite_suggestion.dart`), bukan model.

**Output (semua mode, bentuk sama):**

| Field | Tipe | Keterangan |
|---|---|---|
| `aiTurn` | string | kalimat giliran AI (mode 1 & 2); `""` di mode saran |
| `feedback` | string \| null | feedback bahasa Indonesia untuk **giliran siswa saat ini** (mode 1 saja) |
| `hasError` | boolean | **terstruktur** — `true` kalau giliran siswa saat ini mengandung masalah **penting** (mode 1); hanya dipakai client untuk indikator tampilan feedback |
| `wordsUsedCorrectly` | array\<string\> | **terstruktur** — kata target (bentuk dasar) yang dipakai siswa secara bermakna di giliran saat ini (kesalahan tata bahasa tidak menggugurkan), sudah disaring kode (mode 1) |
| `suggestion` | string \| null | kalimat saran bahasa Inggris tanpa instruksi (mode 3 saja) |
| `aiUsedWords` | array\<string\> | **terstruktur** — `[forcedWord]` setelah validasi di mode 2; selalu `[]` di mode 1 & 3 |
| `assessedStudentTurn` | string \| null | teks siswa yang dinilai (mode 1); `null` di mode lain. **Opsional bagi client** — Worker yang lebih lama tidak mengirimnya |

> **Kenapa `wordsUsedCorrectly` harus terstruktur:** aturan mastery di §3
> bergantung pada "dipakai mandiri tanpa kesalahan" (= makna & pemakaian
> kosakata dapat diterima, bukan kalimat sempurna secara tata bahasa — kesalahan
> tata bahasa cukup dilaporkan lewat `hasError`/`feedback`). Kalau satu-satunya
> keluaran adalah teks feedback bebas, client harus menebak maknanya
> dengan parsing string — tidak mungkin andal. `wordsUsedCorrectly`
> (setelah divalidasi ulang client dan difilter aturan "mandiri" di bawah)
> yang langsung mengisi `learningSessions.cowriteWordsUsedCorrectly`.
>
> **Catatan tentang `hasError` (CW-02):** field ini divalidasi di client
> (`AiWorkerService.cowriteTurn()`, tipe wajib `boolean`) dan **hanya**
> dipakai untuk indikator tampilan feedback (`classifyCowriteFeedback`,
> `lib/utils/cowrite_feedback.dart`): ✓ "Sudah tepat" = ada kata
> tervalidasi kode **dan** `hasError == false`; 💡 "Perlu perbaikan" =
> ada kata tervalidasi dengan `hasError == true`, atau kata target muncul di
> teks tapi tidak dikreditkan; 💬 "Pengingat" = tidak ada kata target, atau
> giliran berbahasa Indonesia/campuran. Hasilnya disimpan di field
> **in-memory** `CowriteTurn.feedbackKind`, yang **tidak** ditulis
> `toMap()` — bentuk `cowriteTranscript` di Firestore tidak berubah.
> `hasError` tidak pernah mengisi `cowriteWordsUsedCorrectly`, cakupan
> sesi, penghitung fallback, atau mastery; itu tetap hanya dari
> `wordsUsedCorrectly` yang divalidasi.
>
> **Aturan "mandiri" ditegakkan di client, bukan Worker:** kalau giliran itu
> memakai "saran menulis", client **tidak memasukkan** kata dari
> `wordsUsedCorrectly` ke `cowriteWordsUsedCorrectly`, dan mencatat
> `usedSuggestion: true` di transcript (§4).
>
> **Alur client per giliran (`LearningFlowController.sendTurn`):**
> 1. Input yang **mengandung kata target** tapi hanya berupa kata lepas,
>    pengulangan, fragmen determiner/preposisi, atau daftar kata
>    (`shouldRejectStudentTurnLocally`) ditolak lokal: tidak masuk
>    `cowriteTranscript`, tidak memanggil Worker, tidak ada giliran AI,
>    penghitung tidak berubah, `turnError` berbahasa Indonesia, draf & fokus
>    `TextField` dipertahankan. Balasan biasa tanpa kata target (`"Okay."`)
>    tetap dikirim sebagai giliran biasa.
> 2. Giliran siswa ditampilkan langsung, lalu mode 1 dipanggil dengan
>    `remainingWords` sebelum giliran ini. Respons dibuang bila alur sudah
>    dimulai ulang (`startFlow`) selama menunggu, dan diperlakukan sebagai
>    gagal kirim (giliran di-rollback) bila `assessedStudentTurn` ada tetapi
>    tidak sama dengan teks yang dikirim.
> 3. `validateStudentTargetWords` (eligible = kata tersisa sebelum giliran)
>    menentukan kata siswa yang sah; semuanya masuk cakupan sesi
>    (`allWordsUsedCorrectly`). Kata itu juga masuk
>    `independentWordsUsedCorrectly` **hanya** bila giliran tidak memakai
>    saran **dan** `containsIndonesianWords` (dihitung client sebelum
>    memanggil Worker dan dikirim sebagai `studentTurnContainsIndonesian`)
>    bernilai `false`.
> 4. `consecutiveMissedStudentTurns`: reset ke 0 bila ada kata sah baru,
>    selain itu +1. Giliran AI, input yang ditolak lokal, dan pengiriman yang
>    gagal tidak mengubahnya.
> 5. Kalau tidak ada kata tersisa → sesi selesai, tanpa bubble AI. Kalau
>    penghitung ≥ `kCowriteFallbackMissThreshold` (3) → client memilih **tepat
>    satu** kata tersisa secara acak (`selectFallbackWord`, sumber acak
>    `cowriteFallbackRandomProvider`) dan memanggil mode 2. Kata itu ditandai
>    terpakai **hanya** bila terdeteksi di teks `aiTurn` hasil mode 2
>    (`validateBotTargetWords` dengan eligible = `[forcedWord]`; klaim
>    `aiUsedWords` tidak dipakai), dan penghitung direset ke 0. Kalau mode 2
>    gagal/tidak lolos, `aiTurn` mode 1 yang ditampilkan, tidak ada kata yang
>    ditandai, dan penghitung tetap ≥ 3 (giliran tanpa kata target berikutnya
>    mencoba fallback lagi). Selain itu `aiTurn` mode 1 ditampilkan dan
>    **tidak pernah** menandai kata, walau kebetulan memuat kata target.
>
> **Tingkat sesi vs mastery mandiri:** `allWordsUsedCorrectly` (state client;
> penanda kata + kondisi berhenti otomatis Fase 3 — `wordUsedCorrectly`
> tingkat sesi) berisi semua kata yang sah terpakai dalam sesi:
> - oleh siswa: mandiri, bersaran, atau di giliran berbahasa Indonesia/campuran;
> - oleh bot lewat mode 2.
>
> `independentWordsUsedCorrectly` hanya berisi kata siswa yang mandiri (tanpa
> saran, berbahasa Inggris). Kata dari mode 2, giliran bersaran, dan giliran
> berbahasa Indonesia/campuran **tidak pernah** masuk ke sana, sehingga tidak
> pernah tersimpan di `cowriteWordsUsedCorrectly` atau menaikkan mastery. Kata yang
> sudah dipakai bot keluar dari `remainingWords`, jadi siswa tidak bisa lagi
> mendapat kredit mandiri untuk kata itu di sesi yang sama.
>
> **Saran menulis & konkurensi:** saran tidak bisa diminta saat giliran
> sedang dikirim, dan giliran tidak bisa dikirim saat saran sedang dimuat
> (client & UI sama-sama menahannya). "✓ Selesai" dijaga
> `isCompletingCowrite` sehingga ketukan ganda tidak menulis dua kali.
>
> **Kompatibilitas dengan Worker yang lebih lama:** sejak 2026-10-16 Worker
> produksi sudah versi baru (`0bec79ee`, `PROJECT_STATE.md` §5t). Catatan ini
> tetap berlaku untuk Worker lama (mis. versi 2026-08-30 bila di-rollback), yang
> mengabaikan `forcedWord` dan `studentTurnContainsIndonesian`, serta tidak
> mengirim `assessedStudentTurn`. Client baru tetap aman:
> - `assessedStudentTurn` opsional, dan awalan saran berbahasa Inggris dibuang client.
> - Respons fallback dari Worker lama biasanya tidak lolos validasi teks,
>   sehingga tidak ada kata yang ditandai. Kalau aturan fallback lama di Worker
>   itu kebetulan memakai kata yang sama, kata itu ditandai karena memang
>   terdeteksi di teks.
> - Pemisahan mastery untuk giliran Indonesia/campuran sepenuhnya di client,
>   jadi tetap berlaku.
> - Indikator feedback (CW-02) dihitung di client, jadi tetap berlaku. Client
>   juga mengganti feedback dengan `kCowriteUncreditedClaimFeedback` bila
>   klaim kata dari Worker lama ditolak validasi client.
>
> Fallback baru, pengingat bahasa, aturan "bot selalu berbahasa Inggris",
> prioritas feedback CW-02, dan penolakan (502) `aiTurn` yang tidak dapat
> diterima hanya berfungsi dengan Worker baru (sudah ter-deploy 2026-10-16).

#### `POST /translate` — terjemahan makna (§2)

**Input:** kata + POS.
**Output:** teks terjemahan Indonesia.

Dipanggil dari dua tempat:
- **Guru** saat menambah kata/makna baru → hasilnya **ditulis** ke
  Firestore oleh client guru.
- **Siswa** saat membuka kamus detail kata yang `translation`-nya `null`
  → hasilnya **hanya ditampilkan**, tidak ditulis ke Firestore (§2).

> Endpoint `/word-details` (definisi Inggris via ChatGPT sebagai fallback
> DictionaryAPI) **belum ada dan jangan dibuat dulu** — statusnya menunggu
> pengukuran jumlah kata 404, lihat catatan fallback di §2.

### 10.3 Yang TIDAK lewat Worker

- **Dictionary API** (`api.dictionaryapi.dev`) — langsung dari client, tidak
  ada secret.
- **Text-to-speech fallback** — Web Speech API di browser, tidak ada API
  eksternal.
- **CSV import Oxford 3000/5000** (`tools/vocab_import/`) — jalan lokal di
  mesin dev, pakai `OPENAI_API_KEY` dari `.env` root untuk terjemahan
  (proses one-off, bukan traffic user produksi).
- **Generate bundle statis** (§11, `tools/vocab_import/bin/generate_bundles.js`)
  — tidak ada AI, transform lokal murni dari data kanonik hasil import.
- **Cloze test** (SPEC §5.2) — tidak butuh AI; blank diturunkan dari
  penanda di `storyContent` dan pencocokan jawaban cuma perbandingan string
  di client.
- **Skoring Placement Test** — dihitung di client (§6), begitu metodenya
  diputuskan (masih ditunda).
- **Skoring Pre-Test / Post-Test** — **tidak** di app sama sekali:
  dilakukan offline oleh peneliti dengan kunci jawaban privat yang tidak
  pernah masuk app/Firestore/Worker (§6b, `tools/research/README.md`).
- **Validasi kode akses guru** — Firestore Security Rules (§1).

### 10.4 Setup & Deploy (ringkas)

```bash
npm create cloudflare@latest vocably-ai-worker
cd vocably-ai-worker
npx wrangler secret put OPENAI_API_KEY   # tersimpan encrypted, tidak masuk git
npx wrangler deploy
```

URL yang dihasilkan (`https://vocably-ai-worker.<subdomain>.workers.dev`)
dimasukkan ke konfigurasi Flutter (`services/`) sebagai base URL AI proxy.
Development lokal: `npx wrangler dev`.

### 10.5 Trade-off yang Sudah Disadari (bukan hal yang perlu ditanyakan ulang)

- Kodebase AI proxy jadi TypeScript, terpisah dari Flutter — dua pipeline
  deploy.
- Tidak ada Admin SDK, jadi verifikasi token manual; menulis Firestore dari
  Worker sengaja dihindari sepenuhnya (§10.1).
- Cold start Workers praktis nol (beda dengan Cloud Functions Node.js yang
  bisa 2–5 detik saat idle) — ini keuntungan.
- Kuota gratis (100.000 request/hari) jauh di atas kebutuhan skala skripsi
  (~35–40 siswa × beberapa panggilan AI per sesi) — dan kalau lewat kuota,
  request cuma gagal, tidak ada risiko tagihan mendadak seperti Blaze.

## 11. Distribusi Bank Kosakata sebagai Aset Statis (baru di v6)

### 11.1 Masalah yang diselesaikan

Firebase plan Spark membatasi **50.000 pembacaan dokumen per hari**, dan
biayanya dihitung **per dokumen**, bukan per query. Bank kosakata berisi
~5.000 dokumen, kira-kira ~1.000 kata per level CEFR. Kalau browse membaca
dari Firestore, satu siswa membuka satu level = ~1.000 pembacaan. 40 siswa
(batas atas rencana sampel 35–40) × sekali saja = ~40.000 → sudah
mendekati batas 50.000/hari dari satu kali buka saja, dan sekali pindah
level atau buka ulang kuota habis, aplikasi berhenti melayani sampai reset
harian. Itu belum menghitung perpindahan
level, buka ulang, dan `get()` di dalam security rules yang juga dihitung
sebagai pembacaan.

Penulisan tidak bermasalah: ~20 tulis per sesi belajar × 40 siswa ≈
800/hari, jauh di bawah batas 20.000.

### 11.2 Pendekatan

Bank kosakata **praktis statis** — satu-satunya penulis adalah skrip import
dev dan guru (siswa read-only sejak v6, §2). Jadi tidak ada alasan
membacanya berulang kali dari Firestore.

**Firestore tetap sumber kebenaran.** Bundle adalah **artefak turunan**
(cache baca) yang di-generate dari Firestore, bukan penyimpanan terpisah
yang perlu disinkronkan dua arah.

- Skrip dev meng-export `vocabWords` menjadi file JSON **per level CEFR**:
  `assets/vocab/vocab_a1.json`, `vocab_a2.json`, … `vocab_c1.json`
  (`vocab_c2.json` boleh kosong/absent sampai ada kata C2).
- Tiap file berisi array objek dengan field yang dibutuhkan browse &
  kamus detail: `word`, `meanings`, `posList`, `cefrLevel`, `topics`.
  Field audit (`source`, `addedByTeacherId`, `createdAt`) tidak perlu ikut.
- Aplikasi memuat file level **yang sedang dibuka siswa saja** (bukan
  semuanya sekaligus) ke memori lewat provider Riverpod. Ukuran per level
  ~200 KB, dan setelah gzip jauh lebih kecil — penting untuk wifi sekolah
  yang lambat.
- Semua browse (abjad/tema/POS), filter, dan pencarian dijalankan **di
  memori** dengan **nol pembacaan Firestore**.
- File bundle disajikan lewat Firebase Hosting (bandwidth statis, bukan
  kuota Firestore) atau dibundel sebagai `assets/` aplikasi.

### 11.3 Delta: kata yang berubah setelah bundle dibuat

Aplikasi menyimpan konstanta `kBundleGeneratedAt` (timestamp saat bundle
di-generate). Saat memuat sebuah level, setelah membaca file JSON-nya,
aplikasi menjalankan satu query kecil:

```dart
firestore.collection('vocabWords')
  .where('cefrLevel', isEqualTo: level)
  .where('updatedAt', isGreaterThan: kBundleGeneratedAt)
```

Hasilnya digabung ke daftar di memori (kata baru ditambahkan, kata yang
sudah ada ditimpa versi Firestore-nya).

> **Kenapa `updatedAt`, bukan `createdAt`:** ada dua jenis perubahan setelah
> bundle dibuat — guru **menambah kata baru** (tertangkap `createdAt`) dan
> guru **mengedit `topics` kata lama** (tidak tertangkap `createdAt`, karena
> tanggal pembuatannya tidak berubah). `updatedAt` menangkap keduanya dengan
> satu query.

Hasil delta biasanya beberapa dokumen saja, jadi biaya pembacaannya
diabaikan. Regenerate bundle secara manual sesekali (mis. setelah guru
menambah banyak kata) supaya delta tidak menumpuk.

> **Bug ditemukan & diperbaiki (Milestone 4, setelah seeding data asli):**
> query di atas butuh **composite index** `cefrLevel + updatedAt` (equality
> + range di field berbeda — auto single-field index Firestore tidak
> cukup). Index ini sudah disebutkan sejak v6 di §11.5 di bawah, tapi
> **tidak pernah benar-benar ditambahkan ke `firestore.indexes.json` atau
> di-deploy** — jadi sampai ada data asli yang cukup besar untuk membuat
> query ini benar-benar berjalan, kegagalannya tidak pernah kelihatan.
> Begitu bank kosakata asli di-seed, query ini gagal dengan
> `FAILED_PRECONDITION` untuk **setiap level**, dan karena
> `loadLevelWithDelta` dulu tidak menangkap error dari `fetchDelta`,
> seluruh level gagal dimuat — bukan cuma delta-nya. Diperbaiki dua arah:
> index-nya sekarang ada di `firestore.indexes.json` (masih perlu
> di-deploy manual, lihat `PROJECT_STATE.md`), **dan**
> `VocabBundleService.loadLevelWithDelta` sekarang menangkap kegagalan
> `fetchDelta` lalu jatuh ke data bundle saja (bukan ke error) — supaya
> masalah index/delta di masa depan (mis. index sedang dibangun ulang)
> tidak pernah membuat seluruh fitur browse mati total, konsisten dengan
> prinsip degradasi rapi yang sama dipakai di `SPEC.md` §3.5 untuk
> DictionaryAPI.

### 11.4 Data yang TETAP dibaca live dari Firestore

Bundle hanya untuk bank kosakata. Yang berikut tetap query Firestore
normal, karena volumenya kecil dan/atau harus selalu segar:

- `users`, `learningProgress`, `learningSessions`, `targetWordSets`,
  `topics`, `placementTestResults`, `researchAssessmentResults`.
- **Catatan efisiensi `learningProgress`:** ambil **sekali per sesi login**
  dengan satu query `where('studentId', isEqualTo: uid)` lalu simpan di
  provider — jangan query per kata saat merender chip, karena itu
  mengembalikan pola "ribuan pembacaan per layar" yang justru mau
  dihindari.

### 11.5 Konsekuensi ke bagian lain dokumen ini

- §8: dua composite index `vocabWords` untuk browse **dihapus**; index baru
  `cefrLevel + updatedAt` ditambahkan untuk query delta. **Status:**
  sekarang benar-benar ada di `firestore.indexes.json` (lihat catatan bug
  di §11.3) — deploy manual (`firebase deploy --only firestore:indexes`)
  masih tugas dev, lihat `PROJECT_STATE.md`.
- §2: field `posList` tidak lagi dipakai untuk query Firestore, tapi tetap
  dipertahankan karena ikut masuk bundle dan dipakai filter POS di memori.
- Skema `vocabWords` **tidak berubah** selain penambahan `updatedAt` —
  bundle tidak menuntut restrukturisasi collection apa pun.
