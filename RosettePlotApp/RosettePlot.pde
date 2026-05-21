public class RosettePlot {

  // BN Rosette Settings...
  int NBEAMS=36;
  int NTRACES=6;
  int NBUTTONS=NTRACES;

  // BN Level Limits...
  float minLevel=0.0;    // level at the origin
  float maxLevel=150.0;  // level at the outer ring
  float traces[][] = new float[NTRACES][NBEAMS];


  int NRINGS=6;
  int NRADIALS=360/30;
  int NTICKS = 36;

  // rosette origin
  int XHOME = 320;
  int YHOME = 200;

  // TICK steps...
  int MINOR_TICK_STEP=1;      // MINOR tick step at 1 degree per tick
  int MAJOR_TICK_STEP=5;      // MAJOR tick step every 5 degrees
  int LABEL_STEP=10;          // DEGREE labels every 10 degrees

  // BUTTON labels...
  String buttons[] = { "100", "200", "300", "400", "500", "600" };

  // BN Rosette Colors...
  color WHITE = color(255, 255, 255);
  color RED = color(255, 0, 0);
  color YELLOW = color(250, 255, 0);
  color ORANGE = color(255, 141, 0);
  color GREEN = color(0, 255, 0);
  color BLUE = color(0, 0, 255);
  color INDIGO = color(128, 0, 255);
  color VIOLET = color(255, 0, 255);
  color BLACK = color(0, 0, 0);

  color traceColors[] = { RED, ORANGE, YELLOW, GREEN, BLUE, INDIGO, VIOLET, BLACK };
  int PX, PY, SX, SY;
  int BACKGROUND;

  public RosettePlot(int px, int py, int sx, int sy, int bg) {
    PX=px; 
    PY=py; 
    SX=sx; 
    SY=sy;
    XHOME = px + sx/2;
    YHOME = py + sy/2;
    BACKGROUND=bg;
  }

  void draw(float[][] traces) {

    // draw background
    fill(BACKGROUND);
    rect(PX, PY, SX, SY);
    // draw buttons
    drawButtons(PX+10, PY+10, buttons);

    // draw rosette
    drawRosette(XHOME, YHOME);

    // draw traces
    drawTraces(XHOME, YHOME, traces);

    float radius = sqrt( pow((XHOME-mouseX), 2) + pow((YHOME-mouseY), 2) );

    if (radius<200.0f) { 
      line(XHOME, YHOME, mouseX, mouseY);
      noFill();
      ellipse(XHOME, YHOME, 2*radius, 2*radius);
    }
  }

  void drawButtons(int x, int y, String[] buttons) {
    int xbox = 40;
    int ybox = 20;

    for (int ibutton=0; ibutton<NBUTTONS; ibutton++) {

      //color(ibutton);
      int x2 = ibutton*(xbox+10)+PX+10;
      int y2 = 10+PY;
      fill(traceColors[ibutton]);
      rect(x2, y2, xbox, ybox);
      fill(0);
      text(buttons[ibutton], x2+10, y2+15);
    }
  }

  void drawRosette(int xhome, int yhome) {
      stroke(0);
      noFill();
    // draw rings
    for (int iring=0; iring<NRINGS; iring++) { 
      // color(iring);
      //label(x,y,iring);
      float radius = maxLevel / NRINGS * (NRINGS-iring);
      //stroke(traceColors[iring]);

      ellipse(xhome, yhome, 2*radius, 2*radius);
    }

    // draw radials
    int idelta=360/NRADIALS;
    for (int idegree=0; idegree<360; idegree+=idelta) {
      //color(idegree);
      //label(x,y,idegree);
      float radian=radians((idegree-90)*1.0);
      float x=maxLevel*cos(radian)+xhome;
      float y=maxLevel*sin(radian)+yhome;
      //println("degree="+idegree+"   x="+x+"   y="+y);
      line(xhome, yhome, x, y);
      stroke(BLUE);
      text(idegree+"", x, y);
    }
  }

  void drawTraces(int xhome, int yhome, float traces[][]) {

    for (int itrace=0; itrace<NTRACES; itrace++) {
      float px=0.0;
      float py=0.0;
      float ox=0.0;
      float oy=0.0;

      stroke(traceColors[itrace]);

      for (int ilevel=0; ilevel<NBEAMS; ilevel++) {
        float level = traces[itrace][ilevel];
        float degree = (360.0 / NBEAMS)*ilevel - 90.0;
        float radian = radians(degree);
        float x=level*cos(radian)+xhome;
        float y=level*sin(radian)+yhome;
        //println("degree="+degree+"   x="+x+"   y="+y);
        if (px!=0.0) {
          line(px, py, x, y);
        } else {
          ox=x;
          oy=y;
        }
        px=x;
        py=y;
      }
      line(px, py, ox, oy);
    }
  }
}
