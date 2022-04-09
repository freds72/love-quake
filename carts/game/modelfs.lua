local modelfs = {}
local ffi=require 'ffi'
local nfs = require( "nativefs" )
local entities = require( "entities" )
local logging = require("logging")

-- caches
local _model_cache,_planes={},{}

-- pico8 compat helpers
local sub,add=string.sub,table.insert
local flr,ceil,abs=math.floor,math.ceil,math.abs
local min,max=math.min,math.max
local band,bor,shl,shr,bnot=bit.band,bit.bor,bit.lshift,bit.rshift,bit.bnot
local sin,cos=math.sin,math.cos

ffi.cdef[[
    #pragma pack(1)
    
    typedef float vec3_t[3];
    typedef struct { unsigned char r,g,b; } color_t;
    
    typedef short dvertexshort_t[3];
    
    typedef struct
    {
        int		fileofs, filelen;
    } lump_t;
    
    typedef struct
    {
      int	   version;	
      lump_t entities;
      lump_t planes;
      lump_t textures;
      lump_t vertices;
      lump_t visibility;
      lump_t nodes;
      lump_t texinfo;
      lump_t faces;
      lump_t lighting;
      lump_t clipnodes;
      lump_t leaves;
      lump_t marksurfaces;
      lump_t edges;
      lump_t surfedges;
      lump_t models;
    } dheader_t;
    
    typedef struct
    {
        vec3_t	mins, maxs;
        float		origin[3];
        int			headnode[4];
        int			visleafs;		// not including the solid leaf 0
        int			firstface, numfaces;
    } dmodel_t;
    
    typedef struct
    {
        int			nummiptex;
        int			dataofs[4];		// [nummiptex]
    } dmiptexlump_t;
    
    static const int MIPLEVELS	= 4;
    typedef struct miptex_s
    {
        char		name[16];
        unsigned	width, height;
        unsigned	offsets[MIPLEVELS];		// four mip maps stored
    } miptex_t;
    
    typedef struct
    {
        vec3_t	normal;
        float	dist;
        int		type;		// PLANE_X - PLANE_ANYZ ?remove? trivial to regenerate
    } dplane_t;
    
    typedef struct
    {
        int			planenum;
        short		children[2];	// negative numbers are -(leafs+1), not nodes
        dvertexshort_t		mins;		// for sphere culling
        dvertexshort_t		maxs;
        unsigned short	firstface;
        unsigned short	numfaces;	// counting both sides
    } dnode_t;
    
    typedef struct
    {
        int			planenum;
        short		children[2];	// negative numbers are contents
    } dclipnode_t;
    
    typedef struct texinfo_s
    {
        // [s/t][xyz offset]
        vec3_t   s;
        float       s_offset;
        vec3_t   t;
        float       t_offset;
        int			miptex;
        int			flags;
    } texinfo_t;
    
    typedef struct
    {
        unsigned short	v[2];		// vertex numbers
    } dedge_t;
    
    static const int	MAXLIGHTMAPS = 4;
    typedef struct
    {
        short		planenum;
        short		side;
    
        int			firstedge;		// we must support > 64k edges
        short		numedges;	
        short		texinfo;
    
        unsigned char		styles[MAXLIGHTMAPS];  // lighting info
        int			          lightofs;		// start of [numstyles*surfsize] samples
    } dface_t;
    
    // #define	AMBIENT_WATER	0
    // #define	AMBIENT_SKY		1
    // #define	AMBIENT_SLIME	2
    // #define	AMBIENT_LAVA	3
    
    static const int NUM_AMBIENTS = 4;
    
    // leaf 0 is the generic CONTENTS_SOLID leaf, used for all solid areas
    // all other leafs need visibility info
    typedef struct
    {
        int			contents;
        int			visofs;				// -1 = no visibility info
    
        dvertexshort_t		mins;			// for frustum culling
        dvertexshort_t		maxs;
    
        unsigned short		firstmarksurface;
        unsigned short		nummarksurfaces;
    
        unsigned char		  ambient_level[NUM_AMBIENTS];
    } dleaf_t;

    // alias models (eg. non geometry)
    // must match definition in spritegn.h
    typedef enum {ST_SYNC=0, ST_RAND } synctype_t;

    typedef enum { ALIAS_SINGLE=0, ALIAS_GROUP } aliasframetype_t;

    typedef enum { ALIAS_SKIN_SINGLE=0, ALIAS_SKIN_GROUP } aliasskintype_t;

    typedef struct {
        int			ident;
        int			version;
        vec3_t		scale;
        vec3_t		scale_origin;
        float		boundingradius;
        vec3_t		eyeposition;
        int			numskins;
        int			skinwidth;
        int			skinheight;
        int			numverts;
        int			numtris;
        int			numframes;
        synctype_t	synctype;
        int			flags;
        float		size;
    } mdl_t;

    // TODO: could be shorts

    typedef struct {
        int		onseam;
        int		s;
        int		t;
    } stvert_t;

    typedef struct dtriangle_s {
        int					facesfront;
        int					vertindex[3];
    } dtriangle_t;

    // This mirrors trivert_t in trilib.h, is present so Quake knows how to
    // load this data

    typedef struct {
        unsigned char	v[3];
        unsigned char   lightnormalindex;
    } trivertx_t;

    typedef struct {
        trivertx_t	bboxmin;	// lightnormal isn't used
        trivertx_t	bboxmax;	// lightnormal isn't used
        char		name[16];	// frame name from grabbing
    } daliasframe_t;

    typedef struct {
        int			numframes;
        trivertx_t	bboxmin;	// lightnormal isn't used
        trivertx_t	bboxmax;	// lightnormal isn't used
    } daliasgroup_t;

    typedef struct {
        int			numskins;
    } daliasskingroup_t;

    typedef struct {
        float	interval;
    } daliasinterval_t;

    typedef struct {
        float	interval;
    } daliasskininterval_t;

    typedef struct {
        aliasframetype_t	type;
    } daliasframetype_t;

    typedef struct {
        aliasskintype_t	type;
    } daliasskintype_t;    
]]

