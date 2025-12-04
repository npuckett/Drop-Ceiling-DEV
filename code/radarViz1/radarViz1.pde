// Rd-03D Radar OSC Receiver
// Install oscP5 library: Sketch -> Import Library -> Add Library -> search "oscP5"

import oscP5.*;
import netP5.*;

OscP5 oscP5;

// Target data
int targetCount = 0;
Target[] targets = new Target[3];

// Display settings
float radarRadius;
float maxDistance = 800;  // Max distance in cm to display (8 meters)
float maxDetectionRadius = 800;  // Ignore targets beyond this distance in cm (8 meters)
boolean showGrid = true;
boolean showLabels = true;
int TARGET_TIMEOUT = 500;  // ms before target disappears
boolean flipped = true;  // true = sensor at top looking down, false = sensor at bottom looking up

// RD-03D beam specifications
float beamAngle = 60;  // ±60° detection angle (120° total)
int gridSpacingCm = 10;  // 10cm grid spacing

class Target {
  int x, y;           // mm (raw)
  float distance;     // cm
  float angle;        // degrees
  int speed;          // cm/s
  boolean valid;
  long lastUpdate;
  
  // For display
  float displayX, displayY;
  
  Target() {
    valid = false;
    lastUpdate = 0;
  }
  
  void update(int _x, int _y, float _dist, float _angle, int _speed) {
    // Ignore targets outside max detection radius
    if (_dist > maxDetectionRadius) {
      return;
    }
    
    // Store values
    x = _x;
    y = _y;
    distance = _dist;
    angle = _angle;
    speed = _speed;
    valid = true;
    lastUpdate = millis();
    
    // Calculate display position based on flipped mode
    float maxDistMM = maxDistance * 10;
    if (flipped) {
      // Sensor at top, looking down - negate X to correct mirroring
      displayX = map(-x, -maxDistMM, maxDistMM, -radarRadius, radarRadius);
      displayY = map(y, 0, maxDistMM, 0, radarRadius);
    } else {
      // Sensor at bottom, looking up
      displayX = map(x, -maxDistMM, maxDistMM, -radarRadius, radarRadius);
      displayY = map(y, 0, maxDistMM, 0, -radarRadius);
    }
  }
  
  void checkTimeout() {
    if (millis() - lastUpdate > TARGET_TIMEOUT) {
      valid = false;
    }
  }
}

void setup() {
  size(1400, 700);
  smooth(8);
  
  radarRadius = width * 0.42;  // Larger visualization
  
  // Initialize targets
  for (int i = 0; i < 3; i++) {
    targets[i] = new Target();
  }
  
  // Start OSC listener on port 8000
  oscP5 = new OscP5(this, 8000);
  
  println("=== Rd-03D Radar Receiver ===");
  println("Listening for OSC on port 8000");
  println("Expected messages:");
  println("  /radar/1  /radar/2  /radar/3  (x, y, distance, angle, speed)");
  println("  /radar/count (count)");
  println("");
  println("Keys: +/- = zoom, R = reset, G = grid, L = labels, F = flip");
}

void draw() {
  background(10, 20, 30);
  
  if (flipped) {
    translate(width/2, height * 0.08);  // Sensor at top, smaller margin
  } else {
    translate(width/2, height * 0.92);  // Sensor at bottom
  }
  
  // Check timeouts
  for (Target t : targets) {
    t.checkTimeout();
  }
  
  // Draw radar display
  drawRadarGrid();
  drawTargets();
  
  // Draw info panel
  resetMatrix();
  drawInfoPanel();
}

