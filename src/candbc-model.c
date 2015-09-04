/*  candbc-model.c --  management of the DBC data model
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

#include <stdio.h>
#include <string.h>
typedef struct yy_buffer_state *YY_BUFFER_STATE;

#include "candbc-model.h"

/****************
 * DESTRUCTORS *
 ****************/
void string_free(string_t string)
{
  if(string != NULL) free(string);
}

void attribute_value_free(attribute_value_t *attribute_value)
{
  if(attribute_value != NULL) {
    switch(attribute_value->value_type) {
    case vt_string:
      string_free(attribute_value->value.string_val);
      break;
    case vt_enum:
      string_free(attribute_value->value.enum_val);
      break;
    default:
      break;
    }
    free(attribute_value);
  }
}

static void attribute_free(attribute_t *attribute)
{
  if(attribute != NULL) {
    string_free(attribute->name);
    attribute_value_free(attribute->value);
    free(attribute);
  }
}

static void attribute_definition_free(
 attribute_definition_t *attribute_definition)
{
  if(attribute_definition != NULL) {
    string_free(attribute_definition->name);
    switch(attribute_definition->value_type) {
    case vt_enum:
      /* free range */
      string_list_free(attribute_definition->range.enum_list);

      /* free default */
      string_free(attribute_definition->default_value.enum_val);
      break;
    case vt_string:
      /* free default */
      string_free(attribute_definition->default_value.string_val);
      break;
    default:
      break;
    }
    free(attribute_definition);
  }
}

static DEFINE_PLIST_FREE(attribute_list, attribute);
DEFINE_LIST_FREE(string_list, string);

static void signal_free(signal_t *signal)
{
  static int counter = 0;
  if(signal != NULL) {
    string_free(signal->name);
    string_free(signal->unit);
    string_list_free(signal->receiver_list);
    string_free(signal->comment);
    attribute_list_free(signal->attribute_list);
    val_map_free(signal->val_map);
    free(signal);
  }
  counter++;
}
static DEFINE_PLIST_FREE(signal_list, signal);

void message_free(message_t *message)
{
  if(message != NULL) {
    string_free(message->name);
    string_free(message->sender);
    signal_list_free(message->signal_list);
    string_free(message->comment);
    attribute_list_free(message->attribute_list);
    string_list_free(message->transmitter_list);
    free(message);
  }
}

static void node_free(node_t *node)
{
  if(node != NULL) {
    string_free(node->name);
    string_free(node->comment);
    attribute_list_free(node->attribute_list);
    free(node);
  }
}

static DEFINE_PLIST_FREE(attribute_definition_list, attribute_definition);
static DEFINE_PLIST_FREE(message_list, message);
static DEFINE_PLIST_FREE(node_list, node);

static void attribute_rel_free(attribute_rel_t *attribute_rel)
{
  string_free(attribute_rel->name);
  attribute_value_free(attribute_rel->attribute_value);
}

static DEFINE_PLIST_FREE(attribute_rel_list, attribute_rel);

static void val_map_entry_free(val_map_entry_t *val_map_entry)
{
  if(val_map_entry != NULL) {
    string_free(val_map_entry->value);
    free(val_map_entry);
  }
}

DEFINE_PLIST_FREE(val_map, val_map_entry);

void valtable_free(valtable_t *valtable)
{
  if(valtable != NULL) {
    string_free(valtable->name);
    string_free(valtable->comment);
    val_map_free(valtable->val_map);
  }
}

DEFINE_PLIST_FREE(valtable_list, valtable);

static void envvar_free(envvar_t *envvar)
{
  if(envvar != NULL) {
    string_free(envvar->name);
    string_free(envvar->unit);
    string_list_free(envvar->node_list);
    val_map_free(envvar->val_map);
    string_free(envvar->comment);
    free(envvar);
  }
}

static DEFINE_PLIST_FREE(envvar_list, envvar);

static void signal_group_free(signal_group_t *signal_group)
{
  if(signal_group != NULL) {
    string_free(signal_group->name);
    string_list_free(signal_group->signal_name_list);
    free(signal_group);
  }
}

static DEFINE_PLIST_FREE(signal_group_list, signal_group);

static void network_free(network_t *network)
{
  if(network != NULL) {
    attribute_list_free(network->attribute_list);
    string_free(network->comment);
    free(network);
  }
}

void dbc_free(dbc_t *dbc)
{
  if(dbc != NULL) {
    string_free(dbc->filename);
    string_free(dbc->version);
    node_list_free(dbc->node_list);
    valtable_list_free(dbc->valtable_list);
    message_list_free(dbc->message_list);
    envvar_list_free(dbc->envvar_list);
    attribute_rel_list_free(dbc->attribute_rel_list);
    attribute_definition_list_free(dbc->attribute_definition_list);
    signal_group_list_free(dbc->signal_group_list);
    network_free(dbc->network);
    free(dbc);
  }
}

/*
 * merge input strings and frees their memory.
 */
char *string_merge(char *in, char *app)
{
  char *ret;

  if(app != NULL) {
    if(in != NULL) {
      char *dp = malloc(strlen(in) + strlen(app) + 1);
      char *sp;

      ret = dp;
      for(sp = in;  *sp  != '\0'; sp++,dp++) *dp = *sp;
      for(sp = app; *sp  != '\0'; sp++,dp++) *dp = *sp;
      *dp = '\0';
      free(in);
      free(app);
    } else {
      ret = app;
    }
  } else {
    if(in != NULL) {
      ret = in;
    } else {
      ret = NULL;
    }
  }

  return ret;
}
