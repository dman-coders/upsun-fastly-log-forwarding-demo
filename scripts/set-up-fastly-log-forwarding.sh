#!/usr/bin/env bash

# Given a Fastly service, add log forwarding to it that sends logs here.

# The $FASTLY_API_SERVICE $FASTLY_API_TOKEN parameters must be available in the environment or presented as arguments.
FASTLY_API_SERVICE=${FASTLY_API_SERVICE:=$1}
FASTLY_API_TOKEN=${FASTLY_API_TOKEN:=$2}
FASTLY_API_URL="https://api.fastly.com"

if [ -z "$FASTLY_API_SERVICE" ] || [ -z "$FASTLY_API_TOKEN" ]; then
  echo " \$FASTLY_API_SERVICE and \$FASTLY_API_TOKEN parameters must be either set in the environment or given as parameters to this utility"
  echo "To retrieve the values, try the following, then run this again"
  echo "export PLATFORM_PROJECT=abcdef123456"
  echo "PLATFORM_CLI=\"\${PLATFORM_CLI:-upsun}\""
  echo "export FASTLY_API_SERVICE=\$(\$PLATFORM_CLI ssh \"echo \\\$FASTLY_API_SERVICE\" | sed -e 's/[[:space:]]//g' )"
  echo "export FASTLY_API_TOKEN=\$(\$PLATFORM_CLI ssh \"echo \\\$FASTLY_API_TOKEN\" | sed -e 's/[[:space:]]//g' )"
  exit 1
fi

# The ENDPOINT_URL where logs will be posted to must also be provided.
if [ -z "$ENDPOINT_URL" ] ; then
  echo "Please define the ENDPOINT_URL of the service that will be receiving these logs."
  echo "LOG_RECEIVER_URL=\$(upsun --project=$RECEIVER_PROJECT environment:url --primary --pipe)"
  echo "export ENDPOINT_URL=\"\${ENDPOINT_URL:=\${LOG_RECEIVER_URL}log-receiver.php}\" "
fi

####
# Begin

echo "Setting up to forward logs from Fastly service $FASTLY_API_SERVICE to our endpoint $ENDPOINT_URL"

# 1. Get the current active version
echo "Fetching current service version"
CURRENT_VERSION=$(curl -s -H "Fastly-Key: $FASTLY_API_TOKEN" \
    "${FASTLY_API_URL}/service/${FASTLY_API_SERVICE}/details" \
    | jq -r ".active_version.number")

echo "Current active version: $CURRENT_VERSION"

# 2. Clone the active version to create a new editable version
NEW_VERSION=$(curl -s -X PUT -H "Fastly-Key: $FASTLY_API_TOKEN" \
    "${FASTLY_API_URL}/service/${FASTLY_API_SERVICE}/version/${CURRENT_VERSION}/clone" \
    | jq -r ".number")

echo "Created new version: $NEW_VERSION"
# 3. Create the HTTPS logging endpoint
# See: https://developer.fastly.com/reference/api/logging/https/
# Note that we set the custom format.

# As I'm using this to test, first delete any pre-existing log forwarding directives.
# Get all HTTPS logging endpoint names and delete them
curl -s -H "Fastly-Key: $FASTLY_API_TOKEN" \
    "${FASTLY_API_URL}/service/${FASTLY_API_SERVICE}/version/${NEW_VERSION}/logging/https" \
    | jq -r '.[] | .name' \
    | while read endpoint_name; do
        echo "Deleting endpoint: $endpoint_name"
        curl -s -X DELETE \
            -H "Fastly-Key: $FASTLY_API_TOKEN" \
            "${FASTLY_API_URL}/service/${FASTLY_API_SERVICE}/version/${NEW_VERSION}/logging/https/${endpoint_name}"
        echo ""
    done

echo "Creating new log forwarding target at $FASTLY_API_URL ..."

LOG_FORMAT='format=%h %l %u %t "%r" %>s %b "%{Referer}i" "%{User-Agent}i" %{Fastly-Debug-State}o %{Age}o'
UPDATED=$(curl -s -X POST \
    -H "Fastly-Key: $FASTLY_API_TOKEN" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H 'Accept: application/json' \
    "${FASTLY_API_URL}/service/${FASTLY_API_SERVICE}/version/${NEW_VERSION}/logging/https" \
    -d 'name=fastly-log-consumer' \
    -d "url=${ENDPOINT_URL}" \
    -d 'method=POST' \
    --data-urlencode "format=$LOG_FORMAT" \
    -d 'format_version=2'
)

# Check that succeeded.
# Don't want to release the new draft if it didn't work
#
# MAY FAIL - the JSON that Fastly gives me may be INVALID due to quote/encoding issues !
# I can't always verify the response. But hopefully that is hard to replicate
# (I sent `\` encoded quotes in the format string. ,was bad)
UPDATED_NAME=$( echo $UPDATED | jq -r ".name" );
if [ "$UPDATED_NAME" != 'fastly-log-consumer' ] ; then
  echo "Failed to create log forwarding rule for some reason. Sorry. $UPDATED"
  exit 1;
fi

# 4. Add a comment to the version
curl -s -X PUT -H "Fastly-Key: $FASTLY_API_TOKEN" \
    "${FASTLY_API_URL}/service/${FASTLY_API_SERVICE}/version/${NEW_VERSION}" \
    -d "comment=Added HTTPS log forwarding endpoint" \
    | jq -r ".comment"

# 5. Validate the new version (optional but recommended)
VALIDATION=$(curl -s -H "Fastly-Key: $FASTLY_API_TOKEN" \
    "${FASTLY_API_URL}/service/${FASTLY_API_SERVICE}/version/${NEW_VERSION}/validate" \
    | jq)
VALIDATION_STATUS=$( echo $VALIDATION | jq -r ".status" );
if [ "$VALIDATION_STATUS" != 'ok' ] ; then
  echo "Failed to validate new service version. $VALIDATION"
  exit 1;
fi

# 6. Activate the new version
echo "Activating new version $NEW_VERSION..."
curl -s -X PUT -H "Fastly-Key: $FASTLY_API_TOKEN" \
    "${FASTLY_API_URL}/service/${FASTLY_API_SERVICE}/version/${NEW_VERSION}/activate" \
    | jq -r ".number,.active"

echo
echo "The Fastly service is now configured to be POSTing logs to the endpoint."
echo "Note that the challenge response still needs to be set up manually in your log consumer project before activating the logging endpoint."

# REVIEW

# Check the logging endpoints on the active version

ACTIVE_VERSION=$(curl -s -H "Fastly-Key: $FASTLY_API_TOKEN" \
    "${FASTLY_API_URL}/service/${FASTLY_API_SERVICE}/details" \
    | jq -r ".active_version.number")

echo "Review the active log forwarding rule:"
curl -s -H "Fastly-Key: $FASTLY_API_TOKEN" \
    "${FASTLY_API_URL}/service/${FASTLY_API_SERVICE}/version/${ACTIVE_VERSION}/logging/https" \
    | jq
