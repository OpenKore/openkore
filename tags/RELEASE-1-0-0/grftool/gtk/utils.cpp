#include <gtk/gtk.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <limits.h>
#include <stdlib.h>

#include <string>
#include <vector>

#include "utils.h"
#include "main.h"

using namespace std;


/* Turns a number into a human-friendly size (1024 -> "1 KB") */
char *
friendly_size_name (unsigned long size)
{
	if (size < 1024)
		return g_strdup_printf ("%ld bytes", size);
	else if (size >= 1024 && size < 1024 * 1024)
		return g_strdup_printf ("%.1f KB", size / 1024.0);
	else
		return g_strdup_printf ("%.1f MB", size / 1024.0 / 1024.0);
}


GladeXML *
load_glade (gchar *basename)
{
	GladeXML *xml = NULL;
	char self[PATH_MAX + 1];
	int i;
	vector<String> searchDirs;
	String filename;

	/* Locate itself if we're on Linux */
	if (realpath ("/proc/self/exe", self)) {
		String dir = g_path_get_dirname (self);
		searchDirs.push_back (dir);
		searchDirs.push_back (dir + "/../share/grftool");
	}

	searchDirs.push_back (".");

	for (i = 0; i < searchDirs.size(); i++) {

		String fn = searchDirs[i] + "/" + basename;
		if (g_file_test (fn, G_FILE_TEST_IS_REGULAR)) {
			filename = fn;
		}
	}

	if (filename == "") {
		show_error (_("Unable to initialize the user interface. You may have to re-install this software."));
		exit (5);
	}

	xml = glade_xml_new (filename, NULL, NULL);
	if (!xml) {
		show_error (_("Unable to initialize the user interface. You may have to re-install this software."));
		exit (5);
	}
	glade_xml_signal_autoconnect (xml);
	return xml;
}


gboolean
mkdirs (const char *dir)
{
	gchar **paths;
	GString *str;
	gint i = 0;

	paths = g_strsplit (dir, G_DIR_SEPARATOR_S, -1);
	str = g_string_new ("");
	while (paths[i]) {
		if (!*paths[i]) {
			i++;
			continue;
		}

		if (i > 0)
			g_string_append_c (str, G_DIR_SEPARATOR);
		g_string_append (str, paths[i]);
		if (!g_file_test (str->str, G_FILE_TEST_IS_DIR)) {
			if (mkdir (str->str, S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH) != 0)
			{
				g_string_free (str, TRUE);
				g_strfreev (paths);
				return FALSE;
			}
		}
		i++;
	}

	g_string_free (str, TRUE);
	g_strfreev (paths);
	return TRUE;
}


/* Show an error dialog */
void
show_error (gchar *format, ...)
{
	GtkWidget *dialog;
	va_list ap;
	gchar *msg;

	va_start (ap, format);
	msg = g_strdup_vprintf (format, ap);
	va_end (ap);

	dialog = gtk_message_dialog_new (GTK_WINDOW (W(main)),
		GTK_DIALOG_MODAL,
		GTK_MESSAGE_ERROR,
		GTK_BUTTONS_OK,
		msg);
	gtk_window_set_resizable (GTK_WINDOW (dialog), FALSE);
	gtk_dialog_run (GTK_DIALOG (dialog));
	gtk_widget_destroy (dialog);
	g_free (msg);
}


/* Attempt to convert a string (possibly with Korean encoding) to UTF-8 */
char *
str_to_utf8 (char *str, gsize *bytes_written)
{
	char *encodings[] = {
		"CSEUCKR", "CSISO2022KR", "EUC-KR", "EUCKR",
		"ISO-2022-KR", "ISO646-KR", "ISO2022KR",
		"ISO8859-1", "UTF-8"
	};
	int j;
	char *ret = NULL;
	gsize written = 0;

	if (!(ret = g_locale_to_utf8 (str, -1, NULL, &written, NULL)))
	for (j = 0; j < sizeof (encodings) / sizeof (char *); j++) {
		ret = g_convert (str, -1,
			"UTF-8", encodings[j],
			NULL, &written, NULL);
		if (ret)
			break;
	}
	if (bytes_written)
		*bytes_written = written;
	return ret;
}
