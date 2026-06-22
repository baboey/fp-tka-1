# Architecture 1 — Baseline Architecture

## Overview

Architecture 1 merupakan implementasi baseline dari Order Processing Service menggunakan Docker Swarm dengan pemisahan service berdasarkan fungsi.

**Test Date:** June 19, 2026  
**Status:** ✅ Completed  
**Max RPS:** 189.59 (0% failure)

---

## Architecture Diagram

```
                    [ Locust - tka-locust ]
                         192.168.56.14
                              │
                              ▼ HTTP :80
         ┌────────────────────────────────────────┐
         │ tka-n1 (Manager + Nginx)               │
         │ 192.168.56.10                          │
         │ 1 vCPU, 2GB RAM (vm3) = $12/bln       │
         │ - Docker Swarm Manager                 │
         │ - Nginx (reverse proxy + microcache)   │
         │ - Local Docker Registry :5000          │
         └─────────────────┬──────────────────────┘
                           │ overlay network
              ┌────────────┴────────────┐
              ▼                         ▼
    ┌──────────────────┐    ┌──────────────────┐
    │ tka-n2 (Worker)  │    │ tka-n3 (Worker)  │
    │ 192.168.56.11    │    │ 192.168.56.12    │
    │ 2 vCPU, 2GB, $18 │    │ 2 vCPU, 2GB, $18 │
    │ Flask (Gunicorn) │    │ Flask (Gunicorn) │
    │ replicas: 2      │    │ replicas: 2      │
    └────────┬─────────┘    └────────┬─────────┘
             │                       │
             └───────────┬───────────┘
                         ▼ Port 27017 (private)
             ┌─────────────────────────────────┐
             │ tka-n4 (MongoDB standalone)     │
             │ 192.168.56.13                   │
             │ 2 vCPU, 4GB RAM (vm5) = $24    │
             │ docker-compose (not Swarm)      │
             └─────────────────────────────────┘
```

---

## VM Specifications

| VM | Role | Specs | IP | Cost/month |
|----|------|-------|----|----|
| tka-n1 | Manager + Nginx | 1 vCPU, 2GB RAM | 192.168.56.10 | $12 |
| tka-n2 | Worker Flask | 2 vCPU, 2GB RAM | 192.168.56.11 | $18 |
| tka-n3 | Worker Flask | 2 vCPU, 2GB RAM | 192.168.56.12 | $18 |
| tka-n4 | MongoDB | 2 vCPU, 4GB RAM | 192.168.56.13 | $24 |
| tka-locust | Load Tester | 1 vCPU, 1GB RAM | 192.168.56.14 | - |
| **Total** | | | | **$72** |

---

## Components

### Nginx (tka-n1)
- Reverse proxy & load balancer
- Microcache 5 seconds TTL for `/products` endpoints
- Gzip compression
- Static file serving (frontend)

### Flask Application (tka-n2, tka-n3)
- Gunicorn WSGI server: 5 workers, 4 threads
- Docker Swarm service with 2 replicas
- Connected to MongoDB via private network

### MongoDB (tka-n4)
- Standalone deployment (not in Swarm)
- Indexed collections: users, products, orders, audit_logs
- Accessible only via private network (192.168.56.13:27017)

### Local Docker Registry (tka-n1)
- Port 5000
- Stores Flask application images
- Insecure registry configuration for all Swarm nodes

---

## Load Test Results

| Scenario | Users | Spawn Rate | RPS | Failure | Avg RT | P99 RT |
|----------|-------|------------|-----|---------|--------|--------|
| 1 | 100 | 10/s | 37.63 | 0% | 11.37ms | 230ms |
| 2 | 200 | 50/s | 80.80 | 0% | 16.61ms | 590ms |
| 3 | 300 | 100/s | 118.71 | 0% | 38.21ms | 2,100ms |
| 4 | 400 | 200/s | 155.36 | 0% | 112.12ms | 4,400ms |
| 5 | 500 | 500/s | 189.59 | 0% | 196.56ms | 6,100ms |

**Key Metrics:**
- Total Requests: 34,397
- Max RPS: 189.59
- Failure Rate: 0%
- Median Response Time: 2ms (all scenarios)

---

## Identified Bottlenecks

1. **Nginx Single Point of Failure**
   - Only 1 vCPU handling all proxy duties
   - No redundancy

2. **No Application Cache Layer**
   - Only Nginx microcache (5s TTL)
   - Every cache miss hits Flask + MongoDB directly

3. **Auth Latency Under Load**
   - Login endpoints reached 6.1s at 500 users
   - No session caching

4. **Manager Node Resource Contention**
   - Swarm Manager + Nginx + Registry on 1 vCPU
   - Limited headroom

5. **MongoDB Over-provisioned**
   - 2 vCPU, 4GB RAM for read-heavy workload
   - Could be optimized with cache layer

---

## Files

- `LOAD_TEST_REPORT.md` - Detailed load testing report
- `scenario1_stats.csv` - Baseline load test data
- `scenario2_stats.csv` - Moderate load test data
- `scenario3_stats.csv` - High load test data
- `scenario4_stats.csv` - Very high load test data
- `scenario5_stats.csv` - Maximum load test data
