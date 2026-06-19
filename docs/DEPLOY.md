# Cloud Deployment Guide

**Purpose:** Step-by-step guide untuk deploy Order Processing Service ke multiple cloud server instances  
**Target Architecture:** Docker Swarm dengan Nginx + Flask + Redis + MongoDB  
**Budget:** ≤ $75/month

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Server Provisioning](#server-provisioning)
4. [Network Setup](#network-setup)
5. [Ansible Configuration](#ansible-configuration)
6. [Deployment Steps](#deployment-steps)
7. [Verification](#verification)
8. [Load Testing](#load-testing)
9. [Troubleshooting](#troubleshooting)
10. [Cleanup](#cleanup)

---

## 🎯 Prerequisites

### Required Tools (Local Machine)
```bash
# Install Ansible
sudo apt update
sudo apt install -y ansible python3-pip

# Install SSH client
sudo apt install -y openssh-client

# Verify installations
ansible --version
ssh -V
```

### Required Accounts
- **Cloud Provider Account** (pilih salah satu):
  - DigitalOcean ($200 credit) - Recommended
  - Microsoft Azure ($100 credit)
  - Google Cloud Platform ($300 credit)

### SSH Key Setup
```bash
# Generate SSH key (jika belum ada)
ssh-keygen -t ed25519 -C "your-email@example.com"

# Start SSH agent
eval "$(ssh-agent -s)"

# Add key to agent
ssh-add ~/.ssh/id_ed25519

# Display public key (akan dipakai di cloud provider)
cat ~/.ssh/id_ed25519.pub
```

---

## 🏗️ Architecture Overview

### Target Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                        Cloud Provider                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Server A (Manager)                    Server B (Worker)        │
│  ┌──────────────────────────┐         ┌──────────────────────┐ │
│  │ Public IP: X.X.X.X       │         │ Public IP: Y.Y.Y.Y   │ │
│  │ Private IP: 10.10.0.1    │◄───────►│ Private IP: 10.10.0.2│ │
│  │                          │         │                      │ │
│  │ - Docker Swarm Manager   │         │ - Docker Swarm Worker│ │
│  │ - Nginx (port 80)        │         │ - Flask x3 replicas  │ │
│  │ - Redis (port 6379)      │         │                      │ │
│  │ - Registry (port 5000)   │         │                      │ │
│  └──────────────────────────┘         └──────────────────────┘ │
│                                                                  │
│  Server C (Worker)                     Server D (Database)      │
│  ┌──────────────────────────┐         ┌──────────────────────┐ │
│  │ Public IP: Z.Z.Z.Z       │         │ Public IP: W.W.W.W   │ │
│  │ Private IP: 10.10.0.3    │◄───────►│ Private IP: 10.10.0.4│ │
│  │                          │         │                      │ │
│  │ - Docker Swarm Worker    │         │ - MongoDB            │ │
│  │ - Flask x3 replicas      │         │ - Port 27017         │ │
│  │                          │         │ - Private only       │ │
│  └──────────────────────────┘         └──────────────────────┘ │
│                                                                  │
│  Server E (Load Tester)                                         │
│  ┌──────────────────────────┐                                  │
│  │ Public IP: V.V.V.V       │                                  │
│  │ Private IP: 10.10.0.5    │                                  │
│  │                          │                                  │
│  │ - Locust                 │                                  │
│  │ - Separate from cluster  │                                  │
│  └──────────────────────────┘                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### VM Specifications & Cost (DigitalOcean Example)

| Server | Role | Specs | Cost/month |
|--------|------|-------|------------|
| Server A | Manager + Nginx + Redis | 2 vCPU, 4GB RAM | $24 |
| Server B | Worker Flask | 2 vCPU, 2GB RAM | $12 |
| Server C | Worker Flask | 2 vCPU, 2GB RAM | $12 |
| Server D | MongoDB | 1 vCPU, 2GB RAM | $12 |
| Server E | Load Tester | 1 vCPU, 1GB RAM | $6 |
| **Total** | | | **$66** |

---

## 🖥️ Server Provisioning

### Option A: DigitalOcean (Recommended)

#### 1. Install doctl CLI
```bash
# Ubuntu/Debian
sudo snap install doctl

# macOS
brew install doctl

# Verify
doctl version
```

#### 2. Authenticate
```bash
doctl auth init
# Enter your DigitalOcean API token
```

#### 3. Create SSH Key in DigitalOcean
```bash
doctl compute ssh-key create tka-deploy-key \
  --public-key "$(cat ~/.ssh/id_ed25519.pub)"
```

#### 4. Create Droplets
```bash
# Create VPC (Private Network)
doctl compute vpc create tka-vpc \
  --region sgp1 \
  --description "TKA Final Project VPC"

# Get VPC UUID
VPC_ID=$(doctl compute vpc list --format ID,Name | grep tka-vpc | awk '{print $1}')

# Server A - Manager + Nginx + Redis
doctl compute droplet create tka-server-a \
  --region sgp1 \
  --image ubuntu-22-04-x64 \
  --size s-2vcpu-4gb \
  --vpc-uuid $VPC_ID \
  --ssh-keys $(doctl compute ssh-key list --format ID,Name | grep tka-deploy-key | awk '{print $1}') \
  --enable-private-networking \
  --wait

# Server B - Worker Flask
doctl compute droplet create tka-server-b \
  --region sgp1 \
  --image ubuntu-22-04-x64 \
  --size s-2vcpu-2gb \
  --vpc-uuid $VPC_ID \
  --ssh-keys $(doctl compute ssh-key list --format ID,Name | grep tka-deploy-key | awk '{print $1}') \
  --enable-private-networking \
  --wait

# Server C - Worker Flask
doctl compute droplet create tka-server-c \
  --region sgp1 \
  --image ubuntu-22-04-x64 \
  --size s-2vcpu-2gb \
  --vpc-uuid $VPC_ID \
  --ssh-keys $(doctl compute ssh-key list --format ID,Name | grep tka-deploy-key | awk '{print $1}') \
  --enable-private-networking \
  --wait

# Server D - MongoDB
doctl compute droplet create tka-server-d \
  --region sgp1 \
  --image ubuntu-22-04-x64 \
  --size s-1vcpu-2gb \
  --vpc-uuid $VPC_ID \
  --ssh-keys $(doctl compute ssh-key list --format ID,Name | grep tka-deploy-key | awk '{print $1}') \
  --enable-private-networking \
  --wait

# Server E - Load Tester
doctl compute droplet create tka-server-e \
  --region sgp1 \
  --image ubuntu-22-04-x64 \
  --size s-1vcpu-1gb \
  --vpc-uuid $VPC_ID \
  --ssh-keys $(doctl compute ssh-key list --format ID,Name | grep tka-deploy-key | awk '{print $1}') \
  --enable-private-networking \
  --wait
```

#### 5. Get Server IPs
```bash
doctl compute droplet list --format Name,PublicIPv4,PrivateIPv4
```

Output example:
```
Name            Public IPv4        Private IPv4
tka-server-a    128.199.123.45     10.10.0.1
tka-server-b    128.199.123.46     10.10.0.2
tka-server-c    128.199.123.47     10.10.0.3
tka-server-d    128.199.123.48     10.10.0.4
tka-server-e    128.199.123.49     10.10.0.5
```

#### 6. Configure Firewall
```bash
# Create firewall
doctl compute firewall create tka-firewall \
  --inbound-rules "protocol:tcp,port_range:22,address:0.0.0.0/0 \
                   protocol:tcp,port_range:80,address:0.0.0.0/0 \
                   protocol:tcp,port_range:2377,address:10.10.0.0/24 \
                   protocol:tcp,port_range:7946,address:10.10.0.0/24 \
                   protocol:udp,port_range:7946,address:10.10.0.0/24 \
                   protocol:udp,port_range:4789,address:10.10.0.0/24"

# Get firewall ID
FIREWALL_ID=$(doctl compute firewall list --format ID,Name | grep tka-firewall | awk '{print $1}')

# Apply firewall to all droplets
for droplet in tka-server-a tka-server-b tka-server-c tka-server-d tka-server-e; do
  DROPLET_ID=$(doctl compute droplet list --format ID,Name | grep $droplet | awk '{print $1}')
  doctl compute firewall add-droplets $FIREWALL_ID --droplet-ids $DROPLET_ID
done
```

---

### Option B: Manual Provisioning (Any Provider)

Jika menggunakan cloud provider lain atau manual provisioning:

#### 1. Create 5 Servers
- OS: Ubuntu 22.04 LTS
- Specs: See table above
- Ensure all servers have:
  - Public IP (kecuali Server D - MongoDB)
  - Private network connectivity
  - SSH access with your public key

#### 2. Record Server Information
Create file `servers.txt`:
```
# Server A - Manager
PUBLIC_IP_A=128.199.123.45
PRIVATE_IP_A=10.10.0.1

# Server B - Worker
PUBLIC_IP_B=128.199.123.46
PRIVATE_IP_B=10.10.0.2

# Server C - Worker
PUBLIC_IP_C=128.199.123.47
PRIVATE_IP_C=10.10.0.3

# Server D - MongoDB
PUBLIC_IP_D=128.199.123.48
PRIVATE_IP_D=10.10.0.4

# Server E - Load Tester
PUBLIC_IP_E=128.199.123.49
PRIVATE_IP_E=10.10.0.5
```

---

## 🌐 Network Setup

### Verify Private Network Connectivity

From each server, test connectivity to other servers via private IPs:

```bash
# SSH to Server A
ssh root@128.199.123.45

# Test connectivity to other servers
ping -c 3 10.10.0.2  # Server B
ping -c 3 10.10.0.3  # Server C
ping -c 3 10.10.0.4  # Server D
ping -c 3 10.10.0.5  # Server E
```

### Configure Hosts File (Optional)

Add to `/etc/hosts` on all servers:
```bash
10.10.0.1 tka-server-a
10.10.0.2 tka-server-b
10.10.0.3 tka-server-c
10.10.0.4 tka-server-d
10.10.0.5 tka-server-e
```

---

## ⚙️ Ansible Configuration

### 1. Create Cloud Inventory File

Create `src/ansible/inventory.cloud.ini`:

```ini
[managers]
tka-server-a ansible_host=128.199.123.45 ansible_user=root

[workers]
tka-server-b ansible_host=128.199.123.46 ansible_user=root
tka-server-c ansible_host=128.199.123.47 ansible_user=root

[database]
tka-server-d ansible_host=128.199.123.48 ansible_user=root

[locust]
tka-server-e ansible_host=128.199.123.49 ansible_user=root

[swarm:children]
managers
workers

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_python_interpreter=/usr/bin/python3

# Private IPs for internal communication
private_ip_manager=10.10.0.1
private_ip_worker_b=10.10.0.2
private_ip_worker_c=10.10.0.3
private_ip_mongodb=10.10.0.4
private_ip_locust=10.10.0.5
```

### 2. Test Connectivity

```bash
cd src/ansible
ansible all -i inventory.cloud.ini -m ping
```

Expected output:
```
tka-server-a | SUCCESS => {"ansible_facts": {"discovered_interpreter_python": "/usr/bin/python3"}, "changed": false, "ping": "pong"}
tka-server-b | SUCCESS => {"ansible_facts": {"discovered_interpreter_python": "/usr/bin/python3"}, "changed": false, "ping": "pong"}
...
```

### 3. Update Playbooks for Cloud

#### Update `deploy.yml`

Replace hardcoded IPs with variables:

```yaml
# Find and replace these values:
# 192.168.56.10 -> {{ private_ip_manager }}
# 192.168.56.13 -> {{ private_ip_mongodb }}
```

Or create `src/ansible/group_vars/all.yml`:

```yaml
---
# Network configuration
manager_private_ip: "{{ private_ip_manager }}"
mongodb_private_ip: "{{ private_ip_mongodb }}"

# Docker registry
docker_registry: "{{ manager_private_ip }}:5000"

# MongoDB connection
mongo_uri: "mongodb://user:user@{{ mongodb_private_ip }}:27017/orderdb?authSource=orderdb"

# Redis connection
redis_url: "redis://{{ manager_private_ip }}:6379/0"
```

---

## 🚀 Deployment Steps

### Step 1: Provision All Servers

```bash
cd src/ansible

# Install Docker on all servers
ansible-playbook -i inventory.cloud.ini provision.yml
```

This will:
- Update apt packages
- Install Docker & Docker Compose
- Enable Docker service
- Add root user to docker group

### Step 2: Initialize Docker Swarm

```bash
# Initialize Swarm on manager
ansible-playbook -i inventory.cloud.ini swarm.yml
```

This will:
- Initialize Swarm on Server A (manager)
- Join Server B and C as workers
- Verify cluster status

**Expected output:**
```
TASK [Display Swarm nodes] *****************************************************
ok: [tka-server-a] => {
    "msg": [
        "ID                            HOSTNAME       STATUS    AVAILABILITY   MANAGER STATUS",
        "abc123 *                      tka-server-a   Ready     Active         Leader",
        "def456                        tka-server-b   Ready     Active",
        "ghi789                        tka-server-c   Ready     Active"
    ]
}
```

### Step 3: Deploy Services

```bash
# Deploy all services
ansible-playbook -i inventory.cloud.ini deploy.yml
```

This will:
1. Configure insecure registry on all Swarm nodes
2. Setup local Docker registry on manager
3. Deploy Redis cache on manager
4. Build and push Flask image
5. Deploy MongoDB on Server D
6. Deploy Swarm stack (Nginx + Flask)

**Expected output:**
```
TASK [Display services] ********************************************************
ok: [tka-server-a] => {
    "msg": [
        "ID             NAME          MODE         REPLICAS   IMAGE",
        "abc123def456   tka_flask     replicated   6/6        10.10.0.1:5000/flask-order:latest",
        "ghi789jkl012   tka_nginx     replicated   1/1        nginx:alpine"
    ]
}
```

---

## ✅ Verification

### 1. Check Service Status

```bash
# SSH to manager
ssh root@128.199.123.45

# Check services
docker service ls

# Expected output:
# ID             NAME          MODE         REPLICAS   IMAGE
# abc123def456   tka_flask     replicated   6/6        10.10.0.1:5000/flask-order:latest
# ghi789jkl012   tka_nginx     replicated   1/1        nginx:alpine
```

### 2. Check Service Logs

```bash
# Check Nginx logs
docker service logs tka_nginx

# Check Flask logs
docker service logs tka_flask
```

### 3. Test Endpoints

```bash
# From your local machine
curl http://128.199.123.45/health
# Expected: {"status":"ok","timestamp":"..."}

curl http://128.199.123.45/products | head -c 200
# Expected: {"data":[...]}

# Test frontend
curl http://128.199.123.45/ | head -20
# Expected: HTML of frontend
```

### 4. Check MongoDB

```bash
# SSH to MongoDB server
ssh root@128.199.123.48

# Check MongoDB container
docker ps | grep mongodb

# Test MongoDB connection
docker exec -it mongodb mongosh -u root -p root --authenticationDatabase admin orderdb --eval "db.stats()"
```

### 5. Check Redis

```bash
# SSH to manager
ssh root@128.199.123.45

# Check Redis container
docker ps | grep redis

# Test Redis connection
docker exec -it redis-cache redis-cli ping
# Expected: PONG
```

---

## 🧪 Load Testing

### 1. Setup Locust on Server E

```bash
# SSH to load tester
ssh root@128.199.123.49

# Install Locust
pip3 install locust

# Create locust directory
mkdir -p /opt/locust
cd /opt/locust

# Copy locustfile from your repo
# (Use scp or copy-paste from src/locust/locustfile.py)
```

### 2. Run Load Tests

```bash
cd /opt/locust

# Scenario 1: Baseline (100 users)
locust -f locustfile.py --host=http://128.199.123.45 --headless -u 100 -r 10 --run-time 60s --csv=scenario1

# Scenario 2: Moderate (200 users)
locust -f locustfile.py --host=http://128.199.123.45 --headless -u 200 -r 50 --run-time 60s --csv=scenario2

# Scenario 3: High (300 users)
locust -f locustfile.py --host=http://128.199.123.45 --headless -u 300 -r 100 --run-time 60s --csv=scenario3

# Scenario 4: Very High (400 users)
locust -f locustfile.py --host=http://128.199.123.45 --headless -u 400 -r 200 --run-time 60s --csv=scenario4

# Scenario 5: Maximum (500 users)
locust -f locustfile.py --host=http://128.199.123.45 --headless -u 500 -r 500 --run-time 60s --csv=scenario5
```

### 3. Collect Results

```bash
# Copy results back to local machine
scp root@128.199.123.49:/opt/locust/scenario*.csv ./result/arch2/
```

---

## 🔧 Troubleshooting

### Issue 1: SSH Connection Refused

**Symptoms:**
```
UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh"}
```

**Solutions:**
1. Check if server is running: `doctl compute droplet list`
2. Verify SSH key is added: `doctl compute ssh-key list`
3. Test SSH manually: `ssh root@<public-ip>`
4. Check firewall rules: `doctl compute firewall list`

### Issue 2: Docker Swarm Join Failed

**Symptoms:**
```
Error response from daemon: rpc error: code = DeadlineExceeded
```

**Solutions:**
1. Check firewall allows Swarm ports (2377, 7946, 4789)
2. Verify private network connectivity: `ping 10.10.0.1`
3. Check manager status: `docker node ls`
4. Reset and rejoin:
   ```bash
   docker swarm leave --force
   # Then re-run swarm.yml
   ```

### Issue 3: Nginx Cannot Connect to Flask

**Symptoms:**
```
nginx: [emerg] host not found in upstream "flask:9091"
```

**Solutions:**
1. Check Flask service is running: `docker service ls`
2. Check overlay network: `docker network ls`
3. Restart Nginx service: `docker service update --force tka_nginx`
4. Check DNS resolution:
   ```bash
   docker exec -it $(docker ps -q -f name=tka_nginx) nslookup flask
   ```

### Issue 4: MongoDB Connection Timeout

**Symptoms:**
```
pymongo.errors.ServerSelectionTimeoutError: No suitable servers found
```

**Solutions:**
1. Check MongoDB is running: `ssh root@<mongodb-ip> "docker ps | grep mongodb"`
2. Verify MongoDB is listening on private IP:
   ```bash
   ssh root@<mongodb-ip> "docker exec mongodb netstat -tlnp | grep 27017"
   ```
3. Test connection from Flask server:
   ```bash
   ssh root@<worker-ip> "telnet 10.10.0.4 27017"
   ```
4. Check MongoDB logs:
   ```bash
   ssh root@<mongodb-ip> "docker logs mongodb"
   ```

### Issue 5: Redis Connection Failed

**Symptoms:**
```
redis.exceptions.ConnectionError: Error connecting to 10.10.0.1:6379
```

**Solutions:**
1. Check Redis is running: `docker ps | grep redis`
2. Test Redis connection:
   ```bash
   docker exec -it redis-cache redis-cli ping
   ```
3. Check if Redis is listening on correct interface:
   ```bash
   docker exec -it redis-cache netstat -tlnp | grep 6379
   ```
4. Update Redis config to bind to all interfaces:
   ```bash
   docker rm -f redis-cache
   docker run -d --name redis-cache --restart always -p 6379:6379 redis:7-alpine redis-server --bind 0.0.0.0 --maxmemory 512mb --maxmemory-policy allkeys-lru
   ```

---

## 🧹 Cleanup

### DigitalOcean Cleanup

```bash
# Delete all droplets
doctl compute droplet delete tka-server-a tka-server-b tka-server-c tka-server-d tka-server-e --force

# Delete firewall
doctl compute firewall delete $(doctl compute firewall list --format ID,Name | grep tka-firewall | awk '{print $1}') --force

# Delete VPC
doctl compute vpc delete $(doctl compute vpc list --format ID,Name | grep tka-vpc | awk '{print $1}') --force

# Delete SSH key
doctl compute ssh-key delete $(doctl compute ssh-key list --format ID,Name | grep tka-deploy-key | awk '{print $1}') --force
```

### Manual Cleanup (Any Provider)

1. **Stop all services:**
   ```bash
   # On manager
   docker stack rm tka
   
   # On MongoDB server
   cd /opt/mongodb && docker-compose down
   ```

2. **Delete cloud resources:**
   - Delete all VMs/droplets/instances
   - Delete firewalls/security groups
   - Delete VPC/networks
   - Delete SSH keys

3. **Verify deletion:**
   - Check cloud provider dashboard
   - Ensure no resources are running
   - Verify billing stops

---

## 📝 Post-Deployment Checklist

- [ ] All 5 servers are running and accessible
- [ ] Private network connectivity verified
- [ ] Docker installed on all servers
- [ ] Docker Swarm cluster initialized
- [ ] All services deployed and running
- [ ] Endpoints accessible via public IP
- [ ] MongoDB seeded with data
- [ ] Redis cache working
- [ ] Load tests completed
- [ ] Screenshots taken for documentation
- [ ] Resources cleaned up (if needed)

---

## 📚 Additional Resources

### Documentation
- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Ansible Documentation](https://docs.ansible.com/)
- [DigitalOcean API Documentation](https://docs.digitalocean.com/reference/api/)
- [Nginx Documentation](https://nginx.org/en/docs/)

### Project Files
- [Architecture 1 Report](../result/arch1/LOAD_TEST_REPORT.md)
- [Architecture 2 Report](../result/arch2/LOAD_TEST_REPORT.md)
- [Project Updates](UPDATES.md)
- [Project Plan](PLAN.md)

---

## 💡 Tips & Best Practices

1. **Start Small:** Test with 2-3 servers first before full deployment
2. **Use Tags:** Tag all cloud resources for easy identification and cleanup
3. **Monitor Costs:** Set up billing alerts to avoid unexpected charges
4. **Backup Data:** Regularly backup MongoDB data
5. **Document Everything:** Keep track of all changes and configurations
6. **Test Recovery:** Practice disaster recovery procedures
7. **Secure Access:** Use SSH keys only, disable password authentication
8. **Enable Monitoring:** Set up monitoring and alerting for production

---

**End of Deployment Guide**

For questions or issues, refer to the [Troubleshooting](#troubleshooting) section or check the [Project Updates](UPDATES.md) for known issues and solutions.
