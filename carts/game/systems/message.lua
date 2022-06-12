local logging=require("engine.logging")
local MessageSystem={}
local ttl=0
local function format(str, ...)
    local args,n={},select("#",...)
    for i=1,n do
        args[i]=tostring(select(i,...))
    end
    return string.format(str,unpack(args))
end
  
function MessageSystem:say(msg,...)
    if not msg then
        self.msg=nil
        return
    end
    local txt = format(msg,...)
    -- avoid repeating messages
    if txt==self.msg then
      return
    end
    logging.info("MESSAGE - "..tostring(txt))
    self.msg = txt
    -- keep 3s on screen
    ttl = time() + 3
end
function MessageSystem:update()
    -- kill message
    if time()>ttl then
        self.msg = nil
    end
end

return MessageSystem