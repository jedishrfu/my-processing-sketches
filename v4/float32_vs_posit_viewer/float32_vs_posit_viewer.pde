// Float vs Posit Bit Visualizer — final (no "Value:" label next to float32 register)
// ----------------------------------------------------------------------------------
// • Click Value box to edit; caret blinks on focus (loop), stops on blur (noLoop).
// • Apply/Enter/blur commits; both IEEE-754 and Posit update immediately.
// • Bit rows pushed down for clear labels; alternating posit labels avoid overlap.
// • pushStyle()/popStyle() isolation to prevent title drift.
// • Exponent bits shrink as regime length grows: eBits = min(es, remaining).

float value = 1.2345;
int   n = 16;
int   es = 3;    // adjust as desired
int   k = 0;

PFont mono;

// UI layout
ArrayList<Button> buttons = new ArrayList<Button>();
ValueField valueField;
int panelX = 20, panelY = 72, panelW = 1080, panelH = 116;
int btnRowY;

Button btnDiv2, btnMul2, btnZero, btnOne;
Button btnKm, btnKp, btnNm, btnNp, btnEsm, btnEsp, btnApply;

void settings() { size(1180, 720); }

void setup() {
  mono = createFont("Menlo", 14, true);
  textFont(mono);
  surface.setTitle("Float vs Posit Visualizer — Value: click to edit, Enter/Apply to commit");
  buildUI();
  noLoop();
}

void buildUI() {
  buttons.clear();
  int x = panelX + 14;
  int y = panelY + 46;
  btnRowY = y;
  int pad = 12;
  int bw = 52, bh = 28;

  // Value field (label removed inside display())
  valueField = new ValueField(x, y, 220, bh);
  x += 220 + 6;

  // Apply
  btnApply = new Button("Apply", x, y, 70, bh, () -> { valueField.commit(); redraw(); });
  buttons.add(btnApply);
  x += 70 + pad;

  // Value action buttons
  btnDiv2 = new Button("÷2", x, y, bw, bh, () -> { value *= 0.5f; redraw(); });
  buttons.add(btnDiv2); x += bw + 6;

  btnMul2 = new Button("×2", x, y, bw, bh, () -> { value *= 2.0f; redraw(); });
  buttons.add(btnMul2); x += bw + 6;

  btnZero = new Button("0", x, y, 42, bh, () -> { value = 0.0f; redraw(); });
  buttons.add(btnZero); x += 42 + 6;

  btnOne = new Button("1", x, y, 42, bh, () -> { value = 1.0f; redraw(); });
  buttons.add(btnOne); x += 42 + 20;

  // k group
  btnKm = new Button("k−", x, y, bw, bh, () -> { k--; redraw(); });
  buttons.add(btnKm); x += bw + 6;

  btnKp = new Button("k+", x, y, bw, bh, () -> { k++; redraw(); });
  buttons.add(btnKp); x += bw + 24;

  // n group
  btnNm = new Button("n−", x, y, bw, bh, () -> { n = max(4, n-1); redraw(); });
  buttons.add(btnNm); x += bw + 6;

  btnNp = new Button("n+", x, y, bw, bh, () -> { n = min(32, n+1); redraw(); });
  buttons.add(btnNp); x += bw + 24;

  // es group
  btnEsm = new Button("es−", x, y, bw, bh, () -> { es = max(0, es-1); redraw(); });
  buttons.add(btnEsm); x += bw + 6;

  btnEsp = new Button("es+", x, y, bw, bh, () -> { es = min(6, es+1); redraw(); });
  buttons.add(btnEsp);
}

void draw() {
  background(18);

  // Header
  pushStyle();
  textAlign(LEFT, BASELINE);
  fill(240); textSize(20);
  text("Float vs Posit Bit Visualizer", 20, 34);
  textSize(13); fill(200);
  text("Click the Value box to edit (Enter/Apply/blur to commit). Buttons adjust k, n, es, or value.", 20, 54);
  popStyle();

  drawControlPanel();

  int rowH = 106;
  int y0 = panelY + panelH + 20;

  drawFloatBits(24, y0 + 10, width - 48, rowH);
  drawPositBits(24, y0 + rowH + 78, width - 48, rowH);
}

