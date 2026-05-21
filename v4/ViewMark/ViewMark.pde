/**
 * ViewMark (Processing / Java mode) - v3
 * -------------------------------------
 * Bottom bar BUTTONS for actions + show/hide thumbnail pane.
 * CommonMark-ish inline styling:
 *   **bold**
 *   *italic*
 *   __underline__
 *   ~~strikethrough~~
 *
 * Slides:
 *   - Prefer: line exactly "---" to separate slides
 *   - Otherwise: blank-line-separated paragraphs
 *
 * Code fences:
 *   ```lang
 *   code...
 *   ```
 * with pastel background + simple language keyword highlighting.
 */

import java.util.*;
import java.util.regex.*;
import java.io.File;
import processing.event.MouseEvent;

String loadedPath = "";
String markdownText = "";

ArrayList<Slide> slides = new ArrayList<Slide>();
int slideIndex = 0;

boolean presenterView = false;
boolean presenting = false;
boolean showThumbs = true;

int theme = 0; // 0 dark, 1 light, 2 slate
int thumbScroll = 0;

PFont fontBody, fontMono, fontTitle, fontSmall, fontBodyBold, fontBodyItalic;
PFont fontTitleBold;

ArrayList<Button> buttons = new ArrayList<Button>();

class Slide {
  String content;
  String notes;
  Slide(String c, String n) { content = c; notes = n; }
}

class Button {
  String id, label;
  float x, y, w, h;
  boolean enabled = true;

  Button(String id, String label) {
    this.id = id;
    this.label = label;
  }

  boolean hit(float mx, float my) {
    return enabled && mx >= x && mx <= x + w && my >= y && my <= y + h;
  }

  void draw() {
    noStroke();
    if (!enabled) {
      fill(theme == 1 ? color(220) : color(30));
    } else if (hit(mouseX, mouseY)) {
      fill(theme == 1 ? color(210) : color(25, 35, 30));
    } else {
      fill(theme == 1 ? color(230) : color(18, 22, 20));
    }
    rect(x, y, w, h, 10);

    stroke(enabled ? accent() : subtle());
    noFill();
    rect(x, y, w, h, 10);
    noStroke();

    fill(enabled ? fg() : subtle());
    textFont(fontSmall);
    textAlign(CENTER, CENTER);
    text(label, x + w/2, y + h/2);
  }
}

void settings() { size(1280, 720); }

void setup() {
  surface.setTitle("ViewMark");
  surface.setResizable(true);

  // NOTE: Processing font “italic” can be system-dependent. This still works well enough for a viewer.
  fontBody      = createFont("SansSerif", 20);
  fontBodyBold  = createFont("SansSerif.bold", 20);
  fontBodyItalic= createFont("SansSerif.italic", 20);
  fontTitle     = createFont("SansSerif.bold", 34);
  fontTitleBold = createFont("SansSerif.bold", 34);
  fontMono      = createFont("Monospaced", 18);
  fontSmall     = createFont("SansSerif", 14);

  markdownText =
    "# ViewMark\n\n" +
    "Use **bold**, *italic*, __underline__, and ~~strikethrough~~.\n\n" +
    "Use `---` on its own line to separate slides.\n\n" +
    "```java\n" +
    "class Demo {\n" +
    "  public static void main(String[] args) {\n" +
    "    int x = 42;\n" +
    "    System.out.println(\"hello\" + x);\n" +
    "  }\n" +
    "}\n" +
    "```\n\n" +
    ":::notes\n" +
    "Notes show in presenter view.\n" +
    ":::";
  rebuildSlides();

  buildButtons();
}

void draw() {
  applyThemeBackground();

  float thumbW = showThumbs ? max(220.0, width * 0.20) : 0;
  if (showThumbs) drawThumbnails(thumbW);

  drawSlideView(thumbW);

  drawBottomBar(); // draws buttons + status
}

void applyThemeBackground() {
  if (theme == 0) background(10);
  else if (theme == 1) background(245);
  else background(28, 32, 40);
}

// Dark mode: green text
int fg() {
  if (theme == 0) return color(0, 220, 90);
  if (theme == 1) return color(15);
  return color(235);
}
int subtle() {
  if (theme == 0) return color(0, 160, 70);
  if (theme == 1) return color(120);
  return color(150);
}
int accent() {
  if (theme == 0) return color(0, 255, 120);
  if (theme == 1) return color(30, 90, 180);
  return color(90, 170, 255);
}

