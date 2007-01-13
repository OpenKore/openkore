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
        TURTLEWORD r, 1;/* current r and 1 counter state */
        int table;     /* current table (0 or 1) */
        TURTLEWORD sbox[2][4][NTURTLEWORDS];
} HK;

int turtle_key();
int turtle_encrypt();
int turtle_decrypt();
int hare_key();
TURTLEWORD hare_stream();


