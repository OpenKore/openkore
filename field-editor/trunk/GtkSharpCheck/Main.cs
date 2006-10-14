using System;

namespace GtkSharpCheck {

/*
 * This program checks whether Gtk-Sharp is installed.
 * Returns 0 on success, 1 on error.
 */

public class MainClass {
	public static int Main(string[] args) {
		try {
			AppDomain.CurrentDomain.Load("gtk-sharp, Version=2.4.0.0, Culture=neutral, PublicKeyToken=35e10195dab3c99f");
			return 0;
		} catch (Exception) {
			return 1;
		}
	}
}

} // namespace GtkSharpCheck