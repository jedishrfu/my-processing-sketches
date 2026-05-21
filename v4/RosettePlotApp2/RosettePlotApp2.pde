import controlP5.*;

int NTRACES = 6;
int NBEAMS = 36;

float[][] traces = new float[NTRACES][NBEAMS];

int gui_w = 200;
int gui_x = 20;
int gui_y = 20;

int BACKGROUND_COLOR = 255;

ControlP5 cp5;
RosettePlot rosettePlot;

void settings() {
  size(600, 480);
}

void setup() {
  rosettePlot = new RosettePlot(250, 20, 300, 420, 200);
  createGUI();
  getLevels();
}

void draw() {
  if (frameCount % 100 == 0) {
    getLevels();
  }

  background(BACKGROUND_COLOR);
  rosettePlot.draw(traces);
}

void createGUI() {
  cp5 = new ControlP5(this);

  int sx = 50;
  int sy = 14;
  int px = 10;
  int py = 0;
  int oy = int(sy * 1.4);

  Group group_narrowband_settings = cp5.addGroup("Narrow Band Traces");

  group_narrowband_settings
    .setHeight(20)
    .setSize(gui_w, 230)
    .setBackgroundColor(color(16, 180))
    .setColorBackground(color(16, 180));

  group_narrowband_settings.getCaptionLabel().align(LEFT, CENTER);

  for (int i = 0; i < NTRACES; i++) {
    int ifreq = (i + 1) * 100;

    cp5.addToggle("TRACE " + ifreq)
      .setGroup(group_narrowband_settings)
      .setSize(sx, sy)
      .setPosition(px, py += oy + 10)
      .setValue(true)
      .plugTo(rosettePlot, "setTrace" + i);
  }

  Group group_display_settings = cp5.addGroup("Display Settings");

  group_display_settings
    .setHeight(20)
    .setSize(gui_w, 80)
    .setBackgroundColor(color(16, 180))
    .setColorBackground(color(16, 180));

  group_display_settings.getCaptionLabel().align(LEFT, CENTER);

  px = 10;
  py = 15;

  cp5.addSlider("BACKGROUND")
    .setGroup(group_display_settings)
    .setSize(100, sy)
    .setPosition(px, py)
    .setRange(0, 255)
    .setValue(BACKGROUND_COLOR)
    .plugTo(this, "BACKGROUND_COLOR");

  cp5.addAccordion("acc")
    .setPosition(gui_x, gui_y)
    .setWidth(gui_w)
    .setCollapseMode(Accordion.MULTI)
    .addItem(group_display_settings)
    .addItem(group_narrowband_settings);
}

void getLevels() {
  for (int itrace = 0; itrace < NTRACES; itrace++) {
    for (int ilevel = 0; ilevel < NBEAMS; ilevel++) {
      float level = 50 + random(50) + 10 * itrace;
      traces[itrace][ilevel] = level;
    }
  }
}