void drawControlPanel() {
  pushStyle();
  noStroke();
  fill(30, 30, 36);
  rect(panelX, panelY, panelW, panelH, 12);

  fill(220); textSize(12); textAlign(LEFT, BASELINE);
  text("Value", panelX + 14, panelY + 24); // panel section header

  fill(180);
  text("k = " + k, panelX + 580, panelY + 24);
  text("n = " + n, panelX + 710, panelY + 24);
  text("es = " + es, panelX + 840, panelY + 24);

  valueField.display();
  for (Button b : buttons) b.display();

  // Per-button hints centered under buttons
  fill(150); textSize(11); textAlign(CENTER, TOP);
  text("Enter", btnApply.centerX(), btnRowY + btnApply.h + 4);
  text("-",     btnDiv2.centerX(),  btnRowY + btnDiv2.h  + 4);
  text("=",     btnMul2.centerX(),  btnRowY + btnMul2.h  + 4);
  text("0",     btnZero.centerX(),  btnRowY + btnZero.h  + 4);
  text("1",     btnOne.centerX(),   btnRowY + btnOne.h   + 4);
  text("[",     btnKm.centerX(),    btnRowY + btnKm.h    + 4);
  text("]",     btnKp.centerX(),    btnRowY + btnKp.h    + 4);
  text("n",     btnNm.centerX(),    btnRowY + btnNm.h    + 4);
  text("N",     btnNp.centerX(),    btnRowY + btnNp.h    + 4);
  text("e",     btnEsm.centerX(),   btnRowY + btnEsm.h   + 4);
  text("E",     btnEsp.centerX(),   btnRowY + btnEsp.h   + 4);
  popStyle();
}

void mousePressed() {
  boolean wasFocused = valueField.focused;
  if (valueField.hit(mouseX, mouseY)) {
    valueField.focused = true;
    valueField.caretToEnd();
    loop();          // blink immediately
    redraw();
  } else {
    valueField.focused = false;
    if (wasFocused) { valueField.commit(); redraw(); }
    noLoop();        // stop blinking when unfocused
  }
  for (Button b : buttons) {
    if (b.hit(mouseX, mouseY)) { b.activate(); break; }
  }
}

void keyTyped() {
  if (valueField.focused) {
    if (key == BACKSPACE) { valueField.backspace(); redraw(); return; }
    if ((key >= '0' && key <= '9') || key == '.' || key == '-' || key == '+' || key == 'e' || key == 'E') {
      valueField.insert(key); redraw(); return;
    }
  }
}

void keyPressed() {
  if (valueField.focused) {
    if (keyCode == ENTER || keyCode == RETURN) { valueField.commit(); redraw(); return; }
    if (keyCode == LEFT)  { valueField.moveCaret(-1); redraw(); return; }
    if (keyCode == RIGHT) { valueField.moveCaret(+1); redraw(); return; }
  } else {
    switch (key) {
      case '[': k--; break;
      case ']': k++; break;
      case 'n': n = max(4, n-1); break;
      case 'N': n = min(32, n+1); break;
      case 'e': es = max(0, es-1); break;
      case 'E': es = min(6, es+1); break;
      case '-': value *= 0.5f; break;
      case '=': value *= 2.0f; break;
      case '0': value = 0.0f; break;
      case '1': value = 1.0f; break;
      default:  return;
    }
  }
  redraw();
}

// ---------- Float drawing ----------

void drawFloatBits(int x, int y, int w, int h) {
  int bits = Float.floatToIntBits(value);
  int[] floatBits = new int[32];
  for (int i = 31; i >= 0; --i) floatBits[31 - i] = (bits >>> i) & 1;
  int exp = (bits >>> 23) & 0xFF;
  int frac = bits & 0x7FFFFF;

  float boxW = (w - 120) / 32.0f;
  float boxH = 28;
  int bx = x + 60;
  int by = y + 46;

  // Title removed previously on request? (kept off)
  // pushStyle(); textAlign(LEFT, BASELINE); textSize(16); fill(230);
  // text("IEEE-754 float32", x, y + 4); popStyle();

  // Labels (fixed)
  drawFieldLabelAbove("sign",          color(210, 90, 90),  bx + boxW*0.5f,           by - 14);
  drawFieldLabelAbove("exponent(8)",   color(90, 180, 230), bx + boxW*(1 + 8*0.5f),   by - 14);
  drawFieldLabelAbove("fraction(23)",  color(120, 220, 140),bx + boxW*(9 + 23*0.5f),  by - 14);

  for (int i = 0; i < 32; i++) {
    int bit = floatBits[i];
    int fieldCol = (i == 0) ? color(210, 90, 90)
                    : (i >= 1 && i <= 8) ? color(90, 180, 230)
                    : color(120, 220, 140);
    drawBitBox(bx + i*boxW, by, boxW, boxH, bit, fieldCol);
  }

  pushStyle();
  fill(200); textSize(13); textAlign(LEFT, BASELINE);
  String expInfo = "exp(raw)=" + exp + " (bias 127 → E=" + (exp - 127) + ")";
  String fracInfo = "frac(raw)=0x" + hex(frac, 6);
  text(expInfo + "    " + fracInfo, x, by + boxH + 32);
  popStyle();
}

// ---------- Posit drawing ----------

