#ifndef INCLUDE_DBCMODEL_H
#define INCLUDE_DBCMODEL_H

#include <stdlib.h>

#if WITH_DMALLOC
#include <dmalloc.h>
#endif

#include <candbc-types.h>

/* macros */
#define DECLARE_LIST(tlist,tobj) \
typedef struct tlist ## _s  \
{			    \
  tobj ## _t	      tobj;  \
  struct tlist ## _s *next; \
} tlist ## _t

#define DECLARE_LIST_FREE(tlist,tobj) \
  void tlist ## _free(tlist ## _t *tlist);

#define DEFINE_LIST_FREE(tlist,tobj) \
void tlist ## _free(tlist ## _t *tlist) \
{				     \
  while(tlist != NULL) {	     \
    tlist ## _t *next = tlist->next; \
    free(tlist->tobj);		     \
    free(tlist);		     \
    tlist = next;		     \
  }				     \
}

#define DECLARE_PLIST(tlist,tobj) \
typedef struct tlist ## _s  \
{			    \
  tobj ## _t	     *tobj; \
  struct tlist ## _s *next; \
} tlist ## _t

#define DEFINE_PLIST_FREE(tlist, tobj) \
void tlist ## _free(tlist ## _t *tlist) \
{				     \
  while(tlist != NULL) {	     \
    tlist ## _t *next = tlist->next; \
    tobj ## _free(tlist->tobj);      \
    free(tlist);		     \
    tlist = next;		     \
  }				     \
}

#define DECLARE_PLIST_FREE(tlist, tobj) \
void tlist ## _free(tlist ## _t *tlist);

#define DEFINE_PLIST_DUP(tlist, tobj)		 \
tlist##_t *tlist##_dup(tlist##_t *orig) 	 \
{						 \
  tlist##_t *first = NULL;			 \
  tlist##_t *current = NULL;			 \
  for(;orig != NULL; orig=orig->next) { 	 \
	tlist##_t *new = (tlist##_t *)malloc(sizeof(tlist##_t)); \
	if(current != NULL) { current->next = new; } \
	if(first   == NULL) { first = new; }	     \
	new->tobj = tobj##_dup(orig->tobj);	     \
	new->next = NULL;			     \
	current = new;				     \
  }						 \
  return first; 				 \
}

#define CREATE(type,obj) type *(obj) = (type *)malloc(sizeof(type))

/* string type */
typedef char *	      string_t;
DECLARE_LIST(string_list, string);
#define STR0(x) ((x)?(x):"(null)")

/* signal group */
typedef struct {
  uint32	  id;
  string_t	  name;
  string_list_t  *signal_name_list;
} signal_group_t;

/* signal group list */
DECLARE_PLIST(signal_group_list, signal_group);

/* attribute object class */
typedef enum {
  aoc_undefined,
  aoc_object,
  aoc_relation,
} attribute_object_class_t;

/* multiplex type */
typedef enum {
  m_signal,
  m_multiplexor,
  m_multiplexed
} mux_t;

/* multiplex info */
typedef struct {
  mux_t  mux_type;
  uint32 mux_value;
} mux_info_t;

/* signal val type */
typedef enum {
  svt_integer,
  svt_float,
  svt_double
} signal_val_type_t;

/* attribute value type */
typedef enum {
  vt_integer,
  vt_float,
  vt_string,
  vt_enum,
  vt_hex
} value_type_t;

/* attribute value union */
typedef union {
  sint32       int_val;
  double       double_val;
  string_t     string_val;
  string_t     enum_val;
  uint32       hex_val;
} value_union_t;

/* attribute value */
typedef struct {
  value_type_t	value_type;
  value_union_t value;
} attribute_value_t;

/* attribute */
typedef struct {
  string_t	     name;
  attribute_value_t *value;
} attribute_t;

/* attribute list */
DECLARE_PLIST(attribute_list, attribute);

/* node */
typedef struct {
  string_t	    name;
  string_t	    comment;
  attribute_list_t *attribute_list;
} node_t;

/* node list */
DECLARE_PLIST(node_list, node);

/* value map entry */
typedef struct {
  uint32   index;
  string_t value;
} val_map_entry_t;

DECLARE_PLIST(val_map, val_map_entry);

/* value table */
typedef struct {
  string_t   name;
  string_t   comment;
  val_map_t *val_map;
} valtable_t;

