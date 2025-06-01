#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <NTPClient.h>
#include <WiFiUdp.h>
#include <math.h>  // For ceil()

// Motor pins
#define MOTOR_IN1 26
#define MOTOR_IN2 25

// WiFi credentials
#define WIFI_SSID "WIFI_SSID"
#define WIFI_PASSWORD "WIFI_PASSWORD"

// Firebase credentials
#define API_KEY "API_KEY"
#define DATABASE_URL "DATABASE_URL"
#define DATABASE_SECRET "DATABASE_SECRET"

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org", 19800, 60000); // IST offset

void openGate() {
  digitalWrite(MOTOR_IN1, HIGH);
  digitalWrite(MOTOR_IN2, LOW);
  delay(1000);
  digitalWrite(MOTOR_IN1, LOW);
  digitalWrite(MOTOR_IN2, LOW);
}

void closeGate() {
  digitalWrite(MOTOR_IN1, LOW);
  digitalWrite(MOTOR_IN2, HIGH);
  delay(1000);
  digitalWrite(MOTOR_IN1, LOW);
  digitalWrite(MOTOR_IN2, LOW);
}

void setup() {
  Serial.begin(9600);
  Serial2.begin(9600, SERIAL_8N1, 16, 17);  // RX2

  pinMode(MOTOR_IN1, OUTPUT);
  pinMode(MOTOR_IN2, OUTPUT);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n✅ Wi-Fi connected");

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  config.signer.tokens.legacy_token = DATABASE_SECRET;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  Serial.println("✅ Firebase connected");

  timeClient.begin();
}

void loop() {
  if (Serial2.available()) {
    String data = Serial2.readStringUntil('\n');
    data.trim();
    Serial.println("📥 Received: " + data);

    char uid[32];
    int ir1, ir2, ir3;

    if (sscanf(data.c_str(), "%[^,],%d,%d,%d", uid, &ir1, &ir2, &ir3) == 4) {
      String uidStr = String(uid);
      String status1 = (ir1 == 0) ? "Occupied" : "Available";
      String status2 = (ir2 == 0) ? "Occupied" : "Available";
      String status3 = (ir3 == 0) ? "Occupied" : "Available";

      // Always update IR sensor data
      Firebase.RTDB.setString(&fbdo, "/IR_Sensors/IR1", status1);
      Firebase.RTDB.setString(&fbdo, "/IR_Sensors/IR2", status2);
      Firebase.RTDB.setString(&fbdo, "/IR_Sensors/IR3", status3);

      if (uidStr == "NO_UID") return;

      Serial.println("🔍 Checking UID: " + uidStr);

      if (Firebase.RTDB.getJSON(&fbdo, "/Users")) {
        FirebaseJson &json = fbdo.jsonObject();
        size_t len = json.iteratorBegin();
        bool found = false;

        for (size_t i = 0; i < len; i++) {
          int type;
          String key, value;
          json.iteratorGet(i, type, key, value);

          FirebaseJsonData rfidData;
          json.get(rfidData, key + "/rfid");

          if (rfidData.success && rfidData.stringValue == uidStr) {
            found = true;
            String userPath = "/Users/" + key;
            String entryPath = "/Entries/" + uidStr;

            if (Firebase.RTDB.getInt(&fbdo, userPath + "/balance")) {
              int balance = fbdo.intData();

              timeClient.update();
              int nowEpoch = timeClient.getEpochTime();
              String currentTime = timeClient.getFormattedTime();

              // Format date: DD-MMM-YYYY
              const char* months[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
              struct tm *ptm = gmtime((time_t *)&nowEpoch);
              char dateBuffer[20];
              sprintf(dateBuffer, "%02d-%s-%04d", ptm->tm_mday, months[ptm->tm_mon], ptm->tm_year + 1900);
              String dateStr = String(dateBuffer);

              String name = "Unknown";
              Firebase.RTDB.getString(&fbdo, userPath + "/name");
              name = fbdo.stringData();

              Firebase.RTDB.getString(&fbdo, entryPath + "/entry_time");
              bool hasEntry = fbdo.stringData() != "";

              if (!hasEntry) {
                // 🚗 Entry
                if (balance > -50) {
                  Firebase.RTDB.setString(&fbdo, entryPath + "/user_id", key);
                  Firebase.RTDB.setString(&fbdo, entryPath + "/rfid", uidStr);
                  Firebase.RTDB.setString(&fbdo, entryPath + "/name", name);
                  Firebase.RTDB.setString(&fbdo, entryPath + "/entry_date", dateStr);
                  Firebase.RTDB.setString(&fbdo, entryPath + "/entry_time", currentTime);
                  Firebase.RTDB.setInt(&fbdo, entryPath + "/entry_epoch", nowEpoch);
                  Firebase.RTDB.setString(&fbdo, entryPath + "/status", "Entered");

                  openGate();
                  delay(2000);
                  closeGate();

                  Serial.println("✅ Entry recorded.");
                } else {
                  Serial.println("❌ Access Denied: Low balance.");
                }
              } else {
                // 🚗 Exit
                Firebase.RTDB.setString(&fbdo, entryPath + "/exit_time", currentTime);
                Firebase.RTDB.setString(&fbdo, entryPath + "/exit_date", dateStr);
                Firebase.RTDB.setString(&fbdo, entryPath + "/status", "Exited");

                if (Firebase.RTDB.getInt(&fbdo, entryPath + "/entry_epoch")) {
                  int entryEpoch = fbdo.intData();
                  int duration = nowEpoch - entryEpoch;
                  int hours = ceil((float)duration / 3600.0); // Round up
                  int cost = hours * 20;
                  int newBalance = balance - cost;

                  Firebase.RTDB.setInt(&fbdo, userPath + "/balance", newBalance);

                  String exitPath = "/Exit/" + uidStr;
                  Firebase.RTDB.setString(&fbdo, exitPath + "/user_id", key);
                  Firebase.RTDB.setString(&fbdo, exitPath + "/exit_time", currentTime);
                  Firebase.RTDB.setString(&fbdo, exitPath + "/exit_date", dateStr);
                  Firebase.RTDB.setInt(&fbdo, exitPath + "/amount_deducted", cost);
                  Firebase.RTDB.setInt(&fbdo, exitPath + "/exit_epoch", nowEpoch);

                  openGate();
                  delay(2000);
                  closeGate();

                  Serial.println("✅ Exit recorded. ₹" + String(cost) + " deducted for " + String(hours) + " hour(s).");
                } else {
                  Serial.println("❌ entry_epoch not found!");
                }
              }
            }
            break;
          }
        }

        json.iteratorEnd();
        if (!found) {
          Serial.println("❌ UID not found.");
        }
      } else {
        Serial.println("🔥 Failed to fetch Users: " + fbdo.errorReason());
      }
    } else {
      Serial.println("⚠ Invalid format");
    }
  }
}
