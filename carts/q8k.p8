pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
-- quake engine
-- by @freds72
#include poly.lua
#include plain.lua

local _model

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
function v_len(v)
	local x,y,z=v[1],v[2],v[3]
	return sqrt(x*x+y*y+z*z)
end

function v_normz(v)
	local x,y,z=v[1],v[2],v[3]
	local d=sqrt(x*x+y*y+z*z)
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

function make_cam()
  local up={0,1,0}
	return {
		pos={0,0,0},    
		track=function(self,pos,m)	
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
    is_visible=function(self,bbox)
      local m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16=unpack(self.m)
      local p,outcode={},0xffff          
      for _,v in pairs(bbox) do
        local code,x,y,z=0,unpack(v)
        x,y,z=m1*x+m5*y+m9*z+m13,m2*x+m6*y+m10*z+m14,m3*x+m7*y+m11*z+m15

        if z<1 then code=2 end
        --if z>250 then code|=1 end
        if x>z then code|=4
        elseif x<-z then code|=8 end
        if y>z then code|=16
        elseif y<-z then code|=32 end
        outcode&=code
      end
      return outcode==0
    end,
    draw_faces=function(self,model)
      local m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16=unpack(self.m)
      local v_cache,f_cache={},{}
      for j,leaf in ipairs(model) do
        for i,face in pairs(leaf.faces) do    
          -- some sectors are sharing faces
          -- make sure a face from a leaf is draw only once
          if not f_cache[face] and v_dot(face.plane.n,self.pos)<face.cp!=face.side then
            f_cache[face]=true
            local p,outcode,clipcode={},0xffff,0          
            -- local g={0,0,0}
            for k,v in pairs(face.verts) do
              local a=v_cache[v]
              if not a then
                local code,x,y,z=0,v[1],v[2],v[3]
                x,y,z=m1*x+m5*y+m9*z+m13,m2*x+m6*y+m10*z+m14,m3*x+m7*y+m11*z+m15

                if z<8 then code=2 end
                --if z>250 then code|=1 end
                if x>z then code|=4
                elseif x<-z then code|=8 end
                if y>z then code|=16
                elseif y<-z then code|=32 end
                -- save world space coords for clipping
                -- to screen space
                local w=64/z
                a={x,y,z,x=63.5+x*w,y=63.5-y*w,w=w,outcode=code}    
                v_cache[v]=a
              end
              outcode&=a.outcode
              clipcode+=a.outcode&2              
              p[k]=a
              -- g=v_add(g,a)
            end
            if outcode==0 then            
              if(clipcode>0) p=z_poly_clip(8,p)
              if #p>2 then
                polyfill(p,1+(i%14))
                --polyline(p,c)
                -- v_scale(g,1/#face.verts)
                -- local w=64/g[3]                
                --if(w>0) print(leaf.id,63.5+g[1]*w,63.5-g[2]*w,c)
              end
            end
          end
        end
      end
    end
  }
end

function z_poly_clip(znear,v)
	local res,v0={},v[#v]
	local d0=v0[3]-znear
	for i=1,#v do
		local v1=v[i]
		local d1=v1[3]-znear
		if d1>0 then
      if d0<=0 then
        local t=d0/(d0-d1)
        local nv=v_lerp(v0,v1,t) 
        local w=64/nv[3]
        res[#res+1]={x=63.5+nv[1]*w,y=63.5-nv[2]*w,w=w}
			end
      res[#res+1]=v1
		elseif d0>0 then
      local t=d0/(d0-d1)
			local nv=v_lerp(v0,v1,t)
      local w=64/nv[3]
      res[#res+1]={x=63.5+nv[1]*w,y=63.5-nv[2]*w,w=w}
		end
    v0=v1
		d0=d1
	end
	return res
end

function make_player(x,y,z)
  local angle,dangle={0,0,0},{0,0,0}
  local velocity={0,0,0,}

  return {
    pos={x,y,z},
    m=make_m_from_euler(0,0,0),
    update=function(self)
      -- damping
      v_scale(dangle,0.6)
      v_scale(velocity,0.7)

      -- move
      local dx,dz,a=0,0,angle[2]
      if(btn(0,1)) dx=1
      if(btn(1,1)) dx=-1
      if(btn(2,1)) dz=1
      if(btn(3,1)) dz=-1

      dangle=v_add(dangle,{stat(39),stat(38),dx})
      angle=v_add(angle,dangle,1/1024)

      local c,s=cos(a),-sin(a)
      velocity=v_add(velocity,m_fwd(self.m),dz*8)
      -- velocity=v_add(velocity,{-dx*c,0,dx*s},1)
      self.pos=v_add(self.pos,velocity)
      self.m=make_m_from_euler(unpack(angle))
    end
  }

end

function visit_bsp(node,pos,visitor)
  local plane=node.plane
  local side=v_dot(plane.n,pos)<=plane.d
  visitor(node,side,pos,visitor)
  visitor(node,not side,pos,visitor)
end

function find_sub_sector(node,pos)
  while node do
    local plane=node.plane
    local side=v_dot(plane.n,pos)<=plane.d
    local child=node.children[not side]
    if child and child.contents then
      -- leaf?
      return child
    end
    node=child
  end
end


function _init()
  -- capture mouse
  -- enable lock+button alias
  poke(0x5f2d,7)

  -- 
  _cam=make_cam()
  _plyr=make_player(0,10,0)

  -- unpack map
  _model,_leaves=decompress("q8k",0,0,unpack_map)
end

function _update()
  _plyr:update()

  _cam:track(_plyr.pos,_plyr.m)
end

function _draw()
  cls()
  local leaves={}
  local current_leaf=find_sub_sector(_model,_cam.pos)
  local pvs={}
  if(current_leaf) pvs=current_leaf.pvs
  visit_bsp(_model,_cam.pos,function(node,side,pos,visitor)
    local child=node.children[side]
    if child and child.pvs then
      -- pvs skips leaf 0
      local id=child.id-1
      -- use band to handle no entry in pvs case
      if band(pvs[id\32],0x0.0001<<(id&31))!=0 then
        add(leaves,child)
      end
    elseif child and _cam:is_visible(child.bbox) then
      visit_bsp(child,pos,visitor)
    end
  end)
  
  _cam:draw_faces(leaves)

  print(stat(1).."\n"..stat(0).."\nleaves:"..#leaves.."\nleaf:"..(current_leaf and current_leaf.id or -1),2,2,7)
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

function unpack_bbox()
  local x0,y0,z0=unpack(unpack_v3())
  local x1,y1,z1=unpack(unpack_v3())
  return {
    {x0,y0,z0},
    {x1,y0,z0},
    {x1,y0,z1},
    {x0,y0,z1},
    {x0,y1,z0},
    {x1,y1,z0},
    {x1,y1,z1},
    {x0,y1,z1}
  }
end

function unpack_map()
  local verts,planes,faces,leaves,nodes,models={},{},{},{},{},{}

  unpack_array(function()
    add(verts,unpack_v3())
  end)

  unpack_array(function()
    add(planes,{
      n=unpack_v3(),
      d=unpack_fixed()
    })
  end)

  unpack_array(function()
    local v={}
    local f=add(faces,{
      -- normal
      plane=unpack_ref(planes),
      side=mpeek()==0,
      verts=v
    })
    unpack_array(function(i)
      -- reference to vertex
      add(v,unpack_ref(verts))
    end)
    f.cp=v_dot(f.plane.n,v[1])    
  end)

  unpack_array(function(i)
    local f,pvs={},{}
    add(leaves,{
      -- get 0-based index of leaf
      -- leaf 0 is "solid" leaf
      id=i-1,
      contents=mpeek(),
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
  printh(#leaves)

  unpack_array(function()
    add(nodes,{
      plane=unpack_ref(planes), 
      bbox=unpack_bbox(),
      flags=mpeek(),
      children={
        [true]=unpack_variant(),
        [false]=unpack_variant()
      }
    })
  end)
  -- attach nodes/leaves
  for _,node in pairs(nodes) do
    local function attach_node(side,leaf)
      local refs=nodes
      if(leaf) refs=leaves
      local id=node.children[side]
      node.children[side]=refs[id]
    end
    attach_node(true,node.flags&0x1!=0)
    attach_node(false,node.flags&0x2!=0)
  end
  
  -- unpack models
  unpack_array(function()
    add(models,unpack_ref(nodes))
  end)

  -- get top level node
  return models[1],leaves
end