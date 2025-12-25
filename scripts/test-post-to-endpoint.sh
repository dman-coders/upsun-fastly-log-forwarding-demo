#!/usr/bin/env bash
# Make a dummy POST to our log consumer.

LOG_RECEIVER_URL=$(upsun environment:url --primary --pipe)
ENDPOINT_URL="${LOG_RECEIVER_URL}log-receiver.php"

echo "Posting to endpoint URL: ${ENDPOINT_URL}"

curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "level": "info",
    "message": "This is a test log message from the test-post-to-endpoint.sh script.",
    "context": {
        "user": "test_user",
        "action": "test_post"
    },
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
}' \
  "${ENDPOINT_URL}"

