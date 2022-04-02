local appleCake = require("lib.AppleCake")(false) -- Set to false will remove the profiling tool from the project
appleCake.beginSession() --Will write to "profile.json" by default in the save directory
appleCake.setName("Love Quake")

local ffi=require('ffi')
local nfs = require( "nativefs" )
local modelfs = require( "modelfs" )
-- local lick = require "lick"
-- lick.reset = true -- reload the love.load everytime you save
local fb = require('fblove_strip')
local renderer = require( "renderer" )
local math3d = require( "math3d")
local progs = require("progs.main")
local logging = require("logging")
local world = require("world")
local lg = love.graphics

ffi.cdef[[
    #pragma pack(1)
    typedef struct { unsigned char r,g,b; } color_t;
]]    

-- pico8 compat helpers
local sub,add,ord,del=string.sub,table.insert,string.byte,table.remove
local abs,flr=math.abs,math.floor
local min,max=math.min,math.max
local band,bor,shl,shr,bnot=bit.band,bit.bor,bit.lshift,bit.rshift,bit.bnot
local sin,cos=math.sin,math.cos
local min, max = math.min, math.max
local function mid(x, a, b)
  return max(a, min(b, x))
end

local scale=2
local _memory_thinktime=-1

-- game globals
local velocity,dangle,angle,pos={0,0,0},{0,0,0},{0,0,0}

function printh(...)
    print(...)
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

function format(str, ...)
  local args={...}
  -- force conversion to string
  for k,v in pairs(args) do
    args[k]=tostring(v)
  end
  return string.format(str,unpack(args))
end

function print_vector(v)
  printh(v[0].." "..v[1].." "..v[2])
end

function read_palette(path)
  local palette = {}
  -- dump to bytes
  local data = nfs.newFileData(path.."/gfx/palette_orig.lmp")

  local src = ffi.cast('color_t*', data:getFFIPointer())
  for i=0,255 do
    -- swap colors
    local rgb = src[i]
    palette[i] = 0xff000000 + shl(rgb.b,16) + shl(rgb.g,8) + rgb.r
  end 
  return palette
end

function read_colormap(path)
  local colormap = {}
  -- dump to bytes
  local data = nfs.newFileData(path.."/gfx/colormap.lmp")

  local src = ffi.cast('uint8_t*', data:getFFIPointer())
  for i=0,256*64-1 do
    colormap[i] = src[i]
  end 
  return colormap
end

local _light_styles={}

love.window.setMode(480 * scale, 270 * scale, {resizable=false, vsync=true, minwidth=480, minheight=270})

if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
  _dont_grab_mouse = true
  require("lldebugger").start()
end

function love.load(args)
  appleCake.mark("Started load")

  framebuffer = fb(480, 270)
  _backbuffer = framebuffer.buf[0]

  hw = 480/2
  hh = 270/2

  local root_path = args[1]
  logging.debug("game root: "..root_path)

  -- set default palette
  _palette = read_palette(root_path)
  _colormap = read_colormap(root_path)

  _font = require("font")(root_path, _palette, _colormap)

  local precache_models = {}
  local level = modelfs.load(root_path, "maps/"..args[2])
  _world_model = level.model
  -- todo: cleanup main geometry
  _level = level.model[1]
  
  world.init(_level)

  _entities = {}
  _new_entities = {}
  _msg = nil
  _msg_ttl = -1

  -- "virtual machine" to host game logic
  _vm = progs({
    total_secrets = 0,
    found_secrets = 0,
    lightstyle=function(self, id, lightstyle)
      local style,base={},ord("a")
      for frame=0,#lightstyle-1 do
        local ch = sub(lightstyle,frame,frame+1)
        local scale = 1 - (ord(ch) - base) / 25
        assert(scale>=0 and scale<=1, "ERROR - Light style: "..id.." invalid value: '"..ch.." @'..frame")

        add(style,scale)
      end
      _light_styles[id] = style
    end,
    objerror=function(self,msg)
      -- todo: set context (if applicable)
      logging.error(tostring(msg))
    end,
    precache_model=function(self,id)
      if not precache_models[id] then
        precache_models[id] = modelfs.load(root_path, id)
      end
    end,
    setmodel=function(self,ent,id,offset)
      if not id then
        ent.origin = {0,0,0}
        ent.mins={0,0,0}
        ent.maxs={0,0,0}
        ent.size={0,0,0}        
        ent.m={
          1,0,0,0,
          0,1,0,0,
          0,0,1,0,
          0,0,0,1
        }
        ent.model = nil
        return
      end
      -- reference to world sub-models?
      local m
      if sub(id,1,1)=="*" then
        m = _world_model[tonumber(sub(id,2)) + 1]
        -- bind to model "owner"
        ent.resources = level.model
      else        
        local cached_model = precache_models[id]
        if cached_model.alias then
          m = cached_model.alias
        else
          m = cached_model.model[1]        
          -- todo: revisit (single big array?)
          ent.resources = cached_model.model
        end
      end

      if not m then
        logging.critical("Invalid model id: "..id)
      end
      ent.model = m   
      if not ent.origin then
        ent.origin = {0,0,0}
      end
      ent.offset = offset
      local angles=ent.mangles or {0,0,0}
      ent.m=make_m_from_euler(unpack(angles))
      m_set_pos(ent.m,ent.origin)

      -- bounding box
      if ent.frame then
        -- animated model?
        local frame = m.frames[ent.frame]
        assert(frame,"Invalid frame id: "..ent.frame)
        ent.size = v_add(frame.maxs,frame.mins,-1)
        ent.mins = v_clone(frame.mins)
        ent.maxs = v_clone(frame.maxs)
      else
        ent.size = v_add(m.maxs,m.mins,-1)
        ent.mins = v_clone(m.mins)
        ent.maxs = v_clone(m.maxs)
      end
      ent.absmins=v_add(ent.origin,ent.mins)
      ent.absmaxs=v_add(ent.origin,ent.maxs)
      -- register into world
      ent.nodes={}
      if id~="*0" then
        world.register(ent)
      end
    end,
    setorigin=function(self,ent,pos)
      ent.origin = v_clone(pos)
      ent.absmins=v_add(ent.origin,ent.mins)
      ent.absmaxs=v_add(ent.origin,ent.maxs)
      m_set_pos(ent.m,ent.origin)

      -- todo: wargh remove!!
      if ent.classname~="player" then
        world.register(ent)
      end
    end,
    time=function()
      return love.frame / 60
    end,
    print=function(self,msg,...)
      local txt = format(msg,...)
      -- avoid repeating messages
      if txt==_msg then
        return
      end
      logging.debug("MESSAGE - "..tostring(txt))
      _msg = txt
      -- keep 3s on screen
      _msg_ttl = love.frame + 3*60
    end,
    -- find all entities with a property matching the given value
    -- if filter is given, only returns entities with an additional "filter" field
    find=function(_,ent,property,value,filter)
      local matches={}
      for i=1,#_entities do
        local other=_entities[i]
        if not other.free and ent~=other and other[property]==value then
          if not filter or other[filter] then
            add(matches, other)
          end
        end
      end
      return matches
    end,
    spawn=function(_)
      -- don't add new entities in this frame
      local ent={
        nodes={},
        m={
          1,0,0,0,
          0,1,0,0,
          0,0,1,0,
          0,0,0,1
        }        
      }
      add(_new_entities,ent)
      return ent
    end,
    remove=function(_,ent)
      -- mark entity for deletion
      ent.free = true
    end,
    set_skill=function(_,skill)
      logging.debug("Selected skill level: "..skill)
      _skill = skill
    end,
    load=function(_,map,intermission)
      if intermission then
        -- switch to intermission state
      else
        server:load("maps/"..map..".bsp")
      end
    end
  })

  -- bind entities and engine
  for i=1,#level.entities do        
    -- order matters: worldspawn is always first
    local ent = level.entities[i]
    if band(ent.spawnflags or 0,512)==0 then
      local ent = _vm:bind(ent)
      if ent then
        -- valid entity?
        add(_entities, ent)
      end
    end
  end

  -- find player pos
  for _,kv in pairs(level.entities) do
    if kv.classname=="info_player_start" then
      pos=kv.origin
      logging.debug("Found player start")
      break
    end
  end
  pos=pos or {0,0,0}
  _plyr=make_player(pos,0)

  -- todo:
  --[[ 
    _player = {
      ...
    }
    _vm:call("player_init",_player)
  ]]
  _cam = make_cam()
  
  -- if not PROF_CAPTURE then    
  if not _dont_grab_mouse then 
    grab_mouse()
  end
  --end

  -- collectgarbage("stop")
  local sus={
    ["pool.lua"]=true,
    ["renderer.lua"]=true
  }
  function trace (event, line)
    local s = debug.getinfo(2).short_src
    if sus[s] then
      print(s .. ":" .. line)
    end
  end
  
  --debug.sethook(trace, "l")
