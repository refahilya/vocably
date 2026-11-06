# Vocably — Handoff (status terkini)

**Satu-satunya sumber status terkini proyek.** Ditulis ulang sebagai snapshot
(bukan log) setiap kali status berubah; riwayat ada di `PROJECT_STATE.md`.
Aturan kerja dan hierarki kebenaran ada di `CLAUDE.md` §0 — kode, tes, Git,
dan bukti deploy selalu mengalahkan dokumen ini. Verifikasi ulang fakta yang
penting untuk tugasmu sebelum mengandalkannya.

**Snapshot: 2026-11-07** (instrumen v2; sisanya dari 2026-11-03). Label: **[terverifikasi]** = dicek langsung
pada tanggal itu · **[dilaporkan pemilik]** = hasil yang dilaporkan pemilik
proyek, tidak direproduksi agen · **[catatan]** = tercatat di riwayat, tidak
dicek ulang hari ini · **[asumsi]** = keputusan sementara agen yang perlu
dikonfirmasi peneliti.

## 1. Git

- **`vocably`** [terverifikasi 2026-11-07]: `main` = `origin/main` di
  `cd9f80b` (treatment riset, §5zj, tiga commit; di-push pemilik). Kode yang
  ter-deploy (rules dan Hosting, §2) = isi commit itu.
  **Instrumen v2 (§5zk) belum di-commit** — seluruhnya di working tree untuk
  ditinjau dan di-commit pemilik. Data v2 **sudah di-seed ke produksi dari
  working tree ini** (§2); Hosting **belum** di-deploy ulang.
- **`vocably-ai-worker`** [catatan 2026-10-28, tidak dicek ulang]: `main` di
  `5bcb5e4`, sama dengan `origin/main`. Satu-satunya perubahan lokal: origin
  `http://localhost:5000` di `wrangler.jsonc` — **khusus lokal; jangan
  di-stage, di-commit, atau di-deploy** (aturan deploy: `CLAUDE.md` §0).
  Worker **tidak** diubah untuk Placement Test, Panel Riset, maupun treatment.
- **Catatan jaringan:** CA bundle OpenSSL milik Git menolak sertifikat TLS
  jaringan ini; `git -c http.sslBackend=schannel <fetch|push|ls-remote>`
  berhasil per perintah tanpa mengubah config.

## 2. Deployment & data produksi

| Komponen | Status | Bukti |
|---|---|---|
| Firestore rules | **Ter-deploy 2026-11-03 06:34 UTC** (13.34 WIB) oleh agen atas izin eksplisit pemilik: rules working tree = Panel Riset + treatment riset (§5zj). `--dry-run` dulu (kompilasi OK), lalu rilis | Keluaran `firebase deploy --only firestore:rules` ("released rules") [terverifikasi] |
| Flutter web (Firebase Hosting) | **Ter-deploy 2026-11-03 06:36 UTC** (`Last-Modified: Tue, 03 Nov 2026 06:36:07 GMT`): build rilis working tree (§5zj), `WORKER_BASE_URL` produksi. `main.dart.js` live = build lokal (SHA-256 sama); kelima header keamanan ada di `web.app` & `firebaseapp.com`; app tampil di Chrome 390 px, Firebase SDK 12.17.0, 0 error konsol / pelanggaran CSP | `firebase deploy --only hosting`; `curl -I`; Playwright [terverifikasi] |
| Cloudflare Worker | Versi `0bec79ee-…` (deploy 2026-10-15) dengan override `--var ALLOWED_ORIGINS`. **CORS dicek ulang 2026-11-03:** preflight dari `https://vocably-idn-en.web.app` → `204` + `Access-Control-Allow-Origin` origin itu + `Vary: Origin`; origin asing → tanpa ACAO | `curl -X OPTIONS` [terverifikasi]; versi [catatan] |
| Index | `firestore.indexes.json` ter-deploy 2026-11-02; tidak berubah (query treatment memakai index yang sudah ada / index otomatis satu field) | [catatan] |
| Data riset produksi | `researchInstrument` **8** (`v1_*` + `v2_*`; v2 di-seed agen 2026-11-07 atas izin pemilik: dry-run → apply → re-run `unchanged`), `placementInstrument` 1, `researchStudy/current` **active** (belum ada jendela tahap yang pernah dibuka), **operator aktif 1** (grant dilaporkan pemilik: `unchanged`/`active: true`), **rencana treatment aktif `t2`** (`researchTreatmentPlan` 8 dokumen `t1_*` + `t2_*`; `researchStudy/current.treatment = {planVersion: t2, makeupDeadlineDays: 2}` sejak 2026-11-07, sebelumnya `t1`; 0 set sesi riset pernah dibuka. Riwayat `t1`: `researchTreatmentPlan` 4 dokumen + `researchStudy/current.treatment = {planVersion: t1, makeupDeadlineDays: 2}`, di-seed agen 2026-11-03 dengan dry-run → apply → re-run `unchanged`, log `C:\vocably-private\audit\admin.private.jsonl`). **0** peserta, roster, attempt, catatan treatment, entri audit | Inspeksi baca-saja Admin SDK sebelum & sesudah deploy [terverifikasi] |
| Data non-riset produksi | 3 `users`, 60 `learningSessions`, 38 `learningProgress` (data uji pengembangan), 2 `targetWordSets` biasa untuk semua siswa (`YEcZWDt5…` A1 3 kata **tanpa tanggal akhir**; `test-m6-target` kedaluwarsa), 4.952 `vocabWords` [catatan] | Inspeksi baca-saja (hitungan saja) [terverifikasi] |

