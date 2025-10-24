# Quick Start for Existing Oraclez Users

**You already have Oraclez built? Perfect! Here's your simplified path:**

## Your 3-Step Setup

### Step 1: Test Your Oraclez Connection

Make sure your Oraclez server is running, then test it:

```bash
cd /workspace
./examples/test_oraclez_connection.sh
```

This will prompt you for your Oraclez URL (e.g., `http://localhost:8080` or `http://YOUR_SERVER_IP:8080`)

**Expected result:** All tests should pass ✓

---

### Step 2: Create Bridge in Chainlink

Connect your Chainlink node to your Oraclez server:

```bash
./scripts/setup_oraclez_bridge.sh
```

You'll be prompted for:
- **Chainlink URL**: Usually `http://localhost:6688`
- **Admin email**: Your Chainlink admin email
- **Admin password**: Your Chainlink admin password  
- **Oraclez URL**: Where your Oraclez is running (e.g., `http://YOUR_SERVER_IP:8080`)
- **Bridge name**: Press Enter to use default `oraclez`

**Expected result:** Bridge created successfully ✓

---

### Step 3: Create a Chainlink Job

View the example job specification:

```bash
cat examples/oraclez_job_spec.toml
```

Create the job:

**Option A - Via Chainlink UI:**
1. Open http://localhost:6688
2. Go to **Jobs** → **New Job**
3. Copy the job spec from `examples/oraclez_job_spec.toml`
4. Replace `YOUR_ORACLE_CONTRACT_ADDRESS` with your actual contract address
5. Click **Create Job**

**Option B - Via CLI:**
```bash
# Edit the job spec first to add your oracle contract address
nano examples/oraclez_job_spec.toml

# Then create it
chainlink jobs create -f examples/oraclez_job_spec.toml
```

---

## That's It! 🎉

Your Chainlink node is now connected to Oraclez. 

### Next Steps:
1. Deploy an Oracle smart contract (if you haven't already)
2. Make a request from your contract to trigger the Chainlink job
3. Monitor job runs in Chainlink UI: **Jobs** → **[Your Job]** → **Runs**

### Troubleshooting:

**Bridge not found error:**
```bash
chainlink bridges list
```
Make sure the bridge name matches what's in your job spec.

**Connection refused:**
- Check if Oraclez is running: `ps aux | grep node`
- Verify the port: `netstat -tulpn | grep 8080`
- Check firewall rules if Oraclez is on a different server

**For more help:**
- Full integration guide: `docs/ORACLEZ_INTEGRATION.md`
- Complete quickstart: `ORACLEZ_QUICKSTART.md`