end

function find_sub_sector(node,pos)
  while node do
    node=node[plane_isfront(node.plane,pos)]
    if node and node.contents then
      -- leaf?
      return node
    end
  end
end

-- find if pos is within an empty space
function node_content(node,pos)
  -- invalid root?
  if not node then
    return -2
  end
  local pos={[0]=pos[1],pos[2],pos[3]}
  while not node.contents do
    node=node[plane_isfront(node.plane,pos)]
    if not node then
      return -2
    end
  end  
  return node.contents
end


-- https://github.com/id-Software/Quake/blob/bf4ac424ce754894ac8f1dae6a3981954bc9852d/WinQuake/world.c
-- hull location
-- https://github.com/id-Software/Quake/blob/bf4ac424ce754894ac8f1dae6a3981954bc9852d/QW/client/pmovetst.c
-- https://developer.valvesoftware.com/wiki/BSP
-- ray/bsp intersection
function ray_bsp_intersect(node,p0,p1,t0,t1,out)
  if not node then
    -- same as -2
    out.start_solid = true
    return 
  end
  local contents=node.contents  
  if contents then
    -- is "solid" space (bsp)
    if contents~=-2 then
      out.all_solid = false
      if contents==-1 then
        out.in_open = true
      else
        out.in_water = true
      end
    else
      out.start_solid = true
    end
    -- empty space
    return true
  end
  local dist,node_dist=plane_dot1(node.plane,p0)
  local otherdist=plane_dot1(node.plane,p1)
  local side,otherside=dist>node_dist,otherdist>node_dist
  if side==otherside then
    -- go down this side
    return ray_bsp_intersect(node[side],p0,p1,t0,t1,out)
  end
  -- crossing a node
  local t=dist-node_dist
  if t<0 then
    t=t-0.001
  else
    t=t+0.001
  end  
  -- cliping fraction
  local frac=mid(t/(dist-otherdist),0,1)
  local pmid=v_lerp(p0,p1,frac)
  local tmid=lerp(t0,t1,frac)
  if not ray_bsp_intersect(node[side],p0,pmid,t0,tmid,out) then
    return
  end

  if node_content(node[not side],pmid)~=-2 then
    return ray_bsp_intersect(node[not side],pmid,p1,tmid,t1,out)
  end

  -- never got out of the solid area
  if out.all_solid then
    return
  end

  local scale=side and 1 or -1
  local nx,ny,nz=plane_get(node.plane)
  out.n={scale*nx,scale*ny,scale*nz,node_dist}
  out.t=tmid
  out.pos = pmid
end

mx,my=0,0
diffx,diffy=0,0
camx,camy=0,0

zoom=1
texture=1
function love.wheelmoved(x, y)
  if y > 0 then
    zoom = 5
  elseif y < 0 then
    zoom = -5
  end
end

function grab_mouse()
  love.mouse.setGrabbed(true)
  love.mouse.setRelativeMode( true )
  love.mouse.setVisible(false)
end

_debug_display = false
function love.keypressed(key)
  if key == "tab" then
    _debug_display = not _debug_display
  elseif key == "escape" then
    love.event.quit(0)
  end
end

function love.mousemoved( x, y, dx, dy, istouch )
  camx = dx*8
  camy = dy*8
end

