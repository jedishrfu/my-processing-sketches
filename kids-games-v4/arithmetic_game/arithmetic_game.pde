// ============================================================
// KidMath Grid Trainer (Processing) — 1000×750
// Downloadable single-file sketch (.pde)
//
// Features:
// - Grade dropdown (3..8), Grid dropdown (10/12/16/20)
// - Vertical operation buttons (allowed by grade)
// - Multiple-choice dialog (grades 3–7) with optional "None of the above"
// - Text-entry dialog (grade 8)
// - Integer ops display as integers; DIV/NROOT display 2 decimals
// - Acceptance: integer ops exact; DIV/NROOT within 0.1
//
// Reset button cycle:
//   1) Clear grid (keep current row/col order)
//   2) Shuffle rows & cols + clear
//   3) Order rows & cols + clear
//   4) back to Clear ...
// Clicking anywhere NOT on Reset resets the reset-cycle back to "Clear".
//
// Scoring (in title line):
//   Level N   correct/tries   (pct%)
// Level up:
//   When 10 CORRECT answers have been given, firecrackers + certificate,
//   level increments, and the 10-question counters reset for next level.
//
// Save/Load per kid name: kidmath_<name>.json (saved in sketch folder)
// ============================================================

import java.util.Arrays;

int CANVAS_W = 1000;
int CANVAS_H = 750;

void settings() { size(CANVAS_W, CANVAS_H); }

// ------------------ State ------------------
int gradeLevel = 3;          // 3..8
int gridSize   = 10;         // 10,12,16,20
int level      = 1;

enum Op { ADD, SUB, MUL, DIV, MOD, NROOT, SUMSQ } // SUMSQ = a^2 + b^2
Op currentOp = Op.ADD;

int[] rows, cols;
int[][] cellState;           // 0 empty, 1 correct, -1 wrong
float[][] chosen;            // NaN if empty, else user's answer

// 10-correct milestone counters
int triesThisLevel = 0;
int correctThisLevel = 0;

// Reset cycle: 0->clear, 1->shuffle, 2->order, then back to 0
int resetStage = 0;

// Dialog
boolean showDialog = false;
int selR = -1, selC = -1;

float[] choices = new float[4];
boolean showNoneOption = false;  // grades 5–7
boolean noneIsCorrect  = false;
String inputAnswer = "";         // grade 8

// Certificate + fireworks
boolean showingCertificate = false;
String certMsg = "";
int fireworksTimer = 0;

// Kid name
String kidName = "kid";

// ------------------ Layout ------------------
float margin = 12;
float headerH = 52;

float panelX, panelY, panelW, panelH;
float gridX, gridY, cell, gridW, gridH;

// ------------------ Colors ------------------
color BG     = color(210, 245, 255);
color HEADER = color(255, 200, 120);
color CARD   = color(255);
color INK    = color(25);
color GOOD   = color(130, 255, 160);
color BAD    = color(255, 150, 150);

// ------------------ UI Widgets ------------------
class Button {
  float x,y,w,h;
  String label;
  Button(String label){ this.label = label; }
  void set(float x,float y,float w,float h){ this.x=x; this.y=y; this.w=w; this.h=h; }
  boolean over(){ return mouseX>=x && mouseX<=x+w && mouseY>=y && mouseY<=y+h; }
  void draw(boolean selected){
    stroke(130);
    fill(selected ? color(210,255,230) : (over()? color(240) : CARD));
    rect(x,y,w,h,10);
    fill(INK);
    textAlign(CENTER,CENTER);
    textSize(14);
    text(label, x+w/2, y+h/2+1);
  }
}

class TextBox {
  float x,y,w,h;
  boolean focused=false;
  String label;
  String value;
  TextBox(String label, String value){ this.label=label; this.value=value; }
  void set(float x,float y,float w,float h){ this.x=x; this.y=y; this.w=w; this.h=h; }
  boolean over(){ return mouseX>=x && mouseX<=x+w && mouseY>=y && mouseY<=y+h; }
  boolean click(){ focused = over(); return focused; }
  void blur(){ focused=false; }
  void draw(){
    fill(INK); textAlign(LEFT,TOP); textSize(12);
    text(label, x, y-15);

    stroke(focused ? color(50,140,255) : 130);
    fill(255);
    rect(x,y,w,h,10);

    fill(INK);
    textAlign(LEFT,CENTER);
    textSize(14);
    String shown = (value.length()==0 ? "type name…" : value);
    text(shown, x+10, y+h/2+1);

    if(focused){
      float tw = textWidth(shown);
      float cx = min(x+w-10, x+10+tw+2);
      stroke(INK);
      line(cx, y+7, cx, y+h-7);
    }
  }
  void key(char k, int kc){
    if(!focused) return;
    if(kc==BACKSPACE){
      if(value.length()>0) value = value.substring(0, value.length()-1);
      return;
    }
    if(kc==DELETE){ value=""; return; }
    if(kc==ENTER || kc==RETURN || kc==TAB){ focused=false; return; }

    if((k>='a'&&k<='z')||(k>='A'&&k<='Z')||(k>='0'&&k<='9')||k==' '||k=='_'||k=='-'){
      if(value.length()<24) value += k;
    }
  }
}

class DropDown {
  float x,y,w,h;
  String title;
  String[] items;
  int selected=0;
  boolean isOpen=false;

