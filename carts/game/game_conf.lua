local GameConf={
    -- physics
    gravity_z = 18,
    -- display
    fov = 110,
    -- temporary
    root_path="D:\\Games\\quake\\id1",
    start_level="start",    
    -- game key bindings
    keys = {
        up = {'w','up'},
        down = {'s','down'},
        left = {'a','left'},
        right = {'d','right'},
        jump = {'space'},
        fire = {'lmb'},
        action = {'rmb','e'},
        ok = {'space'}
    },
    mouse_speed=0.3,
    -- supported entities & various "programs"
    progs={
        "world",
        "triggers",
        "buttons",
        "doors",
        "lights",
        "walls",
        "player",
        "items",
        "misc",
        "shambler",
        "zombie",
        "soldier",
        "weapons",
        "platforms"
    }     
}

-- load user conf (if any)
local status, user_conf = pcall(require, "user_conf")
if status then
    -- merge with standard conf
    for k,v in pairs(user_conf) do
        printh("Found setting override: "..k)
        GameConf[k] = v
    end        
end
return GameConf