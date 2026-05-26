// MarkdownPager.pde
// Processing 3/4+
//
// Green-on-black Markdown viewer with:
// - Page breaks ONLY on level-1 headings (# ...)
// - Headings (#, ##, ###) at 20pt; body at 16pt
// - Extra space after headings
// - Open a file (O)
// - Regex find jump (F) via dialog (Java regex)
// - Plain find jump (G) via dialog (case-insensitive substring)
// - {{TOC}} shows clickable Table of Contents of level-1 headings
// - Click left/right border to prev/next page
// - Mouse wheel scrolls; crossing end/begin flips pages
// - Home/End OR Cmd+Up/Cmd+Down (macOS) jump to top/bottom

import java.util.regex.*;
import java.util.ArrayList;
import java.io.File;
import javax.swing.JOptionPane;
import java.awt.event.KeyEvent;

String[] srcLines = new String[0];

ArrayList<Page> pages = new ArrayList<Page>();
int pageIndex = 0;

PFont fontHeading;
PFont fontBody;

int margin = 30;
float leading = 1.25;
int maxHeadingLevel = 3;

float headingExtraGap = 10;
float tocItemGap = 4;

float scrollY = 0;
float maxScrollY = 0;

int borderClickWidth = 28;

boolean tocMode = false;
ArrayList<TocItem> tocItems = new ArrayList<TocItem>();

String lastRegex = "";
String lastFind = "";
String statusMsg = "";
int statusUntilFrame = 0;

void settings() {
  size(1100, 750);
}

void setup() {
  surface.setTitle("Markdown Pager");
  frameRate(60);

  // Change font name if you don't have Menlo
  fontHeading = createFont("Menlo", 20, true);
  fontBody    = createFont("Menlo", 16, true);

  // Demo text until you open a file
  String demo =
    "# Welcome\n" +
    "Press O to open a markdown file.\n" +
    "Press F for regex-find; press G for plain find.\n" +
    "Click left/right border to page; wheel scrolls and pages.\n" +
    "Home/End (if present) or Cmd+Up/Cmd+Down jump top/bottom.\n" +
    "\n" +
    "# Contents\n" +
    "{{TOC}}\n" +
    "\n" +
    "# Section One\n" +
    "This is some body text.\n" +
    "## Subheading\n" +
    "More text.\n" +
    "\n" +
    "# Section Two\n" +
    "Even more text.\n";

  srcLines = split(demo, "\n");
  buildPages();
  updatePageDerivedState();
}

void draw() {
  background(0);

  // subtle click strips
  noFill();
  stroke(0, 80, 0);
  rect(0, 0, borderClickWidth, height);
  rect(width - borderClickWidth, 0, borderClickWidth, height);

  fill(0, 255, 0);
  noStroke();

  if (pages.size() == 0) {
    textFont(fontBody);
    text("No pages. Press O to open a markdown file.", margin, margin);
    return;
  }

  if (tocMode) drawTOC();
  else         drawPageText();

  drawFooter();
  drawStatus();
}

void drawPageText() {
  Page p = pages.get(pageIndex);

  float y = margin - scrollY;
  float contentHeight = height - margin*2;

  for (int i = 0; i < p.lines.size(); i++) {
    Line ln = p.lines.get(i);
    if (y > height + 100) break;

    if (ln.isHeading) textFont(fontHeading);
    else              textFont(fontBody);

    float lineH = (textAscent() + textDescent()) * leading;

    if (y + lineH > -100 && y < height + 100) {
      text(ln.text, margin, y + textAscent());
    }

    y += lineH;
    if (ln.isHeading) y += headingExtraGap;
  }

  maxScrollY = max(0, p.totalHeight - contentHeight);
  scrollY = constrain(scrollY, 0, maxScrollY);
}

void drawTOC() {
  tocItems.clear();

  ArrayList<Integer> idxs = new ArrayList<Integer>();
  ArrayList<String> titles = new ArrayList<String>();

  for (int i = 0; i < pages.size(); i++) {
    String t = pages.get(i).level1Title;
    if (t != null && t.length() > 0) {
      idxs.add(i);
      titles.add(t);
    }
  }

  textFont(fontHeading);
  text("# Table of Contents", margin, margin + textAscent());

  float y = margin + (textAscent()+textDescent())*leading + 14;

  textFont(fontBody);
  float itemH = (textAscent() + textDescent()) * leading;

  for (int i = 0; i < titles.size(); i++) {
    String title = titles.get(i);
    int target = idxs.get(i);

    float x = margin;
    float w = width - 2*margin;
    float top = y - itemH - 2;
    float h = itemH + tocItemGap + 4;

    boolean hover = (mouseX >= x-6 && mouseX <= x-6+w+12 &&
                     mouseY >= top && mouseY <= top + h);

    if (hover) {
      stroke(0, 140, 0);
      fill(0, 255, 0);
      rect(x-6, top, w+12, h, 6);
      noStroke();
      fill(0);
      text(title, x, y);
      fill(0, 255, 0);
    } else {
      text(title, x, y);
    }

    tocItems.add(new TocItem(x-6, top, w+12, h, target));

    y += itemH + tocItemGap + 6;
    if (y > height - margin) break;
  }

  fill(0, 200, 0);
  textFont(fontBody);
  text("Click an entry to jump. (TOC uses level-1 headings: # ...)", margin, height - margin);
  fill(0, 255, 0);
}

