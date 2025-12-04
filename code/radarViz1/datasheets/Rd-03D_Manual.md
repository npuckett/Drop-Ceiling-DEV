# Rd-03D_V2 Multi-Target Trajectory Tracking User Manual V1.0.0

## 1 Rd-03D_V2 Overview

Target tracking refers to the real-time tracking of the location of the target in the region, to achieve the target in the region ranging, angle measurement and velocity measurement.

The Rd-03D_V2 is a high-precision multi-target recognition millimeter-wave sensor (finalized design) of the silicon micro-EZSensor series, which includes extremely simplified 24 GHz radar sensor hardware CS202_v2 and intelligent algorithm firmware TTO1. This solution is mainly used in common indoor scenes such as homes, offices and hotels to achieve positioning and tracking of single or multiple human bodies.

The sensor hardware consists of AloT millimeter-wave radar chip ICL1122, high-performance microstrip antenna with one transmitter and two receiver, low-cost MCU and peripheral auxiliary circuit. The intelligent algorithm firmware TTO1 uses FMCW waveform and ICL1122 chip proprietary advanced signal processing technology.

### Main Features

| No. | Characteristics | No. | Characteristics |
|-----|-----------------|-----|-----------------|
| 1 | 24GHz ISM band | 6 | 5V power supply |
| 2 | Integrate smart millimeter-wave radar chip ICL1122 and smart algorithm firmware | 7 | Max. detection distance: 8m |
| 3 | Accurate target positioning and tracking | 8 | Azimuth ±60°, Pitch ±30° |
| 4 | Ultra-small module size: 15mm x 44mm | 9 | Wall mounting |
| 5 | Ambient temperature: -20℃ ~ 70℃ | | |

## 2 System Specifications

| Parameters | Minimum | Typical | Maximum | Unit | Remarks |
|------------|---------|---------|---------|------|---------|
| **Hardware Specifications** |||||
| Supported bands | 24 | - | 24.25 | GHz | Comply with FCC, CE certification standards |
| Maximum sweep bandwidth | - | 0.25 | - | GHz | |
| Supply voltage | 4.5 | 5 | 5.5 | V | |
| Dimensions | - | 15 x 44 | - | mm² | |
| Ambient temperature | -20 | - | 70 | ℃ | |
| **System Performance** |||||
| Maximum sensing distance | - | 8 | - | m | |
| Distance resolution | - | 0.75 | - | m | |
| Ranging accuracy | - | 0.15 | - | m | |
| Angle accuracy | - | - | 20 | ° | |
| Data Refresh Rate | 2 | - | 24 | Hz | Frequency of reporting results |
| Average operating current | - | 110 | - | mA | |

## 3 Hardware Description

### J1 Pin Description (FWF15004 Connector)

| J#PIN# | Name | Function | Description |
|--------|------|----------|-------------|
| J1PIN1 | 5V | Power input | 5V |
| J1PIN2 | GND | Ground | Connect to serial board GND |
| J1PIN3 | TX | UART_TX | Connect to serial board RXD |
| J1PIN4 | RX | UART_RX | Connect to serial board TXD |
| J1PIN5 | DP | Positive signal of programming data | Not connected when using a 4-pin serial board |
| J1PIN6 | DM | Negative signal of programming data | Not connected when using a 4-pin serial board |

### J2 Pin Description

| J#PIN# | Name | Function | Description |
|--------|------|----------|-------------|
| J2PIN1 | 5V | Power input | 5V |
| J2PIN2 | DM | Negative signal of programming data | - |
| J2PIN3 | DP | Positive signal of programming data | - |
| J2PIN4 | DEBUG | Debug output TXD | Serial port pin for outputting debugging log |
| J2PIN5 | GND | Ground | - |
| J2PIN6 | TX | UART_TXD | Connect to serial board RXD |
| J2PIN7 | RX | UART_RXD | Connect to serial board TXD |

## 5 Communication Protocol

The Rd-03D_V2 module communicates with the outside world through the serial port (TTL level).

### Serial Settings
- **Baud rate:** 256000
- **Stop bits:** 1
- **Parity:** None

### Data Frame Format

