import os
import re
import io
import math
import logging
import argparse
from ctypes import *
from collections import namedtuple
from file_stream import FileStream
from colormap_reader import ColormapReader
from image_reader import ImageReader
from tqdm import tqdm
from bsp_reader import pack_bsp
from fgd_reader import FGDReader
from python2pico import *
from lzs import Codec
from dotdict import dotdict

local_dir = os.path.dirname(os.path.realpath(__file__))
blender_exe = os.path.expandvars(os.path.join("%programfiles%","Blender Foundation","Blender 2.92","blender.exe"))

def call(args):
    proc = Popen(args, stdout=PIPE, stderr=PIPE, cwd=local_dir)
    out, err = proc.communicate()
    exitcode = proc.returncode
    #
    return exitcode, out, err

# compress the given byte string
# raw = True returns an array of bytes (a byte string otherwise)
def compress_byte_str(s,raw=False,more=False):
  b = bytes.fromhex(s)
  min_size = len(b)
  min_off = 8
  min_len = 3
  if more:
    for l in tqdm(range(8), desc="Compression optimization"):
      cc = Codec(b_off = min_off, b_len = l) 
      compressed = cc.toarray(b)
      if len(compressed)<min_size:
        min_size=len(compressed)
        min_len = l      
  
    logging.debug("Best compression parameters: O:{} L:{} - ratio: {}%".format(min_off, min_len, round(100*min_size/len(b),2)))

  # LZSS compressor  
  cc = Codec(b_off = min_off, b_len = min_len) 
  compressed = cc.toarray(b)
  if raw:
    return compressed
  return "".join(map("{:02x}".format, compressed))

def pack_sprite(arr):
    return ["".join(map("{:02x}".format,arr[i*4:i*4+4])) for i in range(8)]

def to_gamecart(carts_path, name, map_data, gfx_data, compress=False, release=None):
  cart="""\
pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- {0}
-- @freds72
-- *********************************
-- generated code - do not edit
-- *********************************
#include poly.lua
#include {1}
#include {2}
""".format(
  name,
  compress and "lzs.lua" or "plain.lua",
  release and "{}_main_mini.lua".format(name) or "main.lua")

  # transpose gfx
  gfx_data=[pack_sprite(data) for data in gfx_data]

  s = ""

  # tiles
  rows = [""]*8
  for i,img in enumerate(gfx_data):
      # full row?
      if i%16==0:
        # collect
        s += "".join(rows)
        rows = [""]*8           
      for j in range(8):
        rows[j] += img[j]
  # remaining tiles (+ padding)
  s += "".join([row + "0" * (128-len(row)) for row in rows])

  # convert to string
  cart += "__gfx__\n"
  cart += re.sub("(.{128})", "\\1\n", s, 0, re.DOTALL)
  cart += "\n"

  # store map linearly
  cart += "__map__\n"
  cart += re.sub("(.{256})", "\\1\n", "".join(map(pack_byte,map_data)), 0, re.DOTALL)

  # music and sfx (from external cart)
  # group cart?
  music_path = os.path.join(carts_path, "music.p8")    
  if os.path.isfile(music_path):
    logging.info("Found music&sfx cart: {}".format(music_path))

    copy = False
    with open(music_path, "r") as f:
      for line in f:
        line = line.rstrip("\n\r")
        if line in ["__music__","__sfx__"]:
          copy = True
        elif re.match("__([a-z]+)__",line):
          # any other section
          copy = False
        if copy:
          cart += line
          cart += "\n"

  cart_path = os.path.join(carts_path, "{}.p8".format(name))
  with open(cart_path, "w") as f:
    f.write(cart)

