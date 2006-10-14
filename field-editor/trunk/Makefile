PKGS=-pkg:gtk-sharp-2.0,glade-sharp-2.0
RESOURCES=-resource:FieldEditor/glade/MainWindow.glade \
	-resource:FieldEditor/glade/OpenDialog.glade \
	-resource:FieldEditor/glade/SaveDialog.glade \
	-resource:FieldEditor/glade/AboutBox.glade
FLAGS=-target:winexe -optimize
OUTPUT=bin/Release/FieldEditor.exe
SOURCES=FieldEditor/*.cs FieldEditor/Models/*.cs FieldEditor/UI/*.cs FieldEditor/SharpZipLib/*.cs
OUTPUT2=bin/Release/GtkSharpCheck.exe
SOURCES2=GtkSharpCheck/*.cs

.PHONY: all clean

all: $(OUTPUT) $(OUTPUT2)

$(OUTPUT): $(SOURCES) FieldEditor/glade/*.glade
	mcs $(PKGS) $(SOURCES) -out:$(OUTPUT) $(FLAGS) $(RESOURCES)

$(OUTPUT2): $(SOURCES2)
	mcs $(SOURCES2) -out:$(OUTPUT2) $(FLAGS)

clean:
	rm -f $(OUTPUT) $(OUTPUT2)
