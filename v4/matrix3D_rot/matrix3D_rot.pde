int nPoints = 20;

int xDim = 700;
int yDim = 700;
int zDim = 700;

float starDiameter = 14;

Point3D[] pt = new Point3D[nPoints];

int selectedIndex = 0;

float rotX = -0.45;
float rotY = 0.65;
float zoom = 0.95;

boolean showLines = false;
boolean showAxes = true;

float maxDistInSet = 1;

void setup() {
  size(1000, 800, P3D);
  textSize(14);
  smooth(8);
  generatePoints();
}

void draw() {
  background(140);
  lights();

  pushMatrix();
  translate(width / 2.0, height / 2.0 - 20, 0);
  scale(zoom);
  rotateX(rotX);
  rotateY(rotY);

  if (showAxes) {
    drawAxesAndBox();
  }

  if (showLines) {
    drawConnectingLines();
  }

  drawStars3D();
  popMatrix();

  drawOverlay();
}

void generatePoints() {
  for (int i = 0; i < nPoints; i++) {
    float x = random(-xDim / 2.0, xDim / 2.0);
    float y = random(-yDim / 2.0, yDim / 2.0);
    float z = random(-zDim / 2.0, zDim / 2.0);
    pt[i] = new Point3D(x, y, z);
  }
  setOrigin(0);
  printSelectedStarDetails();
  printSortedDistances();
}

void drawAxesAndBox() {
  strokeWeight(2);

  stroke(255, 0, 0);
  line(0, 0, 0, 180, 0, 0);

  stroke(0, 255, 0);
  line(0, 0, 0, 0, 180, 0);

  stroke(0, 120, 255);
  line(0, 0, 0, 0, 0, 180);

  strokeWeight(1);
  stroke(70);
  noFill();
  box(xDim, yDim, zDim);
}

void drawConnectingLines() {
  stroke(80, 120);
  strokeWeight(1);

  for (int i = 0; i < nPoints; i++) {
    for (int j = i + 1; j < nPoints; j++) {
      float d = dist3D(pt[i], pt[j]);
      if (d < 220) {
        line(pt[i].x, pt[i].y, pt[i].z, pt[j].x, pt[j].y, pt[j].z);
      }
    }
  }
}

void drawStars3D() {
  sphereDetail(10);

  for (int i = 0; i < nPoints; i++) {
    Point3D p = pt[i];

    color c;
    if (i == selectedIndex) {
      c = color(255);  // selected origin always white
    } else {
      c = gradientColorLinearRedToBlue(p.distNorm);
    }

    pushMatrix();
    translate(p.x, p.y, p.z);

    if (i == selectedIndex) {
      stroke(255);
      strokeWeight(3);
      fill(c);
      sphere(starDiameter);

      noFill();
      stroke(255);
      strokeWeight(2);
      sphere(starDiameter + 4);
    } else {
      stroke(0);
      strokeWeight(1);
      fill(c);
      sphere(starDiameter);
    }

    popMatrix();
  }
}

color gradientColorLinearRedToBlue(float t) {
  t = constrain(t, 0, 1);
  color cNear = color(255, 0, 0); // red = closest
  color cFar  = color(0, 0, 255); // blue = farthest
  return lerpColor(cNear, cFar, t);
}

void drawOverlay() {
  hint(DISABLE_DEPTH_TEST);

  fill(0, 185);
  noStroke();
  rect(0, height - 135, width, 135);

  Point3D s = pt[selectedIndex];

  fill(255);
  textAlign(LEFT, TOP);
  text("Drag = rotate    Wheel = zoom    Click = select new origin star", 10, height - 127);
  text("Keys: c lines   a axes   r reset   n new stars   +/- zoom", 10, height - 107);

  text("Origin star: " + selectedIndex + " (white)", 10, height - 79);
  text("x = " + nf(s.x, 0, 1) + "    y = " + nf(s.y, 0, 1) + "    z = " + nf(s.z, 0, 1), 10, height - 59);
  text("Color scale: red = closer to origin, blue = farther from origin", 10, height - 39);
  text("Selection details print to the console", 10, height - 19);

  drawGradientLegend();

  hint(ENABLE_DEPTH_TEST);
}

void drawGradientLegend() {
  float gx = width - 240;
  float gy = height - 40;
  float gw = 200;
  float gh = 12;

  noStroke();
  for (int i = 0; i < gw; i++) {
    float t = i / (gw - 1.0);
    fill(gradientColorLinearRedToBlue(t));
    rect(gx + i, gy, 1, gh);
  }

  stroke(255);
  noFill();
  rect(gx, gy, gw, gh);

  fill(255);
  textAlign(LEFT, BOTTOM);
  text("red near", gx, gy - 2);
  textAlign(RIGHT, BOTTOM);
  text("blue far", gx + gw, gy - 2);
}

