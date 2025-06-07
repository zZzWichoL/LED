#include <WiFi.h>

// Configuración WiFi
const char* ssid =  "MEGACABLE-2.4G-DEA7";
const char* password = "WBCHJDP5k8";

// Configuración del servidor TCP
WiFiServer server(8080);
const int LED_PIN = 13; // Pin D13 para el LED

// Variables para debug
unsigned long lastPrintTime = 0;

void setup() {
  Serial.begin(115200);
  
  // Configurar el pin del LED
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW); // LED apagado inicialmente
  
  // Conectar a WiFi
  WiFi.begin(ssid, password);
  Serial.print("Conectando a WiFi");
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println();
  Serial.println("WiFi conectado!");
  Serial.print("Dirección IP: ");
  Serial.println(WiFi.localIP());
  
  // Iniciar servidor TCP
  server.begin();
  server.setNoDelay(true); // Disable Nagle algorithm para respuesta inmediata
  Serial.println("Servidor TCP iniciado en puerto 8080");
  Serial.println("Esperando conexiones...");
  Serial.println("Puedes conectarte desde la app usando:");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
  Serial.println("Puerto: 8080");
}

void loop() {
  // Verificar estado WiFi cada 10 segundos
  if (millis() - lastPrintTime > 10000) {
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("WiFi conectado - IP: " + WiFi.localIP().toString());
      Serial.println("Servidor TCP activo - Puerto: 8080");
    } else {
      Serial.println("WiFi desconectado - Reconectando...");
      WiFi.begin(ssid, password);
    }
    lastPrintTime = millis();
  }
  
  WiFiClient client = server.available();

  if (client) {
    Serial.println("¡Cliente conectado!");
    unsigned long lastCommandTime = millis();

    while (client.connected()) {
      if (client.available()) {
        String command = client.readStringUntil('\n');
        command.trim();
        lastCommandTime = millis();

        if (command == "LED_ON") {
          digitalWrite(LED_PIN, HIGH);
          client.println("LED_ENCENDIDO");
        } else if (command == "LED_OFF") {
          digitalWrite(LED_PIN, LOW);
          client.println("LED_APAGADO");
        } else if (command == "STATUS") {
          int ledState = digitalRead(LED_PIN);
          client.println(ledState == HIGH ? "LED_ENCENDIDO" : "LED_APAGADO");
        } else if (command == "PING") {
          client.println("PONG");
        } else {
          client.println("COMANDO_DESCONOCIDO");
        }
        client.flush();
      }

      // Si pasan más de 30 segundos sin comandos, cierra la conexión
      if (millis() - lastCommandTime > 30000) {
        Serial.println("Timeout de inactividad, cerrando cliente.");
        break;
      }
      delay(10);
    }
    client.stop();
    Serial.println("Cliente desconectado");
  }
}