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

## Arduino: How It Works

### Frame Format (RD-03D Protocol)

The radar outputs 30-byte frames at 256000 baud:

```
┌──────────────────────────────────────────────────────────────────────────┐
│ Header (4)  │ Target 1 (8) │ Target 2 (8) │ Target 3 (8) │ Tail (2)      │
│ AA FF 03 00 │ X Y Spd Dist │ X Y Spd Dist │ X Y Spd Dist │ 55 CC         │
└──────────────────────────────────────────────────────────────────────────┘
```

Each target block contains:
| Bytes | Field    | Format                                              |
|-------|----------|-----------------------------------------------------|
| 0-1   | X        | Little-endian, bit 15: 1=positive, 0=negative (mm)  |
| 2-3   | Y        | Little-endian, offset by 0x8000 (mm)                |
| 4-5   | Speed    | Little-endian, bit 15: 1=away, 0=approaching (cm/s) |
| 6-7   | Distance | Distance resolution value                           |

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
