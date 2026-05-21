// Pi Cubed-like Expression Builder (Processing / Java mode)
// v2: smarter layout, superscripts, fraction centering, parentheses rules,
// undo/redo, LaTeX + ASCII export, PNG snapshot.
//
// Keys: E (LaTeX), A (ASCII), Z (undo), Y (redo), R (reset), P (save PNG)
// Click gray boxes to select; click templates to insert; type numbers/letters.
// Backspace/Delete to revert selection to a box. Arrows navigate.
//
// ------------------------------------------------------------

PFont font;
ExprNode root;
ExprNode focus;               // any selected node (placeholder or not)
PlaceholderNode focusBox;     // if current focus is a placeholder
ArrayList<PaletteItem> palette = new ArrayList<PaletteItem>();
int paletteW = 170;
int margin = 16;

// --- undo/redo stacks (store serialized expression trees) ---
ArrayList<String> undoStack = new ArrayList<String>();
ArrayList<String> redoStack = new ArrayList<String>();

void settings(){ size(1100, 640); }
void setup(){
  font = createFont("Arial", 18);
  textFont(font);
  initPalette();
  resetExpr();
  surface.setTitle("Pi Cubed-like Expression Builder");
}
void draw(){
  background(248);
  drawPalette();
  drawCanvas();
  drawHelp();
}

void pushUndo(){
  undoStack.add(serialize(root, true));
  if (undoStack.size() > 100) undoStack.remove(0);
  redoStack.clear();
}

void undo(){
  if (undoStack.isEmpty()) return;
  String cur = serialize(root, true);
  redoStack.add(cur);
  String prev = undoStack.remove(undoStack.size()-1);
  root = deserialize(prev);
  focus = root;
  focusBox = (root instanceof PlaceholderNode)?(PlaceholderNode)root:null;
}
void redo(){
  if (redoStack.isEmpty()) return;
  String cur = serialize(root, true);
  undoStack.add(cur);
  String nxt = redoStack.remove(redoStack.size()-1);
  root = deserialize(nxt);
  focus = root;
  focusBox = (root instanceof PlaceholderNode)?(PlaceholderNode)root:null;
}

// ---------------- Palette ----------------
enum Template { NUMBER, VARIABLE, ADD, SUB, MUL, DIV, FRAC, POW, ROOT, SIN, COS, TAN, LN, EXP }
class PaletteItem { Template t; String label; PaletteItem(Template t,String label){this.t=t;this.label=label;} }

void initPalette(){
  palette.clear();
  palette.add(new PaletteItem(Template.NUMBER,   "Number"));
  palette.add(new PaletteItem(Template.VARIABLE, "Variable"));
  palette.add(new PaletteItem(Template.ADD,      "a + b"));
  palette.add(new PaletteItem(Template.SUB,      "a − b"));
  palette.add(new PaletteItem(Template.MUL,      "a · b"));
  palette.add(new PaletteItem(Template.DIV,      "a ÷ b"));
  palette.add(new PaletteItem(Template.FRAC,     "Fraction a/b"));
  palette.add(new PaletteItem(Template.POW,      "Power a^b"));
  palette.add(new PaletteItem(Template.ROOT,     "√(a)"));
  palette.add(new PaletteItem(Template.SIN,      "sin(a)"));
  palette.add(new PaletteItem(Template.COS,      "cos(a)"));
  palette.add(new PaletteItem(Template.TAN,      "tan(a)"));
  palette.add(new PaletteItem(Template.LN,       "ln(a)"));
  palette.add(new PaletteItem(Template.EXP,      "exp(a)"));
}

void drawPalette(){
  noStroke(); fill(235); rect(0,0,paletteW,height);
  fill(30); textAlign(LEFT,TOP); textSize(20); text("Templates",12,10);
  textSize(18);
  int y=48;
  for (PaletteItem it : palette){
    int x=10,w=paletteW-20,h=34;
    boolean hover = mouseX>=x && mouseX<=x+w && mouseY>=y && mouseY<=y+h;
    fill(hover? color(210,225,255) : 250); stroke(180); rect(x,y,w,h,6);
    fill(40); noStroke(); textAlign(LEFT,CENTER); text(it.label,x+10,y+h*0.5);
    y += h+8;
  }
}

