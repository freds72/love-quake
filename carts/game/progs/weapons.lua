local weapons=function(progs)
    local weapons ={
        {model="progs/g_shot.mdl", fps_model="progs/v_shot.mdl", classname="weapon_shotgun",ammo="ammo_shells",gives=50},
        {model="progs/g_nail.mdl", fps_model="progs/v_nail.mdl", classname="weapon_nailgun",ammo="ammo_nails",gives=50},
        {model="progs/g_shot.mdl",fps_model="progs/v_shot2.mdl", classname="weapon_supershotgun",ammo="ammo_shells",gives=25},
    }
    for k,weapon in pairs(weapons) do
        local model,class,fps_model=weapon.model,weapon.classname,weapon.fps_model
        progs:precache_model(model)
        progs[weapon.classname]=function(self)
            self.SOLID_TRIGGER = true
            self.MOVETYPE_NONE = true
            self.skin = 1
            self.frame = "shot1"
            self.mangles = {0,0,self.angle or 0}
            -- set size and link into world
            progs:setmodel(self, model,{0,0,-24})
            --progs:drop_to_floor(self)
            
            self.nextthink = progs:time() + 0.1
            self.think=function()            
                self.mangles={0,0,progs:time()}
                self.nextthink = progs:time() + 0.01
            end 
            
            self.touch=function(other)
                if other.classname ~= "player" then
                    return
                end
    
                progs:remove(self)
    
                -- todo: sound
                progs:call(other,"switch_weapon",fps_model,50)
                
                -- linked actions?
                use_targets(self)
            end        
        end
    end
end
return weapons