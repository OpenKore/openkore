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
#include <errno.h>
#include <netinet/in.h>

#include "dataserver.h"
#include "client.h"
#include "fileparsers.h"
#include "utils.h"
#include "threads.h"


#ifdef WIN32
	#include "tcp-server.h"
#else
	#include <sys/poll.h>
	#include <signal.h>
	#include <unistd.h>
	#include <sched.h>
	#include "unix-server.h"
#endif


/* Table files are stored in this array. */
#define NUM_HASH_FILES 7

static StringHash *hashFiles[NUM_HASH_FILES];


#define BUF_SIZE 512

struct _PrivateData {
	StringHashItem *iterators[NUM_HASH_FILES];

	char buf[BUF_SIZE];
	int buf_len;
};


static UnixServer *server;

Options options;


typedef struct {
	Mutex *lock;
	Thread *thread;
	Client *new_client;
	int quit;

	int ID;
	int nclients;
	LList *clients;
} ThreadData;

ThreadData *threads;


/* Client connections are handled like this:
 * The server has multiple client threads. Each client thread can handle multiple
 * clients. When a client connects, the main thread assigns the client to a client
 * thread. This way we have a constant number of threads.
 */


static int
send_reply (Client *client, const char *data)
{
	unsigned char status;
	int ret;

	/*
	 * struct {
	 *    unsigned char status;   // 0 = error, 1 = success
	 *    // The following fields are only sent if status != 0
	 *    uint16_t len;
	 *    char data[len];
	 * }
	 */

	if (data == NULL) {
		status = 0;
		ret = client_send (client, &status, 1);

	} else {
		uint16_t len, nlen;

		status = 1;
		len = strlen (data);
		nlen = htons (len);

		ret = client_send (client, &status, 1);
		if (ret)
			ret = client_send (client, &nlen, 2);
		if (ret)
			ret = client_send (client, data, len);
	}

	if (!ret) {
		DEBUG ("Cannot send data to client %p: %s\n", client, strerror (errno));
	}
	return ret;
}


/* Process data received from client. */
static int
process_data (ThreadData *thread_data, Client *client, unsigned char major, unsigned char minor, char *data, int size)
{
	PrivateData *priv = client->priv;

	switch (major) {
	case 0: {
		/* Major command 0: retrieve data from table files of StringHash type. */
		if (minor >= NUM_HASH_FILES) {
			/* Invalid file requested. */
			DEBUG ("Thread %d, client %p: invalid file requested: %d\n",
			       thread_data->ID, client, (int) minor);
			return 0;
		} else
			return send_reply (client, string_hash_get (hashFiles[(int) minor], data));

	}
	case 1: {
		StringHashItem *item;
		int fileIndex;

		/* Major command 255: special operations for StringHash table files. */
		if (minor < NUM_HASH_FILES) {
			/* Command: start iterating. */
			fileIndex = minor;

			/* Send the first key in the hash and go to the next iteration. */
			item = (StringHashItem *) hashFiles[fileIndex]->first;
			if (item == NULL)
				return send_reply (client, NULL);

			priv->iterators[fileIndex] = (StringHashItem *) ((LListItem *) item)->next;
			return send_reply (client, item->key);

		} else if (minor >= 127 && minor < 127 + NUM_HASH_FILES) {
			/* Command: iterate next. */
			fileIndex = minor - 127;

			/* Send the key in the current iteration and go to the next one. */
			item = priv->iterators[fileIndex];
			if (item == NULL)
				return send_reply (client, NULL);

			priv->iterators[fileIndex] = (StringHashItem *) ((LListItem *) item)->next;
			return send_reply (client, item->key);

		} else {
			/* Invalid command. */
			DEBUG ("Thread %d, client %p: invalid command for major 1: %d\n",
			       thread_data->ID, client, (int) minor);
			return 0;
		}

	}
	default:
		/* Client requested invalid major/minor number. */
		DEBUG ("Invalid major/minor number: %d/%d\n", (int) major, (int) minor);
		return 0;
	}
}


