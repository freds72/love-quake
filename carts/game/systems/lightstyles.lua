local LightStylesSystem={}
local light_styles={}
function LightStylesSystem:set(id, lightstyle)
    local style,min_light,max_light={},ord("a"),ord("z")
    for frame=0,#lightstyle-1 do
        local ch = sub(lightstyle,frame,frame+1)
        local scale = (ord(ch) - min_light) / (max_light - min_light)
        assert(scale>=0 and scale<=1, "ERROR - Light style: "..id.." invalid value: '"..ch.." @'..frame")

        add(style,scale)
    end
    light_styles[id] = style
end

return LightStylesSystem