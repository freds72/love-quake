import struct
import os
import re
import io
import math
import logging
from collections import namedtuple
from dotdict import dotdict
from PIL import Image, ImageFilter, ImageDraw

# helper methods for image manipulation
class ImageReader():  
  def __init__(self, palette):
    # image name -> tiles
    self.rgba_to_pico = {}
    if len(palette)>16:
      raise Exception("Invalid palette length: {} - must be 16.".format(len(palette)))
    
    for i,rgba in enumerate(palette):
      self.rgba_to_pico[rgba + (255,)] = i
    # forced transparency color
    self.rgba_to_pico[(0,0,0,0)] = -1
    self.rgba_to_pico[(255,255,255,0)] = -1
    
  def pixel_to_pico(self, img, x, y, trans):
    low = img.getpixel((x,y))
    if low not in self.rgba_to_pico:
      print(self.rgba_to_pico)
      raise Exception("Image reader - invalid color: {} at {},{}".format(low, x, y))
    low = self.rgba_to_pico[low]
    if low==-1: low = trans
    return low

  # convert an image into a pair of tiles address and tiles data (binary)
  def read(self, stream, name):
    logging.debug("Reading image: {}".format(name))
    with stream.read(name) as image_data:

      # read image bytes
      src_io = io.BytesIO(image_data.read())

      src = Image.open(src_io)
      src_width, src_height = src.size

      # resize to multiple of 16x16
      # + force known image format
      width = 8*(math.ceil(src_width/8))
      height = 8*(math.ceil(src_height/8))
      if width>512 or height>256:
        raise Exception("Image: {} too large: {}x{}px - must be 512x256 max.".format(name,src_width,src_height))

      img = Image.new('RGBA', (width, height), (0,0,0,0))
      img.paste(src, (0,0,src_width,src_height))

      # find a transparency color
      all_colors = set([rgba for rgba,i in self.rgba_to_pico.items() if i!=-1])

      for j in range(src_height):
        for i in range(src_width):
          rgba = img.getpixel((i,j))
          if rgba in all_colors: all_colors.remove(rgba)
      pico8_transparency = 0
      # pick a random color to act as transparent color
      if len(rgba)>0: pico8_transparency = self.rgba_to_pico[all_colors.pop()]

      tw = math.floor(width/8)
      th = math.floor(height/8)
      # print("Processing: {} - {}x{} pix -> {}x{}".format(name,src_width,src_height,width,height))

      sprites = [bytes([0]*64)]
      frame_tiles = []
      tiles = 0
      for j in range(th):
        for i in range(tw):
          # read 8x8 blocks
          image_data = bytes([])
          for y in range(8):
            pixels = []
            for x in range(0,8,2):
              # image is using the pico palette (+transparency)
              # print(indexed_to_rgba[img.getpixel((i*16 + x + n, j*16 + y))])
              low = self.pixel_to_pico(img, i*8 + x, j*8 + y, pico8_transparency)
              high = self.pixel_to_pico(img, i*8 + x + 1, j*8 + y, pico8_transparency)
              pixels.append(low|high<<4)
            image_data += bytes(pixels[::-1])
          # skip tile 0 (transparent)
          tileid = 0
          # skip fully transparent tile
          if not all(b==pico8_transparency|pico8_transparency<<4 for b in image_data):
            # remove duplicates (unlikely but "cheap" optimization)
            if image_data in sprites:            
              tileid = sprites.index(image_data)
            else:
              tileid = len(sprites)
              sprites.append(image_data)
              tiles+=1
          # reference to corresponding tiles
          frame_tiles.append(tileid)

      logging.info("Image: {} - unique tiles#: {}".format(name, tiles))

      return dotdict({
        'name': name,
        'tiles': frame_tiles,
        'tiles_width':  tw,
        'size_pixels': (src_width, src_height),
        'background': pico8_transparency,
        'sprites': sprites})
