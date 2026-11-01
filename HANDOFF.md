# Vocably — Handoff (status terkini)

**Satu-satunya sumber status terkini proyek.** Ditulis ulang sebagai snapshot
(bukan log) setiap kali status berubah; riwayat ada di `PROJECT_STATE.md`.
Aturan kerja dan hierarki kebenaran ada di `CLAUDE.md` §0 — kode, tes, Git,
dan bukti deploy selalu mengalahkan dokumen ini. Verifikasi ulang fakta yang
penting untuk tugasmu sebelum mengandalkannya.

**Snapshot: 2026-11-02.** Label: **[terverifikasi]** = dicek langsung pada
tanggal itu · **[dilaporkan pemilik]** = hasil yang dilaporkan pemilik proyek,
tidak direproduksi agen · **[catatan]** = tercatat di riwayat, tidak dicek
ulang hari ini.

## 1. Git

- **`vocably`** [terverifikasi 2026-11-02]: branch `main` di `01137f6`
  ("docs: consolidate project documentation"), **1 commit di depan**
  `origin/main` (belum di-push). **Implementasi Placement Test PT-V1.1 (§4)
  beserta tiga perbaikan hasil uji manual ada di working tree, belum
  di-commit dan belum di-stage** (37 file terlacak berubah termasuk dokumen,
  25 file/folder baru, `lib/screens/student/placement_test/placement_test_placeholder_screen.dart`
  dihapus).
- **`vocably-ai-worker`** [catatan 2026-10-28, tidak dicek ulang]: `main` di `5bcb5e4`,
  sama dengan `origin/main`. Satu-satunya perubahan lokal: origin
  `http://localhost:5000` di `wrangler.jsonc` — **khusus lokal; jangan
  di-stage, di-commit, atau di-deploy** (aturan deploy: `CLAUDE.md` §0).
  Worker **tidak** diubah untuk Placement Test.
- **Catatan jaringan:** CA bundle OpenSSL milik Git menolak sertifikat TLS
  jaringan ini; `git -c http.sslBackend=schannel <fetch|push|ls-remote>`
  (Windows certificate store, tetap terverifikasi) berhasil per perintah tanpa
  mengubah config.

## 2. Deployment & data produksi

| Komponen | Status | Bukti |
|---|---|---|
| Flutter web (Firebase Hosting) | **Belum di-hosting**; `firebase.json` tidak punya blok `"hosting"` | [terverifikasi 2026-10-26] |
| Cloudflare Worker | Versi `0bec79ee-2958-475e-97fe-64ababf31c9c` (deploy 2026-10-15T17:08Z UTC) dengan override `--var ALLOWED_ORIGINS`, mencakup seluruh pekerjaan Co-Write | [catatan] `wrangler deployments list` 2026-10-16 (`PROJECT_STATE.md` §5t) |
| Firestore rules | Deploy terakhir yang tercatat: rules Milestone 7; **rule `targetWordSets` Milestone 8, seluruh rules riset, dan rules Placement Test belum di-deploy** | [catatan] `PROJECT_STATE.md` §5h/§5k/§5l/§5w, §6; tidak dicek ke project hari ini |
| Index | `vocabWords` `cefrLevel + updatedAt` live; status deploy index `targetWordSets` tidak tercatat | [catatan] `firebase firestore:indexes` (§5b/§6) |
| Data produksi | 4.952 `vocabWords` + master `topics` ter-seed; **tidak ada data riset maupun placement** (`researchParticipants`/`researchInstrument`/`researchAssessmentResults`/`researchStudy`/`placement*`) | [catatan] konsol Firebase (§5 Stage 3) |

## 3. Hasil verifikasi terakhir

Dijalankan agen pada 2026-11-02 terhadap working tree di atas `01137f6`
(belum di-commit), setelah tiga perbaikan hasil uji manual (§4):

