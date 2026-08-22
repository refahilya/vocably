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
| `cefrLevel` | string enum \| null | **hanya untuk siswa** — hasil placement test (`A1`–`C2`, lihat catatan cakupan di §2), `null` kalau belum tes |
| `placementTestCompleted` | boolean | **hanya untuk siswa** — default `false` |
| `placementTestPrompted` | boolean | **hanya untuk siswa** — default `false`; di-set `true` begitu tawaran placement test otomatis pernah ditampilkan sekali. **Ini mekanisme yang menegakkan aturan "kalau siswa menunda, tawaran tidak muncul lagi"** (SPEC §3.1) — tanpa field ini, aplikasi tidak punya cara membedakan "belum pernah ditawari" dari "sudah ditawari tapi ditunda", karena `placementTestCompleted` tetap `false` di kedua kasus |
| `teacherCodeInput` | string \| absent | **hanya untuk guru** — kode akses yang diketik saat sign up, **disimpan permanen sebagai audit trail** (bukan field sementara). Lihat catatan di bawah |

> Kenapa satu collection untuk dua role, bukan dipisah `students`/`teachers`?
> Supaya query auth & profile tetap sederhana (satu lookup by `uid`). Field
> yang cuma relevan untuk satu role (`cefrLevel`, `teacherCodeInput`, dst)
> cukup dibiarkan `null`/absent untuk role lainnya — jangan buat collection
> terpisah kecuali nanti field spesifik-role bertambah banyak.

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
> 5. **Field yang BOLEH di-update siswa atas dirinya sendiri:**
>    `cefrLevel`, `placementTestCompleted`, `placementTestPrompted`, dan
>    `name`. Selain itu ditolak. Ini penting karena skoring placement test
>    dihitung di client (§6).
> 6. Karena tiap akun (`uid`) cuma punya satu dokumen `users` dengan satu
>    field `role`, dan email di Firebase Auth memang unik per akun, aturan
>    **"satu email = satu role"** otomatis terjaga oleh struktur ini +
>    aturan immutability di atas.

## 2. `vocabWords`

Bank kosakata master (bukan per-siswa). Di-import via CSV dari Oxford
3000/5000, dan bisa ditambah manual oleh guru (SPEC §4.1 "Tambah Kosakata").

> **Collection ini read-only untuk siswa.** Satu-satunya penulis adalah
> skrip import dev (lewat Admin SDK lokal) dan akun guru. Tidak ada alur
> apa pun di aplikasi siswa yang menulis ke sini — lihat "Alur generate
> translationId" di bawah. Konsekuensinya untuk browse: karena bank
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
| `cefrLevel` | string enum | `A1`–`C2` — dipakai untuk filter di SPEC §3.3, dan **menentukan file bundle mana yang memuat kata ini** (§11). **Cakupan data aktual saat ini hanya A1–C1** (sumber Oxford 3000/5000); `C2` tetap valid sebagai nilai enum untuk kata yang mungkin ditambahkan guru nanti, tapi jangan diasumsikan selalu ada isinya — UI harus menangani state kosong. **Catatan asumsi:** field ini tetap di level kata (bukan per-makna) — kalau nanti ternyata satu kata perlu level CEFR berbeda per makna/POS, ini perlu didiskusikan ulang |
| `topics` | array\<string\> | satu kata bisa punya lebih dari satu topik, berlaku untuk keseluruhan kata (bukan per-makna). Tiap nilai harus merujuk ke `name` yang ada di collection `topics` (§2b). Terisi sejak import karena CSV sumber memang punya kolom `topics` |
| `source` | string | `"oxford3000"` \| `"oxford5000"` \| `"guru"` — bedakan asal data untuk keperluan audit/filter |
| `addedByTeacherId` | string \| null | `uid` guru kalau `source = "guru"` |
| `createdAt` | Timestamp | |
| `updatedAt` | Timestamp | **(baru di v6)** diperbarui setiap kali dokumen berubah — termasuk saat dibuat (`updatedAt == createdAt` untuk dokumen baru). **Wajib**, karena ini yang dipakai query delta bundle (§11) untuk menangkap kata baru **dan** kata lama yang topiknya diedit guru. Tegakkan di rules: `request.resource.data.updatedAt == request.time` pada setiap `create`/`update` |

