// Markdown Mind Map Viewer for Processing
// Put your markdown file at: sketch_folder/data/mindmap.md
//
// Rules:
// # Title       -> root node
// ## Heading    -> branch from root
// ### Heading   -> child of previous ##
// #### Heading  -> child of previous ###
// etc.

Node root;
PFont font;

float nodeW = 170;
float nodeH = 42;
float levelGap = 230;
float siblingGap = 24;

void setup() {
  size(1200, 800);
  smooth(8);

  font = createFont("Arial", 15);
  textFont(font);

  root = loadMarkdownMindMap("mindmap.md");

  if (root == null) {
    root = new Node("No # heading found");
  }

  layoutTree(root);
}

void draw() {
  background(245, 247, 250);

  translate(width / 2, height / 2);
  drawBranches(root);
  drawNodes(root);
}

Node loadMarkdownMindMap(String filename) {
  String[] lines = loadStrings(filename);

  if (lines == null) {
    println("Could not load " + filename);
    return null;
  }

  Node root = null;
  Node[] lastAtLevel = new Node[10];

  for (String line : lines) {
    line = trim(line);

    if (!line.startsWith("#")) continue;

    int level = countHeadingLevel(line);
    if (level < 1) continue;

    String title = trim(line.substring(level));
    if (title.length() == 0) continue;

    Node node = new Node(title);
    node.level = level;

    if (level == 1 && root == null) {
      root = node;
      lastAtLevel[1] = node;
    } else {
      Node parent;

      if (level == 2) {
        parent = root;
      } else {
        parent = lastAtLevel[level - 1];

        if (parent == null) {
          parent = root;
        }
      }

      if (parent != null) {
        parent.children.add(node);
        node.parent = parent;
      }

      lastAtLevel[level] = node;
    }

    for (int i = level + 1; i < lastAtLevel.length; i++) {
      lastAtLevel[i] = null;
    }
  }

  return root;
}

int countHeadingLevel(String line) {
  int count = 0;

  while (count < line.length() && line.charAt(count) == '#') {
    count++;
  }

  return count;
}

void layoutTree(Node root) {
  root.x = 0;
  root.y = 0;

  int n = root.children.size();

  for (int i = 0; i < n; i++) {
    Node child = root.children.get(i);

    float side = i % 2 == 0 ? 1 : -1;
    int sideIndex = i / 2;

    child.x = side * levelGap;
    child.y = (sideIndex - n / 4.0) * 95;

    layoutSubtree(child, side, 1);
  }
}

void layoutSubtree(Node node, float side, int depth) {
  int n = node.children.size();

  for (int i = 0; i < n; i++) {
    Node child = node.children.get(i);

    child.x = node.x + side * levelGap;
    child.y = node.y + (i - (n - 1) / 2.0) * (nodeH + siblingGap + 18);

    layoutSubtree(child, side, depth + 1);
  }
}

void drawBranches(Node node) {
  for (Node child : node.children) {
    stroke(120, 145, 170);
    strokeWeight(2);
    noFill();

    float x1 = node.x + nodeW / 2 * sign(child.x - node.x);
    float y1 = node.y;

    float x2 = child.x - nodeW / 2 * sign(child.x - node.x);
    float y2 = child.y;

    float midX = (x1 + x2) / 2;

    bezier(x1, y1, midX, y1, midX, y2, x2, y2);

    drawBranches(child);
  }
}

void drawNodes(Node node) {
  drawNodeBox(node);

  for (Node child : node.children) {
    drawNodes(child);
  }
}

void drawNodeBox(Node node) {
  rectMode(CENTER);

  if (node.level == 1) {
    fill(75, 135, 220);
    stroke(40, 90, 170);
  } else if (node.level == 2) {
    fill(210, 230, 255);
    stroke(95, 140, 190);
  } else {
    fill(255);
    stroke(170, 185, 205);
  }

  strokeWeight(1.6);
  rect(node.x, node.y, nodeW, nodeH, 14);

  fill(node.level == 1 ? 255 : 30);
  noStroke();
  textAlign(CENTER, CENTER);
  textSize(node.level == 1 ? 16 : 14);

  text(fitText(node.title, 22), node.x, node.y);
}

String fitText(String s, int maxChars) {
  if (s.length() <= maxChars) return s;
  return s.substring(0, maxChars - 1) + "…";
}

float sign(float v) {
  if (v < 0) return -1;
  return 1;
}

class Node {
  String title;
  int level = 1;
  float x, y;
  Node parent;
  ArrayList<Node> children = new ArrayList<Node>();

  Node(String title) {
    this.title = title;
  }
}
