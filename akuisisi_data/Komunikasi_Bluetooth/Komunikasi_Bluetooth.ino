#include <BluetoothSerial.h>

BluetoothSerial SerialBT;

const int emgPin = 34;
unsigned long previousMillis = 0;
const unsigned long interval = 1; 

void setup() {
  Serial.begin(115200);
  SerialBT.begin("ESP32");
  Serial.println("ESP32 started, ready to pair");
  analogReadResolution(12);
  analogSetPinAttenuation(emgPin, ADC_11db);
}
void loop() {
  unsigned long currentMillis = millis();
  if (currentMillis - previousMillis >= interval) {
    previousMillis = currentMillis;
    int raw = analogRead(emgPin);
    float mv = (raw / 4095.0) * 3.3 * 1000;
    SerialBT.println(mv);
    Serial.println(mv);
  }
}
