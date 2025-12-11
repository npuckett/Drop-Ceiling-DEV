# RD-03D Multi-Target Radar Visualization

A complete system for reading multi-person tracking data from the Ai-Thinker RD-03D 24GHz mmWave radar and visualizing it in Processing.

## Hardware

- **Radar**: Ai-Thinker RD-03D (24GHz FMCW, ±60° azimuth, 8m range, tracks up to 3 targets)
- **Microcontroller**: ESP32 (or any ESP32 with hardware UART)
- **Communication**: Ethernet (OSC) or USB Serial

## Folder Structure

```
radarViz1/
├── README.md                    # This file
├── datasheets/                  # Radar documentation
│   └── Rd-03D_Manual.md
├── arduino/
│   ├── osc/
│   │   └── radar_osc.ino        # ESP32 → OSC over Ethernet
│   └── serial/
│       └── radar_serial.ino     # ESP32 → Serial CSV output
└── processing/
    ├── osc/
    │   └── radarViz1_osc.pde    # OSC receiver visualization
    └── serial/
        └── radarViz1_serial.pde # Serial receiver visualization
```

---

## RD-03D Data Format (Multi-Target Mode)

The RD-03D radar uses a proprietary binary protocol over UART at **256000 baud** (8N1). This section documents the frame format for multi-target detection mode, which is not well documented in the official datasheet.

### Enabling Multi-Target Mode

The radar defaults to single-target mode. To enable tracking of up to 3 targets, send this 12-byte command:

```
FD FC FB FA 02 00 90 00 04 03 02 01
└─────────┘ └───┘ └───┘ └─────────┘
  Preamble   Len   Cmd    Postamble
```

| Bytes | Value | Description |
|-------|-------|-------------|
| 0-3   | `FD FC FB FA` | Command preamble (start marker) |
| 4-5   | `02 00` | Payload length (2 bytes, little-endian) |
| 6-7   | `90 00` | Command: Enable multi-target mode |
| 8-11  | `04 03 02 01` | Command postamble (end marker) |

### Frame Structure

After enabling multi-target mode, the radar continuously outputs 30-byte frames:

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ Byte:  0   1   2   3 │ 4-11      │ 12-19     │ 20-27     │ 28  29                   │
│        ─────────────────────────────────────────────────────────────                │
│        Header        │ Target 1  │ Target 2  │ Target 3  │ Tail                     │
│        AA FF 03 00   │ (8 bytes) │ (8 bytes) │ (8 bytes) │ 55 CC                    │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

| Field | Bytes | Value | Description |
|-------|-------|-------|-------------|
| Header | 0-3 | `AA FF 03 00` | Frame start marker. `03` indicates 3 targets. |
| Target 1 | 4-11 | (see below) | First tracked target data |
| Target 2 | 12-19 | (see below) | Second tracked target data |
| Target 3 | 20-27 | (see below) | Third tracked target data |
| Tail | 28-29 | `55 CC` | Frame end marker |

### Target Data Block (8 bytes each)

Each target occupies 8 bytes with 4 fields, all in **little-endian** format:

```
┌───────────────────────────────────────────────────────────────┐
│ Offset: 0    1  │ 2    3  │ 4    5  │ 6    7                  │
│         ─────────────────────────────────────                 │
│         X coord  │ Y coord │ Speed   │ Distance               │
│         (2 bytes)│(2 bytes)│(2 bytes)│(2 bytes)               │
└───────────────────────────────────────────────────────────────┘
```

### Field Encoding Details

#### X Coordinate (bytes 0-1)
- **Unit**: Millimeters from sensor centerline
- **Range**: Approximately ±8000mm (±8 meters)
- **Encoding**: Sign-magnitude with inverted sign bit

```
Bit:  15  14  13  12  11  10  9   8   7   6   5   4   3   2   1   0
      ├───┼───────────────────────────────────────────────────────┤
      Sign                    Magnitude (0-32767)
      
      Bit 15 = 1  →  Positive (target is to the RIGHT of sensor)
      Bit 15 = 0  →  Negative (target is to the LEFT of sensor)
```

**Decoding:**
```cpp
uint16_t raw = byte[0] | (byte[1] << 8);  // Little-endian
int16_t x = (raw & 0x7FFF);               // Get magnitude
if (!(raw & 0x8000)) x = -x;              // Bit 15 clear = negative
```

