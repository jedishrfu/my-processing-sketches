// Linked List from scratch + visualization + unit tests in setup()
// Drop this in a single .pde file and run in Processing.

// ------------------- Demo / Visualization -------------------
LinkedList<Integer> list = new LinkedList<Integer>();
String lastAction = "Ready.";
int testsPassed = 0, testsFailed = 0;

void setup() {
  size(900, 360);
  textFont(createFont("Menlo", 14));

  // ---------- Run Unit Tests ----------
  runTests();

  // ---------- Seed the visual list ----------
  list.addLast(10);
  list.addLast(20);
  list.addLast(30);
  lastAction = "Seeded: 10 -> 20 -> 30";
}

void draw() {
  background(250);
  drawHeader();
  drawList(list, 50, 200);
}

void drawHeader() {
  fill(20);
  text("Singly Linked List (from scratch) — size: " + list.size(), 20, 24);
  text("Keys: [A] append  [P] prepend  [I] insert@1  [X] remove@1  [C] clear", 20, 44);
  fill(60);
  text("Last action: " + lastAction, 20, 64);

  // Test summary
  fill(20);
  text("Unit Tests — Passed: " + testsPassed + "  Failed: " + testsFailed, 20, 92);
}

void drawList(LinkedList<Integer> ll, float startX, float y) {
  float x = startX;
  float nodeW = 80, nodeH = 40, gap = 30;
  stroke(0);
  fill(255);

  for (int i = 0; i < ll.size(); i++) {
    // Node box
    rect(x, y - nodeH/2, nodeW, nodeH, 8);
    // Value
    fill(0);
    String val = str(ll.get(i));
    textAlign(CENTER, CENTER);
    text(val, x + nodeW/2, y);
    // Index under node
    fill(100);
    textAlign(CENTER, TOP);
    text(i, x + nodeW/2, y + nodeH/2 + 6);
    // Arrow to next
    if (i < ll.size() - 1) {
      float x2 = x + nodeW + gap;
      stroke(0);
      drawArrow(x + nodeW, y, x2 - 8, y);
    }
    x += nodeW + gap;
    fill(255);
  }
  // Null marker at end
  if (ll.size() == 0) {
    fill(150);
    textAlign(LEFT, CENTER);
    text("head = null", startX, y);
  } else {
    fill(150);
    textAlign(LEFT, CENTER);
    text("null", x - 10, y);
  }
}

void drawArrow(float x1, float y1, float x2, float y2) {
  line(x1, y1, x2, y2);
  float a = atan2(y2 - y1, x2 - x1);
  float len = 8;
  pushMatrix();
  translate(x2, y2);
  rotate(a);
  line(0, 0, -len, -len/2);
  line(0, 0, -len,  len/2);
  popMatrix();
}

void keyPressed() {
  if (key == 'a' || key == 'A') {
    int v = (int)random(10, 99);
    list.addLast(v);
    lastAction = "append " + v;
  } else if (key == 'p' || key == 'P') {
    int v = (int)random(10, 99);
    list.addFirst(v);
    lastAction = "prepend " + v;
  } else if (key == 'i' || key == 'I') {
    int v = (int)random(10, 99);
    int idx = min(1, list.size()); // insert at 1 if possible, else at end
    list.insertAt(idx, v);
    lastAction = "insert " + v + " at index " + idx;
  } else if (key == 'x' || key == 'X') {
    if (!list.isEmpty() && list.size() > 1) {
      int removed = list.removeAt(1);
      lastAction = "remove value " + removed + " at index 1";
    } else {
      lastAction = "nothing to remove at index 1";
    }
  } else if (key == 'c' || key == 'C') {
    list.clear();
    lastAction = "clear";
  }
}

// ------------------- Tiny Test Helpers -------------------
void runTests() {
  println("=== Running LinkedList unit tests ===");
  LinkedList<Integer> t = new LinkedList<Integer>();

  // size / isEmpty
  expectEquals("new list size==0", 0, t.size());
  expectTrue("new list isEmpty", t.isEmpty());

  // addFirst / addLast
  t.addFirst(2);
  t.addFirst(1); // list: 1,2
  expectEquals("size after addFirst x2", 2, t.size());
  expectEquals("get(0)==1", 1, t.get(0));
  expectEquals("get(1)==2", 2, t.get(1));

  t.addLast(3); // 1,2,3
  expectEquals("addLast -> size 3", 3, t.size());
  expectEquals("get(2)==3", 3, t.get(2));

  // insertAt
  t.insertAt(1, 99); // 1,99,2,3
  expectEquals("insertAt(1,99)", 99, t.get(1));
  expectEquals("size==4 after insert", 4, t.size());

  // set
  int old = t.set(1, 55); // 1,55,2,3
  expectEquals("set returns old value 99", 99, old);
  expectEquals("value replaced with 55", 55, t.get(1));

  // indexOf
  expectEquals("indexOf(55)==1", 1, t.indexOf(55));
  expectEquals("indexOf(777)==-1", -1, t.indexOf(777));

  // iterator (for-each)
  int sum = 0;
  for (int v : t) sum += v; // 1+55+2+3 = 61
  expectEquals("iterator sum==61", 61, sum);

  // removeAt (middle, head, tail)
  int mid = t.removeAt(1); // removes 55 -> 1,2,3
  expectEquals("removeAt(1) returns 55", 55, mid);
  expectEquals("size==3 after remove", 3, t.size());
  expectEquals("head now 1", 1, t.get(0));

  int head = t.removeAt(0); // removes 1 -> 2,3
  expectEquals("removeAt(0) returns 1", 1, head);
  expectEquals("size==2", 2, t.size());
  expectEquals("new head 2", 2, t.get(0));

  int tail = t.removeAt(1); // removes 3 -> 2
  expectEquals("removeAt(tail)==3", 3, tail);
  expectEquals("size==1", 1, t.size());
  expectEquals("remaining==2", 2, t.get(0));

  // bounds checks
  expectThrows("get(-1) throws", () -> { t.get(-1); });
  expectThrows("get(99) throws", () -> { t.get(99); });
  expectThrows("insertAt(-1) throws", () -> { t.insertAt(-1, 7); });
  expectThrows("insertAt(n+1) throws", () -> { t.insertAt(t.size()+1, 7); });
  expectThrows("removeAt(-1) throws", () -> { t.removeAt(-1); });
  expectThrows("removeAt(n) throws", () -> { t.removeAt(t.size()); });

  // clear
  t.clear();
  expectEquals("clear -> size==0", 0, t.size());
  expectTrue("clear -> isEmpty", t.isEmpty());

  println("=== Test summary: passed=" + testsPassed + " failed=" + testsFailed + " ===");
}

