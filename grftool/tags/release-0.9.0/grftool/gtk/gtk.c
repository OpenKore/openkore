#include <gtk/gtk.h>
#include <glib/gthread.h>
#include <glade/glade.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include "grf.h"


GladeXML *xml;
Grf *grf = NULL;
GString *filename;

GtkWidget *opensel = NULL, *savesel = NULL, *dirsel = NULL;
GtkTreeModel *filelist;
GtkTreePath *current_selection = NULL;
gboolean filling = FALSE;
GdkCursor *busy_cursor = NULL;


typedef struct {
	GThread *thread;
	enum {
		STATUS_INIT,
		STATUS_MKDIR,
		STATUS_EXTRACT,
		STATUS_DONE
	} status;
	unsigned long max;
	unsigned long current;
	unsigned long failed;
	char file[PATH_MAX];

	gboolean stop;
} ExtractProgress;

ExtractProgress extractProgress, lastKnownProgress;
GStaticMutex extractProgressM;

enum {
	INDEX_COL,
	DISPLAY_COL,
	TYPE_COL,
	SIZE_COL,
	SIZE_DISPLAY_COL,
	N_COLS
};

#define W(x) glade_xml_get_widget (xml, #x)
#define _(x) x


/***********************
 * Utility functions
 ***********************/

static void
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


