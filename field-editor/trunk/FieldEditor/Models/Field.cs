using System;
using System.IO;

namespace FieldEditor {

/**
 * Thrown when trying to load an invalid field file.
 */
public class InvalidFieldFileException: Exception {
	public InvalidFieldFileException(string Message): base(Message) {
	}
}

/**
 * Thrown when a Field class does not support saving.
 */
public class SaveNotSupportedException: Exception {
	public SaveNotSupportedException(string Message): base(Message) {
	}
}

/**
 * Describes the type of a block on a field. 
 */
public enum BlockType {
	Walkable,
	NonWalkable,
	NonWalkableNonSnipableWater,
	WalkableWater,
	NonWalkableSnipableWater,
	SnipableCliff,
	NonSnipableCliff,
	Unknown
}

public delegate void FieldBlockChangedEvent(Field source);
public delegate void FieldDimensionChangedEvent(Field source);

/**
 * This abstract class models a two-dimensional field.
 * The field consists of blocks, and each block has a specific type.
 */
public abstract class Field {
	public const BlockType DEFAULT_BLOCK_FILL = BlockType.NonWalkable;

	/** The width of this field. */
	protected uint width = 0;
	/** The height of this field. */
	protected uint height = 0;
	protected uint updateLevel = 0;
	protected bool blockChanged = false, dimensionChanged = false;

	/** Invoked when a block in this field has been changed. */
	public event FieldBlockChangedEvent OnBlockChanged;
	/** Invoked when the width or height of this field has been changed. */
	public event FieldDimensionChangedEvent OnDimensionChanged;


	/**
	 * The width of this field.
	 *
	 * If you set the value to a larger value, then new field
	 * blocks are automatically set to DEFAULT_BLOCK_FILL. 
	 */
	public virtual uint Width {
		get { return width; }
		set {
			if (width != value) {
				Resize(value, height);
			}
		}
	}

	/**
	 * The height of this field.
	 *
	 * If you set the value to a larger value, then new field
	 * blocks are automatically set to BlockType.NonWalkable.
	 */
	public virtual uint Height {
		get { return height; }
		set {
			if (height != value) {
				Resize(width, value);
			}
		}
	}

	/**
	 * Construct this Field object from another Field object.
	 */
	protected void ConstructFromField(Field field) {
		Resize(field.Width, field.Height);
		for (uint x = 0; x < width; x++) {
			for (uint y = 0; y < height; y++) {
				SetBlock(x, y, field.GetBlock(x, y));
			}
		} 
	}

	/**
	 * Returns the type of the block at the specified coordinate.
	 *
	 * @require x < Width && y < Height
	 */
	abstract public BlockType GetBlock(uint x, uint y);

	/**
	 * Set the type of the block at the specified coordinate.
	 *
	 * Triggers the Changed event.
	 *
 	 * @require x < Width && y < Height
 	 * @ensure GetBlock(x, y) == type
	 */
	abstract public void SetBlock(uint x, uint y, BlockType type);

	/**
	 * Save this field to a file. The file format depends on the concrete class,
	 * and can only be loaded by that same class.
	 *
	 * @param filename  The file to save to.
	 * @throws IOException, SaveNotSupportedException
	 */
	abstract public void Save(string filename);

	/**
	 * Save this field to a stream. The file format depends on the concrete class,
	 * and can only be loaded by that same class.
	 *
	 * @param stream  The stream to save to.
	 * @throws IOException, SaveNotSupportedException
	 */
	abstract public void Save(Stream stream);

	/**
	 * Resize the field to the specified dimensions.
	 * New field blocks are to be set to DEFAULT_BLOCK_FILL.
	 *
	 * Triggers the Changed event.
	 *
	 * @ensure Width == newwidth && Height == newheight 
	 */
	abstract public void Resize(uint newwidth, uint newheight);

	/**
	 * Specify that you're about to change the field. This field will be marked
	 * as "updating". While the "updating" mark is enabled, field update events
	 * will not be sent.
	 *
	 * When you're done changing the field, you must call EndUpdate(). If the field
	 * has changed between your last BeginUpdate() call and this EndUpdate() call,
	 * a field update event will be sent (but only once).
	 *
	 * This function can be stacked. That is: if you call BeginUpdate() twice, then
	 * field update events will only be sent when EndUpdate() has been called twice.
	 * You must not call EndUpdate() more often than BeginUpdate().
	 *
	 * Usage of this function may significantly improve performance if you're
	 * modifying many parts of the field.
	 */
	public virtual void BeginUpdate() {
		updateLevel++;
	}

	public virtual void EndUpdate() {
		updateLevel--;
		if (updateLevel == 0) {
			if (blockChanged && OnBlockChanged != null) {
				blockChanged = false;
				OnBlockChanged(this);
			}
			if (dimensionChanged && OnDimensionChanged != null) {
				dimensionChanged = false;
				OnDimensionChanged(this);
			}
		}
	}

	protected void SetBlockChanged() {
		blockChanged = true;
		if (updateLevel > 0 && OnBlockChanged != null) {
			blockChanged = false;
			OnBlockChanged(this);
		}
	}

	protected void SetDimensionChanged() {
		dimensionChanged = true;
		if (updateLevel > 0 && OnDimensionChanged != null) {
			dimensionChanged = false;
			OnDimensionChanged(this);
		}
	}

	public static string BlockTypeToString(BlockType type) {
		switch (type) {
		case BlockType.Walkable:
			return "Walkable";
		case BlockType.NonWalkable:
			return "Non-walkable";
		case BlockType.NonWalkableNonSnipableWater:
			return "Non-walkable non-snipable water";
		case BlockType.WalkableWater:
			return "Walkable water";
		case BlockType.NonWalkableSnipableWater:
			return "Non-walkable snipable water";
		case BlockType.SnipableCliff:
			return "Snipable cliff";
		case BlockType.NonSnipableCliff:
			return "Non-snipable cliff";
		default:
			return "Unknown";
		}
	}
}

} // namespace OpenKore
