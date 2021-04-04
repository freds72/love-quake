pico-8 cartridge // http://www.pico-8.com
version 31
__lua__
-- quake engine
-- by @freds72
#include poly.lua
#include plain.lua

-- game globals
local _particles,_cam,_plyr,_model={}

--[[
local fadetable={
 {0,0,0,0,129,129,129,129,129,129,129,1,131,131,131},
 {129,129,129,129,129,1,1,1,1,1,131,131,131,131,131},
 {140,140,140,140,140,140,140,131,131,131,131,131,131,131,131},
 {12,12,12,12,12,140,140,140,140,140,140,131,131,131,131},
 {133,133,133,133,133,133,133,1,1,131,131,131,131,131,131},
 {5,5,5,5,5,5,5,5,131,131,131,131,131,131,131},
 {134,134,134,134,13,5,5,5,5,5,5,131,131,131,131},
 {7,7,6,6,6,6,6,13,13,13,13,5,5,131,131},
 {136,136,2,2,2,2,2,2,141,133,133,133,131,131,131},
 {8,8,136,136,136,136,2,2,2,2,5,133,133,131,131},
 {9,9,9,9,4,4,4,4,5,5,5,5,5,131,131},
 {10,10,138,138,138,138,138,134,134,5,5,5,5,131,131},
 {138,138,138,138,138,138,5,5,5,5,5,5,131,131,131},
 {3,3,3,3,3,3,3,3,131,131,131,131,131,131,131},
 {4,4,4,4,5,5,5,5,5,5,5,5,131,131,131},
 {14,14,14,134,134,134,13,13,141,141,5,5,5,131,131}
}
]]

local _palette={[0]=0,[5]=134,[13]=133}
local _content_types={{contents=-1},{contents=-2}}

-- bsp drawing helpers
local _vis_mask=split("0x0000.0002,0x0000.0004,0x0000.0008,0x0000.0010,0x0000.0020,0x0000.0040,0x0000.0080,0x0000.0100,0x0000.0200,0x0000.0400,0x0000.0800,0x0000.1000,0x0000.2000,0x0000.4000,0x0000.8000,0x0001.0000,0x0002.0000,0x0004.0000,0x0008.0000,0x0010.0000,0x0020.0000,0x0040.0000,0x0080.0000,0x0100.0000,0x0200.0000,0x0400.0000,0x0800.0000,0x1000.0000,0x2000.0000,0x4000.0000,0x8000.0000",",",1)
_vis_mask[0]=0x0000.0001

-- portal masks
local _portaloutline,_portaloutline_mask={},{}
-- maths & cam
function lerp(a,b,t)
	return a*(1-t)+b*t
end

function make_v(a,b)
	return {
		b[1]-a[1],
		b[2]-a[2],
		b[3]-a[3]}
end
function v_clone(v)
	return {v[1],v[2],v[3]}
end
function v_dot(a,b)
	return a[1]*b[1]+a[2]*b[2]+a[3]*b[3]
end
function v_scale(v,scale)
	v[1]*=scale
	v[2]*=scale
	v[3]*=scale
end
function v_add(v,dv,scale)
	scale=scale or 1
	return {
		v[1]+scale*dv[1],
		v[2]+scale*dv[2],
		v[3]+scale*dv[3]}
end
function v_lerp(a,b,t)
	return {
		lerp(a[1],b[1],t),
		lerp(a[2],b[2],t),
		lerp(a[3],b[3],t)
	}
end
function v_uv_lerp(a,b,t)
	return {
		lerp(a[1],b[1],t),
		lerp(a[2],b[2],t),
		lerp(a[3],b[3],t),
    -- uv coords
		lerp(a[4],b[4],t),
		lerp(a[5],b[5],t)
	}
end

function v_cross(a,b)
	local ax,ay,az=a[1],a[2],a[3]
	local bx,by,bz=b[1],b[2],b[3]
	return {ay*bz-az*by,az*bx-ax*bz,ax*by-ay*bx}
end
-- safe for overflow (to some extent)
function v_len(v)
	local x,y,z=v[1],v[2],v[3]
  -- pick major
  local d=max(max(abs(x),abs(y)),abs(z))
  -- adjust
  x/=d
  y/=d
  z/=d
  -- actuel len
  return sqrt(x*x+y*y+z*z)*d
