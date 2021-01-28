import os
import re
import io
import math
import logging
import argparse
from ctypes import *
from collections import namedtuple
from tqdm import tqdm
from bsp_reader import pack_bsp
from python2pico import *

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

def pack_archive(pico_path, carts_path, root, filename, mapname=None, compress=False, release=None, dump_lightmaps=False, compress_more=False):
  # extract data
  map_data = pack_bsp(filename)

  game_data = compress and compress_byte_str(map_data, more=compress_more) or map_data
  
  # export to game
  to_multicart(game_data, pico_path, carts_path, "q8k")  

def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("--pico-home", required=True, type=str, help="Full path to PICO8 folder")
  parser.add_argument("--carts-path", required=True,type=str, help="Path to carts folder where game is exported")
  parser.add_argument("--bsp", required=True, type=str, help="Path to BSP file")
  parser.add_argument("--compress", action='store_true', required=False, help="Enable compression (default: false)")
  parser.add_argument("--compress-more", action='store_true', required=False, help="Brute force search of best compression parameters. Warning: takes time (default: false)")
  parser.add_argument("--release", required=False,  type=str, help="Generate html+bin packages with given version. Note: compression mandatory if number of carts above 16.")
  parser.add_argument("--dump-lightmaps", action='store_true', required=False, help="Writes lightmaps to disk")

  args = parser.parse_args()

  logging.basicConfig(level=logging.INFO)
  pack_archive(args.pico_home, args.carts_path, os.path.curdir, args.bsp, compress=args.compress or args.compress_more, release=args.release, compress_more=args.compress_more)
  logging.info('DONE')
    
if __name__ == '__main__':
    main()

