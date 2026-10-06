# Reaction Lab

Flutter app and ESP32 reaction-time controller.

## What works without hardware

- Run the Flutter app on Windows with `flutter run -d windows`.
- The app automatically uses local simulation mode on desktop.
- Press `START REACTION TEST` to generate a sample result and append it to `reaction_history.txt`.
- Build and run the ESP32 reaction logic in Wokwi. GPIO buttons, gas potentiometer, LEDs, countdown, and serial output are simulated.

Wokwi does not emulate an ESP32 Bluetooth radio as a phone-visible BLE peripheral. The mobile BLE flow therefore requires a real ESP32 board. Wokwi is still useful for validating the reaction state machine and serial protocol.

## Flutter app

```powershell
flutter pub get
flutter test
flutter run -d windows
```

For a real phone, enable Bluetooth and run on an Android or iOS device. Scan for `Reaction ESP32`, then sync settings before starting a test.

History is stored as CSV-like lines in the app documents directory:

```text
timestamp,gas_ms,brake_ms,index
```

## Wokwi CLI

Install PlatformIO CLI and Wokwi CLI, then build the firmware from the repository root:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install platformio
.\.venv\Scripts\pio.exe run -e esp32dev
wokwi-cli --timeout 30s
```

The Wokwi diagram is in `diagram.json`; its firmware paths are configured in `wokwi.toml`. Use the buttons labelled `START`, `BRAKE`, and `HORN`, and turn the potentiometer to simulate the gas pedal. Serial output is at `115200` baud.

## BLE protocol

The ESP32 advertises service `6e400001-b5a3-f393-e0a9-e50e24dcca9e` and characteristic `6e400002-b5a3-f393-e0a9-e50e24dcca9e`.

The app writes settings as:

```text
CFG g=180 r=180 min=3000 max=6000
```

The ESP32 notifies status lines and completed results, for example:

```text
RESULT gas=412 brake=286 index=143 timestamp=12345
```

`index` is currently a simple score derived from the combined reaction time. Replace that formula when the scoring rule is agreed.
