#!/bin/bash

CANARY_IP="YOUR_CANARY_IP"               # IP of the ESP32 Canary
THRESHOLD_MINUTES=5                     # Minutes of silence before shutdown
STATUS_FILE="/dev/shm/canary.lastseen" # RAM-based file for last chirp timestamp

# Timestamped logger
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Check if the canary responds with any HTTP 200 OK
ping_canary() {
  curl -sf -o - "http://$CANARY_IP/" > /dev/null
  # Or: ping -c1 "$CANARY_IP" &>/dev/null  # Swap if using ICMP
}

now_ts=$EPOCHSECONDS  # Get current time (bash builtin)

if ping_canary; then
  echo "$now_ts" > "$STATUS_FILE"
  log "✅ Canary chirped."
else
  last_seen=0
  [ -s "$STATUS_FILE" ] && last_seen=$(<"$STATUS_FILE")
  elapsed=$(( (now_ts - last_seen) / 60 ))

  log "⚠️ No chirp in $elapsed minutes."

  if [ "$elapsed" -ge "$THRESHOLD_MINUTES" ]; then
    log "💀 Canary is dead. Shutting down MU/TH/UR."
    shutdown -h now
  fi
fi