| Frame Header | Target 1 Info (8 bytes) | Target 2 Info (8 bytes) | Target 3 Info (8 bytes) | Frame Tail |
|--------------|------------------------|------------------------|------------------------|------------|
| AA FF 03 00 | X, Y, Speed, Distance | X, Y, Speed, Distance | X, Y, Speed, Distance | 55 CC |

### Target Data Format (8 bytes per target)

| Field | Type | Description |
|-------|------|-------------|
| Target X coordinate | signed int16 | Bit 15: 1=positive, 0=negative. Bits 0-14: absolute value in mm |
| Target Y coordinate | signed int16 | Bit 15: 1=positive, 0=negative. Bits 0-14: absolute value in mm |
| Target Speed | signed int16 | Bit 15: 1=positive (away), 0=negative (approaching). Bits 0-14: absolute value in cm/s |
| Distance resolution | uint16 | Pixel distance value in mm |

### Data Example

```
AA FF 03 00 0E 03 B1 86 10 00 68 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 55 CC
```

**Parsing Target 1 (blue field):**
- Target 1 X coordinate: 0x0E + 0x03*256 = 782 → 0-782 = **-782 mm**
- Target 1 Y coordinate: 0xB1 + 0x86*256 = 34481 → 34481-2^15 = **1713 mm**
- Target 1 speed: 0x10 + 0x00*256 = 16 → 0-16 = **-16 cm/s**
- Target 1 Distance Resolution: 0x68 + 0x01*256 = **360 mm**

Target 2 and Target 3 are all 0x00 (not present).

## 6 Firmware Parameter Configuration

### 6.1 Data Reporting Interval Settings
- Default: 0.1 seconds
- Minimum: 0.1 seconds
- Function: `Set_ReportIntervalTime(float seconds)`

### 6.2 Target Hold Interval
- Default: 37 seconds
- Function: `Set_HoldCntTime(float seconds)`

### 6.3 Detection Range Setting
- `Set_RectRange(int16_t xn, int16_t xp, int16_t y)` - Rectangular detection range
- `Set_SectorArea(uint16_t distance, uint8_t angle)` - Sector detection range

## 7 Installation and Detection Range

- **Recommended installation:** Wall-hanging
- **Recommended height:** 1.5m ~ 2m
- **Maximum detection distance:** 8m
- **Detection angle range:** ±60° centered on radar antenna normal direction

### Coordinate System

```
        +Y (forward from sensor)
         ↑
         |
   -X ←--●--→ +X
         |
      (sensor)
```

## 9 Installation Instructions

### 9.1 Radar Enclosure Requirements
- Enclosure must have good permeability in the 24 GHz band
- Must not contain metal or materials that shield electromagnetic waves

### 9.2 Environmental Requirements
Avoid these environments:
- Non-human objects with continuous movement (animals, swinging curtains, large plants)
- Large area strong reflection planes
- Air conditioners and electric fans pointing at the sensor

### 9.3 Precautions
- Ensure radar antenna is facing the detection area, unobstructed
- Installation position must be firm and stable
- Use metal shield or back plate to reduce interference from behind the radar
- Multiple 24 GHz radars should not face each other

## 10 Considerations

### 10.1 Firmware Baud Rate
- Default: 256000
- When using lower baud rates, extend data reporting interval accordingly

### 10.2 Maximum Distance, Accuracy and Angular Accuracy
Due to different target size, state and RCS, accuracy may fluctuate.

### 10.3 Power Considerations
Consider ESD and lightning surge electromagnetic compatibility design.

---

## Quick Reference

| Parameter | Value |
|-----------|-------|
| Detection Angle | Azimuth: ±60°, Pitch: ±30° |
| Max Detection Distance | 8m |
| Distance Resolution | 0.75m |
| Ranging Accuracy | 0.15m |
| Angle Accuracy | ~20° |
| Baud Rate | 256000 |
| Data Refresh Rate | 2-24 Hz |
| Targets Tracked | Up to 3 simultaneous |
| Frame Header | `AA FF 03 00` |
| Frame Tail | `55 CC` |
| Frame Size | 32 bytes total |

---

*Copyright © 2025 Shenzhen Ai-Thinker Technology Co., Ltd*
