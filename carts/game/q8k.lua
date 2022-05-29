
local gameConf = require("game_conf")
local stateSystem = require("engine.state_system")
local input=require("engine.input_system")
local world=require("systems.world")
local camera=require("systems.camera")(world)
local messages=require("systems.message")
local rasterizer=require("renderer.wireframe_rasterizer")
local renderer=require("renderer.bsp_renderer")(world, rasterizer)

-- some globals (temp)
_components={}

function _init()
    local menuState = require("screens.play")
    local arg1, arg2 = args()
    stateSystem:next(menuState, gameConf, arg1, arg2)
end

function _update()
    input:update()
    messages:update()
    world:update()
    camera:update()
    stateSystem:update()
end

function _draw()
    cls()
        
    -- something to display?
    rasterizer:beginFrame()
    renderer:draw(camera)
    rasterizer:endFrame()

    stateSystem:draw()
end
