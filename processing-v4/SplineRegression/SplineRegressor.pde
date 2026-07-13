/* ================= Spline Regressor ================= */

class SplineRegressor {
  int degree;      // spline degree
  int M;           // basis count
  double xmin, xmax;
  double[] knots;  // length M + degree + 1
  double[] w;      // weights length M

  SplineRegressor(int degree, int M, double xmin, double xmax) {
    this.degree = degree;
    this.xmin = xmin;
    this.xmax = xmax;
    setBasisCount(M);
  }

  void setBasisCount(int M) {
    this.M = M;
    this.knots = openUniformKnots(M, degree, xmin, xmax);
    this.w = new double[M];
  }

  void fit(double[] x, double[] y, double lambda) {
    int n = x.length;
    double[][] A = new double[M][M];
    double[] b = new double[M];

    for (int i = 0; i < n; i++) {
      double[] phi = basisVector(x[i]);
      for (int a = 0; a < M; a++) {
        b[a] += phi[a] * y[i];
        for (int c = 0; c < M; c++) {
          A[a][c] += phi[a] * phi[c];
        }
      }
    }
    for (int a = 0; a < M; a++) A[a][a] += lambda;

    w = solveLinearSystem(A, b);
  }

  double predict(double x) {
    double[] phi = basisVector(x);
    double s = 0.0;
    for (int j = 0; j < M; j++) s += w[j] * phi[j];
    return s;
  }

  double[] basisVector(double x) {
    double[] v = new double[M];
    for (int i = 0; i < M; i++) v[i] = bspline(i, degree, x, knots);
    return v;
  }

  // Open-uniform/clamped knots
  double[] openUniformKnots(int M, int p, double a, double b) {
    int K = M + p + 1;
    double[] U = new double[K];
    for (int i = 0; i <= p; i++) U[i] = a;
    for (int i = K - p - 1; i < K; i++) U[i] = b;
    int interior = K - 2 * (p + 1);
    for (int j = 0; j < interior; j++) {
      double t = (j + 1) / (double)(interior + 1);
      U[p + 1 + j] = a + (b - a) * t;
    }
    return U;
  }

  // Cox–de Boor
  double bspline(int i, int p, double x, double[] U) {
    if (p == 0) {
      boolean in = (x >= U[i] && x < U[i + 1]) || (x == U[U.length - 1] && i + 1 == U.length - 1);
      return in ? 1.0 : 0.0;
    } else {
      double left = 0.0, right = 0.0;
      double denom1 = U[i + p] - U[i];
      if (denom1 != 0) left = (x - U[i]) / denom1 * bspline(i, p - 1, x, U);
      double denom2 = U[i + p + 1] - U[i + 1];
      if (denom2 != 0) right = (U[i + p + 1] - x) / denom2 * bspline(i + 1, p - 1, x, U);
      return left + right;
    }
  }

  // Solve A w = b via Gaussian elimination with partial pivoting
  double[] solveLinearSystem(double[][] A, double[] b) {
    int n = b.length;
    double[][] Mx = new double[n][n];
    double[] bx = new double[n];
    for (int i = 0; i < n; i++) {
      System.arraycopy(A[i], 0, Mx[i], 0, n);
      bx[i] = b[i];
    }

    for (int k = 0; k < n; k++) {
      int piv = k;
      double best = Math.abs(Mx[k][k]);
      for (int i = k + 1; i < n; i++) {
        double v = Math.abs(Mx[i][k]);
        if (v > best) { best = v; piv = i; }
      }
      if (piv != k) {
        double[] tr = Mx[k]; Mx[k] = Mx[piv]; Mx[piv] = tr;
        double tb = bx[k]; bx[k] = bx[piv]; bx[piv] = tb;
      }
      double diag = Mx[k][k];
      if (Math.abs(diag) < 1e-18) diag = 1e-18;

      for (int i = k + 1; i < n; i++) {
        double f = Mx[i][k] / diag;
        if (f == 0) continue;
        bx[i] -= f * bx[k];
        for (int j = k; j < n; j++) {
          Mx[i][j] -= f * Mx[k][j];
        }
      }
    }

    double[] x = new double[n];
    for (int i = n - 1; i >= 0; i--) {
      double s = bx[i];
      for (int j = i + 1; j < n; j++) s -= Mx[i][j] * x[j];
      double d = Mx[i][i];
      if (Math.abs(d) < 1e-18) d = 1e-18;
      x[i] = s / d;
    }
    return x;
  }
}
