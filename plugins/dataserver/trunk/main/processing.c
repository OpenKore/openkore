#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "processing.h"
#include "dataserver.h"
#include "utils.h"


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


/* Process packet contents. */
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


/*
 * This function processes one client connection.
 * It unserializes packets and takes care of input data buffering.
 */
int
process_client (ThreadData *thread_data, Client *client, PrivateData *priv)
{
	int tmp, len;

	unsigned char major, minor;
	uint16_t size;
	char *data;

	/* Buffer is full. The client is trying to perform a request with a rediculously
	 * big name. It's probably misbehaving, so disconnect it. */
	if (priv->buf_len >= CLIENT_BUF_SIZE) {
		DEBUG ("Thread %d, client %p: buffer full; disconnecting client\n",
		       thread_data->ID, client);
		return 0;
	}

	/* Receive data from client. */
	len = client_recv (client, priv->buf + priv->buf_len, CLIENT_BUF_SIZE - priv->buf_len);
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

	/* Process the packet's content. */
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
