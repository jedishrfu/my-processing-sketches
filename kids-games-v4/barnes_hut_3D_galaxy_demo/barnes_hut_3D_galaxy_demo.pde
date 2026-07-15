/**
 * 3D Barnes–Hut Galaxy Simulation with Octree Visualization
 * ---------------------------------------------------------
 * - True 3D BH octree
 * - Disk + bulge + halo galaxy
 * - Draws octree bounding cubes (grid) + COM spheres
 * - Orbit camera (mouse drag) + zoom (wheel)
 * - WASD + R/F to move camera target
 * - Press 'R' to toggle frame recording (PNG sequence)
 * - Press 'G' to toggle grid (octree cubes)
 * - Press 'C' to toggle COM spheres
 * - Press 'X' to toggle axes
 */

import processing.event.*;

// ----------------- Simulation parameters -----------------
int   N_STARS        = 2500;
float G              = 0.6;
float THETA          = 0.6;
float DT             = 0.4;
float SOFTENING      = 15.0;
float VELOCITY_DAMP  = 1.0;

Body3D[] bodies;
float BOX_SIZE = 6000;

// ----------------- Camera -----------------
float camYaw   = PI/4;
float camPitch = -PI/6;
float camDist  = 3500;
PVector camTarget = new PVector(0,0,0);

boolean dragging = false;
float lastMouseX, lastMouseY;

// ----------------- Visualization toggles -----------------
boolean showOctree = true;   // "grid lines" (bounding cubes)
boolean showCOM    = true;   // centers of mass
boolean showAxes   = true;   // coordinate axes

// ----------------- Recording -----------------
boolean recording = false;
int frameIndex = 0;

// ----------------- Root Octree -----------------
BHTree3D rootTree;

// ----------------- Setup -----------------
void setup() {
  size(700, 700, P3D);
  smooth(4);
  initGalaxy3D();

  hint(ENABLE_DEPTH_TEST);
  perspective(PI/3.0, float(width)/height, 10, 50000);
}

// ----------------- Draw -----------------
void draw() {
  background(0);

  updatePhysics();
  updateCamera();

  lights();
  directionalLight(200, 200, 200, -0.5, -1, -0.3);

  if (showAxes) {
    drawAxes();
  }

  // Draw stars
  strokeWeight(3);
  beginShape(POINTS);
  for (Body3D b : bodies) {
    float r = b.pos.mag();
    float speed = b.vel.mag();
    float hue = map(r, 0, 3000, 0, 255);
    float bri = map(speed, 0, 15, 150, 255);
    colorMode(HSB, 255);
    stroke(hue, 200, bri, 255);
    colorMode(RGB, 255);
    vertex(b.pos.x, b.pos.y, b.pos.z);
  }
  endShape();

  // Octree visualization
  if (rootTree != null) {
    if (showOctree) {
      rootTree.drawCubes();
    }
    if (showCOM) {
      rootTree.drawCOMs();
    }
  }

  // Recording
  if (recording) {
    saveFrame("frames/frame-" + nf(frameIndex++, 5) + ".png");
  }

  drawHUD();
}

// ----------------- HUD -----------------
void drawHUD() {
  hint(DISABLE_DEPTH_TEST);
  camera();  // reset to screen space
  noLights();

  fill(255);
  textSize(12);
  text("3D Barnes–Hut Galaxy   Stars: " + N_STARS, 10, 20);
  text("R: record frames | G: toggle grid (octree cubes) | C: toggle COM | X: toggle axes", 10, 40);
  text("Mouse drag: orbit | Wheel: zoom | WASD/RF: move target", 10, 60);
  text("Recording: " + recording, 10, 80);

  hint(ENABLE_DEPTH_TEST);
}

// ----------------- Axes -----------------
void drawAxes() {
  pushMatrix();
  strokeWeight(2);
  stroke(255, 0, 0);
  line(0,0,0, 200,0,0);
  stroke(0,255,0);
  line(0,0,0, 0,200,0);
  stroke(0,0,255);
  line(0,0,0, 0,0,200);
  popMatrix();
}

// ----------------- Camera control -----------------
void updateCamera() {
  PVector forward = new PVector(
    cos(camPitch)*cos(camYaw),
    sin(camPitch),
    cos(camPitch)*sin(camYaw)
  ).normalize();

  PVector eye = PVector.sub(camTarget, PVector.mult(forward, camDist));
  camera(eye.x, eye.y, eye.z, camTarget.x, camTarget.y, camTarget.z, 0, 1, 0);
}

