#include <gtk/gtk.h>
#include <stdarg.h>
#include "sprite.h"

#include "window.h"
#include "main.h"
#include "utils.h"
#include "callbacks.h"

static void sort_by_column (GtkTreeViewColumn *col, gpointer column);


void
MainWindow::busy (bool b)
{
	if (b) {
		gdk_window_set_cursor (W(main)->window, busyCursor);
	} else {
		gdk_window_set_cursor (W(main)->window, NULL);
	}
}

void
MainWindow::init ()
{
	GtkTreeView *tree;
	GtkTreeViewColumn *column;
	GtkTreeSelection *selection;
	GtkTooltips *tips;
	GdkPixbuf *pixbuf;
	#include "grftool-gtk.csource"


	busyCursor = gdk_cursor_new (GDK_WATCH);
	xml = load_glade ("grftool.glade");


	/* Manually set tooltips (libglade bug??) */
	tips = gtk_tooltips_new ();
	gtk_tooltips_set_tip (tips, W(open),
		_("Open GRF archive"), NULL);
	gtk_tooltips_set_tip (tips, W(extract),
		_("Extract all files or selected files"), NULL);
	gtk_tooltips_set_tip (tips, W(preview_toggle),
		_("Enable/disable preview of files"), NULL);
	gtk_tooltips_set_tip (tips, W(about),
		_("Show about box"), NULL);


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


	spriteViewer = new SpriteViewer ();
	gtk_notebook_append_page (GTK_NOTEBOOK (W(notebook1)),
		spriteViewer->widget, NULL);

	/* Show the GUI */
	status (_("Click Open to open a GRF archive."));
	pixbuf = gdk_pixbuf_new_from_inline (sizeof (grftool_icon),
		grftool_icon, FALSE, NULL);
	gtk_window_set_icon (GTK_WINDOW (W(main)), pixbuf);
	gtk_widget_grab_focus (W(searchentry));
}

/* displayName: UTF-8 encoded filename
   fname: filename in original encoding */
void
MainWindow::preview (char *displayName, char *fname)
{
	GtkTextBuffer *buf;
	char *tmp;
	string ext;

	if (!gtk_toggle_button_get_active (GTK_TOGGLE_BUTTON (W(preview_toggle))))
		return;

	tmp = strrchr (displayName, '.');
	if (!tmp) return;
	ext = g_utf8_strup (tmp, -1);

	buf = gtk_text_view_get_buffer (GTK_TEXT_VIEW (W(text_preview)));
	gtk_text_buffer_set_text (buf, "", 0);
	gtk_image_set_from_file (GTK_IMAGE (W(image_preview)), NULL);


	if (ext == ".TXT" || ext == ".XML") {
		uint32_t size;
		GrfError err;

		char *data = (char *) grf_get (document.grf, fname, &size, &err);
		if (!data) {
			status (grf_strerror (err));
			return;
		}

		String text = str_to_utf8 (data);
		gtk_text_buffer_set_text (buf, text, text.size ());
		gtk_notebook_set_current_page (GTK_NOTEBOOK (W(notebook1)), 0);

	} else if (ext == ".BMP" || ext == ".JPG" || ext == ".PNG" || ext == ".GIF") {
		uint32_t size;
		GrfError err;

		void *data = grf_get (document.grf, fname, &size, &err);
		if (!data) {
			status (grf_strerror (err));
			return;
		}

		int fd;
		char *tmpfile;
		GError *gerr = NULL;
		if ((fd = g_file_open_tmp ("grftoolXXXXXX", &tmpfile, &gerr)) == -1) {
			show_error (_("Unable to create a temporary file: %s"),
				gerr->message);
			g_error_free (gerr);
			return;
		}
		write (fd, data, size);
		close (fd);

		gtk_image_set_from_file (GTK_IMAGE (W(image_preview)), tmpfile);
		remove (tmpfile);
		g_free (tmpfile);
		gtk_notebook_set_current_page (GTK_NOTEBOOK (W(notebook1)), 1);

	} else if (ext == ".SPR") {
		uint32_t size;
		GrfError err;
		Sprite *sprite;
		void *data;

		data = grf_get (document.grf, fname, &size, &err);
		if (!data) {
			status (grf_strerror (err));
			return;
		}

		sprite = sprite_open_from_data ((const unsigned char *) data,
				(unsigned int) size, NULL);
		spriteViewer->set (sprite);
/*		if (sprite) {
			GdkPixbuf *buf;

			pixels = sprite_to_rgb (sprite, 0, NULL, NULL);
			buf = gdk_pixbuf_new_from_data ((const guchar *) pixels,
				GDK_COLORSPACE_RGB, FALSE, 8,
				sprite->images[0].width, sprite->images[0].height,
				sprite->images[0].width * 3, NULL, NULL);
			sprite_free (sprite);
			gtk_image_set_from_pixbuf (GTK_IMAGE (W(image_preview)), buf);
			g_object_unref (G_OBJECT (buf));
		} */
		sprite_free (sprite);
		gtk_notebook_set_current_page (GTK_NOTEBOOK (W(notebook1)), 2);

	} else {
		spriteViewer->set (NULL);
		gtk_notebook_set_current_page (GTK_NOTEBOOK (W(notebook1)), 0);
	}
}

string
MainWindow::selectOpenFile ()
{
	const char *fname = NULL;

	if (!opensel)
		opensel = gtk_file_selection_new (_("Open GRF archive"));

	gtk_file_selection_show_fileop_buttons (GTK_FILE_SELECTION (opensel));
	if (gtk_dialog_run (GTK_DIALOG (opensel)) == GTK_RESPONSE_OK)
		fname = gtk_file_selection_get_filename (GTK_FILE_SELECTION (opensel));
	gtk_widget_hide (opensel);

	if (fname)
		return fname;
	else
		return "";
}

void
MainWindow::status (String msg)
{
	static guint ctx = 0;
	GtkStatusbar *bar;

	bar = GTK_STATUSBAR (W(status));
	gtk_statusbar_pop (bar, ctx);
	ctx = gtk_statusbar_get_context_id (bar, msg);
	gtk_statusbar_push (bar, ctx, msg);
}

void
MainWindow::statusf (const char *format, ...)
{
	va_list ap;
	gchar *msg;

	va_start (ap, format);
	msg = g_strdup_vprintf (format, ap);
	va_end (ap);

	status (msg);
	g_free (msg);
}


/*********************************/


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