void drawRadarGrid() {
  // Calculate beam arc angles based on orientation
  float arcStart, arcEnd;
  if (flipped) {
    // Sensor at top, looking down: 0° is right, 90° is down, 180° is left
    arcStart = radians(90 - beamAngle);  // 30°
    arcEnd = radians(90 + beamAngle);    // 150°
  } else {
    // Sensor at bottom, looking up
    arcStart = radians(-90 - beamAngle);  // -150°
    arcEnd = radians(-90 + beamAngle);    // -30°
  }
  
  // 1. Draw filled detection zone arc (background)
  fill(20, 45, 35);
  noStroke();
  arc(0, 0, radarRadius * 2, radarRadius * 2, arcStart, arcEnd, PIE);
  
  // 2. Distance arcs within beam angle
  noFill();
  strokeWeight(1);
  
  for (int i = 1; i <= 8; i++) {
    float r = radarRadius * i / 8.0;
    
    if (i % 2 == 0) {
      stroke(255);
    } else {
      stroke(255, 100);
    }
    
    // Draw arc only within beam angle (±60°)
    arc(0, 0, r * 2, r * 2, arcStart, arcEnd);
  }
  
  // 3. Draw beam boundary lines at ±60°
  stroke(60, 100, 80);
  strokeWeight(2);
  float leftAngle, rightAngle;
  if (flipped) {
    leftAngle = radians(90 + beamAngle);   // Left edge
    rightAngle = radians(90 - beamAngle);  // Right edge
  } else {
    leftAngle = radians(-90 - beamAngle);
    rightAngle = radians(-90 + beamAngle);
  }
  float leftX = cos(leftAngle) * radarRadius;
  float leftY = sin(leftAngle) * radarRadius;
  float rightX = cos(rightAngle) * radarRadius;
  float rightY = sin(rightAngle) * radarRadius;
  line(0, 0, leftX, leftY);
  line(0, 0, rightX, rightY);
  
  // 4. Draw grid lines on top
  if (showGrid) {
    float pixelsPerCm = radarRadius / maxDistance;
    
    // Vertical grid lines (X axis)
    for (int x = -((int)maxDistance); x <= (int)maxDistance; x += gridSpacingCm) {
      float px = x * pixelsPerCm;
      // Brighter lines at 1 meter marks
      if (x % 100 == 0) {
        stroke(255);
        strokeWeight(1.5);
      } else {
        stroke(255, 60);
        strokeWeight(0.5);
      }
      if (flipped) {
        line(px, 0, px, radarRadius);
      } else {
        line(px, 0, px, -radarRadius);
      }
    }
    
    // Horizontal grid lines (Y axis / distance from sensor)
    for (int y = 0; y <= (int)maxDistance; y += gridSpacingCm) {
      float py = y * pixelsPerCm;
      // Brighter lines at 1 meter marks
      if (y % 100 == 0) {
        stroke(255);
        strokeWeight(1.5);
      } else {
        stroke(255, 60);
        strokeWeight(0.5);
      }
      if (flipped) {
        line(-radarRadius, py, radarRadius, py);
      } else {
        line(-radarRadius, -py, radarRadius, -py);
      }
    }
    
    // Draw meter labels on Y axis
    fill(80, 140, 110);
    textAlign(LEFT, CENTER);
    textSize(11);
    for (int y = 100; y <= (int)maxDistance; y += 100) {
      float py = y * pixelsPerCm;
      int meters = y / 100;
      if (flipped) {
        text(meters + "m", radarRadius + 8, py);
      } else {
        text(meters + "m", radarRadius + 8, -py);
      }
    }
  }
  
  // 5. Labels
  if (showLabels) {
    // Distance labels along center line
    for (int i = 2; i <= 8; i += 2) {
      float r = radarRadius * i / 8.0;
      fill(60, 120, 90);
      textAlign(CENTER, CENTER);
      textSize(10);
      int distLabel = (int)(maxDistance * i / 8);
      if (flipped) {
        text(distLabel + "cm", 0, r + 12);
      } else {
        text(distLabel + "cm", 0, -r - 12);
      }
    }
    
    // Angle labels at beam edges
    fill(60, 120, 90);
    textAlign(CENTER, CENTER);
    textSize(10);
    text("-" + (int)beamAngle + "°", leftX * 1.12, leftY * 1.12);
    text("+" + (int)beamAngle + "°", rightX * 1.12, rightY * 1.12);
    
    // Center line label
    if (flipped) {
      text("0°", 0, radarRadius * 1.08);
    } else {
      text("0°", 0, -radarRadius * 1.08);
    }
  }
  
  // 6. Center point (sensor location)
  fill(100, 200, 150);
  noStroke();
  ellipse(0, 0, 10, 10);
  
  // Sensor base line
  stroke(60, 100, 80);
  strokeWeight(2);
  float baseWidth = radarRadius * 0.15;
  line(-baseWidth, 0, baseWidth, 0);
}

