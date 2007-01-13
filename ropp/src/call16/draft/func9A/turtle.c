/*
 * turtle.c
 * Matt Blaze, September, 1996 
 *
 * This is the basic turtle/hare cipher reference implementation
 * with a simple key schedule. 
 *
 * Turtle blocksize can be any power of two words >= 4;
 * the wordsize is hardcoded in turtle.h.  8 bits is the default. 
 *
 * This code turtle encrypts 8-word blocks on a pl00 at about 3Mbps.  It
 * can probably be made a couple times faster by unrolling the recursive
 * calls. Hare runs at about 9Mbps. 
 */

#include <stdio.h> 
#include "turtle.h"

static int r;
static keyperm();
static int r_turtle_encrypt();

/*
 * Basic turtle encrypt
 * (encrypts blk in place) 
 */
int turtle_encrypt(blk,key) 
     TURTLEWORD *blk;
     TK *key;
{
	int nn, i;
	TURTLEWORD buf[TURTLEMAXN];
	if   ((key==NULL)   ||   (blk==NULL))
        	return -1; 

	r=0;
	nn=key->n/2; 
	r_turtle_encrypt(&(blk[0]),buf,nn,key);

	for  (i=0;   i<nn;   i++)
		blk[i+nn]   ^= buf[i] ;

	r_turtle_encrypt(&(blk[nn]),buf,nn,key); 

	for  (i=0;   i<nn;   i++)
		blk[i]   ^= buf[i] ;

	r_turtle_encrypt(&(blk[0]),buf,nn,key);

	for  (i=0;   i<nn;   i++)
		blk[i+nn]   ^= buf[i] ;

	r_turtle_encrypt(&(blk[nn]),buf,nn,key); 

	for  (i=0;   i<nn;   i++)
        	blk[i]   ^= buf[i] ;

	return 0; 
}

/*
 *	Basic turtle decrypt
 *	(decrypts blk in place) 
 */
int turtle_decrypt(blk,key) 
	TURTLEWORD *blk;
	TK *key;
{
	int nn, i, rr;
	unsigned char buf[TURTLEMAXN];
	if   ((key==NULL)   ||   (blk==NULL))
		return -1; nn=key->n/2; r=key->rr[3];     /* we have to use the key schedule backwards */
            						  /* but only for the OUTERMOST recursive shell */ 

	r_turtle_encrypt(&(blk[nn]),buf,nn,key);

	for   (i=0;   i<nn;   i++)
        	blk[i]   ^= buf[i] ; 

	r=key->rr[2];

	r_turtle_encrypt(&(blk[0]),buf,nn,key);

	for   (i=0;   i<nn;   i++)
		blk[i+nn]   ^= buf[i] ; 

	r=key->rr[l];
	r_turtle_encrypt(&(blk[nn]),buf,nn,key); 

	for   (i=0;   i<nn;   i++)
		blk[i]   ^= buf[i] ; 

	r=0;
	r_turtle_encrypt(&(blk[0]),buf,nn,key);

	for   (i=0;   i<nn;   i++)
	        blk[i+nn]   ^= buf[i] ;

	return 0; 
}

/*
 *	create turtle key from short key.
 *	n must be a power of 2 and >= 4. 
 */
int turtle_key(shortkey,len,key,n) 
	TURTLEWORD *shortkey;
	int len;
	TK *key;
	int n;
{
	int i, j, nn; 
	TURTLEWORD other, t; 
	HK harekey;

	if ((n<4) || (n>TURTLEMAXN) || (key==NULL) || (shortkey==NULL))
		return -1; 

	nn=n*n;

	/* first create a hare key from the shortkey */ 
	hare_key(shortkey,len,&harekey); /* use hare to permute the real sboxes */

	for (j=0; j<nn; j++) {
		for (i=0; i<NTURTLEWORDS; i++) {
         		key->sbox[j][i]  = i;
		}

		for (i=0; i<NTURTLEWORDS; i++) {
			other = hare_stream(&harekey);
			t = key->sbox[j][i];
			key->sbox[j][i]  = key->sbox[j][other];
			key->sbox[j][other]  = t;
		}
	}

	key->n=n;
	key->rr[3]  = nn/4*3;
	key->rr[2]  = nn/4*2;
	key->rr[l]  = nn/4;
	key->rr[0]  = 0; 

	return 0;
}