**Struktur `meanings` (array of map):**

| Field (di dalam tiap elemen `meanings`) | Tipe | Keterangan |
|---|---|---|
| `pos` | string | mis. `"noun"`, `"verb"` |
| `translationId` | string \| null | terjemahan Indonesia **untuk makna ini secara spesifik** — nullable, lihat alur generate di bawah |

> **Kenapa `meanings` (array of map), bukan `pos: array<string>` +
> `translationId: string` tunggal?** Karena satu kata bisa punya makna
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

> **Alur generate `meanings[].translationId` (via ChatGPT API) — direvisi di
> v6:**
> 1. **Saat CSV import** (dev-side script, jalan di laptop dev, pakai API
>    key dev sendiri langsung — bukan lewat Worker karena ini bukan traffic
>    dari user produksi): skrip generate terjemahan untuk semua makna
>    sekaligus (batched) lalu langsung menyimpan hasilnya ke Firestore
>    lewat Admin SDK/service account milik dev.
> 2. **Saat guru menambah kata baru / makna baru** lewat "Tambah Kosakata"
>    (SPEC §4.1): client (akun guru yang login) memanggil **Cloudflare
>    Worker** endpoint `/translate` (§10) dengan kata + POS. Worker balikin
>    teks terjemahan, lalu **client guru yang menulis** hasilnya ke
>    `vocabWords/{id}` di Firestore.
> 3. Kalau panggilan Worker gagal, `translationId` makna itu tetap `null` —
>    tidak ada retry otomatis di background (tidak ada scheduler tanpa Cloud
>    Functions).
> 4. **Lazy display (menggantikan "lazy retry" v5):** saat siswa membuka
>    kamus detail kata yang punya `translationId` masih `null`, client
>    memanggil Worker `/translate` untuk makna itu dan **menampilkan
>    hasilnya di layar saja — TIDAK menulis ke Firestore.** Hasilnya boleh
>    di-cache di memori selama sesi aplikasi berjalan supaya tidak dipanggil
>    berulang di layar yang sama.
>
> > **Kenapa berubah dari v5?** Rencana lama (siswa menulis balik hasil
> > terjemahan) mengharuskan akun siswa punya izin `update` ke
> > `vocabWords`, dan aturan pengamannya — "hanya boleh mengubah
> > `meanings[i].translationId` dari `null` ke non-null" — **tidak bisa
> > ditulis di Security Rules**: bahasa rules tidak punya perulangan, jadi
> > tidak ada cara memeriksa elemen-per-elemen pada array yang panjangnya
> > berubah-ubah. Satu-satunya rule yang bisa ditulis adalah izin
> > all-or-nothing atas `meanings`, yang artinya siswa mana pun bisa
> > menimpa seluruh makna kata apa pun lewat panggilan REST langsung.
> > Untuk penelitian yang datanya harus bersih, risiko itu tidak sepadan
> > dengan penghematan beberapa panggilan API. Maka: **siswa read-only,
> > titik.**
>
> 5. Kekosongan `translationId` yang bertahan adalah **tugas dev/guru**,
>    bukan siswa. Sediakan cara sederhana untuk menemukannya saat analisis
>    (mis. skrip dev yang men-scan `meanings[].translationId == null`), dan
>    isi lewat jalur guru atau skrip.

> **Alur "kata sudah ada" saat guru Tambah Kosakata / saat CSV import
> menemukan duplikat** (SPEC §4.1, §7): karena `docId` = kata yang
> dinormalisasi, kata yang sudah ada tidak bisa dibuat ulang. Tangani ini
> sebagai **operasi tambah elemen ke `meanings`** pada dokumen yang sudah
> ada, bukan error mentah:
> - **CSV import** (skrip manual dev, bukan tugas Claude): kalau baris CSV
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
>    co-write (lihat definisi "mandiri" di §4).
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
penelitian ini (~60 siswa di lingkungan kelas) membuat insentif untuk
melakukan ini rendah, dan memperbaikinya butuh infrastruktur server yang
saat ini di luar anggaran. Kalau validitas data ini kelak jadi masalah nyata
saat analisis skripsi, mitigasi paling ringan adalah audit manual (mis. cari
`masteryStatus: mastered` tanpa `learningSessions` yang cocok datanya) —
bukan redesain arsitektur.

