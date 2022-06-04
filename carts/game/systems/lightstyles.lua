local LightStylesSystem={}
local light_styles={}
local current_lights={}
-- update light style
function LightStylesSystem:set(id, lightstyle)
    assert(id~=255,"Invalid lightstyle id: "..id)

    local style,min_light,max_light={},ord("a"),ord("z")
    for frame=0,#lightstyle-1 do
        local ch = sub(lightstyle,frame,frame+1)
        local scale = (ord(ch) - min_light) / (max_light - min_light)
        assert(scale>=0 and scale<=1, "ERROR - Light style: "..id.." invalid value: '"..ch.." @'..frame")

        add(style,scale)
    end
    light_styles[id] = style
end

-- return lights styles at given frame
function LightStylesSystem:get(frame)
    -- change light every 0.1s
    for i,lightstyle in pairs(light_styles) do
        local frame = flr(frame/6) % #lightstyle
        --print("light style @"..lightstyle.."["..frame.."]")
        current_lights[i] = lightstyle[frame + 1]
    end
    return current_lights
end

return LightStylesSystem