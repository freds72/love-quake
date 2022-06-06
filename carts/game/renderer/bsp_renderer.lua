-- collect and send BSP geometry to rasterizer
local bsp=require("bsp")
local ffi=require("ffi")
local lights=require("systems.lightstyles")
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

  -- active lights
  local _activeLights
  local colormap=mmap("gfx/colormap.lmp","uint8_t")
  -- allocate a big lightmap - to be reused
  local lightmap = ffi.new("unsigned char[?]", 32*32)
  local up={0,1,0}
  local visleaves,visframe,prev_leaf={},0

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
          480/2+(270*x/8),
          270/2-(270*y/8),
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
        vbo:reset()
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

    -- todo: bounded queue
    local _textureCache={}
    local function makeSwirlTextureProxy(texture,face,mip)
      local cache = _textureCache[texture]
      if not cache then
        -- create all entries
        local mips={}
        for i=0,3 do
          local scale=shl(1,i)
          local w,h=texture.width/scale,texture.height/scale
          mips[i]={
            scale=scale,
            width=w,
            height=h,
            ptr=ffi.new("unsigned char[?]",w*h)
          }
        end
        cache={
          mips=mips,
          -- frame time per mip
          frame={},
        }
        _textureCache[texture] = cache
      end
      local t=rasterizer.frame
      -- refresh image?
      if cache.frame[mip]~=t then
        -- update "snapshot" time
        cache.frame[mip]=t
  
        -- see: https://fdossena.com/?p=quakeFluids/i.md
        local texscale=shl(1,mip)
        local tw,th=texture.width/texscale,texture.height/texscale  
        local dst=cache.mips[mip].ptr
        local src=texture.mips[mip+1]
        t=time()*0.2
        for v=0,th-1 do
          local tv=v/th
          for u=0,tw-1 do
            local tu=u/tw
              -- 2* to make sure it rolls over the whole texture space
            local s,t=flr((tu + 0.1*sin(t+2*tv))*tw)%tw,flr((tv + 0.1*sin(t+2*tu))*th)%th
            dst[u] = src[s + t*tw]
          end          
          dst = dst + tw
        end
      end
      return cache.mips[mip]
    end

    local function makeTextureProxy(textures,ent,face,mip)
      -- create texture key
      local texture = textures[face.texinfo.miptex]  
      -- swirling texture? special handling
      if texture.swirl then
        return makeSwirlTextureProxy(texture,face,mip)
      end

      local key=mip
      if texture.sequence then
        local frames = ent.sequence==2 and texture.sequence.alt or texture.sequence.main
        local frame = flr(rasterizer.frame/15) % (#frames+1)        
        key=bor(key,frame*4)
      end
      for i=0,3 do
        local style=_activeLights[face.lightstyles[i+1]]
        if style then
          key=bor(key,shl(flr(255*style),i*8+8))
        end
      end

      local cached_tex=_textureCache[face]
      if cached_tex and cached_tex.mips[key] then
          return cached_tex.mips[key]
      end
      -- missing cache or missing mip
      if not cached_tex then
        cached_tex={mips={}}
        _textureCache[face] = cached_tex
      end

      -- animated?
      if texture.sequence then
        -- texture animation id are between 0-9 (lua counts between 0-8)
        local frames = ent.sequence==2 and texture.sequence.alt or texture.sequence.main
        local frame = flr(rasterizer.frame/15) % (#frames+1)
        texture = frames[frame]
      end
      
      local texscale=shl(1,mip)
      local imgw,imgh=max(face.width/texscale,1),max(face.height/texscale,1)
      cached_tex.mips[key] = setmetatable({
        scale=texscale,
        width=imgw,
        height=imgh
      },{
        __index=function(t,k)
          -- compute lightmap
          local w,h=face.lightwidth,face.lightheight  
          if face.lightofs then
            -- backup pointer
            local lm=lightmap
            for y=0,h-1 do
              for x=0,w-1 do
                local sample,idx=0,x + y*w
                for i=0,3 do
                  local scale = _activeLights[face.lightstyles[i+1]]
                  if scale and scale>0 then
                    local src = face.lightofs + i*w*h
                    sample = sample + scale * src[idx]
                  end
                end
                -- lightmap[x+y*w]=colormap.ptr[8+mid(63-flr(sample/4),0,63)*256]
                lm[x]=mid(63-flr(sample/4),0,63)
              end
              lm = lm + w
            end
          else
            local scale = texture.bright and 32 or (_activeLights[face.lightstyles[1]] or 0)
            ffi.fill(lightmap,w*h,mid(63-flr(scale),0,63))
          end
          -- mix with texture map
          local ptr=texture.mips[mip+1] 
          local tw,th=texture.width/texscale,texture.height/texscale
          local img=ffi.new("unsigned char[?]", imgw*imgh)
          -- backup pointer
          local dst = img
          for y=0,imgh-1 do
            for x=0,imgw-1 do
              --local s,t=(w*x)/imgw,(h*y)/imgh
              local s,t=texscale*x/16,texscale*y/16
              local s0,s1,t0,t1=flr(s),ceil(s),flr(t),ceil(t)
              local s0t0,s0t1,s1t0,s1t1=s0+t0*w,s0+t1*w,s1+t0*w,s1+t1*w
              s=s%1
              t=t%1
              -- todo: cache lightmaps when needed
              --print(s.." / "..t.." @ ".._lightw.." x ".._lighth)
              local a=lightmap[s0t0] * (1-s) + lightmap[s1t0] * s
              local b=lightmap[s0t1] * (1-s) + lightmap[s1t1] * s
              local lexel = a*(1-t) + b*t
              -- img[x+y*(w*16)]=colormap.ptr[8 + flr(lightmap[s0t0]*256)]--ptr[(x-face.umin)%tw+((y-face.vmin)%th)*tw]  -- colormap.ptr[8 + flr(lightmap[s0t0]*256)]
              local tx,ty=(x+flr(face.umin/texscale))%tw,(y+flr(face.vmin/texscale))%th
              dst[x]=colormap.ptr[ptr[tx+ty*tw] + flr(lexel)*256]
            end
            dst = dst + imgw
          end

          t.ptr=img
          return img
        end
      })
      return cached_tex.mips[key]
    end

    local function drawModel(cam,ent,textures,verts,leaves,lstart,lend)
        if not isBBoxVisible(cam,ent.absmins,ent.absmaxs) then
          return 
        end
  
        local m=cam.m
        -- todo: actually entity matrix is overkill as brush models never rotate
        v_cache:init(m_x_m(m,ent.m))
  
        local cam_pos=v_add(cam.origin,ent.origin,-1)
        local poly,f_cache,styles,bright_style={},{},{0,0,0,0},{0.5,0.5,0.5,0.5}
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
                    -- non moving textures are shifted in place
                    if not texture.swirl then
                      s_offset = s_offset-face.umin
                      t_offset = t_offset-face.vmin
                    end
                    for k=1,#vertref do
                        local v=verts[vertref[k]]
                        local a=v_cache:transform(v)
                        local code = vbo[a+VBO_OUTCODE]
                        outcode=band(outcode,code)
                        clipcode=clipcode + band(code,2)
                        -- compute uvs
                        local x,y,z,w=v[1],v[2],v[3],vbo[a+VBO_W]
                        vbo[a+VBO_U] = x*s[0]+y*s[1]+z*s[2]+s_offset
                        vbo[a+VBO_V] = x*t[0]+y*t[1]+z*t[2]+t_offset

                        if w>maxw then
                          maxw=w
                        end
                        poly[k] = a
                    end
        
                    if outcode==0 then
                        local n=#face.verts
                        if clipcode>0 then
                            poly,n = z_poly_clip(poly,n)
                        end
                        if n>2 then
                          -- texture mip
                          local mip=3-mid(flr(2048*maxw),0,3)
                          rasterizer.addSurface(poly,n,makeTextureProxy(textures,ent,face,mip))      
                        end
                    end
                end
            end
        end
    end
  
    
    return {
      update=function()
      end,
      draw=function(self,cam)
          -- nothing to draw (eg. no scene/world)
          if not cam.ready then
              return
          end
          -- update active light styles
          _activeLights = lights:get(rasterizer.frame)

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
              -- todo
            end
          end            
      end
    }
end
return BSPRenderer