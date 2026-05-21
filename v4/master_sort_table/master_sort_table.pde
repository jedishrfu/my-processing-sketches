/**
 * Sorting Algorithms Visualization (with Pin + Info Panel)
 * 
 * - Shows groups of sorting algorithms by category as colored "tags".
 * - Mouse wheel to scroll.
 * - Hover over any algorithm to highlight it and see a tooltip.
 * - Click a tag to PIN its category (others dim); click again to unpin.
 * - Click also selects the algorithm and shows a mini info panel
 *   (complexity, stability, in-place, notes).
 * 
 * Tested for Processing 3.x / 4.x (Java mode).
 */

import java.util.*;
import processing.event.MouseEvent;

class AlgoNode {
  String name;
  String category;
  float x, y, w, h;  // screen coordinates
  int categoryIndex;
  
  AlgoNode(String name, String category, float x, float y, float w, float h, int categoryIndex) {
    this.name = name;
    this.category = category;
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.categoryIndex = categoryIndex;
  }
}

class AlgoInfo {
  String name;
  String categoryType;   // e.g. "Comparison sort", "Non-comparison (radix)"
  String best;
  String average;
  String worst;
  String stable;         // "Yes", "No", "Varies"
  String inPlace;        // "Yes", "No", "Varies"
  String notes;
  
  AlgoInfo(String name,
           String categoryType,
           String best,
           String average,
           String worst,
           String stable,
           String inPlace,
           String notes) {
    this.name = name;
    this.categoryType = categoryType;
    this.best = best;
    this.average = average;
    this.worst = worst;
    this.stable = stable;
    this.inPlace = inPlace;
    this.notes = notes;
  }
}

// Data: categories and algorithms
String[][] CATEGORIES = {
  {
    "Simple Comparison Sorts",
    "Bubble Sort", "Optimized Bubble Sort", "Cocktail Shaker Sort",
    "Gnome Sort", "Stooge Sort", "Bogo Sort", "Bozo Sort", "Slow Sort"
  },
  {
    "Insertion-Based Sorts",
    "Insertion Sort", "Binary Insertion Sort", "Library Sort", "Patience Sorting"
  },
  {
    "Selection-Based Sorts",
    "Selection Sort", "Heapsort", "Smoothsort",
    "Weak Heapsort", "Tournament Sort", "Replacement Selection"
  },
  {
    "Merge-Based Divide-and-Conquer",
    "Merge Sort", "Top-Down Merge Sort", "Bottom-Up Merge Sort",
    "Natural Merge Sort", "TimSort", "Block Merge Sort",
    "GrailSort", "Wikisort"
  },
  {
    "QuickSort Family",
    "QuickSort", "3-way QuickSort", "Dual-Pivot QuickSort",
    "Introsort", "Median-of-Three QuickSort", "Randomized QuickSort"
  },
  {
    "Shell & Gap Sorts",
    "Shellsort", "Hibbard Gap Shellsort", "Sedgewick Gap Shellsort",
    "Ciura Gap Shellsort"
  },
  {
    "Radix & Counting Sorts",
    "LSD Radix Sort", "MSD Radix Sort", "American Flag Sort",
    "Counting Sort", "Bucket Sort", "Pigeonhole Sort",
    "Proxmap Sort"
  },
  {
    "Tree & Graph Sorts",
    "Binary Tree Sort", "Treap Sort", "Splay-Tree Sort",
    "Red-Black Tree Sort", "Topological Sort", "Cycle Sort"
  },
  {
    "Parallel & Network Sorts",
    "Bitonic Sort", "Odd-Even Merge Sort", "AKS Sorting Network",
    "Parallel Merge Sort", "Parallel Radix Sort", "Sample Sort"
  },
  {
    "String & Trie Sorts",
    "3-Way Radix QuickSort", "Multikey Quicksort", "Burstsort",
    "Trie Sort", "Radix Tree Sort", "SA-IS"
  },
  {
    "External & Cache-Efficient Sorts",
    "External Merge Sort", "Multiway Merge Sort", "Polyphase Merge Sort",
    "Cache-Oblivious Merge Sort", "Histogram Sort"
  },
  {
    "Hybrid Real-World Sorts",
    "TimSort", "PDQSort", "IPS4O",
    "BlockQuicksort", "FluxSort",
    "C++ std::sort", "C++ std::stable_sort"
  },
  {
    "Esoteric / Fun Sorts",
    "Sleep Sort", "Pancake Sort", "Spaghetti Sort",
    "Bead Sort", "Quantum Bogosort"
  }
};

