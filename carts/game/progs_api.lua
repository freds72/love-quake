-- programmatic contract between "programs" and the game engine
local logging = require("engine.logging")
local lightStyles = require("systems.lightstyles")
local rampStyles = require("systems.rampstyles")
local messages = require("systems.message")
local stateSystem = require("engine.state_system")

local ProgsAPI=function(modelLoader, models, world, collisionMap)
    local precache_models={}
  
    return {
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
            -- bind to model "owner"
            -- todo: yargh!!! to be changed
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
            ent.size = v_add(m.maxs,m.mins,-1)
            ent.mins = v_clone(m.mins)
            ent.maxs = v_clone(m.maxs)
          end
          ent.absmins=v_add(ent.origin,ent.mins)
          ent.absmaxs=v_add(ent.origin,ent.maxs)
          -- register into world
          ent.nodes={}
          if id~="*0" then
            collisionMap:register(ent)
          end
        end,
        setorigin=function(self,ent,pos)
          ent.origin = v_clone(pos)
          ent.absmins=v_add(ent.origin,ent.mins)
          ent.absmaxs=v_add(ent.origin,ent.maxs)
          m_set_pos(ent.m,ent.origin)
    
          collisionMap:register(ent)
        end,
        time=function()
          return time()
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
          -- detach from ECS
          for name,system in pairs(_components) do
            local c=ent[name]
            if c then
              system:free(c)
              ent[name] = nil
            end
          end
        end,
        set_skill=function(_,skill)
          logging.debug("Selected skill level: "..skill)
          _skill = skill
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
            stateSystem:next("screens.play",world,map)
          end
        end,
        drop_to_floor=function(self,ent)
          -- find "ground"
          local hits = collisionMap:hitscan(ent.mins,ent.maxs,v_add(ent.origin,{0,0,8}),v_add(ent.origin,{0,0,-256}),{},{world.entities[1]},ent)
          if not hits or hits.t==1 or hits.all_solid then
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
        end
      }
end
return ProgsAPI
