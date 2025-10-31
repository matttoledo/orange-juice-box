# WAF Stack - ModSecurity with OWASP CRS

**Layer:** 3 (Web Application Firewall)
**Services:** 1 (modsecurity)
**Rules:** 837 (OWASP CRS v4.19.0)

---

## Overview

The WAF stack provides comprehensive web application firewall protection using **ModSecurity** with the **OWASP Core Rule Set v4.19.0**, protecting against OWASP Top 10 vulnerabilities.

### Architecture Position
```
Cloudflare Tunnel → ModSecurity WAF → NPM → Your App
                    ↑
              (This stack)
```

---

## Services

### modsecurity

**Image:** `owasp/modsecurity-crs:nginx-alpine`
**Rules:** 837 active (OWASP CRS v4.19.0)
**Paranoia Level:** 2 (balanced)

#### Configuration
```yaml
Environment:
  BACKEND: http://infrastructure_npm
  PORT: 8080
  PARANOIA: 2
  BLOCKING_PARANOIA: 2
  ANOMALY_INBOUND: 5
  ANOMALY_OUTBOUND: 4
  ALLOWED_METHODS: GET HEAD POST OPTIONS PUT PATCH DELETE
  PROXY_TIMEOUT: 60s

Networks:
  - public_network
  - security_internal

Replicas: 1
```

#### Resources
```
CPU Limit: 1.0 cores
Memory Limit: 512MB
CPU Reservation: 0.25 cores
Memory Reservation: 256MB
```

#### Logging
```
Audit Logs: /var/log/modsec/audit.log (JSON format)
Volume: modsecurity_logs
```

---

## OWASP CRS v4.19.0

### Rule Categories

| ID Range | Category | Rules | Protection |
|----------|----------|-------|------------|
| **920-*** | Protocol Enforcement | ~50 | HTTP violations |
| **921-*** | Protocol Attack | ~40 | Request smuggling |
| **930-*** | Application Attack | ~60 | LFI, RFI, RCE |
| **931-*** | Application Attack | ~30 | PHP injection |
| **932-*** | Application Attack | ~40 | RCE |
| **933-*** | Application Attack | ~35 | PHP, Node, Java |
| **941-*** | XSS | ~100 | Cross-Site Scripting |
| **942-*** | SQL Injection | ~150 | SQLi variants |
| **943-*** | Session Fixation | ~10 | Session attacks |
| **944-*** | Java Attack | ~20 | Java/OGNL |

**Total:** 837 rules across 10+ attack categories

### Paranoia Levels

ModSecurity uses paranoia levels to balance security vs false positives:

| Level | Rules Active | False Positives | Security | Recommended For |
|-------|--------------|-----------------|----------|-----------------|
| **1** | ~500 | Very Low | Good | General websites |
| **2** | ~700 | Low | Better | **APIs** (current) ✅ |
| **3** | ~830 | Medium | High | High-security apps |
| **4** | ~850 | High | Maximum | Paranoid setups |

**Current:** Paranoia 2 (balanced for API protection)

---

## Attack Detection

### How It Works

1. **Request arrives** at ModSecurity
2. **Rules are evaluated** (837 rules)
3. **Anomaly score calculated** (each rule adds points)
4. **If score ≥ threshold** → Block (HTTP 403)
5. **Else** → Forward to backend

### Anomaly Scoring

```
Threshold: 5 (inbound) / 4 (outbound)

Example XSS Attack:
  Rule 941100: +5 points (XSS via libinjection)
  Rule 941110: +5 points (Script tag vector)
  Rule 941160: +5 points (NoScript XSS)
  Rule 941180: +5 points (document.cookie)
  Rule 941390: +5 points (alert method)
  Rule 941320: +5 points (HTML tag)
  Rule 942550: +5 points (JSON SQLi)
  Rule 942131: +5 points (SQL boolean)

Total Score: 40
Threshold: 5
Result: BLOCKED (403 Forbidden) ✅
```

---

## Deployment

### Deploy Stack
```bash
cd /home/matt/orange-juice-box/stacks/waf

# Deploy
docker stack deploy -c docker-compose.yml waf
```

### Verify Deployment
```bash
# Check service status
docker service ps waf_modsecurity

# Check rules loaded
docker service logs waf_modsecurity | grep "rules loaded"

# Expected: "rules loaded inline/local/remote: 0/837/0"

# Test backend connection
docker exec $(docker ps -qf name=waf_modsecurity) \
  curl -I http://infrastructure_npm
```

---

## Testing

### Test 1: Legitimate Request (Should Pass)
```bash
curl -s https://api.verlyvidracaria.com/verly-service/actuator/health
```

**Expected:** HTTP 200 + JSON response ✅

### Test 2: XSS Attack (Should Block)
```bash
curl "https://api.verlyvidracaria.com/?test=<script>alert('xss')</script>"
```

**Expected:** HTTP 403 Forbidden ✅

**Verified (2025-10-31):**
- Status: 403 ✅
- Rules triggered: 8 different rules
- Anomaly score: 40/5 ✅

### Test 3: SQL Injection (Should Block)
```bash
curl "https://api.verlyvidracaria.com/api/users?id=1' OR '1'='1--"
```

**Expected:** HTTP 403 Forbidden

### Test 4: Path Traversal (Should Block)
```bash
curl "https://api.verlyvidracaria.com/../../../../etc/passwd"
```

**Expected:** HTTP 403 Forbidden

---

## Monitoring

### View Audit Logs

