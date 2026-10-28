# Product Requirements Document (PRD)

**Nama Proyek:** Aplikasi Manajemen Keuangan Pribadi (DompetKu)
**Package Flutter:** `dompetku`
**Platform:** Android & iOS (Flutter Framework)
**Arsitektur Penyimpanan:** Offline-First (Local Relational Database)
**Versi Dokumen:** 1.2
**Status:** Siap implementasi (semua blocker logika ledger sudah dikunci)

---

## Riwayat Perubahan

| Versi | Tanggal | Perubahan |
| :--- | :--- | :--- |
| 1.0 | — | Draft awal PRD. |
| 1.1 | — | Penambahan Auto-Sync Saldo Utama (mode single ledger). |
| 1.2 | 2026-10-26 | Revisi hasil review: aturan read-only transaksi otomatis, pemisahan ringkasan manual vs otomatis, saldo awal, validasi lengkap, klarifikasi FK/soft reference, derived state, strategi hapus goal/hutang, indeks & skema migrasi, modul kategori, kebutuhan non-fungsional, acceptance criteria per sprint. |

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
*   **Out-of-Scope (Versi 1.0):**
    *   Integrasi mutasi bank otomatis (*Open Banking API*).
    *   Sinkronisasi *cloud* multi-perangkat & sistem *login*.
    *   Multi-mata uang.

---

## 2. Aturan Bisnis & Integrasi Saldo Otomatis (Auto-Deduct Logic)

Inti aplikasi ini adalah **Sistem Buku Besar Tunggal (*Single Ledger System*)**: Saldo Utama adalah hasil penjumlahan seluruh baris pada tabel `transactions`. Modul Tabungan dan Hutang/Piutang **tidak pernah mengubah saldo secara langsung**; mereka hanya membuat/menghapus transaksi otomatis yang bermata dua (*linked*) dengan log sumbernya.

### 2.1 Tabel Efek Aksi

| Aksi Pengguna pada Modul | Efek pada Modul Terkait | Efek Otomatis pada Saldo Utama | Kategori Transaksi Otomatis |
| :--- | :--- | :--- | :--- |
| **Setor ke Tabungan (*Top-up*)** | `saving_logs` DEPOSIT baru; saldo goal bertambah (`+`) | **Berkurang (`-`)** | `SAVING_DEPOSIT` (tipe `EXPENSE`) |
| **Tarik dari Tabungan (*Withdraw*)** | `saving_logs` WITHDRAW baru; saldo goal berkurang (`-`) | **Bertambah (`+`)** | `SAVING_WITHDRAW` (tipe `INCOME`) |
| **Mencatat Hutang Baru** *(kita meminjam)* | Record `debts` PAYABLE baru | **Bertambah (`+`)** *hanya jika* "uang diterima di dompet" dicentang (default: ya) | `DEBT_DISBURSEMENT` (tipe `INCOME`) |
| **Bayar / Cicil Hutang** | `debt_payments` baru; sisa hutang berkurang (`-`) | **Berkurang (`-`)** | `DEBT_PAYMENT` (tipe `EXPENSE`) |
| **Mencatat Piutang Baru** *(orang meminjam ke kita)* | Record `debts` RECEIVABLE baru | **Berkurang (`-`)** — uang pasti keluar saat kita meminjamkan | `RECEIVABLE_DISBURSEMENT` (tipe `EXPENSE`) |
| **Terima Cicilan Piutang** | `debt_payments` baru; sisa piutang berkurang (`-`) | **Bertambah (`+`)** | `RECEIVABLE_REPAYMENT` (tipe `INCOME`) |
| **Saldo Awal / Penyesuaian** | — | Naik/turun sesuai nominal yang diinput | `INITIAL_BALANCE` / `ADJUSTMENT` |

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

### 5.7 Klarifikasi Relasi (mengganti klaim v1.1)
* Klaim v1.1 "relasi *Foreign Key* pada tabel `transactions`" **diperbaiki**: `transactions` **tidak memiliki FK ke modul sumber** karena sifatnya polimorfik (`reference_type` + `reference_id` = *soft reference*). Yang berupa FK asli adalah arah sebaliknya: `saving_logs.transaction_id` dan `debt_payments.transaction_id` → `transactions.id`.
* **Integritas soft reference dijaga oleh service layer**, bukan database:
  * Tidak boleh menghapus baris `saving_logs`/`debt_payments` tanpa menghapus transaksi yang dirujuknya (dilakukan dalam transaction yang sama).
  * Tidak boleh menghapus `transactions` dengan `reference_type != 'MANUAL'` dari jalur publik (V8); satu-satunya penghapusan sah adalah lewat modul sumber.
* ON DELETE CASCADE pada FK `transaction_id` tetap dipasang sebagai safety net; namun service tidak boleh mengandalkannya karena bisa memutus link log → saldo (§2.3.5).

### 5.8 Migrasi
* `schemaVersion` Drift dimulai dari **1**. Setiap rilis dengan perubahan skema menaikkan versi dan menulis `MigrationStrategy` (`up`/`down` bila mungkin) yang **menjaga data pengguna**.
* Upgrade dari skema v1.1 (eksperimental, bila ada build lama): migrasi `up` membuat tabel `categories`, mengisi seed, memetakan `transactions.category` TEXT → `category_id`.
* Dilarang menghapus kolom/tabel tanpa migrasi.

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

---

## 7. Kebutuhan Non-Fungsional (baru)

