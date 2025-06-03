#!/bin/bash

CANARY_IP="YOUR_CANARY_IP"  # Pick an IP for your canary, must be on the same subnet as the server you are planning to shut down
THRESHOLD_MINUTES=5        # Minutes to tolerate silence before shutting down
STATUS_FILE="/tmp/canary.lastseen"  # Where we record last successful CHIRP time

# Function to check if canary responds with CHIRP
ping_canary() {
  curl -sf "http://$CANARY_IP/" | grep -q "CHIRP"  # silent + fail-fast, look for "CHIRP"
}

now_ts=$(date +%s)  # current Unix timestamp

# Check for chirp
if ping_canary; then
  echo "$now_ts" > "$STATUS_FILE"                  # save timestamp of last chirp
  echo "✅ Canary chirped."                         # optional: log for debugging
else
  last_seen=$(cat "$STATUS_FILE" 2>/dev/null || echo 0)  # read last timestamp or fallback to 0
  elapsed=$(( (now_ts - last_seen) / 60 ))               # time since last chirp, in minutes

  echo "⚠️ No chirp in $elapsed minutes."

  # If silence exceeds threshold, shut it all down
  if [ "$elapsed" -ge "$THRESHOLD_MINUTES" ]; then
    echo "💀 Canary is dead. Shutting down MU/TH/UR."
    shutdown -h now
  fi
fi
