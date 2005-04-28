#ifndef _UTILS_H_
#define _UTILS_H_

#include <glib.h>
#include <glade/glade.h>
#include <string>

using namespace std;

/* String is like string, but it casts itself to const char * so
   you don't have to type .c_str() every time. */
class String : public string {
public:
	String () : string () {}
	String (const char *s) : string (s) {}
	operator const char * () {
		return c_str ();
	}
	String &operator=(string s) {
		assign (s);
		return *this;
	}
	String &operator=(const char *s) {
		assign (s);
		return *this;
	}
	String &operator+(const char *s) {
		append (s);
		return *this;
	}
};


char *friendly_size_name (unsigned long size);
GladeXML *load_glade (gchar *basename);
gboolean mkdirs (const char *dir);
void show_error (gchar *format, ...);
char *str_to_utf8 (char *str, gsize *bytes_written = NULL);


#endif /* _UTILS_H_ */
