#ifndef INCLUDE_DBCREADER_H
#define INCLUDE_DBCREADER_H

#include <candbc-model.h>

#ifdef __cplusplus
extern "C" {
#endif

dbc_t *dbc_read_file(char *filename);

#ifdef __cplusplus
}
#endif

#endif
