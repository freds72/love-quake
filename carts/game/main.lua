-- current platform is Löve
local ffi=require("ffi")
local input = require("picotron.emulator.input")
local framebuffer = require("picotron.emulator.framebuffer")

local lf = love.filesystem
local lti = love.timer
local gameThread

-- thread sync
local channels = require("picotron.emulator.channels")()

local fb
local width,height=480,270
local scale,xoffset,yoffset = 2,0,0

function love.load()
    love.window.setMode(width * scale, height * scale, {resizable=true, vsync=true, minwidth=480, minheight=270})

    print("starting game thread...")
    gameThread = love.thread.newThread( lf.read("picotron/emulator/host.lua") )
    gameThread:start()
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

function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0

	-- Main loop time.
	return function()
		-- Process events.
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end
				love.handlers[name](a,b,c,d,e,f)
			end
		end

        -- process emulator events
        local msg = channels.events:pop()
        if msg then 
            local name,a,b,c,d,e,f=unpack(msg)
            if name=="flip" then
                if love.graphics and love.graphics.isActive() then
                    local fb = ffi.cast("uint32_t*", a:getFFIPointer())
                    -- display current backbuffer
                    love.graphics.origin()
                    love.graphics.clear(love.graphics.getBackgroundColor())
                    framebuffer:present(xoffset, yoffset, fb, scale)
                    love.graphics.present()
                    -- wait (host)
                end
                -- unlock vm
                channels.lock:push(lti.getTime())   
            elseif name=="load" then
            end
        end

        if love.timer then love.timer.sleep(0.001) end
	end
end