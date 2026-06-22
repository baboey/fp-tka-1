# Load Testing Report - Architecture 2 (Optimized with Redis)

**Test Date:** June 19, 2026  
**Test Duration:** 60 seconds per scenario  
**Test Tool:** Locust 2.44.4  
**Test Host:** tka-locust (192.168.56.14) - Separate from application servers  
**Target Host:** tka-n1 (192.168.56.10) - Nginx Load Balancer

---

## Executive Summary

All 5 load testing scenarios completed successfully with **0% failure rate** across all tests. Architecture 2 demonstrates significant improvements over Architecture 1, particularly in response times.

### Key Results:
- **Maximum RPS Achieved:** 195.28 requests/second
- **Total Requests Processed:** 35,138 across all scenarios
- **Failure Rate:** 0% (zero failures in all scenarios)
- **Peak Concurrent Users:** 500 users handled successfully
- **Average Response Time:** 2-106ms depending on load

### Improvements over Architecture 1:
- **+3% RPS** (189.59 → 195.28)
- **-46% Average Response Time** (196.56ms → 106.12ms at 500 users)
- **-28% P99 Response Time** (6,100ms → 4,400ms at 500 users)
- **-89% Admin Stats Latency** (90ms → <10ms when cached)

---

## Test Scenarios

### Scenario 1: Baseline Load Test
**Parameters:**
- Users: 100
- Spawn Rate: 10 users/second
- Duration: 60 seconds

**Results:**
| Metric | Arch 1 | Arch 2 | Improvement |
|--------|--------|--------|-------------|
| Total Requests | 2,223 | 2,255 | +1.4% |
| Failure Rate | 0% | 0% | same |
| Average RPS | 37.63 | **38.16** | +1.4% |
| Avg Response Time | 11.37ms | **5.84ms** | **-48.6%** |
| Median Response Time | 5ms | **2ms** | -60% |
| P95 Response Time | 71ms | **12ms** | -83% |
| P99 Response Time | 220ms | **77ms** | -65% |

---

### Scenario 2: Moderate Load Test
**Parameters:**
- Users: 200
- Spawn Rate: 50 users/second
- Duration: 60 seconds

**Results:**
| Metric | Arch 1 | Arch 2 | Improvement |
|--------|--------|--------|-------------|
| Total Requests | 4,774 | 4,716 | -1.2% |
| Failure Rate | 0% | 0% | same |
| Average RPS | 80.80 | **79.85** | -1.2% |
| Avg Response Time | 16.61ms | **8.22ms** | **-50.5%** |
| Median Response Time | 2ms | **2ms** | same |
| P95 Response Time | 73ms | **19ms** | -74% |
| P99 Response Time | 500ms | **69ms** | -86% |

---

### Scenario 3: High Load Test
**Parameters:**
- Users: 300
- Spawn Rate: 100 users/second
- Duration: 60 seconds

**Results:**
| Metric | Arch 1 | Arch 2 | Improvement |
|--------|--------|--------|-------------|
| Total Requests | 7,015 | 7,074 | +0.8% |
| Failure Rate | 0% | 0% | same |
| Average RPS | 118.71 | **119.71** | +0.8% |
| Avg Response Time | 38.21ms | **13.45ms** | **-64.8%** |
| Median Response Time | 2ms | **2ms** | same |
| P95 Response Time | 86ms | **33ms** | -62% |
| P99 Response Time | 1,200ms | **140ms** | -88% |

---

### Scenario 4: Very High Load Test
**Parameters:**
- Users: 400
- Spawn Rate: 200 users/second
- Duration: 60 seconds

**Results:**
| Metric | Arch 1 | Arch 2 | Improvement |
|--------|--------|--------|-------------|
| Total Requests | 9,181 | 9,550 | +4.0% |
| Failure Rate | 0% | 0% | same |
| Average RPS | 155.36 | **161.61** | +4.0% |
| Avg Response Time | 112.12ms | **42.32ms** | **-62.3%** |
| Median Response Time | 2ms | **2ms** | same |
| P95 Response Time | 150ms | **60ms** | -60% |
| P99 Response Time | 3,200ms | **1,800ms** | -44% |

---

### Scenario 5: Maximum Load Test
**Parameters:**
- Users: 500
- Spawn Rate: 500 users/second
- Duration: 60 seconds

