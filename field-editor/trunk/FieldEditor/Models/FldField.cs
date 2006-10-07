using System;
using System.IO;

namespace FieldEditor {

/**
 * A field model which can load from and save to .fld files.
 *
 * See http://www.openkore.com/wiki/index.php/Field_file_format
 * for specification.
 */
public class FldField: Field {
	/** The raw field data. Is null if the field is empty. */
	protected byte[] data;

	/**
	 * Construct a new FldField object and load the specified .fld file.
	 *
	 * @throws IOException, InvalidFieldFileException
	 */
	public FldField(string FileName): base() {
		Stream s = new FileStream(FileName, FileMode.Open);
		LoadStream(s);
		s.Close();
	}

	/**
	 * Construct an FldField object from another Field object.
	 */
	public FldField(Field field): base(field) {
	}

	/**
	 * Construct an FldField object and load it from the specified stream.
	 *
	 * @throws IOException, InvalidFieldException
	 */
	public FldField(Stream s) {
		LoadStream(s);
	}

	/**
	 * Load a .fld file from the specified stream.
	 *
	 * @throws IOException, InvalidFieldFileException
	 */
	virtual protected void LoadStream(Stream s) {
		ushort w, h;

		BinaryReader reader = new BinaryReader(s);
		width = w = reader.ReadUInt16();
		height = h = reader.ReadUInt16();
		data = reader.ReadBytes(w * h);
		if (data.Length != w * h) {
			throw new InvalidFieldFileException("Field data size does not match dimensions.");
		}
	}

	override public void Save(string filename) {
		Save(new FileStream(filename, FileMode.Create));
	}

	override public void Save(Stream stream) {
		BinaryWriter writer = new BinaryWriter(stream);
		writer.Write((ushort) width);
		writer.Write((ushort) height);
		writer.Write(data);
		writer.Close();
	}

	override public void Resize(uint newwidth, uint newheight) {
		if (newwidth == 0 && newheight == 0) {
			data = null;
		} else {
			byte[] newdata;

			newdata = new byte[newwidth * newheight];
			for (int y = 0; y < newheight; y++) {
				for (int x = 0; x < newwidth; x++) {
					if (x < width && y < height) {
						// Copy old data.
						newdata[y * newwidth + x] = data[y * width + x];
					} else {
						// Fill a default type.
						newdata[y * newwidth + x] = BlockToByte(DEFAULT_BLOCK_FILL);
					}
				}
			}
			data = newdata;
		}
		width = newwidth;
		height = newheight;
		SetDimensionChanged();
	}

	override public BlockType GetBlock(uint x, uint y) {
		return ByteToBlock(data[y * width + x]);
	}

	override public void SetBlock(uint x, uint y, BlockType type) {
		data[y * width + x] = BlockToByte(type);
		SetBlockChanged();
	}

	private byte BlockToByte(BlockType b) {
		switch (b) {
		case BlockType.Walkable:
			return 0;
		case BlockType.NonWalkable:
			return 1;
		case BlockType.NonWalkableNonSnipableWater:
			return 2;
		case BlockType.WalkableWater:
			return 3;
		case BlockType.NonWalkableSnipableWater:
			return 4;
		case BlockType.SnipableCliff:
			return 5;
		case BlockType.NonSnipableCliff:
			return 6;
		default:
			return 7;
		}
	}

	private BlockType ByteToBlock(byte b) {
		switch (b) {
		case 0:
			return BlockType.Walkable;
		case 1:
			return BlockType.NonWalkable;
		case 2:
			return BlockType.NonWalkableNonSnipableWater;
		case 3:
			return BlockType.WalkableWater;
		case 4:
			return BlockType.NonWalkableSnipableWater;
		case 5:
			return BlockType.SnipableCliff;
		case 6:
			return BlockType.NonSnipableCliff;
		default:
			return BlockType.Unknown;
		}
	}
}

} // namespace FieldEditor