#ifndef _CALLBACKS_H_
#define _CALLBACKS_H_

#include <gtk/gtk.h>

extern "C" {

void filelist_selection_changed_cb (GtkTreeSelection *selection, GtkTreeView *tree);

}

#endif /* _CALLBACKS_H_ */
