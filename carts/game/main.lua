-- current platform is Löve
local ffi=require("ffi")
local input = require("picotron.emulator.input")
local framebuffer = require("picotron.emulator.framebuffer")

local lf = love.filesystem
local lti = love.timer
local lg = love.graphics
local min,max=math.min,math.max
local gameThread

-- thread sync
local channels = require("picotron.emulator.channels")()

-- logical screen size
local displayWidth,displayHeight=480,270
local scale,xoffset,yoffset = 2,0,0
local imageExtensions={[".png"]=true,[".bmp"]=true}

function love.load()
    love.window.setMode(displayWidth * scale, displayHeight * scale, {resizable=true, vsync=true, minwidth=480, minheight=270})

    -- print canvas
    printCanvas = lg.newCanvas( displayWidth, displayHeight, {format="r8"})
    -- exchange buffer
    canvasBytes = love.data.newByteData(displayWidth * displayHeight)
    -- console font
    consoleFont = lg.newFont("picotron/assets/console.fnt")

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
    -- new displayWidth
    displayWidth,displayHeight=w,h
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
        while msg do
            local name,a,b,c,d,e,f=unpack(msg)
            if name=="flip" then
                if lg and lg.isActive() then
                    -- a: framebuffer
                    -- b: HW palette (image)
                    local fb = ffi.cast("uint8_t*", a:getFFIPointer())
                    local pal = ffi.cast("uint32_t*", b:getFFIPointer())
                    -- display current backbuffer
                    lg.origin()
                    lg.clear(lg.getBackgroundColor())
                    lg.setColor(1,1,1,1)
                    framebuffer:present(xoffset, yoffset, fb, pal, scale)
                    lg.present()
                end
                -- unlock vm
                channels.lock:push(lti.getTime())  
                break 
            elseif name=="load" then
                -- a: filename
                local extension=string.sub(a,#a-3,#a)
                if imageExtensions[extension] then
                    print("Loading image asset: "..a)
                    local img = love.image.newImageData(a)
                    -- print("format: "..img:getFormat( ))
                    channels.lock:push(img)
                else
                    print("Loading asset: "..a)
                    channels.lock:push(love.filesystem.newFileData(a))
                end
            elseif name=="print" then
                -- a: text
                -- b: x
                -- c: y
                lg.setCanvas(printCanvas)
                lg.clear(lg.getBackgroundColor())
                lg.setColor(1/255,1/255,1/255)
                local w,h=consoleFont:getWidth(a),consoleFont:getHeight(a)
                lg.print(a,consoleFont,b,c)
                lg.setCanvas()
                local img = printCanvas:newImageData()
                -- images cannot be shared cross-thread
                ffi.copy(canvasBytes:getFFIPointer(),img:getFFIPointer(),displayWidth*displayHeight)
                img:release()
                local x,y=max(0,b),max(0,c)
                -- compute rectangle to capture
                channels.lock:push({canvasBytes,x,y,min(x+w,displayWidth),min(y+h,displayHeight)})
            end
            -- next message
            msg = channels.events:pop()
        end

        if love.timer then love.timer.sleep(0) end
	end
end