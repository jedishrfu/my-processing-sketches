int nPoints = 1000;

int xDim = 1200;
int yDim = 700;
int zDim = 800;
int z10 = zDim / 10;

int rCircle = 10;
float radius = rCircle / 2.0;

Point3D[] pt = new Point3D[nPoints];

int tx, ty, tz;
int selectedIndex = 0;

int nColors = 9;

color[] colorTable = {
  color(255),         // white
  color(255, 0, 0),   // red
  color(255, 255, 0), // yellow
  color(0, 255, 0),   // green
  color(0, 0, 255),   // blue
  color(255, 0, 255), // magenta
  color(192),         // light gray
  color(128),         // gray
  color(0)            // black
};

void setup() {
  size(1200, 700);
  textSize(12);

  for (int i = 0; i < nPoints; i++) {
    int x = (int)random(xDim - rCircle);
    int y = (int)random(yDim - rCircle);
    int z = (int)random(zDim);

    pt[i] = new Point3D(x, y, z);
  }

  setTarget(0);
}

void draw() {
  background(128);

  for (int i = 0; i < nPoints; i++) {
    Point3D p = pt[i];

    if (i == selectedIndex) {
      stroke(255);
      strokeWeight(3);
    } else {
      stroke(0);
      strokeWeight(1);
    }

    fill(colorTable[p.ci]);
    ellipse(p.x, p.y, rCircle, rCircle);

    fill(0);
    //text(i + "  z=" + p.z, p.x + 12, p.y + 4);
  }

  fill(0);
  noStroke();
  rect(0, height - 24, width, 24);

  fill(255);
  //text("Selected point: " + selectedIndex + "   target z = " + tz, 10, height - 8);
}

void mousePressed() {
  int clicked = findPointUnderMouse();

  if (clicked != -1) {
    setTarget(clicked);
    println("pt[" + clicked + "]=(" + pt[clicked].x + "," + pt[clicked].y + "," + pt[clicked].z + "," + pt[clicked].ci + ")");
  }
}

int findPointUnderMouse() {
  for (int i = 0; i < nPoints; i++) {
    float d = dist(mouseX, mouseY, pt[i].x, pt[i].y);
    if (d <= radius) {
      return i;
    }
  }
  return -1;
}

void setTarget(int index) {
  selectedIndex = index;
  tx = pt[index].x;
  ty = pt[index].y;
  tz = pt[index].z;

  updateColors();

  for (int i = 0; i < nPoints; i++) {
    println("pt[" + i + "]=(" + pt[i].x + "," + pt[i].y + "," + pt[i].z + "," + pt[i].ci + ")");
  }
  println();
}

void updateColors() {
  for (int i = 0; i < nPoints; i++) {
    int distZ = abs(pt[i].z - tz);
    int ci = (distZ / z10) % nColors;
    pt[i].ci = ci;
  }
}

class Point3D {
  int x, y, z;
  int ci;

  Point3D(int x, int y, int z) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.ci = 0;
  }
}