| ID | Kategori | Persyaratan |
| :--- | :--- | :--- |
| NFR-01 | Performa | Cold start < 2 detik di perangkat kelas menengah. Query dashboard (agregasi saldo, ringkasan bulan) harus memakai indeks §5 dan SQL `SUM`, bukan iterasi seluruh baris di Dart. Render dashboard < 500 ms untuk 10.000 transaksi. |
| NFR-02 | Platform | Min. Android API 23 (6.0), iOS 13. Mendukung *dark mode* sistem. Orientasi portrait (keyboard input). |
| NFR-03 | Keandalan | Tidak ada jalur UI yang menghasilkan Saldo Utama tidak konsisten dengan Σ transaksi (diuji lewat property test, §9). Semua operasi multi-write memakai `db.transaction()`. |
| NFR-04 | Data & Privasi | 100% lokal, tanpa jaringan, tanpa akun. Risiko: uninstall/ganti HP menghapus data → **FR-11 backup/restore** menjadi pelindung wajib; tampilkan reminder backup bila belum pernah backup > 30 hari dan ada ≥ 20 transaksi. |
| NFR-05 | Kualitas | Coverage unit test untuk ledger service ≥ 90%; integration test untuk alur setor/tarik/cicilan terhadap DB Drift in-memory. |
| NFR-06 | Aksesibilitas | Teks nominal menggunakan `tabularFigures`; target sentuh ≥ 48 dp; label form memakai semantics; kontras warna saldo mengikuti tema. |
| NFR-07 | Penerjemahan | UI string memakai `intl` ARB (infrastruktur disiapkan sejak awal) walaupun rilis 1.0 hanya Bahasa Indonesia. |

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
      features/
        dashboard/    (presentation + providers)
        transactions/
        savings/
        debts/
        categories/
        settings/     (backup/restore, saldo awal, penyesuaian)
    ```
*   **State:** `flutter_riverpod` dengan `StreamProvider` di atas query Drift (watch). Semua angka saldo berasal dari stream agregasi sehingga UI refresh real-time setelah ledger transaction commit.
*   **Ledger service (jantung aplikasi):** satu `LedgerService` yang menjadi **satu-satunya** jalur tulis ke tabel yang memengaruhi saldo. API-nya (indikatif):
    * `addManualTransaction`, `updateManualTransaction`, `deleteManualTransaction`
    * `createSavingsGoal`, `depositToSavings`, `withdrawFromSavings`, `deleteSavingLog`, `deleteSavingsGoal(withLogs:)`, `archiveSavingsGoal`
    * `createDebt(withDisbursement:)`, `payDebt`, `deleteDebtPayment`, `deleteDebt(withPayments:)`, `archiveDebt`
    * `adjustBalance`, `setInitialBalance`
    Setiap method: validasi §4.3 → `db.transaction()` → tulis log + transaction + refresh cache derived.
*   **Package:** `drift` + `sqlite3_flutter_libs`, `drift_flutter`/`build_runner`, `flutter_riverpod`, `intl`, `fl_chart`, `go_router`, `file_picker` / `share_plus` + `path_provider` (FR-11).

---

## 9. Rancangan Antarmuka (UI/UX)

1.  **Dashboard (Tab 1):** Kartu Saldo Utama Aktif + sub-info "Total Aset di Tabungan"; kartu **Net Worth**; bar "Pemasukan vs Pengeluaran bulan ini (manual saja)"; dua chip kecil "Alokasi Tabungan: Rp…" / "Cicilan dibayar: Rp…"; pie chart pengeluaran per kategori (FR-12); daftar pengingat jatuh tempo ≤ 7 hari (hutang *dan* piutang, dengan label jenis).
2.  **Transaksi (Tab 2):** daftar kronologis dengan badge sumber untuk transaksi otomatis (ikon celengan/buku) **tanpa** tombol edit/hapus; tap pada item otomatis membuka detail *read-only* dengan tombol "Buka di modul sumber". Sheet filter bulan/tipe/sumber/kategori.
3.  **Tabungan (Tab 3):** kartu goal + progress bar (+100% badge "Terlampaui"); bottom sheet Setor/Tarik menampilkan "Tersedia: Rp …" dan validasi V1/V3; layar detail goal berisi riwayat log dengan aksi hapus (pengembalian saldo) dan konfirmasi §6.6.
4.  **Hutang & Piutang (Tab 4):** tab switcher **Hutang Saya | Piutang**; form baru PAYABLE memuat checkbox §2.2; item menampilkan sisa + due date; dialog "Bayar/Cicil" dengan validasi V2/V4; layar detail berisi riwayat cicilan + hapus.
5.  **Pengaturan:** Kelola Kategori (FR-10), Set Saldo Awal / Penyesuaian Saldo (FR-09), Backup & Restore (FR-11), Tentang.

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

---

## 11. Risiko & Mitigasi

| Risiko | Mitigasi |
| :--- | :--- |
| Data hilang karena uninstall/HP rusak (offline-only, tanpa akun) | FR-11 + reminder backup NFR-04; dokumentasikan di onboarding. |
| Drift antara cache `current_amount`/`paid_amount` vs Σ log | Recompute dalam transaction yang sama + test kesetaraan; kolom cache tidak pernah ditulis dari UI. |
| Soft reference tidak dijaga database | Enforcement di `LedgerService` + guard test; UNIQUE(`transaction_id`) mencegah link ganda. |
| Zona waktu membuat transaksi "pindah bulan" | Definisi epoch millis + filter lokal §4.2; dokumentasikan ke QA. |
| Scope creep multi-perangkat | Tegas out-of-scope §1.2; skema dibuat *backup-file friendly* agar sinkronisasi cloud bisa ditambahkan kelak tanpa mengubah ledger. |