| Cek | Perintah | Hasil |
|---|---|---|
| Analyzer | `flutter analyze` | 0 isu |
| Tes Flutter | `flutter test --concurrency=1` | **652/652** lulus |
| Tooling riset | `cd tools/research && npm test` dengan `VOCABLY_PLACEMENT_SOURCE` | **93 lulus, 2 dilewati, 0 gagal** (rebuild bank placement ikut berjalan). 2 yang dilewati (`sourcePdf.test.js`) dijalankan terpisah dengan PDF dan kunci pretest peneliti: **2/2 lulus** |
| Emulator riset + placement | `cd tools/research && npm run test:rules` | **129/129** lulus (rules pretest/posttest + jendela tahap, rules placement termasuk paritas K2 rules⇄tooling, tooling peneliti & placement, 2 alur end-to-end dengan login Auth emulator) |
| `status` pada data emulator | `npm run admin -- status --emulator --uid emuStudentPlacement` setelah alur klien lewat rules asli | Empat hasil berbeda tampil benar: `level=A1* targetBand=A2`, `level=A1 targetBand=A2`, `level=A2 targetBand=B1`, `level=C1 targetBand=none` (peserta `excluded`); baris pretest tidak berubah |
| Build rilis | `flutter build web --release --dart-define=WORKER_BASE_URL=…` | Berhasil |
| Kunci/secret di `build/web` | Pindai nama file, pola secret, dan sidik jari kunci asli (hanya hitungan) | **0 temuan:** 0/50 pasangan kunci placement, 0/80 pasangan kunci pretest, 0 nama field kunci, 0 pola secret, 0 host/proyek emulator |
| Integritas | Hash sebelum/sesudah | `firestore.rules`, kedua bank soal, `firebase.json`, `pubspec.yaml` tidak berubah |

- **Tidak diuji:** token Firebase asli + Firestore produksi/staging, runtime
  produksi. Perbaikan M1 dan highlight teruji lewat uji widget, controller,
  dan SDK client terhadap rules di emulator, tetapi **belum diklik ulang di
  Chrome** setelah perbaikan. `AppLifecycleListener`: diuji lewat simulasi
  lifecycle di uji widget; perilaku di Chrome/Android sungguhan **belum**.
- **Uji klik-manual emulator PT-V1.1** [dilaporkan pemilik, 2026-11-01]: alur
  placement selesai di browser dan menghasilkan tiga temuan (§4).
- **Artefak lokal di luar repo** dari uji rules terisolasi: `firestore-debug.log`
  di folder scratchpad `pt-spike` (fase sebelumnya) dan `pt-probe`
  (probe kemampuan rules, 2026-10-28). Tidak berisi data nyata.
- **Kunci jawaban pretest privat:** `export_results.js validate-key` OK (80
  entri) pada 2026-10-25 [catatan]. **Kunci placement privat belum
  di-generate** di mana pun (lihat §8).
- **Worker** [catatan 2026-10-15/16]: `npx vitest run --fileParallelism=false`
  148/148, `npx tsc --noEmit` bersih. **`tools/vocab_import`** [catatan
  2026-10-13]: `npm test` 43/43.
- **E2E manual browser modul riset pretest/posttest** [dilaporkan pemilik,
  2026-10-26]: checklist emulator lulus — sebelum jendela tahap ditambahkan;
  ulangi setelah seed emulator baru (§8).

## 4. Posisi fitur

- **Milestone 1–8:** selesai (riwayat `PROJECT_STATE.md` §2, §5–§5n).
- **Co-Write fase 1 + 2, CW-05, input Indonesia, CW-02:** selesai; sisi Worker
  ter-deploy, sisi Flutter belum di-hosting (§5o–§5t).
- **Pilih kata Difficult untuk "Pelajari Kembali":** selesai (§5u).
- **Modul riset Pre/Post Test:** selesai di `main` (§5v–§5y). Sekarang juga
  butuh **jendela tahap terpisah** pretest/posttest (`researchStudy/current`)
  dan menolak peserta tanpa band/tidak aktif (§5za, belum di-commit).
- **Placement Test PT-V1.1 (§5za):** diimplementasikan dan diverifikasi
  **lokal** (belum di-commit, belum di-deploy): bank aman-app, layar tes,
  attempt riset & belajar, **penilaian K2 oleh Security Rules** dari kunci
  yang tidak bisa dibaca client, band otomatis peserta, kontrol buka/tutup
  per tahap, tinjauan/void/retake/restore/band manual di tooling, ekspor
  offline. **K2 belum divalidasi ahli/pembimbing.** **Enrolmen peserta tanpa
  band lewat CLI belum ada** (milestone berikutnya).
