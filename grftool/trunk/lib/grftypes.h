/*
 *  libgrf
 *  grftypes.h - types and structure definitions shared between different
 *               source files in libgrf.
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

/** @file grftypes.h
 *
 * Macro, data structure and data type definitions.
 *
 * Structures in this header are mainly targetted to be used for GRF handling,
 * but should be adaptable to other archive types as well. RGZ handling uses
 * certain Grf functions, so it uses the same structures as well.
 */


#ifndef __GRFTYPES_H__
#define __GRFTYPES_H__

#include <sys/types.h>
#include <stdio.h>


/*******************************************************
 * Portability macros
 *
 * You can mostly ignore the stuff here. They're just
 * for making sure libgrf is portable and compiles on
 * different platforms/compilers. Scroll down for the
 * real GRF stuff.
 *******************************************************/


/** @def GRFEXTERN_BEGIN
 * Internally used macro which marks the beginning of C
 * function and data type definitions. Used for C++ safety.
 */

/** @def GRFEXTERN_END
 * Internally used macro which marks the beginning of C
 * function and data type definitions. Used for C++ safety.
 */

/** @def GRFINLINE
 * Internally used macro which marks a function as an inline function.
 */

/** @def GRFEXPORT
 * Internally used macro which marks a function as being exportable in
 * the DLL. Only useful on Windows.
 */

/** @def NULL
 * A null pointer.
 */


/* C++ safety stuff */
#ifdef __cplusplus
	#define GRFEXTERN_BEGIN extern "C" {
	#define GRFEXTERN_END }
	#ifdef __GNUC__
		#define GRFINLINE inline
	#else /* __GNUC__ */
		#define GRFINLINE
	#endif /* __GNUC__ */
#else
	#define GRFEXTERN_BEGIN
	#define GRFEXTERN_END
	#ifdef __GNUC__
		#define GRFINLINE inline
	#else /* __GNUC__ */
		#define GRFINLINE
	#endif /* __GNUC__ */
#endif /* __cplusplus */


/* Make use of C++ safety right away :) */
GRFEXTERN_BEGIN

/* Win32 DLL macros */
#ifdef WIN32
	/* Integer types */
	#ifdef __MINGW32__
		#include <stdint.h>
	#else
		#ifndef _INC_WINDOWS
			#include <windows.h>
		#endif /* _INC_WINDOWS */
		typedef UINT32 uint32_t;
		typedef UINT16 uint16_t;
		typedef UINT8 uint8_t;
	#endif /* __MINGW32__ */

	/* Pack to 1 byte boundaries */
	#include <pshpack1.h>

	#ifndef GRF_STATIC
		#ifdef GRF_BUILDING
			#define GRFEXPORT __declspec(dllexport)
		#else /* GRF_BUILDING */
			#define GRFEXPORT __declspec(dllimport)
		#endif /* GRF_BUILDING */
	#else /* GRF_STATIC */
		#define GRFEXPORT
	#endif /* GRF_STATIC */
#else /* WIN32 */
	/* Integer types */
	#include <inttypes.h>
	
	/* Pack to 1 byte boundaries */
	#pragma pack(1)

	#define GRFEXPORT
# endif /* WIN32 */


/* Make sure we have NULL, because its used all the time */
#ifndef NULL
	#define NULL ((void *) 0)
#endif



/*******************************
 * Real GRF stuff begins here
 *******************************/


/** Maximum length of filenames.
 * @note GRAVITY uses 0x100 as a length for filenames.
 */
#define GRF_NAMELEN	0x100


/** Error codes return by libgrf functions */
typedef enum {
	/** No error, everything went well */
	GE_SUCCESS,

	/** Bad arguments passed to function */
	GE_BADARGS,

	/** Not a GRF file */
	GE_INVALID,

	/** Corrupted, but valid GRF file */
	GE_CORRUPTED,

	/** Unsupported GRF version */
	GE_NSUP,

	/** File not found within the GRF */
	GE_NOTFOUND,

	/** Invalid index */
	GE_INDEX,

	/** Error information held in errno (if you're on Unix) */
	GE_ERRNO,

	/** Error is a zlib error, stored in extra */
	GE_ZLIB,

	/** Error is a zlib error, stored in gzFile, use gzerror to get it */
	GE_ZLIBFILE,

	/** File has no data (not really an "error") */
	GE_NODATA,

	/** Bad mode: tried to modify in read-only mode */
	GE_BADMODE,

	/** Feature not implemented */
	GE_NOTIMPLEMENTED
} GrfErrorType;


/** This structure is used by many libgrf functions to report detailed error information.
 *
 * Here's an example about how to use this structure:
 * @code
 * GrfError error;
 * Grf *grf;
 *
 * grf = grf_callback_open ("foo.grf", "rb", &error, NULL);
 * if (grf == NULL) {
 *     printf ("An error occured!\n");
 *     printf ("Error type %d\n", error->type);
 *     printf ("Occured at file %s line %d (function %s)\n", error->file, error->line, error->func);
 *     exit (1);
 * }
 * @endcode
 */
