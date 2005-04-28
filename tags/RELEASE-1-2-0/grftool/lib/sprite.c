/*  libsprite - Library for reading Ragnarok Online sprite files.
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sprite.h"

#ifdef __cplusplus
	extern "C" {
#endif /* __cplusplus */


/***********************
 * UTILITY FUNCTIONS
 ***********************/

/* StrBuf implements a string buffer that can dynamically grow. */
typedef struct {
	unsigned char *str;
	int len;
} StrBuf;


static StrBuf *
strbuf_new ()
{
	StrBuf *buf;

	buf = (StrBuf *) calloc (sizeof (StrBuf), 1);
	buf->str = (unsigned char *) strdup ("");
	return buf;
}


static void
strbuf_append (StrBuf *buf, unsigned char *data, int len)
{
	int offset;

	if (len <= -1)
		len = strlen ((char *) data);
	offset = buf->len;
	buf->len += len;
	buf->str = (unsigned char *) realloc (buf->str, buf->len + 1);
	memcpy (buf->str + offset, data, len);
	buf->str[buf->len] = '\0';
}


static void
strbuf_prepend (StrBuf *buf, unsigned char *data, int len)
{
	unsigned char *str;

	if (len <= -1)
		len = strlen ((char *) data);
	str = (unsigned char *) calloc (1, buf->len + len + 1);
	memcpy (str, data, len);
	memcpy (str + len, buf->str, buf->len);
	free (buf->str);
	buf->str = str;
	buf->len += len;
}


static void
strbuf_free (StrBuf *buf, int free_str)
{
	if (buf) {
		if (free_str && buf->str)
			free (buf->str);
		free (buf);
	}
}


/* Repeat the string str num times.
   Example: strrepeat("A", strlen("A"), 3) -> "AAA" */
static char *
strrepeat (char *str, int len, int num)
{
	char *ret;
	int i;

	if (len <= -1)
		len = strlen (str);
	ret = (char *) calloc (1, len * num + 1);
	for (i = 0; i < num; i++) {
		memcpy (ret + len * num, str, len);
	}
	return ret;
}


static unsigned char *
rle_decode(unsigned char *data, int datalen, int width, int *decoded_size)
{
	StrBuf *buf, *retbuf;
	unsigned char *ret, *tmp;
	int extra, x;

	buf = strbuf_new ();
	retbuf = strbuf_new ();

	extra = 4 - (width % 4);
	if (extra == 4) extra = 0;

	for (x = 0; x < datalen; x++) {
		if (data[x] == 0) {
			x++;
			tmp = (unsigned char *) strrepeat ("", 1, (int) data[x]);
			strbuf_append (buf, tmp, data[x]);
			free (tmp);
		} else
			strbuf_append (buf, &(data[x]), 1);
	}

	for (x = 0; x < buf->len; x += width) {
		if (extra > 0) {
			tmp = (unsigned char *) strrepeat ("", 1, extra);
			strbuf_prepend (retbuf, tmp, extra);
			free (tmp);
		}
		strbuf_prepend (retbuf, buf->str + x, width);
	}

	ret = retbuf->str;
	if (decoded_size) *decoded_size = retbuf->len;
	strbuf_free (retbuf, 0);
	strbuf_free (buf, 1);
	return ret;
}


static unsigned char *
reverse_palette (unsigned char *palette, int palettelen, int *returnsize)
{
	StrBuf *retbuf;
	unsigned char *ret;
	int x;

	retbuf = strbuf_new ();
	for (x = 0; x < palettelen; x += 4) {
		unsigned char tmp[4];

		tmp[0] = palette[x + 2];
		tmp[1] = palette[x + 1];
		tmp[2] = palette[x];
		tmp[3] = '\0';
		strbuf_append (retbuf, tmp, 4);
	}

	ret = retbuf->str;
	if (returnsize) *returnsize = retbuf->len;
	strbuf_free (retbuf, 0);
	return ret;
}