/* Process one client connection. */
static int
process_client (ThreadData *thread_data, Client *client, PrivateData *priv)
{
	int tmp, len;

	unsigned char major, minor;
	uint16_t size;
	char *data;

	/* Buffer is full. The client is trying to perform a request with a rediculously
	 * big name. It's probably misbehaving, so disconnect it. */
	if (priv->buf_len >= BUF_SIZE) {
		DEBUG ("Thread %d, client %p: buffer full; disconnecting client\n",
		       thread_data->ID, client);
		return 0;
	}

	/* Receive data from client. */
	len = client_recv (client, priv->buf + priv->buf_len, BUF_SIZE - priv->buf_len);
	if (len <= 0) {
		/* Client exited. */
		DEBUG ("Thread %d, client %p: client exited\n", thread_data->ID, client);
		return 0;
	}

	priv->buf_len += len;

	/* We expect the following packet:
	 * struct {
	 *     unsigned char major;
	 *     unsigned char minor;
	 *     uint16_t size;
	 *     char data[size];
	 * }
	 *
	 * major and minor specify which file's data the client is requesting.
	 */

	if (len < 4)
		/* Packet too small; continue receiving. */
		return 1;

	/* Get the 'major', 'minor' and 'size' fields and check whether we've received enough data. */
	major = priv->buf[0];
	minor = priv->buf[1];
	memcpy (&size, priv->buf + 2, 2);
	size = ntohs (size);
	if (len < 4 + size)
		return 1;

	/* Get the 'data' field. */
	data = malloc (size + 1);
	memcpy (data, priv->buf + 4, size);
	data[size] = 0;

	if (!process_data (thread_data, client, major, minor, data, size)) {
		free (data);
		return 0;
	}

	/* Remove this packet from the buffer. */
	tmp = priv->buf_len - size - 4;
	if (tmp > 0)
		memmove (priv->buf, priv->buf + size + 4, tmp);
	priv->buf_len -= size + 4;

	free (data);
	return 1;
}


static void
client_thread_callback (void *pointer)
{
	ThreadData *thread_data;
	struct pollfd *ufds;

	thread_data = (ThreadData *) pointer;
	ufds = NULL;

	while (1) {
		Client *client, *new_client = NULL;
		int i, free_ufds = 0;

		/* Check whether we've just been assigned a new client,
		 * or whether the server is shutting down. */
		LOCK (thread_data->lock);
		if (1 || TRYLOCK (thread_data->lock)) {
			if (thread_data->quit) {
				/* Server is shutting down. Free resources and exit thread. */
				UNLOCK (thread_data->lock);
				if (ufds != NULL)
					free (ufds);

				foreach_llist (thread_data->clients, client) {
//				for (client = (Client *) thread_data->clients->first; client != NULL; client = (Client *) client->parent.next) {
					free (client->priv);
					client_close (client);
				}

				llist_free (thread_data->clients);
				return;
			}

			if (thread_data->new_client) {
				new_client = thread_data->new_client;
				thread_data->new_client = NULL;
				thread_data->nclients++;
			}
			UNLOCK (thread_data->lock);
		}

		if (new_client) {
			/* We've been assigned a new client; add to client list. */
			new_client->priv = calloc (sizeof (PrivateData), 1);
			llist_append_existing (thread_data->clients, new_client);
			sched_yield ();
			free (ufds);
			ufds = NULL;

		}

		client = (Client *) thread_data->clients->first;

		if (client == NULL) {
			/* We have no clients so just sleep. */
			usleep (10000);
			continue;
		}


		/* Generate a list of client file descriptors, which we pass to poll() */
		if (ufds == NULL)
			ufds = malloc (sizeof (struct pollfd) * thread_data->nclients);

		for (i = 0; client != NULL; client = (Client *) client->parent.next, i++) {
			ufds[i].fd = client->fd;
			ufds[i].events = POLLIN | POLLERR | POLLHUP;
		}
		i = poll (ufds, thread_data->nclients, 10);
		if (i == -1) {
			/* An error occured. */
			error ("poll() failed: %s\n", strerror (errno));
			exit (1);

		} else if (i == 0)
			/* Timeout; no clients have data pending. */
			continue;


		/* Iterate through clients that have incoming data pending. */
		client = (Client *) thread_data->clients->first;
		i = 0;

		while (client != NULL) {
			Client *current;
			int failed = 0;

			current = client;
			client = (Client *) client->parent.next;

			if (ufds[i].revents & POLLIN)
				failed = !process_client (thread_data, current, current->priv);
			else if (ufds[i].revents & POLLERR || ufds[i].revents & POLLHUP)
				failed = 1;
			else {
				i++;
				continue;
			}

			if (failed) {
				/* Remove client. */
				DEBUG ("Thread %d, client %p: removing client from list\n", thread_data->ID, current);
				free (current->priv);
				client_close (current);
				llist_remove (thread_data->clients, (LListItem *) current);

				LOCK (thread_data->lock);
				thread_data->nclients--;
				UNLOCK (thread_data->lock);

				free_ufds = 1;
			}
			i++;
		}

		if (free_ufds) {
			free (ufds);
			ufds = NULL;
		}

		sched_yield();
	}
}


/* New client connected. */
static void
on_new_client (Client *client)
{
	int i, smallest, found;

	/* Assign this client to the thread with the least clients. */
	smallest = 0;
	found = -1;

	for (i = 0; i < options.threads; i++) {
		int nclients;

		LOCK (threads[i].lock);
		nclients = threads[i].nclients;
		UNLOCK (threads[i].lock);

		if (nclients == 0) {
			found = i;
			break;

		} else if (found == -1 || nclients < smallest) {
			found = i;
			smallest = nclients;
		}
	}

	DEBUG ("New client %p; assign to thread %d\n", client, found);
	LOCK (threads[found].lock);
	threads[found].new_client = client;
	UNLOCK (threads[found].lock);
	sched_yield ();
}



