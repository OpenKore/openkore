#ifndef _UTILS_H_
#define _UTILS_H_

#include <glib.h>
#include <glade/glade.h>


char *friendly_size_name (unsigned long size);
GladeXML *load_glade (gchar *basename);
gboolean mkdirs (const char *dir);
void show_error (gchar *format, ...);
char *str_to_utf8 (char *str, gsize *bytes_written = NULL);


#endif /* _UTILS_H_ */
