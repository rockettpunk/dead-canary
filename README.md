# 🕊️ Dead Canary

A LAN-connected watchdog using an ESP32 that safely shuts down your NAS or server when power is lost — like a literal canary in a server mine.

---

## 🔧 What is it?

My Zimacube NAS (MU/TH/UR) runs on a basic UPS without NUT or similar. I wanted a reliable, local-only way to detect when the **power goes out** — and shut things down cleanly before ZFS could cry.

Enter: **Dead Canary**  
An ESP32 sits on the same power strip as the NAS (but **not** on the UPS), and serves a local `/` endpoint returning `"CHIRP"`. When that chirp goes silent, the NAS knows it’s time to go dark.

---

## 🧰 What You Need

- ESP32 development board
- Arduino IDE
- A Linux server or NAS
- Local Wi-Fi
- (Optional) Glorious plastic pot for housing

---

## 📦 How It Works

### ESP32 Firmware
- Connects to Wi-Fi
- Hosts a webserver on port 80
- Responds to `http://CANARY_IP/` with `"CHIRP"`

### Server Watchdog
- Cron job pings the canary every minute
- If no chirp in 5 minutes, triggers:
  ```bash
  shutdown -h now
