#include "remote.h"
#include "messages.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wz/socket.h>
#include <wz/buffered-output-stream.h>

using namespace Wz;

static Socket *socket = NULL;
static OutputStream *output = NULL;

static void
hook(const char *message) {
	try {
		output->write(message, strlen(message));
	} catch (IOException &e) {
		exit(1);
	}
}

char *
remote_control_init(const char *address, unsigned int port) {
	try {
		socket = Socket::create(wxString::FromAscii(address), port);
		output = new BufferedOutputStream(socket->getOutputStream(), 1024 * 32);
		o_message_set_hook(hook);
		return NULL;
	} catch (Exception &e) {
		return strdup(e.getMessage().ToAscii());
	}
}

void
remote_control_end() {
	output->unref();
	socket->unref();
}