typedef struct {
	GrfErrorType	type;		/**<  Error type */
	uint32_t	line;		/**<  Line number in the soure code where the error took place */
	const char	*file;		/**<  Filename of source code where the error took place. */
	const char	*func;		/**<  Function that produced the error */
	uintptr_t	*extra;		/**< Extra information.
					 * Stored as a uintptr_t pointer (type
					 * which can hold any pointer), but
					 * could be anything (not even a ptr).
					 * In most (all?) programming models
					 * sizeof(pointer) >= sizeof(size_t)
					 */
} GrfError;


/** Structure of information about files within GRFs
 *
 * We try to hold the same structure as used in GRAVITY's GRF handlers.
 *
 * @note GRAVITY's GrfFile struct is 0x114 bytes, in the same order as this structure.
 */
typedef struct _GrfFile {
	/** Size in file.
	 * If using any form of DES encryption, this must be a multiple of 8 (which is the block size).
	 */
	uint32_t compressed_len_aligned;
	uint32_t compressed_len;		/**<  Compressed size */
	uint32_t real_len;			/**<  Original (decompressed) file size */
	uint32_t pos;				/**< location in GRF archive */

	/* Directories have specific sizes and offsets, even though
	 * no data is stored inside the GRF file
	 */

	/** GrfFile::compressed_len_aligned value used for directory entries */
	#define GRFFILE_DIR_SZFILE	0x0714
	/** GrfFile::compressed_len value used for directory entries */
	#define GRFFILE_DIR_SZSMALL	0x0449
	/** GrfFile::real_len value used for directory entries */
	#define GRFFILE_DIR_SZORIG	0x055C
	/** GrfFile::pos value used for directory entries */
	#define GRFFILE_DIR_OFFSET	0x058A

	/** Flags of file.
	 * Such as whether its a file or not, and what encryption methods it uses */
	uint8_t flags;

	/* Known flags for GRF/GPF files */
	/** This flag specifies that an entry is a file. If not set, then the entry is a directory.
	    This flag is used by GrfFile::flags, grf_replace(), grf_index_replace() and grf_put(). */
	#define GRFFILE_FLAG_FILE	0x01
	/** Flag for GrfFile::flags to specify that the file uses mixed crypto. Explained in grfcrypt.h. */
	#define GRFFILE_FLAG_MIXCRYPT	0x02
	/** Flag for GrfFile::flags to specify that only the first 0x14 blocks are encrypted. Explained in grfcrypt.h. */
	#define GRFFILE_FLAG_0x14_DES	0x04

	uint32_t hash;			/**<  Filename hash; used internally by grf_find() */
	char name[GRF_NAMELEN];		/**<  Filename */

	/* This is calculated when the file is crypted, and only used
	 * for GRFFILE_FLAG_MIXCRYPT, to determine how often to use
	 * DES encryption.
	 * Commented out because it doesn't appear in GRAVITY's struct
	 */
	/* uint32_t cycle; */
	
	/* Extra data (which is not found in GRAVITY's struct) */
	char *data;			/**<  Uncompressed file data */
	struct _GrfFile *next;		/**<  Linked list */
	struct _GrfFile *prev;		/**<  Reverse linked list */
} GrfFile;


/** Macro to check if a GrfFile is a directory entry.
 *
 * @param f GrfFile struct to check
 */
#define GRFFILE_IS_DIR(f) (((f).flags & GRFFILE_FLAG_FILE)==0 || ( \
	((f).compressed_len_aligned == GRFFILE_DIR_SZFILE) && \
	((f).compressed_len == GRFFILE_DIR_SZSMALL) && \
	((f).real_len == GRFFILE_DIR_SZORIG) && \
	((f).pos == GRFFILE_DIR_OFFSET) \
	))


/** The structure which contains information about a GRF file. */
typedef struct {
	char *filename;		/**<  Archive filename. */
	uint32_t len;		/**<  Size of the GRF file */

	uint32_t type;		/**<  Archive type (GRF, RGZ, etc)
				 *
				 * @see GRF_TYPE_GRF
				 * @see GRF_TYPE_RGZ
				 */
	uint32_t version;	/**<  Archive internal version number */

	uint32_t nfiles;	/**<  Number of files in the archive */

	/** File information array.
	 * Array which contains information for items inside the GRF file.
	 */
	GrfFile *files;
	GrfFile *first;		/**<  Beginning of the linked list of files */
	GrfFile *last;		/**< Beginning of the reverse linked list */

	#ifndef DOXYGEN_SKIP
	/* Reserved space for future expansion */
	void *_reserved1;
	void *_reserved2;
	void *_reserved3;
	void *_reserved4;
	#endif /* DOXYGEN_SKIP */

	/* Private fields */
	uint8_t allowCrypt;	/**<  Internal use only - Can files be encrypted or not? */
	FILE *f;		/**<  Internal use only */
	uint8_t allowWrite;	/**<  Internal use only - Can Grf be modified? */
	void *zbuf;		/**<  Internal use only - temporary buffer space */

	#ifndef DOXYGEN_SKIP
	/* Reserved space for future expansion */
	void *_priv_reserved1;
	void *_priv_reserved2;
	void *_priv_reserved3;
	void *_priv_reserved4;
	#endif /* DOXYGEN_SKIP */
} Grf;


#ifdef WIN32
	/* Undo packing */
	#include <poppack.h>
#else /* WIN32 */
	/* Undo packing */
	#pragma pack()
#endif /* WIN32 */

GRFEXTERN_END

#endif /* __GRFTYPES_H__ */
