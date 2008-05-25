/**
 * OpenKore - Harmony packet enryption
 * Copyright (C) 2008 darkfate
 
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3 of the License, or (at your option) any later
 * version.

 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.

 * You should have received a copy of the GNU General Public License along with
 * this program; if not, see <http://www.gnu.org/licenses/>.
 */

#include <stdlib.h>
#include <string.h>
#include <windows.h>

#include "blowfish.h"
#include "harmony.h"

unsigned long
create_packet(unsigned char *dst, unsigned char *src, unsigned long len)
{
	int i;
	int tmp;
	unsigned long tmp_tick_count;
	unsigned long size;	
	
	unsigned char *buf;
	unsigned char *buf_head;
	unsigned char *buf_rand;
	unsigned short *buf_len;
	unsigned char *buf_body;
	
	buf = malloc(0x40000);
	buf_head = buf;
	buf_rand = buf + 1;
	buf_len = (void *)buf + 6;
	buf_body = buf + 8;
	
	*buf = (8 * (packet_count % 8 & 7)) | (*buf & 199);
	tmp = rand();
	tmp &= 0x80000003;

	if ( tmp < 0 )
		tmp = ((tmp - 1) | 0xFFFFFFFC) + 1;
		
	*buf = tmp & 3 | (*buf & 0xFC);
	
	if ( len % 4 )
		tmp = 4 - len % 4;
	else
		tmp = 0;
		
	*buf = ((tmp & 3) << 6) | *buf & 0x3F;
	
	tmp_tick_count = GetTickCount();
	srand(tmp_tick_count);
	
	tmp = rand() & 0x800000FF;
	if ( tmp < 0 )
		tmp = ((tmp - 1) | 0xFFFFFF00) + 1;
		
	*buf_rand = (*src ^ 0x36) ^ tmp;
	
	tmp = *buf & 3;

	if ( tmp <= 3 ) {
		switch ( tmp ) {
			case 0:
				modify_bf_key(*buf_rand);
				break;
			case 1:
				modify_bf_key(*buf_rand);
				break;
			case 2:
				modify_bf_key(*buf_rand ^ 0x2D);
				break;
			case 3:
				modify_bf_key(*buf >> 4) | (16 * *buf_rand);
				break;
		}
	}
	
	*buf = (4 * (bf_key_switch & 1)) | (*buf & 0xFB);
	*((int *)(buf_rand + 1)) = packet_count;
	*buf_len = len + ((*buf >> 6) & 3) + 12;

	bf_encipher(
		src,
		buf_body,
		len + ((*buf >> 6) & 3) + 4,
		&bf_key[256 * bf_key_switch],
		256
	);
	
	size = *buf_len;
	bf_encipher(buf_head, buf_head, 8, bf_hard_key, 256);
	
	memcpy(dst, buf, size);
	packet_count++;
	free(buf);
	return size;
}

unsigned long
create_key(unsigned char *dst)
{
	unsigned long tmp_tick_count;
	
	int i;
	int tmp;
	int tmp_rand;
	
	unsigned char *key;
	unsigned long *key_rand_1;
	unsigned char *key_cipher;
	unsigned short *key_rand_2;
	unsigned long *key_rand_3;
	unsigned short *key_rand_4;
	
	unsigned char key_cpy[13];

	key = malloc(13);
	key_rand_1 = (void *)key + 1;
	key_cipher = key + 5;
	key_rand_2 = (void *)key + 5;
	key_rand_3 = (void *)key + 7;
	key_rand_4 = (void *)key + 11;

	tmp_tick_count = GetTickCount();
	srand(tmp_tick_count);
	tmp_rand = rand() + 78319;

	switch_bf_key();
	
	tmp = tmp_rand;
	init_bf_key(tmp);
	
	switch_bf_key();
	
	*key = 0x89;
	*key_rand_1 = tmp;

	tmp_tick_count = GetTickCount();
	tmp = rand();
	srand(tmp ^ tmp_tick_count);
	tmp_rand = rand() + 42564;

	*key_rand_2 = (rand() >> 5) | (8 * (tmp_rand >> 3));

	srand(tmp_rand);
	tmp_rand = rand();
	*key_rand_3 = tmp_rand;

	srand(8 * *(key + 1));
	*key_rand_4 = rand();

	bf_encipher(key_cipher, &key_cpy[5], 8, bf_key, 256);
	memcpy(key_cpy, key, 5);

	switch_bf_key();

	for ( i = 0; i < 56; i++ )
	{	
		tmp = (*(key_cipher + i / 8 + 1) >> (8 - i % 8)) | (*(key_cipher + i / 8) << i % 8);
		modify_bf_key(tmp);
	}

	switch_bf_key();
	memcpy(dst, key_cpy, 13);
	free(key);
	return 13;
}

bool
switch_bf_key(void)
{
	bf_key_switch = bf_key_switch == 0;
	return bf_key_switch;
}

int
init_bf_key(int rand)
{
	int result;
	int i;
	int k;
	int tmp;
	bool b;
	
	result = rand % 4;
	k = rand % 4;
	
	b = bf_key_switch == 0;

	for ( i = 0; i < 256; i++ ) {
		result = k;
		tmp = k;
		if ( k <= 3 ) {
			switch ( tmp ) {
				case 0:
					bf_key[256 * b + i] += rand;
					result = k++ + 1;
					break;
				case 1:
					result =  bf_key[256 * b + i]- rand;
					bf_key[256 * b + i] -= rand;
					k++;
					break;
				case 2:
					result = i;
					bf_key[256 * b + i] += rand;
					k++;
					break;
				case 3:
					result = b << 8;
					bf_key[256 * b + i] -= rand;
					k = 0;
					break;
			}
		}
	}
	return result;
}

int
modify_bf_key(unsigned char seed)
{
	int result;
	bool b;
	
	b = bf_key_switch == 0;
	
	bf_key[256 * b + keymod_count] ^= seed;
	
	keymod_count++;
	result = keymod_count;
	
	if ( keymod_count == 255 ) {
		keymod_count = 0;
		result = switch_bf_key();
	}
	
	return result;
}

void
on_connect(void)
{	
	packet_count = 0;
	bf_key_switch = 0;
	keymod_count = 0;
	
	memcpy(&bf_key, &bf_hard_key, 256);
	memcpy(&bf_key[256], &bf_hard_key, 256);
}


int
bf_encipher(unsigned char *input, unsigned char *output, int len, unsigned char *key, int key_len)
{
	BLOWFISH_CTX ctx;
	unsigned long xl, xr;
	unsigned long size;
	int i;
	int k;
	
	if ( !(input && output && key) )
		return -1;
	
	Blowfish_Init(&ctx, key, key_len);
	
	i = 0;
	k = 0;
	while ( i < len ) {
		size = 4;
		
		if (len - i < 4)
			size = len - i;
			
		memcpy(&xl, input+i, size);
		i += 4;
		size = 4;
		
		if ( len - i < 4 )
			size = len - i;
			
		memcpy(&xr, input+i, size);
		i += 4;
		
		Blowfish_Encrypt(&ctx, &xl, &xr);
		
		memcpy(output+k, &xl, 4);
		k += 4;
		memcpy(output+k, &xr, 4);
		k += 4;
	}
	return 0;
}