  DropDown(String title, String[] items){ this.title=title; this.items=items; }

  void set(float x,float y,float w,float h){ this.x=x; this.y=y; this.w=w; this.h=h; }

  boolean overBox(){ return mouseX>=x && mouseX<=x+w && mouseY>=y && mouseY<=y+h; }

  void drawBox(){
    fill(INK); textAlign(LEFT,TOP); textSize(12);
    text(title, x, y-15);
    stroke(130);
    fill(isOpen ? color(245) : CARD);
    rect(x,y,w,h,10);

    fill(INK);
    textAlign(LEFT,CENTER);
    textSize(14);
    text(items[selected], x+10, y+h/2+1);

    float cx = x+w-18, cy = y+h/2;
    triangle(cx-6, cy-3, cx+6, cy-3, cx, cy+5);
  }

  void drawOverlay(){
    if(!isOpen) return;
    float itemH = h;
    float listH = items.length * itemH;

    stroke(130);
    fill(CARD);
    rect(x, y+h+6, w, listH+8, 12);

    for(int i=0;i<items.length;i++){
      float iy = y+h+10 + i*itemH;
      boolean hov = mouseX>=x && mouseX<=x+w && mouseY>=iy && mouseY<=iy+itemH;
      noStroke();
      fill(hov ? color(230) : CARD);
      rect(x+6, iy, w-12, itemH, 10);

      fill(INK);
      textAlign(LEFT,CENTER);
      textSize(14);
      text(items[i], x+14, iy+itemH/2+1);
    }
  }

  boolean click(){
    if(isOpen){
      float itemH = h;
      float top = y+h+10;
      float bottom = top + items.length*itemH;
      if(mouseX>=x && mouseX<=x+w && mouseY>=top && mouseY<=bottom){
        int idx = int((mouseY - top)/itemH);
        idx = constrain(idx, 0, items.length-1);
        selected = idx;
        isOpen = false;
        return true;
      }
      isOpen = false;
      return true; // consume click while open
    } else {
      if(overBox()){
        isOpen = true;
        return true;
      }
    }
    return false;
  }

  void close(){ isOpen=false; }
}

// UI instances
DropDown ddGrade, ddGrid;
TextBox tbName;

Button btnReset = new Button("Reset");
Button btnSave  = new Button("Save");
Button btnLoad  = new Button("Load");

Button[] opButtons = new Button[0];

// ------------------ Confetti ------------------
class Confetto {
  float x, y, vx, vy, ang, vang, life, size;
  color c;
  int shape; // 0=rect,1=tri,2=circle
  Confetto(float x, float y){
    this.x = x; this.y = y;
    float a = random(TWO_PI);
    float s = random(2.0, 8.0);
    vx = cos(a)*s;
    vy = sin(a)*s - random(2,6);
    ang = random(TWO_PI);
    vang = random(-0.25, 0.25);
    life = 255;
    size = random(4, 10);
    c = color(random(255), random(255), random(255));
    shape = (int)random(3);
  }
  void step(){
    x += vx; y += vy;
    vy += 0.12;        // gravity
    vx *= 0.99; vy *= 0.99;
    ang += vang;
    life -= 3.8;
  }
  void draw(){
    pushStyle();
    pushMatrix();
    translate(x, y);
    rotate(ang);
    noStroke();
    fill(c, life);
    if(shape==0){
      rectMode(CENTER);
      rect(0,0,size,size*0.6,2);
      rectMode(CORNER); // don't leak rectMode
    } else if(shape==1){
      triangle(-size*0.6, size*0.5, size*0.6, size*0.5, 0, -size*0.7);
    } else {
      ellipseMode(CENTER);
      circle(0,0,size*0.9);
      ellipseMode(CORNER);
    }
    popMatrix();
    popStyle();
  }
}
ArrayList<Confetto> confetti = new ArrayList<Confetto>();

// quick burst
void spawnConfettiBurst(float x, float y, int count){
  for(int i=0;i<count;i++) confetti.add(new Confetto(x,y));
}

// update + draw
void updateConfetti(){
  for(int i=confetti.size()-1;i>=0;i--){
    Confetto c = confetti.get(i);
    c.step();
    c.draw();
    if(c.life <= 0) confetti.remove(i);
  }
}

// ------------------ Fireworks ------------------
class Spark {
  float x,y,vx,vy,life;
  color c;
  Spark(float x,float y){
    this.x=x; this.y=y;
    float a = random(TWO_PI);
    float s = random(1.5, 6.0);
    vx = cos(a)*s;
    vy = sin(a)*s - random(1,3);
    life = 255;
    c = color(random(255), random(255), random(255));
  }
  void step(){
    x += vx; y += vy;
    vy += 0.08;
    vx *= 0.99; vy *= 0.99;
    life -= 3.2;
  }
  void draw(){
    noStroke();
    fill(c, life);
    circle(x,y,4);
  }
}
ArrayList<Spark> sparks = new ArrayList<Spark>();

void spawnFirecrackers(){
  for(int b=0;b<6;b++){
    float bx = gridX + cell + random((gridSize-1)*cell);
    float by = gridY + cell + random(2*cell, 6*cell);
    for(int i=0;i<90;i++) sparks.add(new Spark(bx,by));
  }
  fireworksTimer = 140;
}

