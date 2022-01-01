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
import logging

class ENTITYWalker(ENTITYListener):     
    def __init__(self, classes):
      self.result = []
      self.classes = classes

    def exitBlock(self, ctx):
      # entity properties      
      properties=dotdict({})
      classname = None
      for pair in ctx.pair():
        attribute = pair.keyword().getText().lower().strip('"')
        value = pair.args().getText().lower().strip('"')

        # decode special attributes
        if attribute in ['origin']:
          x,y,z=[float(v) for v in value.split(' ')]
          # fix Quake y/z orientation
          value=dotdict({'x':x,'y':z,'z':y})
        elif attribute in ['angle','speed','spawnflags','_lightmap_scale','lip']:
          value=int(value)
        elif attribute in ['delay','wait']:
          value=float(value)        
        elif attribute=="classname":
          classname = value
        # persist value
        properties[attribute] = value
     
      if not classname:
        raise Exception("Missing classname for entity: {}".format(ctx.getText()))
      
      # find defining class
      if classname not in self.classes:
        logging.warning("Base class: {} not found for entity: {}".format(classname, ctx.getText()))
        return

      # flatten all parent properties
      # bad idea? assumes no naming conflicts
      classdef = self.classes[classname]      
      for k,v in classdef.getAll().items():
        if k not in properties:
          properties[k] = v
      self.result.append(properties)

class ENTITYReader():
  def __init__(self, data, classes):    

    lexer = ENTITYLexer(InputStream(data))
    stream = CommonTokenStream(lexer)
    parser = ENTITYParser(stream)
    tree = parser.actors()
    walker = ParseTreeWalker()

    ENTITY_walker = ENTITYWalker(classes)
    walker.walk(ENTITY_walker, tree)
    self.entities = ENTITY_walker.result
