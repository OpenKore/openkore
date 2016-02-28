/**
 * The Whirlpool hashing function.
 *
 * The Whirlpool algorithm was developed by
 * Paulo S. L. M. Barreto and Vincent Rijmen.
 *
 * See
 *      P.S.L.M. Barreto, V. Rijmen,
 *      ``The Whirlpool hashing function,''
 *      NESSIE submission, 2000 (tweaked version, 2001),
 *      <https://www.cosic.esat.kuleuven.ac.be/nessie/workshop/submissions/whirlpool.zip>
 *
 * @version 3.0 (2003.03.12)
 *
 * Modified for use in this software package.
 */
#ifndef _WHIRLPOOL_ALGORITHM_H_
#define _WHIRLPOOL_ALGORITHM_H_

#ifdef __cplusplus
extern "C" {
#endif


/**
 * The size, in bytes, of a Whirlpool hash.
 */
#define WP_DIGEST_SIZE 64

typedef struct WP_Struct WP_Struct;

/**
 * Create a new WP_Struct handle and initialize the hashing state.
 *
 * @return A new WP_Struct handle, which must be freed by WP_Free() when no longer
 *         needed, or NULL if failed to allocate memory.
 */
WP_Struct *WP_Create();

/**
 * (Re-)Initialize the hashing state.
 *
 * @param wp  A WP_Struct handle, as created by WP_Create()
 * @require   wp != NULL
 */
void       WP_Init(WP_Struct *wp);

/**
 * Delivers input data to the hashing algorithm.
 *
 * @param source      Plaintext data to hash.
 * @param sourceBits  How many bits of plaintext to process.
 * @param wp          A WP_Struct handle, as created by WP_Create()
 * @require source != NULL && wp != NULL
 */
void       WP_Add(const unsigned char * const source,
                  unsigned long sourceBits,
                  WP_Struct * const wp);

/**
 * Get the hash value from the hashing state.
 *
 * @param wp      A WP_Struct handle, as created by WP_Create()
 * @param result  A string to store the hash to.
 * @require
 *     wp != NULL
 *     result != NULL
 *     result must be able to hold at least WP_DIGEST_SIZE bytes.
 */
void       WP_Finalize(WP_Struct * const wp,
                       unsigned char * const result);

/**
 * Free a created WP_Struct handle.
 *
 * @param wp  A WP_Struct handle, as created by WP_Create().
 * @require   wp != NULL
 */
void       WP_Free(WP_Struct *wp);


#ifdef __cplusplus
}
#endif

#endif