love.frame = 0
local _profileUpdate
function love.update(dt)
  _profileUpdate = appleCake.profileFunc(nil, _profileUpdate)

  -- any entities to create?
  for i=1,#_new_entities do
    add(_entities, _new_entities[i])
  end
  _new_entities = {}

  -- any thinking to do?
  for i=#_entities,1,-1 do
    local ent = _entities[i]
    -- to be removed?
    if ent.free then
      world:unregister(ent)
      del(_entities, i)
    else
      -- any velocity?
      if ent.velocity then
        -- todo: physics...
        -- print("entity: "..i.." moving: "..v_tostring(ent.origin))
        ent.origin = v_add(ent.origin, ent.velocity, 1/60)
        -- link to world
        world.register(ent)
      end

      if ent.nextthink and ent.nextthink<love.frame/60 and ent.think then
        ent.nextthink = nil
        ent:think()
      end

      -- todo: force origin changes via function
      -- todo: apply angles
      if ent.m then
        -- not a physic entity
        local m=ent.m
        if ent.mangles then
          m=make_m_from_euler(unpack(ent.mangles))
        end
        m_set_pos(m, ent.origin)
        ent.m=m
      end
    end
  end

  _plyr:update()  
  _cam:track(v_add(_plyr.origin,{0,0,22}),_plyr.m,_plyr.angle)

  -- kill mouse
  camx,camy=0,0

  -- kill msg?
  if _msg_ttl<love.frame then
    _msg = nil
    _msg_ttl = -1
  end

  love.frame = love.frame + 1

  _profileUpdate:stop() -- By setting it to love.graphics.getStats we can see details of the draw
end

