# Mac Connectivity Debugging Guide

## Issue
Mac cannot access `http://redash.192.168.0.2.nip.io` - ERR_ADDRESS_UNREACHABLE

## Orange Pi Status ✅ ALL GOOD

- ✅ IP Address: 192.168.0.2
- ✅ UFW Firewall: Port 80 ALLOW Anywhere
- ✅ Traefik listening on *:80 (all interfaces)
- ✅ Docker ingress network working
- ✅ Services responding from Orange Pi itself

## Diagnostic Steps (Run on Mac)

### Step 1: Basic Network Connectivity

```bash
# Test if Mac can reach Orange Pi at all
ping 192.168.0.2

# Expected: Reply from 192.168.0.2
# If fails: Mac and Orange Pi are NOT on same network
```

### Step 2: Test HTTP Port

```bash
# Test if port 80 is reachable
nc -zv 192.168.0.2 80

# Expected: Connection to 192.168.0.2 port 80 [tcp/http] succeeded
# If fails: Firewall/router blocking
```

### Step 3: Test Direct HTTP Request

```bash
# Test raw HTTP request
curl -v http://192.168.0.2

# Expected: HTML response or redirect
# If fails: Traefik not responding
```

### Step 4: Test with Host Header

```bash
# Test Grafana
curl -H "Host: grafana.192.168.0.2.nip.io" http://192.168.0.2

# Expected: HTML with /login redirect
```

### Step 5: Check Mac Network

```bash
# Check Mac IP address
ifconfig | grep "inet 192.168"

# Expected: inet 192.168.0.X (same subnet as Orange Pi)
# If different subnet: Need to configure routing
```

### Step 6: DNS Resolution Test

```bash
# Check if .nip.io resolves correctly
nslookup grafana.192.168.0.2.nip.io

# Expected: Address: 192.168.0.2
```

## Common Issues & Solutions

### Issue 1: Mac on Different Subnet

**Problem:** Mac is on 192.168.1.X but Orange Pi is on 192.168.0.2

**Solution:**
- Connect Mac to same WiFi/network as Orange Pi
- OR configure router to route between subnets

### Issue 2: Router/Firewall Blocking

**Problem:** Router has AP isolation or client isolation enabled

**Solution:**
- Disable AP isolation in router settings
- Disable client isolation
- Check router firewall rules

### Issue 3: Mac Firewall Blocking

**Problem:** Mac firewall blocking outbound connections

**Solution:**
```bash
# Check Mac firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Temporarily disable to test
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off
```

### Issue 4: VPN Active on Mac

**Problem:** Mac is connected to VPN that routes all traffic elsewhere

**Solution:**
- Disconnect VPN temporarily
- OR add route for 192.168.0.0/24 via local gateway

## Quick Fix Options

### Option A: Use Direct IP:PORT (No Traefik)

If Traefik routing is the issue, access services directly:

```bash
# From Mac (if ping works):
http://192.168.0.2:3000    # Grafana (old deployment)
http://192.168.0.2:9091    # Prometheus (old deployment)
http://192.168.0.2:9000    # Portainer (old deployment)
http://192.168.0.2:8888    # Dozzle (old deployment)
```

### Option B: SSH Tunnel

If network is completely isolated, use SSH tunnel:

```bash
# On Mac:
ssh -L 8080:192.168.0.2:80 matt@192.168.0.2

# Then access:
http://localhost:8080
# Add Host header manually or use browser extension
```

### Option C: Add Static Route (if different subnet)

```bash
# On Mac (if Orange Pi is on different subnet):
sudo route add -net 192.168.0.0/24 192.168.0.1  # Use your router IP
```

## Expected Working State

After fixing network connectivity, from Mac you should see:

```bash
ping 192.168.0.2
# → Reply from 192.168.0.2

curl http://192.168.0.2
# → 404 page not found (Traefik is working!)

curl -H "Host: grafana.192.168.0.2.nip.io" http://192.168.0.2
# → HTML with /login redirect

# In browser:
http://grafana.192.168.0.2.nip.io → Grafana login page
http://redash.192.168.0.2.nip.io → Redash setup page
```

## Report Back

Please run Step 1 and Step 5 from Mac and tell me the results:

```bash
# Step 1
ping 192.168.0.2

# Step 5
ifconfig | grep "inet 192.168"
```

This will tell us if it's a network configuration issue or something else.
