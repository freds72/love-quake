-- collect and send BSP geometry to rasterizer
local bsp=require("bsp")
local ffi=require("ffi")
local BSPRenderer=function(world,rasterizer)
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
  local surfaceCache = require("renderer.surface_cache")(rasterizer)

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

  function mode7(x0,y0,x1)	
    -- sky normal in camera space
    local n,d=_params.sky,_params.sky_distance
    local htw,offsetx,offsety=_texw/2,_params.t*32,_params.t*24
    local texscale = _texscale * 16
    for x=x0,x1 do
      -- intersection with sky plane
      local e={-(x-480/2)/270,-1,(y0-270/2)/270}
      local ne=v_dot(n,e)
      if ne~=0 then
        -- simili fisheye
        -- ne=ne*ne
        -- project point back into world space
        local p=m_inv_x_v(_viewmatrix,v_scale(e,d/ne))
        -- front 
        local s,t=flr((p[1]+offsetx)/texscale)%htw,flr((p[2]+offsety)/texscale)%_texh
        local coloridx=_colormap[_texptr[s+t*_texw]]
        if coloridx==0 then
          -- background
          local s,t=flr((p[1]+offsetx/2)/texscale)%htw + htw,flr((p[2]+offsety/2)/texscale)%_texh
          coloridx=_colormap[_texptr[s+t*_texw]]
        end
        _backbuffer[x+y0*480]=_palette[coloridx]
      end
    end
  end
    
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
          -- front 
          s,t=p[1],p[2]
        end

        idx=vbo:pop(ax,ay,az,480/2+270*ax*w,270/2-270*ay*w,w,code,s,t)
        self.cache[v]=idx
      end
      return idx
    end
  }

    local function collect_entities(entities)
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
    local function collect_leaves(cam,root,leaves)
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

    local function drawModel(cam,ent,textures,verts,leaves,lstart,lend)
        if not isBBoxVisible(cam,ent.absmins,ent.absmaxs) then
          return 
        end
  
        local m=cam.m
        -- todo: entity matrix is overkill as brush models never rotate
        v_cache:init(m_x_m(m,ent.m))
        v_cache_sky:init(m_x_m(m,ent.m),cam.origin)
        vbo:reset()

        local cam_pos=v_add(cam.origin,ent.origin,-1)
        local poly,f_cache={},{}
        for i=lstart,lend do
            local leaf = leaves[i]
            for j=1,#leaf do
                local face = leaf[j]
                if not f_cache[face] and planes.dot(face.plane,cam_pos)>face.cp~=face.side then
                    -- mark visited
                    f_cache[face]=true
                    local vertref,texinfo,outcode,clipcode,maxw=face.verts,face.texinfo,0xffff,0,-math.huge
                    local s,s_offset,t,t_offset=texinfo.s,texinfo.s_offset,texinfo.t,texinfo.t_offset  
                    local texture=textures[texinfo.miptex]
                    if texture.sky then
                      maxw=1
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
                          local texpxy=surfaceCache:makeTextureProxy(texture,ent,face,mip)
                          rasterizer.addSurface(poly,n,texpxy)      
                        end
                    end
                end
            end
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
    
    return {
      beginFrame=function()
          surfaceCache:beginFrame()
      end,
      endFrame=function()
      end,
      draw=function(self,cam)
          -- nothing to draw (eg. no scene/world)
          if not cam.ready then
              return
          end
          
          -- refresh visible set
          local world_entity = world.entities[1]
          local main_model = world_entity.model
          local resources = world.level.model
          local leaves = collect_leaves(cam,main_model.hulls[1],resources.leaves)
          -- world entity
          drawModel(cam,world_entity,resources.textures,resources.verts,leaves,1,#leaves)

          -- visible entities
          local visents = collect_entities(world.entities)
          
          for i=1,#visents do
            local ent=visents[i]
            local m = ent.model
            -- todo: find out a better way to detect type
            if m.leaf_start then
              local resources = ent.resources or resources
              drawModel(cam,ent,resources.textures,resources.verts,resources.leaves,m.leaf_start,m.leaf_end)
            else
              drawAliasModel(
                cam,
                ent, 
                m,
                ent.skin,
                ent.frame)        
            end
          end            
      end
    }
end
return BSPRenderer