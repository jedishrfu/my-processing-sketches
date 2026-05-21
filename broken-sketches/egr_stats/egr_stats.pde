// Graph Analysis in Processing
// Binary .egr ECL-format loader + simple DIMACS .eg loader
// Cheap stats run automatically.
// Expensive stats run only when requested by keys.
//
// Keys:
//   o = open file
//   e = export CSV
//   1 = sampled distance histogram
//   2 = sampled betweenness
//   3 = simple community detection
//   4 = full distance histogram
//   5 = full betweenness
//   r = resample visible graph layout

import java.util.*;
import java.io.*;

HashMap<Integer, HashSet<Integer>> adj = new HashMap<Integer, HashSet<Integer>>();
ArrayList<int[]> edges = new ArrayList<int[]>();

boolean graphLoaded = false;
boolean isDirected = false;

// Visualization
HashMap<Integer, PVector> pos = new HashMap<Integer, PVector>();
HashSet<Integer> visibleNodes = new HashSet<Integer>();
ArrayList<int[]> visibleEdges = new ArrayList<int[]>();

float repulsion = 2000;
float spring = 0.01;
int maxVisibleNodes = 1000;

// Metrics
ArrayList<Integer> degrees = new ArrayList<Integer>();
ArrayList<HashSet<Integer>> components = new ArrayList<HashSet<Integer>>();
HashSet<Integer> largestComp = new HashSet<Integer>();
ArrayList<Integer> eccList = new ArrayList<Integer>();
HashMap<Integer, Float> betweenness = new HashMap<Integer, Float>();
ArrayList<Integer> distanceHistogram = new ArrayList<Integer>();
ArrayList<HashSet<Integer>> communities = new ArrayList<HashSet<Integer>>();

void setup() {
  size(1200, 700);
  background(255);
  textFont(createFont("Monospaced", 12));

  println("Press 'o' to open a graph file, 'e' to export CSV.");
  println("Press '1' sampled distances, '2' sampled betweenness, '3' communities.");
  println("Press '4' full distance histogram, '5' full betweenness.");
  println("Press 'r' to resample visible graph.");
}

void draw() {
  background(255);

  if (graphLoaded) {
    forceLayoutStep();
    drawGraph();
    drawHUD();
  } else {
    fill(0);
    text("Press 'o' to open an .egr or .eg file.", 20, 40);
  }
}

void keyPressed() {
  if (key == 'o') {
    selectInput("Choose an .egr or .eg file", "fileSelected");
  } else if (key == 'e' && graphLoaded) {
    exportCSV();
  } else if (key == '1' && graphLoaded) {
    computeDistanceHistogramSampled(200);
  } else if (key == '2' && graphLoaded) {
    computeBetweennessSampled(200);
  } else if (key == '3' && graphLoaded) {
    detectCommunities();
  } else if (key == '4' && graphLoaded) {
    computeDistanceHistogram();
  } else if (key == '5' && graphLoaded) {
    computeBetweenness();
  } else if (key == 'r' && graphLoaded) {
    initPositionsSampled(maxVisibleNodes);
  }
}

void fileSelected(File selection) {
  if (selection == null) {
    println("No file selected.");
    return;
  }

  resetGraph();

  String path = selection.getAbsolutePath();
  println("Loading: " + path);

  if (path.endsWith(".eg")) {
    isDirected = true;
    loadDIMACSeg(path);
  } else {
    isDirected = false;
    loadEGR(path);
  }

  if (adj.isEmpty()) {
    println("No graph loaded.");
    graphLoaded = false;
    return;
  }

  computeStatsCheap();
  computeConnectedComponentsOnly();
  initPositionsSampled(maxVisibleNodes);

  graphLoaded = true;

  println("Graph loaded.");
  println("Expensive stats were NOT run automatically.");
  println("Use keys 1, 2, 3, 4, 5 to run optional analyses.");
}

//////////////////////////////////////////////////////////////
// RESET
//////////////////////////////////////////////////////////////

void resetGraph() {
  adj.clear();
  edges.clear();
  pos.clear();
  visibleNodes.clear();
  visibleEdges.clear();
  degrees.clear();
  components.clear();
  largestComp.clear();
  eccList.clear();
  betweenness.clear();
  distanceHistogram.clear();
  communities.clear();
  graphLoaded = false;
}

