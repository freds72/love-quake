if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    _dont_grab_mouse = true
    -- start debugger only in 1 thread
    -- require("lldebugger").start()
end

-- yikes until better solution!
printh=print
local conf = require("game_conf")
printh=nil
local nfs = require("lib.nativefs")

-- current platform is Löve
local ffi=require("ffi")
local framebuffer = require("picotron.emulator.framebuffer")

local lf = love.filesystem
local lti = love.timer
local lg = love.graphics
local min,max=math.min,math.max
local gameThread

-- thread sync
local channels = require("picotron.emulator.channels")()

--
local utf8offset=require("utf8").offset
local string_sub = string.sub
local select = select
string.ulen = require("utf8").len

function string.usub(s, start_in_chars, ...)
  local start_in_bytes = utf8offset(s, start_in_chars)
  if start_in_bytes == nil then
    start_in_bytes = #s + 1
    if start_in_chars < 0 then
      start_in_bytes = -start_in_bytes
    end
  end

  if select('#', ...) == 0 then -- no second arg
    return string_sub(s, start_in_bytes)
  end

  local end_in_chars = ...
  if end_in_chars == -1 then -- -1 doesn't go well with the +1 needed later
    return string_sub(s, start_in_bytes)
  end

  local end_in_bytes = utf8offset(s, end_in_chars + 1)
  if end_in_bytes == nil then
    end_in_bytes = #s + 1
    if end_in_chars < 0 then
      end_in_bytes = -end_in_bytes
    end
  end
  return string_sub(s, start_in_bytes, end_in_bytes - 1)
end

-- keyboards and mouse states
local scanCodes={}
local mouseInfo={
    dx=0,
    dy=0
}

-- Picotron display size
local screenWidth,screenHeight=480,270

-- Love screen size
local scale,xoffset,yoffset = 2,0,0
local displayWidth,displayHeight=scale * screenWidth,scale * screenHeight
local imageExtensions={[".png"]=true,[".bmp"]=true}
  
function love.load(args)  
    love.window.setMode(displayWidth, displayHeight, {resizable=true, vsync=true, minwidth=480, minheight=270})

    if not _dont_grab_mouse then
        love.mouse.setGrabbed(true)
        love.mouse.setRelativeMode( true )
        love.mouse.setVisible(false)
    end

    -- print canvas
    printCanvas = lg.newCanvas( screenWidth, screenHeight, {format="r8"})
    -- exchange buffer
    canvasBytes = love.data.newByteData(screenWidth * screenHeight)
    -- console font
    consoleFont = lg.newFont("picotron/assets/console.fnt")

    print("starting game thread...")
    gameThread = love.thread.newThread( lf.read("picotron/emulator/host.lua") )
    gameThread:start(unpack(args))
end

function love.keypressed( key, scancode, isrepeat )
    if key == "escape" then
        love.event.quit(0)
    elseif key == "f11" then
        fullscreen = not fullscreen
        love.window.setFullscreen(fullscreen)
        love.resize(love.graphics.getDimensions())
    end    
    scanCodes[scancode] = true
end

function love.keyreleased( key, scancode )
    scanCodes[scancode] = nil
end

-- "scancodes" for mouse
local mbtn_names={"lmb","rmb","mmb"}
function love.mousepressed( x, y, button, istouch, presses )
    -- convert mouse buttons to "scancodes"
    scanCodes[mbtn_names[button]] = true
end
function love.mousereleased( x, y, button, istouch, presses )
    scanCodes[mbtn_names[button]] = nil
end

function love.wheelmoved( x, y )
    mouseInfo.wheel = y
end

function love.mousemoved( x, y, dx, dy, istouch )
    mouseInfo.dx = mouseInfo.dx + dx/scale
    mouseInfo.dy = mouseInfo.dy + dy/scale
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
        local msg = channels:pop()
        while msg do
            local name,a,b,c,d,e,f=unpack(msg)
            if name=="flip" then
                if love.timer then dt = love.timer.step() end

                if lg and lg.isActive() then
                    -- a: framebuffer
                    -- b: HW palette (image)
                    -- c: selected colormap row
                    local fb = ffi.cast("uint8_t*", a:getFFIPointer())
                    local pal = ffi.cast("uint32_t*", b:getFFIPointer()) + c
                    -- display current backbuffer
                    lg.origin()
                    lg.clear(lg.getBackgroundColor())
                    lg.setColor(1,1,1)
                    framebuffer:present(xoffset, yoffset, fb, pal, scale)
                    lg.setColor(0,1,0)
                    lg.print("fps: "..love.timer.getFPS(),2,displayHeight - 20)
                    lg.present()
                end
                -- unlock vm
                channels:response(lti.getTime())
                break 
            elseif name=="load" then
                -- a: filename
                local paths, filename, data, err = { 
                    conf.mod_path and conf.mod_path.."/"..a or "", 
                    love.filesystem.getSourceBaseDirectory().."/"..arg[1].."/"..a, 
                    conf.root_path.."/"..a }
                
                -- try reading file and fallback through mod_path, source path and root_path
                for _,fn in ipairs(paths) do
                    filename = fn
                    data, err = nfs.newFileData(filename)
                    if data then
                        local extension=string.sub(a,#a-3,#a)
                        if imageExtensions[extension] then
                            local img = love.image.newImageData(data)
                            print("Loading image asset: "..filename.." format:"..img:getFormat( ))
                            local w,h=img:getWidth(),img:getHeight()
                            local data = love.data.newByteData(img,0,img:getSize())
                            img:release()
                            channels:response({data,w,h})
                        else
                            print("Loading asset: "..filename)
                            channels:response({data, data:getSize()})
                        end
                        break
                    end
                    if err then print(err) end
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
                    local ch=string.usub(a,i,i)
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
                        -- todo: color (wargh!)
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
                ffi.copy(canvasBytes:getFFIPointer(),img:getFFIPointer(),screenWidth*screenHeight)
                img:release()
                local x,y=max(0,b),max(0,c)
                -- compute rectangle to capture
               channels:response({canvasBytes,x,y,min(x+w,screenWidth),min(y+h,screenHeight)})
            elseif name=="keys" then
                -- copy active scan codes
                local keys={}
                for k in pairs(scanCodes) do
                    keys[k] = scanCodes[k]
                end
                channels:response(keys)            
            elseif name=="mouse" then
                channels:response({
                    -- return mouse position when requested
                    x=math.floor(love.mouse.getX()/scale),
                    y=math.floor(love.mouse.getY()/scale),        
                    dx=mouseInfo.dx,
                    dy=mouseInfo.dy
                })
                mouseInfo.dx=0
                mouseInfo.dy=0
            end
        -- next message
            msg = channels:pop()
        end

        if love.timer then love.timer.sleep(0) end
	end
end