end

function v_normz(v)
	local x,y,z=v[1],v[2],v[3]
  local d=v_len(v)
	return {x/d,y/d,z/d},d
end

-- matrix functions
function m_x_v(m,v)
	local x,y,z=v[1],v[2],v[3]
	return {m[1]*x+m[5]*y+m[9]*z+m[13],m[2]*x+m[6]*y+m[10]*z+m[14],m[3]*x+m[7]*y+m[11]*z+m[15]}
end

function make_m_from_euler(x,y,z)
		local a,b = cos(x),-sin(x)
		local c,d = cos(y),-sin(y)
		local e,f = cos(z),-sin(z)
  
    -- yxz order
  local ce,cf,de,df=c*e,c*f,d*e,d*f
	 return {
	  ce+df*b,a*f,cf*b-de,0,
	  de*b-cf,a*e,df+ce*b,0,
	  a*d,-b,a*c,0,
	  0,0,0,1}
end

-- only invert 3x3 part
function m_inv(m)
	m[2],m[5]=m[5],m[2]
	m[3],m[9]=m[9],m[3]
	m[7],m[10]=m[10],m[7]
end
-- returns basis vectors from matrix
function m_right(m)
	return {m[1],m[2],m[3]}
end
function m_up(m)
	return {m[5],m[6],m[7]}
end
function m_fwd(m)
	return {m[9],m[10],m[11]}
end
-- optimized 4x4 matrix mulitply
function m_x_m(a,b)
	local a11,a21,a31,_,a12,a22,a32,_,a13,a23,a33,_,a14,a24,a34=unpack(a)
	local b11,b21,b31,_,b12,b22,b32,_,b13,b23,b33,_,b14,b24,b34=unpack(b)

	return {
			a11*b11+a12*b21+a13*b31,a21*b11+a22*b21+a23*b31,a31*b11+a32*b21+a33*b31,0,
			a11*b12+a12*b22+a13*b32,a21*b12+a22*b22+a23*b32,a31*b12+a32*b22+a33*b32,0,
			a11*b13+a12*b23+a13*b33,a21*b13+a22*b23+a23*b33,a31*b13+a32*b23+a33*b33,0,
			a11*b14+a12*b24+a13*b34+a14,a21*b14+a22*b24+a23*b34+a24,a31*b14+a32*b24+a33*b34+a34,1
		}
end

function make_m_from_v_angle(up,angle)
	local fwd={-sin(angle),0,cos(angle)}
	local right=v_normz(v_cross(up,fwd))
	fwd=v_cross(right,up)
	return {
		right[1],right[2],right[3],0,
		up[1],up[2],up[3],0,
		fwd[1],fwd[2],fwd[3],0,
		0,0,0,1
	}
end