//////////////////////////////////////////////////////////////
// LOADERS
//////////////////////////////////////////////////////////////

// Binary .egr loader: ECL graph format.
// File ints are little-endian.
// Java reads big-endian, so reverseBytes is used.
void loadEGR(String path) {
  try {
    DataInputStream in = new DataInputStream(
      new BufferedInputStream(new FileInputStream(path))
    );

    int nodes = readIntLE(in);
    int edgeCount = readIntLE(in);

    println("Binary .egr header:");
    println("nodes = " + nodes);
    println("edges = " + edgeCount);

    if (nodes <= 0 || edgeCount < 0) {
      println("Bad .egr header.");
      in.close();
      return;
    }

    int[] nindex = new int[nodes + 1];
    int[] nlist = new int[edgeCount];

    for (int i = 0; i <= nodes; i++) {
      nindex[i] = readIntLE(in);
    }

    for (int i = 0; i < edgeCount; i++) {
      nlist[i] = readIntLE(in);
    }

    // Read and ignore weights if present.
    for (int i = 0; i < edgeCount; i++) {
      try {
        int w = readIntLE(in);
      } catch (EOFException eof) {
        break;
      }
    }

    in.close();

    for (int u = 0; u < nodes; u++) {
      if (!adj.containsKey(u)) {
        adj.put(u, new HashSet<Integer>());
      }

      int start = nindex[u];
      int end = nindex[u + 1];

      if (start < 0 || end < start || end > edgeCount) {
        println("Bad nindex range at node " + u + ": " + start + " to " + end);
        continue;
      }

      for (int ei = start; ei < end; ei++) {
        int v = nlist[ei];

        if (v >= 0 && v < nodes) {
          addEdge(u, v);
        }
      }
    }

    println("Loaded binary .egr graph with " + adj.size() +
            " nodes and " + edges.size() + " edges.");

  } catch (Exception e) {
    e.printStackTrace();
  }
}

int readIntLE(DataInputStream in) throws IOException {
  return Integer.reverseBytes(in.readInt());
}

// Very simple DIMACS .eg: lines like "a u v w"
// Weight is ignored.
void loadDIMACSeg(String path) {
  try {
    BufferedReader br = new BufferedReader(new FileReader(path));
    String line;

    while ((line = br.readLine()) != null) {
      line = line.trim();

      if (line.length() == 0) continue;
      if (line.startsWith("c")) continue;
      if (line.startsWith("p")) continue;

      String[] parts = line.split("\\s+");

      if (parts.length >= 3 && parts[0].equals("a")) {
        int u = Integer.parseInt(parts[1]);
        int v = Integer.parseInt(parts[2]);
        addEdge(u, v);
      }
    }

    br.close();

    println("Loaded .eg graph with " + adj.size() +
            " nodes and " + edges.size() + " edges.");

  } catch (Exception e) {
    e.printStackTrace();
  }
}

void addEdge(int u, int v) {
  edges.add(new int[]{u, v});

  if (!adj.containsKey(u)) {
    adj.put(u, new HashSet<Integer>());
  }

  if (!adj.containsKey(v)) {
    adj.put(v, new HashSet<Integer>());
  }

  adj.get(u).add(v);
  adj.get(v).add(u);
}

//////////////////////////////////////////////////////////////
// CHEAP STATS
//////////////////////////////////////////////////////////////

void computeStatsCheap() {
  println("\n=== BASIC STATS ===");
  println("Nodes: " + adj.size());
  println("Edges: " + edges.size());

  if (adj.isEmpty()) {
    println("Graph is empty or failed to load.");
    return;
  }

  degrees.clear();

  for (int v : adj.keySet()) {
    degrees.add(adj.get(v).size());
  }

  if (degrees.isEmpty()) {
    println("No degree data.");
    return;
  }

  int minDeg = Collections.min(degrees);
  int maxDeg = Collections.max(degrees);
  float avgDeg = averageInt(degrees);

  println("Min degree: " + minDeg);
  println("Max degree: " + maxDeg);
  println("Avg degree: " + avgDeg);

  boolean regular = true;
  int first = degrees.get(0);

  for (int d : degrees) {
    if (d != first) {
      regular = false;
      break;
    }
  }

  println("Regular: " + regular);
}

