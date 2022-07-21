local ffi=require("ffi")
local logging=require("engine.logging")
local lights=require("systems.lightstyles")

local SurfaceCache=function(rasterizer, dynamic_lights)
    -- allocate a big lightmap - to be reused
    local lightmap = ffi.new("unsigned char[?]", 64*64)
    -- from conf?
    local colormap=mmap("gfx/colormap.lmp","uint8_t")
    -- contains a snapshot of the lightstlyes at given frame
    local activeLights


    -- keyed by face+key
    local textureCache={}
    -- see: https://en.wikipedia.org/wiki/Region-based_memory_management
    -- using region allocator to avoid memory fragmentation management
    local texturesByRegion={}
    local recyclesByRegion={}
    local regions={
      {block=4096, len=128},
      {block=8192, len=32},
      {block=16384, len=32},
      {block=32768, len=16},
      {block=65536, len=8}
    }
    -- allocate memory pages
    local total=0
    for k,region in pairs(regions) do
      region.ptr=ffi.new("uint8_t[?]",region.block*region.len)
      texturesByRegion[k]={}
      total = total + region.block*region.len
    end
    logging.info("Allocated surface cache: "..flr(total/1024).."kb")

    local function makeSwirlTextureProxy(texture,face,mip)
      local cache = textureCache[texture]
      if not cache then
        -- create all entries
        local mips={}
        for i=0,3 do
          local scale=shl(1,i)
          local w,h=texture.width/scale,texture.height/scale
          mips[i]={
            scale=scale,
            imgw=w,
            width=w,
            height=h,
            umin=flr(face.umin/scale),
            vmin=flr(face.vmin/scale),
            ptr=ffi.new("unsigned char[?]",w*h)
          }
        end
        cache={
          mips=mips,
          -- frame time per mip
          frame={},
        }
        textureCache[texture] = cache
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

    -- sky image
    local skymap=ffi.new("uint8_t[?]",128*128)
    local skytex_t
    local skytex={
      scale=16,
      width=128,
      height=128
    }
    local function makeSkyTextureProxy(texture,mip)  
      if skytex_t==rasterizer.frame then
        return skytex
      end

      skytex.umin=time()
      skytex.vmin=time()*1.5
      skytex.ptr=nil
      return setmetatable(
        skytex,
        {
          __index=function(t,k)
            -- copy skymap to texture
            local src,dst=texture.mips[1]+128,skymap
            for y=0,127 do
              ffi.copy(dst,src,128)
              dst = dst + 128
              src = src + 256
            end
            -- merge with second layer
            local src,dst=texture.mips[1],skymap
            for y=0,127 do
              for x=0,127 do
                if src[x]~=0 then
                  dst[x] = src[x]
                end
              end
              dst = dst + 128
              src = src + 256
            end

            skytex_t=rasterizer.frame

            t.ptr=skymap
            return skymap
          end
        }
      )
    end

    return {
      beginFrame=function()
        -- update active light styles
        activeLights = lights:get(rasterizer.frame)
      end,
      endFrame=function()        
        -- report number of regions that went full recycling in one frame
        for i=1,#regions do
          local usage,region=recyclesByRegion[i] or 0,regions[i]
          if usage>=region.len then
            logging.warn("Region: "..region.block.." overuse: "..usage.."/"..region.len)
          end
          recyclesByRegion[i]=0
        end
      end,
      -- active_lights: light index bitmask
      makeTextureProxy=function(self,texture,ent,face,mip,active_dynamic_lights)
        if texture.swirl then
          -- swirling texture? special handling
          return makeSwirlTextureProxy(texture,face,mip)
        elseif texture.sky then
          return makeSkyTextureProxy(texture,mip)
        end

        -- create texture key
        local key=mip
        if texture.sequence then
            local frames = ent.sequence==2 and texture.sequence.alt or texture.sequence.main
            local frame = flr(rasterizer.frame/15) % (#frames+1)        
            key=bor(key,frame*4)
        end
        for i=0,3 do
            local style=activeLights[face.lightstyles[i+1] ]
            if style then
              key=bor(key,shl(flr(255*style),i*8+8))
            end
        end

        local cached_tex=textureCache[face]
        if cached_tex and cached_tex[key] then
            return cached_tex[key]
        end

        -- missing cache or missing mip
        if not cached_tex then
            cached_tex={}
            textureCache[face] = cached_tex
        end

        -- animated?
        if texture.sequence then
            -- texture animation id are between 0-9 (lua counts between 0-8)
            local frames = ent.sequence==2 and texture.sequence.alt or texture.sequence.main
            local frame = flr(rasterizer.frame/15) % (#frames+1)
            texture = frames[frame]
        end
        
        local texscale=shl(1,mip)
        -- round up odd sized faces
        local imgw,imgh=max(flr(face.width/texscale+0.5),1),max(flr(face.height/texscale+0.5),1)
        local textureProxy = setmetatable({
            scale=texscale,
            width=imgw,
            height=imgh,
            umin=flr(face.umin/texscale),
            vmin=flr(face.vmin/texscale)
        },{
          __index=function(self,_)
            -- grab memory region
            local size,img = imgw * imgh
            for k,region in ipairs(regions) do
              if flr(size/region.block)==0 then
                local tbr=texturesByRegion[k]
                local block
                if #tbr==region.len then
                  block=del(tbr,1)
                  -- kill previous texture
                  textureCache[block.face][block.key]=nil
                  -- reuse
                  block.face = face
                  block.key = key
                  -- debug purposes
                  recyclesByRegion[k]=(recyclesByRegion[k] or 0)+1
                else
                  block = {
                    ptr = region.ptr + (#tbr) * region.block,
                    face = face,
                    key = key
                  }
                end
                -- track
                add(tbr,block)
                img = block.ptr
                break
              end
            end
            assert(img)

            -- compute lightmap
            local w,h,lightstyles=face.lightwidth,face.lightheight,face.lightstyles
            if face.lightofs then
                -- backup pointer
                local lm,src,size=lightmap,face.lightofs,w*h
                for y=0,h-1 do
                  for x=0,w-1 do
                      local sample,src=0,src + x + y*w
                      for i=0,3 do
                        local scale = activeLights[lightstyles[i+1]]
                        if scale and scale>0 then
                            sample = sample + scale * src[0]
                        end
                        src = src + size
                      end
                      -- lightmap[x+y*w]=colormap.ptr[8+mid(63-flr(sample/4),0,63)*256]                      
                      lm[x]=63-min(shr(sample,1),63)
                  end
                  -- next row
                  lm = lm + w
                end
            else
                local scale = texture.bright and 32 or (activeLights[lightstyles[1]] or 0)
                ffi.fill(lightmap,w*h,mid(63-flr(scale),0,63))
            end

            ffi.fill(lightmap,w*h,63)--mid(63-flr(scale),0,63))

            -- point light?
            -- mix with point lights
            if active_dynamic_lights then
              for i=1,8 do
                if band(active_dynamic_lights,shl(1,i-1))~=0 then
                  -- printh("active light: "..i.."/"..active_dynamic_lights)
                  local light = dynamic_lights[i]
                  -- projected radius
                  local dist,d=planes.dot(face.plane,light.origin)
                  -- visible from face?
                  if dist>face.cp~=face.side then
                    dist=d-dist
                    if not face.side then
                      dist=-dist
                    end
                    local texinfo = face.texinfo
                    local s,s_offset,t,t_offset = texinfo.s,texinfo.s_offset,texinfo.t,texinfo.t_offset  
                    local x,y,z=unpack(light.origin)
                    -- project point into face
                    local x0=x*s[0]+y*s[1]+z*s[2]+s_offset
                    local y0=x*t[0]+y*t[1]+z*t[2]+t_offset
                    x0=(x0-face.umin)/16+0.5
                    y0=(y0-face.vmin)/16+0.5
                    local r = light.radius * light.radius - dist * dist
                    if r>0 then
                      r=sqrt(r)/16
                      --printh(x0.." "..y0.." / "..w.." x "..h)
                      local lm=lightmap
                      for y=0,h-1 do
                        local rr=r*r-(y-y0)*(y-y0)
                        if rr>=0 then
                          local xx=sqrt(rr)
                          for x=max(flr(x0-xx),0),min(flr(x0+xx),w)-1 do
                            lm[x]=max(lm[x]-16,0)
                          end
                        end
                        lm=lm+w
                      end

                      -- draw circle
                      --[[
                      local function pset(x0,y0)
                        if x0>=0 and y0>=0 and x0<imgw and y0<imgh then
                          img[x0+y0*imgw] = colormap.ptr[15]
                        end                
                      end
                      local function circfill(x0,y0,r)
                        if r==0 then
                          return
                        end
                        x0=flr(x0)
                        y0=flr(y0)
                        local x,y=flr(r),0
                        local d=1-x

                        while x>=y do
                          pset(x0-x,y0+y)
                          pset(x0+x,y0+y)
                          pset(x0-x,y0-y)
                          pset(x0+x,y0-y)
                          y=y+1

                          if d<0 then
                            d=d+shl(y,1)+1
                          else
                            if x>=y then
                              pset(x0-y,y0+x)
                              pset(x0+y,y0+x)
                              pset(x0-y,y0-x)
                              pset(x0+y,y0-x)
                            end
                            x=x-1
                            d=d+shl(y-x+1,1)
                          end
                        end
                      end
                      circfill(x0,y0,r)
                      ]]
                    end
                  end
                end
              end
            end

            -- mix with texture map
            local ptr=texture.mips[mip+1] 
            local tw,th=texture.width/texscale,texture.height/texscale
            -- texture offset to be aligned with lightmap
            local xmin,ymin=self.umin,self.vmin
            -- backup pointer
            local dst = img
            local dt=texscale/16
            local t=dt/2
            for y=0,imgh-1 do
                local s=dt/2
                local t0,tfrac,t1=flr(t),t%1,ceil(t)
                for x=0,imgw-1 do
                  local s0,sfrac,s1=flr(s),s%1,ceil(s)
                  local s0t0,s0t1,s1t0,s1t1=s0+t0*w,s0+t1*w,s1+t0*w,s1+t1*w
                  -- todo: cache lightmaps when needed
                  --print(s.." / "..t.." @ ".._lightw.." x ".._lighth)
                  local a=lightmap[s0t0] * (1-sfrac) + lightmap[s1t0] * sfrac
                  local b=lightmap[s0t1] * (1-sfrac) + lightmap[s1t1] * sfrac
                  local lexel = a*(1-tfrac) + b*tfrac
                  local tx,ty=(x+xmin)%tw,(y+ymin)%th
                  --dst[x]=8+8*mip
                  dst[x]=colormap.ptr[ptr[tx+ty*tw] + flr(lexel)*256]
                  --dst[x]=colormap.ptr[15 + flr(lexel)*256]
                  s = s + dt
                end
                dst = dst + imgw
                t = t + dt
            end

            self.ptr=img
            return img
          end
        })
        --cached_tex[key] = textureProxy
        return textureProxy
      end,
      stats=function(self)
        local s=""
        for i=1,#texturesByRegion do
          local tbr=texturesByRegion[i]
          s=s.."region: "..regions[i].block.." usage:"..(#tbr).."/"..regions[i].len.." "..(recyclesByRegion[i] or 0)
          s=s.."\n"
        end

        return s
      end
    }
end
return SurfaceCache
