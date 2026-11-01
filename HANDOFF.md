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

- **`vocably`** [terverifikasi 2026-11-02]: branch `main` di `ef55afd`
  ("chore: update placement test question options"), sama dengan
  `origin/main` menurut pelacakan lokal. Placement Test PT-V1.1 sudah masuk
  commit `4929b4d` dan `ef55afd`. **Redesain UI (§4) ada di working tree,
  belum di-stage dan belum di-commit:** 40 file terlacak berubah termasuk
  dokumen, 17 file baru (widget layout/feedback/brand, font, tes). Tidak ada
  file yang dihapus.
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
| Flutter web (Firebase Hosting) | **Belum di-hosting**; `firebase.json` tidak punya blok `"hosting"`. Redesain UI belum sampai ke pengguna mana pun | [terverifikasi 2026-11-02] |
| Cloudflare Worker | Versi `0bec79ee-2958-475e-97fe-64ababf31c9c` (deploy 2026-10-15T17:08Z UTC) dengan override `--var ALLOWED_ORIGINS`, mencakup seluruh pekerjaan Co-Write | [catatan] `wrangler deployments list` 2026-10-16 (`PROJECT_STATE.md` §5t) |
| Firestore rules | **Ter-deploy ke `vocably-idn-en` pada 2026-11-02 00.52 WIB**, oleh agen atas izin eksplisit pemilik: mencakup rule `targetWordSets` Milestone 8, rules riset, dan rules Placement Test. `firestore.rules` tidak berubah sejak itu | Keluaran `firebase deploy --only firestore:rules,firestore:indexes`: "released rules" (`PROJECT_STATE.md` §5zc). ID ruleset tidak dicatat |
| Index | `firestore.indexes.json` ter-deploy pada kesempatan yang sama | Keluaran deploy: "deployed indexes … successfully". Status pembangunan tiap index setelahnya tidak dicek |
| Data produksi | 4.952 `vocabWords` + master `topics` ter-seed; **tidak ada data riset maupun placement** (`researchParticipants`/`researchInstrument`/`researchAssessmentResults`/`researchStudy`/`placement*`). Deploy rules tidak menulis data | [catatan] konsol Firebase (§5 Stage 3); tidak dicek ulang hari ini |

## 3. Hasil verifikasi terakhir

Dijalankan agen pada 2026-11-02 terhadap working tree di atas `ef55afd`
(belum di-commit), setelah redesain UI (§4):

| Cek | Perintah | Hasil |
|---|---|---|
| Analyzer | `flutter analyze` | 0 isu |
| Tes Flutter | `flutter test --concurrency=1` | **913/913** lulus, termasuk 210 tes responsif (8 viewport, teks 130% di 320 px, HP miring 844×390 dan 568×320, ukuran target tap) |
| Tooling riset | `cd tools/research && npm test` dengan `VOCABLY_PLACEMENT_SOURCE` | **93 lulus, 2 dilewati, 0 gagal** (rebuild bank placement ikut berjalan). 2 yang dilewati (`sourcePdf.test.js`) butuh PDF peneliti dan tidak diulang pada putaran ini; tooling tidak berubah sejak terakhir lulus |
| Emulator riset + placement | Isi `npm run test:rules` (`node --test --test-concurrency=1 test/rules/*.test.js`) pada port alternatif 8091/9091 | **129/129** lulus. `npm run test:rules` polos gagal start karena port 9099 masih dipakai emulator sisa uji browser, jadi dipakai konfigurasi sementara di luar repo yang menunjuk `firestore.rules` dan index yang sama |
| Build rilis | `flutter build web --release --dart-define=WORKER_BASE_URL=…` | Berhasil; URL Worker produksi ada di bundle. Peringatan "Wasm dry run failed" sudah dikenal (§7) |
| Kunci/secret di `build/web` | Pindai nama file, pola secret, dan sidik jari kunci asli (hanya hitungan) | **0 temuan:** 0/50 pasangan kunci placement, 0/80 pasangan kunci pretest, 0 nama field kunci, 0 pola secret, 0 host/proyek emulator |
| Browser | Build `--profile` + Chrome headless + emulator + Worker tiruan, host produksi diblokir di browser | Masuk, alur 3 fase sampai Selesai, Riwayat, Pelajari Kembali, Keranjang, Pre-Test 20 soal, Placement, target guru, tambah/edit kata: semua tuntas; 0 overflow horizontal pada 8 viewport + 2 lanskap; 1 error konsol, yaitu 400 yang disengaja |
| Integritas | `git diff` | `firestore.rules`, indeks, `firebase.json`, kedua bank soal, `lib/services`, `lib/providers`, `lib/models` tidak berubah; 0 file ter-stage |

