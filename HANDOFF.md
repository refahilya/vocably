# Vocably — Handoff (status terkini)

**Satu-satunya sumber status terkini proyek.** Ditulis ulang sebagai snapshot
(bukan log) setiap kali status berubah; riwayat ada di `PROJECT_STATE.md`.
Aturan kerja dan hierarki kebenaran ada di `CLAUDE.md` §0 — kode, tes, Git,
dan bukti deploy selalu mengalahkan dokumen ini. Verifikasi ulang fakta yang
penting untuk tugasmu sebelum mengandalkannya.

**Snapshot: 2026-11-03.** Label: **[terverifikasi]** = dicek langsung pada
tanggal itu · **[dilaporkan pemilik]** = hasil yang dilaporkan pemilik proyek,
tidak direproduksi agen · **[catatan]** = tercatat di riwayat, tidak dicek
ulang hari ini.

## 1. Git

- **`vocably`** [terverifikasi 2026-11-03]: sebelum perbaikan keamanan,
  `main` = `origin/main` di `4704341` ("chore: ignore Firebase Hosting
  cache"); Panel Riset (`0c531ac`, `b8946fa`, `a025343`) dan konfigurasi
  Hosting (`17ed34c`) sudah di-commit dan di-push oleh pemilik proyek.
  Perbaikan temuan OWASP ZAP (`PROJECT_STATE.md` §5zi) di-commit dan di-push
  agen dengan izin eksplisit pemilik proyek — hash: `git log`.
- **`vocably-ai-worker`** [catatan 2026-10-28, tidak dicek ulang]: `main` di `5bcb5e4`,
  sama dengan `origin/main`. Satu-satunya perubahan lokal: origin
  `http://localhost:5000` di `wrangler.jsonc` — **khusus lokal; jangan
  di-stage, di-commit, atau di-deploy** (aturan deploy: `CLAUDE.md` §0).
  Worker **tidak** diubah untuk Placement Test maupun Panel Riset.
- **Catatan jaringan:** CA bundle OpenSSL milik Git menolak sertifikat TLS
  jaringan ini; `git -c http.sslBackend=schannel <fetch|push|ls-remote>`
  (Windows certificate store, tetap terverifikasi) berhasil per perintah tanpa
  mengubah config.

## 2. Deployment & data produksi

| Komponen | Status | Bukti |
|---|---|---|
| Flutter web (Firebase Hosting) | **Ter-hosting** di `https://vocably-idn-en.web.app` (build dengan `Last-Modified: Mon, 02 Nov 2026 17:55:05 GMT`; isi build persis tidak diverifikasi). Build itu **tanpa header keamanan** (tanpa CSP / `X-Frame-Options` / `nosniff`) — perbaikan §5zi **belum di-deploy** | `curl -I` 2026-11-03 [terverifikasi]; scan OWASP ZAP produksi 2026-11-03 (§3) |
| Cloudflare Worker | Versi `0bec79ee-2958-475e-97fe-64ababf31c9c` (deploy 2026-10-15T17:08Z UTC) dengan override `--var ALLOWED_ORIGINS`, mencakup seluruh pekerjaan Co-Write | [catatan] `wrangler deployments list` 2026-10-16 (`PROJECT_STATE.md` §5t) |
| Firestore rules | Ter-deploy ke `vocably-idn-en` pada 2026-11-02 00.52 WIB (rules riset + Placement Test). **`firestore.rules` di working tree sudah berubah sejak itu (Panel Riset) dan BELUM di-deploy** — produksi belum punya rules panel | Keluaran deploy 2026-11-02 (`PROJECT_STATE.md` §5zc); diff working tree [terverifikasi 2026-11-03] |
| Index | `firestore.indexes.json` ter-deploy 2026-11-02; tidak berubah (panel hanya memakai index otomatis satu field) | Keluaran deploy; status pembangunan index tidak dicek |
| Data produksi | 4.952 `vocabWords` + master `topics` ter-seed; **tidak ada data riset, placement, maupun operator** (`researchParticipants`/`researchInstrument`/`researchAssessmentResults`/`researchStudy`/`placement*`/`researchOperators`). Grant operator produksi **belum** dijalankan | [catatan] konsol Firebase (§5 Stage 3); tidak dicek ulang hari ini |

## 3. Hasil verifikasi terakhir

Dijalankan agen pada 2026-11-02/03 terhadap working tree di atas `49f6a7a`
setelah Panel Riset dibangun:

| Cek | Perintah | Hasil |
|---|---|---|
| Analyzer | `flutter analyze` | 0 isu |
| Tes Flutter | `flutter test --concurrency=1` | **999/999** lulus (950 sebelumnya + 49 baru: logika sel panel, paritas payload panel ⇄ fixture, layar panel, routing operator, cermin progres di controller siswa, 12 kasus responsif panel termasuk target tap) |
| Tooling riset | `cd tools/research && npm test` | **93 lulus, 3 dilewati, 0 gagal**; yang dilewati: 2 cek PDF peneliti (`sourcePdf.test.js`) dan 1 rebuild bank placement (butuh `VOCABLY_PLACEMENT_SOURCE`) |
| Emulator riset + placement + panel | `cd tools/research && npm run test:rules` | **158/158** lulus (129 sebelumnya + 24 rules panel + grant/revoke operator + enrolmen baru + cermin) |
| Build rilis | `flutter build web --release --dart-define=WORKER_BASE_URL=…` | Berhasil; bundle tanpa host/proyek emulator |
| Browser E2E (Playwright + Chrome, app debug terhadap Firestore/Auth emulator, banner "Running in emulator mode" tampil) | Lihat baris di bawah | Lulus, rincian di bawah |

**Skenario E2E yang benar-benar dijalankan [terverifikasi 2026-11-02/03]:**
1. Guru biasa (`guru@example.test`) login → hanya Target Kata + Kosakata.
2. Siswa baru daftar lewat UI → tawaran Placement → "Nanti Saja" → banner
   riset "Belum tersedia".
3. `enrol --emulator --csv` dengan **e-mail** (dry-run lalu `--apply`) →
   peserta `awaiting_placement` + roster; enrolmen ulang ditolak.
4. Operator (`peneliti@example.test`) login di jendela terpisah → tab Riset →
   panel: 6 peserta, nama dari roster.
5. Tutup ketiga tahap dari panel (konfirmasi + riwayat) → siswa melihat "Tes
   belum dibuka".
6. Buka Placement (tutup otomatis 90 menit) → siswa mengerjakan 50 butir lewat
   UI; panel menampilkan "Mengerjakan 12/50" langsung; setelah "Kirim" dinilai
   rules (A1* → band A2) dan baris panel berubah ke "Band A2" tanpa reload.
7. Izinkan Pre-Test per siswa (tombol nonaktif sampai pernyataan K2
   dicentang) → Buka Pre-Test → siswa mengerjakan lewat UI.
8. Tiga siswa lain (dummy) mengerjakan Pre-Test lewat client SDK dengan login
   Auth asli dan rules asli (payload sama dengan app) → panel memantau 4
   siswa sekaligus (8/20, 14/20, 5/20, selesai).
9. "Ulang (gangguan teknis)" untuk siswa 14/20 → percobaan 1 `voided`
   (14 jawaban utuh, dicek `status`), percobaan 2 bisa dibuat siswa.
10. Siswa menyelesaikan Pre-Test → Tutup Pre-Test → "Izinkan 2 peserta"
    Post-Test (dua centang wajib, termasuk sesi ke-4) → Buka Post-Test →
    siswa menyelesaikan Post-Test lewat UI → baris "Selesai / Selesai".
11. Panel di 390 px dan 768 px: tanpa scroll horizontal; blok per peserta di HP.
12. Penolakan server dengan login asli: 13 percobaan guru biasa/siswa
    (daftar peserta, roster, progres, jadikan diri operator, buka tahap,
    izinkan posttest, palsukan hitungan progres) → semua `permission-denied`.
13. `operator --revoke` lewat CLI saat panel terbuka → tab Riset hilang
    tanpa reload.

- **Tidak diuji:** rules panel di Firestore **produksi** (belum di-deploy),
  token asli, HP Android sungguhan, banyak HP bersamaan di jaringan sekolah,
  Worker/LLM asli (tidak tersentuh fitur ini). Worker dan `tools/vocab_import`
  tidak berubah dan tidak dijalankan ulang ([catatan] Worker 148/148
  2026-10-15/16; vocab_import 43/43 2026-10-13).
- **Kunci jawaban pretest privat:** `export_results.js validate-key` OK (80
  entri) pada 2026-10-25 [catatan]. **Kunci placement privat belum
  di-generate** di mana pun (lihat §8).
- **Artefak lokal di luar repo:** screenshot E2E dan skrip simulasi siswa di
  folder scratchpad sesi agen; `firestore-debug.log` di scratchpad `pt-spike`
  dan `pt-probe` (fase sebelumnya). Tidak berisi data nyata.

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
| **Belum:** scan ZAP produksi sesudah deploy | Menunggu deploy Hosting oleh/atas izin pemilik proyek |

## 4. Posisi fitur

- **Milestone 1–8:** selesai (riwayat `PROJECT_STATE.md` §2, §5–§5n).
- **Co-Write fase 1 + 2, CW-05, input Indonesia, CW-02:** selesai; sisi Worker
  ter-deploy, sisi Flutter belum di-hosting (§5o–§5t).
- **Pilih kata Difficult untuk "Pelajari Kembali":** selesai (§5u).
- **Modul riset Pre/Post Test:** selesai di `main` (§5v–§5y), dengan jendela
  tahap terpisah (§5za).
- **Placement Test PT-V1.1 (§5za–§5zg):** selesai di `main`, rules lama
  ter-deploy, app belum di-hosting, kunci & bank belum di-seed ke produksi.
  **K2 belum divalidasi ahli/pembimbing.**
- **Panel Riset + enrolmen tanpa band (§5zh):** selesai dan di-commit;
  status deploy rules panel tidak dicek ulang (lihat §2):
  - grant/revoke operator satu kali lewat CLI (`operator --grant/--revoke
    --email`), identitas = login guru biasa;
  - rules operator sempit + `researchAuditLog` wajib per tindakan;
  - `enrol` tanpa kolom band (`email|uid,researchId,cohort`) + roster nama;
    setiap band responden kini berasal dari Placement Test riset;
  - panel di tab "Riset": buka/tutup tiga tahap (sampai ditutup atau tutup
    otomatis 60/90/120 menit), otorisasi per siswa/massal (posttest dengan
    atestasi sesi ke-4), pantau langsung lewat cermin `researchProgress`
    (jumlah + status saja), void teknis + retake, riwayat tindakan;
  - pengalaman siswa tidak berubah (cermin progres ditulis best effort di
    belakang layar).

## 5. Blocker sebelum produksi / responden sungguhan

1. ~~Commit & push Panel Riset~~ — selesai (`0c531ac`, `b8946fa`, `a025343`
   ada di `origin/main`, [terverifikasi 2026-11-03]).
2. **Deploy rules baru** (`firebase deploy --only firestore:rules`) — tanpa
   ini panel tidak berfungsi di produksi (semua tulisan panel ditolak rules
   lama) dan app yang di-hosting akan gagal menulis cermin progres (diabaikan
   tanpa mengganggu siswa).
3. **Kunci placement privat** di-generate (`build_placement.js --key-out`, di
   luar repo & OneDrive), lalu **seed produksi**: `seed-instrument`,
   `seed-placement --key …`, `study --status active`, lalu `operator --grant`
   untuk akun peneliti — dengan service account milik peneliti dan izin
   eksplisit. Belum pernah dilakukan. Perintah persis: §8.
4. **Deploy ulang Hosting dengan header keamanan (§5zi):** build produksi
   saat ini tanpa CSP/anti-clickjacking. Build rilis lalu
   `firebase deploy --only hosting --project vocably-idn-en`, cek
   `curl -I https://vocably-idn-en.web.app/`, lalu scan ZAP ulang.
5. **Validasi ahli instrumen** (pretest/posttest dan aturan K2 placement) dan
   **pilot** pada siswa non-responden — belum.
6. **Persiapan responden (35–40 siswa):** akun siswa (daftar sendiri di app),
   daftar e-mail untuk `enrol`, data demografi; pembersihan data uji;
   prosedur ekspor data belajar — **belum ada tool-nya**.
7. Keputusan riset di §6 yang menyangkut pengambilan data.

## 6. Keputusan riset yang masih terbuka (milik peneliti)

| Keputusan | Dampak | Langkah berikutnya |
|---|---|---|
| **Validasi K2** oleh pembimbing/ahli (dipilih peneliti; belum disahkan) | Klaim validitas level & band placement; `authorize` (CLI) dan panel meminta pernyataan K2 | Catat persetujuan atau keterbatasan |
| **Band manual (D4):** bukti yang sah, band yang diizinkan, kriteria kelayakan bersyarat, perlu persetujuan protokol/pembimbing? | `assign-band` mencatat band + dasar + alasan; peserta `conditional` **tetap diblokir** dari pretest/posttest (fail closed); panel menampilkannya sebagai "Perlu tindakan peneliti" | Tetapkan kriteria; lalu buat jalur "konfirmasi kelayakan" |
| **Banding/peninjau kedua** atas keputusan peneliti | `placement-restore` hanya mengoreksi void keliru (attempt sama) | Tentukan siapa yang meninjau banding |
| Status pretest/treatment/posttest saat tinjauan `pending` | Saat ini: semua aksi riset peserta itu diblokir; data yang sudah ada tetap | Konfirmasi atau ubah |
| Batas waktu penilaian kiriman yang diterima sebelum penutupan | Saat ini tanpa batas (rules); ekspor menandai attempt `in_progress (incomplete)` | Tentukan bila perlu |
| Kebijakan email/akun peserta (siswa daftar sendiri dengan email pribadi; konfirmasi kepemilikan) | `enrol` kini menerima e-mail; kepemilikan e-mail tidak diverifikasi app | Putuskan sebelum pengambilan data |
| Teks UI placement (level saja, tanpa skor; pesan netral untuk tinjauan) | Diimplementasikan sesuai prinsip B13; teks persis belum disetujui | Review teks di `placement_test_screen.dart` |
| Teks UI Panel Riset (label status, pernyataan wajib, dialog) | Dibuat agen, belum disetujui peneliti | Review `lib/screens/teacher/research_panel/` |
| Koreksi PDF/JSON PT-V1.1 (daftar D10) | Dokumen peneliti belum direvisi; daftar di `tools/research/README.md` | Revisi `.docx`/PDF/JSON peneliti |
| B2-06 *starve*: label kata kerja, opsinya bentuk kata benda | Validitas satu butir B2 pretest | Review ahli sebelum pilot |
| Retensi / penghapusan data riset (termasuk roster nama dan log audit) | Etika & perlindungan data | Tentukan periode, pelaksana, caranya |
| Verifikasi sesi treatment ke-4 sebelum membuka posttest | Panel/CLI hanya mencatat atestasi peneliti | Tentukan bukti yang dipakai sebelum mencentang |
| Format, penyimpanan, akses ekspor | File `operational_*` berisi UID | Setujui set CSV, lokasi, daftar akses |
| Desain set kata sesi treatment (4 × 5 kata per band) dan cara penargetannya | Intervensi belum diimplementasikan | Milestone terpisah |
| Penghitung kemajuan pretest ("Butir 7/20"); kalimat contoh "book" | Pengalaman siswa / teks petunjuk | Setujui atau tolak |

## 7. Known issues & keterbatasan

| Item | Status |
|---|---|
| **Banner riset di dashboard siswa tidak memperbarui diri sendiri** saat peneliti membuka tahap atau mengizinkan siswa yang sedang berada di dashboard; banner baru benar setelah siswa membuka layar tes (yang selalu membaca server) atau kembali ke dashboard | Diamati di E2E; perilaku lama, bukan dari panel. Saat sesi kelas: minta siswa mengetuk banner / "Muat ulang" |
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
| `canvaskit.wasm` dimuat dari `www.gstatic.com`; di cache kosong pada jaringan lambat bisa puluhan detik (46 s teramati saat uji lokal) | Perilaku bawaan Flutter; opsi self-host (`--no-web-resources-cdn`) belum dievaluasi |
| Tes otomatis void percobaan pretest **selesai** belum memeriksa `responses` tetap utuh (void panel `in_progress` sudah diperiksa) | Celah tes kecil |
| Belum diverifikasi: E2E Co-Write di Chrome terhadap Worker produksi; redesain dan panel di HP Android sungguhan | Terbuka |

## 8. Langkah berikutnya

1. Deploy Hosting dengan header keamanan (§5 no. 4) dan scan ZAP produksi
   ulang; uji login/kamus/Co-Write sekali di HP sungguhan di bawah CSP.
2. Uji panel sekali lagi secara manual di emulator (checklist "Researcher
   Panel" di `tools/research/README.md`), sebaiknya juga dari HP sungguhan.
3. Keputusan peneliti di §6 (validasi K2, teks panel, kebijakan e-mail,
   retensi roster/log).
4. Produksi — hanya dengan izin eksplisit, urutan ini (PowerShell, dari root
   repo; `<project-id>` = `vocably-idn-en`; file privat di luar repo &
   OneDrive):

   ```powershell
   # a. Rules baru (panel + cermin). Tidak menulis data.
   firebase deploy --only firestore:rules --project vocably-idn-en

   # b. Kunci placement privat (sekali; jangan pernah di repo/OneDrive)
   cd tools\research
   npm run build:placement -- --source C:\path\to\placement_items_v1.0.json --key-out C:\vocably-private\placement\placement_key_pt_v1_1.private.json

   # c. Seed + studi (dry-run dulu tanpa --apply; --apply butuh --log)
   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\vocably-private\service-account.json"
   $P = @("--production", "--project", "vocably-idn-en", "--confirm-project", "vocably-idn-en")
   npm run admin -- seed-instrument @P --apply --log C:\vocably-private\audit\admin.private.jsonl
   npm run admin -- seed-placement --key C:\vocably-private\placement\placement_key_pt_v1_1.private.json @P --apply --log C:\vocably-private\audit\admin.private.jsonl
   npm run admin -- study --status active @P --apply --log C:\vocably-private\audit\admin.private.jsonl

   # d. Daftarkan akun peneliti sebagai operator (akun guru yang sudah ada)
   npm run admin -- operator --grant --email <e-mail peneliti> @P            # dry run: cek UID
   npm run admin -- operator --grant --email <e-mail peneliti> @P --apply --log C:\vocably-private\audit\admin.private.jsonl

   # e. Setelah siswa mendaftar di app: enrol dengan e-mail (CSV di luar repo)
   npm run admin -- enrol --csv C:\vocably-private\peserta.csv @P              # dry run
   npm run admin -- enrol --csv C:\vocably-private\peserta.csv @P --apply --log C:\vocably-private\audit\admin.private.jsonl

   # f. Hosting (blok "hosting" + header keamanan sudah di firebase.json, README "Deployment")
   cd ..\..
   flutter build web --release --dart-define=WORKER_BASE_URL=https://vocably-ai-worker.refahilyaa.workers.dev
   firebase deploy --only hosting --project vocably-idn-en
   ```

   Setelah itu, sesi kelas dijalankan dari tab **Riset** (buka/tutup,
   izinkan, pantau, ulang). `study --status closed` dan ekspor tetap CLI.
5. Generate kunci placement privat dan simpan cadangannya di luar repo &
   OneDrive.
6. E2E Co-Write langsung terhadap Worker produksi (lihat §7).
