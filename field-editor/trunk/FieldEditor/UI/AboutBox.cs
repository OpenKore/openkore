using System;
using Gtk;
using Glade;

namespace FieldEditor {

public class AboutBox {
	static private AboutBox instance;
	[Widget] private Dialog aboutBox;

	private AboutBox() {
		Glade.XML xml = MainWindow.getGlade("AboutBox.glade");
		xml.Autoconnect(this);
	}

	public static void Present(Window parent) {
		if (instance == null) {
			instance = new AboutBox();
		}
		instance.aboutBox.TransientFor = parent;
		instance.aboutBox.Show();
		instance.aboutBox.Present();
	}

	protected void OnWindowClosed(object o, DeleteEventArgs args) {
		OnCloseClicked(null, null);
		args.RetVal = true;
	}

	protected void OnCloseClicked(object o, EventArgs args) {
		aboutBox.Hide();
	}
}

} // namespace FieldEditor