void computeConnectedComponentsOnly() {
  println("\n=== CONNECTIVITY ===");

  if (adj.isEmpty()) {
    println("No graph loaded.");
    return;
  }

  components = connectedComponents();

  println("Components: " + components.size());

  if (!components.isEmpty()) {
    largestComp = components.get(0);
    println("Largest component size: " + largestComp.size());
  }
}

//////////////////////////////////////////////////////////////
// FULL GRAPH STATISTICS
//////////////////////////////////////////////////////////////

void computeStatsFull() {
  computeStatsCheap();
  computeConnectedComponentsOnly();

  if (largestComp.isEmpty()) return;

  println("\n=== DIAMETER largest component ===");
  int diam = diameter(largestComp);
  println("Diameter: " + diam);

  println("\n=== ECCENTRICITY ===");
  eccList = eccentricities(largestComp);
  println("Min ecc: " + Collections.min(eccList));
  println("Max ecc: " + Collections.max(eccList));
  println("Avg ecc: " + averageInt(eccList));

  println("\n=== CLUSTERING ===");
  float avgClust = averageClustering();
  println("Average clustering coefficient: " + avgClust);

  println("\n=== TRIANGLES approximate ===");
  int tri = countTriangles();
  println("Triangles: " + tri);
}

//////////////////////////////////////////////////////////////
// CONNECTED COMPONENTS
//////////////////////////////////////////////////////////////

ArrayList<HashSet<Integer>> connectedComponents() {
  HashSet<Integer> visited = new HashSet<Integer>();
  ArrayList<HashSet<Integer>> comps = new ArrayList<HashSet<Integer>>();

  for (int v : adj.keySet()) {
    if (!visited.contains(v)) {
      HashSet<Integer> comp = bfsComponent(v);
      visited.addAll(comp);
      comps.add(comp);
    }
  }

  comps.sort((a, b) -> b.size() - a.size());
  return comps;
}

HashSet<Integer> bfsComponent(int start) {
  HashSet<Integer> comp = new HashSet<Integer>();
  LinkedList<Integer> q = new LinkedList<Integer>();

  q.add(start);
  comp.add(start);

  while (!q.isEmpty()) {
    int u = q.poll();

    for (int w : adj.get(u)) {
      if (!comp.contains(w)) {
        comp.add(w);
        q.add(w);
      }
    }
  }

  return comp;
}

//////////////////////////////////////////////////////////////
// DIAMETER AND ECCENTRICITY
//////////////////////////////////////////////////////////////

int diameter(HashSet<Integer> comp) {
  int diam = 0;

  for (int v : comp) {
    int d = bfsMaxDist(v, comp);
    if (d > diam) diam = d;
  }

  return diam;
}

ArrayList<Integer> eccentricities(HashSet<Integer> comp) {
  ArrayList<Integer> ecc = new ArrayList<Integer>();

  for (int v : comp) {
    ecc.add(bfsMaxDist(v, comp));
  }

  return ecc;
}

int bfsMaxDist(int start, HashSet<Integer> comp) {
  HashMap<Integer, Integer> dist = new HashMap<Integer, Integer>();
  LinkedList<Integer> q = new LinkedList<Integer>();

  q.add(start);
  dist.put(start, 0);

  int maxd = 0;

  while (!q.isEmpty()) {
    int u = q.poll();

    for (int w : adj.get(u)) {
      if (comp.contains(w) && !dist.containsKey(w)) {
        int nd = dist.get(u) + 1;
        dist.put(w, nd);
        q.add(w);

        if (nd > maxd) {
          maxd = nd;
        }
      }
    }
  }

  return maxd;
}

//////////////////////////////////////////////////////////////
// CLUSTERING AND TRIANGLES
//////////////////////////////////////////////////////////////

float averageClustering() {
  float sum = 0;

  for (int v : adj.keySet()) {
    sum += clustering(v);
  }

  return sum / max(1, adj.size());
}

float clustering(int v) {
  HashSet<Integer> nbrs = adj.get(v);
  int k = nbrs.size();

  if (k < 2) return 0;

  int links = 0;

  for (int a : nbrs) {
    for (int b : nbrs) {
      if (a < b && adj.get(a).contains(b)) {
        links++;
      }
    }
  }

  return (2.0 * links) / (k * (k - 1));
}