ArrayList<AlgoNode> nodes = new ArrayList<AlgoNode>();
color[] categoryColors;

float scrollOffset = 0;
float contentHeight = 0;
float margin = 40;
float legendWidth = 260;

PFont titleFont;
PFont headerFont;
PFont bodyFont;

// Pinning + info panel state
int pinnedCategoryIndex = -1;
String selectedAlgoName = null;
String selectedAlgoCategory = null;

// Detailed info map
HashMap<String, AlgoInfo> algoInfoMap = new HashMap<String, AlgoInfo>();

void setup() {
  size(1200, 700);
  smooth(4);
  
  titleFont = createFont("SansSerif.bold", 32);
  headerFont = createFont("SansSerif.bold", 18);
  bodyFont = createFont("SansSerif", 14);
  
  // Generate colors per category
  categoryColors = new color[CATEGORIES.length];
  
  colorMode(HSB, 255);
  for (int i = 0; i < CATEGORIES.length; i++) {
    float hue = map(i, 0, CATEGORIES.length, 0, 255);
    categoryColors[i] = color(hue, 180, 230);
  }
  colorMode(RGB, 255);
  
  initAlgoInfo();
}

void draw() {
  background(18, 20, 25);
  nodes.clear();
  
  drawTitleBar();
  layoutAndDrawCategories();
  drawLegend();
  drawHoverHighlightAndTooltip();
  drawInfoPanel();
  
  // Scroll bounds (after computing contentHeight)
  float minScroll = min(0, height - contentHeight - margin);
  float maxScroll = 0;
  scrollOffset = constrain(scrollOffset, minScroll, maxScroll);
}

void drawTitleBar() {
  noStroke();
  fill(28, 30, 38);
  rect(0, 0, width, 70);
  
  fill(240);
  textFont(titleFont);
  textAlign(LEFT, CENTER);
  text("Sorting Algorithms Map", margin, 35);
  
  textFont(bodyFont);
  fill(190);
  String subtitle = "Mouse wheel: scroll • Hover: tooltip • Click: pin category + show info • Press '0': reset scroll";
  text(subtitle, margin + 420, 35);
}

// Main layout + drawing of categories and tags
void layoutAndDrawCategories() {
  textFont(bodyFont);
  textAlign(LEFT, TOP);
  
  float currentY = 80;        // below title bar
  float tagHeight = 26;
  float tagPaddingX = 10;
  float tagGapX = 10;
  float tagGapY = 8;
  float categoryGap = 35;
  float headerGap = 8;
  
  float panelLeft = margin;
  float panelRight = width - legendWidth - margin;
  
  for (int ci = 0; ci < CATEGORIES.length; ci++) {
    String categoryName = CATEGORIES[ci][0];
    
    // Draw category header
    float headerYScreen = currentY + scrollOffset;
    if (headerYScreen > -40 && headerYScreen < height + 40) {
      // Dim header if another category is pinned
      if (pinnedCategoryIndex != -1 && ci != pinnedCategoryIndex) {
        fill(150);
      } else {
        fill(235);
      }
      textFont(headerFont);
      text(categoryName, panelLeft, headerYScreen);
    }
    
    currentY += headerGap + textAscent() + textDescent();
    float x = panelLeft;
    float y = currentY;
    
    textFont(bodyFont);
    
    // Algorithms in this category
    for (int ai = 1; ai < CATEGORIES[ci].length; ai++) {
      String algo = CATEGORIES[ci][ai];
      float tw = textWidth(algo) + 2 * tagPaddingX;
      
      // Wrap into next line if too wide
      if (x + tw > panelRight) {
        x = panelLeft;
        y += tagHeight + tagGapY;
      }
      
      float yScreen = y + scrollOffset;
      
      // Compute color, dim if not pinned
      int baseCol = categoryColors[ci];
      int borderCol = lerpColor(baseCol, color(0), 0.5);
      boolean dim = (pinnedCategoryIndex != -1 && ci != pinnedCategoryIndex);
      
      if (dim) {
        baseCol = lerpColor(baseCol, color(60), 0.65);
        borderCol = lerpColor(borderCol, color(40), 0.75);
      }
      
      // Draw tag if visible on screen
      if (yScreen + tagHeight > 70 && yScreen < height + 40) {
        // Background
        fill(borderCol);
        stroke(0, 100);
        strokeWeight(1.2);
        rect(x, yScreen, tw, tagHeight, 12);
        
        // Inner lighter fill
        noStroke();
        fill(baseCol);
        rect(x + 1, yScreen + 1, tw - 2, tagHeight - 2, 11);
        
        // Text
        if (dim) {
          fill(40);
        } else {
          fill(15);
        }
        textAlign(LEFT, CENTER);
        text(algo, x + tagPaddingX, yScreen + tagHeight * 0.52);
      }
      
      // Store node (screen coordinates)
      nodes.add(new AlgoNode(algo, categoryName, x, y + scrollOffset, tw, tagHeight, ci));
      
      x += tw + tagGapX;
    }
    
    // advance vertical position for next category
    y += tagHeight;
    currentY = y + categoryGap;
  }
  
  // Total content height in unscrolled coordinates
  contentHeight = currentY;
}

