/*  candbc-parser.c --  parser for DBC files
    Copyright (C) 2007-2009 Andreas Heitmann

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
#include <sys/types.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <ctype.h>
#include <math.h>

#include <candbc-model.h>

/* Tell Bison how much stack space is needed. */
#define YYMAXDEPTH 20000

%}

/*
 * Define the parameter name of the yyparse() argument
 */
%parse-param {void* dbcptr}

%union {
  number_t                     number;
  double                       double_val;
  string_t                     string;
  object_type_t                object_type;
  signal_t                    *signal;
  node_list_t                 *node_list;
  string_list_t               *string_list;
  mux_info_t                   mux_info;
  signal_list_t               *signal_list;
  string_t                     signal_name;
  string_list_t               *signal_name_list;
  signal_group_t              *signal_group;
  signal_group_list_t         *signal_group_list;
  message_t                   *message;
  message_list_t              *message_list;
  attribute_value_t           *attribute_value;
  attribute_object_class_t     attribute_object_class;
  attribute_rel_t             *attribute_rel;
  attribute_rel_list_t        *attribute_rel_list;
  attribute_definition_t      *attribute_definition;
  attribute_definition_list_t *attribute_definition_list;
  dbc_t                       *dbc;
  envvar_t                    *envvar;
  envvar_list_t               *envvar_list;
  val_map_entry_t             *val_map_entry;
  val_map_t                   *val_map;
  valtable_list_t             *valtable_list;
  valtable_t                  *valtable;
}

%{
extern int yylex (void);
extern char *yytext;
extern int   yylineno;

static void
yyerror (void* dbcptr, char* msg)
{
  fprintf(stderr,"Error in line %d '%s', symbol '%s'\n",
          yylineno, msg, yytext);
}

/* context dependent object access (TODO: replace by dbc pointer) */
char *current_yacc_file;
dbc_t *current_dbc;
string_t current_attribute;

static attribute_definition_t *
attribute_definition_find(string_t name, attribute_object_class_t aoc)
{
  /* lookup attribute in attribute_definition_list */
  attribute_definition_list_t *adl;
  attribute_definition_t *ret = NULL;

  for(adl = current_dbc->attribute_definition_list;
      adl != NULL;
      adl=adl->next) {
    if(!strcmp(adl->attribute_definition->name,name)) {
      int found;

      switch(adl->attribute_definition->object_type) {
      case ot_network:
      case ot_node:
      case ot_message:
      case ot_signal:
        found = (aoc == aoc_object);
        break;
      case ot_node_signal:
      case ot_node_message:
        found = (aoc == aoc_relation);
        break;
      default:
        found = 0;
      }
      if(found) {
        ret = adl->attribute_definition;
        break;
      }
    }
  }
  return ret;
}

static node_t *node_find(string_t name)
{
  node_list_t *nl;

  for(nl = current_dbc->node_list; nl != NULL; nl = nl->next) {
    if(nl->node->name != NULL) {
      if(!strcmp(nl->node->name, name)) {
        return nl->node;
      }
    }
  }
  return NULL;
}

static message_t *message_find(uint32 id)
{
  message_list_t *ml;

  for(ml = current_dbc->message_list; ml != NULL; ml = ml->next)
    if(ml->message->id == id)
      return ml->message;
  return NULL;
}


static signal_t *signal_find(uint32 id, string_t name)
{
  message_list_t *ml;
  signal_list_t *sl;

  for(ml = current_dbc->message_list; ml != NULL; ml = ml->next)
    if(ml->message->id == id)
      for(sl = ml->message->signal_list; sl != NULL; sl = sl->next)
        if(sl->signal->name != NULL)
          if(!strcmp(sl->signal->name,name))
            return sl->signal;
  return NULL;
}

static envvar_t *envvar_find(string_t name)
{
  envvar_list_t *el;

  for(el = current_dbc->envvar_list; el != NULL; el = el->next)
    if(el->envvar->name != NULL)
      if(!strcmp(el->envvar->name,name))
        return el->envvar;
  return NULL;
}

/*
 * create a new attribute and append it to the attribute list "al".
 *
 * name - name of the new attribute
 * av   - value of the new attribute
 *
 * if the attribute with the given name is already in
 * current_dbc->attribute_defition_list, the value is cast to the
 * already existing type.
 */
static void attribute_append(
  attribute_list_t **al,
  string_t           name,
  attribute_value_t *av)
{
  CREATE(attribute_t,a);
  CREATE(attribute_list_t,al_new);

  /* search for the end of the list and link new node */
  if(*al == NULL) {
    *al = al_new;
  } else {
    attribute_list_t *linkfrom = linkfrom = *al;
    while(linkfrom->next != NULL) {
      linkfrom = linkfrom->next;
    }
    linkfrom ->next = al_new;
  }
  al_new->next = NULL;

  /* look up value type in attribute definition list */
  attribute_definition_t *const ad =
    attribute_definition_find(name, aoc_object);

  if(ad != NULL) {
    /* dynamic cast */
    if(   av->value_type == vt_integer
       && ad->value_type == vt_float) {
      av->value.double_val = (double)av->value.int_val;
      av->value_type = ad->value_type;
    } else if(   av->value_type == vt_float
              && ad->value_type == vt_integer) {
      printf("%lf -> ", av->value.double_val);
      av->value.int_val = (sint32)lrint(av->value.double_val);
      printf("%ld\n", av->value.int_val);
      av->value_type = ad->value_type;
    } else if(   av->value_type == vt_integer
              && ad->value_type == vt_hex) {
      av->value.hex_val = (uint32)av->value.int_val;
      av->value_type = ad->value_type;
    } else if(   av->value_type == vt_integer
              && ad->value_type == vt_enum) {
#ifdef CONVERT_INT_TO_ENUM
      int eindex = av->value.int_val;
      string_list_t *el;

      /* goto element eindex in the enum list and set the string */
      for(el = ad->range.enum_list;
          el != NULL;
          el = el->next, eindex--) {
        if(eindex == 0) {
          av->value.enum_val = strdup(el->string);
        }
      }
      av->value_type = ad->value_type;
#endif
    } else if(av->value_type != ad->value_type) {
      fprintf(stderr, "error: unhandled type conversion: %d->%d\n",
              av->value_type,
              ad->value_type);
    }
  }

  /* copy attribute name and value*/
  a->name  = name;
  a->value = av;

  /* fill new list element */
  al_new->attribute = a;
}

%}

