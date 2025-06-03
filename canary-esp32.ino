#include <WiFi.h>          // Core Wi-Fi library
#include <WebServer.h>     // Lightweight HTTP server
#include <ESPmDNS.h>       // Optional: mDNS for esp-canary.local support

// Wi-Fi credentials (replace with your network info)
const char* ssid = "YOUR_WIFI_SSID";         // Wi-Fi name
const char* password = "YOUR_WIFI_PASSWORD"; // Wi-Fi password

WebServer server(80);  // Start web server on port 80

// Handle root endpoint
void handleRoot() {
  server.send(200, "text/plain", "CHIRP"); // Respond with CHIRP to prove life
}

void setup() {
  Serial.begin(115200);  // Start serial output for debug
  WiFi.begin(ssid, password); // Connect to Wi-Fi
  Serial.print("Connecting to WiFi");

  // Wait until connected
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println(" connected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP()); // Show IP (for config/testing)

  // Start mDNS service (optional, makes esp-canary.local work)
  if (MDNS.begin("esp-canary")) {
    Serial.println("mDNS responder started as http://esp-canary.local/");
  }

  server.on("/", handleRoot); // Define root endpoint
  server.begin();             // Start web server
  Serial.println("HTTP server started");
}

void loop() {
  server.handleClient();  // Respond to HTTP requests
}
