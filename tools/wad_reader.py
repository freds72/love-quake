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
        'hw': hw_palette[color_index],
        'rgb': palette.get_rgb(color_index),
        'ramp': [palette.get_pal_id(tuple(list(lump.read(3)))) for i in range(16)]
      })
  return colormap      

def pack_archive(pico_path, carts_path, stream, mapname, compress=False, release=None, dump_lightmaps=False, compress_more=False, test=False):
  # extract palette
  colormap = read_colormap(stream)

  # extract data
  map_data = pack_bsp(stream, "maps/" + mapname + ".bsp", colormap)

  if not test:
    game_data = compress and compress_byte_str(map_data, more=compress_more) or map_data
  
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

  args = parser.parse_args()

  logging.basicConfig(level=logging.INFO)
  with FileStream(args.mod_path) as stream:
    pack_archive(args.pico_home, args.carts_path, stream, args.map, compress=args.compress or args.compress_more, release=args.release, compress_more=args.compress_more, test=args.test)
  logging.info('DONE')
    
if __name__ == '__main__':
    main()

