/**
 * LaTeX Live Renderer (Processing + JLaTeXMath)
 * ------------------------------------------------
 * Type LaTeX in the editor panel at the bottom and see the equation render above.
 * Controls:
 *   - Type normally in the bottom panel; supports multi-line with Shift+Enter.
 *   - Ctrl/Cmd+Enter: force render (also renders automatically on pause).
 *   - Mouse drag (on render area): pan the formula.
 *   - Mouse wheel: zoom in/out the formula.
 *   - 'C' : center the view.
 *   - 'R' : reset zoom to 1.0
 *   - 'S' : save a PNG of the rendered formula (timestamped).
 *
 * Requires: jlatexmath-<version>.jar in the sketch's "code" folder.
 */

import java.awt.*;
import java.awt.image.BufferedImage;

// JLaTeXMath
import org.scilab.forge.jlatexmath.TeXConstants;
import org.scilab.forge.jlatexmath.TeXFormula;
import org.scilab.forge.jlatexmath.TeXIcon;

PFont uiFont;

StringBuilder input = new StringBuilder("\\int_{0}^{\\infty} e^{-x^2} \\, dx = \\frac{\\sqrt{\\pi}}{2}");
boolean needsRender = true;

PImage rendered;
String errorMsg = null;

// View / interaction
float zoom = 1.0f;
float offsetX = 0, offsetY = 0;
boolean dragging = false;
float lastX, lastY;

// Layout
int editorHeight = 180;
int gutter = 12;

void settings() {
  size(900, 600);
  smooth(8);
}

void setup() {
  surface.setTitle("LaTeX Live Renderer (Processing + JLaTeXMath)");
  uiFont = createFont("Arial", 16);
  textFont(uiFont);
  textLeading(22);
  renderLatex();
}

void draw() {
  background(250);

  // Render area
  int renderW = width;
  int renderH = height - editorHeight;

  // Header
  fill(20);
  textAlign(LEFT, TOP);
  textSize(14);
  text("Render Area (drag to pan, wheel to zoom)", gutter, gutter);

  // Border for render area
  stroke(230);
  noFill();
  rect(0, 0, renderW-1, renderH-1);

  // Draw rendered LaTeX (if any)
  if (rendered != null) {
    pushMatrix();
    translate(renderW/2 + offsetX, renderH/2 + offsetY);
    scale(zoom);
    imageMode(CENTER);
    image(rendered, 0, 0);
    popMatrix();
  }

  // Error message (if any)
  if (errorMsg != null) {
    fill(180, 0, 0);
    textAlign(LEFT, BOTTOM);
    textSize(13);
    text("Parse error: " + errorMsg, gutter, renderH - gutter);
  }

  // Editor panel
  drawEditor(renderW, renderH);
}

void drawEditor(int renderW, int renderH) {
  int y0 = renderH;
  noStroke();
  fill(246);
  rect(0, y0, width, editorHeight);

  // Divider
  stroke(210);
  line(0, y0, width, y0);

  // Labels & help
  fill(40);
  textSize(14);
  textAlign(LEFT, TOP);
  text("LaTeX Input (Shift+Enter for newline, Ctrl/Cmd+Enter to render)", gutter, y0 + gutter);

  // Input box
  int boxY = y0 + 2*gutter + 16;
  int boxH = editorHeight - (3*gutter + 16);
  stroke(200);
  noFill();
  rect(gutter, boxY, width - 2*gutter, boxH);

  // Text inside box
  float tx = gutter + 8;
  float ty = boxY + 8;
  fill(20);
  textAlign(LEFT, TOP);
  textSize(16);
  drawWrappedText(input.toString(), tx, ty, width - 2*gutter - 16, boxH - 16);

  // Auto-render if flagged
  if (needsRender) {
    renderLatex();
    needsRender = false;
  }
}

void drawWrappedText(String s, float x, float y, float w, float h) {
  // Simple manual wrap for display (does not change content).
  String[] lines = s.split("\n", -1);
  float yy = y;
  for (String line : lines) {
    // naive wrap by words
    String[] words = splitTokens(line, " ");
    String current = "";
    for (String word : words) {
      String trial = current.isEmpty() ? word : current + " " + word;
      if (textWidth(trial) > w) {
        text(current, x, yy);
        yy += textLeading;
        current = word;
      } else {
        current = trial;
      }
    }
    text(current, x, yy);
    yy += textLeading;
    if (yy > y + h - textLeading) break;
  }
}

void mousePressed() {
  if (mouseY < height - editorHeight) {
    dragging = true;
    lastX = mouseX;
    lastY = mouseY;
  }
}

