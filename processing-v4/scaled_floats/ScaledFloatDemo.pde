import java.io.*;

ScaledFloatArray1D sfa;
float[] originalData;
float[] restoredData;

void settings() {
  size(800, 500);
}

void setup() {
  textSize(14);
  fill(0);

  // Generate test data
  originalData = new float[100];
  for (int i = 0; i < originalData.length; i++) {
    originalData[i] = 200 + 100 * sin(radians(i * 3.6));
  }

  // Compress and decompress
  sfa = new ScaledFloatArray1D(originalData);
  restoredData = sfa.get();

  // Print info
  printGetterInfo();

  // Write to binary files
  writeBinaryFloatArray(originalData, "original_data.bin");
  writeBinaryShortArray(sfa.getDataValues(), "scaled_data.bin");

  // Show sizes
  printFileSize("original_data.bin");
  printFileSize("scaled_data.bin");
}

void draw() {
  background(255);
  drawAxesAndTicks();
  drawPlot();
}

void printGetterInfo() {
  println("ScaledFloatArray1D Getters:");
  println("  Min:      " + nf(sfa.getDataMinimum(), 1, 3));
  println("  Max:      " + nf(sfa.getDataMaximum(), 1, 3));
  println("  Range:    " + nf(sfa.getDataRange(), 1, 3));
  println("  Digits:   " + sfa.getDecimalDigits());
  println("  Accuracy: " + nf(sfa.getDataAccuracy(), 1, 5));
}

void writeBinaryFloatArray(float[] arr, String filename) {
  try {
    DataOutputStream out = new DataOutputStream(new FileOutputStream(dataPath(filename)));
    for (int i = 0; i < arr.length; i++) {
      out.writeFloat(arr[i]);
    }
    out.close();
  } catch (IOException e) {
    println("Error writing to " + filename + ": " + e.getMessage());
    println(e);
  }
}
void writeBinaryShortArray(short[] arr, String filename) {
  try {
    DataOutputStream out = new DataOutputStream(new FileOutputStream(dataPath(filename)));
    for (int i = 0; i < arr.length; i++) {
      out.writeShort(arr[i]);
    }
    out.close();
  } catch (IOException e) {
    println("Error writing to " + filename + ": " + e.getMessage());
    e.printStackTrace();
  }
}
void printFileSize(String filename) {
  File f = new File(dataPath(filename));
  if (f.exists()) {
    float kb = f.length() / 1024.0;
    println("File: " + filename + " size = " + nf(kb, 1, 2) + " KB");
  } else {
    println("File not found: " + filename);
  }
}

void drawAxesAndTicks() {
  int marginLeft = 60;
  int marginBottom = 40;
  int marginTop = 20;
  int marginRight = 20;

  // axis lines
  stroke(0);
  line(marginLeft, height - marginBottom, width - marginRight, height - marginBottom); // x-axis
  line(marginLeft, marginTop, marginLeft, height - marginBottom); // y-axis

  // y-axis ticks
  float minVal = min(min(originalData), min(restoredData));
  float maxVal = max(max(originalData), max(restoredData));
  int numYTicks = 5;
  float stepVal = (maxVal - minVal) / (numYTicks - 1);
  textAlign(RIGHT, CENTER);
  for (int i = 0; i < numYTicks; i++) {
    float val = minVal + i * stepVal;
    float y = map(val, minVal, maxVal, height - marginBottom, marginTop);
    stroke(200);
    line(marginLeft - 5, y, width - marginRight, y);
    stroke(0);
    line(marginLeft - 5, y, marginLeft, y);
    fill(0);
    text(nf(val, 1, 1), marginLeft - 10, y);
  }

  // x-axis ticks
  int numXTicks = 10;
  float tickSpacing = (width - marginLeft - marginRight) / (float) numXTicks;
  textAlign(CENTER, TOP);
  for (int i = 0; i <= numXTicks; i++) {
    float x = marginLeft + i * tickSpacing;
    stroke(0);
    line(x, height - marginBottom, x, height - marginBottom + 5);
    int idx = (int) map(i, 0, numXTicks, 0, originalData.length - 1);
    text(str(idx), x, height - marginBottom + 8);
  }
}

void drawPlot() {
  int marginLeft = 60;
  int marginBottom = 40;
  int marginTop = 20;
  int marginRight = 20;

  float minVal = min(min(originalData), min(restoredData));
  float maxVal = max(max(originalData), max(restoredData));

  // Original data in blue
  stroke(0, 0, 255);
  noFill();
  beginShape();
  for (int i = 0; i < originalData.length; i++) {
    float x = map(i, 0, originalData.length - 1, marginLeft, width - marginRight);
    float y = map(originalData[i], minVal, maxVal, height - marginBottom, marginTop);
    vertex(x, y);
  }
  endShape();

  // Scaled/Restored data in red
  stroke(255, 0, 0);
  noFill();
  beginShape();
  for (int i = 0; i < restoredData.length; i++) {
    float x = map(i, 0, restoredData.length - 1, marginLeft, width - marginRight);
    float y = map(restoredData[i], minVal, maxVal, height - marginBottom, marginTop);
    vertex(x, y);
  }
  endShape();

  // Legend
  fill(0);
  textAlign(LEFT, BOTTOM);
  text("Blue: Original", marginLeft + 10, marginTop + 20);
  text("Red: Scaled/Restored", marginLeft + 10, marginTop + 40);
}