```bash
# Real-time audit logs (JSON format)
docker exec $(docker ps -qf name=waf_modsecurity) \
  tail -f /var/log/modsec/audit.log

# Recent blocks
docker service logs waf_modsecurity | grep "Access denied" | tail -10
```

### Log Format (JSON)

```json
{
  "transaction": {
    "client_ip": "10.0.8.241",
    "request": {
      "method": "GET",
      "uri": "/?test=<script>alert('xss')</script>"
    },
    "response": {
      "http_code": 403
    },
    "messages": [
      {
        "message": "XSS Attack Detected via libinjection",
        "ruleId": "941100",
        "severity": "2"
      }
    ]
  }
}
```

### Metrics

```bash
# Count blocked requests today
docker exec $(docker ps -qf name=waf_modsecurity) \
  grep "Access denied" /var/log/modsec/audit.log | wc -l

# Group by rule ID
docker service logs waf_modsecurity | \
  grep "ruleId" | \
  sed 's/.*ruleId":"\([0-9]*\)".*/\1/' | \
  sort | uniq -c | sort -rn
```

---

## Tuning

### Reduce False Positives

If legitimate requests are being blocked:

1. **Identify blocking rule:**
   ```bash
   # Check audit logs for rule ID
   docker service logs waf_modsecurity | grep "Access denied"
   ```

2. **Options:**

   **A. Increase anomaly threshold:**
   ```yaml
   # In docker-compose.yml
   - ANOMALY_INBOUND=10  # Was 5
   ```

   **B. Disable specific rule:**
   ```yaml
   # Add to docker-compose.yml
   - DISABLE_RULE_IDS=941100,941110
   ```

   **C. Whitelist IP:**
   ```nginx
   # Add to custom config
   SecRule REMOTE_ADDR "@ipMatch 192.168.0.100" \
     "id:1000,phase:1,nolog,allow,ctl:ruleEngine=Off"
   ```

### Increase Protection

For higher security requirements:

```yaml
# In docker-compose.yml
- PARANOIA=3              # Was 2
- ANOMALY_INBOUND=3       # Was 5 (stricter)
- BLOCKING_PARANOIA=3      # Was 2
```

**⚠️ Warning:** Higher paranoia = more false positives

---

## Troubleshooting

### Issue: All Requests Blocked (HTTP 403)

**Cause:** Paranoia level too high or threshold too low

**Solution:**
```yaml
# Temporarily disable to test
- SecRuleEngine DetectionOnly

# Or increase threshold
- ANOMALY_INBOUND=20
```

### Issue: ModSecurity Not Blocking Attacks

**Cause:** Rules not loaded or engine disabled

**Verification:**
```bash
# Check if rules loaded
docker service logs waf_modsecurity | grep "rules loaded"

# Should show: 0/837/0

# Check engine status
docker exec $(docker ps -qf name=waf_modsecurity) \
  grep "SecRuleEngine" /etc/modsecurity.d/modsecurity.conf

# Should show: SecRuleEngine on
```

### Issue: Backend Connection Failed

**Symptom:** 502 Bad Gateway

**Solution:**
```bash
# Test backend from WAF container
docker exec $(docker ps -qf name=waf_modsecurity) \
  curl -I http://infrastructure_npm

# Verify both on same network
docker service inspect waf_modsecurity | grep Networks
docker service inspect infrastructure_npm | grep Networks
```

---

## Maintenance

### Update OWASP CRS

```bash
# Pull latest image
docker service update --image owasp/modsecurity-crs:nginx-alpine waf_modsecurity

# Verify new version
docker service logs waf_modsecurity | grep "OWASP_CRS"
```

### Backup Logs

```bash
# Backup audit logs
docker run --rm \
  -v modsecurity_logs:/logs \
  alpine tar czf - /logs > modsec-logs-$(date +%Y%m%d).tar.gz
```

### Performance Tuning

If WAF is causing slowdowns:

1. **Disable audit logging for successful requests:**
   ```yaml
   - AUDIT_ENGINE=RelevantOnly  # Only log blocks
   ```

2. **Reduce paranoia level:**
   ```yaml
   - PARANOIA=1  # Faster, less rules
   ```

3. **Disable response body inspection:**
   ```yaml
   - RESPONSE_BODY_ACCESS=Off
   ```

---

## Best Practices

### 1. Start with Paranoia 2
Balanced protection without too many false positives.

### 2. Monitor Audit Logs Weekly
Review blocked requests to identify patterns.

### 3. Whitelist Known Good IPs
Add trusted IPs to bypass WAF for better performance.

### 4. Test Before Production
Always test new paranoia levels or rule changes in staging.

### 5. Keep CRS Updated
Update OWASP CRS image monthly for latest rules.

---

## Real-World Examples

### Blocked XSS Attack (2025-10-31)
```bash
Request: /?test=<script>alert(document.cookie)</script>
Result: HTTP 403
Rules: 8 triggered (941100, 941110, 941160, 941180, 941390, 941320, 942550, 942131)
Score: 40/5
Status: ✅ BLOCKED
```

### Allowed Legitimate Request
```bash
Request: /verly-service/actuator/health
Result: HTTP 200
Score: 0/5
Status: ✅ ALLOWED
```

---

## References

- **ModSecurity:** https://github.com/SpiderLabs/ModSecurity
- **OWASP CRS:** https://coreruleset.org/
- **CRS Documentation:** https://coreruleset.org/docs/
- **Rule IDs:** https://coreruleset.org/docs/rules/

---

**Stack:** waf
**Status:** Active ✅
**Rules:** 837/837 loaded ✅
**Blocking:** XSS, SQLi, RCE ✅
**Last Updated:** 2025-10-31