PaletteItem paletteAt(int mx,int my){
  int y=48,x=10,w=paletteW-20,h=34;
  for (PaletteItem it:palette){
    if (mx>=x && mx<=x+w && my>=y && my<=y+h) return it;
    y += h+8;
  }
  return null;
}

// --------------- Expression Tree ---------------
abstract class ExprNode {
  ExprNode parent;
  float x,y,w,h,baseline;
  abstract void layout();
  abstract void draw();
  abstract PlaceholderNode findPlaceholderAt(float mx,float my);
  abstract ExprNode findNodeAt(float mx,float my);
  abstract String toTex();
  abstract String toAscii();
  abstract String kind(); // for serialization
  int precedence(){ return 10; } // lower = binds weaker; used for parens
}

class PlaceholderNode extends ExprNode {
  @Override void layout(){ w=44; h=34; baseline=h*0.7; }
  @Override void draw(){
    stroke( (this==focusBox)? color(30,120,255):150 );
    strokeWeight( (this==focusBox)? 2:1 );
    fill(235); rect(x,y,w,h,6);
    fill(140); noStroke(); textAlign(CENTER,CENTER); text("+",x+w/2,y+h/2);
    strokeWeight(1);
  }
  @Override PlaceholderNode findPlaceholderAt(float mx,float my){
    return (mx>=x && mx<=x+w && my>=y && my<=y+h)? this:null;
  }
  @Override ExprNode findNodeAt(float mx,float my){
    return (mx>=x && mx<=x+w && my>=y && my<=y+h)? this:null;
  }
  @Override String toTex(){ return "\\Box"; }
  @Override String toAscii(){ return "□"; }
  @Override String kind(){ return "ph"; }
}

class NumberNode extends ExprNode {
  String value="0";
  NumberNode(String v){ value=v; }
  @Override void layout(){ textSize(20); w=textWidth(value)+14; h=28; baseline=h*0.75; }
  @Override void draw(){
    boolean sel=(focus==this);
    fill(sel? color(255,255,220):255); stroke(sel? color(30,120,255):180);
    rect(x,y,w,h,6);
    fill(20); noStroke(); textAlign(CENTER,CENTER); text(value, x+w/2,y+h*0.52);
  }
  @Override PlaceholderNode findPlaceholderAt(float mx,float my){ return null; }
  @Override ExprNode findNodeAt(float mx,float my){
    return (mx>=x && mx<=x+w && my>=y && my<=y+h)? this:null;
  }
  @Override String toTex(){ return value; }
  @Override String toAscii(){ return value; }
  @Override String kind(){ return "num:"+value; }
  @Override int precedence(){ return 100; }
}

class VariableNode extends ExprNode {
  String name="x";
  VariableNode(String n){ name=n; }
  @Override void layout(){ textSize(20); w=textWidth(name)+14; h=28; baseline=h*0.75; }
  @Override void draw(){
    boolean sel=(focus==this);
    fill(sel? color(255,255,220):255); stroke(sel? color(30,120,255):180);
    rect(x,y,w,h,6);
    fill(20); noStroke(); textAlign(CENTER,CENTER); text(name, x+w/2,y+h*0.52);
  }
  @Override PlaceholderNode findPlaceholderAt(float mx,float my){ return null; }
  @Override ExprNode findNodeAt(float mx,float my){
    return (mx>=x && mx<=x+w && my>=y && my<=y+h)? this:null;
  }
  @Override String toTex(){ return name; }
  @Override String toAscii(){ return name; }
  @Override String kind(){ return "var:"+name; }
  @Override int precedence(){ return 100; }
}

