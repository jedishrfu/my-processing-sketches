// Processing sketch: BWT & bzip2 Visualizer
// ------------------------------------------------------------
// Purpose: illustrate the main stages used by bzip2:
//   1) Burrows–Wheeler Transform (BWT)
//   2) Move-to-Front (MTF)
//   3) Run-Length Encoding (RLE)
//   4) (Optional) Huffman coding visualization (codes shown; no bitstream I/O)
// Also supports inverse BWT to verify round-trip.
//
// Controls:
//  - Click the text box to edit the input string. Include a unique end marker like '$' if you want.
//  - Buttons: Run, Step ▶, ◀ Step, Reset, Random, Inverse Check
//  - Keyboard: 'n' (next), 'p' (previous), 'r' (run all), 'i' (inverse check)
//  - Mouse wheel over panels to scroll.
//
// Notes:
//  - For pedagogy, MTF uses the set of unique chars observed in the input (sorted ascending).
//    Real bzip2 initializes MTF list with all 256 byte values.
//  - Huffman stage displays codes based on RLE symbol frequencies but does not pack bits.
//
// Tested in Processing (Java mode) 4.x.

// ---------------- UI State ----------------

import java.util.*;

String inputStr = "banana$"; // Feel free to change
boolean inputFocused = false;
PFont mono;
int step = 0; // Which stage to display
final int MAX_STEP = 7; // 0..7
float scrollY = 0;    // content scroll
float scrollYRight = 0; // secondary panel scroll

// Buttons
class Btn {
  String label; float x, y, w, h; Runnable onClick; boolean hot;
  Btn(String label, float x, float y, float w, float h, Runnable onClick) {
    this.label = label; this.x = x; this.y = y; this.w = w; this.h = h; this.onClick = onClick;
  }
  void draw() {
    stroke(0,50); fill(hot? color(240,250,255) : color(245)); rect(x, y, w, h, 8);
    fill(20); textAlign(CENTER, CENTER); text(label, x+w/2, y+h/2);
  }
  boolean hit(float mx, float my) { return mx>=x && mx<=x+w && my>=y && my<=y+h; }
}
ArrayList<Btn> btns = new ArrayList<Btn>();

// --------------- Data for stages ---------------
// Stage structs
static class BWTResult { String bwt; int index; String[] matrix; String lastCol; }
static class MTFResult { int[] mtf; ArrayList<ArrayList<Character>> lists; }
static class RLEPair { int val; int count; RLEPair(int v,int c){val=v;count=c;} }

BWTResult bwtRes;
MTFResult mtfRes;
ArrayList<RLEPair> rleRes;
HashMap<Integer, String> huffCodes; // symbol -> code
HashMap<Integer, Integer> huffFreqs; // symbol -> freq
String inverseCheck = "(not run)";

void setup() {
  size(1100, 760);
  mono = createFont("JetBrains Mono", 14, true);
  textFont(mono);
  buildButtons();
  computeAll();
}

void buildButtons() {
  btns.clear();
  float x=20, y=70; float bw=110, bh=34, gap=10;
  btns.add(new Btn("Run", x, y, bw, bh, ()->{ computeAll(); step = MAX_STEP; })); x+=bw+gap;
  btns.add(new Btn("◀ Step", x, y, bw, bh, ()->{ step=max(0, step-1);})); x+=bw+gap;
  btns.add(new Btn("Step ▶", x, y, bw, bh, ()->{ step=min(MAX_STEP, step+1);})); x+=bw+gap;
  btns.add(new Btn("Reset", x, y, bw, bh, ()->{ step=0; scrollY=0; scrollYRight=0;})); x+=bw+gap;
  btns.add(new Btn("Random", x, y, bw, bh, ()->{ inputStr = randomExample(); computeAll(); step=0;})); x+=bw+gap;
  btns.add(new Btn("Inverse Check", x, y, 150, bh, ()->{ runInverseCheck(); step=MAX_STEP;}));
}