int countTriangles() {
  int tri = 0;

  for (int v : adj.keySet()) {
    for (int u : adj.get(v)) {
      if (u > v) continue;

      for (int w : adj.get(v)) {
        if (w > u) continue;

        if (adj.get(u).contains(w)) {
          tri++;
        }
      }
    }
  }

  return tri;
}

//////////////////////////////////////////////////////////////
// DISTANCE DISTRIBUTION
//////////////////////////////////////////////////////////////

void computeDistanceHistogramSampled(int sampleSize) {
  distanceHistogram.clear();

  if (largestComp.isEmpty()) {
    computeConnectedComponentsOnly();
  }

  if (largestComp.isEmpty()) {
    println("No largest component available.");
    return;
  }

  ArrayList<Integer> nodes = new ArrayList<Integer>(largestComp);
  Collections.shuffle(nodes);

  int limit = min(sampleSize, nodes.size());

  for (int i = 0; i < limit; i++) {
    int v = nodes.get(i);
    HashMap<Integer, Integer> dist = bfsAllDist(v, largestComp);

    for (int d : dist.values()) {
      ensureSize(distanceHistogram, d + 1);
      distanceHistogram.set(d, distanceHistogram.get(d) + 1);
    }
  }

  println("\n=== SAMPLED DISTANCE DISTRIBUTION ===");
  println("Sampled BFS roots: " + limit);

  for (int d = 0; d < distanceHistogram.size(); d++) {
    println("Distance " + d + ": " + distanceHistogram.get(d));
  }
}

void computeDistanceHistogram() {
  distanceHistogram.clear();

  if (largestComp.isEmpty()) {
    computeConnectedComponentsOnly();
  }

  if (largestComp.isEmpty()) {
    println("No largest component available.");
    return;
  }

  println("\n=== FULL DISTANCE DISTRIBUTION ===");
  println("This may take a long time.");

  for (int v : largestComp) {
    HashMap<Integer, Integer> dist = bfsAllDist(v, largestComp);

    for (int d : dist.values()) {
      ensureSize(distanceHistogram, d + 1);
      distanceHistogram.set(d, distanceHistogram.get(d) + 1);
    }
  }

  for (int d = 0; d < distanceHistogram.size(); d++) {
    println("Distance " + d + ": " + distanceHistogram.get(d));
  }
}

HashMap<Integer, Integer> bfsAllDist(int start, HashSet<Integer> comp) {
  HashMap<Integer, Integer> dist = new HashMap<Integer, Integer>();
  LinkedList<Integer> q = new LinkedList<Integer>();

  q.add(start);
  dist.put(start, 0);

  while (!q.isEmpty()) {
    int u = q.poll();

    for (int w : adj.get(u)) {
      if (comp.contains(w) && !dist.containsKey(w)) {
        dist.put(w, dist.get(u) + 1);
        q.add(w);
      }
    }
  }

  return dist;
}

//////////////////////////////////////////////////////////////
// BETWEENNESS CENTRALITY
//////////////////////////////////////////////////////////////

void computeBetweennessSampled(int sampleSize) {
  betweenness.clear();

  for (int v : adj.keySet()) {
    betweenness.put(v, 0.0);
  }

  ArrayList<Integer> sources = new ArrayList<Integer>(adj.keySet());
  Collections.shuffle(sources);

  int limit = min(sampleSize, sources.size());

  println("\n=== SAMPLED BETWEENNESS CENTRALITY ===");
  println("Sampled sources: " + limit);

  for (int i = 0; i < limit; i++) {
    brandesFromSource(sources.get(i));
  }

  printTopBetweenness();
}

void computeBetweenness() {
  betweenness.clear();

  for (int v : adj.keySet()) {
    betweenness.put(v, 0.0);
  }

  println("\n=== FULL BETWEENNESS CENTRALITY ===");
  println("This may take a long time.");

  for (int s : adj.keySet()) {
    brandesFromSource(s);
  }

  printTopBetweenness();
}