-- reads the given struct name from the byte array
local function read_all(cname, lump, mem)
    local res = {}
    local sz,ct = ffi.sizeof(cname), ffi.typeof(cname.."*")
    local n = lump.filelen / sz
    mem = mem + lump.fileofs
    for i=0,n-1 do
        res[i] = ffi.cast(ct, mem)
        mem = mem + sz
    end
    --return ffi.cast(cname.."["..n.."]", mem)
    return res
end

-- planes functions (globals)
plane_get=function(pi)
    local n=_planes[pi].normal
    return n[1],n[2],n[3]
end
plane_dot=function(pi,v)
    local plane=_planes[pi]
    local t,n=plane.type,plane.normal
    if t<3 then                 
        return n[t+1]*v[t+1],plane.dist
    end
    return n[1]*v[1]+n[2]*v[2]+n[3]*v[3],plane.dist
end
plane_isfront=function(pi,v)
    local plane=_planes[pi]
    local t,n=plane.type,plane.normal
    if t<3 then    
        return n[t+1]*v[t+1]>plane.dist
    end
    return n[1]*v[1]+n[2]*v[2]+n[3]*v[3]>plane.dist
end
-- mins/maxs must be absolute corners
plane_classify_bbox=function(pi,c,e)
    local plane=_planes[pi]
    local t,n=plane.type,plane.normal
    -- todo: optimize
    -- if t<3 then
    --     if n[t]*mins[t+1]<=plane.dist then
    --         return 1
    --     elseif n[t]*maxs[t+1]>=plane.dist then
    --         return 2
    --     end
    --     return 3
    -- end
    -- cf: https://gdbooks.gitbooks.io/3dcollisions/content/Chapter2/static_aabb_plane.html

    -- Compute the projection interval radius of b onto L(t) = b.c + t * p.n
    local r = e[1]*abs(n[1]) + e[2]*abs(n[2]) + e[3]*abs(n[3])
  
    -- Compute distance of box center from plane
    local s = n[1]*c[1]+n[2]*c[2]+n[3]*c[3] - plane.dist
  
    -- Intersection occurs when distance s falls within [-r,+r] interval
    if s<=-r then
      return 1
    elseif s>=r then
      return 2
    end
    return 3  
end

local function unpack_array(fn,array)
    for i=0,#array do
        fn(array[i],i)
    end
end
local function unpack_vert(v,dst)
    dst = dst or {}
    add(dst, v.x)
    add(dst, v.y)
    add(dst, v.z)
    return dst
end

-- shared content leaves
local content_types={}
for i=1,6 do
    -- -1: ordinary leaf
    -- -2: the leaf is entirely inside a solid (nothing is displayed).
    -- -3: Water, the vision is troubled.
    -- -4: Slime, green acid that hurts the player.
    -- -5: Lava, vision turns red and the player is badly hurt.   
    -- -6: sky 
    add(content_types,{contents=-i})