void drawLegend() {
  float legendX = width - legendWidth + 20;
  float legendY = 90;
  
  // Legend background
  noStroke();
  fill(25, 28, 36, 245);
  rect(width - legendWidth, 70, legendWidth, height - 70);
  
  // Legend title
  textFont(headerFont);
  fill(240);
  textAlign(LEFT, TOP);
  text("Categories", legendX, legendY);
  legendY += 28;
  
  textFont(bodyFont);
  for (int i = 0; i < CATEGORIES.length; i++) {
    String cat = CATEGORIES[i][0];
    int col = categoryColors[i];
    
    boolean dim = (pinnedCategoryIndex != -1 && i != pinnedCategoryIndex);
    if (dim) {
      col = lerpColor(col, color(60), 0.65);
    }
    
    // Color swatch
    fill(col);
    stroke(0, 120);
    strokeWeight(1);
    rect(legendX, legendY + 4, 16, 16, 4);
    
    noStroke();
    if (dim) {
      fill(160);
    } else {
      fill(220);
    }
    text(cat, legendX + 24, legendY);
    
    legendY += 22;
    
    if (legendY > height - 40) {
      // Stop if we run out of space
      break;
    }
  }
}

// Hover highlight and tooltip
void drawHoverHighlightAndTooltip() {
  AlgoNode hovered = null;
  
  for (AlgoNode node : nodes) {
    if (mouseX >= node.x && mouseX <= node.x + node.w &&
        mouseY >= node.y && mouseY <= node.y + node.h) {
      hovered = node;
      break;
    }
  }
  
  if (hovered != null) {
    // Highlight border around hovered tag
    stroke(255, 250, 200);
    strokeWeight(2.5);
    noFill();
    rect(hovered.x - 2, hovered.y - 2, hovered.w + 4, hovered.h + 4, 14);
    
    // Tooltip
    String line1 = hovered.name;
    String line2 = "Category: " + hovered.category;
    
    textFont(bodyFont);
    textAlign(LEFT, TOP);
    float tw = max(textWidth(line1), textWidth(line2)) + 20;
    float th = 40;
    
    float tx = mouseX + 16;
    float ty = mouseY + 16;
    
    if (tx + tw > width - 10) tx = width - tw - 10;
    if (ty + th > height - 10) ty = height - th - 10;
    
    // Tooltip background
    noStroke();
    fill(20, 20, 25, 230);
    rect(tx, ty, tw, th, 8);
    stroke(255, 255, 220, 220);
    noFill();
    rect(tx, ty, tw, th, 8);
    
    // Tooltip text
    fill(245);
    text(line1, tx + 10, ty + 6);
    fill(200);
    text(line2, tx + 10, ty + 6 + 18);
  }
}