void brandesFromSource(int s) {
  Stack<Integer> S = new Stack<Integer>();
  HashMap<Integer, ArrayList<Integer>> P = new HashMap<Integer, ArrayList<Integer>>();
  HashMap<Integer, Integer> sigma = new HashMap<Integer, Integer>();
  HashMap<Integer, Integer> dist = new HashMap<Integer, Integer>();

  for (int v : adj.keySet()) {
    P.put(v, new ArrayList<Integer>());
    sigma.put(v, 0);
    dist.put(v, -1);
  }

  sigma.put(s, 1);
  dist.put(s, 0);

  LinkedList<Integer> Q = new LinkedList<Integer>();
  Q.add(s);

  while (!Q.isEmpty()) {
    int v = Q.poll();
    S.push(v);

    for (int w : adj.get(v)) {
      if (dist.get(w) < 0) {
        dist.put(w, dist.get(v) + 1);
        Q.add(w);
      }

      if (dist.get(w) == dist.get(v) + 1) {
        sigma.put(w, sigma.get(w) + sigma.get(v));
        P.get(w).add(v);
      }
    }
  }

  HashMap<Integer, Float> delta = new HashMap<Integer, Float>();

  for (int v : adj.keySet()) {
    delta.put(v, 0.0);
  }

  while (!S.empty()) {
    int w = S.pop();

    for (int v : P.get(w)) {
      if (sigma.get(w) != 0) {
        float c = sigma.get(v) * ((1.0 + delta.get(w)) / sigma.get(w));
        delta.put(v, delta.get(v) + c);
      }
    }

    if (w != s) {
      betweenness.put(w, betweenness.get(w) + delta.get(w));
    }
  }
}

void printTopBetweenness() {
  ArrayList<Map.Entry<Integer, Float>> list =
    new ArrayList<Map.Entry<Integer, Float>>(betweenness.entrySet());

  list.sort((a, b) -> Float.compare(b.getValue(), a.getValue()));

  println("Top 10 nodes by betweenness:");

  for (int i = 0; i < min(10, list.size()); i++) {
    println(list.get(i).getKey() + " : " + list.get(i).getValue());
  }
}

//////////////////////////////////////////////////////////////
// SIMPLE COMMUNITY DETECTION
//////////////////////////////////////////////////////////////

void detectCommunities() {
  println("\n=== SIMPLE COMMUNITY DETECTION ===");
  println("This can be expensive.");

  HashMap<String, Float> edgeBet = edgeBetweennessSampled(100);

  ArrayList<Map.Entry<String, Float>> list =
    new ArrayList<Map.Entry<String, Float>>(edgeBet.entrySet());

  list.sort((a, b) -> Float.compare(b.getValue(), a.getValue()));

  HashMap<Integer, HashSet<Integer>> adjCopy =
    new HashMap<Integer, HashSet<Integer>>();

  for (int v : adj.keySet()) {
    adjCopy.put(v, new HashSet<Integer>(adj.get(v)));
  }

  int removeCount = max(1, edges.size() / 50);

  for (int i = 0; i < removeCount && i < list.size(); i++) {
    String key = list.get(i).getKey();
    String[] parts = key.split("_");

    int u = Integer.parseInt(parts[0]);
    int v = Integer.parseInt(parts[1]);

    if (adjCopy.containsKey(u)) {
      adjCopy.get(u).remove(v);
    }

    if (adjCopy.containsKey(v)) {
      adjCopy.get(v).remove(u);
    }
  }

  communities = connectedComponentsFromAdj(adjCopy);

  println("Detected " + communities.size() +
          " communities after removing top edges.");
}