void keyPressed() {
  // Toggles
  if (key == 'r' || key == 'R') {
    recording = !recording;
    return;
  }
  if (key == 'g' || key == 'G') {
    showOctree = !showOctree;
    return;
  }
  if (key == 'c' || key == 'C') {
    showCOM = !showCOM;
    return;
  }
  if (key == 'x' || key == 'X') {
    showAxes = !showAxes;
    return;
  }

  // Camera motion
  float speed = 80;
  PVector forward = new PVector(
    cos(camPitch)*cos(camYaw),
    sin(camPitch),
    cos(camPitch)*sin(camYaw)
  ).normalize();
  PVector worldUp = new PVector(0,1,0);
  PVector right = forward.cross(worldUp).normalize();

  if (key == 'w' || key == 'W') camTarget.add(PVector.mult(forward, speed));
  if (key == 's' || key == 'S') camTarget.sub(PVector.mult(forward, speed));
  if (key == 'a' || key == 'A') camTarget.sub(PVector.mult(right, speed));
  if (key == 'd' || key == 'D') camTarget.add(PVector.mult(right, speed));
  if (key == 'f')             camTarget.sub(PVector.mult(worldUp, speed));
  if (key == 't')             camTarget.add(PVector.mult(worldUp, speed));
}

void mousePressed() {
  if (mouseButton == LEFT) {
    dragging = true;
    lastMouseX = mouseX;
    lastMouseY = mouseY;
  }
}

void mouseDragged() {
  if (dragging) {
    float dx = mouseX - lastMouseX;
    float dy = mouseY - lastMouseY;
    camYaw   += dx * 0.01;
    camPitch += dy * 0.01;
    camPitch = constrain(camPitch, -PI/2 + 0.1, PI/2 - 0.1);
    lastMouseX = mouseX;
    lastMouseY = mouseY;
  }
}

void mouseReleased() {
  dragging = false;
}

void mouseWheel(MouseEvent e) {
  camDist *= 1 + e.getCount() * 0.05;
  camDist = constrain(camDist, 800, 8000);
}

// ----------------- Physics update -----------------
void updatePhysics() {
  Cube rootCube = new Cube(new PVector(0,0,0), BOX_SIZE);
  rootTree = new BHTree3D(rootCube, 0);

  for (Body3D b : bodies) {
    if (rootCube.contains(b.pos)) {
      rootTree.insert(b);
    }
  }

  for (Body3D b : bodies) {
    b.resetForce();
    rootTree.updateForce(b);
  }
  for (Body3D b : bodies) {
    b.update(DT);
  }
}

// ----------------- Galaxy initialization -----------------
void initGalaxy3D() {
  bodies = new Body3D[N_STARS];

  float diskR = 2500;
  float diskH = 200;
  float bulgeR = 500;
  float haloR  = 3500;

  int nDisk  = int(N_STARS * 0.7);
  int nBulge = int(N_STARS * 0.2);
  int nHalo  = N_STARS - nDisk - nBulge;

  int idx = 0;

  // Disk
  for (int i = 0; i < nDisk; i++) {
    float u = random(1);
    float r = sqrt(u) * diskR;
    float a = random(TWO_PI);

    float x = r * cos(a);
    float z = r * sin(a);
    float y = randomGaussian() * diskH * 0.2;

    float v = 0.9 * sqrt(r / diskR + 0.02) * 25;
    float vx = -sin(a) * v + random(-5, 5);
    float vy = random(-3, 3);
    float vz =  cos(a) * v + random(-5, 5);

    bodies[idx++] = new Body3D(new PVector(x, y, z),
                               new PVector(vx, vy, vz),
                               1.0);
  }

  // Bulge
  for (int i = 0; i < nBulge; i++) {
    float r   = pow(random(1), 0.3) * bulgeR;
    float th  = random(TWO_PI);
    float phi = acos(random(-1, 1));

    float x = r * sin(phi) * cos(th);
    float y = r * cos(phi);
    float z = r * sin(phi) * sin(th);

    PVector vel = new PVector(random(-30, 30),
                              random(-30, 30),
                              random(-30, 30));

    bodies[idx++] = new Body3D(new PVector(x, y, z), vel, 2.0);
  }

  // Halo
  for (int i = 0; i < nHalo; i++) {
    float r   = pow(random(1), 0.5) * haloR + diskR;
    float th  = random(TWO_PI);
    float phi = acos(random(-1, 1));

    float x = r * sin(phi) * cos(th);
    float y = r * cos(phi);
    float z = r * sin(phi) * sin(th);

    PVector vel = new PVector(random(-20, 20),
                              random(-20, 20),
                              random(-20, 20));

    bodies[idx++] = new Body3D(new PVector(x, y, z), vel, 0.5);
  }
}

// ----------------- Classes -----------------
class Body3D {
  PVector pos, vel, force;
  float mass;