- **Perbaikan hasil uji manual PT-V1.1 (§5zb):** penolakan `start()` kini
  menampilkan status yang benar ("Tes belum dibuka"), hanya kata target yang
  tebal + bergaris bawah, dan `status` memisahkan jumlah terjawab, level
  tersimpan, dan band target. Skoring K2 tidak berubah. Di emulator kunci
  placement **sintetis**, jadi jawaban yang benar secara makna tetap
  menghasilkan A1* (`tools/research/README.md`).

## 5. Blocker sebelum produksi / responden sungguhan

1. **Commit** implementasi Placement Test dan perbaikannya (pemilik proyek).
2. **Deploy rules dulu, baru hosting.** Rules produksi saat ini menolak baca
   `researchParticipants`, `researchStudy`, `placementConfig`,
   `placementAttempts`. Deploy `firestore.rules` membawa rule Milestone 8,
   rules riset, dan rules placement sekaligus — keputusan sadar pemilik.
   Rules riset kini **mewajibkan** `researchStudy/current` dengan jendela
   tahap terbuka; tanpa dokumen itu semua tes riset tertolak (fail closed).
3. **Kunci placement privat** di-generate (`build_placement.js --key-out`, di
   luar repo & OneDrive), lalu **seed produksi**: `seed-instrument`,
   `seed-placement --key …`, `study`, `stage`, enrol, `authorize` — dengan
   service account milik peneliti dan izin eksplisit. Belum pernah dilakukan.
4. **Enrolmen peserta tanpa band** (CLI) — belum ada; `enrol` masih wajib
   kolom `band`. Tanpa ini, alur placement riset tidak bisa dipakai untuk
   responden sungguhan.
5. **Konfigurasi Firebase Hosting:** `firebase.json` masih belum punya blok
   `"hosting"`, jadi `firebase deploy --only hosting` belum bisa berjalan
   (`README.md` "Deployment").
6. **Validasi ahli instrumen** (pretest/posttest dan aturan K2 placement) dan
   **pilot** pada siswa non-responden — belum.
7. **Persiapan responden (35–40 siswa):** data demografi; pembersihan data
   uji; prosedur ekspor data belajar — **belum ada tool-nya**.
8. Keputusan riset di §6 yang menyangkut pengambilan data.

## 6. Keputusan riset yang masih terbuka (milik peneliti)

| Keputusan | Dampak | Langkah berikutnya |
|---|---|---|
| **Validasi K2** oleh pembimbing/ahli (dipilih peneliti; belum disahkan) | Klaim validitas level & band placement; `authorize` meminta `--acknowledge-placement-policy` | Catat persetujuan atau keterbatasan |
| **Band manual (D4):** bukti yang sah, band yang diizinkan, kriteria kelayakan bersyarat, perlu persetujuan protokol/pembimbing? | `assign-band` mencatat band + dasar + alasan; peserta `conditional` **tetap diblokir** dari pretest/posttest (fail closed) | Tetapkan kriteria; lalu buat jalur "konfirmasi kelayakan" |
| **Banding/peninjau kedua** atas keputusan peneliti | `placement-restore` hanya mengoreksi void keliru (attempt sama) | Tentukan siapa yang meninjau banding |
| Status pretest/treatment/posttest saat tinjauan `pending` | Saat ini: semua aksi riset peserta itu diblokir; data yang sudah ada tetap | Konfirmasi atau ubah |
| Batas waktu penilaian kiriman yang diterima sebelum penutupan | Saat ini tanpa batas (rules); ekspor menandai attempt `in_progress (incomplete)` | Tentukan bila perlu |
| Kebijakan email/akun peserta (siswa daftar sendiri dengan email pribadi; konfirmasi kepemilikan) | Prasyarat CLI enrolmen | Putuskan sebelum milestone enrolmen |
| Teks UI placement (level saja, tanpa skor; pesan netral untuk tinjauan) | Diimplementasikan sesuai prinsip B13; teks persis belum disetujui | Review teks di `placement_test_screen.dart` |
| Koreksi PDF/JSON PT-V1.1 (daftar D10) | Dokumen peneliti belum direvisi; daftar di `tools/research/README.md` | Revisi `.docx`/PDF/JSON peneliti |
| B2-06 *starve*: label kata kerja, opsinya bentuk kata benda | Validitas satu butir B2 pretest | Review ahli sebelum pilot |
| Retensi / penghapusan data riset | Etika & perlindungan data | Tentukan periode, pelaksana, caranya |
| Verifikasi sesi treatment ke-4 sebelum membuka posttest | Validitas waktu posttest | Tentukan bukti sebelum `--confirm-session4-completed` |
| Format, penyimpanan, akses ekspor | File `operational_*` berisi UID | Setujui set CSV, lokasi, daftar akses |
| Desain set kata sesi treatment (4 × 5 kata per band) dan cara penargetannya | Intervensi belum diimplementasikan | Milestone terpisah |
| Penghitung kemajuan pretest ("Butir 7/20"); kalimat contoh "book" | Pengalaman siswa / teks petunjuk | Setujui atau tolak |