void updateFireworks(){
  if(fireworksTimer>0) fireworksTimer--;
  for(int i=sparks.size()-1;i>=0;i--){
    Spark s = sparks.get(i);
    s.step();
    s.draw();
    if(s.life <= 0) sparks.remove(i);
  }
}

// ------------------ Setup ------------------
void setup(){
  surface.setTitle("KidMath Grid");
  textFont(createFont("Comic Sans MS", 16));

  ddGrade = new DropDown("Grade", new String[]{"3","4","5","6","7","8"});
  ddGrid  = new DropDown("Grid Size", new String[]{"10×10","12×12","16×16","20×20"});
  tbName  = new TextBox("Name", kidName);

  ddGrade.selected = 0; // grade 3
  ddGrid.selected  = 0; // 10x10

  applyGradeFromDropdown();
  applyGridFromDropdown();
  ensureOpAllowed();

  buildCanonicalHeaders();
  shuffleIntArray(rows);
  shuffleIntArray(cols);

  allocateCells();
  clearGridOnly();

  rebuildOpButtons();
}

// ------------------ Allowed ops by grade ------------------
Op[] opsForGrade(int g){
  if(g==3) return new Op[]{ Op.ADD, Op.SUB };
  if(g==4) return new Op[]{ Op.ADD, Op.SUB, Op.MUL };
  if(g==5) return new Op[]{ Op.ADD, Op.SUB, Op.MUL, Op.DIV };
  if(g==6) return new Op[]{ Op.ADD, Op.SUB, Op.MUL, Op.DIV, Op.MOD };
  if(g==7) return new Op[]{ Op.ADD, Op.SUB, Op.MUL, Op.DIV, Op.MOD, Op.NROOT };
  return new Op[]{ Op.ADD, Op.SUB, Op.MUL, Op.DIV, Op.MOD, Op.NROOT, Op.SUMSQ };
}

String opLabel(Op o){
  switch(o){
    case ADD:   return "Addition";
    case SUB:   return "Subtraction";
    case MUL:   return "Multiplication";
    case DIV:   return "Division";
    case MOD:   return "Modulo";
    case NROOT: return "Nth Root";
    case SUMSQ: return "a² + b²";
  }
  return "";
}

String opSymbol(Op o){
  switch(o){
    case ADD:   return "+";
    case SUB:   return "−";
    case MUL:   return "×";
    case DIV:   return "÷";
    case MOD:   return "%";
    case NROOT: return "x^(1/n)";
    case SUMSQ: return "a²+b²";
  }
  return "";
}

boolean isIntegerOp(Op o){
  return (o==Op.ADD || o==Op.SUB || o==Op.MUL || o==Op.MOD || o==Op.SUMSQ);
}

void ensureOpAllowed(){
  Op[] allowed = opsForGrade(gradeLevel);
  boolean ok=false;
  for(Op o: allowed) if(o==currentOp) ok=true;
  if(!ok) currentOp = allowed[0];
}

// ------------------ Layout ------------------
void computeLayout(){
  panelX = margin;
  panelY = headerH + margin;
  panelW = 230;
  panelH = height - panelY - margin;

  float gap = 10;
  float gridAreaX = panelX + panelW + gap;
  float gridAreaY = headerH + margin;
  float gridAreaW = width - gridAreaX - margin;
  float gridAreaH = height - gridAreaY - margin;

  float cellW = gridAreaW / (gridSize + 1);
  float cellH = gridAreaH / (gridSize + 1);
  cell = floor(min(cellW, cellH));
  cell = max(12, cell);

  gridW = (gridSize + 1)*cell;
  gridH = (gridSize + 1)*cell;

  gridX = gridAreaX;
  gridY = gridAreaY + (gridAreaH - gridH)/2.0;
}

// ------------------ Draw ------------------
void draw(){
  background(BG);
  computeLayout();

  drawHeader();
  drawGrid();
  drawPanel();

  if(showDialog) drawDialog();
  updateFireworks();
  updateConfetti();
  if(showingCertificate) drawCertificate();

  // overlays last
  ddGrade.drawOverlay();
  ddGrid.drawOverlay();
}

// Header: title + score on same line
void drawHeader(){
  noStroke();
  fill(HEADER);
  rect(0,0,width,headerH);

  fill(INK);
  textAlign(LEFT,CENTER);
  textSize(18);
  String title = opLabel(currentOp) + " (" + opSymbol(currentOp) + ")   •   Grade " + gradeLevel;
  text(title, margin, headerH/2);

  float pct = (triesThisLevel==0) ? 0 : (100.0 * correctThisLevel / triesThisLevel);
  String score = "Level " + level + "   " + correctThisLevel + "/" + triesThisLevel + "   (" + nf(pct,0,1) + "%)";

  textSize(16);
  float pad=10;
  float boxW = max(250, textWidth(score) + 2*pad);
  float boxH = 34;
  float x = width - margin - boxW;
  float y = (headerH - boxH)/2;

  stroke(180);
  fill(255,255,255,210);
  rect(x,y,boxW,boxH,12);

  noStroke();
  fill(INK);
  textAlign(RIGHT,CENTER);
  text(score, x+boxW-pad, y+boxH/2+1);
}

