#ifndef _SERVER_H_
#define _SERVER_H_

typedef struct _Client Client;

struct _Client {
	int fd;
};

typedef void (*NewClientCallback) (Client *client);

#endif /* _SERVER_H_ */