%token T_COLON
%token T_SEMICOLON
%token T_SEP
%token T_AT
%token T_PLUS
%token T_MINUS
%token T_BOX_OPEN
%token T_BOX_CLOSE
%token T_PAR_OPEN
%token T_PAR_CLOSE
%token T_COMMA
%token T_ID
%token T_STRING_VAL
%token T_INT_VAL
%token T_DOUBLE_VAL

%token T_VERSION
%token T_INT
%token T_FLOAT
%token T_STRING
%token T_ENUM
%token T_HEX
%token T_BO         /* Botschaft */
%token T_BS
%token T_BU         /* Steuergerät */
%token T_SG         /* Signal */
%token T_EV         /* Environment */
%token T_NS
%token T_NS_DESC
%token T_CM         /* Comment */
%token T_BA_DEF     /* Attribut-Definition */
%token T_BA         /* Attribut */
%token T_VAL
%token T_CAT_DEF
%token T_CAT
%token T_FILTE
%token T_BA_DEF_DEF
%token T_EV_DATA
%token T_ENVVAR_DATA
%token T_SGTYPE
%token T_SGTYPE_VAL
%token T_BA_DEF_SGTYPE
%token T_BA_SGTYPE
%token T_SIG_TYPE_REF
%token T_VAL_TABLE
%token T_SIG_GROUP
%token T_SIG_VALTYPE
%token T_SIGTYPE_VALTYPE
%token T_BO_TX_BU
%token T_BA_DEF_REL
%token T_BA_REL
%token T_BA_DEF_DEF_REL
%token T_BU_SG_REL
%token T_BU_EV_REL
%token T_BU_BO_REL
%token T_SG_MUL_VAL
%token T_DUMMY_NODE_VECTOR
%token T_NAN

%type <number>                    T_INT_VAL bit_start bit_len
                                  endianess signedness T_DUMMY_NODE_VECTOR
