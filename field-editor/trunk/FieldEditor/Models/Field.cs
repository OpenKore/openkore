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
 * A convenience structure for representing a point on the field.
 */
public struct FieldPoint {
	public uint X;
	public uint Y;
}

public class FieldSelection {
	public uint Left, Right;
	public uint Top,  Bottom;

	private uint beginX, beginY;

	public uint Width {
		get { return Right - Left + 1; }
	}

	public uint Height {
		get { return Top - Bottom + 1; }
	}

	public void SetBeginPoint(uint x, uint y) {
		Left = Right = beginX = x;
		Top = Bottom = beginY = y;
	}

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

	protected void SetBlockChanged() {
		if (OnBlockChanged != null) {
			OnBlockChanged(this);
		}
	}

	protected void SetDimensionChanged() {
		if (OnDimensionChanged != null) {
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