abstract class UnaryNode extends ExprNode {
  ExprNode a;
  abstract String op();    // "sin","cos","tan","ln","exp","√"
  abstract boolean drawsRadical();
  @Override void layout(){
    a.layout();
    textSize(20);
    float labelW = drawsRadical()? textWidth("√") : textWidth(op())+6;
    w = labelW + 8 + a.w + 10;
    h = max(a.h, 30) + 6;
    baseline = max(a.baseline, h*0.7);
  }
  @Override void draw(){
    boolean sel=(focus==this);
    float labelW = drawsRadical()? textWidth("√") : textWidth(op())+6;
    fill(sel? color(255,255,220):255); stroke(sel? color(30,120,255):180);
    rect(x,y,labelW+10,h,6);
    fill(20); noStroke(); textAlign(LEFT,CENTER);
    text(drawsRadical()? "√":op(), x+6, y+h*0.52);
    a.x = x + labelW + 14; a.y = y + (h - a.h)/2; a.draw();
    if (drawsRadical()){
      stroke(20); float ry = y + h*0.65;
      line(x+labelW+6, ry, a.x, ry);
    }
  }
  @Override PlaceholderNode findPlaceholderAt(float mx,float my){ return a.findPlaceholderAt(mx,my); }
  @Override ExprNode findNodeAt(float mx,float my){
    if (mx>=x && mx<=x+w && my>=y && my<=y+h) return this;
    return a.findNodeAt(mx,my);
  }
  @Override String toTex(){
    if (op().equals("√")) return "\\sqrt{"+a.toTex()+"}";
    return "\\"+op()+"\\left("+a.toTex()+"\\right)";
  }
  @Override String toAscii(){
    if (op().equals("√")) return "sqrt("+a.toAscii()+")";
    return op()+"("+a.toAscii()+")";
  }
  @Override int precedence(){ return 90; }
}

class SqrtNode extends UnaryNode { SqrtNode(ExprNode a){this.a=a;a.parent=this;} String op(){return "√";} boolean drawsRadical(){return true;} }
class FuncNode extends UnaryNode { String name; FuncNode(String n,ExprNode a){name=n;this.a=a;a.parent=this;} String op(){return name;} boolean drawsRadical(){return false;} }

abstract class BinaryNode extends ExprNode {
  ExprNode a,b;
  abstract String sym();  // "+","−","·","÷","^" (power handled by subclass)
  abstract int myPrec();  // precedence: +/− 10, ·/÷ 20, ^ 40
  @Override int precedence(){ return myPrec(); }

  @Override void layout(){
    a.layout(); b.layout();
    textSize(20);
    float sw = textWidth(sym())+16;
    w = a.w + sw + b.w + 10;
    h = max(max(a.h,b.h), 30) + 6;
    baseline = max(a.baseline, b.baseline);
  }

  boolean needParensLeft(){ return a.precedence() < this.precedence(); }
  boolean needParensRight(){ 
    // right-associativity tweak: for subtraction/division keep parens on equal prec
    int rp = b.precedence();
    if (sym().equals("−") || sym().equals("÷")) return rp <= this.precedence();
    return rp < this.precedence();
  }

  @Override void draw(){
    boolean sel=(focus==this);
    // left (with optional parens)
    float lx = x+4, ly = y + (h - a.h)/2;
    if (needParensLeft()){
      drawParen(lx, y, a, true); // left paren
      lx += 16;
    }
    a.x = lx; a.y = ly; a.draw();
    float afterLeft = a.x + a.w + (needParensLeft()? 16:0);

    // operator box
    float sw = textWidth(sym())+16;
    float sx = afterLeft + 4;
    fill(sel? color(255,255,220):255); stroke(sel? color(30,120,255):180);
    rect(sx,y,sw,h,6);
    fill(20); noStroke(); textAlign(CENTER,CENTER);
    text(sym(), sx+sw/2, y+h*0.52);

    // right (with optional parens)
    float rx = sx + sw + 4;
    if (needParensRight()){
      drawParen(rx, y, b, false); // right side will be inside
      rx += 16;
      b.x = rx; b.y = y + (h - b.h)/2; b.draw();
      // closing paren
      float px = b.x + b.w;
      drawSingleParen(px, y, false);
    } else {
      b.x = rx; b.y = y + (h - b.h)/2; b.draw();
    }
    // if we opened left paren, close it
    if (needParensLeft()){
      float px = a.x - 16;
      drawSingleParen(px, y, true);
    }
  }

  void drawParen(float px, float py, ExprNode n, boolean left){
    drawSingleParen(px, py, left);
  }
  void drawSingleParen(float px, float py, boolean left){
    noFill(); stroke(60);
    float top = py+6, bot = py + h - 6;
    if (left){
      bezier(px+12,top, px+2,top+10, px+2,bot-10, px+12,bot);
    } else {
      bezier(px,top, px+10,top+10, px+10,bot-10, px,bot);
    }
  }

