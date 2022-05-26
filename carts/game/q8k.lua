
local gameConf = require("game_conf")
local stateSystem = require("engine.state_system")
local input=require("engine.input_system")
local world=require("systems.world")
local camera=require("systems.camera")(world)
local rasterizer=require("renderer.wireframe_rasterizer")
local renderer=require("renderer.bsp_renderer")(world, rasterizer)

function _init()
    local menuState = require("screens.menu")
    local arg1, arg2 = args()
    stateSystem:next(menuState, gameConf, arg1, arg2)
end

function _update()
    input:update()
    world:update()
    camera:update()
    stateSystem:update()
end

function _draw()
    cls()
        
    rasterizer.beginFrame()
    renderer:draw(camera)
    rasterizer.endFrame()

    stateSystem:draw()
end