int panelBg() {
  if (theme == 1) return color(232);
  if (theme == 2) return color(18, 20, 26);
  return color(8, 10, 12);
}
int cardBg() {
  if (theme == 1) return color(242);
  if (theme == 2) return color(22, 25, 32);
  return color(14, 16, 20);
}

/* ---------- Slides ---------- */

void rebuildSlides() {
  slides.clear();
  String md = normalizeNewlines(markdownText);

  String[] rawSlides;
  if (containsHrSeparator(md)) rawSlides = splitOnHr(md);
  else rawSlides = split(md, "\n\n");

  for (String rs : rawSlides) {
    String trimmed = rs.trim();
    if (trimmed.length() == 0) continue;

    String notes = "";
    String body = trimmed;

    int notesStart = body.indexOf(":::notes");
    if (notesStart >= 0) {
      int after = notesStart + ":::notes".length();
      int end = body.indexOf(":::", after);
      if (end > after) {
        notes = body.substring(after, end).trim();
        body = (body.substring(0, notesStart) + body.substring(end + 3)).trim();
      }
    }
    slides.add(new Slide(body, notes));
  }

  if (slides.size() == 0) slides.add(new Slide("(empty)", ""));
  slideIndex = constrain(slideIndex, 0, slides.size() - 1);
  thumbScroll = 0;
}

String normalizeNewlines(String s) {
  return s.replace("\r\n", "\n").replace("\r", "\n");
}

boolean containsHrSeparator(String md) {
  return md.contains("\n---\n") || md.startsWith("---\n") || md.endsWith("\n---") || md.equals("---");
}

String[] splitOnHr(String md) {
  ArrayList<String> parts = new ArrayList<String>();
  String[] lines = split(md, "\n");
  StringBuilder cur = new StringBuilder();

  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];
    if (line.trim().equals("---")) {
      parts.add(cur.toString());
      cur = new StringBuilder();
    } else {
      cur.append(line);
      if (i < lines.length - 1) cur.append("\n");
    }
  }
  parts.add(cur.toString());
  return parts.toArray(new String[0]);
}

/* ---------- Thumbnails ---------- */

void drawThumbnails(float thumbW) {
  noStroke();
  fill(panelBg());
  rect(0, 0, thumbW, height);

  fill(accent());
  textFont(fontSmall);
  textAlign(LEFT, TOP);
  text("VIEWMARK", 14, 12);

  fill(subtle());
  String fileLabel = (loadedPath.length() == 0) ? "Built-in text" : shortenPath(loadedPath, 32);
  text(fileLabel, 14, 30);

  float y = 58 - thumbScroll;
  float pad = 10;
  float cardH = 90;
  float cardW = thumbW - pad * 2;

  for (int i = 0; i < slides.size(); i++) {
    boolean selected = (i == slideIndex);

    float x0 = pad;
    float y0 = y;
    float r = 12;

    if (y0 + cardH > 50 && y0 < height - 40) {
      noStroke();
      if (selected) fill(accent(), 40);
      else fill(cardBg());
      rect(x0, y0, cardW, cardH, r);

      fill(selected ? fg() : color(fg(), 220));
      textFont(fontSmall);
      textAlign(LEFT, TOP);
      String title = makeTitle(slides.get(i).content, i);
      text((i + 1) + ". " + title, x0 + 10, y0 + 10, cardW - 20, cardH - 20);

      noFill();
      stroke(selected ? accent() : color(subtle(), 80));
      rect(x0, y0, cardW, cardH, r);
      noStroke();
    }

    y += cardH + 10;
  }
}

String shortenPath(String p, int maxChars) {
  if (p == null) return "";
  if (p.length() <= maxChars) return p;
  return "…" + p.substring(p.length() - (maxChars - 1));
}

/* ---------- Main Slide View ---------- */

