/**
 * 
 * BeamNoise Rosette | Jim McArdle
 * 
 * A reimagining of the STDA BeamNoise Rosette via Processing & COntrolP5
 * 
 */

import controlP5.Accordion;
import controlP5.ControlP5;
import controlP5.Group;
import processing.core.*;

int NTRACES=6;
int NBEAMS=36;
  float traces[][] = new float[NTRACES][NBEAMS];
  
int viewport_w = 1280;
int viewport_h = 720;
int viewport_x = 230;
int viewport_y = 0;

int gui_w = 200;
int gui_x = 20;
int gui_y = 20;

int BACKGROUND_COLOR = 255;

boolean BB_MODE = false;

// BN Rosette Colors...
color BRED = color(180, 0, 0);
color RED = color(128, 0, 0);
color BGREEN = color(0, 180, 0);
color GREEN = color(0, 128, 0);

RosettePlot rosettePlot = new RosettePlot(250,20,300,420,200);

void settings() {
  size(600, 480);
}

void setup() {
  createGUI();
}

void draw() {

  if(frameCount%100==0) {
    getLevels();
  }
  background(BACKGROUND_COLOR);
  rosettePlot.draw(traces);
}

ControlP5 cp5;

void createGUI() {
  cp5 = new ControlP5(this);

  int sx, sy, px, py, oy;

  sx = 50; 
  sy = 14; 
  oy = (int)(sy*1.5f);


  ////////////////////////////////////////////////////////////////////////////
  // GUI - NARROW BANDS
  ////////////////////////////////////////////////////////////////////////////
  Group group_narrowband_settings = cp5.addGroup("Narrow Band Freqs");
  {

    group_narrowband_settings.setHeight(20)
      .setSize(gui_w, 200)
      .setBackgroundColor(color(16, 180))
      .setColorBackground(color(16, 180));

    group_narrowband_settings.getCaptionLabel().align(LEFT, CENTER);

    sx = 50;
    sy = 14;
    px = 10; 
    py = 0;
    oy = (int)(sy*1.4f);

    for (int i=0; i<6; i++) {
      int ifreq=(i+1)*100;
      
      cp5.addSlider("FREQ: "+ifreq)
        .setGroup(group_narrowband_settings)
        .setSize(sx, sy)
        .setPosition(px, py+=oy+10)
        .setRange(0, 5000)
        .setValue(0.0)
        .plugTo(rosettePlot, "setFreq"+i);
    }
  }

  ////////////////////////////////////////////////////////////////////////////
  // GUI - BROADBANDS
  ////////////////////////////////////////////////////////////////////////////
  Group group_broadband_settings = cp5.addGroup("Broadband Freqs");
  {

    group_broadband_settings.setHeight(20)
      .setSize(gui_w, 200)
      .setBackgroundColor(color(16, 180))
      .setColorBackground(color(16, 180));

    group_broadband_settings.getCaptionLabel().align(LEFT, CENTER);

    sx = 50;
    sy = 14;
    px = 10; 
    py = 0;
    oy = (int)(sy*1.4f);

    for (int i=0; i<6; i++) {
      //int ifreq=(i+1)*100;
      cp5.addSlider("BB"+i+"/LO")
        .setGroup(group_broadband_settings)
        .setSize(sx, sy)
        .setPosition(px, py+=oy+10)
        .setRange(0, 5000)
        .setValue(0.0)
        .setColorForeground(BRED)
        .setColorBackground(RED)
        .plugTo(rosettePlot, "setLowerFreq"+i);

      cp5.addSlider("BB"+i+"/HI")
        .setGroup(group_broadband_settings)
        .setSize(sx, sy)
        .setPosition(px+100, py)
        .setRange(0, 5000)
        .setValue(0.0)
        .setColorForeground(BGREEN)
        .setColorBackground(GREEN)
        .plugTo(rosettePlot, "setUpperFreq"+i);
    }
  }

  ////////////////////////////////////////////////////////////////////////////
  // GUI - DISPLAY SETTINGS
  ////////////////////////////////////////////////////////////////////////////
  Group group_display_settings = cp5.addGroup("Display Settings");
  {
    group_display_settings.setHeight(20)
      .setSize(gui_w, 25)
      .setBackgroundColor(color(16, 180))
      .setColorBackground(color(16, 180));

    group_display_settings.getCaptionLabel().align(LEFT, CENTER);

    sx = 50;
    sy = 14;
    px = 10; 
    py = 15;
    oy = (int)(sy*1.4f);

    cp5.addRadioButton("radiobuttons")
      .setGroup(group_display_settings)
      .setSize(sy, sy)
      .setPosition(px, py+=oy+10)
      .setItemsPerRow(1)
      .setSpacingColumn(3)
      .setSpacingRow(3)
      .addItem("BB Mode", 0)      
      .addItem("NB Mode", 1)
      .activate(BB_MODE ? 0 : 2);

    cp5.addSlider("BACKGROUND")
      .setGroup(group_display_settings)
      .setSize(sx, sy)
      .setPosition(px, py+=oy+sy)
      .setRange(0, 255)
      .setValue(BACKGROUND_COLOR)
      .plugTo(this, "BACKGROUND_COLOR");
  }


  ////////////////////////////////////////////////////////////////////////////
  // GUI - ACCORDION
  ////////////////////////////////////////////////////////////////////////////
  cp5.addAccordion("acc")
    .setPosition(gui_x, gui_y).setWidth(gui_w).setSize(gui_w, viewport_h)
    .setCollapseMode(Accordion.MULTI)
    .addItem(group_display_settings)
    .addItem(group_narrowband_settings)    
    .addItem(group_broadband_settings);
}


////////////////////////////////////////////////////////////////////////////
// GENERATE Fake BeamNoise
////////////////////////////////////////////////////////////////////////////
void getLevels() {
  for (int itrace=0; itrace<NTRACES; itrace++) {
    for (int ilevel=0; ilevel<NBEAMS; ilevel++) {
      float level = 50+ random(50)+10*itrace;
      traces[itrace][ilevel]=level;
    }
  }
}
