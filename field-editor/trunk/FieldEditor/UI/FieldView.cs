using System;
using System.Collections.Generic;
using Gtk;
using Gdk;


namespace FieldEditor {

/**
 * Various functions for calculating coordinates.
 */
class Calc {
	public static FieldSelection ScreenSelectionToFieldSelection(
		Field field, uint zoomLevel, int x, int y, int width, int height
	) {
		FieldSelection s = new FieldSelection();
		s.Left   = (uint) Math.Max(0,            x / zoomLevel);
		s.Right  = (uint) Math.Min(field.Width,  (x + width) / zoomLevel);
		s.Top    = (uint) Math.Max(0,            field.Height - (y / zoomLevel) - 1);
		s.Bottom = (uint) Math.Min(field.Height, field.Height - ((y + height) / zoomLevel) - 1);
		return s;
	}

	/**
	 * Convert a position on screen to a position on the field.
	 *
	 * @param  p  [in, out] A reference to a FieldPoint which contains the
	 *            position on screen. The X and Y members will be changed
	 *            to the position on the field. This position is clamped
	 *            so that it is always within the field's dimensions.
	 * @return True if the calculated position hadn't to be clamped to fit
	 *         in the field's dimensions, false otherwise.
	 * @require field != null
	 */
	public static bool ScreenPosToFieldPos(ref FieldPoint p, Field field, uint zoomLevel) {
		bool result = true;

		if (p.X / zoomLevel >= field.Width) {
			p.X = field.Width - 1;
			result = false;
		} else {
			p.X /= zoomLevel;
		}

		if (p.Y / zoomLevel >= field.Height) {
			p.Y = 0;
			result = false;
		} else {
			p.Y = field.Height - (p.Y / zoomLevel) - 1;
		}

		return result;
	}

	/**
	 * Convert a point on the field to a point on screen.
	 *
	 * @require field != null
	 */
	public static void FieldPosToScreenPos(ref FieldPoint p, Field field, uint zoomLevel) {
		p.X *= zoomLevel;
		p.Y = (field.Height - p.Y - 1) * zoomLevel;
	}

	public static void FieldPosToScreenPos(ref Point p, Field field, uint zoomLevel) {
		FieldPoint fp;
		fp.X = (uint) Math.Max(0, p.X);
		fp.Y = (uint) Math.Max(0, p.Y);
		FieldPosToScreenPos(ref fp, field, zoomLevel);
		p.X = (int) fp.X;
		p.Y = (int) fp.Y;
	}
}

/**
 * This event is triggered when the user moves the mouse over
 * this widget.
 *
 * @param source  The FieldView which generated the event.
 * @param x, y    The coordinate of field block that the mouse is currently on.
 *                x and y are both -1 if the mouse is not within the area
 *                that displays the field, but is still within the FieldView widget.
 * @invariant
 *     source != null
 *     x >= -1
 *     y >= -1
 */
public delegate void MouseMoveEvent(FieldView source, int x, int y);

/**
 * This event is triggered when the user (de)selected a part of the field.
 *
 * @param source     The FieldView which generated the event.
 * @param selection  The selected region, or null if nothing is selected.
 * @invariant        source != null
 */
public delegate void SelectionChangedEvent(FieldView source, FieldSelection selection);

/**
 * A widget for displaying a Field model.
 */
public class FieldView: DrawingArea {
	/** The currently used field model. May be null. */
	private Field field;

	/**
	 * The zoom level.
	 *
	 * @invariant zoomLevel >= 1
	 */
	private uint zoomLevel = 1;

	/**
	 * Contains color information for rendering the field.
	 *
	 * @invariant
	 *   if widget is realized: colors != null
	 */
	private FieldColors colors;

	/**
	 * An off-screen pixmap which contains the rendered field.
	 */
	private Pixmap pixmap;

	/**
	 * The current selection. May be null.
	 *
	 * @invariant
	 *     if selection != null: field != null
	 */
	private FieldSelection selection;
	/**
	 * Whether a mouse button is pressed down (thus, whether we're
	 * in the process of creating a selection).
	 *
	 * @invariant
	 *     if creatingSelection: selection != null
	 */
	private bool creatingSelection = false;

