-- helper class to store and find entities
local Entities=function(entities)
    local new_entities={}
        -- transfer new entities to active list     
    function entities:preUpdate()
        -- any entities to create?
        for i=1,#new_entities do
            add(entities, new_entities[i])
        end
        new_entities = {}            
    end

    -- delayed add to list of active entities
    function entities:add(ent) 
        return add(new_entities, ent) 
    end

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