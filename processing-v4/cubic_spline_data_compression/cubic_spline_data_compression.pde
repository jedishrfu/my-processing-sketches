// Random points + Natural Cubic Spline interpolation demo
// Drop in a single .pde file and run in Processing (Java mode).

int N = 100;
double[] x = new double[N];
double[] y = new double[N];
NaturalCubicSpline spline;

int margin = 50;

void setup() {
  size(900, 500);
  // Generate data
  for (int i = 0; i < N; i++) {
    x[i] = i;                  // index as x
    y[i] = random(0, 100);     // value as y
  }
  // Build spline that passes through all points (natural boundary)
  spline = new NaturalCubicSpline(x, y);
  noLoop(); // static drawing
}

void draw() {
  background(255);
  drawAxes();

  // Plot raw points
  stroke(0);
  fill(0);
  for (int i = 0; i < N; i++) {
    float sx = sx(x[i]);
    float sy = sy(y[i]);
    ellipse(sx, sy, 4, 4);
  }

  // Draw spline curve
  stroke(200, 0, 0);
  noFill();
  float step = 0.25f; // sampling step along x
  float prevX = sx(0);
  float prevY = sy(spline.eval(0));
  for (float xi = step; xi <= N - 1; xi += step) {
    float yy = (float) spline.eval(xi);
    float cx = sx(xi);
    float cy = sy(yy);
    line(prevX, prevY, cx, cy);
    prevX = cx;
    prevY = cy;
  }

  // Labels
  fill(0);
  text("Index (x)", width/2, height - 10);
  pushMatrix();
  translate(15, height/2);
  rotate(-HALF_PI);
  text("Value (y)", 0, 0);
  popMatrix();
}

void keyPressed() {
  // Press 'r' to regenerate data and redraw
  if (key == 'r' || key == 'R') {
    for (int i = 0; i < N; i++) y[i] = random(0, 100);
    spline = new NaturalCubicSpline(x, y);
    redraw();
  }
}

void drawAxes() {
  stroke(120);
  // x-axis
  line(margin, height - margin, width - margin, height - margin);
  // y-axis
  line(margin, height - margin, margin, margin);
  // ticks
  stroke(180);
  for (int i = 0; i <= 10; i++) {
    float yy = sy(i * 10.0);
    line(margin - 5, yy, width - margin, yy);
  }
  for (int i = 0; i <= 10; i++) {
    float xx = map(i, 0, 10, margin, width - margin);
    line(xx, margin, xx, height - margin + 5);
  }
}

float sx(double xi) {
  return map((float) xi, 0, N - 1, margin, width - margin);
}

float sy(double yi) {
  // flip y so 0 is bottom, 100 is top
  return map((float) yi, 0, 100, height - margin, margin);
}

// ------------ Natural Cubic Spline (Numerical Recipes style) ------------
class NaturalCubicSpline {
  int n;
  double[] xa, ya, y2; // x, y, and second derivatives at knots

  NaturalCubicSpline(double[] x, double[] y) {
    this.n = x.length;
    this.xa = x.clone();
    this.ya = y.clone();
    this.y2 = new double[n];
    computeSecondDerivatives();
  }

  void computeSecondDerivatives() {
    // Natural spline: y''(0) = y''(n-1) = 0
    double[] u = new double[n - 1];
    y2[0] = 0.0;
    u[0] = 0.0;

    for (int i = 1; i < n - 1; i++) {
      double sig = (xa[i] - xa[i - 1]) / (xa[i + 1] - xa[i - 1]);
      double p = sig * y2[i - 1] + 2.0;
      y2[i] = (sig - 1.0) / p;
      double dd = (ya[i + 1] - ya[i]) / (xa[i + 1] - xa[i]) - (ya[i] - ya[i - 1]) / (xa[i] - xa[i - 1]);
      u[i] = (6.0 * dd / (xa[i + 1] - xa[i - 1]) - sig * u[i - 1]) / p;
    }

    y2[n - 1] = 0.0;
    for (int k = n - 2; k >= 0; k--) {
      y2[k] = y2[k] * y2[k + 1] + u[k];
    }
  }

  double eval(double x) {
    // Binary search for the right interval
    int klo = 0;
    int khi = n - 1;
    while (khi - klo > 1) {
      int k = (khi + klo) >> 1;
      if (xa[k] > x) khi = k;
      else klo = k;
    }
    double h = xa[khi] - xa[klo];
    if (h == 0.0) return ya[klo]; // defensive

    double a = (xa[khi] - x) / h;
    double b = (x - xa[klo]) / h;
    return a * ya[klo] + b * ya[khi]
      + ((a * a * a - a) * y2[klo] + (b * b * b - b) * y2[khi]) * (h * h) / 6.0;
  }
}
