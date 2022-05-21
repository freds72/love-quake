if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    _dont_grab_mouse = true
    require("lldebugger").start()
end

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

    if not _dont_grab_mouse then
        love.mouse.setGrabbed(true)
        love.mouse.setRelativeMode( true )
        love.mouse.setVisible(false)
    end

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
                if love.timer then dt = love.timer.step() end

                if lg and lg.isActive() then
                    -- a: framebuffer
                    -- b: HW palette (image)
                    local fb = ffi.cast("uint8_t*", a:getFFIPointer())
                    local pal = ffi.cast("uint32_t*", b:getFFIPointer())
                    -- display current backbuffer
                    lg.origin()
                    lg.clear(lg.getBackgroundColor())
                    lg.setColor(1,1,1)
                    framebuffer:present(xoffset, yoffset, fb, pal, scale)
                    lg.setColor(0,1,0)
                    lg.print(love.timer.getFPS(),2,2)
                    lg.present()
                end
                -- unlock vm
                channels.lock:push(lti.getTime())  
                break 
            elseif name=="load" then
                -- a: filename
                local extension=string.sub(a,#a-3,#a)
                if imageExtensions[extension] then
                    local img = love.image.newImageData(a)
                    print("Loading image asset: "..a.." format:"..img:getFormat( ))
                    local w,h=img:getWidth(),img:getHeight()
                    local data = love.data.newByteData(img,0,img:getSize())
                    img:release()
                    channels.lock:push({data,w,h})
                else
                    print("Loading asset: "..a)
                    local data = love.filesystem.newFileData(a)
                    channels.lock:push({data, data:setSize()})
                end
            elseif name=="print" then
                -- a: text
                -- b: x
                -- c: y
                lg.setCanvas(printCanvas)
                lg.clear(lg.getBackgroundColor())
                lg.setColor(1/255,1/255,1/255)

                local w,h,dh=0,0,consoleFont:getHeight() + consoleFont:getLineHeight()
                local s,sx,sy="",b,c
                for i=1,#a do
                    local ch=string.sub(a,i,i)
                    if ch=="\n" then
                        local sw=consoleFont:getWidth(s)
                        lg.print(s,consoleFont,sx,sy)
                        w = w + sw
                        h = h + dh
                        -- newline
                        sy = sy + dh
                        sx = b
                        s = ""
                    elseif ch~="\b" then
                        s = s .. ch
                    end
                end                    
                -- any remaining string to display?
                if s~="" then
                    local sw=consoleFont:getWidth(s)
                    lg.print(s,consoleFont,sx,sy)
                    w = w + sw
                    h = h + dh
                end

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