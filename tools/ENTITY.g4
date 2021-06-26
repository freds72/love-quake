// set CLASSPATH=antlr-4.9-complete.jar
// java org.antlr.v4.Tool -Dlanguage=Python3 -visitor -listener ENTITY.g4

// $env:Path += ";D:\Java\jdk-15.0.1\bin"
// $env:CLASSPATH="antlr-4.9.2-complete.jar"

grammar ENTITY;

// parser
actors:
  block* EOF
  ;

block:
  '{' pair* '}'
  ;

pair:
  keyword args
  ;
  
keyword:
  QUOTED_STRING
  ;
  
args:
  QUOTED_STRING
  ;

// lexer
QUOTED_STRING:
  '"' (~('"' | '\\' | '\r' | '\n') )+ '"'
  ;

fragment AZ:
  'A'..'Z'
  ;

fragment CHAR:
  ('a'..'z'|'A'..'Z'|'_')
  ;

fragment DIGIT
  : ('0'..'9')
  ;

fragment BOOLEAN
  : ('true' | 'false')
  ;

BLOCKCOMMENT
   : '/*' .*? '*/' -> skip
   ;

LINECOMMENT
   : '//' ~ [\r\n]* -> skip
   ;

WS
   : [ \t\n\r] + -> skip
   ;