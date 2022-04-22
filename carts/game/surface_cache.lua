-- surface = texture x lightmap x mip
local surface_cache=function(light_styles)
    local ffi=require('ffi')

    -- 
    local pool=require("recycling_pool")("surfaces",1,50)
    local active_surfaces={}

    local frame = 0
    local swirl_key=function()
    end
    local bright_key=function()
    end
    return {
        -- clean up entries not used in this frame
        start_frame=function()
        end,
        end_frame=function()
            frame = frame + 1
        end,
        bind=function(self,face,texture,mip)
            -- already registered?
            local idx = active_surfaces[face]
            if idx then
                return idx
            end
            --
            idx = pool:pop(face)
            active_surfaces[face]=idx

            if texture.sky then
                -- always render sky texture in full
                mip = 0
            end
            local texscale=shl(1,mip)
            local texw,texh=texture.width/texscale,texture.height/texscale
            -- dynamic texture?
            if texture.swirl then
                local cache = _texture_cache[texture]
                if not cache then
                    -- create entry
                    local mips={}
                    for i=0,3 do
                        local w,h=shr(texture.width,i),shr(texture.height,i)
                        add(mips,ffi.new("unsigned char[?]",w*h))
                    end
                    cache={
                        mips=mips,
                        -- frame time per mip
                        frame={}
                    }
                    _texture_cache[texture] = cache
                end
                mip = mip + 1
                _texptr=cache.mips[mip]
                local t=_params.t
                -- refresh image?
                if cache.frame[mip]~=t then
                    -- copy texture
                    cache.frame[mip]=t
        
                    -- see: https://fdossena.com/?p=quakeFluids/i.md
                    local src=texture.mips[mip]
                    t=t*0.8
                    for u=0,_texw-1 do
                        local tu=u/_texw
                        for v=0,_texh-1 do
                            local tv=v/_texh
                            -- 2* to make sure it rolls over the whole texture space
                            local s,t=flr((tu + 0.1*sin(t+(2*3.1415*tv)))*_texw)%_texw,flr((tv + 0.1*sin(t+(2*3.1415*tu)))*_texh)%_texh
                            _texptr[u + v*_texw] = src[s + t*_texw]
                        end
                    end
                end
            else
                _texptr=texture.mips[mip+1]
            end            
        end
    }
end

return texture_cache