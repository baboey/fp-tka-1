# LAPORAN FINAL PROJECT TEKNOLOGI KOMPUTASI AWAN 2026
## Order Processing Service (Backend Flask + MongoDB + Nginx Proxy)

---

## 1. Introduction

### Latar Belakang
Dalam era *e-commerce* modern, performa backend dalam memproses pesanan (*Order Processing Service*) merupakan komponen krusial yang menentukan kepuasan pelanggan. Layanan ini bertanggung jawab atas pembuatan pesanan baru, pengecekan status pesanan, pengelolaan riwayat transaksi, serta pembaruan status pesanan. Lonjakan trafik tiba-tiba, seperti saat program promo atau *flash sale*, menuntut infrastruktur yang andal, elastis, dan efisien secara biaya.

### Permasalahan
Sebagai Cloud Engineer, tantangannya adalah merancang, mendeploy, dan mengoptimalkan backend **Order Processing Service** berbasis **Python (Flask)** dengan database **MongoDB** dan reverse proxy **Nginx**. Infrastruktur yang dirancang harus memiliki stabilitas tinggi dengan **budget maksimal Rp 1.300.000 (≈ $75 USD) per bulan**, serta mampu menghadapi pengujian beban (*load testing*) menggunakan Locust dengan tingkat kegagalan (*failure*) 0%.

### Anggota Kelompok & Pembagian Kerja

Berikut adalah daftar anggota kelompok beserta pembagian tanggung jawab dalam pengerjaan Final Project ini:

| No | Nama / NRP | Peran Utama | Deskripsi Kontribusi / Pembagian Kerja |
|----|------------|-------------|----------------------------------------|
| 1  | [Nama Anggota 1] / [NRP 1] | **Team Lead & Cloud Architect** | Merancang keseluruhan arsitektur cloud, mengelola alokasi anggaran, dan menyusun spesifikasi VM. |
| 2  | [Nama Anggota 2] / [NRP 2] | **Backend Developer (Core)** | Melakukan migrasi kode backend produksi utama yang terintegrasi dengan JWT Auth dan Database. |
| 3  | [Nama Anggota 3] / [NRP 3] | **Backend & Security Engineer** | Membuat API kompatibilitas frontend unauthenticated dan merancang logika validasi token JWT. |
| 4  | [Nama Anggota 4] / [NRP 4] | **Nginx & Frontend Integrator** | Mengintegrasikan static asset frontend ke server Nginx, merekayasa routing, dan menyelesaikan isu CORS. |
| 5  | [Nama Anggota 5] / [NRP 5] | **Database Administrator (DBA)** | Mengatur seeding database MongoDB, mengoptimasi skrip `mongorestore` otomatis, dan merancang indeks query. |
| 6  | [Nama Anggota 6] / [NRP 6] | **DevOps & Containerization** | Mengembangkan berkas Dockerfile, menyusun konfigurasi `docker-compose.yaml`, dan memanage port-binding lokal/cloud. |
| 7  | [Nama Anggota 7] / [NRP 7] | **QA & Load Tester (Locust)** | Menyiapkan pengujian Locust, menjalankan pengujian untuk 5 skenario beban puncak, dan mendokumentasikan performa RPS. |

---


## 2. Arsitektur Cloud

Untuk mencapai performa optimal dengan budget di bawah $75/bulan, kami merekomendasikan pemisahan VM Aplikasi dan VM Database (*Decoupled Architecture*). Hal ini mencegah persaingan *resource* antara komputasi Flask dan manajemen I/O tulis/baca MongoDB.

### A. Diagram Arsitektur Cloud (Rekomendasi)
```
                  [ User / Client ]
                         │
                         ▼ (HTTP - Port 80)
            ┌──────────────────────────┐
            │   VM 1: Web & App Server │
            │ ┌──────────────────────┐ │
            │ │      Nginx Proxy     │ │
            │ └──────────┬───────────┘ │
            │            │             │
            │ ┌──────────▼───────────┐ │
            │ │    Flask Backend     │ │
            │ └──────────┬───────────┘ │
            └────────────┼─────────────┘
                         │ (MongoDB Protocol - Port 27017)
                         ▼
            ┌──────────────────────────┐
            │   VM 2: Database Server  │
            │ ┌──────────────────────┐ │
            │ │       MongoDB        │ │
            │ └──────────────────────┘ │
            └──────────────────────────┘
```

### B. Tabel Spesifikasi & Biaya VM (Estimasi DigitalOcean / GCP)

| No | Komponen | Spesifikasi VM | Harga/Bulan | Fungsi |
|----|----------|----------------|-------------|--------|
| 1  | **VM 1: Web & App** | 1 vCPU, 2 GB RAM (Tipe vm3) | $12.00 | Menjalankan Nginx (Frontend statis & Reverse Proxy) dan Flask Backend. |
| 2  | **VM 2: Database** | 2 vCPU, 2 GB RAM (Tipe vm4) | $18.00 | Dedicated Database Server MongoDB untuk query performa tinggi. |
| **Total** | | | **$30.00 / bulan** (~Rp 500.000) | Sangat hemat dan di bawah batas budget $75/bulan. |