end  

local function unpack_map(bsp)
    local plane_offset = #_planes + 1

    local verts,faces,leaves,nodes,models,uvs,clipnodes={},{},{},{},{},{},{}

    local function v_rebase(v)
        return {v[0],v[1],v[2]}
    end
    -- convert verts to 1-based array
    unpack_array(function(v)
        add(verts,v_rebase(v[0]))
    end, bsp.vertices)

    -- register planes in global array
    unpack_array(function(plane)
        add(_planes,{
            normal=v_rebase(plane.normal),
            dist=plane.dist,
            type=plane.type
        })
    end, bsp.planes)
    
    unpack_array(function(f,i)      
        -- side flag
        local face={
            side=(f.side~=0),
            plane=f.planenum + plane_offset       
        }

        local face_verts = {}
        for i=0,f.numedges-1 do
            local edge_id = bsp.surfedges[f.firstedge + i]
            if edge_id>=0 then
                local edge = bsp.edges[edge_id]
                add(face_verts, edge.v[0]+1)
            else
                local edge = bsp.edges[-edge_id]
                add(face_verts, edge.v[1]+1)
            end
        end
        -- texture?
        if f.texinfo~=-1 then
            local tex = bsp.texinfo[f.texinfo]
            face.texinfo = tex

            local lightstyles={}
            for i=0,3 do
                add(lightstyles, f.styles[i])
            end
            face.lightstyles = lightstyles

            -- light info?
            if f.lightofs~=-1 then
                local lightmap_scale = 16
                local u_min=32000
                local u_max=-32000
                local v_min=32000
                local v_max=-32000
                for _,vi in pairs(face_verts) do
                    local v=verts[vi]
                    local u=v_dot(v,v_rebase(tex.s)) + tex.s_offset
                    local v=v_dot(v,v_rebase(tex.t)) + tex.t_offset
                    u_min=min(u_min,u)
                    v_min=min(v_min,v)
                    u_max=max(u_max,u)
                    v_max=max(v_max,v)
                end
                face.umin = u_min
                face.vmin = v_min
                u_min=flr(u_min / lightmap_scale)
                v_min=flr(v_min / lightmap_scale)
                u_max=ceil(u_max / lightmap_scale)
                v_max=ceil(v_max / lightmap_scale)
                
                -- lightmap size
                face.width = u_max-u_min+1
                face.height = v_max-v_min+1 
                face.lightofs = bsp.lightmaps[f.lightofs]
            end
        end

        -- !! 1-based array
        face.verts = face_verts
        face.cp=plane_dot(face.plane, verts[face_verts[1]])
        add(faces, face)
    end, bsp.faces)
    
    local unpack_node_pvs
    unpack_node_pvs=function(node, model, cache)
        for i=0,1 do
            local child_id = node.children[i]
            if band(child_id,0x8000) ~= 0 then
                child_id = bnot(child_id)
                if child_id ~= 0 then
                    local leaf = bsp.leaves[child_id]
                    if leaf.visofs~=-1 and not cache[child_id] then
                        local numbytes = shr(model.visleafs+7,3)
                        -- print("leafs: {} / bytes: {} / offset: {} / {}".format(model.numleafs, numbytes, leaf.visofs, len(visdata)))
                        local vis = {}
                        local i = 0
                        local c_out = 0     
                        while c_out<numbytes do
                            local ii = bsp.visdata[leaf.visofs+i]
                            if ii ~= 0 then
                                vis[shr(c_out,2)] = bor(vis[shr(c_out,2)] or 0, shl(ii, 8*(c_out%4)))              
                                i = i + 1
                                c_out = c_out + 1
                                goto skip
                            end
                            -- skip 0
                            i = i + 1
                            -- number of bytes to skip
                            c = bsp.visdata[leaf.visofs+i]
                            i = i + 1
                            c_out = c_out + c
