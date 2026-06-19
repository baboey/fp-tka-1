# Project Updates & Progress Log

**Project:** Order Processing Service - Final Project TKA 2026  
**Last Updated:** June 19, 2026  
**Status:** ✅ Architecture 2 Completed & Tested

---

## 📋 Executive Summary

Successfully deployed and tested two architectures for the Order Processing Service:
- **Architecture 1 (Baseline):** Docker Swarm with Nginx + Flask + MongoDB
- **Architecture 2 (Optimized):** Added Redis cache layer + VM spec optimization

**Key Achievement:** 195.28 RPS with 0% failure rate, 46% faster response times

---

## 🗓️ Timeline & Milestones

### Phase 1: Initial Setup (June 19, 2026 - Morning)

#### ✅ VM Infrastructure Setup
- **Tool:** Vagrant + libvirt (KVM)
- **VMs Created:** 5 instances
  - `tka-n1` (Manager + Nginx) - 1 vCPU, 2GB RAM
  - `tka-n2` (Worker Flask) - 2 vCPU, 2GB RAM
  - `tka-n3` (Worker Flask) - 2 vCPU, 2GB RAM
  - `tka-n4` (MongoDB) - 2 vCPU, 4GB RAM
  - `tka-locust` (Load Tester) - 1 vCPU, 1GB RAM
- **Network:** Private network 192.168.56.0/24
- **Total Cost:** $72/month (within $75 budget)

#### ✅ Docker Swarm Cluster
- Initialized Swarm on tka-n1 (manager)
- Joined tka-n2 and tka-n3 as workers
- Created overlay network for service communication

#### ✅ Services Deployed
- **Nginx:** Reverse proxy with microcache (5s TTL)
- **Flask:** 2 replicas with Gunicorn (5 workers, 4 threads)
- **MongoDB:** Standalone on tka-n4 with indexes
- **Local Registry:** For storing Flask images

---

### Phase 2: Architecture 1 Testing (June 19, 2026 - Midday)

#### ✅ Load Testing Completed
**Test Configuration:**
- Tool: Locust 2.44.4
- Host: tka-locust (separate from app servers)
- Target: tka-n1 (Nginx)
- Duration: 60 seconds per scenario

**Results Summary:**

| Scenario | Users | Spawn Rate | RPS | Failure | Avg RT | P99 RT |
|----------|-------|------------|-----|---------|--------|--------|
| 1 | 100 | 10/s | 37.63 | 0% | 11.37ms | 230ms |
| 2 | 200 | 50/s | 80.80 | 0% | 16.61ms | 590ms |
| 3 | 300 | 100/s | 118.71 | 0% | 38.21ms | 2,100ms |
| 4 | 400 | 200/s | 155.36 | 0% | 112.12ms | 4,400ms |
| 5 | 500 | 500/s | 189.59 | 0% | 196.56ms | 6,100ms |

**Key Findings:**
- ✅ 0% failure rate across all scenarios
- ✅ Max RPS: 189.59 (95% of 200 target)
- ⚠️ Auth latency reached 6.1s at 500 users
- ⚠️ Admin stats endpoint slow (90ms median)

**Files Created:**
- `result/arch1/README.md` - Architecture documentation
- `result/arch1/LOAD_TEST_REPORT.md` - Detailed test report
- `result/arch1/scenario[1-5]_stats.csv` - Raw test data

---

### Phase 3: Architecture 2 Optimization (June 19, 2026 - Afternoon)

#### 🔍 Bottleneck Analysis

**Identified Issues:**
1. **Nginx bottleneck:** Single instance on 1 vCPU manager
2. **No application cache:** Only Nginx microcache (5s TTL)
3. **Manager resource contention:** Swarm + Nginx + Registry on 1 vCPU
4. **MongoDB over-provisioned:** 2 vCPU, 4GB for read-heavy workload
5. **Auth latency:** No session caching

#### ✅ Optimization Implemented

**1. Redis Cache Layer**
- Added Redis 7 on manager node
- 512MB max memory with LRU eviction
- Application-level caching for `/products` (30s TTL)
- Application-level caching for `/admin/stats` (30s TTL)
- Cache invalidation on order creation

**2. VM Specification Reallocation**
```
BEFORE (Architecture 1):
- tka-n1: 1 vCPU, 2GB RAM ($12)
- tka-n4: 2 vCPU, 4GB RAM ($24)

AFTER (Architecture 2):
- tka-n1: 2 vCPU, 4GB RAM ($24) ← Upgraded
- tka-n4: 1 vCPU, 2GB RAM ($12) ← Downgraded

Total: Same $72/month
```

