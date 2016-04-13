#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

#include "dataserver.h"
#include "client.h"
#include "descriptions.h"

#ifdef WIN32
	#include "tcp-server.h"
#else
	#include <signal.h>
	#include "unix-server.h"
#endif


DescInfo *itemsDesc;
DescInfo *skillsDesc;

static UnixServer *server;

static struct {
	char *tables;
} options;


static inline int
send_reply (Client *client, const char *msg)
{
	uint16_t len, nlen;

	if (msg == NULL) {
		len = 0;
		return (send (client->fd, &len, 2, 0) != -1);

	} else {
		len = strlen (msg);
		nlen = htons (len);

		if (send (client->fd, &nlen, 2, 0) == -1)
			return 0;
		return (send (client->fd, msg, len, 0) != -1);
	}
}


/* Process data received from a client. */
static void
client_callback (Client *client)
{
	const int buf_size = 512;
	char buf[buf_size];
	int buf_len, tmp;
	ssize_t len;

	char type;
	uint16_t size;
	char *name;

	buf_len = 0;

	while (1) {
		/* Buffer is full. The client is trying to perform a request with a rediculously
		 * big name. It's probably misbehaving, so disconnect it. */
		if (buf_len >= buf_size)
			return;

		/* Receive data from client. */
		len = recv (client->fd, buf + buf_len, buf_size - buf_len, 0);
		if (len <= 0)
			/* Client exited. */
			return;

		buf_len += len;

		/* We expect the following packet:
		 * struct {
		 *     char type;
		 *     uint16_t size;
		 *     char name[size];
		 * }
		 */

		if (len < 4)
			/* Packet too small; continue receiving. */
			continue;

		/* Get the 'type' and 'size' fields and check whether we've received enough data. */
		type = buf[0];
		memcpy (&size, buf + 1, 2);
		size = ntohs (size);
//		size = ntohs (*((uint16_t *) (buf + 1)));
		if (len < 3 + size)
			continue;

		/* Get the 'name' field. */
		name = malloc (size + 1);
		memcpy (name, buf + 3, size);
		name[size] = 0;

		/* Send an appropriate reply. */
		switch (type) {
		case 0: case 1: {
			/* itemsdescriptions.txt/skillsdescriptions.txt */
			DescInfo *info;

			info = (type == 0) ? itemsDesc : skillsDesc;
			if (!send_reply (client, desc_info_lookup (info, name)))
				return;
			break;
		}

		default: /* ????? */
			break;
		};

		/* Remove this packet from the buffer. */
		tmp = buf_len - size - 3;
		if (tmp > 0)
			memmove (buf, buf + size + 3, tmp);
		buf_len -= size + 3;

		free (name);
	}
}


static void
unix_stop ()
{
	server->stop = 1;
}


static int
unix_start ()
{
	int ret;

	/* Check whether there's already a server running. */
	ret = unix_server_trylock ();
	if (ret == -1)
		/* Error. */
		return 1;
	else if (ret == 0) {
		/* Yes. */
		fprintf (stderr, "Server already running.\n");
		return 2;
	}

	/* Setup signal handlers for clean exiting. */
	signal (SIGINT,  unix_stop);
	signal (SIGQUIT, unix_stop);
	signal (SIGTERM, unix_stop);
	signal (SIGHUP,  unix_stop);

	/* Start server and run until we've caught a signal. */
	server = unix_server_new (strdup ("/tmp/kore-dataserver.socket"), client_callback);
	if (server == NULL)
		return 1;
	unix_server_main_loop (server);
	return unix_server_free (server);
}


static void
usage (int retval)
{
	printf ("Usage: dataserver [ARGS]\n\n");
	printf ("  --tables DIR     Specify the tables folder. Default: working directory\n");
	exit (retval);
}


static void
load_data_files ()
{
	char file[PATH_MAX];
	#define CHECK(var) do {	\
			if (var == NULL) {				\
				fprintf (stderr, "Error: cannot load %s\n", file); \
				exit (1); \
			} \
		} while (0)

	snprintf (file, sizeof (file), "%s/itemsdescriptions.txt", options.tables);
	itemsDesc = desc_info_load (file);
	CHECK(itemsDesc);

	snprintf (file, sizeof (file), "%s/skillsdescriptions.txt", options.tables);
	skillsDesc = desc_info_load (file);
	CHECK(skillsDesc);
}


int
main (int argc, char *argv[])
{
	int i;

	/* Parse arguments. */
	options.tables = ".";
	for (i = 1; i < argc; i++) {
		if (strcmp (argv[i], "--help") == 0)
			usage (0);

		else if (strcmp (argv[i], "--tables") == 0) {
			if (argv[i + 1] == NULL) {
				fprintf (stderr, "--tables requires a directory name.\n");
				usage (1);
			}
			options.tables = argv[i + 1];
			i++;

		} else {
			fprintf (stderr, "Unknown parameter: %s\n", argv[i]);
			usage (1);
		}
	}

	/* Load data files. */
	load_data_files ();

	/* Initialize server and main loop. */
	return unix_start ();
}