// Info panel at bottom-left for selected algorithm
void drawInfoPanel() {
  if (selectedAlgoName == null) return;
  
  AlgoInfo info = algoInfoMap.get(selectedAlgoName);
  
  float panelWidth = min(520, width - legendWidth - 2 * margin);
  float panelHeight = 130;
  float panelX = margin;
  float panelY = height - panelHeight - 20;
  
  // Background
  noStroke();
  fill(18, 20, 30, 235);
  rect(panelX, panelY, panelWidth, panelHeight, 10);
  
  stroke(255, 255, 200, 180);
  noFill();
  rect(panelX, panelY, panelWidth, panelHeight, 10);
  
  textFont(headerFont);
  textAlign(LEFT, TOP);
  fill(240);
  String title = selectedAlgoName;
  text(title, panelX + 12, panelY + 10);
  
  textFont(bodyFont);
  float y = panelY + 40;
  float x = panelX + 12;
  
  fill(200);
  String catLine = "Category: " + (selectedAlgoCategory == null ? "Unknown" : selectedAlgoCategory);
  text(catLine, x, y);
  y += 18;
  
  if (info != null) {
    text("Type: " + info.categoryType, x, y);
    y += 18;
    text("Best:    " + info.best, x, y);
    y += 16;
    text("Average: " + info.average, x, y);
    y += 16;
    text("Worst:   " + info.worst, x, y);
    y += 18;
    text("Stable: " + info.stable + "    In-place: " + info.inPlace, x, y);
    y += 18;
    
    // Notes, possibly wrapping if needed
    String notesLabel = "Notes: " + info.notes;
    drawWrappedText(notesLabel, x, y, panelWidth - 24);
  } else {
    text("No detailed complexity info in this sketch for this algorithm.", x, y);
    y += 18;
    drawWrappedText("Notes: Likely comparison-based with ~O(n log n) average; details depend on the reference implementation.", x, y, panelWidth - 24);
  }
}

// Simple word-wrap drawer for small notes
void drawWrappedText(String s, float x, float y, float maxWidth) {
  String[] words = split(s, ' ');
  String line = "";
  for (int i = 0; i < words.length; i++) {
    String testLine = (line.length() == 0) ? words[i] : (line + " " + words[i]);
    if (textWidth(testLine) > maxWidth) {
      text(line, x, y);
      y += 16;
      line = words[i];
    } else {
      line = testLine;
    }
  }
  if (line.length() > 0) {
    text(line, x, y);
  }
}

// Mouse wheel scrolling
void mouseWheel(MouseEvent event) {
  float e = event.getCount();
  scrollOffset -= e * 30; // scroll step
}

// Click to pin category + select algo for info panel
void mousePressed() {
  AlgoNode clicked = null;
  for (AlgoNode node : nodes) {
    if (mouseX >= node.x && mouseX <= node.x + node.w &&
        mouseY >= node.y && mouseY <= node.y + node.h) {
      clicked = node;
      break;
    }
  }
  
  if (clicked != null) {
    // Toggle pin
    if (pinnedCategoryIndex == clicked.categoryIndex) {
      pinnedCategoryIndex = -1;
    } else {
      pinnedCategoryIndex = clicked.categoryIndex;
    }
    
    // Update selected algorithm for info panel
    selectedAlgoName = clicked.name;
    selectedAlgoCategory = clicked.category;
  }
}

// Optional: reset scroll with '0'
void keyPressed() {
  if (key == '0') {
    scrollOffset = 0;
  }
}