// Grid
void drawGrid(){
  stroke(170);
  fill(255,255,255,220);
  rect(gridX-8, gridY-8, gridW+16, gridH+16, 18);

  textAlign(CENTER,CENTER);
  textSize(max(9, (int)(cell*0.28)));

  for(int r=0;r<gridSize+1;r++){
    for(int c=0;c<gridSize+1;c++){
      float x = gridX + c*cell;
      float y = gridY + r*cell;

      boolean isHeaderCell = (r==0 || c==0);
      if(isHeaderCell){
        fill(HEADER);
      } else {
        int rr=r-1, cc=c-1;
        if(cellState[rr][cc]==1) fill(GOOD);
        else if(cellState[rr][cc]==-1) fill(BAD);
        else fill(255);
      }

      stroke(205);
      rect(x,y,cell,cell);

      fill(INK);
      if(r==0 && c==0){
        text(opSymbol(currentOp), x+cell/2, y+cell/2);
      } else if(r==0 && c>0){
        text(cols[c-1], x+cell/2, y+cell/2);
      } else if(c==0 && r>0){
        text(rows[r-1], x+cell/2, y+cell/2);
      } else {
        int rr=r-1, cc=c-1;
        if(!Float.isNaN(chosen[rr][cc])){
          text(formatAnswer(chosen[rr][cc]), x+cell/2, y+cell/2);
        }
      }
    }
  }
}

// Panel
void drawPanel(){
  stroke(170);
  fill(255,255,255,230);
  rect(panelX, panelY, panelW, panelH, 16);

  float x = panelX + 10;
  float y = panelY + 10;

  // name
  tbName.set(x, y+18, panelW-20, 30);
  tbName.value = kidName;
  tbName.draw();
  y += 56;

  // grade dropdown
  ddGrade.set(x, y+18, panelW-20, 30);
  ddGrade.drawBox();
  y += 56;

  // grid dropdown
  ddGrid.set(x, y+18, panelW-20, 30);
  ddGrid.drawBox();
  y += 56;

  // save/load
  float bw = (panelW-20-10)/2.0;
  btnSave.set(x, y+10, bw, 30);
  btnLoad.set(x+bw+10, y+10, bw, 30);
  btnSave.draw(false);
  btnLoad.draw(false);
  y += 52;

  // reset
  btnReset.set(x, y, panelW-20, 34);
  btnReset.label = (resetStage==0 ? "Reset (Clear)" : (resetStage==1 ? "Reset (Shuffle)" : "Reset (Order)"));
  btnReset.draw(false);
  y += 48;

  // operations label
  fill(INK);
  textAlign(LEFT,TOP);
  textSize(13);
  text("Operation", x, y);
  y += 18;

  // vertical operation buttons
  Op[] allowed = opsForGrade(gradeLevel);
  if(opButtons.length != allowed.length) rebuildOpButtons();

  float bh = 30, gap = 8;
  for(int i=0;i<allowed.length;i++){
    opButtons[i].label = opLabel(allowed[i]);
    opButtons[i].set(x, y, panelW-20, bh);
    opButtons[i].draw(allowed[i]==currentOp);
    y += bh + gap;
    if(y > panelY + panelH - 30) break;
  }

  fill(INK);
  textAlign(LEFT, BOTTOM);
  textSize(11);
  text("Click a box to answer.", x, panelY + panelH - 12);
}

void rebuildOpButtons(){
  Op[] allowed = opsForGrade(gradeLevel);
  opButtons = new Button[allowed.length];
  for(int i=0;i<allowed.length;i++) opButtons[i] = new Button(opLabel(allowed[i]));
}

// ------------------ Dialog ------------------
void drawDialog(){
  float a = rows[selR];
  float b = cols[selC];
  String prompt = problemString(a,b) + " = ?";

  float dialogW = min(520, width-60);
  float dialogH = (gradeLevel==8) ? 250 : 360;
  float dx = (width-dialogW)/2;
  float dy = (height-dialogH)/2;

  stroke(120);
  fill(255);
  rect(dx,dy,dialogW,dialogH,16);

  fill(INK);
  textAlign(CENTER,TOP);
  textSize(20);
  text(prompt, dx+dialogW/2, dy+14);

  if(gradeLevel==8){
    float boxW=240, boxH=40;
    float bx = dx+(dialogW-boxW)/2;
    float by = dy+86;

    stroke(140);
    fill(255);
    rect(bx,by,boxW,boxH,10);

    fill(INK);
    textAlign(CENTER,CENTER);
    textSize(18);
    text(inputAnswer.length()==0 ? "type answer…" : inputAnswer, bx+boxW/2, by+boxH/2);

    float okW=160, okH=42;
    float okX = dx+(dialogW-okW)/2;
    float okY = dy+154;

    boolean hov = mouseX>=okX && mouseX<=okX+okW && mouseY>=okY && mouseY<=okY+okH;
    fill(hov ? color(230) : color(210,255,230));
    stroke(140);
    rect(okX,okY,okW,okH,10);

    fill(INK);
    textAlign(CENTER,CENTER);
    textSize(16);
    text("OK", okX+okW/2, okY+okH/2);

    fill(INK);
    textAlign(CENTER,TOP);
    textSize(12);
    text("Accepted if within 0.1 of correct.", dx+dialogW/2, dy+dialogH-26);
    return;
  }

  int numChoices = (gradeLevel==3 ? 3 : 4);
  showNoneOption = (gradeLevel>=5 && gradeLevel<=7);

  float btnW = min(360, dialogW-80);
  float btnH = 44;
  float bx = dx + (dialogW-btnW)/2;
  float by = dy + 76;

  for(int i=0;i<numChoices;i++){
    float yy = by + i*(btnH+12);
    boolean hov = mouseX>=bx && mouseX<=bx+btnW && mouseY>=yy && mouseY<=yy+btnH;

    stroke(140);
    fill(hov ? color(235) : color(250));
    rect(bx,yy,btnW,btnH,12);

    fill(INK);
    textAlign(CENTER,CENTER);
    textSize(18);
    text(formatAnswer(choices[i]), bx+btnW/2, yy+btnH/2);
  }

  if(showNoneOption){
    float yy = by + numChoices*(btnH+12);
    boolean hov = mouseX>=bx && mouseX<=bx+btnW && mouseY>=yy && mouseY<=yy+btnH;

    stroke(140);
    fill(hov ? color(235) : color(250));
    rect(bx,yy,btnW,btnH,12);

    fill(INK);
    textAlign(CENTER,CENTER);
    textSize(16);
    text("None of the above", bx+btnW/2, yy+btnH/2);
  }

  fill(INK);
  textAlign(CENTER,TOP);
  textSize(12);
  text("Accepted if within 0.1 of correct.", dx+dialogW/2, dy+dialogH-26);
}