/**********************
 * PUBLIC FUNCTIONS
 **********************/


SPREXPORT Sprite *
sprite_open (const char *fname, SpriteError *error)
{
	FILE *f;
	long size;
	unsigned char *data;
	Sprite *sprite;

	if (!fname) {
		if (error) *error = SE_BADARGS;
		return NULL;
	}

	f = fopen ("4_deviruchi.spr", "rb");
	if (!f) {
		if (error) *error = SE_CANTOPEN;
		return NULL;
	}

	fseek (f, 0, SEEK_END);
	size = ftell (f);
	fseek (f, 0, SEEK_SET);
	data = malloc (size);
	fread (data, size, 1, f);
	fclose (f);

	sprite = sprite_open_from_data (data, size, error);
	if (sprite)
		sprite->filename = strdup (fname);
	return sprite;
}


SPREXPORT Sprite *
sprite_open_from_data (const unsigned char *data, unsigned int size, SpriteError *error)
{
	Sprite *sprite;
	unsigned char palette[1024], buf[4];
	int i, pos, palette_size;


	/* Check buffer size; a valid sprite file is at least:
	   Magic header       4 bytes
           Number of frames   2 bytes
           Palette            1024 bytes
           --------------------------
           Total              1030 bytes
         */
	if (size < 1030) {
		if (error) *error = SE_INVALID;
		return NULL;
	}

	/* Check file's "magic header", which is 4 bytes */
	if (memcmp (data, "SP\001\002", 4) != 0) {
		if (error) *error = SE_INVALID;
		return NULL;
	}

	/* Read the number of sprites */
	sprite = (Sprite *) calloc (sizeof (Sprite), 1);
	sprite->nimages = (data[5] << 8) + data[4];

	/* Read palette */
	memcpy (&palette, data + size - 1024, 1024);
	sprite->palette = (SpritePalette *) reverse_palette (palette, 1024, &palette_size);
	sprite->palette_size = palette_size;

	/* Now read the actual sprite data */
	sprite->images = (SpriteImage *) calloc (sizeof (SpriteImage), sprite->nimages);
	pos = 8;
	for (i = 0; i < sprite->nimages; i++) {
		int width, height, compressed_len, pixels_size;
		unsigned char *pixels;

		buf[0] = data[pos];
		buf[1] = data[pos + 1];
		pos += 2;
		width = (buf[1] << 8) + buf[0];

		buf[0] = data[pos];
		buf[1] = data[pos + 1];
		pos += 2;
		height = (buf[1] << 8) + buf[0];

		buf[0] = data[pos];
		buf[1] = data[pos + 1];
		pos += 2;
		compressed_len = (buf[1] << 8) + buf[0];

		pixels = rle_decode ((unsigned char *) data + pos, compressed_len, width, &pixels_size);
		pos += compressed_len;

		sprite->images[i].data = pixels;
		sprite->images[i].len = pixels_size;
		sprite->images[i].width = width;
		sprite->images[i].height = height;
	}

	return sprite;
}


SPREXPORT void
sprite_free (Sprite *sprite)
{
	if (sprite) {
		int i;

		if (sprite->filename)
			free (sprite->filename);
		if (sprite->images)
		{
			for (i = 0; i < sprite->nimages; i++)
				if (sprite->images[i].data)
					free (sprite->images[i].data);
			free (sprite->images);
		}
		if (sprite->palette)
			free (sprite->palette);
		free (sprite);
	}
}


