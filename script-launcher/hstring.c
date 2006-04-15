/*
 * Hongli's Utility Library
 * Dynamic strings
 *
 * Copyright (c) 2005, Hongli Lai
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 * Neither the name of the Hongli's Utility Library nor the names of its
 * contributors may be used to endorse or promote products derived from this
 * software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "hstring.h"


static size_t
get_str_len (const char *str, int len)
{
	if (len < 0)
		return strlen (str);
	else
		return len;
}

HString *
h_string_new (const char *initValue, int len)
{
	HString *str;
	unsigned int l;

	str = (HString *) malloc (sizeof (HString));
	l = get_str_len (initValue, len);
	str->str = (char *) malloc (l + 1);
	memcpy (str->str, initValue, l);
	str->str[l] = '\0';
	str->len = l;
	return str;
}

void
h_string_append (HString *str, const char *append, int len)
{
	int l;

	l = get_str_len (append, len);
	str->str = (char *) realloc (str->str, str->len + l + 1);
	memcpy (str->str + str->len, append, l);
	str->len += l;
	str->str[str->len] = '\0';
}

void
h_string_append_c (HString *str, char c)
{
	h_string_append (str, &c, 1);
}

void
h_string_free (HString *str, int free_content)
{
	if (free_content)
		free (str->str);
	free (str);
}