## 3. Hasil verifikasi terakhir

**Instrumen v2 (§5zk), dijalankan agen 2026-11-07 terhadap working tree:**

| Cek | Hasil |
|---|---|
| PDF v2 → diff terhadap bank v1 (skrip baca-saja) | Tepat **8 teks pengecoh** berubah, sesuai catatan peneliti; kata, nomor, kelas kata, ID butir sama |
| `build_instrument.js` (PDF v2) | 80 butir, §3.4 cocok, kunci 5/5/5/5, 320 ID opsi unik, teks kunci 78 exact + 2 wrapped, 80/80 kata di bundle; `--check` → `instrument_v2.json` up to date |
| Kunci v2 ⇄ kunci v1 (hitungan saja) | Huruf kunci sama **80/80**, teks kunci sama 80/80; ID opsi berbeda 320/320 (versi ikut di-hash) |
| `sourcePdf.test.js` dengan PDF & kunci v2 | 2/2 (rebuild = bank ter-commit; kunci privat = build baru) |
| Rencana `t2` | `--check` OK; *seed*, urutan sesi, dan alokasi **identik dengan `t1`** |
| `npm test` | **106 lulus, 3 dilewati, 0 gagal** (+2 tes rencana) |
| `npm run test:rules` | **188/188** |
| `flutter analyze` / `flutter test --concurrency=1` | 0 isu / **1054/1054** (+3: aset & service v2) |

Dijalankan agen pada 2026-11-03 terhadap working tree treatment (§5zj):

| Cek | Perintah | Hasil |
|---|---|---|
| Analyzer | `flutter analyze` | 0 isu |
| Tes Flutter | `flutter test --concurrency=1` | **1051/1051** (1007 sebelumnya + 44 baru: model & parsing treatment, paritas payload ⇄ fixture, controller sesi riset, dashboard/kartu sesi, Panel treatment & susulan, responsif termasuk dialog buka sesi di semua viewport) |
| Tooling riset | `cd tools/research && npm test` | **104 lulus, 3 dilewati, 0 gagal** (dilewati: 2 cek PDF peneliti, 1 rebuild bank placement) |
| Emulator (rules + tooling + ekspor) | `npm run test:rules` | **188/188** (158 sebelumnya + 30 baru: `treatmentRules.test.js` 23, `treatmentAdmin.test.js` 7; tes posttest lama diperbarui untuk gerbang 4/4) |
| Build rilis | `flutter build web --release --dart-define=WORKER_BASE_URL=…` | OK; bundle tanpa host emulator/`localhost`/fake worker |
| Rencana `t1` | `node bin/build_treatment_plan.js --check plans/treatment_plan_t1.json` | OK (re-derivasi dari seed cocok; semua kata ada di bundle level band-nya) |