## 4. `learningSessions`

Satu dokumen per sesi belajar 3-fase. Ini sumber data untuk Riwayat
Pembelajaran tab "per sesi" (SPEC §3.6).

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
| `cowriteWordsUsedCorrectly` | array\<string\> | wordId yang berhasil dipakai **mandiri** tanpa kesalahan — diisi client dari field terstruktur respons `/cowrite-turn` (§10.2), bukan hasil parsing teks feedback |
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

> **TBD — sesi yang ditinggal/tidak selesai (belum diputuskan).** Sebuah
> dokumen bisa tertinggal selamanya di `currentPhase = "membaca"` (atau fase
> lain) kalau siswa keluar di tengah jalan. Belum diputuskan: apakah sesi
> semacam ini harus bisa dilanjutkan (resume), harus tetap muncul di Riwayat
> tab "per sesi" sebagai belum selesai, atau ditangani dengan cara lain.
> **Jangan mengasumsikan atau mengimplementasikan salah satu perilaku ini**
> sebelum didiskusikan eksplisit — ini perlu diputuskan sebelum Milestone 7
> (fitur 3 fase) dikerjakan.

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
> meskipun kalimatnya benar secara gramatikal.

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

## 6b. `researchAssessmentResults` — Status: TBD (placeholder)

Collection untuk modul riset **Pre-Test & Post-Test** (SPEC §3.7) —
**terpisah total dari `placementTestResults`** (tujuan, alur, dan
kepemilikan data beda — lihat tabel perbandingan di `SPEC.md` §3.7).

> **Instrumen belum divalidasi — jangan implementasikan isi soal/skoring.**
> Skema di bawah sengaja generik supaya instrumen final bisa dipasang tanpa
> redesign collection.

| Field | Tipe | Keterangan |
|---|---|---|
| `studentId` | string | |
| `type` | string enum | `"preTest"` \| `"postTest"` — satu collection untuk keduanya |
| `responses` | map \| TBD | **placeholder generik** untuk jawaban/hasil — bentuk persis menunggu instrumen final. Sengaja tidak di-strict-type dulu |
| `startedAt` | Timestamp | |
| `completedAt` | Timestamp \| null | |

> Kenapa satu collection dengan field `type`? Karena instrumennya
> kemungkinan besar sama, cuma diambil di waktu berbeda. Kalau nanti
> ternyata benar-benar berbeda bentuk, pertimbangkan pemisahan saat itu —
> jangan dipisah dari awal tanpa kebutuhan konkret.

## 7. Ringkasan Relasi