%type <double_val>                T_DOUBLE_VAL scale offset min max double_val
%type <string>                    T_ID T_STRING_VAL version
%type <string_list>               space_identifier_list comma_identifier_list
%type <string_list>               comma_string_list
%type <node_list>                 space_node_list node_list
%type <mux_info>                  mux_info
%type <signal>                    signal
%type <signal_list>               signal_list
%type <signal_name>               signal_name
%type <signal_name_list>          signal_name_list
%type <signal_group>              signal_group
%type <signal_group_list>         signal_group_list
%type <message>                   message
%type <message_list>              message_list
%type <object_type>               attribute_object_type
%type <attribute_value>           attribute_value
%type <attribute_object_class>    attribute_definition_object_or_relation
%type <attribute_rel>             attribute_rel
%type <attribute_rel_list>        attribute_rel_list
%type <attribute_definition>      attribute_definition
%type <attribute_definition_list> attribute_definition_list
%type <envvar>                    envvar
%type <envvar_list>               envvar_list
%type <val_map>                   val_map
%type <val_map_entry>             val_map_entry
%type <valtable_list>             valtable_list
%type <valtable>                  valtable
%%

/*
 * the dbc file format is not context-free. we handle this by using
 * mid-rule actions to partially fill the dbc structure with data
 * needed later.
 */
dbc:
      {
        CREATE(network_t, network);
        current_dbc = (dbc_t *)dbcptr;
        current_dbc->network = network;
        current_dbc->network->comment = NULL;
        current_dbc->network->attribute_list = NULL;
      }
        version                   /* 2 */
        symbol_section            /* 3 ignored */
        message_section           /* 4 ignored */
        node_list                 /* 5 */
      { current_dbc->node_list = $5; }
        valtable_list             /* 7 */
      { current_dbc->valtable_list = $7; }
        message_list              /* 9 */
      { current_dbc->message_list = $9; }
        message_transmitter_list  /* 11 changes message */
        envvar_list               /* 12 */
      { current_dbc->envvar_list  = $12; }
        envvar_data_list          /* 14 */
        comment_list              /* 15 changes target objects */
        attribute_definition_list /* 16 */
      { current_dbc->attribute_definition_list = $16; }
        attribute_definition_default_list /* 18 changes attr. definition list */
        attribute_list            /* 19 changes target objects */
	attribute_rel_list        /* 20 */
        val_list                  /* 21 */
        sig_valtype_list          /* 22 changes signals */
        signal_group_list         /* 23 */
      {
        current_dbc->version            = $2;
        current_dbc->signal_group_list  = $23;
	current_dbc->attribute_rel_list = $20;
      }
    ;

version: T_VERSION T_STRING_VAL { $$ = $2; };

symbol_section:
      T_NS T_COLON
    | T_NS T_COLON symbol_list;

symbol_list:
      symbol
    | symbol symbol_list
    ;

symbol:
      T_NS_DESC
    | T_CM
    | T_BA_DEF
    | T_BA
    | T_VAL
    | T_CAT_DEF
    | T_CAT
    | T_FILTE
    | T_BA_DEF_DEF
    | T_EV_DATA
    | T_ENVVAR_DATA
    | T_SGTYPE
    | T_SGTYPE_VAL
    | T_BA_DEF_SGTYPE
    | T_BA_SGTYPE
    | T_SIG_TYPE_REF
    | T_VAL_TABLE
    | T_SIG_GROUP
    | T_SIG_VALTYPE
    | T_SIGTYPE_VALTYPE
    | T_BO_TX_BU
    | T_BA_DEF_REL
    | T_BA_REL
    | T_BA_DEF_DEF_REL
    | T_BU_SG_REL
    | T_BU_EV_REL
    | T_BU_BO_REL
    | T_SG_MUL_VAL
    ;

envvar_list:
      /* empty */
    {
      $$ = NULL;
    }
    | envvar envvar_list
    {
      CREATE(envvar_list_t,list);
      list->envvar = $1;
      list->next   = $2;
      $$ = list;
    }
    ;

