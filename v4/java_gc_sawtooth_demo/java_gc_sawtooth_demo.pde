import java.lang.management.*;
import java.util.*;

int W=1100, H=600;

int[] heapMB;
byte[] gcEvent;
int idx=0;

ArrayList<byte[]> old=new ArrayList<byte[]>();

// aggressive settings for fast GC
int tmpPerFrame=100000;
int tmpSize=256;

int oldAdds=10;
int oldSize=128*1024;

int cycle=360;
int dropAt=240;

long lastGCCount=0;

GarbageCollectorMXBean gcBean;

void setup(){
  size(1100,600);   // MUST BE FIRST
  frameRate(60);

  heapMB=new int[W];
  gcEvent=new byte[W];

  // grab a GC bean
  for(GarbageCollectorMXBean b:ManagementFactory.getGarbageCollectorMXBeans()){
    if(b.getCollectionCount()!=-1){
      gcBean=b;
      break;
    }
  }
}

void draw(){

  // create lots of short-lived garbage
  for(int i=0;i<tmpPerFrame;i++){
    byte[] t=new byte[tmpSize];
    t[0]=1;
  }

  // build old-gen pressure
  for(int i=0;i<oldAdds;i++){
    old.add(new byte[oldSize]);
  }

  // periodically drop old refs
  if(frameCount%cycle==dropAt){
    old.clear();
  }

  // measure heap
  Runtime rt=Runtime.getRuntime();
  long used=rt.totalMemory()-rt.freeMemory();
  int usedMB=(int)(used/(1024*1024));
  int maxMB=(int)(rt.maxMemory()/(1024*1024));

  heapMB[idx]=usedMB;
  gcEvent[idx]=0;

  // detect GC by counter change
  long c=gcBean.getCollectionCount();
  if(c>lastGCCount){
    long delta=c-lastGCCount;
    if(delta==1) gcEvent[idx]=1;      // small/young
    else if(delta<=3) gcEvent[idx]=2; // bigger
    else gcEvent[idx]=3;              // full-ish
    lastGCCount=c;
  }

  idx=(idx+1)%W;

  background(20);
  drawGraph(maxMB);

  fill(255);
  text("Heap Used: "+usedMB+"MB / "+maxMB+"MB",20,20);
  text("Green=minor  Orange=major  Red=full-ish",20,40);
}

void drawGraph(int maxMB){

  int top=60;
  int bottom=H-60;
  int h=bottom-top;

  for(int i=1;i<W;i++){

    int a=(idx+i-1)%W;
    int b=(idx+i)%W;

    float y0=bottom-(heapMB[a]/max(1.0,(float)maxMB))*h;
    float y1=bottom-(heapMB[b]/max(1.0,(float)maxMB))*h;

    if(gcEvent[b]==1) stroke(0,255,0);
    else if(gcEvent[b]==2) stroke(255,180,0);
    else if(gcEvent[b]==3) stroke(255,0,0);
    else stroke(230);

    line(i-1,y0,i,y1);
  }
}
