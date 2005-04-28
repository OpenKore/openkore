/*
 *  libgrf
 *  grf.h - read and manipulate GRF/GPF files
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
 */

/** @mainpage
 * libgrf is a library for reading and writing GRF archives.
 * Application developers are probably most interested in grf.h and grfsupport.h.
 * Use the link bar on top of this page to browse the documentation.
 */

/** @file grf.h
 *
 * Reading and writing .GRF archives.
 */

#ifndef __GRF_H__
#define __GRF_H__

#include "grftypes.h"
#include "grfsupport.h"

GRFEXTERN_BEGIN

#ifdef WORK_AROUND_DOXYGEN_BUG
static int foo;
#endif /* WORK_AROUND_DOXYGEN_BUG */


/** Callback prototype of a function called for each file entry when opening a GRF file.
 *
 * It should return -1 if there has been an error.
 * 0 if processing may continue,
 * or 1 if further reading should stop (for example, when trying to locate a file quickly)
 *
 * @see grf_callback_open()
 *
 * @param file   Pointer to a Grf structure, as returned by grf_callback_open()
 * @param error  [out] Pointer to a GrfError variable for error reporting. When an error
 *               occured, the value of this parameter is non-NULL.
 *
 */
typedef int (*GrfOpenCallback) (GrfFile *file, GrfError *error);

/** Callback prototype for grf_callback_flush()
 * @param file   Pointer to a Grf structure, as returned by grf_callback_open()
 * @param error  [out] Pointer to a GrfError variable for error reporting. When an error
 *               occured, the value of this parameter is non-NULL.
 */
typedef int (*GrfFlushCallback) (GrfFile *file, GrfError *error);


/** Value to distinguish a GRF file in Grf::type */
# define GRF_TYPE_GRF 0x01

/** @brief The same as grf_callback_open(), but without a callback parameter. Kept for compatibility with libgrf 0.9. */
# define grf_open(fname, mode, error) grf_callback_open(fname, mode, error, NULL)

/** The same as grf_callback_flush(), but without a callback parameter. */
#define grf_flush(fname, error) grf_callback_flush(fname, error, NULL)


/* Opening */
GRFEXPORT Grf *grf_callback_open (const char *fname, const char *mode, GrfError *error, GrfOpenCallback callback);

/* Extraction functions */
GRFEXPORT void *grf_get (Grf *grf, const char *fname, uint32_t *size, GrfError *error);
GRFEXPORT void *grf_get_z (Grf *grf, const char *fname, uint32_t *size, uint32_t *usize, GrfError *error);
GRFEXPORT void *grf_chunk_get (Grf *grf, const char *fname, char *buf, uint32_t offset, uint32_t *len, GrfError *error);
GRFEXPORT void *grf_index_get (Grf *grf, uint32_t index, uint32_t *size, GrfError *error);
GRFEXPORT void *grf_index_get_z(Grf *grf, uint32_t index, uint32_t *size, uint32_t *usize, GrfError *error);
GRFEXPORT void *grf_index_chunk_get (Grf *grf, uint32_t index, char *buf, uint32_t offset, uint32_t *len, GrfError *error);
GRFEXPORT int grf_extract (Grf *grf, const char *grfname, const char *file, GrfError *error);
GRFEXPORT int grf_index_extract (Grf *grf, uint32_t index, const char *file, GrfError *error);

/* GRF modification functions */
GRFEXPORT int grf_del(Grf *grf, const char *fname, GrfError *error);
GRFEXPORT int grf_index_del(Grf *grf, uint32_t index, GrfError *error);

GRFEXPORT int grf_replace(Grf *grf, const char *name, const void *data, uint32_t len, uint8_t flags, GrfError *error);
GRFEXPORT int grf_index_replace(Grf *grf, uint32_t index, const void *data, uint32_t len, uint8_t flags, GrfError *error);

GRFEXPORT int grf_put(Grf *grf, const char *name, const void *data, uint32_t len, uint8_t flags, GrfError *error);

GRFEXPORT int grf_callback_flush(Grf *grf, GrfError *error, GrfFlushCallback callback);
GRFEXPORT int grf_repak(const char *grf, const char *tmpgrf, GrfError *error);

/* Closing and freeing */
GRFEXPORT void grf_close(Grf *grf);
GRFEXPORT void grf_free(Grf *grf);


/* Useful libgrf functions found in grfsupport:
 *
 * grf_find
 * grf_sort
 * grf_strerror
 */


GRFEXTERN_END

#endif /* __GRF_H__ */
