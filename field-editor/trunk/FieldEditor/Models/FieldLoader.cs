using System;
using System.IO;
using System.Collections;

namespace FieldEditor {

/**
 * Represents a class which can load a field file and generate a Field model.
 */
public interface FieldLoadModule {
	/**
	 * Load a field from the specified stream.
	 *
	 * Loading may generate a warning, which is a message that
	 * should be displayed to the user. Warnings are not critical, meaning
	 * that the field file has successfully been loaded.
	 *
	 * @param s         The stream to load from.
	 * @param warning   If a warning message occured while loading
	 *                  this file, then the warning will be placed
	 *                  in this variable. Otherwise, it is set to null.
	 * @throws IOException, InvalidFieldFileException
	 * @require !s.Closed
	 */
	Field LoadFromStream(Stream s, out string warning);

	/**
	 * Returns whether this FieldLoadModule supports loading
	 * the specified file.
	 */
	bool SupportsFile(string filename);
}

/**
 * Convenience class for loading field files of various types.
 * This class automatically detects the field type and determines
 * which model class to use.
 *
 * External DLLs may register new loaders to add support for more
 * file formats.
 */
public class FieldLoader {
	private static IList loadModules = new ArrayList();

	/**
	 * Load a field from the specified file.
	 *
	 * Loading some files may generate a warning, which is a message that
	 * should be displayed to the user. Warnings are not critical, meaning
	 * that the field file has successfully been loaded.
	 *
	 * @param filename  The file to load from.
	 * @param warning   If a warning message occured while loading
	 *                  this file, then the warning will be placed
	 *                  in this variable. Otherwise, it is set to null.
	 * @return The loaded field, or null if the field format is not supported.
	 * @throws IOException, InvalidFieldFileException, ApplicationException
	 */
	public static Field LoadFromFile(string filename, out string warning) {
		string fn;

		fn = filename.ToLower();
		warning = null;
		if (fn.EndsWith(".fld")) {
			return new FldField(filename);

		} else if (fn.EndsWith(".gat")) {
			string rswFile = Path.ChangeExtension(filename, ".rsw");
			
			if (File.Exists(rswFile)) {
				return new GatField(filename, rswFile);
			} else {
				warning = "You are loading a .gat file. For optimal results, " +
					"OpenKore Field Editor needs the file " + Path.GetFileName(rswFile) +
					", which doesn't exist.\n\n" +
					"Please put " + Path.GetFileName(rswFile) + " in the same folder as " +
					Path.GetFileName(filename) + " if you know how to do that.";
				return new GatField(filename, null);
			}

		} else if (fn.EndsWith(".fld.gz")) {
			return new GZipFldField(filename);

		} else {
			foreach (FieldLoadModule module in loadModules) {
				if (module.SupportsFile(filename)) {
					Stream s = new FileStream(filename, FileMode.Open);
					return module.LoadFromStream(s, out warning);
				}
			}
			return null;
		}
	}

	public static Field LoadFromFile(string filename) {
		string w;
		return LoadFromFile(filename, out w);
	}

	/**
	 * Register a loader module.
	 */
	public static void RegisterLoadModule(FieldLoadModule module) {
		loadModules.Add(module);
	}
}

} // namespace FieldEditor