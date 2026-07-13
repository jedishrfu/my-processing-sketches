class FlipFlop
{
  int initState = 0;

  int state=0;

  FlipFlop tf[]=new FlipFlop[2];
  
  int x,y;

  public FlipFlop (int px, int py, FlipFlop falsePath, FlipFlop truePath, int pinitState) {
    x=px; y=py;

    initState=pinitState;
    resetState();

    tf[0]=falsePath;
    tf[1]=truePath;
    }

  public void flipState(boolean recurse) {
    if (state==0) state=1; else state=0;

    if(recurse==true && tf[state]!=null) tf[state].flipState(true);

    return;
    }

  public void setState() {
    state=(initState+1)%2;
    }

  public void resetState() {
    state=initState;
    }

  public int getState() { return state; }
  
  public int getx() { return x; }
  public int gety() { return y; }

}