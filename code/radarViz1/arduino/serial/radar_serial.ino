#include <Arduino.h>

// ============== CONFIGURATION ==============
// Radar pins
#define RX_PIN 20
#define TX_PIN 21
#define RADAR_BAUD 256000

// Serial output baud rate
#define OUTPUT_BAUD 115200

// Frame timing
#define FRAME_TIMEOUT_MS 100               // Max time between bytes in a frame
#define MIN_SEND_INTERVAL_MS 20            // Minimum ms between serial sends (~50Hz max)

// ============== GLOBALS ==============
HardwareSerial RadarSerial(1);

// Radar frame constants
#define FRAME_SIZE 32                      // AA FF 03 00 + 24 data + 55 CC
#define FRAME_HEADER_SIZE 4
#define TARGET_DATA_SIZE 8
const uint8_t FRAME_HEADER[4] = {0xAA, 0xFF, 0x03, 0x00};
const uint8_t FRAME_TAIL[2] = {0x55, 0xCC};

// Frame buffer and state machine
uint8_t frameBuf[FRAME_SIZE];
uint8_t frameIdx = 0;
uint32_t lastByteTime = 0;
uint32_t lastSendTime = 0;
uint32_t frameCount = 0;
uint32_t errorCount = 0;

// Parser state
enum ParserState {
    SYNC_HEADER,      // Looking for AA FF 03 00
    READ_DATA,        // Reading target data
    VERIFY_TAIL       // Checking for 55 CC
};
ParserState parserState = SYNC_HEADER;
uint8_t syncIdx = 0;

// Target data structure
struct Target {
    int16_t x;
    int16_t y;
    int16_t speed;
    uint16_t distance_res;
    float distance;
    float angle;
    bool valid;
};

Target targets[3];

// Commands
const uint8_t Multi_Target_Detection_CMD[12] = {
    0xFD, 0xFC, 0xFB, 0xFA, 0x02, 0x00, 0x90, 0x00, 0x04, 0x03, 0x02, 0x01
};

// ============== SERIAL SEND ==============
void sendSerial() {
    // Rate limit sending
    uint32_t now = millis();
    if (now - lastSendTime < MIN_SEND_INTERVAL_MS) return;
    lastSendTime = now;
    
    // Count valid targets
    int count = 0;
    for (int i = 0; i < 3; i++) {
        if (targets[i].valid) count++;
    }
    
    // Send each valid target as comma-separated values
    // Format: T,index,x,y,distance,angle,speed
    for (int i = 0; i < 3; i++) {
        if (targets[i].valid) {
            Serial.print("T,");
            Serial.print(i + 1);
            Serial.print(",");
            Serial.print(targets[i].x);
            Serial.print(",");
            Serial.print(targets[i].y);
            Serial.print(",");
            Serial.print(targets[i].distance, 1);
            Serial.print(",");
            Serial.print(targets[i].angle, 1);
            Serial.print(",");
            Serial.println(targets[i].speed);
        }
    }
    
    // Send target count
    // Format: C,count
    Serial.print("C,");
    Serial.println(count);
}

// ============== RADAR PARSING ==============
void parseTarget(int idx, const uint8_t* data) {
    // Read raw 16-bit values (little endian)
    uint16_t raw_x = data[0] | (data[1] << 8);
    uint16_t raw_y = data[2] | (data[3] << 8);
    uint16_t raw_speed = data[4] | (data[5] << 8);
    uint16_t raw_dist = data[6] | (data[7] << 8);
    
    // Check if target is valid (non-zero data)
    targets[idx].valid = (raw_x != 0 || raw_y != 0);
    
    if (!targets[idx].valid) {
        targets[idx].x = 0;
        targets[idx].y = 0;
        targets[idx].speed = 0;
        targets[idx].distance = 0;
        targets[idx].angle = 0;
        return;
    }
    
    // X coordinate: bit 15 is sign indicator
    // Per datasheet: bit 15 = 1 means positive, bit 15 = 0 means negative
    int16_t x_val = (raw_x & 0x7FFF);  // Get magnitude (lower 15 bits)
    if (!(raw_x & 0x8000)) {           // If bit 15 is NOT set, value is negative
        x_val = -x_val;
    }
    targets[idx].x = x_val;
    
    // Y coordinate: offset by 0x8000 (always positive, forward direction)
    targets[idx].y = (int16_t)(raw_y - 0x8000);
    
    // Speed: bit 15 indicates direction
    // Positive = moving away, Negative = approaching
    int16_t spd_val = (raw_speed & 0x7FFF);
    if (!(raw_speed & 0x8000)) {
        spd_val = -spd_val;
    }
    targets[idx].speed = spd_val;
    
    // Distance resolution value
    targets[idx].distance_res = raw_dist;
    
    // Calculate distance in cm from X,Y coordinates (which are in mm)
    float x_mm = (float)targets[idx].x;
    float y_mm = (float)targets[idx].y;
    targets[idx].distance = sqrtf(x_mm * x_mm + y_mm * y_mm) / 10.0f;
    
    // Calculate angle: atan2(x, y) gives angle from forward (Y) axis
    // Positive X = right, Negative X = left
    targets[idx].angle = atan2f(x_mm, y_mm) * 180.0f / PI;
}

