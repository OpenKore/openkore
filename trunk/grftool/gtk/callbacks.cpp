#include <gtk/gtk.h>
#include <errno.h>
#include <string.h>

#include "main.h"
#include "callbacks.h"
#include "utils.h"

extern "C" {


void
open_cb ()
{
	String fname;
	if ((fname = mainWin.selectOpenFile ()) != "")
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

	if (!document.grf) return;

	if (!savesel) {
		gchar *tmp, *dir;

		/* We want the extract file selector to have
		   the same working directory as the open one */
		savesel = gtk_file_selection_new (_("Extract & save file"));
		dirsel = gtk_file_selection_new (_("Extract & save to folder"));
		gtk_widget_set_sensitive (GTK_FILE_SELECTION (dirsel)->file_list,
			FALSE);
		tmp = g_path_get_dirname (document.filename);
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
		if (grf_index_extract (document.grf, index, savename, &err)) {
			mainWin.statusf (_("%s saved"), basename);
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
			if (!mkdirs (savedir)) {
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
				files = g_list_prepend (files, document.grf->files[index].name);
				indices = g_list_prepend (indices, GINT_TO_POINTER (index));
			}
			list = g_list_reverse (list);

		} else if (gtk_tree_model_get_iter_first (filelist, &iter)) {
			/* Nothing is selected */
			do {
				gtk_tree_model_get (filelist, &iter,
					INDEX_COL, &index,
					-1);
				files = g_list_prepend (files, document.grf->files[index].name);
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
	unsigned long i;

	if (!document.grf) return;

	mainWin.status (_("Searching..."));
	mainWin.busy (true);
	while (gtk_events_pending ()) gtk_main_iteration ();
	i = fill_filelist ();

	mainWin.statusf (_("%ld files found"), i);
	mainWin.busy (false);
}


void
filelist_selection_changed_cb (GtkTreeSelection *selection, GtkTreeView *tree)
{
	GList *list, *l;
	char *tmp;
	GtkTreeIter iter;
	GtkTreePath *thisPath;
	unsigned long index;
	guint len;

	if (!document.grf || filling) return;

	list = gtk_tree_selection_get_selected_rows (selection, NULL);
	len = g_list_length (list);
	if (list && !list->next) { /* 1 file selected */
		char *fname, *display;

		thisPath = (GtkTreePath *) list->data;
		if (current_selection) {
			if (gtk_tree_path_compare (current_selection, thisPath) == 0)
				/* The user selected an already selected row; don't do anything */
				goto end;
			gtk_tree_path_free (current_selection);
		}

		current_selection = gtk_tree_path_copy (thisPath);
		gtk_tree_model_get_iter (filelist, &iter, thisPath);
		gtk_tree_model_get (filelist, &iter,
			INDEX_COL, &index,
			DISPLAY_COL, &display,
			-1);

		tmp = g_path_get_basename (document.filename);
		mainWin.statusf (_("%s: %ld files - file #%ld selected"),
			tmp, document.grf->nfiles, index + 1);
		g_free (tmp);

		mainWin.preview (display, document.grf->files[index].name);

		g_free (display);

	} else if (!list) { /* no files selected */
		tmp = g_path_get_basename (document.filename);
		mainWin.statusf (_("%s: %ld files"), tmp, document.grf->nfiles);
		g_free (tmp);

	} else { /* >1 files selected */
		char *sizestr;
		unsigned long size = 0;

		for (l = list; l; l = l->next) {
			thisPath = (GtkTreePath *) list->data;
			gtk_tree_model_get_iter (filelist, &iter, thisPath);
			gtk_tree_model_get (filelist, &iter,
				INDEX_COL, &index,
				-1);
			size += document.grf->files[index].real_len;
		}

		sizestr = friendly_size_name (size);
		tmp = g_path_get_basename (document.filename);
		mainWin.statusf (_("%s: %ld files - %d files selected (%s)"),
			tmp, document.grf->nfiles, len, sizestr);
		g_free (tmp);
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


} /* extern "C" */