static GladeXML *
load_glade (gchar *basename)
{
	GladeXML *xml;
	char self[PATH_MAX + 1];
	GList *search_dirs = NULL, *dir;
	gchar *filename = NULL;

	/* Locate itself if we're on Linux */
	if (realpath ("/proc/self/exe", self)) {
		char *dir;

		dir = g_path_get_dirname (self);
		search_dirs = g_list_append (search_dirs, dir);
		search_dirs = g_list_append (search_dirs,
			g_strdup_printf ("%s/../share/grftool", dir));
	}
	search_dirs = g_list_append (search_dirs, g_strdup ("."));

	for (dir = search_dirs; dir; dir = dir->next) {
		gchar *fn;

		fn = g_strdup_printf ("%s/%s", (gchar *) dir->data, basename);
		if (g_file_test (fn, G_FILE_TEST_IS_REGULAR)) {
			filename = fn;
			break;
		}
		g_free (fn);
	}
	g_list_foreach (search_dirs, (GFunc) g_free, NULL);
	g_list_free (search_dirs);

	if (!filename) {
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


static void
set_status (const char *msg)
{
	static guint ctx = 0;
	GtkStatusbar *bar;

	bar = GTK_STATUSBAR (W(status));
	gtk_statusbar_pop (bar, ctx);
	ctx = gtk_statusbar_get_context_id (bar, msg);
	gtk_statusbar_push (bar, ctx, msg);
}


static void
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
		if (!g_file_test (str->str, G_FILE_TEST_IS_DIR))
			mkdir (str->str, S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
		i++;
	}

	g_string_free (str, TRUE);
	g_strfreev (paths);
}


static char *
get_type_name (char *filename)
{
	char *ext;

	ext = strrchr (filename, '.');
	if (!ext)
		return g_strdup (_("Unknown"));
	ext = g_utf8_strup (ext + 1, -1);

	if (strcmp (ext, "BMP") == 0) {
		g_free (ext);
		return g_strdup (_("Bitmap Image"));

	} else if (strcmp (ext, "JPG") == 0) {
		g_free (ext);
		return g_strdup (_("JPEG Image"));

	} else if (strcmp (ext, "GIF") == 0) {
		g_free (ext);
		return g_strdup (_("GIF Image"));

	} else if (strcmp (ext, "PNG") == 0) {
		g_free (ext);
		return g_strdup (_("PNG Image"));

	} else if (strcmp (ext, "TXT") == 0) {
		g_free (ext);
		return g_strdup (_("Text File"));

	} else if (strcmp (ext, "WAV") == 0) {
		g_free (ext);
		return g_strdup (_("Wave Sound"));

	} else if (strcmp (ext, "MP3") == 0) {
		g_free (ext);
		return g_strdup (_("MP3 Music"));

	} else if (strcmp (ext, "SPR") == 0) {
		g_free (ext);
		return g_strdup (_("Sprite Data"));

	} else if (strcmp (ext, "XML") == 0) {
		g_free (ext);
		return g_strdup (_("XML Document"));

	} else
		return ext;
}


/* Attempt to convert a string (possibly with Korean encoding) to UTF-8 */
static inline char *
str_to_utf8 (char *str, gsize *bytes_written)
{
	char *encodings[] = {
		"CSEUCKR", "CSISO2022KR", "EUC-KR", "EUCKR",
		"ISO-2022-KR", "ISO646-KR", "ISO2022KR",
		"ISO8859-1", "UTF-8"
	};
	int j;
	char *ret = NULL;

	if (!(ret = g_locale_to_utf8 (str, -1, NULL, bytes_written, NULL)))
	for (j = 0; j < sizeof (encodings) / sizeof (char *); j++) {
		ret = g_convert (str, -1,
			"UTF-8", encodings[j],
			NULL, bytes_written, NULL);
		if (ret)
			break;
	}
	return ret;
}


static char *
friendly_size_name (unsigned long size)
{
	if (size < 1024)
		return g_strdup_printf ("%ld bytes", size);
	else if (size >= 1024 && size < 1024 * 1024)
		return g_strdup_printf ("%.1f KB", size / 1024.0);
	else
		return g_strdup_printf ("%.1f MB", size / 1024.0 / 1024.0);
}


static unsigned long
fill_filelist ()
{
	long i;
	unsigned long num = 0;
	GtkTreeIter iter = {};
	gchar *search;
	GPatternSpec *pattern = NULL;

	filling = TRUE;

	gtk_list_store_clear (GTK_LIST_STORE (filelist));
	search = (gchar *) gtk_entry_get_text (GTK_ENTRY (W(searchentry)));
	if (search && *search) {
		if (!strchr (search, '*')) {
			search = g_strdup_printf ("*%s*", search);
			pattern = g_pattern_spec_new (search);
			g_free (search);
		} else
			pattern = g_pattern_spec_new (search);
	}

	/* Detach list model from view to make insertion faster */
	g_object_ref (filelist);
	gtk_tree_view_set_model (GTK_TREE_VIEW (W(filelist)), NULL);

	/* We add items to the list in reversed order because for some reason
	   the list reverses the order again. i is not an unsigned long because
	   it will conflict with 'i >= 0' and 'i--' */
	for (i = (long) grf->nfiles - 1; i >= 0; i--) {
		char *filename = NULL;
		char *size = NULL;
		char *type;

		if (!grf->files[i].real_len)
			continue;

		/* Do not display folders */
		if (grf->files[i].type == 2)
			continue;

		/* Attempt to convert the filename to UTF-8 */
		if (!grf->files[i].name) {
			printf("%ld: %s\n", i, grf->files[i].name);
			continue;
		}
		filename = str_to_utf8 (grf->files[i].name, NULL);
		if (!filename)
			continue;

		if (pattern && !g_pattern_match_string (pattern, filename)) {
			g_free (filename);
			continue;
		}

		size = friendly_size_name (grf->files[i].real_len);
		type = get_type_name (filename);

		/* Add to list */
		gtk_list_store_prepend (GTK_LIST_STORE (filelist), &iter);
		gtk_list_store_set (GTK_LIST_STORE (filelist), &iter,
			INDEX_COL, i,
			DISPLAY_COL, filename,
			TYPE_COL, type,
			SIZE_COL, grf->files[i].real_len,
			SIZE_DISPLAY_COL, size,
			-1);
		num++;

		g_free (size);
		g_free (filename);
		g_free (type);
	}

	/* Re-attach model */
	gtk_tree_view_set_model (GTK_TREE_VIEW (W(filelist)), filelist);
	g_object_unref (filelist);

	filling = FALSE;

	if (pattern)
		g_pattern_spec_free (pattern);
	return num;
}


static void
open_grf_file (const char *fname)
{
	char *title, *tmp;
	GrfError err;
	Grf *newgrf;
	GList *list, *cols;

	if (!g_file_test (fname, G_FILE_TEST_EXISTS)) {
		show_error (_("File %s does not exist."), fname);
		return;
	}

	gdk_window_set_cursor (W(main)->window, busy_cursor);
	set_status (_("Loading..."));
	while (gtk_events_pending ()) gtk_main_iteration ();
	newgrf = grf_open (fname, &err);
	if (!newgrf) {
		char *base;

		base = g_path_get_basename (fname);
		set_status ("");
		show_error (_("Error while opening %s:\n%s"),
			base, grf_strerror (err));
		g_free (base);
		return;
	}
	if (grf)
		grf_free (grf);
	grf = newgrf;

	g_string_printf (filename, "%s", fname);

	title = g_strdup_printf (_("%s - GRF Tool"), fname);
	gtk_window_set_title (GTK_WINDOW (W(main)), title);
	g_free (title);

	gtk_list_store_clear (GTK_LIST_STORE (filelist));

	cols = gtk_tree_view_get_columns (GTK_TREE_VIEW (W(filelist)));
	for (list = cols; list; list = list->next) {
		GtkTreeViewColumn *col = (GtkTreeViewColumn *) list->data;
		gtk_tree_view_column_set_sort_indicator (col, FALSE);
	}
	gtk_tree_sortable_set_sort_column_id (GTK_TREE_SORTABLE (filelist),
		GTK_TREE_SORTABLE_DEFAULT_SORT_COLUMN_ID, GTK_SORT_ASCENDING);
	g_list_free (cols);


	fill_filelist ();


	tmp = g_path_get_basename (fname);
	title = g_strdup_printf (_("%s: %ld files"), tmp, grf->nfiles);
	set_status (title);
	g_free (tmp);
	g_free (title);
	gtk_widget_set_sensitive (W(extract), TRUE);
	gdk_window_set_cursor (W(main)->window, NULL);
}


static gboolean
idle_open (gpointer fname)
{
	open_grf_file ((const char *) fname);
	return FALSE;
}


static void
preview_file (char *display, char *fname)
{
	GtkTextBuffer *buf;
	char *ext;

	if (!gtk_toggle_button_get_active (GTK_TOGGLE_BUTTON (W(preview_toggle))))
		return;

	ext = strrchr (display, '.');
	if (!ext) return;
	ext = g_utf8_strup (ext, -1);

	buf = gtk_text_view_get_buffer (GTK_TEXT_VIEW (W(text_preview)));
	gtk_text_buffer_set_text (buf, "", 0);
	gtk_image_set_from_file (GTK_IMAGE (W(image_preview)), NULL);

	if (strcmp (ext, ".TXT") == 0 || strcmp (ext, ".XML") == 0) {
		char *data, *text;
		unsigned long size;
		gsize strsize;
		GrfError err;

		(void *) data = grf_get (grf, fname, &size, &err);
		if (!data) {
			set_status (grf_strerror (err));
			goto end;
		}

		text = str_to_utf8 (data, &strsize);
		size = strsize;
		g_free (data);

		gtk_text_buffer_set_text (buf, text, size);
		gtk_notebook_set_current_page (GTK_NOTEBOOK (W(notebook1)), 0);
		g_free (text);

	} else if (strcmp (ext, ".BMP") == 0 || strcmp (ext, ".JPG") == 0
	  || strcmp (ext, ".PNG") == 0 || strcmp (ext, ".GIF") == 0) {
		char *data, *tmpfile = NULL;
		unsigned long size;
		GrfError err;

		GError *gerr = NULL;
		int fd;


		(void *) data = grf_get (grf, fname, &size, &err);
		if (!data) {
			set_status (grf_strerror (err));
			goto end;
		}

		if ((fd = g_file_open_tmp ("grftoolXXXXXX", &tmpfile, &gerr)) == -1) {
			show_error (_("Unable to create a temporary file: %s"),
				gerr->message);
			g_error_free (gerr);
			goto end;
		}

		write (fd, data, size);
		close (fd);

		gtk_image_set_from_file (GTK_IMAGE (W(image_preview)), tmpfile);
		remove (tmpfile);
		g_free (tmpfile);
		gtk_notebook_set_current_page (GTK_NOTEBOOK (W(notebook1)), 1);

	} else
		gtk_notebook_set_current_page (GTK_NOTEBOOK (W(notebook1)), 0);

	end:
	g_free (ext);
}


static gpointer
extract_thread (gpointer user_data)
{
	GList *args = user_data;
	const char *savedir = g_list_nth_data (args, 0);
	GList *files = g_list_nth_data (args, 1);
	GList *indices = g_list_nth_data (args, 2);

	GList *l, *f, *dirs = NULL;
	char *dir;
	unsigned long failed = 0, max = 0;
	gboolean stop = FALSE;
	GTimer *timer = NULL;

	g_list_free (args);


	/* Generate a list of unique subdirectories */
	for (l = files; l; l = l->next) {
		char *p;

		/* Convert paths to Unix paths */
		for (p = (char *) l->data; *p; p++) if (*p == '\\') *p = G_DIR_SEPARATOR;

		dir = g_path_get_dirname ((gchar *) l->data);
		if (!g_list_find_custom (dirs, dir, (GCompareFunc) g_ascii_strcasecmp)) {
			dirs = g_list_prepend (dirs, dir);
			max++;
		} else
			g_free (dir);
	}

	g_static_mutex_lock (&extractProgressM);
	extractProgress.max = max;
	extractProgress.status = STATUS_MKDIR;
	g_static_mutex_unlock (&extractProgressM);

	/* Create the subdirectories */
	dirs = g_list_sort (dirs, (GCompareFunc) g_ascii_strcasecmp);
	dirs = g_list_reverse (dirs);
	for (l = dirs; l; l = l->next) {
		dir = g_build_filename (G_DIR_SEPARATOR_S, savedir, (char *) l->data, NULL);
		mkdirs (dir);
		g_free (dir);

		g_static_mutex_lock (&extractProgressM);
		extractProgress.current++;
		stop = extractProgress.stop;
		g_static_mutex_unlock (&extractProgressM);
	}

	g_list_foreach (dirs, (GFunc) g_free, NULL);
	g_list_free (dirs);
	if (stop) goto end;


	g_static_mutex_lock (&extractProgressM);
	extractProgress.current = 0;
	extractProgress.max = g_list_length (files);
	extractProgress.status = STATUS_EXTRACT;
	stop = extractProgress.stop;
	g_static_mutex_unlock (&extractProgressM);

	if (stop) goto end;
	timer = g_timer_new ();
	g_timer_start (timer);

	/* Start the actual extraction */
	for (l = indices, f = files; l; l = l->next, f = f->next) {
		unsigned long i;
		char *fname;

		i = GPOINTER_TO_INT (l->data);
		fname = g_build_filename (savedir, (char *) f->data, NULL);
		if (!grf_index_extract (grf, i, fname, NULL))
			failed++;
		g_free (fname);

		g_static_mutex_lock (&extractProgressM);
		extractProgress.current++;
		strncpy (extractProgress.file, grf->files[i].name, PATH_MAX - 1);
		stop = extractProgress.stop;
		g_static_mutex_unlock (&extractProgressM);

		if (stop) goto end;
	}


	end:
	if (timer)
		g_timer_destroy (timer);
	g_list_free (files);
	g_list_free (indices);

	g_static_mutex_lock (&extractProgressM);
	extractProgress.failed = failed;
	extractProgress.status = STATUS_DONE;
	g_static_mutex_unlock (&extractProgressM);

	return NULL;
}


static gboolean
watch_extract_thread (gpointer user_data)
{
	ExtractProgress ep;

	g_static_mutex_lock (&extractProgressM);
	memcpy (&ep, &extractProgress, sizeof (ExtractProgress));
	g_static_mutex_unlock (&extractProgressM);

	if (ep.status != lastKnownProgress.status) {
		switch (ep.status) {
		case STATUS_INIT:
			break;
		case STATUS_MKDIR:
			gtk_progress_bar_set_text (GTK_PROGRESS_BAR (W(progress)),
				_("Creating folders..."));
			break;
		case STATUS_EXTRACT:
			gtk_progress_bar_set_text (GTK_PROGRESS_BAR (W(progress)),
				_("0%"));
			break;
		case STATUS_DONE:
			break;
		default:
			break;
		};
	}

	if (ep.current != lastKnownProgress.current || ep.max != lastKnownProgress.max) {
		if (ep.max == 0)
			gtk_progress_bar_set_fraction (GTK_PROGRESS_BAR (W(progress)), 0.0);
		else
			gtk_progress_bar_set_fraction (GTK_PROGRESS_BAR (W(progress)),
				(gdouble) ep.current / (gdouble) ep.max);

		if (ep.status == STATUS_EXTRACT && ep.file) {
			char *tmp, *basename;

			basename = g_path_get_basename (ep.file);
			tmp = str_to_utf8 (basename, NULL);
			g_free (basename);
			basename = g_strdup_printf ("%.1f%%: %s",
				((gdouble) ep.current / (gdouble) ep.max) * 100, tmp);
			g_free (tmp);

			gtk_progress_bar_set_text (GTK_PROGRESS_BAR (W(progress)),
				basename);
			g_free (basename);
		}
	}

	memcpy (&lastKnownProgress, &ep, sizeof (ExtractProgress));
	return TRUE;
}


static gboolean
watch_extract_thread_stop (gpointer user_data)
{
	guint watcher;
	gboolean result = TRUE;

	g_static_mutex_lock (&extractProgressM);
	if (extractProgress.status == STATUS_DONE) {
		char *msg;

		watcher = GPOINTER_TO_INT (user_data);
		gtk_timeout_remove (watcher);
		result = FALSE;

		if (extractProgress.failed == 0)
			msg = g_strdup_printf (_("%ld files extracted."), extractProgress.current);
		else
			msg = g_strdup_printf (_("%ld files extracted (%ld failed)."),
				extractProgress.current, extractProgress.failed);
		set_status (msg);
		g_free (msg);

		gtk_widget_hide (W(progressBox));
		gtk_widget_set_sensitive (W(open), TRUE);
		gtk_widget_set_sensitive (W(extract), TRUE);
	}
	g_static_mutex_unlock (&extractProgressM);
	if (!result) {
		g_thread_join (extractProgress.thread);
		memset (&lastKnownProgress, 0, sizeof (ExtractProgress));
	}
	return result;
}


static void
extract_files (const char *savedir, GList *files, GList *indices)
{
	GError *err = NULL;
	GList *args;
	guint watcher;

	/* Run extraction as background thread */
	args = g_list_append (NULL, (gpointer) savedir);
	args = g_list_append (args, files);
	args = g_list_append (args, indices);
	memset (&extractProgress, 0, sizeof (ExtractProgress));
	memset (&lastKnownProgress, 0, sizeof (ExtractProgress));
	extractProgress.thread = g_thread_create (extract_thread,
		args, TRUE, &err);
	if (!extractProgress.thread) {
		show_error (_("A system error occured while extracting (unable to create thread).\n%s"),
			err->message);
		g_error_free (err);
		g_list_free (args);
		memset (&extractProgress, 0, sizeof (ExtractProgress));
		return;
	}

	/* Update GUI in main thread */
	set_status (_("Extracting files..."));
	gtk_widget_set_sensitive (W(open), FALSE);
	gtk_widget_set_sensitive (W(extract), FALSE);
	gtk_widget_set_sensitive (W(stop), TRUE);
	gtk_widget_show (W(progressBox));
	watcher = gtk_timeout_add (100, watch_extract_thread, NULL);
	gtk_timeout_add (10, watch_extract_thread_stop, GINT_TO_POINTER (watcher));

	return;
}


static void
sort_by_anything (GtkTreeViewColumn *column, gint sort_column, GtkSortType default_sort)
{
	GtkTreeView *view = GTK_TREE_VIEW (W(filelist));
	GtkTreeModel *model = gtk_tree_view_get_model (view);
	GList *list, *cols = gtk_tree_view_get_columns (view);
	gint sort_id;
	GtkSortType sort_type;

	for (list = cols; list; list = list->next) {
		GtkTreeViewColumn *col = (GtkTreeViewColumn *) list->data;
		gtk_tree_view_column_set_sort_indicator (col, FALSE);
	}
	g_list_free (cols);

	gtk_tree_view_column_set_sort_indicator (column, TRUE);
	gtk_tree_sortable_get_sort_column_id (GTK_TREE_SORTABLE (model), &sort_id, &sort_type);
	if (sort_id == sort_column) {
		sort_type = (sort_type == GTK_SORT_ASCENDING) ? GTK_SORT_DESCENDING : GTK_SORT_ASCENDING;
		gtk_tree_sortable_set_sort_column_id (GTK_TREE_SORTABLE (model), sort_column, sort_type);
		gtk_tree_view_column_set_sort_order (column, sort_type);

	} else {
		gtk_tree_sortable_set_sort_column_id (GTK_TREE_SORTABLE (model), sort_column, default_sort);
		gtk_tree_view_column_set_sort_order (column, default_sort);
	}
}


static void
sort_by_column (GtkTreeViewColumn *col, gpointer column)
{
	sort_by_anything (col, GPOINTER_TO_INT (column), GTK_SORT_ASCENDING);
}


/***********************
 * Callbacks
 ***********************/

void
open_cb ()
{
	const char *fname = NULL;

	gtk_file_selection_show_fileop_buttons (GTK_FILE_SELECTION (opensel));
	if (gtk_dialog_run (GTK_DIALOG (opensel)) == GTK_RESPONSE_OK)
		fname = gtk_file_selection_get_filename (GTK_FILE_SELECTION (opensel));
	gtk_widget_hide (opensel);

	if (fname)
		open_grf_file (fname);
}


void
extract_cb ()
{
	GtkTreeSelection *selection;
	GList *list, *l;
	GtkTreePath *path;
	GtkTreeIter iter;
	char *fname, *display;
	unsigned long size, index;
	void *data;

	if (!grf) return;

	if (!savesel) {
		gchar *tmp, *dir;

		/* We want the extract file selector to have
		   the same working directory as the open one */
		savesel = gtk_file_selection_new (_("Extract & save file"));
		dirsel = gtk_file_selection_new (_("Extract & save to folder"));
		gtk_widget_set_sensitive (GTK_FILE_SELECTION (dirsel)->file_list,
			FALSE);
		tmp = g_path_get_dirname (filename->str);
		dir = g_strdup_printf ("%s%c", tmp, G_DIR_SEPARATOR);

		gtk_file_selection_complete (GTK_FILE_SELECTION (savesel), dir);
		gtk_file_selection_complete (GTK_FILE_SELECTION (dirsel), dir);

		g_free (dir);
		g_free (tmp);
	}

	selection = gtk_tree_view_get_selection (GTK_TREE_VIEW (W(filelist)));
	list = gtk_tree_selection_get_selected_rows (selection, NULL);

	if (list && !list->next) {
		/* 1 file selected */
		GtkTreePath *path;
		const gchar *savename = NULL;
		gchar *basename;
		GrfError err;

		/* Get file information */
		path = (GtkTreePath *) list->data;
		gtk_tree_model_get_iter (filelist, &iter, path);
		gtk_tree_model_get (filelist, &iter,
			INDEX_COL, &index,
			DISPLAY_COL, &display,
			-1);

		/* Setup save dialog */
		basename = strrchr (display, '\\');
		if (basename)
			gtk_file_selection_set_filename (GTK_FILE_SELECTION (savesel),
				basename + 1);
		if (gtk_dialog_run (GTK_DIALOG (savesel)) == GTK_RESPONSE_OK)
			savename = gtk_file_selection_get_filename (GTK_FILE_SELECTION (savesel));
		gtk_widget_hide (savesel);
		if (!savename) {
			g_free (display);
			goto end;
		}

		/* Extract */
		if (grf_index_extract (grf, index, savename, &err)) {
			char *msg;

			msg = g_strdup_printf (_("%s saved"), basename + 1);
			set_status (msg);
			g_free (msg);
		} else {
			show_error (_("Unable to extract %s:\n%s"),
				basename + 1,
				grf_strerror (err));
		}
		g_free (display);

	} else {
		/* More than 1 file selected, or nothing selected */
		const gchar *savedir = NULL;
		GList *files = NULL, *indices = NULL;

		if (gtk_dialog_run (GTK_DIALOG (dirsel)) == GTK_RESPONSE_OK)
			savedir = gtk_file_selection_get_filename (GTK_FILE_SELECTION (dirsel));
		gtk_widget_hide (dirsel);
		if (!savedir)
			goto end;

		if (!g_file_test (savedir, G_FILE_TEST_IS_DIR)) {
			if (mkdir (savedir, S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH) != 0) {
				show_error (_("Unable to create a new folder: %s"),
					g_strerror (errno));
				goto end;
			}
		}

		if (list) {
			/* More than 1 file is selected */
			for (l = list; l; l = l->next) {
				path = (GtkTreePath *) l->data;
				gtk_tree_model_get_iter (filelist, &iter, path);
				gtk_tree_model_get (filelist, &iter,
					INDEX_COL, &index,
					-1);
				files = g_list_prepend (files, grf->files[index].name);
				indices = g_list_prepend (indices, GINT_TO_POINTER (index));
			}
			list = g_list_reverse (list);

		} else if (gtk_tree_model_get_iter_first (filelist, &iter)) {
			/* Nothing is selected */
			do {
				gtk_tree_model_get (filelist, &iter,
					INDEX_COL, &index,
					-1);
				files = g_list_prepend (files, grf->files[index].name);
				indices = g_list_prepend (indices, GINT_TO_POINTER (index));
			} while (gtk_tree_model_iter_next (filelist, &iter));
			list = g_list_reverse (list);
		}

		extract_files (savedir, files, indices);
	}

	end:
	g_list_foreach (list, (GFunc) gtk_tree_path_free, NULL);
	g_list_free (list);
}


void
preview_toggled_cb ()
{
	gboolean active;

	active = gtk_toggle_button_get_active (GTK_TOGGLE_BUTTON (W(preview_toggle)));
	if (active)
		gtk_widget_show (W(preview_pane));
	else
		gtk_widget_hide (W(preview_pane));
}


void
filelist_activated_cb (GtkTreeView *tree, GtkTreePath *path)
{
	extract_cb ();
}


void
fill_filelist_cb ()
{
	gchar *msg;
	unsigned long i;

	if (!grf) return;

	set_status (_("Searching..."));
	while (gtk_events_pending ()) gtk_main_iteration ();
	i = fill_filelist ();

	msg = g_strdup_printf (_("%ld files found"), i);
	set_status (msg);
	g_free (msg);
}


static void
filelist_selection_changed_cb (GtkTreeSelection *selection, GtkTreeView *tree)
{
	GList *list, *l;
	char *title, *tmp;
	GtkTreeIter iter;
	GtkTreePath *this;
	unsigned long index;
	guint len;

	if (!grf || filling) return;

	list = gtk_tree_selection_get_selected_rows (selection, NULL);
	len = g_list_length (list);
	if (list && !list->next) { /* 1 file selected */
		char *fname, *display;

		this = (GtkTreePath *) list->data;
		if (current_selection) {
			if (gtk_tree_path_compare (current_selection, this) == 0)
				/* The user selected an already selected row; don't do anything */
				goto end;
			gtk_tree_path_free (current_selection);
		}

		current_selection = gtk_tree_path_copy (this);
		gtk_tree_model_get_iter (filelist, &iter, this);
		gtk_tree_model_get (filelist, &iter,
			INDEX_COL, &index,
			DISPLAY_COL, &display,
			-1);

		tmp = g_path_get_basename (filename->str);
		title = g_strdup_printf (_("%s: %ld files - file #%ld selected"),
			tmp, grf->nfiles, index + 1);
		set_status (title);
		g_free (tmp);
		g_free (title);

		preview_file (display, grf->files[index].name);

		g_free (display);

	} else if (!list) { /* no files selected */
		tmp = g_path_get_basename (filename->str);
		title = g_strdup_printf (_("%s: %ld files"), tmp, grf->nfiles);
		set_status (title);
		g_free (tmp);
		g_free (title);

	} else { /* >1 files selected */
		char *sizestr;
		unsigned long size = 0;

		for (l = list; l; l = l->next) {
			this = (GtkTreePath *) list->data;
			gtk_tree_model_get_iter (filelist, &iter, this);
			gtk_tree_model_get (filelist, &iter,
				INDEX_COL, &index,
				-1);
			size += grf->files[index].real_len;
		}

		sizestr = friendly_size_name (size);
		tmp = g_path_get_basename (filename->str);
		title = g_strdup_printf (_("%s: %ld files - %d files selected (%s)"),
			tmp, grf->nfiles, len, sizestr);
		set_status (title);
		g_free (tmp);
		g_free (title);
		g_free (sizestr);
	}

	end:
	g_list_foreach (list, (GFunc) gtk_tree_path_free, NULL);
	g_list_free (list);
}


void
stop_cb ()
{
	g_static_mutex_lock (&extractProgressM);
	if (extractProgress.thread)
		extractProgress.stop = TRUE;
	g_static_mutex_unlock (&extractProgressM);
	gtk_widget_set_sensitive (W(stop), FALSE);
}


int
main (int argc, char *argv[])
{
	GtkTreeView *tree;
	GtkTreeViewColumn *column;
	GtkTreeSelection *selection;
	GtkTooltips *tips;

	g_thread_init (NULL);
	gtk_init (&argc, &argv);
	memset (&extractProgress, 0, sizeof (ExtractProgress));
	g_static_mutex_init (&extractProgressM);
	xml = load_glade ("grftool.glade");

	opensel = gtk_file_selection_new (_("Open GRF archive"));
	filename = g_string_new ("");


	/* Manually set tooltips (libglade bug??) */
	tips = gtk_tooltips_new ();
	gtk_tooltips_set_tip (tips, W(open),
		_("Open GRF file"), NULL);
	gtk_tooltips_set_tip (tips, W(extract),
		_("Extract all files or selected files"), NULL);
	gtk_tooltips_set_tip (tips, W(preview_toggle),
		_("Enable/disable preview of files"), NULL);


	/* Setup the file list model and widget */
	filelist = GTK_TREE_MODEL (gtk_list_store_new (N_COLS,
		G_TYPE_ULONG,	/* index */
		G_TYPE_STRING,	/* display name (filename converted to UTF-8) */
		G_TYPE_STRING,	/* type */
		G_TYPE_ULONG,	/* decompressed file size */
		G_TYPE_STRING	/* file size string */
	));
	tree = GTK_TREE_VIEW (W(filelist));
	g_object_set (tree,
		"model", filelist,
		"rules-hint", TRUE,
		NULL);
	selection = gtk_tree_view_get_selection (tree);
	gtk_tree_selection_set_mode (selection, GTK_SELECTION_MULTIPLE);
	g_signal_connect (G_OBJECT (selection), "changed",
		G_CALLBACK (filelist_selection_changed_cb), tree);
	gtk_tree_sortable_set_default_sort_func (GTK_TREE_SORTABLE (filelist),
		(GtkTreeIterCompareFunc) gtk_false, NULL, NULL);


	column = gtk_tree_view_column_new_with_attributes (
		_("Filename"),
		gtk_cell_renderer_text_new (),
		"text", DISPLAY_COL,
		NULL);
	g_object_set (column,
		"reorderable", TRUE,
		"resizable", TRUE,
		"clickable", TRUE,
		NULL);
	gtk_tree_view_append_column (tree, column);
	g_signal_connect (G_OBJECT (column), "clicked",
		G_CALLBACK (sort_by_column), GINT_TO_POINTER (DISPLAY_COL));

	column = gtk_tree_view_column_new_with_attributes (
		_("Type"),
		gtk_cell_renderer_text_new (),
		"text", TYPE_COL,
		NULL);
	g_object_set (column,
		"reorderable", TRUE,
		"resizable", TRUE,
		"clickable", TRUE,
		NULL);
	gtk_tree_view_append_column (tree, column);
	g_signal_connect (G_OBJECT (column), "clicked",
		G_CALLBACK (sort_by_column), GINT_TO_POINTER (TYPE_COL));

	column = gtk_tree_view_column_new_with_attributes (
		_("Size"),
		gtk_cell_renderer_text_new (),
		"text", SIZE_DISPLAY_COL,
		NULL);
	g_object_set (column,
		"reorderable", TRUE,
		"resizable", TRUE,
		"clickable", TRUE,
		NULL);
	gtk_tree_view_append_column (tree, column);
	g_signal_connect (G_OBJECT (column), "clicked",
		G_CALLBACK (sort_by_column), GINT_TO_POINTER (SIZE_COL));

	gtk_tree_view_set_headers_visible (tree, TRUE);


	gtk_widget_modify_bg (W(viewport1), GTK_STATE_NORMAL,
		&(gtk_widget_get_style (W(viewport1))->white));


	/* Show the GUI */
	set_status (_("Click Open to open a GRF archive."));
	busy_cursor = gdk_cursor_new (GDK_WATCH);
	if (argv[1])
		gtk_idle_add (idle_open, argv[1]);
	gtk_widget_realize (W(main));
	gtk_widget_show (W(main));
	gtk_main ();
	return 0;
}
