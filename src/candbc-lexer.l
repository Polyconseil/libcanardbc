/*  candbc-lexer.c --  lexical analyzer for DBC files
    Copyright (C) 2007-2009,2014 Andreas Heitmann

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>. */

%{

#include <stdio.h>
#include <string.h>

#include <candbc-model.h>

#include "candbc-parser.h"

%}

%option yylineno

ws		[ \t]+
decnumber	[-+]?[0-9]+
hexnumber	0x[0-9a-fA-F]+
double_val	[-+]?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?
id		[a-zA-Z_]([_a-zA-Z0-9]*)?
string		\"([^"\\]|(\\.))*\"
nl		[\n\r]

%%

"//"[^\n]*	 ;

"VERSION"	       { return T_VERSION;	   }
"BO_"		       { return T_BO;		   }
"BS_"		       { return T_BS;		   }
"BU_"		       { return T_BU;		   }
"SG_"		       { return T_SG;		   }
"EV_"		       { return T_EV;		   }
"SIG_VALTYPE_"	       { return T_SIG_VALTYPE;	   }
"NS_"		       { return T_NS;		   }
"INT"		       { return T_INT;		   }
"FLOAT" 	       { return T_FLOAT;	   }
"NAN"		       { return T_NAN;		   }
"STRING"	       { return T_STRING;	   }
"ENUM"		       { return T_ENUM; 	   }
"HEX"		       { return T_HEX;		   }

"NS_DESC_"	       { return T_NS_DESC;	   }
"CM_"		       { return T_CM;		   }
"BA_DEF_"	       { return T_BA_DEF;	   }
"BA_"		       { return T_BA;		   }
"VAL_"		       { return T_VAL;		   }
"CAT_DEF_"	       { return T_CAT_DEF;	   }
"CAT_"		       { return T_CAT;		   }
"FILTER"	       { return T_FILTE;	   }
"BA_DEF_DEF_"	       { return T_BA_DEF_DEF;	   }
"EV_DATA_"	       { return T_EV_DATA;	   }
"ENVVAR_DATA_"	       { return T_ENVVAR_DATA;	   }
"SGTYPE_"	       { return T_SGTYPE;	   }
"SGTYPE_VAL_"	       { return T_SGTYPE_VAL;	   }
"BA_DEF_SGTYPE_"       { return T_BA_DEF_SGTYPE;   }
"BA_SGTYPE_"	       { return T_BA_SGTYPE;	   }
"SIG_TYPE_REF_"        { return T_SIG_TYPE_REF;    }
"VAL_TABLE_"	       { return T_VAL_TABLE;	   }
"SIG_GROUP_"	       { return T_SIG_GROUP;	   }
"SIGTYPE_VALTYPE_"     { return T_SIGTYPE_VALTYPE; }
"BO_TX_BU_"	       { return T_BO_TX_BU;	   }
"BA_DEF_REL_"	       { return T_BA_DEF_REL;	   }
"BA_REL_"	       { return T_BA_REL;	   }
"BA_DEF_DEF_REL_"      { return T_BA_DEF_DEF_REL;  }
"BU_SG_REL_"	       { return T_BU_SG_REL;	   }
"BU_EV_REL_"	       { return T_BU_EV_REL;	   }
"BU_BO_REL_"	       { return T_BU_BO_REL;	   }
"SG_MUL_VAL_"	       { return T_SG_MUL_VAL;	   }
"DUMMY_NODE_VECTOR"[0-3] {
   yylval.number = yytext[17]-'0';
   return T_DUMMY_NODE_VECTOR;
}

{nl}		 ;
{ws}		 ;

{id}		 {
		   yylval.string = strdup(yytext);
		   return T_ID;
		 }

{string}	 {
		   int len = strlen(yytext);
		   if(len>2) {
		     yylval.string = (char *) malloc (len-1);
		     memcpy (yylval.string, yytext+1, len-2);
		     yylval.string[len-2]='\0';
		   } else {
		     yylval.string = NULL;
		   }
		   return T_STRING_VAL;
		 }

{decnumber}	 {
		   yylval.number = atoll(yytext);
		   return T_INT_VAL;
		 }

{hexnumber}	 {
		   yylval.number = strtol(yytext,NULL,16);
		   return T_INT_VAL;
		 }

{double_val}	 {
		   yylval.double_val = strtod(yytext, NULL);
		   return T_DOUBLE_VAL;
		 }

":"		 { return T_COLON; }
";"		 { return T_SEMICOLON; }
"|"		 { return T_SEP; }
","		 { return T_COMMA; }
"@"		 { return T_AT; }
"+"		 { return T_PLUS; }
"-"		 { return T_MINUS; }
"["		 { return T_BOX_OPEN; }
"]"		 { return T_BOX_CLOSE; }
"("		 { return T_PAR_OPEN; }
")"		 { return T_PAR_CLOSE; }

<<EOF>> 	 { yyterminate(); }
.		 { return yytext[0]; }

%%

int
yywrap()
{
       return 1;
}