SPREXPORT void *
sprite_to_bmp (Sprite *sprite, int i, int *size, SpriteError *error)
{
	StrBuf *buf;
	unsigned long file_size, offset, tmp;
	unsigned short tmp2;
	void *data;

	/* Sanity check arguments */
	if (!sprite || i < 0) {
		if (error) *error = SE_BADARGS;
		return NULL;
	}

	if (i >= sprite->nimages) {
		if (error) *error = SE_INDEX;
		return NULL;
	}


	buf = strbuf_new ();

	/* Bitmap file header */
	offset = 54 + sprite->palette_size;
	file_size = offset + sprite->images[i].len;
	strbuf_append (buf, (unsigned char *) "BM", 2);		/* Magic */
	strbuf_append (buf, (unsigned char *) &file_size, 4);	/* File size */
	strbuf_append (buf, (unsigned char *) "\0\0\0\0", 4);	/* Reserved */
	strbuf_append (buf, (unsigned char *) &offset, 4);	/* Offset to image data */

	/* Bitmap info header */
	tmp = 40;
	strbuf_append (buf, (unsigned char *) &tmp, 4);				/* Size of the info header */
	strbuf_append (buf, (unsigned char *) &(sprite->images[i].width), 4);	/* Width */
	strbuf_append (buf, (unsigned char *) &(sprite->images[i].height), 4);	/* Height */
	tmp2 = 1;
	strbuf_append (buf, (unsigned char *) &tmp2, 2);	/* Planes */
	tmp2 = 8;
	strbuf_append (buf, (unsigned char *) &tmp2, 2);	/* Bit count */

	tmp = 0;
	strbuf_append (buf, (unsigned char *) &tmp, 4);		/* Compression type */
	tmp = sprite->images[i].len;
	strbuf_append (buf, (unsigned char *) &tmp, 4);		/* Pixel data size */
	tmp = 0;
	strbuf_append (buf, (unsigned char *) &tmp, 4);		/* X pixels per meter */
	strbuf_append (buf, (unsigned char *) &tmp, 4);		/* Y pixels per meter */
	tmp = 256;
	strbuf_append (buf, (unsigned char *) &tmp, 4);		/* Number of colors */
	tmp = 0;
	strbuf_append (buf, (unsigned char *) &tmp, 4);		/* Number of important colors */

	/* Palette */
	strbuf_append (buf, (unsigned char *) sprite->palette, sprite->palette_size);
	/* Pixel data */
	strbuf_append (buf, sprite->images[i].data, sprite->images[i].len);


	data = buf->str;
	if (size) *size = buf->len;
	strbuf_free (buf, 0);
	return data;
}


SPREXPORT int
sprite_to_bmp_file (Sprite *sprite, int i, const char *writeToFile, SpriteError *error)
{
	void *buf;
	int bufsize;
	FILE *f;

	if (!writeToFile) {
		if (error) *error = SE_BADARGS;
		return 0;
	}

	buf = sprite_to_bmp (sprite, i, &bufsize, error);
	if (!buf) return 0;

	f = fopen (writeToFile, "wb");
	if (!f) {
		if (error) *error = SE_CANTWRITE;
		return 0;
	}

	fwrite (buf, 1, bufsize, f);
	fclose (f);
	return 1;
}


SPREXPORT void *
sprite_to_rgb (Sprite *sprite, int i, int *size, SpriteError *error)
{
	unsigned char *pixels;
	int rowstride, x, y, j;

	if (!sprite || i < 0) {
		if (error) *error = SE_BADARGS;
		return NULL;
	}

	if (i >= sprite->nimages) {
		if (error) *error = SE_INDEX;
		return NULL;
	}


	rowstride = sprite->images[i].len / sprite->images[i].height;
	pixels = (unsigned char *) calloc (3, sprite->images[i].height * rowstride);
	if (size) *size = sprite->images[i].height * rowstride * 3;

	j = 0;
	for (y = 0; y < sprite->images[i].height; y++) {
		for (x = 0; x < sprite->images[i].width; x++) {
			int d;	/* Raw bitmap data index */
			int p;	/* Palette index */

			d = (sprite->images[i].height - y - 1) * rowstride + x;
			p = sprite->images[i].data[d];

			pixels[j]	= sprite->palette[p].r;
			pixels[j + 1]	= sprite->palette[p].g;
			pixels[j + 2]	= sprite->palette[p].b;
			j += 3;
		}
	}

	return pixels;
}


#ifdef __cplusplus
	}
#endif /* __cplusplus */
