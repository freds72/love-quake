-- programmatic contract between "programs" and the game engine
local logging = require("engine.logging")
local lightStyles = require("systems.lightstyles")
local rampStyles = require("systems.rampstyles")
local messages = require("systems.message")
local stateSystem = require("engine.state_system")
local gameState = require("systems.game_state")

-- misc effects (to be moved elsewhere?)
require("systems.particles_trail")
require("systems.particles_blast")
require("systems.follow_light")
require("systems.fading_light")
require("systems.liquid")

local ProgsAPI=function(modelLoader, models, world, collisionMap)
    local precache_models={}
  
    return {
      -- secrets
        total_secrets = 0,
        found_secrets = 0,
        lightstyle=function(self, id, lightstyle)
          lightStyles:set(id, lightstyle)
        end,
        rampstyle=function(self,id,ramp)
          rampStyles:set(id, ramp)
        end,
        objerror=function(self,msg)
          -- todo: set context (if applicable)
          logging.error(tostring(msg))
        end,
        precache_model=function(self,id)
          if not precache_models[id] then
            precache_models[id] = modelLoader:load(id)
          end
        end,
        attachmodel=function(self,ent,id,prop)
          local cached_model = precache_models[id]
          if not cached_model then
              logging.critical("Unknown alias model: "..id)
          end
          ent[prop] = cached_model.alias          
        end,
        setmodel=function(self,ent,id,offset)
          if not id then
            ent.mins={0,0,0}
            ent.maxs={0,0,0}
            ent.size={0,0,0}        
            local angles=ent.mangles or {0,0,0}
            ent.m=make_m_from_euler(unpack(angles))
            m_set_pos(ent.m,ent.origin)            
            ent.model = nil
            return
          end
          -- reference to a world sub-models?
          local m
          if sub(id,1,1)=="*" then
            m = models[tonumber(sub(id,2)) + 1]
          else        
            local cached_model = precache_models[id]
            if cached_model.alias then
              m = cached_model.alias
            else
              m = cached_model.model[1]        
              -- todo: revisit (single big array?)
              ent.resources = cached_model.model
            end
          end
    
          if not m then
            logging.critical("Invalid model id: "..id)
          end
          ent.model = m   
          if not ent.origin then
            ent.origin = {0,0,0}
          end
          ent.offset = offset
          local angles=ent.mangles or {0,0,0}
          ent.m=make_m_from_euler(unpack(angles))
          m_set_pos(ent.m,ent.origin)
    
          -- bounding box
          if ent.frame then
            -- animated model?
            local frame = m.frames[ent.frame]
            assert(frame,"Invalid frame id: "..ent.frame)
            ent.size = v_add(frame.maxs,frame.mins,-1)
            ent.mins = v_clone(frame.mins)
            ent.maxs = v_clone(frame.maxs)
          else            
            ent.mins = m.mins and v_clone(m.mins) or ent.mins
            ent.maxs = m.maxs and v_clone(m.maxs) or ent.maxs
            ent.size = v_add(ent.maxs,ent.mins,-1)
          end
          ent.absmins=v_add(ent.origin,ent.mins)
          ent.absmaxs=v_add(ent.origin,ent.maxs)

          assert(ent.absmins)
          assert(ent.absmaxs)
          
          -- register into world
          ent.nodes={}
          if id~="*0" then
            collisionMap:register(ent)
          end
        end,
        setorigin=function(self,ent,pos)
          ent.origin = v_clone(pos)
          collisionMap:register(ent)
        end,
        time=function()
          -- sync with world time
          return world.time_t
        end,
        print=function(self,msg,...)
          messages:say(msg,...)
        end,
        -- find all entities with a property matching the given value
        -- if filter is given, only returns entities with an additional "filter" field
        find=function(_,...)
          return world.entities:find(...)
        end,
        spawn=function(_)
          return world:spawn()
        end,
        remove=function(_,ent)
          -- mark entity for deletion
          ent.free = true
        end,
        set_skill=function(self,skill)
          logging.debug("Selected skill level: "..skill)
          gameState.skill = skill
        end,
        load=function(self,map,intermission)
          -- clear message
          messages:say()
          -- remove player
          if world.player then
            world.player.free=true
          end
          
          if intermission then
            -- switch to intermission state
            logging.debug("Map intermission")
            stateSystem:next("screens.intermission",world,map,self.found_secrets,self.total_secrets)
          else
            logging.debug("Loading map: "..map)
            stateSystem:next("screens.play",map)
          end
        end,
        drop_to_floor=function(self,ent)      
          -- find "ground"
          local hits = collisionMap:hitscan({0,0,0},{0,0,0},v_add(ent.origin,{0,0,8}),v_add(ent.origin,{0,0,-256}),{},{world.entities[1]},ent)
          if hits.t==1 or hits.all_solid then
            logging.critical("Entity: "..ent.classname.." unable to find resting ground")
            return
          end
          self:setorigin(ent,hits.pos)
        end,
        attach=function(self,ent,system,args)
          local c=_components[system]
          if not c then
            logging.error("Unknown system: "..system)
            return
          end
          ent[system]=c:new(ent,args)
        end,
        -- returns the closest entity in the line of sight
        -- returns entity, pos, normal
        traceline=function(self,ent,p0,p1,monsters)
          local absmins,absmaxs=v_min(p0,p1),v_max(p0,p1)
          local ents = collisionMap:touches(absmins, absmaxs, ent)                      
          local triggers = {}
          local trace = collisionMap:hitscan({0,0,0},{0,0,0},p0,p1,triggers,ents)
          if trace.n then
            return trace.ent,trace.pos,trace.n
          end
        end,
        -- call an entity function
        call=function(_,ent,fn,...)
          world:call(ent,fn,...)
        end,        
      }
end
return ProgsAPI
