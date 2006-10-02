PKGS=-pkg:gtk-sharp-2.0,glade-sharp-2.0
FLAGS=-target:winexe -optimize
OUTPUT=bin/Release/FieldEditor.exe
SOURCES=*.cs

.PHONY: clean

$(OUTPUT): $(SOURCES)
	mcs $(PKGS) $(SOURCES) -out:$(OUTPUT) $(FLAGS)

clean:
	rm -f $(OUTPUT)
