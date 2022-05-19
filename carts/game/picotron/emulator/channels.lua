-- thread communication channels
local lt = love.thread
local Channels={
    vsync = lt.getChannel ("vsync"),
    onload = lt.getChannel("load"),
    onkill = lt.getChannel("kill"),
    onfileRequest = lt.getChannel("filerequest"),
    onfileResponse = lt.getChannel("fileresponse")    
}
return Channels
