#ifndef _WINDOW_H_
#define _WINDOW_H_

#include <gtk/gtk.h>
#include <string>
#include "utils.h"

using namespace std;

class MainWindow {
public:
	void init ();

	void busy (bool b);
	void preview (char *displayName, char *fname);
	string selectOpenFile ();
	void status (String msg);
	void statusf (const char *format, ...);
private:
	GdkCursor *busyCursor;
	GtkWidget *opensel;
};

#endif /* _WINDOW_H_ */
