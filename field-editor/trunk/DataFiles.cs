using System;
using System.IO;
using GLib;

namespace FieldEditor {

/**
 * This class provides data files lookup services.
 */
public class DataFiles {
	private static readonly string BASE_DIR = System.AppDomain.CurrentDomain.BaseDirectory;

	/**
	 * Find a Glade file.
	 *
	 * @param baseName  The base name of the Glade file to find.
	 * @return A full filename, or null if not found.
	 * @require baseName != null
	 */
	public static string Glade(string baseName) {
		string[] dirs = new string[] {
			Path.Combine(BASE_DIR, "glade"),
			Path.Combine(Path.Combine(Path.Combine(BASE_DIR, ".."), ".."), "glade"),
			BASE_DIR,
			Path.Combine(Path.Combine(BASE_DIR, ".."), "..")
		};
		return FindFirst(dirs, baseName);
	}

	private static string FindFirst(string[] dirs, string baseName) {
		foreach (string dir in dirs) {
			string filename = Path.Combine(dir, baseName);
			if (File.Exists(filename)) {
				return filename;
			}
		}
		return null;
	}
}

} // namespace FieldEditor