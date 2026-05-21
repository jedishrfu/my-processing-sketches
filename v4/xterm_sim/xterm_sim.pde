// Terminal Emulator in Processing
// Emulates a 40 row x 120 column character terminal

int cols = 120;
int rows = 40;
int charWidth = 8;
int charHeight = 16;

char[][] screenBuffer = new char[rows][cols];
int cursorX = 0;
int cursorY = 0;

PFont font;

void setup() {
  size(960,640);
  font = createFont("Courier", charHeight, true);
  textFont(font);
  textSize(charHeight);
  frameRate(30);
  
  // Initialize screen buffer
  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      screenBuffer[y][x] = ' ';
    }
  }
}

void draw() {
  background(0);
  fill(0, 255, 0);  // green-on-black terminal look
  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      text(screenBuffer[y][x], x * charWidth, (y + 1) * charHeight - 2);
    }
  }
  
  // Draw cursor (blinking)
  if (frameCount % 60 < 30) {
    fill(0, 255, 0);
    rect(cursorX * charWidth, cursorY * charHeight, charWidth, charHeight);
  }
}

void keyTyped() {
  char c = key;
  
  if (c == BACKSPACE || c == DELETE) {
    if (cursorX > 0) {
      cursorX--;
      screenBuffer[cursorY][cursorX] = ' ';
    } else if (cursorY > 0) {
      cursorY--;
      cursorX = cols - 1;
      screenBuffer[cursorY][cursorX] = ' ';
    }
  } else if (c == ENTER || c == RETURN) {
    cursorX = 0;
    cursorY++;
    if (cursorY >= rows) {
      scrollUp();
      cursorY = rows - 1;
    }
  } else if (c >= 32 && c < 127) { // Printable ASCII
    screenBuffer[cursorY][cursorX] = c;
    cursorX++;
    if (cursorX >= cols) {
      cursorX = 0;
      cursorY++;
      if (cursorY >= rows) {
        scrollUp();
        cursorY = rows - 1;
      }
    }
  }
}

void scrollUp() {
  for (int y = 1; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      screenBuffer[y - 1][x] = screenBuffer[y][x];
    }
  }
  for (int x = 0; x < cols; x++) {
    screenBuffer[rows - 1][x] = ' ';
  }
}