// Initialize complexity / stability info
void initAlgoInfo() {
  // Helper for adding
  addInfo("Bubble Sort",
          "Comparison sort",
          "O(n)",
          "O(n^2)",
          "O(n^2)",
          "Yes",
          "Yes",
          "Simple quadratic sort; good for teaching, rarely used in production.");
          
  addInfo("Optimized Bubble Sort",
          "Comparison sort",
          "O(n)",
          "O(n^2)",
          "O(n^2)",
          "Yes",
          "Yes",
          "Stops early if no swaps occur on a pass.");
          
  addInfo("Cocktail Shaker Sort",
          "Comparison sort",
          "O(n)",
          "O(n^2)",
          "O(n^2)",
          "Yes",
          "Yes",
          "Bidirectional bubble; slightly better on some inputs.");
          
  addInfo("Gnome Sort",
          "Comparison sort",
          "O(n)",
          "O(n^2)",
          "O(n^2)",
          "Yes",
          "Yes",
          "Conceptually similar to insertion sort using swaps.");
          
  addInfo("Stooge Sort",
          "Comparison sort (inefficient)",
          "≈O(n^2.7)",
          "≈O(n^2.7)",
          "≈O(n^2.7)",
          "Yes",
          "No",
          "Deliberately inefficient; used as a curiosity.");
          
  addInfo("Bogo Sort",
          "Randomized comparison (inefficient)",
          "O(n)",
          "O((n+1)!)",
          "Unbounded expected",
          "No",
          "No",
          "Randomly shuffles until sorted; joke/teaching algorithm.");
          
  addInfo("Bozo Sort",
          "Randomized comparison (inefficient)",
          "O(n)",
          "Very large (randomized)",
          "Unbounded expected",
          "No",
          "No",
          "Randomly swaps elements until sorted.");
          
  addInfo("Slow Sort",
          "Comparison sort (inefficient)",
          "O(n^2)",
          "O(n^2 log n)",
          "O(n^2 log n)",
          "Yes",
          "No",
          "Recursive 'proof by induction' joke sort.");
          
  // Insertion-based
  addInfo("Insertion Sort",
          "Comparison sort",
          "O(n)",
          "O(n^2)",
          "O(n^2)",
          "Yes",
          "Yes",
          "Very fast on small or nearly sorted arrays; used in hybrids.");
          
  addInfo("Binary Insertion Sort",
          "Comparison sort",
          "O(n)",
          "O(n^2)",
          "O(n^2)",
          "Yes",
          "Yes",
          "Uses binary search to find position; fewer comparisons, same moves.");
          
  addInfo("Library Sort",
          "Comparison sort",
          "O(n log n)",
          "O(n log n)",
          "O(n^2)",
          "Yes (typically)",
          "No (extra gaps)",
          "Uses gaps like a bookshelf; amortized O(n log n) in average case.");
          
  addInfo("Patience Sorting",
          "Comparison sort / LIS-related",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "Yes",
          "No (extra piles)",
          "Based on card game patience; used for LIS and TimSort runs.");
          
  // Selection-based
  addInfo("Selection Sort",
          "Comparison sort",
          "O(n^2)",
          "O(n^2)",
          "O(n^2)",
          "No",
          "Yes",
          "Performs minimal swaps; good when writes are expensive.");
          
  addInfo("Heapsort",
          "Comparison sort (heap-based)",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "No",
          "Yes",
          "In-place and reliable; used as fallback in introsort.");
          
  addInfo("Smoothsort",
          "Comparison sort (heap-like)",
          "O(n)",
          "O(n log n)",
          "O(n log n)",
          "No",
          "Yes",
          "Dijkstra’s adaptive heap; linear on nearly sorted data.");
          
  addInfo("Weak Heapsort",
          "Comparison sort (heap variant)",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "No",
          "Yes",
          "Variant of heapsort with fewer comparisons.");
          
  addInfo("Tournament Sort",
          "Comparison sort",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "No (usually)",
          "No (tree structure)",
          "Uses winner tree; useful in external merge pipelines.");
          
  addInfo("Replacement Selection",
          "External selection / run generation",
          "O(n log M)",
          "O(n log M)",
          "O(n log M)",
          "N/A",
          "No",
          "Used to generate long runs for external merge sort (M = memory).");
          
  // Merge-based
  addInfo("Merge Sort",
          "Comparison sort (divide-and-conquer)",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "Yes",
          "No (unless special techniques)",
          "Stable, predictable; standard library default for stable sorts.");
          
  addInfo("Top-Down Merge Sort",
          "Comparison sort (divide-and-conquer)",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "Yes",
          "No",
          "Recursive variant of merge sort.");
          
  addInfo("Bottom-Up Merge Sort",
          "Comparison sort (divide-and-conquer)",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "Yes",
          "No",
          "Iterative merge sort; good for external and streaming contexts.");
          
  addInfo("Natural Merge Sort",
          "Adaptive merge sort",
          "O(n)",
          "O(n log n)",
          "O(n log n)",
          "Yes",
          "No",
          "Uses existing runs; faster on partially sorted data.");
          
  addInfo("TimSort",
          "Hybrid comparison sort",
          "O(n)",
          "O(n log n)",
          "O(n log n)",
          "Yes",
          "No",
          "Python/Java standard sort; highly tuned for real-world data.");
          
  addInfo("Block Merge Sort",
          "Comparison sort (block-based merge)",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "Yes",
          "Almost (uses small extra buffers)",
          "Reduces extra memory while staying stable.");
          
  addInfo("GrailSort",
          "Comparison sort (in-place stable)",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "Yes",
          "Yes (uses O(1) or small buffer)",
          "Engineering-focused in-place stable merge sort.");
          
  addInfo("Wikisort",
          "Comparison sort (in-place stable)",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "Yes",
          "Yes (small buffer)",
          "Practical in-place stable sort popularized via Wiki article.");
          
  // QuickSort family
  addInfo("QuickSort",
          "Comparison sort (partition-based)",
          "O(n log n)",
          "O(n log n)",
          "O(n^2)",
          "No (standard)",
          "Yes",
          "Very fast in practice; pivot choice is critical.");
          
  addInfo("3-way QuickSort",
          "Comparison sort (partition-based)",
          "O(n)",
          "O(n log n)",
          "O(n^2)",
          "No",
          "Yes",
          "Handles many equal keys efficiently via 3-way partitioning.");
          
  addInfo("Dual-Pivot QuickSort",
          "Comparison sort (partition-based)",
          "O(n log n)",
          "O(n log n)",
          "O(n^2)",
          "No",
          "Yes",
          "Used in Java for primitives; tuned dual-pivot variant.");
          
  addInfo("Introsort",
          "Hybrid comparison sort",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "No",
          "Yes",
          "Combines quicksort, heapsort, insertion; used in C++ std::sort.");
          
  addInfo("Median-of-Three QuickSort",
          "Comparison sort (partition-based)",
          "O(n log n)",
          "O(n log n)",
          "O(n^2)",
          "No",
          "Yes",
          "Uses median of three elements as pivot to reduce bad cases.");
          
  addInfo("Randomized QuickSort",
          "Randomized comparison sort",
          "O(n log n)",
          "O(n log n) expected",
          "O(n^2)",
          "No",
          "Yes",
          "Random pivot selection gives good expected performance.");
          
  // Shell & gap sorts
  addInfo("Shellsort",
          "Comparison sort (gap-based)",
          "O(n log^2 n) or better",
          "Depends on gaps",
          "Depends on gaps",
          "No (usually)",
          "Yes",
          "Early practical sort; performance depends heavily on gap sequence.");
          
  addInfo("Hibbard Gap Shellsort",
          "Comparison sort (gap-based)",
          "O(n^(3/2))",
          "O(n^(3/2))",
          "O(n^(3/2))",
          "No",
          "Yes",
          "Uses gaps 1,3,7,... (2^k − 1).");
          
  addInfo("Sedgewick Gap Shellsort",
          "Comparison sort (gap-based)",
          "≈O(n^(4/3))",
          "≈O(n^(4/3))",
          "≈O(n^(4/3))",
          "No",
          "Yes",
          "Empirically efficient gap sequence due to Sedgewick.");
          
  addInfo("Ciura Gap Shellsort",
          "Comparison sort (gap-based)",
          "Empirically fast",
          "Empirically fast",
          "Unknown tight bound",
          "No",
          "Yes",
          "Popular practical sequence: 1,4,10,23,57,...");
          
  // Radix & counting
  addInfo("LSD Radix Sort",
          "Non-comparison (radix)",
          "O(w·n)",
          "O(w·n)",
          "O(w·n)",
          "Yes",
          "No (typically uses buckets)",
          "Digit-by-digit from least significant; good for fixed-width keys.");
          
  addInfo("MSD Radix Sort",
          "Non-comparison (radix)",
          "O(w·n)",
          "O(w·n)",
          "O(w·n)",
          "Often",
          "No",
          "Top-down radix; useful for variable-length strings/keys.");
          
  addInfo("American Flag Sort",
          "Non-comparison (radix, in-place)",
          "O(w·n)",
          "O(w·n)",
          "O(w·n)",
          "Not inherently",
          "Yes (in-place)",
          "In-place MSB radix variant; good cache behavior.");
          
  addInfo("Counting Sort",
          "Non-comparison (counting)",
          "O(n + k)",
          "O(n + k)",
          "O(n + k)",
          "Yes",
          "No (extra count array)",
          "Requires small integer key range [0,k).");
          
  addInfo("Bucket Sort",
          "Non-comparison (distribution)",
          "O(n + k)",
          "O(n + k)",
          "O(n^2) worst",
          "Depends on inner sort",
          "No",
          "Assumes roughly uniform distribution into buckets.");
          
  addInfo("Pigeonhole Sort",
          "Non-comparison (distribution)",
          "O(n + k)",
          "O(n + k)",
          "O(n + k)",
          "Yes",
          "No",
          "Simple distribution sort for dense keys.");
          
  addInfo("Proxmap Sort",
          "Non-comparison (distribution)",
          "O(n)",
          "O(n)",
          "O(n^2)",
          "Usually",
          "No",
          "Uses mapping function to place records into proximate buckets.");
          
  // Tree & graph sorts
  addInfo("Binary Tree Sort",
          "Comparison sort (tree-based)",
          "O(n log n)",
          "O(n log n)",
          "O(n^2)",
          "Yes (if implemented carefully)",
          "No (tree structure)",
          "Insert into BST then traverse in-order.");
          
  addInfo("Treap Sort",
          "Randomized tree-based sort",
          "O(n log n)",
          "O(n log n) expected",
          "O(n^2)",
          "Yes (with stable insertion)",
          "No",
          "BST + heap by random priority; good expected performance.");
          
  addInfo("Splay-Tree Sort",
          "Self-adjusting tree sort",
          "O(n log n) amortized",
          "O(n log n) amortized",
          "O(n^2)",
          "Varies",
          "No",
          "Uses splay tree; amortized guarantees.");
          
  addInfo("Red-Black Tree Sort",
          "Balanced tree sort",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "Varies",
          "No",
          "Balanced BST; similar complexity to other balanced trees.");
          
  addInfo("Topological Sort",
          "Graph-based ordering",
          "O(V + E)",
          "O(V + E)",
          "O(V + E)",
          "N/A",
          "N/A",
          "Orders DAG vertices; not a general comparison sort.");
          
  addInfo("Cycle Sort",
          "Comparison sort (min-writes)",
          "O(n^2)",
          "O(n^2)",
          "O(n^2)",
          "No",
          "Yes",
          "Minimizes writes; used when write operations are expensive.");
          
  // Parallel & network
  addInfo("Bitonic Sort",
          "Sorting network / parallel",
          "O(log^2 n)",
          "O(log^2 n)",
          "O(log^2 n)",
          "No (network-level)",
          "Yes (network)",
          "Fixed network; popular on GPUs and hardware.");
          
  addInfo("Odd-Even Merge Sort",
          "Sorting network / parallel",
          "O(log^2 n)",
          "O(log^2 n)",
          "O(log^2 n)",
          "No (network-level)",
          "Yes",
          "Batcher’s network; used in parallel hardware.");
          
  addInfo("AKS Sorting Network",
          "Theoretical sorting network",
          "O(log n)",
          "O(log n)",
          "O(log n)",
          "No",
          "Yes",
          "Asymptotically optimal but impractical; theoretical interest.");
          
  addInfo("Parallel Merge Sort",
          "Parallel comparison sort",
          "O((n log n)/p + log n)",
          "O((n log n)/p + log n)",
          "O((n log n)/p + log n)",
          "Yes",
          "No",
          "Parallelizes merging across processors (p = processors).");
          
  addInfo("Parallel Radix Sort",
          "Parallel non-comparison",
          "O((w·n)/p + overhead)",
          "O((w·n)/p + overhead)",
          "O((w·n)/p + overhead)",
          "Yes",
          "No",
          "Heavily used on GPUs for key-value pairs.");
          
  addInfo("Sample Sort",
          "Parallel comparison sort",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "No",
          "No",
          "Uses samples to split data into buckets; good load balancing.");
          
  // String & trie sorts
  addInfo("3-Way Radix QuickSort",
          "String / radix + comparison",
          "O(n + R)",
          "O(n log R)",
          "O(n log R)",
          "No",
          "Yes",
          "Efficient for strings with common prefixes (R = alphabet size).");
          
  addInfo("Multikey Quicksort",
          "String comparison sort",
          "O(n)",
          "O(n log n)",
          "O(n^2)",
          "No",
          "Yes",
          "Quicksort adapted to variable-length keys.");
          
  addInfo("Burstsort",
          "Trie-based string sort",
          "O(n·L)",
          "O(n·L)",
          "O(n·L)",
          "Yes",
          "No",
          "Builds burst tries; extremely fast for large string sets.");
          
  addInfo("Trie Sort",
          "Trie-based sort",
          "O(n·L)",
          "O(n·L)",
          "O(n·L)",
          "Yes",
          "No",
          "Insert keys into trie and traverse in lexicographic order.");
          
  addInfo("Radix Tree Sort",
          "Radix / Patricia-based sort",
          "O(n·L)",
          "O(n·L)",
          "O(n·L)",
          "Yes",
          "No",
          "Compressed trie (Patricia) for key ordering.");
          
  addInfo("SA-IS",
          "Suffix array construction",
          "O(n)",
          "O(n)",
          "O(n)",
          "N/A",
          "No",
          "Induced sorting for suffix arrays; core in string algorithms.");
          
  // External & cache efficient
  addInfo("External Merge Sort",
          "External comparison sort",
          "O(n log_k n)",
          "O(n log_k n)",
          "O(n log_k n)",
          "Yes",
          "No",
          "Minimizes disk I/O; k-way merging with limited RAM.");
          
  addInfo("Multiway Merge Sort",
          "External / multi-way merge",
          "O(n log_k n)",
          "O(n log_k n)",
          "O(n log_k n)",
          "Yes",
          "No",
          "Generalization of merge sort with k-way merge.");
          
  addInfo("Polyphase Merge Sort",
          "Tape-based external merge",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "Yes",
          "No",
          "Balances runs on multiple tapes; classic Knuth-era algorithm.");
          
  addInfo("Cache-Oblivious Merge Sort",
          "Cache-oblivious comparison sort",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "Yes",
          "No",
          "Designed without explicit block sizes yet cache-efficient.");
          
  addInfo("Histogram Sort",
          "Parallel / cache-aware distribution",
          "O(n)",
          "O(n)",
          "O(n)",
          "Varies",
          "No",
          "Parallel histogramming then redistribution; used on NUMA / GPUs.");
          
  // Hybrid real-world
  addInfo("IPS4O",
          "Parallel hybrid comparison sort",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "No",
          "Yes",
          "In-place parallel super scalar samplesort; high performance.");
          
  addInfo("PDQSort",
          "Hybrid comparison sort",
          "O(n)",
          "O(n log n)",
          "O(n log n)",
          "No",
          "Yes",
          "Pattern-defeating quicksort; robust against bad patterns.");
          
  addInfo("BlockQuicksort",
          "Hybrid comparison sort",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "No",
          "Yes",
          "Uses block partitioning to reduce branch mispredictions.");
          
  addInfo("FluxSort",
          "Hybrid comparison sort",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "Varies",
          "Yes",
          "Engineering-tuned hybrid; details depend on implementation.");
          
  addInfo("C++ std::sort",
          "Hybrid comparison sort (introsort)",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "No",
          "Yes",
          "Typically introsort: quicksort + heapsort + insertion.");
          
  addInfo("C++ std::stable_sort",
          "Stable merge-based comparison sort",
          "O(n log n)",
          "O(n log n)",
          "O(n log n)",
          "Yes",
          "No (uses extra buffers)",
          "Stable, often advanced merge or Grail-like implementation.");
          
  // Esoteric / fun
  addInfo("Sleep Sort",
          "Esoteric / timing-based",
          "Varies",
          "Unbounded / impractical",
          "Unbounded / impractical",
          "No",
          "No",
          "Spawns a thread per value and sleeps; not a real algorithm.");
          
  addInfo("Pancake Sort",
          "Comparison sort (prefix reversals)",
          "O(n)",
          "O(n^2)",
          "O(n^2)",
          "No",
          "Yes",
          "Uses prefix reversals (flips) like flipping a pancake stack.");
          
  addInfo("Spaghetti Sort",
          "Physical analogy sort",
          "O(n)",
          "O(n)",
          "O(n)",
          "N/A",
          "No",
          "Thought experiment using spaghetti lengths; not practical code.");
          
  addInfo("Bead Sort",
          "Gravity / abacus-like",
          "O(n)",
          "O(n)",
          "O(n^2)",
          "N/A / disputed",
          "No",
          "Simulates beads falling under gravity; hardware intuition.");
          
  addInfo("Quantum Bogosort",
          "Hypothetical quantum algorithm (joke)",
          "O(n)",
          "O(n)",
          "O(n)",
          "No",
          "No",
          "Assumes the universe collapses only into sorted state; joke example.");
}

// Helper for inserting into map
void addInfo(String name,
             String categoryType,
             String best,
             String average,
             String worst,
             String stable,
             String inPlace,
             String notes) {
  AlgoInfo info = new AlgoInfo(name, categoryType, best, average, worst, stable, inPlace, notes);
  algoInfoMap.put(name, info);
}
