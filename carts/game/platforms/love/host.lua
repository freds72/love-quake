-- 
local lt = love.thread
local ffi=require("ffi")
local input = require("platforms.love.input")

-- framebuffer
local framebufferLen = 480*270*ffi.sizeof("uint32_t")
local fb = love.data.newByteData(framebufferLen)
local vid_ptr = ffi.cast("uint32_t*",fb:getFFIPointer())
lt.getChannel("onload"):push(fb)

-- thread sync
local ondraw = lt.getChannel("ondraw")
local onkill = lt.getChannel("onkill")

-- platform specific api
local flr,ceil=math.floor,math.ceil
local sub,add,ord,del=string.sub,table.insert,string.byte,table.remove
local abs=math.abs
local min,max=math.min,math.max
local band,bor,shl,shr,bnot=bit.band,bit.bor,bit.lshift,bit.rshift,bit.bnot
local printh=print

local this_time = 0

local api=setmetatable({
    cos=function(angle)
        return math.cos(3.1415 * angle)
    end,
    sin=function(angle)
        return math.sin(3.1415 * angle)
    end,
    time=function()
        return this_time
    end,
    cls=function(color)
        ffi.fill(vid_ptr, framebufferLen, 0)
    end,
    flip=function()
        -- wait for display sync        
        this_time = ondraw:demand()
    end,
    pset=function(x,y,c)
        vid_ptr[flr(x)+480*flr(y)]=0xff000000+c
    end,
    print=function(s,x,y,c)    
    end,
    line=function(x0,y0,x1,y1,c)   
        c = 0xff000000+c     
        local dx,dy=x1-x0,y1-y0
        if abs(dx)>abs(dy) then
            if x0>x1 then
                x0,y0,x1,y1=x1,y1,x0,y0
            end
            local dy=(y1-y0)/(x1-x0)
            if x0<0 then
                y0=y0+x0*dy x0=0
            end
            for x=flr(x0),min(flr(x1),480)-1 do
                vid_ptr[x+480*flr(y0)]=c
                y0 = y0 + dy
            end
        else
            if y0>y1 then
                x0,y0,x1,y1=x1,y1,x0,y0
            end
            local dx=(x1-x0)/(y1-y0)
            if y0<0 then
                x0=x0+y0*dx y0=0
            end
            for y=flr(y0),min(flr(y1),270)-1 do
                vid_ptr[flr(x0)+480*y]=c
                x0 = x0 + dx
            end            
        end
    end,
    rnd=function(range)
        return (range or 1) * math.random()
    end
    },
    { __index=_G })

-- load game within the "picotron" API context
local chunk = love.filesystem.load("game.lua") -- load the chunk

-- load game within env
setfenv(chunk, api)()

-- run
setfenv(function()
    -- 
    while not onkill:peek() do
        _update()
        _draw()   
        flip()
    end
    printh("stopping game host")
end, api)()


