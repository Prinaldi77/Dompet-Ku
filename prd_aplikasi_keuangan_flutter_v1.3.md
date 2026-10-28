# Product Requirements Document (PRD)

**Nama Proyek:** Aplikasi Manajemen Keuangan Pribadi (DompetKu)
**Package Flutter:** `dompetku`
**Platform:** Android & iOS (Flutter Framework)
**Arsitektur Penyimpanan:** Offline-First (Local Relational Database)
**Versi Dokumen:** 1.3
**Status:** Siap implementasi (semua blocker logika ledger sudah dikunci). FR-13 sudah dibangun dan terverifikasi di perangkat; FR-14 masih tahap rancangan.

---

## Riwayat Perubahan

| Versi | Tanggal | Perubahan |
| :--- | :--- | :--- |
| 1.0 | — | Draft awal PRD. |
| 1.1 | — | Penambahan Auto-Sync Saldo Utama (mode single ledger). |
| 1.2 | 2026-10-26 | Revisi hasil review: aturan read-only transaksi otomatis, pemisahan ringkasan manual vs otomatis, saldo awal, validasi lengkap, klarifikasi FK/soft reference, derived state, strategi hapus goal/hutang, indeks & skema migrasi, modul kategori, kebutuhan non-fungsional, acceptance criteria per sprint. |
| 1.3 | 2026-10-28 | Penambahan **FR-13 Kunci Aplikasi** (dokumentasi fitur yang sudah diimplementasikan + batas keamanannya) dan **FR-14 Draf Transaksi dari Notifikasi Aplikasi Bayar** (rancangan baru). "Sistem *login*" dipindah dari Out-of-Scope karena kunci aplikasi lokal sudah menjadi bagian produk; Open Banking API dan sinkronisasi *cloud* multi-perangkat tetap di luar lingkup. Ikut diperbarui: §2.1.2, §2.3.6–§2.3.7, §4.3 (V9–V13), §4.4, §5.1, §5.6–§5.7, §5.8–§5.12, §6.8–§6.11, NFR-04–NFR-07 (diamandemen) + NFR-08–NFR-11, §8, §9, §10 (Sprint 7–8), §11. Nama file dokumen ikut menyesuaikan versi konten (`v1.2.md` → `v1.3.md`). |

---

## 1. Ringkasan Proyek (Project Overview)

### 1.1 Latar Belakang & Tujuan
Membangun aplikasi *mobile* pribadi yang ringan, cepat, dan bekerja secara *offline* untuk mencatat arus kas harian (pemasukan dan pengeluaran), memantau progres target tabungan, serta mengelola pencatatan hutang dan piutang beserta riwayat cicilannya. Seluruh modul terintegrasi secara otomatis dengan **Saldo Utama** agar pengguna mengetahui jumlah uang tunai/aktif yang benar-benar bisa digunakan saat ini.

### 1.2 Lingkup Proyek (Scope)
*   **In-Scope (MVP):**
    *   Pencatatan transaksi pemasukan dan pengeluaran harian (manual).
    *   Penentuan **Saldo Awal** saat onboarding / penyesuaian saldo.
    *   Manajemen target tabungan (*Saving Goals*) yang terhubung langsung dengan pemotongan/penambahan Saldo Utama.
    *   Manajemen hutang dan piutang dengan sistem cicilan (*partial payment*) yang otomatis memperbarui Saldo Utama.
    *   Visualisasi ringkasan saldo aktif, aset tabungan, kewajiban hutang, dan **Net Worth** di halaman *Dashboard*.
    *   Manajemen kategori transaksi.
    *   **Kunci aplikasi lokal** (PIN + biometrik + auto-lock) untuk mengakses data di perangkat ini saja (FR-13).
    *   **Draf transaksi otomatis dari notifikasi aplikasi bayar** — hanya sebagai usulan yang harus dikonfirmasi pengguna (FR-14).
*   **Out-of-Scope (Versi 1.0):**
    *   Integrasi mutasi bank otomatis (*Open Banking API*). FR-14 **bukan** pengecualian aturan ini: FR-14 hanya membaca notifikasi lokal milik pengguna, tidak menghubungi server bank apa pun.
    *   Autentikasi berbasis akun/server, *login* email atau sosial, pemulihan kredensial dari *cloud*. Yang ada hanyalah kunci aplikasi di perangkat (FR-13): tidak ada akun, dan tidak ada cara memulihkan PIN selain mereset aplikasi (§6.9).
    *   Sinkronisasi *cloud* multi-perangkat.
    *   Multi-mata uang.

---

## 2. Aturan Bisnis & Integrasi Saldo Otomatis (Auto-Deduct Logic)

Inti aplikasi ini adalah **Sistem Buku Besar Tunggal (*Single Ledger System*)**: Saldo Utama adalah hasil penjumlahan seluruh baris pada tabel `transactions`. Modul Tabungan dan Hutang/Piutang **tidak pernah mengubah saldo secara langsung**; mereka hanya membuat/menghapus transaksi otomatis yang bermata dua (*linked*) dengan log sumbernya. Fitur baru apa pun (FR-13, FR-14, dan seterusnya) **tidak boleh** menambah jalur tulis ke tabel yang memengaruhi saldo — satu-satunya jalur tulis tetap `LedgerService` (§8).

### 2.1 Tabel Efek Aksi

#### 2.1.1 Aksi modul lama (FR-01…FR-12)

| Aksi Pengguna pada Modul | Efek pada Modul Terkait | Efek Otomatis pada Saldo Utama | Kategori Transaksi Otomatis |
| :--- | :--- | :--- | :--- |
| **Setor ke Tabungan (*Top-up*)** | `saving_logs` DEPOSIT baru; saldo goal bertambah (`+`) | **Berkurang (`-`)** | `SAVING_DEPOSIT` (tipe `EXPENSE`) |
| **Tarik dari Tabungan (*Withdraw*)** | `saving_logs` WITHDRAW baru; saldo goal berkurang (`-`) | **Bertambah (`+`)** | `SAVING_WITHDRAW` (tipe `INCOME`) |
| **Mencatat Hutang Baru** *(kita meminjam)* | Record `debts` PAYABLE baru | **Bertambah (`+`)** *hanya jika* "uang diterima di dompet" dicentang (default: ya) | `DEBT_DISBURSEMENT` (tipe `INCOME`) |
| **Bayar / Cicil Hutang** | `debt_payments` baru; sisa hutang berkurang (`-`) | **Berkurang (`-`)** | `DEBT_PAYMENT` (tipe `EXPENSE`) |
| **Mencatat Piutang Baru** *(orang meminjam ke kita)* | Record `debts` RECEIVABLE baru | **Berkurang (`-`)** — uang pasti keluar saat kita meminjamkan | `RECEIVABLE_DISBURSEMENT` (tipe `EXPENSE`) |
| **Terima Cicilan Piutang** | `debt_payments` baru; sisa piutang berkurang (`-`) | **Bertambah (`+`)** | `RECEIVABLE_REPAYMENT` (tipe `INCOME`) |
| **Saldo Awal / Penyesuaian** | — | Naik/turun sesuai nominal yang diinput | `INITIAL_BALANCE` / `ADJUSTMENT` |

#### 2.1.2 Efek Aksi FR-14 (Draf dari Notifikasi)

| Aksi pada Modul Deteksi | Efek pada `transaction_drafts` | Efek pada Saldo Utama |
| :--- | :--- | :--- |
| Notifikasi aplikasi bayar tertangkap & ter-parse | Baris baru `status='PENDING'` | **Tidak ada** |
| Notifikasi sama datang lagi (re-post, sinkronisasi, beberapa aplikasi) | Ditolak oleh UNIQUE(`dedup_key`) — tidak ada baris baru | **Tidak ada** |
| Parse gagal / nominal tidak valid / arah tidak dikenali | Tidak ada baris; hanya `draft_parse_stats.skipped` (§5.11) yang bertambah | **Tidak ada** |
| Pengguna menekan **Terima** | Baris → `status='ACCEPTED'` + `accepted_log_id` terisi; transaksi `MANUAL` dibuat lewat `LedgerService.confirmDraftTransaction` (satu `db.transaction()`) | **Berubah**, persis seperti transaksi manual biasa (tipe INCOME/EXPENSE sesuai `direction`) |
| Pengguna menekan **Abaikan** | Baris → `status='DISMISSED'` | **Tidak ada** |
| Draf ditampilkan padahal ada transaksi manual mirip | ditandai `likely_duplicate` — **dihitung saat query** (§4.4.3), bukan kolom | **Tidak ada** |
| Masa tunggu draf berakhir (§3.2.6) | Baris → `status='EXPIRED'` | **Tidak ada** |
| Hapus draf (`deleteDraft`) — sah hanya untuk `PENDING`/`DISMISSED`/`EXPIRED` | Baris terhapus. Draf `ACCEPTED` **tidak dapat** dihapus fisiknya, supaya jejak saldo di `draft_acceptance_log` (§5.10) tidak hilang | **Tidak ada** |
| Hapus transaksi hasil draf dari layar Transaksi | Transaksi `MANUAL` terhapus (jalur FR-02 biasa); baris draf menjadi `status='VOIDED'` | **Pulih** (transaksi manual boleh dihapus) |

Ringkasnya: **tidak ada satu pun aksi deteksi yang mengubah Saldo Utama selain "Terima"**, dan "Terima" hanya menulis lewat `LedgerService`.

### 2.2 Aturan Pencatatan Hutang Baru (Klarifikasi vs v1.1)
Pada v1.1 efek saldo untuk "Mencatat Hutang Baru" bersifat *"opsional"* — aturan tersebut **dihapus dan diganti** menjadi:

* Saat form pembuatan hutang PAYABLE, tersedia checkbox **"Uang pinjaman diterima di dompet?"** (default **centang**).
* Jika dicentang: dibuat transaksi `INCOME` kategori `DEBT_DISBURSEMENT` dan di-link ke `debts.initial_transaction_id`.
* Jika tidak dicentang (misal hutang lama yang sudah terpakai sebelum aplikasi dipakai): **tidak ada transaksi**, `initial_transaction_id = NULL`. Saldo Utama tidak berubah, dan ini benar secara akuntansi karena uang memang tidak masuk dompet.
* Piutang (RECEIVABLE) tidak punya checkbox: uang **selalu** keluar, jadi transaksi `EXPENSE` selalu dibuat.

### 2.3 Prinsip Integritas Ledger

