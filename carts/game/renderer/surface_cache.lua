local ffi=require("ffi")
local logging=require("engine.logging")
local lights=require("systems.lightstyles")

local SurfaceCache=function(rasterizer)
    -- allocate a big lightmap - to be reused
    local lightmap = ffi.new("unsigned char[?]", 64*64)
    -- from conf?
    local colormap=mmap("gfx/colormap.lmp","uint8_t")
    local activeLights

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

    return {
      beginFrame=function()
        -- update active light styles
        activeLights = lights:get(rasterizer.frame)
      end,
      endFrame=function()
      end,
      makeTextureProxy=function(self,textures,ent,face,mip)
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
            local style=activeLights[face.lightstyles[i+1]]
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
                    local scale = activeLights[face.lightstyles[i+1]]
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
                local scale = texture.bright and 32 or (activeLights[face.lightstyles[1]] or 0)
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
    }
end
return SurfaceCache