void drawFooter() {
  fill(0, 200, 0);
  textFont(fontBody);

  String title = pages.get(pageIndex).level1Title;
  if (title == null) title = "";

  String footer =
    "Page " + (pageIndex+1) + "/" + pages.size() +
    (title.length()>0 ? ("   [" + title + "]") : "") +
    "   O=open  F=regex-find  G=find  N/P=next/prev  Home/End or Cmd+Up/Down";

  text(footer, margin, height - 10);
  fill(0, 255, 0);
}

void drawStatus() {
  if (frameCount < statusUntilFrame && statusMsg != null && statusMsg.length() > 0) {
    fill(0, 200, 0);
    textFont(fontBody);
    text(statusMsg, margin, height - margin - 24);
    fill(0, 255, 0);
  }
}

void setStatus(String msg) {
  statusMsg = msg;
  statusUntilFrame = frameCount + 240;
}

// -------------------- Keys --------------------

void keyPressed() {
  if (key == 'o' || key == 'O') {
    selectInput("Select a markdown file:", "fileSelected");

  } else if (key == 'n' || key == 'N' || keyCode == RIGHT || key == ' ') {
    nextPage();

  } else if (key == 'p' || key == 'P' || keyCode == LEFT) {
    prevPage();

  } else if (keyCode == KeyEvent.VK_HOME || (keyCode == UP && keyEvent.isMetaDown())) {
    // Home OR Cmd+Up on macOS
    scrollY = 0;

  } else if (keyCode == KeyEvent.VK_END || (keyCode == DOWN && keyEvent.isMetaDown())) {
    // End OR Cmd+Down on macOS
    scrollY = maxScrollY;

  } else if (key == 'f' || key == 'F') {
    regexFindJump();

  } else if (key == 'g' || key == 'G') {
    plainFindJump();

  } else if (key == 'r' || key == 'R') {
    buildPages();
    updatePageDerivedState();
    setStatus("Rebuilt pages.");
  }
}

void fileSelected(File selection) {
  if (selection == null) { setStatus("Open cancelled."); return; }

  String[] lines = loadStrings(selection.getAbsolutePath());
  if (lines == null) { setStatus("Failed to load file."); return; }

  srcLines = lines;
  buildPages();
  pageIndex = 0;
  scrollY = 0;
  updatePageDerivedState();
  setStatus("Loaded: " + selection.getName() + " (" + srcLines.length + " lines)");
}

// -------------------- Mouse --------------------

void mousePressed() {
  if (tocMode) {
    for (TocItem item : tocItems) {
      if (item.hit(mouseX, mouseY)) {
        jumpToPage(item.targetPage);
        return;
      }
    }
  }

  if (mouseX <= borderClickWidth) prevPage();
  else if (mouseX >= width - borderClickWidth) nextPage();
}

void mouseWheel(processing.event.MouseEvent event) {
  float delta = event.getCount() * 35;
  scrollY += delta;

  if (scrollY > maxScrollY + 5) {
    if (pageIndex < pages.size()-1) { nextPage(); scrollY = 0; }
    else scrollY = maxScrollY;
  } else if (scrollY < -5) {
    if (pageIndex > 0) { prevPage(); scrollY = maxScrollY; }
    else scrollY = 0;
  }

  scrollY = constrain(scrollY, 0, maxScrollY);
}

// -------------------- Find / Jump --------------------

void regexFindJump() {
  String prompt =
    "Enter Java regex to find a page (searches full page text).\n" +
    "Example: (?i)benchmark|compression\n" +
    "Tip: include (?m) for multiline ^ and $ anchors.\n";

  String rx = JOptionPane.showInputDialog(null, prompt, lastRegex);
  if (rx == null) { setStatus("Regex find cancelled."); return; }

  rx = rx.trim();
  if (rx.length() == 0) { setStatus("Regex was empty."); return; }

  Pattern pat;
  try {
    pat = Pattern.compile(rx);
  } catch (Exception ex) {
    setStatus("Bad regex: " + ex.getMessage());
    return;
  }

  lastRegex = rx;

  int idx = (pageIndex + 1) % pages.size();
  for (int tries = 0; tries < pages.size(); tries++) {
    if (pat.matcher(pages.get(idx).searchText).find()) {
      jumpToPage(idx);
      setStatus("Matched regex on page " + (idx + 1));
      return;
    }
    idx = (idx + 1) % pages.size();
  }

  setStatus("No match for regex.");
}