void drawSlideView(float thumbW) {
  if (slides.size() == 0) return;
  Slide s = slides.get(slideIndex);

  float pad = 64;
  float rightPanelW = presenterView ? (width - thumbW) * 0.32 : 0;

  float x0 = thumbW;
  float contentX = x0 + pad;
  float contentW = (width - thumbW) - pad*2 - rightPanelW;

  String title = makeTitle(s.content, slideIndex);
  fill(fg());
  textFont(fontTitleBold);
  textAlign(LEFT, TOP);
  text(title, contentX, pad);

  float y = pad + 60;
  y = drawMarkdownish(s.content, contentX, y, contentW);

  // Presenter notes panel (optional)
  if (presenterView) {
    float px = width - rightPanelW;
    noStroke();
    fill(panelBg());
    rect(px, 0, rightPanelW, height);

    fill(accent());
    textFont(fontBodyBold);
    textAlign(LEFT, TOP);
    text("NOTES", px + 20, 20);

    fill(theme == 1 ? color(40) : color(210));
    textFont(fontBody);
    String notes = (s.notes.trim().length() == 0) ? "(no speaker notes)" : s.notes;
    text(notes, px + 20, 55, rightPanelW - 40, height - 80);
  }
}

String makeTitle(String content, int idx) {
  String t = content.trim();
  if (t.length() == 0) return "Slide " + (idx + 1);

  String[] lines = split(t, "\n");
  if (lines.length > 0) {
    String l0 = lines[0].trim();
    if (l0.startsWith("#")) return l0.replaceAll("^#+\\s*", "").trim();
  }

  int nl = t.indexOf("\n");
  String firstLine = (nl >= 0) ? t.substring(0, nl).trim() : t;
  if (firstLine.length() <= 60) return capitalize(firstLine);

  int dot = t.indexOf(".");
  if (dot > 10 && dot < 80) return capitalize(t.substring(0, dot + 1).trim());

  return "Slide " + (idx + 1);
}

String capitalize(String s) {
  if (s.length() == 0) return s;
  return s.substring(0, 1).toUpperCase() + s.substring(1);
}

/* ---------- Markdown-ish renderer (with inline emphasis) ---------- */

float drawMarkdownish(String md, float x, float y, float w) {
  String[] lines = split(normalizeNewlines(md), "\n");

  boolean inCode = false;
  String codeLang = "";
  StringBuilder codeBlock = new StringBuilder();

  float lineH = 28;
  float blockGap = 10;

  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];
    String trimmed = line.trim();

    // code fences
    if (trimmed.startsWith("```")) {
      if (!inCode) {
        inCode = true;
        codeBlock = new StringBuilder();
        codeLang = trimmed.substring(3).trim().toLowerCase();
      } else {
        y = drawCodeBlock(codeBlock.toString(), codeLang, x, y, w);
        y += blockGap;
        inCode = false;
        codeLang = "";
      }
      continue;
    }

    if (inCode) {
      codeBlock.append(line).append("\n");
      continue;
    }

    if (trimmed.length() == 0) { y += blockGap; continue; }

    // headings
    if (trimmed.startsWith("#")) {
      int level = 0;
      while (level < trimmed.length() && trimmed.charAt(level) == '#') level++;
      String ht = trimmed.substring(level).trim();

      fill(accent());
      textAlign(LEFT, TOP);
      textFont(level == 1 ? fontTitleBold : fontBodyBold);
      text(ht, x, y);
      textFont(fontBody);
      y += (level == 1 ? 52 : 34);
      continue;
    }

    // bullets
    boolean bullet = trimmed.startsWith("- ") || trimmed.startsWith("* ");
    if (bullet) {
      fill(accent());
      textFont(fontBody);
      textAlign(LEFT, TOP);
      text("•", x, y);
      drawInlineRich(trimmed.substring(2), x + 22, y + 4, w - 22);
      y += lineH;
      continue;
    }

    // normal line
    drawInlineRich(line, x, y + 4, w);
    y += lineH;
  }

  if (inCode) {
    y = drawCodeBlock(codeBlock.toString(), codeLang, x, y, w);
    y += blockGap;
  }

  return y;
}

/*
 * Inline rich text:
 * - backticks `code` => monospace pill
 * - **bold**
 * - *italic*
 * - __underline__
 * - ~~strikethrough~~
 *
 * This is a pragmatic renderer (not a full CommonMark parser).
 * It handles non-nested emphasis reliably for typical slides.
 */