HashMap<String, Float> edgeBetweennessSampled(int sampleSize) {
  HashMap<String, Float> edgeBet = new HashMap<String, Float>();

  for (int[] e : edges) {
    edgeBet.put(edgeKey(e[0], e[1]), 0.0);
  }

  ArrayList<Integer> sources = new ArrayList<Integer>(adj.keySet());
  Collections.shuffle(sources);

  int limit = min(sampleSize, sources.size());

  println("Sampling edge betweenness from " + limit + " sources.");

  for (int i = 0; i < limit; i++) {
    int s = sources.get(i);

    Stack<Integer> S = new Stack<Integer>();
    HashMap<Integer, ArrayList<Integer>> P =
      new HashMap<Integer, ArrayList<Integer>>();
    HashMap<Integer, Integer> sigma =
      new HashMap<Integer, Integer>();
    HashMap<Integer, Integer> dist =
      new HashMap<Integer, Integer>();

    for (int v : adj.keySet()) {
      P.put(v, new ArrayList<Integer>());
      sigma.put(v, 0);
      dist.put(v, -1);
    }

    sigma.put(s, 1);
    dist.put(s, 0);

    LinkedList<Integer> Q = new LinkedList<Integer>();
    Q.add(s);

    while (!Q.isEmpty()) {
      int v = Q.poll();
      S.push(v);

      for (int w : adj.get(v)) {
        if (dist.get(w) < 0) {
          dist.put(w, dist.get(v) + 1);
          Q.add(w);
        }

        if (dist.get(w) == dist.get(v) + 1) {
          sigma.put(w, sigma.get(w) + sigma.get(v));
          P.get(w).add(v);
        }
      }
    }

    HashMap<Integer, Float> delta = new HashMap<Integer, Float>();

    for (int v : adj.keySet()) {
      delta.put(v, 0.0);
    }

    while (!S.empty()) {
      int w = S.pop();

      for (int v : P.get(w)) {
        if (sigma.get(w) != 0) {
          float c = sigma.get(v) * ((1.0 + delta.get(w)) / sigma.get(w));
          String key = edgeKey(v, w);

          if (edgeBet.containsKey(key)) {
            edgeBet.put(key, edgeBet.get(key) + c);
          } else {
            edgeBet.put(key, c);
          }

          delta.put(v, delta.get(v) + c);
        }
      }
    }
  }

  return edgeBet;
}

String edgeKey(int u, int v) {
  if (u < v) {
    return u + "_" + v;
  } else {
    return v + "_" + u;
  }
}

ArrayList<HashSet<Integer>> connectedComponentsFromAdj(
  HashMap<Integer, HashSet<Integer>> A
) {
  HashSet<Integer> visited = new HashSet<Integer>();
  ArrayList<HashSet<Integer>> comps = new ArrayList<HashSet<Integer>>();

  for (int v : A.keySet()) {
    if (!visited.contains(v)) {
      HashSet<Integer> comp = new HashSet<Integer>();
      LinkedList<Integer> q = new LinkedList<Integer>();

      q.add(v);
      comp.add(v);
      visited.add(v);

      while (!q.isEmpty()) {
        int u = q.poll();

        for (int w : A.get(u)) {
          if (!visited.contains(w)) {
            visited.add(w);
            comp.add(w);
            q.add(w);
          }
        }
      }

      comps.add(comp);
    }
  }

  comps.sort((a, b) -> b.size() - a.size());
  return comps;
}

//////////////////////////////////////////////////////////////
// CSV EXPORT
//////////////////////////////////////////////////////////////

void exportCSV() {
  try {
    String filename = "graph_metrics.csv";
    PrintWriter pw = new PrintWriter(new FileWriter(filename));

    pw.println("node,degree,betweenness,community");

    HashMap<Integer, Integer> nodeComm = new HashMap<Integer, Integer>();

    for (int i = 0; i < communities.size(); i++) {
      for (int v : communities.get(i)) {
        nodeComm.put(v, i);
      }
    }

    for (int v : adj.keySet()) {
      int deg = adj.get(v).size();
      float b = betweenness.containsKey(v) ? betweenness.get(v) : 0.0;
      int cid = nodeComm.containsKey(v) ? nodeComm.get(v) : -1;

      pw.println(v + "," + deg + "," + b + "," + cid);
    }

    pw.flush();
    pw.close();

    println("Exported metrics to " + filename);

  } catch (Exception e) {
    e.printStackTrace();
  }
}

//////////////////////////////////////////////////////////////
// FORCE-DIRECTED LAYOUT
//////////////////////////////////////////////////////////////

void initPositionsSampled(int maxNodes) {
  pos.clear();
  visibleNodes.clear();
  visibleEdges.clear();

  ArrayList<Integer> nodes = new ArrayList<Integer>(adj.keySet());
  Collections.shuffle(nodes);

  int limit = min(maxNodes, nodes.size());

  for (int i = 0; i < limit; i++) {
    int v = nodes.get(i);
    visibleNodes.add(v);
    pos.put(v, new PVector(random(width), random(height)));
  }

  for (int[] e : edges) {
    if (visibleNodes.contains(e[0]) && visibleNodes.contains(e[1])) {
      visibleEdges.add(e);
    }
  }

  println("Visible sampled nodes: " + visibleNodes.size());
  println("Visible sampled edges: " + visibleEdges.size());
}

