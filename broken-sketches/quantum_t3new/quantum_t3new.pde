int ncellx = 3;
int ncelly = 3;
int dcellx = 300;
int dcelly = 300;

Qubit qubits[][] = new Qubit[ncelly][ncelly];

int imove=0;

ArrayList<Qlink> qlinks = new ArrayList();

boolean gamewon=false;

void settings() {
  size(ncellx*dcellx,ncelly*dcelly);
}


void setup() {
  gamewon=false;
  
  for(int ix=0; ix<ncellx; ix++) {
    for(int iy=0; iy<ncelly; iy++) {
      qubits[ix][iy] = new Qubit(ix*dcellx,iy*dcelly,dcellx,dcelly);
    }
  }
}

void draw() {
   for(int ix=0; ix<ncellx; ix++) {    
     for(int iy=0; iy<ncelly; iy++) {
        qubits[ix][iy].drawCell();       
     }     
   }
}

Qubit qdrag = null;
Qubit qdrop = null;

void mousePressed() {
   println("mouse pressed at: "+ mouseX/dcellx+"  "+mouseY/dcelly);
   qdrag = getcell(mouseX,mouseY);   
}

void mouseReleased() {
  if(gamewon) {
    setup();
    return;
  }
  
   println("mouse released at: "+ mouseX/dcellx+"  "+mouseY/dcelly);
   qdrop = getcell(mouseX, mouseY);
   
   // DRAG / DROP move for entangled cells     
   if(qdrag!=qdrop) { 
          
     qdrag.setState(imove%2+2);
     qdrop.setState(imove%2+2);

     addlink(qdrag,qdrop);
     
   } else {
      qdrop.setState((imove%2));
   }
   
   gamewon=checkwin();
   imove++;
}

void addlink(Qubit qdrag, Qubit qdrop) {
  qlinks.add(new Qlink(qdrag,qdrop));
}

boolean checkLoop(Qubit qs) {
    boolean inloop=false;
    
    for(int iq=0; iq<qlinks.size(); iq++) {
      Qlink qlink = qlinks.get(iq);

      if (qs==qlink.getLeftQubit() || qs==qlink.getRightQubit()) {
        inloop=true;
      }
    }  
    
    return inloop;
}

Qubit getcell(int mx, int my) {
   Qubit qcell = null;
   
   for(int ix=0; ix<ncellx; ix++) {    
     for(int iy=0; iy<ncelly; iy++) {
        if(qubits[ix][iy].testMouse(mx,my)) {
          qcell=qubits[ix][iy];
          break;
        }
     }     
   }
   
   return qcell;
}

boolean checkwin() {
  Qubit qa;
  Qubit qb;
  Qubit qc;
  
  for(int ix=0; ix<ncellx; ix++) {
    qa=qubits[ix][0];
    qb=qubits[ix][1];
    qc=qubits[ix][2];
    
    if(qa.getState()==0 || qa.getState()==1) {
      if(qa.getState()==qb.getState() && qb.getState()==qc.getState()) {
        qa.setWin();
        qb.setWin();
        qc.setWin();
        return true;
      }
    }
  }
  
  for(int iy=0; iy<ncelly; iy++) {
    qa=qubits[0][iy];
    qb=qubits[1][iy];
    qc=qubits[2][iy];
    
    if(qa.getState()==0 || qa.getState()==1) {    
      if(qa.getState()==qb.getState() && qb.getState()==qc.getState()) {
        qa.setWin();
        qb.setWin();
        qc.setWin();
        return true;
      }
    }
  }
  
  qa=qubits[0][0];
  qb=qubits[1][1];
  qc=qubits[2][2];
  
  if(qa.getState()==0 || qa.getState()==1) {
    if(qa.getState()==qb.getState() && qb.getState()==qc.getState()) {
      qa.setWin();
      qb.setWin();
      qc.setWin();
      return true;
    }  
  }
  
  qa=qubits[0][2];
  qb=qubits[1][1];
  qc=qubits[2][0];
  
  if(qa.getState()==0 || qa.getState()==1) {
    if(qa.getState()==qb.getState() && qb.getState()==qc.getState()) {
      qa.setWin();
      qb.setWin();
      qc.setWin();
      return true;
    } 
  }
  
  return false;
}