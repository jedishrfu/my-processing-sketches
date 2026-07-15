void setup() {
  size(800, 400); // Set the window size first
  background(255);
  
  drawAxes();
  drawSine();
  drawCosine();
}

void drawAxes() {
  stroke(0);
  float padding = 50;
  float scaleX = (width - 2 * padding) / (2 * PI);
  float scaleY = (height - 2 * padding) / 2;
  
  line(padding, height / 2, width - padding, height / 2); // X-axis
  line(padding, padding, padding, height - padding);      // Y-axis
  
  // Labels
  fill(0);
  textSize(14);
  text("0", padding - 10, height / 2 + 15);
  text("π", padding + scaleX * PI - 5, height / 2 + 15);
  text("2π", padding + scaleX * 2 * PI - 10, height / 2 + 15);
  text("1", padding - 20, height / 2 - scaleY);
  text("-1", padding - 25, height / 2 + scaleY);
}

void drawSine() {
  stroke(255, 0, 0); // Red for sine
  noFill();
  float padding = 50;
  float scaleX = (width - 2 * padding) / (2 * PI);
  float scaleY = (height - 2 * padding) / 2;
  
  beginShape();
  for (float x = 0; x <= 2 * PI; x += 0.01) {
    float screenX = padding + x * scaleX;
    float screenY = height / 2 - sin(x) * scaleY;
    vertex(screenX, screenY);
  }
  endShape();
}

void drawCosine() {
  stroke(0, 0, 255); // Blue for cosine
  noFill();
  float padding = 50;
  float scaleX = (width - 2 * padding) / (2 * PI);
  float scaleY = (height - 2 * padding) / 2;
  
  beginShape();
  for (float x = 0; x <= 2 * PI; x += 0.01) {
    float screenX = padding + x * scaleX;
    float screenY = height / 2 - cos(x) * scaleY;
    vertex(screenX, screenY);
  }
  endShape();
}
