/*  Kore Shared Data Server
 *  Copyright (C) 2005  Hongli Lai <hongli AT navi DOT cx>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

#include "dataserver.h"
#include "client.h"
#include "fileparsers.h"

#ifdef WIN32
	#include "tcp-server.h"
#else
	#include <signal.h>
	#include "unix-server.h"
#endif


StringHash *itemsDesc, *skillsDesc;
StringHash *cities, *elements, *items, *itemSlotCount, *maps;


static UnixServer *server;

static struct {
	char *tables;
} options;


static int
send_reply (Client *client, const char *msg)
{
	uint16_t len, nlen;

	if (msg == NULL) {
		len = 0;
		return (send (client->fd, &len, 2, MSG_NOSIGNAL) != -1);

	} else {
		len = strlen (msg);
		nlen = htons (len);

		if (send (client->fd, &nlen, 2, MSG_NOSIGNAL) == -1)
			return 0;
		return (send (client->fd, msg, len, MSG_NOSIGNAL) != -1);
	}
}


/* Process data received from client. */
static int
process (Client *client, char major, char minor, char *data, int size)
{
	StringHash *hash = NULL;

	switch (major) {
	case 0:
		if (minor == 0)
			/* itemsdescriptions.txt */
			hash = itemsDesc;
		else if (minor == 1)
			/* skillsdescriptions.txt */
			hash = skillsDesc;
		else
			return 0;
		return send_reply (client, string_hash_get (hash, data));

	case 1:
		if (minor == 0)
			/* cities.txt */
			hash = cities;
		else if (minor == 1)
			/* elements.txt */
			hash = elements;
		else if (minor == 2)
			/* items.txt */
			hash = items;
		else if (minor == 3)
			/* itemslotcounttable.txt */
			hash = itemSlotCount;
		else if (minor == 4)
			/* maps.txt */
			hash = maps;
		else
			return 0;
		return send_reply (client, string_hash_get (hash, data));

	default:
		/* Client requested invalid major/minor number. */
		return 0;
	}
}


/* Process client connections. */
static void
client_callback (Client *client)
{
	const int buf_size = 512;
	char buf[buf_size];
	int buf_len, tmp;
	ssize_t len;

	char major, minor;
	uint16_t size;
	char *data;

	buf_len = 0;
	while (1) {
		/* Buffer is full. The client is trying to perform a request with a rediculously
		 * big name. It's probably misbehaving, so disconnect it. */
		if (buf_len >= buf_size)
			return;

		/* Receive data from client. */
		len = recv (client->fd, buf + buf_len, buf_size - buf_len, MSG_NOSIGNAL);
		if (len <= 0)
			/* Client exited. */
			return;

		buf_len += len;

		/* We expect the following packet:
		 * struct {
		 *     char major;
		 *     char minor;
		 *     uint16_t size;
		 *     char data[size];
		 * }
		 *
		 * major and minor specify which file's data the client is requesting.
		 */

		if (len < 4)
			/* Packet too small; continue receiving. */
			continue;

		/* Get the 'major', 'minor' and 'size' fields and check whether we've received enough data. */
		major = buf[0];
		minor = buf[1];
		memcpy (&size, buf + 2, 2);
		size = ntohs (size);
		if (len < 4 + size)
			continue;

		/* Get the 'data' field. */
		data = malloc (size + 1);
		memcpy (data, buf + 4, size);
		data[size] = 0;

		if (!process (client, major, minor, data, size)) {
			free (data);
			return;
		}

		/* Remove this packet from the buffer. */
		tmp = buf_len - size - 4;
		if (tmp > 0)
			memmove (buf, buf + size + 4, tmp);
		buf_len -= size + 4;

		free (data);
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

	printf ("Server ready.\n");
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


static StringHash *
load_hash_file (const char *basename, StringHash * (*loader) (const char *filename))
{
	char file[PATH_MAX];
	StringHash *hash;

	snprintf (file, sizeof (file), "%s/%s", options.tables, basename);
	printf ("Loading %s...\n", file);
	hash = loader (file);
	if (hash == NULL) {
		fprintf (stderr, "Error: cannot load %s\n", file);
		exit (1);
	}
	return hash;
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
	itemsDesc  = load_hash_file ("itemsdescriptions.txt",  desc_info_load);
	skillsDesc = load_hash_file ("skillsdescriptions.txt", desc_info_load);
	cities        = load_hash_file ("cities.txt",             rolut_load);
	elements      = load_hash_file ("elements.txt",           rolut_load);
	items         = load_hash_file ("items.txt",              rolut_load);
	itemSlotCount = load_hash_file ("itemslotcounttable.txt", rolut_load);
	maps          = load_hash_file ("maps.txt",               rolut_load);

	/* Initialize server and main loop. */
	i = unix_start ();

	/* Free resources. */
	string_hash_free (itemsDesc);
	string_hash_free (skillsDesc);
	return i;
}
