import java.io.DataInput;
import java.io.DataOutput;
import java.io.IOException;
import java.util.Arrays;

class ScaledFloatArray1D {

  private static final int DEFAULT_DECIMAL_DIGITS = 2;

  private float m_dataMinimum;
  private float m_dataMaximum;
  private int m_powerOfTen;
  private int m_decimalDigits;
  private float m_dataScale;
  private short[] m_dataValues;

  private final String[] ixname = {
    "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th"
  };

  // Constructors

  ScaledFloatArray1D(float[] inp) {
    this(inp, DEFAULT_DECIMAL_DIGITS);
  }

  ScaledFloatArray1D(float[] inp, int decimalDigits) {
    float dataMinimum = Float.MAX_VALUE;
    float dataMaximum = Float.MIN_VALUE;
    
    for (int i = 0; i < inp.length; i++) {
      dataMinimum = Math.min(dataMinimum, inp[i]);
      dataMaximum = Math.max(dataMaximum, inp[i]);
    }
    
    putdata(inp, decimalDigits, dataMinimum, dataMaximum);
  }

  ScaledFloatArray1D(float[] inp, float dataMinimum, float dataMaximum) {
    putdata(inp, DEFAULT_DECIMAL_DIGITS, dataMinimum, dataMaximum);
  }

  ScaledFloatArray1D(float[] inp, int decimalDigits, float dataMinimum, float dataMaximum) {
    putdata(inp, decimalDigits, dataMinimum, dataMaximum);
  }

  // Data handling

  private void putdata(float[] inp, int decimalDigits, float dataMinimum, float dataMaximum) {
    this.m_dataMinimum = dataMinimum;
    this.m_dataMaximum = dataMaximum;
    this.m_decimalDigits = decimalDigits;
    this.m_powerOfTen = (int) pow(10, decimalDigits);
    this.m_dataScale = (m_dataMaximum - m_dataMinimum) / (Short.MAX_VALUE - Short.MIN_VALUE);
    this.m_dataValues = new short[inp.length];

    for (int i = 0; i < inp.length; i++) {
      put(i, inp[i]);
    }
  }

  float getDataMinimum() {
    return m_dataMinimum;
  }

  float getDataMaximum() {
    return m_dataMaximum;
  }

  float getDataRange() {
    return m_dataMaximum - m_dataMinimum;
  }
 short[] getDataValues() {
    return m_dataValues;
  }

  int getDecimalDigits() {
    return m_decimalDigits;
  }

  float getDataAccuracy() {
    return max((m_dataScale / 2.0f), (1.0f / m_powerOfTen));
  }

  float[] get() {
    float[] out = new float[m_dataValues.length];
    for (int i = 0; i < m_dataValues.length; i++) {
      out[i] = g(i);
    }
    return out;
  }

  float get(int i) {
    checkIndex(1, i, 0, m_dataValues.length - 1);
    return g(i);
  }

  void put(int i, float inp) {
    checkIndex(1, i, 0, m_dataValues.length - 1);
    checkData(inp);
    m_dataValues[i] = (short) round((inp - m_dataMinimum) / m_dataScale - Short.MIN_VALUE);
  }

  ScaledFloatArray1D add(ScaledFloatArray1D that) {
    if (this.m_dataValues.length != that.m_dataValues.length) {
      throw new RuntimeException("Arrays are not the same length!");
    }
    if (this.m_dataMinimum != that.m_dataMinimum || this.m_dataMaximum != that.m_dataMaximum) {
      throw new RuntimeException("Arrays have mismatched min/max!");
    }
    float[] sum = new float[m_dataValues.length];
    for (int i = 0; i < sum.length; i++) {
      sum[i] = this.get(i) + that.get(i);
    }
    return new ScaledFloatArray1D(sum, m_decimalDigits, m_dataMinimum, m_dataMaximum);
  }

  private float g(int i) {
    return round(m_powerOfTen * ((m_dataValues[i] - Short.MIN_VALUE) * m_dataScale + m_dataMinimum)) / (float) m_powerOfTen;
  }

  private void checkIndex(int irank, int ix, int ixlow, int ixhigh) {
    if (ix < ixlow || ix > ixhigh) {
      throw new ArrayIndexOutOfBoundsException("Index " + ixname[irank] + " out of bounds: " + ix);
    }
  }

  private void checkData(float inp) {
    if (inp < m_dataMinimum || inp > m_dataMaximum) {
      throw new RuntimeException("Data out of range: " + inp);
    }
  }

  // For hashing/equality
  public boolean equals(Object obj) {
    if (obj == null || !(obj instanceof ScaledFloatArray1D)) return false;
    ScaledFloatArray1D that = (ScaledFloatArray1D) obj;
    return m_decimalDigits == that.m_decimalDigits &&
      m_powerOfTen == that.m_powerOfTen &&
      Float.compare(m_dataMinimum, that.m_dataMinimum) == 0 &&
      Float.compare(m_dataMaximum, that.m_dataMaximum) == 0 &&
      Float.compare(m_dataScale, that.m_dataScale) == 0 &&
      Arrays.equals(m_dataValues, that.m_dataValues);
  }

  public int hashCode() {
    int hash = 7;
    hash = 31 * hash + Float.floatToIntBits(m_dataMinimum);
    hash = 31 * hash + Float.floatToIntBits(m_dataMaximum);
    hash = 31 * hash + m_powerOfTen;
    hash = 31 * hash + m_decimalDigits;
    hash = 31 * hash + Float.floatToIntBits(m_dataScale);
    hash = 31 * hash + Arrays.hashCode(m_dataValues);
    return hash;
  }
}
