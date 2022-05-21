-- picotron emulator entry point
local lt = love.thread
local lti = love.timer
local ffi=require("ffi")
local input = require("picotron.emulator.input")
-- thread sync
local channels=require("picotron.emulator.channels")()

-- framebuffer (1 byte per pixel)
local framebufferLen = 480*270
local fb = love.data.newByteData(framebufferLen)
local vid_ptr = ffi.cast("uint8_t*",fb:getFFIPointer())

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
    mid=function(x, a, b)
        return math.max(a, math.min(b, x))
    end,
    -- rebase angle to 0..1
    cos=function(angle)
        return math.cos(math.pi * angle)
    end,
    -- rebase angle to 0..1
    sin=function(angle)
        return math.sin(math.pi * angle)
    end, 
    abs=function(a)   
        return math.abs(a)
    end,
    time=function()
        return this_time
    end,
    cls=function(color)
        ffi.fill(vid_ptr, framebufferLen, 0)
    end,
    flip=function()
        -- wait for display sync 
        channels.events:push({"flip",fb,activePalette})
        this_time = channels.lock:demand()
    end,
    pset=function(x,y,c)
        vid_ptr[flr(x)+480*flr(y)]=flr(c)
    end,
    pal=function(colors)

    end,
    -- map an asset to memory
    mmap=function(name)
        -- delegate to main thread
        channels.events:push({"load",name})
        return channels.lock:demand()
    end,
    printh=function(s)
        -- print to console
        _print(s)
    end,
    print=function(s,x,y,c)
        c=flr(c)%64
        x=flr(x)
        y=flr(y)
        channels.events:push({"print",s,x,y})
        local img,x0,y0,x1,y1 = unpack(channels.lock:demand())
        local src=ffi.cast('uint8_t*', img:getFFIPointer())
        for y=y0,y1-1 do
            for x=x0,x1-1 do
                local idx=x+480*y
                -- masking and merging
                local s=src[idx]
                if s~=0 then
                    vid_ptr[idx]=flr(c*s)
                end
            end
        end
    end,
    line=function(x0,y0,x1,y1,c)   
        c = flr(c)
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
-- credits: https://lospec.com/palette-list/famicube
activePalette=api.mmap("picotron/assets/famicube-1x.png")

-- activeColormap=api.mmap("picotron/assets/colormap.bmp","uint8")

-- load game within the "picotron" API context
local chunk = love.filesystem.load("game.lua") -- load the chunk

print("Starting game...")

-- load game within env
setfenv(chunk, api)()

-- run
setfenv(function()
    local init=api._init
    if init then
        init()
    end
    -- 
    while true do
        if api._update then _update() end
        if api._draw then _draw() end
        flip()
    end
end, api)()


