# Generated from FGD.g4 by ANTLR 4.9.2
from antlr4 import *
if __name__ is not None and "." in __name__:
    from .FGDParser import FGDParser
else:
    from FGDParser import FGDParser

# This class defines a complete generic visitor for a parse tree produced by FGDParser.

class FGDVisitor(ParseTreeVisitor):

    # Visit a parse tree produced by FGDParser#blocks.
    def visitBlocks(self, ctx:FGDParser.BlocksContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FGDParser#classdef.
    def visitClassdef(self, ctx:FGDParser.ClassdefContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FGDParser#classtype.
    def visitClasstype(self, ctx:FGDParser.ClasstypeContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FGDParser#classattribute.
    def visitClassattribute(self, ctx:FGDParser.ClassattributeContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FGDParser#attributeproperty.
    def visitAttributeproperty(self, ctx:FGDParser.AttributepropertyContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FGDParser#classname.
    def visitClassname(self, ctx:FGDParser.ClassnameContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FGDParser#tooltip.
    def visitTooltip(self, ctx:FGDParser.TooltipContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FGDParser#classprops.
    def visitClassprops(self, ctx:FGDParser.ClasspropsContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FGDParser#untypedproperty.
    def visitUntypedproperty(self, ctx:FGDParser.UntypedpropertyContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FGDParser#typedproperty.
    def visitTypedproperty(self, ctx:FGDParser.TypedpropertyContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FGDParser#option.
    def visitOption(self, ctx:FGDParser.OptionContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FGDParser#valuetype.
    def visitValuetype(self, ctx:FGDParser.ValuetypeContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FGDParser#propertyname.
    def visitPropertyname(self, ctx:FGDParser.PropertynameContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FGDParser#value.
    def visitValue(self, ctx:FGDParser.ValueContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FGDParser#optionkey.
    def visitOptionkey(self, ctx:FGDParser.OptionkeyContext):
        return self.visitChildren(ctx)



del FGDParser