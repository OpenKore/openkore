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

#include "Exception.h"
#include "Object.h"
#include "Pointer.h"
#include "IO/All.h"
#include "Net/All.h"
#include "Threading/All.h"

/**
 * @defgroup Base Base
 * @defgroup Threading Concurrency & Threading
 * @defgroup IO Input/Output
 * @defgroup Net Networking
 */

/**
 * @mainpage OpenKore Standard Library
 * The OpenKore Standard Library (OSL) is a portability and utility library for
 * C++. Highlights:
 * - Usage of modern C++ features such as templates and namespaces.
 * - Small and statically linkable. No need for external DLLs.
 * - Easy to integrate with your project. You can just copy the source files to
 *   your project, and it should compile out-of-the-box without configuring macros
 *   or anything like that.
 * - Supports POSIX (Unix/Linux) and Win32.
 * - Well-documented and easy-to-read code.
 * - Unit tested to maximize stability and to prevent regressions.
 *
 * Read the <a href="modules.html">Modules</a> page to get started.
 *
 *
 * @section Namespaces
 * All classes in the OpenKore Standard Library are in the <tt>OSL</tt> namespace.
 * So be sure to include the namespace in your source code:
 * @code
 * #include <OSL/Whatever.h>
 * using namespace OSL;
 * @endcode
 *
 *
 * @section Header-Files Header includes
 * Most classes in the OSL are contained in their own
 * header file. You can:
 * -# include each header file individually,
 * -# include a group of header files at once,
 * -# or you can include the entire OSL at once.
 *
 * For case 2, include the 'All.h' header for the appropriate group. For example:
 * @code
 * #include <OSL/IO/All.h>
 * #include <OSL/Net/All.h>
 * @endcode
 *
 * For case 3, include the 'All.h' header in the base directory:
 * @code
 * #include <OSL/All.h>
 * @endcode
 */