String randomExample(){
  String[] samples = {
    "banana$", "mississippi$", "abracadabra$", "panamabananas$", "TOBEORNOTTOBE$",
    "aabaaabaaaab$", "the quick brown fox$", "broccoli$",
  };
  return samples[int(random(samples.length))];
}

void draw() {
  background(252);
  drawHeader();
  drawControls();
  drawPanels();
}

void drawHeader(){
  fill(20); textAlign(LEFT, TOP); textSize(20);
  text("BWT & bzip2 Visualizer", 20, 12);
  textSize(12);
  fill(70);
  text("Stages: 0 Input  |  1 Rotations  |  2 Sorted + LastCol  |  3 BWT Output  |  4 MTF  |  5 RLE  |  6 Huffman  |  7 Inverse", 20, 40);
}

void drawControls(){
  // Input box
  float bx = 20, by = 120, bw = 1060, bh = 34;
  stroke(0,60); fill(inputFocused? color(255,255,240):255); rect(bx, by, bw, bh, 8);
  fill(0); textAlign(LEFT, CENTER); textSize(16);
  String shown = inputStr;
  text(shown, bx+10, by+bh/2);
  fill(120); textSize(11);
  text("Click to edit. Include a unique end marker like '$' to ensure reversibility.", bx, by+bh+18);
  // Buttons
  for (Btn b : btns) { b.hot = b.hit(mouseX, mouseY); b.draw(); }
}

void drawPanels(){
  float leftX = 20, leftY = 180, leftW = width*0.56, leftH = height-200;
  float rightX = leftX + leftW + 20, rightY = leftY, rightW = width - rightX - 20, rightH = leftH;

  // Left panel (main)
  stroke(0,60); fill(255); rect(leftX, leftY, leftW, leftH, 12);
  pushMatrix(); translate(0, -scrollY);
  drawLeftContent(leftX, leftY, leftW, leftH);
  popMatrix();

  // Right panel (details)
  stroke(0,60); fill(255); rect(rightX, rightY, rightW, rightH, 12);
  pushMatrix(); translate(0, -scrollYRight);
  drawRightContent(rightX, rightY, rightW, rightH);
  popMatrix();
}

