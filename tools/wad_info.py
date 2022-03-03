import os
import re
import io
import math
import logging
from ctypes import *
import argparse
import string

from numpy import integer

# credits: https://gist.github.com/JonathonReinhart/b6f355f13021cd8ec5d0101e0e6675b2
class StructHelper(object):
  def __get_value_str(self, name, fmt='{}'):
      val = getattr(self, name)
      if isinstance(val, Array):
          val = list(val)
      return fmt.format(val)

  def __str__(self):
      result = '{}:\n'.format(self.__class__.__name__)
      maxname = max(len(name) for name, type_ in self._fields_)
      for name, type_ in self._fields_:
          value = getattr(self, name)
          result += ' {name:<{width}}: {value}\n'.format(
                  name = name,
                  width = maxname,
                  value = self.__get_value_str(name),
                  )
      return result

  def __repr__(self):
      return '{name}({fields})'.format(
              name = self.__class__.__name__,
              fields = ', '.join(
                  '{}={}'.format(name, self.__get_value_str(name, '{!r}')) for name, _ in self._fields_)
              )

  @classmethod
  def _typeof(cls, field):
      """Get the type of a field
      Example: A._typeof(A.fld)
      Inspired by stackoverflow.com/a/6061483
      """
      for name, type_ in cls._fields_:
          if getattr(cls, name) is field:
              return type_
      raise KeyError

  @classmethod
  def read_from(cls, f):
      result = cls()
      if f.readinto(result) != sizeof(cls):
          raise EOFError
      return result

  @classmethod
  def read_one(cls, f, entry=None):
    if entry:
        f.seek(entry.offset)
    return cls.read_from(f)

  @classmethod
  def read_all(cls, f, entry):
    f.seek(entry.offset)
    result = []
    n = int(entry.size/sizeof(cls))
    for i in range(n):
      result.append(cls.read_from(f))
    return result

  def get_bytes(self):
      """Get raw byte string of this structure
      ctypes.Structure implements the buffer interface, so it can be used
      directly anywhere the buffer interface is implemented.
      https://stackoverflow.com/q/1825715
      """

      # Works for either Python2 or Python3
      return bytearray(self)

      # Python 3 only! Don't try this in Python2, where bytes() == str()
      #return bytes(self)

# warning: outdated/wrong on some structures      
# http://www.gamers.org/dEngine/quake/spec/quake-spec34/qkspec_4.htm
# real sources
# https://github.com/id-Software/Quake/blob/master/QW/client/bspfile.h

class wadhead_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("magic", c_char * 4),
    ("numentries", c_int),
    ("diroffset", c_int)
  ]

class wadentry_t(LittleEndianStructure, StructHelper):
  _pack_ = 1
  _fields_ = [
    ("offset", c_int),
    ("dsize", c_int),
    ("size", c_int),
    ("type", c_char),
    ("compression", c_char),
    ("pad", c_char * 2),
    ("name", c_char * 16)
  ]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--wad", required=True, type=str, help="Full path to WAD file")
    parser.add_argument("--extract", required=False, type=int, help="Extract given entry from WAD")
    parser.add_argument("--ext", required=False, type=str, default="lmp", help="File extension (default: lmp)")

    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO)

    with open(args.wad,"rb") as f:
        header = wadhead_t.read_from(f)
        logging.info("Found WAD header v{} #entries: {}".format(header.magic, header.numentries))
        
        f.seek(header.diroffset)
        directory = []
        for i in range(header.numentries):
            d = wadentry_t.read_one(f)
            # logging.info("Entry #{}: {}".format(i, d))
            directory.append(d)
        
        if args.extract:
            d = directory[args.extract]
            name = d.name.decode("ascii")
            logging.info("Exporting: {}".format(d))
            with open("{}.{}".format(name, args.ext),"wb") as outf:
                f.seek(d.offset)
                outf.write(f.read(d.dsize))

if __name__ == '__main__':
    main()