envvar:
      T_EV                    /* EV_               */
      T_ID                    /*  2: environment variable name */
      T_COLON                 /* :                 */
      T_INT_VAL               /*  4: type: 0 int, 1 float, 0 string, 0 data */
      T_BOX_OPEN              /* [                 */
      T_INT_VAL               /*  6: minimum value */
      T_SEP                   /* |                 */
      T_INT_VAL               /*  8: maximum value */
      T_BOX_CLOSE             /* ]                 */
      T_STRING_VAL            /* 10: unit          */
      T_INT_VAL               /* 11: initial value */
      T_INT_VAL               /* 12: ??? (maybe a counter/index) */
      T_DUMMY_NODE_VECTOR     /* 13: access type   */
      comma_identifier_list   /* 14: node list     */
      T_SEMICOLON
    {
      CREATE(envvar_t, envvar);

      envvar->name    = $2;
      envvar->envtype = (envtype_t)$4;
      envvar->min     = $6;
      envvar->max     = $8;
      envvar->unit    = $10;
      envvar->max     = $11;
      envvar->index   = $12;
      envvar->access  = (accesstype_t)$13;
      envvar->node_list = $14;
      envvar->val_map = NULL;
      envvar->comment = NULL;
      $$ = envvar;
    }
    ;

envvar_data_list:
      /* empty */
    | envvar_data envvar_data_list
    ;

envvar_data:
      T_ENVVAR_DATA T_ID /* environment variable name */
      T_COLON T_INT_VAL  /* length (data) */
      T_SEMICOLON
      {
        free($2);
      }
    ;

attribute_value:
    /*
     * may be int, hex or enum selector, depending on attribute definition
     * the data type will be fixed later during attribute_append
     */
      T_INT_VAL
    {
      CREATE(attribute_value_t, av);
      av->value_type    = vt_integer; /* preliminary value type */
      av->value.int_val = $1;
      $$ = av;
    }
    | T_STRING_VAL
    {
      CREATE(attribute_value_t, av);
      av->value_type = vt_string;
      av->value.string_val = $1;
      $$ = av;
    }
    | T_DOUBLE_VAL
    {
      CREATE(attribute_value_t, av);
      av->value_type = vt_float;
      av->value.double_val = $1;
      $$ = av;
    }
    ;

attribute_list:
      /* empty */
    | attribute attribute_list
    ;

attribute:
      T_BA T_STRING_VAL attribute_value T_SEMICOLON
    {
      if(current_dbc->network != NULL) {
        attribute_append(&current_dbc->network->attribute_list,$2,$3);
      } else {
        fprintf(stderr,"error: network not found\n");
        free($2);
        attribute_value_free($3);
      }
    }
    | T_BA T_STRING_VAL T_BU T_ID      attribute_value T_SEMICOLON
    {
      node_t *const node = node_find($4);
      if(node != NULL) {
        attribute_append(&node->attribute_list,$2,$5);
      } else {
        fprintf(stderr,"error: node %s not found\n", $4);
        attribute_value_free($5);
      }
      free($4);
    }
    | T_BA T_STRING_VAL T_BO T_INT_VAL attribute_value T_SEMICOLON
    {
      message_t *const message = message_find($4);
      if(message != NULL) {
        attribute_append(&message->attribute_list,$2,$5);
      } else {
        fprintf(stderr,"error: message %d not found\n", (int)$4);
        attribute_value_free($5);
        free($2);
      }
    }
    | T_BA             /* BA_ */
      T_STRING_VAL     /* attribute name */
      T_SG             /* SG_ */
      T_INT_VAL        /* message id */
      T_ID             /* signal name */
      attribute_value  /* attribute value */
      T_SEMICOLON      /* ; */
    {
      signal_t *const signal = signal_find($4,$5);

      if(signal != NULL) {
        attribute_append(&signal->attribute_list,$2,$6);
      } else {
        fprintf(stderr,"error: signal %d (%s) not found\n", (int)$4, $5);
        attribute_value_free($6);
        free($2);
      }
      free($5);
    }
    ;

attribute_rel_list:
      /* empty */
    {
      $$ = NULL;
    }
    | attribute_rel attribute_rel_list
    {
      CREATE(attribute_rel_list_t,list);
      list->attribute_rel = $1;
      list->next          = $2;
      $$ = list;
    }
    ;

