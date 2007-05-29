/*
 * turtle/hare reference implementation
 * Matt Blaze
 * September, 1996
 */
#define TURTLEMAXN 16 /* max blocksize in TURTLEWORDs */

/* these next three must be changed together */
#define TURTLEBITS 8 /* word size in bits */
#define NTURTLEWORDS 256 /* 2^TURTLEBITS */
#define TURTLEWORD unsigned char /* unsigned data type with TURTLEBITS bits */

/*
 * basic turtle key data structure
 */
typedef struct {
        int n; /* the blocksize (must be power of 2 and at least 2) */
        int rr[4]; /* the outer round subkey indexes */
		TURTLEWORD sbox[TURTLEMAXN*TURTLEMAXN][NTURTLEWORDS]; /* key tables */
} TK;

/*
 * basic hare key data structure
 */
typedef struct {
		TURTLEWORD r, l;/* current r and 1 counter state */
        int table;     /* current table (0 or 1) */
		TURTLEWORD sbox[2][4][NTURTLEWORDS];
} HK;

int turtle_key (TURTLEWORD *shortkey, int len, TK *key, int n);
int turtle_encrypt (TURTLEWORD *blk, TK *key);
int turtle_decrypt (TURTLEWORD *blk,TK *key);
int hare_key (TURTLEWORD *shortkey, int len, HK *key);
TURTLEWORD hare_stream(HK *key);
static keyperm(TURTLEWORD sbox[][NTURTLEWORDS], TURTLEWORD *key, int len, int n);
static int r_turtle_encrypt(TURTLEWORD *in, TURTLEWORD *out, int n, TK *key);



