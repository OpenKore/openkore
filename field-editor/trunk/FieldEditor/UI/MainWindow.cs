using System;
using System.IO;
using Gtk;
using Glade;

namespace FieldEditor {

public class MainWindow {
	[Widget] private Window window;
	[Widget] private ScrolledWindow scrolledWindow;
	[Widget] private FileChooserDialog openFileDialog, saveFileDialog;
	[Widget] private HPaned splitPane;
	[Widget] private Widget infoTable;
	[Widget] private SpinButton widthEdit, heightEdit;
	[Widget] private Label currentCoord, currentBlockType, zoomLevelLabel, selectedCoord;
	[Widget] private MenuItem saveMenu, saveAsMenu;
	[Widget] private ToolButton saveAsButton, zoomInButton, zoomOutButton;
	[Widget] private ComboBox selectedBlockType;

	private FieldView fieldView;
	/** The currently open file. */
	private string filename = null;
	private bool selectedBlockTypeChanging;

	public MainWindow() {
		initUI();
	}

	private void initUI() {
		Glade.XML xml = getGlade("MainWindow.glade");
		xml.Autoconnect(this);
		setupSelectedBlockType();

		fieldView = new FieldView();
		fieldView.OnMouseMove += OnFieldMouseMove;
		fieldView.OnSelectionChanged += OnFieldSelectionChanged;
		scrolledWindow.AddWithViewport(fieldView);
		fieldView.Show();

		splitPane.Position = 320;

		try {
			window.Icon = Gdk.Pixbuf.LoadFromResource("FieldEditor.ico");
		} catch (GLib.GException) {
			window.Icon = Gdk.Pixbuf.LoadFromResource("FieldEditor.FieldEditor.ico");
		} catch (ArgumentException) {
			window.Icon = Gdk.Pixbuf.LoadFromResource("FieldEditor.FieldEditor.ico");
		}
		window.Show();
	}

	private void setupOpenDialog() {
		FileFilter filter;
		Glade.XML xml = getGlade("OpenDialog.glade");

		xml.Autoconnect(this);

		filter = new FileFilter();
		filter.Name = "All support files (*.fld, *.fld.gz, *.gat)";
		filter.AddPattern("*.fld");
		filter.AddPattern("*.fld.gz");
		filter.AddPattern("*.gat");
		openFileDialog.AddFilter(filter);

		filter = new FileFilter();
		filter.Name = "OpenKore Field Files (*.fld, *.fld.gz)";
		filter.AddPattern("*.fld");
		filter.AddPattern("*.fld.gz");
		openFileDialog.AddFilter(filter);

		filter = new FileFilter();
		filter.Name = "Ragnarok Online Ground Files (*.gat)";
		filter.AddPattern("*.gat");
		openFileDialog.AddFilter(filter);

		filter = new FileFilter();
		filter.Name = "All Files (*)";
		filter.AddPattern("*");
		openFileDialog.AddFilter(filter);

		openFileDialog.PreviewWidget = new FieldPreview();
		openFileDialog.UpdatePreview += OnUpdatePreview;
	}

	private void setupSaveDialog() {
		FileFilter filter;
		Glade.XML xml = getGlade("SaveDialog.glade");

		xml.Autoconnect(this);

		filter = new FileFilter();
		filter.Name = "OpenKore Field Files (*.fld)";
		filter.AddPattern("*.fld");
		saveFileDialog.AddFilter(filter);

		filter = new FileFilter();
		filter.Name = "Compressed OpenKore Field Files (*.fld.gz)";
		filter.AddPattern("*.fld.gz");
		saveFileDialog.AddFilter(filter);
	}

	/**
	 * Load an embedded Glade resource. This function handles
	 * the differences in resource names between Visual Studio
	 * and MonoDevelop.
	 */
	public static Glade.XML getGlade(string gladeName) {
		try {
			return new Glade.XML("FieldEditor.glade." + gladeName, null); 
		} catch (ArgumentException) {
			return new Glade.XML(gladeName, null);
		}
	}

	private void setupSelectedBlockType() {
		selectedBlockTypeChanging = true;
		((ListStore) selectedBlockType.Model).Clear();
		foreach (object o in Enum.GetValues(((Enum) BlockType.Walkable).GetType())) {
			selectedBlockType.AppendText(Field.BlockTypeToString((BlockType) o));
		}
		selectedBlockTypeChanging = false;
	}

	/********************************/

