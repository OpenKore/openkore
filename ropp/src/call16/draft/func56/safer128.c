/*******************************************************************************
*
* FILE:           safer.c
*
* DESCRIPTION:    block-cipher algorithm SAFER (Secure And Fast Encryption
*                 Routine) in its four versions: SAFER K-64, SAFER K-128,
*                 SAFER SK-64 and SAFER SK-128.
*
* AUTHOR:         Richard De Moliner (demoliner@isi.ee.ethz.ch)
*                 Signal and Information Processing Laboratory
*                 Swiss Federal Institute of Technology
*                 CH-8092 Zuerich, Switzerland
*
* DATE:           September 9, 1995
*
* CHANGE HISTORY:
*
*******************************************************************************/

/* modified in order to use the libmcrypt API by Nikos Mavroyanopoulos 
 * All modifications are placed under the license of libmcrypt.
 */


/* $Id: safer128.c,v 1.12 2003/01/19 17:48:27 nmav Exp $ */

/******************* External Headers *****************************************/

/******************* Local Headers ********************************************/
#include <libdefs.h>

#include <mcrypt_modules.h>
#include "safer.h"

#define _mcrypt_set_key safer_sk128_LTX__mcrypt_set_key
#define _mcrypt_encrypt safer_sk128_LTX__mcrypt_encrypt
#define _mcrypt_decrypt safer_sk128_LTX__mcrypt_decrypt
#define _mcrypt_get_size safer_sk128_LTX__mcrypt_get_size
#define _mcrypt_get_block_size safer_sk128_LTX__mcrypt_get_block_size
#define _is_block_algorithm safer_sk128_LTX__is_block_algorithm
#define _mcrypt_get_key_size safer_sk128_LTX__mcrypt_get_key_size
#define _mcrypt_get_supported_key_sizes safer_sk128_LTX__mcrypt_get_supported_key_sizes
#define _mcrypt_get_algorithms_name safer_sk128_LTX__mcrypt_get_algorithms_name
#define _mcrypt_self_test safer_sk128_LTX__mcrypt_self_test
#define _mcrypt_algorithm_version safer_sk128_LTX__mcrypt_algorithm_version

/******************* Constants ************************************************/
#define TAB_LEN      256
static int _safer128_init = 0;
/******************* Assertions ***********************************************/

/******************* Macros ***************************************************/
#define ROL(x, n)    ((unsigned char)((unsigned int)(x) << (n)\
                                     |(unsigned int)((x) & 0xFF) >> (8 - (n))))
#define EXP(x)       exp_tab128[(x) & 0xFF]
#define LOG(x)       log_tab128[(x) & 0xFF]
#define PHT(x, y)    { y += x; x += y; }
#define IPHT(x, y)   { x -= y; y -= x; }

/******************* Types ****************************************************/
static unsigned char exp_tab128[TAB_LEN];
static unsigned char log_tab128[TAB_LEN];

/******************* Module Data **********************************************/

/******************* Functions ************************************************/

/******************************************************************************/

static void _mcrypt_Safer_Init_Module(void)
{
	unsigned int i, exp;

	exp = 1;
	for (i = 0; i < TAB_LEN; i++) {
		exp_tab128[i] = (unsigned char) (exp & 0xFF);
		log_tab128[exp_tab128[i]] = (unsigned char) i;
		exp = exp * 45 % 257;
	}
}				/* Safer_Init_Module */

/******************************************************************************/

