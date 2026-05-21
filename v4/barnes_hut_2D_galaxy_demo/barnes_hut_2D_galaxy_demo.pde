// Galaxy simulation with Barnes-Hut (2D quadtree) in Processing
// ~2000 stars in a rotating galaxy disk, with quadtree visualization.
//
// Press 'Q' to toggle drawing the quadtree bounding boxes
// and centers of mass.

int N_STARS = 2000;       // number of bodies
float G = 0.5;            // gravitational constant (tweak for different behavior)
float THETA = 0.6;        // Barnes-Hut opening angle (smaller = more accurate, slower)
float DT = 0.5;           // time step
float SOFTENING = 5.0;    // softening length to reduce singularities
float VELOCITY_DAMP = 1.0; // e.g. 0.999 for a bit of damping

Body[] bodies;
boolean showQuadtree = true;  // toggle with 'Q'

void setup() {
  size(700, 700);
  smooth(4);
  initGalaxy();
}

void draw() {
  background(0);
  
  // Build Barnes-Hut tree
  float L = max(width, height);
  Quad rootQuad = new Quad(width * 0.5, height * 0.5, L);
  BHTree tree = new BHTree(rootQuad, 0);  // depth = 0 for root
  
  // Insert bodies into tree
  for (int i = 0; i < bodies.length; i++) {
    Body b = bodies[i];
    if (rootQuad.contains(b.x, b.y)) {
      tree.insert(b);
    }
  }
  
  // Compute forces and update bodies
  for (int i = 0; i < bodies.length; i++) {
    Body b = bodies[i];
    b.resetForce();
    tree.updateForce(b);
  }
  
  for (int i = 0; i < bodies.length; i++) {
    bodies[i].update(DT);
  }
  
  // Draw bodies
  noStroke();
  for (int i = 0; i < bodies.length; i++) {
    Body b = bodies[i];
    
    // Color by radius / speed for nice effect
    float dx = b.x - width * 0.5;
    float dy = b.y - height * 0.5;
    float r = sqrt(dx*dx + dy*dy);
    float speed = sqrt(b.vx*b.vx + b.vy*b.vy);
    
    float hue = map(r, 0, width * 0.5, 0, 255);
    float bri = map(speed, 0, 5, 120, 255);
    
    colorMode(HSB, 255);
    fill(hue, 200, bri, 220);
    colorMode(RGB, 255);
    
    ellipse(b.x, b.y, 2, 2);
  }
  
  // Draw quadtree boxes and centers of mass on top
  if (showQuadtree) {
    tree.drawTree();
  }
}

void keyPressed() {
  if (key == 'q' || key == 'Q') {
    showQuadtree = !showQuadtree;
  }
}

// ----------------- Galaxy initialization -----------------
void initGalaxy() {
  bodies = new Body[N_STARS];
  
  float cx = width * 0.5;
  float cy = height * 0.5;
  float maxR = min(width, height) * 0.45;
  
  // Rotating disk galaxy
  for (int i = 0; i < N_STARS; i++) {
    // Radius with more density in center: r ~ sqrt(U)
    float u = random(1);
    float radius = sqrt(u) * maxR;
    float angle = random(TWO_PI);
    
    float x = cx + radius * cos(angle);
    float y = cy + radius * sin(angle);
    
    float mass = 1.0;
    
    // Rough circular orbit velocity
    float vMag = 2.0 * sqrt(radius / maxR + 0.01); // tweak factor
    float vx = -sin(angle) * vMag;
    float vy =  cos(angle) * vMag;
    
    // Small noise to break symmetry
    vx += random(-0.3, 0.3);
    vy += random(-0.3, 0.3);
    
    bodies[i] = new Body(x, y, vx, vy, mass);
  }
}

// ----------------- Classes: Body, Quad, BHTree -----------------

class Body {
  float x, y;   // position
  float vx, vy; // velocity
  float fx, fy; // force accumulator
  float mass;
  
  Body(float x, float y, float vx, float vy, float mass) {
    this.x = x;
    this.y = y;
    this.vx = vx;
    this.vy = vy;
    this.mass = mass;
    this.fx = 0;
    this.fy = 0;
  }
  
  // Constructor for a "center of mass" body (for tree internal nodes)
  Body(float x, float y, float mass) {
    this(x, y, 0, 0, mass);
  }
  
  void resetForce() {
    fx = 0;
    fy = 0;
  }
  
  void addForce(Body other) {
    float dx = other.x - this.x;
    float dy = other.y - this.y;
    
    float distSq = dx*dx + dy*dy + SOFTENING*SOFTENING;
    float dist = sqrt(distSq);
    
    if (dist == 0) return; // avoid self-force
    
    float F = (G * this.mass * other.mass) / distSq;
    float Fx = F * dx / dist;
    float Fy = F * dy / dist;
    
    fx += Fx;
    fy += Fy;
  }
  
  void update(float dt) {
    float ax = fx / mass;
    float ay = fy / mass;
    
    vx += ax * dt;
    vy += ay * dt;
    
    vx *= VELOCITY_DAMP;
    vy *= VELOCITY_DAMP;
    
    x += vx * dt;
    y += vy * dt;
  }
}

// Represents an axis-aligned square region (quadtree node region)
class Quad {
  float xMid;   // center x
  float yMid;   // center y
  float length; // side length of square
  