  @Override PlaceholderNode findPlaceholderAt(float mx,float my){
    PlaceholderNode p=a.findPlaceholderAt(mx,my);
    if (p!=null) return p;
    return b.findPlaceholderAt(mx,my);
  }
  @Override ExprNode findNodeAt(float mx,float my){
    if (mx>=x && mx<=x+w && my>=y && my<=y+h) return this;
    ExprNode r=a.findNodeAt(mx,my); if (r!=null) return r;
    return b.findNodeAt(mx,my);
  }
  @Override String toTex(){
    String L = (needParensLeft()? "\\left("+a.toTex()+"\\right)" : a.toTex());
    String R = (needParensRight()? "\\left("+b.toTex()+"\\right)" : b.toTex());
    if (sym().equals("^")) return L + "^{" + R + "}";
    if (sym().equals("÷")) return "\\frac{"+a.toTex()+"}{"+b.toTex()+"}";
    return "("+L+" "+sym()+" "+R+")";
  }
  @Override String toAscii(){
    String L = (needParensLeft()? "("+a.toAscii()+")" : a.toAscii());
    String R = (needParensRight()? "("+b.toAscii()+")" : b.toAscii());
    if (sym().equals("^")) return L + "^(" + R + ")";
    if (sym().equals("÷")) return "(" + a.toAscii() + ")/(" + b.toAscii() + ")";
    return L + " " + sym() + " " + R;
  }
}

class AddNode extends BinaryNode { AddNode(ExprNode a,ExprNode b){this.a=a;this.b=b;a.parent=this;b.parent=this;} String sym(){return "+";} int myPrec(){return 10;} }
class SubNode extends BinaryNode { SubNode(ExprNode a,ExprNode b){this.a=a;this.b=b;a.parent=this;b.parent=this;} String sym(){return "−";} int myPrec(){return 10;} }
class MulNode extends BinaryNode { MulNode(ExprNode a,ExprNode b){this.a=a;this.b=b;a.parent=this;b.parent=this;} String sym(){return "·";} int myPrec(){return 20;} }
class DivNode extends BinaryNode { DivNode(ExprNode a,ExprNode b){this.a=a;this.b=b;a.parent=this;b.parent=this;} String sym(){return "÷";} int myPrec(){return 20;} }

class PowNode extends BinaryNode {
  PowNode(ExprNode a,ExprNode b){ this.a=a; this.b=b; a.parent=this; b.parent=this; }
  String sym(){ return "^"; }
  int myPrec(){ return 40; }
  @Override void layout(){
    a.layout(); b.layout();
    float supScale = 0.8;
    w = a.w + 8 + b.w*supScale + 12;
    h = max(a.h, b.h) + 6;
    baseline = a.baseline;
  }
  @Override void draw(){
    boolean sel=(focus==this);
    a.x = x+4; a.y = y + (h - a.h)/2; a.draw();
    // superscript box
    float supScale = 0.8;
    float bx = a.x + a.w + 6;
    float by = a.y - 10;
    pushMatrix();
    translate(bx, by);
    scale(supScale);
    if (sel){ stroke(color(30,120,255)); fill(color(255,255,220)); rect(-4,-4,b.w+8,b.h+8,6); }
    b.x = 0; b.y = 0; b.draw();
    popMatrix();
  }
  @Override String toTex(){
    String L = (a.precedence() < this.precedence()? "\\left("+a.toTex()+"\\right)" : a.toTex());
    return L + "^{" + b.toTex() + "}";
  }
  @Override String toAscii(){
    String L = (a.precedence() < this.precedence()? "("+a.toAscii()+")" : a.toAscii());
    return L + "^(" + b.toAscii() + ")";
  }
}

// ------------ Tree utils / Editing ------------
void resetExpr(){
  root = new PlaceholderNode();
  root.parent = null;
  focus = root;
  focusBox = (PlaceholderNode)root;
  undoStack.clear(); redoStack.clear();
  pushUndo();
}

void drawCanvas(){
  float cx = paletteW + (width - paletteW)/2.0;
  float cy = height/2.0 - 30;
  root.layout();
  root.x = cx - root.w/2;
  root.y = cy - root.h/2;
  root.draw();

  fill(30); textAlign(LEFT,TOP); textSize(22);
  text("Expression", paletteW + margin, 10);
  textSize(18);
}

