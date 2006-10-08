PKGS=-pkg:gtk-sharp-2.0,glade-sharp-2.0
RESOURCES=-resource:FieldEditor/glade/MainWindow.glade \
	-resource:FieldEditor/glade/OpenDialog.glade \
	-resource:FieldEditor/glade/SaveDialog.glade \
	-resource:FieldEditor/glade/AboutBox.glade
FLAGS=-target:winexe -optimize $(RESOURCES)
OUTPUT=bin/Release/FieldEditor.exe
SOURCES=FieldEditor/*.cs FieldEditor/Models/*.cs FieldEditor/UI/*.cs FieldEditor/SharpZipLib/*.cs

.PHONY: clean

$(OUTPUT): $(SOURCES) FieldEditor/glade/*.glade
	mcs $(PKGS) $(SOURCES) -out:$(OUTPUT) $(FLAGS)

clean:
	rm -f $(OUTPUT)