void drawLeftContent(float x, float y, float w, float h){
  float pad = 14; float cy = y + pad; float lx = x + pad;
  textAlign(LEFT, TOP); fill(10); textSize(16);
  String title = new String[]{
    "0) Input", "1) All cyclic rotations", "2) Sorted rotations & last column",
    "3) BWT output (last column) + index", "4) Move-to-Front (MTF)",
    "5) Run-Length Encoding (RLE)", "6) Huffman codes (from RLE symbols)", "7) Inverse BWT check"
  }[step];
  text(title, lx, cy); cy += 28;
  textSize(14); fill(30);

  switch(step){
    case 0:
      text("Input string:", lx, cy); cy+=22;
      text("\u2192 " + inputStr, lx+10, cy); cy+=24;
      text("Length = "+ inputStr.length() +". Unique chars = '" + uniqueChars(inputStr) + "'", lx+10, cy);
      break;
    case 1:
      text("All cyclic rotations of the input (unsorted):", lx, cy); cy+=22;
      String[] rots = rotations(inputStr);
      for (int i=0;i<rots.length;i++){ text(nf(i,2)+": "+rots[i], lx+10, cy); cy+=20; }
      break;
    case 2:
      text("Sort the rotations lexicographically. The last column becomes the BWT.", lx, cy); cy+=22;
      for (int i=0;i<bwtRes.matrix.length;i++){
        String row = bwtRes.matrix[i];
        char last = row.charAt(row.length()-1);
        text(nf(i,2)+": "+row+"   | last: '"+last+"'", lx+10, cy); cy+=20;
      }
      cy+=10;
      text("Last column: "+bwtRes.lastCol, lx+10, cy);
      break;
    case 3:
      text("BWT output is the last column plus the row index of the original string.", lx, cy); cy+=22;
      text("BWT: " + bwtRes.bwt, lx+10, cy); cy+=20;
      text("Index of original row: " + bwtRes.index, lx+10, cy); cy+=20;
      text("(Store both to make the transform reversible.)", lx+10, cy); cy+=20;
      break;
    case 4:
      text("Move-to-Front (MTF) encodes each char as its index in a mutable list of symbols.", lx, cy); cy+=22;
      text("Alphabet (sorted unique chars): '"+ uniqueChars(inputStr) + "'", lx+10, cy); cy+=20;
      text("BWT input to MTF: " + bwtRes.bwt, lx+10, cy); cy+=20;
      text("MTF output (indices): "+ join(intArrayToStringArray(mtfRes.mtf), ", "), lx+10, cy); cy+=20;
      text("(Observe many 0s after runs; ideal for RLE.)", lx+10, cy);
      break;
    case 5:
      text("Run-Length Encoding (RLE) over the MTF indices:", lx, cy); cy+=22;
      for (RLEPair p : rleRes) { text("("+p.val+", "+p.count+")", lx+10, cy); cy+=20; }
      cy+=10; text("Total pairs: "+rleRes.size(), lx+10, cy);
      break;
    case 6:
      text("Huffman codes built from RLE symbol frequencies (for illustration):", lx, cy); cy+=22;
      text("Unique symbols: "+huffFreqs.size(), lx+10, cy); cy+=20;
      ArrayList<Integer> keys = new ArrayList<Integer>(huffFreqs.keySet());
      keys.sort((a,b)->huffFreqs.get(b)-huffFreqs.get(a));
      int shown = 0;
      for (Integer k : keys) {
        String code = huffCodes.get(k);
        text("sym "+k+"  freq "+huffFreqs.get(k)+"  code "+code, lx+10, cy); cy+=20; shown++;
        if (cy>y+h-40) break;
      }
      break;
    case 7:
      text("Inverse BWT reconstructs the original string using (bwt, index).", lx, cy); cy+=22;
      text("Inverse result: "+ inverseCheck, lx+10, cy); cy+=20;
      text("If this matches the input, the pipeline is lossless up to BWT.", lx+10, cy);
      break;
  }
}

void drawRightContent(float x, float y, float w, float h){
  float pad=14, cy=y+pad, lx=x+pad; textAlign(LEFT, TOP); textSize(14); fill(30);
  switch(step){
    case 2:
      text("TF (table-fill) explanation of inverse BWT (concept):", lx, cy); cy+=20;
      text("1) Start with an empty column.\n2) Repeatedly prepend the BWT string, then sort rows.\n3) After length steps, the row at 'index' is the original.", lx, cy); cy+=60;
      drawInverseTF(lx, cy, w-2*pad, 18, min(10, inputStr.length()));
      break;
    case 4:
      text("MTF list evolution (first 24 steps):", lx, cy); cy+=22;
      int stepsToShow = min(24, bwtRes.bwt.length());
      String alpha = uniqueChars(inputStr);
      ArrayList<ArrayList<Character>> Ls = mtfRes.lists;
      for (int i=0;i<stepsToShow;i++){
        char ch = bwtRes.bwt.charAt(i);
        String listStr = listToString(Ls.get(i));
        text(nf(i,2)+" ch='"+ch+"'  list="+listStr+"  idx="+mtfRes.mtf[i], lx, cy); cy+=18;
      }
      break;
    case 5:
      text("RLE stream visualization:", lx, cy); cy+=22;
      StringBuilder sb = new StringBuilder();
      for (RLEPair p : rleRes) sb.append("("+p.val+","+p.count+") ");
      text(sb.toString(), lx, cy);
      break;
    case 6:
      text("Why Huffman after RLE?", lx, cy); cy+=20;
      text("RLE creates a skewed distribution (many small integers). Huffman assigns\nshorter codes to frequent symbols and longer codes to rare ones.", lx, cy); cy+=40;
      text("Top-10 most frequent symbols:", lx, cy); cy+=20;
      ArrayList<Integer> keys = new ArrayList<Integer>(huffFreqs.keySet());
      keys.sort((a,b)->huffFreqs.get(b)-huffFreqs.get(a));
      for (int i=0;i<min(10, keys.size()); i++){
        int k = keys.get(i);
        text(nf(i+1,2)+"  sym "+k+"  freq "+huffFreqs.get(k)+"  code "+huffCodes.get(k), lx, cy); cy+=18;
      }
      break;
    default:
      text("Tips:\n- Use Random to load classic examples (banana$, mississippi$, ...).\n- Step through to see how each transform changes the data.\n- Inverse Check confirms BWT reversibility.", lx, cy);
  }
}

