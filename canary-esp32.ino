// Dead Canary Sketch
// An ESP32-based watchdog that sits on your network, serves a simple "CHIRP" signal to a simple web portal,
// and sends a Wake-on-LAN (WOL) packet after a 90s delay when power is restored.
// Designed to resurrect your homelab server after a safe shutdown.

#include <WiFi.h>           // Wi-Fi control for ESP32
#include <WebServer.h>      // Lightweight HTTP server
#include <WiFiUdp.h>        // UDP support for WOL magic packet

// === Wi-Fi Credentials ===
// Replace these with your actual Wi-Fi SSID and password
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// === Static IP Configuration ===
// Set a fixed IP to ensure reliable communication from the watchdog
IPAddress local_IP(192, 168, 86, 25);       // Static IP for the ESP32 (Dead Canary) change to your subnet
IPAddress gateway(192, 168, 86, 1);          // Change to your router's IP
IPAddress subnet(255, 255, 255, 0);          // Standard subnet mask
IPAddress primaryDNS(8, 8, 8, 8);            // Optional: set a known DNS
IPAddress secondaryDNS(1, 1, 1, 1);

// === HTTP Server Setup ===
WebServer server(80);  // Listens on port 80 (http://CANARY_IP/ returns "CHIRP" just for fun)

// === Target Server MAC Address (WOL Target) ===
// Replace with the MAC address of the device you want to wake (e.g., your erver)
byte targetMac[] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };

// === Wake-on-LAN Packet Function ===
// Sends a "magic packet" to the specified MAC address over UDP broadcast
void sendWOL() {
  WiFiUDP udp;
  udp.beginPacket(IPAddress(255, 255, 255, 255), 9);  // UDP broadcast on port 9

  byte packet[102];
  for (int i = 0; i < 6; i++) packet[i] = 0xFF;       // Start of magic packet
  for (int i = 1; i <= 16; i++) {
    memcpy(&packet[i * 6], targetMac, 6);            // Repeat MAC address 16 times
  }

  udp.write(packet, sizeof(packet));
  udp.endPacket();

  Serial.println("🔊 Sent Wake-on-LAN packet to MU/TH/UR.");
}

// === HTTP Root Handler ===
// Returns "CHIRP" when the server receives a request to "/"
// This is used by the host system to detect that the canary is alive
void handleRoot() {
  server.send(200, "text/plain", "CHIRP");
}

// === Setup Function ===
void setup() {
  Serial.begin(115200);  // Start serial output for debugging

  // Configure static IP address
  if (!WiFi.config(local_IP, gateway, subnet, primaryDNS, secondaryDNS)) {
    Serial.println("⚠️ Failed to configure static IP");
  }

  // Connect to Wi-Fi
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\n✅ Connected to WiFi!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  // Start the HTTP server and bind the root endpoint
  server.on("/", handleRoot);
  server.begin();
  Serial.println("🌐 HTTP server started at /");

  // === Delayed Wake-Up Sequence ===
  // Wait 90 seconds before sending the WOL packet
  // This gives time for power/network to fully stabilize after a blackout
  unsigned long start = millis();
  unsigned long waitTime = 90000;

  Serial.println("⏳ Waiting 90 seconds before sending WOL...");
  while (millis() - start < waitTime) {
    server.handleClient();  // Allow "CHIRP" responses during the wait
    delay(10);              // Short delay to yield
  }

  sendWOL();  // Send the magic packet to wake your server
}

// === Main Loop ===
// Continuously respond to HTTP CHIRP requests
void loop() {
  server.handleClient();
}
