# PLAN INTERNAL — Final Project TKA 2026 (Order Processing Service)

> Dokumen kerja/handoff tim. Laporan publik ada di [`README.md`](../README.md). Soal: [`soal.md`](../soal.md).

## Ringkasan & Target

Deploy **Order Processing Service** (Flask + MongoDB + Nginx) ke cloud, budget ≤ $75/bln. Penilaian: Arsitektur 20%, Implementasi & uji endpoint 20%, **Load Testing Locust 35%**, Dokumentasi 25%.

**Insight penentu strategi:**
- Nilai RPS = `(RPS / 200) × 30` → **~200 RPS @0% failure = nilai penuh**. Target = lewati 200 RPS dengan **0% failure + headroom**, bukan throughput ekstrem.
- Beban Locust **read-heavy**: `user{1..50}@example.com` tak ada di dump → mayoritas `GET /products`; hanya admin (`admin1..5@tka.its.ac.id`) login sukses → `/admin/stats`. **Prioritas optimasi: `/products` lalu `/admin/stats`.**

## Keputusan Desain
- **Provider:** DigitalOcean (utama) + opsi **Azure** di tabel biaya.
- **Folder:** konsolidasi ke **`src/`** (single source of truth); `Resources/` dihapus pasca-migrasi file uniknya (locustfile, DB docs).
- **Orkestrasi:** **Docker Swarm** untuk tier stateless (Nginx+Flask) + **MongoDB standalone** di VM DB + **Compose 1-VM** sebagai baseline & fallback/lokal.
- **Optimasi:** Nginx microcache + index Mongo + tuning gunicorn. (Redis & Mongo replica-set → hanya "Saran" laporan.)
- **Otomasi:** **Ansible** (Terraform = future).
- **Locust:** dijalankan **apa adanya** (read-heavy; jujur & RPS maksimal).

## Hubungan kode (lineage)
`src/flask/server.py` = backend resmi (`app.py` dari soal) **+ ekstensi tim**:
- Compat endpoint `/order` (POST/GET/PUT) untuk frontend sederhana — *kontribusi Anggota 3*
- `GET /orders` optional-auth, helper `get_auth_user()`, `GET /` health-check DB
- ⚠️ Yang perlu dibenahi: `GET /orders` tanpa token mengembalikan **semua order** (dokumen penuh, tanpa limit/proyeksi) → beri limit/proyeksi; set `debug=False`.

---

## Fase 0 — Repo Restructure ✅ (selesai)
- Migrasi `Resources/Test/locustfile.py` → `src/locust/`; `Resources/DB/{README.md,generate_dump.py}` → `src/db/`; rename `db_dump` → `src/db/dump`.
- Hapus `Resources/`; pulihkan `LICENSE`; buat `result/`; mount compose `./db/dump`.
- `README.md` = laporan; `docs/PLAN.md` = plan internal (file ini); `plan.md` dihapus.
- Catatan: jangan taruh file di folder bernama `test/` (ke-ignore oleh `.gitignore`) → pakai `src/locust/`.

## Fase 1–3 — Arsitektur bertahap (Arsitektur 20%)
- **Fase 1 Baseline (Compose, 1 VM):** nginx+flask+mongo. Ukur RPS awal. *Juga fallback & dev lokal.*
- **Fase 2 Optimasi single-VM:** gunicorn + index + microcache. Ukur ulang.
- **Fase 3 Swarm (target):** Mongo standalone di VM DB; Nginx+Flask Swarm services lintas node; `docker service scale flask=N`.

### Biaya — DigitalOcean (basis tier soal)
| Node | Peran | Spek | $/bln |
|---|---|---|---|
| N1 | Manager + Nginx (cache/LB/static) | 1vCPU/2GB (vm3) | 12 |
| N2 | Worker — Flask gunicorn | 2vCPU/2GB (vm4) | 18 |
| N3 | Worker — Flask gunicorn | 2vCPU/2GB (vm4) | 18 |
| N4 | MongoDB standalone (private) | 2vCPU/4GB (vm5) | 24 |
| **Total** | | | **$72 ≤ $75 ✓** |
Baseline ~$24; Swarm minimal (N1+N2+N4) ~$54.

### Biaya — Azure (verifikasi Pricing Calculator)
Nginx B1s ~$8 + Flask×2 B1ms ~$30 + Mongo B2s ~$30 = **~$68 ≤ $75**.

## Perubahan Teknis (Implementasi 20% + pendukung RPS 35%)

