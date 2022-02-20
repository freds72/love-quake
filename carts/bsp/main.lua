local ffi=require 'ffi'
local nfs = require( "nativefs" )
local model = require( "model" )
-- local lick = require "lick"
-- lick.reset = true -- reload the love.load everytime you save
local fb = require 'fblove_strip'
local poly = require( "poly" )
local math3d = require( "math3d")

ffi.cdef[[
    #pragma pack(1)
    typedef struct { unsigned char r,g,b; } color_t;
]]    

-- pico8 compat helpers
local add=table.insert
local flr=math.floor
local min,max=math.min,math.max
local band,bor,shl,shr,bnot=bit.band,bit.bor,bit.lshift,bit.rshift,bit.bnot
local sin,cos=math.sin,math.cos
local scale=2

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

love.window.setMode(480 * scale, 270 * scale, {resizable=false, vsync=true, minwidth=480, minheight=270})

function love.load(args)
  framebuffer = fb(480, 270)
  _backbuffer = framebuffer.buf[0]

  hw = 480/2
  hh = 270/2

  local root_path = args[1]
  print("INFO - game root: "..root_path)

  -- set default palette
  _palette = read_palette(root_path)
  _colormap = read_colormap(root_path)

  models,entities = load_bsp(root_path, args[2])

  -- find player pos
  for _,kv in pairs(entities) do
    for k,v in pairs(kv) do
      if k=="classname" and v=="info_player_start" then
        print("INFO - player start: "..kv["origin"])
        pos=split(kv["origin"]," ")
        -- conver to numbers
        for k,v in pairs(pos) do
          pos[k]=tonumber(v)          
        end
        break
      end
    end
    if pos then break end
  end
  pos=pos or {0,0,0}
  _cam = make_cam(models.textures)

  grab_mouse()
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
function is_empty(node,pos)
  while node.contents==nil or node.contents>0 do
    node=node[plane_isfront(node.plane,pos)]
  end  
  --return node.contents!=-1
  return node.contents~=-2 or node.contents~=-1
end

-- https://github.com/id-Software/Quake/blob/bf4ac424ce754894ac8f1dae6a3981954bc9852d/WinQuake/world.c
-- hull location
-- https://github.com/id-Software/Quake/blob/bf4ac424ce754894ac8f1dae6a3981954bc9852d/QW/client/pmovetst.c
-- https://developer.valvesoftware.com/wiki/BSP
-- ray/bsp intersection
function hitscan(node,p0,p1,out)
  -- is "solid" space (bsp)
  if not node then
    return true
  end
  local contents=node.contents
  if contents then
    -- is "solid" space (bsp)
    if contents==-2 then
      return true
    end
    -- in "empty" space
    if contents<0 then
      return
    end
  end

  local dist,node_dist=plane_dot(node.plane,p0)
  local otherdist=plane_dot(node.plane,p1)
  local side,otherside=dist>node_dist,otherdist>node_dist
  if side==otherside then
    -- go down this side
    return hitscan(node[side],p0,p1,out)
  end
  -- crossing a node
  local t=dist-node_dist
  if t<0 then
    t=t-0x0.01
  else
    t=t+0x0.01
  end  
  -- cliping fraction
  local frac=mid(t/(dist-otherdist),0,1)
  local p10=v_lerp(p0,p1,frac)
  --add(out,p10)
  local hit,otherhit=hitscan(node[side],p0,p10,out),hitscan(node[otherside],p10,p1,out)  
  if hit~=otherhit then
    -- not already registered?
    if not out.n then
      -- check if in global empty space
      -- note: nodes do not have spatial relationships!!
      if is_empty(_model.clipnodes,p10) then
        local scale=t<0 and -1 or 1
        local nx,ny,nz=plane_get(node.plane)
        out.n={scale*nx,scale*ny,scale*nz,node_dist}
        out.t=frac
      end
    end
  end
  return hit or otherhit
end

mx,my=0,0
diffx,diffy=0,0
camx,camy=0,0

zoom=1
texture=1
function love.wheelmoved(x, y)
  if y > 0 then
    zoom = zoom + 5
  elseif y < 0 then
    zoom = zoom - 5
  end
end

function grab_mouse()
    local state = not love.mouse.isGrabbed()   -- the opposite of whatever it currently is
    love.mouse.setGrabbed(state)
    local state = not love.mouse.isVisible()   -- the opposite of whatever it currently is
    love.mouse.setVisible(state)     
end

function love.keypressed(key)
  if key == "tab" then
    grab_mouse()
  end
end

function love.update(dt)
  if love.mouse.isGrabbed() then
      local mx, my = love.mouse.getPosition()
      camx = mx - 480/2
      camy = my - 270/2
      --diffx, diffy = mx,my
  end

  local keys={
    ["z"]={0,1,0},
    ["s"]={0,-1,0},
    ["q"]={1,0,0},
    ["d"]={-1,0,0}
  }
  local acc={0,0,0}
  for k,move in pairs(keys) do
    if love.keyboard.isDown(k) then
      acc=v_add(acc, move)
    end
  end

  v_scale(dangle,0.02)
  v_scale(velocity,0.3)

  dangle=v_add(dangle,{camy,0,camx})
  angle=v_add(angle,dangle,1/4096)

  local a,dx,dz=angle[3],acc[2],acc[1]
  local c,s=cos(a),sin(a)
  velocity=v_add(velocity,{s*dx-c*dz,c*dx+s*dz,0},2)          
  pos=v_add(pos,velocity)
  pos[3]=zoom

  _cam:track(
    v_add(pos,{0,0,64}), 
    m_x_m(
      make_m_from_euler(0,0,angle[3]),
      make_m_from_euler(angle[1],0,0)))
