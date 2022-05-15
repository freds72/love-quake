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
local fb

function love.load()
    love.window.setMode(480 * 2, 270 * 2, {resizable=false, vsync=true, minwidth=480, minheight=270})

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

function love.update()
    --input:update()
end

function love.draw()
    framebuffer:present(fb, 2)
    ondraw:push(lti.getTime())
    -- display   
    -- print("fb:"..tostring(fb)) 
    
end