attribute_rel:
      /* node-message relational attribute */
      T_BA_REL        /* 1 BA_REL_ */
      T_STRING_VAL    /* 2 attribute name */
      T_BU_SG_REL     /* 3 BU_SG_REL */
      T_ID            /* 4 node name */
      T_SG            /* 5 SG_  */
      T_INT_VAL       /* 6 message id */
      signal_name     /* 7 signal name */
      attribute_value /* 8 attribute value */
      T_SEMICOLON     /* 9 ; */
    {
      node_t *node = node_find($4);
      message_t *message = message_find($6);
      signal_t *signal = signal_find($6,$7);

      if(   (node != NULL)
         && (message != NULL)
         && (signal != NULL)) {
        CREATE(attribute_rel_t,attribute_rel);
        attribute_rel->name             = $2;
        attribute_rel->node             = node;
        attribute_rel->message          = message;
        attribute_rel->signal           = signal;
        attribute_rel->attribute_value  = $8;
        $$ = attribute_rel;
      } else {
        free($2);
        attribute_value_free($8);
        $$ = NULL;
      }
      free($4);
      free($7);
    }

attribute_definition_default_list:
      /* empty */
    | attribute_definition_default attribute_definition_default_list
    ;

/* set context dependent attribute value type */
attribute_definition_default:
      attribute_definition_object_or_relation
      T_STRING_VAL T_INT_VAL T_SEMICOLON
    {
      attribute_definition_t *const ad = attribute_definition_find($2, $1);
      free($2);
      if(ad != NULL) {
        switch(ad->value_type) {
        case vt_integer: ad->default_value.int_val = $3; break;
        case vt_hex:     ad->default_value.hex_val = (uint32)$3; break;
        case vt_float:   ad->default_value.double_val = (double)$3; break;
        default:
          break;
        }
      }
    }
    | attribute_definition_object_or_relation
      T_STRING_VAL T_DOUBLE_VAL T_SEMICOLON
    {
      attribute_definition_t *const ad = attribute_definition_find($2, $1);
      free($2);
      if(ad != NULL && ad->value_type == vt_float) {
        ad->default_value.double_val = $3;
      }
    }
    | attribute_definition_object_or_relation
      T_STRING_VAL T_STRING_VAL T_SEMICOLON
    {
      attribute_definition_t *const ad = attribute_definition_find($2, $1);
      if(ad != NULL) {
        switch(ad->value_type) {
        case vt_string:
          ad->default_value.string_val = $3;
          break;
        case vt_enum:
          ad->default_value.enum_val = $3;
          break;
        default:
          break;
        }
      } else {
        fprintf(stderr,"error: attribute %s not found\n", $2);
        free($3);
      }
      free($2);
    }
    ;

attribute_definition_object_or_relation:
      T_BA_DEF_DEF     { $$ = aoc_object; }
    | T_BA_DEF_DEF_REL { $$ = aoc_relation; }
    ;

attribute_definition_list:
      /* empty */
    {
      $$ = NULL;
    }
    | attribute_definition attribute_definition_list
    {
      CREATE(attribute_definition_list_t,list);
      list->attribute_definition = $1;
      list->next                 = $2;
      $$ = list;
    }
    ;

attribute_definition:
      attribute_object_type T_STRING_VAL
      T_INT T_INT_VAL T_INT_VAL T_SEMICOLON
    {
      CREATE(attribute_definition_t,ad);
      ad->object_type           = $1;
      ad->name                  = $2;
      ad->value_type            = vt_integer;
      ad->range.int_range.min   = (sint32)$4;
      ad->range.int_range.max   = (sint32)$5;
      ad->default_value.int_val = 0;
      $$ = ad;
    }
    | attribute_object_type T_STRING_VAL
      T_FLOAT double_val double_val T_SEMICOLON
    {
      CREATE(attribute_definition_t,ad);
      ad->object_type              = $1;
      ad->name                     = $2;
      ad->value_type               = vt_float;
      ad->range.double_range.min   = $4;
      ad->range.double_range.max   = $5;
      ad->default_value.double_val = 0;
      $$ = ad;
    }
    | attribute_object_type T_STRING_VAL T_STRING T_SEMICOLON
    {
      CREATE(attribute_definition_t,ad);
      ad->object_type              = $1;
      ad->name                     = $2;
      ad->value_type               = vt_string;
      ad->default_value.string_val = NULL;
      $$ = ad;
    }
    | attribute_object_type T_STRING_VAL T_ENUM comma_string_list T_SEMICOLON
    {
      CREATE(attribute_definition_t,ad);
      ad->object_type            = $1;
      ad->name                   = $2;
      ad->value_type             = vt_enum;
      ad->range.enum_list        = $4;
      ad->default_value.enum_val = NULL;
      $$ = ad;
    }
    | attribute_object_type T_STRING_VAL T_HEX T_INT_VAL T_INT_VAL T_SEMICOLON
    {
      CREATE(attribute_definition_t,ad);
      ad->object_type           = $1;
      ad->name                  = $2;
      ad->value_type            = vt_hex;
      ad->range.hex_range.min   = (uint32)$4;
      ad->range.hex_range.max   = (uint32)$5;
      ad->default_value.hex_val = 0;
      $$ = ad;
    }
    ;