void drawPositBits(int x, int y, int w, int h) {
  pushStyle();
  textAlign(LEFT, BASELINE);
  textSize(16); fill(230);
  text("Posit (n="+n+", es="+es+", regime k="+k+")", x, y + 4);
  popStyle();

  int[] enc = encodePosit(value, n, es, k);

  float boxW = (w - 120) / (float)n;
  float boxH = 28;
  int bx = x + 60;
  int by = y + 46;

  FieldLayout layout = buildPositLayout(n, es, k);
  if (!layout.valid) {
    pushStyle();
    fill(255, 150, 120);
    textSize(13);
    text("Warning: (n, es, k) leaves little/zero room for exponent/fraction — truncation/padding applied.", x, by + boxH + 34);
    popStyle();
  }

  for (int i = 0; i < n; i++) {
    int bit = enc[i];
    int fieldCol = color(180);
    if (i == 0) fieldCol = color(210, 90, 90);
    else if (i >= layout.rStart && i < layout.rEnd) fieldCol = color(230, 200, 90);
    else if (i >= layout.eStart && i < layout.eEnd) fieldCol = color(90, 180, 230);
    else if (i >= layout.fStart && i < layout.fEnd) fieldCol = color(120, 220, 140);
    drawBitBox(bx + i*boxW, by, boxW, boxH, bit, fieldCol);
  }

  // Alternating labels (avoid collisions)
  float signMid   = bx + boxW*0.5f;
  float regimeMid = bx + boxW*(layout.rStart + max(0, layout.rEnd - layout.rStart)/2.0f);
  float expMid    = bx + boxW*(layout.eStart + max(0, layout.eEnd - layout.eStart)/2.0f);
  float fracMid   = bx + boxW*(layout.fStart + max(0, layout.fEnd - layout.fStart)/2.0f);

  drawFieldLabelAbove("sign",                color(210, 90, 90),  signMid,   by - 14);
  drawFieldLabelBelow("regime(k="+k+")",     color(230, 200, 90),  regimeMid, by + boxH + 14);
  drawFieldLabelAbove("exponent(es="+es+")", color(90, 180, 230),  expMid,    by - 14);
  drawFieldLabelBelow("fraction",            color(120, 220, 140), fracMid,   by + boxH + 14);

  double useed = Math.pow(2.0, 1<<es);
  pushStyle();
  fill(200); textSize(13); textAlign(LEFT, BASELINE);
  text("useed = 2^(2^es) = " + nf((float)useed, 1, 3) + 
       "   (eBits used: " + (layout.eEnd - layout.eStart) + ")", x, by + boxH + 36);
  popStyle();
}

// ---------- Posit encode/layout ----------

int[] encodePosit(float x, int n, int es, int k) {
  int[] out = new int[n];

  if (!Float.isFinite(x)) { // NaR
    out[0] = 1; for (int i = 1; i < n; i++) out[i] = 0; return out;
  }
  if (x == 0.0f) { for (int i = 0; i < n; i++) out[i] = 0; return out; }

  boolean sign = (x < 0);
  double ax = Math.abs((double)x);
  out[0] = sign ? 1 : 0;

  // Regime: k>=0 => k ones then 0;  k<0 => |k| zeros then 1
  int idx = 1;
  int run = max(0, abs(k));
  int runBit = (k >= 0) ? 1 : 0;
  int termBit = 1 - runBit;

  int maxRun = max(0, (n-1) - 1); // leave space for terminator
  if (run > maxRun) run = maxRun;

  for (int i = 0; i < run && idx < n; i++) out[idx++] = runBit;
  if (idx < n) out[idx++] = termBit;

  int remaining = n - idx;
  int eBits = min(es, max(0, remaining));
  int fBits = max(0, remaining - eBits);

  double useed = Math.pow(2.0, 1<<es);
  double scaled = ax / Math.pow(useed, (double)k);

  double eReal = (scaled > 0) ? Math.floor(log2(scaled)) : 0.0;
  if (Double.isInfinite(eReal) || Double.isNaN(eReal)) eReal = 0.0;
  int e = (int)eReal;
  if (e < 0) e = 0;
  int eMax = (es == 0) ? 0 : (1<<es) - 1;
  e = constrain(e, 0, eMax);  // int overload OK

  double residual = (e > 0) ? (scaled / Math.pow(2.0, e)) : scaled;
  if (residual < 1.0) residual = 1.0;   // keep fraction in [0,1] for teaching
  double frac = residual - 1.0;
  frac = clamp(frac, 0.0, 1.0);

  // Exponent bits (MSB->LSB)
  for (int b = eBits - 1; b >= 0; --b) {
    if (idx < n) out[idx++] = (e >>> b) & 1;
  }

  // Fraction bits
  double f = frac;
  for (int i = 0; i < fBits && idx < n; i++) {
    f *= 2.0;
    if (f >= 1.0) { out[idx++] = 1; f -= 1.0; }
    else { out[idx++] = 0; }
  }
  while (idx < n) out[idx++] = 0;
  return out;
}

