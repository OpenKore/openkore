// Sprite viewer widget
#include <gtk/gtk.h>
#include <vector>
#include "sprite.h"

using namespace std;


class SpriteViewer {
public:
	GtkWidget *widget;
	vector<GdkPixbuf *> frames;
	int currentFrame;

	SpriteViewer ();
	~SpriteViewer ();

	void set (Sprite *sprite);
private:
	guint animation_id;

	void clearFrames ();
};
