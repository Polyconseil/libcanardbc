#include <stdlib.h>
#include <string.h>

#include <glib.h>
#include <json-glib/json-glib.h>

#include <candbc-model.h>
#include <candbc-reader.h>

typedef struct {
    int messages;
    int normal_messages;
    int multiplexed_messages;
    int multiplexed_message_combinations;
    int signals;
    int signals_bit_length;
} stats_t;

static void extract_message_signals(JsonBuilder *builder, signal_list_t* signal_list,
    GHashTable *multiplexing_table, stats_t *stats)
{
    if (signal_list == NULL)
        return;

    json_builder_set_member_name(builder, "signals");
    json_builder_begin_object(builder);

    while (signal_list != NULL) {
        signal_t *signal = signal_list->signal;

        /* Keys are the signal names */
        json_builder_set_member_name(builder, signal->name);

        json_builder_begin_object(builder);
        json_builder_set_member_name(builder, "bit_start");
        json_builder_add_int_value(builder, signal->bit_start);

        json_builder_set_member_name(builder, "length");
        json_builder_add_int_value(builder, signal->bit_len);
        stats->signals_bit_length += signal->bit_len;

        json_builder_set_member_name(builder, "little_endian");
        json_builder_add_int_value(builder, signal->endianness);

        json_builder_set_member_name(builder, "factor");
        json_builder_add_double_value(builder, signal->scale);

        json_builder_set_member_name(builder, "offset");
        json_builder_add_double_value(builder, signal->offset);

        json_builder_set_member_name(builder, "min");
        json_builder_add_double_value(builder, signal->min);

        json_builder_set_member_name(builder, "max");
        json_builder_add_double_value(builder, signal->max);

        if (signal->unit) {
            json_builder_set_member_name(builder, "unit");
            json_builder_add_string_value(builder, signal->unit);
        }

        if (signal->val_map != NULL) {
            val_map_t *val_map = signal->val_map;

            json_builder_set_member_name(builder, "enums");
            json_builder_begin_object(builder);
            while (val_map != NULL) {
                val_map_entry_t *val_map_entry = val_map->val_map_entry;
                gchar *key = g_strdup_printf("%lu", val_map_entry->index);
                json_builder_set_member_name(builder, key);
                json_builder_add_string_value(builder, val_map_entry->value);
                g_free(key);

                val_map = val_map->next;
            }
            json_builder_end_object(builder);
        }

        switch (signal->mux_type) {
        case m_multiplexor:
            json_builder_set_member_name(builder, "multiplexor");
            json_builder_add_boolean_value(builder, TRUE);
            break;
        case m_multiplexed:
            json_builder_set_member_name(builder, "multiplexing");
            json_builder_add_int_value(builder, signal->mux_value);
            g_hash_table_add(multiplexing_table, &(signal->mux_value));
            break;
        default:
            /* m_signal */
            break;
        }
        json_builder_end_object(builder);

        stats->signals++;
        signal_list = signal_list->next;
    }
    json_builder_end_object(builder);
}

static char* convert_attribute_value_to_string(attribute_value_t *attribute_value)
{
    char *s_value;

    value_type_t value_type = attribute_value->value_type;
    value_union_t value = attribute_value->value;

    switch (value_type) {
      case vt_integer:
        s_value = g_strdup_printf("%ld", value.int_val);
        break;
      case vt_float:
        s_value = g_strdup_printf("%lg", value.double_val);
        break;
      case vt_string:
        s_value = g_strdup_printf("%s", value.string_val);
        break;
      case vt_enum:
        s_value = g_strdup_printf("%s", value.enum_val);
        break;
      case vt_hex:
        s_value = g_strdup_printf("%lu", value.hex_val);
        break;
      default:
        s_value = NULL;
    }

    return s_value;
}

static int extract_attribute_definitions(JsonBuilder *builder, attribute_definition_list_t* attribute_definition_list)
{
    if (attribute_definition_list == NULL)
        return 0;

    json_builder_set_member_name(builder, "attribute_definitions");
    json_builder_begin_object(builder);

    while (attribute_definition_list != NULL) {
        attribute_definition_t *attribute_definition = attribute_definition_list->attribute_definition;

        /* Extract ONLY enums of message objects */
        if (attribute_definition->object_type == ot_message &&
            attribute_definition->value_type == vt_enum) {
            /* Union */
            string_list_t *string_list = attribute_definition->range.enum_list;
            int i;

            json_builder_set_member_name(builder, attribute_definition->name);
            json_builder_begin_object(builder);

            i = 0;
            while (string_list != NULL) {
                char *s_value = g_strdup_printf("%d", i);
                json_builder_set_member_name(builder, s_value);
                g_free(s_value);
                json_builder_add_string_value(builder, string_list->string);

                i++;
                string_list = string_list->next;
            }

            json_builder_end_object(builder);
        }
        attribute_definition_list = attribute_definition_list->next;
    }
    json_builder_end_object(builder);

    return 0;
}

