import java.applet.*;
import java.awt.*;
import java.awt.event.*;

// ----------------------------------------------------------------------
// Dr NIM Simulation by Jim McArdle April, 2000
//
// Dr NIM was a small game toy marketed by E.S.R Inc in the 1960's
// It was invented by John Godfrey (see patent #xxx-xxx-xxx-xxx)
//
// Dr NIM is a mechanical computer which can play a game of NIM with
// a human player.
//
// As the marbles
// flow through the game, they activate gates causing them to switch from
// side to side. The net effect of this is to redirect future marbles
// down a different path. The gates then imitate flipflops used in
// modern computing circuitry.
//
// Future Design Ideas:
//
//


int xDim=600;
int yDim=400;

int rMarble=30;

Button about;

int aboutFlag;

Polygon pp[] = new Polygon[6];


FlipFlop ff[] = new FlipFlop[5];

int    tx,ty;

AffineTranform at = new AffineTransform();

//Polygon

  public void setup () {
    int x,y,z;

    this.setBackground(Color.lightGray);

    addMouseListener(this);

    // define polygons p[*] that draw the RED raised areas
    pp[0] = new Polygon();   // outer most frame
    pp[1] = new Polygon();   // Dr NIM title piece
    pp[2] = new Polygon();   // Unmarked piece below ff 2 and 3
    pp[3] = new Polygon();   // New Game / Player piece
    pp[4] = new Polygon();   // Dr NIM piece
    pp[5] = new Polygon();   // Trigger piece

    // define the moveable game pieces (flipflops)
    ff[0] = new FlipFlop();
    ff[1] = new FlipFlop();
    ff[2] = new FlipFlop();
    ff[3] = new FlipFlop();
    ff[4] = new FlipFlop();

    // initialize the moveable game pieces
    ff[0].setClose();
    ff[1].setOpen();
    ff[2].setClose();
    ff[3].setOpen();
    ff[4].setOpen();
    }

  public void nextState() {

    if (FlipFlop.inMotion()) return;

    if (ff[0].isOpen()) {
      ff[0].setClose();

      // second level of ff
      if (ff[3].isOpen()) {
        ff[3].setClose();
        ff[4].setClose(false);
        }
      else {
        if (ff[4].isOpen()) {
          nextState();
          }
        }
      }

    else if (ff[1].isOpen()) {
      ff[1].setClose();
      ff[0].setOpen();

      // second level of ff
      if (ff[3].isOpen()) {
        ff[3].setClose();
        ff[4].setClose(false);
        }
      else {
        if (ff[4].isOpen()) {
          nextState();
          }
        }
      }

    else if (ff[2].isOpen()) {
      ff[2].setClose();
      ff[1].setOpen();
      if(ff[4].isOpen()) ff[4].setCLose();
      }
    }

  public void update() {
    for (i=0; i<ff.length; i++) {
      ff[i].nextStep();
      }
    }


  public void paint(Graphics g) {

    g.setColor(Color.gray);
    g.fillRect(0,0,600,400);

    // Draw the RED raised areas
    g.setColor(Color.red);
    for (i=0; i<pp.length; i++) {
      g.drawPoly(ff[i]);
      }

    // Draw the game flipflops
    g.setColor(Color.white);
    for(i=0;i<pp.size;i++) {
      g.drawPoly(ff[i].getPolygon());
      if(ff[i].hasMarble()) {
        g.drawCircle(ff[i].getX(),ff[i].getY(),rCircle);
        }
      }

    if(aboutFlag>0) {
      g.drawString("Dr NIM Game by JH Godfrey (patent #3,388,483 06/18/1968)",60,60);
      g.drawString("Dr NIM Simulation by Jim McArdle, v1.0 April, 2001",250,350);
      aboutFlag=0;
      }

    }

  public void mouseClicked(MouseEvent me) { }
  public void mouseReleased(MouseEvent me) { }

  public void mouseEntered(MouseEvent me) { }
  public void mouseExited(MouseEvent me) { }

  public void mousePressed(MouseEvent me) {
    tx = me.getX();
    ty = me.getY();

    this.repaint();
    }

    class AboutSelector implements ActionListener
    {
      public AboutSelector () { }

      public void actionPerformed(ActionEvent ae) {
        aboutFlag++;

        repaint();
        }
    }


class FlipFlop extends Polygon
{
  int ffType = 0;

  int state=0;

  FlipFlop tf[]=new FlipFlop[2];

  public FlipFlop (int px, int py, FlipFlop zeroPath, FlipFlop onePath, int pffType) {
    x=px; y=py;

    ffType=pffType;
    resetState();

    tf[0]=zeroPath;
    tf[1]=onePath;
    }

  public void cascadeStates() {
    if(tf[state]!=null) tf[state].cascadeStates();

    flipState();
    return;
    }

  public void flipState() {
    if(state==1) state--;
    else state++;

    return;
    }

  public void initState(int pstate) {
    state=pstate;
    }

  public void setState() {
    state=1;
    }

  public void resetState() {
    state=0;
    }

  public int getState() { return state; }

  }
