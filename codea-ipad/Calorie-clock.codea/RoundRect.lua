function roundRect(x,y,w,h,r)
    pushStyle()
    
    insetPos = vec2(x+r,y+r)
    insetSize = vec2(w-2*r,h-2*r)
    
    --Copy fill into stroke
    local red,green,blue,a = fill()
    stroke(red,green,blue,a)
    
    noSmooth()
    rectMode(CORNER)
    rect(insetPos.x,insetPos.y,insetSize.x,insetSize.y)
    
    if r > 0 then
        smooth()
        lineCapMode(ROUND)
        strokeWidth(r*2)
        
        line(insetPos.x, insetPos.y, 
        insetPos.x + insetSize.x, insetPos.y)
        line(insetPos.x, insetPos.y,
        insetPos.x, insetPos.y + insetSize.y)
        line(insetPos.x, insetPos.y + insetSize.y,
        insetPos.x + insetSize.x, insetPos.y + insetSize.y)
        line(insetPos.x + insetSize.x, insetPos.y,
        insetPos.x + insetSize.x, insetPos.y + insetSize.y)            
    end
    popStyle()
end