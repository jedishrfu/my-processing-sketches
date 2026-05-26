// AST visualization in Processing
// Non-overlapping layout via subtree widths.

// ---- AST node definitions ----

abstract class Expr {
  abstract String toInfix();
}

class NumberExpr extends Expr {
  float value;
  NumberExpr(float v) { value = v; }
  String toInfix() { return nf(value, 0, 2); }
}

class VariableExpr extends Expr {
  String name;
  VariableExpr(String n) { name = n; }
  String toInfix() { return name; }
}

class UnaryExpr extends Expr {
  char op;
  Expr operand;
  UnaryExpr(char op, Expr operand) { this.op = op; this.operand = operand; }
  String toInfix() { return op + operand.toInfix(); }
}

class BinaryExpr extends Expr {
  char op;
  Expr left, right;
  BinaryExpr(char op, Expr left, Expr right) {
    this.op = op;
    this.left = left;
    this.right = right;
  }
  String toInfix() {
    return "(" + left.toInfix() + " " + op + " " + right.toInfix() + ")";
  }
}

class FuncCallExpr extends Expr {
  String name;
  Expr[] args;
  FuncCallExpr(String name, Expr[] args) {
    this.name = name;
    this.args = args;
  }
  String toInfix() {
    String s = name + "(";
    for (int i = 0; i < args.length; i++) {
      if (i > 0) s += ", ";
      s += args[i].toInfix();
    }
    s += ")";
    return s;
  }
}

// ---- Example AST ----

Expr root;

void buildExampleAst() {
  Expr a = new VariableExpr("a");
  Expr x = new VariableExpr("x");
  Expr k0 = new VariableExpr("K0");

  Expr min_ax = new FuncCallExpr("min", new Expr[]{ a, x });
  Expr sin_x = new FuncCallExpr("sin", new Expr[]{ x });
  Expr ln_k0 = new FuncCallExpr("ln", new Expr[]{ k0 });
  Expr plus = new BinaryExpr('+', sin_x, ln_k0);
  root = new FuncCallExpr("max", new Expr[]{ min_ax, plus });
}

// ---- Layout structures ----

class NodeLayout {
  Expr expr;
  float x, y;
  NodeLayout[] children;
}

float nodeRadius = 18;
float horizontalPadding = 20;  // extra space around subtrees
float verticalSpacing = 80;

// First pass: compute subtree width in pixels.
float computeWidth(Expr e) {
  if (e == null) return 0;
  float minWidth = nodeRadius * 2 + horizontalPadding;

  if (e instanceof BinaryExpr) {
    BinaryExpr b = (BinaryExpr)e;
    float lw = computeWidth(b.left);
    float rw = computeWidth(b.right);
    return max(minWidth, lw + rw);
  } else if (e instanceof UnaryExpr) {
    return max(minWidth, computeWidth(((UnaryExpr)e).operand));
  } else if (e instanceof FuncCallExpr) {
    FuncCallExpr f = (FuncCallExpr)e;
    if (f.args.length == 0) return minWidth;
    float total = 0;
    for (int i = 0; i < f.args.length; i++) {
      float w = computeWidth(f.args[i]);
      total += w;
      if (i < f.args.length - 1) total += horizontalPadding;
    }
    return max(minWidth, total);
  } else {
    // Number or variable: single node width
    return minWidth;
  }
}

// Second pass: assign node positions using subtree width.
NodeLayout assignPositions(Expr e, float centerX, float y) {
  if (e == null) return null;
  NodeLayout n = new NodeLayout();
  n.expr = e;
  n.x = centerX;
  n.y = y;

  if (e instanceof BinaryExpr) {
    BinaryExpr b = (BinaryExpr)e;
    float lw = computeWidth(b.left);
    float rw = computeWidth(b.right);
    float total = lw + rw;
    // place left subtree centered over [centerX - total/2, centerX - total/2 + lw]
    float leftCenter = centerX - total/2 + lw/2;
    float rightCenter = centerX + total/2 - rw/2;

    n.children = new NodeLayout[2];
    n.children[0] = assignPositions(b.left, leftCenter, y + verticalSpacing);
    n.children[1] = assignPositions(b.right, rightCenter, y + verticalSpacing);

  } else if (e instanceof UnaryExpr) {
    UnaryExpr u = (UnaryExpr)e;
    n.children = new NodeLayout[1];
    n.children[0] = assignPositions(u.operand, centerX, y + verticalSpacing);

  } else if (e instanceof FuncCallExpr) {
    FuncCallExpr f = (FuncCallExpr)e;
    int k = f.args.length;
    n.children = new NodeLayout[k];
    if (k > 0) {
      float[] widths = new float[k];
      float total = 0;
      for (int i = 0; i < k; i++) {
        widths[i] = computeWidth(f.args[i]);
        total += widths[i];
        if (i < k - 1) total += horizontalPadding;
      }
      float leftEdge = centerX - total / 2;
      float cursor = leftEdge;
      for (int i = 0; i < k; i++) {
        float cx = cursor + widths[i] / 2;
        n.children[i] = assignPositions(f.args[i], cx, y + verticalSpacing);
        cursor += widths[i];
        if (i < k - 1) cursor += horizontalPadding;
      }
    }

  } else {
    // leaf: no children
    n.children = null;
  }

  return n;
}

void drawLayout(NodeLayout n) {
  if (n == null) return;

  // edges
  if (n.children != null) {
    stroke(0);
    for (NodeLayout c : n.children) {
      if (c != null) {
        line(n.x, n.y, c.x, c.y);
        drawLayout(c);
      }
    }
  }

  // node
  fill(255);
  stroke(0);
  ellipse(n.x, n.y, nodeRadius*2, nodeRadius*2);

  // label
  fill(0);
  textAlign(CENTER, CENTER);
  text(nodeLabel(n.expr), n.x, n.y);
}

String nodeLabel(Expr e) {
  if (e instanceof NumberExpr) {
    return nf(((NumberExpr)e).value, 0, 1);
  } else if (e instanceof VariableExpr) {
    return ((VariableExpr)e).name;
  } else if (e instanceof UnaryExpr) {
    return "" + ((UnaryExpr)e).op;
  } else if (e instanceof BinaryExpr) {
    return "" + ((BinaryExpr)e).op;
  } else if (e instanceof FuncCallExpr) {
    return ((FuncCallExpr)e).name;
  }
  return "?";
}

// ---- Processing setup/draw ----

NodeLayout layoutRoot;

void setup() {
  size(900, 600);
  textFont(createFont("Consolas", 14));
  buildExampleAst();
  float totalWidth = computeWidth(root);
  float cx = width / 2.0;
  layoutRoot = assignPositions(root, cx, 150);
}

void draw() {
  background(250);

  // expression at top
  fill(0);
  textAlign(LEFT, TOP);
  if (root != null) {
    text("Expression: " + root.toInfix(), 10, 10);
  }

  translate(0, 40);
  drawLayout(layoutRoot);
}

