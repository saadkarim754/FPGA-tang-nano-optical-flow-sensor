# Tang Nano 4K Optical Flow Sensor

An embedded hardware-software co-designed optical flow sensor utilizing the Sipeed Tang Nano 4K (GW1NSR-4C). The system leverages the FPGA fabric for deterministic, real-time image processing and utilizes the embedded Cortex-M3 hard processor for high-level flow calculation and UART telemetry.

## Hardware Setup & Pinout

### Components Required
* **Sipeed Tang Nano 4K Board** (GW1NSR-4C SoC)
* **OV2640 DVP Camera** (Connects directly to the onboard FPC connector)
* **USB-to-TTL Serial Adapter** (For reading telemetry from the Cortex-M3)

### Pinout Configuration

| Signal Name | FPGA Pin | Bank / Voltage | Description |
|-------------|----------|----------------|-------------|
| `clk_27m` | 45 | Bank 1 / 3.3V | 27MHz Onboard Crystal |
| `btn_reset_n` | 14 | Bank 2 / 3.3V | User Key 1 (Active Low) |
| `led` | 10 | Bank 1 / 3.3V | Onboard Status LED |
| `uart_tx` | 27 | Bank 0 / 3.3V | UART Transmit (Connect to RX of Serial Adapter) |
| `uart_rx` | 28 | Bank 0 / 3.3V | UART Receive |
| **DVP Camera** | | | |
| `dvp_scl` / `dvp_sda` | 44 / 46 | Bank 1 / 3.3V | SCCB (I2C) for Camera Config |
| `dvp_pclk` | 41 | Bank 1 / 3.3V | Pixel Clock |
| `dvp_vsync` | 43 | Bank 1 / 3.3V | Vertical Sync |
| `dvp_href` | 42 | Bank 1 / 3.3V | Horizontal Sync |
| `dvp_d[7:6]` | 40, 39 | Bank 1 / 3.3V | Camera Data 9 and 8 |
| `dvp_d[5:0]` | 23, 16, 18, 20, 19, 17 | Bank 3 / **1.8V** | Camera Data 7 to 2 (Hardware Locked to 1.8V) |

> **Warning:** Note that on the Tang Nano 4K, Bank 3 is strictly hardwired to 1.8V. The constraints map the lower bits of the camera FPC connector directly to this bank. You must set `IO_TYPE=LVCMOS18` for `dvp_d[5:0]` in your `.cst` file to synthesize correctly without routing errors.

## Project Scope

- **FPGA Fabric:** Interfacing the DVP camera via a hardware state machine, buffering image data, and running low-level hardware acceleration to detect FAST features in real-time.
- **Cortex-M3 Processor:** Communicating via AHB to the FPGA, fetching feature matrices, calculating the temporal optical flow mathematically between frames, and streaming computed vectors out via UART.

## Known Issues and Possible Errors

* **PNR Bank Constraints Error:** If Place and Route fails with Bank Voltage errors, ensure `dvp_d[5:0]` constraints are strictly `LVCMOS18`. Mixing voltages in Bank 3 causes the bitstream generation to fail.
* **Camera Initialization Issues:** The OV2640 requires a specific sequence via I2C/SCCB. If the UART repeatedly outputs `OPTFLOW: Waiting for camera frames...`, verify the camera module is securely connected and ensure the hardware-based configuration state machine is completing successfully.
* **UART Garbage Output:** Ensure the ground of the USB-to-TTL adapter is connected to the FPGA board's ground (GND). Confirm your baud rate matches exactly. The Cortex-M3 calculates the baud divisor as: `sys_clk / baud_rate`. With a `27MHz` clock, `115200` baud is a divisor of `~234`.
* **AHB Memory Mapping Errors:** The FPGA BRAM mappings reside at specific base addresses. Accessing misaligned or invalid addresses past `0xA0000000` from the Cortex-M3 will trigger a HardFault.

## Firmware Notes & Tips

The Cortex-M3 firmware (`firmware/main.c`) essentially acts as the high-level manager polling FPGA registers. 

- **AHB Read Rates:** The loop in `main()` polls `FEAT_STATUS_REG` at close to CPU speed. When reading the entire `curr_features` array dynamically, a slight delay is intentionally introduced (`delay_ms(1)`) to avoid bus congestion. Keep loops tight, but allow breathing room for the AHB bus when moving massive arrays.
- **Adjusting the Processing Threshold:** The FAST algorithm threshold is set via `FEAT_THRESHOLD_REG`. Currently, it defaults to 30 (`FEAT_THRESHOLD_REG = 30;`). Lowering this will detect more features but increases memory reads and potentially raises visual noise. Adjust this to match your environment's lighting.
- **Optical Flow Timing:** The Cortex-M3 needs to finish the `compute_optical_flow()` block before the FPGA signals the next frame. The current `uart_put_int()` transmit is synchronous and blocking; if UART printing takes too long, frames may be dropped. Consider utilizing an interrupt-based UART TX buffer if dropping frames becomes an issue in the future.
