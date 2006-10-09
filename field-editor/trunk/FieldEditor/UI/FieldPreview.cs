using System;
using System.IO;
using Gtk;
using Gdk;

namespace FieldEditor {

/**
 * A widget for previewing a field file.
 */
public class FieldPreview: Viewport {
	private const int DEFAULT_WIDTH = 200;
	private const int DEFAULT_HEIGHT = 200;

	private Label label;
	private Gtk.Image image;

	/**
	 * The field file to preview.
	 */
	public string Filename {
		set {
			if (value == null) {
				SetStatus("No file selected.");
			} else {
				try {
					Field field = FieldLoader.LoadFromFile(value);
					if (field == null) {
						SetStatus("Unknown field format.");
					} else {
						SetStatus(null);
						ShowField(field);
					}
				} catch (IOException e) {
					SetStatus("Cannot load file: " + e.Message);
				} catch (InvalidFieldFileException e) {
					SetStatus(e.Message);
				} catch (ApplicationException e) {
					SetStatus("Error: " + e.Message);
				}
			}
		}
	}

	public FieldPreview() {
		ShadowType = ShadowType.EtchedIn;
		SetSizeRequest(DEFAULT_WIDTH, DEFAULT_HEIGHT);
		SetStatus("No file selected.");
	}

	private void SetStatus(string status) {
		if (status == null && label != null) {
			Remove(label);
			label = null;
		} else if (status != null) {
			if (image != null) {
				Remove(image);
				image = null;
			}
			if (label == null) {
				label = new Label();
				label.SetAlignment(0.5f, 0.5f);
				label.Wrap = true;
				label.Show();
				Add(label);
			}
			label.Text = status;
		}
	}

	private void ShowField(Field field) {
		FieldRenderer renderer = new FieldRenderer(field, null);
		FieldRegion region = new FieldRegion();
		Pixbuf pixbuf;

		region.Left = region.Bottom = 0;
		region.Top = field.Height - 1;
		region.Right = field.Width - 1;
		pixbuf = renderer.RenderToPixbuf(region, null);

		if (pixbuf.Width > DEFAULT_WIDTH || pixbuf.Height > DEFAULT_HEIGHT) {
			int w, h;

			CalculateOptimalDimensions(pixbuf, out w, out h);
			pixbuf = pixbuf.ScaleSimple(w, h, InterpType.Tiles);
		}

		if (image == null) {
			image = new Gtk.Image(pixbuf);
			image.Show();
			Add(image);
		} else {
			image.Pixbuf = pixbuf;
		}
	}
	
	private void CalculateOptimalDimensions(Pixbuf pixbuf, out int w, out int h) {
		if (pixbuf.Width > DEFAULT_WIDTH) {
			w = DEFAULT_WIDTH;
			h = (int) (pixbuf.Height * (DEFAULT_WIDTH / (double) pixbuf.Width));
		} else {
			h = DEFAULT_HEIGHT;
			w = (int) (pixbuf.Width * (DEFAULT_HEIGHT / (double) pixbuf.Height));
		}
	}
}

} // namespace FieldPreview