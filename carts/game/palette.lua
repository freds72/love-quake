local palette={}
local ffi=require('ffi')

-- p8 compat
local band,bor,shl,shr,bnot=bit.band,bit.bor,bit.lshift,bit.rshift,bit.bnot

ffi.cdef[[
    #pragma pack(1)
    typedef struct { unsigned char r,g,b; } color_t;
]]    

local function read_palette()
    local palette = {}
    -- dump to bytes
    local data = love.filesystem.newFileData("gfx/palette.lmp")

    local src = ffi.cast('color_t*', data:getFFIPointer())
    for i=0,255 do
        -- swap colors
        local rgb = src[i]
        palette[i] = 0xff000000 + shl(rgb.b,16) + shl(rgb.g,8) + rgb.r
    end 
    return palette
end

local function read_colormap()
    local colormap = {}
    -- dump to bytes
    local data = love.filesystem.newFileData("gfx/colormap.lmp")

    local src = ffi.cast('uint8_t*', data:getFFIPointer())
    for i=0,256*64-1 do
        colormap[i] = src[i]
    end 
    return colormap
end

-- read the 
function palette.load()
    return read_palette(),read_colormap()
end

return palette