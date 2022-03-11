local server={}
-- mimic quake separation between server (game logic) & client (rendering)

local _player

local player_mins = {-16, -16, -24}
local player_maxs = {16, 16, 32}
local STEPSIZE = 18

local function player_move()
end

local function fly_move()
    local blocked = 0
    
    -- 
    for i=1,3 do

    end
end

-- SV_RunCmd
function server.run()
    _player.pre_think()
    _player.think()

    -- compute move box
    -- collect all physical entities touching move box    
    local blocking={
        world
    }
    query_entities(move_box, blocking)
    
    -- player move
    -- query player position (water/ground/...)
    local origin = v_add(_player.origin, make_v(player_mins, _player.mins))
    local pmove = {
        origin = origin,
        velocity = v_clone(_player.velocity),
        angles = v_clone(_player.angles),
        physents = {_world.model},
        mins = v_add(origin, {-256,-256,-256}),
        maxs = v_add(origin, {256,256,256})
    }
    

    fly_move(blocking)
end



return server