DECLARE_PLIST(valtable_list, valtable);

/* signal */
typedef struct {
  string_t	    name;
  mux_t 	    mux_type;
  uint32	    mux_value;
  uint8 	    bit_start;
  uint8 	    bit_len;
  uint8 	    endianess;
  uint8 	    signedness;
  double	    scale;
  double	    offset;
  double	    min;
  double	    max;
  signal_val_type_t signal_val_type;
  string_t	    unit;
  string_list_t    *receiver_list;
  string_t	    comment;
  attribute_list_t *attribute_list;
  val_map_t	   *val_map;
} signal_t;

DECLARE_PLIST(signal_list, signal);

/* message */
typedef struct {
  uint32	    id;
  string_t	    name;
  uint8 	    len;
  string_t	    sender;
  signal_list_t    *signal_list;
  string_t	    comment;
  attribute_list_t *attribute_list;
  string_list_t    *transmitter_list;
} message_t;

/* message list */
DECLARE_PLIST(message_list, message);

/* relational attribute */
typedef struct {
  string_t	     name;
  attribute_value_t *attribute_value;
  node_t	    *node;
  message_t	    *message;
  signal_t	    *signal;
} attribute_rel_t;

/* relational attribute list */
DECLARE_PLIST(attribute_rel_list, attribute_rel);

/* attribute_object type */
typedef enum {
  ot_network,
  ot_node,
  ot_message,
  ot_signal,
  ot_envvar,
  ot_node_signal,
  ot_node_message,
  ot_integer,
  ot_float,
  ot_string,
  ot_enum,
  ot_hex
} object_type_t;

/* integer range */
typedef struct {
  sint32 min;
  sint32 max;
} int_range_t;

/* double range */
typedef struct {
  double min;
  double max;
} double_range_t;

/* hex range */
typedef struct {
  uint32 min;
  uint32 max;
} hex_range_t;

/* attribute definition */
typedef struct {
  object_type_t   object_type;
  string_t	  name;

  value_type_t	  value_type;

  /* range */
  union {
    int_range_t     int_range;
    double_range_t  double_range;
    hex_range_t     hex_range;
    string_list_t  *enum_list;
  } range;

  /* default value */
  value_union_t default_value;

} attribute_definition_t;

/* attribute definition list */
DECLARE_PLIST(attribute_definition_list, attribute_definition);

/* network */
typedef struct {
  attribute_list_t *attribute_list;
  string_t	    comment;
} network_t;

/* env variable */
typedef enum {
  at_unrestricted = 0,
  at_readonly	  = 1,
  at_writeonly	  = 2,
  at_readwrite	  = 3,
} accesstype_t;

typedef enum {
  et_integer   = 0,
  et_float     = 1,
  et_string    = 2,
  et_data      = 3,
} envtype_t;

typedef struct {
  string_t	 name;
  envtype_t	 envtype;
  accesstype_t	 access;
  uint32	 min;
  uint32	 max;
  string_t	 unit;
  uint32	 initial;
  uint32	 index;
  string_list_t *node_list;
  val_map_t	*val_map;
  string_t	 comment;
 } envvar_t;

/* envvar list */
DECLARE_PLIST(envvar_list, envvar);

/* dbc */
typedef struct {
  string_t		       filename;
  string_t		       version;
  node_list_t		      *node_list;
  valtable_list_t	      *valtable_list;
  message_list_t	      *message_list;
  envvar_list_t 	      *envvar_list;
  attribute_rel_list_t	      *attribute_rel_list;
  attribute_definition_list_t *attribute_definition_list;
  signal_group_list_t	      *signal_group_list;
  network_t		      *network;
} dbc_t;

/* functions */
DECLARE_LIST_FREE(string_list, string);
DECLARE_PLIST_FREE(val_map, val_map_entry);
DECLARE_PLIST_FREE(valtable_list, valtable);

#ifdef __cplusplus
extern "C" {
#endif

void string_free(string_t string);
void valtable_free(valtable_t *valtable);
void attribute_value_free(attribute_value_t *attribute_value);
void message_free(message_t *message);
void dbc_free(dbc_t *dbc);
message_t *message_dup(message_t *orig);
char *string_merge(char *in, char *app);
dbc_t *dbc_read_file(char *filename);

#ifdef __cplusplus
}
#endif


#endif
