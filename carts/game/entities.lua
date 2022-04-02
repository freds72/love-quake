local entities={}

local sub,add=string.sub,table.insert

-- quake "object notation" parser
-- loosely based of : https://gist.github.com/tylerneylon/59f4bcf316be525b30ab
local function parse_str(str, pos, val)
    val=val or ''
    if pos>#str then
        assert'end of input found while parsing string.'
    end
    local c=sub(str,pos,pos)
    -- end of string
    if c=='"' then
        return val,pos
    end
    return parse_str(str,pos+1,val..c)
end

local value_factory={
    angle=tonumber,
    wait=tonumber,
    delay=tonumber,
    spawnflags = tonumber,
    message = function(value)
        -- fixes \n into real \n!
        local msg = string.gsub(value, "\\n", "\n")
        return msg
    end,
    origin=function(value)
        local coords=split(value," ")
        -- conver to numbers
        for k,v in pairs(coords) do
            coords[k]=tonumber(v)          
        end
        return coords
    end
}

-- public values and functions.
function unpack_entities(str)
    pos=pos or 1
    if pos>#str then
        assert'reached unexpected end of input.'
    end
    local json,obj={}
    while pos<=#str do
        local first=sub(str,pos,pos)
        -- end of stream
        if not first then
            if stack or obj then
                assert'unclosed block'
            end
            break
        end

        if first=="{" then
            -- push
            obj={}
            stack={}
        elseif first=="\"" then
            local key
            key,pos=parse_str(str,pos+1)
            if not key then
                assert"invalid key/value pair"
            end
            add(stack,key)
            if #stack==2 then
                local k,v=stack[1],stack[2]      
                -- convert values to lua objects/numbers          
                local fn=value_factory[k]
                obj[k]=fn and fn(v) or v
                stack={}
            end
        elseif first=="}" then
            add(json,obj)
            obj=nil
            stack=nil
        end
        -- skip
        pos=pos+1	     
    end
    return json
end

return entities