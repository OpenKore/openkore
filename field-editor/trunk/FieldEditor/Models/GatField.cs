using System;
using System.IO;

namespace FieldEditor {

/**
 * A field model which can load from .gat files. Saving is not supported.
 *
 * See http://www.openkore.com/wiki/index.php/Field_file_format
 * for specification.
 */
public class GatField: Field {
	public readonly byte[] CORRECT_SIGNATURE = new byte[] {0x47, 0x52, 0x41, 0x54, 0x01, 0x02};

	/** The field data. Is null if the field is empty. */
	protected BlockType[][] blocks;

	protected bool hasWaterLevel;
	protected float waterLevel;


	/**
	 * Construct a new GatField object and load the specified .gat file.
	 *
	 * @param FileName  The filename of the .gat file to load.
	 * @param RswFile   The filename of the corresponding .rsw file. This may be null.
	 * @throws IOException, InvalidFieldFileException
	 */
	public GatField(string FileName, string RswFile) {
		Stream gatStream = new FileStream(FileName, FileMode.Open);
		Stream rswStream = null;
		
		if (RswFile != null) {
			rswStream = new FileStream(RswFile, FileMode.Open);
		}
		LoadStream(gatStream, rswStream);
		gatStream.Close();
	}

	/**
	 * Load a .gat file from the specified stream(s).
	 *
	 * @param gatStream  The stream which contains the .gat file.
	 * @param rswStream  The stream which contains the corresponding .rsw file. This may be null.
	 * @require The streams must not be closed.
	 * @throws IOException, InvalidFieldFileException
	 */
	virtual protected void LoadStream(Stream gatStream, Stream rswStream) {
		BinaryReader reader;

		hasWaterLevel = rswStream != null;
		if (rswStream != null) {
			BinaryReader rswReader;

			rswStream.Seek(166, SeekOrigin.Begin);
			rswReader = new BinaryReader(rswStream);
			waterLevel = rswReader.ReadSingle();
		}

		gatStream = new BufferedStream(gatStream);
		reader = new BinaryReader(gatStream);
		try {
			byte[] magic;
			bool correct;

			// Check signature.
			magic = reader.ReadBytes(CORRECT_SIGNATURE.Length);
			// magic.Equals(CORRECT_SIGNATURE) doesn't work, bah.
			correct = magic.Length == CORRECT_SIGNATURE.Length;
			if (correct) {
				for (int i = 0; i < magic.Length && correct; i++) {
					correct = magic[i] == CORRECT_SIGNATURE[i];
				}
			}
			if (!correct) {
				throw new InvalidFieldFileException("This does not seem to be a valid .GAT file.");
			}

			// Read dimensions.
			width = reader.ReadUInt32();
			height = reader.ReadUInt32();

			// Read field data.
			blocks = new BlockType[width][];

			for (uint x = 0; x < width; x++) {
				blocks[x] = new BlockType[height];
			}

			for (uint y = 0; y < height; y++) {
				for (uint x = 0; x < width; x++) {
					float upperLeftHeight  = reader.ReadSingle();
					float upperRightHeight = reader.ReadSingle();
					float lowerLeftHeight  = reader.ReadSingle();
					float lowerRightHeight = reader.ReadSingle();
					byte type = reader.ReadByte();
					reader.ReadBytes(3);

					float averageDepth = (upperLeftHeight + upperRightHeight
						+ lowerLeftHeight + lowerRightHeight) / 4;
					blocks[x][y] = ByteToBlock(type, averageDepth);
				}
			}

		} catch (EndOfStreamException) {
			throw new InvalidFieldFileException("Unexpected end-of-file reached.");
		}
	}

	override public void Save(string filename) {
		throw new SaveNotSupportedException("Saving .GAT files is not supported.");
	}
	
	override public void Save(Stream stream) {
		Save("");
	}

	override public void Resize(uint newwidth, uint newheight) {
		if (newwidth == 0 && newheight == 0) {
			blocks = null;
		} else {
			BlockType[][] newblocks;

			newblocks = new BlockType[newwidth][];

			for (int x = 0; x < newwidth; x++) {
				newblocks[x] = new BlockType[newheight];
			}

			for (int y = 0; y < newheight; y++) {
				for (int x = 0; x < newwidth; x++) {
					if (x < width && y < height) {
						// Copy old data.
						newblocks[x][y] = blocks[x][y];
					} else {
						// Fill a default type.
						newblocks[x][y] = DEFAULT_BLOCK_FILL;
					}
				}
			}
			blocks = newblocks;
		}
		width = newwidth;
		height = newheight;
		SetDimensionChanged();
	}

	override public BlockType GetBlock(uint x, uint y) {
		return blocks[x][y];
	}

	override public void SetBlock(uint x, uint y, BlockType type) {
		blocks[x][y] = type;
		SetBlockChanged();
	}

	private BlockType ByteToBlock(byte b, float averageDepth) {
		if (hasWaterLevel && averageDepth > waterLevel) {
			// Block is below water level.
			switch (b) {
			case 0:
				return BlockType.Walkable;
			case 1:
				return BlockType.NonWalkableNonSnipableWater;
			case 3:
				return BlockType.WalkableWater;
			case 5:
				return BlockType.NonWalkableSnipableWater;
			case 6:
				return BlockType.NonWalkableNonSnipableWater;
			default:
				return BlockType.Unknown;
			}
		} else {
			// Block is above water level.
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
}

} // namespace FieldEditor