- **Tidak diuji:** token Firebase asli + Firestore produksi/staging, runtime
  produksi, Worker dan LLM asli (uji browser memakai Worker tiruan), Chrome
  di HP Android sungguhan, keyboard layar + lanskap di perangkat nyata.
  Uji browser memakai build profile, yang tidak melaporkan RenderFlex
  overflow; overflow itu dicakup tes responsif. Perbaikan M1 belum diklik
  ulang di Chrome. `AppLifecycleListener`: diuji lewat simulasi lifecycle di
  uji widget; perilaku di Chrome/Android sungguhan **belum**.
- **Uji klik-manual emulator PT-V1.1** [dilaporkan pemilik, 2026-11-01]: alur
  placement selesai di browser dan menghasilkan tiga temuan, sudah diperbaiki
  (`PROJECT_STATE.md` §5zb).
- **`status` pada data emulator** [catatan 2026-11-02, sebelum redesain]:
  `npm run admin -- status --emulator --uid emuStudentPlacement` menampilkan
  empat hasil berbeda dengan benar.
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
  dan menolak peserta tanpa band/tidak aktif (§5za).
- **Placement Test PT-V1.1 (§5za):** selesai di `main`, rules ter-deploy,
  app belum di-hosting, kunci dan bank belum di-seed ke produksi: bank
  aman-app, layar tes,
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
- **Redesain UI & responsif (§5zd):** selesai dan diverifikasi lokal, belum
  di-commit dan belum di-hosting. Semua layar yang ada memakai arah "buku
  latihan" (`DESIGN_REFERENCE.md` §0), font lokal, dan kerangka responsif
  `widgets/app_layout.dart`. Logika, rules, data, kontrak Worker, skoring,
  dan bank soal tidak berubah. Tidak ada layar profil/pengaturan atau
  manajemen siswa di aplikasi, jadi keduanya tidak termasuk.

## 5. Blocker sebelum produksi / responden sungguhan

1. **Commit** redesain UI (pemilik proyek).
2. **Jendela tahap riset:** rules yang kini ter-deploy **mewajibkan**
   `researchStudy/current` dengan jendela tahap terbuka; tanpa dokumen itu
   semua tes riset tertolak (fail closed). Ini perilaku yang benar, bukan
   gangguan, sampai langkah 3 selesai.
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
| **Tangga level di dashboard selalu membuka A1.** Menekan level mana pun menyetel `vocabBrowserFilterProvider` lalu mendorong layar kosakata, tetapi provider itu auto-dispose, jadi nilainya sudah hilang saat layar terbuka (terkonfirmasi di browser: tekan B1 menghasilkan A1). Kode ini tidak berubah sejak sebelum redesain; tes lama hanya memeriksa layar terbuka | **Bug lama, belum diperbaiki.** Perbaikan mengubah masa hidup state (`keepAlive` atau parameter level), jadi menunggu keputusan pemilik |
| **Mode emulator dengan sesi tersimpan menghubungi Auth sungguhan** sebelum `useAuthEmulator` berlaku. Saat uji redesain, beberapa percobaan login akun dummy sempat mengenai `identitytoolkit.googleapis.com` dan ditolak 400; tidak ada data produksi berubah | Peringatan dan cara menghindarinya ada di `tools/research/README.md`. Perilaku app tidak diubah |
| Komentar `firestore.rules` (dua tempat) masih tertulis "NOT deployed", padahal rules sudah ter-deploy | Komentar basi; dibiarkan karena pekerjaan redesain dilarang menyentuh rules. Perbarui saat rules berikutnya diubah |
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
| Belum diverifikasi: E2E Co-Write di Chrome terhadap Worker produksi; klik-ulang M1 setelah perbaikan §5zb; redesain di HP Android sungguhan | Terbuka |

## 8. Langkah berikutnya

1. Review tampilan redesain lalu commit (pemilik proyek): satu commit untuk
   kode + tes, satu untuk dokumen. Kode tidak bisa dipecah lebih kecil karena
   token tema yang dihapus membuat tiap bagian tidak terkompilasi sendirian.
2. Putuskan perbaikan bug tangga level dashboard (§7).
3. Coba redesain di HP Android sungguhan, termasuk keyboard layar dan
   posisi miring; ulangi M1 dan `AppLifecycleListener` (pindah tab) di sana
   (`tools/research/README.md` "Placement Test checklist").
4. Keputusan peneliti di §6, terutama validasi K2, kriteria band manual, dan
   kebijakan akun/email.
5. Milestone berikutnya: CLI enrolmen peserta **tanpa band** (lookup email →
   UID, dry-run, konfirmasi) — belum disetujui.
6. Generate kunci placement privat dan simpan cadangannya di luar repo &
   OneDrive.
7. Saat siap produksi (izin eksplisit): urutan di §5.
8. E2E Co-Write langsung terhadap Worker produksi (lihat §7).