**Browser E2E [terverifikasi 2026-11-03]** — build profile terhadap emulator
Firestore/Auth (`demo-vocably-test`, banner "Running in emulator mode") +
*fake worker* lokal (kontrak `/generate-story` & `/cowrite-turn`, scratchpad,
tidak di repo; token emulator tidak diterima Worker produksi), Playwright,
peneliti 1280 px + siswa 390 px:
1. Siswa A2 mengerjakan **Pre-Test lewat UI** (20 butir) → panel "2 selesai",
   band A2 "1 peserta siap".
2. Daftar Target Kata guru tidak menampilkan set riset; "Target Kata Hari Ini"
   siswa tidak berisi kata riset.
3. Peneliti **Buka sesi 1** A2 (dialog: 5 kata rencana, centang pengawasan
   wajib) → rules emulator menerima → stabilo "Sesi 1 dibuka"; "Buka sesi 2"
   nonaktif selama sesi 1 terbuka; entri audit tampil.
4. **Kartu "Sesi Riset ke-1" muncul sendiri** di dashboard siswa yang sudah
   terbuka (listener) → daftar 5 kata → cerita (rules menerima create sesi
   resmi) → Cloze (1 salah sengaja) → Co-Write (5 kata) → Selesai → kartu
   "Sudah selesai"; panel langsung "1/4 selesai".
5. Siswa B1 tidak hadir di sesi 1 (sesi lampau disiapkan lewat setup
   emulator) → panel menawarkan **Susulan sesi 1** → dibuka → B1 melihat kartu,
   menyelesaikan sesi → tercatat `makeup`; "Susulan dipakai: sesi 1", tidak
   ada tawaran susulan kedua.
6. Sesi 2–4 A2 dicatat lewat setup emulator → panel "4/4 sesi selesai" →
   **Izinkan Post-Test** (rules menerima gerbang 4/4); B1 (1/4) tetap
   "Menunggu 4 sesi treatment"; CLI `authorize --stage postTest` untuk B1
   ditolak `treatment not completed (1/4 …)`.
7. `status` CLI menampilkan `treatment=n/4`; `export_treatment.js --emulator`
   menghasilkan baris benar (regular/makeup, hadir, 0 masalah) tanpa teks
   co-write.
- **Tidak diuji:** treatment di **produksi** (tidak ada akun peserta; akun uji
  palsu di produksi dilarang); cerita/Co-Write dengan Worker & LLM produksi
  di bawah CSP; HP Android sungguhan; banyak siswa bersamaan di jaringan
  sekolah; sesi yang selesai setelah jendela tutup lewat UI (diuji di rules
  dan ekspor).

### 3b. Keamanan Hosting — temuan OWASP ZAP (2026-11-03, agen; §5zi)

