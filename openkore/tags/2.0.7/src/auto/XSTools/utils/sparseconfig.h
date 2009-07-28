// Copyright (c) 2005, Google Inc.
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
// 
//     * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//     * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#ifdef _MSC_VER
	#define HASH_NAMESPACE  stdext
	#define HASH_FUN_H   <hash_map>
	// In windows-land, hash<> is called hash_compare<> (from xhash.h)
	#define hash  hash_compare
#else
	/* the location of <hash_fun.h>/<stl_hash_fun.h> */
	#define HASH_FUN_H <ext/hash_fun.h>
	/* the namespace of hash_map/hash_set */
	#define HASH_NAMESPACE __gnu_cxx
#endif

/* Define to 1 if the system has the type `long long'. */
#define HAVE_LONG_LONG 1

/* the namespace where STL code like vector<> is defined */
#define STL_NAMESPACE std

/* Stops putting the code inside the Google namespace */
#define _END_GOOGLE_NAMESPACE_ }

/* Puts following code inside the Google namespace */
#define _START_GOOGLE_NAMESPACE_ namespace google {

#ifndef GCC_VERSION
#define GCC_VERSION (__GNUC__ * 10000 \
                   	 + __GNUC_MINOR__ * 100 \
                   	 + __GNUC_PATCHLEVEL__)
#endif
/* the location of <hash_fun.h>/<stl_hash_fun.h> */
#if GCC_VERSION < 40300
	#define HASH_FUN_H <ext/hash_fun.h>
#else
	#define HASH_FUN_H <backward/hash_fun.h>
#endif