	public event MouseMoveEvent OnMouseMove;
	public event SelectionChangedEvent OnSelectionChanged;


	public uint ZoomLevel {
		get { return zoomLevel; }
		set {
			if (zoomLevel < 1) {
				throw new Exception("ZoomLevel may not be less than 1.");
			} else if (zoomLevel != value) {
				zoomLevel = value;
				pixmap = null;
				if (field != null) {
					SetSizeRequest((int) (field.Width * zoomLevel),
						(int) (field.Height * zoomLevel));
				}
				QueueDraw();
			}
		}
	}
	
	public FieldSelection Selection {
		get { return selection; }
	}

	/**
	 * Construct a new FieldView widget.
	 */
	public FieldView() {
		Realized += OnRealized;
		ExposeEvent += OnExposed;
		MotionNotifyEvent += OnMotionNotify;
		ButtonPressEvent += OnButtonPress;
		ButtonReleaseEvent += OnButtonRelease;
		Events |= EventMask.PointerMotionMask | EventMask.ButtonPressMask | EventMask.ButtonReleaseMask;
	}

	/**
	 * The currently used field model. The value may be null.
	 */
	public Field Field {
		get { return field; }
		set {
			if (field != value) {
				if (field != null) {
					field.OnBlockChanged -= OnFieldBlockChanged;
					field.OnDimensionChanged -= OnFieldDimensionChanged;
				}

				field = value;
				pixmap = null;
				selection = null;
				creatingSelection = false;
				if (field != null) {
					field.OnBlockChanged += OnFieldBlockChanged;
					field.OnDimensionChanged += OnFieldDimensionChanged;
					SetSizeRequest((int) (field.Width * zoomLevel),
						(int) (field.Height * zoomLevel));
				} else {
					SetSizeRequest(0, 0);
				}
				QueueDraw();
			}
		}
	}

	private void OnRealized(object o, EventArgs args) {
		colors = new FieldColors(GdkWindow);
	}

	private void OnExposed(object o, ExposeEventArgs args) {
		Rectangle area = args.Event.Region.Clipbox;

		GdkWindow.DrawRectangle(Style.BackgroundGC(StateType.Normal), true,
			area.X, area.Y, area.Width, area.Height);
		if (field != null) {
			if (pixmap == null) {
				FieldSelection region;

				pixmap = new Pixmap(GdkWindow,
					(int) (field.Width * zoomLevel),
					(int) (field.Height * zoomLevel),
					-1);
				region = new FieldSelection();
				region.Left = region.Bottom = 0;
				region.Right = field.Width - 1;
				region.Top = field.Height - 1;
				RenderToDrawable(field, region, null, zoomLevel, pixmap);
			}

			GdkWindow.DrawDrawable(Style.BlackGC, pixmap,
				area.X, area.Y, area.X, area.Y,
				area.Width, area.Height);

			if (selection != null) {
				RenderToDrawable(field, selection, selection, zoomLevel, GdkWindow);
			}
		}
	}

	private void OnFieldBlockChanged(Field field) {
		pixmap = null;
		QueueDraw();
	}

	private void OnFieldDimensionChanged(Field field) {
		pixmap = null;
		selection = null;
		creatingSelection = false;
		QueueDraw();
	}

	private void OnMotionNotify(object o, MotionNotifyEventArgs args) {
		if (OnMouseMove != null && field != null) {
			// Generate OnMouseMove events.
			FieldPoint p;

			p.X = (uint) Math.Max(0, args.Event.X);
			p.Y = (uint) Math.Max(0, args.Event.Y);
			if (!Calc.ScreenPosToFieldPos(ref p, field, zoomLevel)) {
				OnMouseMove(this, -1, -1);
			} else {
				OnMouseMove(this, (int) p.X, (int) p.Y);
			}
		}

		if (creatingSelection) {
			// Update selection.

			RedrawFieldRegion(selection);

			FieldPoint p;
			p.X = (uint) Math.Max(0, args.Event.X);
			p.Y = (uint) Math.Max(0, args.Event.Y);
			Calc.ScreenPosToFieldPos(ref p, field, zoomLevel);
			selection.SetEndPoint(p.X, p.Y);

			RedrawFieldRegion(selection);

			if (OnSelectionChanged != null) {
				OnSelectionChanged(this, selection);
			}
		}
	}

