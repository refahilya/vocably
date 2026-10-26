# Vocably — Handoff (status terkini)

**Satu-satunya sumber status terkini proyek.** Ditulis ulang sebagai snapshot
(bukan log) setiap kali status berubah; riwayat ada di `PROJECT_STATE.md`.
Aturan kerja dan hierarki kebenaran ada di `CLAUDE.md` §0 — kode, tes, Git,
dan bukti deploy selalu mengalahkan dokumen ini. Verifikasi ulang fakta yang
penting untuk tugasmu sebelum mengandalkannya.

**Snapshot: 2026-10-26.** Label: **[terverifikasi]** = dicek langsung pada
tanggal itu · **[dilaporkan pemilik]** = hasil yang dilaporkan pemilik proyek,
tidak direproduksi agen · **[catatan]** = tercatat di riwayat, tidak dicek
ulang hari ini.

## 1. Git

- **`vocably`** [terverifikasi 2026-10-26, termasuk `git ls-remote`]:
  branch `main` di `b120d2f` ("feat: implement research pretest and posttest
  workflow"), sama dengan `origin/main` di GitHub. Working tree bersih
  sebelum konsolidasi dokumen ini; perubahan dokumen ini belum di-commit.
- **`vocably-ai-worker`** [terverifikasi 2026-10-26]: `main` di `5bcb5e4`,
  sama dengan `origin/main`. Satu-satunya perubahan lokal: origin
  `http://localhost:5000` di `wrangler.jsonc` — **khusus lokal; jangan
  di-stage, di-commit, atau di-deploy** (aturan deploy: `CLAUDE.md` §0).
- **Catatan jaringan:** CA bundle OpenSSL milik Git menolak sertifikat TLS
  jaringan ini; `git -c http.sslBackend=schannel <fetch|push|ls-remote>`
  (Windows certificate store, tetap terverifikasi) berhasil per perintah tanpa
  mengubah config.

## 2. Deployment & data produksi

| Komponen | Status | Bukti |
|---|---|---|
| Flutter web (Firebase Hosting) | **Belum di-hosting**; `firebase.json` tidak punya blok `"hosting"` | [terverifikasi 2026-10-26] |
| Cloudflare Worker | Versi `0bec79ee-2958-475e-97fe-64ababf31c9c` (deploy 2026-10-15T17:08Z UTC) dengan override `--var ALLOWED_ORIGINS`, mencakup seluruh pekerjaan Co-Write | [catatan] `wrangler deployments list` 2026-10-16 (`PROJECT_STATE.md` §5t) |
| Firestore rules | Deploy terakhir yang tercatat: rules Milestone 7 (berisi semua rules sampai Milestone 7); **rule `targetWordSets` Milestone 8 dan seluruh rules riset belum di-deploy** | [catatan] `PROJECT_STATE.md` §5h/§5k/§5l/§5w, §6; tidak dicek ke project hari ini |
| Index | `vocabWords` `cefrLevel + updatedAt` live; status deploy index `targetWordSets` tidak tercatat | [catatan] `firebase firestore:indexes` (§5b/§6) |
| Data produksi | 4.952 `vocabWords` + master `topics` ter-seed; **tidak ada data riset** (`researchParticipants`/`researchInstrument`/`researchAssessmentResults`) | [catatan] konsol Firebase (§5 Stage 3) |

## 3. Hasil verifikasi terakhir

Dijalankan agen pada 2026-10-26 terhadap kode `b120d2f`:

| Cek | Perintah | Hasil |
|---|---|---|
| Analyzer | `flutter analyze` | 0 isu |
| Tes Flutter | `flutter test --concurrency=1` | **602/602** lulus |
| Tooling riset | `cd tools/research && npm test` | **71 lulus, 2 dilewati** (cek PDF/kunci butuh `VOCABLY_INSTRUMENT_PDF`/`VOCABLY_INSTRUMENT_KEY`) |
| Emulator riset | `cd tools/research && npm run test:rules` | **86/86** lulus (rules, tooling peneliti, 1 alur end-to-end) di emulator Firestore + Auth lokal |

- **Build rilis** `flutter build web --release --dart-define=WORKER_BASE_URL=…`:
  berhasil pada 2026-10-26 untuk kode yang sama; output tidak memuat host
  emulator, project demo, atau pemanggilan emulator.
- **Kunci jawaban privat:** `export_results.js validate-key` OK (80 entri, hash
  bank cocok) pada 2026-10-25; isi kunci tidak pernah ditampilkan.
- **Worker** [catatan 2026-10-15/16]: `npx vitest run --fileParallelism=false`
  148/148, `npx tsc --noEmit` bersih. **`tools/vocab_import`** [catatan
  2026-10-13]: `npm test` 43/43.
- **E2E manual browser modul riset** [dilaporkan pemilik, 2026-10-26]:
  seluruh checklist di `tools/research/README.md` ("Running the app against
  the emulators") lulus di emulator lokal, termasuk void percobaan yang
  **sudah selesai** dengan `--allow-completed` → otorisasi retake → percobaan 2
  dengan urutan butir/opsi baru, dan jawaban lama tetap tersimpan. Hanya
  emulator — **bukan** bukti kesiapan produksi.
- **E2E lokal CW-02** [dilaporkan pemilik, 2026-10-16]: memuaskan.

## 4. Posisi fitur

- **Milestone 1–8:** selesai (riwayat `PROJECT_STATE.md` §2, §5–§5n).
- **Co-Write fase 1 + 2, CW-05, input Indonesia, CW-02:** selesai; sisi Worker
  ter-deploy, sisi Flutter belum di-hosting (§5o–§5t).
- **Pilih kata Difficult untuk "Pelajari Kembali":** selesai (§5u).
- **Modul riset Pre/Post Test:** bank soal + pemisahan kunci (§5v), rules +
  emulator (§5w), model & perencana (§5x), penyimpanan jawaban, tooling
  peneliti, layar tes, alur emulator + uji end-to-end, serta ekspor & skoring
  offline (§5y) — semuanya sudah di `main`. **Belum pernah dijalankan ke
  produksi**; rules riset belum di-deploy.
- **Placement Test:** ditunda (metode skoring TBD) — hanya scaffold.

## 5. Blocker sebelum produksi / responden sungguhan

1. **Deploy rules dulu, baru hosting.** Rules produksi saat ini menolak baca
   `researchParticipants`; build yang memuat modul riset akan menampilkan
   "Gagal memuat" pada banner Pre-Test/Post-Test sampai rules riset
   ter-deploy. Deploy `firestore.rules` juga membawa rule Milestone 8 —
   keputusan sadar pemilik proyek.
2. **Seed produksi** `researchInstrument` lalu enrol & otorisasi peserta
   (`research_admin.js --production`), dengan service account milik peneliti
   dan izin eksplisit. Belum pernah dilakukan.
3. **Konfigurasi Firebase Hosting** (`README.md` "Deployment").
4. **Validasi ahli instrumen dan pilot** pada siswa non-responden — belum.
5. **Persiapan responden (35–40 siswa):** keputusan data demografi (kelas/NISN
   tidak ada di `users`); pembersihan data uji di `learningSessions`,
   `learningProgress`, `targetWordSets` (bank kosakata dan `topics` tetap);
   prosedur ekspor data belajar (transkrip, hasil cloze, progres mastery) —
   **belum ada tool-nya** (ekspor yang ada hanya untuk Pre/Post Test).
6. Keputusan riset di §6 yang menyangkut pengambilan data.

## 6. Keputusan riset yang masih terbuka (milik peneliti)

| Keputusan | Dampak | Langkah berikutnya |
|---|---|---|
| B2-06 *starve*: label kata kerja, opsinya bentuk kata benda | Validitas satu butir B2 (PDF §4.6: butir tidak diubah setelah data terkumpul; dianalisis dengan & tanpa) | Review ahli sebelum pilot; perubahan = build ulang bank & kunci (versi baru) |
| Retensi / penghapusan data riset | Etika & perlindungan data; belum ada job penghapusan | Tentukan periode, pelaksana, caranya |
| Verifikasi sesi treatment ke-4 sebelum membuka posttest | Validitas waktu posttest; sesi treatment belum dilacak | Tentukan bukti (mis. daftar hadir) sebelum `--confirm-session4-completed` |
| Prosedur gangguan teknis / retake | Kapan void, siapa memutuskan, apa yang dicatat | Setujui alur void → retake dan siapa yang boleh menjalankan |
| Format, penyimpanan, akses ekspor | Siapa boleh melihat file `operational_*` (berisi UID) | Setujui set CSV, lokasi, daftar akses |
| Desain set kata sesi treatment (4 × 5 kata per band) | Intervensinya belum diimplementasikan | Tentukan pembagian; milestone terpisah |
| Penghitung kemajuan ("Butir 7/20") | Pengalaman siswa; tidak ada di PDF | Setujui atau tolak |
| Kalimat penjelasan contoh "book" (orang ketiga, verbatim PDF §5) | Teks petunjuk | Konfirmasi tetap ditampilkan |

## 7. Known issues & keterbatasan

| Item | Status |
|---|---|
| Validator Co-Write heuristik tanpa data POS (komparatif hanya dalam konteks pembanding; giliran semua-target berinfleksi tanpa koma dihitung kalimat; `My mother is teacher` cocok dengan `teach`) | Diketahui, terdokumentasi |
| Deteksi bahasa Indonesia berbasis daftar kata (kalimat hanya kata isi tidak terdeteksi; penanda lemah mirip nama butuh penanda kedua) | Hanya uji unit & kontrak prompt |
| Penilaian makna CW-05 dan kualitas output LLM (feedback, kelanjutan, kalimat fallback) | Perlu uji langsung dengan model asli |
| Sisa CW-02: kontradiksi parsial tak terdeteksi; pujian untuk kata yang tidak diklaim tak tertangkap (indikator tetap amber/biru); salah eja dianggap pengingat; feedback menunggu panggilan fallback; penilaian di temperatur 0.7; 502 membuat siswa mengirim ulang giliran | Teruji lokal; perlu uji langsung |
| Setelah bot memakai kata lewat fallback, siswa tidak bisa lagi mendapat kredit mandiri untuk kata itu di sesi tersebut | Sesuai aturan |
| "Pelajari Kembali" tanpa batas jumlah kata; pilihan sangat besar bisa melampaui timeout cerita 45 dtk | Keputusan produk; tinjau bila bermasalah |
| "Coba lagi" Per Kata hanya meng-invalidate `historyWordEntriesProvider`, bukan `learningProgressListProvider` | Observasi, belum diverifikasi |
| Binding Rate Limiting native Cloudflare belum dipastikan (fallback in-memory dipakai) | Terbuka |
| Build `--wasm` gagal (`flutter_tts` memakai JS interop lama) | Pakai build JS |
| Tes otomatis void percobaan **selesai** belum memeriksa `responses` tetap utuh (kodenya hanya mengubah `status`/`voidReason`/`voidedAt`) | Celah tes kecil |
| Belum diverifikasi: E2E Co-Write di Chrome terhadap Worker produksi (termasuk perbaikan keyboard fisik); klik-manual Milestone 8; pilihan Difficult di lebar HP | Terbuka |

## 8. Langkah berikutnya

1. Review lalu commit konsolidasi dokumen ini (pemilik proyek).
2. Ambil keputusan riset di §6, terutama B2-06, retensi, dan verifikasi sesi 4.
3. E2E langsung Co-Write di Chrome dengan LLM asli terhadap Worker produksi:
   perbaikan keyboard fisik; tiga giliran tanpa kata → tepat satu kata
   fallback; feedback sesuai kalimat saat ini dengan indikator ✓/💡/💬;
   kelanjutan yang tidak mengulang siswa; saran "Coba tulis".
4. Klik-manual Milestone 8 di browser: guru Set Target Kata ("Tanpa batas
   akhir") → kartu muncul; siswa melihat target di dashboard → cerita memakai
   kata itu; guru Edit Kata (topik); tombol "Keluar" untuk guru & siswa di
   berbagai lebar.
5. Saat siap produksi (izin eksplisit): urutan di §5 — deploy rules, seed &
   enrol, hosting, lalu pilot.
6. Pastikan ketersediaan binding Rate Limiting Cloudflare.
7. Simpan cadangan privat kunci jawaban di luar repo dan OneDrive.
