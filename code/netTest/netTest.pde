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
  size(1800, 900);
  
  // Initialize ControlP5
  cp5 = new ControlP5(this);
  
  // Create slider for Channel 1
  cp5.addSlider("ch1")
     .setPosition(550, 100)
     .setSize(1200, 80)
     .setRange(0, 145)
     .setValue(0)
     .setLabel("")
     .setCaptionLabel("")
     .onChange(new CallbackListener() {
       public void controlEvent(CallbackEvent event) {
         channel1Value = event.getController().getValue();
       }
     });
  
  // Create slider for Channel 2
  cp5.addSlider("ch2")
     .setPosition(550, 350)
     .setSize(1200, 80)
     .setRange(0, 145)
     .setValue(0)
     .setLabel("")
     .setCaptionLabel("")
     .onChange(new CallbackListener() {
       public void controlEvent(CallbackEvent event) {
         channel2Value = event.getController().getValue();
       }
     });
  
  // Create slider for Channel 3
  cp5.addSlider("ch3")
     .setPosition(550, 600)
     .setSize(1200, 80)
     .setRange(0, 145)
     .setValue(0)
     .setLabel("")
     .setCaptionLabel("")
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
  
  // Display title
  fill(255);
  textAlign(LEFT);
  textSize(24);
  text("ArtNet DMX Manual Control", 20, 40);
  
  // Display large channel values to the left of each slider
  textSize(288);
  textAlign(RIGHT);
  fill(255);  // White for Channel 1
  text(int(channel1Value), 520, 200);
  
  fill(255);  // White for Channel 2
  text(int(channel2Value), 520, 450);
  
  fill(255);  // White for Channel 3
  text(int(channel3Value), 520, 700);
  
  // Display channel labels
  textSize(24);
  textAlign(RIGHT);
  fill(180);
  text("Ch 1", 520, 230);
  text("Ch 2", 520, 480);
  text("Ch 3", 520, 730);
  
  // Display network info at bottom
  textAlign(LEFT);
  textSize(18);
  fill(180);
  text("Target: " + artnetNodeIP + "  |  Universe: " + universe, 30, 850);
  text("Local: 169.254.166.10", 30, 875);
}

void exit()
{
  // Clean shutdown
  artnet.stop();
  super.exit();
}