attribute_object_type:
      T_BA_DEF                   { $$ = ot_network; }
    | T_BA_DEF     T_BU          { $$ = ot_node; }
    | T_BA_DEF     T_BO          { $$ = ot_message; }
    | T_BA_DEF     T_SG          { $$ = ot_signal; }
    | T_BA_DEF     T_EV          { $$ = ot_envvar; }
      /* node-signal relation ("Node - Mapped Rx Signal") */
    | T_BA_DEF_REL T_BU_SG_REL   { $$ = ot_node_signal; }
      /* node-message relation ("Node - Tx Message") */
    | T_BA_DEF_REL T_BU_BO_REL   { $$ = ot_node_message; }
    ;

/*********************************************************************/

val_list:
      /* empty */
    | val val_list
    ;

val:
    /* VAL_  messageid signalname  val_mapping ; */
      T_VAL T_INT_VAL signal_name val_map T_SEMICOLON
    {
      signal_t *const signal = signal_find($2,$3);

      if(signal != NULL) {
        if(signal->val_map == NULL) {
          signal->val_map = $4;
        } else {
          fprintf(stderr,
                  "error: duplicate val_map for signal %d (%s)\n", (int)$2, $3);
          val_map_free($4);
        }
      } else {
        fprintf(stderr,"error: signal %d (%s) not found\n", (int)$2, $3);
        val_map_free($4);
      }
      free($3);
    }
    /* VAL_ envvarname val_map */
    | T_VAL T_ID val_map T_SEMICOLON
    {
      envvar_t *const envvar = envvar_find($2);

      if(envvar != NULL) {
        if(envvar->val_map == NULL) {
          envvar->val_map = $3;
        } else {
          fprintf(stderr,
                  "error: duplicate val_map for environment variable %s\n", $2);
          val_map_free($3);
        }
      } else {
        fprintf(stderr,"error: environment variable %s not found\n", $2);
        val_map_free($3);
      }
      free($2);
    }
    ;

val_map:
      /* empty */
    {
      $$ = NULL;
    }
    | val_map_entry val_map
    {
      CREATE(val_map_t, val_map);
      val_map->val_map_entry = $1;
      val_map->next          = $2;
      $$ = val_map;
    }
    ;

val_map_entry:
      T_INT_VAL T_STRING_VAL
    {
      CREATE(val_map_entry_t, val_map_entry);
      val_map_entry->index = $1;
      val_map_entry->value = $2;
      $$ = val_map_entry;
    }
    ;

/*********************************************************************/

sig_valtype_list:
      /* empty */
    | sig_valtype sig_valtype_list
    ;

/*
 * set signal value type in target signal
 *
 * SIG_VALTYPE:
 * no section - signed or unsigned
 * 1 - IEEE float
 * 2 - IEEE double
 */
sig_valtype:
      T_SIG_VALTYPE T_INT_VAL T_ID T_COLON T_INT_VAL T_SEMICOLON
    {
      signal_t *const s = signal_find($2,$3);
      free($3);
      if(s != NULL) {
        switch($5) {
        case 1: s->signal_val_type = svt_float; break;
        case 2: s->signal_val_type = svt_double; break;
        }
      }
    }
    ;

/*********************************************************************/

comment_list:
      /* empty */
    | comment comment_list
    ;

