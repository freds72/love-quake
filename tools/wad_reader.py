import os
import re
import io
import math
import logging
import argparse
from ctypes import *
from collections import namedtuple
from file_stream import FileStream
from colormap_reader import AutoPalette
from tqdm import tqdm
from bsp_reader import pack_bsp
from python2pico import *
from lzs import Codec
from dotdict import dotdict

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

def read_colormap(stream):
  # read palette (e.g. all known colors)
  # convention: 16 solid bars
  palette = AutoPalette()
  with stream.read("gfx/palette.lmp") as lump:
    for i in range(16*16):
      rgb = lump.read(3)
      palette.register((rgb[0],rgb[1],rgb[2]))
  
  hw_palette = palette.pal()
  colormap = {}
  with stream.read("gfx/colormap.lmp") as lump:
    for color_index in range(16):
      colormap[color_index] = dotdict({
        'id': color_index,
        'hw': hw_palette[color_index],
        'rgb': palette.get_rgb(color_index),
        'ramp': [palette.get_pal_id(tuple(list(lump.read(3)))) for i in range(16)]
      })
  return colormap      

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

  # pad map
  # map_data = ["".join(map("{:02x}".format,map_data[i:i+width] + [0]*(128-width))) for i in range(0,len(map_data),width)]
  # map_data = "".join(map_data)
  # cart += "__map__\n"
  # cart += re.sub("(.{256})", "\\1\n", map_data, 0, re.DOTALL)

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

def pack_archive(pico_path, carts_path, stream, mapname, compress=False, release=None, dump_lightmaps=False, compress_more=False, test=False, only_lightmap=False):
  # extract palette
  colormap = read_colormap(stream)

  # extract data
  level_data,sprite_data = pack_bsp(stream, "maps/" + mapname + ".bsp", colormap, only_lightmap)

  if not test:
    game_data = compress and compress_byte_str(level_data, more=compress_more) or level_data

    to_gamecart(carts_path, "q8k", None , sprite_data, compress, release)

    # export to game
    to_multicart(game_data, pico_path, carts_path, "q8k")  

def main():
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

  args = parser.parse_args()

  logging.basicConfig(level=logging.INFO)
  with FileStream(args.mod_path) as stream:
    pack_archive(args.pico_home, args.carts_path, stream, args.map, compress=args.compress or args.compress_more, release=args.release, compress_more=args.compress_more, test=args.test, only_lightmap=args.lightmaps)
  logging.info('DONE')
    
if __name__ == '__main__':
    main()