void drawInlineRich(String line, float x, float y, float w) {
  ArrayList<Token> toks = tokenizeInline(line);

  float cx = x;
  float maxX = x + w;

  textAlign(LEFT, BASELINE);

  for (Token t : toks) {
    if (t.text.length() == 0) continue;

    // wrap by words for non-code tokens
    if (!t.code) {
      String[] words = splitTokensPreserveSpaces(t.text);
      for (String chunk : words) {
        if (chunk.length() == 0) continue;

        // choose font
        if (t.bold) textFont(fontBodyBold);
        else if (t.italic) textFont(fontBodyItalic);
        else textFont(fontBody);

        float tw = textWidth(chunk);

        if (cx + tw > maxX) { cx = x; y += 28; }

        fill(fg());
        text(chunk, cx, y);

        // underline / strike
        float x1 = cx;
        float x2 = cx + tw;

        if (t.underline) {
          stroke(fg());
          line(x1, y + 4, x2, y + 4);
          noStroke();
        }
        if (t.strike) {
          stroke(fg());
          line(x1, y - 6, x2, y - 6);
          noStroke();
        }

        cx += tw;
      }
    } else {
      // inline code pill
      textFont(fontMono);
      float tw = textWidth(t.text) + 14;

      if (cx + tw > maxX) { cx = x; y += 28; }

      noStroke();
      fill(codeInlineBg());
      rect(cx, y - 18, tw, 24, 6);

      fill(theme == 1 ? color(20) : fg());
      text(t.text, cx + 7, y);

      cx += tw;
      textFont(fontBody);
    }
  }
}

class Token {
  String text;
  boolean bold, italic, underline, strike, code;
  Token(String text) { this.text = text; }
}

// Split preserving spaces as separate chunks so wrapping looks natural.
String[] splitTokensPreserveSpaces(String s) {
  ArrayList<String> out = new ArrayList<String>();
  StringBuilder cur = new StringBuilder();
  for (int i = 0; i < s.length(); i++) {
    char c = s.charAt(i);
    if (c == ' ') {
      if (cur.length() > 0) { out.add(cur.toString()); cur.setLength(0); }
      out.add(" ");
    } else {
      cur.append(c);
    }
  }
  if (cur.length() > 0) out.add(cur.toString());
  return out.toArray(new String[0]);
}

ArrayList<Token> tokenizeInline(String s) {
  ArrayList<Token> out = new ArrayList<Token>();

  boolean bold = false, italic = false, underline = false, strike = false, code = false;
  StringBuilder cur = new StringBuilder();

  int i = 0;
  while (i < s.length()) {
    // backticks
    if (s.charAt(i) == '`') {
      flushToken(out, cur, bold, italic, underline, strike, code);
      code = !code;
      i++;
      continue;
    }

    if (!code) {
      // ** or __ or ~~ (2-char markers)
      if (i + 1 < s.length()) {
        String two = s.substring(i, i + 2);
        if (two.equals("**")) { flushToken(out, cur, bold, italic, underline, strike, code); bold = !bold; i += 2; continue; }
        if (two.equals("__")) { flushToken(out, cur, bold, italic, underline, strike, code); underline = !underline; i += 2; continue; }
        if (two.equals("~~")) { flushToken(out, cur, bold, italic, underline, strike, code); strike = !strike; i += 2; continue; }
      }
      // * italic (single marker)
      if (s.charAt(i) == '*') {
        flushToken(out, cur, bold, italic, underline, strike, code);
        italic = !italic;
        i++;
        continue;
      }
    }

    cur.append(s.charAt(i));
    i++;
  }

  flushToken(out, cur, bold, italic, underline, strike, code);
  return out;
}

void flushToken(ArrayList<Token> out, StringBuilder cur,
                boolean bold, boolean italic, boolean underline, boolean strike, boolean code) {
  if (cur.length() == 0) return;
  Token t = new Token(cur.toString());
  t.bold = bold; t.italic = italic; t.underline = underline; t.strike = strike; t.code = code;
  out.add(t);
  cur.setLength(0);
}

int codeInlineBg() {
  if (theme == 1) return color(225, 232, 245);
  return color(22, 28, 30);
}

/* ---------- Code blocks (pastel bg + approx highlighting) ---------- */

float drawCodeBlock(String code, String lang, float x, float y, float w) {
  String[] lines = split(code.trim(), "\n");
  textFont(fontMono);

  float pad = 16;
  float lineH = 24;
  float h = pad*2 + max(1, lines.length) * lineH;

  noStroke();
  fill(codeBlockBg(lang));
  rect(x, y - 6, w, h, 12);

  float ty = y + pad + 6;

  for (int i = 0; i < lines.length; i++) {
    String ln = lines[i];

    fill(color(20));
    text(ln, x + pad, ty + i*lineH);

    highlightNumbers(ln, x + pad, ty + i*lineH);
    highlightStrings(ln, x + pad, ty + i*lineH);
    highlightComments(ln, x + pad, ty + i*lineH, lang);
    highlightKeywords(ln, x + pad, ty + i*lineH, lang);
  }

  textFont(fontBody);
  return y + h;
}

