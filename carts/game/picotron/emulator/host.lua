if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    -- start debugger only in 1 thread
    require("lldebugger").start()
end

-- thread params
local _arg0,_arg1,_arg2,_arg3 = ...

-- picotron emulator entry point
local lt = love.thread
local lti = love.timer
local ffi=require("ffi")
-- thread sync
local channels=require("picotron.emulator.channels")()
local _frame=0
local _lastInputFrame=-1
local _previousKeys,_keys={},{}

-- framebuffer (1 byte per pixel)
local framebufferLen = 480*270
local fb = love.data.newByteData(framebufferLen)
local vid_ptr = ffi.cast("uint8_t*",fb:getFFIPointer())

-- platform specific api
local _print=print

local this_time = 0

-- emulation helpers
-- local fontManager=require("picotron.emulator.fontmanager")()

-- active assets
local activeColormap

-- misc convenient functions
mid=function(x, a, b)
    return math.max(a, math.min(b, x))
end
-- rebase angle to 0..1
cos=function(angle)
    return math.cos(math.pi * angle)
end
-- rebase angle to 0..1
sin=function(angle)
    return math.sin(math.pi * angle)
end
flr=math.floor
ceil=math.ceil
abs=math.abs
min=math.min
max=math.max
sqrt=math.sqrt
band=bit.band
bor=bit.bor
shl=bit.lshift
shr=bit.rshift
bnot=bit.bnot
add=table.insert
del=table.remove
sub=string.sub
ord=string.byte
rnd=function(start_range, end_range)
    start_range = start_range or 0
    end_range = end_range or 1
    return start_range + (end_range - start_range) * math.random()
end    
time=function()
    return this_time
end
function split(inputstr, sep)
    if sep == nil then
      sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      table.insert(t, str)
    end
    return t
end

-- map an asset to memory
mmap=function(name,layout)
    -- delegate to main thread
    local data,w,h=unpack(channels:wait({"load",name}))
    -- 1d assets
    h=h or 1
    local ptr = data:getFFIPointer()
    return {_data=data,size=w*h,ptr=layout and ffi.cast(layout.."*",ptr) or ptr,width=w,height=h}
end

-- input
local function refreshInputs()
    if _lastInputFrame~=_frame then
        -- sync 
        local keys = channels:wait({"keys"})
        _previousKeys,_keys = _keys,keys

        _mouse = channels:wait({"mouse"})
        _lastInputFrame = _frame
    end 
end
btn=function(id)
    -- gamepad not supported
    return false
end
-- returns true if given scancode is down
key=function(id)
    refreshInputs()
    return _keys[id]
end
-- returns if a given scancode has been pressed (down then released)
keyp=function(id)
    refreshInputs()
    -- was pressed but not anymore
    return _previousKeys[id] and not _keys[id]
end

-- returns mouse coords
mouse=function()
    refreshInputs()
    return _mouse.x,_mouse.y
end
-- returns mouse mouve
dmouse=function()
    refreshInputs()
    return _mouse.dx,_mouse.dy
end

-- text
-- print to console
printh=function(s)
    -- print to console
    _print(s)
end
-- print on screen
print=function(s,x,y,c)
    c=flr(c)%activeColormap.width
    x=flr(x)
    y=flr(y)
    local img,x0,y0,x1,y1 = unpack(channels:wait({"print",s,x,y}))
    local src=ffi.cast('uint8_t*', img:getFFIPointer())
    for y=480*y0,480*(y1-1) do
        for x=x0,x1-1 do
            local idx=x+y
            -- masking and merging
            local s=src[idx]
            if s~=0 then
                vid_ptr[idx]=flr(c*s)
            end
        end
    end
end

-- gfx
cls=function(color)
    ffi.fill(vid_ptr, framebufferLen, 0)
end
flip=function()
    -- wait for display sync 
    this_time = channels:wait({"flip",fb,activeColormap._data, activeColormapRow * activeColormap.width})
    _frame = _frame + 1
end
local _color=0
color=function(c)
    _color=c or 0
end
pset=function(x,y,c)
    vid_ptr[flr(x)+480*flr(y)]=flr(c)%256
end
blend=function(colors,row,screen)
    row = row or 0
    activeColormap = colors
    assert(row<64,"Invalid colormap row")
    activeColormapRow = row
end

local _texture
-- set the active texture
tput=function(src)    
    _texture = src
end
-- draw a perspective correct textured line
-- note: only horiz lines are supported
tline3d=function(x0,y0,x1,_,u,v,w,du,dv,dw)
    local ptr,width,height=_texture.ptr,_texture.width,_texture.height
    for x=x0+480*y0,x1+480*y0 do
        vid_ptr[x]=ptr[(flr(u/w)%width)+width*(flr(v/w)%height)]
        u = u + du
        v = v + dv
        w = w + dw
    end
end
line=function(x0,y0,x1,y1,c)   
    c = flr(c or _color or 0)%activeColormap.width
    _color = c
    local dx,dy=x1-x0,y1-y0
    if abs(dx)>abs(dy) then
        if x0>x1 then
            x0,y0,x1,y1=x1,y1,x0,y0
        end
        local dy=(y1-y0)/(x1-x0)
        if x0<0 then
            y0=y0-x0*dy x0=0
        end
        for x=flr(x0),min(flr(x1),480)-1 do
            if y0>=0 and y0<270 then                
                vid_ptr[x+480*flr(y0)]=c
            end
            y0 = y0 + dy
        end
    else
        if y0>y1 then
            x0,y0,x1,y1=x1,y1,x0,y0
        end
        local dx=(x1-x0)/(y1-y0)
        if y0<0 then
            x0=x0-y0*dx y0=0
        end        
        for y=flr(y0),min(flr(y1),270)-1 do
            if x0>=0 and x0<480 then
                vid_ptr[flr(x0)+480*y]=c
            end
            x0 = x0 + dx
        end            
    end
end
 
-- misc helpers
args=function()
    return _arg1,_arg2,_arg3
end

-- default values
blend(mmap("gfx/colormap.png"),31)

-- load game within the "picotron" API context
local chunk,err = love.filesystem.load(_arg0..".lua") -- load the chunk
assert(chunk,err)

printh("Starting game...")

-- load game
chunk()

-- init
if _init then _init() end

-- game loop
while true do
    if _update then _update() end
    if _draw then _draw() end
    flip()
end