void mouseDragged() {
  if (dragging) {
    offsetX += mouseX - lastX;
    offsetY += mouseY - lastY;
    lastX = mouseX;
    lastY = mouseY;
  }
}

void mouseReleased() {
  dragging = false;
}

void mouseWheel(MouseEvent e) {
  float s = e.getCount() < 0 ? 1.1 : 1.0/1.1;
  // Zoom about mouse point in render area
  if (mouseY < height - editorHeight) {
    // Convert mouse point to world space near the center
    float cx = width/2 + offsetX;
    float cy = (height - editorHeight)/2 + offsetY;
    float dx = (mouseX - cx) / zoom;
    float dy = (mouseY - cy) / zoom;
    zoom *= s;
    // Recompute offset so the zoom centers around the cursor
    offsetX = mouseX - (width/2) - dx * zoom;
    offsetY = mouseY - (height - editorHeight)/2 - dy * zoom;
  } else {
    zoom *= s;
  }
}

void keyPressed() {
  // Editor typing
  boolean inEditor = mouseY >= height - editorHeight;

  // Shortcuts always active
  if ((key == ENTER || key == RETURN) && (keyEvent.isControlDown() || keyEvent.isMetaDown())) {
    needsRender = true;
    return;
  }

  if (key == 'S' || key == 's') {
    saveRenderedPNG();
    return;
  }
  if (key == 'R' || key == 'r') {
    zoom = 1.0f;
    return;
  }
  if (key == 'C' || key == 'c') {
    offsetX = 0;
    offsetY = 0;
    return;
  }

  if (!inEditor) return;

  if (key == BACKSPACE) {
    if (input.length() > 0) input.deleteCharAt(input.length()-1);
    needsRender = true;
  } else if (key == DELETE) {
    // ignore
  } else if (key == ENTER || key == RETURN) {
    if (keyEvent.isShiftDown()) {
      input.append('\n');
      needsRender = true;
    } else {
      // plain Enter: render
      needsRender = true;
    }
  } else if (key != CODED) {
    input.append(key);
    needsRender = true;
  }
}

void renderLatex() {
  try {
    errorMsg = null;
    String latex = input.toString().trim();
    if (latex.isEmpty()) {
      rendered = null;
      return;
    }

    // Build JLaTeXMath icon
    TeXFormula formula = new TeXFormula(latex);
    // STYLE_DISPLAY for big equations; change the float to adjust base size.
    TeXIcon icon = formula.createTeXIcon(TeXConstants.STYLE_DISPLAY, 24f);

    // Render to BufferedImage (ARGB)
    BufferedImage bi = new BufferedImage(icon.getIconWidth(), icon.getIconHeight(), BufferedImage.TYPE_INT_ARGB);
    Graphics2D g2 = bi.createGraphics();
    // high-quality hints
    g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
    g2.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
    g2.setColor(new Color(0,0,0,0));
    g2.fillRect(0, 0, bi.getWidth(), bi.getHeight());
    g2.setColor(Color.BLACK);

    icon.paintIcon(null, g2, 0, 0);
    g2.dispose();

    rendered = bufferedToPImage(bi);

  } catch (Exception ex) {
    errorMsg = ex.getMessage();
    rendered = null;
  }
}

PImage bufferedToPImage(BufferedImage bimg) {
  // Convert BufferedImage (ARGB) to Processing PImage safely.
  int w = bimg.getWidth();
  int h = bimg.getHeight();
  PImage out = createImage(w, h, ARGB);
  int[] px = new int[w*h];
  bimg.getRGB(0, 0, w, h, px, 0, w);
  out.loadPixels();
  arrayCopy(px, out.pixels);
  out.updatePixels();
  return out;
}

void saveRenderedPNG() {
  if (rendered == null) return;
  String filename = "latex_" + nf(year(),4) + nf(month(),2) + nf(day(),2) + "_" + nf(hour(),2) + nf(minute(),2) + nf(second(),2) + ".png";
  // Save exactly what you see (with zoom/pan baked into a new image):
  int renderW = width;
  int renderH = height - editorHeight;

  PGraphics pg = createGraphics(renderW, renderH);
  pg.beginDraw();
  pg.background(255);
  pg.imageMode(CENTER);
  pg.translate(renderW/2 + offsetX, renderH/2 + offsetY);
  pg.scale(zoom);
  pg.image(rendered, 0, 0);
  pg.endDraw();
  pg.save(filename);

  println("Saved: " + filename);
}