# extract blender models
def pack_models(home_path, blender_files, colormap):
    # data buffer
    blob = ""

    # convert HW palette to parameter
    colors = "".join(map(pack_byte, colormap.palette.pal()))

    # 3d models
    blob += pack_variant(len(blender_files))
    for i, blender_file in enumerate(blender_files):
        logging.info("Exporting 3d model: {}".format(blender_file))
        fd, path = tempfile.mkstemp()
        try:
            os.close(fd)
            exitcode, out, err = call([blender_exe,os.path.join(home_path, blender_file),"--background","--python","blender_reader.py","--","--colors",colors,"--out",path])
            if err:
                raise Exception('Unable to loadt: {}. Exception: {}'.format(blender_file,err))
            logging.debug("Blender exit code: {} \n out:{}\n err: {}\n".format(exitcode,out,err))
            with open(path, 'r') as outfile:      
                blob += outfile.read()
        finally:
            os.remove(path)
    return blob

def pack_entities(entities, models):
  blob = ""
  # player start?
  classnames=['info_player_start','info_player_deathmatch','testplayerstart']
  player_starts=[e for e in entities if e.classname in classnames]
  if len(player_starts)==0:
    logging.warning("Missing info_player_start entity in: {}".format(entities))
    player_starts=[dotdict({
      'classname':'debug_player_start',
      'origin':dotdict({'x':0,'y':0,'z':0}),
      'angle':0
    })]
  player_start = player_starts[0]
  logging.info("Found player start: {} at: {}".format(player_start.classname, player_start.origin))
  blob += pack_vec3(player_start.origin)
  blob += pack_fixed(player_start.get("angle",0))

  # all entities with a model
  threed_models = []
  things = list([e for e in entities if "model.path" in e])
  blob += pack_variant(len(things))
  for thing in things:
    blob += pack_vec3(thing.origin)    
    threed_model = thing.get("model.path")
    id = 0
    if threed_model not in threed_models:
      id = len(threed_models)
      logging.info("Registering 3d model: {} with ID: {}".format(threed_model, id))
      threed_models.append(threed_model)
    else:
      id = threed_models.index(threed_model)
    blob += pack_variant(id + 1)

  # (supported) triggers
  trigger_filter = re.compile("trigger*")
  triggers = []  
  for trigger in [e for e in entities if trigger_filter.match(e.classname)]:
    flags = 0

    # brush model reference
    trigger_blob = pack_variant(int(trigger.model[1:])+1)
    # delay (applies for all triggers) converted to number of frames
    # cancel negative values
    trigger_blob += pack_variant(max(0,int(trigger.get("delay",0)*30)))
    
    if "message" in trigger:
      flags |= 2
      trigger_blob += pack_string(trigger.message)

    if trigger.classname == "trigger_once":
      flags |= 0
    elif trigger.classname == "trigger_multiple":
      flags |= 1
      # cancel negative values for wait
      trigger_blob += pack_variant(max(0,int(trigger.wait*30)))

    # put decoding flag first
    triggers.append(pack_byte(flags) + trigger_blob)

  # pack "active" triggers
  blob += pack_variant(len(triggers))
  blob += "".join(triggers)

  doors_filter = re.compile("func_door")
  doors = []
  for door in [e for e in entities if doors_filter.match(e.classname)]:
    flags = 0
    # brush model reference
    model_id = int(door.model[1:])
    door_blob = pack_variant(model_id+1)
    # wait time before door closes again
    # cancel negative values for wait
    door_blob += pack_variant(max(0,int(door.wait*30)))
    # speed
    door_blob += pack_variant(max(0,int(door.get("speed",3))))
    # 0-359: horizontal angle
    # -1: up move
    # -2: down move
    angle = door.get('angle',0)
    # bounding box extents
    model = models[model_id]    
    extents = dotdict({
      'x':model.bound.max.x - model.bound.min.x,
      'y':model.bound.max.y - model.bound.min.y,
      'z':model.bound.max.z - model.bound.min.z})
    
    # pos1 (origin)
    door_blob += pack_vec3(model.origin)
    
    # pos 2 (destination)
    pos2 = model.origin
    lip = door.get("lip",8)
    if angle==-1:      
      pos2.y+=extents.y-lip
    elif angle==-2:
      pos2.y-=extents.y-lip
    else:
      # todo: support all angles
      pos2.x+=extents.x-lip

    door_blob += pack_vec3(pos2)

    # put decoding flag first
    doors.append(pack_byte(flags) + door_blob)

  # pack doors
  blob += pack_variant(len(doors))
  blob += "".join(doors)

  return (blob, threed_models)


