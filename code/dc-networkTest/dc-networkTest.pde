/*
 * Drop Ceiling DMX Network Test
 * Simple test to send values to DMX addresses 1, 2, 3 via ArtNet
 * 
 * ArtNet Node IP: 169.254.166.100
 * Subnet: 255.255.0.0
 */

import ch.bildspur.artnet.*;

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

// Fade control
float channel1Target = 255;
float channel2Target = 128;
float channel3Target = 64;
float fadeSpeed = 2.0;  // Fade speed per frame

void setup()
{
  size(400, 300);
  
  // Initialize ArtNet client
  artnet = new ArtNetClient();
  artnet.start();
  
  // Initialize DMX data array to zero
  for (int i = 0; i < dmxData.length; i++)
  {
    dmxData[i] = 0;
  }
  
  println("ArtNet DMX Test Started");
  println("Target IP: " + artnetNodeIP);
  println("Universe: " + universe);
  println("Channels will fade up and down continuously");
}

void draw()
{
  background(50);
  
  // Fade channels towards their targets
  channel1Value = lerp(channel1Value, channel1Target, 0.05);
  channel2Value = lerp(channel2Value, channel2Target, 0.05);
  channel3Value = lerp(channel3Value, channel3Target, 0.05);
  
  // Reverse direction when reaching targets
  if (abs(channel1Value - channel1Target) < 1)
  {
    channel1Target = (channel1Target > 127) ? 0 : 255;
  }
  if (abs(channel2Value - channel2Target) < 1)
  {
    channel2Target = (channel2Target > 127) ? 0 : 255;
  }
  if (abs(channel3Value - channel3Target) < 1)
  {
    channel3Target = (channel3Target > 127) ? 0 : 255;
  }
  
  // Update DMX data array
  // DMX channels are 1-indexed, but array is 0-indexed
  dmxData[0] = (byte)int(channel1Value);  // DMX Channel 1
  dmxData[1] = (byte)int(channel2Value);  // DMX Channel 2
  dmxData[2] = (byte)int(channel3Value);  // DMX Channel 3
  
  // Send DMX data via ArtNet
  artnet.unicastDmx(artnetNodeIP, subnet, universe, dmxData);
  
  // Display current values on screen
  fill(255);
  textAlign(LEFT);
  textSize(16);
  
  text("ArtNet DMX Test - Fading", 20, 30);
  text("Target: " + artnetNodeIP, 20, 60);
  
  text("Channel 1: " + int(channel1Value) + " → " + int(channel1Target), 20, 100);
  text("Channel 2: " + int(channel2Value) + " → " + int(channel2Target), 20, 130);
  text("Channel 3: " + int(channel3Value) + " → " + int(channel3Target), 20, 160);
  
  text("Press keys 1-3 to toggle channels", 20, 220);
  text("Press +/- to adjust fade speed", 20, 250);
  text("Fade speed: " + nf(fadeSpeed, 1, 1), 20, 280);
}

void keyPressed()
{
  // Toggle channel targets with number keys
  if (key == '1')
  {
    channel1Target = (channel1Target > 127) ? 0 : 255;
    println("Channel 1 target set to: " + int(channel1Target));
  }
  else if (key == '2')
  {
    channel2Target = (channel2Target > 127) ? 0 : 255;
    println("Channel 2 target set to: " + int(channel2Target));
  }
  else if (key == '3')
  {
    channel3Target = (channel3Target > 127) ? 0 : 255;
    println("Channel 3 target set to: " + int(channel3Target));
  }
  else if (key == '+' || key == '=')
  {
    fadeSpeed = min(fadeSpeed + 0.5, 10.0);
    println("Fade speed increased to: " + fadeSpeed);
  }
  else if (key == '-' || key == '_')
  {
    fadeSpeed = max(fadeSpeed - 0.5, 0.5);
    println("Fade speed decreased to: " + fadeSpeed);
  }
}

void exit()
{
  // Clean shutdown
  artnet.stop();
  super.exit();
}
