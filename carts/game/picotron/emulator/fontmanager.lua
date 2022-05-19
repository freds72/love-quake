local FontManager=function()
    local fonts={}
    return {
        -- data: paletted image
        -- layout: character layout
        -- width: character width (pixels)
        -- height: character height (pixels)
        load=function(self,id,data,layout,width,height)
            -- already registered
            if fonts[id] then
                return
            end
            -- 
            
        end
    }
end

return FontManager