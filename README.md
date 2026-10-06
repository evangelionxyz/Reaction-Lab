# Reaction Lab

Flutter app and ESP32 reaction-time controller.

## What Works Without Real Hardware

You can run and test this project 100% without physical hardware in two ways:

1. **Desktop Mock Simulation**:
   - Run the Flutter app on Windows with `flutter run -d windows`.
   - The app automatically uses local mock simulation on desktop.
   - Press `START REACTION TEST` to generate sample results.

2. **Full Bluetooth BLE Simulation (Android Emulator + Netsim + Python Bumble)**:
   - Run the real Android Flutter app on the Android Emulator (`Medium_Phone`).
   - Run `esp32_simulator.py` on your host PC via Google Bumble.
   - The Android Emulator connects over virtual radio (Netsim / Rootcanal) to the Python simulator.
   - The app performs actual BLE discovery, GATT connection, characteristic read/write/notifications, countdown, sensor/reaction measurement, and history recording.

3. **Wokwi Microcontroller Simulation**:
   - Build and run the ESP32 Arduino logic in Wokwi CLI to validate GPIO pin logic and serial output.

---

## 🚀 Running the Full BLE Bluetooth Simulation

### Step 1: Start Android Emulator with Netsim

Launch your Android Virtual Device (ensure Netsim packet streamer is active):

```powershell
& "D:\Devkit\Android\SDK\emulator\emulator.exe" -avd Medium_Phone -packet-streamer-endpoint default
```

*(If launching from Android Studio, recent versions automatically run Netsim in the background).*

Make sure Bluetooth is enabled on the emulator:
```powershell
& "D:\Devkit\Android\SDK\platform-tools\adb.exe" shell cmd bluetooth_manager enable
```

### Step 2: Set up Virtual Environment and Run Simulated ESP32

#### Install dependencies in `.venv`:
```powershell
# If .venv is not yet created:
python -m venv .venv

# Install dependencies using .venv's pip:
.\.venv\Scripts\pip.exe install -r requirements.txt
```

#### Run the simulator using `.venv`:
```powershell
# Activate .venv (PowerShell)
.\.venv\Scripts\Activate.ps1
python esp32_simulator.py

# Or directly run via .venv:
.\.venv\Scripts\python.exe esp32_simulator.py
```

The simulator auto-discovers the running emulator's Netsim gRPC port from `netsim.ini`, registers `Reaction ESP32` with MAC address `F0:F1:F2:F3:F4:F5`, and starts advertising.

#### Interactive Controls in the Simulator Terminal:
- `s` + Enter: Simulate pressing the physical starter button (**PB_STARTER** / GPIO 35).
- `h` + Enter: Simulate pressing the physical horn button (**PB_KLAKSON** / GPIO 39, notifies `HORN`).
- `m` + Enter: Toggle between **Automatic Reaction Mode** (realistic driver reaction times) and **Manual Mode**.
- `g` + Enter: Manually press the gas pedal (when in manual reaction mode).
- `b` + Enter: Manually press the brake pedal (when in manual reaction mode).
- `status` + Enter: Display current BLE connection state, LED states, and timings.
- `q` + Enter: Quit simulator.

### Step 3: Run the Flutter App on the Android Emulator

In another terminal:

```powershell
flutter run -d emulator-5554
```

1. Open the app on the emulator.
2. Tap **SCAN** to discover `Reaction ESP32`.
3. The app connects automatically, discovers the service and characteristic, enables notifications, and syncs initial configuration (`CFG g=... r=... min=... max=...`).
4. Tap **START REACTION TEST** (or press `s` in the Python simulator):
   - The countdown `3`, `2`, `1` executes.
   - The Green LED turns on and sends `GAS!`.
   - Driver gas reaction is recorded (`GAS_RESULT <ms>`).
   - The motor driving phase holds for the configured random duration.
   - The Red LED turns on and sends `STOP`.
   - Driver brake reaction is recorded and calculated into an index score.
   - The result appears in the app's **Reaction History** list and appends to `reaction_history.txt`.

---

## Flutter Desktop Mode (Windows)

```powershell
flutter pub get
flutter test
flutter run -d windows
```

History is stored as CSV-like lines in the app documents directory:

```text
timestamp,gas_ms,brake_ms,index
```

---

## Wokwi Firmware Simulation

Install PlatformIO CLI and build the firmware from the repository root:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install platformio
.\.venv\Scripts\pio.exe run -e esp32dev
wokwi-cli --timeout 30s
```

The Wokwi diagram is in `diagram.json`; firmware paths are configured in `wokwi.toml`. Use the buttons labelled `START`, `BRAKE`, and `HORN`, and turn the potentiometer to simulate the gas pedal. Serial output is at `115200` baud.

---

## BLE Protocol Specification

- **Service UUID**: `6e400001-b5a3-f393-e0a9-e50e24dcca9e`
- **Characteristic UUID**: `6e400002-b5a3-f393-e0a9-e50e24dcca9e` (Read, Write, Notify)

### App Commands (Write to ESP32):
- `CFG g=<0-255> r=<0-255> min=<ms> max=<ms>`: Updates LED brightnesses and random stop delay window.
- `START`: Triggers countdown and reaction test.

### ESP32 Telemetry (Notifications to App):
- `READY`: ESP32 initialized and ready for connections.
- `CONFIG OK`: Configuration acknowledged.
- `START OK`: Reaction test triggered.
- `3`, `2`, `1`: Countdown ticks.
- `GAS!`: Green LED on; begin measuring gas reaction.
- `GAS_RESULT <ms>`: Milliseconds until gas pressed.
- `STOP`: Red LED on; begin measuring brake reaction.
- `RESULT gas=<gas_ms> brake=<brake_ms> index=<index> timestamp=<millis>`: Final test result.
- `HORN`: Horn button pressed.