void drawTargets() {
  for (int i = 0; i < 3; i++) {
    Target t = targets[i];
    if (!t.valid) continue;
    
    // Target color based on index
    color c;
    switch (i) {
      case 0: c = color(255, 100, 100); break;  // Red
      case 1: c = color(100, 255, 100); break;  // Green
      case 2: c = color(100, 100, 255); break;  // Blue
      default: c = color(255);
    }
    
    // Pulse effect
    float pulse = sin(millis() * 0.005 + i) * 0.3 + 0.7;
    
    // Draw target blip
    noStroke();
    fill(c, 100);
    ellipse(t.displayX, t.displayY, 40 * pulse, 40 * pulse);
    
    fill(c);
    ellipse(t.displayX, t.displayY, 16, 16);
    
    // Target label
    fill(255);
    textAlign(LEFT, CENTER);
    textSize(12);
    text("T" + (i + 1), t.displayX + 15, t.displayY - 15);
    
    // Speed indicator (line showing direction/magnitude)
    if (abs(t.speed) > 5) {
      stroke(c);
      strokeWeight(2);
      float speedLen = constrain(t.speed * 0.5, -30, 30);
      // Draw line in direction of movement (assuming Y is forward)
      line(t.displayX, t.displayY, t.displayX, t.displayY + speedLen);
      
      // Arrowhead
      if (t.speed > 0) {
        // Moving away
        triangle(t.displayX, t.displayY + speedLen,
                 t.displayX - 4, t.displayY + speedLen - 6,
                 t.displayX + 4, t.displayY + speedLen - 6);
      } else {
        // Moving closer
        triangle(t.displayX, t.displayY + speedLen,
                 t.displayX - 4, t.displayY + speedLen + 6,
                 t.displayX + 4, t.displayY + speedLen + 6);
      }
    }
  }
}

void drawInfoPanel() {
  int panelX = 20;
  int panelY = 20;
  
  // Background
  fill(0, 150);
  noStroke();
  rect(panelX - 10, panelY - 10, 280, 200, 8);
  
  // Title
  fill(255);
  textAlign(LEFT, TOP);
  textSize(16);
  text("Rd-03D Radar", panelX, panelY);
  
  textSize(12);
  fill(150);
  text("Targets: " + targetCount + "  |  Range: " + (int)maxDistance + "cm", panelX, panelY + 25);
  
  // Target details
  int y = panelY + 50;
  for (int i = 0; i < 3; i++) {
    Target t = targets[i];
    
    // Color indicator
    switch (i) {
      case 0: fill(255, 100, 100); break;
      case 1: fill(100, 255, 100); break;
      case 2: fill(100, 100, 255); break;
    }
    
    if (t.valid) {
      ellipse(panelX + 5, y + 6, 10, 10);
      fill(255);
      text(String.format("T%d: %.0fcm @ %.0f° | %dcm/s", 
           i + 1, t.distance, t.angle, t.speed), panelX + 15, y);
      text(String.format("    X:%dmm Y:%dmm", t.x, t.y), panelX + 15, y + 14);
    } else {
      fill(80);
      ellipse(panelX + 5, y + 6, 10, 10);
      fill(100);
      text("T" + (i + 1) + ": --", panelX + 15, y);
    }
    y += 40;
  }
}

// ============== OSC HANDLERS ==============

void oscEvent(OscMessage msg) {
  String addr = msg.addrPattern();
  
  if (addr.equals("/radar/count")) {
    targetCount = msg.get(0).intValue();
    
  } else if (addr.startsWith("/radar/")) {
    // Extract target number from address
    try {
      int idx = Integer.parseInt(addr.substring(7)) - 1;
      if (idx >= 0 && idx < 3) {
        int x = msg.get(0).intValue();
        int y = msg.get(1).intValue();
        float dist = msg.get(2).floatValue();
        float angle = msg.get(3).floatValue();
        int speed = msg.get(4).intValue();
        
        targets[idx].update(x, y, dist, angle, speed);
        
        // Debug output
        println(String.format("T%d: x=%d y=%d dist=%.1f angle=%.1f spd=%d",
                idx + 1, x, y, dist, angle, speed));
      }
    } catch (Exception e) {
      println("Error parsing OSC: " + e.getMessage());
    }
  }
}

// ============== KEYBOARD CONTROLS ==============

void keyPressed() {
  if (key == 'g' || key == 'G') {
    showGrid = !showGrid;
  }
  if (key == 'l' || key == 'L') {
    showLabels = !showLabels;
  }
  if (key == '+' || key == '=') {
    maxDistance = min(maxDistance + 100, 2000);
    maxDetectionRadius = maxDistance;
    println("Range: " + maxDistance + "cm");
  }
  if (key == '-' || key == '_') {
    maxDistance = max(maxDistance - 100, 200);
    maxDetectionRadius = maxDistance;
    println("Range: " + maxDistance + "cm");
  }
  if (key == 'r' || key == 'R') {
    // Reset all targets
    for (Target t : targets) {
      t.valid = false;
    }
    targetCount = 0;
    println("Targets reset");
  }
  if (key == 'f' || key == 'F') {
    // Flip orientation
    flipped = !flipped;
    println("Flipped: " + (flipped ? "sensor at top" : "sensor at bottom"));
  }
}
