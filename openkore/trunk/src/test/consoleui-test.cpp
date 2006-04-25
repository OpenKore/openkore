#include "consoleui.h"
#include <stdio.h>
#include <unistd.h>
#include <stdarg.h>
#include <time.h>
#include <string.h>

static ConsoleUI *ui = NULL;

static void
show(const char *format, ...) {
	va_list ap;
	char buf[1024 * 4];

	va_start(ap, format);
	vsnprintf(buf, sizeof(buf) - 1, format, ap);
	va_end(ap);
	ui->print(buf);
}

int
main() {
	srand(time(NULL));
	ui = ConsoleUI::getInstance();
	ui->start();

	for (int i = 1; i <= 30; i++) {
		show("Loading %d...\n", i);
		usleep(rand() % 200000);
	}

	show("Checking for new portals...");
	sleep(3);
	show(" none found.\n");

	bool quit = false;
	while (!quit) {
		char *input = ui->getInput();
		if (input != NULL) {
			if (strcmp(input, "quit") == 0) {
				quit = true;
			} else {
				show("Unknown command '%s'\n", input);
			}
			free(input);
		} else {
			usleep(50000);
		}
	}
	return 0;
}
