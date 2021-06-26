# Generated from ENTITY.g4 by ANTLR 4.9.2
from antlr4 import *
if __name__ is not None and "." in __name__:
    from .ENTITYParser import ENTITYParser
else:
    from ENTITYParser import ENTITYParser

# This class defines a complete generic visitor for a parse tree produced by ENTITYParser.

class ENTITYVisitor(ParseTreeVisitor):

    # Visit a parse tree produced by ENTITYParser#actors.
    def visitActors(self, ctx:ENTITYParser.ActorsContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by ENTITYParser#block.
    def visitBlock(self, ctx:ENTITYParser.BlockContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by ENTITYParser#pair.
    def visitPair(self, ctx:ENTITYParser.PairContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by ENTITYParser#keyword.
    def visitKeyword(self, ctx:ENTITYParser.KeywordContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by ENTITYParser#args.
    def visitArgs(self, ctx:ENTITYParser.ArgsContext):
        return self.visitChildren(ctx)



del ENTITYParser