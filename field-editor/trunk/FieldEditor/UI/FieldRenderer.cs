using System;
using System.Collections;
using Gdk;

namespace FieldEditor {

/* Historical note: we used to use Gdk.DrawPoints() and Gdk.DrawRectangle()
 * to render the field, but performance was abysmal on Windows,
 * and Gtk-Sharp for Windows has a different parameter definition
 * for DrawPoints() than the Linux version! The GdkPixbuf renderer
 * is the most cross-platform with decent performance.
 */

/**
 * This class is responsible for rendering a Field.
 */
public class FieldRenderer {
	/** The number of channels in the GdkPixbuf used to render the field. */
	protected const uint CHANNELS = 3;

	private FieldColors colors;
	private Field field;
	private uint zoomLevel = 1;

	public FieldColors Colors {
		get { return colors; }
		set { colors = value; }
	}

	/**
	 * The field to render.
	 *
	 * @invariant Field != null
	 */
	public Field Field {
		get { return field; }
		set { field = value; }
	}

	/**
	 * The current zoomlevel at which the field will be rendered.
	 *
	 * @invariant zoomLevel >= 1
	 */
	public uint ZoomLevel {
		get { return zoomLevel; }
		set { zoomLevel = value; }
	}

	/**
	 * Create a new FieldRenderer for rendering the specified field.
	 *
	 * @param field   The field to render.
	 * @param colors  The colors to use when rendering this field. If this is null,
	 *                then the default colors will be used.
	 * @require field != null
	 * @ensure
	 *     this.Field == field
	 *     if colors != null: this.Colors == colors
	 *     this.ZoomLevel == 1
	 */
	public FieldRenderer(Field field, FieldColors colors) {
		this.field = field;
		if (colors != null) {
			this.colors = colors;
		} else {
			this.colors = new FieldColors();
		}
	}

	/**
	 * Render a part of a field to a drawable.
	 *
	 * @param drawable  The drawable to render to.
	 * @param gc        The GC to use when rendering. This GC is not
	 *                  actually used for anything visible, so any GC will do.
	 * @param region    The region of the field to render.
	 * @param selection  The region of the field that is selected, or null.
	 *                   This region will be rendered with a different color.
	 * @require  Both region and selection must be within the current field's bounds.
	 */
	public void RenderToDrawable(Drawable drawable, Gdk.GC gc, FieldRegion region, FieldRegion selection) {
		using (Pixbuf pixbuf = RenderToPixbuf(region, selection)) {
			Point screenLeftTop;

			screenLeftTop.X = (int) region.Left;
			screenLeftTop.Y = (int) region.Top;
			Calc.FieldPosToScreenPos(ref screenLeftTop, field, zoomLevel);

			pixbuf.RenderToDrawable(drawable, gc,
				0, 0, screenLeftTop.X, screenLeftTop.Y,
				(int) (region.Width * zoomLevel),
				(int) (region.Height * zoomLevel),
				RgbDither.Normal, 0, 0);
		}
	}

	/**
	 * Render a part of a field to a Gdk.Pixbuf.
	 *
	 * @param region     The region of the field to render.
	 * @param selection  The region of the field that is selected, or null.
	 *                   This region will be rendered with a different color.
	 * @require  Both region and selection must be within the current field's bounds.
	 */
	public Pixbuf RenderToPixbuf(FieldRegion region, FieldRegion selection) {
		Point screenLeftTop;
		uint width, height;
		byte[] pixels;

		/*
		 * Create a pixel buffer which will hold the region we're
		 * going to render.
		 */
		screenLeftTop.X = (int) region.Left;
		screenLeftTop.Y = (int) region.Top;
		Calc.FieldPosToScreenPos(ref screenLeftTop, field, zoomLevel);
		width = region.Width * zoomLevel;
		height = region.Height * zoomLevel;
		pixels = new byte[width * height * CHANNELS];

		/*
		 * Go through each block in the region and render it
		 * to the pixel buffer.
		 */
		for (uint y = region.Bottom; y <= region.Top; y++) {
			for (uint x = region.Left; x <= region.Right; x++) {
				Point p;
				Color color;

				p.X = (int) x;
				p.Y = (int) y;
				Calc.FieldPosToScreenPos(ref p, field, zoomLevel);

				if (selection != null && WithinSelection(selection, x, y)) {
					color = colors.GetSelectionColor(field.GetBlock(x, y));
				} else {
					color = colors.GetColor(field.GetBlock(x, y));
				}

				DrawFilledRect(pixels,
					(uint) (p.X - screenLeftTop.X),
					(uint) (p.Y - screenLeftTop.Y),
					zoomLevel, zoomLevel, width,
					(byte) (color.Red / 256),
					(byte) (color.Green / 256),
					(byte) (color.Blue / 256));
			}
		}

		/*
		 * Render the selection border.
		 */
		if (selection != null) {
			Point p1, p2;
			Color color;

			p1.X = (int) selection.Left;
			p1.Y = (int) selection.Top;
			p2.X = (int) selection.Right;
			p2.Y = (int) selection.Bottom;
			Calc.FieldPosToScreenPos(ref p1, field, zoomLevel);
			Calc.FieldPosToScreenPos(ref p2, field, zoomLevel);
			p1.X -= screenLeftTop.X;
			p1.Y -= screenLeftTop.Y;
			p2.X -= screenLeftTop.X;
			p2.Y -= screenLeftTop.Y;

			color = colors.SelectionBorderColor;

			DrawOpenRect(pixels,
				(uint) p1.X,
				(uint) p1.Y,
				(uint) (p2.X - p1.X + zoomLevel - 1),
				(uint) (p2.Y - p1.Y + zoomLevel - 1),
				width,
				(byte) (color.Red / 256),
				(byte) (color.Green / 256),
				(byte) (color.Blue / 256));
		}

		return new Pixbuf(pixels, Colorspace.Rgb, CHANNELS == 4, 8,
					(int) width, (int) height,
					(int) (width * CHANNELS), null);
	}

