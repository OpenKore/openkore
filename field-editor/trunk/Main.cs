using System;
using System.IO;
using Gtk;

namespace FieldEditor {

class MainClass	{
	public static void Main(string[] args) {
		Application.Init();
		#if !DEBUG || BETA
		try {
		#endif
			new MainWindow();
			Application.Run();
		#if !DEBUG || BETA
		} catch (Exception e) {
			string msg = "An unexpected occured:\n{0}";

			try { 
				TextWriter s = new StreamWriter("exception.txt");
				s.WriteLine(e.Message + ":\n" + e.StackTrace);
				s.Close();
				msg += "\n\nA stack trace has been written to exception.txt.";
			} finally {
				Dialog d = new MessageDialog(null, DialogFlags.Modal,
					MessageType.Error, ButtonsType.Ok,
					msg, e.Message);
				d.Resizable = false;
				d.Run();
				d.Destroy();
			}
		}
		#endif
	}
}

} // namespace FieldEditor