// ---------------- Events ----------------
void mousePressed(){
  // Input focus
  float bx = 20, by = 120, bw = 1060, bh = 34;
  inputFocused = (mouseX>=bx && mouseX<=bx+bw && mouseY>=by && mouseY<=by+bh);
  // Buttons
  for (Btn b : btns) if (b.hit(mouseX, mouseY)) b.onClick.run();
}

void keyTyped(){
  if (inputFocused){
    if (key==BACKSPACE) {
      if (inputStr.length()>0) inputStr = inputStr.substring(0, inputStr.length()-1);
    } else if (key==DELETE) {
      inputStr = "";
    } else if (key==ENTER || key==RETURN) {
      inputFocused = false; computeAll(); step=0;
    } else if (key!=TAB) {
      inputStr += key;
    }
  } else {
    if (key=='n') step = min(MAX_STEP, step+1);
    if (key=='p') step = max(0, step-1);
    if (key=='r') { computeAll(); step = MAX_STEP; }
    if (key=='i') { runInverseCheck(); step=MAX_STEP; }
  }
}

void mouseWheel(MouseEvent event) {
  float e = event.getCount();
  if (mouseX < width*0.58) scrollY = constrain(scrollY + e*16, 0, 2000);
  else scrollYRight = constrain(scrollYRight + e*16, 0, 2000);
}

// ---------------- Pipeline Compute ----------------
void computeAll(){
  if (inputStr.length()==0) return;
  bwtRes = bwtForward(inputStr);
  mtfRes = mtfEncode(bwtRes.bwt, uniqueChars(inputStr));
  rleRes = rleEncode(mtfRes.mtf);
  buildHuffman(rleRes);
  inverseCheck = "(not run)";
}

void runInverseCheck(){
  String inv = bwtInverse(bwtRes.bwt, bwtRes.index);
  inverseCheck = inv;
}

// ---------------- BWT Forward ----------------
BWTResult bwtForward(String s){
  BWTResult r = new BWTResult();
  String[] rots = rotations(s);
  String[] sorted = sort(rots);
  r.matrix = sorted;
  StringBuilder last = new StringBuilder();
  int idx=-1;
  for (int i=0;i<sorted.length;i++){
    String row = sorted[i];
    last.append(row.charAt(row.length()-1));
    if (row.equals(s)) idx = i;
  }
  r.lastCol = last.toString();
  r.bwt = r.lastCol;
  r.index = idx;
  return r;
}

String[] rotations(String s){
  int n = s.length(); String[] r = new String[n];
  for (int i=0;i<n;i++){
    r[i] = s.substring(i) + s.substring(0, i);
  }
  return r;
}

// ---------------- BWT Inverse ----------------
String bwtInverse(String bwt, int idx){
  int n = bwt.length();
  String[] table = new String[n];
  for (int i=0;i<n;i++) table[i] = "";
  for (int k=0;k<n;k++){
    for (int i=0;i<n;i++) table[i] = bwt.charAt(i) + table[i];
    table = sort(table);
  }
  return table[idx];
}

// Draw a few TF steps on right panel
void drawInverseTF(float x, float y, float w, float rowH, int steps){
  String b = bwtRes.bwt; int n = b.length();
  String[] table = new String[n]; for (int i=0;i<n;i++) table[i] = "";
  textAlign(LEFT, TOP); textSize(12); fill(0);
  for (int k=0;k<steps; k++){
    for (int i=0;i<n;i++) table[i] = b.charAt(i) + table[i];
    table = sort(table);
    float cy = y + k*(rowH+2);
    text("Step "+(k+1)+": "+ join(table, " | "), x, cy);
  }
}