	private void OnButtonPress(object o, ButtonPressEventArgs args) {
		if (args.Event.Button == 1 && field != null) {
			// Create a new selection.
			creatingSelection = true;
			if (selection != null) {
				RedrawFieldRegion(selection);
			}

			FieldPoint p;
			p.X = (uint) Math.Max(0, args.Event.X);
			p.Y = (uint) Math.Max(0, args.Event.Y);
			Calc.ScreenPosToFieldPos(ref p, field, zoomLevel);

			selection = new FieldSelection();
			selection.SetBeginPoint(p.X, p.Y);
			RedrawFieldRegion(selection);

			if (OnSelectionChanged != null) {
				OnSelectionChanged(this, selection);
			}

		} else if (args.Event.Button == 3 && field != null && selection != null) {
			// Clear the selection and re-render the previously selected part.
			RedrawFieldRegion(selection);
			creatingSelection = false;
			selection = null;
			if (OnSelectionChanged != null) {
				OnSelectionChanged(this, null);
			}
		}
	}

	private void OnButtonRelease(object o, ButtonReleaseEventArgs args) {
		if (args.Event.Button == 1 && field != null && creatingSelection) {
			creatingSelection = false;
			RedrawFieldRegion(selection);
			if (OnSelectionChanged != null) {
				OnSelectionChanged(this, selection);
			}
		}
	}

	/**
	 * Mark a region of the field for redrawing.
	 *
	 * @require field != null && region != null
	 */
	private void RedrawFieldRegion(FieldSelection region) {
		FieldPoint begin;
		begin.X = region.Left;
		begin.Y = region.Top;
		Calc.FieldPosToScreenPos(ref begin, field, zoomLevel);

		FieldPoint end;
		end.X = region.Right + 1;
		end.Y = region.Bottom - 1;
		Calc.FieldPosToScreenPos(ref end, field, zoomLevel);

		QueueDrawArea((int) begin.X, (int) begin.Y,
			(int) (end.X - begin.X),
			(int) (end.Y - begin.Y));
	}


	/********************** Renderers **********************/
	

	/**
	 * Render a part of a field to a Drawable.
	 *
	 * @param region     The region to render.
	 * @param selection  The region of the field that is selected, or null.
	 *                   This region will be rendered with a different color.
	 * @param drawable   The Drawable to render to.
	 */
	private void RenderToDrawable(Field field, FieldSelection region, FieldSelection selection,
		uint zoomLevel, Drawable drawable)
	{
		int blockTypeLen = Enum.GetValues(((Enum) BlockType.Walkable).GetType()).Length;
		/*
		 * These variables map a BlockType to a list of points on screen.
		 * normalPoints contains the points that should be rendered normally.
		 * selectedPoints contains the points that are to be rendered with the selection color.
		 */
		IList<Point>[] normalPoints   = new List<Point>[blockTypeLen];
		IList<Point>[] selectedPoints = new List<Point>[blockTypeLen];

		/*
		 * Look at every block in the field and update blockTypePoints
		 * with a corresponding list of points per block type. Then
		 * render those list of points.
		 */
		for (uint y = region.Bottom; y <= region.Top; y++) {
			for (uint x = region.Left; x <= region.Right; x++) {
				BlockType type;
				IList<Point>[] pointsArray;
				IList<Point> points;
				Point point;

				type = field.GetBlock(x, y);

				// Check whether this block is within the selection, and determine
				// which array to use.
				if (selection != null && x >= selection.Left && x <= selection.Right
				 && y >= selection.Bottom && y <= selection.Top) {
					pointsArray = selectedPoints;
				} else {
					pointsArray = normalPoints;
				}
				points = pointsArray[(int) type];
				if (points == null) {
					points = new List<Point>(1024);
					pointsArray[(int) type] = points;
				}

				point.X = (int) x;
				point.Y = (int) y;
				Calc.FieldPosToScreenPos(ref point, field, zoomLevel);
				points.Add(point);
			}
		}

		/* Note: we used to use Gdk.DrawPoints() and Gdk.DrawRectangle()
		 * to render the field, but performance was abysmal on Windows,
		 * and Gtk-Sharp for Windows has a different parameter definition
		 * for DrawPoints() than the Linux version! The GdkPixbuf renderer
		 * is the most cross-platform with decent performance.
		 */
		RenderFieldBlocksWithPixbuf(drawable, region, field, zoomLevel,
			normalPoints, selectedPoints);

		// Render selection.
		if (selection != null) {
			Point p1, p2;
			p1.X = (int) selection.Left;
			p1.Y = (int) selection.Top;
			p2.X = (int) selection.Right;
			p2.Y = (int) selection.Bottom;
			Calc.FieldPosToScreenPos(ref p1, field, zoomLevel);
			Calc.FieldPosToScreenPos(ref p2, field, zoomLevel);
			drawable.DrawRectangle(colors.SelectionBorderGC, false,
				p1.X, p1.Y,
				(int) (p2.X - p1.X + zoomLevel - 1),
				(int) (p2.Y - p1.Y + zoomLevel - 1));
		}
	}

