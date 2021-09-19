from antlr4 import *
from FGDLexer import FGDLexer
from FGDParser import FGDParser
from FGDVisitor import FGDVisitor
from FGDListener import FGDListener
from collections import namedtuple
from dotdict import dotdict
import logging

class FGDWalker(FGDListener):     
    def __init__(self):
      self.result = dotdict({})

    def getText(self, ctx):
      return ctx().getText().strip('"')
    def getSafeText(self, ctx):
      return ctx().getText().lower().strip('"')

    def exitClassdef(self, ctx):
      classname = self.getText(ctx.classname)
      if classname in self.result:
        logging.warning("FGD class: {} already registered".format(classname))

      classdef = dotdict({
        'type': self.getText(ctx.classtype),
        'bases': dotdict({})
      })
      self.result[classname] = classdef

      # extract class attributes (base class, size...)
      if ctx.classattribute():        
        for attr in ctx.classattribute():          
          name = self.getText(attr.KEYWORD)
          if name=='base':
            for parentclass in attr.attributeproperty():            
              parentclass = self.getText(parentclass.KEYWORD)
              if parentclass not in self.result:
                raise Exception("Unknown parent class: {} defined for class: {}".format(parentclass, classname))
              # reference to parent
              classdef.bases[parentclass] = self.result[parentclass]
                    
      for prop in ctx.classprops().typedproperty():        
        name = self.getSafeText(prop.propertyname)        
        valuetype = self.getSafeText(prop.valuetype)        
        value = None
        if prop.value():
          value = self.getText(prop.value)
          if valuetype == "flags":
            value = 0
            for option in prop.option():
              optionvalue = int(self.getSafeText(option.value))
              optionkey = int(self.getText(option.optionkey))
              if optionvalue == 1:
                value |= optionkey
          elif name in ['dmg','sounds','health','light']:
            value = int(value)
          elif name in ['angle','wait','delay']:
            value = float(value)
          # register property
          classdef[name] = value
      logging.debug("Found FGD class: {} = {}".format(classname, classdef))

class FGDReader():
  def __init__(self, data):    
    lexer = FGDLexer(InputStream(data))
    stream = CommonTokenStream(lexer)
    parser = FGDParser(stream)
    tree = parser.blocks()
    walker = ParseTreeWalker()

    FGD_walker = FGDWalker()
    walker.walk(FGD_walker, tree)    

if __name__ == '__main__':
  filename = "C:\\Users\\Frederic\\AppData\\Roaming\\TrenchBroom\\games\\q8k\\test.fgd"
  with open(filename,'r') as f:
    FGDReader(f.read())
