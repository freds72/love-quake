-- current platform is Löve
local ffi=require("ffi")
local input = require("platforms.love.input")
local framebuffer = require("platforms.love.framebuffer")

local lf = love.filesystem
local lti = love.timer
local gameThread

-- thread sync
local ondraw = love.thread.getChannel ("ondraw")
local onload = love.thread.getChannel("onload")
local onkill = love.thread.getChannel("onkill")
local fb
local width,height=480,270
local scale,xoffset,yoffset = 2,0,0

function love.load()
    love.window.setMode(width * scale, height * scale, {resizable=true, vsync=true, minwidth=480, minheight=270})

    gameThread = love.thread.newThread( lf.read("platforms/love/host.lua") )
    gameThread:start()

    -- wait for framebuffer creation/sharing
    fb = ffi.cast("uint32_t*", onload:demand():getFFIPointer())
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit(0)
    end
end

function love.resize(w,h)   
    -- new width
    width,height=w,h
    scale=w/480
    xoffset=0
    yoffset=h/2-scale*270/2
    -- take smaller scale
    if scale>h/270 then
        scale=h/270
        xoffset=w/2-scale*480/2
        yoffset=0
    end
end

function love.quit()
    -- ensure buffer flip is unlocked
    ondraw:push(lti.getTime())    
    -- notify running thread
    onkill:push(true)
    -- wait
    gameThread:wait()    
    gameThread=nil
end

function love.update()
    --input:update()
end

function love.draw()
    -- display current backbuffer
    framebuffer:present(xoffset, yoffset, fb, scale)
    -- unlock game
    ondraw:push(lti.getTime())   
    
    -- love.graphics.print("fps: "..love.timer.getFPS())
end
