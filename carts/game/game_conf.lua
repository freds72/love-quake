local GameConf={
    -- temporary
    root_path="D:\\Games\\quake\\id1",
    start_level="e1m1",    
    -- game key bindings
    keys = {
        up = {'w','up'},
        down = {'s','down'},
        left = {'a','left'},
        right = {'d','right'},
        action = {'space'}
    },
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
        "weapons"
    }     
}
return GameConf