	private bool WithinSelection(FieldRegion selection, uint x, uint y) {
		return x >= selection.Left && x <= selection.Right
			&& y >= selection.Bottom && y <= selection.Top;
	}

	/**
	 * Draw a filled rectangle on a pixel buffer.
	 *
	 * @param pixels    A buffer with raw pixel data.
	 * @param x, y      The coordinates to render the rectangle on.
	 * @param width     The width of the rectangle to render.
	 * @param height    The height of the rectangle to render.
	 * @param imgwidth  The width of the image represented by the pixel buffer.
	 * @param red, green, blue  An RGB value to use as color for the rectangle. 
	 */
	private void DrawFilledRect(byte[] pixels, uint x, uint y, uint width, uint height,
				uint imgwidth, byte red, byte green, byte blue) {
		for (uint j = y; j < y + height; j++) {
			for (uint i = x; i < x + width; i++) {
				uint offset = (j * imgwidth + i) * CHANNELS;
				pixels[offset] = red;
				pixels[offset + 1] = green;
				pixels[offset + 2] = blue;
				//pixels[offset + 3] = 0xFF;
			}
		}
	}
	
	private void DrawHLine(byte[] pixels, uint x, uint y, uint length,
			uint imgwidth, byte red, byte green, byte blue) {
		for (uint i = x; i < x + length; i++) {
			uint offset = (y * imgwidth + i) * CHANNELS;
			pixels[offset] = red;
			pixels[offset + 1] = green;
			pixels[offset + 2] = blue;
			//pixels[offset + 3] = 0xFF;
		}
	}

	private void DrawVLine(byte[] pixels, uint x, uint y, uint length,
			uint imgwidth, byte red, byte green, byte blue) {
		for (uint j = y; j < y + length; j++) {
			uint offset = (j * imgwidth + x) * CHANNELS;
			pixels[offset] = red;
			pixels[offset + 1] = green;
			pixels[offset + 2] = blue;
			//pixels[offset + 3] = 0xFF;
		}
	}

	/**
	 * Draw an open rectangle on a pixel buffer.
	 *
	 * @param pixels    A buffer with raw pixel data.
	 * @param x, y      The coordinates to render the rectangle on.
	 * @param width     The width of the rectangle to render.
	 * @param height    The height of the rectangle to render.
	 * @param imgwidth  The width of the image represented by the pixel buffer.
	 * @param red, green, blue  An RGB value to use as color for the rectangle. 
	 */
	private void DrawOpenRect(byte[] pixels, uint x, uint y, uint width, uint height,
				uint imgwidth, byte red, byte green, byte blue) {
		DrawHLine(pixels, x, y, width + 1, imgwidth, red, green, blue);
		DrawHLine(pixels, x, y + height, width + 1, imgwidth, red, green, blue);
		if (height > 1) {
			DrawVLine(pixels, x, y + 1, height - 1,
				imgwidth, red, green, blue);
			DrawVLine(pixels, x + width, y + 1, height - 1,
				imgwidth, red, green, blue);
		}
	}
}

} // namespace FieldRenderer