	/**
	 * Open a field file.
	 */
	private void Open(string filename) {
		string warning;
		Field field;
		Exception e = null;

		try {
			field = FieldLoader.LoadFromFile(filename, out warning);
			if (field == null) {
				ShowError("Unknown field file format.");
			} else {
				if (warning != null) {
					ShowWarning(warning);
				}
				fieldView.Field = field;
				this.filename = filename;
				Update();
			}
		} catch (ApplicationException e2) {
			e = e2;
		} catch (IOException e2) {
			e = e2;
		} catch (InvalidFieldFileException e2) {
			e = e2;
		}
		
		if (e != null) {
			ShowError("Unable to load the specified file:\n" + e.Message);
		}
	}

	/**
	 * Save the current field file.
	 *
	 * @require fieldView.Field != null
	 */
	private void Save(string filename) {
		Field field;
		string extension, fn;

		fn = filename.ToLower();
		extension = Path.GetExtension(fn);
		if ((extension == ".fld" && fieldView.Field is FldField)
		 || (extension == ".gat" && fieldView.Field is GatField)
		 || (fn.EndsWith(".fld.gz") && fieldView.Field is GZipFldField)) {
			field = fieldView.Field;
		} else if (fn.EndsWith(".fld")) {
			field = new FldField(fieldView.Field);
		} else {
			field = new GZipFldField(fieldView.Field);
		}

		try {
			field.Save(filename);
			fieldView.Field = field;
			this.filename = filename;
			Update();
		} catch (IOException e) {
			ShowError("Cannot save file:\n" + e.Message);
		} catch (SaveNotSupportedException e) {
			ShowError(e.Message);
		}
	}

	/**
	 * Called when a file has been opened or saved.
	 */
	private void Update() {
		window.Title = Path.GetFileName(filename) + " - OpenKore Field Editor";
		infoTable.Sensitive = saveMenu.Sensitive = saveAsMenu.Sensitive
			= saveAsButton.Sensitive = true;
		zoomInButton.Sensitive = fieldView.ZoomLevel < 20;
		zoomOutButton.Sensitive = fieldView.ZoomLevel > 1;
		widthEdit.Value = fieldView.Field.Width;
		heightEdit.Value = fieldView.Field.Height;
	}

	/**
	 * Show an error dialog.
	 */
	private void ShowError(string msg) {
		Dialog d = new MessageDialog(window, DialogFlags.Modal,
			MessageType.Error, ButtonsType.Ok,
			"{0}", msg);
		d.Resizable = false;
		d.Run();
		d.Destroy();
	}

	/**
	 * Show a warning dialog.
	 */
	private void ShowWarning(string msg) {
		Dialog d = new MessageDialog(window, DialogFlags.Modal,
			MessageType.Warning, ButtonsType.Ok,
			"{0}", msg);
		d.Resizable = false;
		d.Run();
		d.Destroy();
	}

	/**
	 * Show or hide the "(Mixed)" type in the 'Selected region' type combo box.
	 */
	private void ShowMixedType(bool show, bool activate) {
		int len;
		int count = 1;
		TreeIter iter;

		len = Enum.GetValues(((Enum) BlockType.Walkable).GetType()).Length;
		selectedBlockType.Model.GetIterFirst(out iter);
		while (selectedBlockType.Model.IterNext(ref iter)) {
			count++;
		}

		if (show && len == count) {
			selectedBlockType.AppendText("(Mixed)");
			if (activate) {
				selectedBlockType.Active = (int) count;
			}
		} else if (!show && len != count) {
			selectedBlockType.RemoveText(count - 1);
		}
	}

	/********* Callbacks *********/

	protected void OnDelete(object o, DeleteEventArgs args) {
		OnQuit(null, null);
	}

	protected void OnQuit(object o, EventArgs args) {
		Application.Quit();
	}

	protected void OnOpen(object o, EventArgs args) {
		if (openFileDialog == null) {
			setupOpenDialog();
		}

		ResponseType response = (ResponseType) openFileDialog.Run();
		openFileDialog.Hide();

		if (response == ResponseType.Ok) {
			Open(openFileDialog.Filename);
		}
	}

	protected void OnSave(object o, EventArgs args) {
		if (filename == null) {
			OnSaveAs(null, null);
		} else {
			Save(filename);
		}
	}

