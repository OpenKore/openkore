MODULE = UnixUtils   PACKAGE = UnixUtils::ConsoleUI

void
start()
CODE:
	// Initialize singleton.
	ConsoleUI::getInstance()->start();

void
stop ()
CODE:
	ConsoleUI::getInstance()->stop();

SV *
getInput()
INIT:
	char *line;
CODE:
	line = ConsoleUI::getInstance()->getInput();
	if (line == NULL) {
		XSRETURN_UNDEF;
	} else {
		RETVAL = newSVpv(line, strlen(line));
		free(line);
	}
OUTPUT:
	RETVAL

void
print(msg)
	char *msg
CODE:
	ConsoleUI::getInstance()->print(msg);
