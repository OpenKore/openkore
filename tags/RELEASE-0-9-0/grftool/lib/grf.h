/*  libgrf - Library for reading GRF archives.
 *  Copyright (C) 2004  Hongli Lai <h.lai@chello.nl>
 *
 *  Based on grfio.[ch] from the eAthena source code.
 *  Copyright (C) ????  Whomever wrote grfio.[ch]
 *  (his name isn't mentioned in the source)
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

#ifndef _GRF_H_
#define _GRF_H_

#include <stdio.h>

#ifdef __cplusplus
	extern "C" {
#endif /* __cplusplus */

#ifndef NULL
#	define NULL ((void *) 0)
#endif /* NULL */

#ifdef WIN32
#	ifndef GRF_STATIC
#		ifdef GRF_BUILDING
#			define GRFEXPORT __declspec(dllexport)
#		else /* GRF_BUILDING */
#			define GRFEXPORT __declspec(dllimport)
#		endif /* GRF_BUILDING */
#	else /* GRF_STATIC */
#		define GRFEXPORT
#	endif /* GRF_STATIC */
#else /* _WIN32 */
#	define GRFEXPORT
#endif /* _WIN32 */


typedef struct {
	char *name;	/* Filename */

	/* Type values:
	 * 1, 5: Probably means that these are regular, unencoded files.
	 * 2: Folder.
	 * 3: Entry is encoded and needs to be decoded before decompression.
	 * 4: There doesn't seem to be any entries with this type value.
	 */
	int type;

	unsigned long compressed_len;		/* The compressed length */
	unsigned long compressed_len_aligned;	/* ??? */
	unsigned long real_len;			/* The length of the file when it's decompressed */
	unsigned long pos;			/* The offset to the compressed data inside the GRF archive */
	long cycle;				/* Used internally to determine how to decode this file, if necessary */
} GrfFile;

typedef struct {
	char *filename;		/* The filename of the GRF archive */
	int version;		/* The GRF archive's internal version number */
	unsigned long nfiles;	/* Number of files inside the archive */
	GrfFile *files;		/* An array which contains information about all files */

	/* Private fields; do not use! */
	FILE *f;
} Grf;

typedef enum {
	/* Developer errors */
	GE_BADARGS,	/* Bad arguments passed to function */

	/* grf_new() errors */
	GE_CANTOPEN,	/* Cannot open file */
	GE_INVALID,	/* Bad magic header; probably not a valid GRF file */
	GE_CORRUPTED,	/* Good magic header but bad file list header; probably corrupted */
	GE_NOMEM,	/* Out of memory */
	GE_NSUP,	/* Unsupported GRF archive version */

	/* grf_get(), grf_index_get() and grf_extract() errors */
	GE_NOTFOUND,	/* File not found inside GRF file */

	/* grf_index_get() errors */
	GE_INDEX,	/* Invalid index */

	/* grf_extract() errors */
	GE_WRITE	/* Unable to write to destination file */
} GrfError;


/* Open a .grf file */
GRFEXPORT Grf *grf_open (const char *fname, GrfError *error);

/* Look for a file in the file list */
GRFEXPORT GrfFile *grf_find (Grf *grf, char *fname, unsigned long *index);

/* Extract a file inside a .grf file into memory */
GRFEXPORT void *grf_get (Grf *grf, char *fname, unsigned long *size, GrfError *error);

/* Like grf_get(), but expects an index instead of a filename */
GRFEXPORT void *grf_index_get (Grf *grf, unsigned long index, unsigned long *size, GrfError *error);

/* Extract to a file */
GRFEXPORT int grf_extract (Grf *grf, char *fname, const char *writeToFile, GrfError *error);
GRFEXPORT int grf_index_extract (Grf *grf, unsigned long index, const char *writeToFile, GrfError *error);

/* Free a Grf* pointer */
GRFEXPORT void grf_free (Grf *grf);

/* Converts an error code to a human-readable message */
GRFEXPORT const char *grf_strerror (GrfError error);


#ifdef __cplusplus
	}
#endif /* __cplusplus */

#endif /* _GRF_H_ */
