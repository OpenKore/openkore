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

	for (int i = 1; i <= 5; i++) {
		show("Loading %d...\n", i);
		usleep(rand() % 200000);
	}

	show("Checking for new portals...");
	sleep(1);
	show(" none found.\n");

	show("\e[1;31mThis is a test error.");
	sleep(2);
	show("\e[1;31m This is another test error.\n");
	sleep(2);
	show("\e[1;32mThis is a green message.\n");
	show("\e[0mThis is a message with normal color.\n");
	show("\e[1;32mThis is a green message.\n");

	bool quit = false;
	while (!quit) {
		char *input = ui->getInput();
		if (input != NULL) {
			if (strcmp(input, "quit") == 0) {
				quit = true;
			} else if (strlen(input) > 0) {
				show("Unknown command '%s'\n", input);
			}
			free(input);
		} else {
			usleep(50000);
		}
	}
	return 0;
}
