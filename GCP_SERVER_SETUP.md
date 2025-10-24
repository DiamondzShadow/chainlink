# Running Chainlink Scripts on Your GCP Server

This guide shows you how to access your GCP server and run Chainlink/Oraclez integration scripts.

## Step 1: Connect to Your GCP Server

### Option A: Using gcloud CLI (Recommended)

```bash
# List your instances to find the name
gcloud compute instances list

# SSH into your instance
gcloud compute ssh YOUR_INSTANCE_NAME --zone=YOUR_ZONE

# Example:
# gcloud compute ssh chainlink-node --zone=us-central1-a
```

### Option B: Using Standard SSH

```bash
# Get your instance's external IP from GCP Console
# Then SSH with your key
ssh -i ~/.ssh/google_compute_engine YOUR_USERNAME@YOUR_GCP_EXTERNAL_IP

# Example:
# ssh -i ~/.ssh/google_compute_engine ubuntu@34.123.45.67
```

### Option C: Using GCP Console (Browser SSH)

1. Go to [GCP Compute Engine Console](https://console.cloud.google.com/compute/instances)
2. Find your Chainlink instance
3. Click the **SSH** button next to it
4. A browser terminal will open

---

## Step 2: Find Your Chainlink Directory

Once connected to your server:

```bash
# Check if you're in the right directory
pwd

# If not, find where Chainlink is installed
find ~ -name "chainlink" -type d 2>/dev/null | grep -v node_modules

# Common locations:
# /home/YOUR_USERNAME/chainlink
# /opt/chainlink
# ~/go/src/github.com/smartcontractkit/chainlink
```

Navigate to it:
```bash
cd /path/to/your/chainlink/directory
```

Verify you're in the right place:
```bash
# You should see these files:
ls -la | grep -E "(ORACLEZ|examples|scripts)"

# Expected output should show:
# ORACLEZ_QUICKSTART.md
# examples/
# scripts/
```

---

## Step 3: Verify Chainlink is Running

Check if your Chainlink node is running:

```bash
# Check the process
ps aux | grep chainlink

# Check if the port is open (default: 6688)
netstat -tulpn | grep 6688

# Or using ss
ss -tulpn | grep 6688

# Test if you can reach the UI
curl -k https://localhost:6688
# or
curl http://localhost:6688
```

If Chainlink is NOT running, start it:

```bash
# Start Chainlink (adjust command based on your setup)
chainlink node start

# Or if using systemd:
sudo systemctl start chainlink

# Or if using docker:
docker start chainlink
```

---

## Step 4: Verify Oraclez is Running

Check if Oraclez is accessible from your Chainlink server:

```bash
# Test local connection (if Oraclez is on same server)
curl http://localhost:8080

# Test remote connection (if Oraclez is on different server)
curl http://YOUR_ORACLEZ_IP:8080

# Full test with sample request
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{
    "id": "test-123",
    "data": {
      "videoId": "dQw4w9WgXcQ",
      "endpoint": "views"
    }
  }'
```

**If you get a connection error:**
- Make sure Oraclez is running: `ps aux | grep node`
- Check firewall rules between servers
- Verify the port number (default is 8080)

---

## Step 5: Run the Integration Scripts

Now you can run the Chainlink-Oraclez integration scripts:

### Test the Connection:

```bash
cd /path/to/chainlink
./examples/test_oraclez_connection.sh
```

When prompted, enter your Oraclez URL:
- If on same server: `http://localhost:8080`
- If on different server: `http://YOUR_ORACLEZ_SERVER_IP:8080`

### Create the Bridge:

```bash
./scripts/setup_oraclez_bridge.sh
```

You'll be prompted for:
- **Chainlink URL**: `http://localhost:6688` (if Chainlink is on this server)
- **Admin email**: Your Chainlink admin email
- **Admin password**: Your Chainlink admin password
- **Oraclez URL**: `http://localhost:8080` or `http://YOUR_ORACLEZ_IP:8080`

### View Example Jobs:

```bash
cat examples/oraclez_job_spec.toml
```

---

## Common GCP/Server Issues

### Issue: "Permission denied" when running scripts

**Solution:**
```bash
# Make scripts executable
chmod +x examples/test_oraclez_connection.sh
chmod +x scripts/setup_oraclez_bridge.sh
```

### Issue: Can't connect to Chainlink node

**Solution:**
```bash
# Check if Chainlink is running
sudo systemctl status chainlink

# Check logs
journalctl -u chainlink -f

# Or if using docker:
docker logs chainlink
```

### Issue: Firewall blocking connections

**Solution:**
```bash
# Check GCP firewall rules
gcloud compute firewall-rules list

# Allow Oraclez port (8080) if needed
gcloud compute firewall-rules create allow-oraclez \
    --allow tcp:8080 \
    --source-ranges YOUR_CHAINLINK_IP/32 \
    --description "Allow Chainlink to access Oraclez"

# Check local firewall (ufw)
sudo ufw status
sudo ufw allow 8080/tcp
```

### Issue: Connection timeout between servers

**Solution:**
```bash
# Test connectivity
ping YOUR_ORACLEZ_IP

# Test port connectivity
nc -zv YOUR_ORACLEZ_IP 8080

# Or using telnet
telnet YOUR_ORACLEZ_IP 8080
```

### Issue: Oraclez and Chainlink on different servers

**Solution:**
Make sure:
1. Oraclez server allows incoming connections from Chainlink IP
2. You use the external/public IP (not localhost) in bridge configuration
3. Firewall rules allow traffic on port 8080

```bash
# On Oraclez server - check what IP it's listening on
netstat -tulpn | grep 8080

# Should show 0.0.0.0:8080 (listens on all interfaces)
# If shows 127.0.0.1:8080 (only localhost), you need to change Oraclez config
```

---

## Quick Reference: Full Workflow

```bash
# 1. SSH into GCP server
gcloud compute ssh YOUR_INSTANCE_NAME --zone=YOUR_ZONE

# 2. Navigate to Chainlink directory
cd /path/to/chainlink

# 3. Test Oraclez connection
./examples/test_oraclez_connection.sh

# 4. Create bridge
./scripts/setup_oraclez_bridge.sh

# 5. View job example
cat examples/oraclez_job_spec.toml

# 6. Create job via Chainlink CLI
chainlink jobs create -f examples/oraclez_job_spec.toml

# OR via UI: Open http://YOUR_SERVER_IP:6688 in browser
```

---

## Need to Access Chainlink UI from Your Local Machine?

### Option 1: SSH Port Forwarding

```bash
# Forward Chainlink port 6688 to your local machine
gcloud compute ssh YOUR_INSTANCE_NAME --zone=YOUR_ZONE \
    -- -L 6688:localhost:6688

# Now access in your browser: http://localhost:6688
```

### Option 2: Allow External Access (Less Secure)

```bash
# Create firewall rule
gcloud compute firewall-rules create allow-chainlink-ui \
    --allow tcp:6688 \
    --source-ranges YOUR_LOCAL_IP/32 \
    --description "Allow access to Chainlink UI"

# Then access: http://YOUR_SERVER_EXTERNAL_IP:6688
```

**⚠️ Security Note:** Option 1 (SSH tunneling) is more secure for production!

---

## Summary

1. **Connect**: SSH into your GCP server
2. **Navigate**: Go to Chainlink directory
3. **Verify**: Check Chainlink and Oraclez are running
4. **Integrate**: Run the bridge setup scripts
5. **Create Jobs**: Use UI or CLI to create Chainlink jobs

For more details, see:
- `ORACLEZ_QUICKSTART_EXISTING.md` - For existing Oraclez users
- `ORACLEZ_QUICKSTART.md` - Full setup guide
- `docs/ORACLEZ_INTEGRATION.md` - Detailed integration docs