void mouseDragged() {
  rotY += (mouseX - pmouseX) * 0.01;
  rotX -= (mouseY - pmouseY) * 0.01;
}

void mousePressed() {
  int clicked = findProjectedPointUnderMouse();
  if (clicked != -1) {
    setOrigin(clicked);
    printSelectedStarDetails();
    printSortedDistances();
  }
}

void mouseWheel(processing.event.MouseEvent event) {
  float e = event.getCount();
  zoom *= pow(0.92, e);
  zoom = constrain(zoom, 0.25, 4.0);
}

int findProjectedPointUnderMouse() {
  float bestDist = 20;
  int bestIndex = -1;

  pushMatrix();
  translate(width / 2.0, height / 2.0 - 20, 0);
  scale(zoom);
  rotateX(rotX);
  rotateY(rotY);

  for (int i = 0; i < nPoints; i++) {
    Point3D p = pt[i];
    float sx = screenX(p.x, p.y, p.z);
    float sy = screenY(p.x, p.y, p.z);
    float d = dist(mouseX, mouseY, sx, sy);

    if (d < bestDist) {
      bestDist = d;
      bestIndex = i;
    }
  }

  popMatrix();
  return bestIndex;
}

void setOrigin(int index) {
  selectedIndex = index;
  updateDistancesAndColors();
}

void updateDistancesAndColors() {
  Point3D origin = pt[selectedIndex];
  maxDistInSet = 0;

  for (int i = 0; i < nPoints; i++) {
    float d = dist3D(pt[i], origin);
    pt[i].distFromOrigin = d;

    if (i != selectedIndex && d > maxDistInSet) {
      maxDistInSet = d;
    }
  }

  if (maxDistInSet <= 0) {
    maxDistInSet = 1;
  }

  for (int i = 0; i < nPoints; i++) {
    if (i == selectedIndex) {
      pt[i].distNorm = 0;
    } else {
      pt[i].distNorm = constrain(pt[i].distFromOrigin / maxDistInSet, 0, 1);
    }
  }
}

float dist3D(Point3D a, Point3D b) {
  float dx = a.x - b.x;
  float dy = a.y - b.y;
  float dz = a.z - b.z;
  return sqrt(dx * dx + dy * dy + dz * dz);
}

void printSelectedStarDetails() {
  Point3D s = pt[selectedIndex];

  println();
  println("==================================================");
  println("Selected origin star: " + selectedIndex);
  println("Coordinates: (" + nf(s.x, 0, 2) + ", " + nf(s.y, 0, 2) + ", " + nf(s.z, 0, 2) + ")");
  println("==================================================");
}

void printSortedDistances() {
  float[] d = new float[nPoints];
  int[] idx = new int[nPoints];

  for (int i = 0; i < nPoints; i++) {
    d[i] = pt[i].distFromOrigin;
    idx[i] = i;
  }

  for (int i = 0; i < nPoints - 1; i++) {
    for (int j = i + 1; j < nPoints; j++) {
      if (d[j] < d[i]) {
        float td = d[i];
        d[i] = d[j];
        d[j] = td;

        int ti = idx[i];
        idx[i] = idx[j];
        idx[j] = ti;
      }
    }
  }

  println("Distances from origin star " + selectedIndex + ":");
  for (int i = 0; i < nPoints; i++) {
    println(
      "rank " + i +
      " -> star " + idx[i] +
      "   d = " + nf(d[i], 0, 2) +
      "   xyz = (" +
      nf(pt[idx[i]].x, 0, 2) + ", " +
      nf(pt[idx[i]].y, 0, 2) + ", " +
      nf(pt[idx[i]].z, 0, 2) + ")"
    );
  }
  println();
}

void keyPressed() {
  if (key == 'c' || key == 'C') {
    showLines = !showLines;
  } else if (key == 'a' || key == 'A') {
    showAxes = !showAxes;
  } else if (key == 'r' || key == 'R') {
    rotX = -0.45;
    rotY = 0.65;
    zoom = 0.95;
  } else if (key == 'n' || key == 'N') {
    generatePoints();
  } else if (key == '+' || key == '=') {
    zoom *= 1.1;
    zoom = constrain(zoom, 0.25, 4.0);
  } else if (key == '-') {
    zoom /= 1.1;
    zoom = constrain(zoom, 0.25, 4.0);
  }
}

class Point3D {
  float x, y, z;
  float distFromOrigin;
  float distNorm;

  Point3D(float x, float y, float z) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.distFromOrigin = 0;
    this.distNorm = 0;
  }
}
