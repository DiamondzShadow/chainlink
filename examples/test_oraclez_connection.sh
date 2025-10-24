#!/bin/bash

# Test Oraclez Connection Script
# This script tests the connection between Chainlink and Oraclez

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Oraclez Connection Test ===${NC}\n"

# Get Oraclez URL
if [ -z "$ORACLEZ_URL" ]; then
    read -p "Enter Oraclez server URL (e.g., http://localhost:8080): " ORACLEZ_URL
fi

# Sample YouTube video ID (Rick Astley - Never Gonna Give You Up)
TEST_VIDEO_ID="dQw4w9WgXcQ"

echo -e "${YELLOW}Testing Oraclez at: $ORACLEZ_URL${NC}\n"

# Test 1: Server accessibility
echo -e "${YELLOW}[Test 1/4]${NC} Checking server accessibility..."
if curl -s -f -m 5 "$ORACLEZ_URL" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Server is accessible${NC}"
else
    echo -e "${RED}✗ Cannot connect to server${NC}"
    echo -e "${YELLOW}  Make sure Oraclez is running on $ORACLEZ_URL${NC}"
    exit 1
fi

# Test 2: Views endpoint
echo -e "\n${YELLOW}[Test 2/4]${NC} Testing views endpoint..."
VIEWS_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ORACLEZ_URL" \
    -H "Content-Type: application/json" \
    -d "{
        \"id\": \"test-views-$(date +%s)\",
        \"data\": {
            \"videoId\": \"$TEST_VIDEO_ID\",
            \"endpoint\": \"views\"
        }
    }")

VIEWS_HTTP_CODE=$(echo "$VIEWS_RESPONSE" | tail -n1)
VIEWS_BODY=$(echo "$VIEWS_RESPONSE" | sed '$d')

if [ "$VIEWS_HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Views endpoint working${NC}"
    echo -e "${BLUE}Response:${NC}"
    echo "$VIEWS_BODY" | python3 -m json.tool 2>/dev/null || echo "$VIEWS_BODY"
    
    # Extract views count
    VIEWS_COUNT=$(echo "$VIEWS_BODY" | grep -o '"views":[0-9]*' | grep -o '[0-9]*')
    if [ -n "$VIEWS_COUNT" ]; then
        echo -e "${GREEN}  Views Count: $VIEWS_COUNT${NC}"
    fi
else
    echo -e "${RED}✗ Views endpoint failed (HTTP $VIEWS_HTTP_CODE)${NC}"
    echo "Response: $VIEWS_BODY"
fi

# Test 3: Likes endpoint
echo -e "\n${YELLOW}[Test 3/4]${NC} Testing likes endpoint..."
LIKES_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ORACLEZ_URL" \
    -H "Content-Type: application/json" \
    -d "{
        \"id\": \"test-likes-$(date +%s)\",
        \"data\": {
            \"videoId\": \"$TEST_VIDEO_ID\",
            \"endpoint\": \"likes\"
        }
    }")

LIKES_HTTP_CODE=$(echo "$LIKES_RESPONSE" | tail -n1)
LIKES_BODY=$(echo "$LIKES_RESPONSE" | sed '$d')

if [ "$LIKES_HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Likes endpoint working${NC}"
    echo -e "${BLUE}Response:${NC}"
    echo "$LIKES_BODY" | python3 -m json.tool 2>/dev/null || echo "$LIKES_BODY"
    
    # Extract likes count
    LIKES_COUNT=$(echo "$LIKES_BODY" | grep -o '"likes":[0-9]*' | grep -o '[0-9]*')
    if [ -n "$LIKES_COUNT" ]; then
        echo -e "${GREEN}  Likes Count: $LIKES_COUNT${NC}"
    fi
else
    echo -e "${RED}✗ Likes endpoint failed (HTTP $LIKES_HTTP_CODE)${NC}"
    echo "Response: $LIKES_BODY"
fi

# Test 4: Response format validation
echo -e "\n${YELLOW}[Test 4/4]${NC} Validating response format..."
VALIDATION_ERRORS=0

# Check if response has required fields
if echo "$VIEWS_BODY" | grep -q '"jobRunID"'; then
    echo -e "${GREEN}✓ jobRunID field present${NC}"
else
    echo -e "${RED}✗ Missing jobRunID field${NC}"
    VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

if echo "$VIEWS_BODY" | grep -q '"data"'; then
    echo -e "${GREEN}✓ data field present${NC}"
else
    echo -e "${RED}✗ Missing data field${NC}"
    VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

if echo "$VIEWS_BODY" | grep -q '"value"'; then
    echo -e "${GREEN}✓ value field present${NC}"
else
    echo -e "${RED}✗ Missing value field${NC}"
    VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

if echo "$VIEWS_BODY" | grep -q '"statusCode"'; then
    echo -e "${GREEN}✓ statusCode field present${NC}"
else
    echo -e "${RED}✗ Missing statusCode field${NC}"
    VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

# Test with invalid video ID
echo -e "\n${YELLOW}[Bonus Test]${NC} Testing error handling with invalid video ID..."
ERROR_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ORACLEZ_URL" \
    -H "Content-Type: application/json" \
    -d "{
        \"id\": \"test-error-$(date +%s)\",
        \"data\": {
            \"videoId\": \"invalid_video_id_xyz\",
            \"endpoint\": \"views\"
        }
    }")

ERROR_HTTP_CODE=$(echo "$ERROR_RESPONSE" | tail -n1)

if [ "$ERROR_HTTP_CODE" != "200" ]; then
    echo -e "${GREEN}✓ Error handling works correctly${NC}"
else
    echo -e "${YELLOW}⚠ Server returned 200 for invalid video ID (may need checking)${NC}"
fi

# Summary
echo -e "\n${BLUE}=== Test Summary ===${NC}"
if [ "$VIEWS_HTTP_CODE" = "200" ] && [ "$LIKES_HTTP_CODE" = "200" ] && [ "$VALIDATION_ERRORS" = "0" ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo -e "${GREEN}✓ Oraclez is working correctly${NC}"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "  1. Create a bridge in your Chainlink node: ./scripts/setup_oraclez_bridge.sh"
    echo "  2. Create a job using the bridge: see examples/oraclez_job_spec.toml"
    echo "  3. Test the complete integration with a smart contract"
else
    echo -e "${RED}✗ Some tests failed${NC}"
    if [ "$VALIDATION_ERRORS" != "0" ]; then
        echo -e "${RED}  $VALIDATION_ERRORS validation error(s) found${NC}"
    fi
    echo -e "\n${YELLOW}Troubleshooting:${NC}"
    echo "  1. Check Oraclez logs for errors"
    echo "  2. Verify environment variables (.env file)"
    echo "  3. Ensure YouTube API key is valid"
    echo "  4. Check Supabase connection"
    exit 1
fi

echo ""