**Results:**
| Metric | Arch 1 | Arch 2 | Improvement |
|--------|--------|--------|-------------|
| Total Requests | 11,204 | 11,543 | +3.0% |
| Failure Rate | 0% | 0% | same |
| Average RPS | 189.59 | **195.28** | +3.0% |
| Avg Response Time | 196.56ms | **106.12ms** | **-46.0%** |
| Median Response Time | 2ms | **2ms** | same |
| P95 Response Time | 590ms | **190ms** | -68% |
| P99 Response Time | 6,100ms | **4,400ms** | -27.9% |

---

## Performance Analysis

### RPS Comparison
```
Scenario 1:  37.63 → 38.16 RPS  (+1.4%)
Scenario 2:  80.80 → 79.85 RPS  (-1.2%)
Scenario 3: 118.71 → 119.71 RPS (+0.8%)
Scenario 4: 155.36 → 161.61 RPS (+4.0%)
Scenario 5: 189.59 → 195.28 RPS (+3.0%)
```

### Average Response Time Comparison
```
Scenario 1:  11.37ms →  5.84ms  (-48.6%)
Scenario 2:  16.61ms →  8.22ms  (-50.5%)
Scenario 3:  38.21ms → 13.45ms  (-64.8%)
Scenario 4: 112.12ms → 42.32ms  (-62.3%)
Scenario 5: 196.56ms → 106.12ms (-46.0%)
```

### P99 Response Time Comparison
```
Scenario 1:   220ms →   77ms  (-65%)
Scenario 2:   500ms →   69ms  (-86%)
Scenario 3: 1,200ms →  140ms  (-88%)
Scenario 4: 3,200ms → 1,800ms (-44%)
Scenario 5: 6,100ms → 4,400ms (-28%)
```

---

## Key Findings

### Strengths of Architecture 2:
1. **Significantly Lower Response Times** - Redis caching reduces average response time by 46-65%
2. **Better Tail Latency** - P99 response times improved by 28-88%
3. **Efficient Resource Usage** - MongoDB downgraded but performs better due to Redis
4. **Scalable Design** - 6 Flask replicas handle load better than 2
5. **Cache Invalidation** - Proper invalidation ensures data consistency

### Areas for Further Improvement:
1. **Auth Latency** - Still reaches 4.4s at 500 users (could add session caching)
2. **Cache Stampede** - Could add locking mechanism for cache misses
3. **Redis HA** - Single Redis instance is a potential SPOF

---

## Infrastructure Configuration

### Test Environment:
| Component | Specification | Count |
|-----------|--------------|-------|
| **Manager Node (tka-n1)** | 2 vCPU, 4GB RAM | 1 |
| **Worker Nodes (tka-n2, tka-n3)** | 2 vCPU, 2GB RAM each | 2 |
| **Database Node (tka-n4)** | 1 vCPU, 2GB RAM | 1 |
| **Load Test Node (tka-locust)** | 1 vCPU, 1GB RAM | 1 |

### Software Stack:
- **Load Balancer:** Nginx with microcache (30s TTL for /products)
- **Cache Layer:** Redis 7 (512MB, LRU eviction)
- **Application:** Flask + Gunicorn (5 workers, 4 threads)
- **Database:** MongoDB 7.0 with indexed collections
- **Orchestration:** Docker Swarm with overlay network
- **Load Tester:** Locust 2.44.4

### Optimization Features:
- Nginx microcache for product endpoints (30s TTL)
- **Redis application-level cache** for /products and /admin/stats
- Gunicorn with gthread worker class
- MongoDB indexes on frequently queried fields
- Docker Swarm service discovery
- Keepalive connections between Nginx and Flask
- **Cache invalidation on order creation**

---

## Conclusion

Architecture 2 successfully improved upon Architecture 1 with:
- **+3% RPS** (195.28 vs 189.59)
- **-46% Average Response Time** (106.12ms vs 196.56ms at 500 users)
- **-28% P99 Response Time** (4,400ms vs 6,100ms at 500 users)

The Redis cache layer proved to be the most impactful optimization, significantly reducing response times while maintaining the same budget ($72/month). The reallocation of VM specifications (upgrading manager, downgrading MongoDB) was effective in eliminating bottlenecks.

**Overall Assessment:** ✅ **EXCELLENT** - Production-ready with significant performance improvements over baseline.

---

## Appendix: Raw Data

CSV files with detailed statistics are available in:
- `scenario1_stats.csv` - Baseline load test data
- `scenario2_stats.csv` - Moderate load test data
- `scenario3_stats.csv` - High load test data
- `scenario4_stats.csv` - Very high load test data
- `scenario5_stats.csv` - Maximum load test data
