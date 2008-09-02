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

/******************* External Headers *****************************************/

/******************* Local Headers ********************************************/
#include "safer.h"

/******************* Constants ************************************************/
#define TAB_LEN      256

/******************* Assertions ***********************************************/

/******************* Macros ***************************************************/
#define ROL(x, n)    ((unsigned char)(((unsigned int)(x) << (n))\
									 |((unsigned int)((x) & 0xFF) >> (8 - (n)))))
#define EXP(x)       exp_tab[(x) & 0xFF]
#define LOG(x)       log_tab[(x) & 0xFF]
#define PHT(x, y)    { y += x; x += y; }
#define IPHT(x, y)   { x -= y; y -= x; }

/******************* Types ****************************************************/
static unsigned char exp_tab[TAB_LEN];
static unsigned char log_tab[TAB_LEN];

/******************* Module Data **********************************************/
static int init_called = 0;
/******************* Functions ************************************************/

/******************************************************************************/
#ifndef NOT_ANSI_C
    void Safer_Init_Module(void)
#else
    Safer_Init_Module()
#endif

{   unsigned int i, exp;

	if (init_called) return;

	exp = 1;
    for (i = 0; i < TAB_LEN; i++)
    {
        exp_tab[i] = (unsigned char)(exp & 0xFF);
        log_tab[exp_tab[i]] = (unsigned char)i;
        exp = exp * 45 % 257;
	}

	init_called = 1;
} /* Safer_Init_Module */

/******************************************************************************/
#ifndef NOT_ANSI_C
    void Safer_Expand_Userkey(safer_block_t userkey_1,
                              safer_block_t userkey_2,
                              unsigned int nof_rounds,
                              int strengthened,
                              safer_key_t key)
#else
    Safer_Expand_Userkey(userkey_1, userkey_2, nof_rounds, strengthened, key)
    safer_block_t userkey_1;
    safer_block_t userkey_2;
    unsigned int nof_rounds;
    int strengthened;
    safer_key_t key;
#endif

{   unsigned int i, j;
    unsigned char ka[SAFER_BLOCK_LEN + 1];
    unsigned char kb[SAFER_BLOCK_LEN + 1];

    if (SAFER_MAX_NOF_ROUNDS < nof_rounds)
        nof_rounds = SAFER_MAX_NOF_ROUNDS;
    *key++ = (unsigned char)nof_rounds;
    ka[SAFER_BLOCK_LEN] = 0;
    kb[SAFER_BLOCK_LEN] = 0;
    for (j = 0; j < SAFER_BLOCK_LEN; j++)
    {
        ka[SAFER_BLOCK_LEN] ^= ka[j] = ROL(userkey_1[j], 5);
        kb[SAFER_BLOCK_LEN] ^= kb[j] = *key++ = userkey_2[j];
    }
    for (i = 1; i <= nof_rounds; i++)
    {
        for (j = 0; j < SAFER_BLOCK_LEN + 1; j++)
        {
            ka[j] = ROL(ka[j], 6);
            kb[j] = ROL(kb[j], 6);
        }
        for (j = 0; j < SAFER_BLOCK_LEN; j++)
            if (strengthened)
                *key++ = (ka[(j + 2 * i - 1) % (SAFER_BLOCK_LEN + 1)]
                                + exp_tab[exp_tab[18 * i + j + 1]]) & 0xFF;
            else
                *key++ = (ka[j] + exp_tab[exp_tab[18 * i + j + 1]]) & 0xFF;
        for (j = 0; j < SAFER_BLOCK_LEN; j++)
            if (strengthened)
                *key++ = (kb[(j + 2 * i) % (SAFER_BLOCK_LEN + 1)]
                                + exp_tab[exp_tab[18 * i + j + 10]]) & 0xFF;
            else
                *key++ = (kb[j] + exp_tab[exp_tab[18 * i + j + 10]]) & 0xFF;
    }
    for (j = 0; j < SAFER_BLOCK_LEN + 1; j++)
        ka[j] = kb[j] = 0;
} /* Safer_Expand_Userkey */

/******************************************************************************/
#ifndef NOT_ANSI_C
    void Safer_Encrypt_Block(safer_block_t block_in, safer_key_t key,
                             safer_block_t block_out)