**Example:**
| Raw bytes | Raw value | Bit 15 | Result |
|-----------|-----------|--------|--------|
| `E8 83` | 0x83E8 | 1 (set) | +1000 mm (1m right) |
| `E8 03` | 0x03E8 | 0 (clear) | -1000 mm (1m left) |
| `00 00` | 0x0000 | 0 | 0 (no target) |

#### Y Coordinate (bytes 2-3)
- **Unit**: Millimeters from sensor (forward distance)
- **Range**: 0 to ~8000mm (0-8 meters)
- **Encoding**: Unsigned with 0x8000 offset

```
Actual Y = Raw Value - 0x8000
```

**Decoding:**
```cpp
uint16_t raw = byte[2] | (byte[3] << 8);
int16_t y = (int16_t)(raw - 0x8000);
```

**Example:**
| Raw bytes | Raw value | Calculation | Result |
|-----------|-----------|-------------|--------|
| `00 80` | 0x8000 | 0x8000 - 0x8000 | 0 mm |
| `E8 83` | 0x83E8 | 0x83E8 - 0x8000 | +1000 mm |
| `D0 87` | 0x87D0 | 0x87D0 - 0x8000 | +2000 mm |

#### Speed (bytes 4-5)
- **Unit**: Centimeters per second
- **Range**: Approximately ±100+ cm/s
- **Encoding**: Same sign-magnitude as X coordinate

```
Bit 15 = 1  →  Positive speed (target moving AWAY from sensor)
Bit 15 = 0  →  Negative speed (target moving TOWARD sensor)
```

**Decoding:**
```cpp
uint16_t raw = byte[4] | (byte[5] << 8);
int16_t speed = (raw & 0x7FFF);
if (!(raw & 0x8000)) speed = -speed;
```

#### Distance Resolution (bytes 6-7)
- **Unit**: Internal resolution value
- **Note**: Not typically used; distance is calculated from X,Y

```cpp
float distance_cm = sqrtf(x*x + y*y) / 10.0f;  // X,Y are in mm
float angle_deg = atan2f(x, y) * 180.0f / PI;  // Angle from forward
```

### Invalid/Empty Targets

When fewer than 3 targets are detected, unused target slots contain all zeros:

```
00 00 00 00 00 00 00 00  = No target in this slot
```

Check for validity:
```cpp
bool valid = (raw_x != 0 || raw_y != 0);
```

### Complete Frame Example

Raw frame (30 bytes):
```
AA FF 03 00  E8 83 D0 87 0A 80 00 00  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  55 CC
└─ Header ─┘ └──── Target 1 ────────┘ └──── Target 2 ────────┘ └──── Target 3 ────────┘ └Tail┘
```

Decoded:
| Field | Raw | Decoded |
|-------|-----|---------|
| Target 1 X | `E8 83` | +1000 mm (1m right) |
| Target 1 Y | `D0 87` | +2000 mm (2m forward) |
| Target 1 Speed | `0A 80` | +10 cm/s (moving away) |
| Target 1 Dist | (calculated) | 223.6 cm |
| Target 1 Angle | (calculated) | 26.6° |
| Targets 2-3 | `00...` | Not detected |

### Frame Timing

- **Baud rate**: 256000 (high speed!)
- **Frame interval**: ~20-50ms depending on radar configuration
- **Byte time**: ~39μs per byte
- **Frame time**: ~1.2ms for 30 bytes

---

## Arduino: How It Works

### State Machine Parser

The Arduino uses a robust header-based state machine instead of scanning for tail bytes:

```
┌─────────────┐     AA FF 03 00      ┌─────────────┐
│ SYNC_HEADER │ ──────────────────→  │  READ_DATA  │
│ (waiting)   │                      │ (24 bytes)  │
└─────────────┘                      └─────────────┘
       ↑                                    │
       │              55 CC                 │
       └────────────────────────────────────┘
                   (validate & process)
```

**Key methods:**

1. **`processByte()`** - State machine that syncs on header `AA FF 03 00`
2. **`parseTarget()`** - Decodes 8-byte target data with proper sign handling
3. **`processFrame()`** - Validates frame and triggers data output
4. **`resetParser()`** - Resets state on timeout or error

### Coordinate Parsing (parseTarget)

```cpp
// X coordinate: bit 15 indicates sign
int16_t x_val = (raw_x & 0x7FFF);  // Lower 15 bits = magnitude
if (!(raw_x & 0x8000)) {           // Bit 15 NOT set = negative
    x_val = -x_val;
}

// Y coordinate: always positive, offset by 0x8000
int16_t y = (int16_t)(raw_y - 0x8000);

// Distance from X,Y (mm → cm)
float distance = sqrtf(x*x + y*y) / 10.0f;

// Angle from forward axis
float angle = atan2f(x, y) * 180.0f / PI;
```

