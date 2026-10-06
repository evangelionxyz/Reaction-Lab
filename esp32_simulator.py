"""
esp32_simulator.py - Simulated ESP32 Reaction Controller for Android Emulator (Netsim / Rootcanal).
Simulates hardware buttons, gas pedal, brake pedal, LEDs, and BLE GATT protocol from revisi.ino.
"""

import argparse
import asyncio
import logging
import os
import random
import re
import sys
import time
from pathlib import Path

from bumble.core import AdvertisingData, UUID
from bumble.device import Device, DeviceConfiguration
from bumble.gatt import (
    Attribute,
    Characteristic,
    CharacteristicValue,
    Service,
)
from bumble.hci import Address
from bumble.transport import open_transport

# Default Nordic UART / Reaction Lab UUIDs
SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
CHARACTERISTIC_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("ESP32-Sim")


def detect_netsim_grpc_port() -> int | None:
    """Auto-detects the active Netsim gRPC port from netsim.ini or netsim_stdout.log."""
    temp_dir = Path(os.environ.get("TEMP", os.environ.get("TMP", "C:\\Windows\\Temp")))

    # 1. Check netsim.ini
    ini_file = temp_dir / "netsim.ini"
    if ini_file.exists():
        try:
            with open(ini_file, "r", encoding="utf-8") as f:
                for line in f:
                    if "=" in line:
                        k, v = line.strip().split("=", 1)
                        if k in ("grpc.port", "grpc.backend.port"):
                            port = int(v)
                            logger.info(f"Discovered Netsim gRPC port {port} from {ini_file}")
                            return port
        except Exception as e:
            logger.debug(f"Error reading {ini_file}: {e}")

    # 2. Check netsimd/netsim_stdout.log
    log_file = temp_dir / "netsimd" / "netsim_stdout.log"
    if log_file.exists():
        try:
            with open(log_file, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    match = re.search(r"Adding netsim_grpc listener on GRPC:127\.0\.0\.1:(\d+)", line)
                    if match:
                        port = int(match.group(1))
                        logger.info(f"Discovered Netsim gRPC port {port} from {log_file}")
                        return port
        except Exception as e:
            logger.debug(f"Error reading {log_file}: {e}")

    return None


class ESP32Simulator:
    def __init__(
        self,
        device_name: str = "Reaction ESP32",
        mac_address: str = "F0:F1:F2:F3:F4:F5",
        auto_mode: bool = True,
        grpc_port: int | None = None,
    ):
        self.device_name = device_name
        self.mac_address = mac_address
        self.auto_mode = auto_mode
        self.grpc_port = grpc_port

        # Hardware simulation parameters (matching revisi.ino)
        self.green_brightness = 180
        self.red_brightness = 180
        self.stop_min_ms = 3000
        self.stop_max_ms = 6000

        # Virtual State
        self.connected = False
        self.active_connection = None
        self.test_in_progress = False
        self.current_phase = "IDLE"  # IDLE, COUNTDOWN, GAS, DRIVING, BRAKE

        # Events for interactive input
        self.gas_event = asyncio.Event()
        self.brake_event = asyncio.Event()

        # Bumble objects
        self.device: Device | None = None
        self.reaction_char: Characteristic | None = None

    async def send_ble(self, message: str):
        """Sends a notification packet to Android, mimicking kirimBLE() in revisi.ino."""
        logger.info(f"[NOTIFY -> Android] {message}")
        if self.device and self.reaction_char and self.connected:
            try:
                payload = message.encode("utf-8")
                await self.device.notify_subscribers(self.reaction_char, payload)
            except Exception as e:
                logger.warning(f"Failed to notify BLE subscriber: {e}")

    def on_ble_write(self, connection, value: bytes):
        """Handles incoming commands written by the Android app."""
        text = value.decode("utf-8", errors="replace").strip()
        logger.info(f"[WRITE <- Android] '{text}'")

        # Parse CFG g=%d r=%d min=%lu max=%lu
        cfg_match = re.match(
            r"^CFG\s+g=(\d+)\s+r=(\d+)\s+min=(\d+)\s+max=(\d+)$", text
        )
        if cfg_match:
            g, r, min_ms, max_ms = map(int, cfg_match.groups())
            self.green_brightness = max(0, min(255, g))
            self.red_brightness = max(0, min(255, r))
            self.stop_min_ms = max(1000, min(60000, min_ms))
            self.stop_max_ms = max(self.stop_min_ms, min(60000, max_ms))
            logger.info(
                f"[CONFIG UPDATED] Green LED={self.green_brightness}, "
                f"Red LED={self.red_brightness}, Stop Window={self.stop_min_ms}-{self.stop_max_ms}ms"
            )
            asyncio.create_task(self.send_ble("CONFIG OK"))
            return

        if text == "START":
            if self.test_in_progress:
                logger.warning("Test already in progress, ignoring duplicate START")
                return
            asyncio.create_task(self._handle_start_command())
            return

        logger.warning(f"Unrecognized BLE command: '{text}'")

    async def _handle_start_command(self):
        await self.send_ble("START OK")
        await self.run_reaction_test()

    async def run_reaction_test(self):
        """Executes the full reaction test sequence exactly as in revisi.ino."""
        if self.test_in_progress:
            return
        self.test_in_progress = True
        try:
            logger.info("================= STARTING REACTION TEST =================")

            # 1. Countdown: 3, 2, 1
            self.current_phase = "COUNTDOWN"
            for count in [3, 2, 1]:
                await self.send_ble(str(count))
                await asyncio.sleep(1.0)

            # 2. Gas Phase
            self.current_phase = "GAS"
            logger.info(f"[LED GREEN ON] (Brightness: {self.green_brightness}/255)")
            await self.send_ble("GAS!")

            gas_start = time.perf_counter()
            if self.auto_mode:
                # Realistic human gas reaction time between 250ms and 450ms
                simulated_gas_delay = random.uniform(0.25, 0.45)
                await asyncio.sleep(simulated_gas_delay)
            else:
                logger.info("Press 'g' + Enter in terminal to press GAS pedal...")
                self.gas_event.clear()
                try:
                    await asyncio.wait_for(self.gas_event.wait(), timeout=10.0)
                except asyncio.TimeoutError:
                    logger.warning("Gas timed out, assuming 2.0s")
            
            gas_reaction_ms = int((time.perf_counter() - gas_start) * 1000)
            logger.info(f"[GAS REACTION] {gas_reaction_ms} ms")
            await self.send_ble(f"GAS_RESULT {gas_reaction_ms}")

            # 3. Driving Phase (random duration between stop_min_ms and stop_max_ms)
            self.current_phase = "DRIVING"
            drive_ms = random.randint(self.stop_min_ms, self.stop_max_ms)
            logger.info(f"[MOTOR RUNNING] Holding gas pedal for {drive_ms} ms...")
            await asyncio.sleep(drive_ms / 1000.0)

            # 4. Brake Phase
            self.current_phase = "BRAKE"
            logger.info("[LED GREEN OFF]")
            logger.info(f"[LED RED ON] (Brightness: {self.red_brightness}/255)")
            await self.send_ble("STOP")

            brake_start = time.perf_counter()
            if self.auto_mode:
                # Realistic human brake reaction time between 220ms and 380ms
                simulated_brake_delay = random.uniform(0.22, 0.38)
                await asyncio.sleep(simulated_brake_delay)
            else:
                logger.info("Press 'b' + Enter in terminal to hit BRAKE pedal...")
                self.brake_event.clear()
                try:
                    await asyncio.wait_for(self.brake_event.wait(), timeout=10.0)
                except asyncio.TimeoutError:
                    logger.warning("Brake timed out, assuming 2.0s")

            brake_reaction_ms = int((time.perf_counter() - brake_start) * 1000)
            logger.info("[LED RED OFF]")
            logger.info(f"[BRAKE REACTION] {brake_reaction_ms} ms")

            # 5. Result Calculation (matching revisi.ino formula)
            # index = 100000UL / max(1UL, reaksiGas + reaksiRem)
            total_reaction = max(1, gas_reaction_ms + brake_reaction_ms)
            index = 100000 // total_reaction
            timestamp = int(time.time() * 1000)

            result_str = (
                f"RESULT gas={gas_reaction_ms} brake={brake_reaction_ms} "
                f"index={index} timestamp={timestamp}"
            )
            logger.info(f"[TEST COMPLETE] Index: {index} (Gas: {gas_reaction_ms}ms, Brake: {brake_reaction_ms}ms)")
            await self.send_ble(result_str)
            logger.info("============================================================")

        finally:
            self.test_in_progress = False
            self.current_phase = "IDLE"

    async def trigger_horn(self):
        """Simulates physical horn button (PB_KLAKSON)."""
        logger.info("[HARDWARE BUTTON] HORN (PB_KLAKSON) pressed!")
        await self.send_ble("HORN")

    async def trigger_hardware_start(self):
        """Simulates physical starter button (PB_STARTER)."""
        logger.info("[HARDWARE BUTTON] START (PB_STARTER) pressed!")
        await self.run_reaction_test()

    async def cli_loop(self):
        """Provides an interactive CLI for testing hardware buttons and actions."""
        if not sys.stdin or not hasattr(sys.stdin, "isatty") or not sys.stdin.isatty():
            return

        print("\n" + "=" * 58)
        print(" Interactive Controls:")
        print("   [s] + Enter : Trigger Start Button (PB_STARTER)")
        print("   [h] + Enter : Trigger Horn Button (PB_KLAKSON)")
        print("   [g] + Enter : Press Gas Pedal (when in manual mode)")
        print("   [b] + Enter : Hit Brake Pedal (when in manual mode)")
        print("   [m] + Enter : Toggle Auto/Manual reaction mode")
        print("   [status]    : Show current state and config")
        print("   [q] + Enter : Quit Simulator")
        print("=" * 58 + "\n")

        loop = asyncio.get_running_loop()
        while True:
            try:
                line = await loop.run_in_executor(None, sys.stdin.readline)
                if not line:
                    await asyncio.sleep(0.5)
                    continue
                cmd = line.strip().lower()

                if cmd in ("s", "start"):
                    asyncio.create_task(self.trigger_hardware_start())
                elif cmd in ("h", "horn"):
                    asyncio.create_task(self.trigger_horn())
                elif cmd in ("g", "gas"):
                    if self.current_phase == "GAS":
                        self.gas_event.set()
                    else:
                        print("ℹNot currently in GAS reaction phase.")
                elif cmd in ("b", "brake"):
                    if self.current_phase == "BRAKE":
                        self.brake_event.set()
                    else:
                        print("ℹNot currently in BRAKE reaction phase.")
                elif cmd in ("m", "mode"):
                    self.auto_mode = not self.auto_mode
                    print(f"Mode switched: {'AUTOMATIC (Realistic simulation)' if self.auto_mode else 'MANUAL (Interactive g/b keys)'}")
                elif cmd == "status":
                    print(f"\n--- ESP32 Status ---")
                    print(f"Connected: {self.connected}")
                    print(f"Phase: {self.current_phase}")
                    print(f"Auto Mode: {self.auto_mode}")
                    print(f"Green Brightness: {self.green_brightness}/255")
                    print(f"Red Brightness: {self.red_brightness}/255")
                    print(f"Stop Window: {self.stop_min_ms}ms - {self.stop_max_ms}ms\n")
                elif cmd in ("q", "quit", "exit"):
                    logger.info("Exiting simulator...")
                    os._exit(0)
            except Exception as e:
                logger.error(f"CLI error: {e}")

    async def start(self):
        # 1. Connect to Netsim transport
        port = self.grpc_port or detect_netsim_grpc_port()
        transport_spec = f"android-netsim:localhost:{port}" if port else "android-netsim"

        logger.info(f"Connecting to Android Netsim transport: '{transport_spec}'...")
        try:
            transport = await open_transport(transport_spec)
        except Exception as e:
            logger.error(
                f"Failed to connect to Netsim: {e}\n"
                "Ensure Android Emulator is running with Netsim enabled!\n"
                "Try running emulator with: emulator.exe -avd Medium_Phone -packet-streamer-endpoint default"
            )
            return

        # 2. Build Virtual Device Configuration
        config = DeviceConfiguration(
            name=self.device_name,
            address=Address(self.mac_address),
        )
        self.device = Device.from_config_with_hci(config, transport.source, transport.sink)

        # 3. Create Custom GATT Service and Characteristic
        self.reaction_char = Characteristic(
            CHARACTERISTIC_UUID,
            Characteristic.Properties.READ
            | Characteristic.Properties.WRITE
            | Characteristic.Properties.WRITE_WITHOUT_RESPONSE
            | Characteristic.Properties.NOTIFY,
            Attribute.READABLE | Attribute.WRITEABLE,
            CharacteristicValue(
                read=lambda conn: b"READY",
                write=self.on_ble_write,
            ),
        )

        reaction_service = Service(
            SERVICE_UUID,
            [self.reaction_char],
        )

        # Device Information Service (0x180A)
        dis_service = Service(
            "180A",
            [
                Characteristic(
                    "2A29",
                    Characteristic.Properties.READ,
                    Attribute.READABLE,
                    CharacteristicValue(read=lambda _: b"Espressif Systems"),
                ),
                Characteristic(
                    "2A24",
                    Characteristic.Properties.READ,
                    Attribute.READABLE,
                    CharacteristicValue(read=lambda _: b"Reaction ESP32 Virtual"),
                ),
            ],
        )

        self.device.add_services([reaction_service, dis_service])

        # 4. Connection Handlers
        @self.device.on("connection")
        def on_connection(connection):
            logger.info(f"[BLE CONNECTED] Central connected: {connection.peer_address}")
            self.connected = True
            self.active_connection = connection
            # Mimic revisi.ino: send READY upon connection setup
            asyncio.create_task(self.send_ble("READY"))

        @self.device.on("disconnection")
        def on_disconnection(connection, reason):
            logger.info(f"[BLE DISCONNECTED] Central disconnected (reason: {reason})")
            self.connected = False
            self.active_connection = None

        # 5. Power On and Start Advertising
        await self.device.power_on()

        # Advertising Data (Flags + Local Name = 19 bytes)
        adv_data = bytes(
            AdvertisingData(
                [
                    (AdvertisingData.FLAGS, bytes([0x06])),
                    (AdvertisingData.COMPLETE_LOCAL_NAME, self.device_name.encode("utf-8")),
                ]
            )
        )

        # Scan Response Data (128-bit Service UUID = 18 bytes)
        scan_response_data = bytes(
            AdvertisingData(
                [
                    (
                        AdvertisingData.COMPLETE_LIST_OF_128_BIT_SERVICE_CLASS_UUIDS,
                        UUID(SERVICE_UUID).to_pdu_bytes(),
                    )
                ]
            )
        )

        await self.device.start_advertising(
            auto_restart=True,
            advertising_data=adv_data,
            scan_response_data=scan_response_data,
        )

        logger.info(f"ESP32 peripheral '{self.device_name}' [{self.mac_address}] is advertising on Netsim!")

        # 6. Start Interactive CLI in background
        asyncio.create_task(self.cli_loop())

        # Keep server running
        await asyncio.Event().wait()


def main():
    parser = argparse.ArgumentParser(description="Reaction Lab ESP32 BLE Simulator for Netsim")
    parser.add_argument("--port", type=int, help="Netsim gRPC port (auto-detected if omitted)")
    parser.add_argument("--name", default="Reaction ESP32", help="Advertised device name")
    parser.add_argument("--address", default="F0:F1:F2:F3:F4:F5", help="Bluetooth MAC address")
    parser.add_argument(
        "--manual", action="store_true", help="Start in manual interactive reaction mode instead of automatic"
    )

    args = parser.parse_args()

    simulator = ESP32Simulator(
        device_name=args.name,
        mac_address=args.address,
        auto_mode=not args.manual,
        grpc_port=args.port,
    )

    try:
        asyncio.run(simulator.start())
    except KeyboardInterrupt:
        print("\nSimulator stopped.")


if __name__ == "__main__":
    main()
