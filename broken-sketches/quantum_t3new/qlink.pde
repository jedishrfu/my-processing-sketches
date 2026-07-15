class Qlink {
  
  Qubit qleft;
  Qubit qright;
  
  public Qlink(Qubit qleft, Qubit qright) {
    this.qleft = qleft;
    this.qright = qright;
  }
  
  Qubit getLeftQubit() {
    return qleft;
  }
  Qubit getRightQubit() {
    return qright;
  }
}