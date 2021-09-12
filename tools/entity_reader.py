import sys
import copy
from antlr4 import *
from ENTITYLexer import ENTITYLexer
from ENTITYParser import ENTITYParser
from ENTITYVisitor import ENTITYVisitor
from ENTITYListener import ENTITYListener
from collections import namedtuple
from dotdict import dotdict
from enum import IntFlag

class ENTITYWalker(ENTITYListener):     
    def __init__(self):
      self.result = []

    def exitBlock(self, ctx):
      # entity properties
      properties=dotdict({})
      for pair in ctx.pair():
        attribute = pair.keyword().getText().lower().strip('"')
        value = pair.args().getText().lower().strip('"')
        # decode special attributes
        if attribute in ['origin']:
          x,y,z=[float(v) for v in value.split(' ')]
          # fix Quake y/z orientation
          value=dotdict({'x':x,'y':z,'z':y})
        elif attribute in ['angle','speed','spawnflags','_lightmap_scale']:
          value=int(value)
        # persist value
        properties[attribute] = value
     
      self.result.append(properties)

class ENTITYReader():
  def __init__(self, data):    
    lexer = ENTITYLexer(InputStream(data))
    stream = CommonTokenStream(lexer)
    parser = ENTITYParser(stream)
    tree = parser.actors()
    walker = ParseTreeWalker()

    ENTITY_walker = ENTITYWalker()
    walker.walk(ENTITY_walker, tree)
    self.entities = ENTITY_walker.result
