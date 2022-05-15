local fonts=function(root_path)
    local ffi=require 'ffi'
    local nfs = require( "lib/nativefs" )
    local palette = require("palette")()
    
    -- p8 compat
    local sub,max=string.sub,math.max   

    local all_chars={
        -- menu chars 1
        "\100\101\102\103\104\105\106\107\108\109\110\111\112\113\114\115",
        "\116\117\118\119\120\121\122\123\124\125\126\127\128\129\130\131",
        -- chars
        " !\"#$%&\'()*+,-./",
        "0123456789:;(=)?",
        "@ABCDEFGHIJKLMNO",
        "PQRSTUVWXYZ[\\]^_",
        "`abcdefghijklmno",
        "pqrstuvwxyz{|}~\008"
    }
    local char_index,alt_char_index={},{}
    for k,chars in pairs(all_chars) do
        for i=1,#chars do
            local ch = sub(chars,i,i)
            char_index[ch]=love.graphics.newQuad((i-1)*8,(k-1)*8,8,8,16*8,16*8)
            alt_char_index[ch]=love.graphics.newQuad((i-1)*8,(k-1)*8 + 64,8,8,16*8,16*8)
        end
    end

    -- load gfx.wad file

    local scale = 2                

    local flr=math.floor
    local transform = love.math.newTransform( )

    local data = love.filesystem.newFileData("fonts/conchars.lmp")
    local src = ffi.cast("unsigned char*",data:getFFIPointer())

    -- decode image
    local imagedata = love.image.newImageData(16*8,16*8)
    local image     = love.graphics.newImage(imagedata,{linear=true, mipmaps=false})
    image:setFilter('nearest','nearest')        
    local dst = ffi.cast('uint32_t*', imagedata:getFFIPointer()) 
    for i=0,16*8*16*8-1 do
        local col = src[i]
        dst[i] = col==0 and 0x0 or palette.hw[col]
    end
    image:replacePixels(imagedata)        
    
    return {
        -- print text using bitmap font
        print=function(s,x,y)
            love.graphics.setColor(1,1,1)
            local sx,sy=x,y
            local alt=false
            for i=1,#s do
                local ch=sub(s,i,i)
                if ch=="\n" then
                    sy = sy + 8 * scale
                    sx = x
                elseif ch=="\b" then
                    alt = not alt
                else
                    local quad=(alt and alt_char_index or char_index)[ch]
                    -- display placeholder for unknown chars
                    quad = quad or alt_char_index["?"]
                    love.graphics.draw(image, quad, transform:reset():translate(sx,sy):scale(2,2))
                    sx = sx + 8 * scale
                end
            end
        end,
        -- return text width/height
        size=function(s)
            local w,h=0,0
            local sx,sy=0,0
            for i=1,#s do
                local ch=sub(s,i,i)
                if ch=="\n" then
                    sy = sy + 8 * scale
                    sx = 0
                else
                    sx = sx + 8 * scale
                end
                w = max(w,sx)
                h = max(h,sy)
            end                    
            return w,h
        end
    }
end
return fonts