1.  **Setiap aksi ledger adalah satu `db.transaction()` Drift.** Isinya dapat mencakup: insert/update log module + insert/update/delete transaksi + update derived cache. Jika satu langkah gagal, seluruh aksi di-*rollback* — saldo tidak pernah timpang.
2.  **Transaksi otomatis bersifat read-only di layar Arus Kas.** Baris dengan `reference_type IN ('SAVING','DEBT')` tidak dapat diedit/dihapus dari daftar transaksi (ikon edit/hapus disembunyikan; percobaan dari API layer ditolak dengan error `ProtectedTransaction`). Perubahan dilakukan dari modul sumber (Tabungan/Hutang), yang akan memperbarui log **dan** transaksi terkaitnya dalam satu database transaction.
3.  **Derived state adalah cache, bukan sumber kebenaran.** `savings_goals.current_amount` selalu dihitung ulang sebagai Σ(`saving_logs`) dan `debts.paid_amount` sebagai Σ(`debt_payments`), dihitung **di dalam** database transaction yang sama saat log berubah. Kolom di tabel master hanya mirror untuk performa; service tidak boleh menerima penulisan langsung ke kolom tersebut.
4.  **Satu log = satu transaksi.** Relasi 1:1 antara (`saving_logs` ↔ `transactions`) dan (`debt_payments` ↔ `transactions`) dijaga oleh service layer; `transactions.reference_type + reference_id` adalah *soft reference* polimorfik (lihat §5.4).
5.  **Perubahan nominal selalu asimetris terhadap saldo.** Deleting/mengurangi setoran tabungan mengembalikan uang ke Saldo Utama; menambah setoran memotongnya. Tidak ada jalur lain yang mengubah Saldo Utama.
6.  **Draf hasil deteksi notifikasi (FR-14) bukan transaksi.** Selama statusnya masih `'PENDING'`, barisnya hidup di tabel `transaction_drafts` dan **tidak muncul** di `transactions`, tidak di arus kas, tidak di dashboard, tidak di Net Worth. Saat pengguna menekan **Terima**, baris `transactions` yang tercipta adalah transaksi **`MANUAL`** (`reference_type = NULL`, §5.1) dengan `source = 'NOTIFICATION'` sebagai penanda asalnya. Berkat itu seluruh aturan lama tetap berlaku tanpa di-*patch*: ringkasan manual FR-01c ikut menghitungnya, ia boleh diedit dan dihapus seperti transaksi manual lain (FR-02), dan jumlah saldo tidak pernah berubah dua kali untuk satu pembayaran.
7.  **Kunci aplikasi (FR-13) tidak menyentuh ledger.** Ia hanya gerbang UI di atas lapisan penyimpanan. Membuka, memindahkan, atau menghapus berkas basis data tidak pernah mengubah Saldo Utama, dan layar kunci tidak pernah menulis ke tabel apa pun.

---

## 3. Kebutuhan Fungsional (Functional Requirements)

| ID | Modul | Nama Fitur | Deskripsi Fitur | Prioritas |
| :--- | :--- | :--- | :--- | :--- |
| **FR-01** | Dashboard | Ringkasan Finansial Terpadu | Menampilkan: (a) **Saldo Utama Aktif**, (b) **Net Worth**, (c) **Ringkasan bulan berjalan yang hanya menghitung transaksi `reference_type = 'MANUAL'`** (Total Pemasukan vs Total Pengeluaran, agar flow pindah-pos tidak terhitung ganda), (d) kartu terpisah "Alokasi Tabungan bulan ini" dan "Cicilan dibayar bulan ini" (dari transaksi otomatis), (e) Total uang di tabungan, (f) pengingat jatuh tempo **hutang DAN piutang** ≤ 7 hari. | P0 |
| **FR-02** | Arus Kas | CRUD Transaksi Reguler | Tambah/ubah/hapus pemasukan dan pengeluaran **manual** beserta judul, nominal, kategori (dari daftar kategori), tanggal, dan catatan. | P0 |
| **FR-03** | Arus Kas | Filter & Riwayat Terintegrasi | Daftar kronologis seluruh transaksi (manual + otomatis). Transaksi otomatis menampilkan badge sumber dan **tidak dapat** diedit/dihapus dari layar ini (lihat §2.3.2). Filter: bulan, tipe (income/expense), sumber (manual/tabungan/hutang), kategori. | P1 |
| **FR-04** | Tabungan | Manajemen Target (*Goals*) | CRUD pos tabungan: nama target, nominal target, tenggat waktu. Progress = Σ log / target (lihat §2.3.3). Status `is_completed` otomatis `true` saat terkumpul ≥ target, otomatis `false` lagi jika turun di bawah target akibat penarikan/hapus log. | P0 |
| **FR-05** | Tabungan | Setor & Tarik Otomatis | Setor → potong Saldo Utama; tarik → kembalikan ke Saldo Utama; dalam satu `db.transaction()`. Bottom sheet menampilkan available saldo sebelum konfirmasi. Menghapus riwayat setoran/tarikan dari layar detail goal = menghapus log + transaksi terkait (saldo pulih). | P0 |
| **FR-06** | Hutang/Piutang | Pencatatan Hutang & Piutang | Membuat PAYABLE (dengan checkbox §2.2) atau RECEIVABLE (selalu buat transaksi keluar). Menampilkan sisa kewajiban = `total_amount − Σ debt_payments`. | P0 |
| **FR-07** | Hutang/Piutang | Cicilan & Pelunasan Otomatis | Setiap pembayaran/terima cicilan membuat transaksi otomatis (§2.1). Status `is_settled` otomatis `true` saat Σ cicilan ≥ `total_amount`, dan otomatis `false` lagi jika cicilan dihapus/dikurangi. Riwayat cicilan dapat dihapus dari detail hutang (log + transaksi terhapus dalam satu transaction). | P0 |
| **FR-08** | Validasi | Proteksi Saldo & Nominal | *Warning dialog* (boleh dibatalkan, tidak ada bypass senyap) apabila: (a) setor tabungan > Saldo Utama; (b) bayar/angsur hutang PAYABLE > Saldo Utama; (c) tarik tabungan > saldo goal saat ini; (d) cicilan > sisa hutang/piutang; (e) nominal ≤ 0. Detail di §4.3. | P1 |
| **FR-09** | Onboarding | Saldo Awal | Saat DB masih kosong (belum ada transaksi manual maupun otomatis), wizard meminta **Saldo Awal** → dibuat transaksi `MANUAL` `INCOME` kategori `INITIAL_BALANCE`. Setelah itu tersedia menu "Penyesuaian Saldo" di profil/pengaturan untuk koreksi (transaksi `ADJUSTMENT`, income/expense). | P0 |
| **FR-10** | Kategori | Manajemen Kategori | CRUD kategori (nama, ikon, tipe: `INCOME`/`EXPENSE`/`BOTH`, flag `is_system`). Kategori sistem (`INITIAL_BALANCE`, `ADJUSTMENT`, dan seluruh kategori otomatis §2.1) tidak dapat dihapus/dinamai ulang sembarangan — hanya dapat dinonaktifkan. Kategori manual yang sudah dipakai transaksi tidak dapat dihapus; gunakan arsip/nonaktifkan. Seed default: Makanan, Transportasi, Belanja, Tagihan, Hiburan, GAJI, Lainnya. | P1 |
| **FR-11** | Data | Backup & Restore | Ekspor seluruh basis data ke file `.sqlite` cadangan (simpan via *file picker/share sheet*), dan impor/pulihkan dari file tersebut. Karena aplikasi single-device tanpa cloud, ini adalah satu-satunya perlindungan kehilangan data (lihat §7 NFR-04). | P1 |
| **FR-12** | Dashboard | Grafik Pengeluaran | *Pie chart* pengeluaran manual bulan berjalan per kategori + baris pembanding alokasi otomatis (tabungan & cicilan) sebagai porsi terpisah, bukan dicampur ke "pengeluaran". | P2 |
| **FR-13** | Keamanan | Kunci Aplikasi Lokal | Mengunci seluruh aplikasi di balik PIN 4–6 angka (disimpan sebagai hash PBKDF2-HMAC-SHA256, §3.1), dengan biometrik perangkat (sidik jari / Face ID) sebagai pembuka cepat opsional dan auto-lock 30 detik saat aplikasi kembali dari latar. **Sudah diimplementasikan** — bagian ini mendokumentasikan keputusan yang sudah berjalan agar tidak di-*refactor* sembarangan. Rincian: §3.1. | P0 |
| **FR-14** | Deteksi | Draf Transaksi dari Notifikasi Aplikasi Bayar | Membaca notifikasi aplikasi pembayaran yang **diizinkan pengguna**, mengekstrak nominal + arah dana + merchant, lalu menyajikannya sebagai **draf** di Inbox. Saldo Utama **tidak pernah** berubah sampai pengguna menekan **Terima** di layar konfirmasi (§2.1.2, §2.3.6). Android saja; tanpa jaringan; parser dapat dimatikan per aplikasi. Rincian: §3.2. | P2 |

### 3.1 Rincian FR-13 — Kunci Aplikasi Lokal

**Status: sudah diimplementasikan dan terverifikasi di perangkat** (`lib/core/security/`, `lib/features/lock/`). Bagian ini menjadi rujukan bila fitur ini disentuh lagi; nilainya sengaja didokumentasikan persis seperti implementasi, bukan seperti niat awal.

#### 3.1.1 Parameter yang terkunci

| Aspek | Nilai | Implementasi / catatan |
| :--- | :--- | :--- |
| Panjang PIN | 4–6 angka | `pinLengthMin`, `pinLengthMax` pada `lib/core/security/pin_hash.dart` |
| PIN ditolak bila | seluruh digit sama (`1111`), urutan naik/turun (`1234`, `9876`), ada non-angka, panjang di luar rentang | `pinValidationError()` mengembalikan pesan Bahasa Indonesia; kosong = valid |
| Derivasi kunci | PBKDF2-HMAC-SHA256 (RFC 2898), **30.000 iterasi**, turunan **32 byte** | Konstanta `pinIterations`, `pinKeyLength`. Ditulis tangan di atas `package:crypto` agar hasilnya identik di Android dan iOS. |
| Salt | 16 byte acak kuat (`Random.secure()`), base64, dibuat ulang setiap ganti PIN | `generatePinSalt()` |
| Perbandingan hash | *constant-time* | `_constantEquals()`, bukan `==` |
| Eksekusi hash | Di isolate (`Isolate.run`) | 30.000 iterasi HMAC di thread UI akan menjegal cold start (NFR-01) |
| Penyimpanan kredensial | `SharedPreferences`: `app_lock_enabled`, `app_lock_pin_salt`, `app_lock_pin_hash`, biometrik flag | Alasan §3.1.2; **bukan** kolom SQLite, **bukan** Android Keystore |
| Auto-lock | Latar > **30 detik** → terkunci; cold start selalu mulai terkunci | `appLockTimeout` |
| Percobaan gagal | **5×** PIN salah → cooldown **60 detik**, sisa percobaan ditampilkan | `appLockMaxAttempts`, `appLockCooldown` |
| Biometrik | Default **mati**, diaktifkan eksplisit; `biometricOnly: true` (PIN perangkat tidak dijadikan fallback) | `local_auth` + `MainActivity : FlutterFragmentActivity`; iOS `NSFaceIDUsageDescription` sudah dideklarasikan |
| Status biometrik | Diperbarui saat controller dibuat **dan** setiap `notifyResumed()` | Sidik jari bisa didaftarkan/dihapus dari pengaturan sistem saat aplikasi di latar; tanpa refresh, tombol "Sidik jari" bisa basi |
| Bypass | Tidak ada | Redirect `go_router` → `lockPath = '/lock'` dengan `refreshListenable`, `PopScope(canPop: false)`, dan `LockPage` benar-benar di-*dispose* saat terbuka (dashboard tidak dirender selama terkunci) |
| Reset | "Lupa PIN? Reset aplikasi" → hapus kredensial **dan** seluruh data; dikonfirmasi dua langkah | Konsekuensi §6.9 |

#### 3.1.2 Mengapa kredensial di `SharedPreferences` (dan jangan dipindah)

Ini keputusan sadar, bukan utang teknis:

1. **Restore backup FR-11 tidak boleh membuat pengguna terkunci.** Bila hash dibungkus kunci Android Keystore yang terikat perangkat, restore file `.sqlite` di HP baru akan membuka data tapi tidak bisa dibuka aplikasinya. Kredensial yang hanya berupa hash + salt bisa ikut dipulihkan atau di-reset tanpa merusak data.
2. **Tidak ada yang perlu di-*decrypt*.** Kita tidak pernah menyimpan PIN, hanya hash. Menempatkannya di Keystore tidak menambah rahasia apa pun.
3. **Konsisten dengan filosofi produk** (§1.2): tanpa akun, tanpa server, tanpa pemulihan kredensial.

