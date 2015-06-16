#include <stdlib.h>

#include <glib/gprintf.h>
#include <json-glib/json-glib.h>

#include <candbc-model.h>
#include <candbc-reader.h>

int extract_message_signals(JsonBuilder *builder, signal_list_t* signal_list)
{
    json_builder_set_member_name(builder, "signals");
    json_builder_begin_object(builder);

    while (signal_list != NULL) {
        signal_t *signal = signal_list->signal;

        /* Keys are the signal names */
        json_builder_set_member_name(builder, signal->name);

        json_builder_begin_object(builder);
        json_builder_set_member_name(builder, "bitstart");
        json_builder_add_int_value(builder, signal->bit_start);

        json_builder_set_member_name(builder, "length");
        json_builder_add_int_value(builder, signal->bit_len);

        json_builder_set_member_name(builder, "scale");
        json_builder_add_double_value(builder, signal->scale);

        json_builder_set_member_name(builder, "min");
        json_builder_add_double_value(builder, signal->min);

        json_builder_set_member_name(builder, "max");
        json_builder_add_double_value(builder, signal->max);

        if (signal->unit) {
            json_builder_set_member_name(builder, "unit");
            json_builder_add_string_value(builder, signal->unit);
        }

        json_builder_end_object(builder);

        signal_list = signal_list->next;
    }
    json_builder_end_object(builder);

    return 0;
}

char* convert_attribute_value_to_string(attribute_value_t *attribute_value)
{
    char *s_value;

    value_type_t value_type = attribute_value->value_type;
    value_union_t value = attribute_value->value;

    switch(value_type) {
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
    }

    return s_value;
}

int extract_message_attributes(JsonBuilder *builder, attribute_list_t* attribute_list)
{
    json_builder_set_member_name(builder, "attributes");
    json_builder_begin_object(builder);

    /* Extract only one attribute GenMsgSendType */
    while (attribute_list != NULL) {
        attribute_t *attribute = attribute_list->attribute;

        if (g_strcmp0(attribute->name, "GenMsgSendType") == 0) {
            char *s_value = convert_attribute_value_to_string(attribute->value);
            json_builder_set_member_name(builder, attribute->name);
            /* FIXME Normalize with constant */
            json_builder_add_string_value(builder, s_value);
            g_free(s_value);
        }
        attribute_list = attribute_list->next;
    }
    json_builder_end_object(builder);

    return 0;
}

int extract_messages(JsonBuilder *builder, message_list_t *message_list)
{
    message_list_t *current = message_list;

    /* Extract message list */
    json_builder_set_member_name(builder, "messages");
    json_builder_begin_object(builder);

    while (message_list != NULL) {
        message_t *message = message_list->message;

        /* Keys are the message IDs */
        char *s_id = g_strdup_printf("%lu", message->id);
        json_builder_set_member_name(builder, s_id);
        //g_warning(s_id);
        g_free(s_id);

        json_builder_begin_object(builder);
        json_builder_set_member_name(builder, "name");
        json_builder_add_string_value(builder, message->name);

        json_builder_set_member_name(builder, "length");
        json_builder_add_int_value(builder, message->len);

        extract_message_attributes(builder, message->attribute_list);
        extract_message_signals(builder, message->signal_list);

        json_builder_end_object(builder);
        message_list = message_list->next;
    }

    json_builder_end_object(builder);

    return 0;
}


int write_dbc_to_file(dbc_t *dbc, const char *filename)
{
    JsonBuilder *builder = json_builder_new();
    GError *error = NULL;

    json_builder_begin_object(builder);

    /* Filename and version */
    json_builder_set_member_name(builder, "filename");
    json_builder_add_string_value(builder, dbc->filename);

    json_builder_set_member_name(builder, "version");
    json_builder_add_string_value(builder, dbc->version);

    extract_messages(builder, dbc->message_list);

    json_builder_end_object(builder);

    /* Write the JSON */
    JsonNode *root = json_builder_get_root(builder);
    JsonGenerator *generator = json_generator_new();
    json_generator_set_root(generator, root);

    json_generator_set_indent(generator, 4);
    json_generator_set_pretty(generator, TRUE);
    g_printf("Write JSON to %s\n", filename);
    json_generator_to_file(generator, filename, &error);
    if (error != NULL) {
        g_printf("Unable to write file: %s\n", error->message);
    }

    json_node_free(root);
    g_object_unref(generator);
    g_object_unref(builder);

    return 0;
}

int main(int argc, char** argv) {
    dbc_t *dbc;

    if (argc < 3) {
       g_print("Usage: %s <source.dbc> <dest.json>\n", argv[0]);
       return EXIT_FAILURE;
    }

    dbc = dbc_read_file(argv[1]);
    write_dbc_to_file(dbc, argv[2]);

    return 0;
}
