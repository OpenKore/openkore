#include "sprite-viewer.h"

static gboolean
animate (SpriteViewer *viewer)
{
	gtk_image_set_from_pixbuf (GTK_IMAGE (viewer->widget),
		viewer->frames[viewer->currentFrame]);

	viewer->currentFrame++;
	if (viewer->currentFrame >= viewer->frames.size ())
		viewer->currentFrame = 0;
	return TRUE;
}

SpriteViewer::SpriteViewer ()
{
	widget = gtk_image_new ();
	gtk_widget_show (widget);
	animation_id = 0;
	currentFrame = 0;
}

SpriteViewer::~SpriteViewer ()
{
	if (animation_id) {
		gtk_timeout_remove (animation_id);
		clearFrames ();
	}
	gtk_widget_destroy (widget);
}

void
SpriteViewer::set (Sprite *sprite)
{
	if (sprite) {
		unsigned int i;
		void *pixels;
		GdkPixbuf *buf;

		clearFrames ();
		currentFrame = 0;
		for (i = 0; i < sprite->nimages; i++) {
			pixels = sprite_to_rgb (sprite, i, NULL, NULL);
			buf = gdk_pixbuf_new_from_data ((const guchar *) pixels,
				GDK_COLORSPACE_RGB, FALSE, 8,
				sprite->images[i].width, sprite->images[i].height,
				sprite->images[i].width * 3, NULL, NULL);
			frames.push_back (buf);
		}

		if (animation_id)
			gtk_timeout_remove (animation_id);
		animation_id = gtk_timeout_add (100, (GtkFunction) animate, this);

	} else if (animation_id) {
		gtk_timeout_remove (animation_id);
		clearFrames ();
		animation_id = 0;
	}
}

void
SpriteViewer::clearFrames ()
{
	unsigned int i;

	for (i = 0; i < frames.size (); i++)
		g_object_unref (G_OBJECT (frames[i]));
	frames.clear ();
}