boolean handleDialogClick(){
  float dialogW = min(520, width-60);
  float dialogH = (gradeLevel==8) ? 250 : 360;
  float dx = (width-dialogW)/2;
  float dy = (height-dialogH)/2;

  float a = rows[selR];
  float b = cols[selC];
  float correct = compute(a,b);

  if(gradeLevel==8){
    float okW=160, okH=42;
    float okX = dx+(dialogW-okW)/2;
    float okY = dy+154;
    if(mouseX>=okX && mouseX<=okX+okW && mouseY>=okY && mouseY<=okY+okH){
      submitTextAnswer();
      showDialog=false;
      return true;
    }
    if(mouseX>=dx && mouseX<=dx+dialogW && mouseY>=dy && mouseY<=dy+dialogH) return true;
    return false;
  }

  int numChoices = (gradeLevel==3 ? 3 : 4);
  boolean hasNone = (gradeLevel>=5 && gradeLevel<=7);

  float btnW = min(360, dialogW-80);
  float btnH = 44;
  float bx = dx + (dialogW-btnW)/2;
  float by = dy + 76;

  for(int i=0;i<numChoices;i++){
    float yy = by + i*(btnH+12);
    if(mouseX>=bx && mouseX<=bx+btnW && mouseY>=yy && mouseY<=yy+btnH){
      float picked = choices[i];
      applyAnswer(approx(picked, correct), picked);
      showDialog=false;
      return true;
    }
  }

  if(hasNone){
    float yy = by + numChoices*(btnH+12);
    if(mouseX>=bx && mouseX<=bx+btnW && mouseY>=yy && mouseY<=yy+btnH){
      applyAnswer(noneIsCorrect, correct); // paste correct answer
      showDialog=false;
      return true;
    }
  }

  if(mouseX>=dx && mouseX<=dx+dialogW && mouseY>=dy && mouseY<=dy+dialogH) return true;
  return false;
}

// ------------------ Certificate ------------------
void drawCertificate(){
  // soft dark overlay
  noStroke();
  fill(0,0,0,90);
  rect(0,0,width,height);

  // continuous confetti blooms while certificate is visible
  if(frameCount % 10 == 0){
    float bx = width*0.5 + random(-220, 220);
    float by = height*0.35 + random(-40, 60);
    spawnConfettiBurst(bx, by, 22);
  }
float w = min(700, width-70);
  float h = 320;
  float x = (width-w)/2;
  float y = (height-h)/2;

  // colorful backdrop
  stroke(90);
  fill(255);
  rect(x,y,w,h,24);

  // rainbow banner stripes
  noStroke();
  for(int i=0;i<7;i++){
    float yy = y + 18 + i*12;
    fill(color(255 - i*20, 120 + i*15, 200 - i*18), 210);
    rect(x+18, yy, w-36, 12, 8);
  }

  // frame
  stroke(240,160,60);
  strokeWeight(4);
  noFill();
  rect(x+12,y+12,w-24,h-24,20);
  strokeWeight(1);

  // big star badge
  pushMatrix();
  translate(x+w-90, y+85);
  rotate(-0.15);
  noStroke();
  fill(255, 220, 80);
  star(0,0,38,18,5);
  fill(255, 140, 160, 220);
  star(0,0,26,12,5);
  popMatrix();

  // sprinkle stars
  noStroke();
  for(int i=0;i<10;i++){
    float sx = x + 40 + random(w-80);
    float sy = y + 150 + random(h-190);
    fill(color(random(255), random(255), random(255)), 90);
    star(sx, sy, random(10,16), random(4,8), 5);
  }

  fill(INK);
  textAlign(CENTER,CENTER);
  textSize(30);
text("🎓 Certificate of Progress 🎓", x+w/2, y+70);

  textSize(22);
  text(certMsg, x+w/2, y+140);

  textSize(14);
  text("Click to continue", x+w/2, y+210);
}