void forceLayoutStep() {
  if (visibleNodes.isEmpty()) return;

  HashMap<Integer, PVector> disp = new HashMap<Integer, PVector>();

  for (int v : visibleNodes) {
    disp.put(v, new PVector(0, 0));
  }

  for (int v : visibleNodes) {
    for (int u : visibleNodes) {
      if (v == u) continue;

      PVector dv = PVector.sub(pos.get(v), pos.get(u));
      float d = dv.mag() + 0.01;

      dv.normalize();
      dv.mult(repulsion / (d * d));

      disp.get(v).add(dv);
    }
  }

  for (int[] e : visibleEdges) {
    int u = e[0];
    int v = e[1];

    if (!pos.containsKey(u) || !pos.containsKey(v)) continue;

    PVector dv = PVector.sub(pos.get(v), pos.get(u));
    dv.mult(spring);

    disp.get(u).add(dv);
    disp.get(v).sub(dv);
  }

  for (int v : visibleNodes) {
    PVector p = pos.get(v);
    p.add(disp.get(v));

    p.x = constrain(p.x, 20, width - 20);
    p.y = constrain(p.y, 20, height - 20);
  }
}

void drawGraph() {
  HashMap<Integer, Integer> nodeComm = new HashMap<Integer, Integer>();

  for (int i = 0; i < communities.size(); i++) {
    for (int v : communities.get(i)) {
      nodeComm.put(v, i);
    }
  }

  stroke(0, 40);

  for (int[] e : visibleEdges) {
    PVector a = pos.get(e[0]);
    PVector b = pos.get(e[1]);

    if (a != null && b != null) {
      line(a.x, a.y, b.x, b.y);
    }
  }

  noStroke();

  for (int v : visibleNodes) {
    PVector p = pos.get(v);
    if (p == null) continue;

    int cid = nodeComm.containsKey(v) ? nodeComm.get(v) : -1;

    if (cid >= 0) {
      colorMode(HSB, 1.0);
      float h = (cid * 0.15) % 1.0;
      fill(h, 0.8, 0.9);
    } else {
      colorMode(RGB, 255);
      fill(0);
    }

    ellipse(p.x, p.y, 6, 6);
  }

  colorMode(RGB, 255);
}

void drawHUD() {
  fill(0);
  textAlign(LEFT, TOP);

  text(
    "Nodes: " + adj.size() +
    "\nEdges: " + edges.size() +
    "\nComponents: " + components.size() +
    "\nLargest comp: " + largestComp.size() +
    "\nVisible nodes: " + visibleNodes.size() +
    "\nVisible edges: " + visibleEdges.size() +
    "\n" +
    "\no: open graph" +
    "\ne: export CSV" +
    "\nr: resample visible graph" +
    "\n1: sampled distance histogram" +
    "\n2: sampled betweenness" +
    "\n3: sampled community detection" +
    "\n4: FULL distance histogram" +
    "\n5: FULL betweenness",
    10,
    10
  );

  drawDistanceHistogramHUD();
}

void drawDistanceHistogramHUD() {
  if (distanceHistogram.size() == 0) return;

  int x0 = width - 260;
  int y0 = height - 160;
  int w = 240;
  int h = 140;

  stroke(0);
  noFill();
  rect(x0, y0, w, h);

  int maxCount = 1;

  for (int c : distanceHistogram) {
    maxCount = max(maxCount, c);
  }

  stroke(0, 150, 0);

  for (int d = 0; d < distanceHistogram.size(); d++) {
    float x = map(d, 0, max(1, distanceHistogram.size() - 1),
                  x0 + 5, x0 + w - 5);
    float barH = map(distanceHistogram.get(d), 0, maxCount, 0, h - 20);

    line(x, y0 + h - 5, x, y0 + h - 5 - barH);
  }

  fill(0);
  textAlign(LEFT, BOTTOM);
  text("Distance histogram", x0 + 5, y0 - 2);
}

//////////////////////////////////////////////////////////////
// UTILS
//////////////////////////////////////////////////////////////

float averageInt(ArrayList<Integer> list) {
  if (list.isEmpty()) return 0;

  float s = 0;

  for (int x : list) {
    s += x;
  }

  return s / list.size();
}

void ensureSize(ArrayList<Integer> list, int size) {
  while (list.size() < size) {
    list.add(0);
  }
}