void drawHelp(){
  fill(40); textAlign(LEFT,TOP); textSize(14);
  String s = "Click a gray box then a template. Type digits/letters.\n" +
             "Backspace/Delete: box   Arrows: navigate   Up: parent\n" +
             "E: LaTeX   A: ASCII   Z/Y: undo/redo   R: reset   P: PNG";
  text(s, paletteW + margin, height - 80);
}

void replaceAt(PlaceholderNode p, ExprNode n){
  if (p==null || n==null) return;
  n.parent = p.parent;
  if (p.parent==null) root = n;
  else if (p.parent instanceof UnaryNode){
    UnaryNode u=(UnaryNode)p.parent; if (u.a==p) u.a=n;
  } else if (p.parent instanceof BinaryNode){
    BinaryNode b=(BinaryNode)p.parent; if (b.a==p) b.a=n; if (b.b==p) b.b=n;
  }
  else if (p.parent instanceof FracNode){
    FracNode f=(FracNode)p.parent; if (f.num==p) f.num=n; if (f.den==p) f.den=n;
  }
  // new focus: first placeholder inside n, else n
  PlaceholderNode first = firstPlaceholder(n);
  if (first!=null){ focusBox=first; focus=first; } else { focus=n; focusBox=null; }
  pushUndo();
}

PlaceholderNode firstPlaceholder(ExprNode node){
  if (node instanceof PlaceholderNode) return (PlaceholderNode)node;
  if (node instanceof UnaryNode) return firstPlaceholder(((UnaryNode)node).a);
  if (node instanceof BinaryNode){
    PlaceholderNode p = firstPlaceholder(((BinaryNode)node).a);
    if (p!=null) return p;
    return firstPlaceholder(((BinaryNode)node).b);
  }
  if (node instanceof FracNode){
    PlaceholderNode p = firstPlaceholder(((FracNode)node).num);
    if (p!=null) return p;
    return firstPlaceholder(((FracNode)node).den);
  }
  return null;
}

void insertTemplateAt(PlaceholderNode p, Template t){
  switch(t){
    case NUMBER:   replaceAt(p, new NumberNode("0")); break;
    case VARIABLE: replaceAt(p, new VariableNode("x")); break;
    case ADD: replaceAt(p, new AddNode(new PlaceholderNode(), new PlaceholderNode())); break;
    case SUB: replaceAt(p, new SubNode(new PlaceholderNode(), new PlaceholderNode())); break;
    case MUL: replaceAt(p, new MulNode(new PlaceholderNode(), new PlaceholderNode())); break;
    case DIV: replaceAt(p, new DivNode(new PlaceholderNode(), new PlaceholderNode())); break;
    case FRAC: replaceAt(p, new FracNode(new PlaceholderNode(), new PlaceholderNode())); break;
    case POW: replaceAt(p, new PowNode(new PlaceholderNode(), new PlaceholderNode())); break;
    case ROOT: replaceAt(p, new SqrtNode(new PlaceholderNode())); break;
    case SIN: replaceAt(p, new FuncNode("sin", new PlaceholderNode())); break;
    case COS: replaceAt(p, new FuncNode("cos", new PlaceholderNode())); break;
    case TAN: replaceAt(p, new FuncNode("tan", new PlaceholderNode())); break;
    case LN:  replaceAt(p, new FuncNode("ln",  new PlaceholderNode())); break;
    case EXP: replaceAt(p, new FuncNode("exp", new PlaceholderNode())); break;
  }
}

void replaceWithPlaceholder(ExprNode n){
  if (n==null) return;
  if (n.parent==null){ resetExpr(); return; }
  PlaceholderNode ph = new PlaceholderNode();
  ph.parent = n.parent;
  if (n.parent instanceof UnaryNode){
    UnaryNode u=(UnaryNode)n.parent; if (u.a==n) u.a=ph;
  } else if (n.parent instanceof BinaryNode){
    BinaryNode b=(BinaryNode)n.parent; if (b.a==n) b.a=ph; if (b.b==n) b.b=ph;
  } else if (n.parent instanceof FracNode){
    FracNode f=(FracNode)n.parent; if (f.num==n) f.num=ph; if (f.den==n) f.den=ph;
  }
  focus = ph; focusBox = ph;
  pushUndo();
}

