
int inumber=0;
int jnumber=0;
int maxnumber=0;
int ijump=0;
int numbers[]=new int[100000];

void setup() {
   size(1000,1000);
   line(0,0,1000,1000);
}

void draw() {
  
  ijump++;
  
  //if(ijump>99) exit();
  
  jnumber=inumber-ijump;
  
  if(jnumber<0 || numbers[jnumber]>0) {
    jnumber=inumber+ijump;
  }
  
  numbers[jnumber]=1;
  
  drawarc(inumber,jnumber);
  
  inumber=jnumber;
  
  println(inumber);
  
  drawtext(ijump,inumber);
}

void drawtext(int ijump,int inumber) {  
  fill(256,256,256);
  rect(480,0,300,30);
  fill(0, 102, 153);
  if(inumber>maxnumber) maxnumber=inumber;
  String msg = "ijump="+ijump+"  inumber="+inumber+"  max="+maxnumber;
  text(msg,500,20);
}

void drawarc(int inumber, int jnumber) {
  int x = (inumber+jnumber);
  int y=x;
  float aangle;
  float zangle;
  noFill();
  //stroke(color(random(256), random(256), random(256)));
  stroke(color(inumber%256, jnumber%256, ijump%256));
  //ellipse(x,y,ijump*2,ijump*2);
  if(inumber>jnumber) { aangle=QUARTER_PI+0.0; zangle=QUARTER_PI+PI; }
  else { aangle=QUARTER_PI+PI; zangle=QUARTER_PI+PI+PI; }
  arc(x,y,ijump*2,ijump*2,aangle,zangle);
}
void keyPressed() {
  if (key=='s' || key=='S') {
    PImage shot = get();
    shot.save("shot.png");
  }
}
