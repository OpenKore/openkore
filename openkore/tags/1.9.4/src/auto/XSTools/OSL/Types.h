/*
 *  OpenKore C++ Standard Library
 *  Copyright (C) 2006  VCL
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 *  MA  02110-1301  USA
 */

#ifndef _OSL_TYPES_H_
#define _OSL_TYPES_H_

/**
 * Various basic data types, for easy-of-use and portability.
 *
 * @defgroup BasicTypes Basic Data types
 * @ingroup Base
 */

#if defined(IN_DOXYGEN)

	/**
	 * An unsigned integer which is guaranteed to be exactly 32 bits on all platforms.
	 * @ingroup BasicTypes
	 */
	typedef platform_specific_type uint32_t;

	/**
	 * An unsigned integer which is guaranteed to be exactly 16 bits on all platforms.
	 * @ingroup BasicTypes
	 */
	typedef platform_specific_type uint16_t;

	/**
	 * An unsigned integer which is guaranteed to be exactly 8 bits on all platforms.
	 * @ingroup BasicTypes
	 */
	typedef platform_specific_type uint8_t;

#elif defined(WIN32)

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

#else /* if !defined(WIN32) */

	#include <inttypes.h>

#endif

#endif
