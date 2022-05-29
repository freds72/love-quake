-- helper class to store and find entities
local Entities=function(entities)

    function entities:find(ent,property,value,filter)
        local matches={}
        for i=1,#entities do
            local other=entities[i]
            -- filter out "to be removed entities"
            if not other.free and ent~=other and other[property]==value then
                if not filter or other[filter] then
                    add(matches, other)
                end
            end
        end
        return matches
    end
    return entities
end
return Entities