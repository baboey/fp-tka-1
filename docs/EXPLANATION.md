# Penjelasan Arsitektur & Pemecahan Solusi Soal Final Project TKA 2026
## Order Processing Service (Flask + MongoDB + Nginx)

Dokumen ini menjelaskan rancangan arsitektur sistem proyek ini dan bagaimana setiap keputusan desain/teknis kita menjawab secara tepat semua syarat, kendala, dan instruksi yang diminta pada berkas [soal.md](file:///C:/Users/arya4/fp-tka-1/soal.md).

---

## 1. Desain Arsitektur Sistem (Menjawab Rubrik 1 — 20% Nilai)

Untuk menyelesaikan tantangan *Order Processing Service* yang andal, elastis, dan hemat biaya, arsitektur cloud dirancang dengan memisahkan fungsi komputasi (*stateless*) dari penyimpanan data (*stateful*).

### A. Diagram Hubungan Komponen (Docker Swarm Cluster)
Sesuai rancangan draw.io, hubungan antarkomponen saat dideploy adalah sebagai berikut:
```
           [ Komputer Tester / Locust ]  (Host terpisah dari server)
                         │
                         ▼ HTTP (Port 80)
┌────────────────────────────────────────────────────────┐
│                   1. VM Manager (N1)                   │ 
│  - NGINX Reverse Proxy & Load Balancer                 │ ──> Menyajikan FE statis &
│  - Caching Engine (Microcache 5 detik)                 │     caching API /products
└────────────────────────┬───────────────────────────────┘
                         │ routing mesh / overlay network
            ┌────────────┴────────────┐
            ▼                         ▼
┌───────────────────────┐ ┌───────────────────────┐
│   2. VM Worker (N2)   │ │   3. VM Worker (N3)   │ 
│ - Flask App Container │ │ - Flask App Container │ ──> Memproses logika bisnis
│   (Gunicorn 5w/4t)    │ │   (Gunicorn 5w/4t)    │     (Replicas: Scaled)
└───────────┬───────────┘ └───────────┬───────────┘
            │                         │
            └────────────┬────────────┘
                         ▼ Port 27017 (Private Net Only)
┌────────────────────────────────────────────────────────┐
│                  4. VM Database (N4)                   │ 
│  - MongoDB Standalone Container                        │ ──> Menyimpan data pengguna,
│  - Database Seed Dump & Auto-Indexing                  │     produk, & pesanan
└────────────────────────────────────────────────────────┘
```

### B. Penjelasan Peran Setiap VM (Separation of Concerns)
* **VM N1 (Nginx Load Balancer & Cache):** Bertindak sebagai gerbang terdepan (Reverse Proxy) yang memisahkan dan mengarahkan trafik. Nginx melayani berkas frontend statis secara langsung dan meng-cache data katalog produk publik agar tidak membebani server aplikasi.
* **VM N2 & N3 (Flask App Workers):** Berfungsi sebagai kluster Docker Swarm stateless yang menjalankan backend Flask dengan server Gunicorn. Droplet ini bertugas memproses komputasi logika bisnis yang berat (seperti pembuatan order dan enkripsi hashing).
* **VM N4 (Database MongoDB):** Didedikasikan khusus untuk MongoDB secara mandiri (*standalone*) dalam jaringan privat. Memisahkan I/O Disk database yang padat dari VM komputasi.

### C. Alasan Menggunakan Arsitektur Ini (Why this architecture?)
1. **Performa Tinggi saat Load Test:** Pemisahan VM database (**N4**) mencegah perebutan resource CPU antara pemrosesan Flask dan operasi baca/tulis disk database MongoDB. Selain itu, Nginx caching di **N1** memastikan ribuan request produk dilayani instan dari RAM.
2. **Skalabilitas & High Availability (HA):** Menggunakan kluster Docker Swarm di **N2 & N3** mempermudah penambahan replika backend secara dinamis (`docker service scale`) untuk meratakan trafik beban, serta memastikan sistem tidak mati jika salah satu server worker mengalami kegagalan.
3. **Efisiensi Biaya (Hemat Budget):** Docker Swarm sangat ringan dibanding Kubernetes yang membutuhkan spesifikasi master node yang mahal. Ini memungkinkan kita menyewa 4 droplet DO ekonomis dengan biaya total di bawah limit anggaran.

### D. Justifikasi Anggaran & Spesifikasi VM (Budget Constraint)
Syarat pada `soal.md` membatasi biaya sewa server maksimal **Rp 1.300.000 / bulan (≈ $75 USD)**. 
Kita memilih DigitalOcean (DO) dengan pembagian droplet sebagai berikut:
* **N1 (Manager & Nginx):** 1 vCPU, 2 GB RAM (vm3) = **$12 / bln**
* **N2 (Worker Flask 1):** 2 vCPU, 2 GB RAM (vm4) = **$18 / bln**
* **N3 (Worker Flask 2):** 2 vCPU, 2 GB RAM (vm4) = **$18 / bln**
* **N4 (Database MongoDB):** 2 vCPU, 4 GB RAM (vm5) = **$24 / bln**
* **Total Biaya Bulanan:** **$72 USD (≈ Rp 1.250.000)** (Lolos batas budget ≤ $75 USD ✓).

---

## 2. Cara Kita Menyelesaikan Syarat Soal (Menjawab Soal.md)

Berikut adalah bagaimana setiap instruksi khusus pada [soal.md](file:///C:/Users/arya4/fp-tka-1/soal.md) dipenuhi di dalam kode dan infrastruktur kita:

### A. Kompatibilitas REST API & Frontend (Soal Poin C)
* **Tantangan:** Soal menyediakan frontend bawaan (`index.html`/`styles.css`) yang memanggil `/order` (bukan `/orders` jamak) tanpa autentikasi token.
* **Solusi Kita:** Di dalam [server.py](file:///C:/Users/arya4/fp-tka-1/src/flask/server.py) baris 449-518, kita membuat **Compatibility Endpoints** (`POST /order`, `GET /order/<id>`, `PUT /order/<id>`) yang berjalan tanpa autentikasi agar frontend bawaan tetap berjalan 100% lancar, sementara endpoint canggih dengan token JWT (`/orders`, `/admin/stats`) digunakan untuk optimasi load testing Locust.

### B. Pemisahan Database dari App Server (Tips & Tricks Soal #5)
* **Tantangan:** Menyatukan database dan aplikasi dalam satu VM sering menyebabkan perebutan CPU saat agregasi data stat/laporan dijalankan.
* **Solusi Kita:** MongoDB diletakkan di VM terpisah (**N4**), terisolasi di dalam *private network*. VM aplikasi (**N2** & **N3**) berkomunikasi ke database melalui IP privat MongoDB. Port database 27017 ditutup dari publik demi keamanan.

### C. Mekanisme Reset Database Skenario Locust (Soal Poin D.3 & Tips #6)
* **Tantangan:** Di setiap skenario Locust, data transaksi dari skenario sebelumnya harus dihapus agar tidak terjadi akumulasi data yang memperlambat query `GET /orders`, tetapi **tidak diperkenankan** menghapus data awal bawaan (seperti daftar produk & akun user).
* **Solusi Kita:** Kita membuat script [reset_db.sh](file:///C:/Users/arya4/fp-tka-1/src/scripts/reset_db.sh). Script ini mengeksekusi perintah `mongorestore --drop /dump/` langsung ke kontainer MongoDB.
* **Hasil:** Perintah `--drop` akan membersihkan (*drop*) koleksi yang ada, lalu memulihkan database ke kondisi *seed data* awal yang asli (505 user, 96 produk, 10.000 order bawaan) tanpa menyisakan data sampah hasil uji Locust sebelumnya.

---

## 3. Penerapan Best Practice & Optimasi Performa Tinggi (Sudah Diimplementasikan)

Guna memastikan aplikasi kita mampu menembus target pengujian di Locust dengan tingkat kegagalan **0% failure**, empat teknik optimasi performa tinggi berikut telah diimplementasikan:

### A. Eksplorasi Indeksasi MongoDB (Tips & Tricks Soal #7)
Tanpa indeks, MongoDB harus memindai setiap dokumen (*Collection Scan*). Dengan data transaksi bawaan sebanyak 10.000 baris, query riwayat transaksi (`GET /orders`) akan lambat.
* **Implementasi (pada [init_db.sh](file:///C:/Users/arya4/fp-tka-1/src/scripts/init_db.sh)):** Kita membuat indeks setelah pemulihan database selesai:
  - Indeks unik pada `users.email` untuk mempercepat pencarian data user & login.
  - Indeks majemuk pada `products` untuk mempercepat pemuatan produk berdasarkan status aktif, kategori, harga, dan rating.
  - Indeks majemuk pada `orders` berdasarkan status dan ID pengguna untuk mempercepat query *history*.

### B. Optimasi Server Sebelum Scale-out (Tips & Tricks Soal #2)
* **Implementasi (pada [Dockerfile](file:///C:/Users/arya4/fp-tka-1/src/flask/Dockerfile) & [server.py](file:///C:/Users/arya4/fp-tka-1/src/flask/server.py)):**
  - Mengganti Flask *development server* (yang bersifat *single-threaded* bawaan python) dengan **Gunicorn WSGI Server** dengan konfigurasi 5 workers dan 4 threads (`gunicorn -w 5 -k gthread --threads 4`).
  - Menonaktifkan debug mode (`debug=False`) untuk menghindari penumpukan memori proses debug dan menutup celah keamanan.
  - Mengonfigurasi *Connection Pool* database MongoDB di Flask (`maxPoolSize=100`, `minPoolSize=10`) untuk menggunakan kembali koneksi database secara efisien.

### C. Nginx Microcaching (Tips & Tricks Soal #3)
Karena Locust mensimulasikan trafik yang *read-heavy* (membaca daftar produk via `GET /products`), Flask backend tidak perlu merespon request yang sama berulang kali dalam satu detik.
* **Implementasi (pada [nginx.conf](file:///C:/Users/arya4/fp-tka-1/src/nginx/nginx.conf)):** Nginx dikonfigurasi sebagai cache server dengan microcache berdurasi **5 detik** khusus untuk endpoint produk.
* **Efek:** Nginx menyimpan respon produk di memori RAM. Selama 5 detik, request yang masuk akan langsung dilayani oleh Nginx, membebaskan Flask dan database dari beban query katalog produk.

### D. Kompresi Payload Gzip
* **Implementasi (pada [nginx.conf](file:///C:/Users/arya4/fp-tka-1/src/nginx/nginx.conf)):** Mengaktifkan fitur kompresi `gzip on` di Nginx untuk mengecilkan ukuran data JSON dan berkas statis.
* **Efek:** Mengurangi lalu lintas bandwidth jaringan yang dikirimkan ke Locust, sehingga mempercepat waktu tunggu rata-rata (*average response time*).
