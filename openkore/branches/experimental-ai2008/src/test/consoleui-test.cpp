#include "consoleui.h"
#include <stdio.h>
#include <unistd.h>
#include <stdarg.h>
#include <time.h>
#include <string.h>

static ConsoleUI *ui = NULL;

static void
usage() {
	fprintf(stderr, "Usage: consoleui-test <-c|-p>\n"
		"  -c  Test for correctness.\n"
		"  -p  Test for performance.\n");
	exit(1);
}

static void
show(const char *format, ...) {
	va_list ap;
	char buf[1024 * 4];

	va_start(ap, format);
	vsnprintf(buf, sizeof(buf) - 1, format, ap);
	va_end(ap);
	ui->print(buf);
}

/*
static void
doNothing(unsigned int maxIterations) {
	FILE *f = fopen("/dev/urandom", "r");
	if (f == NULL) {
		show("Cannot open /dev/urandom for reading.\n");
		exit(1);
	}

	unsigned int i = 0;
	while (i < maxIterations && !feof(f)) {
		fgetc(f);
		i++;
	}
	fclose(f);
}
*/

static int
testCorrectness() {
	ui = ConsoleUI::getInstance();
	ui->start();
	srand(time(NULL));

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

static int
testPerformance() {
	ui = ConsoleUI::getInstance();
	ui->start();

	for (int i = 1; i <= 5000000; i++) {
		show("Loading %d...\n", i);
	}
	return 0;
}

int
main(int argc, char *argv[]) {
	if (argc != 2) {
		usage();
	}

	if (strcmp(argv[1], "-c") == 0) {
		return testCorrectness();
	} else if (strcmp(argv[1], "-p") == 0) {
		return testPerformance();
	} else {
		usage();
		return 1; // Never reached.
	}
}

