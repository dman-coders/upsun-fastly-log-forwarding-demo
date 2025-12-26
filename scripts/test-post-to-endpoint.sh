#!/usr/bin/env bash
# Make a dummy POST to our log consumer.

LOG_RECEIVER_URL=$(upsun environment:url --primary --pipe)
ENDPOINT_URL="${LOG_RECEIVER_URL}log-receiver.php"

echo "Posting to endpoint URL: ${ENDPOINT_URL}"
LOG_LINE="1.2.3.4 - - $(date -u +"[%d/%b/%Y:%H:%M:%S +0000]") \"GET /dummy.html HTTP/1.1\" 200 43 \"-\" \"Log receiver tester\""
curl -X POST \
  -H "Content-Type: text/plain" \
  --data-binary "${LOG_LINE}" \
  "${ENDPOINT_URL}"