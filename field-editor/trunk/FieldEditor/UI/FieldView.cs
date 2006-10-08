using System;
using System.Collections;
using Gtk;
using Gdk;

namespace FieldEditor {

/**
 * Various functions for calculating coordinates.
 */
internal class Calc {
	public static FieldRegion ScreenSelectionToFieldRegion(
		Field field, uint zoomLevel, int x, int y, int width, int height
	) {
		FieldRegion s = new FieldRegion();
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
public delegate void SelectionChangedEvent(FieldView source, FieldRegion selection);


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
	 * The field renderer to use.
	 *
	 * @invariant
	 *     if field != null: renderer != null
	 */
	private FieldRenderer renderer;

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
	private FieldRegion selection;
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
					if (renderer == null) {
						renderer = new FieldRenderer(field, null);
					}
					renderer.ZoomLevel = zoomLevel;
				}
				QueueDraw();
			}
		}
	}
	
	public FieldRegion Selection {
		get { return selection; }
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

					if (renderer != null) {
						renderer.Field = field;
					} else {
						renderer = new FieldRenderer(field, null);
					}

				} else {
					SetSizeRequest(0, 0);
					renderer = null;
				}
				QueueDraw();
			}
		}
	}

	/**
	 * Construct a new FieldView widget.
	 */
	public FieldView() {
		ExposeEvent += OnExposed;
		MotionNotifyEvent += OnMotionNotify;
		ButtonPressEvent += OnButtonPress;
		ButtonReleaseEvent += OnButtonRelease;
		Events |= EventMask.PointerMotionMask | EventMask.ButtonPressMask | EventMask.ButtonReleaseMask;
	}

	private void OnExposed(object o, ExposeEventArgs args) {
		Rectangle area = args.Event.Region.Clipbox;

		GdkWindow.DrawRectangle(Style.BackgroundGC(StateType.Normal), true,
			area.X, area.Y, area.Width, area.Height);
		if (field != null) {
			if (pixmap == null) {
				FieldRegion region;

				pixmap = new Pixmap(GdkWindow,
					(int) (field.Width * zoomLevel),
					(int) (field.Height * zoomLevel),
					-1);
				region = new FieldRegion();
				region.Left = region.Bottom = 0;
				region.Right = field.Width - 1;
				region.Top = field.Height - 1;
				renderer.RenderToDrawable(pixmap, Style.BlackGC, region, null);
			}

			GdkWindow.DrawDrawable(Style.BlackGC, pixmap,
				area.X, area.Y, area.X, area.Y,
				area.Width, area.Height);

			if (selection != null) {
				renderer.RenderToDrawable(GdkWindow, Style.BlackGC,
					selection, selection);
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

			selection = new FieldRegion();
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
	private void RedrawFieldRegion(FieldRegion region) {
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
}

} // namespace FieldEditor
