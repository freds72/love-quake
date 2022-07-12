
local stateSystem = require("engine.state_system")
local input=require("engine.input_system")
local world=require("systems.world")
local camera=require("systems.camera")(world)
local particles=require("systems.particles")
local messages=require("systems.message")
local rasterizer=require("renderer.span_rasterizer")
--local rasterizer=require("renderer.wireframe_rasterizer")
local renderer=require("renderer.bsp_renderer")(world, rasterizer)

-- global "pluggable" components
_components = {}

function _init()
    -- blend table
    _colormap=mmap("gfx/colormap.png")
    blend(_colormap,31)

    local arg1, arg2 = args()
    stateSystem:next("screens.play", arg1, arg2)

    profiler = require("lib.profile") 
    --profiler.start()
end

function _update()
    input:update()
    messages:update()
    world:update()
    particles:update()
    camera:update()
    stateSystem:update()
end

function _draw()
    cls()
        
    -- something to display?
    rasterizer:beginFrame()

    -- 3d world
    renderer:beginFrame()
    renderer:draw(camera)
    renderer:endFrame()

    -- 
    particles:draw(rasterizer, camera)

    rasterizer:endFrame()

    stateSystem:draw()

    --local report = profiler.report(20)
    --printh(report)
    --profiler.reset()
end
