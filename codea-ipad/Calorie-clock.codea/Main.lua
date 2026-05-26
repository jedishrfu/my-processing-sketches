-- Calorie-clock

function seconds_from_midnight()
    
    -- Get the current time
    local current_time = os.date("*t")
    
    -- Calculate the total seconds since midnight
    local seconds_since_midnight = current_time.hour * 3600 + current_time.min * 60 + current_time.sec
    
    return seconds_since_midnight
    
end

function cals_from_midnight()
    
    local cals_per_day = 1500
    local cals_per_second = cals_per_day / (24*3600)
    
    return seconds_from_midnight() * cals_per_second
    
end

-- Use this function to perform your initial setup

function setup()
    
    x0=WIDTH/2
    y0=HEIGHT/2
    r0=x0/2
    r1=x0/8
    dtheta=2*math.pi/24
    
end

-- This function gets called once every frame

function draw()
    
    -- This sets a dark background color 
    background(40, 40, 50)

    -- This sets the line thickness
    strokeWidth(5)
    fontSize(32)
    
    -- Do your drawing here
    half_pi=math.pi / 2
    theta = 0
    
    for i = 0, 24 do

        x=r0*math.cos(theta+half_pi)+x0
        y=r0*math.sin(theta+half_pi)+y0
       
        now_hour = math.floor(seconds_from_midnight() / 3600) + 1
        
        if now_hour < i then
            fill(128,128,128) 
        else
            fill(127, 225, 225)
        end
        ellipse(x,y,r1)
        
        fill(0,0,255)
        text(i-1,x,y)
        
        theta=-dtheta*(i)
    end

    cal_count = 1400
    now_cals = math.floor(cals_from_midnight())
    
    if now_cals > cal_count then
        fill(0,255,0)
    else
        fill(255,0,0)
    end
    
    cals_int = math.floor(cals_from_midnight())
    text(cals_int,WIDTH/2,HEIGHT/2)
    
end