	/** The number of channels in the GdkPixbuf used to render the field. */
	const int CHANNELS = 4;

	/**
	 * Render a rectangle on a pixel buffer.
	 *
	 * @param pixels    A buffer with raw pixel data.
	 * @param x, y      The coordinates to render the rectangle on.
	 * @param width     The width of the rectangle to render.
	 * @param height    The height of the rectangle to render.
	 * @param imgwidth  The width of the image represented by the pixel buffer.
	 * @param red, green, blue  An RGB value to use as color for the rectangle. 
	 */
	private void RenderRect(byte[] pixels, uint x, uint y, uint width, uint height,
				uint imgwidth, byte red, byte blue, byte green) {
		for (uint j = y; j < y + height; j++) {
			for (uint i = x; i < x + width; i++) {
				pixels[(j * imgwidth + i) * CHANNELS] = red;
				pixels[(j * imgwidth + i) * CHANNELS + 1] = blue;
				pixels[(j * imgwidth + i) * CHANNELS + 2] = green;
				pixels[(j * imgwidth + i) * CHANNELS + 3] = 0xFF;
			}
		}
	}

	private void RenderFieldBlocksWithPixbuf(Drawable drawable, FieldSelection region,
	                    Field field, uint zoomLevel,
	                    IList<Point>[] normalPoints,
	                    IList<Point>[] selectedPoints) {
		Point screenLeftTop;
		uint width, height;
		byte[] pixels;
		int blockTypeLen;

		screenLeftTop.X = (int) region.Left;
		screenLeftTop.Y = (int) region.Top;
		Calc.FieldPosToScreenPos(ref screenLeftTop, field, zoomLevel);
		width = region.Width * zoomLevel;
		height = region.Height * zoomLevel;
		pixels = new byte[width * height * CHANNELS];
		blockTypeLen = Enum.GetValues(((Enum) BlockType.Walkable).GetType()).Length;

		for (int i = 0; i < blockTypeLen; i++) {
			if (normalPoints[i] != null) {
				foreach (Point p in normalPoints[i]) {
					Color color = colors.GetColor(i);
					RenderRect(pixels,
						(uint) (p.X - screenLeftTop.X),
						(uint) (p.Y - screenLeftTop.Y),
						zoomLevel, zoomLevel, width,
						(byte) (color.Red / 256),
						(byte) (color.Green / 256),
						(byte) (color.Blue / 256));
				}
			}
			if (selectedPoints[i] != null) {
				foreach (Point p in selectedPoints[i]) {
					Color color = colors.GetSelectionColor(i);
					RenderRect(pixels,
						(uint) (p.X - screenLeftTop.X),
						(uint) (p.Y - screenLeftTop.Y),
						zoomLevel, zoomLevel, width,
						(byte) (color.Red / 256),
						(byte) (color.Green / 256),
						(byte) (color.Blue / 256));
				}
			}
		}
		
		using (Pixbuf pixbuf = new Pixbuf(pixels, Colorspace.Rgb, true, 8,
						(int) width, (int) height,
						(int) width * CHANNELS, null)) {
			pixbuf.RenderToDrawable(drawable, Style.BlackGC,
				0, 0, screenLeftTop.X, screenLeftTop.Y,
				(int) width, (int) height,
				RgbDither.Normal, 0, 0);
		}
	}
}

} // namespace FieldEditor
