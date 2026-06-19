# Architecture 2 — Optimized with Redis Cache Layer

## Overview

Architecture 2 is an optimized version of Architecture 1, adding a **Redis cache layer** and **rebalancing VM specifications** to improve performance under high load.

**Test Date:** June 19, 2026  
**Status:** ✅ Completed  
**Max RPS:** 195.28 (0% failure)  
**Improvement over Arch1:** +3% RPS, -46% avg response time

---

## Architecture Diagram

```
                    [ Locust - tka-locust ]
                         192.168.56.14
                              │
                              ▼ HTTP :80
         ┌────────────────────────────────────────┐
         │ tka-n1 (Manager + Nginx + Redis)       │
         │ 192.168.56.10                          │
         │ 2 vCPU, 4GB RAM (vm5) = $24/bln       │
         │ - Docker Swarm Manager                 │
         │ - Nginx (reverse proxy + microcache)   │
         │ - Redis 7 (cache layer)                │
         │ - Local Docker Registry :5000          │
         └─────────────────┬──────────────────────┘
                           │ overlay network
              ┌────────────┴────────────┐
              ▼                         ▼
    ┌──────────────────┐    ┌──────────────────┐
    │ tka-n2 (Worker)  │    │ tka-n3 (Worker)  │
    │ 192.168.56.11    │    │ 192.168.56.12    │
    │ 2 vCPU, 2GB, $18 │    │ 2 vCPU, 2GB, $18 │
    │ Flask x3         │    │ Flask x3         │
    │ replicas: 3      │    │ replicas: 3      │
    └────────┬─────────┘    └────────┬─────────┘
             │                       │
             └───────────┬───────────┘
                         ▼ Port 27017 (private)
             ┌─────────────────────────────────┐
             │ tka-n4 (MongoDB standalone)     │
             │ 192.168.56.13                   │
             │ 1 vCPU, 2GB RAM (vm3) = $12    │
             │ docker-compose (not Swarm)      │
             └─────────────────────────────────┘
```

---

## VM Specifications

| VM | Role | Specs | IP | Cost/month |
|----|------|-------|----|----|
| tka-n1 | Manager + Nginx + Redis | 2 vCPU, 4GB RAM | 192.168.56.10 | $24 |
| tka-n2 | Worker Flask | 2 vCPU, 2GB RAM | 192.168.56.11 | $18 |
| tka-n3 | Worker Flask | 2 vCPU, 2GB RAM | 192.168.56.12 | $18 |
| tka-n4 | MongoDB | 1 vCPU, 2GB RAM | 192.168.56.13 | $12 |
| tka-locust | Load Tester | 1 vCPU, 1GB RAM | 192.168.56.14 | - |
| **Total** | | | | **$72** |

---

## Key Changes from Architecture 1

| Component | Architecture 1 | Architecture 2 | Impact |
|-----------|---------------|----------------|--------|
| **Manager Node** | 1 vCPU, 2GB ($12) | **2 vCPU, 4GB ($24)** | Eliminates proxy bottleneck |
| **Redis Cache** | ❌ None | ✅ **Redis 7 on N1** | Caches /products + /admin/stats |
| **MongoDB Node** | 2 vCPU, 4GB ($24) | **1 vCPU, 2GB ($12)** | Reduced load via Redis |
| **Flask Replicas** | 2 total (1 per worker) | **6 total (3 per worker)** | Better load distribution |
| **Nginx Cache TTL** | 5 seconds | **30 seconds** | Fewer cache misses |
| **Flask Redis Cache** | ❌ None | ✅ **30s TTL** | Reduces MongoDB queries |

---

## Components

### Nginx (tka-n1)
- Reverse proxy & load balancer
- Microcache **30 seconds TTL** for `/products` endpoints (up from 5s)
- Gzip compression
- Static file serving (frontend)

### Redis Cache (tka-n1)
- **Redis 7** with 512MB max memory
- LRU eviction policy
- Caches `/products` responses (30s TTL)
- Caches `/admin/stats` aggregation results (30s TTL)
- Cache invalidation on order creation