::skip::
                        end
                        cache[child_id] = vis
                    end
                end
            else
                unpack_node_pvs(bsp.nodes[child_id], model, cache)
            end
        end
    end

    -- attach vis data to 1st model
    local main_model,vis_cache=bsp.models[0],{}    
    unpack_node_pvs(bsp.nodes[main_model.headnode[0]], main_model, vis_cache)

    unpack_array(function(leaf, i)
        local mins,maxs=leaf.mins,leaf.maxs
        local l={
            contents = leaf.contents,
            pvs = vis_cache[i],
            mins={mins[0],mins[1],mins[2]},
            maxs={maxs[0],maxs[1],maxs[2]}
        }
        for i=0,leaf.nummarksurfaces-1 do
            -- de-ref face
            add(l, faces[bsp.marksurfaces[leaf.firstmarksurface + i] + 1])
        end
        add(leaves,l)
    end, bsp.leaves)

    unpack_array(function(node)
        local mins,maxs=node.mins,node.maxs
        local n={
            plane=node.planenum + plane_offset,
            mins={mins[0],mins[1],mins[2]},
            maxs={maxs[0],maxs[1],maxs[2]}
        }
        local flags = 0
        for i=0,1 do
            local child_id = node.children[i]
            if band(child_id,0x8000) ~= 0 then
                child_id = bnot(child_id)
                if child_id ~= 0 then
                    flags = bor(flags, i+1)
                    child_id = child_id + 1
                else
                    child_id = 0
                end
            else
                -- node
                if child_id==0 then
                    assert("invalid child reference: 0")
                end
                child_id = child_id + 1
            end
            n[i==0] = child_id
        end
        n.flags=flags
        add(nodes, n)
    end, bsp.nodes)

    -- attach nodes/leaves
    for _,node in pairs(nodes) do
        local function attach_node(side,leaf)
            local refs=leaf and leaves or nodes
            local child=refs[node[side]]
            node[side]=child or {contents=content_types[2].contents}
            -- used to optimize bsp traversal for rendering
            if child then
                child.parent=node
            end
        end
        attach_node(true,band(node.flags,0x1)~=0)
        attach_node(false,band(node.flags,0x2)~=0)
    end
    
    -- unpack "clipnodes" (collision hulls)
    unpack_array(function(node)
        local clipnode={
            plane=node.planenum + plane_offset
        }
        local flags = 0
        for i=0,1 do
            clipnode[i==0]=node.children[i]
        end
        add(clipnodes, clipnode)
    end, bsp.clipnodes)
    -- attach references
    for _,node in pairs(clipnodes) do
        local function attach_node(side)
            local id=node[side]
            node[side]=id<0 and content_types[-id] or clipnodes[id+1]
        end
        attach_node(true)
        attach_node(false)
    end
    
    -- unpack "models"  
    local leaf_base=0
    models.verts=verts
    models.planes=bsp.planes
    models.leaves=leaves
    models.textures=bsp.textures
    unpack_array(function(model)  
        local mins,maxs=model.mins,model.maxs
        add(models,{
            faces=faces,
            mins={mins[0],mins[1],mins[2]},
            maxs={maxs[0],maxs[1],maxs[2]},
            hulls={
                -- root node (for display)
                nodes[model.headnode[0]+1],                
                -- 32 unit clip nodes
                clipnodes[model.headnode[1]+1],
                -- 64 unit clip nodes
                clipnodes[model.headnode[1]+2],
            },
            leaf_start=leaf_base + 2,
            leaf_end=leaf_base + model.visleafs + 1})
        leaf_base = leaf_base + model.visleafs
    end, bsp.models)

    return models
end

local function unpack_textures(lump, mem)
    mem = mem + lump.fileofs
    local textures = {}
    local m = ffi.cast("dmiptexlump_t*", mem)
    local n = m.nummiptex
    local sequences={}
    for i=0,n-1 do
        local ofs = m.dataofs[i]
        if ofs~=-1 then
            local mt = ffi.cast("miptex_t*", mem + ofs)
            local texname=ffi.string(mt.name)
            -- print("texture: "..texname.." size: "..mt.width.."x"..mt.height)
            -- store pointers to image data (e.g. color indices)
            local imgs={}
            for j=0,3 do
                add(imgs,ffi.cast("unsigned char*", mem + ofs + mt.offsets[j]))
                --[[
                local scale=shl(1,j)
                local w,h=flr(mt.width/scale), flr(mt.height/scale)
                local imagedata = love.image.newImageData(w,h)
                local image     = love.graphics.newImage(imagedata,{linear=true, mipmaps=false})
                image:setFilter('nearest','nearest')        
                local ptr = ffi.cast('uint32_t*', imagedata:getFFIPointer()) 
                for k=0,w*h-1 do
                    local rgb=palette[data[k] ]
                    ptr[k]=0xff000000+shl(rgb.b,16)+shl(rgb.g,8)+rgb.r
                end
                image:replacePixels(imagedata)
                add(imgs, image)
                ]]
            end
            local sky=sub(texname,0,3)=="sky"
            local swirl=sub(texname,1,1)=="*"
            local texinfo = {
                width = mt.width,
                height = mt.height,
                mips = imgs,
                sky=sky,
                swirl=swirl,
                bright = swirl or sky
            }
            -- part of a sequence?
            if sub(texname,0,1)=="+" then
                local seqid=tonumber(sub(texname,1,2),16)
                local seqname=sub(texname,3)
                -- print("INFO - texture sequence: "..seqname.." @"..seqid)
                local seq=sequences[seqname] or {main={},alt={}}
                if seqid>0x9 then
                    seq.alt[seqid-0xa] = texinfo
                else
                    seq.main[seqid] = texinfo
                end
                sequences[seqname] = seq

                texinfo.sequence = seq
            end
            textures[i] = texinfo
        end
    end
    return textures
