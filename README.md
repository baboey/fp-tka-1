# LAPORAN FINAL PROJECT TEKNOLOGI KOMPUTASI AWAN 2026
## Order Processing Service — Flask + MongoDB + Nginx (Docker Swarm)

> Plan kerja/handoff internal tim: [`docs/PLAN.md`](docs/PLAN.md). Soal: [`soal.md`](soal.md).

---

## 1. Introduction

### Latar Belakang
Dalam era *e-commerce* modern, performa backend pemrosesan pesanan (*Order Processing Service*) sangat menentukan kepuasan pelanggan. Layanan ini menangani pembuatan pesanan, pengecekan status, riwayat transaksi, serta pembaruan status. Lonjakan trafik tiba-tiba (flash sale, promo) menuntut infrastruktur yang andal, elastis, dan efisien biaya.

### Permasalahan
Sebagai Cloud Engineer, tantangannya adalah **mendeploy, mengonfigurasi, dan mengoptimalkan** backend *Order Processing Service* berbasis **Python (Flask)** dengan database **MongoDB** dan reverse proxy **Nginx**, dengan **budget maksimal ≈ Rp 1.300.000 (≈ $75 USD) per bulan**, agar mampu menerima request tertinggi secara stabil dengan tingkat kegagalan **0%** saat *load testing* (Locust).

### Anggota Kelompok & Pembagian Kerja

| No | Nama / NRP | Peran Utama | Kontribusi |
|----|------------|-------------|------------|
| 1 | [Nama Anggota 1] / [NRP 1] | **Team Lead & Cloud Architect** | Merancang arsitektur cloud, mengelola anggaran & spesifikasi VM, koordinasi fase deploy, *destroy resources*. |
| 2 | Thio Billy Amansyah / 5027231007 | **Backend Developer (Core)** | Menjaga paritas backend produksi (JWT Auth + Database), build image Flask. |
| 3 | [Nama Anggota 3] / [NRP 3] | **Backend & Security Engineer** | Membuat API kompatibilitas frontend & logika validasi token JWT, hardening endpoint. |
| 4 | [Nama Anggota 4] / [NRP 4] | **Nginx & Frontend Integrator** | Integrasi static asset, routing, *microcache*, strategi load balancing, isu CORS. |
| 5 | [Nama Anggota 5] / [NRP 5] | **Database Administrator (DBA)** | Seeding MongoDB, otomasi `mongorestore`, perancangan **index** query, `reset_db`. |
| 6 | [Nama Anggota 6] / [NRP 6] | **DevOps & Containerization** | Dockerfile (Gunicorn), `compose`/`stack.yaml` Swarm, Ansible, port-binding & registry. |
| 7 | Arya Bisma Putra Refman / 5027241036 | **QA & Load Tester (Locust)** | Pengujian Locust 5 skenario dari host terpisah, monitoring resource, dokumentasi RPS. |

---

## 2. Arsitektur Cloud

Karena beban uji **read-heavy** (mayoritas `GET /products`) dan nilai RPS penuh dicapai pada **±200 RPS dengan 0% failure**, fokus arsitektur kami adalah **keandalan (0% failure) + skalabilitas mudah**, bukan throughput ekstrem. Kami menempuh pendekatan **bertahap** (sesuai tips soal "mulai dari konfigurasi terkecil").

- **Fase 1 — Baseline:** 1 VM all-in-one (Docker Compose) untuk mengukur baseline & sebagai *fallback*/dev lokal.
- **Fase 2 — Optimasi single-VM:** Gunicorn + index MongoDB + Nginx *microcache*.
- **Fase 3 — Target (Docker Swarm):** tier *stateless* (Nginx + Flask) dijalankan sebagai Swarm services lintas node dengan replika yang mudah diskalakan; **MongoDB dijalankan standalone** (di luar Swarm) pada VM database — memisahkan *state* dari *compute*.

### A. Diagram Arsitektur (Target — Docker Swarm)
```
        [ User / Client ]        [ Locust — host TERPISAH ]
                 \                        /
                  v  HTTP :80            v
        +-------------------------------------+
        | Node Manager — Nginx (Swarm service)|  microcache + static FE +
        |  reverse proxy -> flask VIP         |  reverse proxy (routing mesh)
        +------------------+------------------+
                           | overlay network (VIP / routing mesh)
            +--------------+--------------+
            v                             v
   +-----------------+           +-----------------+
   | Worker — Flask  |           | Worker — Flask  |   docker service scale flask=N
   |  (Gunicorn) xN  |           |  (Gunicorn) xN  |
   +--------+--------+           +--------+--------+
             \   MONGO_URI = IP privat   /
              v                         v
        +-------------------------------------+
        | VM Database — MongoDB standalone    |  (Compose + init_db.sh: seed + index)
        | port 27017 hanya private network    |
        +-------------------------------------+
```

