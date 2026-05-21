int cellSize = 60;

int[][] solution = new int[9][9];
int[][] userGuesses = new int[9][9];

boolean[][][] pencilMarks = new boolean[9][9][10];

int selRow = 0, selCol = 0;

boolean showHints = false;
boolean puzzleSolved = false;

void settings() {
  size(cellSize * 9, cellSize * 9);
}

void setup() {
  textAlign(CENTER, CENTER);
  textSize(24);
  initPuzzle();
}

void draw() {
  background(255);
  drawGrid();
  drawNumbers();
  drawSelection();
  if (showHints) drawHints();
  if (puzzleSolved) drawVictory();
}

void keyPressed() {
  if (puzzleSolved) return;

  if (keyCode == UP) selRow = (selRow + 8) % 9;
  else if (keyCode == DOWN) selRow = (selRow + 1) % 9;
  else if (keyCode == LEFT) selCol = (selCol + 8) % 9;
  else if (keyCode == RIGHT) selCol = (selCol + 1) % 9;
  else if (key == 'H' || key == 'h') showHints = !showHints;
  else if (key == BACKSPACE || key == DELETE) {
    userGuesses[selRow][selCol] = 0;
    for (int i = 1; i <= 9; i++) pencilMarks[selRow][selCol][i] = false;
  } else if (key >= '1' && key <= '9') {
    int val = key - '0';
    if (solution[selRow][selCol] > 0) {
      if (keyEvent.isShiftDown()) {
        pencilMarks[selRow][selCol][val] = !pencilMarks[selRow][selCol][val];
      } else {
        userGuesses[selRow][selCol] = val;
        // Clear pencil marks when guessing
        for (int i = 1; i <= 9; i++) pencilMarks[selRow][selCol][i] = false;
        checkVictory();
      }
    }
  }
}

void drawGrid() {
  stroke(0);
  for (int i = 0; i <= 9; i++) {
    strokeWeight(i % 3 == 0 ? 4 : 1);
    line(i * cellSize, 0, i * cellSize, height);
    line(0, i * cellSize, width, i * cellSize);
  }
}

void drawSelection() {
  noFill();
  stroke(255, 0, 0);
  strokeWeight(3);
  rect(selCol * cellSize, selRow * cellSize, cellSize, cellSize);
}

void drawNumbers() {
  textSize(24);
  for (int row = 0; row < 9; row++) {
    for (int col = 0; col < 9; col++) {
      int val = solution[row][col];
      int guess = userGuesses[row][col];

      int x = col * cellSize + cellSize / 2;
      int y = row * cellSize + cellSize / 2;

      if (val < 0) {
        fill(255, 0, 0);
        text(-val, x, y);
      } else if (guess > 0) {
        if (guess == val) fill(0);
        else if (showHints) {
          fill(255, 255, 255);
          noStroke();
          fill(255, 200, 200);
          rect(col * cellSize, row * cellSize, cellSize, cellSize);
          fill(0, 0, 255);
        } else {
          fill(0, 0, 255);
        }
        text(guess, x, y);
      } else {
        drawPencilMarks(row, col);
      }
    }
  }
}

void drawPencilMarks(int row, int col) {
  textSize(12);
  fill(100);
  for (int n = 1; n <= 9; n++) {
    if (pencilMarks[row][col][n]) {
      int x = col * cellSize + ((n - 1) % 3) * cellSize / 3 + cellSize / 6;
      int y = row * cellSize + ((n - 1) / 3) * cellSize / 3 + cellSize / 6;
      text(n, x, y);
    }
  }
}

void drawHints() {
  textSize(10);
  fill(255, 0, 0);
  for (int row = 0; row < 9; row++) {
    for (int col = 0; col < 9; col++) {
      int val = solution[row][col];
      int guess = userGuesses[row][col];
      if (val > 0 && guess > 0 && guess != val) {
        int x = col * cellSize + cellSize - 8;
        int y = row * cellSize + 8;
        text("×", x, y);
      }
    }
  }
}

void drawVictory() {
  fill(0, 200, 0, 180);
  noStroke();
  rect(0, height / 2 - 30, width, 60);
  textSize(32);
  fill(255);
  text("Puzzle Complete!", width / 2, height / 2);
}

void checkVictory() {
  for (int row = 0; row < 9; row++) {
    for (int col = 0; col < 9; col++) {
      int sol = solution[row][col];
      if (sol > 0 && userGuesses[row][col] != sol) return;
    }
  }
  puzzleSolved = true;
}

void initPuzzle() {
  int[][] preset = {
    {-5, 3, 0, 0, -7, 0, 0, 0, 0},
    {6, 0, 0, -1, 9, 5, 0, 0, 0},
    {0, 9, 8, 0, 0, 0, 0, 6, 0},
    {8, 0, 0, 0, 6, 0, 0, 0, 3},
    {4, 0, 0, 8, 0, 3, 0, 0, 1},
    {7, 0, 0, 0, 2, 0, 0, 0, 6},
    {0, 6, 0, 0, 0, 0, 2, 8, 0},
    {0, 0, 0, 4, 1, 9, 0, 0, 5},
    {0, 0, 0, 0, 8, 0, 0, 7, 9}
  };

  int[][] fullSolution = {
    {5,3,4,6,7,8,9,1,2},
    {6,7,2,1,9,5,3,4,8},
    {1,9,8,3,4,2,5,6,7},
    {8,5,9,7,6,1,4,2,3},
    {4,2,6,8,5,3,7,9,1},
    {7,1,3,9,2,4,8,5,6},
    {9,6,1,5,3,7,2,8,4},
    {2,8,7,4,1,9,6,3,5},
    {3,4,5,2,8,6,1,7,9}
  };

  for (int row = 0; row < 9; row++) {
    for (int col = 0; col < 9; col++) {
      if (preset[row][col] != 0) {
        solution[row][col] = -preset[row][col];
      } else {
        solution[row][col] = fullSolution[row][col];
      }
    }
  }
}