// ------------------ Mouse / Keyboard ------------------
void mousePressed(){
  if(showingCertificate){
    showingCertificate = false;
    return;
  }

  // If click is NOT on Reset, reset reset-cycle back to start
  boolean clickOnReset = btnReset.over();
  if(!clickOnReset) resetStage = 0;

  // Dropdowns first
  if(ddGrade.click()){
    ddGrid.close();
    tbName.blur();
    int newGrade = 3 + ddGrade.selected;
    if(newGrade != gradeLevel){
      gradeLevel = newGrade;
      ensureOpAllowed();
      rebuildOpButtons();
      clearGridOnly();
      triesThisLevel = 0;
      correctThisLevel = 0;
    }
    return;
  }
  if(ddGrid.click()){
    ddGrade.close();
    tbName.blur();
    int[] sizes = {10,12,16,20};
    int newSize = sizes[ddGrid.selected];
    if(newSize != gridSize){
      gridSize = newSize;
      buildCanonicalHeaders();
      shuffleIntArray(rows);
      shuffleIntArray(cols);
      allocateCells();
      clearGridOnly();
      triesThisLevel = 0;
      correctThisLevel = 0;
      resetStage = 0;
    }
    return;
  }

  // Dialog click
  if(showDialog){
    if(handleDialogClick()) return;
    showDialog = false;
    return;
  }

  // Name box
  if(tbName.click()){
    ddGrade.close(); ddGrid.close();
    return;
  } else {
    tbName.blur();
    kidName = tbName.value;
  }

  // Save/Load
  if(btnSave.over()){ saveGame(); return; }
  if(btnLoad.over()){ loadGame(); return; }

  // Reset
  if(btnReset.over()){
    doResetCycle();
    return;
  }

  // Op buttons
  if(handleOpButtonsClick()) return;

  // Grid cell click
  int r = cellRowFromMouse();
  int c = cellColFromMouse();
  if(r>=0 && c>=0){
    openDialogForCell(r,c);
  }
}

boolean handleOpButtonsClick(){
  Op[] allowed = opsForGrade(gradeLevel);
  for(int i=0;i<allowed.length;i++){
    if(opButtons[i].over()){
      if(currentOp != allowed[i]){
        currentOp = allowed[i];
        buildCanonicalHeaders();
        shuffleIntArray(rows);
        shuffleIntArray(cols);
        clearGridOnly();
        triesThisLevel = 0;
        correctThisLevel = 0;
        resetStage = 0;
      }
      return true;
    }
  }
  return false;
}

void keyPressed(){
  if(!showDialog && tbName.focused){
    tbName.key(key, keyCode);
    kidName = tbName.value;
    return;
  }

  if(!showDialog || gradeLevel!=8) return;

  if(keyCode==BACKSPACE){
    if(inputAnswer.length()>0) inputAnswer = inputAnswer.substring(0, inputAnswer.length()-1);
    return;
  }
  if(keyCode==ENTER || keyCode==RETURN){
    submitTextAnswer();
    showDialog=false;
    return;
  }
  if((key>='0'&&key<='9') || key=='-' || key=='.'){
    inputAnswer += key;
  }
}

// ------------------ Reset cycle ------------------
void doResetCycle(){
  if(resetStage==0){
    clearGridOnly();
    resetStage = 1;
  } else if(resetStage==1){
    shuffleIntArray(rows);
    shuffleIntArray(cols);
    clearGridOnly();
    resetStage = 2;
  } else {
    Arrays.sort(rows);
    Arrays.sort(cols);
    clearGridOnly();
    resetStage = 0;
  }
}

// ------------------ Dialog open / choice generation ------------------
void openDialogForCell(int r, int c){
  selR=r; selC=c;
  inputAnswer = "";
  generateChoicesForCell(r,c);
  showDialog = true;
}

void generateChoicesForCell(int r, int c){
  float a = rows[r];
  float b = cols[c];
  float correct = compute(a,b);

  showNoneOption = (gradeLevel>=5 && gradeLevel<=7);
  noneIsCorrect = false;

  int numChoices = (gradeLevel==3 ? 3 : 4);

  if(showNoneOption){
    noneIsCorrect = (random(1) < 0.25);
  }

  FloatList selected = new FloatList();

  if(!showNoneOption || !noneIsCorrect){
    selected.append(correct);
  }

  FloatList pool = new FloatList();
  for(int i=0;i<160;i++){
    float v;
    if(isIntegerOp(currentOp)){
      v = round(correct + random(-14, 14));
    } else {
      v = round((correct + random(-6,6))*100.0)/100.0;
    }
    if(!Float.isNaN(v) && !Float.isInfinite(v)) pool.append(v);
  }

  if(currentOp==Op.NROOT){
    float n=a, x=b;
    pool.append(round(pow(max(1, x+1), 1.0/n)*100)/100.0);
    pool.append(round(pow(max(1, x+4), 1.0/n)*100)/100.0);
  }

  pool.shuffle();

  int guard=0;
  while(selected.size() < numChoices && guard++ < 5000){
    float v = pool.get((int)random(pool.size()));
    if(showNoneOption && noneIsCorrect && approx(v, correct)) continue;

    boolean dup=false;
    for(int i=0;i<selected.size();i++){
      float u = selected.get(i);
      if(isIntegerOp(currentOp)){
        if(round(u)==round(v)) { dup=true; break; }
      } else {
        if(abs(u-v) < 0.02) { dup=true; break; }
      }
    }
    if(!dup) selected.append(v);
  }

  if(!showNoneOption || !noneIsCorrect){
    boolean has=false;
    for(int i=0;i<selected.size();i++) if(approx(selected.get(i), correct)) has=true;
    if(!has) selected.set((int)random(selected.size()), correct);
  }

  selected.shuffle();
  for(int i=0;i<numChoices;i++) choices[i] = selected.get(i);
}