// ------------- Fraction Node (pretty bar) -------------
class FracNode extends ExprNode {
  ExprNode num, den;
  FracNode(ExprNode n, ExprNode d){ num=n; den=d; n.parent=this; d.parent=this; }
  @Override void layout(){
    num.layout(); den.layout();
    float barW = max(num.w, den.w) + 18;
    w = barW + 10;
    h = num.h + den.h + 22;
    baseline = num.h + 11;
  }
  @Override void draw(){
    boolean sel=(focus==this);
    float cx = x + w/2;
    num.x = cx - num.w/2; num.y = y + 4; num.draw();
    stroke(sel? color(30,120,255) : 20);
    line(x+6, y + num.h + 10, x + w - 6, y + num.h + 10);
    den.x = cx - den.w/2; den.y = y + num.h + 12; den.draw();
    if (sel){ noFill(); stroke(30,120,255); rect(x+2,y+2,w-4,h-4,6); }
  }
  @Override PlaceholderNode findPlaceholderAt(float mx,float my){
    PlaceholderNode p=num.findPlaceholderAt(mx,my);
    if (p!=null) return p;
    return den.findPlaceholderAt(mx,my);
  }
  @Override ExprNode findNodeAt(float mx,float my){
    if (mx>=x && mx<=x+w && my>=y && my<=y+h) return this;
    ExprNode r=num.findNodeAt(mx,my); if (r!=null) return r;
    return den.findNodeAt(mx,my);
  }
  @Override String toTex(){ return "\\frac{"+num.toTex()+"}{"+den.toTex()+"}"; }
  @Override String toAscii(){ return "("+num.toAscii()+")/("+den.toAscii()+")"; }
  @Override String kind(){ return "frac"; }
  @Override int precedence(){ return 20; }
}

// ------------- Picking & Input -------------
void mousePressed(){
  if (mouseX < paletteW){
    PaletteItem it = paletteAt(mouseX, mouseY);
    if (it != null){
      if (focusBox != null) insertTemplateAt(focusBox, it.t);
      else if (focus instanceof PlaceholderNode) insertTemplateAt((PlaceholderNode)focus, it.t);
    }
  } else {
    ExprNode hit = root.findNodeAt(mouseX, mouseY);
    focus = hit!=null? hit : root;
    focusBox = (focus instanceof PlaceholderNode)? (PlaceholderNode)focus : null;
  }
}

void keyTyped(){
  if (key==CODED || key==BACKSPACE || key==DELETE || key==ENTER || key==RETURN) return;
  char c = key;
  if (focusBox != null){
    if ((c>='0' && c<='9') || c=='.') replaceAt(focusBox, new NumberNode(""+c));
    else if (isLetter(c))              replaceAt(focusBox, new VariableNode(""+c));
    return;
  }
  if (focus instanceof NumberNode){
    NumberNode n=(NumberNode)focus;
    if ((c>='0' && c<='9') || c=='.'){ n.value += c; }
  } else if (focus instanceof VariableNode){
    VariableNode v=(VariableNode)focus;
    if (isLetter(c)) v.name += c;
  }
}
boolean isLetter(char c){ return (c>='a'&&c<='z')||(c>='A'&&c<='Z'); }

void keyPressed(){
  if (key==BACKSPACE || key==DELETE){ replaceWithPlaceholder(focus); return; }
  if (key=='r'||key=='R'){ resetExpr(); return; }
  if (key=='z'||key=='Z'){ undo(); return; }
  if (key=='y'||key=='Y'){ redo(); return; }
  if (key=='e'||key=='E'){ println("LaTeX: "+ root.toTex()); return; }
  if (key=='a'||key=='A'){ println("ASCII: "+ root.toAscii()); return; }
  if (key=='p'||key=='P'){ saveFrame("pi-cubed-like-####.png"); println("Saved PNG."); return; }

  if (keyCode==UP) { selectParent(); return; }
  if (keyCode==LEFT){ selectSibling(-1); return; }
  if (keyCode==RIGHT){ selectSibling(1); return; }
}