// ---------------- MTF ----------------
MTFResult mtfEncode(String s, String alphabet){
  ArrayList<Character> L = new ArrayList<Character>();
  for (int i=0;i<alphabet.length();i++) L.add(alphabet.charAt(i));
  int[] out = new int[s.length()];
  ArrayList<ArrayList<Character>> snaps = new ArrayList<ArrayList<Character>>();
  for (int i=0;i<s.length();i++){
    char c = s.charAt(i);
    int idx = L.indexOf(c);
    out[i] = idx;
    // save snapshot BEFORE moving to front
    snaps.add(new ArrayList<Character>(L));
    // move to front
    L.remove(idx);
    L.add(0, c);
  }
  MTFResult r = new MTFResult(); r.mtf = out; r.lists = snaps; return r;
}

String uniqueChars(String s){
  HashSet<Character> set = new HashSet<Character>();
  for (int i=0;i<s.length();i++) set.add(s.charAt(i));
  ArrayList<Character> arr = new ArrayList<Character>(set);
  arr.sort((a,b)->Character.compare(a,b));
  StringBuilder sb = new StringBuilder();
  for (char c : arr) sb.append(c);
  return sb.toString();
}

// ---------------- RLE ----------------
ArrayList<RLEPair> rleEncode(int[] arr){
  ArrayList<RLEPair> out = new ArrayList<RLEPair>();
  if (arr.length==0) return out;
  int cur = arr[0], cnt=1;
  for (int i=1;i<arr.length;i++){
    if (arr[i]==cur) cnt++;
    else { out.add(new RLEPair(cur, cnt)); cur = arr[i]; cnt=1; }
  }
  out.add(new RLEPair(cur, cnt));
  return out;
}

// ---------------- Huffman (visualization only) ----------------
class Node { int sym; int freq; Node left,right; Node(int s,int f){sym=s;freq=f;} Node(Node l, Node r){left=l; right=r; freq=l.freq+r.freq; sym=Integer.MIN_VALUE;} boolean isLeaf(){return left==null && right==null;} }

void buildHuffman(ArrayList<RLEPair> rle){
  // Flatten pairs to a sequence of integers to be coded: (val,count) pairs in sequence
  ArrayList<Integer> stream = new ArrayList<Integer>();
  for (RLEPair p : rle){ stream.add(p.val); stream.add(p.count); }
  huffFreqs = new HashMap<Integer,Integer>();
  for (int v : stream){ huffFreqs.put(v, huffFreqs.getOrDefault(v,0)+1); }
  if (huffFreqs.isEmpty()) { huffCodes = new HashMap<Integer,String>(); return; }
  PriorityQueue<Node> pq = new PriorityQueue<Node>((a,b)-> a.freq-b.freq);
  for (int k : huffFreqs.keySet()) pq.add(new Node(k, huffFreqs.get(k)));
  if (pq.size()==1){ // edge case: single symbol
    Node only = pq.poll();
    huffCodes = new HashMap<Integer,String>();
    huffCodes.put(only.sym, "0");
    return;
  }
  while (pq.size()>1){ Node a=pq.poll(), b=pq.poll(); pq.add(new Node(a,b)); }
  Node root = pq.poll();
  huffCodes = new HashMap<Integer,String>();
  assignCodes(root, "");
}

void assignCodes(Node n, String code){
  if (n.isLeaf()){ huffCodes.put(n.sym, code.length()>0? code : "0"); return; }
  assignCodes(n.left, code+"0");
  assignCodes(n.right, code+"1");
}

// ---------------- Utils ----------------
String[] intArrayToStringArray(int[] a){ String[] s = new String[a.length]; for (int i=0;i<a.length;i++) s[i] = str(a[i]); return s; }
String listToString(ArrayList<Character> L){ StringBuilder sb = new StringBuilder(); for (char c : L){ sb.append(c); } return sb.toString(); }
