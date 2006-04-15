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

#ifndef _HSTRING_H_
#define _HSTRING_H_

/**
 * A string data structure, which automatically grows as necessary.
 * This object can be used as a buffer, or a NULL-terminated string.
 * Even if you append non-NULL terminated data, it will ensure that
 * the internal buffer is NULL-terminated.
 */
typedef struct {
	/**
	 * The string.
	 * @invariant str != NULL       <br>
	 *            str[len] == 0
	 */
	char *str;
	/**
	 * Length of the string, not including terminating NULL.
	 * @invariant len == (memory reserved for str) - 1
	 */
	unsigned int len;
} HString;


/**
 * Create a new HString object.
 *
 * @param initValue The initial value for this HString. This string is
 *                  copied, so you can free it after calling this function.
 * @param len The length of initValue (not including terminating NULL if
 *            its a string), or -1 if you want h_string_new() to
 *            automatically calculate it with strlen().
 * @return A new HString object.
 * @pre initValue != NULL
 * @post
 *    result->str equals initValue                            <br>
 *    result->len == (len < 0) ? strlen (initValue) : len
 */
HString *h_string_new (const char *initValue, int len);

/**
 * Append a string to the end of a HString.
 *
 * @param str The HString object to modify.
 * @param append The string to append.
 * @param len The length of append (not including terminating NULL if its a string), or -1
 *            if you want it to be automatically calculated with strlen().
 * @pre
 *    str != NULL       <br>
 *    append != NULL
 * @post
 *    str->str equals old->str + append                               <br>
 *    str->len == old->len + ((len < 0) ? strlen (append) : len)      <br>
 *    str->str[str->len] == 0
 */
void     h_string_append (HString *str, const char *append, int len);

/**
 * Append a single character to the end of a HString.
 *
 * @param str The HString object to modify.
 * @param c The character to append.
 * @pre str != NULL
 * @post
 *    str->str equals old->str + c     <br>
 *    str->len == old->len + 1         <br>
 *    str->str[str->len] == 0
 */
void     h_string_append_c (HString *str, char c);

/**
 * Free a HString object.
 *
 * @param str The HString object to free.
 * @param free_content Whether to free the string conten too.
 * @pre str != NULL
 */
void     h_string_free (HString *str, int free_content);

#endif /* HSTRING_H_ */
