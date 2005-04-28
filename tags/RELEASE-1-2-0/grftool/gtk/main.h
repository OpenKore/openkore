#ifndef _MAIN_H_
#define _MAIN_H_

#include <gtk/gtk.h>
#include <glade/glade.h>
#include "grf.h"
#include "window.h"
#include "utils.h"


/* The currently opened GRF file */
extern MainWindow mainWin;
extern GladeXML *xml;

/* State information */
extern gboolean filling;


/* File selectors */
extern GtkWidget *savesel;
extern GtkWidget *dirsel;

/* Other widgets */
extern GtkTreeModel *filelist;
extern GtkTreePath *current_selection;


typedef enum {
	STATUS_INIT,
	STATUS_MKDIR,
	STATUS_EXTRACT,
	STATUS_DONE
} ExtractStatus;

typedef struct {
	GThread *thread;
	ExtractStatus status;
	unsigned long max;
	unsigned long current;
	unsigned long failed;
	char file[PATH_MAX];

	gboolean stop;
} ExtractProgress;

extern ExtractProgress extractProgress;
extern GStaticMutex extractProgressM;

typedef struct {
	Grf *grf;
	String filename;
} Document;

extern Document document;


/* Macros and types */
#define W(x) glade_xml_get_widget (xml, #x)
#define _(x) x

enum {
	INDEX_COL,
	DISPLAY_COL,
	TYPE_COL,
	SIZE_COL,
	SIZE_DISPLAY_COL,
	N_COLS
};


void open_grf_file (const char *fname);
void extract_files (const char *savedir, GList *files, GList *indices);
unsigned long fill_filelist ();


#endif /* _MAIN_H_ */