  Quad(float xMid, float yMid, float length) {
    this.xMid = xMid;
    this.yMid = yMid;
    this.length = length;
  }
  
  boolean contains(float x, float y) {
    return (x >= xMid - length*0.5 && x <= xMid + length*0.5 &&
            y >= yMid - length*0.5 && y <= yMid + length*0.5);
  }
  
  Quad nw() {
    return new Quad(xMid - length*0.25, yMid - length*0.25, length*0.5);
  }
  
  Quad ne() {
    return new Quad(xMid + length*0.25, yMid - length*0.25, length*0.5);
  }
  
  Quad sw() {
    return new Quad(xMid - length*0.25, yMid + length*0.25, length*0.5);
  }
  
  Quad se() {
    return new Quad(xMid + length*0.25, yMid + length*0.25, length*0.5);
  }
}

// Barnes-Hut tree (quadtree for 2D)
class BHTree {
  Quad quad;
  Body body;        // aggregate body for center-of-mass (for this node)
  BHTree nw, ne, sw, se;
  int depth;        // depth in the tree (root = 0)
  
  BHTree(Quad quad, int depth) {
    this.quad = quad;
    this.depth = depth;
    this.body = null;
  }
  
  boolean isExternal() {
    return (nw == null && ne == null && sw == null && se == null);
  }
  
  void insert(Body b) {
    if (body == null && isExternal()) {
      // Empty external node: just store the body
      body = b;
      return;
    }
    
    if (isExternal()) {
      // Subdivide and move existing body down, then insert new body
      subdivide();
      insertIntoChild(body);
      insertIntoChild(b);
      body = combineBodies(body, b);
    } else {
      // Internal node: update center of mass and delegate insertion
      insertIntoChild(b);
      body = combineBodies(body, b);
    }
  }
  
  void subdivide() {
    if (nw != null) return; // already subdivided
    nw = new BHTree(quad.nw(), depth + 1);
    ne = new BHTree(quad.ne(), depth + 1);
    sw = new BHTree(quad.sw(), depth + 1);
    se = new BHTree(quad.se(), depth + 1);
  }
  
  void insertIntoChild(Body b) {
    if (quad.nw().contains(b.x, b.y)) {
      if (nw == null) nw = new BHTree(quad.nw(), depth + 1);
      nw.insert(b);
    } else if (quad.ne().contains(b.x, b.y)) {
      if (ne == null) ne = new BHTree(quad.ne(), depth + 1);
      ne.insert(b);
    } else if (quad.sw().contains(b.x, b.y)) {
      if (sw == null) sw = new BHTree(quad.sw(), depth + 1);
      sw.insert(b);
    } else if (quad.se().contains(b.x, b.y)) {
      if (se == null) se = new BHTree(quad.se(), depth + 1);
      se.insert(b);
    } else {
      // Rare numerical edge cases: ignore
    }
  }
  
  // Combine two bodies to form center-of-mass body (for tree node)
  Body combineBodies(Body a, Body b) {
    float m = a.mass + b.mass;
    if (m == 0) return new Body(a.x, a.y, 0);
    
    float x = (a.x * a.mass + b.x * b.mass) / m;
    float y = (a.y * a.mass + b.y * b.mass) / m;
    return new Body(x, y, m);
  }
  
  void updateForce(Body b) {
    if (body == null) return;
    
    if (isExternal()) {
      if (body != b) {
        b.addForce(body);
      }
      return;
    }
    
    // Size of region
    float s = quad.length;
    float dx = body.x - b.x;
    float dy = body.y - b.y;
    float dist = sqrt(dx*dx + dy*dy + SOFTENING*SOFTENING);
    
    // Barnes-Hut opening criterion
    if ((s / dist) < THETA) {
      if (body != b) {
        b.addForce(body);
      }
    } else {
      if (nw != null) nw.updateForce(b);
      if (ne != null) ne.updateForce(b);
      if (sw != null) sw.updateForce(b);
      if (se != null) se.updateForce(b);
    }
  }
  
  // Draw quadtree bounding boxes in depth-colored beige and COM points
  void drawTree() {
    if (body == null) return;
    
    pushStyle();
    rectMode(CENTER);
    
    // Map depth to a beige-ish shade
    // deeper -> darker beige
    int maxDepth = 10;
    float d = constrain(depth, 0, maxDepth);
    float base = map(d, 0, maxDepth, 240, 140);   // grey-ish base
    float r = base + 10;                          // slightly warmer (redder)
    float g = base - 5;                           // slightly darker green
    float b = base - 20;                          // slightly darker blue
    
    r = constrain(r, 0, 255);
    g = constrain(g, 0, 255);
    b = constrain(b, 0, 255);
    
    stroke(r, g, b, 160);   // semi-transparent beige outline
    noFill();
    rect(quad.xMid, quad.yMid, quad.length, quad.length);
    
    // Draw center of mass
    fill(r, g, b, 220);
    noStroke();
    float radius = 3;
    if (depth == 0) radius = 6;  // root COM bigger
    ellipse(body.x, body.y, radius, radius);
    
    popStyle();
    
    // Recurse
    if (nw != null) nw.drawTree();
    if (ne != null) ne.drawTree();
    if (sw != null) sw.drawTree();
    if (se != null) se.drawTree();
  }
}
