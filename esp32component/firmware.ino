const int PB_STARTER = 35;
const int PB_REM     = 34;
const int PB_KLAKSON = 39;
const int GAS        = 32;
const int LED_HIJAU  = 25;
const int LED_MERAH  = 26;

#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>

// Gas diinjak jika nilai ADC <= 2000
const int AMBANG_GAS = 2000;

bool klaksonLama = HIGH;
int brightnessHijau = 180;
int brightnessMerah = 180;
unsigned long durasiStopMin = 3000;
unsigned long durasiStopMax = 6000;
bool remoteStartRequested = false;

static const char* SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
static const char* CHARACTERISTIC_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
BLECharacteristic* bleCharacteristic = nullptr;

void kirimBLE(const String& pesan) {
  Serial.println(pesan);
  if (bleCharacteristic != nullptr) {
    bleCharacteristic->setValue(pesan.c_str());
    bleCharacteristic->notify();
  }
}

class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    String command = characteristic->getValue().c_str();
    int hijau;
    int merah;
    unsigned long minimum;
    unsigned long maksimum;
    if (sscanf(command.c_str(), "CFG g=%d r=%d min=%lu max=%lu", &hijau, &merah, &minimum, &maksimum) == 4) {
      brightnessHijau = constrain(hijau, 0, 255);
      brightnessMerah = constrain(merah, 0, 255);
      durasiStopMin = constrain(minimum, 1000UL, 60000UL);
      durasiStopMax = constrain(maksimum, durasiStopMin, 60000UL);
      kirimBLE("CONFIG OK");
    } else if (command == "START") {
      remoteStartRequested = true;
      kirimBLE("START OK");
    }
  }
};

void setupBLE() {
  BLEDevice::init("Reaction ESP32");
  BLEServer* server = BLEDevice::createServer();
  BLEService* service = server->createService(SERVICE_UUID);
  bleCharacteristic = service->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY
  );
  bleCharacteristic->addDescriptor(new BLE2902());
  bleCharacteristic->setCallbacks(new CommandCallbacks());
  service->start();
  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->start();
}

void cekKlakson() {
  bool klaksonBaru = digitalRead(PB_KLAKSON);

  if (klaksonLama == HIGH && klaksonBaru == LOW) {
    kirimBLE("HORN");
  }

  klaksonLama = klaksonBaru;
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_HIJAU, OUTPUT);
  pinMode(LED_MERAH, OUTPUT);
  setupBLE();

  pinMode(PB_STARTER, INPUT);
  pinMode(PB_REM, INPUT);
  pinMode(PB_KLAKSON, INPUT);
  pinMode(GAS, INPUT);

  analogReadResolution(12);
  randomSeed(analogRead(GAS) ^ micros());

  kirimBLE("READY");
}

void loop() {
  cekKlakson();

  if (!remoteStartRequested && digitalRead(PB_STARTER) == HIGH) {
    return;
  }

  if (!remoteStartRequested) {
    delay(40);
  }

  if (!remoteStartRequested) {
    while (digitalRead(PB_STARTER) == LOW) {
      delay(1);
    }
  }
  remoteStartRequested = false;

  // Countdown 3, 2, 1
  for (int angka = 3; angka >= 1; angka--) {
    kirimBLE(String(angka));

    unsigned long awal = millis();

    while (millis() - awal < 1000) {
      cekKlakson();
      delay(1);
    }
  }

  // Mengukur reaksi gas
  analogWrite(LED_HIJAU, brightnessHijau);
  analogWrite(LED_MERAH, 0);
  kirimBLE("GAS!");

  unsigned long mulaiGas = millis();

  while (analogRead(GAS) > AMBANG_GAS) {
    cekKlakson();
    delay(1);
  }

  unsigned long reaksiGas = millis() - mulaiGas;

  kirimBLE("GAS_RESULT " + String(reaksiGas));

  // Motor berjalan selama 3–6 detik
  Serial.println("MOTOR JALAN - tahan gas...");

  unsigned long mulaiJalan = millis();
  unsigned long durasiJalan = random(durasiStopMin, durasiStopMax + 1);

  while (millis() - mulaiJalan < durasiJalan) {
    cekKlakson();
    delay(1);
  }

  // Mengukur reaksi rem
  analogWrite(LED_HIJAU, 0);
  analogWrite(LED_MERAH, brightnessMerah);
  kirimBLE("STOP");

  unsigned long mulaiRem = millis();

  while (
    analogRead(GAS) <= AMBANG_GAS ||
    digitalRead(PB_REM) == HIGH
  ) {
    cekKlakson();
    delay(1);
  }

  unsigned long reaksiRem = millis() - mulaiRem;

  unsigned long index = 100000UL / max(1UL, reaksiGas + reaksiRem);
  String hasil = "RESULT gas=" + String(reaksiGas) + " brake=" + String(reaksiRem) +
                 " index=" + String(index) + " timestamp=" + String(millis());
  analogWrite(LED_MERAH, 0);
  kirimBLE(hasil);
  delay(300); 
}