### Flask Application (tka-n2, tka-n3)
- Gunicorn WSGI server: 5 workers, 4 threads
- Docker Swarm service with **6 replicas** (3 per worker)
- Connected to MongoDB via private network
- **Redis integration** for application-level caching

### MongoDB (tka-n4)
- Standalone deployment (not in Swarm)
- **Downgraded to 1 vCPU, 2GB RAM** (from 2 vCPU, 4GB)
- Indexed collections: users, products, orders, audit_logs
- Accessible only via private network (192.168.56.13:27017)
- Reduced load thanks to Redis cache layer

---

## Load Test Results

| Scenario | Users | Spawn Rate | RPS | Failure | Avg RT | P99 RT |
|----------|-------|------------|-----|---------|--------|--------|
| 1 | 100 | 10/s | **38.16** | 0% | **5.84ms** | 240ms |
| 2 | 200 | 50/s | **79.85** | 0% | **8.22ms** | 510ms |
| 3 | 300 | 100/s | **119.71** | 0% | **13.45ms** | 940ms |
| 4 | 400 | 200/s | **161.61** | 0% | **42.32ms** | 2,800ms |
| 5 | 500 | 500/s | **195.28** | 0% | **106.12ms** | 4,400ms |

**Key Metrics:**
- Total Requests: 35,138
- Max RPS: 195.28
- Failure Rate: 0%
- Median Response Time: 2ms (all scenarios)

---

## Comparison: Architecture 1 vs Architecture 2

| Metric | Arch 1 | Arch 2 | Improvement |
|--------|--------|--------|-------------|
| **Max RPS** | 189.59 | **195.28** | +3.0% |
| **Total Requests** | 34,397 | **35,138** | +2.2% |
| **Avg RT (Scenario 1)** | 11.37ms | **5.84ms** | -48.6% |
| **Avg RT (Scenario 5)** | 196.56ms | **106.12ms** | -46.0% |
| **P99 RT (Scenario 5)** | 6,100ms | **4,400ms** | -27.9% |
| **Auth Latency (Scenario 5)** | 6,100ms | **4,400ms** | -27.9% |
| **Admin Stats RT** | 90ms | **<10ms** (cached) | -89% |
| **Failure Rate** | 0% | **0%** | same |

---

## Performance Analysis

### RPS Scaling
```
Scenario 1:  38.16 RPS  (100 users)
Scenario 2:  79.85 RPS  (200 users)  [+109%]
Scenario 3: 119.71 RPS  (300 users)  [+214%]
Scenario 4: 161.61 RPS  (400 users)  [+324%]
Scenario 5: 195.28 RPS  (500 users)  [+412%]
```

### Response Time Improvement

The most significant improvement is in **average response time**:
- Scenario 1: 11.37ms → **5.84ms** (-48.6%)
- Scenario 5: 196.56ms → **106.12ms** (-46.0%)

This is primarily due to:
1. **Redis caching** eliminating repeated MongoDB queries
2. **More Flask replicas** distributing load better
3. **Longer Nginx cache TTL** reducing backend hits

### Endpoint Performance

#### Fastest Endpoints (with Redis cache):
1. **GET /products?[filters]** - 2ms median (Redis + Nginx cache)
2. **GET /products/<id>** - 2ms median (Nginx cache)
3. **GET /admin/stats** - <10ms when cached (was 72-90ms)

#### Improved Endpoints:
1. **POST /auth/login** - Reduced latency due to less DB contention
2. **GET /orders** - Faster due to reduced MongoDB load

---

## Cost-Benefit Analysis

| Aspect | Analysis |
|--------|----------|
| **Cost** | Same $72/month, reallocated specs |
| **RPS Improvement** | +3% (189.59 → 195.28) |
| **Response Time** | -46% average improvement |
| **Scalability** | Better headroom with 6 Flask replicas |
| **Complexity** | Slightly higher (Redis integration) |

---

## Files

- `LOAD_TEST_REPORT.md` - Detailed load testing report
- `scenario1_stats.csv` - Baseline load test data
- `scenario2_stats.csv` - Moderate load test data
- `scenario3_stats.csv` - High load test data
- `scenario4_stats.csv` - Very high load test data
- `scenario5_stats.csv` - Maximum load test data
