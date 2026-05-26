/*
 * Open Source Physics software is free software as described near the bottom of this code file.
 *
 * For additional information and documentation on Open Source Physics please see: 
 * <http://www.opensourcephysics.org/>
 *
 * Open Source Physics software is free software; you can redistribute
 * it and/or modify it under the terms of the GNU General Public License (GPL) as
 * published by the Free Software Foundation; either version 2 of the License,
 * or(at your option) any later version.
 *
 * Code that uses any portion of the code in the org.opensourcephysics package
 * or any subpackage (subdirectory) of this package must must also be be released
 * under the GNU GPL license.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston MA 02111-1307 USA
 * or view the license online at http://www.gnu.org/copyleft/gpl.html
 *
 * Copyright (c) 2007  The Open Source Physics project
 *                     http://www.opensourcephysics.org
 */

/**
 * Processing port of the OSP GalaxyApp (Schulman–Seiden galaxy percolation model).
 */

final float TWO_PI_OVER_6 = TWO_PI / 6.0;

// Model params
int   numberOfRings              = 50;
int   initialNumberOfActiveCells = 200;
float p                          = 0.18;
float v                          = 1.0;
float dt                         = 10.0;

// State
float t = 0;
int numberOfCells;
int numberOfActiveCells;

int[] starLifeTime;
int[] cellR;
int[] cellA;
int[] activeCellLabel;

// Display scaling
float scaleFactor;

// ==== Frame-rate control ====
float userFPS = 15;        // safer default than 30
boolean draggingSlider = false;
float sliderX, sliderY, sliderW, sliderH;

void setup() {
  size(700, 700);
  smooth();

  // slider geometry
  sliderW = 200;
  sliderH = 16;
  sliderX = 20;
  sliderY = height - 40;

  frameRate(userFPS);
  initializeModel();
}

void draw() {
  background(0);

  // ---- Simulation step ----
  t += dt;
  formNewStars();

  noStroke();
  fill(255, 255, 0);

  for (int label = 0; label < numberOfCells; label++) {
    if (starLifeTime[label] > 0) {
      int r = cellR[label];
      int a = cellA[label];

      float angle = TWO_PI_OVER_6 * a / (float) r + (v * t) / (float) r;
      float x = r * cos(angle);
      float y = r * sin(angle);
      float ds = starLifeTime[label] / 15.0;

      float sx = width * 0.5 + x * scaleFactor;
      float sy = height * 0.5 - y * scaleFactor;

      float sizePix = max(2, ds * scaleFactor * 0.6);
      ellipse(sx, sy, sizePix, sizePix);

      starLifeTime[label]--;
    }
  }

  // ---- HUD ----
  fill(255);
  textAlign(LEFT, TOP);
  text("t = " + nf(t, 1, 1) + "    #active = " + numberOfActiveCells, 10, 10);

  drawFPSControl();
}

// ------------------ Slider UI ------------------

void drawFPSControl() {
  fill(255);
  text("Frame rate", sliderX, sliderY - 18);

  // slider background
  fill(80);
  rect(sliderX, sliderY, sliderW, sliderH, 4);

  // handle position
  float handleX = sliderX + map(userFPS, 1, 60, 0, sliderW);

  fill(220);
  rect(handleX - 5, sliderY - 4, 10, sliderH + 8, 4);

  fill(255);
  text(nf(userFPS, 1, 1) + " fps", sliderX + sliderW + 20, sliderY - 2);
}

void mousePressed() {
  if (mouseY > sliderY - 5 && mouseY < sliderY + sliderH + 5 &&
      mouseX > sliderX && mouseX < sliderX + sliderW) {
    draggingSlider = true;
    updateFPSFromMouse();
  }
}

void mouseDragged() {
  if (draggingSlider) {
    updateFPSFromMouse();
  }
}

void mouseReleased() {
  draggingSlider = false;
}

void updateFPSFromMouse() {
  float pos = constrain(mouseX, sliderX, sliderX + sliderW);
  userFPS = map(pos - sliderX, 0, sliderW, 1, 60);
  frameRate(userFPS);
}

// ------------------ Keyboard control ------------------
void keyPressed() {
  if (key == '[') {
    userFPS = max(1, userFPS - 2);
    frameRate(userFPS);
  } 
  else if (key == ']') {
    userFPS = min(60, userFPS + 2);
    frameRate(userFPS);
  } 
  else if (key == 'r' || key == 'R') {
    initializeModel();
  }
}

// ------------------ Model code unchanged ------------------

void initializeModel() {
  t = 0;

  numberOfCells = 3 * numberOfRings * (numberOfRings + 1);

  cellR = new int[numberOfCells];
  cellA = new int[numberOfCells];
  starLifeTime = new int[numberOfCells];
  activeCellLabel = new int[numberOfCells];

  int cellLabel = 0;

  for (int r = 1; r <= numberOfRings; r++) {
    for (int a = 0; a < r * 6; a++) {
      cellR[cellLabel] = r;
      cellA[cellLabel] = a;
      cellLabel++;
    }
  }

  numberOfActiveCells = initialNumberOfActiveCells;

  for (int i = 0; i < numberOfCells; i++) {
    starLifeTime[i] = 0;
  }
  initializeGalaxy();

  scaleFactor = min(width, height) / (2.0 * (numberOfRings + 1.0));
}

void initializeGalaxy() {
  int i = 0;
  while (i < initialNumberOfActiveCells) {
    int label = (int)(random(numberOfCells));
    if (starLifeTime[label] != 15) {
      starLifeTime[label] = 15;
      activeCellLabel[i] = label;
      i++;
    }
  }
}

void formNewStars() {
  int[] current = activeCellLabel.clone();
  int currentN = numberOfActiveCells;
  numberOfActiveCells = 0;

  for (int i = 0; i < currentN; i++) {
    int label = current[i];
    int r = cellR[label];
    int a = cellA[label];

    createStars(r, pbc(a + 1, r));
    createStars(r, pbc(a - 1, r));

    if (r < numberOfRings - 1) {
      int ap = aForOtherRadius(a, r, r + 1);
      createStars(r + 1, pbc(ap, r + 1));
      createStars(r + 1, pbc(ap + 1, r + 1));
    }

    if (r > 1) {
      int am = aForOtherRadius(a, r, r - 1);
      createStars(r - 1, pbc(am, r - 1));
      createStars(r - 1, pbc(am + 1, r - 1));
    }
  }
}

int pbc(int a, int r) {
  int m = 6 * r;
  return (a % m + m) % m;
}

int aForOtherRadius(int a, int r, int rOther) {
  float angle = TWO_PI_OVER_6 * a / (float) r + (v * t) / (float) r;
  angle -= TWO_PI * (int)(angle / TWO_PI);

  float angleChange = (v * t) / (float) rOther;
  angleChange -= TWO_PI * (int)(angleChange / TWO_PI);

  return (int)((rOther / TWO_PI_OVER_6) * (angle - angleChange));
}

void createStars(int r, int a) {
  int label = a + 3 * r * (r - 1);
  if (random(1) < p && starLifeTime[label] != 15) {
    activeCellLabel[numberOfActiveCells] = label;
    numberOfActiveCells++;
    starLifeTime[label] = 15;
  }
}