**3. Flask Replicas Scaling**
- Increased from 2 to 6 replicas (3 per worker)
- Better load distribution via Swarm routing mesh

**4. Nginx Cache TTL**
- Increased from 5s to 30s
- Reduced backend hits for read-heavy endpoints

**5. Flask Code Changes**
- Added Redis integration in `server.py`
- Cache `/products` responses with query params
- Cache `/admin/stats` aggregation results
- Invalidate cache on order creation

**Files Modified:**
- `Vagrantfile` - Updated VM specs
- `src/flask/server.py` - Added Redis caching
- `src/flask/requirements.txt` - Added redis==5.0.8
- `src/nginx/nginx-swarm.conf` - Increased TTL to 30s
- `src/stack.yaml` - Added Redis env, 6 replicas
- `src/ansible/deploy.yml` - Added Redis deployment

---

### Phase 4: Architecture 2 Testing (June 19, 2026 - Evening)

#### ✅ Load Testing Completed

**Results Summary:**

| Scenario | Users | Spawn Rate | RPS | Failure | Avg RT | P99 RT |
|----------|-------|------------|-----|---------|--------|--------|
| 1 | 100 | 10/s | **38.16** | 0% | **5.84ms** | 240ms |
| 2 | 200 | 50/s | **79.85** | 0% | **8.22ms** | 510ms |
| 3 | 300 | 100/s | **119.71** | 0% | **13.45ms** | 940ms |
| 4 | 400 | 200/s | **161.61** | 0% | **42.32ms** | 2,800ms |
| 5 | 500 | 500/s | **195.28** | 0% | **106.12ms** | 4,400ms |

**Improvement over Architecture 1:**
- ✅ **+3% RPS** (189.59 → 195.28)
- ✅ **-46% Average Response Time** (196.56ms → 106.12ms)
- ✅ **-28% P99 Response Time** (6,100ms → 4,400ms)
- ✅ **-89% Admin Stats Latency** (90ms → <10ms when cached)

**Files Created:**
- `result/arch2/README.md` - Architecture documentation
- `result/arch2/LOAD_TEST_REPORT.md` - Detailed test report
- `result/arch2/scenario[1-5]_stats.csv` - Raw test data

---

## 📁 File Structure Changes

### New Files Created
```
result/
├── arch1/
│   ├── README.md
│   ├── LOAD_TEST_REPORT.md
│   └── scenario[1-5]_stats.csv
└── arch2/
    ├── README.md
    ├── LOAD_TEST_REPORT.md
    └── scenario[1-5]_stats.csv

docs/
├── UPDATES.md (this file)
└── DEPLOY.md (to be created)
```

### Modified Files
```
Vagrantfile                          # Updated VM specs for Arch 2
src/flask/server.py                  # Added Redis caching
src/flask/requirements.txt           # Added redis==5.0.8
src/nginx/nginx-swarm.conf           # Increased TTL to 30s
src/stack.yaml                       # Added Redis env, 6 replicas
src/ansible/deploy.yml               # Added Redis deployment
src/ansible/inventory.ini            # Updated SSH key paths
```

---

## 🎯 Key Achievements

### Technical Achievements
1. ✅ **Zero Failure Rate:** Maintained 0% failure across all load tests
2. ✅ **Performance Optimization:** 46% faster response times
3. ✅ **Cost Efficiency:** Same budget ($72/month) with better performance
4. ✅ **Scalability:** Successfully scaled to 6 Flask replicas
5. ✅ **Cache Strategy:** Implemented multi-layer caching (Nginx + Redis)

### Infrastructure Achievements
1. ✅ **Docker Swarm:** Successfully deployed multi-node cluster
2. ✅ **Service Discovery:** Overlay network for inter-service communication
3. ✅ **Load Balancing:** Nginx with microcache for read-heavy workload
4. ✅ **Database Optimization:** MongoDB indexes for query performance
5. ✅ **Automation:** Ansible playbooks for deployment

---

## 🐛 Issues Encountered & Solutions

### Issue 1: Multipass Installation Failure
**Problem:** Snap installation failed with mount error  
**Solution:** Switched to Vagrant + libvirt (KVM)

### Issue 2: Nginx Configuration Error
**Problem:** `invalid number of arguments in proxy_set_header`  
**Root Cause:** Docker configs + envsubst conflict  
**Solution:** Direct volume mount instead of Docker configs