**2a. Gunicorn** — `src/flask/Dockerfile`: ganti `CMD ["python3","server.py"]` →
```
CMD ["gunicorn","-w","5","-k","gthread","--threads","4","--worker-connections","1000","-b","0.0.0.0:9091","--access-logfile","-","server:app"]
```
Tuning `-w`≈`2*vCPU+1`; uji `-k gevent`.

**2b. Index MongoDB** — `src/scripts/init_db.sh` (createIndex setelah mongorestore):
- `users`: `{email:1}` **unique**, `{role:1,is_active:1}`
- `products`: `{is_active:1,created_at:-1}`, `{is_active:1,category:1,created_at:-1}`, `{is_active:1,price:1}`, `{is_active:1,rating:-1}`
- `orders`: `{order_id:1}` unique, `{created_at:-1}`, `{user_id:1,created_at:-1}`, `{status:1,created_at:-1}`
- `audit_logs`: `{created_at:-1}`

**2c. Nginx microcache + LB** — `src/nginx/nginx.conf`: `proxy_cache` `GET /products` & `/products/<id>` (TTL 5–10 dtk) + header `X-Cache-Status`; `upstream`+`keepalive`; di Swarm proxy ke VIP `http://flask:9091`; bandingkan `round-robin` vs `least_conn`; `gzip on`; naikkan `worker_connections`.

**2d. Backend & deploy:** fix `GET /orders` unauth (limit/proyeksi); `debug=False`; `MongoClient(maxPoolSize=...)`. Swarm: build+push image ke Docker Hub public; `nginx.conf` via `docker config`; `flask` service `deploy.replicas` + `MONGO_URI=...@<IP_PRIVAT_DB>`; **Mongo standalone (di luar stack)**, port 27017 hanya private net.

## Otomasi — Ansible (`src/ansible/`)
- `provision.yml` (install Docker), `swarm.yml` (init+join+`docker config`), `deploy.yml` (build+push, `docker stack deploy`, Mongo+seed), `inventory.ini`.

## Load Testing (35%)
- Locust **dari host terpisah** (`src/locust/locustfile.py`).
- Reset DB tiap skenario: `src/scripts/reset_db.sh` → `mongorestore --drop` dari `src/db/dump`.
- 5 skenario (apa adanya): (1) max RPS bertahap 0% failure; (2–5) spawn 50/100/200/500 → naikkan hingga failure, catat user terakhir 0% failure. Pakai `docker service scale flask=N`.
- Monitoring `htop`/`vmstat` → screenshot ke `result/`.

## Uji Endpoint (20%)
Postman: `POST /auth/register`, `/auth/login`, `GET /products`, `POST /orders` (token), `GET /orders`, `GET /orders/<id>`, `PUT /orders/<id>/status`, `GET /admin/stats`, + compat `/order`. Plus screenshot frontend.

## Pembagian Kerja (7 anggota)
| Anggota | Peran | Deliverable |
|---|---|---|
| 1 Team Lead & Architect | Arsitektur (20%) | Provision VM DO (+Azure), diagram draw.io, tabel biaya, koordinasi, **destroy resources** |
| 2 Backend Core | Impl backend | Paritas `server.py`↔`app.py`, JWT, build image |
| 3 Backend & Security | Compat + security | Compat `/order`, fix `/orders` unauth, hardening token, bantu uji Postman |
| 4 Nginx & Frontend | Nginx (impl+RPS) | microcache, upstream/`least_conn`, keepalive, gzip, static FE, `docker config` |
| 5 DBA | DB (impl+RPS) | index `init_db.sh`, `reset_db.sh`, Mongo standalone, connection-pool, `src/db/` |
| 6 DevOps | Container+Swarm (impl+RPS) | gunicorn, `stack.yaml`, registry, Ansible, private-net DB |
| 7 QA & Load Tester | Locust (35%) | host terpisah, 5 skenario, `service scale`, monitoring, screenshot & analisis |
Dokumentasi (25%) = bersama; dikompilasi Team Lead ke README.

## Verifikasi
1. Repo bersih; `src/locust/locustfile.py` ter-track; tak ada dump kembar.
2. `docker compose up -d --build` → `/health` 200, frontend di `localhost`, login admin, `/admin/stats` ada data.
3. Index: `getIndexes()` & `explain()` → IXSCAN.
4. Gunicorn aktif (bukan dev server); microcache → `X-Cache-Status: HIT`.
5. Swarm: stack deploy, `service scale`, self-healing.
6. RPS tiap fase; target ≥200 @0% failure + headroom. `reset_db.sh` → `orders.count()` = 10.000.
7. Cloud DO + Locust host terpisah → screenshot; **destroy resources** di akhir.