void expectTrue(String name, boolean cond) {
  if (cond) {
    testsPassed++; println("[PASS] " + name);
  } else {
    testsFailed++; println("[FAIL] " + name + " (expected true)");
  }
}

void expectEquals(String name, int expected, int actual) {
  if (expected == actual) {
    testsPassed++; println("[PASS] " + name);
  } else {
    testsFailed++;
    println("[FAIL] " + name + " expected=" + expected + " actual=" + actual);
  }
}

// Simple functional interface for lambdas
interface ThrowingRunnable { void run(); }

void expectThrows(String name, ThrowingRunnable fn) {
  try {
    fn.run();
    testsFailed++;
    println("[FAIL] " + name + " (no exception)");
  } catch (IndexOutOfBoundsException e) {
    testsPassed++; println("[PASS] " + name + " (IndexOutOfBoundsException)");
  } catch (Throwable t) {
    testsFailed++;
    println("[FAIL] " + name + " (wrong exception: " + t.getClass().getSimpleName() + ")");
  }
}

// ------------------- Linked List Implementation -------------------
class LinkedList<E> implements Iterable<E> {
  private Node<E> head;
  private int n;

  private class Node<E> {
    E data;
    Node<E> next;
    Node(E d) { data = d; }
  }

  // Add at front: O(1)
  public void addFirst(E value) {
    Node<E> node = new Node<E>(value);
    node.next = head;
    head = node;
    n++;
  }

  // Add at end: O(n)
  public void addLast(E value) {
    Node<E> node = new Node<E>(value);
    if (head == null) {
      head = node;
    } else {
      Node<E> cur = head;
      while (cur.next != null) cur = cur.next;
      cur.next = node;
    }
    n++;
  }

  // Insert at index (0..n). 0 = front, n = end. O(n)
  public void insertAt(int index, E value) {
    checkPositionIndex(index); // allow index == n
    if (index == 0) { addFirst(value); return; }
    Node<E> prev = nodeAt(index - 1);
    Node<E> node = new Node<E>(value);
    node.next = prev.next;
    prev.next = node;
    n++;
  }

  // Remove at index (0..n-1). Returns removed value. O(n)
  public E removeAt(int index) {
    checkElementIndex(index);
    if (index == 0) {
      E val = head.data;
      head = head.next;
      n--;
      return val;
    }
    Node<E> prev = nodeAt(index - 1);
    Node<E> victim = prev.next;
    prev.next = victim.next;
    n--;
    return victim.data;
  }

  // Get value at index: O(n)
  public E get(int index) {
    checkElementIndex(index);
    return nodeAt(index).data;
  }

  // Set value at index, return old value: O(n)
  public E set(int index, E value) {
    checkElementIndex(index);
    Node<E> node = nodeAt(index);
    E old = node.data;
    node.data = value;
    return old;
  }

  // Return first index of value using equals(), or -1 if not found: O(n)
  public int indexOf(Object o) {
    int i = 0;
    for (Node<E> cur = head; cur != null; cur = cur.next, i++) {
      if (o == null ? cur.data == null : o.equals(cur.data)) return i;
    }
    return -1;
  }

  public int size() { return n; }
  public boolean isEmpty() { return n == 0; }

  public void clear() {
    head = null;
    n = 0;
  }

  // Helpers
  private Node<E> nodeAt(int index) {
    Node<E> cur = head;
    for (int i = 0; i < index; i++) cur = cur.next;
    return cur;
  }

  private void checkElementIndex(int index) {
    if (index < 0 || index >= n) {
      throw new IndexOutOfBoundsException("index " + index + " out of [0," + (n-1) + "]");
    }
  }

  private void checkPositionIndex(int index) {
    if (index < 0 || index > n) {
      throw new IndexOutOfBoundsException("index " + index + " out of [0," + n + "]");
    }
  }

  // Iterator support (for-each)
  public java.util.Iterator<E> iterator() {
    return new java.util.Iterator<E>() {
      Node<E> cur = head;
      public boolean hasNext() { return cur != null; }
      public E next() {
        if (cur == null) throw new java.util.NoSuchElementException();
        E val = cur.data;
        cur = cur.next;
        return val;
      }
      public void remove() { throw new UnsupportedOperationException(); }
    };
  }
}
