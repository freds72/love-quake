-- quake engine
-- by @freds72

-- game globals
local _particles,_cam,_plyr,_model={}
local plane_dot,plane_isfront,plane_get

-- texture coordinates + texture maps + s/t cache
local _maps,_texcoords={},{}
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
  local d=v_len(v)
	return {v[1]/d,v[2]/d,v[3]/d},d
end

-- matrix functions
-- matrix vector multiply
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
	local a11,a12,a13,a21,a22,a23,a31,a32,a33=a[1],a[5],a[9],a[2],a[6],a[10],a[3],a[7],a[11]
	local b11,b12,b13,b14,b21,b22,b23,b24,b31,b32,b33,b34=b[1],b[5],b[9],b[13],b[2],b[6],b[10],b[14],b[3],b[7],b[11],b[15]

	return {
			a11*b11+a12*b21+a13*b31,a21*b11+a22*b21+a23*b31,a31*b11+a32*b21+a33*b31,0,
			a11*b12+a12*b22+a13*b32,a21*b12+a22*b22+a23*b32,a31*b12+a32*b22+a33*b32,0,
			a11*b13+a12*b23+a13*b33,a21*b13+a22*b23+a23*b33,a31*b13+a32*b23+a33*b33,0,
			a11*b14+a12*b24+a13*b34+a[13],a21*b14+a22*b24+a23*b34+a[14],a31*b14+a32*b24+a33*b34+a[15],1
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

function make_cam()
  local up={0,1,0}
  local visleaves,visframe,prev_leaf={},0

  -- traverse bsp
  local function collect_child(node,side,pos)
    local child=node[side]
    if child and child.visframe==visframe then
      if child.contents then
        visleaves[#visleaves+1]=child
      else
        collect_bsp(child,pos)
      end
    end
  end
  -- unrolled true/false children traversing for performance
  function collect_bsp(node,pos)
    local side=plane_isfront(node.plane,pos)
    collect_child(node,not side,pos)
    collect_child(node,side,pos)
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
                if(leaf.visframe==visframe) break
                leaf.visframe=visframe
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
    draw_faces=function(self,verts,faces,leaves)
      local m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16=unpack(self.m)
      local cam_u,cam_v={m1,m5,m9},{m2,m6,m10}
      local v_cache,f_cache,pos={},{},self.pos
      
      for j,leaf in ipairs(leaves) do
        -- faces form a convex space, render in any order        
        for i=1,leaf.nf do
          -- face index
          local fi=leaf[i]  
          -- sky? skip
          if not faces[fi+3] then
            -- face normal          
            local fn,side=faces[fi],faces[fi+2]
            -- some sectors are sharing faces
            -- make sure a face from a leaf is drawn only once
            if not f_cache[fi] and plane_dot(fn,pos)<faces[fi+1]!=side then            
              f_cache[fi]=true
                          
              local p,outcode,clipcode,uvi,uvs={},0xffff,0,faces[fi+6]
              if (uvi!=-1) uvs={}
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
                if uvs then
                  uvs[k]=_texcoords[uvi+k]
                end
              end
              if outcode==0 then 
                if(clipcode>0) p,uvs=z_poly_clip(p,uvs)

                if #p>2 then
                  if uvi!=-1 then
                    local s,t=plane_dot(fn,cam_u),plane_dot(fn,cam_v)
                    if(side) s,t=-s,-t
                    local a=atan2(s,t)
                    -- normalized 2d vector
                    local u,v=sin(a),cos(a)
                    -- copy texture to hw map
                    local mi=faces[fi+7]
                    local stride=_maps[mi]
                    for dst,src in pairs(_maps[mi+1]) do
                      poke4(dst,peek4(src,stride))
                    end
                    -- texture coords
                    -- printh(tostr(_maps[mi],true))
                    -- poke4(0x5f38,_maps[mi])
                    --poke4(0x5f38,0x0)

                    -- display light center on texture
                    -- for light,_ in pairs(leaf.things) do
                    --   local dist,d=plane_dot(fn,light.pos)
                    --   if dist<faces[fi+1]!=side then
                    --     -- translate to uv space
                    --     local u,v=unpack(v_uv(texcoords,light.pos,umin,vmin))                      
                    --     if u>=0 and v>=0 then
                    --       mset(u,v,1)
                    --       
                    --     end
                    --   end
                    -- end

                    if abs(u)>abs(v) then
                      polytex_ymajor(p,uvs,v/u)
                    else
                      polytex_xmajor(p,uvs,u/v)
                    end                   
                  else
                    polyfill(p,0)
                  end
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
  local angle,dangle,velocity={0,a,0},{0,0,0},{0,0,0,}
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
      if(btn(0,1)) dx=3
      if(btn(1,1)) dx=-3
      if(btn(2,1)) dz=3
      if(btn(3,1)) dz=-3
      if(btnp(4)) jmp=20

      dangle=v_add(dangle,{stat(39),stat(38),dx/4})
      angle=v_add(angle,dangle,1/1024)
    
      local c,s=cos(a),-sin(a)
      velocity=v_add(velocity,{s*dz-c*dx,jmp-2,c*dz+s*dx})          
      -- check next position
      local vn,vl=v_normz(velocity)
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
      fire_ttl=max(fire_ttl-1)
      if fire_ttl==0 and btn(5) then
        make_particle(
          v_add(v_add(self.pos,m_up(self.m),18+rnd(4)),m_right(self.m),4-rnd(8)),
          m_fwd(self.m),
          24+rnd(8))  
        fire_ttl=5      
      end
    end
  }
end

function make_particle(pos,fwd,vel)
  local p=add(_particles,{
    pos=pos,
    fwd=fwd,
    vel=vel,
    ttl=90,
    col=12+rnd(2),
    nodes={},
    update=update_particle,
    draw=draw_particles})
  register_thing_subs(_model.bsp,p,0)
end

function update_particle(self)
  self.ttl-=1
  -- 
  unregister_thing_subs(self)
  if(self.ttl<0) del(_particles,self) return

  -- move
  local next_pos=v_add(self.pos,self.fwd,self.vel)
  -- gravity
  next_pos[2]-=2
  
  local hits={}
  if hitscan(_model.bsp,self.pos,next_pos,hits) and hits.n then
    del(_particles,self) 
    return  
  end
  self.prev_pos=self.pos
  self.pos=next_pos
  register_thing_subs(_model.bsp,self,0)
end

function draw_particles(self,m)
  local m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16=unpack(m)
  local x0,y0,z0=unpack(self.prev_pos)
  local x1,y1,z1=unpack(self.pos)
  local ax0,ay0,az0=m1*x0+m5*y0+m9*z0+m13,m2*x0+m6*y0+m10*z0+m14,m3*x0+m7*y0+m11*z0+m15
  local ax1,ay1,az1=m1*x1+m5*y1+m9*z1+m13,m2*x1+m6*y1+m10*z1+m14,m3*x1+m7*y1+m11*z1+m15
  -- to screen space
  if az0>8 and az1>8 then
    local w0,w1=64/az0,64/az1
    line(63.5+ax0*w0,63.5-ay0*w0,63.5+ax1*w1,63.5-ay1*w1,self.col)
  end
end

local _skulls={}
function make_skull(pos,up)
  local p=add(_particles,{
    pos=pos,
    period=4+rnd(4),
    m=make_m_from_v_angle(up,0),
    nodes={},
    update=update_skull,
    draw=draw_skull})
  register_thing_subs(_model.bsp,p,4)
  add(_skulls,p)
end

function update_skull(self)
  local velocity=v_normz(make_v(self.pos,_plyr.pos),0.8)
  -- avoid other skulls
  for _,other in pairs(_skulls) do
    if other!=self then
      local on,od=v_normz(make_v(self.pos,other.pos))
      if od<24 then
        velocity=v_add(velocity,on,-1)
      end
    end
  end
  -- mild gravity
  velocity[2]-=0.9*cos(time()/self.period)
  --if(rnd()>0.2) velocity[2]+=rnd(4)

  -- check next position
  local vn,vl=v_normz(velocity)
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
    velocity=nil
::clear::
  else
    velocity=nil
  end

  if velocity then
    unregister_thing_subs(self)
    local right=m_right(self.m)
    self.pos=v_add(self.pos,velocity)
    self.reye=v_add(self.pos,right,4)
    self.leye=v_add(self.pos,right,-4)
    if rnd()>0.5 then
      --make_blood(self.reye)
      --make_blood(self.leye)
    end
    register_thing_subs(_model.bsp,self,4)
  end
end

function draw_eye(x,y,w)
  fillp(0xa5a5.8)
  circfill(x,y,(2.4+rnd(0.5))*w,2) 
  fillp()
  circfill(x,y,1.4*w,12) 
  circfill(x,y,w,13)
end

function draw_skull(self,m)
  -- find eyes
  local x,y,z=unpack(m_x_v(m,self.pos))
  local x0,y0,z0=unpack(m_x_v(m,self.reye))
  local x1,y1,z1=unpack(m_x_v(m,self.leye))
  local w0,w1,w=64/z0,64/z1,64/z
  fillp(0xa5a5.8)
  circfill(63.5+x*w,63.5-y*w,9.4*w,7)
  fillp()
  circfill(63.5+x*w,63.5-y*w,8*w,7)
  if(z0>8) draw_eye(63.5+x0*w0,63.5-y0*w0,w0)
  if(z1>8) draw_eye(63.5+x1*w1,63.5-y1*w1,w1)
end

function make_blood(pos)
  local p=add(_particles,{
    pos=v_add(pos,{0.5-rnd(),0.5-rnd(),0.5-rnd()},1.5),
    ttl=12+rnd(5),
    col=13,
    nodes={},
    update=update_blood,
    draw=draw_blood})
  register_thing_subs(_model.bsp,p,0)
end

function update_blood(self)
  self.ttl-=1
  -- 
  unregister_thing_subs(self)
  if(self.ttl<0) del(_particles,self) return

  -- gravity
  local next_pos=v_add(self.pos,{0,-0.2,0})
  
  local hits={}
  if hitscan(_model.bsp,self.pos,next_pos,hits) and hits.n then
    del(_particles,self) 
    return  
  end
  self.pos=next_pos
  register_thing_subs(_model.bsp,self,0)
end

function draw_blood(self,m)
  local m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16=unpack(m)
  local x0,y0,z0=unpack(self.pos)
  local ax0,ay0,az0=m1*x0+m5*y0+m9*z0+m13,m2*x0+m6*y0+m10*z0+m14,m3*x0+m7*y0+m11*z0+m15
  -- to screen space
  if az0>8 then
    local w0=64/az0
    --fillp(0xa5a5.8)
    circfill(63.5+ax0*w0,63.5-ay0*w0,w0,self.col) 
    --fillp()
  end
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

-- find if pos is within an empty space
function is_empty(node,pos)
  while node.contents==nil or node.contents>0 do
    node=node[plane_isfront(node.plane,pos)]
  end  
  return node.contents!=-1
end

-- detach a thing from a convex sector (leaf)
function unregister_thing_subs(thing)
  for node,_ in pairs(thing.nodes) do
    if(node.things) node.things[thing]=nil
  end
end

-- registers a thing in all convex sectors within radius
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
        out.n=n
        out.t=frac
      end
    end
  end
  return hit or otherhit
end


function _init()
  -- enable tile 0 + extended memory
  poke(0x5f36, 0x18)
  -- capture mouse
  -- enable lock+button alias
  poke(0x5f2d,7)

  -- unpack map
  _model,pos,angle=decompress("q8k",0,0,unpack_map)
  -- restore spritesheet
  reload()

  palt(0,false)
  pal({129, 133, 5, 134, 143, 15, 130, 132, 4, 137, 9, 136, 8, 13, 12},1,1)

  -- 
  _cam=make_cam()
  _plyr=make_player(pos,angle)
  for i=1,5 do
    --make_skull(v_add(pos,{0.5-rnd(),rnd(),0.5-rnd()},48),{0,1,0})
  end
end

function _update()

  _plyr:update()
  
  for p in all(_particles) do
    p:update()
  end

  _cam:track(v_add(_plyr.pos,{0,48,0}),_plyr.m,_plyr.angle)
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
  local verts,planes,faces,leaves,nodes,models,uvs={},{},{},{},{},{},{}

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

  -- temporary
  unpack_array(function()
    add(uvs,{
      unpack_v3(),
      unpack_fixed(),
      unpack_v3(),
      unpack_fixed()
    })
  end)

  -- faces
  local face_sizeof=8
  unpack_array(function()
    local base,face_verts,pi,flags=#faces+1,{},plane_sizeof*unpack_variant()+1,mpeek()
    
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
      -- texture coordinates (reference)
      local texcoords=unpack_ref(uvs)
      -- 6: start of uv coords
      add(faces,#_texcoords)
      -- 7: texture map (reference)
      add(faces,unpack_variant())
      -- 
      local umin,vmin=unpack_fixed(),unpack_fixed()
      for _,vi in ipairs(face_verts) do
        local v={verts[vi],verts[vi+1],verts[vi+2]}
        add(_texcoords,{
          v_dot(texcoords[1],v)+texcoords[2]-umin,
          v_dot(texcoords[3],v)+texcoords[4]-vmin})
      end
    else
      for i=1,3 do
        add(faces,-1)
      end      
    end

    -- "fix" cp value
    local vi=face_verts[1]
    faces[base+1]=plane_dot(pi,{verts[vi],verts[vi+1],verts[vi+2]})
  end,"faces")

  -- lightmap maps
  local maps_addr=0x8000
  unpack_array(function()
    -- convert to tline coords
    -- add(_maps,(size&0xf)>>16|(size\16)>>8)
    local height,size=mpeek(),mpeek()
    local mw,tiles=add(_maps,4*size\height),add(_maps,{})
    -- copy to ram    
    mw/=4
    for i=0,size-1 do
      if i%mw==0 then
        -- record start of map span
        tiles[0x2000+((i\mw)<<7)]=maps_addr
      end
      poke4(maps_addr,unpack_fixed())
      maps_addr+=4
    end
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
      local node,flags={plane=plane_sizeof*unpack_variant()+1},mpeek()
      -- either empty, lava, ... or reference to a another half-space
      local contents=flags&0xf
      node[true]=contents!=0 and -contents or unpack_variant()
      contents=(flags&0xf0)>>4
      node[false]=contents!=0 and -contents or unpack_variant()
      add(clipnodes,node)
    end)
    -- attach references
    for node in all(clipnodes) do
      local function attach_node(side)
        local id=node[side]
        node[side]=id<0 and _content_types[-id] or clipnodes[id]
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