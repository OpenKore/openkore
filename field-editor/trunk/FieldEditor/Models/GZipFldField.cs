using System;
using System.IO;
using ICSharpCode.SharpZipLib.GZip;

namespace FieldEditor {

/**
 * Supports loading GZip-compressed .fld files.
 */
public class GZipFldField: Field {
	private FldField field;

	public override uint Width {
		get { return field.Width; }
		set { field.Width = value; }
	}

	public override uint Height {
		get { return field.Height; }
		set { field.Height = value; }
	}

	/**
	 * Construct a new GZipFldField object and load a field file
	 * from the specified filename.
	 *
	 * @throws IOException, InvalidFieldException, ApplicationException
	 */
	public GZipFldField(string filename) {
		Stream file = new FileStream(filename, FileMode.Open);
		Stream gzipStream = new GZipInputStream(file);
		field = new FldField(gzipStream);
		gzipStream.Close();
		file.Close();
	}

	/**
	 * Construct an FldField object from another Field object.
	 */
	public GZipFldField(Field field) {
		this.field = new FldField(field);
	}

	public override BlockType GetBlock(uint x, uint y) {
		return field.GetBlock(x, y);
	}

	public override void SetBlock(uint x, uint y, BlockType type) {
		field.SetBlock(x, y, type);
	}

	public override void Save(string filename) {
		Stream stream = new FileStream(filename, FileMode.Create);
		Save(stream);
		stream.Close();
	}

	public override void Save(Stream stream) {
		GZipOutputStream gzipStream = new GZipOutputStream(stream);
		gzipStream.IsStreamOwner = true;
		gzipStream.SetLevel(9);
		field.Save(gzipStream);
	}

	public override void Resize(uint newwidth, uint newheight) {
		field.Resize(newwidth, newheight);
	}
}

} // namespace FieldEditor