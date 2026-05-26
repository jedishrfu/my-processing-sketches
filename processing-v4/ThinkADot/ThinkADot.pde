// ESR Think-A-Dot Game

int rCircle=30;  // RADIUS of sensitivity is 30 pixels about the FF

FlipFlop ff[] = new FlipFlop[8];  // ThinkADot has 8 FF

// SETUP runs once to initialize items...
void setup () {

  // DRAW GRAY rectangle on RED background 
  size(500,400);
  background(255,0,0);
  
  fill(200); // COLOR Light Gray
  rect(20,20,500-40,300-40);

  // FlipFlops DEFINED in reverse order due to flipflop dependencies
  ff[7]=new FlipFlop( 400, 250,  null,  null, 1);
  ff[6]=new FlipFlop( 250, 250,  null,  null, 0);
  ff[5]=new FlipFlop( 100, 250,  null,  null, 1);
  ff[4]=new FlipFlop( 325, 150, ff[6], ff[7], 0);
  ff[3]=new FlipFlop( 175, 150, ff[5], ff[6], 0);
  ff[2]=new FlipFlop( 400,  50, ff[4], ff[7], 1);
  ff[1]=new FlipFlop( 250,  50, ff[3], ff[4], 0);
  ff[0]=new FlipFlop( 100,  50, ff[5], ff[3], 1);
  
  // DRAW Think-A-Dot title...
  textSize(32);  // FONT size 32 pixels
  fill(0);       // FONT Color Black
  text("Think-A-Dot (ESR Inc.)",70,350);
  
  // DRAW ball drops on top and Set/Resets on side...
  textSize(20);
  
  text("[ o ]",  85,  18);   // LEFT ball drop
  text("[ o ]", 234,  18);   // MIDDLE ball drop
  text("[ o ]", 384,  18);   // RIGHT ball drop
  text("[ ]",     0, 150);   // LEFT reset YELLOW diamond
  text("[ ]",   480, 150);   // RIGHT reset BLUE diamond
}

// DRAW runs every 1/60 of second to capture mouse clicks
void draw() {
    
   // DRAW FlipFlop and COLOR based on state
   for(int i=0; i<ff.length; i++) {
      int ffstate = ff[i].getState();
      if(ffstate==0) {
        fill(0,0,255);  // COLOR Blue
      }
      else {
        fill(255,255,0);  // COLOR Yellow
      }
      
      ellipse(ff[i].x,ff[i].y,30,30);   // DRAW a circle
   }   
}

void mouseClicked() {
  if (mouseX<20) { // LEFT border click
    for(int i=0; i<ff.length; i++) ff[i].setState();
  }
    
  else if (mouseX>480) { // RIGHT border click
    for(int i=0; i<ff.length; i++) ff[i].resetState();
    
  } else if (mouseY<20) { // TOP border click
    
    if(mouseX<500/3) { // DROP left ball
        ff[0].flipState(true);
    } else if (mouseX<2*500/3) { // DROP middle ball
        ff[1].flipState(true);
    } else { // DROP right ball
        ff[2].flipState(true);
    } 
    
  } else {
    
    for(int i=0; i<ff.length; i++) {
      if ( (Math.abs(mouseX-ff[i].getx()) < rCircle) && (Math.abs(mouseY-ff[i].gety()) < rCircle) ) {
        ff[i].flipState(false);
        break;
        }
      }
  }
}