def pack_archive(pico_path, carts_path, stream, mapname, compress=False, release=None, dump_lightmaps=False, compress_more=False, test=False, only_lightmap=False):
  # extract palette
  colormap = ColormapReader(stream)

  raw_data = colormap.pack()
  uv = ImageReader(colormap.palette.raw()).read(FileStream(os.path.join(carts_path,"..")), os.path.join("models","uvmap.png"))

  # get "game classes" (FGD)
  fgd_classes = {}
  # todo: parameter
  filename = "C:\\Users\\Frederic\\AppData\\Roaming\\TrenchBroom\\games\\q8k\\q8k.fgd"
  with open(filename,'r') as f:
    reader = FGDReader(f.read())
    fgd_classes = reader.result

  # extract data  
  level_data, sprite_data, map_data, entities, models = pack_bsp(stream, os.path.join("maps",mapname + ".bsp"), fgd_classes, colormap.colors, uv.sprites, only_lightmap)
  
  raw_data += level_data

  # pack entities
  entities_data, threed_models = pack_entities(entities, models)

  # extract 3d models
  blender_data = pack_models(os.path.join(carts_path,".."), threed_models, colormap)

  raw_data += blender_data
  raw_data += entities_data

  if not test:
    game_data = compress and compress_byte_str(raw_data, more=compress_more) or raw_data

    to_gamecart(carts_path, "q8k", uv.tiles + map_data, sprite_data, compress, release)

    # export to game
    to_multicart(game_data, pico_path, carts_path, "q8k")  

def main():
  global blender_exe
  parser = argparse.ArgumentParser()
  parser.add_argument("--pico-home", required=True, type=str, help="Full path to PICO8 folder")
  parser.add_argument("--carts-path", required=True, type=str, help="Path to carts folder where game is exported")
  parser.add_argument("--mod-path", required=True ,type=str, help="Path mod path (gfx, maps...)")
  parser.add_argument("--map", required=True, type=str, help="Level name")
  parser.add_argument("--compress", action='store_true', required=False, help="Enable compression (default: false)")
  parser.add_argument("--compress-more", action='store_true', required=False, help="Brute force search of best compression parameters. Warning: takes time (default: false)")
  parser.add_argument("--release", required=False,  type=str, help="Generate html+bin packages with given version. Note: compression mandatory if number of carts above 16.")
  parser.add_argument("--dump-lightmaps", action='store_true', required=False, help="Writes lightmaps to disk")
  parser.add_argument("--test", action='store_true', required=False, help="Test mode - does not write cart data")
  parser.add_argument("--lightmaps", action='store_true', required=False, help="Lightmap (only) textures mode")
  parser.add_argument("--blender-location", required=False, type=str, help="Full path to Blender 2.9+ executable (default: {})".format(blender_exe))

  args = parser.parse_args()

  logging.basicConfig(level=logging.INFO)

  if args.blender_location:
    blender_exe = args.blender_location
  logging.debug("Blender location: {}".format(blender_exe))
  # test Blender path
  if not os.path.isfile(os.path.join(blender_exe)):
    raise Exception("Unable to locate Blender app at: {}".format(blender_exe))

  with FileStream(args.mod_path) as stream:
    pack_archive(args.pico_home, args.carts_path, stream, args.map, compress=args.compress or args.compress_more, release=args.release, compress_more=args.compress_more, test=args.test, only_lightmap=args.lightmaps)
  logging.info('DONE')
    
if __name__ == '__main__':
    main()

