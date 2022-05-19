-- picotron emulator entry point
local lt = love.thread
local ffi=require("ffi")
local input = require("picotron.emulator.input")
-- thread sync
local channels=require("picotron.emulator.channels")

-- framebuffer
local framebufferLen = 480*270*ffi.sizeof("uint32_t")
local fb = love.data.newByteData(framebufferLen)
local vid_ptr = ffi.cast("uint32_t*",fb:getFFIPointer())
channels.onload:push(fb)

-- platform specific api
local flr,ceil=math.floor,math.ceil
local sub,add,ord,del=string.sub,table.insert,string.byte,table.remove
local abs=math.abs
local min,max=math.min,math.max
local band,bor,shl,shr,bnot=bit.band,bit.bor,bit.lshift,bit.rshift,bit.bnot
local _print=print

local this_time = 0

-- emulation helpers
-- local fontManager=require("picotron.emulator.fontmanager")()

-- active assets
local activePalette,activeColormap

-- asset id cache

local api=setmetatable({
    -- rebase angle to 0..1
    cos=function(angle)
        return math.cos(math.pi * angle)
    end,
    -- rebase angle to 0..1
    sin=function(angle)
        return math.sin(math.pi * angle)
    end,    
    time=function()
        return this_time
    end,
    cls=function(color)
        ffi.fill(vid_ptr, framebufferLen, 0)
    end,
    flip=function()
        -- wait for display sync        
        this_time = channels.vsync:demand()
    end,
    pset=function(x,y,c)
        vid_ptr[flr(x)+480*flr(y)]=0xff000000+c
    end,
    pal=function(colors)

    end,
    -- map an asset to memory
    mmap=function(name)
        -- delegate to main thread
        channels.onfileRequest:push(name)
        local img = unpack(channels.onfileResponse:demand())
    end,
    printh=function(s)
        -- print to console
        _print(s)
    end,
    print=function(s,x,y)    
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

-- default values
-- activePalette=api.mmap("picotron/assets/palette.png","uint32")
-- activeColormap=api.mmap("picotron/assets/colormap.bmp","uint8")

-- load game within the "picotron" API context
local chunk = love.filesystem.load("game.lua") -- load the chunk

-- load game within env
setfenv(chunk, api)()

-- run
setfenv(function()
    local init=api._init
    if init then
        init()
    end
    -- 
    while not channels.onkill:peek() do
        if api._update then _update() end
        if api._draw then _draw() end
        flip()
    end
    
    printh("Emulator stopped")
end, api)()


