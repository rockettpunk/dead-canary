// Dead Canary v2.0 - June 2025
// Purpose: ESP32-based offline watchdog with OLED status display and Wake-on-LAN support for MU/TH/UR

#include <Adafruit_GFX.h>         // Graphics library for the OLED
#include <Adafruit_SSD1306.h>     // OLED driver library
#include <WiFi.h>                 // WiFi control for ESP32
#include <WebServer.h>            // Lightweight web server for CHIRP endpoint
#include <WiFiUdp.h>              // Used for sending Wake-on-LAN packets via UDP broadcast

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// WiFi credentials (replace with your own network details)
const char* ssid = "YOURSSID";
const char* password = "YOURPASSWORD";

// Static IP configuration for the Canary
IPAddress local_IP(192, 168, 86, 25);
IPAddress gateway(192, 168, 86, 1);
IPAddress subnet(255, 255, 255, 0);
IPAddress primaryDNS(8, 8, 8, 8);
IPAddress secondaryDNS(1, 1, 1, 1);

// HTTP server instance (serves the /CHIRP endpoint)
WebServer server(80);

// Your servers MAC address for Wake-on-LAN targeting
byte targetMac[] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };

// Helper: Center text horizontally on the OLED
void centerText(const char* text, int y, int textSize = 1) {
  int16_t x1, y1;
  uint16_t w, h;
  display.setTextSize(textSize);
  display.getTextBounds(text, 0, y, &x1, &y1, &w, &h);
  int x = (SCREEN_WIDTH - w) / 2;
  display.setCursor(x, y);
  display.println(text);
}

// HTTP handler for root path - replies with "CHIRP" for your servers watchdog to check
void handleRoot() {
  server.send(200, "text/plain", "CHIRP");
}

// Sends a Wake-on-LAN magic packet to your servers MAC address
void sendWOL() {
  WiFiUDP udp;
  udp.beginPacket(IPAddress(255, 255, 255, 255), 9);
  byte packet[102];
  for (int i = 0; i < 6; i++) packet[i] = 0xFF;
  for (int i = 1; i <= 16; i++) {
    memcpy(&packet[i * 6], targetMac, 6);
  }
  udp.write(packet, sizeof(packet));
  udp.endPacket();
  Serial.println("Wakey wakey");
}

void setup() {
  Serial.begin(115200);

  // Initialize OLED display
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println(F("SSD1306 allocation failed"));
    for (;;);  // Halt if OLED init fails
  }
  display.clearDisplay();
  display.display();

  // Apply static IP settings
  if (!WiFi.config(local_IP, gateway, subnet, primaryDNS, secondaryDNS)) {
    Serial.println("Failed to configure static IP");
  }

  // Disable WiFi power save mode (prevents random disconnects)
  WiFi.setSleep(false);

  // Connect to WiFi network
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected to WiFi!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  // Start the HTTP server for CHIRP responses
  server.on("/", handleRoot);
  server.begin();
  Serial.println("HTTP server started at /");

  // Non-blocking 90-second delay before sending WOL
  unsigned long start = millis();
  unsigned long waitTime = 90000;
  Serial.println("Waiting 90 seconds before sending WOL...");
  while (millis() - start < waitTime) {
    server.handleClient();  // Respond to any incoming CHIRP requests during wait
    delay(10);
  }

  // Send the Wake-on-LAN magic packet
  sendWOL();
}

void loop() {
  server.handleClient();  // Keep responding to CHIRP requests

  static unsigned long lastDraw = 0;             // For OLED screen refresh rate
  static unsigned long lastReconnectAttempt = 0; // Timer for WiFi reconnects
  static int failedAttempts = 0;                 // Counter for failed reconnect tries

  // Refresh OLED display every 1 second
  if (millis() - lastDraw >= 1000) {
    lastDraw = millis();
    unsigned long seconds = millis() / 1000;
    unsigned long days = seconds / 86400;
    unsigned long hours = (seconds % 86400) / 3600;
    unsigned long minutes = (seconds % 3600) / 60;
    unsigned long secs = seconds % 60;

    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextWrap(false);

    centerText("DEAD CANARY", 0, 1);
    display.drawFastHLine(0, 12, SCREEN_WIDTH, SSD1306_WHITE);

    char line1[16], line2[16], label[] = "UPTIME:";
    snprintf(line1, sizeof(line1), "%lud %luh", days, hours);
    snprintf(line2, sizeof(line2), "%lum %lus", minutes, secs);

    centerText(label, 20, 1);
    centerText(line1, 32, 1);
    centerText(line2, 44, 1);

    display.display();
  }

  // WiFi Reconnect Watchdog
  if (WiFi.status() != WL_CONNECTED) {
    unsigned long now = millis();

    // Retry WiFi reconnect every 30 seconds
    if (now - lastReconnectAttempt > 30000) {
      Serial.println("WiFi lost. Attempting reconnection...");
      WiFi.disconnect();
      WiFi.begin(ssid, password);
      lastReconnectAttempt = now;
    }

    // If more than 5 failed reconnect attempts → Restart ESP
    failedAttempts++;
    if (failedAttempts > 5) {
      Serial.println("Too many failed WiFi attempts. Restarting ESP...");
      ESP.restart();
    }
  } else {
    failedAttempts = 0;  // Reset fail counter if WiFi is back
  }
}