int codeBlockBg(String lang) {
  if (lang == null) lang = "";
  lang = lang.toLowerCase();

  if (lang.contains("py")) return color(232, 245, 238);
  if (lang.contains("js") || lang.contains("ts")) return color(248, 243, 224);
  if (lang.contains("c") || lang.contains("cpp") || lang.contains("c++")) return color(236, 239, 250);
  if (lang.contains("java") || lang.contains("processing")) return color(236, 248, 250);
  if (lang.contains("sh") || lang.contains("bash") || lang.contains("zsh")) return color(245, 235, 245);
  return color(240, 240, 240);
}

void highlightNumbers(String line, float x, float y) { highlightRegex(line, "\\b\\d+(\\.\\d+)?\\b", x, y, color(70, 110, 140)); }
void highlightStrings(String line, float x, float y) {
  highlightRegex(line, "\"([^\"\\\\]|\\\\.)*\"", x, y, color(120, 80, 140));
  highlightRegex(line, "'([^'\\\\]|\\\\.)*'", x, y, color(120, 80, 140));
}
void highlightComments(String line, float x, float y, String lang) {
  String l = (lang == null) ? "" : lang.toLowerCase();
  if (l.contains("py") || l.contains("sh") || l.contains("bash") || l.contains("zsh")) highlightRegex(line, "#.*$", x, y, color(90, 120, 90));
  else highlightRegex(line, "//.*$", x, y, color(90, 120, 90));
}
void highlightKeywords(String line, float x, float y, String lang) {
  String l = (lang == null) ? "" : lang.toLowerCase();
  String kw;
  if (l.contains("py")) kw = "\\b(def|class|return|import|from|as|if|elif|else|for|while|break|continue|in|and|or|not|True|False|None|with|try|except|finally|lambda|yield)\\b";
  else if (l.contains("js") || l.contains("ts")) kw = "\\b(function|class|return|import|from|export|default|if|else|for|while|break|continue|const|let|var|new|this|typeof|instanceof|async|await|try|catch|finally|true|false|null|undefined)\\b";
  else if (l.contains("c") || l.contains("cpp") || l.contains("c++")) kw = "\\b(int|float|double|char|bool|void|class|struct|return|if|else|for|while|break|continue|const|static|inline|template|typename|using|namespace|new|delete|true|false|nullptr)\\b";
  else kw = "\\b(class|interface|extends|implements|public|private|protected|static|final|void|int|float|double|boolean|char|String|new|return|if|else|for|while|break|continue|true|false|null|import)\\b";
  highlightRegex(line, kw, x, y, color(20, 90, 160));
}

void highlightRegex(String line, String pattern, float x, float y, int col) {
  Pattern p = Pattern.compile(pattern);
  Matcher m = p.matcher(line);

  fill(col);
  textFont(fontMono);
  while (m.find()) {
    int start = m.start();
    String before = line.substring(0, start);
    String match = m.group();
    float dx = textWidth(before);
    text(match, x + dx, y);
  }
}

/* ---------- Bottom Bar + Buttons ---------- */

void buildButtons() {
  buttons.clear();
  buttons.add(new Button("open", "Open"));
  buttons.add(new Button("prev", "Prev"));
  buttons.add(new Button("next", "Next"));
  buttons.add(new Button("thumbs", "Thumbs"));
  buttons.add(new Button("notes", "Notes"));
  buttons.add(new Button("theme", "Theme"));
  buttons.add(new Button("present", "Present"));
  buttons.add(new Button("reset", "Reset"));
}

void layoutButtons(float barY, float barH) {
  float pad = 10;
  float bx = pad;
  float by = barY + 6;
  float bh = barH - 12;

  for (Button b : buttons) {
    float bw = textWidthWithFont(fontSmall, b.label) + 28;
    b.x = bx;
    b.y = by;
    b.w = bw;
    b.h = bh;
    bx += bw + 10;
  }

  // enable/disable
  getBtn("prev").enabled = (slideIndex > 0);
  getBtn("next").enabled = (slideIndex < slides.size() - 1);
  getBtn("thumbs").label = showThumbs ? "Hide Thumbs" : "Show Thumbs";
  getBtn("notes").label  = presenterView ? "Hide Notes" : "Show Notes";
  getBtn("present").label= presenting ? "Windowed" : "Present";
}

