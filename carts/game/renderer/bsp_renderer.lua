-- collect and send BSP geometry to rasterizer
local bsp=require("bsp")
local ffi=require("ffi")
local BSPRenderer=function(world,rasterizer, lights)
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
    
  -- vertex buffer "cache"
  local vbo = rasterizer.vbo
  local vboptr = vbo:ptr(0)
  local up={0,1,0}
  local visleaves,visframe,prev_leaf={},0
  
  -- surface (eg lighted texture) cache
  local surfaceCache = require("renderer.surface_cache")(rasterizer, lights)

  local h_ratio,v_ratio=(480-480/2)/270,(270-270/2)/270
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
    local p0=vboptr + v0
    local d0=p0[VBO_3] - 8
    for i=1,nv do
      local side=d0>0
      if side then
        res[#res+1]=v0
      end
      local v1=v[i]
      local p1=vboptr + v1
      local d1=p1[VBO_3]-8
      -- not same sign?
      if (d1>0)~=side then
        local t = d0/(d0-d1)
        local x,y,z=
          lerp(p0[VBO_1],p1[VBO_1],t),
          lerp(p0[VBO_2],p1[VBO_2],t),
          lerp(p0[VBO_3],p1[VBO_3],t)
        res[#res+1]=vbo:pop(          
          x,y,z,
          480/2+(270*x/8),
          270/2-(270*y/8),
          1/8,
          0,
          lerp(p0[VBO_U],p1[VBO_U],t),
          lerp(p0[VBO_V],p1[VBO_V],t))
      end
      v0=v1
      p0=p1
      d0=d1
    end
    return res,#res
  end

  local function isBBoxVisible(cam,mins,maxs)
    local m,outcode=cam.m,0xffff
    local m1,m5,m9,m13,m2,m6,m10,m14,m3,m7,m11,m15=m[1],m[5],m[9],m[13],m[2],m[6],m[10],m[14],m[3],m[7],m[11],m[15]
    for i=0,7 do
      local x,y,z=
        band(i,1)~=0 and maxs[1] or mins[1],
        band(i,2)~=0 and maxs[2] or mins[2],
        band(i,4)~=0 and maxs[3] or mins[3]
      local code,ax,az,ay=0,m1*x+m5*y+m9*z+m13,m2*x+m6*y+m10*z+m14,m3*x+m7*y+m11*z+m15
  
      -- znear=8
      if az<8 then code=2 end
      --if az>2048 then code|=1 end
      if ax>h_ratio*az then code = code + 4
      elseif ax<-h_ratio*az then code = code + 8 end
      if ay>v_ratio*az then code = code + 16
      elseif ay<-v_ratio*az then code = code + 32 end
      outcode = band(outcode, code)
      if outcode == 0 then
        return true
      end
    end
  end

  -- polygon clipping against BSP hull
  local empty_set={}
  function poly_clip(node,v)
    -- degenerate case
    if #v<3 then
      return empty_set,empty_set
    end
    local dists,side={},0
    for i=1,#v do
      local d,dist=planes.dot(node.plane,v[i])  
      d=d-dist
      side=bor(side,d>0 and 1 or 2)
      dists[i]=d
    end
    -- early exit tests (eg. no clipping)
    if side==1 then return v,empty_set end
    if side==2 then return empty_set,v end
    -- straddling
    -- copy original face reference
    local res,out_res,v0,d0={face=v.face},{face=v.face},v[#v],dists[#v]
    for i=1,#v do
      local v1,d1=v[i],dists[i]
      if d0<=0 then
        out_res[#out_res+1]=v0
      end
      if (d1>0)~=(d0>0) then
        -- add middle point
        local v2=v_lerp(v0,v1,d0/(d0-d1))
        out_res[#out_res+1]=v2
        -- add to end
        res[#res+1]=v2
      end
      if d1>0 then
        res[#res+1]=v1
      end    
      v0=v1
      d0=d1
    end
  
    return res,out_res
  end
  
  local bsp_clip
  bsp_clip=function(node,poly,out)
    -- use hyperplane to split poly
    local res_in,res_out=poly_clip(node,poly)
    if #res_in>0 then
      local child=node[true]
      if child.contents then
        if child.contents~=-2 then
          add(out,res_in)
        end
      else
        bsp_clip(child,res_in,out)
      end
    end
    if #res_out>0 then
      local child=node[false]
      if child.contents then
        if child.contents~=-2 then
          add(out,res_out)
        end
      else   
        bsp_clip(child,res_out,out)
      end
    end
  end

  -- collect bps leaves in order
  local collect_bsp
  local function collect_leaf(cam,child)
    if child.visframe==visframe then
      if child.contents then       
        if isBBoxVisible(cam,child.mins,child.maxs) then
          visleaves[#visleaves+1]=child
        end
      else
        collect_bsp(cam,child)
      end
    end
  end    
  collect_bsp=function(cam,node)
    local side=planes.isFront(node.plane,cam.origin)
    collect_leaf(cam,node[side])
    collect_leaf(cam,node[not side])
  end

  local v_cache={
    cache={},
    init=function(self,m)
        self.m = m
        local cache=self.cache
        for k in pairs(cache) do
          cache[k]=nil
        end
    end,
    transform=function(self,v)
      -- find vbo (if any)
      local idx=self.cache[v]
      if not idx then
        local m,code,x,y,z=self.m,0,v[1],v[2],v[3]
        local ax,az,ay=m[1]*x+m[5]*y+m[9]*z+m[13],m[2]*x+m[6]*y+m[10]*z+m[14],m[3]*x+m[7]*y+m[11]*z+m[15]

        -- znear=8
        if az<8 then code=2 end
        --if az>2048 then code|=1 end
        if ax>h_ratio*az then code = code + 4
        elseif ax<-h_ratio*az then code = code + 8 end
        if ay>v_ratio*az then code = code + 16
        elseif ay<-v_ratio*az then code = code + 32 end
        -- save world space coords for clipping
        -- to screen space
        local w=1/az
        idx=vbo:pop(ax,ay,az,480/2+270*ax*w,270/2-270*ay*w,w,code)
        self.cache[v]=idx
      end
      return idx
    end
  }

  local v_cache_sky={
    cache={},
    init=function(self,m,origin)
      self.m = m
      local cache=self.cache
      for k in pairs(cache) do
        cache[k]=nil
      end      
      local n=m_x_n(m,{0,0,-1})
      local n0=m_x_v(m,{0,0,2048+origin[3]})      
      self.sky = n
      self.sky_distance = v_dot(n,n0)
      self.t = time()
      self.z = origin[3]      
    end,
    transform=function(self,v)
      -- find vbo (if any)
      local idx=self.cache[v]
      if not idx then
        local m,code,x,y,z=self.m,0,v[1],v[2],v[3]
        local ax,az,ay=m[1]*x+m[5]*y+m[9]*z+m[13],m[2]*x+m[6]*y+m[10]*z+m[14],m[3]*x+m[7]*y+m[11]*z+m[15]

        -- znear=8
        if az<8 then code=2 end
        --if az>2048 then code|=1 end
        if ax>h_ratio*az then code = code + 4
        elseif ax<-h_ratio*az then code = code + 8 end
        if ay>v_ratio*az then code = code + 16
        elseif ay<-v_ratio*az then code = code + 32 end
        -- save world space coords for clipping
        -- to screen space
        local w=1/az

        -- intersection with sky plane
        local e={-ax*w,-1,-ay*w}
        local ne,s,t=v_dot(self.sky,e),0,0
        if ne~=0 then
          -- project point back into world space
          local p=m_inv_x_v(self.m,v_scale(e,self.sky_distance/ne))
          -- u/v coords
          s,t=p[1],p[2]
        end

        idx=vbo:pop(ax,ay,az,480/2+270*ax*w,270/2-270*ay*w,w,code,s,t)
        self.cache[v]=idx
      end
      return idx
    end
  }

  -- BSP function helpers
    local function collectVisibleEntities(entities)
      local ents={}
      -- skip world
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
    end
    local function collectVisibleLeaves(cam,root,leaves)
        local current_leaf=bsp.locate(root,cam.origin)
        
        if not current_leaf or not current_leaf.pvs then
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
        collect_bsp(cam,root)
        return visleaves  
    end

    -- collects all leaves within a radius
    local function collectLightedLeaves(idx,pos,radius,node,out)
        if node.contents then
            if node.contents~=-2 then
                -- printh("dist:"..dist.." faces:"..#node)
                local turned_on=out[node] or 0
                out[node] = bor(turned_on, shl(1,idx-1))
            end
            return
        end
      
        local dist,d=planes.dot(node.plane,pos)
        -- not touching plane
        if dist > d + radius then
          collectLightedLeaves(idx,pos,radius,node[true],out)
          return
        end
        -- not touching plane (other side)
        if dist < d - radius then
          collectLightedLeaves(idx,pos,radius,node[false],out)
          return
        end
        
        -- overlapping plane
        collectLightedLeaves(idx,pos,radius,node[true],out)
        collectLightedLeaves(idx,pos,radius,node[false],out)     
    end
    
    -- find all leaves touched by lights
    function collectLights(node)
        local out={}
        lights:visit(collectLightedLeaves,node,out)
        return out
    end
    
    local function drawModel(cam,ent,textures,verts,leaves,lstart,lend,lighted_leaves)
        if not isBBoxVisible(cam,ent.absmins,ent.absmaxs) then
          return 
        end
  
        local m=cam.m
        -- todo: entity matrix is overkill as brush models never rotate
        local viewm=m_x_m(m,ent.m)
        v_cache:init(viewm)
        v_cache_sky:init(viewm,cam.origin)
        vbo:reset()

        local cam_pos=v_add(cam.origin,ent.origin,-1)
        local poly,f_cache={},{}
        for i=lstart,lend do
            local leaf = leaves[i]
            -- dynamic lights bitmask (e.g. enabled lights for this leaf)
            local active_lights = lighted_leaves and lighted_leaves[leaf] or 0
            for j=1,#leaf do
                local face = leaf[j]
                if not f_cache[face] and planes.dot(face.plane,cam_pos)>face.cp~=face.side then
                    -- mark visited
                    f_cache[face]=true
                    local vertref,texinfo,outcode,clipcode,maxw=face.verts,face.texinfo,0xffff,0,-math.huge
                    local s,s_offset,t,t_offset=texinfo.s,texinfo.s_offset,texinfo.t,texinfo.t_offset  
                    local texture=textures[texinfo.miptex]
                    -- select the right "vertex shader"
                    if texture.sky then
                      for k=1,#vertref do
                          local v=verts[vertref[k]]
                          local a=v_cache_sky:transform(v)
                          -- get vertex pointer
                          local pa=vboptr + a
                          local code = pa[VBO_OUTCODE]
                          outcode=band(outcode,code)
                          clipcode=clipcode + band(code,2)
                          poly[k] = a
                      end
                    else
                      for k=1,#vertref do
                        local v=verts[vertref[k]]
                        local a=v_cache:transform(v)
                        -- get vertex pointer
                        local pa=vboptr + a
                        local code = pa[VBO_OUTCODE]
                        outcode=band(outcode,code)
                        clipcode=clipcode + band(code,2)
                        -- compute uvs
                        local x,y,z,w=v[1],v[2],v[3],pa[VBO_W]
                        pa[VBO_U] = x*s[0]+y*s[1]+z*s[2]+s_offset
                        pa[VBO_V] = x*t[0]+y*t[1]+z*t[2]+t_offset

                        if w>maxw then
                          maxw=w
                        end
                        poly[k] = a
                      end                      
                    end

                    if outcode==0 then
                        local n=#face.verts
                        if clipcode>0 then
                            poly,n = z_poly_clip(poly,n)
                        end
                        if n>2 then
                          -- texture mip
                          local mip=3-mid(flr(1536*maxw),0,3)
                          rasterizer.addSurface(poly,n,surfaceCache:makeTextureProxy(texture,ent,face,mip,active_lights),debugColor)      
                        end
                    end
                end
            end
        end
    end

    -- debug function
    local function drawLeaves(cam,ent,verts,leaves)

      local m=cam.m
      -- todo: entity matrix is overkill as brush models never rotate
      v_cache:init(m_x_m(m,ent.m))
      vbo:reset()

      local cam_pos=v_add(cam.origin,ent.origin,-1)
      local poly,f_cache={},{}
      for leaf in pairs(leaves) do
        for j=1,#leaf do
          local face = leaf[j]
          if not f_cache[face] and planes.dot(face.plane,cam_pos)>face.cp~=face.side then
              -- mark visited
              f_cache[face]=true
              local vertref,outcode,clipcode,maxw=face.verts,0xffff,0,-math.huge
              for k=1,#vertref do
                local v=verts[vertref[k]]
                local a=v_cache:transform(v)
                -- get vertex pointer
                local pa=vboptr + a
                local code = pa[VBO_OUTCODE]
                outcode=band(outcode,code)
                clipcode=clipcode + band(code,2)

                poly[k] = a
              end                      

              if outcode==0 then
                  local n=#face.verts
                  if clipcode>0 then
                      poly,n = z_poly_clip(poly,n)
                  end
                  if n>2 then
                    local a0=poly[n]
                    for i=1,n do
                      local a1=poly[i]
                      -- get vertex pointer
                      local p0 = vboptr + a0
                      local p1 = vboptr + a1
                      line(p0[VBO_X],p0[VBO_Y],p1[VBO_X],p1[VBO_Y],15)
                      a0=a1
                    end                    
                  end
              end
          end
        end
      end
    end

    -- clip against world
    local function drawMovingModel(cam,hull,ent,textures,verts,leaves,lstart,lend)
      if not isBBoxVisible(cam,ent.absmins,ent.absmaxs) then
        return
      end

      -- does entity clip world?
      local node=bsp.firstNode(hull,ent)
      if node then
        -- yes: clip brush
        local out={}
        local out,brush_verts={},{}
        for j=lstart,lend do
          local leaf=leaves[j]    
          for i=1,#leaf do
            -- face index
            local face=leaf[i]     
            local poly,vertref={face=face},face.verts
            for k=1,#vertref do
              local vi=vertref[k]
              local v=brush_verts[vi]
              if not v then
                -- "move" brush        
                v=v_add(verts[vi],ent.origin)
                brush_verts[vi]=v
              end
              poly[k]=v
            end
            -- clip against world
            bsp_clip(node,poly,out)
          end
        end 
        
        -- 
        v_cache:init(cam.m)
        vbo:reset()
                        
        -- cam pos in model space (eg. shifted)
        local cam_pos=v_add(cam.origin,ent.origin,-1)
        local ox,oy,oz=unpack(ent.origin)

        -- all "faces"
        local poly={}
        for i,poly_verts in pairs(out) do
          -- dual sided or visible?
          local face=poly_verts.face
          if planes.dot(face.plane,cam_pos)>face.cp~=face.side then            
            local n,texinfo,outcode,clipcode,maxw=#poly_verts,face.texinfo,0xffff,0,-math.huge
            local s,s_offset,t,t_offset=texinfo.s,texinfo.s_offset,texinfo.t,texinfo.t_offset  
            local texture=textures[texinfo.miptex]
            -- rebase texture (moving brush coords are absolute)
            s_offset = s_offset - (ox*s[0]+oy*s[1]+oz*s[2])
            t_offset = t_offset - (ox*t[0]+oy*t[1]+oz*t[2])
            
            for k=1,n do
              local v=poly_verts[k]
              local a=v_cache:transform(v)
              -- get vertex pointer
              local pa = vboptr + a
              local code = pa[VBO_OUTCODE]
              outcode=band(outcode,code)
              clipcode=clipcode + band(code,2)
              -- compute uvs
              local x,y,z,w=v[1],v[2],v[3],pa[VBO_W]
              pa[VBO_U] = x*s[0]+y*s[1]+z*s[2]+s_offset
              pa[VBO_V] = x*t[0]+y*t[1]+z*t[2]+t_offset

              if w>maxw then
                maxw=w
              end
              poly[k] = a
            end                      

            if outcode==0 then
              if clipcode>0 then
                  poly,n = z_poly_clip(poly,n)
              end
              if n>2 then
                -- texture mip
                local mip=3-mid(flr(1536*maxw),0,3)
                rasterizer.addSurface(poly,n,surfaceCache:makeTextureProxy(texture,ent,face,mip),62)      
              end
            end
          end
        end
      else
        -- no: regular draw
        drawModel(cam,ent,textures,verts,leaves,lstart,lend,15)
      end 
    end

    local function drawAliasModel(cam,ent,model,skin,frame_name)      
      -- check bounding box
      if not isBBoxVisible(cam,ent.absmins,ent.absmaxs) then
        return 
      end

      local skin = model.skins[skin]
      local frame = model.frames[frame_name]
      local uvs = model.uvs
      local faces = model.faces
      -- positions + normals are in the frame
      local verts, normals = frame.verts, frame.normals
      
      v_cache:init(m_x_m(cam.m,ent.m))
      local origin=ent.origin
      if ent.offset then
        -- visual offset?
        origin = v_add(origin,ent.offset)
      end
      local cam_pos=v_add(cam.origin,origin,-1)

      -- transform light vector into model space
      local light_n=m_inv_x_n(ent.m,{0,0.707,-0.707})

      for i=1,#faces,4 do    
        -- read vertex references
        local is_front,v0,v1,v2=faces[i],faces[i+1],faces[i+2],faces[i+3]
        local a0,a1,a2=
         v_cache:transform(verts[v0]),
         v_cache:transform(verts[v1]),
         v_cache:transform(verts[v2])
        -- store point addresses
        local poly={a0,a1,a2}
        -- work with direct offsets
        a0,a1,a2=
         vboptr + a0,
         vboptr + a1,
         vboptr + a2
        local outcode=band(0xffff,band(band(a0[VBO_OUTCODE],a1[VBO_OUTCODE]),a2[VBO_OUTCODE]))
        local clipcode=band(a0[VBO_OUTCODE],2)+band(a1[VBO_OUTCODE],2)+band(a2[VBO_OUTCODE],2)
        local uv0,uv1,uv2=uvs[v0],uvs[v1],uvs[v2]
        a0[VBO_U] = uv0.u + ((not is_front and uv0.onseam) and (skin.width / 2) or 0)
        a0[VBO_V] = uv0.v     
        a1[VBO_U] = uv1.u + ((not is_front and uv1.onseam) and (skin.width / 2) or 0)
        a1[VBO_V] = uv1.v     
        a2[VBO_U] = uv2.u + ((not is_front and uv2.onseam) and (skin.width / 2) or 0)
        a2[VBO_V] = uv2.v     

        if outcode==0 then
          -- ccw?
          local ax,ay=a1[VBO_X]-a0[VBO_X],a1[VBO_Y]-a0[VBO_Y]
          local bx,by=a1[VBO_X]-a2[VBO_X],a1[VBO_Y]-a2[VBO_Y]
          if ax*by - ay*bx<=0 then
            local n=3
            if clipcode>0 then
              poly,n = z_poly_clip(poly,n)
            end
            if n>2 then
              rasterizer.addSurface(poly,n,skin)    
            end
          end
        end
      end
    end

    -- debug bounding box
    local function drawBBox(cam,mins,maxs)
      local verts={
        {-1,-1,-1},
        { 1,-1,-1},
        { 1, 1,-1},
        {-1, 1,-1},
        {-1,-1,1},
        { 1,-1,1},
        { 1, 1,1},
        {-1, 1,1}}
      local faces={
        {1,2,6,5},
        {2,3,7,6},
        {3,4,8,7},
        {4,1,5,8},
        {1,2,3,4},
        {5,6,7,8}
      }
      local size=v_scale(v_add(maxs,mins,-1),0.5)
      local og=v_scale(v_add(maxs,mins),0.5)
      for k,vert in pairs(verts) do
        verts[k] = v_add(og,{
          vert[1] * size[1],
          vert[2] * size[2],
          vert[3] * size[3]
        })
      end

      v_cache:init(cam.m)

      for _,face in pairs(faces) do

        local a0,a1,a2,a3=
         v_cache:transform(verts[face[1]]),
         v_cache:transform(verts[face[2]]),
         v_cache:transform(verts[face[3]]),
         v_cache:transform(verts[face[4]])
        -- store point addresses
        local poly={a0,a1,a2,a3}
        -- work with direct offsets
        a0,a1,a2,a3=
         vboptr + a0,
         vboptr + a1,
         vboptr + a2,
         vboptr + a3
        local outcode=band(0xffff,band(band(band(a0[VBO_OUTCODE],a1[VBO_OUTCODE]),a2[VBO_OUTCODE]),a3[VBO_OUTCODE]))
        local clipcode=band(a0[VBO_OUTCODE],2)+band(a1[VBO_OUTCODE],2)+band(a2[VBO_OUTCODE],2)+band(a3[VBO_OUTCODE],2)

        if outcode==0 then
          local n=4
          if clipcode>0 then
            poly,n = z_poly_clip(poly,n)
          end

          local a0=poly[n]
          for i=1,n do
            local a1=poly[i]
            -- get vertex pointer
            local p0 = vboptr + a0
            local p1 = vboptr + a1
            line(p0[VBO_X],p0[VBO_Y],p1[VBO_X],p1[VBO_Y],15)
            a0=a1
          end
        end
      end
    end

    return {
      beginFrame=function()
          surfaceCache:beginFrame()
      end,
      endFrame=function()
        surfaceCache:endFrame()
      end,
      draw=function(self,cam)
        -- nothing to draw (eg. no scene/world)
        if not cam.ready then
            return
        end
        debugColor=12
        
        -- refresh visible set
        local world_entity = world.entities[1]
        local main_model = world_entity.model
        local resources = world.level.model
        local leaves = collectVisibleLeaves(cam,main_model.hulls[1],resources.leaves)
        -- collect point lights
        local lighted_leaves=collectLights(main_model.hulls[1])

        -- world entity
        drawModel(cam,world_entity,resources.textures,resources.verts,leaves,1,#leaves,lighted_leaves)

        -- visible entities
        local visents = collectVisibleEntities(world.entities)
        
        for i=1,#visents do
          local ent=visents[i]
          local m = ent.model
          -- todo: find out a better way to detect type
          if m.leaf_start then
            local resources = ent.resources or resources
            if ent.MOVING_BSP then
              drawMovingModel(cam,main_model.hulls[1],ent,resources.textures,resources.verts,resources.leaves,m.leaf_start,m.leaf_end)
              -- 
              -- drawBBox(cam,{ent.absmins[1],ent.absmins[2],ent.absmaxs[3]},v_add(ent.absmaxs,{0,0,1}))

            else
              drawModel(cam,ent,resources.textures,resources.verts,resources.leaves,m.leaf_start,m.leaf_end)
            end
          else
            drawAliasModel(
              cam,
              ent, 
              m,
              ent.skin,
              ent.frame)        
          end
        end   

        if false then
          for i=1,#world.entities do
            local ent=world.entities[i]
            -- todo: find out a better way to detect type
            if ent.SOLID_TRIGGER then
              drawBBox(cam, ent.absmins, ent.absmaxs)
            end
          end   
        end
        --print(surfaceCache:stats(),2,2,8)          
      end
    }
end
return BSPRenderer