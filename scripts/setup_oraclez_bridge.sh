#!/bin/bash

# Setup Oraclez Bridge for Chainlink Node
# This script creates a bridge connection to the Oraclez external adapter

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Oraclez Bridge Setup for Chainlink ===${NC}\n"

# Check if required tools are installed
command -v curl >/dev/null 2>&1 || { echo -e "${RED}Error: curl is required but not installed.${NC}" >&2; exit 1; }

# Get configuration from environment variables or prompt user
if [ -z "$CHAINLINK_URL" ]; then
    read -p "Enter Chainlink node URL (default: http://localhost:6688): " CHAINLINK_URL
    CHAINLINK_URL=${CHAINLINK_URL:-http://localhost:6688}
fi

if [ -z "$CHAINLINK_EMAIL" ]; then
    read -p "Enter Chainlink admin email: " CHAINLINK_EMAIL
fi

if [ -z "$CHAINLINK_PASSWORD" ]; then
    read -sp "Enter Chainlink admin password: " CHAINLINK_PASSWORD
    echo ""
fi

if [ -z "$ORACLEZ_URL" ]; then
    read -p "Enter Oraclez server URL (e.g., http://YOUR_SERVER_IP:8080): " ORACLEZ_URL
fi

if [ -z "$BRIDGE_NAME" ]; then
    read -p "Enter bridge name (default: oraclez): " BRIDGE_NAME
    BRIDGE_NAME=${BRIDGE_NAME:-oraclez}
fi

# Validate inputs
if [ -z "$CHAINLINK_EMAIL" ] || [ -z "$CHAINLINK_PASSWORD" ] || [ -z "$ORACLEZ_URL" ]; then
    echo -e "${RED}Error: Missing required configuration${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Configuration:${NC}"
echo "  Chainlink URL: $CHAINLINK_URL"
echo "  Bridge Name: $BRIDGE_NAME"
echo "  Oraclez URL: $ORACLEZ_URL"
echo ""

# Test Oraclez connectivity
echo -e "${YELLOW}Testing Oraclez server connectivity...${NC}"
if curl -s -f -X POST "$ORACLEZ_URL" \
    -H "Content-Type: application/json" \
    -d '{"id":"test","data":{"videoId":"dQw4w9WgXcQ","endpoint":"views"}}' > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Oraclez server is accessible${NC}"
else
    echo -e "${RED}✗ Warning: Cannot connect to Oraclez server at $ORACLEZ_URL${NC}"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Login to Chainlink node
echo -e "\n${YELLOW}Logging into Chainlink node...${NC}"
COOKIE_FILE=$(mktemp)
LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${CHAINLINK_URL}/sessions" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${CHAINLINK_EMAIL}\",\"password\":\"${CHAINLINK_PASSWORD}\"}" \
    -c "$COOKIE_FILE")

HTTP_CODE=$(echo "$LOGIN_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$LOGIN_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo -e "${RED}✗ Login failed (HTTP $HTTP_CODE)${NC}"
    echo "Response: $RESPONSE_BODY"
    rm -f "$COOKIE_FILE"
    exit 1
fi

echo -e "${GREEN}✓ Successfully logged in${NC}"

# Check if bridge already exists
echo -e "\n${YELLOW}Checking if bridge already exists...${NC}"
BRIDGE_CHECK=$(curl -s -w "\n%{http_code}" -X GET "${CHAINLINK_URL}/v2/bridge_types/${BRIDGE_NAME}" \
    -b "$COOKIE_FILE")

BRIDGE_CHECK_CODE=$(echo "$BRIDGE_CHECK" | tail -n1)

if [ "$BRIDGE_CHECK_CODE" = "200" ]; then
    echo -e "${YELLOW}⚠ Bridge '$BRIDGE_NAME' already exists${NC}"
    read -p "Do you want to update it? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Update existing bridge
        echo -e "\n${YELLOW}Updating bridge...${NC}"
        UPDATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "${CHAINLINK_URL}/v2/bridge_types/${BRIDGE_NAME}" \
            -H "Content-Type: application/json" \
            -b "$COOKIE_FILE" \
            -d "{
                \"name\": \"${BRIDGE_NAME}\",
                \"url\": \"${ORACLEZ_URL}\",
                \"confirmations\": 0,
                \"minimumContractPayment\": \"0\"
            }")
        
        UPDATE_HTTP_CODE=$(echo "$UPDATE_RESPONSE" | tail -n1)
        UPDATE_BODY=$(echo "$UPDATE_RESPONSE" | sed '$d')
        
        if [ "$UPDATE_HTTP_CODE" = "200" ]; then
            echo -e "${GREEN}✓ Bridge updated successfully${NC}"
            echo -e "\n${GREEN}Bridge Details:${NC}"
            echo "$UPDATE_BODY" | python3 -m json.tool 2>/dev/null || echo "$UPDATE_BODY"
        else
            echo -e "${RED}✗ Failed to update bridge (HTTP $UPDATE_HTTP_CODE)${NC}"
            echo "Response: $UPDATE_BODY"
            rm -f "$COOKIE_FILE"
            exit 1
        fi
    else
        echo -e "${YELLOW}Bridge creation skipped${NC}"
    fi
else
    # Create new bridge
    echo -e "\n${YELLOW}Creating new bridge...${NC}"
    CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${CHAINLINK_URL}/v2/bridge_types" \
        -H "Content-Type: application/json" \
        -b "$COOKIE_FILE" \
        -d "{
            \"name\": \"${BRIDGE_NAME}\",
            \"url\": \"${ORACLEZ_URL}\",
            \"confirmations\": 0,
            \"minimumContractPayment\": \"0\"
        }")
    
    CREATE_HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -n1)
    CREATE_BODY=$(echo "$CREATE_RESPONSE" | sed '$d')
    
    if [ "$CREATE_HTTP_CODE" = "200" ] || [ "$CREATE_HTTP_CODE" = "201" ]; then
        echo -e "${GREEN}✓ Bridge created successfully${NC}"
        echo -e "\n${GREEN}Bridge Details:${NC}"
        echo "$CREATE_BODY" | python3 -m json.tool 2>/dev/null || echo "$CREATE_BODY"
        
        # Extract and display authentication tokens
        echo -e "\n${YELLOW}⚠ IMPORTANT: Save these authentication tokens securely!${NC}"
        INCOMING_TOKEN=$(echo "$CREATE_BODY" | grep -o '"incomingToken":"[^"]*"' | cut -d'"' -f4)
        OUTGOING_TOKEN=$(echo "$CREATE_BODY" | grep -o '"outgoingToken":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$INCOMING_TOKEN" ]; then
            echo "  Incoming Token: $INCOMING_TOKEN"
        fi
        if [ -n "$OUTGOING_TOKEN" ]; then
            echo "  Outgoing Token: $OUTGOING_TOKEN"
        fi
    else
        echo -e "${RED}✗ Failed to create bridge (HTTP $CREATE_HTTP_CODE)${NC}"
        echo "Response: $CREATE_BODY"
        rm -f "$COOKIE_FILE"
        exit 1
    fi
fi

# Cleanup
rm -f "$COOKIE_FILE"

echo -e "\n${GREEN}=== Setup Complete ===${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Create a job that uses the '$BRIDGE_NAME' bridge"
echo "  2. Test the integration with a sample YouTube video ID"
echo "  3. See docs/ORACLEZ_INTEGRATION.md for example job specifications"
echo ""
