// Maximum Independent Set local-improvement demo (1→2 and 2→3 swaps)
// Processing (Java mode)

import java.util.*;

void setup() {
  size(800, 600);
  Graph g = demoGraph(); // or build your own
  Set<Integer> S = greedyMIS(g);  // initial MIS
  println("Initial MIS size = " + S.size() + "  " + S);

  Set<Integer> improved = localImprove(g, S);
  println("Improved MIS size = " + improved.size() + "  " + improved);

  noLoop();
}

// ---------------- Graph ----------------

static class Graph {
  int n;                        // vertices are 0..n-1
  ArrayList<HashSet<Integer>> adj;

  Graph(int n) {
    this.n = n;
    adj = new ArrayList<>(n);
    for (int i = 0; i < n; i++) adj.add(new HashSet<>());
  }

  void addEdge(int u, int v) {
    if (u == v) return;
    adj.get(u).add(v);
    adj.get(v).add(u);
  }

  boolean areAdj(int u, int v) {
    return adj.get(u).contains(v);
  }

  Set<Integer> neighbors(int v) {
    return Collections.unmodifiableSet(adj.get(v));
  }

  int size() { return n; }
}

// Example graph (mix of cycles/cords to show nontrivial improvements)
Graph demoGraph() {
  Graph g = new Graph(10);
  // 0-1-2-3-4-5 cycleish
  g.addEdge(0,1); g.addEdge(1,2); g.addEdge(2,3); g.addEdge(3,4); g.addEdge(4,5); g.addEdge(5,0);
  // extra spokes/chords
  g.addEdge(2,5); g.addEdge(1,4);
  // tail
  g.addEdge(6,2); g.addEdge(6,7); g.addEdge(7,8); g.addEdge(8,9);
  return g;
}

// ---------------- Utilities ----------------

boolean isIndependent(Graph g, Set<Integer> S) {
  for (int u : S) {
    for (int v : g.neighbors(u)) {
      if (u < v && S.contains(v)) return false;
    }
  }
  return true;
}

boolean isMaximal(Graph g, Set<Integer> S) {
  for (int v = 0; v < g.size(); v++) {
    if (S.contains(v)) continue;
    boolean ok = true;
    for (int u : g.neighbors(v)) if (S.contains(u)) { ok = false; break; }
    if (ok) return false; // could add v, so not maximal
  }
  return true;
}

// Greedy MIS: repeatedly add vertices with no neighbors in S
Set<Integer> greedyMIS(Graph g) {
  Set<Integer> S = new HashSet<>();
  boolean added = true;
  while (added) {
    added = false;
    for (int v = 0; v < g.size(); v++) {
      if (S.contains(v)) continue;
      boolean ok = true;
      for (int u : g.neighbors(v)) if (S.contains(u)) { ok = false; break; }
      if (ok) { S.add(v); added = true; }
    }
  }
  return S;
}

// Re-maximalize: greedily add any currently admissible vertices
Set<Integer> reMaximalize(Graph g, Set<Integer> S) {
  Set<Integer> R = new HashSet<>(S);
  boolean changed = true;
  while (changed) {
    changed = false;
    for (int v = 0; v < g.size(); v++) {
      if (R.contains(v)) continue;
      boolean ok = true;
      for (int u : g.neighbors(v)) if (R.contains(u)) { ok = false; break; }
      if (ok) { R.add(v); changed = true; }
    }
  }
  return R;
}

// ---------- Improvement moves ----------

// Try a single 1→2 swap; return improved set if found, else original S
Set<Integer> tryOneToTwoSwap(Graph g, Set<Integer> S) {
  // Precompute "conflict-only-with" buckets for speed (optional)
  for (int u : S) {
    // Candidates that only clash with u inside S
    ArrayList<Integer> C = new ArrayList<>();
    for (int v = 0; v < g.size(); v++) {
      if (S.contains(v)) continue;
      boolean ok = true;
      for (int x : g.neighbors(v)) {
        if (S.contains(x) && x != u) { ok = false; break; }
      }
      if (ok) C.add(v);
    }
    // find independent pair in C
    int m = C.size();
    for (int i = 0; i < m; i++) {
      int a = C.get(i);
      for (int j = i+1; j < m; j++) {
        int b = C.get(j);
        if (!g.areAdj(a,b)) {
          Set<Integer> T = new HashSet<>(S);
          T.remove(u);
          T.add(a); T.add(b);
          T = reMaximalize(g, T);
          if (T.size() > S.size() && isIndependent(g, T)) return T;
        }
      }
    }
  }
  return S;
}

// Try a single 2→3 swap; return improved set if found, else original S
Set<Integer> tryTwoToThreeSwap(Graph g, Set<Integer> S) {
  // Enumerate pairs X={u,w} in S
  Integer[] arr = S.toArray(new Integer[0]);
  for (int i = 0; i < arr.length; i++) {
    int u = arr[i];
    for (int j = i+1; j < arr.length; j++) {
      int w = arr[j];
      // Candidates that only clash within X
      ArrayList<Integer> C = new ArrayList<>();
      for (int v = 0; v < g.size(); v++) {
        if (S.contains(v)) continue;
        boolean ok = true;
        for (int x : g.neighbors(v)) {
          if (S.contains(x) && x != u && x != w) { ok = false; break; }
        }
        if (ok) C.add(v);
      }
      // find independent triple in C
      int m = C.size();
      for (int aIdx = 0; aIdx < m; aIdx++) {
        int a = C.get(aIdx);
        for (int bIdx = aIdx+1; bIdx < m; bIdx++) {
          int b = C.get(bIdx);
          if (g.areAdj(a,b)) continue;
          for (int cIdx = bIdx+1; cIdx < m; cIdx++) {
            int c = C.get(cIdx);
            if (g.areAdj(a,c) || g.areAdj(b,c)) continue;
            Set<Integer> T = new HashSet<>(S);
            T.remove(u); T.remove(w);
            T.add(a); T.add(b); T.add(c);
            T = reMaximalize(g, T);
            if (T.size() > S.size() && isIndependent(g, T)) return T;
          }
        }
      }
    }
  }
  return S;
}

// Outer loop: keep applying improvements while possible
Set<Integer> localImprove(Graph g, Set<Integer> S0) {
  Set<Integer> S = reMaximalize(g, S0);
  boolean improved = true;
  while (improved) {
    improved = false;

    Set<Integer> S1 = tryOneToTwoSwap(g, S);
    if (S1.size() > S.size()) {
      println("Applied 1→2 swap: " + S.size() + " -> " + S1.size());
      S = S1; improved = true; continue;
    }

    Set<Integer> S2 = tryTwoToThreeSwap(g, S);
    if (S2.size() > S.size()) {
      println("Applied 2→3 swap: " + S.size() + " -> " + S2.size());
      S = S2; improved = true; continue;
    }
  }
  return S;
}