void selectParent(){
  if (focus!=null && focus.parent!=null){
    focus = focus.parent;
    focusBox = (focus instanceof PlaceholderNode)? (PlaceholderNode)focus : null;
  }
}
void selectSibling(int dir){
  if (focus==null || focus.parent==null) return;
  ExprNode p = focus.parent;
  if (p instanceof BinaryNode){
    BinaryNode b=(BinaryNode)p;
    focus = (focus==b.a)? b.b : b.a;
  } else if (p instanceof FracNode){
    FracNode f=(FracNode)p;
    focus = (focus==f.num)? f.den : f.num;
  } else if (p instanceof UnaryNode){
    focus = p; // climb to parent
  }
  focusBox = (focus instanceof PlaceholderNode)? (PlaceholderNode)focus : null;
}

// ------------- Serialization (for undo/redo) -------------
String serialize(ExprNode n, boolean top){
  if (n instanceof PlaceholderNode) return "ph";
  if (n instanceof NumberNode) return "num:"+((NumberNode)n).value;
  if (n instanceof VariableNode) return "var:"+((VariableNode)n).name;
  if (n instanceof AddNode) return "add("+serialize(((AddNode)n).a,false)+","+serialize(((AddNode)n).b,false)+")";
  if (n instanceof SubNode) return "sub("+serialize(((SubNode)n).a,false)+","+serialize(((SubNode)n).b,false)+")";
  if (n instanceof MulNode) return "mul("+serialize(((MulNode)n).a,false)+","+serialize(((MulNode)n).b,false)+")";
  if (n instanceof DivNode) return "div("+serialize(((DivNode)n).a,false)+","+serialize(((DivNode)n).b,false)+")";
  if (n instanceof PowNode) return "pow("+serialize(((PowNode)n).a,false)+","+serialize(((PowNode)n).b,false)+")";
  if (n instanceof SqrtNode) return "sqrt("+serialize(((SqrtNode)n).a,false)+")";
  if (n instanceof FuncNode) return "fun:"+((FuncNode)n).name+"("+serialize(((FuncNode)n).a,false)+")";
  if (n instanceof FracNode) return "frac("+serialize(((FracNode)n).num,false)+","+serialize(((FracNode)n).den,false)+")";
  return "ph";
}

ExprNode deserialize(String s){
  // very small parser for our simple format
  s = s.trim();
  if (s.equals("ph")) return new PlaceholderNode();
  if (s.startsWith("num:")) return new NumberNode(s.substring(4));
  if (s.startsWith("var:")) return new VariableNode(s.substring(4));
  if (s.startsWith("sqrt(")) return new SqrtNode(deserialize(innerOne(s)));
  if (s.startsWith("fun:")){
    int p = s.indexOf('(');
    String name = s.substring(4, p);
    String body = s.substring(p);
    return new FuncNode(name, deserialize(innerOne(body)));
  }
  if (s.startsWith("add(")) return binFrom("add", s);
  if (s.startsWith("sub(")) return binFrom("sub", s);
  if (s.startsWith("mul(")) return binFrom("mul", s);
  if (s.startsWith("div(")) return binFrom("div", s);
  if (s.startsWith("pow(")) return binFrom("pow", s);
  if (s.startsWith("frac(")){
    String[] ab = splitTopTwo(s.substring(5, s.length()-1));
    FracNode f = new FracNode(deserialize(ab[0]), deserialize(ab[1]));
    return f;
  }
  return new PlaceholderNode();
}
ExprNode binFrom(String tag, String s){
  String body = s.substring(tag.length()+1, s.length()-1);
  String[] ab = splitTopTwo(body);
  ExprNode A = deserialize(ab[0]), B = deserialize(ab[1]);
  if (tag.equals("add")) return new AddNode(A,B);
  if (tag.equals("sub")) return new SubNode(A,B);
  if (tag.equals("mul")) return new MulNode(A,B);
  if (tag.equals("div")) return new DivNode(A,B);
  if (tag.equals("pow")) return new PowNode(A,B);
  return new AddNode(A,B);
}
String innerOne(String s){
  // assumes format f( ... )
  int i=s.indexOf('('), j=s.lastIndexOf(')');
  return s.substring(i+1, j);
}
String[] splitTopTwo(String s){
  int depth=0, cut=-1;
  for (int i=0;i<s.length();i++){
    char c=s.charAt(i);
    if (c=='(') depth++;
    else if (c==')') depth--;
    else if (c==',' && depth==0){ cut=i; break; }
  }
  if (cut==-1) return new String[]{s,"ph"};
  return new String[]{ s.substring(0,cut), s.substring(cut+1) };
}
