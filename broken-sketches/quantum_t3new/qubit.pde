class Qubit 
{
 static final int xoff = 5; 
 static final int yoff = 5; 
 
 int tsize;
 int toffs;


 static final int STATE_00 = 0;
 static final int STATE_11 = 1;
 static final int STATE_01 = 2;
 static final int STATE_10 = 3;
 static final int NO_STATE = 4; 
 
 String pieces[] = { "00", "11", "01", "10", "  " };
 
 int xp=0;
 int yp=0;
 int sx=0;
 int sy=0;
 
 int bgfill = color(255,255,255);
 
 int state = NO_STATE;
 
 int iframe = 0;
 
 color redtext = color(255,0,0);
 color bluetext = color(0,0,255);
 color blacktext = color(0,0,0);
 color txfill = blacktext;
 
 public Qubit(int xp, int yp, int sx, int sy) {
   
   this.state=NO_STATE;
   
   this.xp=xp;
   this.yp=yp;
   this.sx=sx;
   this.sy=sy;
   
   tsize = sx - xoff;
   toffs = xoff+(int)(sx*0.75);
 }
 
 public void setState(int state) {
   this.state=state;
 }
 
 public int getState() {
   return state;
 }
 
 public void setLoop() {
   txfill=redtext;  
 }
 
 public void setWin() {
   bgfill=128;  
   txfill=bluetext;
 }
 
 public void drawCell() {
   
   fill(bgfill);
   rect(xp+xoff,yp+yoff,sx-2*xoff,sy-2*yoff);
       
   textSize(tsize);
   fill(txfill);
   text(pieces[state].charAt(iframe%2),xp+toffs,yp+toffs);
   
   iframe++;
 }
 
 boolean testMouse(int mx, int my) {
   
   if((mx>xp)&&(mx<xp+sx)&&(my>yp)&&(my<yp+sy)){
     return true;
   }
   
   return false;
 }
}