end

local function load_bsp(data)
    local mem = data:getFFIPointer()

    local header = ffi.cast('dheader_t*', mem)
    assert(header.version==29, "Unsupported BSP file version: "..header.version)

    local ptr = ffi.cast("unsigned char*",mem)
    
    local entities_lump = header.entities
    local entities = ffi.string(ptr + entities_lump.fileofs, entities_lump.filelen)

    local bsp={
        models = read_all("dmodel_t", header.models, ptr),
        vertices = read_all("vec3_t", header.vertices, ptr),
        visdata = read_all("unsigned char", header.visibility, ptr)[0],
        lightmaps = read_all("unsigned char", header.lighting, ptr),
        nodes = read_all("dnode_t", header.nodes, ptr),
        clipnodes = read_all("dclipnode_t", header.clipnodes, ptr),
        faces = read_all("dface_t", header.faces, ptr),
        texinfo = read_all("texinfo_t", header.texinfo, ptr),
        textures = unpack_textures(header.textures, ptr),
        planes = read_all("dplane_t", header.planes, ptr),
        leaves = read_all("dleaf_t", header.leaves, ptr),
        edges = read_all("dedge_t", header.edges, ptr),
        marksurfaces = read_all("unsigned short", header.marksurfaces, ptr)[0],
        surfedges = read_all("int", header.surfedges, ptr)[0],
    }    
    return unpack_map(bsp), unpack_entities(entities)
end

local function load_aliasframe(ptr, scale, origin, numverts, frames)
    -- shared frame information
    local aliasframe = ffi.cast('daliasframe_t*', ptr)

    local name = ffi.string(aliasframe.name)
    logging.debug("Loading frame: "..name)

    local frame={
        verts = {},
        normals = {},
        mins = v_add({
            scale[1]*aliasframe.bboxmin.v[0],
            scale[2]*aliasframe.bboxmin.v[1],
            scale[3]*aliasframe.bboxmin.v[2]},origin),
        maxs = v_add({
            scale[1]*aliasframe.bboxmax.v[0],
            scale[2]*aliasframe.bboxmax.v[1],
            scale[3]*aliasframe.bboxmax.v[2]},origin)
    }
    -- register by name
    if frames[name] then
        logging.critical("Duplicate frame name: "..name)
    end

    frames[name] = frame

    ptr = ptr + ffi.sizeof("daliasframe_t")

    --    
    for i=1,numverts do
        local tri = ffi.cast('trivertx_t*', ptr)
        add(frame.normals,tri.lightnormalindex + 1)
        add(frame.verts,v_add({
            scale[1]*tri.v[0],
            scale[2]*tri.v[1],
            scale[3]*tri.v[2]},origin))
        ptr = ptr + ffi.sizeof("trivertx_t")        
    end

    return ptr
end

local function load_framegroup(ptr, scale, origin, numverts, frames)
    local group = ffi.cast('daliasgroup_t*', ptr)
    ptr = ptr + ffi.sizeof("daliasgroup_t")     
    
    logging.debug("MDL group - #frames: "..group.numframes)

    -- intervals are ignored
    ptr = ptr + ffi.sizeof("daliasinterval_t") * group.numframes

    for i=1,group.numframes do
        ptr = load_aliasframe(ptr, scale, origin, numverts, frames)
    end
    return ptr
end