void submitTextAnswer(){
  float a = rows[selR];
  float b = cols[selC];
  float correct = compute(a,b);

  try{
    float v = float(trim(inputAnswer));
    applyAnswer(approx(v, correct), v);
  } catch(Exception e){
    applyAnswer(false, correct);
  }
}

// ------------------ Apply answer + Level up on 10 CORRECT ------------------
void applyAnswer(boolean ok, float displayValue){
  chosen[selR][selC] = displayValue;
  cellState[selR][selC] = ok ? 1 : -1;

  triesThisLevel++;
  if(ok){
    correctThisLevel++;
    // confetti bloom at the answered cell
    float cx = gridX + (selC+1)*cell + cell/2;
    float cy = gridY + (selR+1)*cell + cell/2;
    spawnConfettiBurst(cx, cy, 80);
  }

  // Level up when 10 CORRECT
  if(correctThisLevel >= 10){
    level++;
    certMsg = "Great, you made it to level " + level + "!";
    showingCertificate = true;

    spawnFirecrackers();

    triesThisLevel = 0;
    correctThisLevel = 0;
  }
}

// ------------------ Compute / formatting ------------------
String problemString(float a, float b){
  switch(currentOp){
    case ADD:   return nf(a,0,0) + " + " + nf(b,0,0);
    case SUB:   return nf(a,0,0) + " − " + nf(b,0,0);
    case MUL:   return nf(a,0,0) + " × " + nf(b,0,0);
    case DIV:   return nf(a,0,0) + " ÷ " + nf(b,0,0);
    case MOD:   return nf(a,0,0) + " % " + nf(b,0,0);
    case NROOT: return nf(b,0,0) + "^(1/" + nf(a,0,0) + ")";
    case SUMSQ: return nf(a,0,0) + "² + " + nf(b,0,0) + "²";
  }
  return "";
}

float compute(float a, float b){
  switch(currentOp){
    case ADD:  return a + b;
    case SUB:  return a - b;
    case MUL:  return a * b;
    case DIV:  return (b==0) ? Float.NaN : a / b;
    case MOD:  return (b==0) ? Float.NaN : ((int)a % (int)b);
    case NROOT:
      if(a==0) return Float.NaN;
      if(b < 0 && ((int)a)%2==0) return Float.NaN;
      return pow(b, 1.0/a);
    case SUMSQ:
      return a*a + b*b;
  }
  return Float.NaN;
}

String formatAnswer(float v){
  if(Float.isNaN(v) || Float.isInfinite(v)) return "—";
  if(isIntegerOp(currentOp)) return str((int)round(v));
  return nf(v, 0, 2);
}

boolean approx(float a, float b){
  if(Float.isNaN(a)||Float.isNaN(b)||Float.isInfinite(a)||Float.isInfinite(b)) return false;
  if(isIntegerOp(currentOp)) return round(a)==round(b);
  return abs(a-b) <= 0.1;
}

// ------------------ Headers / allocation ------------------
void buildCanonicalHeaders(){
  rows = new int[gridSize];
  cols = new int[gridSize];

  if(currentOp == Op.NROOT){
    for(int i=0;i<gridSize;i++) rows[i] = clamp(2+i, 2, 9);
    for(int i=0;i<gridSize;i++) cols[i] = 2 + i;
  } else {
    for(int i=0;i<gridSize;i++){
      rows[i] = clamp(1+i, 1, 20);
      cols[i] = clamp(1+i, 1, 20);
    }
  }
}

void allocateCells(){
  cellState = new int[gridSize][gridSize];
  chosen = new float[gridSize][gridSize];
}

void clearGridOnly(){
  for(int r=0;r<gridSize;r++){
    for(int c=0;c<gridSize;c++){
      cellState[r][c] = 0;
      chosen[r][c] = Float.NaN;
    }
  }
  showDialog = false;
}

// ------------------ Mouse -> Cell mapping ------------------
int cellRowFromMouse(){
  float gx0 = gridX + cell;
  float gy0 = gridY + cell;
  if(mouseX < gx0 || mouseY < gy0) return -1;
  int c = int((mouseX - gx0)/cell);
  int r = int((mouseY - gy0)/cell);
  if(r<0||r>=gridSize||c<0||c>=gridSize) return -1;
  return r;
}

int cellColFromMouse(){
  float gx0 = gridX + cell;
  float gy0 = gridY + cell;
  if(mouseX < gx0 || mouseY < gy0) return -1;
  int c = int((mouseX - gx0)/cell);
  int r = int((mouseY - gy0)/cell);
  if(r<0||r>=gridSize||c<0||c>=gridSize) return -1;
  return c;
}

// ------------------ Dropdown apply helpers ------------------
void applyGradeFromDropdown(){
  gradeLevel = 3 + ddGrade.selected;
}
void applyGridFromDropdown(){
  int[] sizes = {10,12,16,20};
  gridSize = sizes[ddGrid.selected];
}

// ------------------ Shuffle helper ------------------
void shuffleIntArray(int[] a){
  for(int i=a.length-1;i>0;i--){
    int j=(int)random(i+1);
    int t=a[i]; a[i]=a[j]; a[j]=t;
  }
}