| Cek | Hasil |
|---|---|
| ZAP 2.17.0 headless (spider + client spider Firefox + passive) ke **produksi** sebelum perbaikan | Medium: CSP Header Not Set (10038, 4 URL), Missing Anti-clickjacking Header (10020); Low: nosniff (10021). Cross-Domain Misconfiguration (10098) **hanya** pada `www.gstatic.com`, `fonts.gstatic.com`, `api.dictionaryapi.dev` — bukan pada Hosting maupun Worker [terverifikasi] |
| CORS origin sendiri (`curl` dengan `Origin` asing) | Hosting: tanpa header CORS. Worker: preflight/POST dengan origin asing atau `null` tanpa `Access-Control-Allow-Origin`; origin produksi di-echo + `Vary: Origin` [terverifikasi] |
| `flutter analyze` / `flutter test --concurrency=1` | 0 isu / **1007/1007** (999 + 8 di `test/hosting_security_headers_test.dart`) |
| Build rilis + server lokal yang memasang header dari `firebase.json` (emulator Hosting & `firebase serve` **tidak** memasang `headers`) | App tampil, splash hilang, Firebase app `vocably-idn-en` terinisialisasi, login salah → "Email atau password salah." lewat Auth produksi; 0 pelanggaran CSP; stylesheet engine Flutter terpasang |
| Sesi login di bawah CSP yang sama (build profile + emulator Firestore/Auth `demo-vocably-test`; hanya `connect-src` ditambah host emulator untuk uji ini) | `siswa.b1@example.test` login → dashboard (baca Firestore) → Jelajah B1 (bundle aset) → detail kata (dictionaryapi + TTS) → Pre-Test: attempt dibuat dan satu jawaban tersimpan (`status --emulator`: `in_progress 1/20`); 0 pelanggaran CSP |
| Probe CSP di halaman yang sama (skrip halaman sendiri) | Diizinkan: dictionaryapi, Worker (401 tanpa token), googleapis, gstatic, fonts.gstatic, audio. Diblokir: inline script, `eval`, skrip eksternal asing, `connect-src` asing, framing |
| ZAP ke server lokal sesudah perbaikan | 10038/10020/10021 hilang. Sisa: **CSP: style-src unsafe-inline (10055, Medium)** — diterima, lihat §7 |
| **Produksi sesudah deploy** (`curl -I`, Chrome, ZAP baseline + probe CORS) | Kelima header ada di `web.app` & `firebaseapp.com`, tanpa header CORS untuk `Origin` asing. App tampil, Firebase SDK 12.17.0 terinisialisasi, 0 pelanggaran CSP, login salah → "Email atau password salah.". ZAP: 10038/10020/10021 **hilang**; sisa di Vocably hanya 10055 `style-src unsafe-inline`; 10098 hanya pada `www.gstatic.com`, `fonts.gstatic.com`, `api.dictionaryapi.dev`. Temuan Low baru: Worker tanpa HSTS (10035) |
| Belum diuji di produksi | Login akun sungguhan, Firestore tulis, Co-Write/cerita di bawah CSP (diuji lokal terhadap emulator, kecuali Worker); HP Android, Firefox, Safari |


## 4. Posisi fitur

- **Milestone 1–8:** selesai (riwayat `PROJECT_STATE.md` §2, §5–§5n).
- **Co-Write fase 1 + 2, CW-05, input Indonesia, CW-02:** selesai (§5o–§5t);
  Worker ter-deploy.
- **Modul riset Pre/Post Test** (§5v–§5y, §5za), **Placement Test PT-V1.1**
  (§5za–§5zg; **K2 belum divalidasi ahli/pembimbing**), **Panel Riset +
  enrolmen tanpa band** (§5zh): di `main`, rules & Hosting ter-deploy.
- **Instrumen Pre/Post-Test v2 (§5zk): dibangun & diverifikasi lokal; belum
  di-commit, belum di produksi.** v1 + 8 teks pengecoh direvisi validator
  (A2-15 b, A2-17 d, B1-02 d, B1-04 b, B1-10 a, B1-18 b & d, B2-20 d); butir,
  kata, kunci sama. Versi aktif tooling = v2; app mem-bundle v1 & v2 dan
  memuat bank sesuai `instrumentVersion` peserta; rencana `t2` = alokasi `t1`.
  PDF v1 tidak diarsipkan (keputusan pemilik; v1 tidak pernah dipakai untuk
  data) — v1 tercatat lewat bank di Git, kunci privat, dan SHA-256 PDF.
- **Treatment riset (§5zj): selesai, ter-deploy (rules + Hosting), rencana
  `t1` ter-seed; di-commit & di-push (§1).**
  - rencana 4 × 5 kata per band dari 20 kata Pre/Post-Test, diacak **sekali
    per band** dari *seed* tercatat, dikunci (`researchTreatmentPlan`,
    create-only; file `tools/research/plans/treatment_plan_t1.json`, penerusnya `t2`);
  - Opsi B: set `targetWordSets` per sesi dengan `research`, siswa hadir
    ditandai di Panel, jendela 60/90/120 menit; susulan satu kali per siswa
    (`rtm_{uid}`, batas 2 hari, bisa diubah); pembukaan ulang ≤ 12 jam;
  - sesi belajar resmi = `targetWordSetId` + `researchSession` (eksplisit,
    rules); belajar biasa tetap terbuka termasuk sebelum Pre-Test;
  - penyelesaian di `researchTreatment/{uid}` (bukti lengkap dicek rules),
    rekonsiliasi otomatis dari dashboard + `treatment-record` (CLI);
  - Post-Test butuh 4/4 + atestasi (Panel & CLI);
  - ekspor keterlaksanaan `bin/export_treatment.js` (sesi, attempt, paparan
    kata instrumen sebelum Pre-Test / selama treatment, ringkasan) — hanya
    hitungan, ID riset.