Button getBtn(String id) {
  for (Button b : buttons) if (b.id.equals(id)) return b;
  return null;
}

float textWidthWithFont(PFont f, String s) {
  textFont(f);
  return textWidth(s);
}

void drawBottomBar() {
  float barH = 50;
  float barY = height - barH;

  noStroke();
  fill(theme == 1 ? color(230) : color(0));
  rect(0, barY, width, barH);

  layoutButtons(barY, barH);

  // draw buttons
  for (Button b : buttons) b.draw();

  // status text (right side)
  fill(subtle());
  textFont(fontSmall);
  textAlign(RIGHT, CENTER);
  String status = "Slide " + (slideIndex + 1) + "/" + slides.size();
  if (loadedPath.length() > 0) status += "  |  " + shortenPath(loadedPath, 40);
  text(status, width - 12, barY + barH/2);
}

/* ---------- Input ---------- */

void keyPressed() {
  // keep arrows as convenience
  if (keyCode == RIGHT) { nextSlide(); return; }
  if (keyCode == LEFT)  { prevSlide(); return; }
}

void mousePressed() {
  // bottom bar buttons
  float barH = 50;
  float barY = height - barH;
  if (mouseY >= barY) {
    for (Button b : buttons) {
      if (b.hit(mouseX, mouseY)) {
        handleButton(b.id);
        return;
      }
    }
  }

  // click in thumbnails to select slide
  float thumbW = showThumbs ? max(220.0, width * 0.20) : 0;
  if (showThumbs && mouseX <= thumbW) {
    float pad = 10;
    float cardH = 90;
    float yStart = 58 - thumbScroll;

    for (int i = 0; i < slides.size(); i++) {
      float x0 = pad;
      float y0 = yStart + i * (cardH + 10);
      float w0 = thumbW - pad * 2;
      float h0 = cardH;

      if (mouseX >= x0 && mouseX <= x0 + w0 && mouseY >= y0 && mouseY <= y0 + h0) {
        slideIndex = i;
        return;
      }
    }
  }
}

void mouseWheel(MouseEvent event) {
  if (!showThumbs) return;
  float thumbW = max(220.0, width * 0.20);
  if (mouseX <= thumbW) {
    float e = event.getCount();
    thumbScroll += (int)(e * 30.0);

    float cardH = 90;
    float totalH = 58 + slides.size() * (cardH + 10);
    int maxScroll = max(0, (int)(totalH - height + 60));

    thumbScroll = (int)constrain((float)thumbScroll, 0.0, (float)maxScroll);
  }
}

void handleButton(String id) {
  if (id.equals("open")) {
    selectInput("Open Markdown file for ViewMark:", "fileSelected");
  } else if (id.equals("prev")) {
    prevSlide();
  } else if (id.equals("next")) {
    nextSlide();
  } else if (id.equals("thumbs")) {
    showThumbs = !showThumbs;
    thumbScroll = 0;
  } else if (id.equals("notes")) {
    presenterView = !presenterView;
  } else if (id.equals("theme")) {
    theme = (theme + 1) % 3;
  } else if (id.equals("present")) {
    presenting = !presenting;
    if (presenting) surface.setSize(displayWidth, displayHeight);
    else surface.setSize(1280, 720);
  } else if (id.equals("reset")) {
    slideIndex = 0;
  }
}

void prevSlide() { slideIndex = max(0, slideIndex - 1); }
void nextSlide() { slideIndex = min(slides.size() - 1, slideIndex + 1); }

/* ---------- File open callback ---------- */

void fileSelected(File selection) {
  if (selection == null) return;

  loadedPath = selection.getAbsolutePath();
  String[] lines = loadStrings(selection);
  if (lines == null) return;

  StringBuilder sb = new StringBuilder();
  for (int i = 0; i < lines.length; i++) {
    sb.append(lines[i]);
    if (i < lines.length - 1) sb.append("\n");
  }
  markdownText = sb.toString();
  rebuildSlides();
}