	protected void OnSaveAs(object o, EventArgs args) {
		if (saveFileDialog == null) {
			setupSaveDialog();
		}

		if (filename != null) {
			saveFileDialog.CurrentName = Path.GetFileName(filename);
		}
		ResponseType response = (ResponseType) saveFileDialog.Run();
		saveFileDialog.Hide();

		if (response == ResponseType.Ok) {
			string fn = saveFileDialog.Filename;
			if (Path.GetExtension(fn).ToLower() != ".fld") {
				fn += ".fld";
			}
			Save(fn);
		}
	}

	protected void OnAbout(object o, EventArgs args) {
		AboutBox.Present(window);
	}

	protected void OnWidthChanged(object o, EventArgs args) {
		fieldView.Field.Width = (uint) widthEdit.ValueAsInt;
	}

	protected void OnHeightChanged(object o, EventArgs args) {
		fieldView.Field.Height = (uint) heightEdit.ValueAsInt;
	}

	private void OnFieldMouseMove(FieldView sender, int x, int y) {
		if (x == -1 && y == -1) {
			currentCoord.Text = currentBlockType.Text = "-";
		} else {
			currentCoord.Text = String.Format("{0:d}, {1:d}", x, y);
			currentBlockType.Text = Field.BlockTypeToString(
				fieldView.Field.GetBlock((uint) x, (uint) y)
			);
		}
	}

	private void OnFieldSelectionChanged(FieldView sender, FieldRegion selection) {
		if (selection != null) {
			selectedBlockType.Sensitive = true;

			if (selection.Left != selection.Right || selection.Top != selection.Bottom) {
				// More than 1 block has been selected.
				selectedCoord.Text = String.Format("({0}, {1}) - ({2}, {3})",
					selection.Left, selection.Top,
					selection.Right, selection.Bottom);

				BlockType type = sender.Field.GetBlock(selection.Left, selection.Top);
				bool same = true;
				for (uint x = selection.Left; x <= selection.Right && same; x++) {
					for (uint y = selection.Bottom; y <= selection.Top && same; y++) {
						same = sender.Field.GetBlock(x, y) == type;
					}
				}

				selectedBlockTypeChanging = true;
				ShowMixedType(!same, !same);
				if (same) {
					selectedBlockType.Active = (int) type;
				}
				selectedBlockTypeChanging = false;

			} else {
				// Only 1 block is selected.
				selectedCoord.Text = String.Format("({0}, {1})",
					selection.Left, selection.Top);
				selectedBlockTypeChanging = true;
				ShowMixedType(false, false);
				selectedBlockType.Active = (int) sender.Field.GetBlock(selection.Left, selection.Top);
				selectedBlockTypeChanging = false;
			}

		} else {
			selectedCoord.Text = "-";
			selectedBlockType.Sensitive = false;
		}
	}

	protected void OnZoomIn(object o, EventArgs args) {
		fieldView.ZoomLevel++;
		zoomInButton.Sensitive = fieldView.ZoomLevel < 20;
		zoomOutButton.Sensitive = true;
		zoomLevelLabel.Text = String.Format("{0:d}x", fieldView.ZoomLevel);
	}

	protected void OnZoomOut(object o, EventArgs args) {
		fieldView.ZoomLevel--;
		zoomInButton.Sensitive = true;
		zoomOutButton.Sensitive = fieldView.ZoomLevel > 1;
		zoomLevelLabel.Text = String.Format("{0:d}x", fieldView.ZoomLevel);
	}

	protected void OnSelectedBlockTypeChanged(object o, EventArgs args) {
		int len = Enum.GetValues(((Enum) BlockType.Walkable).GetType()).Length;
		// Make sure we do nothing when user selected "(Mixed)",
		// or when the combo boxed is being automaticallychanged.
		if (selectedBlockType.Active < len && !selectedBlockTypeChanging) {
			BlockType type = (BlockType) selectedBlockType.Active;
			FieldRegion selection = fieldView.Selection;

			fieldView.Field.BeginUpdate();
			for (uint x = selection.Left; x <= selection.Right; x++) {
				for (uint y = selection.Bottom; y <= selection.Top; y++) {
					fieldView.Field.SetBlock(x, y, type);
				}
			}
			fieldView.Field.EndUpdate();
			//OnFieldSelectionChanged(fieldView, selection);
		}
	}

	protected void OnUpdatePreview(object o, EventArgs args) {
		FileChooser chooser = (FileChooser) o;
		FieldPreview preview = (FieldPreview) chooser.PreviewWidget;

		if (File.Exists(chooser.Filename)) {
			preview.Filename = chooser.Filename;
		} else {
			preview.Filename = null;
		} 
	}
}

} // namespace FieldEditor
