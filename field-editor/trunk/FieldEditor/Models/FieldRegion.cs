namespace FieldEditor {

/**
 * Represents a region on a Field.
 *
 * This class also provides convenience methods for interactively
 * updating a selection on the field: SetBeginPoint()
 * and SetEndPoint().
 */
public class FieldRegion {
	public uint Left, Right;
	public uint Top,  Bottom;

	private uint beginX, beginY;

	public uint Width {
		get { return Right - Left + 1; }
	}

	public uint Height {
		get { return Top - Bottom + 1; }
	}

	/**
	 * Set the begin point of the field region.
	 *
	 * This function does not update any of the fields
	 * in this class. They are only calculated
	 * when you call SetEndPoint().
	 */
	public void SetBeginPoint(uint x, uint y) {
		Left = Right = beginX = x;
		Top = Bottom = beginY = y;
	}

	/**
	 * Set the end point of the field region.
	 * The Left, Right, Top, Bottom, Width and Height
	 * fields are automatically updated according to the
	 * set begin and end points.
	 *
	 * @require SetBeginPoint() must have been called in the past.
	 */
	public void SetEndPoint(uint x, uint y) {
		if (x > beginX) {
			Right = x;
		} else {
			Right = beginX;
			Left = x;
		}
		if (y < beginY) {
			Bottom = y;
		} else {
			Bottom = beginY;
			Top = y;
		}
	}
}

} // namespace FieldRegion