/*
 *  libgrf
 *  grfsupport.c - provide commonly used functions to the library
 *  Copyright (C) 2004  Faithful <faithful@users.sf.net>
 *  Copyright (C) 2004  Hongli Lai <h.lai@chello.nl>
 *  Copyright (C) 2004  Rasqual <rasqualtwilight@users.sf.net>
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
 *
 */

#include "grftypes.h"
#include "grfsupport.h"

#include <stdlib.h>		/* snprintf, free */
#include <errno.h>		/* errno */
#include <string.h>		/* strerror, strcoll */
#include <zlib.h>		/* gzerror */

GRFEXTERN_BEGIN


/***************************
* Endian support functions *
***************************/
/* Pointless:
 * GRFINLINE uint8_t LittleEndian8 (uint8_t *p) { return *p; }
 */
/* Unused:
 * GRFINLINE uint16_t LittleEndian16 (uint8_t *p) { return p[1]*256 + *p; }
 */


/** Endian support function.
 *
 * Grabs a uint32_t from a 4byte (or more) character array.
 *
 * @warning If the character array is less than 4 bytes long, this function
 *		will access memory outside of the array
 *
 * @param p A uint8_t (char) array holding the bytes
 * @return A uint32_t in Little Endian order
 */
GRFINLINE uint32_t
LittleEndian32(uint8_t *p)
{
	return ((p[3] * 256 + p[2]) * 256 + p[1]) * 256 + *p;
}


/** Endian support function.
 *
 * Transforms a host uint32_t into a little-endian uint32_t
 *
 * @param hi A host uint32_t value
 * @return A uint32_t in Little Endian order
 */
GRFINLINE uint32_t
ToLittleEndian32(uint32_t hi)
{
	uint32_t lei;
	uint8_t *p = (uint8_t *) & lei;
	p[0] = hi & 0xFF;
	p[1] = (hi & 0xFF00) >> 8U;
	p[2] = (hi & 0xFF0000) >> 16U;
	p[3] = (hi & 0xFF000000) >> 24U;
	return lei;
}


/*************************
 * GRF Support Functions *
 *************************/

/** Normalize path for use in file operations.
 *
 * Regardless of platform (Win32, *NIX, etc) '/' is used as a path seperator
 * with fopen(), etc. Also, I've not seen any MBCS use anything less than
 * (decimal) 127 as part of a multi-byte character, so this shouldn't cause
 * any problems.
 *
 * @warning out must be allocated at least as long as strlen(in)+1
 *
 * @param out c-string to place converted path-/filename
 * @param in c-string to convert '\\' to '/'
 * @return A duplicate pointer to the normalized data
 */
GRFEXPORT char *
GRF_normalize_path(char *out, const char *in)
{
	char *orig;

	for (orig = out; *in != 0; out++, in++)
		*out = (*in == '\\') ? '/' : *in;
	out[0] = 0;

	return orig;
}


/** Function to hash a filename.
 *
 * @note This function hashes the exact same way that GRAVITY's GRF openers
 *		do. Enjoy ;-)
 *
 * @param name Filename to be hashed
 * @return The value of the hashed filename
 */
GRFEXPORT uint32_t
GRF_NameHash(const char *name)
{
	size_t i;
	uint32_t tmp;

	i = strlen(name);
	tmp = 0x1505;
	for (i = strlen(name); i > 0; i--, name++)
		tmp = tmp * 0x21 + *name;

	return tmp;
}


/** Finds a file inside an archive.
 *
 * @param grf Pointer to a Grf struct to search for the file
 * @param fname Full filename to search for
 * @param index Pointer to a uint32_t which will hold the index of the
 *		file in the Grf::files array.
 */
GRFEXPORT GrfFile *
grf_find(Grf *grf, const char *fname, uint32_t *index)
{
	uint32_t i,j;

	/* Make sure our arguments are sane */
	if (!grf || !fname) {
		/* GRF_SETERR(error,GE_BADARGS,grf_find); */
		return NULL;
	}

	/* For speed, grab the filename hash */
	j = GRF_NameHash(fname);
	for (i = 0; i < grf->nfiles; i++)
		/* Check 4 bytes against each other instead of
		 * a multi-character name
		 */
		if (grf->files[i].hash == j)
			/* Just to double check that we have the right file,
			 * compare the names
			 */
			if (!strncmp(fname, grf->files[i].name, GRF_NAMELEN)) {
				/* Return the information */
				if (index) *index = i;
				return &(grf->files[i]);
			}

	/* GRF_SETERR(error, GE_SUCCESS, grf_find); */
	return NULL;
}