---

## 3. Implementasi

Aplikasi ini dideploy menggunakan kontainerisasi **Docker Compose** untuk memastikan konsistensi lingkungan antara lokal dan cloud.

### Langkah-Langkah Konfigurasi & Provisioning

1.  **Clone Repositori & Masuk Direktori**:
    ```bash
    git clone <url-repo-kelompok>
    cd fp-tka-1/src
    ```

2.  **Menyusun Struktur File**:
    *   `src/flask/server.py`: Backend Flask (JWT, Produk, Order, & Admin Stats).
    *   `src/nginx/nginx.conf`: Konfigurasi reverse proxy.
    *   `src/nginx/html/`: Direktori file statis frontend (`index.html`, `styles.css`).
    *   `src/db_dump/orderdb/`: Database dump awal yang memuat data inisiasi.

3.  **Menjalankan Docker Compose**:
    ```bash
    docker compose up -d --build
    ```

4.  **Inisialisasi Database Otomatis**:
    Saat container pertama kali dijalankan, script [`init_db.sh`](file:///c:/Users/arya4/fp-tka-1/src/scripts/init_db.sh) akan dieksekusi secara otomatis untuk:
    *   Membuat user database baru dengan kredensial aman.
    *   Menjalankan `mongorestore` untuk mengimpor 10.000 order, 505 user, dan 96 produk ke database `orderdb`.

---

## 4. Hasil Pengujian Endpoint

Seluruh API Endpoint utama telah diuji menggunakan Postman/curl dan bekerja dengan sukses:

1.  **Registrasi (`POST /auth/register`)**: Berhasil mendaftarkan user baru dan mengembalikan token JWT.
2.  **Login (`POST /auth/login`)**: Autentikasi user dan admin dengan pengembalian token JWT.
3.  **Katalog Produk (`GET /products`)**: Mengembalikan list katalog produk secara paginated dan terurut.
4.  **Buat Order (`POST /orders`)**: Membuat order berautentikasi (JWT) disertai pengecekan stok produk secara real-time.
5.  **Dashboard Admin (`GET /admin/stats`)**: Menghitung statistik pendapatan, produk terlaris, dan agregasi data bulanan.
6.  **Antarmuka Frontend**: Menampilkan UI sederhana yang responsif pada `http://localhost/` untuk membuat pesanan dan melihat riwayat data secara instan.

---

## 5. Hasil Load Testing (Locust)

Pengujian beban dilakukan menggunakan Locust dengan script [`locustfile.py`](file:///c:/Users/arya4/fp-tka-1/Keterangan%20Final%20Project%20TKA/Resources/Test/locustfile.py) dari host eksternal untuk menghindari bias resource:

| No | Skenario | Parameter | Durasi | Target Hasil |
|---|---|---|---|---|
| 1 | Maksimum RPS | Naikkan user bertahap | 60s | Mencari RPS puncak dengan 0% failure |
| 2 | Peak Concurrency (Spawn 50) | Naikkan user hingga failure | 60s | Concurrency puncak sebelum failure |
| 3 | Peak Concurrency (Spawn 100) | Naikkan user hingga failure | 60s | Concurrency puncak sebelum failure |
| 4 | Peak Concurrency (Spawn 200) | Naikkan user hingga failure | 60s | Concurrency puncak sebelum failure |
| 5 | Peak Concurrency (Spawn 500) | Naikkan user hingga failure | 60s | Concurrency puncak sebelum failure |

*(Catatan: Grafik performa RPS, response time, dan utilitas CPU/Memory akan di-upload ke folder `result/` setelah pengujian beban pada cloud selesai).*

---

## 6. Kesimpulan dan Saran

### Kesimpulan
*   Implementasi decoupled architecture (memisahkan database dari application server) terbukti menjaga performa CPU backend tetap stabil ketika query agregasi database berat sedang berjalan.
*   Penerapan Nginx sebagai reverse proxy memangkas overhead pemrosesan file statis oleh Flask, sehingga Flask bisa fokus menangani komputasi API JWT dan pesanan.

### Saran untuk Deployment Nyata
1.  **Caching**: Gunakan Redis untuk melakukan caching katalog produk (`GET /products`) guna mengurangi beban read pada MongoDB.
2.  **Database Indexing**: Buat indeks tambahan pada field `created_at` dan `status` di MongoDB untuk mempercepat query list order history.
3.  **Horizontal Auto-Scaling**: Terapkan auto-scaling group di cloud provider untuk VM Backend jika utilisasi CPU melebihi 70%.
