#!/bin/bash
# canary-watchdog.sh
# A lightweight Bash script that monitors an ESP32 "Dead Canary" and safely shuts down the server
# if it stops chirping (responding over HTTP) for a set duration.
# Designed for homelab setups where the canary reboots on power restoration and your server is on a UPS.

CANARY_IP="192.168.86.25"               # IP address of your Dead Canary (ESP32 with static IP), match with your static IP in your canary-esp32.ino
THRESHOLD_MINUTES=5                     # Minutes without a chirp before initiating shutdown
STATUS_FILE="/dev/shm/canary.lastseen" # Stores last successful chirp time (uses tmpfs for no disk wear)

# --- Timestamped Logger ---
# Adds date/time to all output, useful for logs or journal tracking
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# --- Chirp Checker ---
# Pings the canary using HTTP and checks if it gives any valid 200 OK response
ping_canary() {
  curl -sf -o - "http://$CANARY_IP/" > /dev/null
  # Alternatively, use ICMP ping if needed:
  # ping -c1 "$CANARY_IP" &>/dev/null
}

# Get current epoch time in seconds using Bash builtin
now_ts=$EPOCHSECONDS

if ping_canary; then
  # Canary is alive — update last seen timestamp
  echo "$now_ts" > "$STATUS_FILE"
  log "✅ Canary chirped"
else
  # Canary didn't respond — figure out how long it's been quiet
  last_seen=0
  [ -s "$STATUS_FILE" ] && last_seen=$(<"$STATUS_FILE")
  elapsed=$(( (now_ts - last_seen) / 60 ))

  log "⚠️ No chirp in $elapsed minutes"

  # If the silence has gone on too long — time to kill MU/TH/UR
  if [ "$elapsed" -ge "$THRESHOLD_MINUTES" ]; then
    log "💀 Canary is dead. Shutting down MU/TH/UR"
    shutdown -h now
  fi
fi
