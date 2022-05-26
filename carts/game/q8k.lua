
local gameConf = require("game_conf")
local stateSystem = require("engine.state_system")
local input=require("engine.input_system")
local world=require("systems.world")

function _init()
    local menuState = require("screens.menu")
    local arg1, arg2 = args()
    stateSystem:next(menuState, gameConf, arg1, arg2)
end

function _update()
    input:update()
    world:update()
    stateSystem:update()
end

function _draw()
    cls()
    stateSystem:draw()
end