```
users (siswa) ──1:N── learningProgress ──N:1── vocabWords
users (siswa) ──1:N── learningSessions
users (siswa) ──1:N── placementTestResults        (TBD)
users (siswa) ──1:N── researchAssessmentResults    (TBD)
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
- `researchAssessmentResults` filter by `studentId` + `type` (TBD)

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
- Placement Test & Pre-Test/Post-Test → skema §6 dan §6b sengaja generik.
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
- Semua kata target **wajib** dipakai dan **wajib** bertanda.
- Setelah menerima respons OpenAI, Worker **memvalidasi** bahwa setiap kata
  target muncul minimal sekali sebagai `[[kataTarget|...]]`. Kalau ada yang
  hilang, retry sekali ke OpenAI; kalau masih gagal, balikan error yang
  bisa dibaca client (bukan cerita cacat).
- `kataTarget` di dalam penanda harus **persis** sama dengan kata yang
  dikirim client (sudah lewat `normalizeWord()`), supaya client bisa
  mencocokkannya tanpa normalisasi tambahan.
- AI **boleh dan seharusnya** memakai bentuk infleksi yang natural di
  `bentukTerpakai` — jangan memaksa bentuk dasar, karena itu menghasilkan
  kalimat yang salah gramatikal.

#### `POST /cowrite-turn` — Fase 3 (SPEC §5.3)

**Input:** transcript sejauh ini + daftar kata target yang belum terpakai +
flag apakah giliran ini memakai fitur "saran menulis".

**Output:**

| Field | Tipe | Keterangan |
|---|---|---|
| `aiTurn` | string | kalimat giliran AI berikutnya |
| `feedback` | string \| null | feedback untuk giliran siswa sebelumnya (grammar, typo, dsb) — teks bebas untuk ditampilkan ke siswa |
| `hasError` | boolean | **terstruktur** — `true` kalau giliran siswa sebelumnya mengandung kesalahan |
| `wordsUsedCorrectly` | array\<string\> | **terstruktur** — kata target (bentuk dasar) yang dipakai siswa dengan benar di giliran tersebut |
| `suggestion` | string \| null | isi "saran menulis", hanya diisi kalau client memintanya |

> **Kenapa `hasError` dan `wordsUsedCorrectly` harus terstruktur:** aturan
> mastery di §3 bergantung pada "dipakai mandiri tanpa kesalahan". Kalau
> satu-satunya keluaran adalah teks feedback bebas, client harus menebak
> maknanya dengan parsing string — tidak mungkin andal. Dua field ini yang
> langsung mengisi `learningSessions.cowriteWordsUsedCorrectly`.
>
> **Aturan "mandiri" ditegakkan di client, bukan Worker:** kalau giliran itu
> memakai "saran menulis", client **tidak memasukkan** kata dari
> `wordsUsedCorrectly` ke `cowriteWordsUsedCorrectly`, dan mencatat
> `usedSuggestion: true` di transcript (§4).

#### `POST /translate` — terjemahan makna (§2)

**Input:** kata + POS.
**Output:** teks terjemahan Indonesia.

Dipanggil dari dua tempat:
- **Guru** saat menambah kata/makna baru → hasilnya **ditulis** ke
  Firestore oleh client guru.
- **Siswa** saat membuka kamus detail kata yang `translationId`-nya `null`
  → hasilnya **hanya ditampilkan**, tidak ditulis ke Firestore (§2).

> Endpoint `/word-details` (definisi Inggris via ChatGPT sebagai fallback
> DictionaryAPI) **belum ada dan jangan dibuat dulu** — statusnya menunggu
> pengukuran jumlah kata 404, lihat catatan fallback di §2.

### 10.3 Yang TIDAK lewat Worker

- **Dictionary API** (`api.dictionaryapi.dev`) — langsung dari client, tidak
  ada secret.
- **Text-to-speech fallback** — Web Speech API di browser, tidak ada API
  eksternal.
- **CSV import Oxford 3000/5000** — skrip dev-side, jalan lokal, pakai API
  key dev sendiri (proses one-off, bukan traffic user produksi).
- **Generate bundle statis** (§11) — skrip dev-side, tidak ada AI.
- **Cloze test** (SPEC §5.2) — tidak butuh AI; blank diturunkan dari
  penanda di `storyContent` dan pencocokan jawaban cuma perbandingan string
  di client.
- **Skoring Placement Test / Pre-Test / Post-Test** — dihitung di client
  (§6).
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
  (~60 siswa × beberapa panggilan AI per sesi) — dan kalau lewat kuota,
  request cuma gagal, tidak ada risiko tagihan mendadak seperti Blaze.

## 11. Distribusi Bank Kosakata sebagai Aset Statis (baru di v6)

### 11.1 Masalah yang diselesaikan

Firebase plan Spark membatasi **50.000 pembacaan dokumen per hari**, dan
biayanya dihitung **per dokumen**, bukan per query. Bank kosakata berisi
~5.000 dokumen, kira-kira ~1.000 kata per level CEFR. Kalau browse membaca
dari Firestore, satu siswa membuka satu level = ~1.000 pembacaan. 60 siswa
× sekali saja = 60.000 → kuota habis sebelum jam istirahat, dan aplikasi
berhenti melayani sampai reset harian. Itu belum menghitung perpindahan
level, buka ulang, dan `get()` di dalam security rules yang juga dihitung
sebagai pembacaan.

Penulisan tidak bermasalah: ~20 tulis per sesi belajar × 60 siswa ≈
1.200/hari, jauh di bawah batas 20.000.

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
  `cefrLevel + updatedAt` ditambahkan untuk query delta.
- §2: field `posList` tidak lagi dipakai untuk query Firestore, tapi tetap
  dipertahankan karena ikut masuk bundle dan dipakai filter POS di memori.
- Skema `vocabWords` **tidak berubah** selain penambahan `updatedAt` —
  bundle tidak menuntut restrukturisasi collection apa pun.