/** Function to sort a Grf::files array
 *
 * @param grf Pointer to Grf struct which needs its files array sorted
 * @param compar Callback function to determine which entry should be before the
 *               other. It should return -1 if the first file should be first,
 *               0 if they are equal, or 1 if the first file should be second.
 *
 * @see GRF_AlphaSort_Func()
 * @see GRF_OffsetSort_Func()
 */
GRFEXPORT void
grf_sort(Grf *grf, int(*compar)(const void *, const void *))
{
	/* Run the sort */
	qsort(grf, grf->nfiles - 1, sizeof(GrfFile), compar);
}


/** Alphabetical sorting callback function; can be used with grf_sort().
 *
 * @param g1 Pointer to the 1st GrfFile to evaluate
 * @param g2 Pointer to the 2nd GrfFile to evaluate
 * @return -1 if g1 should be first, 0 if g1 and g2 are equal, or 1 if
 *	g2 should be before g1
 */
GRFEXPORT int
GRF_AlphaSort_Func(const GrfFile *g1, const GrfFile *g2)
{
	return strcoll(g1->name, g2->name);
}


/** Offset-based sorting callback function; can be used with grf_sort().
 *
 * @param g1 Pointer to the 1st GrfFile to evaluate
 * @param g2 Pointer to the 2nd GrfFile to evaluate
 * @return -1 if g1 should be first, 0 if g1 and g2 are equal, or 1 if
 *	g2 should be before g1
 */
GRFEXPORT int
GRF_OffsetSort_Func(const GrfFile *g1, const GrfFile *g2)
{
	/* Check their offsets */
	if (g1->pos>g2->pos)
		return 1;
	else if (g1->pos==g2->pos)
		return 0;
	return -1;
}


/** Synchronize the linked list with the array
 *
 * @param grf Pointer to the Grf struct
 * @return 1 on success, 0 on fail
 */
int
GRF_list_from_array(Grf *grf, GrfError *error)
{
	uint32_t i;

	if (!grf) {
		GRF_SETERR(error,GE_BADARGS,GRF_list_from_array);
		return 0;
	}
	
	/* Reset the linked list */
	for (i = 0; i < grf->nfiles; i++) {
		if (i < grf->nfiles - 1)
			grf->files[i].next = &(grf->files[i + 1]);
		else
			grf->files[i].next = NULL;

		if (i > 0)
			grf->files[i].prev = &(grf->files[i - 1]);
		else
			grf->files[i].prev = NULL;
	}
	grf->files[0].prev=NULL;
	grf->files[grf->nfiles-1].next=NULL;
	grf->first=&(grf->files[0]);
	grf->last=&(grf->files[grf->nfiles-1]);

	GRF_SETERR(error,GE_SUCCESS,GRF_list_from_array);
	return 1;
}

/** Synchronize the Grf::files array with the linked list.
 *
 * @param grf Pointer to the Grf structure
 * @return 1 on success, 0 on fail
 */
int
GRF_array_from_list(Grf *grf, GrfError *error)
{
	GrfFile *newfiles, *cur;
	uint32_t i;

	/* Check our arguments */
	if (!grf) {
		GRF_SETERR(error, GE_BADARGS, GRF_array_from_list);
		return 0;
	}

	/* Allocate memory */
	newfiles = (GrfFile *) malloc(sizeof(GrfFile) * grf->nfiles);
	if (newfiles == NULL) {
		GRF_SETERR(error, GE_ERRNO, malloc);
		return 0;
	}

	/* Loop through the linked list, copying info into its position
	 * in the new array
	 */
	for (i = 0, cur = grf->first; i < grf->nfiles && cur; i++, cur = cur->next)
		memcpy(&(newfiles[i]), &(grf->files[i]), sizeof(GrfFile));

	/* Free old arguments */
	free(grf->files);

	/* Set new files */
	grf->files = newfiles;

	GRF_SETERR(error, GE_SUCCESS, GRF_array_from_list);
	return 1;
}