/*
 *	Basic hare stream generator
 *	(returns one TURTLEWORD) 
 */
TURTLEWORD hare_stream(key)
      HK *key;
{
	TURTLEWORD r, 1, t;
	int table, otable;

	r = key->r;
	1 = key->l;
	table = key->table;
	otable = l-table;
	r^=key->sbox[table][0][l];
	l^=key->sbox[table][1][r];
	r^=key->sbox[table][2][l];
	l^=key->sbox[table][3][r];
	t = key->sbox[otable][key->r][key->l];
	key->sbox[otable][key->r][key->l]  = key->sbox[otable][key->r][r];
	key->sbox[otable][key->r][r]  = t;
	key->l = (key->l + 1) % NTURTLEWORDS;

	if   (key->l == 0)  {
		key->r = (key->r + 1) % NTURTLEWORDS;
	} 

	if (key->r > 3) {
		key->r = 0;
		key->l = 0;
          	key->table = otable; 
	}

	return 1;
}

/*
 *	create hare key from short key 
 */
int hare_key(shortkey,len,key) 
	TURTLEWORD *shortkey;
	int len;
	HK *key;
{
	if ((key == NULL) || (shortkey == NULL))
		return -1;

	/* first create the tables from the shortkey */ 
	keyperm(key->sbox[0],shortkey,len,4);

	/* do it again for the other set */ 
	keyperm(key->sbox[l],shortkey,len,4);
	key->table = 0;
	key->r = 0;
	key->l = 0;

	return 0; 
}

/*********************************************
 * support functions - not part of interface * 
 *********************************************/
/*
 *	recursive turtle function 
 */
static int r_turtle_encrypt(in,out,n,key) 
	TURTLEWORD *in;
	TURTLEWORD *out;
	int n;
	TK *key;
{
	int nn, i;
	TURTLEWORD buf[TURTLEMAXN];
	if  (n==2)  { /* this is the basic lookup */
		out[l]  = in[l]   ^ key->sbox[r++][in[0]];
		out[0]  = in[0]   ^ key->sbox[r++][out[l]];
		out[1] ^= key->sbox[r++][out[0]];
		out[0] ^= key->sbox[r++][out[1]];
	} else {    /* recurse */ 
		nn=n/2;
		r_turtle_encrypt(&(in[0]),buf,nn,key);

		for   (i=0;   i<nn;   i++)
			out[i+nn]   = in[i+nn]   ^ buf[i]; 

		r_turtle_encrypt(&(out[nn]),buf,nn,key); 

		for   (i=0;   i<nn;   i++)
         		out[i]   = in[i]   ^ buf[i]; 

		r_turtle_encrypt(&(out[0]),buf,nn,key); 

		for   (i=0;   i<nn;   i++)
			out[i+nn]   ^= buf[i];

		r_turtle_encrypt(&(out[nn]),buf,nn,key); 

		for   (i=0;   i<nn;   i++)
			out[i]   ^= buf[i]; 
	}

	return 0; 
}

/* Simple key permutation expand function.
 * This is really more of an example than anything else.
 * Generate n permutations on 2^WORDBITS elements from the cryptovariable.
 * This is approximately similar to the RC-4 permutation generator, but
 * we go through each table WORDBITS times, which smoothes out the early
 * swaps and does a total of x log x swaps in each permutation. 
 */
static keyperm(sbox,key,len,n)
	TURTLEWORD sbox[][NTURTLEWORDS]; 
	TURTLEWORD *key; int len; int n;
{
	int a, b, i, j, k; 
	TURTLEWORD t;

	for (b=0; b<n; b++) {
		for (i=0; i<NTURTLEWORDS; i++) {
			sbox[b] [i]=i;
		}
	}

	j=len;
	k=0;

	for (b=0; b<n; b++) { /* for each keygen sbox */
		for (a=0; a<TURTLEBITS; a++) { /* n times around for each */ 
			for (i=0; i<NTURTLEWORDS; i++) { /* swap w/ element */ 
				j = (j + key[k] +sbox[b] [(a*b+i)%NTURTLEWORDS]) %NTURTLEWORDS;
				t = sbox [b] [i] ;
				sbox[b][i]  = sbox[b][j];
				sbox[b] [j]  = t;
				k=(k+l)%len;
			}
		}
	}
}