/* TODO: append comment to object */
comment:
      T_CM                     T_STRING_VAL T_SEMICOLON
    {
      if(current_dbc->network != NULL) {
	current_dbc->network->comment =
	  string_merge(current_dbc->network->comment, $2);
      } else {
	string_free($2);
      }
    }
    | T_CM T_EV T_ID           T_STRING_VAL T_SEMICOLON
    {
      envvar_t *const envvar = envvar_find($3);
      if(envvar != NULL) {
	envvar->comment = string_merge(envvar->comment, $4);
      } else {
        fprintf(stderr,"error: environment variable %s not found\n", $3);
	string_free($4);
      }
      string_free($3);
    }
    | T_CM T_BU T_ID           T_STRING_VAL T_SEMICOLON
    {
      node_t *const node = node_find($3);
      if(node != NULL) {
	node->comment = string_merge(node->comment, $4);
      } else {
        fprintf(stderr,"error: node %s not found\n", $3);
        string_free($4);
      }
      string_free($3);
    }
    | T_CM T_BO T_INT_VAL      T_STRING_VAL T_SEMICOLON
    {
      message_t *const message = message_find($3);
      if(message != NULL) {
	message->comment = string_merge(message->comment, $4);
      } else {
        fprintf(stderr,"error: message %s not found\n", $4);
        string_free($4);
      }
    }
    | T_CM T_SG T_INT_VAL T_ID T_STRING_VAL T_SEMICOLON
    {
      signal_t *const signal = signal_find($3, $4);
      if(signal != NULL) {
	signal->comment = string_merge(signal->comment, $5);
      } else {
        fprintf(stderr,"error: signal %d (%s) not found\n", (int)$3, $4);
        string_free($5);
      }
      string_free($4);
    }
    ;

/*********************************************************************/

message_list:
      /* empty */
    {
      $$ = NULL;
    }
    | message message_list
    {
      CREATE(message_list_t,list);
      list->message = $1;
      list->next    = $2;
      $$ = list;
    }
    ;

message:
      T_BO T_INT_VAL T_ID T_COLON T_INT_VAL T_ID signal_list
    {
      CREATE(message_t, m);
      m->id               = $2;
      m->name             = $3;
      m->len              = $5;
      m->sender           = $6;
      m->signal_list      = $7;
      m->comment          = NULL;
      m->attribute_list   = NULL;
      m->transmitter_list = NULL;
      $$ = m;
    }
    ;

/*********************************************************************/

signal_list:
      /* empty */
    {
      $$ = NULL;
    }
    | signal signal_list
    {
      CREATE(signal_list_t,list);
      list->signal = $1;
      list->next   = $2;
      $$ = list;
    }
    ;

signal:
      T_SG signal_name mux_info T_COLON
      bit_start T_SEP bit_len T_AT endianess signedness
      T_PAR_OPEN scale T_COMMA offset T_PAR_CLOSE
      T_BOX_OPEN min T_SEP max T_BOX_CLOSE
      T_STRING_VAL comma_identifier_list
    {
      CREATE(signal_t, signal);
      signal->name       = $2;
      signal->mux_type   = $3.mux_type;
      signal->mux_value  = $3.mux_value;
      signal->bit_start  = $5;
      signal->bit_len    = $7;
      signal->endianess  = $9;
      signal->signedness = $10;
      signal->scale      = $12;
      signal->offset     = $14;
      signal->min        = $17;
      signal->max        = $19;
      signal->unit       = $21;
      signal->signal_val_type = svt_integer;
      signal->receiver_list   = $22;
      signal->comment         = NULL;
      signal->attribute_list  = NULL;
      signal->val_map         = NULL;
      $$ = signal;
    }
    ;

/*********************************************************************/

mux_info:
      /* empty */
    {
      $$.mux_type = m_signal;
      $$.mux_value = 0;
    }
    | T_ID
    {
      switch($1[0]) {
      case 'M':
        $$.mux_type  = m_multiplexor;
        $$.mux_value = 0;
        break;
      case 'm':
        $$.mux_type  = m_multiplexed;
        $$.mux_value = strtoul($1+1, NULL, 10);
        break;
      default:
        /* error: unknown mux type */
        break;
      }
      free($1);
    }
    ;