Konsekuensi yang diterima (didokumentasikan, tidak "diperbaiki"): `allowBackup = true` membuat nilai `SharedPreferences` — jadi juga hash PIN — ikut terbawa backup ADB/*cloud backup* perangkat. Yang dilindungi FR-13 adalah **akses UI di perangkat ini**, bukan berkasnya. Lihat §3.1.4.

#### 3.1.3 Alur

1. **Cold start** → `main()` membaca konfigurasi kunci, `DompetKuApp` mulai dalam keadaan terkunci → `/lock`; dashboard tidak dibangun.
2. **Layar kunci**: judul "DompetKu terkunci", keypad PIN dengan input ter-mask, tombol **Sidik jari** (hanya tampil bila status biometrik `available`), teks bantu, dan tautan "Lupa PIN? Reset aplikasi".
3. **Unlock** berhasil → `/lock` ditutup, `LockPage` di-*dispose* (angka PIN tidak tertinggal), pengguna mendarat di tab terakhir.
4. **Aplikasi masuk latar** → waktu dicatat **sekali**. Android mengirim `AppLifecycleState.hidden` lagi sesaat sebelum `resumed`; bila waktu ini ditimpa, auto-lock tidak pernah memicu (regresi nyata — lihat §3.1.5).
5. **`resumed`** → bila selisih waktu > 30 detik, kunci lagi; status biometrik ikut di-*refresh*.
6. **Pengaturan → Keamanan** → aktifkan/nonaktifkan PIN (butuh PIN lama saat mengubah/mematikan), aktifkan/nonaktifkan biometrik, tile menampilkan status ("PIN aktif", "PIN + sidik jari aktif · auto-lock 30 detik").

#### 3.1.4 Batas keamanan yang harus diketahui pengguna (tampilkan di UI)

* PIN **bukan enkripsi**. Berkas `.sqlite` dan file cadangan FR-11 tetap teks terbuka; siapa pun yang bisa membaca berkasnya bisa membuka datanya tanpa PIN.
* Kunci melindungi dari **akses kasual** (HP di tangan orang lain yang tidak tahu PIN), bukan dari forensik, root, atau *backup* yang dicuri.
* Biometrik memakai kunci sistem perangkat: menambah/menghapus sidik jari di pengaturan dapat mengubah akses — statusnya dibaca ulang setiap resume (§3.1.1).
* Saran nyata: simpan file backup di tempat yang sudah dilindungi, dan gunakan PIN yang tidak tertebak orang di sekitar pengguna.

#### 3.1.5 Acceptance criteria FR-13 (terpenuhi di build saat ini)

* Cold start dengan kunci aktif → layar kunci tampil dan `DashboardPage` tidak ada di tree (assert `find.byType(LockPage), findsOneWidget` + `find.byType(DashboardPage), findsNothing`).
* PIN benar → dashboard; PIN salah → pesan + hitungan sisa; 5× salah → cooldown 60 detik dan input terkunci.
* Latar 45 detik → resume → layar kunci muncul (dengan BiometricPrompt otomatis). Latar 12 detik → resume → tetap terbuka (tidak ada kunci palsu).
* Sidik jari: tempel valid → terbuka; tempel tidak dikenal → "Sidik jari tidak dikenali. Gunakan PIN."
* `LockPage` ter-*dispose* setelah terbuka, jadi digit PIN lama tidak tertinggal saat terkunci ulang.
* Regression test khusus urutan lifecycle Android: `hidden → paused → (45 dtk) → hidden → resumed` **wajib** menghasilkan keadaan terkunci.
* **Belum diverifikasi:** jalur iOS (Face ID) — sudah dikonfigurasi, belum pernah diuji di simulator. Masuk sisa AC Sprint 7 (§10).

### 3.2 Rincian FR-14 — Draf Transaksi dari Notifikasi Aplikasi Bayar

**Status: rancangan, belum diimplementasikan.** Prioritas P2 — dibangun hanya setelah FR-01…FR-12 stabil, karena ia menambah permukaan izin dan parser yang rapuh.

#### 3.2.1 Masalah & tujuan

Semua pencatatan hari ini manual (FR-02): setiap kali pengguna membayar dengan QRIS lewat DANA/GoPay/OVO/ShopeePay, atau menerima transfer, ia harus mengetik judul, nominal, kategori, dan tanggal — padahal notifikasi aplikasi itu sudah memuat nominal dan merchant. **Tujuan FR-14 hanyalah menghilangkan ketikan, bukan mengambil keputusan.** Pengguna tetap satu-satunya yang menulis ledger (§2.3.5 tetap berlaku).

#### 3.2.2 Prinsip keras (tidak dapat dinegosiasikan)

1. Tidak ada penulisan otomatis ke `transactions` dalam bentuk apa pun. **Hanya** tombol **Terima** yang menulis, lewat `LedgerService.confirmDraftTransaction`.
2. Draf disimpan di tabel terpisah (`transaction_drafts`, §5.9). Selama masih draf, ia tidak terlihat oleh query saldo/dashboard/arus kas mana pun.
3. Tidak ada lalu lintas jaringan. Aplikasi tidak mendeklarasikan izin `INTERNET` dan tidak boleh menambahkannya untuk fitur ini (NFR-09).
4. Teks notifikasi mentah **tidak disimpan** secara default. Yang disimpan hanya field terstruktur hasil parse (§5.9).
5. Fitur ini **mati secara anggun**: izin belum diberikan / dicabut → deteksi nonaktif, seluruh fitur lain tetap berjalan, dan UI memberi tahu cara mengaktifkannya.
6. Saat aplikasi **terkunci** (FR-13) tidak ada draf yang dibuat; notifikasi yang lewat pada periode itu di-*replay* ke antrean parsing hanya setelah terbuka, dan sisanya hilang (§3.2.6).

#### 3.2.3 Alur data

1. **Izin.** Pengguna menekan "Aktifkan deteksi" di Pengaturan → aplikasi memanggil intent `Settings.ACTION_NOTIFICATION_ACCESS_SETTINGS` (ekstra `:settings:fragment_args_key` = paket sendiri agar daftar langsung tersorot). Android meminta pengguna menyetujui "Akses notifikasi" — izin sistem yang **tidak bisa** diminta lewat *runtime permission API*. Status aktif dibaca dari `Settings.Secure.ENABLED_NOTIFICATION_LISTENERS` (API `NotificationManager.getEnabledNotificationListeners()`) dan diperiksa ulang setiap `notifyResumed()`; aplikasi menampilkan salah satu dari: `belum diizinkan`, `aktif`, `dicabut`.
2. **Listener.** `DompetkuNotificationListener extends NotificationListenerService` mendeklarasikan `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE` di *service* -nya (bukan hanya di `<manifest>`) — tanpa itu sistem tidak pernah meng-*bind*.
3. **Saring paket.** Hanya notifikasi dari paket yang **dicentang pengguna** di §3.2.8 yang diproses. Defaultnya kosong; paket lain dibuang tanpa dibaca lebih jauh.
4. **Parse.** Aturan per-paket (§3.2.4) mengekstrak `direction`, `amount`, `merchant`, dan memakai `postTime` notifikasi sebagai tanggal. Gagal → dibuang, hanya counter `skipped` yang bertambah.
5. **Dedup.** Hash kunci dedup (`dedup_key`, §5.9) dicegah oleh UNIQUE index; notifikasi yang sama datang dua kali hanya jadi satu draf.
6. **Persist.** Insert `transaction_drafts` dengan `status='PENDING'`, `source_package` = paket asal, `confidence='HIGH'` (atau `'AMBIGUOUS'` bila arah tidak pasti, §3.2.4).
7. **Notifikasi ke pengguna.** Badge jumlah draf `PENDING` di tab Transaksi + kartu "N draf menunggu" di Dashboard (tap → Inbox). **Tidak ada system notification sendiri** dari DompetKu (menghindari loop dan kebisingan).
8. **Konfirmasi.** Di Inbox, pengguna membuka draf → layar konfirmasi (§3.2.9) → **Terima** / **Abaikan**. **Terima** = satu `db.transaction()` yang: validasi §4.3 → insert `transactions` (`reference_type = NULL`, `source='NOTIFICATION'`) → update draf `status='ACCEPTED'` + `accepted_log_id` → insert `draft_acceptance_log` (§5.10).

#### 3.2.4 Kontrak parser (aturan deteksi)

* **Bentuk aturan:** satu *rule pack* per aplikasi, berisi (a) *gate regex* untuk mengenali notifikasi transaksi, (b) *capture group* nominal, (c) *capture group* merchant, (d) logika arah. Rule pack disimpan sebagai konstanta Dart bertipe + **versi aturan** (`rule_version`) di kolom §5.9, supaya draf lama bisa dilacak dibuat oleh aturan mana.
* **Wajib diuji dengan fixture, bukan dengan asumsi.** Format teks notifikasi DANA/OVO/GoPay/ShopeePay/BCA **berubah mengikuti rilis aplikasi mereka dan tidak dijanjikan stabil**. Sebelum menulis regex, tangkap sampel nyata dari perangkat pengguna (`adb shell dumpsys notification --noredact` atau ekspor manual) dan simpan sebagai fixture. Setiap rule pack punya fixture sendiri; fixture yang gagal parse = build gagal.
* **Nominal:** buang `Rp`, spasi, dan pemisah ribuan titik (`Rp 1.250.000` → `1250000`). Hanya terima angka yang berada **dalam 12 karakter setelah** token `Rp`/`IDR` — ini yang mencegah nomor telepon, nomor referensi, atau tanggal ikut terbaca. Ada desimal (`Rp 15.000,00`) → ambil bagian bulatnya. Di luar rentang §4.2 (0 < nominal ≤ 1 triliun) → buang.
* **Arah:** kamus kata kunci IN (`dana masuk`, `uang masuk`, `top up berhasil`, `penambahan saldo`, `transfer diterima`, `refund`, `dana dikembalikan`) dan OUT (`berhasil bayar`, `pembayaran`, `belanja`, `bayar`, `QRIS`, `transfer keluar`, `tarik saldo`). Tidak cocok salah satu → `confidence='AMBIGUOUS'` dan layar konfirmasi **memaksa pengguna memilih arah** sebelum tombol Terima aktif (V13).
* **Merchant:** grup setelah kata `di`/`ke`/`untuk`; dipotong 60 karakter; kosong → pakai `title` notifikasi; masih kosong → `merchant` NULL dan UI menampilkan "Tidak dikenali".
* **Waktu:** pakai `postTime` notifikasi, **bukan** `DateTime.now()` saat parse (listener bisa telat diproses). Zona waktu perangkat → epoch millis UTC (§4.2).
* **Kategori usulan:** hanya dari tabel kata-kunci → `category_id` milik pengguna (mis. mengandung "ALFAMART"/"INDOMARET" → kategori Belanja), selain itu default kategori `Lainnya`. Kategori yang diusulkan harus cocok dengan `tipe` transaksi (§5.6); tidak cocok → jangan usulkan apa pun.
* **Parser tidak boleh melempar.** Semua regex dibungkus `try`; kegagalan berarti "buang draf ini", bukan crash listener.

#### 3.2.5 Mesin status draf

| Status | Artinya | Transisi |
| :--- | :--- | :--- |
| `PENDING` | Menunggu keputusan; belum berdampak ke ledger | → `ACCEPTED` (Terima), `DISMISSED` (Abaikan), `EXPIRED` (§3.2.6), terhapus (hapus) |
| `ACCEPTED` | Sudah menjadi transaksi manual | → `VOIDED` bila transaksi hasil draf dihapus dari layar Transaksi |
| `DISMISSED` | Pengguna menolak draf | terminal; barisnya tetap ada di "Riwayat draf" (§3.2.8) |
| `EXPIRED` | `PENDING` lebih dari 30 hari | terminal |
| `VOIDED` | Transaksi hasil draf sudah dihapus, jadi draf tidak lagi mewakili apa pun | terminal |

Tombol **Undo** di snackbar setelah "Terima"/"Abaikan" berlaku 5 detik; implementasinya satu `db.transaction()` pembatalan (§4.4.6), bukan penanda `undone` di skema.

#### 3.2.6 Kelangsungan, batas teknis, dan anti-hilang

* `NotificationListenerService` hanya menerima notifikasi yang **datang setelah** *service* ter-*bind*. Notifikasi yang terbit sebelum izin diberikan atau sebelum HP dinyalakan **tidak dapat dibaca** — tidak ada riwayat. UI harus jujur: "DompetKu hanya menangkap pembayaran yang muncul setelah fitur ini diaktifkan."
* Beberapa vendor (Xiaomi/Huawei/Samsung mode hemat baterai) membunuh *service* saat aplikasi di-*swipe away*. Mitigasi: tampilkan status "deteksi tidak aktif" bila daftar listener aktif tidak memuat paket kami, dan periksa saat `notifyResumed()` (hook yang sama dengan FR-13).
* **Snapshot, bukan streaming.** Karena draf hanya dibuat saat notifikasi muncul, pembayaran yang notifikasinya lewat saat aplikasi belum terpasang/terkunci tidak akan pernah muncul. Untuk itu jalur manual FR-02 tetap wajib ada dan tidak boleh di-*deprecate*.
* Draf `PENDING` lebih dari **30 hari** → `EXPIRED` (dibersihkan otomatis lewat query saat aplikasi dibuka, bukan lewat *worker* berjadwal — tidak ada izin `SCHEDULE_EXACT_ALARM`).
* Kapasitas: maksimal **500** baris draf (semua status). Bila penuh, `EXPIRED`/`DISMISSED` tertua dihapus lebih dulu; draf `PENDING` tidak pernah dihapus diam-diam. Tujuannya menjaga ukuran file backup FR-11 tetap kecil (§6.11).

#### 3.2.7 Privasi & keamanan data notifikasi (NFR-09)

* Izin "Akses notifikasi" adalah izin sensitif: DompetKu melihat **semua** notifikasi perangkat, bukan hanya aplikasi bayar. Karena itu: (a) pemrosesan dilakukan di memori, (b) hanya paket yang dicentang yang dikirim ke parser, (c) konten notifikasi dari paket lain tidak dibaca, tidak di-*log*, dan tidak ditulis ke disk.
* Tidak ada `raw_snapshot` di produksi. Kolomnya ada di §5.9 **hanya** untuk mode diagnostik eksplisit (debug build, dan pengguna harus menyalakan sendiri).
* Tidak ada analitik, tidak ada *crash reporting* pihak ketiga yang ikut membawa teks notifikasi.
* Bila pengguna melepas izin di pengaturan: listener berhenti, Inbox tetap bisa dipakai (draf lama masih ada), dan Pengaturan menampilkan tombol "Buka pengaturan".

#### 3.2.8 UI

1. **Pengaturan → Deteksi Pembayaran**: status izin, *switch* master, daftar aplikasi yang boleh dibaca (hanya paket yang terpasang dan punya rule pack), tombol "Buka pengaturan izin", statistik (`terdeteksi`, `dibuat`, `dilewati`) dari §5.11, dan penjelasan §3.2.6 butir pertama.
2. **Inbox Draf** (tab Transaksi, segmen "Draf"): daftar draf `PENDING` kronologis terbalik; baris berisi arah (ikon ↑ masuk / ↓ keluar), merchant, nominal, waktu, chip sumber (`DANA`), dan `confidence='AMBIGUOUS'` → chip peringatan "arah tidak pasti". Aksi geser: Terima / Abaikan.
3. **Layar konfirmasi draf** (§3.2.9): judul, tipe (wajib dipilih bila AMBIGUOUS), nominal **dapat diedit** (nominal notifikasi tidak selalu sama dengan uang yang benar-benar keluar — mis. promo/cashback), kategori (usulan §3.2.4), tanggal (default `postTime`), catatan. Ringkasan dampak: "Saldo Utama akan berkurang Rp 15.000 → Rp 385.000". Tombol **Terima** disabled sampai arah valid.
4. **Badge** jumlah `PENDING` di tab Transaksi dan kartu Dashboard; tidak ada *notification* sistem dari DompetKu.
5. **Kosong & keadaan khusus:** izin belum aktif → layar penjelas + tombol; `EXPIRED`/`DISMISSED` tersembunyi di bawah "Riwayat draf".

#### 3.2.9 Kontrak layar konfirmasi draf (draf → transaksi manual)

Layar ini adalah satu-satunya tempat `source = 'NOTIFICATION'` menjadi transaksi. Aturan, dalam satu `db.transaction()`:

1. Validasi penuh §4.3 memakai **nilai akhir yang terlihat di layar** (nominal boleh sudah diedit): V5, V9, V10, V11, V13 → bila gagal, tidak ada yang tertulis.
2. Insert `transactions` dengan `reference_type = NULL` (**manual** — bukan `'SAVING'`/`'DEBT'`, supaya V8 tidak menjadikannya transaksi terlindungi dari edit/hapus) dan `source = 'NOTIFICATION'`. Kategori harus kompatibel `tipe` (§5.6).
3. Update `transaction_drafts`: `status='ACCEPTED'`, `accepted_log_id` → id log §5.10.
4. Insert `draft_acceptance_log` (§5.10) memakai **nilai akhir** yang dikonfirmasi + `rule_version` yang berlaku saat draf dibuat.
5. Gagal di langkah mana pun → *rollback* total; draf tetap `PENDING`; tidak ada saldo setengah berubah (§2.3.1).
6. **Pembatalan ("Undo"):** satu `db.transaction()` yang mengembalikan saldo dengan menghapus transaksi hasil draf (jalur `deleteManualTransaction` FR-02) dan mengembalikan draf ke `PENDING`. Berlaku **5 detik** dari snackbar setelah aksi; setelah itu tidak ada tombol Undo. Tidak ada kolom/flag *undo* di skema (§2.3.6 tetap benar: undo = transaksi manual dihapus).
7. **Setelah lewat layar ini,** transaksi adalah transaksi manual biasa: read-write normal di FR-02/FR-03, dihitung di ringkasan manual FR-01c, dan **boleh** dihapus dari layar Transaksi. Kalau dihapus, draf menjadi `VOIDED` (§3.2.5).

#### 3.2.10 Di luar lingkup FR-14

* Tidak ada auto-post, auto-kategori final, atau "mode tenang" yang menyimpan draf tanpa tanya.
* Tidak memakai Open Banking API / *webhook* bank / scraping SMS-OTP (tetap out-of-scope §1.2, dan membaca OTP adalah risiko yang tidak sebanding).
* Tidak memakai saldo yang tertera di notifikasi untuk "sinkronisasi saldo otomatis" (tergoda, tapi `ADJUSTMENT` otomatis dari angka yang tidak bisa kita verifikasi akan menodai invariant §2.3.5). Ditunda, bukan ditolak.
* Tidak ada padanan di iOS: tidak ada API untuk membaca notifikasi aplikasi lain. Tombol deteksi **disembunyikan** di iOS (bukan dinonaktifkan dengan pesan yang menyesatkan).
* Tidak ada multi-akun/multi-dompet per aplikasi bayar.

#### 3.2.11 Rencana uji (gerbang masuk Sprint 8)

* **Fixture parser:** minimal 20 sampel teks notifikasi nyata per aplikasi (10 positif, 10 negatif/rusak/berubah format) → 0 *crash*, field benar ≥ 90 %, yang rusak **dibuang senyap** (tidak jadi draf sampah).
* **Dedup:** notifikasi identik 5× → tepat 1 baris draf (UNIQUE `dedup_key`).
* **Isolasi ledger (property test):** sisipkan N draf acak → Saldo Utama, Net Worth, dan seluruh query dashboard **tidak berubah** sama sekali; hanya setelah `confirmDraftTransaction` saldo bergerak.
* **Double-count:** simulasi notifikasi ganda (bank + wallet untuk satu pembayaran) → flag duplikat muncul, dan menolak Terima ganda bila idempotensi dilanggar.
* **Undo:** Terima → Undo dalam 5 detik → Σ transaksi sama persis dengan sebelum Terima; Undo setelah 5 detik tidak tersedia.
* **Izin:** cabut izin saat aplikasi jalan → tidak ada crash, status UI berubah, draf lama tetap ada; 10 notifikasi acak dari paket lain → 0 baris draf.
* **Tanpa jaringan:** uji bahwa build release tidak pernah membuat koneksi (daftar paket jaringan kosong) dan izin `INTERNET` tidak dideklarasikan.
* **Cleanup:** `EXPIRED` pada 31 hari, kap 500 baris dipaksa dan tidak ada `PENDING` yang hilang.
* **Kebersihan:** `dart analyze` bersih, seluruh test lama tetap lulus.

---

## 4. Rumus & Aturan Perhitungan (Core Formulas & Validation Rules)

### 4.1 Rumus

1.  **Saldo Utama Aktif**
    $$\text{Saldo Utama} = \sum \text{INCOME} - \sum \text{EXPENSE} \quad (\text{seluruh baris } transactions)$$

2.  **Ringkasan Bulan (Dashboard, §3 FR-01c)**
    $$\text{Pemasukan}_{bulan} = \sum \text{INCOME} \cap \text{reference\_type} = \text{'MANUAL'}$$
    (Begitu pula pengeluaran. Transaksi otomatis dilaporkan terpisah.)

3.  **Progres Tabungan**
    $$\text{Persentase} = \min\!\left(\frac{\text{current\_amount}}{\text{target\_amount}},\ 100\%\right) \times 100\% \quad\text{dan tampilkan nominal aslinya } (\text{bisa} > 100\%)$$

4.  **Sisa Kewajiban Hutang/Piutang**
    $$\text{Sisa} = \text{total\_amount} - \sum \text{amount\_paid}$$

5.  **Net Worth**
    $$\text{Net Worth} = (\text{Saldo Utama} + \text{Total Tabungan} + \text{Sisa Piutang}) - \text{Sisa Hutang}$$
    *Ditampilkan sebagai kartu sekunder di Dashboard (FR-01b).*

> **Catatan Net Worth vs double-count:** "Setor tabungan" memindahkan uang dari Saldo Utama ke Total Tabungan sehingga Net Worth tidak berubah — benar. "Bayar hutang" mengurangi Saldo Utama dan Sisa Hutang dengan jumlah sama — Net Worth tidak berubah, kecuali bunga (di luar cakupan).

### 4.2 Unit & Tanggal
*   **Nominal:** **integer Rupiah penuh** (tanpa koma/desimal), disimpan pada kolom `INTEGER`. Valid input 0 < nominal ≤ 1.000.000.000.000 (1 triliun). Formatting tampilan via `intl`: `Rp 1.250.000`.
*   **Tanggal/waktu:** disimpan sebagai *epoch milliseconds* (integer UTC) di Drift. Filter "bulan berjalan" memakai **zona waktu perangkat** (`DateTime.now()` lokal → range millis). Diterima: transaksi yang dibuat sebelum tengah malam lokal dihitung pada tanggal lokalnya masing-masing (tidak ada reklasifikasi saat berpindah zona).

### 4.3 Aturan Validasi Lengkap (FR-08)

| # | Kondisi | Hasil |
| :--- | :--- | :--- |
| V1 | Setor tabungan > Saldo Utama | Warning dialog, tawarkan nominal maks = saldo |
| V2 | Bayar/angsur hutang PAYABLE > Saldo Utama | Warning dialog |
| V3 | Tarik tabungan > `current_amount` goal | Ditolak (hard error, karena tidak mungkin) |
| V4 | Cicilan > sisa hutang/piutang | Warning dialog: "melebihi sisa?" — input dibatasi (clamp) ke nilai sisa; pembayaran tidak bisa melebihi sisa sehingga tidak ada dana berlebih yang perlu ditentukan nasibnya |
| V5 | Nominal ≤ 0 atau non-numeric | Ditolak |
| V6 | Target amount ≤ 0 saat membuat goal | Ditolak |
| V7 | Menghapus goal/hutang yang memiliki log/cicilan | Lihat §6.6 |
| V8 | Hapus/edit transaksi `reference_type != 'MANUAL'` dari API/layar transaksi | Ditolak `ProtectedTransaction` |
| V9 | Simpan draf (FR-14) dengan nominal ≤ 0, non-numeric, atau > 1 triliun (§4.2) | Ditolak di layar konfirmasi; draf tetap `PENDING` |
| V10 | Simpan draf dengan kategori yang `tipe`-nya tidak cocok arah dana (misal kategori EXPENSE untuk dana masuk) | Ditolak, pilih kategori lain (§5.6) |
| V11 | Terima draf dengan status bukan `PENDING` (sudah `ACCEPTED`/`DISMISSED`/`EXPIRED`) | Ditolak `DraftNotPending` — **idempotensi**: satu draf tidak dapat menghasilkan dua transaksi |
| V12 | Notifikasi dari paket yang tidak diizinkan pengguna, atau parse gagal | **Bukan error UI.** Dibuang diam-diam, hanya `draft_parse_stats.skipped` (§5.11) yang bertambah |
| V13 | Arah dana tidak pasti (`confidence='AMBIGUOUS'`) | Tombol **Terima** dinonaktifkan sampai pengguna memilih "uang masuk" / "uang keluar" di layar konfirmasi |

> V9–V13 hanya memvalidasi **calon** transaksi. Tidak ada satu pun jalur deteksi yang mengubah Saldo Utama tanpa melewati layar konfirmasi + `LedgerService.confirmDraftTransaction` (§2.1.2).

### 4.4 Rumus & Aturan Turunan FR-14 (baru)

1.  **Kunci dedup** (UNIQUE di §5.9):
    `dedup_key = SHA-256( source_package | direction | amount | floor(postTime / 60000) )` — dibulatkan ke menit, supaya dua *post* notifikasi yang nyaris serentak (re-render, sinkronisasi aplikasi sumber) tetap menghasilkan satu baris.
2.  **Pratinjau dampak saldo di layar konfirmasi:** `saldo_setelah = saldo_sekarang + amount` bila arah `'IN'`, `saldo_sekarang − amount` bila `'OUT'`.
    Angka ini **hanya ditampilkan**; nilainya tidak ditulis ke kolom mana pun dan tidak pernah dibaca query agregasi.
3.  **Ambang `likely_duplicate`** (penanda UI saja, dihitung saat query — bukan kolom): ada transaksi `'MANUAL'` dengan `amount` dan `type` yang sama serta `|transaction_date − postTime| ≤ 600 detik`.
4.  **Kedaluwarsa:** `status='PENDING' AND created_at < now − 30 hari` → `EXPIRED`. Dieksekusi saat aplikasi dibuka (bukan *worker* berjadwal, §3.2.6).
5.  **Kapasitas:** total baris `transaction_drafts` (semua status) dijaga ≤ **500**. Saat penuh, `EXPIRED`/`DISMISSED` tertua dihapus lebih dulu; `PENDING` tidak pernah dihapus diam-diam.
6.  **Undo** = satu `db.transaction()` berisi `deleteManualTransaction(transaction_id)` + kembalikan draf ke `PENDING` + hapus baris `draft_acceptance_log` terkait; tersedia **5 detik** dari snackbar setelah Terima/Abaikan, setelah itu tidak ada tombolnya. Tidak ada kolom/flag *undo* di skema (§4.4.6 inilah yang dimaksud "undo = transaksi manual dihapus" di §2.3.6).

---

## 5. Rancangan Skema Database (Drift / SQLite)

### 5.1 `transactions` — tabel pusat arus kas
| Kolom | Tipe | Keterangan |
| :--- | :--- | :--- |
| `id` | INTEGER PK autoincrement | |
| `title` | TEXT | "Makan Siang", "Setor Tabungan: Beli Laptop", "Cicil Hutang: Budi" |
| `amount` | INTEGER | Rupiah penuh, > 0 |
| `type` | TEXT | `'INCOME'` / `'EXPENSE'` |
| `category_id` | INTEGER FK → `categories.id` | Menggantikan kolom TEXT v1.1 (lihat §5.6) |
| `transaction_date` | INTEGER | epoch millis UTC |
| `note` | TEXT NULL | |
| `reference_type` | TEXT NULL | `'MANUAL'` (default via NULL atau literal — gunakan **NULL = manual** dan nilai lain untuk otomatis, agar indeks hemat), `'SAVING'`, `'DEBT'` |
| `reference_id` | INTEGER NULL | id `saving_logs` / `debt_payments` / id `debts` untuk initial disbursement |
| `source` | TEXT NOT NULL DEFAULT `'MANUAL'` | **baru (FR-14):** `'MANUAL'` (dipakai manual) / `'NOTIFICATION'` (hasil Terima draf). Murni label penanda asal untuk badge & filter FR-03 — **tidak** dipakai di agregasi mana pun, dan transaksinya tetap `reference_type = NULL` sehingga hak edit/hapusnya sama dengan transaksi manual (§2.3.6) |

Indeks: `(transaction_date)`, `(type, transaction_date)`, `(reference_type, reference_id)`.

### 5.2 `savings_goals`
`id` PK, `goal_name` TEXT, `target_amount` INTEGER, `current_amount` INTEGER DEFAULT 0 *(cache derived, §2.3.3)*, `target_date` INTEGER NULL, `is_completed` INTEGER (bool) DEFAULT 0.

### 5.3 `saving_logs`
`id` PK, `saving_id` INTEGER FK → `savings_goals.id` **ON DELETE CASCADE**, `transaction_id` INTEGER FK → `transactions.id` **ON DELETE CASCADE**, `amount` INTEGER, `action_type` TEXT (`'DEPOSIT'`/`'WITHDRAW'`), `created_at` INTEGER. Indeks: `(saving_id)`, UNIQUE(`transaction_id`).

### 5.4 `debts`
`id` PK, `person_name` TEXT, `type` TEXT (`'PAYABLE'`/`'RECEIVABLE'`), `total_amount` INTEGER, `paid_amount` INTEGER DEFAULT 0 *(cache derived)*, `due_date` INTEGER NULL, `is_settled` INTEGER DEFAULT 0, `initial_transaction_id` INTEGER FK → `transactions.id` NULL **ON DELETE SET NULL**, `description` TEXT NULL. Indeks: `(type, is_settled)`, `(due_date)`.

### 5.5 `debt_payments`
`id` PK, `debt_id` INTEGER FK → `debts.id` **ON DELETE CASCADE**, `transaction_id` INTEGER FK → `transactions.id` **ON DELETE CASCADE**, `amount_paid` INTEGER, `payment_date` INTEGER, `note` TEXT NULL. Indeks: `(debt_id)`, UNIQUE(`transaction_id`).

### 5.6 `categories` (baru)
`id` PK, `name` TEXT, `icon` TEXT (nama ikon), `tipe` TEXT (`'INCOME'`/`'EXPENSE'`/`'BOTH'`), `is_system` INTEGER DEFAULT 0, `is_active` INTEGER DEFAULT 1, `sort_order` INTEGER. Nama unik (UNIQUE index).

FR-14 **tidak** menambah kategori sistem baru: draf memakai kategori milik pengguna yang sudah ada (usulan hanya lewat pemetaan kata-kunci → `category_id`, §3.2.4), dan keharusan kecocokan `tipe` ditegakkan oleh V10.

### 5.7 Klarifikasi Relasi (mengganti klaim v1.1)
* Klaim v1.1 "relasi *Foreign Key* pada tabel `transactions`" **diperbaiki**: `transactions` **tidak memiliki FK ke modul sumber** karena sifatnya polimorfik (`reference_type` + `reference_id` = *soft reference*). Yang berupa FK asli adalah arah sebaliknya: `saving_logs.transaction_id` dan `debt_payments.transaction_id` → `transactions.id`.
* **Integritas soft reference dijaga oleh service layer**, bukan database:
  * Tidak boleh menghapus baris `saving_logs`/`debt_payments` tanpa menghapus transaksi yang dirujuknya (dilakukan dalam transaction yang sama).
  * Tidak boleh menghapus `transactions` dengan `reference_type != 'MANUAL'` dari jalur publik (V8); satu-satunya penghapusan sah adalah lewat modul sumber.
* ON DELETE CASCADE pada FK `transaction_id` tetap dipasang sebagai safety net; namun service tidak boleh mengandalkannya karena bisa memutus link log → saldo (§2.3.5).
* **Kecuali** untuk draf FR-14: `transaction_drafts.transaction_id` dan `draft_acceptance_log.transaction_id` memakai **ON DELETE SET NULL**, bukan CASCADE. Menghapus transaksi hasil draf (yang memang transaksi manual, FR-02) **tidak boleh** menghapus bukti bahwa draf pernah ada — draf hanya bergeser ke `status='VOIDED'`; sebaliknya, menghapus atau mengabaikan draf tidak pernah menyentuh `transactions`.

### 5.8 Migrasi
* `schemaVersion` Drift dimulai dari **1**. Setiap rilis dengan perubahan skema menaikkan versi dan menulis `MigrationStrategy` (`up`/`down` bila mungkin) yang **menjaga data pengguna**.
* Upgrade dari skema v1.1 (eksperimental, bila ada build lama): migrasi `up` membuat tabel `categories`, mengisi seed, memetakan `transactions.category` TEXT → `category_id`.
* Dilarang menghapus kolom/tabel tanpa migrasi.
* **Khusus FR-14 → `schemaVersion` 1 ke 2** (semuanya aditif, tidak menyentuh baris ledger yang sudah ada):
  * `CREATE TABLE transaction_drafts`, `draft_acceptance_log`, `draft_parse_stats` (§5.9–§5.11) beserta indeksnya.
  * `ALTER TABLE transactions ADD COLUMN source TEXT NOT NULL DEFAULT 'MANUAL'` — kolom lama tetap, seluruh baris_existing otomatis `'MANUAL'`, jadi tidak ada backfill dan tidak ada perubahan hasil agregasi.
  * `down` = `DROP TABLE` tiga tabel baru + rebuild `transactions` tanpa `source`. **Bukan** jalur upgrade pengguna (Drift `down` hanya untuk pengembangan), tapi wajib ditulis supaya bisa diuji.
  * **Tidak ada seed kategori baru** untuk FR-14: draf memakai kategori milik pengguna yang sudah ada (§3.2.4), sehingga daftar kategori tidak tiba-tiba berubah.
* **Khusus FR-13:** tidak ada migrasi. Konfigurasi kunci aplikasi berada di `SharedPreferences` (§5.12), bukan di basis data.

### 5.9 `transaction_drafts` (baru — FR-14)

| Kolom | Tipe | Keterangan |
| :--- | :--- | :--- |
| `id` | INTEGER PK autoincrement | |
| `source_package` | TEXT | id paket aplikasi bayar asal notifikasi (mis. `id.dana`) — sekaligus kunci *rule pack* §3.2.4 |
| `direction` | TEXT | `'IN'` / `'OUT'` / `'UNKNOWN'` → dipetakan ke `INCOME`/`EXPENSE` **hanya** saat draf disimpan |
| `amount` | INTEGER | nominal hasil parse, harus lolos §4.2 (0 < x ≤ 1 triliun) |
| `merchant` | TEXT NULL | maks 60 karakter; NULL bila tidak terbaca |
| `notified_at` | INTEGER | epoch millis **`postTime` notifikasi**, bukan waktu parse |
| `rule_version` | INTEGER | versi rule pack yang menghasilkan draf ini (mitigasi §11 "format berubah") |
| `confidence` | TEXT | `'HIGH'` / `'AMBIGUOUS'` (arah tidak pasti → V13) |
| `dedup_key` | TEXT | SHA-256 (§4.4.1). **UNIQUE** — penolakan notifikasi ganda terjadi di database, bukan di Dart |
| `status` | TEXT | `'PENDING'` / `'ACCEPTED'` / `'DISMISSED'` / `'EXPIRED'` / `'VOIDED'` (§3.2.5) |
| `transaction_id` | INTEGER FK → `transactions.id` NULL **ON DELETE SET NULL** | transaksi manual hasil "Terima". **Soft link audit**, bukan soft reference ledger: query saldo tidak pernah membacanya, dan menghapus transaksi manual mengembalikan draf ke `VOIDED` |
| `raw_snapshot` | TEXT NULL | **Selalu NULL di build rilis.** Hanya untuk mode diagnostik yang dinyalakan pengguna di debug build (§3.2.7) — jangan pernah menyalin isi notifikasi penuh secara default |
| `accepted_log_id` | INTEGER FK → `draft_acceptance_log.id` NULL **ON DELETE SET NULL** | penunjuk log penerimaan (§5.10); FK dua arah `drafts ↔ log` sengaja dibuat *nullable* agar tidak ada *cycle* yang memaksa penghapusan berantai |
| `created_at` | INTEGER | waktu draf dimasukkan |

Indeks: `(status, notified_at)` untuk Inbox, UNIQUE(`dedup_key`). Kapasitas maksimum 500 baris (§4.4.5).

> Tabel ini **tidak boleh** dibaca oleh query agregasi saldo/dashboard/arus kas. Pelindungnya: tidak ada `JOIN` ke `transaction_drafts` di SQL ledger mana pun + uji "Sisipkan 50 draf → Σ saldo tidak berubah" (§3.2.11).

### 5.10 `draft_acceptance_log` (baru — FR-14)

`id` PK, `draft_id` INTEGER FK → `transaction_drafts.id` **ON DELETE CASCADE** (aman karena draf `ACCEPTED` tidak pernah dihapus fisiknya, §2.1.2), `transaction_id` INTEGER FK → `transactions.id` **ON DELETE SET NULL**, `final_amount` INTEGER, `final_direction` TEXT, `final_category_id` INTEGER FK → `categories.id`, `user_edited` INTEGER (bool) DEFAULT 0 — penanda bahwa pengguna mengubah nilai usulan, `accepted_at` INTEGER, `rule_version` INTEGER. Indeks: `(draft_id)`, `(accepted_at)`.

Isinya **nilai akhir yang dikonfirmasi pengguna**, bukan nilai usulan — supaya kalau suatu saat perlu ditelusuri ("kenapa saldo berubah?"), yang tercatat adalah keputusan, bukan tebakan parser. Riwayat ini juga yang dihapus/dipulihkan oleh aksi Undo (§4.4.6).

### 5.11 `draft_parse_stats` (baru — FR-14)

`source_package` TEXT PK, `detected` INTEGER DEFAULT 0, `skipped` INTEGER DEFAULT 0, `drafted` INTEGER DEFAULT 0, `last_seen_at` INTEGER NULL, `last_rule_version` INTEGER.

Hanya **counter agregat** — tidak ada teks notifikasi di dalamnya. Fungsinya membuat kegagalan senyap bisa didiagnosis: bila `detected` naik tapi `drafted` diam di nol, format notifikasi aplikasi itu berubah (§11). Ditampilkan apa adanya di Pengaturan → Deteksi Pembayaran (§3.2.8).

### 5.12 Catatan: preferensi non-ledger tinggal di `SharedPreferences`
Aplikasi sudah punya pola ini (tema, onboarding, pengingat backup), dan FR-13/FR-14 ikut polanya:

| Kunci | Nilai | Dipakai oleh | Catatan |
| :--- | :--- | :--- | :--- |
| `app_lock_enabled`, `app_lock_pin_salt`, `app_lock_pin_hash`, flag biometrik | bool / base64 | FR-13 | **Sengaja** tidak pernah masuk SQLite maupun Android Keystore (alasan §3.1.2) |
| `detection_enabled` | bool | FR-14 | *switch* master deteksi; default **mati** |
| `detection_allowed_packages` | JSON list string | FR-14 | daftar `source_package` yang boleh dibaca (§3.2.8) — default **kosong**, tidak ada aplikasi yang otomatis ikut terbaca |
| `detection_seen_dedup_keys` | LRU string (maks 200) | FR-14 | cache optimasi saja; kebenaran dedup tetap di UNIQUE `dedup_key` (§5.9) |

Konsekuensi yang diterima: (a) kredensial dan preferensi **tidak** termasuk isi file backup `.sqlite` FR-11, sehingga restore di HP lain mengembalikan data draf tanpa membuat pengguna terkunci permanen — ia cukup memasang PIN/biometrik baru; (b) `allowBackup=true` tetap membawa nilai `SharedPreferences` lewat cadangan sistem, jadi yang ikut terbawa hanyalah hash PIN dan preferensi, dan ini **tidak** setara enkripsi data (§3.1.4); (c) preferensi bukan bagian dari invariant ledger, jadi tidak pernah dibutuhkan `db.transaction()`.

---

## 6. Keputusan Produk yang Dikunci (Hasil Review)

1.  **Saldo Utama tidak dapat bernilai negatif?** Boleh negatif secara data (akomodasi koreksi), tetapi UI menampilkan warna peringatan merah + hint "Saldo tercatat minus, gunakan Penyesuaian Saldo (FR-09)". Tidak ada blokir keras.
2.  **Over-save diizinkan** (setoran melebihi target → progress >100%, badge "Terlampaui"). Tidak ada validasi penolakan.
3.  **Edit transaksi manual** yang mengubah tanggal/bulan: ringkasan dashboard ikut berubah; tidak ada audit trail (di luar MVP).
4.  **Edit goal:** boleh ubah `goal_name`, `target_amount`, `target_date`. `current_amount` tidak dapat diedit langsung.
5.  **Edit hutang:** boleh ubah `person_name`, `due_date`, `description`. Mengubah `total_amount` **tidak mengubah** nominal transaksi otomatis yang sudah dibuat (transaksi awal adalah bukti dana yang benar-benar mengalir); UI menampilkan warning bahwa sisa dihitung ulang.
6.  **Hapus goal/hutang dengan riwayat:** dialog konfirmasi dua langkah:
    * Opsi A (default): **"Batalkan semua riwayat dan kembalikan dana"** → setiap log dihapus beserta transaksinya → Saldo Utama pulih, goal hilang.
    * Opsi B: **"Arsipkan"** (flag `is_archived`, ditambah di `savings_goals` dan `debts`) → data tetap, tidak muncul di daftar aktif. Direkomendasikan bila pengguna hanya ingin menyembunyikan.
7.  **Piutang dibayar sebagian, lalu sisa di-*write off*:** v1.1 tidak membahasnya; MVP: tidak ada fitur write-off (gunakan hapus riwayat piutang, yang membuat Saldo Utama **naik** karena transaksi pengeluaran awal dihapus — sesuai §2.3.5). Dinilai cukup dan tidak membingungkan karena ledger selalu konsisten.
8.  **Draf hasil deteksi tidak pernah tersimpan otomatis (FR-14).** Tidak ada "mode hemat" yang meng-*auto-accept* nominal besar/kecil, dan tidak ada *auto-merge* ke transaksi yang sudah ada. Alasan: satu kesalahan parser yang tertulis senyap merusak kepercayaan pada seluruh angka aplikasi, sedangkan satu pembayaran yang terlewat selalu bisa dicatat manual dalam 10 detik (FR-02).
9.  **Lupa PIN = reset, tidak ada pemulihan (FR-13).** Tidak ada email, tidak ada *recovery code*, tidak ada server. "Lupa PIN? Reset aplikasi" menghapus kredensial **dan** seluruh data. Konsekuensi ini harus dibaca pengguna **sebelum** mengaktifkan kunci (dialog aktivasi menampilkan risikonya), dan itulah sebabnya FR-11 backup menjadi prasyarat memakai FR-13. Alternatif yang ditolak: menyimpan PIN dalam bentuk terdekripsi (menambah kunci yang bisa hilang) atau pertanyaan pemulihan (memindahkan masalah ke rahasia yang lebih lemah dari PIN).
10.  **Deteksi notifikasi hanya Android (FR-14), dan tidak berjalan saat terkunci (FR-13).** iOS tidak punya API untuk membaca notifikasi aplikasi lain → *switch* deteksi **disembunyikan** di iOS (bukan dinonaktifkan dengan pesan yang menyesatkan). Saat layar kunci aktif, listener menahan hasil di antrean memori dan memprosesnya setelah terbuka, karena membaca dan menulis data sambil pengguna tidak bisa melihatnya adalah sumber kebingungan.
11.  **Draf ikut backup, kredensial tidak.** `transaction_drafts`, `draft_acceptance_log`, dan `draft_parse_stats` adalah tabel basis data sehingga otomatis terbawa file `.sqlite` FR-11 — restore di HP lain mengembalikan Inbox draf juga, dan itu diinginkan. Kredensial kunci aplikasi (FR-13) sengaja berada di `SharedPreferences` (§5.12) supaya restore backup **tidak pernah** membuat pengguna terkunci permanen. Konsekuensi: setelah restore di perangkat lain, pengguna harus men-setting ulang PIN/biometrik.

---

## 7. Kebutuhan Non-Fungsional (baru)

| ID | Kategori | Persyaratan |
| :--- | :--- | :--- |
| NFR-01 | Performa | Cold start < 2 detik di perangkat kelas menengah. Query dashboard (agregasi saldo, ringkasan bulan) harus memakai indeks §5 dan SQL `SUM`, bukan iterasi seluruh baris di Dart. Render dashboard < 500 ms untuk 10.000 transaksi. |
| NFR-02 | Platform | Min. Android API 23 (6.0), iOS 13. Mendukung *dark mode* sistem. Orientasi portrait (keyboard input). |
| NFR-03 | Keandalan | Tidak ada jalur UI yang menghasilkan Saldo Utama tidak konsisten dengan Σ transaksi (diuji lewat property test, §9). Semua operasi multi-write memakai `db.transaction()`. |
| NFR-04 | Data & Privasi | 100% lokal, tanpa jaringan, tanpa akun. Risiko: uninstall/ganti HP menghapus data → **FR-11 backup/restore** menjadi pelindung wajib; tampilkan reminder backup bila belum pernah backup > 30 hari dan ada ≥ 20 transaksi. "Tanpa jaringan" berlaku juga untuk FR-14: **izin `INTERNET` tidak boleh dideklarasikan** dan tidak ada teks notifikasi yang meninggalkan perangkat (NFR-09). Berkas `.sqlite` dan file cadangan tetap **teks terbuka** — kunci aplikasi (FR-13) tidak mengenkripsinya (§3.1.4). |
| NFR-05 | Kualitas | Coverage unit test untuk ledger service ≥ 90%; integration test untuk alur setor/tarik/cicilan terhadap DB Drift in-memory. Tambahan wajib: **property test** yang membuktikan draf FR-14 tidak pernah mengubah Saldo Utama (§3.2.11), **regression test urutan lifecycle Android** untuk auto-lock (§3.1.5), dan **fixture parser** per aplikasi bayar (§3.2.4). |
| NFR-06 | Aksesibilitas | Teks nominal menggunakan `tabularFigures`; target sentuh ≥ 48 dp; label form memakai semantics; kontras warna saldo mengikuti tema. Layar kunci (FR-13) dan Inbox Draf (FR-14) ikut aturan ini; status draf tidak boleh diwakili warna saja (selalu ada ikon + teks arah). |
| NFR-07 | Penerjemahan | UI string memakai `intl` ARB (infrastruktur disiapkan sejak awal) walaupun rilis 1.0 hanya Bahasa Indonesia. Berlaku juga untuk pesan baru FR-13 ("Sidik jari tidak dikenali. Gunakan PIN.", "DompetKu terkunci") dan FR-14 (label status draf, pesan izin). |
| NFR-08 | Keamanan akses (FR-13) | PIN 4–6 angka di-hash PBKDF2-HMAC-SHA256 **30.000 iterasi**, kunci **32 byte**, salt acak 16 byte, perbandingan *constant-time*, dijalankan di isolate. Auto-lock **30 detik** setelah aplikasi kembali dari latar; cold start selalu terkunci; **5×** PIN salah → cooldown **60 detik**. Biometrik default mati dan memakai `biometricOnly` (tanpa fallback PIN perangkat). Tidak ada jalur UI yang melewati layar kunci: redirect router + `PopScope(canPop: false)`, dan layar di baliknya tidak dirender. Hash tidak pernah ditulis ke log. Membuka kunci **tidak boleh** memperlambat restore FR-11 (§5.12). |
| NFR-09 | Privasi notifikasi (FR-14) | Isi notifikasi diproses di memori, hanya dari paket yang dicentang pengguna, dan **tidak pernah** disimpan utuh di build rilis (`raw_snapshot` selalu NULL, §5.9). Tidak ada analitik, *crash reporting*, atau *telemetry* yang ikut membawa teks notifikasi. Izin sistem hanya *Notification Listener Access* — tanpa izin itu fitur mati secara anggun dan seluruh fitur lain tetap berjalan. UI wajib menyatakan dua hal jujur: DompetKu melihat semua notifikasi perangkat saat izin aktif (§3.2.7), dan hanya pembayaran yang muncul **setelah** fitur diaktifkan yang bisa ditangkap (§3.2.6). |
| NFR-10 | Performa & stabilitas deteksi (FR-14) | Parse satu notifikasi < 50 ms dan tidak dijalankan di UI thread; kegagalan parse **tidak boleh** melempar exception ke platform (`NotificationListenerService` yang crash membuat izin tampak "rusak" di mata pengguna). Antrean pending dibatasi (mis. 50 item, terbuang terbaru bukan terlama) dan diproses setelah layar kunci terbuka. Tidak ada *worker* berjadwal / alarm_exact: pembersihan `EXPIRED` dan statistik berjalan saat aplikasi dibuka. Listener tidak menambah cold start > 100 ms. |
| NFR-11 | Invarian lintas-fitur | Menambah FR baru **tidak boleh** mengubah hasil query agregasi yang ada. Uji wajib: sebelum/sesudah migrasi `schemaVersion` 1→2, Σ saldo, Net Worth, ringkasan bulan, dan laporan FR-12 pada dataset fixture yang sama menghasilkan angka identik; 50 draf `PENDING` yang disisipkan tidak mengubah satu pun angka tersebut; `transactions` bertambah **hanya** lewat `LedgerService`. |

---

## 8. Spesifikasi Teknis & Arsitektur Flutter

*   **Framework:** Flutter SDK terbaru (Dart 3.x).
*   **Arsitektur:** *Clean Architecture / Feature-First*:
    ```
    lib/
      core/           (theme, router go_router, formatters, db, error)
        data/
          drift/      (app_database.dart, tables, dao, migrations)
        domain/
        security/     (FR-13: pin_hash, app_lock_store, biometric_gate, app_lock_controller)
      features/
        dashboard/    (presentation + providers)
        transactions/
        savings/
        debts/
        categories/
        lock/         (FR-13: lock_page)
        detection/    (FR-14: draft_inbox_page, draft_confirm_sheet, notification_rules, draft_service)
        settings/     (backup/restore, saldo awal, penyesuaian, keamanan, deteksi pembayaran)
    ```
*   **State:** `flutter_riverpod` dengan `StreamProvider` di atas query Drift (watch). Semua angka saldo berasal dari stream agregasi sehingga UI refresh real-time setelah ledger transaction commit.
*   **Ledger service (jantung aplikasi):** satu `LedgerService` yang menjadi **satu-satunya** jalur tulis ke tabel yang memengaruhi saldo. API-nya (indikatif):
    * `addManualTransaction`, `updateManualTransaction`, `deleteManualTransaction`
    * `createSavingsGoal`, `depositToSavings`, `withdrawFromSavings`, `deleteSavingLog`, `deleteSavingsGoal(withLogs:)`, `archiveSavingsGoal`
    * `createDebt(withDisbursement:)`, `payDebt`, `deleteDebtPayment`, `deleteDebt(withPayments:)`, `archiveDebt`
    * `adjustBalance`, `setInitialBalance`
    * **FR-14 (baru):** `confirmDraftTransaction(draftId, {title, amount, type, categoryId, date, note})` — satu-satunya entri draf ke ledger; ia membuat transaksi **`MANUAL`** (`reference_type = NULL`, `source = 'NOTIFICATION'`) dan menandai draf `ACCEPTED` di dalam `db.transaction()` yang sama.
    Setiap method: validasi §4.3 → `db.transaction()` → tulis log + transaction + refresh cache derived.
*   **Draft service (FR-14, tidak menyentuh saldo):** `NotificationIngestService.ingest(rawEvent)` (panggil dari platform channel → saring paket → parse → dedup → insert draf), `DraftService.accept(...)` (hanya meneruskan ke `LedgerService.confirmDraftTransaction` + update status), `DraftService.dismiss(draftId)`, `DraftService.deleteDraft(draftId)`, `DraftService.cleanupExpired()`, `DraftService.stats()`. **Tidak ada method di kelas ini yang menulis `transactions` langsung** — dijaga uji "0 baris `transactions` setelah 50 ingest" (§3.2.11).
*   **Platform — Android (FR-13):** `MainActivity` **wajib** tetap `FlutterFragmentActivity` (`local_auth` memakai Fragment API). Tidak ada *permission* khusus untuk biometrik; status dibaca via `BiometricManager`/`getAvailableBiometrics()`.
*   **Platform — Android (FR-14):** *service* di `android/app/src/main/AndroidManifest.xml`:
    ```xml
    <service
        android:name=".DompetkuNotificationListener"
        android:exported="false"
        android:label="@string/app_name"
        android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
        <intent-filter>
            <action android:name="android.service.notification.NotificationListenerService" />
        </intent-filter>
    </service>
    ```
    * Permission `BIND_NOTIFICATION_LISTENER_SERVICE` harus ada pada elemen `<service>`; pemakaiannya di luar kendali aplikasi (pengguna memberi izin di *Settings* → *Notification access*), jadi tidak ada *runtime permission request* ala `requestPermissions()`.
    * **Tetap tidak mendeklarasikan `android.permission.INTERNET`** — ini juga penjaga NFR-09: tanpa izin tersebut, kesalahan yang mengirim data keluar tidak mungkin terjadi.
    * Komunikasi Kotlin ↔ Dart lewat `MethodChannel('dompetku/notification')` (Dart memanggil `setStatus`/`openNotificationAccessSettings`) dan `EventChannel('dompetku/notification/events')` (Kotlin mengirim `postTime`, `packageName`, `title`, `text` yang sudah disaring paket). Parsing regex dilakukan **di Dart**, supaya aturan bisa diuji dengan fixture Dart biasa tanpa *instrumented test*.
    * iOS: tidak ada padanan API → seluruh modul deteksi di-*compile* tapi tidak diaktifkan, dan *switch*-nya disembunyikan (§3.2.10).
*   **Package:** `drift` + `sqlite3_flutter_libs`, `drift_flutter`/`build_runner`, `flutter_riverpod`, `intl`, `fl_chart`, `go_router`, `file_picker` / `share_plus` + `path_provider` (FR-11), `shared_preferences` + `local_auth` + `crypto` (FR-13, sudah dipakai), `device_info_plus` (opsional, untuk membaca versi OS saat mendiagnosis perilaku listener). **FR-14 tidak menambah dependensi jaringan sama sekali;** bila suatu saat memakai paket *notification listener* pihak ketiga, paket itu harus di-*vendor* dan diaudit dulu (§11) — *default*-nya tetap *platform channel* sendiri.

---

## 9. Rancangan Antarmuka (UI/UX)

1.  **Dashboard (Tab 1):** Kartu Saldo Utama Aktif + sub-info "Total Aset di Tabungan"; kartu **Net Worth**; bar "Pemasukan vs Pengeluaran bulan ini (manual saja)"; dua chip kecil "Alokasi Tabungan: Rp…" / "Cicilan dibayar: Rp…"; pie chart pengeluaran per kategori (FR-12); daftar pengingat jatuh tempo ≤ 7 hari (hutang *dan* piutang, dengan label jenis). **FR-14:** satu baris kecil "N draf menunggu" di bawah kartu saldo (tap → Inbox draf); angka ini dari `transaction_drafts` `status='PENDING'` dan **tidak** memengaruhi satu pun kartu lain.
2.  **Transaksi (Tab 2):** daftar kronologis dengan badge sumber untuk transaksi otomatis (ikon celengan/buku) **tanpa** tombol edit/hapus; tap pada item otomatis membuka detail *read-only* dengan tombol "Buka di modul sumber". Sheet filter bulan/tipe/sumber/kategori. **FR-14:** transaksi hasil draf (`source='NOTIFICATION'`) tetap dapat diedit/dihapus seperti transaksi manual, hanya diberi chip kecil "dari notifikasi · DANA"; filter **sumber** bertambah opsi "hasil draf". Draf `PENDING` **tidak pernah** masuk daftar ini — ia hidup di Inbox terpisah (item 7).
3.  **Tabungan (Tab 3):** kartu goal + progress bar (+100% badge "Terlampaui"); bottom sheet Setor/Tarik menampilkan "Tersedia: Rp …" dan validasi V1/V3; layar detail goal berisi riwayat log dengan aksi hapus (pengembalian saldo) dan konfirmasi §6.6.
4.  **Hutang & Piutang (Tab 4):** tab switcher **Hutang Saya | Piutang**; form baru PAYABLE memuat checkbox §2.2; item menampilkan sisa + due date; dialog "Bayar/Cicil" dengan validasi V2/V4; layar detail berisi riwayat cicilan + hapus.
5.  **Pengaturan:** Kelola Kategori (FR-10), Set Saldo Awal / Penyesuaian Saldo (FR-09), Backup & Restore (FR-11), **Keamanan** (FR-13), **Deteksi Pembayaran** (FR-14), Tentang.
6.  **Layar Kunci (FR-13, menutupi seluruh aplikasi saat terkunci):** judul "DompetKu terkunci", keypad PIN dengan input ter-mask, tombol **Sidik jari** (hanya tampil bila biometrik tersedia), sisa percobaan + hitung mundur cooldown, dan tautan "Lupa PIN? Reset aplikasi" dengan konfirmasi dua langkah. Tidak bisa di-*back* keluar (`PopScope(canPop: false)`), dan layar di baliknya memang tidak dirender. Tile **Keamanan** menampilkan status ("PIN aktif", "PIN + sidik jari aktif · auto-lock 30 detik"), tempat mengaktif/nonaktifkan PIN (minta PIN lama) dan biometrik, serta **menampilkan batas keamanan §3.1.4 apa adanya** sebelum pengguna mengaktifkan.
7.  **Inbox Draf (FR-14, di Tab Transaksi segmen "Draf"):** daftar draf `PENDING` kronologis terbalik — ikon arah (↑ masuk / ↓ keluar), merchant, nominal, waktu notifikasi, chip paket asal (`DANA`), dan chip peringatan "arah tidak pasti" untuk `confidence='AMBIGUOUS'`. Aksi geser: Terima / Abaikan; Undo 5 detik di snackbar (§4.4.6). Layar konfirmasi memuat ringkasan dampak "Saldo Utama akan berkurang Rp 15.000 → Rp 385.000" (§4.4.2) dan seluruh field dapat diedit sebelum **Terima**. Keadaan khusus: izin belum aktif → layar penjelas + tombol "Buka pengaturan izin"; `EXPIRED`/`DISMISSED` tersembunyi di "Riwayat draf".

---

## 10. Tahapan Pengerjaan (Roadmap + Acceptance Criteria)

*   **Sprint 1 — Setup & Database Core.** Inisialisasi `dompetku`, struktur folder, skema Drift §5 + seed kategori + `MigrationStrategy` v1.
    * *AC:* `build_runner` sukses; test: FK/cascade berperilaku benar; soft-reference guard menolak hapus transaksi otomatis.
*   **Sprint 2 — LedgerService + Modul Transaksi + Saldo Awal.** CRUD manual, `LedgerService`, onboarding saldo awal.
    * *AC:* Σ transaksi == Saldo Utama setelah 200 operasi acak (property test); hapus/edit manual memulihkan/mengubah saldo dengan benar.
*   **Sprint 3 — Dashboard.** Kartu saldo, ringkasan manual-only, kartu alokasi/cicilan, Net Worth, pengingat ≤ 7 hari.
    * *AC:* setoran tabungan **tidak** muncul di "Total Pengeluaran bulan ini"; angka update < 1 detik tanpa restart.
*   **Sprint 4 — Tabungan Auto-Deduct.** CRUD goal, setor/tarik, riwayat log, hapus log, hapus vs arsip goal.
    * *AC:* V1/V3 teruji; hapus setoran mengembalikan saldo persis; progress cache = Σ log selalu sama.
*   **Sprint 5 — Hutang/Piutang & Cicilan.** Form + checkbox §2.2, cicilan, hapus cicilan, status lunas dua arah.
    * *AC:* piutang baru selalu memotong saldo; `is_settled` flip bolak-balik dengan benar saat cicilan ditambah/dihapus.
*   **Sprint 6 — Kategori, Backup/Restore, Polishing.** FR-10, FR-11, `fl_chart` FR-12, validasi penuh, empty state, dark mode, build APK/AAB.
    * *AC:* restore file backup menghasilkan saldo identik dengan sebelum ekspor; tidak ada crash pada 500 transaksi pertama.
*   **Sprint 7 — Kunci Aplikasi (FR-13).** *Status: **selesai** (commit `016c7a6` + perbaikan `ae34e4b`).* `core/security/` (hash PIN, store, biometrik gate, controller), `features/lock/`, redirect router + `PopScope`, penjagaan lifecycle + auto-lock 30 detik, tile Keamanan di Pengaturan, test unit + widget + router.
    * *AC (terpenuhi):* lihat daftar di §3.1.5 — cold start mengunci, PIN/biometrik/divergi gagal, cooldown 5×60 s, regresi urutan lifecycle Android `hidden → paused → hidden → resumed`, `LockPage` ter-*dispose* (digit tidak tertinggal), `dart analyze` bersih, 90 test lulus.
    * *AC tersisa:* jalur iOS (Face ID) **belum pernah diuji** di simulator; pengujian biometrik iOS di perangkat nyata ditunda sampai ada perangkatnya.
*   **Sprint 8 — Deteksi Draf dari Notifikasi (FR-14).** *Status: belum dimulai. P2 — mulai hanya setelah Sprint 1–7 hijau.*
    1.  **8a — Bekal & investigasi format (beban risiko terbesar).** Tangkap sampel notifikasi nyata dari aplikasi bayar yang dipakai pengguna (`adb shell dumpsys notification --noredact`), bekukan sebagai fixture, dan tetapkan *rule pack* v1 per paket. **Jangan** menulis regex dari ingatan (§3.2.4).
        * *AC:* fixture terdokumentasi per aplikasi; tidak ada aturan yang belum punya sampel nyata.
    2.  **8b — Skema & ingest.** Migrasi `schemaVersion` 1→2 (§5.8), tiga tabel §5.9–§5.11, kolom `transactions.source`, `NotificationListenerService` + `MethodChannel`/`EventChannel`, `NotificationIngestService` (saring paket → parse → dedup → insert).
        * *AC:* fixture 20/aplikasi → 0 crash, field benar ≥ 90 %, yang rusak dibuang senyap; notifikasi sama 5× → 1 draf; **sisip 50 draf → tidak ada satu baris pun di `transactions` dan Σ saldo/Net Worth/ringkasan bulan tidak berubah** (NFR-11); migrasi tidak mengubah satu pun angka pada dataset fixture.
    3.  **8c — Inbox & konfirmasi.** Segmen "Draf (N)" (§9.7), layar konfirmasi (§3.2.9) dengan pratinjau dampak saldo, `LedgerService.confirmDraftTransaction`, Undo 5 detik, badge dashboard, Pengaturan → Deteksi Pembayaran (status izin + *switch* paket + statistik §5.11).
        * *AC:* V9–V13 teruji; Terima → transaksi `MANUAL` + draf `ACCEPTED` + `draft_acceptance_log` dalam satu transaction; Terima pada draf non-`PENDING` ditolak (`DraftNotPending`); Undo mengembalikan Σ transaksi persis; cabut izin saat aplikasi jalan → tidak ada crash dan draf lama tetap ada; transaksi hasil draf masih dapat diedit/dihapus lewat FR-02.
    4.  **8d — Penutupan risiko.** Penanganan *service* yang dibunuh vendor + pemeriksaan status saat `notifyResumed()`, `EXPIRED` 30 hari, kap 500 baris, klaim jujur di UI ("hanya yang muncul setelah fitur aktif"), verifikasi build release tidak mendeklarasikan `INTERNET`.
        * *AC:* uji pembersihan & kapasitas; audit manual manifest + `flutter build apk` (tidak ada izin jaringan); **dokumentasikan bahwa distribusi tetap sideload pribadi** — pengajuan ke Play Store butuh peninjauan kebijakan *notification access* terpisah (§11) dan bukan bagian sprint ini.

---

## 11. Risiko & Mitigasi

| Risiko | Mitigasi |
| :--- | :--- |
| Data hilang karena uninstall/HP rusak (offline-only, tanpa akun) | FR-11 + reminder backup NFR-04; dokumentasikan di onboarding. |
| Drift antara cache `current_amount`/`paid_amount` vs Σ log | Recompute dalam transaction yang sama + test kesetaraan; kolom cache tidak pernah ditulis dari UI. |
| Soft reference tidak dijaga database | Enforcement di `LedgerService` + guard test; UNIQUE(`transaction_id`) mencegah link ganda. |
| Zona waktu membuat transaksi "pindah bulan" | Definisi epoch millis + filter lokal §4.2; dokumentasikan ke QA. |
| Scope creep multi-perangkat | Tegas out-of-scope §1.2; skema dibuat *backup-file friendly* agar sinkronisasi cloud bisa ditambahkan kelak tanpa mengubah ledger. |
| **FR-14:** format teks notifikasi aplikasi bayar berubah tanpa pemberitahuan (update DANA/GoPay/OVO/ShopeePay/BCA) | Aturan parse disimpan sebagai *rule pack* berversi (`rule_version`, §5.9) + fixture wajib per aplikasi (§3.2.4, Sprint 8a). Gagal parse = **dibuang**, bukan ditebak. Statistik `detected` vs `drafted` (§5.11) ditampilkan di Pengaturan supaya "fiturnya diam-diam mati" bisa dilihat pengguna. |
| **FR-14:** nominal atau arah dana terbaca salah → transaksi salah masuk ledger | Tidak ada auto-post sama sekali (§2.3.6); layar konfirmasi menampilkan nominal **yang dapat diedit** + pratinjau dampak saldo (§4.4.2); arah tidak pasti → **Terima** terkunci (V13); nota/memo draf ditandai `source='NOTIFICATION'` sehingga mudah disaring saat koreksi. |
| **FR-14:** satu pembayaran tercatat dua kali (notifikasi bank **dan** wallet) | UI memaksa pengguna memilih **satu** aplikasi sumber per metode bayar (§3.2.8); `dedup_key` UNIQUE (§4.4.1) untuk sumber yang sama; `likely_duplicate` (§4.4.3) untuk kembar beda sumber — ditandai, tidak dibuang diam-diam. |
| **FR-14:** notifikasi terlewat (aplikasi belum dipasang/belum ada izin, listener belum ter-*bind*, *service* dibunuh vendor) | Diterima sebagai batas desain, bukan bug: FR-02 manual tetap jalur utama dan tidak di-*deprecate*; status izin & "deteksi tidak aktif" selalu terlihat (Pengaturan + Inbox + cek saat `notifyResumed()`); tidak ada janji riwayat yang tidak bisa ditepati (§3.2.6). |
| **FR-14:** izin *Notification access* dibaca sebagai izin sensitif (kebijakan Play Store, persepsi pengguna) | Distribusi tetap sideload pribadi; **jangan** ajukan build ber-FR-14 ke Play Store tanpa meninjau kebijakan akses notifikasi. Redam risikonya: hanya paket yang dicentang yang diproses, `raw_snapshot` NULL di rilis, tidak ada izin `INTERNET`, tidak ada analitik (NFR-09). |
| **FR-14:** *plugin* notification-listener pihak ketiga membawa jaringan/telemetri atau berhenti di-*maintain* | *Default* = *platform channel* sendiri (§8). Bila paket dipakai, harus di-*vendor* + diaudit + di-*pin* versinya; tidak ada paket yang boleh menambah izin jaringan. |
| **FR-13:** pengguna lupa PIN → seluruh data tidak dapat diakses lagi | Sengaja tanpa pemulihan (§6.9). Mitigasi: peringatan risiko **sebelum** mengaktifkan kunci (§9.6) + pengingat backup FR-11/NFR-04; reset adalah satu-satunya jalan keluar dan itu harus tertulis jelas di dialog. |
| **FR-13:** salah paham "ada PIN = data terenkripsi" | Tulis jujur di tile Keamanan dan §3.1.4: PIN hanya gerbang UI; `.sqlite` dan file backup tetap teks terbuka. Arahkan pengguna melindungi file backup & layar kunci perangkat, bukan mengandalkan PIN aplikasi. |
| **FR-13:** biometrik berubah saat aplikasi di latar (sidik jari ditambah/dihapus di pengaturan sistem) | Status biometrik dibaca ulang setiap `notifyResumed()`, bukan hanya saat controller dibuat — supaya tombol "Sidik jari" tidak pernah menjanjikan hal yang tidak bisa dipakai (§3.1.1). |
| **FR-13:** auto-lock tidak memicu karena urutan *lifecycle* Android | Sudah terjadi dan sudah diperbaiki: `hidden` dikirim dua kali (sekali saat pergi, sekali sesaat sebelum `resumed`), sehingga waktu latar hanya boleh dicatat bila belum ada (`_backgroundedAt ??=`). Dijaga regression test eksplisit (§3.1.5) agar tidak kembali regresi. |
| **FR-13 + FR-14 bersama:** restore backup `.sqlite` di perangkat lain membuat pengguna terkunci oleh PIN lama | Kredensial sengaja tidak ikut file backup (§5.12): restore membuka data tanpa menuntut PIN lama, lalu pengguna dapat memasang kunci baru. Alur onboarding pasca-restore wajib mengulang tawaran "aktifkan kunci aplikasi". |