-- note: all frames are registered in a dictionary
-- up to the entity declaration to setup animation sequences
local function load_aliasmodel(data)
    local mem = data:getFFIPointer()

    local header = ffi.cast('mdl_t*', mem)
    assert(header.version==6, "Unsupported MDL file version: "..header.version)

    local mod={
        flags = header.flags,
        skins = {},
        uvs = {},
        faces = {},
        frames = {}
    }
    local scale = {header.scale[0],header.scale[1],header.scale[2]}
    local origin = {header.scale_origin[0],header.scale_origin[1],header.scale_origin[2]}
    
    local ptr = ffi.cast("unsigned char*",mem)
    -- skip header
    ptr = ptr + ffi.sizeof("mdl_t")
    
    local skinsize = header.skinheight * header.skinwidth
    logging.debug("#skin: "..header.numskins)
    for i=0,header.numskins-1 do
        local skintype = ffi.cast('daliasskintype_t*', ptr).type
        ptr = ptr + ffi.sizeof("daliasskintype_t")
        if skintype == 0 then            
            add(mod.skins, {
                width = header.skinwidth,
                height = header.skinheight,
                -- single mips
                mips = {ptr}
            })
        else
            logging.critical("not supported - skin type: "..skintype)
        end
        ptr = ptr + skinsize
    end

    -- uv coords
    for i=0,header.numverts-1 do
        local vert = ffi.cast('stvert_t*', ptr)
        add(mod.uvs,{
            onseam=vert.onseam==0x20,
            u=vert.s,
            v=vert.t
        })
        ptr = ptr + ffi.sizeof("stvert_t")
    end

    -- tris
    for i=0,header.numtris-1 do
        local tri = ffi.cast('dtriangle_t*', ptr)
        add(mod.faces,tri.facesfront==1)
        local v0,v1,v2=tri.vertindex[0],tri.vertindex[1],tri.vertindex[2]
        add(mod.faces,v0+1)
        add(mod.faces,v1+1)
        add(mod.faces,v2+1)
        ptr = ptr + ffi.sizeof("dtriangle_t")
    end

    -- poses
    logging.debug("MDL poses: "..header.numframes)
    for i=1,header.numframes do
        local frametype = ffi.cast('daliasframetype_t*', ptr).type
        ptr = ptr + ffi.sizeof("daliasframetype_t")
        if frametype==0 then
            ptr = load_aliasframe(ptr, scale, origin, header.numverts, mod.frames)
        else        
            ptr = load_framegroup(ptr, scale, origin, header.numverts, mod.frames)
        end
    end
    return mod
end

-- handle to bsp raw memory
function modelfs.load(root_path, name)
    local model = _model_cache[name]
    if not model then               
        local filename = root_path.."/"..name
        local data,err = nfs.newFileData(filename)

        -- bsp? or mdl?
        local extension = sub(name,#name-3)
        if extension==".bsp" then
            logging.info("Loading BSP file: "..filename)
            local m,e = load_bsp(data)
            model = {
                -- keep ffi data alive
                _ffi_ = data,
                model = m,
                entities = e
            }
        elseif extension==".mdl" then
            logging.info("Loading MDL file: "..filename)
            local alias = load_aliasmodel(data)
            model = {
                _ffi_ = data,
                alias = alias            
            }
        else
            assert(false, "ERROR - unsupported model file: "..name)
        end

        -- register in cache
        _model_cache[name] = model
    end
    return model
end

-- temp hull for slidebox
local function init_hull()
    local box_clipnodes={}
    for i=0,5 do
        local side,type = band(i,1)==0,shr(i,1)
        local plane={
            type = type,
            normal = {0,0,0}
        }
        -- set vector
        plane.normal[type+1]=1
        -- register
        add(_planes,plane)

        local clipnode={
            plane = #_planes
        }
        clipnode[side] = -1
        if i ~= 5 then
            clipnode[not side] = i + 1
        else
            clipnode[not side] = -2
        end
        -- register
        box_clipnodes[i] = clipnode
    end

    -- attach
    for _,node in pairs(box_clipnodes) do
        local function attach_node(side)
            local id=node[side]
            node[side]=id<0 and content_types[-id] or box_clipnodes[id]
        end
        attach_node(true)
        attach_node(false)
    end
    return box_clipnodes
end

local _box_hull=init_hull()

function modelfs.make_hull(mins,maxs)
	_planes[_box_hull[0].plane].dist = maxs[1]
	_planes[_box_hull[1].plane].dist = mins[1]
	_planes[_box_hull[2].plane].dist = maxs[2]
	_planes[_box_hull[3].plane].dist = mins[2]
	_planes[_box_hull[4].plane].dist = maxs[3]
	_planes[_box_hull[5].plane].dist = mins[3]

    return _box_hull[0]
end

return modelfs