public class RosettePlot {

  int NBEAMS = 36;
  int NTRACES = 6;

  float minLevel = 0.0;
  float maxLevel = 150.0;

  int NRINGS = 6;
  int NRADIALS = 360 / 30;

  int XHOME;
  int YHOME;

  String[] labels = { "100", "200", "300", "400", "500", "600" };

  boolean[] traceOn = { true, true, true, true, true, true };

  color WHITE = color(255);
  color RED = color(255, 0, 0);
  color YELLOW = color(250, 255, 0);
  color ORANGE = color(255, 141, 0);
  color GREEN = color(0, 255, 0);
  color BLUE = color(0, 0, 255);
  color INDIGO = color(128, 0, 255);
  color VIOLET = color(255, 0, 255);
  color BLACK = color(0);

  color[] traceColors = { RED, ORANGE, YELLOW, GREEN, BLUE, INDIGO };

  int PX, PY, SX, SY;
  int BACKGROUND;

  public RosettePlot(int px, int py, int sx, int sy, int bg) {
    PX = px;
    PY = py;
    SX = sx;
    SY = sy;

    XHOME = px + sx / 2;
    YHOME = py + sy / 2;

    BACKGROUND = bg;
  }

  void draw(float[][] traces) {
    fill(BACKGROUND);
    noStroke();
    rect(PX, PY, SX, SY);

    drawTraceLegend();
    drawRosette(XHOME, YHOME);
    drawTraces(XHOME, YHOME, traces);
    drawMouseRadius();
  }

  void drawTraceLegend() {
    int xbox = 40;
    int ybox = 20;

    for (int i = 0; i < NTRACES; i++) {
      int x = i * (xbox + 10) + PX + 10;
      int y = PY + 10;

      if (traceOn[i]) {
        fill(traceColors[i]);
      } else {
        fill(180);
      }

      stroke(0);
      rect(x, y, xbox, ybox);

      fill(0);
      text(labels[i], x + 10, y + 15);
    }
  }

  void drawRosette(int xhome, int yhome) {
    stroke(0);
    noFill();

    for (int iring = 0; iring < NRINGS; iring++) {
      float radius = maxLevel / NRINGS * (NRINGS - iring);
      ellipse(xhome, yhome, 2 * radius, 2 * radius);
    }

    int idelta = 360 / NRADIALS;

    for (int idegree = 0; idegree < 360; idegree += idelta) {
      float radian = radians(idegree - 90);
      float x = maxLevel * cos(radian) + xhome;
      float y = maxLevel * sin(radian) + yhome;

      stroke(0);
      line(xhome, yhome, x, y);

      fill(BLUE);
      text(idegree, x, y);
      noFill();
    }
  }

  void drawTraces(int xhome, int yhome, float[][] traces) {
    for (int itrace = 0; itrace < NTRACES; itrace++) {

      if (!traceOn[itrace]) {
        continue;
      }

      float px = 0.0;
      float py = 0.0;
      float ox = 0.0;
      float oy = 0.0;

      stroke(traceColors[itrace]);
      noFill();

      for (int ilevel = 0; ilevel < NBEAMS; ilevel++) {
        float level = traces[itrace][ilevel];

        float degree = (360.0 / NBEAMS) * ilevel - 90.0;
        float radian = radians(degree);

        float x = level * cos(radian) + xhome;
        float y = level * sin(radian) + yhome;

        if (ilevel > 0) {
          line(px, py, x, y);
        } else {
          ox = x;
          oy = y;
        }

        px = x;
        py = y;
      }

      line(px, py, ox, oy);
    }
  }

  void drawMouseRadius() {
    float radius = dist(XHOME, YHOME, mouseX, mouseY);

    if (radius < maxLevel) {
      stroke(0);
      line(XHOME, YHOME, mouseX, mouseY);

      noFill();
      ellipse(XHOME, YHOME, 2 * radius, 2 * radius);
    }
  }

  void setTrace0(boolean v) {
    traceOn[0] = v;
  }

  void setTrace1(boolean v) {
    traceOn[1] = v;
  }

  void setTrace2(boolean v) {
    traceOn[2] = v;
  }

  void setTrace3(boolean v) {
    traceOn[3] = v;
  }

  void setTrace4(boolean v) {
    traceOn[4] = v;
  }

  void setTrace5(boolean v) {
    traceOn[5] = v;
  }
}