### B. Tabel Spesifikasi & Biaya — DigitalOcean (utama)
| Node | Peran | Spesifikasi (tier) | Harga/bln |
|------|-------|--------------------|-----------|
| N1 | Manager + Nginx (cache/LB/static) | 1 vCPU, 2 GB (vm3) | $12 |
| N2 | Worker — Flask (Gunicorn) | 2 vCPU, 2 GB (vm4) | $18 |
| N3 | Worker — Flask (Gunicorn) | 2 vCPU, 2 GB (vm4) | $18 |
| N4 | MongoDB standalone (private) | 2 vCPU, 4 GB (vm5) | $24 |
| **Total** | | | **$72 / bln (≤ $75) ✓** |

*Baseline (Fase 1) ~$24/bln; Swarm minimal (N1+N2+N4) ~$54/bln, lalu tambah N3 saat scale-out.*

### C. Tabel Spesifikasi & Biaya — Microsoft Azure (alternatif)
> Harga final wajib diverifikasi via **Azure Pricing Calculator**.

| Peran | SKU (perkiraan) | Harga/bln |
|-------|------------------|-----------|
| Nginx / manager | B1s (1 vCPU, 1 GB) | ~$8 |
| Flask × 2 | B1ms (1 vCPU, 2 GB) | ~$30 |
| MongoDB | B2s (2 vCPU, 4 GB) | ~$30 |
| **Total** | | **~$68 / bln (≤ $75)** |

### D. Alasan Pemilihan
- **Pisah DB dari app** mencegah kompetisi resource antara komputasi Flask & I/O MongoDB (agregasi `/admin/stats` berat).
- **Stateless di Swarm, DB di luar Swarm** memberi kemudahan *scaling* & *self-healing* untuk tier app tanpa kerumitan *stateful service* pada orkestrator.
- **Nginx microcache** untuk `GET /products` melayani mayoritas trafik tanpa menyentuh Flask/Mongo → kunci menembus 200+ RPS dengan 0% failure.

---

## 3. Implementasi

Deployment memakai **Docker** (Compose untuk baseline/DB, **Docker Swarm** untuk tier stateless) dengan otomasi **Ansible**.

### Struktur Repository
```
fp-tka-1/
├── README.md            ← laporan (file ini)
├── soal.md · LICENSE
├── docs/PLAN.md         ← plan internal tim
├── result/              ← screenshot Locust & resource
└── src/                 ← seluruh kode & konfigurasi
    ├── flask/   server.py, Dockerfile, requirements.txt
    ├── nginx/   nginx.conf, html/ (index.html, styles.css)
    ├── db/      dump/ (seed), README.md, generate_dump.py
    ├── locust/  locustfile.py
    ├── scripts/ init_db.sh, reset_db.sh, api.sh
    ├── ansible/ provision.yml, swarm.yml, deploy.yml, inventory.ini
    ├── compose.yaml
    └── stack.yaml       ← Docker Swarm
```
> Catatan: backend yang dijalankan `src/flask/server.py` merupakan pengembangan dari backend resmi soal (`app.py`), ditambah endpoint kompatibilitas `/order`, opsi akses `/orders`, dan health-check `/`.

### Langkah Konfigurasi (ringkas)
1. **Clone/Pull perubahan terbaru & masuk direktori**
   ```bash
   # Di VM, tarik commit terbaru jika sudah pernah clone
   git pull origin main
   cd src/
   ```
2. **Jalankan baseline lokal / Reset container**
   Jika container sudah berjalan sebelumnya, jalankan perintah berikut untuk menghentikan dan membangun ulang menggunakan Gunicorn dan perbaikan Nginx:
   ```bash
   docker compose down
   docker compose up -d --build
   ```
   Saat pertama kali dijalankan, [`scripts/init_db.sh`](src/scripts/init_db.sh) otomatis membuat user DB, menjalankan `mongorestore` (505 user, 96 produk, 10.000 order), lalu membuat **index**.
3. **Reset Database Uji (Locust)**
   Untuk mereset akumulasi data transaksi (order) hasil load testing kembali ke data awal tanpa mematikan container, jalankan:
   ```bash
   chmod +x scripts/reset_db.sh
   ./scripts/reset_db.sh
   ```