void plainFindJump() {
  String prompt = "Enter text to find (case-insensitive) in a page:";
  String q = JOptionPane.showInputDialog(null, prompt, lastFind);
  if (q == null) { setStatus("Find cancelled."); return; }

  q = q.trim();
  if (q.length() == 0) { setStatus("Find was empty."); return; }

  lastFind = q;
  String needle = q.toLowerCase();

  int idx = (pageIndex + 1) % pages.size();
  for (int tries = 0; tries < pages.size(); tries++) {
    if (pages.get(idx).searchText.toLowerCase().indexOf(needle) >= 0) {
      jumpToPage(idx);
      setStatus("Matched text on page " + (idx + 1));
      return;
    }
    idx = (idx + 1) % pages.size();
  }

  setStatus("No match for text.");
}

// -------------------- Paging --------------------

void jumpToPage(int idx) {
  pageIndex = constrain(idx, 0, pages.size()-1);
  scrollY = 0;
  updatePageDerivedState();
}

void nextPage() {
  if (pageIndex < pages.size()-1) {
    pageIndex++;
    scrollY = 0;
    updatePageDerivedState();
  }
}

void prevPage() {
  if (pageIndex > 0) {
    pageIndex--;
    scrollY = 0;
    updatePageDerivedState();
  }
}

void updatePageDerivedState() {
  Page p = pages.get(pageIndex);
  tocMode = p.containsTOC;
  maxScrollY = max(0, p.totalHeight - (height - margin*2));
  scrollY = constrain(scrollY, 0, maxScrollY);
}

// -------------------- Build pages --------------------

void buildPages() {
  pages.clear();
  Page current = new Page();

  for (int i = 0; i < srcLines.length; i++) {
    String line = (srcLines[i] == null) ? "" : srcLines[i];
    int lvl = headingLevel(line);

    // Break only on level-1 headings
    if (lvl == 1 && current.lines.size() > 0) {
      finalizePage(current);
      pages.add(current);
      current = new Page();
    }

    boolean headingFont = (lvl >= 1 && lvl <= maxHeadingLevel);
    current.lines.add(new Line(line, headingFont, lvl));
  }

  if (current.lines.size() > 0) {
    finalizePage(current);
    pages.add(current);
  }

  if (pages.size() == 0) {
    Page p = new Page();
    p.lines.add(new Line("# (empty)", true, 1));
    finalizePage(p);
    pages.add(p);
  }

  pageIndex = constrain(pageIndex, 0, pages.size()-1);
  scrollY = 0;
}

void finalizePage(Page p) {
  // title = first level-1 heading in page
  p.level1Title = "";
  for (Line ln : p.lines) {
    if (ln.level == 1) {
      p.level1Title = stripHeadingMarker(ln.text, 1).trim();
      break;
    }
  }

  // search text & TOC flag
  StringBuilder sb = new StringBuilder();
  p.containsTOC = false;
  for (Line ln : p.lines) {
    sb.append(ln.text).append("\n");
    if (ln.text != null && ln.text.indexOf("{{TOC}}") >= 0) p.containsTOC = true;
  }
  p.searchText = sb.toString();

  // measure height
  float h = 0;
  for (Line ln : p.lines) {
    if (ln.isHeading) textFont(fontHeading);
    else              textFont(fontBody);

    float lineH = (textAscent() + textDescent()) * leading;
    h += lineH;
    if (ln.isHeading) h += headingExtraGap;
  }
  p.totalHeight = h;
}

// -------------------- Markdown helpers --------------------

int headingLevel(String line) {
  if (line == null || line.length() == 0) return 0;
  if (line.charAt(0) != '#') return 0;

  int i = 0;
  while (i < line.length() && line.charAt(i) == '#') i++;

  // require space/tab or end
  if (i == line.length()) return i;
  char c = line.charAt(i);
  if (c == ' ' || c == '\t') return i;
  return 0;
}

String stripHeadingMarker(String line, int level) {
  if (line == null) return "";
  int i = 0;
  while (i < line.length() && i < level && line.charAt(i) == '#') i++;
  if (i == level) {
    String rest = line.substring(i);
    if (rest.startsWith(" ")) rest = rest.substring(1);
    if (rest.startsWith("\t")) rest = rest.substring(1);
    return rest;
  }
  return line;
}

// -------------------- Data structures --------------------

class Line {
  String text;
  boolean isHeading;
  int level;
  Line(String t, boolean h, int lvl) { text=t; isHeading=h; level=lvl; }
}

class Page {
  ArrayList<Line> lines = new ArrayList<Line>();
  String level1Title = "";
  String searchText = "";
  boolean containsTOC = false;
  float totalHeight = 0;
}

class TocItem {
  float x, y, w, h;
  int targetPage;
  TocItem(float X, float Y, float W, float H, int tgt) {
    x=X; y=Y; w=W; h=H; targetPage=tgt;
  }
  boolean hit(float mx, float my) {
    return mx >= x && mx <= x+w && my >= y && my <= y+h;
  }
}
