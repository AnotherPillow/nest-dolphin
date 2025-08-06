#!/bin/bash
    
API_URL="https://nest.rip/api/files/upload"
API_KEY_FILE="${HOME}/.nest-key"

if [[ ! -f "$API_KEY_FILE" ]]; then
    echo "api key store file doesn't exist: $API_KEY_FILE"
    exit 1
fi

if [[ $# -ne 1 ]]; then
    echo "Exactly one argument (path to the file) is required."
    exit 1
fi

FILE_PATH=$1
if [[ ! -f "$FILE_PATH" ]]; then
    echo "File not found: $FILE_PATH"
    exit 1
fi

# read and trim file
API_KEY=$(<"$API_KEY_FILE")
API_KEY=${API_KEY//$'\r'/}
API_KEY=${API_KEY//$'\n'/}

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: $API_KEY" \
    -H "User-Agent: nest-dolphin/1.0.0" \
    -F "files=@${FILE_PATH}" \
    "$API_URL")

# Split body and status code
HTTP_BODY=$(printf "%s" "$RESPONSE" | head -n -1)
HTTP_CODE=$(printf "%s" "$RESPONSE" | tail -n1)

# ---- Check result ----------------------------------------------------
if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    # Successful upload – print the JSON payload returned by the API
    ACCESSIBLE_URL=$(printf "%s" "$HTTP_BODY" | jq -r '.accessibleURL')
    echo "Sucessfully uploaded to $ACCESSIBLE_URL"
    wl-copy "${ACCESSIBLE_URL}"
    echo "Copied to clipboard."
    exit 0
else
    echo "Upload failed (HTTP $HTTP_CODE). Server response: $HTTP_BODY"
    exit 1
fi