#else
    Safer_Encrypt_Block(block_in, key, block_out)
    safer_block_t block_in;
    safer_key_t key;
    safer_block_t block_out;
#endif

{   unsigned char a, b, c, d, e, f, g, h, t;
    unsigned int round;

    a = block_in[0]; b = block_in[1]; c = block_in[2]; d = block_in[3];
    e = block_in[4]; f = block_in[5]; g = block_in[6]; h = block_in[7];
    if (SAFER_MAX_NOF_ROUNDS < (round = *key)) round = SAFER_MAX_NOF_ROUNDS;
    while(round--)
    {
        a ^= *++key; b += *++key; c += *++key; d ^= *++key;
        e ^= *++key; f += *++key; g += *++key; h ^= *++key;
        a = EXP(a) + *++key; b = LOG(b) ^ *++key;
        c = LOG(c) ^ *++key; d = EXP(d) + *++key;
        e = EXP(e) + *++key; f = LOG(f) ^ *++key;
        g = LOG(g) ^ *++key; h = EXP(h) + *++key;
        PHT(a, b); PHT(c, d); PHT(e, f); PHT(g, h);
        PHT(a, c); PHT(e, g); PHT(b, d); PHT(f, h);
        PHT(a, e); PHT(b, f); PHT(c, g); PHT(d, h);
        t = b; b = e; e = c; c = t; t = d; d = f; f = g; g = t;
    }
    a ^= *++key; b += *++key; c += *++key; d ^= *++key;
    e ^= *++key; f += *++key; g += *++key; h ^= *++key;
    block_out[0] = a & 0xFF; block_out[1] = b & 0xFF;
    block_out[2] = c & 0xFF; block_out[3] = d & 0xFF;
    block_out[4] = e & 0xFF; block_out[5] = f & 0xFF;
    block_out[6] = g & 0xFF; block_out[7] = h & 0xFF;
} /* Safer_Encrypt_Block */

/******************************************************************************/
#ifndef NOT_ANSI_C
    void Safer_Decrypt_Block(safer_block_t block_in, safer_key_t key, 
                             safer_block_t block_out)
#else
    Safer_Decrypt_Block(block_in, key, block_out)
    safer_block_t block_in;
    safer_key_t key;
    safer_block_t block_out;
#endif

{   unsigned char a, b, c, d, e, f, g, h, t;
    unsigned int round;

    a = block_in[0]; b = block_in[1]; c = block_in[2]; d = block_in[3];
    e = block_in[4]; f = block_in[5]; g = block_in[6]; h = block_in[7];
    if (SAFER_MAX_NOF_ROUNDS < (round = *key)) round = SAFER_MAX_NOF_ROUNDS;
    key += SAFER_BLOCK_LEN * (1 + 2 * round);
    h ^= *key; g -= *--key; f -= *--key; e ^= *--key;
    d ^= *--key; c -= *--key; b -= *--key; a ^= *--key;
    while (round--)
    {
        t = e; e = b; b = c; c = t; t = f; f = d; d = g; g = t;
        IPHT(a, e); IPHT(b, f); IPHT(c, g); IPHT(d, h);
        IPHT(a, c); IPHT(e, g); IPHT(b, d); IPHT(f, h);
        IPHT(a, b); IPHT(c, d); IPHT(e, f); IPHT(g, h);
        h -= *--key; g ^= *--key; f ^= *--key; e -= *--key;
        d -= *--key; c ^= *--key; b ^= *--key; a -= *--key;
        h = LOG(h) ^ *--key; g = EXP(g) - *--key;
        f = EXP(f) - *--key; e = LOG(e) ^ *--key;
        d = LOG(d) ^ *--key; c = EXP(c) - *--key;
        b = EXP(b) - *--key; a = LOG(a) ^ *--key;
    }
    block_out[0] = a & 0xFF; block_out[1] = b & 0xFF;
    block_out[2] = c & 0xFF; block_out[3] = d & 0xFF;
    block_out[4] = e & 0xFF; block_out[5] = f & 0xFF;
    block_out[6] = g & 0xFF; block_out[7] = h & 0xFF;
} /* Safer_Decrypt_Block */

/******************************************************************************/