  // Main constructor
  Body3D(PVector p, PVector v, float m) {
    pos = p.copy();
    vel = v.copy();
    mass = m;
    force = new PVector();
  }

  // Convenience constructor: zero velocity
  Body3D(PVector p, float m) {
    this(p, new PVector(0, 0, 0), m);
  }

  void resetForce() {
    force.set(0, 0, 0);
  }

  void addForce(Body3D o) {
    PVector d = PVector.sub(o.pos, pos);
    float distSq = d.magSq() + SOFTENING * SOFTENING;
    float dist   = sqrt(distSq);
    if (dist == 0) return;

    float F = (G * mass * o.mass) / distSq;
    d.mult(F / dist);
    force.add(d);
  }

  void update(float dt) {
    PVector acc = PVector.div(force, mass);
    vel.add(PVector.mult(acc, dt));
    vel.mult(VELOCITY_DAMP);
    pos.add(PVector.mult(vel, dt));
  }
}

class Cube {
  PVector center;
  float size;

  Cube(PVector c, float s) {
    center = c.copy();
    size   = s;
  }

  boolean contains(PVector p) {
    float h = size * 0.5;
    return (p.x >= center.x - h && p.x <= center.x + h &&
            p.y >= center.y - h && p.y <= center.y + h &&
            p.z >= center.z - h && p.z <= center.z + h);
  }

  Cube childCube(int i) {
    float q = size * 0.25;
    float h = size * 0.5;

    float x = center.x + (((i & 1) == 0) ? -q : q);
    float y = center.y + (((i & 2) == 0) ? -q : q);
    float z = center.z + (((i & 4) == 0) ? -q : q);

    return new Cube(new PVector(x, y, z), h);
  }
}

class BHTree3D {
  Cube cube;
  Body3D body;
  BHTree3D[] kids = new BHTree3D[8];
  int depth;

  BHTree3D(Cube c, int d) {
    cube = c;
    depth = d;
  }

  boolean isLeaf() {
    for (BHTree3D k : kids) if (k != null) return false;
    return true;
  }

  void insert(Body3D b) {
    if (body == null && isLeaf()) {
      body = b;
      return;
    }

    if (isLeaf()) {
      subdivide();
      insertIntoChild(body);
      insertIntoChild(b);
      body = combine(body, b);
    } else {
      insertIntoChild(b);
      body = combine(body, b);
    }
  }

  void subdivide() {
    // children created lazily in insertIntoChild
  }

  void insertIntoChild(Body3D b) {
    int i = idx(b.pos);
    if (kids[i] == null) {
      kids[i] = new BHTree3D(cube.childCube(i), depth + 1);
    }
    kids[i].insert(b);
  }

  int idx(PVector p) {
    int i = 0;
    if (p.x >= cube.center.x) i |= 1;
    if (p.y >= cube.center.y) i |= 2;
    if (p.z >= cube.center.z) i |= 4;
    return i;
  }

  Body3D combine(Body3D a, Body3D b) {
    float m = a.mass + b.mass;
    if (m == 0) return new Body3D(a.pos, 0);
    PVector pos = PVector.add(
      PVector.mult(a.pos, a.mass),
      PVector.mult(b.pos, b.mass)
    ).div(m);
    return new Body3D(pos, m);
  }

  void updateForce(Body3D b) {
    if (body == null) return;

    if (isLeaf()) {
      if (body != b) b.addForce(body);
      return;
    }

    float s = cube.size;
    PVector d = PVector.sub(body.pos, b.pos);
    float dist = sqrt(d.magSq() + SOFTENING * SOFTENING);

    if ((s / dist) < THETA) {
      if (body != b) b.addForce(body);
    } else {
      for (BHTree3D k : kids) if (k != null) k.updateForce(b);
    }
  }

  // Draw octree cubes (grid lines)
  void drawCubes() {
    if (body == null) return;

    float shade = map(depth, 0, 10, 220, 120);
    stroke(shade + 10, shade - 5, shade - 20, 70);
    strokeWeight(1);
    noFill();

    pushMatrix();
    translate(cube.center.x, cube.center.y, cube.center.z);
    box(cube.size);
    popMatrix();

    for (BHTree3D k : kids) if (k != null) k.drawCubes();
  }

  // Draw COM spheres
  void drawCOMs() {
    if (body == null) return;

    float shade = map(depth, 0, 10, 240, 150);
    fill(shade + 20, shade - 10, shade - 30, 255);
    noStroke();

    float r = max(1, 6 - depth * 0.4);

    pushMatrix();
    translate(body.pos.x, body.pos.y, body.pos.z);
    sphere(r);
    popMatrix();

    for (BHTree3D k : kids) if (k != null) k.drawCOMs();
  }
}