// ------------------ Save / Load ------------------
String sanitizeName(String nm){
  if(nm==null) return "";
  String t = trim(nm);
  String out="";
  for(int i=0;i<t.length();i++){
    char ch=t.charAt(i);
    if((ch>='a'&&ch<='z')||(ch>='A'&&ch<='Z')||(ch>='0'&&ch<='9')) out += ch;
    else if(ch==' '||ch=='_'||ch=='-') out += '_';
  }
  while(out.indexOf("__")>=0) out = out.replace("__","_");
  while(out.startsWith("_")) out = out.substring(1);
  while(out.endsWith("_")) out = out.substring(0,out.length()-1);
  return out;
}
String saveFileForName(String nm){
  String s = sanitizeName(nm);
  if(s.length()==0) s="kid";
  return "kidmath_"+s+".json";
}

void saveGame(){
  kidName = tbName.value;
  String file = saveFileForName(kidName);

  JSONObject root = new JSONObject();
  root.setString("kidName", kidName);
  root.setInt("gradeLevel", gradeLevel);
  root.setInt("gridSize", gridSize);
  root.setString("currentOp", currentOp.name());

  root.setInt("level", level);
  root.setInt("triesThisLevel", triesThisLevel);
  root.setInt("correctThisLevel", correctThisLevel);
  root.setInt("resetStage", resetStage);

  JSONArray jr=new JSONArray();
  JSONArray jc=new JSONArray();
  for(int i=0;i<gridSize;i++){ jr.setInt(i, rows[i]); jc.setInt(i, cols[i]); }
  root.setJSONArray("rows", jr);
  root.setJSONArray("cols", jc);

  JSONArray js=new JSONArray();
  JSONArray jv=new JSONArray();
  int idx=0;
  for(int r=0;r<gridSize;r++){
    for(int c=0;c<gridSize;c++){
      js.setInt(idx, cellState[r][c]);
      float v = chosen[r][c];
      if(Float.isNaN(v)) jv.setString(idx, "NaN");
      else jv.setFloat(idx, v);
      idx++;
    }
  }
  root.setJSONArray("cellState", js);
  root.setJSONArray("chosen", jv);

  saveJSONObject(root, file);
}

void loadGame(){
  kidName = tbName.value;
  String file = saveFileForName(kidName);

  JSONObject root = null;
  try { root = loadJSONObject(file); } catch(Exception e) { root = null; }
  if(root == null) return;

  kidName = root.getString("kidName", kidName);
  tbName.value = kidName;

  gradeLevel = constrain(root.getInt("gradeLevel", 3), 3, 8);
  gridSize = root.getInt("gridSize", 10);
  if(gridSize!=10 && gridSize!=12 && gridSize!=16 && gridSize!=20) gridSize=10;

  ddGrade.selected = gradeLevel - 3;
  ddGrid.selected  = (gridSize==10?0:gridSize==12?1:gridSize==16?2:3);

  String opName = root.getString("currentOp", "ADD");
  try { currentOp = Op.valueOf(opName); } catch(Exception e){ currentOp = Op.ADD; }
  ensureOpAllowed();

  level = root.getInt("level", 1);
  triesThisLevel = root.getInt("triesThisLevel", 0);
  correctThisLevel = root.getInt("correctThisLevel", 0);
  resetStage = root.getInt("resetStage", 0);

  rows = new int[gridSize];
  cols = new int[gridSize];
  allocateCells();

  JSONArray jr = root.getJSONArray("rows");
  JSONArray jc = root.getJSONArray("cols");
  for(int i=0;i<gridSize;i++){
    rows[i] = (jr!=null && i<jr.size()) ? jr.getInt(i) : (1+i);
    cols[i] = (jc!=null && i<jc.size()) ? jc.getInt(i) : (1+i);
  }

  JSONArray js = root.getJSONArray("cellState");
  JSONArray jv = root.getJSONArray("chosen");
  int idx=0;
  for(int r=0;r<gridSize;r++){
    for(int c=0;c<gridSize;c++){
      cellState[r][c] = (js!=null && idx<js.size()) ? js.getInt(idx) : 0;

      chosen[r][c] = Float.NaN;
      if(jv!=null && idx<jv.size()){
        try { chosen[r][c] = jv.getFloat(idx); }
        catch(Exception e){
          String s = jv.getString(idx, "NaN");
          chosen[r][c] = "NaN".equals(s) ? Float.NaN : Float.NaN;
        }
      }
      idx++;
    }
  }

  rebuildOpButtons();
  showDialog=false;
  showingCertificate=false;
  sparks.clear();
  confetti.clear();
  fireworksTimer=0;
}


// draw a star centered at x,y
void star(float x, float y, float radius1, float radius2, int npoints) {
  float angle = TWO_PI / npoints;
  float halfAngle = angle / 2.0;
  beginShape();
  for (float a = -HALF_PI; a < TWO_PI - HALF_PI; a += angle) {
    float sx = x + cos(a) * radius1;
    float sy = y + sin(a) * radius1;
    vertex(sx, sy);
    sx = x + cos(a + halfAngle) * radius2;
    sy = y + sin(a + halfAngle) * radius2;
    vertex(sx, sy);
  }
  endShape(CLOSE);
}

// ------------------ Small utils ------------------
int clamp(int v, int lo, int hi){ return max(lo, min(hi, v)); }