## 5. Blocker sebelum mengundang responden

1. **Instrumen v2: commit + deploy Hosting** (§8 langkah 1–2). Bank `v2_*` dan
   rencana `t2` sudah di produksi; app yang ter-deploy belum memuat bank v2,
   jadi peserta v2 belum bisa mengerjakan tes. **Jangan `enrol` siapa pun sebelum Hosting di-deploy:**
   peserta mencatat versi instrumen saat di-enrol, dan rules menolak sesi
   treatment bila versi peserta ≠ versi rencana aktif.
2. **Validasi ahli instrumen** (guru bahasa Inggris; Pre/Post-Test, aturan K2
   dan "+1 band"): revisi 8 pengecoh dari validator sudah masuk sebagai v2;
   **status validasi formal (lembar validasi, mis. Aiken's V) belum
   dilaporkan** — instrumen tetap tidak boleh disebut valid/reliabel. Revisi
   isi berikutnya = versi baru lagi (`v3`, rencana `t3`).
3. **Gladi teknis** di sekolah (2–3 siswa non-responden, HP & jaringan
   sekolah, cohort `pilot`/`test`): login, placement, pretest, **satu sesi
   treatment lengkap dengan cerita & Co-Write Worker produksi**, posttest,
   ekspor. Ini juga satu-satunya uji LLM/Worker produksi di bawah CSP.
4. **Pembersihan data uji produksi** (setelah gladi): set target biasa
   `YEcZWDt5…` (A1, semua siswa, tanpa batas akhir) masih tampil di "Target
   Kata Hari Ini" semua siswa; 3 akun uji + sesi/progres belajarnya. Tidak
   memengaruhi data riset (terpisah), tapi mengganggu pengalaman siswa. Hanya
   lewat Console/Admin, dengan cadangan.
5. Persiapan responden: akun siswa (daftar sendiri), CSV e-mail untuk
   `enrol`, persetujuan (sudah, dilaporkan pemilik), **lembar hadir & log
   gangguan teknis manual** per sesi.

## 6. Keputusan riset — final, terbuka, dan asumsi agen

**Final (pemilik, 2026-11-03):** kata treatment = 20 kata Pre-Test band, 4 × 5,
acak sekali per band lalu dikunci; Opsi B; urutan sesi sama untuk satu band
(susulan satu-satunya pengecualian); belajar biasa boleh termasuk sebelum
Pre-Test, kata instrumen tidak disembunyikan, paparan dicatat; sesi resmi di
kelas dengan pengawasan, sesi di luar kelas ditandai; definisi sesi selesai
dan bukti sesi 4 (lihat `DATA_MODEL.md` §6e); 6 kriteria eksklusi; **satu
susulan per siswa, batas sementara 2 hari**; Post-Test segera setelah
susulan walau beda hari; validator = guru bahasa Inggris; persetujuan &
izin wali sudah ditangani; kebijakan retensi/akses ditunda.

**Asumsi sementara agen [asumsi] — perlu konfirmasi:**

| Asumsi | Alasan | Cara mengubah |
|---|---|---|
| Urutan sesi `t1`/`t2` = **urutan acak bawaan** (grup G1..G4 sesuai hasil acak), sama untuk semua band | Peneliti belum memberi urutan per band; urutan acak netral. `t2` sengaja memakai *seed* & urutan `t1` (keputusan pemilik 2026-11-07) | Rencana versi baru dengan `--order`, `seed-treatment --plan …` (diizinkan selama belum ada sesi rencana aktif yang dibuka) |
| Batas susulan dihitung dari **tutupnya pembukaan pertama** sesi itu (+2 hari) | Titik waktu yang pasti dan tercatat | `seed-treatment --makeup-days N` (1–14) |
| Susulan hanya ditawarkan **setelah** jendela sesi itu tutup; selama masih buka → "Buka ulang sesi" (≤ 12 jam sejak pembukaan pertama, untuk terlambat/gangguan teknis) | Membedakan "terlambat hari itu" dari "tidak hadir" | Kode Panel & rules (`kTreatmentReopenLimit`, `validRegularOpening`) |
| Selama susulan belum dipakai, siswa boleh **melewatkan satu sesi** dan lanjut ke sesi berikutnya bersama kelas, lalu menyusul | Tanpa ini, siswa yang absen sekali tertahan dan otomatis gugur; sesuai "satu susulan" | Rules `validResearchSessionCreate` |
| "Sesi di luar kelas" ditangani dengan: **mulai hanya di dalam jendela** untuk siswa yang ditandai hadir + atestasi pengawasan + **tanda `completed_after_window`** di ekspor (selesai setelah jendela tutup). Lokasi fisik tidak dideteksi (tanpa GPS) | Web app tidak bisa membuktikan lokasi; GPS menambah risiko privasi dan tidak andal di dalam gedung | Keputusan desain; bandingkan dengan lembar hadir |
| Rencana `t1` di-seed ke produksi 2026-11-03, sebelum validasi ahli; digantikan `t2` saat v2 di-seed | Berversi; tidak memblokir versi baru | Lihat blocker 1–2 |
| Siswa yang menyusul sesi 4 mengerjakan Post-Test setelah peneliti **mengizinkan & membuka** Post-Test lagi untuknya | Otorisasi per siswa dan jendela tahap yang bisa dibuka berulang sudah ada | — |

**Masih terbuka (milik peneliti):**

| Keputusan | Dampak | Langkah berikutnya |
|---|---|---|
| **Validasi K2** dan instrumen oleh guru bahasa Inggris (lembar validasi, mis. Aiken's V) | Klaim validitas; revisi butir → versi baru bank + rencana | Jadwalkan sebelum gladi |
| Pilot vs gladi teknis saja (KR-20 dari data pretest studi bila tanpa pilot) | Keterbatasan yang dilaporkan | Putuskan & tulis di metodologi |
| Cara memakai data paparan awal (dilaporkan saja / analisis tambahan dengan & tanpa siswa terpapar) | Analisis | Tentukan sebelum analisis |
| Retensi / penghapusan data riset, roster nama, log audit; lokasi & akses ekspor | Etika & perlindungan data | Ditunda (pemilik) |
| Band manual / `conditional` | Sesuai keputusan eksklusi: peserta dengan void integritas **dikeluarkan**; `assign-band` tidak dipakai | Konfirmasi di protokol |
| Teks UI Panel (treatment, susulan, pernyataan) dan kartu siswa | Dibuat agen, belum disetujui | Review `lib/screens/teacher/research_panel/`, `dashboard_screen.dart` |
| B2-06 *starve*; koreksi PDF/JSON PT-V1.1 (D10) | Validitas butir | Review ahli |
| Batas waktu penilaian kiriman sebelum penutupan; status peserta saat tinjauan `pending` | Lihat versi sebelumnya | Tentukan bila perlu |

## 7. Known issues & keterbatasan

| Item | Status |
|---|---|
| **Banner Pre/Post-Test di dashboard siswa tidak memperbarui diri sendiri** saat peneliti membuka tahap atau mengizinkan siswa yang sedang di dashboard (baru benar setelah siswa membuka layar tes atau kembali ke dashboard). **Kartu sesi treatment sudah live** (listener) | Perilaku lama untuk banner tes; saat sesi kelas: minta siswa mengetuk banner |
| Cermin progres `researchProgress` best effort: kalau tulisan cermin gagal (offline), panel menampilkan hitungan sebelumnya sampai jawaban berikutnya tersimpan; attempt yang baru dibuat tetapi cerminnya gagal tampil "belum mulai" | Sesuai desain; keputusan rules tidak pernah memakai cermin |
| Roster menyimpan nama saat `enrol`; ganti nama setelahnya tidak ikut | Diterima |
| Otorisasi massal = satu batch per siswa (batas 20 `get()` rules per batch); 40 siswa ≈ 40 tulisan berurutan | Diterima; penolakan satu siswa tidak menghentikan yang lain |
| Tutup otomatis 60/90/120 menit memakai jam perangkat operator; jam yang sangat salah ditolak rules (closeAt harus di masa depan menurut server) | Diterima |
| Entri audit dari satu batch (void + retake) punya waktu sama; urutan tampilannya di "Riwayat tindakan" bisa terbalik | Kosmetik |
| Void/retake/restore placement riset, void attempt `completed`, dan placement belajar tetap hanya lewat CLI | Sengaja (kebijakan belum final / jarang) |
| Sesudah operator dicabut saat tab Riset terbuka, shell pindah ke tab yang masih ada (Kosakata) | Sesuai desain shell |
| **Mode emulator dengan sesi tersimpan menghubungi Auth sungguhan** sebelum `useAuthEmulator` berlaku | Peringatan dan cara menghindarinya ada di `tools/research/README.md`. Perilaku app tidak diubah |
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
| **CSP `style-src 'unsafe-inline'`** (ZAP 10055, Medium) | Diterima: engine Flutter menyisipkan `<style>` sendiri yang isinya beda per browser/versi; Hosting statis tidak bisa nonce. `script-src` tetap ketat (`README.md` "Deployment" §1) |
| ZAP "Cross-Domain Misconfiguration" (10098) pada `www.gstatic.com`, `fonts.gstatic.com`, `api.dictionaryapi.dev` | Bukan origin Vocably; CDN/API publik dan app butuh `*` untuk memuatnya. Tidak bisa/perlu diubah |
| Loader SDK Firebase (`firebase_web_sdk_loader_web.dart`) memakai nama global internal FlutterFire (`firebase_core`/`firebase_auth`/`firebase_firestore`) | Kalau upgrade FlutterFire mengubahnya atau plugin web baru ditambah, Firebase gagal start (layar error init) — cek di browser setelah upgrade |
| Worker produksi juga menerima origin `http://localhost:5555` (README "Deployment" §3), padahal `DATA_MODEL.md` §10.1 menyebut produksi tidak boleh menerima localhost | Inkonsistensi dokumen lama; tidak diubah di §5zi (Worker repo terpisah, butuh deploy). Risiko kecil: tetap perlu ID token Firebase |
| Worker tidak mengirim `Strict-Transport-Security` (ZAP 10035, Low) | Ditemukan pada scan 2026-11-03; tidak diubah (repo Worker terpisah, butuh deploy Worker) |
| `canvaskit.wasm` dimuat dari `www.gstatic.com`; di cache kosong pada jaringan lambat bisa puluhan detik (46 s teramati saat uji lokal) | Perilaku bawaan Flutter; opsi self-host (`--no-web-resources-cdn`) belum dievaluasi |
| Tes otomatis void percobaan pretest **selesai** belum memeriksa `responses` tetap utuh (void panel `in_progress` sudah diperiksa) | Celah tes kecil |
| Belum diverifikasi: E2E Co-Write di Chrome terhadap Worker produksi; redesain dan panel di HP Android sungguhan | Terbuka |
| **Keaslian data belajar:** siswa yang memanggil API langsung bisa memajukan fase sesi resminya (Cloze/Co-Write) tanpa benar-benar belajar — hanya untuk sesi yang ia ditandai hadir dan dimulai di dalam jendela. Rules memeriksa bentuk & bukti, bukan keaslian (`DATA_MODEL.md` §3a) | Diterima (Spark, tanpa server); data belajar dipakai sebagai bukti keterlaksanaan, bukan hasil utama; lembar hadir & pengawasan |
| **Lokasi/pengawasan tidak terdeteksi app:** "di kelas" = jendela yang dibuka peneliti + siswa yang ditandai hadir + atestasi; siswa yang ditandai hadir lalu mengerjakan dari tempat lain di dalam jendela tidak bisa dibedakan | Diterima; ekspor menandai `completed_after_window`; cocokkan dengan lembar hadir |
| "Satu sesi terbuka per band" dan "susulan hanya setelah jendela tutup" dijaga **Panel**, bukan rules (rules menjaga urutan pembukaan pertama, ≤ 12 jam pembukaan ulang, satu susulan, batas hari) | Diterima; operator tunggal |
| `targetWordSets` bisa dibaca semua akun yang login → UID siswa yang ditandai hadir di set riset terlihat oleh akun lain yang memakai alat teknis (bukan nama) | Diterima (pola target lama); tercatat |
| Jendela sesi tidak bisa ditutup lebih awal (set create-only); kartu siswa hilang sendiri saat `endAt` lewat | Diterima; pilih 60/90/120 menit sesuai jam pelajaran |
| Siswa yang ditandai hadir untuk satu sesi bisa memulai ulang sesi itu (tanpa resume) berkali-kali selama jendela; semua attempt terekspor, yang tercatat = yang pertama selesai | Sesuai keputusan "tanpa resume" |
| Pembukaan sesi dengan satu calon peserta tidak menampilkan daftar centang (langsung "Siswa: …"); bila siswa itu tidak hadir, batalkan dialog | Kosmetik |
| Catatan penyelesaian ditulis app setelah Selesai; bila gagal (offline), dashboard mencatatnya saat dibuka lagi, atau `treatment-record` (CLI); ekspor menandai `completed_unrecorded` | Sesuai desain |
| Cerita AI berbeda per siswa walau kata sama; generate ulang tidak dicatat | Keterbatasan treatment, dilaporkan di metodologi |

## 8. Langkah berikutnya

1. **Tinjau & commit instrumen v2** (pemilik): bank `assets/research/instrument_v2.json`,
   rencana `tools/research/plans/treatment_plan_t2.json`, konstanta tooling &
   app, tes, dokumen. Kunci v2 privat ada di
   `C:\Users\refah\vocably-private\instrument_v2_key.private.json` (jangan di-commit).
2. **Produksi v2.** Seed **sudah** dijalankan agen 2026-11-07 (perintah di
   bawah, dry-run → apply dengan log → re-run `unchanged`). Tersisa: **build +
   `firebase deploy --only hosting`** dari kode yang sudah di-commit (izin pemilik):

   ```powershell
   npm run admin -- seed-instrument @P                                    # dry run: 4 × create v2_*, v1_* tidak disentuh → lalu @L
   node bin/build_treatment_plan.js --check plans/treatment_plan_t2.json
   npm run admin -- seed-treatment --plan plans/treatment_plan_t2.json @P # dry run → lalu @L (ganti t1 → t2; boleh karena belum ada sesi t1)
   npm run admin -- status @P
   # lalu: flutter build web --release --dart-define=WORKER_BASE_URL=… ; firebase deploy --only hosting
   ```

   Rules **tidak** perlu di-deploy ulang (membaca `researchInstrument/{versi}_{band}`
   sesuai versi peserta).
3. **Konfirmasi status validasi formal** instrumen & K2 dari validator.
4. **Gladi teknis** di sekolah dengan cohort `pilot`/`test` (blocker 3), lalu
   bersihkan data uji (blocker 4).
5. Mulai studi (PowerShell, `tools\research`, `$P` = produksi; dry-run dulu):

   ```powershell
   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\vocably-private\service-account.json"
   $P = @("--production", "--project", "vocably-idn-en", "--confirm-project", "vocably-idn-en")
   $L = @("--apply", "--log", "C:\vocably-private\audit\admin.private.jsonl")
   npm run admin -- status @P                                       # sebelum mulai: 0 peserta
   npm run admin -- enrol --csv C:\vocably-private\peserta.csv @P   # dry run → lalu tambah @L
   npm run admin -- learning-placement --close @P                    # selama placement resmi → @L
   # Kelas: Panel → Placement → Izinkan & Buka Pre-Test → Sesi treatment 1–4 (+ susulan) → Post-Test
   npm run admin -- status @P                                       # treatment=n/4 per peserta
   npm run export:treatment -- --out-dir C:\vocably-private\export-YYYYMMDD @P
   npm run export -- export --key <instrument_key.private.json> --out-dir <folder> @P
   npm run export:placement -- --key <placement_key.private.json> --out-dir <folder> @P
   ```

   Setelah langkah 2, rencana aktif = `t2`; ubah batas susulan dengan
   `npm run admin -- seed-treatment --plan plans/treatment_plan_t2.json --makeup-days N @P @L`.
6. Setelah gladi: uji Co-Write/cerita di HP dengan Worker produksi; bila ada
   `Refused to … Content Security Policy` di Console, catat dan laporkan.
