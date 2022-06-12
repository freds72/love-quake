
local gameConf = require("game_conf")
local stateSystem = require("engine.state_system")
local input=require("engine.input_system")
local world=require("systems.world")
local camera=require("systems.camera")(world)
local messages=require("systems.message")
local rasterizer=require("renderer.span_rasterizer")
--local rasterizer=require("renderer.wireframe_rasterizer")
local renderer=require("renderer.bsp_renderer")(world, rasterizer)

-- some globals (temp)
_components={}

function _init()
    -- blend table
    _colormap=mmap("gfx/colormap.png")
    blend(_colormap,31)

    local menuState = require("screens.play")
    local arg1, arg2 = args()
    stateSystem:next(menuState, gameConf, arg1, arg2)

    _components["particles"] = require("systems.particles")(rasterizer)

    profiler = require("lib.profile") 
    --profiler.start()
end

function _update()
    input:update()
    messages:update()
    world:update()
    for _,c in pairs(_components) do
        c:update(1/60)
    end
    camera:update()
    stateSystem:update()
end

function _draw()
    cls()
        
    -- something to display?
    rasterizer:beginFrame()
    renderer:beginFrame()
    renderer:draw(camera)
    renderer:endFrame()
    for _,c in pairs(_components) do
        c:draw(camera)
    end
    rasterizer:endFrame()

    stateSystem:draw()

    --local report = profiler.report(20)
    --printh(report)
    --profiler.reset()
end
