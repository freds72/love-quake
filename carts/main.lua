-- quake engine
-- by @freds72

-- game globals
local _particles,_cam,_plyr,_model={}
local plane_dot,plane_isfront,plane_get

-- texture coordinates + texture maps
local _uvs,_maps={},{}
local _content_types={{contents=-1},{contents=-2}}

-- bsp drawing helpers
local _vis_mask=split("0x0000.0002,0x0000.0004,0x0000.0008,0x0000.0010,0x0000.0020,0x0000.0040,0x0000.0080,0x0000.0100,0x0000.0200,0x0000.0400,0x0000.0800,0x0000.1000,0x0000.2000,0x0000.4000,0x0000.8000,0x0001.0000,0x0002.0000,0x0004.0000,0x0008.0000,0x0010.0000,0x0020.0000,0x0040.0000,0x0080.0000,0x0100.0000,0x0200.0000,0x0400.0000,0x0800.0000,0x1000.0000,0x2000.0000,0x4000.0000,0x8000.0000",",",1)
_vis_mask[0]=0x0000.0001

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
function v_uv(texcoords,a)
  return {
    (v_dot(texcoords[1],a)+texcoords[2])>>3,
    (v_dot(texcoords[3],a)+texcoords[4])>>3
  }
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
function v2_lerp(a,b,t)
	return {
		lerp(a[1],b[1],t),
		lerp(a[2],b[2],t)
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
    local side=plane_isfront(node.plane,pos)
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
    draw_faces=function(self,verts,faces,leaves)
      local m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16=unpack(self.m)
      local cam_u,cam_v={m1,m5,m9},{m2,m6,m10}
      local v_cache,f_cache,pos={},{},self.pos
      
      for j,leaf in ipairs(leaves) do
        -- faces form a convex space, render in any order        
        for i=1,leaf.nf do
          -- face index
          local fi=leaf[i]  
          -- face normal          
          local fn,side=faces[fi],faces[fi+2]
          -- some sectors are sharing faces
          -- make sure a face from a leaf is drawn only once
          if not f_cache[fi] and plane_dot(fn,pos)<faces[fi+1]!=side then            
            f_cache[fi]=true
                        
            local p,outcode,clipcode,texcoords,uvs={},0xffff,0,_uvs[faces[fi+6]]
            if(texcoords) uvs={}
            for k,vi in pairs(faces[fi+4]) do
              -- base index in verts array
              local a=v_cache[vi]
              if not a then
                local code,x,y,z=0,verts[vi],verts[vi+1],verts[vi+2]
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
                v_cache[vi]=a
              end
              outcode&=a.outcode
              clipcode+=a.outcode&2
              p[k]=a              
              if texcoords then
                uvs[k]=v_uv(texcoords,{verts[vi],verts[vi+1],verts[vi+2]})
              end
            end
            if outcode==0 then 
              if(clipcode>0) p,uvs=z_poly_clip(p,uvs)

              if #p>2 then
                if texcoords then
                  local s,t=plane_dot(fn,cam_u),plane_dot(fn,cam_v)
                  if(side) s,t=-s,-t
                  local a=atan2(s,t)
                  -- normalized 2d vector
                  local u,v=sin(a),cos(a)
                  -- copy texture
                  local mi=faces[fi+7]
                  -- texture coords
                  poke4(0x5f38,_maps[mi])
                  for k,v in pairs(_maps[mi+1]) do
                     poke4(k,v)
                  end
                  if abs(u)>abs(v) then
                    polytex_ymajor(p,uvs,v/u)
                  else
                    polytex_xmajor(p,uvs,u/v)
                  end 
                else
                  polyfill(p,12)
                end
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

-- znear=8
function z_poly_clip(v,uvs)
	local res,v0,uv0,res_uv={},v[#v],uvs and uvs[#v],{}
	local d0=v0[3]-8
	for i=1,#v do
		local v1,uv1=v[i],uvs and uvs[i]
		local d1=v1[3]-8
		if d1>0 then
      if d0<=0 then
        local t=d0/(d0-d1)
        local nv=v_lerp(v0,v1,t) 
        res[#res+1]={
          x=63.5+(nv[1]<<3),
          y=63.5-(nv[2]<<3),
          w=8}
        if uvs then
          res_uv[#res_uv+1]=v2_lerp(uv0,uv1,t)
        end
			end
      res[#res+1]=v1
      res_uv[#res_uv+1]=uv1
		elseif d0>0 then
      local t=d0/(d0-d1)
			local nv=v_lerp(v0,v1,t)
      res[#res+1]={
        x=63.5+(nv[1]<<3),
        y=63.5-(nv[2]<<3),
        w=8}
      if uvs then
        res_uv[#res_uv+1]=v2_lerp(uv0,uv1,t)
      end
		end
    v0=v1
    uv0=uv1
		d0=d1
	end
	return res,res_uv
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
      angle[3]*=0.8
      v_scale(dangle,0.6)
      v_scale(velocity,0.7)

      -- move
      local dx,dz,a,jmp=0,0,angle[2],0
      if(btn(0,1)) dx=4
      if(btn(1,1)) dx=-4
      if(btn(2,1)) dz=4
      if(btn(3,1)) dz=-4
      if(btnp(4)) jmp=20

      dangle=v_add(dangle,{stat(39),stat(38),dx/8})
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
      --fire_ttl=max(fire_ttl-1)
      --if fire_ttl==0 and btnp(5) then
      --  printh("pop")
      --  make_particle(v_add(self.pos,{0,24,0}),m_fwd(self.m))  
      --  fire_ttl=15      
      --end
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
    node=node[plane_isfront(node.plane,pos)]
    if node and node.contents then
      -- leaf?
      return node
    end
  end
end

function is_empty(node,pos)
  while node.contents==nil or node.contents>0 do
    node=node[plane_isfront(node.plane,pos)]
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

  local dist,d=plane_dot(node.plane,thing.pos)
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
        local nx,ny,nz=plane_get(node.plane)
        local n={scale*nx,scale*ny,scale*nz,node_dist}
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

  -- enable tile 0
  poke(0x5f36, 0x8)
  palt(0,false)
  pal({129, 133, 5, 134, 143, 15, 130, 132, 4, 137, 9, 136, 8, 13, 12},1,1)

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
  
  local visleaves=_cam:collect_leaves(_model.bsp,_model.leaves)
  _cam:draw_faces(_model.verts,_model.faces,visleaves)

  -- _cam:draw_points({_plyr.pos})

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
function unpack_array(fn,name)
  local mem0=stat(0)
	for i=1,unpack_variant() do
		fn(i)
	end
  if(name) printh(name..":"..stat(0)-mem0.."kb")
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

  printh("------------------------")
  -- vertices
  local vert_sizeof=3
  unpack_array(function()
    local x,y,z=unpack(unpack_v3())
    add(verts,x)
    add(verts,y)
    add(verts,z)
  end,"verts")

  -- planes
  local plane_sizeof=5
  plane_get=function(pi)
    return planes[pi],planes[pi+1],planes[pi+2]
  end
  plane_dot=function(pi,v)
    local t=planes[pi+4]
    if t<3 then    
      return planes[pi+t]*v[t+1],planes[pi+3]
    end
    return planes[pi]*v[1]+planes[pi+1]*v[2]+planes[pi+2]*v[3],planes[pi+3]
  end
  plane_isfront=function(pi,v)
    local t=planes[pi+4]
    if t<3 then
      return planes[pi+t]*v[t+1]>planes[pi+3]
    end
    return planes[pi]*v[1]+planes[pi+1]*v[2]+planes[pi+2]*v[3]>planes[pi+3]
  end

  unpack_array(function()  
    local t=mpeek()
    local x,y,z=unpack(unpack_v3())
    add(planes,x)
    add(planes,y)
    add(planes,z)
    add(planes,unpack_fixed())
    add(planes,t)
  end,"planes")  

  unpack_array(function()
    add(_uvs,{
      unpack_v3(),
      unpack_fixed(),
      unpack_v3(),
      unpack_fixed()
    })
  end)

  -- faces
  local face_sizeof=8
  unpack_array(function(fi)
    local base=#faces+1

    local face_verts,pi,flags={},plane_sizeof*unpack_variant()+1,mpeek()
    
    -- 0: supporting plane
    add(faces,pi)
    -- 1: cp (placeholder)
    add(faces,0)
    -- 2:side
    add(faces,flags&0x1==0)
    -- 3: sky flag
    add(faces,flags&0x4!=0)

    unpack_array(function()
      add(face_verts,vert_sizeof*unpack_variant()+1)
    end)
    -- 4: verts indices
    add(faces,face_verts)

    -- texture (if any)
    if flags&0x2!=0 then      
      -- 5: base light (e.g. ramp)
      add(faces,mpeek())      
      -- 6: texture coordinates (reference)
      add(faces,unpack_variant())
      -- 7: texture map (reference)
      add(faces,unpack_variant())
    else
      add(faces,0)
      add(faces,0)
      add(faces,0)
    end

    -- "fix" cp value
    local vi=face_verts[1]
    faces[base+1]=plane_dot(pi,{verts[vi],verts[vi+1],verts[vi+2]})
  end,"faces")

  -- texture maps
  unpack_array(function(i)
    local size=mpeek()
    -- convert to tline coords
    add(_maps,(size&0xf)>>8|(size\16)>>16)
    local tiles={}
    unpack_array(function()
      tiles[0x2000+unpack_variant()]=unpack_fixed()
    end)    
    add(_maps,tiles)
  end,"maps")
  
  unpack_array(function(i)
    local pvs={}
    local l=add(leaves,{
      -- get 0-based index of leaf
      -- leaf 0 is "solid" leaf
      -- id=i-1,
      contents=mpeek()-128,
      pvs=pvs
    })
    
    -- potentially visible set    
    unpack_array(function()
      pvs[unpack_variant()]=unpack_fixed()
    end)
    
    local n=unpack_variant()
    l.nf=n
    for i=1,n do      
      add(l,face_sizeof*unpack_variant()+1)
    end
  end,"leaves")

  unpack_array(function()
    local pi=plane_sizeof*unpack_variant()+1
    -- merge plane and node
    add(nodes,{
      flags=mpeek(),
      [true]=unpack_variant(),
      [false]=unpack_variant(),
      plane=pi
    })
  end,"nodes")
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
      local pi=plane_sizeof*unpack_variant()+1
      local node,flags={
        plane=pi
      },mpeek()
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
    add(models,{verts=verts,planes=planes,faces=faces,bsp=bsp,clipnodes=clipnodes[1],leaves=leaves})
  end,"models")

  -- get top level node
  -- unpack player position
  local plyr_pos,plyr_angle=unpack_v3(),unpack_fixed()
  
  return models[1],plyr_pos,plyr_angle
end