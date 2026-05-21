void op(int a[],int b) { a[0]=a[0]+b; }

void pa(int dist, int[] data, int size) {
  
  System.out.printf("\n---- dist=%d\n",dist);
  
  for(int i=0; i<size; i++) {
     System.out.printf("data[%d]=%d\n",i,data[i]);
  }
}

void pxsum(int[] data, int size, int identity) {
  
  // add missing code here
  for(int dist=2; dist<=size; dist*=2) { // upsweep (slide 13)
    //#pragma omp for
    for(int i=dist-1; i<size; i+=dist) {
      data[i]+=data[i-dist/2];
    }
  }
  
  System.out.println("\n-------\n-------\n");
 
  data[size-1] = identity;
  for(int dist=size; dist>1; dist/=2) { // down sweep (slide 14)
  
    //#pragma omp for
    for(int i=dist-1; i<size; i+=dist) {
      int temp=data[i-dist/2];
      data[i-dist/2]=data[i];
      data[i]=data[i] + temp;
      
      pa(dist*100,data,size);
    }
    
    pa(dist,data,size);
  }
  
}    

void setup() {
  pixelDensity(1);
  
  int data[] = {1,1,1,1,1,1,1,1};
  pxsum(data,data.length,0);
  
  pa(999,data,data.length);
  
  exit();
}  
  