/***********************************************/


static void
unix_stop ()
{
	server->stop = 1;
}


static int
unix_start ()
{
	int i;

	/* Setup signal handlers for clean exiting. */
	signal (SIGINT,  unix_stop);
	signal (SIGQUIT, unix_stop);
	signal (SIGTERM, unix_stop);
	signal (SIGHUP,  unix_stop);

	/* Start server and run until we've caught a signal. */
	server = unix_server_new (strdup ("/tmp/kore-dataserver.socket"), on_new_client);
	if (server == NULL)
		return 1;

	message ("Server ready.\n");
	unix_server_main_loop (server);

	/* Main loop exited; tell all threads to quit. */
	for (i = 0; i < options.threads; i++) {
		LOCK (threads[i].lock);
		threads[i].quit = 1;
		UNLOCK (threads[i].lock);
	}

	return unix_server_free (server);
}


static void
usage (int retval)
{
	#define USAGE "Usage: dataserver [ARGS]\n\n" \
			"  --tables DIR     Specify the tables folder. Default: working directory\n" \
			"  --threads NUM    Specify the number of threads for handling client\n" \
			"                   connections. (default: 5)\n"		\
			"  --silent         Don't output any messages unless absolutely necessary.\n" \
			"  --debug          Enable debugging messages.\n"
	printf ("%s", USAGE);
	exit (retval);
}


static StringHash *
load_hash_file (const char *basename, StringHash * (*loader) (const char *filename))
{
	char file[PATH_MAX];
	StringHash *hash;

	snprintf (file, sizeof (file), "%s/%s", options.tables, basename);
	message ("Loading %s...\n", file);
	hash = loader (file);
	if (hash == NULL) {
		error ("Error: cannot load %s\n", file);
		error ("If your table files are somewhere else, then use the --tables parameter.\n");
		exit (1);
	}
	return hash;
}


int
main (int argc, char *argv[])
{
	int i, ret;

	/* Check whether there's already a server running. */
	ret = unix_server_trylock ();
	if (ret == -1)
		/* Error. */
		return 1;
	else if (ret == 0) {
		/* Yes. */
		error ("Server already running.\n");
		return 2;
	}

	/* Parse arguments. */
	memset (&options, 0, sizeof (options));
	options.tables = ".";
	options.threads = 5;

	for (i = 1; i < argc; i++) {
		if (strcmp (argv[i], "--help") == 0) {
			usage (0);

		} else if (strcmp (argv[i], "--tables") == 0) {
			if (argv[i + 1] == NULL) {
				error ("--tables requires a directory name.\n");
				usage (1);
			}
			options.tables = argv[i + 1];
			i++;

		} else if (strcmp (argv[i], "--threads") == 0) {
			if (argv[i + 1] == NULL) {
				error ("--threads requires a number.\n");
				usage (1);
			}
			options.threads = atoi (argv[i + 1]);
			if (options.threads <= 0) {
				error ("The number of threads must be bigger than 0.\n");
				usage (1);
			}
			i++;

		} else if (strcmp (argv[i], "--silent") == 0) {
			options.silent = 1;

		} else if (strcmp (argv[i], "--debug") == 0) {
			options.debug = 1;

		} else {
			error ("Unknown parameter: %s\n", argv[i]);
			usage (1);
		}
	}

	/* Load data files. */
	hashFiles[0] = load_hash_file ("itemsdescriptions.txt",  desc_info_load);
	hashFiles[1] = load_hash_file ("skillsdescriptions.txt", desc_info_load);
        hashFiles[2] = load_hash_file ("cities.txt",             rolut_load);
	hashFiles[3] = load_hash_file ("elements.txt",           rolut_load);
	hashFiles[4] = load_hash_file ("items.txt",              rolut_load);
	hashFiles[5] = load_hash_file ("itemslotcounttable.txt", rolut_load);
	hashFiles[6] = load_hash_file ("maps.txt",               rolut_load);

	/* Initialize threads for handling client connections. */
	threads = malloc (options.threads * sizeof (ThreadData));
	for (i = 0; i < options.threads; i++) {
		threads[i].lock = mutex_new ();
		threads[i].ID = i;
		threads[i].new_client = NULL;
		threads[i].quit = 0;
		threads[i].nclients = 0;
		threads[i].clients = llist_new (sizeof (Client));

		threads[i].thread = thread_new (client_thread_callback, &(threads[i]), 0);
		if (!threads[i].thread) {
			error ("Unable to create a thread.\n");
			return 1;
		}
	}

	/* Initialize server and main loop. */
	ret = unix_start ();

	/* Free resources. */
	for (i = 0; i < options.threads; i++) {
		thread_join (threads[i].thread);
		mutex_free (threads[i].lock);
	}
	free (threads);

	for (i = 0; i < NUM_HASH_FILES; i++)
		string_hash_free (hashFiles[i]);

	return ret;
}
