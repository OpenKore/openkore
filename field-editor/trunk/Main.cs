using System;
using Gtk;

namespace FieldEditor {

class MainClass	{
	public static void Main(string[] args) {
		Application.Init();
		new MainWindow();
		Application.Run();
	}
}

} // namespace FieldEditor