/***************************
* Error Handling Functions *
***************************/

/** Set error information in a GrfError structure.
 *
 * @see GRF_SETERR
 * @see GRF_SETERR_2
 *
 * @warning This function assumes that file and func point to constants
 *		or statics, and just directly copies the pointer
 *
 * @param err Pointer to the error struct/enum to set the information
 *		into
 * @param errtype The error type to set
 * @param line Line number (hopefully) close to where the error occurred
 * @param file File in which the error occurred
 * @param func Function in which the error occurred
 * @param extra Information needed for finding various odd errors, such as
 *		ones spit out by zlib's gzip functions
 * @return A duplicate of the err pointer
 */
GRFEXPORT GrfError *GRF_SetError(GrfError *err, GrfErrorType errtype, uint32_t line, const char *file, const char *func, void *extra) {
	if (err) {
		/* Set the error informations */
		err->type = errtype;
		err->line = line;
		err->file = file;
		err->func = func;
		err->extra = extra;
	}

	return err;
}

/** Convert a GrfErrorType to a human-readable string.
 *
 * @param error The error type we need a string for
 * @return A string constant giving a human-readable (we hope) version
 *		of the error type.
 */
static const char *
GRF_strerror_type(GrfErrorType error)
{
	switch (error) {
	case GE_SUCCESS:
		return "Success.";
	case GE_BADARGS:
		return "Bad arguments passed to function.";
	case GE_INVALID:
		return "Not a valid archive.";
	case GE_CORRUPTED:
		return "The archive appears to be corrupted.";
	case GE_NSUP:
		return "Archives of this version is not supported.";
	case GE_NOTFOUND:
		return "File not found inside archive.";
	case GE_INDEX:
		return "Invalid index.";
	case GE_ERRNO:
		return strerror(errno);
	case GE_ZLIB:
		return "Error in zlib.";
	case GE_ZLIBFILE:
		return "Error in zlib.";
	case GE_BADMODE:
		return "Bad mode: tried to modify in read-only mode.";
	case GE_NOTIMPLEMENTED:
		return "This feature is not implemented.";
	default:
		return "Unknown error.";
	};
}


/** Convert zlib errors into a string constant
 *
 * @param error zlib error number to grab a name
 * @return Human-readable string explanation of the error number
 */
static const char *
GRF_strerror_zlib(int error)
{
	switch (error) {
	case Z_OK:
		return "zlib success.";
	case Z_STREAM_END:
		return "zlib end of stream.";
	case Z_ERRNO:
		return strerror(errno);
	case Z_STREAM_ERROR:
		return "zlib stream error.";
	case Z_DATA_ERROR:
		return "zlib data error.";
	case Z_MEM_ERROR:
		return "zlib memory error.";
	case Z_BUF_ERROR:
		return "zlib buffer error.";
	case Z_VERSION_ERROR:
		return "zlib version error.";
	default:
		return "zlib unknown error.";
	}
}


/** Create a human-readable message from a GrfError struct or enum
 *
 * @note A pointer for the err argument isn't used only to keep
 *		compatibility with the older libgrf
 *
 * @param err Error structure containing information we need
 * @return A human-readable string, which must not be freed.
 */
GRFEXPORT const char *
grf_strerror(GrfError err)
{
	static char errbuf[0x1000];
	const char *tmpbuf;
	int dummy;

	/* Get the error string */
	switch (err.type) {
	case GE_ZLIB:
		tmpbuf = GRF_strerror_zlib((int) (ssize_t) err.extra);  /* NOTE: ptr => ssize_t /-signed-/ => int conversion */
		break;
	case GE_ZLIBFILE:
		tmpbuf = gzerror((gzFile) err.extra, &dummy);
		break;
	default:
		tmpbuf = GRF_strerror_type(err.type);
	}

	#ifdef GRF_DEBUG
		snprintf(errbuf, 0x1000, "%s:%u:%s: %s", err.file, err.line, err.func, tmpbuf);
	#else
		snprintf(errbuf, 0x1000, "%s: %s", err.func, tmpbuf);
	#endif

	return errbuf;
}


GRFEXTERN_END