void processFrame() {
    frameCount++;
    
    // Parse all 3 targets from the frame buffer
    // Target 1: bytes 4-11, Target 2: bytes 12-19, Target 3: bytes 20-27
    parseTarget(0, &frameBuf[4]);
    parseTarget(1, &frameBuf[12]);
    parseTarget(2, &frameBuf[20]);
    
    sendSerial();
}

void resetParser() {
    parserState = SYNC_HEADER;
    syncIdx = 0;
    frameIdx = 0;
}

void processByte(uint8_t b) {
    lastByteTime = millis();
    
    switch (parserState) {
        case SYNC_HEADER:
            // Look for header bytes AA FF 03 00
            if (b == FRAME_HEADER[syncIdx]) {
                frameBuf[syncIdx] = b;
                syncIdx++;
                if (syncIdx >= FRAME_HEADER_SIZE) {
                    // Header found, now read data
                    parserState = READ_DATA;
                    frameIdx = FRAME_HEADER_SIZE;
                }
            } else if (b == FRAME_HEADER[0]) {
                // Could be start of new header
                syncIdx = 1;
                frameBuf[0] = b;
            } else {
                syncIdx = 0;
            }
            break;
            
        case READ_DATA:
            frameBuf[frameIdx++] = b;
            // We need 24 bytes of target data + 2 bytes tail = 26 more bytes
            // Total frame: header(4) + 3*target(24) + tail(2) = 30 bytes
            if (frameIdx >= 30) {
                // Check tail
                if (frameBuf[28] == 0x55 && frameBuf[29] == 0xCC) {
                    processFrame();
                } else {
                    errorCount++;
                }
                resetParser();
            }
            break;
            
        default:
            resetParser();
            break;
    }
}

// ============== SETUP ==============
void setup() {
    Serial.begin(OUTPUT_BAUD);
    delay(1000);
    Serial.println("=== RD-03D Radar -> Serial ===");

    Serial.printf("Radar: RX=GPIO%d, TX=GPIO%d, Baud=%d\n", RX_PIN, TX_PIN, RADAR_BAUD);
    RadarSerial.begin(RADAR_BAUD, SERIAL_8N1, RX_PIN, TX_PIN);
    RadarSerial.setRxBufferSize(512);  // Larger buffer for high baud rate

    delay(500);

    // Send multi-target detection command
    RadarSerial.write(Multi_Target_Detection_CMD, sizeof(Multi_Target_Detection_CMD));
    delay(200);
    Serial.println("Multi-target detection activated.");
    Serial.printf("Frame size: %d bytes, Send rate limit: %dms\n", FRAME_SIZE, MIN_SEND_INTERVAL_MS);
    Serial.println("Output format: T,index,x,y,distance,angle,speed");
    Serial.println("               C,count");
    Serial.println();

    // Clear any stale data
    while (RadarSerial.available()) RadarSerial.read();
    resetParser();
    lastByteTime = millis();
}

// ============== LOOP ==============
void loop() {
    // Check for frame timeout (partial frame stuck)
    if (parserState != SYNC_HEADER && (millis() - lastByteTime > FRAME_TIMEOUT_MS)) {
        errorCount++;
        resetParser();
    }
    
    // Process all available bytes
    while (RadarSerial.available()) {
        uint8_t b = RadarSerial.read();
        processByte(b);
    }
    
    // Periodic status (every 10 seconds)
    static uint32_t lastStatus = 0;
    if (millis() - lastStatus > 10000) {
        lastStatus = millis();
        Serial.printf("[Status] Frames: %lu, Errors: %lu\n", frameCount, errorCount);
    }
}
