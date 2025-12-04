/*
 * Drop Ceiling DMX Network Test
 * Simple test to send values to DMX addresses 1, 2, 3 via ArtNet
 * 
 * ArtNet Node IP: 169.254.166.100
 * Subnet: 255.255.0.0
 */

import ch.bildspur.artnet.*;
import controlP5.*;

// ControlP5
ControlP5 cp5;

// ArtNet configuration
ArtNetClient artnet;
byte[] dmxData = new byte[512];  // DMX universe has 512 channels

// Network settings
String artnetNodeIP = "169.254.166.100";
int subnet = 0;
int universe = 0;

// Test values for DMX channels 1, 2, 3
float channel1Value = 0;
float channel2Value = 0;
float channel3Value = 0;

void setup()
{
  size(400, 400);
  
  // Initialize ControlP5
  cp5 = new ControlP5(this);
  
  // Create slider for Channel 1
  cp5.addSlider("ch1")
     .setPosition(20, 50)
     .setSize(350, 30)
     .setRange(0, 145)
     .setValue(0)
     .setLabel("Channel 1")
     .setColorCaptionLabel(color(255))
     .onChange(new CallbackListener() {
       public void controlEvent(CallbackEvent event) {
         channel1Value = event.getController().getValue();
       }
     });
  
  // Create slider for Channel 2
  cp5.addSlider("ch2")
     .setPosition(20, 100)
     .setSize(350, 30)
     .setRange(0, 145)
     .setValue(0)
     .setLabel("Channel 2")
     .setColorCaptionLabel(color(255))
     .onChange(new CallbackListener() {
       public void controlEvent(CallbackEvent event) {
         channel2Value = event.getController().getValue();
       }
     });
  
  // Create slider for Channel 3
  cp5.addSlider("ch3")
     .setPosition(20, 150)
     .setSize(350, 30)
     .setRange(0, 145)
     .setValue(0)
     .setLabel("Channel 3")
     .setColorCaptionLabel(color(255))
     .onChange(new CallbackListener() {
       public void controlEvent(CallbackEvent event) {
         channel3Value = event.getController().getValue();
       }
     });
  
  // Initialize ArtNet client with specific network interface
  artnet = new ArtNetClient();
  artnet.start("169.254.166.10");  // Bind to our local IP on en4
  
  // Initialize DMX data array to zero
  for (int i = 0; i < dmxData.length; i++)
  {
    dmxData[i] = 0;
  }
  
  println("ArtNet DMX Test Started");
  println("Local IP: 169.254.166.10");
  println("Target IP: " + artnetNodeIP);
  println("Universe: " + universe);
  println("Channels will fade up and down continuously");
}

void draw()
{
  background(50);
  
  // Update DMX data array directly from slider values
  // DMX channels are 1-indexed, but array is 0-indexed
  // Convert to byte with proper unsigned handling
  dmxData[0] = (byte)(int(channel1Value) & 0xFF);  // DMX Channel 1
  dmxData[1] = (byte)(int(channel2Value) & 0xFF);  // DMX Channel 2
  dmxData[2] = (byte)(int(channel3Value) & 0xFF);  // DMX Channel 3
  
  // Send DMX data via ArtNet
  artnet.unicastDmx(artnetNodeIP, subnet, universe, dmxData);
  
  // Display current values on screen
  fill(255);
  textAlign(LEFT);
  textSize(14);
  
  text("ArtNet DMX Manual Control", 20, 30);
  text("Target: " + artnetNodeIP, 20, 220);
  text("Universe: " + universe, 20, 240);
  
  text("Channel 1 (R): " + int(channel1Value) + " (DMX[0]=" + (int(dmxData[0]) & 0xFF) + ")", 20, 270);
  text("Channel 2 (G): " + int(channel2Value) + " (DMX[1]=" + (int(dmxData[1]) & 0xFF) + ")", 20, 290);
  text("Channel 3 (B): " + int(channel3Value) + " (DMX[2]=" + (int(dmxData[2]) & 0xFF) + ")", 20, 310);
}

void exit()
{
  // Clean shutdown
  artnet.stop();
  super.exit();
}
