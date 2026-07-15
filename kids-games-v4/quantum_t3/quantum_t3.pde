int ncellx = 3;
int ncelly = 3;
int dcellx = 300;
int dcelly = 300;
int doffx = 5;
int doffy = 5;

int toffs=50;
int tsize= dcelly-toffs;

int imove=1;   // x starts  (O=ZERO and X=ONE)

int iframe=0;

int t3board[][] = new int[ncellx][ncelly];
int t3bgnd[][] = new int[ncellx][ncelly];

int dragx=0;
int dragy=0;
int dropx=0;
int dropy=0;

int qsfrow[] = new int[10];
int qsfcol[] = new int[10];
int qstrow[] = new int[10];
int qstcol[] = new int[10];
int nqs=0;

void settings() {
  
  size(ncellx*dcellx,ncelly*dcelly);
  
}

void setup() {
  for(int ix=0; ix<ncellx; ix++) {
    for(int iy=0; iy<ncelly; iy++) {
      t3board[ix][iy]=-1;
      t3bgnd[ix][iy]=255;
    }
  }
}

void draw() {
  
   for(int ix=0; ix<ncellx; ix++) {
     
     for(int iy=0; iy<ncelly; iy++) {
       
       fill(t3bgnd[ix][iy]);
       rect(ix*dcellx+doffx,iy*dcelly+doffy,dcellx-2*doffx,dcelly-2*doffy);
       
       String piece="  ";
       
       switch(t3board[ix][iy]) {
         case 0: piece="OX"; break;
         case 1: piece="XO"; break;
         case 2: piece="OO"; break;
         case 3: piece="XX"; break;
         default: piece="  ";
       }
       
       //println("piece="+piece+" / "+piece.charAt(0)+" / "+piece.charAt(1));
       
       textSize(tsize);
       fill(0);
       text(piece.charAt(iframe%2),ix*dcellx+1.3*toffs,iy*dcelly+tsize);
     }
     
   }
   
   iframe++;
}

void mousePressed() {
   println("mouse pressed at: "+ mouseX/dcellx+"  "+mouseY/dcelly);
   dragx=mouseX/dcellx;
   dragy=mouseY/dcelly;
   markcell(imove%2, mouseX/dcellx,mouseY/dcelly);
}

void mouseReleased() {
   println("mouse released at: "+ mouseX/dcellx+"  "+mouseY/dcelly);
   dropx=mouseX/dcellx;
   dropy=mouseY/dcelly;
   
   int itype = (imove+1)%2;
   
   if(dragx==dropx && dragy==dropy) { 
     itype=imove%2+2;
     
   } else {
     // STORE drag / drop cells in entanglement list
   }
   markcell(itype, mouseX/dcellx,mouseY/dcelly);
   imove++;
   checkwin();
}

void markcell(int itype, int icellx, int icelly) {
  
  println("itype="+itype+"  at "+icellx+" / "+icelly);
  
  t3board[icellx][icelly]=itype;
  
  if(itype>1) {
    
    for(int ix=0; ix<ncellx; ix++) {
      for(int iy=0; iy<ncelly; iy++) {
        
        if(t3board[ix][iy]==0 || t3board[ix][iy]==1) t3board[ix][iy]+=2;
      }
    }
    
  }
  
}

void checkwin() {
  
  // horizontal wins
  if((t3board[0][0]>1 && t3board[0][0]==t3board[0][1] && t3board[0][1]==t3board[0][2])) {
    t3bgnd[0][0]=127;
    t3bgnd[0][1]=127;
    t3bgnd[0][2]=127;
    return;
    
  } else if ((t3board[1][0]>1 && t3board[1][0]==t3board[1][1] && t3board[1][1]==t3board[1][2])) {
    t3bgnd[1][0]=127;
    t3bgnd[1][1]=127;
    t3bgnd[1][2]=127;    
    return;
    
  } else if ((t3board[2][0]>1 && t3board[2][0]==t3board[2][1] && t3board[2][1]==t3board[2][2])) {
    t3bgnd[2][0]=127;
    t3bgnd[2][1]=127;
    t3bgnd[2][2]=127;     
    return;
    
  // vertical wins
  } else if ((t3board[0][0]>1 && t3board[0][0]==t3board[1][0] && t3board[1][0]==t3board[2][0])) {
    t3bgnd[0][0]=127;
    t3bgnd[1][0]=127;
    t3bgnd[2][0]=127;    
    return;
    
  } else if ((t3board[0][1]>1 && t3board[0][1]==t3board[1][1] && t3board[1][1]==t3board[2][1])) {
    t3bgnd[0][1]=127;
    t3bgnd[1][1]=127;
    t3bgnd[2][1]=127;    
    return;
    
  } else if ((t3board[0][2]>1 && t3board[0][2]==t3board[1][2] && t3board[1][2]==t3board[2][2])) {
    t3bgnd[0][2]=127;
    t3bgnd[1][2]=127;
    t3bgnd[2][2]=127; 
    return;
    
  // diagonal wins  
  } else if ((t3board[0][0]>1 && t3board[0][0]==t3board[1][1] && t3board[1][1]==t3board[2][2])) {
    t3bgnd[0][0]=127;
    t3bgnd[1][1]=127;
    t3bgnd[2][2]=127;     
    return;
    
  } else if ((t3board[0][2]>1 && t3board[0][2]==t3board[1][1] && t3board[1][1]==t3board[2][0])) {
    t3bgnd[0][2]=127;
    t3bgnd[1][1]=127;
    t3bgnd[2][0]=127; 
    return;
  }
}

void addlink(int frow,int fcol, int trow, int tcol) {
  qsfrow[nqs]=frow;
  qsfcol[nqs]=fcol;
  qstrow[nqs]=trow;
  qstcol[nqs]=tcol;
  nqs++;
}

void remlink(int frow,int fcol, int trow, int tcol) {
  int remindex=-1;
  
  for(int i=0; i<nqs; i++) {
    if(frow==qsfrow[i] && fcol==qsfcol[i] && trow==qstrow[i] && tcol==qstcol[i]) {
      remindex=i;
    }
    
    if(remindex==i) {
      qsfrow[remindex]=qsfrow[i+1];
      qsfcol[remindex]=qsfcol[i+1];
      qstrow[remindex]=qstrow[i+1];
      qstcol[remindex]=qstcol[i+1];
      remindex++;
    }
  }
  
  if(remindex!=-1) nqs--;
}

int findlink(int frow,int fcol, int trow, int tcol) {
    int findindex=-1;
  for(int i=0; i<nqs; i++) {
    if(frow==qsfrow[i] && fcol==qsfcol[i] && trow==qstrow[i] && tcol==qstcol[i]) {
      findindex=i; break;
    }
  }
  return findindex;
}

void nextlink(int frow,int fcol) {
}