class FieldLayout {
  boolean valid;
  int rStart, rEnd, eStart, eEnd, fStart, fEnd;
}

FieldLayout buildPositLayout(int n, int es, int k) {
  FieldLayout L = new FieldLayout();
  L.valid = true;

  int idx = 1;
  int run = max(0, abs(k));
  int rLen = min(run + 1, max(0, n - idx));
  L.rStart = idx; L.rEnd = idx + rLen; idx += rLen;

  int remaining = n - idx;
  int eBits = min(es, max(0, remaining));
  int fBits = max(0, remaining - eBits);

  L.eStart = idx; L.eEnd = idx + eBits; idx += eBits;
  L.fStart = idx; L.fEnd = idx + fBits;

  if (L.fStart > n) L.valid = false;
  return L;
}

// ---------- Drawing helpers (style-isolated) ----------

void drawBitBox(float x, float y, float w, float h, int bit, int fieldCol) {
  pushStyle();
  stroke(fieldCol);
  fill(28);
  rect(x, y, w, h, 5);
  noStroke();
  fill(fieldCol);
  textAlign(CENTER, CENTER);
  text(bit, x + w*0.5f, y + h*0.5f);
  popStyle();
}

void drawFieldLabelAbove(String s, int col, float cx, float y) {
  pushStyle();
  noStroke();
  fill(col);
  textAlign(CENTER, BOTTOM);
  textSize(12);
  text(s, cx, y);
  popStyle();
}

void drawFieldLabelBelow(String s, int col, float cx, float y) {
  pushStyle();
  noStroke();
  fill(col);
  textAlign(CENTER, TOP);
  textSize(12);
  text(s, cx, y);
  popStyle();
}

// ---------- Misc ----------

double log2(double v) { return Math.log(v) / Math.log(2.0); }
double clamp(double v, double lo, double hi) { return Math.max(lo, Math.min(hi, v)); }

// ---------- Simple UI classes (style-isolated) ----------

class Button {
  String label;
  int x, y, w, h;
  Runnable action;

  Button(String label, int x, int y, int w, int h, Runnable action) {
    this.label = label; this.x = x; this.y = y; this.w = w; this.h = h; this.action = action;
  }

  void display() {
    pushStyle();
    boolean hover = hit(mouseX, mouseY);
    stroke(70);
    fill(hover ? color(60) : color(44));
    rect(x, y, w, h, 6);
    noStroke();
    fill(230);
    textAlign(CENTER, CENTER);
    text(label, x + w/2, y + h/2 + 1);
    popStyle();
  }

  boolean hit(int mx, int my) { return mx >= x && mx <= x+w && my >= y && my <= y+h; }
  float centerX() { return x + w*0.5f; }
  void activate() { if (action != null) action.run(); }
}

class ValueField {
  int x, y, w, h;
  boolean focused = false;
  String buf;
  int caret = 0;
  boolean lastParseOK = true;

  ValueField(int x, int y, int w, int h) {
    this.x = x; this.y = y; this.w = w; this.h = h;
    buf = nf(value, 1, 6);
    caret = buf.length();
  }

  void display() {
    pushStyle();
    stroke(lastParseOK ? (focused ? color(130, 220, 150) : color(80)) : color(230, 120, 120));
    fill(36);
    rect(x, y, w, h, 6);

    // (Removed the "Value:" label per request)

    fill(230); textAlign(LEFT, CENTER); textSize(14);
    int tx = x + 8;
    int ty = y + h/2 + 1;
    text(buf, tx, ty);

    if (focused) {
      // blink caret
      if ((millis()/500)%2 == 0) {
        float caretX = textWidth(buf.substring(0, caret));
        stroke(230);
        line(tx + caretX, y + 6, tx + caretX, y + h - 6);
      }
    }
    popStyle();
  }

  boolean hit(int mx, int my) { return (mx >= x && mx <= x+w && my >= y && my <= y+h); }

  void insert(char c) {
    buf = buf.substring(0, caret) + c + buf.substring(caret);
    caret++;
  }

  void backspace() {
    if (caret > 0) {
      buf = buf.substring(0, caret-1) + buf.substring(caret);
      caret--;
    }
  }

  void moveCaret(int d) { caret = constrain(caret + d, 0, buf.length()); }
  void caretToEnd() { caret = buf.length(); }

  void commit() {
    try {
      float v = parseFloat(buf);
      if (Float.isNaN(v)) throw new RuntimeException();
      value = v;
      lastParseOK = true;
    } catch (Exception ex) {
      lastParseOK = false;
    }
  }
}
