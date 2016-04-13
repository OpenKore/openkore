#ifndef _PROCESSING_H_
#define _PROCESSING_H_

#include "dataserver.h"
#include "client.h"

int process_client (ThreadData *thread_data, Client *client, PrivateData *priv);

#endif /* _PROCESSING_H_ */
