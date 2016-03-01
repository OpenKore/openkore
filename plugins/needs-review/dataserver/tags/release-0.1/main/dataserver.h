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

#ifndef _DATASERVER_H_
#define _DATASERVER_H_

#include "client.h"
#include "string-hash.h"
#include "threads.h"


#define NUM_HASH_FILES 7
#define CLIENT_BUF_SIZE 512


typedef struct {
	char *tables;
	int silent;
	int debug;
	int threads;
} Options;


struct _PrivateData {
	StringHashItem *iterators[NUM_HASH_FILES];

	char buf[CLIENT_BUF_SIZE];
	int buf_len;
};


typedef struct {
	Mutex *lock;
	Thread *thread;
	Client *new_client;
	int quit;

	int ID;
	int nclients;
	LList *clients;
} ThreadData;


extern Options options;
extern StringHash *hashFiles[NUM_HASH_FILES];


#endif /* _DATASERVER_H_ */
