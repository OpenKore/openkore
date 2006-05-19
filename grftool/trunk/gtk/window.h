#ifndef _WINDOW_H_
#define _WINDOW_H_

#include <gtk/gtk.h>
#include <glibmm/ustring.h>
#include "utils.h"
#include "sprite-viewer.h"

using namespace Glib;

class MainWindow {
public:
	void init ();

	void busy (bool b);
	void preview (char *displayName, char *fname);
	ustring selectOpenFile ();
	void status (String msg);
	void statusf (const char *format, ...);
private:
	GdkCursor *busyCursor;
	SpriteViewer *spriteViewer;
};

#endif /* _WINDOW_H_ */
