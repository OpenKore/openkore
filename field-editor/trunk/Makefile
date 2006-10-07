PKGS=-pkg:gtk-sharp-2.0,glade-sharp-2.0
RESOURCES=-resource:glade/MainWindow.glade,glade/OpenDialog.glade,glade/SaveDialog.glade,glade/AboutBox.glade
FLAGS=-target:winexe -optimize $(RESOURCES)
OUTPUT=bin/Release/FieldEditor.exe
SOURCES=*.cs

.PHONY: clean

$(OUTPUT): $(SOURCES) glade/*.glade
	mcs $(PKGS) $(SOURCES) -out:$(OUTPUT) $(FLAGS)

clean:
	rm -f $(OUTPUT)
