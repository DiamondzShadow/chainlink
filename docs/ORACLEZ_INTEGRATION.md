# Oraclez Integration Guide

This guide explains how to integrate the Oraclez YouTube Stats External Adapter with your Chainlink node.

## Overview

Oraclez is a Chainlink External Adapter that fetches YouTube video statistics (views and likes) and manages state using Supabase. This adapter triggers events based on configurable thresholds for views and likes.

Repository: https://github.com/DiamondzShadow/Oraclez

## Prerequisites

1. Oraclez adapter running on a server (accessible via HTTP/HTTPS)
2. Running Chainlink node with API access
3. Chainlink node admin credentials

## Setup Steps

### 1. Deploy Oraclez Adapter

First, ensure the Oraclez adapter is running on your server:

```bash
# Clone Oraclez repository
git clone https://github.com/DiamondzShadow/Oraclez
cd Oraclez

# Install dependencies
npm install

# Configure environment variables
cp .env.example .env
# Edit .env with your YouTube API key, Supabase credentials, etc.

# Start the server
npm start
```

The adapter will run on port 8080 by default (configurable via PORT environment variable).

### 2. Create Bridge in Chainlink Node

#### Option A: Using the Chainlink UI

1. Navigate to your Chainlink node UI (default: http://localhost:6688)
2. Login with your admin credentials
3. Go to **Bridges** → **New Bridge**
4. Fill in the bridge details:
   - **Bridge Name**: `oraclez` (or your preferred name)
   - **Bridge URL**: `http://YOUR_SERVER_IP:8080` (replace with your Oraclez server URL)
   - **Confirmations**: `0` (optional, adjust as needed)
   - **Minimum Contract Payment**: `0` (optional)
5. Click **Create Bridge**
6. **Save the authentication tokens** displayed after creation

#### Option B: Using the API/CLI

Use the provided script to create the bridge automatically:

```bash
./scripts/setup_oraclez_bridge.sh
```

Or manually using curl:

```bash
# Set your Chainlink node credentials
export CHAINLINK_URL="http://localhost:6688"
export CHAINLINK_EMAIL="your-admin@email.com"
export CHAINLINK_PASSWORD="your-password"

# Login and get session cookie
curl -X POST "${CHAINLINK_URL}/sessions" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${CHAINLINK_EMAIL}\",\"password\":\"${CHAINLINK_PASSWORD}\"}" \
  -c cookies.txt

# Create the bridge
curl -X POST "${CHAINLINK_URL}/v2/bridge_types" \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{
    "name": "oraclez",
    "url": "http://YOUR_SERVER_IP:8080",
    "confirmations": 0,
    "minimumContractPayment": "0"
  }'
```

### 3. Verify Bridge Connection

Test the bridge connection:

```bash
# Test directly with Oraclez
curl -X POST http://YOUR_SERVER_IP:8080 \
  -H "Content-Type: application/json" \
  -d '{
    "id": "test-123",
    "data": {
      "videoId": "dQw4w9WgXcQ",
      "endpoint": "views"
    }
  }'
```

### 4. Create Chainlink Job

Create a job that uses the Oraclez bridge. See `examples/oraclez_job_spec.toml` for example job specifications.

#### Example Job for Views:

```toml
type = "directrequest"
schemaVersion = 1
name = "YouTube Views Job"
maxTaskDuration = "0s"
contractAddress = "YOUR_ORACLE_CONTRACT_ADDRESS"
minIncomingConfirmations = 0
observationSource = """
    decode_log   [type="ethabidecodelog"
                  abi="OracleRequest(bytes32 indexed specId, address requester, bytes32 requestId, uint256 payment, address callbackAddr, bytes4 callbackFunctionId, uint256 cancelExpiration, uint256 dataVersion, bytes data)"
                  data="$(jobRun.logData)"
                  topics="$(jobRun.logTopics)"]

    decode_cbor  [type="cborparse" data="$(decode_log.data)"]
    
    fetch        [type="bridge"
                  name="oraclez"
                  requestData="{\\"id\\": $(jobSpec.externalJobID), \\"data\\": {\\"videoId\\": $(decode_cbor.videoId), \\"endpoint\\": \\"views\\"}}"]
    
    parse        [type="jsonparse" path="data,value" data="$(fetch)"]
    
    encode_data  [type="ethabiencode"
                  abi="(uint256 value)"
                  data="{\\"value\\": $(parse)}"]
    
    encode_tx    [type="ethabiencode"
                  abi="fulfillOracleRequest(bytes32 requestId, uint256 payment, address callbackAddress, bytes4 callbackFunctionId, uint256 expiration, bytes32 data)"
                  data="{\\"requestId\\": $(decode_log.requestId), \\"payment\\": $(decode_log.payment), \\"callbackAddress\\": $(decode_log.callbackAddr), \\"callbackFunctionId\\": $(decode_log.callbackFunctionId), \\"expiration\\": $(decode_log.cancelExpiration), \\"data\\": $(encode_data)}"]

    submit_tx    [type="ethtx" to="YOUR_ORACLE_CONTRACT_ADDRESS" data="$(encode_tx)"]

    decode_log -> decode_cbor -> fetch -> parse -> encode_data -> encode_tx -> submit_tx
"""
```

#### Example Job for Likes:

```toml
type = "directrequest"
schemaVersion = 1
name = "YouTube Likes Job"
maxTaskDuration = "0s"
contractAddress = "YOUR_ORACLE_CONTRACT_ADDRESS"
minIncomingConfirmations = 0
observationSource = """
    decode_log   [type="ethabidecodelog"
                  abi="OracleRequest(bytes32 indexed specId, address requester, bytes32 requestId, uint256 payment, address callbackAddr, bytes4 callbackFunctionId, uint256 cancelExpiration, uint256 dataVersion, bytes data)"
                  data="$(jobRun.logData)"
                  topics="$(jobRun.logTopics)"]

    decode_cbor  [type="cborparse" data="$(decode_log.data)"]
    
    fetch        [type="bridge"
                  name="oraclez"
                  requestData="{\\"id\\": $(jobSpec.externalJobID), \\"data\\": {\\"videoId\\": $(decode_cbor.videoId), \\"endpoint\\": \\"likes\\"}}"]
    
    parse        [type="jsonparse" path="data,value" data="$(fetch)"]
    
    encode_data  [type="ethabiencode"
                  abi="(uint256 value)"
                  data="{\\"value\\": $(parse)}"]
    
    encode_tx    [type="ethabiencode"
                  abi="fulfillOracleRequest(bytes32 requestId, uint256 payment, address callbackAddress, bytes4 callbackFunctionId, uint256 expiration, bytes32 data)"
                  data="{\\"requestId\\": $(decode_log.requestId), \\"payment\\": $(decode_log.payment), \\"callbackAddress\\": $(decode_log.callbackAddr), \\"callbackFunctionId\\": $(decode_log.callbackFunctionId), \\"expiration\\": $(decode_log.cancelExpiration), \\"data\\": $(encode_data)}"]

    submit_tx    [type="ethtx" to="YOUR_ORACLE_CONTRACT_ADDRESS" data="$(encode_tx)"]

    decode_log -> decode_cbor -> fetch -> parse -> encode_data -> encode_tx -> submit_tx
"""
```

## Configuration Options

### Oraclez Endpoints

The Oraclez adapter supports two endpoints:

1. **views**: Returns YouTube video view count
   - Triggers at 525 views initially, then every 5 views
2. **likes**: Returns YouTube video like count
   - Triggers at every 25-like milestone

### Request Format

```json
{
  "id": "job-run-id",
  "data": {
    "videoId": "YOUTUBE_VIDEO_ID",
    "endpoint": "views" // or "likes"
  }
}
```

### Response Format

```json
{
  "jobRunID": "job-run-id",
  "data": {
    "value": 1234,
    "views": 1234,
    "likes": 56,
    "shouldTrigger": true
  },
  "result": 1234,
  "statusCode": 200
}
```

## Troubleshooting

### Bridge Connection Issues

1. Verify Oraclez server is running:
   ```bash
   curl http://YOUR_SERVER_IP:8080
   ```

2. Check Chainlink node logs:
   ```bash
   chainlink admin logs
   ```

3. Verify bridge configuration:
   ```bash
   chainlink bridges list
   ```

### Common Errors

- **Bridge not found**: Ensure the bridge name in your job matches the created bridge name
- **Connection refused**: Check if Oraclez server is accessible from Chainlink node
- **Invalid video ID**: Verify YouTube video ID is correct
- **API quota exceeded**: Check YouTube API quota in Google Cloud Console

## Security Considerations

1. **HTTPS**: Use HTTPS for production deployments of Oraclez
2. **Authentication**: Consider adding authentication between Chainlink and Oraclez
3. **Firewall**: Restrict Oraclez server access to only your Chainlink node IP
4. **API Keys**: Keep YouTube API keys and Supabase credentials secure
5. **Rate Limiting**: Monitor YouTube API usage to avoid quota issues

## Additional Resources

- [Chainlink External Adapters Documentation](https://docs.chain.link/chainlink-nodes/external-adapters/external-adapters)
- [Chainlink Jobs Documentation](https://docs.chain.link/chainlink-nodes/oracle-jobs/jobs)
- [Oraclez Repository](https://github.com/DiamondzShadow/Oraclez)

## Support

For issues related to:
- **Oraclez adapter**: Open an issue at https://github.com/DiamondzShadow/Oraclez/issues
- **Chainlink integration**: Check Chainlink documentation or Discord community