end

local visframe,prev_leaf=0
function love.draw()
  -- cls
  framebuffer.fill(0)

  -- refresh visible set
  local leaves = _cam:collect_leaves(models[1].bsp,models.leaves)
  _cam:draw_model(models[1],models.verts,leaves,1,#leaves)

  --[[
  for i=2,#models do
    local m=models[i]
    _cam:draw_model(m,models.verts,models.leaves,m.leaf_start,m.leaf_end)
  end
  ]]
  
  clear_spans()

	framebuffer.refresh()
	framebuffer.draw(0,0, scale)

  love.graphics.print("FPS: " .. love.timer.getFPS(), 1, 1 )

    --[[
  love.graphics.setColor( 1,1,1)
  love.graphics.draw(models.raw.textures[texture].imgs[1], 0 ,0,0,4,4)
  ]]

end

-- camera
function make_cam(textures)
  local up={0,1,0}
  local visleaves,visframe,prev_leaf={},0

  local function z_poly_clip(v,nv,uvs)
    local res,v0={},v[nv]
    local d0=v0[3]-8
    for i=1,nv do
      local side=d0>0
      if side then
        res[#res+1]=v0
      end
      local v1=v[i]
      local d1=v1[3]-8
      -- not same sign?
      if (d1>0)~=side then
        local nv=v_lerp(v0,v1,d0/(d0-d1),uvs)
        -- project against near plane
        nv.x=hw+(nv[1]*33.75)
        nv.y=hh-(nv[2]*33.75)
        nv.w=33.75
        res[#res+1]=nv
      end
      v0=v1
      d0=d1
    end
    return res,#res
  end

  -- collect bps leaves in order
  local function collect_bsp(node,pos)
    local function collect_leaf(side)
      local child=node[side]
      if child and child.visframe==visframe then
        if child.contents then          
          visleaves[#visleaves+1]=child
        else
          collect_bsp(child,pos)
        end
      end
    end  
    local side=plane_isfront(node.plane,pos)
    collect_leaf(side)
    collect_leaf(not side)
  end

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
      self.pos=pos
    end,
    collect_leaves=function(self,root,leaves)
      local pos={[0]=self.pos[1],self.pos[2],self.pos[3]}
      local current_leaf=find_sub_sector(root,pos)
      
      if not current_leaf then
        -- debug
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
      return visleaves
    end,  
    draw_model=function(self,model,verts,leaves,lstart,lend)
      local v_cache_class={
        __index=function(self,v)
          local m,code,x,y,z=self.m,0,v[0],v[1],v[2]
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
          local w=270/az
          local a={ax,ay,az,x=480/2+ax*w,y=270/2-ay*w,w=w,outcode=code}
          self[v]=a          
          return a
        end
      }

      local m=self.m
      --local pts,cam_u,cam_v,v_cache,f_cache,cam_pos={},{m[1],m[5],m[9]},{m[2],m[6],m[10]},setmetatable({m=m_x_m(m,model.m)},v_cache_class),{},v_add(self.pos,model.origin,-1)
      local v_cache=setmetatable({m=m_x_m(m,model.m)},v_cache_class)
      local cam_pos={[0]=self.pos[1],self.pos[2],self.pos[3]}
      local f_cache={}

      for i=lstart,lend do
        local leaf=leaves[i]
        for j,face in ipairs(leaf) do
          if not f_cache[face] and plane_dot(face.plane,cam_pos)>face.cp~=face.side then
            f_cache[face]=true
            local outcode,clipcode,poly,uvs=0xffff,0,{},{}
            local texinfo = face.texinfo
            local s,s_offset,t,t_offset=texinfo.s,texinfo.s_offset,texinfo.t,texinfo.t_offset
            for k,vi in pairs(face.verts) do
              local v=models.verts[vi]
              local a=v_cache[v]
              outcode=band(outcode,a.outcode)
              clipcode=clipcode + band(a.outcode,2)
              -- compute uvs
              a.u=v[0]*s[0]+v[1]*s[1]+v[2]*s[2]+s_offset
              a.v=v[0]*t[0]+v[1]*t[1]+v[2]*t[2]+t_offset
              poly[k] = a
            end
            if outcode==0 then
              if clipcode>0 then
                poly = z_poly_clip(poly,#poly,true)
              end
              if #poly>2 then
                local texture = textures[texinfo.miptex]
                if texture then
                  push_baselight(face.baselight)
                  push_texture(texture.mips[1],texture.width,texture.height)
                  if face.lightofs then
                    push_lightmap(face.lightofs, face.width, face.height, face.umin, face.vmin)
                  end
                  polytex(poly,#poly)    
                  push_lightmap()     
                else
                  polyfill(poly,#poly,0)
                end
              end
            end
          end
        end
      end    
    end  
  }
end