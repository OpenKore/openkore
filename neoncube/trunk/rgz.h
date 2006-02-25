/*
 *  libgrf
 *  rgz.h - library functions to manipulate RGZ files
 *  Copyright (C) 2004  Faithful <faithful@users.sf.net>
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

/** @file rgz.h
 *
 * Reading .RGZ archives.
 */

#ifndef __RGZ_H__
#define __RGZ_H__

#include "grf.h"

GRFEXTERN_BEGIN


/*! \brief Value to distinguish a RGZ file in Grf::type */
# define GRF_TYPE_RGZ	0x02

/* RGZ archived file types */
# define RGZ_TYPE_DIRECTORY	'd'
# define RGZ_TYPE_EOF		'e'
# define RGZ_TYPE_FILE		'f'

/*! \brief Another name for Grf */
# define Rgz Grf
/*! \brief Another name for GrfError */
# define RgzError GrfError
/*! \brief Another name for GrfErrorType */
# define RgzErrorType GrfErrorType
/*! \brief Another name for GrfFile */
# define RgzFile GrfFile
/*! \brief Another name for grf_free */
# define rgz_free grf_free
/*! \brief Another name for grf_find */
# define rgz_find grf_find
/*! \brief Another name for grf_find_unused */
# define rgz_find_unused grf_find_unused
/*! \brief Another name for grf_sort */
# define rgz_sort grf_sort
/*! \brief Another name for rgz_strerror */
# define rgz_strerror grf_strerror
/*! \brief Another name for GRF_NameHash */
# define RGZ_NameHash GRF_NameHash
/*! \brief Another name for GRF_AlphaSort */
# define RGZ_AlphaSort GRF_AlphaSort
/*! \brief Another name for GRF_OffsetSort */
# define RGZ_OffsetSort GRF_OffsetSort
/*! \brief Another name for GRF_SETERR */
# define RGZ_SETERR GRF_SETERR
/*! \brief Another name for GRF_SETERR_2 */
# define RGZ_SETERR_2 GRF_SETERR_2
/*! \brief Another name for GRFERRTYPE */
# define RGZERRTYPE GRFERRTYPE

/*! \brief Macro to open a file without a callback function */
# define rgz_open(fname,error) rgz_callback_open(fname,error,NULL)

GRFEXPORT Rgz *rgz_callback_open (const char *fname, RgzError *error, int (*entryInfoFunc)(RgzFile*,RgzError*));
GRFEXPORT void *rgz_get (Rgz *rgz, const char *fname, uint32_t *size, RgzError *error);
GRFEXPORT void *rgz_index_get (Rgz *rgz, uint32_t index, uint32_t *size, RgzError *error);
GRFEXPORT int rgz_extract (Rgz *rgz, const char *grfname, const char *file, RgzError *error);
GRFEXPORT int rgz_index_extract (Rgz *rgz, uint32_t index, const char *file, RgzError *error);

GRFEXPORT void __rgz_free_memory__(void *buf);


GRFEXTERN_END


#endif /* !defined(__RGZ_H__) */
