from antlr4 import *
from FGDLexer import FGDLexer
from FGDParser import FGDParser
from FGDVisitor import FGDVisitor
from FGDListener import FGDListener
from collections import namedtuple
from dotdict import dotdict
import logging

class ClassDef:
  def __init__(self, name, type):
    self.name = name
    self.type = type
    self.bases = {}
    self.properties = {}
  def __repr__(self):
    return type(self)
  def __str__(self):
    s = self.name + " @" + self.type
    if len(self.bases)>0:
      s += " : "
      s += ",".join(self.bases.keys())
    s += " "
    s += str(self.properties)
    return s
  def addBaseClass(self, cls):
    self.bases[cls.name] = cls
    # flatten properties
    for k,v in cls.properties.items():
      self.add(k, v)

  # find "name" property in self of base class
  def add(self, name, value):
    self.properties[name] = value

  def get(self, name, default=None):
    return self.properties.get(name, default)

  # get all valued properties
  def getAll(self):
    return self.properties
    
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

      classdef = ClassDef(classname, self.getText(ctx.classtype))
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
              classdef.addBaseClass(self.result[parentclass])
          elif attr.untypedproperty():
            # flatten additional properties using a dot notation
            for pair in attr.untypedproperty():
              attribute = pair.QUOTED_STRING().getText().lower().strip('"')
              value = pair.value().getText().lower().strip('"')
              classdef.add(name + "." + attribute, value)
                    
      for prop in ctx.classprops().typedproperty():        
        name = self.getSafeText(prop.propertyname)        
        valuetype = self.getSafeText(prop.valuetype)        
        value = prop.value() and self.getText(prop.value) or None
        if valuetype == "flags": 
          # decode bitfield         
          value = 0
          for option in prop.option():
            optionvalue = int(self.getSafeText(option.value))
            optionkey = int(self.getText(option.optionkey))
            if optionvalue == 1:
              value |= optionkey       
        elif value:
          if name in ['dmg','sounds','health','light','lip']:
            value = int(value)
          elif name in ['angle','wait','delay']:
            value = float(value)
        # register property
        if value is not None: classdef.add(name, value)

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
    self.result = FGD_walker.result

if __name__ == '__main__':
  filename = "C:\\Users\\Frederic\\AppData\\Roaming\\TrenchBroom\\games\\q8k\\test.fgd"
  with open(filename,'r') as f:
    FGDReader(f.read())