local _profileDraw
local _ram={}
local _fps={}
function love.draw()
  _profileDraw = appleCake.profileFunc(nil, _profileDraw)
  -- cls
  -- framebuffer.fill(0)

  start_frame(_backbuffer)
	local n=m_x_n(_cam.m,{0,0,-1})
	local n0=m_x_v(_cam.m,{0,0,2048+_cam.origin[3]})
  push_param("sky", n)  
  push_param("sky_distance", v_dot(n,n0))  
  push_param("t", love.frame / 60)
  push_param("z", _cam.origin[3])
  push_viewmatrix(_cam.m)
  
  -- refresh visible set
  local leaves = _cam:collect_leaves(_level.hulls[1],_world_model.leaves)
  -- world entity
  -- local m0=collectgarbage("count")
  _cam:draw_model(_entities[1],_world_model.textures,_world_model.verts,leaves,1,#leaves)
  --print(collectgarbage("count")-m0.."kb")

  local visents = _cam:collect_entities(_entities)

  for i=1,#visents do
    local ent=visents[i]
    local m = ent.model
    -- BSP?
    if m.leaf_start then
      local res = ent.resources
      _cam:draw_model(ent,res.textures,res.verts,res.leaves,m.leaf_start,m.leaf_end)
    else
      _cam:draw_aliasmodel(
        ent, 
        m,
        ent.skin,
        ent.frame)
    end
  end
  
  end_frame()

  -- appleCake.countMemory()
  _profileDraw:stop() -- By setting it to love.graphics.getStats we can see details of the draw

  --
  -- local model = _flame.alias
  -- local skin = model.skins[1]
  -- local mip = skin.mips[1]
  -- for i=0,skin.width-1 do
  --   for j=0,skin.height-1 do
  --     _backbuffer[i + j*480] = _palette[_colormap[mip[i+j*skin.width]]]
  --   end
  -- end

	framebuffer.refresh()
	framebuffer.draw(0,0, scale)

  -- love.graphics.setColor(0,1,0)
  -- for k,n in pairs(_normz) do
  --   love.graphics.line( 2 * n.n0.x, 2 * n.n0.y, 2 * n.n1.x, 2 * n.n1.y)
  -- end
  -- points
  --[[
  love.graphics.setColor(0,1,0)
  local bbox={}
  local mdls=0
  for i=1,#visents do
    local ent=visents[i]
    if ent.m and not ent.m.leaf_start and ent.origin and ent.mins then
      mdls = mdls + 1
      for i=0,7 do
        bbox[i]={     
          band(i,1)>0 and ent.absmaxs[1] or ent.absmins[1],
          band(i,2)>0 and ent.absmaxs[2] or ent.absmins[2],
          band(i,4)>0 and ent.absmaxs[3] or ent.absmins[3]
        }
      end
      for k,v in pairs(bbox) do
        local x,y,w=_cam:project(v)        
        if w>0 then
          if x>=0 and y>=0 and x<480 and y<270 then
            love.graphics.points(2*x, 2*y)
          end
        end
      end
      local x,y,w=_cam:project(ent.origin)      
      if w>0 then
        if x>=0 and y>=0 and x<480 and y<270 then
          love.graphics.circle("line",2*x, 2*y, 8, 8)
        end
      end  
    end
  end
  ]]
  
  --[[
  print("classify:"..tostring(plane_classify_bbox_test({
      type=2,
      normal={[0]=0,0,1},
      dist=8
    },
    {7,7,7},
    {10,10,10})))
    ]]

  -- note: text is written using Love2d api - mush be done after direct buffer draw
  local current_leaf=find_sub_sector(_level.hulls[1],{[0]=_plyr.origin[1],_plyr.origin[2],_plyr.origin[3]})
  
  if _memory_thinktime<love.frame then
    local prev = _memory    
    _memory = collectgarbage("count")
    _memory_min = min(_memory, _memory_min or 0)
    _memory_max = max(_memory, _memory_max or 0)
    _ram[love.frame%480] = _memory
    _mem_per_frame = 0
    if prev then
      _mem_per_frame=(_memory-prev)
    end
    _memory_thinktime = love.frame + 30
  end
  _fps[love.frame%480]=love.timer.getFPS()
  _font.print("RAM:\b"..flr(_memory).."\bkb\nRAM/frame:\b"..flr(_mem_per_frame).."\bkb\nFPS:" .. love.timer.getFPS().."\nleaves:"..#leaves.."\n#ents:"..(#visents).."\ncontent:"..(current_leaf and current_leaf.contents or "n/a").."\nground: "..tostring(_plyr.on_ground), 2, 2 )

  if _debug_display then
    -- draw 2d map
    local map = world.get_map()
    _debug_scale = 2*270/(map.maxs[2]-map.mins[2])
    _debug_x,_debug_y=-map.mins[1],-map.mins[2]
    local player_ent={origin=_plyr.origin,mins={-16,-16,0},maxs={16,16,48}}
    locate_ent(player_ent)
    love.graphics.setColor(0,1,0)
    draw_map(world.get_map())

    -- all entities
    love.graphics.setColor(0.25,0.25,0.25)
    for i=2,#_entities do
      draw_entity(_entities[i])  
    end

    -- "active" entities
    love.graphics.setColor(0.0,0.8,0.1)
    local ents = world.touches(v_add(_plyr.absmins, {-256,-256,-256}),v_add(_plyr.absmaxs, {256,256,256}))
    for i=1,#ents do
      draw_entity(ents[i])  
    end

    love.graphics.setColor(0,1,0)
    draw_entity(player_ent,true)

    -- reset colors
    love.graphics.setColor(1,1,1)
  end

  local m=_cam.m
  local fwd,up={m[2],m[6],m[10]},{m[3],m[7],m[11]}
  local triggers={}
  local p0,p1 = v_add(_cam.origin,up,-8),v_add(_cam.origin,fwd,1024)
  local trace = hitscan({0,0,0},{0,0,0},p0,p1,triggers,_entities)
  if trace and trace.n then
    local pos = v_add(trace.pos,trace.ent.origin)
    local x0,y0,w0=_cam:project(pos)
    local x1,y1,w1=_cam:project(v_add(pos,trace.n,8))
    lg.setColor(0,1,0)
    lg.circle("line",2*x0,2*y0,w0*64)
    lg.line(2*x0,2*y0,2*x1,2*y1)
    lg.setColor(1,1,1)
  end

  -- any on screen message?
  if _msg then
    local w,h = _font.size(_msg)
    _font.print(_msg, 480 - w/2, 270/2 - h/2)
  end
  
  -- collectgarbage()
  --[[
  love.graphics.setColor(1,0,0)
  lg.line(0,270*2-(_memory_max/1024),480,270*2-(_memory_max/1024))
  love.graphics.setColor(0,1,0)
  for i=0,480-1 do
    local mem=_ram[i]
    if mem then
      lg.points(i,270*2-(mem/1024))
    end
  end
  love.graphics.setColor(1,1,0)
  for i=0,480-1 do
    local counter=_fps[i]
    if counter then
      lg.points(i,270*2-counter)
    end
  end
  love.graphics.setColor(1,1,1)
  ]]

end

function love.quit()
  appleCake.endSession()
end

function draw_entity(ent,fill)
  local mins,maxs=v_add(ent.origin,ent.mins),v_add(ent.origin,ent.maxs)
  love.graphics.rectangle(
    fill and "fill" or "line",
    _debug_scale * (mins[1]+_debug_x),
    _debug_scale * (mins[2]+_debug_y),
    _debug_scale * (maxs[1]-mins[1]),
    _debug_scale * (maxs[2]-mins[2]))
end

function draw_map(cell)
  local mins,maxs=cell.mins,cell.maxs
  love.graphics.rectangle(
    "line",
    _debug_scale * (mins[1]+_debug_x),
    _debug_scale * (mins[2]+_debug_y),
    _debug_scale * (maxs[1]-mins[1]),
    _debug_scale * (maxs[2]-mins[2]))

  if cell[true] then
    draw_map(cell[true])
  end
  if cell[false] then
    draw_map(cell[false])
  end
end

function locate_ent(ent)
  local mins,maxs=v_add(ent.origin,ent.mins),v_add(ent.origin,ent.maxs)
  local ents=world.touches(mins,maxs)

  -- draw
  love.graphics.setColor(0.8,0,0)
  for _,e in pairs(ents) do
    draw_entity(e,true)
  end
end

-- camera

function make_cam()
  local profileTransform
  local profileDrawModel,profileDrawAlias,profileCollectLeaves,profileCollectEnts

  -- "vertex buffer" layout:
  -- 0: x (cam)
  -- 1: y (cam)
  -- 2: z (cam)
  -- 3: x
  -- 4: y
  -- 5: w
  -- 6: outcode
  -- 7: u
  -- 8: v
  local VBO_1 = 0
  local VBO_2 = 1
  local VBO_3 = 2
  local VBO_X = 3
  local VBO_Y = 4
  local VBO_W = 5
  local VBO_OUTCODE = 6
  local VBO_U = 7
  local VBO_V = 8
  
  local vbo = require("pool")("v_cache",9,2500)
  -- share with rasterizer
  push_vbo(vbo)

  local up={0,1,0}
  local visleaves,visframe,prev_leaf={},0
  -- pre-computed normals for alias models
  local _normals={
    {-0.525731, 0.000000, 0.850651}, 
    {-0.442863, 0.238856, 0.864188}, 
    {-0.295242, 0.000000, 0.955423}, 
    {-0.309017, 0.500000, 0.809017}, 
    {-0.162460, 0.262866, 0.951056}, 
    {0.000000, 0.000000, 1.000000}, 
    {0.000000, 0.850651, 0.525731}, 
    {-0.147621, 0.716567, 0.681718}, 
    {0.147621, 0.716567, 0.681718}, 
    {0.000000, 0.525731, 0.850651}, 
    {0.309017, 0.500000, 0.809017}, 
    {0.525731, 0.000000, 0.850651}, 
    {0.295242, 0.000000, 0.955423}, 
    {0.442863, 0.238856, 0.864188}, 
    {0.162460, 0.262866, 0.951056}, 
    {-0.681718, 0.147621, 0.716567}, 
    {-0.809017, 0.309017, 0.500000}, 
    {-0.587785, 0.425325, 0.688191}, 
    {-0.850651, 0.525731, 0.000000}, 
    {-0.864188, 0.442863, 0.238856}, 
    {-0.716567, 0.681718, 0.147621}, 
    {-0.688191, 0.587785, 0.425325}, 
    {-0.500000, 0.809017, 0.309017}, 
    {-0.238856, 0.864188, 0.442863}, 
    {-0.425325, 0.688191, 0.587785}, 
    {-0.716567, 0.681718, -0.147621}, 
    {-0.500000, 0.809017, -0.309017}, 
    {-0.525731, 0.850651, 0.000000}, 
    {0.000000, 0.850651, -0.525731}, 
    {-0.238856, 0.864188, -0.442863}, 
    {0.000000, 0.955423, -0.295242}, 
    {-0.262866, 0.951056, -0.162460}, 
    {0.000000, 1.000000, 0.000000}, 
    {0.000000, 0.955423, 0.295242}, 
    {-0.262866, 0.951056, 0.162460}, 
    {0.238856, 0.864188, 0.442863}, 
    {0.262866, 0.951056, 0.162460}, 
    {0.500000, 0.809017, 0.309017}, 
    {0.238856, 0.864188, -0.442863}, 
    {0.262866, 0.951056, -0.162460}, 
    {0.500000, 0.809017, -0.309017}, 
    {0.850651, 0.525731, 0.000000}, 
    {0.716567, 0.681718, 0.147621}, 
    {0.716567, 0.681718, -0.147621}, 
    {0.525731, 0.850651, 0.000000}, 
    {0.425325, 0.688191, 0.587785}, 
    {0.864188, 0.442863, 0.238856}, 
    {0.688191, 0.587785, 0.425325}, 
    {0.809017, 0.309017, 0.500000}, 
    {0.681718, 0.147621, 0.716567}, 
    {0.587785, 0.425325, 0.688191}, 
    {0.955423, 0.295242, 0.000000}, 
    {1.000000, 0.000000, 0.000000}, 
    {0.951056, 0.162460, 0.262866}, 
    {0.850651, -0.525731, 0.000000}, 
    {0.955423, -0.295242, 0.000000}, 
    {0.864188, -0.442863, 0.238856}, 
    {0.951056, -0.162460, 0.262866}, 
    {0.809017, -0.309017, 0.500000}, 
    {0.681718, -0.147621, 0.716567}, 
    {0.850651, 0.000000, 0.525731}, 
    {0.864188, 0.442863, -0.238856}, 
    {0.809017, 0.309017, -0.500000}, 
    {0.951056, 0.162460, -0.262866}, 
    {0.525731, 0.000000, -0.850651}, 
    {0.681718, 0.147621, -0.716567}, 
    {0.681718, -0.147621, -0.716567}, 
    {0.850651, 0.000000, -0.525731}, 
    {0.809017, -0.309017, -0.500000}, 
    {0.864188, -0.442863, -0.238856}, 
    {0.951056, -0.162460, -0.262866}, 
    {0.147621, 0.716567, -0.681718}, 
    {0.309017, 0.500000, -0.809017}, 
    {0.425325, 0.688191, -0.587785}, 
    {0.442863, 0.238856, -0.864188}, 
    {0.587785, 0.425325, -0.688191}, 
    {0.688191, 0.587785, -0.425325}, 
    {-0.147621, 0.716567, -0.681718}, 
    {-0.309017, 0.500000, -0.809017}, 
    {0.000000, 0.525731, -0.850651}, 
    {-0.525731, 0.000000, -0.850651}, 
    {-0.442863, 0.238856, -0.864188}, 
    {-0.295242, 0.000000, -0.955423}, 
    {-0.162460, 0.262866, -0.951056}, 
    {0.000000, 0.000000, -1.000000}, 
    {0.295242, 0.000000, -0.955423}, 
    {0.162460, 0.262866, -0.951056}, 
    {-0.442863, -0.238856, -0.864188}, 
    {-0.309017, -0.500000, -0.809017}, 
    {-0.162460, -0.262866, -0.951056}, 
    {0.000000, -0.850651, -0.525731}, 
    {-0.147621, -0.716567, -0.681718}, 
    {0.147621, -0.716567, -0.681718}, 
    {0.000000, -0.525731, -0.850651}, 
    {0.309017, -0.500000, -0.809017}, 
    {0.442863, -0.238856, -0.864188}, 
    {0.162460, -0.262866, -0.951056}, 
    {0.238856, -0.864188, -0.442863}, 
    {0.500000, -0.809017, -0.309017}, 
    {0.425325, -0.688191, -0.587785}, 
    {0.716567, -0.681718, -0.147621}, 
    {0.688191, -0.587785, -0.425325}, 
    {0.587785, -0.425325, -0.688191}, 
    {0.000000, -0.955423, -0.295242}, 
    {0.000000, -1.000000, 0.000000}, 
    {0.262866, -0.951056, -0.162460}, 
    {0.000000, -0.850651, 0.525731}, 
    {0.000000, -0.955423, 0.295242}, 
    {0.238856, -0.864188, 0.442863}, 
    {0.262866, -0.951056, 0.162460}, 
    {0.500000, -0.809017, 0.309017}, 
    {0.716567, -0.681718, 0.147621}, 
    {0.525731, -0.850651, 0.000000}, 
    {-0.238856, -0.864188, -0.442863}, 
    {-0.500000, -0.809017, -0.309017}, 
    {-0.262866, -0.951056, -0.162460}, 
    {-0.850651, -0.525731, 0.000000}, 
    {-0.716567, -0.681718, -0.147621}, 
    {-0.716567, -0.681718, 0.147621}, 
    {-0.525731, -0.850651, 0.000000}, 
    {-0.500000, -0.809017, 0.309017}, 
    {-0.238856, -0.864188, 0.442863}, 
    {-0.262866, -0.951056, 0.162460}, 
    {-0.864188, -0.442863, 0.238856}, 
    {-0.809017, -0.309017, 0.500000}, 
    {-0.688191, -0.587785, 0.425325}, 
    {-0.681718, -0.147621, 0.716567}, 
    {-0.442863, -0.238856, 0.864188}, 
    {-0.587785, -0.425325, 0.688191}, 
    {-0.309017, -0.500000, 0.809017}, 
    {-0.147621, -0.716567, 0.681718}, 
    {-0.425325, -0.688191, 0.587785}, 
    {-0.162460, -0.262866, 0.951056}, 
    {0.442863, -0.238856, 0.864188}, 
    {0.162460, -0.262866, 0.951056}, 
    {0.309017, -0.500000, 0.809017}, 
    {0.147621, -0.716567, 0.681718}, 
    {0.000000, -0.525731, 0.850651}, 
    {0.425325, -0.688191, 0.587785}, 
    {0.587785, -0.425325, 0.688191}, 
    {0.688191, -0.587785, 0.425325}, 
    {-0.955423, 0.295242, 0.000000}, 
    {-0.951056, 0.162460, 0.262866}, 
    {-1.000000, 0.000000, 0.000000}, 
    {-0.850651, 0.000000, 0.525731}, 
    {-0.955423, -0.295242, 0.000000}, 
    {-0.951056, -0.162460, 0.262866}, 
    {-0.864188, 0.442863, -0.238856}, 
    {-0.951056, 0.162460, -0.262866}, 
    {-0.809017, 0.309017, -0.500000}, 
    {-0.864188, -0.442863, -0.238856}, 
    {-0.951056, -0.162460, -0.262866}, 
    {-0.809017, -0.309017, -0.500000}, 
    {-0.681718, 0.147621, -0.716567}, 
    {-0.681718, -0.147621, -0.716567}, 
    {-0.850651, 0.000000, -0.525731}, 
    {-0.688191, 0.587785, -0.425325}, 
    {-0.587785, 0.425325, -0.688191}, 
    {-0.425325, 0.688191, -0.587785}, 
    {-0.425325, -0.688191, -0.587785}, 
    {-0.587785, -0.425325, -0.688191}, 
    {-0.688191, -0.587785, -0.425325}, 	
    }

  local function z_poly_clip(v,nv)
    local res,v0={},v[nv]
    local d0=vbo[v0 + VBO_3] - 8
    for i=1,nv do
      local side=d0>0
      if side then
        res[#res+1]=v0
      end
      local v1=v[i]
      local d1=vbo[v1 + VBO_3]-8
      -- not same sign?
      if (d1>0)~=side then
        local t = d0/(d0-d1)
        local x,y,z=
          lerp(vbo[v0+VBO_1],vbo[v1+VBO_1],t),
          lerp(vbo[v0+VBO_2],vbo[v1+VBO_2],t),
          lerp(vbo[v0+VBO_3],vbo[v1+VBO_3],t)
        res[#res+1]=vbo:pop(          
          x,y,z,
          hw+(270*x/8),
          hh-(270*y/8),
          1/8,
          0,
          lerp(vbo[v0+VBO_U],vbo[v1+VBO_U],t),
          lerp(vbo[v0+VBO_V],vbo[v1+VBO_V],t))
      end
      v0=v1
      d0=d1
    end
    return res,#res
  end

  -- collect bps leaves in order
  local collect_bsp
  local function collect_leaf(child,pos)
    if child and child.visframe==visframe then
      if child.contents then          
        visleaves[#visleaves+1]=child
      else
        collect_bsp(child,pos)
      end
    end
  end    
  collect_bsp=function(node,pos)
    local side=plane_isfront(node.plane,pos)
    collect_leaf(node[side],pos)
    collect_leaf(node[not side],pos)
  end

  local v_cache={
    cache={},
    init=function(self,m,base)
        self.m = m
        self.base=base or 1
        local cache=self.cache
        for k in pairs(cache) do
          cache[k]=nil
        end
        vbo:reset()
    end,
    transform=function(self,v)
      -- find vbo (if any)
      local idx=self.cache[v]
      if not idx then
        local base=self.base
        local m,code,x,y,z=self.m,0,v[base+0],v[base+1],v[base+2]
        local ax,az,ay=m[1]*x+m[5]*y+m[9]*z+m[13],m[2]*x+m[6]*y+m[10]*z+m[14],m[3]*x+m[7]*y+m[11]*z+m[15]

        -- znear=8
        if az<8 then code=2 end
        --if az>2048 then code|=1 end
        if ax>az then code = code + 4
        elseif ax<-az then code = code + 8 end
        if ay>az then code = code + 16
        elseif ay<-az then code = code + 32 end
        -- save world space coords for clipping
        -- to screen space
        local w=1/az
        idx=vbo:pop(ax,ay,az,480/2+270*ax*w,270/2-270*ay*w,w,code)
        self.cache[v]=idx
      end
      return idx
    end
  }

	return {
		pos={0,0,0},    
		track=function(self,pos,m)
      --pos=v_add(v_add(pos,m_fwd(m),-24),m_up(m),24)	      
      local m={unpack(m)}		
      -- inverse view matrix
      m[2],m[5]=m[5],m[2]
			m[3],m[9]=m[9],m[3]
      m[7],m[10]=m[10],m[7]
      --
      self.m=m_x_m(m,{
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        -pos[1],-pos[2],-pos[3],1
      })
      self.origin=pos
    end,
    project=function(self,pos)
      pos=m_x_v(self.m,pos)
      local w=1/pos[2]
      return 480/2+270*pos[1]*w,270/2-270*pos[3]*w,w
    end,
    -- returns true if bounding box (mins,maxs) is visible
    is_visible=function(self,mins,maxs)
      local m,outcode=self.m,0xffff
      local m1,m5,m9,m13,m2,m6,m10,m14,m3,m7,m11,m15=m[1],m[5],m[9],m[13],m[2],m[6],m[10],m[14],m[3],m[7],m[11],m[15]
      for i=0,7 do
        local x,y,z=     
          band(i,1)~=0 and maxs[1] or mins[1],
          band(i,2)~=0 and maxs[2] or mins[2],
          band(i,4)~=0 and maxs[3] or mins[3]    
        local code = 0
        local ax,az,ay=m1*x+m5*y+m9*z+m13,m2*x+m6*y+m10*z+m14,m3*x+m7*y+m11*z+m15
    
        -- znear=8
        if az<8 then code=2 end
        --if az>2048 then code|=1 end
        if ax>az then code = code + 4
        elseif ax<-az then code = code + 8 end
        if ay>az then code = code + 16
        elseif ay<-az then code = code + 32 end
        outcode = band(outcode, code)
        if outcode == 0 then
          return true
        end
      end
    end,
    collect_entities=function(self,entities)
      local ents={}
      for i=2,#entities do
        local ent = entities[i]
        if not ent.DRAW_NOT and ent.nodes then
          -- find if touching a visible leaf?
          for node,_ in pairs(ent.nodes) do
            if node.visframe==visframe then              
              add(ents,ent)
              -- break at first visible node
              break
            end
          end
        end
      end
      return ents
    end,
    collect_leaves=function(self,root,leaves)
      profileCollectLeaves = appleCake.profileFunc(nil, profileCollectLeaves)

      local pos={[0]=self.origin[1],self.origin[2],self.origin[3]}
      local current_leaf=find_sub_sector(root,pos)
      
      if not current_leaf or not current_leaf.pvs then
        -- debug
        profileCollectLeaves:stop()
        return leaves
      end

      -- changed sector?
      if current_leaf and current_leaf~=prev_leaf then
        prev_leaf = current_leaf
        visframe = visframe + 1
        -- find all (potentially) visible leaves
        for i,bits in pairs(current_leaf.pvs) do
          i=shl(i,5)
          for j=0,31 do
            -- visible?
            if band(bits,shl(0x1,j))~=0 then
              local leaf=leaves[bor(i,j)+2]
              -- tag visible parents (if not already tagged)
              -- check bounding box
              while leaf and leaf.visframe~=visframe do
                leaf.visframe=visframe
                leaf=leaf.parent
              end
            end
          end
        end
      end
      visleaves={}
      collect_bsp(root,pos)

      profileCollectLeaves:stop()
      return visleaves
    end,  
    draw_model=function(self,ent,textures,verts,leaves,lstart,lend)
      if not self:is_visible(ent.absmins,ent.absmaxs) then
        return 
      end

      profileDrawModel = appleCake.profileFunc(nil, profileDrawModel)
      local m=self.m
      --local pts,cam_u,cam_v,v_cache,f_cache,cam_pos={},{m[1],m[5],m[9]},{m[2],m[6],m[10]},setmetatable({m=m_x_m(m,model.m)},v_cache_class),{},v_add(self.pos,model.origin,-1)
      v_cache:init(m_x_m(m,ent.m),0)

      local cam_pos=v_add(self.origin,ent.origin,-1)
      cam_pos={[0]=cam_pos[1],cam_pos[2],cam_pos[3]}
      local poly,f_cache,styles,bright_style={},{},{0,0,0,0},{0.5,0.5,0.5,0.5}
      for i=lstart,lend do
        for j,face in ipairs(leaves[i]) do
          if not f_cache[face] and plane_dot(face.plane,cam_pos)>face.cp~=face.side then
            profileTransform = appleCake.profileFunc(nil, profileTransform)
            -- mark visited
            f_cache[face]=true
            local texinfo,outcode,clipcode=face.texinfo,0xffff,0            
            local maxw,s,s_offset,t,t_offset=-32000,texinfo.s,texinfo.s_offset,texinfo.t,texinfo.t_offset
            for k,vi in ipairs(face.verts) do
              local v=verts[vi]
              local a=v_cache:transform(v)
              local code = vbo[a+VBO_OUTCODE]
              outcode=band(outcode,code)
              clipcode=clipcode + band(code,2)
              -- compute uvs
              local x,y,z=v[0],v[1],v[2]
              vbo[a+VBO_U] = x*s[0]+y*s[1]+z*s[2]+s_offset
              vbo[a+VBO_V] = x*t[0]+y*t[1]+z*t[2]+t_offset
              local w = vbo[a+VBO_W]
              if w>maxw then
                maxw = w
              end
              poly[k] = a
            end
            profileTransform:stop()

            if outcode==0 then
              local n=#face.verts
              if clipcode>0 then
                poly,n = z_poly_clip(poly,n,true)
              end
              if n>2 then
                local texture = textures[texinfo.miptex]                
                -- animated?
                if texture.sequence then
                  -- texture animation id are between 0-9 (lua counts between 0-8)
                  local frames = ent.sequence==2 and texture.sequence.alt or texture.sequence.main
                  local frame = flr(love.frame/15) % (#frames+1)
                  texture = frames[frame]
                end
                local mip=3-mid(flr(2048*maxw),0,3)
                push_texture(texture,mip)
                if texture.bright then
                  push_baselight(bright_style)
                else
                  styles[1]=0
                  styles[2]=0
                  styles[3]=0
                  styles[4]=0
                  for i,style in pairs(face.lightstyles) do
                    local lightstyle=_light_styles[style]  
                    if lightstyle then
                      local frame = flr(love.frame/15) % #lightstyle
                      --print("light style @"..lightstyle.."["..frame.."]")
                      styles[i] = lightstyle[frame + 1]
                    end
                  end
                  push_baselight(styles)
                end
                if face.lightofs then
                    push_lightmap(face.lightofs, face.width, face.height, face.umin, face.vmin)
                end 
                polytex(poly,n,texture.sky)    
                push_lightmap()     
              end
            end
          end
        end
      end
      profileDrawModel:stop()
    end,
    draw_aliasmodel=function(self,ent,model,skin,frame_name)      
      -- check bounding box
      if not self:is_visible(ent.absmins,ent.absmaxs) then
        return
      end

      profileDrawAlias = appleCake.profileFunc(nil, profileDrawAlias)

      local skin = model.skins[skin]
      local frame = model.frames[frame_name]
      local uvs = model.uvs
      local faces = model.faces
      -- positions + normals are in the frame
      local verts, normals = frame.verts, frame.normals
      
      v_cache:init(m_x_m(self.m,ent.m))
      local origin=ent.origin
      if ent.offset then
        -- visual offset?
        origin = v_add(origin,ent.offset)
      end
      local cam_pos=v_add(self.origin,origin,-1)

      -- transform light vector into model space
      local light_n=m_inv_x_n(ent.m,{0,0.707,-0.707})
      local poly,baselight={},{1}

      -- todo: gouraud
      push_baselight(baselight)
      push_texture(skin,0)      

      for i=1,#faces,4 do    
        profileTransform = appleCake.profileFunc(nil, profileTransform)
        -- vertex index are "constants" (eg. from model)
        local is_front=faces[i]
        local outcode,clipcode=0xffff,0
        -- read vertex references
        for k=1,3 do
          local vi=faces[i+k]
          local a=v_cache:transform(verts[vi])
          local code = vbo[a+VBO_OUTCODE]
          outcode=band(outcode,code)
          clipcode=clipcode + band(code,2)
          -- compute uvs
          local uv,u_offset = uvs[vi],0
          if not is_front and uv.onseam then
            u_offset = skin.width / 2
          end
          vbo[a + VBO_U] = uv.u + u_offset
          vbo[a + VBO_V] = uv.v     
          --[[
          local light_dot = v_dot(light_n,_normals[normals[vi] ]) 
          a.l = light_dot<0 and (1+light_dot) or 1
          ]]
          poly[k] = a
        end
        profileTransform:stop()

        if outcode==0 then
          -- ccw?
          local base=poly[2]
          local ax,ay=vbo[base + VBO_X]-vbo[poly[1] + VBO_X],vbo[base + VBO_Y]-vbo[poly[1] + VBO_Y]
          local bx,by=vbo[base + VBO_X]-vbo[poly[3] + VBO_X],vbo[base + VBO_Y]-vbo[poly[3] + VBO_Y]
          if ax*by - ay*bx<=0 then
            local n=3
            if clipcode>0 then
              poly,n = z_poly_clip(poly,n)
            end
            if n>2 then
              polytex(poly,n)    
            end
          end
        end
      end
      profileDrawAlias:stop()
    end  
  }
end

-- returns first hit along a ray
-- note: world is an entity like any other (sort of!)
function hitscan(mins,maxs,p0,p1,triggers,ents)
  local size=make_v(mins,maxs)
  local radius=max(size[1],size[2])
  local hull_type = 1
  if radius>=64 then
    hull_type = 3
  elseif radius>=32 then
    hull_type = 2
  end

  -- collect triggers
  local hits
  for k=1,#ents do
    local other_ent = ents[k]
    -- skip "hollow" entities
    if not (other_ent.SOLID_NOT or triggers[other_ent]) then
      -- convert into model's space (mostly zero except moving brushes)
      local model,hull=other_ent.model
      if not model or not model.hulls then
        -- use local aabb - hit is computed in ent space
        hull = modelfs.make_hull(make_v(maxs,other_ent.mins),make_v(mins,other_ent.maxs))
      else
        hull = model.hulls[hull_type]
      end
      
      local tmphits={
        t=1,
        all_solid=true,
        ent=other_ent
      } 
      -- rebase ray in entity origin
      ray_bsp_intersect(hull,make_v( other_ent.origin,p0),make_v( other_ent.origin,p1),0,1,tmphits)
      -- "invalid" location
      if tmphits.start_solid or tmphits.all_solid then
        if not other_ent.SOLID_TRIGGER then
          return tmphits
        end
        -- damage or other actions
        triggers[other_ent] = true
      end

      if tmphits.n then
        -- closest hit?
        -- print(other_ent.classname.." @ "..tmphits.t)
        if other_ent.SOLID_TRIGGER then
          -- damage or other actions
          triggers[other_ent] = true
        elseif tmphits.t<(hits and hits.t or 32000) then
          hits = tmphits
        end
      end
    end
  end  
  return hits
end

function try_move(ent,origin,velocity)
  local vel2d = {velocity[1],velocity[2],0}
  local vl = v_len(vel2d)
  local vl0 = vl
  local next_pos=v_add(origin,velocity)
  local on_ground,blocked = false,false
  local invalid=false

  -- avoid touching the same non-solid multiple times (ex: triggers)
  local touched = {}
  -- collect all potential touching entities (done only once)
  -- todo: smaller box
  local ents=world.touches(v_add(ent.absmins,{-256,-256,-256}), v_add(ent.absmaxs,{256,256,256}))
  add(ents,1,_entities[1])  
  -- check current to target pos
  for i=1,4 do
    local hits = hitscan(ent.mins,ent.maxs,origin,next_pos,touched,ents)
    if not hits then
      goto clear
    end
    if hits.n then            
      local fix=v_dot(hits.n,velocity)
      -- not separating?
      if fix<0 then  
        vl = vl + v_dot(vel2d,hits.n)
        local old_vel = v_clone(velocity)
        velocity=v_add(velocity,hits.n,-fix)
        -- print("fix pos:"..fix.." before: "..v_tostring(old_vel).." after: "..v_tostring(velocity))      
        -- floor?
        if hits.n[3]>0.7 then
          on_ground=true
        end
        -- wall hit?
        if not hits.ent.SOLID_SLIDEBOX and hits.n[3]==0 then
          blocked=true
        end
      end
      next_pos=v_add(origin,velocity)
    end
  end
::blocked::
  invalid = true
  velocity={0,0,0}
::clear::

  return {
    pos=v_add(origin,velocity),
    velocity=velocity,
    on_ground=on_ground,
    on_wall=blocked,
    fraction=max(0,vl/vl0),
    touched=touched,
    invalid=invalid}
end


function make_player(pos,a)
  local angle,dangle,velocity={0,0,a},{0,0,0},{0,0,0}
  local fire_ttl=0
  local on_ground=false
  local mins={-16,-16,0}
  local maxs={16,16,48}

  -- start above floor
  pos=v_add(pos,{0,0,1})
  return {
    classname="player",
    origin=pos,
    mins=mins,    
    maxs=maxs,
    nodes={},
    SOLID_NOT = true,
    absmins=v_add(pos,mins),
    absmaxs=v_add(pos,maxs),  
    m=make_m_from_euler(unpack(angle)),
    update=function(self)
      -- damping      
      angle[2]=angle[2]*0.8
      dangle = v_scale(dangle,0.6)
      
      velocity[1]=velocity[1]*0.7
      velocity[2]=velocity[2]*0.7
      velocity[3]=velocity[3]*0.9

      -- move
      local keys={
        ["z"]={0,1,0},
        ["s"]={0,-1,0},
        ["q"]={1,0,0},
        ["d"]={-1,0,0},
        ["space"]={0,0,12}
      }

      local acc={0,0,0}
      for k,move in pairs(keys) do
        if love.keyboard.isDown(k) then
          acc=v_add(acc, move)
        end
      end

      dangle=v_add(dangle,{camy,acc[1]*2,camx})
      angle=v_add(angle,dangle,1/24)
    
      local a,dx,dz=angle[3],acc[2],acc[1]
      local c,s=cos(2*3.1415*a/360),sin(2*3.1415*a/360)
      velocity=v_add(velocity,{s*dx-c*dz,c*dx+s*dz,(on_ground and acc[3] or 0)-0.5})
            
      -- check next position
      local vn,vl=v_normz(velocity)      
      if vl>0.1 then
        local move = try_move(self,self.origin,velocity)   
        on_ground=move.on_ground
        if on_ground and move.on_wall and move.fraction<1 then
          local up_move = try_move(self,v_add(self.origin,{0,0,18}),velocity) 
          -- largest distance?
          if not up_move.invalid and up_move.fraction>move.fraction then
            move = up_move
            -- slight nudge up
            move.velocity[3] = move.velocity[3] + 3
            -- "mini" jump
            on_ground=false
          end
        end
        self.origin = move.pos
        velocity = move.velocity

        -- trigger touched items
        for other_ent in pairs(move.touched) do
          if other_ent.touch then
            other_ent.touch(self)
          end
        end       
        
      else
        velocity = {0,0,0}
      end

      -- "debug"
      self.on_ground = on_ground

      self.m=m_x_m(
          m_x_m(
            make_m_from_euler(0,0,angle[3]),
            make_m_from_euler(angle[1],0,0)),
            make_m_from_euler(0,angle[2],0))
      self.absmins=v_add(self.origin,self.mins)
      self.absmaxs=v_add(self.origin,self.maxs)
    end
  } 
end