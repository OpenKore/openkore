#include <gtk/gtk.h>
#include <glib/gthread.h>
#include <glade/glade.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>

#include "grf.h"
#include "callbacks.h"
#include "utils.h"
#include "main.h"


GladeXML *xml;
Document document;

GtkWidget *savesel = NULL, *dirsel = NULL;
GtkTreeModel *filelist;
GtkTreePath *current_selection = NULL;
gboolean filling = FALSE;


ExtractProgress extractProgress, lastKnownProgress;
GStaticMutex extractProgressM;

MainWindow mainWin;


/***********************
 * Utility functions
 ***********************/

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


unsigned long
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
	for (i = (long) document.grf->nfiles - 1; i >= 0; i--) {
		char *filename = NULL;
		char *size = NULL;
		char *type;

		if (!document.grf->files[i].real_len)
			continue;

		/* Do not display folders */
		if (GRFFILE_IS_DIR(document.grf->files[i]))
			continue;

		/* Attempt to convert the filename to UTF-8 */
		if (!document.grf->files[i].name) {
			printf("%ld: %s\n", i, document.grf->files[i].name);
			continue;
		}
		filename = str_to_utf8 (document.grf->files[i].name, NULL);
		if (!filename)
			continue;

		if (pattern && !g_pattern_match_string (pattern, filename)) {
			g_free (filename);
			continue;
		}

		size = friendly_size_name (document.grf->files[i].real_len);
		type = get_type_name (filename);

		/* Add to list */
		gtk_list_store_prepend (GTK_LIST_STORE (filelist), &iter);
		gtk_list_store_set (GTK_LIST_STORE (filelist), &iter,
			INDEX_COL, i,
			DISPLAY_COL, filename,
			TYPE_COL, type,
			SIZE_COL, document.grf->files[i].real_len,
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


void
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

	mainWin.busy (true);
	mainWin.status (_("Loading..."));
	while (gtk_events_pending ()) gtk_main_iteration ();
	newgrf = grf_open (fname, "r", &err);
	if (!newgrf) {
		char *base;

		base = g_path_get_basename (fname);
		mainWin.status ("");
		gdk_window_set_cursor (W(main)->window, NULL);
		show_error (_("Error while opening %s:\n%s"),
			base, grf_strerror (err));
		g_free (base);
		return;
	}
	if (document.grf)
		grf_free (document.grf);
	document.grf = newgrf;

	document.filename = fname;

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
	title = g_strdup_printf (_("%s: %ld files"), tmp, (long int)document.grf->nfiles);
	mainWin.status (title);
	g_free (tmp);
	g_free (title);
	gtk_widget_set_sensitive (W(extract), TRUE);
	mainWin.busy (false);
}


static gboolean
idle_open (gpointer fname)
{
	open_grf_file ((const char *) fname);
	return FALSE;
}


static gpointer
extract_thread (gpointer user_data)
{
	GList *args = (GList *) user_data;
	const char *savedir = (const char *) g_list_nth_data (args, 0);
	GList *files = (GList *) g_list_nth_data (args, 1);
	GList *indices = (GList *) g_list_nth_data (args, 2);

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
		if (!grf_index_extract (document.grf, i, fname, NULL))
			failed++;
		g_free (fname);

		g_static_mutex_lock (&extractProgressM);
		extractProgress.current++;
		strncpy (extractProgress.file, document.grf->files[i].name, PATH_MAX - 1);
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
		mainWin.status (msg);
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


void
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
	mainWin.status (_("Extracting files..."));
	gtk_widget_set_sensitive (W(open), FALSE);
	gtk_widget_set_sensitive (W(extract), FALSE);
	gtk_widget_set_sensitive (W(stop), TRUE);
	gtk_widget_show (W(progressBox));
	watcher = gtk_timeout_add (100, watch_extract_thread, NULL);
	gtk_timeout_add (10, watch_extract_thread_stop, GINT_TO_POINTER (watcher));

	return;
}


int
main (int argc, char *argv[])
{
	g_thread_init (NULL);
	gtk_init (&argc, &argv);
	document.grf = (Grf *) 0;
	mainWin.init ();

	memset (&extractProgress, 0, sizeof (ExtractProgress));
	g_static_mutex_init (&extractProgressM);

	if (argv[1])
		gtk_idle_add (idle_open, argv[1]);
	gtk_widget_realize (W(main));
	gtk_widget_show (W(main));
	gtk_main ();
	return 0;
}