## 7. Known issues & keterbatasan

| Item | Status |
|---|---|
| **Oracle kunci placement lewat attempt belajar:** level yang dikembalikan bisa dipakai, pelan-pelan, untuk menebak kunci (dibatasi 1 attempt belajar/hari/akun; akun ganda bisa melewatinya) | Mitigasi operasional: `learning-placement --close` selama sesi placement resmi |
| Rules tidak bisa membuktikan siapa yang menjawab placement (hanya pengawasan) | Diterima |
| App tidak memverifikasi hash bank placement (tidak ada paket `crypto`); urutan butir tetap divalidasi rules terhadap `placementInstrument` di server | Diterima; tambah dependensi hanya dengan persetujuan |
| `tabSwitchCount` hanya `hidden` (visibilitychange); perangkat kedua/split-screen tidak terdeteksi; nilai ditulis client | Hanya dicatat, tidak pernah dipakai untuk tindakan |
| Penilaian placement mengirim hingga 6 usulan (5 ditolak rules) — muncul sebagai peringatan permission-denied di konsol | Sesuai desain |
| Validator Co-Write heuristik tanpa data POS | Diketahui, terdokumentasi |
| Deteksi bahasa Indonesia berbasis daftar kata | Hanya uji unit & kontrak prompt |
| Penilaian makna CW-05 dan kualitas output LLM | Perlu uji langsung dengan model asli |
| Sisa CW-02 (kontradiksi parsial, pujian kata tak diklaim, dll.) | Teruji lokal; perlu uji langsung |
| Setelah bot memakai kata lewat fallback, siswa tidak bisa lagi mendapat kredit mandiri untuk kata itu di sesi tersebut | Sesuai aturan |
| "Pelajari Kembali" tanpa batas jumlah kata | Keputusan produk |
| "Coba lagi" Per Kata hanya meng-invalidate `historyWordEntriesProvider` | Observasi, belum diverifikasi |
| Binding Rate Limiting native Cloudflare belum dipastikan | Terbuka |
| Build `--wasm` gagal (`flutter_tts` memakai JS interop lama) | Pakai build JS |
| Tes otomatis void percobaan pretest **selesai** belum memeriksa `responses` tetap utuh | Celah tes kecil |
| Belum diverifikasi: E2E Co-Write di Chrome terhadap Worker produksi; klik-manual Milestone 8; pilihan Difficult di lebar HP; klik-ulang layar placement setelah perbaikan §5zb | Terbuka |

## 8. Langkah berikutnya

1. Review lalu commit implementasi Placement Test dan perbaikannya (pemilik
   proyek).
2. Ulangi uji klik di emulator (`tools/research/README.md` "Placement Test
   checklist"): M1 dan highlight di Chrome pada lebar 390 px, lalu
   `siswa.umum@example.test` (placement belajar) dan pretest dengan jendela
   tahap; termasuk `AppLifecycleListener` di Chrome desktop dan Chrome
   Android (pindah tab).
3. Keputusan peneliti di §6, terutama validasi K2, kriteria band manual, dan
   kebijakan akun/email.
4. Milestone berikutnya: CLI enrolmen peserta **tanpa band** (lookup email →
   UID, dry-run, konfirmasi) — belum disetujui.
5. Generate kunci placement privat dan simpan cadangannya di luar repo &
   OneDrive.
6. Saat siap produksi (izin eksplisit): urutan di §5.
7. E2E Co-Write langsung dan klik-manual Milestone 8 (lihat §7).