static int extract_message_attributes(JsonBuilder *builder, attribute_list_t* attribute_list)
{
    if (attribute_list == NULL)
        return 0;

    json_builder_set_member_name(builder, "attributes");
    json_builder_begin_object(builder);

    while (attribute_list != NULL) {
        attribute_t *attribute = attribute_list->attribute;
        char *s_value = convert_attribute_value_to_string(attribute->value);
        json_builder_set_member_name(builder, attribute->name);
        json_builder_add_string_value(builder, s_value);
        g_free(s_value);

        attribute_list = attribute_list->next;
    }
    json_builder_end_object(builder);

    return 0;
}

static void extract_messages(JsonBuilder *builder, message_list_t *message_list, stats_t *stats)
{
    /* Extract message list */
    json_builder_set_member_name(builder, "messages");
    json_builder_begin_object(builder);

    while (message_list != NULL) {
        int multiplexing_count;
        message_t *message = message_list->message;
        GHashTable *multiplexing_table = g_hash_table_new(g_int_hash, g_int_equal);

        /* Keys are the message IDs */
        char *s_id = g_strdup_printf("%lu", message->id);
        json_builder_set_member_name(builder, s_id);
        g_free(s_id);

        json_builder_begin_object(builder);
        json_builder_set_member_name(builder, "name");
        json_builder_add_string_value(builder, message->name);

        json_builder_set_member_name(builder, "sender");
        json_builder_add_string_value(builder, message->sender);

        json_builder_set_member_name(builder, "length");
        json_builder_add_int_value(builder, message->len);

        extract_message_attributes(builder, message->attribute_list);
        extract_message_signals(builder, message->signal_list,
            multiplexing_table, stats);

        multiplexing_count = g_hash_table_size(multiplexing_table);
        if (multiplexing_count) {
            json_builder_set_member_name(builder, "has_multiplexor");
            json_builder_add_boolean_value(builder, TRUE);

            /* Each mode provides a distinct message */
            stats->multiplexed_messages++;
            stats->multiplexed_message_combinations += multiplexing_count;
        } else {
            stats->normal_messages++;
        }
        json_builder_end_object(builder);
        g_hash_table_destroy(multiplexing_table);

        stats->messages++;
        message_list = message_list->next;
    }

    json_builder_end_object(builder);
}


static void write_dbc_to_file(dbc_t *dbc, const char *filename, stats_t *stats)
{
    JsonBuilder *builder = json_builder_new();
    GError *error = NULL;

    json_builder_begin_object(builder);

    /* Filename and version */
    json_builder_set_member_name(builder, "filename");
    json_builder_add_string_value(builder, dbc->filename);

    json_builder_set_member_name(builder, "version");
    json_builder_add_string_value(builder, dbc->version);

    /* Extract attribute definitions of messages ONLY */
    extract_attribute_definitions(builder, dbc->attribute_definition_list);
    extract_messages(builder, dbc->message_list, stats);

    json_builder_end_object(builder);

    /* Write the JSON */
    JsonNode *root = json_builder_get_root(builder);
    JsonGenerator *generator = json_generator_new();
    json_generator_set_root(generator, root);

    json_generator_set_indent(generator, 4);
    json_generator_set_pretty(generator, TRUE);
    json_generator_to_file(generator, filename, &error);
    if (error != NULL) {
        g_printerr("Unable to generate file: %s\n", error->message);
    }

    json_node_free(root);
    g_object_unref(generator);
    g_object_unref(builder);
}

static void display_stats(stats_t *stats) {
    g_print("Number of messages: %d (%d normal and %d multiplexed)\n",
        stats->messages, stats->normal_messages, stats->multiplexed_messages);
    g_print("Number of combinations of multiplexed messages: %d\n", stats->multiplexed_message_combinations);
    g_print("Number of signals: %d\n", stats->signals);
    g_print("Total length of signal bits: %d\n", stats->signals_bit_length);
}

int main(int argc, char** argv) {
    dbc_t *dbc;
    stats_t stats = {0};

    g_print("If your input file is not an UTF-8 file, you can do:\n");
    g_print("  iconv -f ISO-8859-1 -t UTF-8 < foo.dbc > foo.dbc.utf8\n\n");

    if (argc < 3) {
       g_print("Usage: %s <source.dbc> <dest.json>\n", argv[0]);
       return EXIT_FAILURE;
    }

    g_print("Read input file %s\n", argv[1]);
    dbc = dbc_read_file(argv[1]);
    g_print("Write JSON output to %s\n", argv[2]);
    write_dbc_to_file(dbc, argv[2], &stats);
    g_print("Done.\n\n");

    display_stats(&stats);
    return 0;
}