WIN32DLL_DEFINE
    int _mcrypt_set_key(safer_key_t * key, safer_block_t * userkey,
			int len)
{
	unsigned int i, j;
	unsigned char ka[SAFER_BLOCK_LEN + 1];
	unsigned char kb[SAFER_BLOCK_LEN + 1];
	int nof_rounds = SAFER_SK64_DEFAULT_NOF_ROUNDS;
	int strengthened = 1;
	unsigned char *userkey_1 = &userkey[0];
	unsigned char *userkey_2 = &userkey[8];

	if (_safer128_init == 0) {
		_mcrypt_Safer_Init_Module();
		_safer128_init = 1;
	}
	if (SAFER_MAX_NOF_ROUNDS < nof_rounds)
		nof_rounds = SAFER_MAX_NOF_ROUNDS;
	*key++ = (unsigned char) nof_rounds;
	ka[SAFER_BLOCK_LEN] = 0;
	kb[SAFER_BLOCK_LEN] = 0;
	for (j = 0; j < SAFER_BLOCK_LEN; j++) {
		ka[SAFER_BLOCK_LEN] ^= ka[j] = ROL(userkey_1[j], 5);
		kb[SAFER_BLOCK_LEN] ^= kb[j] = *key++ = userkey_2[j];
	}
	for (i = 1; i <= nof_rounds; i++) {
		for (j = 0; j < SAFER_BLOCK_LEN + 1; j++) {
			ka[j] = ROL(ka[j], 6);
			kb[j] = ROL(kb[j], 6);
		}
		for (j = 0; j < SAFER_BLOCK_LEN; j++)
			if (strengthened)
				*key++ =
				    (ka
				     [(j + 2 * i - 1) %
				      (SAFER_BLOCK_LEN + 1)] +
				     exp_tab128[exp_tab128[18 * i + j + 1]]) &
				    0xFF;
			else
				*key++ =
				    (ka[j] +
				     exp_tab128[exp_tab128[18 * i + j + 1]]) &
				    0xFF;
		for (j = 0; j < SAFER_BLOCK_LEN; j++)
			if (strengthened)
				*key++ =
				    (kb
				     [(j + 2 * i) %
				      (SAFER_BLOCK_LEN + 1)] +
				     exp_tab128[exp_tab128[18 * i + j + 10]]) &
				    0xFF;
			else
				*key++ =
				    (kb[j] +
				     exp_tab128[exp_tab128[18 * i + j + 10]]) &
				    0xFF;
	}
	for (j = 0; j < SAFER_BLOCK_LEN + 1; j++)
		ka[j] = kb[j] = 0;

	return 0;
}				/* Safer_Expand_Userkey */

/******************************************************************************/


WIN32DLL_DEFINE
    void _mcrypt_encrypt(const safer_key_t * key, safer_block_t * block_in)
{
	unsigned char a, b, c, d, e, f, g, h, t;
	unsigned int round;

	a = block_in[0];
	b = block_in[1];
	c = block_in[2];
	d = block_in[3];
	e = block_in[4];
	f = block_in[5];
	g = block_in[6];
	h = block_in[7];
	if (SAFER_MAX_NOF_ROUNDS < (round = *key))
		round = SAFER_MAX_NOF_ROUNDS;
	while (round--) {
		a ^= *++key;
		b += *++key;
		c += *++key;
		d ^= *++key;
		e ^= *++key;
		f += *++key;
		g += *++key;
		h ^= *++key;
		a = EXP(a) + *++key;
		b = LOG(b) ^ *++key;
		c = LOG(c) ^ *++key;
		d = EXP(d) + *++key;
		e = EXP(e) + *++key;
		f = LOG(f) ^ *++key;
		g = LOG(g) ^ *++key;
		h = EXP(h) + *++key;
		PHT(a, b);
		PHT(c, d);
		PHT(e, f);
		PHT(g, h);
		PHT(a, c);
		PHT(e, g);
		PHT(b, d);
		PHT(f, h);
		PHT(a, e);
		PHT(b, f);
		PHT(c, g);
		PHT(d, h);
		t = b;
		b = e;
		e = c;
		c = t;
		t = d;
		d = f;
		f = g;
		g = t;
	}
	a ^= *++key;
	b += *++key;
	c += *++key;
	d ^= *++key;
	e ^= *++key;
	f += *++key;
	g += *++key;
	h ^= *++key;
	block_in[0] = a & 0xFF;
	block_in[1] = b & 0xFF;
	block_in[2] = c & 0xFF;
	block_in[3] = d & 0xFF;
	block_in[4] = e & 0xFF;
	block_in[5] = f & 0xFF;
	block_in[6] = g & 0xFF;
	block_in[7] = h & 0xFF;
}				/* Safer_Encrypt_Block */

/******************************************************************************/