signal_name:      T_ID                  { $$ = (string_t)$1; }
signal_name_list: space_identifier_list { $$ = (string_list_t *)$1; }

space_identifier_list:
      T_ID
    {
      CREATE(string_list_t,list);
      list->string = $1;
      list->next   = NULL;
      $$ = list;
    }
    | T_ID space_identifier_list
    {
      CREATE(string_list_t,list);
      list->string = $1;
      list->next   = $2;
      $$ = list;
    }
    ;

comma_identifier_list:
      T_ID
    {
      CREATE(string_list_t,list);
      list->string = $1;
      list->next   = NULL;
      $$ = list;
    }
    | T_ID T_COMMA comma_identifier_list
    {
      CREATE(string_list_t,list);
      list->string = $1;
      list->next   = $3;
      $$ = list;
    }
    ;

comma_string_list:
      T_STRING_VAL
    {
      CREATE(string_list_t,list);
      list->string = $1;
      list->next   = NULL;
      $$ = list;
    }
    | T_STRING_VAL T_COMMA comma_string_list
    {
      CREATE(string_list_t,list);
      list->string = $1;
      list->next   = $3;
      $$ = list;
    }
    ;

/* double_val or int_val as float */
double_val:
      T_DOUBLE_VAL  { $$ = $1; }
    | T_NAN         { $$ = NAN; }
    | T_INT_VAL     { $$ = (double)$1; }
    ;

bit_start:   T_INT_VAL    { $$ = $1; };
bit_len:     T_INT_VAL    { $$ = $1; };

scale:  double_val { $$ = $1; };
offset: double_val { $$ = $1; };
min:    double_val { $$ = $1; };
max:    double_val { $$ = $1; };

endianess: T_INT_VAL { $$ = $1; };

signedness:
      T_PLUS  { $$ = 0; }
    | T_MINUS { $$ = 1; }
    ;

/* list of nodes */

space_node_list:
      /* empty */
    {
      $$ = NULL;
    }
    | T_ID space_node_list
    {
      CREATE(node_list_t,list);
      CREATE(node_t,node);
      node->name = $1;
      node->comment = NULL;
      node->attribute_list = NULL;
      list->node = node;
      list->next = $2;
      $$ = list;
    }
    ;

node_list: T_BU T_COLON space_node_list
    {
      $$ = $3;
    }
    ;

valtable_list:
      /* empty */
    {
      $$ = NULL;
    }
    | valtable valtable_list
    {
      CREATE(valtable_list_t, valtable_list);
      valtable_list->next     = $2;
      valtable_list->valtable = $1;
      $$ = valtable_list;
    }
    ;

valtable:
      T_VAL_TABLE T_ID val_map T_SEMICOLON
    {
      CREATE(valtable_t, valtable);
      valtable->name    = $2;
      valtable->comment = NULL;
      valtable->val_map = $3;
      $$ = valtable;
    }
    ;

/* message section (BS) */
message_section: T_BS T_COLON
    ;

/* signal group */
signal_group:
      T_SIG_GROUP T_INT_VAL T_ID T_INT_VAL
      T_COLON signal_name_list T_SEMICOLON
    {
      CREATE(signal_group_t,sg);
      sg->id   = $2;
      sg->name = $3;
      /* TODO: meaning of $4? */
      sg->signal_name_list = $6;
      $$ = sg;
    }
    ;

/* signal group_list */
signal_group_list:
      /* empty */
    {
      $$ = NULL;
    }
    | signal_group signal_group_list
    {
      CREATE(signal_group_list_t,list);
      list->signal_group = $1;
      list->next         = $2;
      $$ = list;
    }
    ;

/* TODO: use comma_node_list */
message_transmitters: T_BO_TX_BU T_INT_VAL T_COLON
                      comma_identifier_list T_SEMICOLON
    {
      message_t *const message = message_find($2);
      if(message != NULL) {
	/* duplicate list: new one replaces old one */
	string_list_free(message->transmitter_list);
	message->transmitter_list = $4;
      } else {
        fprintf(stderr,"error: message %d not found\n", (int)$2);
	string_list_free($4);
      }
    }
    ;

message_transmitter_list:
      /* empty */
    | message_transmitters message_transmitter_list
    ;