4. **Optimasi performa**
   - **Gunicorn** (ganti Flask dev server) di [`flask/Dockerfile`](src/flask/Dockerfile): `gunicorn -w 5 -k gthread --threads 4`.
   - **Index MongoDB** pada `users.email` (unique), `products`, `orders`, `audit_logs`.
   - **Nginx microcache** `GET /products` di [`nginx/nginx.conf`](src/nginx/nginx.conf) + `gzip` + `keepalive`.
5. **Deploy Docker Swarm (cloud)** — diotomasi Ansible:
   ```bash
   ansible-playbook -i ansible/inventory.ini ansible/provision.yml ansible/swarm.yml ansible/deploy.yml
   ```
   MongoDB dijalankan standalone di VM DB; image Flask di-push ke registry; `nginx.conf` dikirim via `docker config`; scale via `docker service scale flask=N`.

> [!NOTE]
> **[TODO: lampirkan screenshot setiap langkah konfigurasi/provisioning di VM]**

---

## 4. Hasil Pengujian Endpoint

> [!NOTE]
> **[TODO: jalankan aplikasi, ambil screenshot Postman tiap endpoint & tampilan web]**

Target URL `http://localhost/` atau `http://<IP_VM>/`:

1. **Registrasi** — `POST /auth/register` → `[screenshot]`
2. **Login** — `POST /auth/login` (mengembalikan JWT) → `[screenshot]`
3. **Katalog Produk** — `GET /products` → `[screenshot]`
4. **Buat Order** — `POST /orders` (dengan token, mengurangi stok) → `[screenshot]`
5. **Detail/Status Order** — `GET /orders/<id>` → `[screenshot]`
6. **Update Status** — `PUT /orders/<id>/status` (admin) → `[screenshot]`
7. **Dashboard Admin** — `GET /admin/stats` → `[screenshot]`
8. **Compat (frontend sederhana)** — `POST/GET/PUT /order` → `[screenshot]`
9. **Antarmuka Frontend Web** — tampilan browser → `[screenshot]`

---

## 5. Hasil Load Testing (Locust)

> [!NOTE]
> **[TODO: jalankan Locust dari host TERPISAH; isi RPS/Concurrency aktual + screenshot grafik & resource]**

Pengujian memakai [`src/locust/locustfile.py`](src/locust/locustfile.py) dari host eksternal. **Database direset (`reset_db.sh`) sebelum setiap skenario** untuk menghapus data insert-an tanpa menghilangkan seed awal.

| No | Skenario | Parameter | Durasi | Hasil (RPS / User) | Failure |
|----|----------|-----------|--------|--------------------|---------|
| 1 | Maksimum RPS | Naikkan user bertahap | 60s | `[RPS puncak]` | `[0%]` |
| 2 | Peak Concurrency (Spawn 50) | Naikkan hingga failure | 60s | `[Max user]` | `[0%]` |
| 3 | Peak Concurrency (Spawn 100) | Naikkan hingga failure | 60s | `[Max user]` | `[0%]` |
| 4 | Peak Concurrency (Spawn 200) | Naikkan hingga failure | 60s | `[Max user]` | `[0%]` |
| 5 | Peak Concurrency (Spawn 500) | Naikkan hingga failure | 60s | `[Max user]` | `[0%]` |

- **Grafik RPS & Response Time:** `[screenshot Locust]`
- **Utilisasi Resource (CPU/Memory):** `[screenshot htop saat pengujian]`

---

## 6. Kesimpulan dan Saran

### Kesimpulan
- Mengganti Flask dev server dengan **Gunicorn** + menambah **index MongoDB** + **Nginx microcache** adalah kunci mencapai RPS tinggi dengan **0% failure** pada beban read-heavy.
- **Memisahkan MongoDB (stateful) dari tier app (stateless)** menjaga performa CPU backend stabil saat agregasi DB berat berjalan, dan menyederhanakan orkestrasi Swarm.
- **Docker Swarm** memudahkan *scale-out* (`docker service scale`) & *self-healing* tanpa biaya cluster tambahan.

### Saran untuk Deployment Nyata
1. **Caching lanjutan**: Redis untuk cache katalog/produk lintas instance.
2. **MongoDB Replica Set**: untuk *high availability* & pembacaan dari secondary.
3. **Infrastructure as Code**: Terraform untuk provisioning VM/LB/firewall.
4. **Auto-scaling**: scaling otomatis tier app saat utilisasi CPU > 70%.
