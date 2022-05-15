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

-- platform specific api
local flr,ceil=math.floor,math.ceil
local api=setmetatable({
    flr=flr,
    cls=function(color)
        ffi.fill(vid_ptr, framebufferLen, 0)
    end,
    flip=function()        
        ondraw:demand()
    end,
    pset=function(x,y,c)
        vid_ptr[flr(x)+480*flr(y)]=0xff000000+c
    end,
    print=function(s,x,y,c)    
    end,
    printh=print,
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
    while true do
        _update()
        _draw()   
        flip()
    end
end, api)()