function make_cam(name)
  local up={0,1,0}
  local visleaves,visframe,prev_leaf={},0

  -- traverse bsp
  -- unrolled true/false children traversing for performance
  local function collect_bsp(node,pos)
    local side=node.dot(pos)>node[4]
    local child=node[not side]
    if child and child[name]==visframe then
      if child.contents then
        visleaves[#visleaves+1]=child
      else
        collect_bsp(child,pos)
      end
    end
    local child=node[side]
    if child and child[name]==visframe then
      if child.contents then
        visleaves[#visleaves+1]=child
      else
        collect_bsp(child,pos)
      end
    end
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
    collect_leaves=function(self,bsp,all_leaves)
      local current_leaf=find_sub_sector(bsp,self.pos)
      -- changed sector?
      if current_leaf and current_leaf!=prev_leaf then
        prev_leaf=current_leaf
        visframe+=1
        -- find all visible leaves
        local vis_mask=_vis_mask
        for i,bits in pairs(current_leaf.pvs) do
          for j,mask in pairs(vis_mask) do
            -- visible?
            if bits&mask!=0 then
              local leaf=all_leaves[(i<<5|j)+2]
              -- tag visible parents
              while leaf do
                -- already tagged?
                if(leaf[name]==visframe) break
                leaf[name]=visframe
                leaf=leaf.parent
              end
            end
          end
        end    
      end
      -- collect convex spaces back to front
      visleaves={}
      collect_bsp(bsp,self.pos)
      return visleaves
    end,  
    draw_points=function(self,points)
      local m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16=unpack(self.m)
      for k,v in ipairs(points) do
        local x,y,z=v[1],v[2],v[3]
        local ax,ay,az=m1*x+m5*y+m9*z+m13,m2*x+m6*y+m10*z+m14,m3*x+m7*y+m11*z+m15
        -- to screen space
        if az>0 then
          ax=63.5+((ax/az)<<6)       
          ay=63.5-((ay/az)<<6)
          circfill(ax,ay,4*64/az,7)
          if (v.msg) print(v.msg,ax+4*64/az+1,ay,8)
          if v.n then
            local v1=v_add(v,v.n,16)
            local x,y,z=v1[1],v1[2],v1[3]
            local ax1,ay1,az1=m1*x+m5*y+m9*z+m13,m2*x+m6*y+m10*z+m14,m3*x+m7*y+m11*z+m15
            if az1>0 then
              ax1=63.5+((ax1/az1)<<6)       
              ay1=63.5-((ay1/az1)<<6)
              line(ax,ay,ax1,ay1,15)
            end
          end
        end
      end
    end,
    draw_faces=function(self,leaves)
      local m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16=unpack(self.m)
      local v_cache,f_cache,pos={},{},self.pos
      
      for j,leaf in ipairs(leaves) do
        -- faces form a convex space, render in any order
        for i,face in pairs(leaf.faces) do    
          -- some sectors are sharing faces
          -- make sure a face from a leaf is drawn only once
          if not f_cache[face] and face.dot(pos)<face.cp!=face.side then            
            f_cache[face]=true
            local p,outcode,clipcode={},0xffff,0
            for k,v in pairs(face.verts) do
              local a=v_cache[v]
              if not a then
                local code,x,y,z=0,v[1],v[2],v[3]
                local ax,ay,az=m1*x+m5*y+m9*z+m13,m2*x+m6*y+m10*z+m14,m3*x+m7*y+m11*z+m15

                -- znear=8
                if az<8 then code=2 end
                --if az>2048 then code|=1 end
                if ax>az then code|=4
                elseif ax<-az then code|=8 end
                if ay>az then code|=16
                elseif ay<-az then code|=32 end
                -- save world space coords for clipping
                -- to screen space
                local w=64/az
                a={ax,ay,az,x=63.5+ax*w,y=63.5-ay*w,w=w,outcode=code}
                v_cache[v]=a
              end
              outcode&=a.outcode
              clipcode+=a.outcode&2
              p[k]=a
            end
            if outcode==0 then 
              if(clipcode>0) p=z_poly_clip(p)

              if #p>2 then
                polyfill(p,face.color)
                --polyline(p,0x11)
              end
            end
          end
        end
        -- draw entities in this convex space
        for thing,_ in pairs(leaf.things) do
          thing:draw(self.m)
        end
      end
    end
  }
end

function z_poly_clip(v)
	local res,v0={},v[#v]
	local d0=v0[3]-8
	for i=1,#v do
		local v1=v[i]
		local d1=v1[3]-8
		if d1>0 then
      if d0<=0 then
        local nv=v_lerp(v0,v1,d0/(d0-d1))         
        res[#res+1]={
          x=63.5+(nv[1]<<3),
          y=63.5-(nv[2]<<3),
          w=8
        }
			end
      res[#res+1]=v1
		elseif d0>0 then
      local nv=v_lerp(v0,v1,d0/(d0-d1))
      res[#res+1]={
        x=63.5+(nv[1]<<3),
        y=63.5-(nv[2]<<3),
        w=8
      }
    end
    v0=v1
		d0=d1
	end
	return res
end

function make_player(pos,a)
  local angle,dangle={0,a,0},{0,0,0}
  local velocity={0,0,0,}
  local wall_run

  local fire_ttl=0

  -- start above floor
  pos=v_add(pos,{0,1,0})
  return {
    pos=pos,
    m=make_m_from_euler(unpack(angle)),
    update=function(self)
      -- damping
      v_scale(dangle,0.6)
      v_scale(velocity,0.7)

      -- move
      local dx,dz,a,jmp=0,0,angle[2],0
      if(btn(0,1)) dx=4
      if(btn(1,1)) dx=-4
      if(btn(2,1)) dz=4
      if(btn(3,1)) dz=-4
      if(btnp(4)) jmp=20

      dangle=v_add(dangle,{stat(39),stat(38),wall_run and -4 or 0})
      angle=v_add(angle,dangle,1/1024)
    
      local c,s=cos(a),-sin(a)
      velocity=v_add(velocity,{s*dz-c*dx,jmp-2,c*dz+s*dx})      
      -- check next position
      local vn,vl=v_normz(velocity)
      wall_run=false
      if vl>0.1 then
        -- check current to target pos
        for i=1,3 do
          local hits={}            
          if hitscan(_model.clipnodes,self.pos,v_add(self.pos,velocity),hits) and hits.n then
            local fix=v_dot(hits.n,velocity)
            -- separating?
            if fix<0 then
              velocity=v_add(velocity,hits.n,-fix)

              if abs(hits.n[2])<0.2 then
                local wall_v=v_clone(vn,hits.n)
                if abs(wall_v[2])<0.25 then
                  velocity[2]+=10
                  printh("wall run")
                  -- wall_run=true
                end
              end
            end
          else
            goto clear
          end
        end
        -- cornered?
        velocity={0,0,0}
::clear::
      else
        velocity={0,0,0}
      end

      self.pos=v_add(self.pos,velocity)
      self.m=make_m_from_euler(unpack(angle))

      -- fire?
      fire_ttl=max(fire_ttl-1)
      if fire_ttl==0 and btnp(5) then
        printh("pop")
        make_particle(v_add(self.pos,{0,24,0}),m_fwd(self.m))  
        fire_ttl=15      
      end
    end
  }
end

function update_particle(self)
  self.ttl-=1
  -- 
  unregister_thing_subs(self)
  if(self.ttl<0) del(_particles,self) return

  -- move
  local next_pos=v_add(self.pos,self.vel,4)
  local hits={}
  if hitscan(_model.bsp,self.pos,next_pos,hits) and hits.n then
    printh("hit wall")
    del(_particles,self) 
    return
  end
  self.pos=next_pos
  register_thing_subs(_model.bsp,self,0)
end

function draw_particles(self,m)
  local m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16=unpack(m)
  local x,y,z=unpack(self.pos)
  local ax,ay,az=m1*x+m5*y+m9*z+m13,m2*x+m6*y+m10*z+m14,m3*x+m7*y+m11*z+m15
  -- to screen space
  if az>8 then
    local w=64/az
    circfill(63.5+ax*w,63.5-ay*w,w*4,rnd(15))
  end
end

function make_particle(pos,vel)
  local p=add(_particles,{
    pos=v_clone(pos),
    vel=vel,
    ttl=90,
    nodes={},
    update=update_particle,
    draw=draw_particles})
  register_thing_subs(_model.bsp,p,0)
end

-->8
-- bsp functions

-- find in what convex leaf pos is
function find_sub_sector(node,pos)
  while node do
    node=node[node.dot(pos)>node[4]]
    if node and node.contents then
      -- leaf?
      return node
    end
  end
end

function is_empty(node,pos)
  while node.contents==nil or node.contents>0 do
    node=node[node.dot(pos)>node[4]]
  end  
  return node.contents!=-1
end


function unregister_thing_subs(thing)
  for node,_ in pairs(thing.nodes) do
    if(node.things) node.things[thing]=nil
  end
end

function register_thing_subs(node,thing,radius)
  if(not node) return
  -- leaf?
  if node.contents then
    -- thing -> leaf
    thing.nodes[node]=true
    -- reverse
    if(not node.things) node.things={}
    node.things[thing]=true
    return
  end

  local dist,d=node.dot(thing.pos),node[4]
  local side,otherside=dist>d-radius,dist>d+radius
  
  register_thing_subs(node[side],thing,radius)
  
  -- straddling?
  if side!=otherside then
    register_thing_subs(node[otherside],thing,radius)
  end
end


-- https://github.com/id-Software/Quake/blob/bf4ac424ce754894ac8f1dae6a3981954bc9852d/WinQuake/world.c
-- hull location
-- https://github.com/id-Software/Quake/blob/bf4ac424ce754894ac8f1dae6a3981954bc9852d/QW/client/pmovetst.c
-- https://developer.valvesoftware.com/wiki/BSP
-- ray/bsp intersection
function hitscan(node,p0,p1,out)
  -- is "solid" space (bsp)
  if(not node) return true
  local contents=node.contents
  if contents then
  -- is "solid" space (bsp)
     if(contents==-2) return true
    -- in "empty" space
    if(contents<0) return
  end

  local dist,otherdist=node.dot(p0),node.dot(p1)
  local side,otherside=dist>node[4],otherdist>node[4]
  if side==otherside then
    -- go down this side
    return hitscan(node[side],p0,p1,out)
  end
  -- crossing a node
  local t=dist-node[4]
  if t<0 then
    t-=0x0.01
  else
    t+=0x0.01
  end  
  -- cliping fraction
  local frac=mid(t/(dist-otherdist),0,1)
  local p10=v_lerp(p0,p1,frac)
  --add(out,p10)
  local hit,otherhit=hitscan(node[side],p0,p10,out),hitscan(node[otherside],p10,p1,out)  
  if hit!=otherhit then
    -- not already registered?
    if #out==0 then
      -- check if in global empty space
      -- note: nodes do not have spatial relationships!!
      if is_empty(_model.clipnodes,p10) then
        add(out,p10) 
        local scale=t<0 and -1 or 1
        local n={scale*node[1],scale*node[2],scale*node[3],node[4],dot=node.dot}
        p10.n=n
        p10.msg=tostr(frac)
        out.n=n
        out.t=frac
      end
    end
  end
  return hit or otherhit
end


function _init()
  -- capture mouse
  -- enable lock+button alias
  poke(0x5f2d,7)

  -- unpack map
  _model,pos,angle=decompress("q8k",0,0,unpack_map)
  -- restore spritesheet
  reload()

  -- 
  _cam=make_cam("main")
  _plyr=make_player(pos,angle)

end

function _update()
  _plyr:update()

  --_spirit:update()

  --
  --local thing={unpack(pos)}
  --thing.nodes={}
  --register_thing_subs(_model.bsp,thing,16)

  for p in all(_particles) do
    p:update()
  end
  
  _cam:track(v_add(_plyr.pos,{0,24,0}),_plyr.m,_plyr.angle)
end

function _draw()
  cls()

  fillp(0xa5a5)
  local visleaves=_cam:collect_leaves(_model.bsp,_model.leaves)
  _cam:draw_faces(visleaves)

  -- _cam:draw_points({_plyr.pos})

  pal(_palette,1)

  local s="%:"..(flr(1000*stat(1))/10).."\n"..stat(0).."\nleaves:"..#visleaves
  print(s,2,3,1)
  print(s,2,2,12)

  pset(64,64,15)
end

-->8
-- data unpacking functions
-- unpack 1 or 2 bytes
function unpack_variant()
	local h=mpeek()
	-- above 127?
  if h&0x80>0 then
    h=(h&0x7f)<<8|mpeek()
  end
	return h
end
-- unpack a fixed 16:16 value
function unpack_fixed()
	return mpeek()<<8|mpeek()|mpeek()>>8|mpeek()>>16
end

-- unpack an array of bytes
function unpack_array(fn)
	for i=1,unpack_variant() do
		fn(i)
	end
end

function unpack_chr()
  return chr(mpeek())
end

-- reference
function unpack_ref(a)
  local n=unpack_variant()
  local r=a[n]
  assert(r,"invalid reference: "..n)
  return r
end

-- 3d vertex
function unpack_v3()
  return {unpack_fixed(),unpack_fixed(),unpack_fixed()}
end

function unpack_map()
  local verts,planes,faces,leaves,nodes,models={},{},{},{},{},{}

  unpack_array(function()
    add(verts,unpack_v3())
  end)

  unpack_array(function()
    local t,p=mpeek(),add(planes,unpack_v3())
    p[4]=unpack_fixed()
    local x,y,z=unpack(p)
    local dot=function(v)    
      return x*v[1]+y*v[2]+z*v[3]
    end
    if t==0 then    
      dot=function(v)
        return x*v[1]
      end
    elseif t==1 then    
      dot=function(v)
        return y*v[2]
      end
    elseif t==2 then    
      dot=function(v)
        return z*v[3]
      end
    end
    p.dot=dot        
  end)

  unpack_array(function()
    local face_verts,plane,flags,color={},unpack_ref(planes),mpeek(),mpeek()/255
    --if color>0.75 then
    --  color=0x77
    --elseif color>0.25 then
    --  color=0x17
    --else
    --  color=0
    --end
    
    local c,side=0x66,flags&0x1==0
    if(plane[2]>0==side) c=0x55
    if(plane[2]>0.7==side) c=0xd5
    if((plane[2]==1)==side) c=0xdd
    if plane[2]==0 then
      c=0x55
      if(0.7*plane[1]+0.7*plane[3]>-0.25==side) c=0x65
      if(0.7*plane[1]+0.7*plane[3]>0==side) c=0x77
      --if(face[3]>0.75==face.side) c=0x81
    end
    local f=add(faces,setmetatable({
      sky=flags&0x2!=0,
      -- face side vs supporting plane
      side=side,
      color=flr(rnd(15))*0x11,--_palette[mid(flr(16*color),0,15)]|_palette[mid(flr(16*color)+1,0,15)]<<4,
      verts=face_verts
    },{__index=plane}))

    unpack_array(function(i)
      -- reference to vertex
      add(face_verts,unpack_ref(verts))
    end)
    f.cp=f.dot(face_verts[1])
  end)

  unpack_array(function(i)
    local f,pvs={},{}
    add(leaves,{
      -- get 0-based index of leaf
      -- leaf 0 is "solid" leaf
      id=i-1,
      contents=mpeek()-128,
      faces=f,
      pvs=pvs
    })

    -- potentially visible set    
    unpack_array(function()
      pvs[unpack_variant()]=unpack_fixed()
    end)
    
    unpack_array(function()
      add(f,unpack_ref(faces))
    end)
  end)

  unpack_array(function()
    local plane=unpack_ref(planes)
    -- merge plane and node
    add(nodes,setmetatable({
      flags=mpeek(),
      [true]=unpack_variant(),
      [false]=unpack_variant()
    },{__index=plane}))
  end)
  -- attach nodes/leaves
  for _,node in pairs(nodes) do
    local function attach_node(side,leaf)
      local refs=leaf and leaves or nodes
      local child=refs[node[side]]
      node[side]=child
      -- used to optimize bsp traversal for rendering
      if(child) child.parent=node
    end
    attach_node(true,node.flags&0x1!=0)
    attach_node(false,node.flags&0x2!=0)
  end
  
  -- unpack models
  unpack_array(function()
    local bsp=unpack_ref(nodes)
    -- collision hull
    local clipnodes={}
    unpack_array(function()
      local node,flags=setmetatable({},{__index=unpack_ref(planes)}),mpeek()
      local contents=flags&0xf
      if contents!=0 then
        node[true]=-contents
      else
        node[true]=unpack_variant()
      end
      contents=(flags&0xf0)>>4
      if contents!=0 then
        node[false]=-contents
      else
        node[false]=unpack_variant()
      end
      add(clipnodes,node)
    end)
    -- attach references
    for _,node in pairs(clipnodes) do
      local function attach_node(side)
        local id=node[side]
        if id<0 then
          node[side]=_content_types[-id]
        else
          node[side]=clipnodes[id]
        end
      end
      attach_node(true)
      attach_node(false)
    end
    add(models,{bsp=bsp,clipnodes=clipnodes[1],leaves=leaves})
  end)
  
  -- get top level node
  -- unpack player position
  local plyr_pos,plyr_angle=unpack_v3(),unpack_fixed()
  
  return models[1],plyr_pos,plyr_angle
end
