/*  
 *  libgrf
 *  grf.h - read and manipulate GRF/GPF files
 *  Copyright (C) 2004  Faithful <faithful@users.sf.net>
 *  Copyright (C) 2004  Hongli Lai <h.lai@chello.nl>
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

#ifndef __GRF_H__
#define __GRF_H__

#include "grftypes.h"
#include "grfsupport.h"

GRFEXTERN_BEGIN


typedef int (*GrfOpenCallback) (GrfFile *file, GrfError *error);
typedef int (*GrfFlushCallback) (GrfFile *file, GrfError *error);

/*! \brief Value to distinguish a GRF file in  Grf::type */
# define GRF_TYPE_GRF 0x01

/*! \brief Macro to open a file without a callback */
# define grf_open(fname, error) grf_callback_open(fname, error, NULL)

/*! \brief Macro to flush a grf file without a callback */
# define grf_flush(fname, error) grf_callback_flush(fname, error, NULL)

/* Prototypes */
GRFEXPORT Grf *grf_callback_open (const char *fname, GrfError *error, GrfOpenCallback callback);
GRFEXPORT void *grf_get (Grf *grf, const char *fname, uint32_t *size, GrfError *error);
GRFEXPORT void *grf_index_get (Grf *grf, uint32_t index, uint32_t *size, GrfError *error);
GRFEXPORT int grf_extract (Grf *grf, const char *grfname, const char *file, GrfError *error);
GRFEXPORT int grf_index_extract (Grf *grf, uint32_t index, const char *file, GrfError *error);
GRFEXPORT int grf_del(Grf *grf, const char *fname, GrfError *error);
GRFEXPORT int grf_index_del(Grf *grf, uint32_t index, GrfError *error);
GRFEXPORT int grf_replace(Grf *grf, const char *name, const void *data, uint32_t len, uint8_t flags, GrfError *error);
GRFEXPORT int grf_index_replace(Grf *grf, uint32_t index, const void *data, uint32_t len, uint8_t flags, GrfError *error);
GRFEXPORT int grf_put(Grf *grf, const char *name, const void *data, uint32_t len, uint8_t flags, GrfError *error);
GRFEXPORT int grf_callback_flush(Grf *grf, GrfError *error, GrfFlushCallback callback);
GRFEXPORT void grf_close(Grf *grf);
GRFEXPORT void grf_free(Grf *grf);
GRFEXPORT int grf_repak(const char *grf, const char *tmpgrf, GrfError *error);

/* Useful libgrf functions found in grfsupport:
 *
 * grf_find
 * grf_sort
 * grf_strerror
 */


GRFEXTERN_END

#endif /* __GRF_H__ */