WIN32DLL_DEFINE
    void _mcrypt_decrypt(const safer_key_t * key, safer_block_t * block_in)
{
	safer_block_t a, b, c, d, e, f, g, h, t;
	unsigned int round;
	a = block_in[0];
	b = block_in[1];
	c = block_in[2];
	d = block_in[3];
	e = block_in[4];
	f = block_in[5];
	g = block_in[6];
	h = block_in[7];
	if (SAFER_MAX_NOF_ROUNDS < (round = *key))
		round = SAFER_MAX_NOF_ROUNDS;
	key += SAFER_BLOCK_LEN * (1 + 2 * round);
	h ^= *key;
	g -= *--key;
	f -= *--key;
	e ^= *--key;
	d ^= *--key;
	c -= *--key;
	b -= *--key;
	a ^= *--key;
	while (round--) {
		t = e;
		e = b;
		b = c;
		c = t;
		t = f;
		f = d;
		d = g;
		g = t;
		IPHT(a, e);
		IPHT(b, f);
		IPHT(c, g);
		IPHT(d, h);
		IPHT(a, c);
		IPHT(e, g);
		IPHT(b, d);
		IPHT(f, h);
		IPHT(a, b);
		IPHT(c, d);
		IPHT(e, f);
		IPHT(g, h);
		h -= *--key;
		g ^= *--key;
		f ^= *--key;
		e -= *--key;
		d -= *--key;
		c ^= *--key;
		b ^= *--key;
		a -= *--key;
		h = LOG(h) ^ *--key;
		g = EXP(g) - *--key;
		f = EXP(f) - *--key;
		e = LOG(e) ^ *--key;
		d = LOG(d) ^ *--key;
		c = EXP(c) - *--key;
		b = EXP(b) - *--key;
		a = LOG(a) ^ *--key;
	}
	block_in[0] = a & 0xFF;
	block_in[1] = b & 0xFF;
	block_in[2] = c & 0xFF;
	block_in[3] = d & 0xFF;
	block_in[4] = e & 0xFF;
	block_in[5] = f & 0xFF;
	block_in[6] = g & 0xFF;
	block_in[7] = h & 0xFF;
}				/* Safer_Decrypt_Block */

/******************************************************************************/

WIN32DLL_DEFINE int _mcrypt_get_size()
{
	return (1 + SAFER_BLOCK_LEN * (1 + 2 * SAFER_MAX_NOF_ROUNDS));
}
WIN32DLL_DEFINE int _mcrypt_get_block_size()
{
	return 8;
}
WIN32DLL_DEFINE int _is_block_algorithm()
{
	return 1;
}
WIN32DLL_DEFINE int _mcrypt_get_key_size()
{
	return 16;
}

static const int key_sizes[] = { 16 };
WIN32DLL_DEFINE const int *_mcrypt_get_supported_key_sizes(int *len)
{
	*len = sizeof(key_sizes)/sizeof(int);
	return key_sizes;

}

WIN32DLL_DEFINE char *_mcrypt_get_algorithms_name()
{
	return "SAFER-SK128";
}

#define CIPHER "35ed856e2cf90947"

WIN32DLL_DEFINE int _mcrypt_self_test()
{
	char *keyword;
	unsigned char plaintext[16];
	unsigned char ciphertext[16];
	int blocksize = _mcrypt_get_block_size(), j;
	void *key;
	unsigned char cipher_tmp[200];

	keyword = calloc(1, _mcrypt_get_key_size());
	if (keyword == NULL)
		return -1;

	for (j = 0; j < _mcrypt_get_key_size(); j++) {
		keyword[j] = ((j * 2 + 10) % 256);
	}

	for (j = 0; j < blocksize; j++) {
		plaintext[j] = j % 256;
	}
	key = malloc(_mcrypt_get_size());
	if (key == NULL) {
		free(keyword);
		return -1;
	}
	memcpy(ciphertext, plaintext, blocksize);

	_mcrypt_set_key(key, (void *) keyword, _mcrypt_get_key_size());
	free(keyword);

	_mcrypt_encrypt(key, (void *) ciphertext);

	for (j = 0; j < blocksize; j++) {
		sprintf(&((char *) cipher_tmp)[2 * j], "%.2x",
			ciphertext[j]);
	}

	if (strcmp((char *) cipher_tmp, CIPHER) != 0) {
		printf("failed compatibility\n");
		printf("Expected: %s\nGot: %s\n", CIPHER,
		       (char *) cipher_tmp);
		free(key);
		return -1;
	}
	_mcrypt_decrypt(key, (void *) ciphertext);
	free(key);

	if (strcmp(ciphertext, plaintext) != 0) {
		printf("failed internally\n");
		return -1;
	}

	return 0;
}

WIN32DLL_DEFINE word32 _mcrypt_algorithm_version()
{
	return 20010801;
}

#ifdef WIN32
# ifdef USE_LTDL
WIN32DLL_DEFINE int main (void)
{
       /* empty main function to avoid linker error (see cygwin FAQ) */
}
# endif
#endif
