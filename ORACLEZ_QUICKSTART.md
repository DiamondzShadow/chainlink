# Oraclez Integration - Quick Start Guide

This is a quick start guide to connect your Chainlink node to the Oraclez YouTube Stats external adapter.

## 🚀 Choose Your Path

### ✅ Already Have Oraclez Built? (Skip to Connection)

**If you already have Oraclez running, skip to Step 3 below!**

You only need to:
1. Test your Oraclez connection: `./examples/test_oraclez_connection.sh`
2. Create the bridge in Chainlink: `./scripts/setup_oraclez_bridge.sh`
3. Create jobs that use the bridge

**[Jump to Step 3: Create Bridge in Chainlink](#3-create-bridge-in-chainlink)**

---

### 🆕 Need to Install Oraclez? (Start Here)

Follow steps 1-5 below if you need to set up Oraclez from scratch.

---

## Overview

Oraclez is an external adapter that fetches YouTube video statistics (views and likes). This guide will help you:
1. Set up the Oraclez server (if needed)
2. Connect it to your Chainlink node
3. Create jobs to fetch YouTube stats

## Prerequisites

**For everyone:**
- A running Chainlink node

**Only if installing Oraclez (Steps 1-2):**
- Node.js installed on your server (for Oraclez)
- YouTube Data API v3 key
- Supabase account

## Step-by-Step Setup

### 1. Deploy Oraclez on Your Server

**⚠️ SKIP THIS STEP if you already have Oraclez built and running!**

```bash
# Clone the Oraclez repository
git clone https://github.com/DiamondzShadow/Oraclez
cd Oraclez

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env
nano .env  # Edit with your credentials
```

Edit `.env` file with:
```env
PORT=8080
YOUTUBE_API_KEY=your_youtube_api_key_here
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key_here
INITIAL_LIKES_COUNT=0
```

Start Oraclez:
```bash
npm start
```

Verify it's running:
```bash
curl http://localhost:8080
```

### 2. Set Up Supabase Database

**⚠️ SKIP THIS STEP if you already have Oraclez configured!**

In your Supabase project, run this SQL:

```sql
CREATE TABLE adapter_state (
    id TEXT PRIMARY KEY,
    last_views_count INTEGER DEFAULT 0,
    last_likes_count INTEGER DEFAULT 0,
    last_likes_triggered_multiple INTEGER DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 3. Create Bridge in Chainlink

**✅ START HERE if you already have Oraclez running!**

This step connects your Chainlink node to your Oraclez server (whether you just built it or already had it).

#### Option A: Automated Setup (Recommended)

```bash
# From your Chainlink node workspace
cd /workspace
./scripts/setup_oraclez_bridge.sh
```

Follow the prompts to enter:
- Chainlink node URL (e.g., http://localhost:6688)
- Admin email and password
- Oraclez server URL (e.g., http://YOUR_SERVER_IP:8080)

#### Option B: Manual Setup via UI

1. Open your Chainlink node UI: http://localhost:6688
2. Navigate to **Bridges** → **New Bridge**
3. Fill in:
   - **Name**: `oraclez`
   - **URL**: `http://YOUR_SERVER_IP:8080`
   - **Confirmations**: `0`
4. Click **Create Bridge**
5. **Save the tokens** displayed!

### 4. Create a Job

Copy one of the example job specifications:

```bash
# View the examples
cat examples/oraclez_job_spec.toml
```

Create a job via:

**UI Method:**
1. Go to **Jobs** → **New Job**
2. Copy the job spec from `examples/oraclez_job_spec.toml`
3. Replace `YOUR_ORACLE_CONTRACT_ADDRESS` with your contract
4. Click **Create Job**

**CLI Method:**
```bash
chainlink jobs create -f examples/oraclez_job_spec.toml
```

### 5. Test the Integration

Test with a sample YouTube video:

```bash
# Test views endpoint
curl -X POST http://YOUR_ORACLEZ_SERVER:8080 \
  -H "Content-Type: application/json" \
  -d '{
    "id": "test-123",
    "data": {
      "videoId": "dQw4w9WgXcQ",
      "endpoint": "views"
    }
  }'

# Test likes endpoint
curl -X POST http://YOUR_ORACLEZ_SERVER:8080 \
  -H "Content-Type: application/json" \
  -d '{
    "id": "test-456",
    "data": {
      "videoId": "dQw4w9WgXcQ",
      "endpoint": "likes"
    }
  }'
```

Expected response:
```json
{
  "jobRunID": "test-123",
  "data": {
    "value": 1234567890,
    "views": 1234567890,
    "likes": 12345678,
    "shouldTrigger": true
  },
  "result": 1234567890,
  "statusCode": 200
}
```

## Common Issues & Solutions

### Issue: "Connection refused" when testing Oraclez

**Solution:** 
- Check if Oraclez is running: `ps aux | grep node`
- Verify the port: `netstat -tulpn | grep 8080`
- Check firewall rules: `sudo ufw status`

### Issue: "YouTube API quota exceeded"

**Solution:**
- Check your quota in Google Cloud Console
- Wait for quota reset (daily)
- Consider requesting quota increase

### Issue: Bridge not found in Chainlink

**Solution:**
- Verify bridge name matches in job spec and bridge configuration
- List bridges: `chainlink bridges list`
- Check bridge name is lowercase and contains only alphanumeric characters, hyphens, or underscores

### Issue: "Invalid API key" from Oraclez

**Solution:**
- Verify YouTube API key in `.env` file
- Ensure the key is enabled for YouTube Data API v3
- Check for any restrictions on the API key

## Next Steps

1. **Deploy Smart Contract**: Deploy an Oracle contract that can request data from your Chainlink node
2. **Request Data**: Call your oracle contract to trigger the Chainlink job
3. **Monitor**: Watch job runs in Chainlink UI under Jobs → [Job Name] → Runs
4. **Production**: Use HTTPS, add authentication, and implement proper monitoring

## File Reference

- **Integration Guide**: `docs/ORACLEZ_INTEGRATION.md` - Detailed integration documentation
- **Setup Script**: `scripts/setup_oraclez_bridge.sh` - Automated bridge setup
- **Job Examples**: `examples/oraclez_job_spec.toml` - Job specification templates

## Support

- **Oraclez Issues**: https://github.com/DiamondzShadow/Oraclez/issues
- **Chainlink Docs**: https://docs.chain.link/
- **Chainlink Discord**: https://discord.gg/chainlink

## Architecture Diagram

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│  Smart Contract │ ───────>│  Chainlink Node  │ ───────>│  Oraclez Server │
│   (On-chain)    │         │   (Off-chain)    │         │   (Your Server) │
└─────────────────┘         └──────────────────┘         └─────────────────┘
        │                           │                              │
        │                           │                              │
        │                      Bridge: oraclez              YouTube API v3
        │                           │                              │
        │                    ┌──────┴────────┐                    │
        │                    │ Job Pipelines │                    │
        │                    └───────────────┘                    │
        │                                                          │
        └────────<── Callback with data ──<─────────<─────────────┘
```

## How It Works

1. **Smart contract** makes a request to the Chainlink oracle
2. **Chainlink node** picks up the request via event monitoring
3. **Job pipeline** executes:
   - Decodes the request parameters
   - Calls the Oraclez bridge
   - Parses the response
   - Encodes the result
4. **Oraclez server** fetches data from YouTube API
5. **Response** is sent back through Chainlink to the smart contract

## Oraclez Features

### Views Endpoint
- Initial trigger: 525 views
- Subsequent triggers: Every 5 views (530, 535, 540, etc.)
- Use case: Track video popularity milestones

### Likes Endpoint
- Triggers: Every 25 likes (25, 50, 75, 100, etc.)
- Use case: Engagement-based rewards or triggers

### State Management
- Persistent state in Supabase
- Per-video tracking
- Automatic threshold management

## Production Checklist

- [ ] Oraclez running with process manager (PM2, systemd)
- [ ] HTTPS enabled with valid SSL certificate
- [ ] Firewall configured (only Chainlink node can access Oraclez)
- [ ] API keys secured and rotated regularly
- [ ] Monitoring and alerting set up
- [ ] Backup Chainlink node configuration
- [ ] Document oracle contract addresses
- [ ] Test failover scenarios
- [ ] Set up log aggregation
- [ ] Configure rate limiting

---

**Ready to go?** Start with step 1 and follow the guide sequentially. Each step builds on the previous one.
