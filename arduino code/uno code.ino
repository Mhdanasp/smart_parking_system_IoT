#include <MFRC522.h>
#include <SPI.h>

// RFID Pins
#define SS_PIN 10  // SDA
#define RST_PIN 9

MFRC522 mfrc522(SS_PIN, RST_PIN);

// IR Sensors
const int ir1 = 2;
const int ir2 = 3;
const int ir3 = 4;

void setup() {
  Serial.begin(9600);        // Communication with ESP32
  SPI.begin();               // Init SPI bus
  mfrc522.PCD_Init();        // Init RFID

  pinMode(ir1, INPUT);
  pinMode(ir2, INPUT);
  pinMode(ir3, INPUT);
}

void loop() {
  int s1 = digitalRead(ir1);
  int s2 = digitalRead(ir2);
  int s3 = digitalRead(ir3);

  String uid = "NO_UID";  // Default if no RFID is scanned

  if (mfrc522.PICC_IsNewCardPresent() && mfrc522.PICC_ReadCardSerial()) {
    uid = "";
    for (byte i = 0; i < mfrc522.uid.size; i++) {
      uid += String(mfrc522.uid.uidByte[i], HEX);
    }
    uid.toUpperCase();

    mfrc522.PICC_HaltA();  // Halt RFID card
    mfrc522.PCD_StopCrypto1();
    delay(1000);           // Delay after successful scan
  }

  // Format: UID_or_NO_UID,IR1,IR2,IR3
  Serial.print(uid);
  Serial.print(",");
  Serial.print(s1);
  Serial.print(",");
  Serial.print(s2);
  Serial.print(",");
  Serial.println(s3);

  delay(500); // Update every 500ms
}