### Rate Limiting

Both versions limit output rate to prevent flooding:
- **OSC**: 20ms minimum between sends (~50Hz max)
- **Serial**: 20ms minimum between sends

### Multi-Target Command

On startup, the radar must be put into multi-target mode:
```cpp
const uint8_t Multi_Target_Detection_CMD[12] = {
    0xFD, 0xFC, 0xFB, 0xFA, 0x02, 0x00, 0x90, 0x00, 0x04, 0x03, 0x02, 0x01
};
RadarSerial.write(Multi_Target_Detection_CMD, sizeof(Multi_Target_Detection_CMD));
```

---

## OSC Example

**Use case**: ESP32 with Ethernet, sending data over network to Processing

### Arduino (radar_osc.ino)

```
ESP32-P4 ──UART──→ RD-03D Radar
    │
    └──Ethernet──→ Processing (OSC port 8000)
```

**Configuration:**
```cpp
IPAddress localIP(169, 254, 166, 20);     // ESP32 static IP
IPAddress oscTargetIP(169, 254, 166, 10); // Computer IP
const uint16_t oscTargetPort = 8000;
```

**OSC Messages Sent:**
| Address        | Arguments                  | Description              |
|----------------|----------------------------|--------------------------|
| `/radar/1`     | x, y, distance, angle, speed | Target 1 data           |
| `/radar/2`     | x, y, distance, angle, speed | Target 2 data           |
| `/radar/3`     | x, y, distance, angle, speed | Target 3 data           |
| `/radar/count` | count                      | Number of valid targets  |

### Processing (radarViz1_osc.pde)

**Requirements:** oscP5 library (Sketch → Import Library → Add Library → "oscP5")

**Key features:**
- Listens on UDP port 8000
- Draws semicircular radar display with ±60° beam angle
- Color-coded targets (Red, Green, Blue)
- Speed indicators with directional arrows
- 10cm grid with 1m labels

**Keyboard controls:**
- `+/-` : Zoom in/out
- `G` : Toggle grid
- `L` : Toggle labels
- `R` : Reset targets

---

## Serial Example

**Use case**: Direct USB connection between ESP32 and Processing

### Arduino (radar_serial.ino)

```
ESP32 ──UART──→ RD-03D Radar
    │
    └──USB──→ Processing (Serial @ 115200 baud)
```

**Serial Output Format (CSV):**
```
T,1,1234,-567,145.2,23.5,12     # Target: index,x,y,distance,angle,speed
T,2,-890,2345,250.1,-20.8,-5
C,2                              # Count: number of valid targets
```

### Processing (radarViz1_serial.pde)

**Key features:**
- Auto-detects USB serial ports
- Same visualization as OSC version
- Reconnect with `P` key

**Keyboard controls:**
- `+/-` : Zoom in/out
- `G` : Toggle grid
- `L` : Toggle labels
- `R` : Reset targets
- `P` : Reconnect serial
- `F` : Flip orientation

---

## Wiring

### ESP32-P4 to RD-03D

| ESP32 Pin | RD-03D Pin | Description |
|-----------|------------|-------------|
| GPIO 20   | TX         | Radar transmit → ESP receive |
| GPIO 21   | RX         | ESP transmit → Radar receive |
| 3.3V      | VCC        | Power (3.3V or 5V depending on version) |
| GND       | GND        | Ground |

---

## Performance Notes

1. **Baud Rate**: The radar runs at 256000 baud - ensure proper wiring and short cables
2. **RX Buffer**: Increased to 512 bytes to handle high data rate
3. **Frame Timeout**: 100ms timeout resets parser if frame is incomplete
4. **Error Tracking**: Both versions report frame count and error count every 10 seconds

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No data from radar | Check TX/RX wiring (they should be crossed) |
| Garbled data | Verify baud rate is 256000 |
| Targets on wrong side | X negation is applied in Processing |
| Flickering targets | Increase TARGET_TIMEOUT in Processing |
| High error count | Check cable quality, reduce cable length |

---

## References

- [RD-03D Datasheet](datasheets/Rd-03D_Manual.md)
- [ESP32 Arduino Core](https://github.com/espressif/arduino-esp32)
- [oscP5 Library](https://sojamo.de/libraries/oscP5/)