### Issue 3: Flask Service Startup Failure
**Problem:** `host not found in upstream "flask:9091"`  
**Root Cause:** Nginx starts before Flask service is ready  
**Solution:** Added `resolver 127.0.0.11` and `set $upstream` directive

### Issue 4: MongoDB Connection Timeout
**Problem:** `wait_for` timeout waiting for MongoDB  
**Root Cause:** Checking wrong host (127.0.0.1 instead of 192.168.56.13)  
**Solution:** Updated `wait_for` to use correct host IP

### Issue 5: Locust Import Errors
**Problem:** `ModuleNotFoundError: No module named 'zope.event'`  
**Root Cause:** Namespace package conflict between system and pip packages  
**Solution:** Copied zope.event to system packages directory

### Issue 6: dpkg Interrupted Error
**Problem:** `E: dpkg was interrupted, you must manually run 'sudo dpkg --configure -a'`  
**Solution:** Ran `sudo dpkg --configure -a` on affected VMs

---

## 📊 Performance Comparison

### Architecture 1 vs Architecture 2

| Metric | Arch 1 | Arch 2 | Improvement |
|--------|--------|--------|-------------|
| **Max RPS** | 189.59 | **195.28** | +3.0% |
| **Total Requests** | 34,397 | **35,138** | +2.2% |
| **Avg RT (Scenario 1)** | 11.37ms | **5.84ms** | -48.6% |
| **Avg RT (Scenario 5)** | 196.56ms | **106.12ms** | -46.0% |
| **P99 RT (Scenario 5)** | 6,100ms | **4,400ms** | -27.9% |
| **Auth Latency (Scenario 5)** | 6,100ms | **4,400ms** | -27.9% |
| **Admin Stats RT** | 90ms | **<10ms** | -89% |
| **Failure Rate** | 0% | **0%** | same |
| **Budget** | $72/mo | **$72/mo** | same |

---

## 🔮 Next Steps

### Immediate (For Final Submission)
1. ✅ Create UPDATES.md (this document)
2. ⏳ Create DEPLOY.md for cloud deployment guide
3. ⏳ Take screenshots of all endpoints (Postman)
4. ⏳ Take screenshots of frontend
5. ⏳ Take screenshots of Locust results
6. ⏳ Update README.md with final results

### Future Improvements (If Time Permits)
1. **Deploy to Real Cloud Servers:**
   - DigitalOcean or Azure
   - Multiple physical servers
   - VPN setup (Tailscale/WireGuard)

2. **Additional Optimizations:**
   - Redis session caching for auth
   - MongoDB read replicas
   - Auto-scaling based on CPU metrics
   - CDN for static assets

3. **Monitoring & Observability:**
   - Prometheus + Grafana
   - Centralized logging (ELK stack)
   - APM (Application Performance Monitoring)

4. **High Availability:**
   - MongoDB replica set
   - Redis Sentinel/Cluster
   - Multiple Nginx instances with keepalived

---

## 📝 Notes & Learnings

### What Worked Well
1. **Incremental Approach:** Started with baseline, then optimized
2. **Multi-layer Caching:** Nginx + Redis provided significant improvement
3. **Docker Swarm:** Easy to scale and manage
4. **Ansible Automation:** Made deployment reproducible
5. **Load Testing:** Identified bottlenecks early

### What Could Be Better
1. **Documentation:** Should have documented decisions earlier
2. **Testing:** Could have tested more edge cases
3. **Monitoring:** Should have added monitoring from the start
4. **Backup Strategy:** No backup/restore tested
5. **Security:** Could have added more security hardening

### Key Learnings
1. **Cache is King:** For read-heavy workloads, caching is crucial
2. **Resource Allocation:** Right-sizing VMs matters more than adding more VMs
3. **Database Indexes:** Proper indexes can make or break performance
4. **Load Testing:** Essential for finding bottlenecks before production
5. **Separation of Concerns:** Separating DB from app improves both

---

## 📚 References

### Documentation
- [Architecture 1 Report](../result/arch1/LOAD_TEST_REPORT.md)
- [Architecture 2 Report](../result/arch2/LOAD_TEST_REPORT.md)
- [Deployment Guide](DEPLOY.md)
- [Project Plan](PLAN.md)
- [Technical Explanation](EXPLANATION.md)

### Code
- [Flask Application](../src/flask/server.py)
- [Nginx Configuration](../src/nginx/nginx-swarm.conf)
- [Docker Stack](../src/stack.yaml)
- [Ansible Playbooks](../src/ansible/)

---

**End of Updates Log**
