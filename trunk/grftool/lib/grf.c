/*  libgrf - Library for reading GRF archives.
 *  Copyright (C) 2004  Hongli Lai <h.lai@chello.nl>
 *
 *  Based on grfio.[ch] from the eAthena source code.
 *  Copyright (C) ????  Whomever wrote grfio.[ch]
 *  (his name isn't mentioned in the source)
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

#include "grf.h"
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#ifdef __cplusplus
	extern "C" {
#endif /* __cplusplus */


/* Takes the first 4 bytes of array p and converts it into a 32-bit integer */
static inline unsigned long
getlong (unsigned char *p)
{
	return p[0] + p[1] * 256 + (p[2] + p[3] * 256) * 65536;
}


/* Convenience function for uncompressing data */
static int
decode_zip (Bytef* dest, uLongf* destLen, const Bytef* source, uLong sourceLen)
{
	z_stream stream;
	int err;

	stream.next_in = (Bytef *) source;
	stream.avail_in = (uInt) sourceLen;
	/* Check for source > 64K on 16-bit machine: */
	if ((uLong)stream.avail_in != sourceLen) return Z_BUF_ERROR;

	stream.next_out = dest;
	stream.avail_out = (uInt)*destLen;
	if ((uLong) stream.avail_out != *destLen) return Z_BUF_ERROR;

	stream.zalloc = (alloc_func) 0;
	stream.zfree = (free_func) 0;

	err = inflateInit (&stream);
	if (err != Z_OK) return err;

	err = inflate (&stream, Z_FINISH);
	if (err != Z_STREAM_END) {
		inflateEnd (&stream);
		return err == Z_OK ? Z_BUF_ERROR : err;
	}
	*destLen = stream.total_out;

	err = inflateEnd (&stream);
	return err;
}


/****************************************************
 * Functions and tables for decoding encoded data
 ****************************************************/

static unsigned char BitMaskTable[8] = {
	0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01
};

static char	BitSwapTable1[64] = {
	58, 50, 42, 34, 26, 18, 10,  2, 60, 52, 44, 36, 28, 20, 12,  4,
	62, 54, 46, 38, 30, 22, 14,  6, 64, 56, 48, 40, 32, 24, 16,  8,
	57, 49, 41, 33, 25, 17,  9,  1, 59, 51, 43, 35, 27, 19, 11,  3,
	61, 53, 45, 37, 29, 21, 13,  5, 63, 55, 47, 39, 31, 23, 15,  7
};
static char	BitSwapTable2[64] = {
	40,  8, 48, 16, 56, 24, 64, 32, 39,  7, 47, 15, 55, 23, 63, 31,
	38,  6, 46, 14, 54, 22, 62, 30, 37,  5, 45, 13, 53, 21, 61, 29,
	36,  4, 44, 12, 52, 20, 60, 28, 35,  3, 43, 11, 51, 19, 59, 27,
	34,  2, 42, 10, 50, 18, 58, 26, 33,  1, 41,  9, 49, 17, 57, 25
};
static char	BitSwapTable3[32] = {
	16,  7, 20, 21, 29, 12, 28, 17,  1, 15, 23, 26,  5, 18, 31, 10,
     2,  8, 24, 14, 32, 27,  3,  9, 19, 13, 30,  6, 22, 11,  4, 25
};

static unsigned char NibbleData[4][64]={
	{
		0xef, 0x03, 0x41, 0xfd, 0xd8, 0x74, 0x1e, 0x47,  0x26, 0xef, 0xfb, 0x22, 0xb3, 0xd8, 0x84, 0x1e,
		0x39, 0xac, 0xa7, 0x60, 0x62, 0xc1, 0xcd, 0xba,  0x5c, 0x96, 0x90, 0x59, 0x05, 0x3b, 0x7a, 0x85,
		0x40, 0xfd, 0x1e, 0xc8, 0xe7, 0x8a, 0x8b, 0x21,  0xda, 0x43, 0x64, 0x9f, 0x2d, 0x14, 0xb1, 0x72,
		0xf5, 0x5b, 0xc8, 0xb6, 0x9c, 0x37, 0x76, 0xec,  0x39, 0xa0, 0xa3, 0x05, 0x52, 0x6e, 0x0f, 0xd9,
	}, {
		0xa7, 0xdd, 0x0d, 0x78, 0x9e, 0x0b, 0xe3, 0x95,  0x60, 0x36, 0x36, 0x4f, 0xf9, 0x60, 0x5a, 0xa3,
		0x11, 0x24, 0xd2, 0x87, 0xc8, 0x52, 0x75, 0xec,  0xbb, 0xc1, 0x4c, 0xba, 0x24, 0xfe, 0x8f, 0x19,
		0xda, 0x13, 0x66, 0xaf, 0x49, 0xd0, 0x90, 0x06,  0x8c, 0x6a, 0xfb, 0x91, 0x37, 0x8d, 0x0d, 0x78,
		0xbf, 0x49, 0x11, 0xf4, 0x23, 0xe5, 0xce, 0x3b,  0x55, 0xbc, 0xa2, 0x57, 0xe8, 0x22, 0x74, 0xce,
	}, {
		0x2c, 0xea, 0xc1, 0xbf, 0x4a, 0x24, 0x1f, 0xc2,  0x79, 0x47, 0xa2, 0x7c, 0xb6, 0xd9, 0x68, 0x15,
		0x80, 0x56, 0x5d, 0x01, 0x33, 0xfd, 0xf4, 0xae,  0xde, 0x30, 0x07, 0x9b, 0xe5, 0x83, 0x9b, 0x68,
		0x49, 0xb4, 0x2e, 0x83, 0x1f, 0xc2, 0xb5, 0x7c,  0xa2, 0x19, 0xd8, 0xe5, 0x7c, 0x2f, 0x83, 0xda,
		0xf7, 0x6b, 0x90, 0xfe, 0xc4, 0x01, 0x5a, 0x97,  0x61, 0xa6, 0x3d, 0x40, 0x0b, 0x58, 0xe6, 0x3d,
	}, {
		0x4d, 0xd1, 0xb2, 0x0f, 0x28, 0xbd, 0xe4, 0x78,  0xf6, 0x4a, 0x0f, 0x93, 0x8b, 0x17, 0xd1, 0xa4,
		0x3a, 0xec, 0xc9, 0x35, 0x93, 0x56, 0x7e, 0xcb,  0x55, 0x20, 0xa0, 0xfe, 0x6c, 0x89, 0x17, 0x62,
		0x17, 0x62, 0x4b, 0xb1, 0xb4, 0xde, 0xd1, 0x87,  0xc9, 0x14, 0x3c, 0x4a, 0x7e, 0xa8, 0xe2, 0x7d,
		0xa0, 0x9f, 0xf6, 0x5c, 0x6a, 0x09, 0x8d, 0xf0,  0x0f, 0xe3, 0x53, 0x25, 0x95, 0x36, 0x28, 0xcb,
	}
};

typedef unsigned char BYTE;
typedef unsigned short WORD;
typedef unsigned long DWORD;


static void
NibbleSwap (BYTE *src, int len)
{
	for(; 0 < len; len--, src++) {
		*src = (*src >> 4) | (*src << 4);
	}
}


static void
BitConvert (BYTE *Src, char *BitSwapTable)
{
	int lop,prm;
	BYTE tmp[8];
	*(DWORD*)tmp=*(DWORD*)(tmp+4)=0;

	for(lop=0;lop!=64;lop++) {
		prm = BitSwapTable[lop]-1;
		if (Src[(prm >> 3) & 7] & BitMaskTable[prm & 7]) {
			tmp[(lop >> 3) & 7] |= BitMaskTable[lop & 7];
		}
	}
	*(DWORD*)Src     = *(DWORD*)tmp;
	*(DWORD*)(Src+4) = *(DWORD*)(tmp+4);
}

static void
BitConvert4(BYTE *Src)
{
	int lop,prm;
	BYTE tmp[8];
	tmp[0] = ((Src[7]<<5) | (Src[4]>>3)) & 0x3f;	// ..0 vutsr
	tmp[1] = ((Src[4]<<1) | (Src[5]>>7)) & 0x3f;	// ..srqpo n
	tmp[2] = ((Src[4]<<5) | (Src[5]>>3)) & 0x3f;	// ..o nmlkj
	tmp[3] = ((Src[5]<<1) | (Src[6]>>7)) & 0x3f;	// ..kjihg f
	tmp[4] = ((Src[5]<<5) | (Src[6]>>3)) & 0x3f;	// ..g fedcb
	tmp[5] = ((Src[6]<<1) | (Src[7]>>7)) & 0x3f;	// ..cba98 7
	tmp[6] = ((Src[6]<<5) | (Src[7]>>3)) & 0x3f;	// ..8 76543
	tmp[7] = ((Src[7]<<1) | (Src[4]>>7)) & 0x3f;	// ..43210 v

	for(lop=0;lop!=4;lop++) {
		tmp[lop] = (NibbleData[lop][tmp[lop*2]] & 0xf0)
		         | (NibbleData[lop][tmp[lop*2+1]] & 0x0f);
	}

	*(DWORD*)(tmp+4)=0;
	for(lop=0;lop!=32;lop++) {
		prm = BitSwapTable3[lop]-1;
		if (tmp[prm >> 3] & BitMaskTable[prm & 7]) {
			tmp[(lop >> 3) + 4] |= BitMaskTable[lop & 7];
		}
	}
	*(DWORD*)Src ^= *(DWORD*)(tmp+4);
}

static void
decode_des_etc(BYTE *buf,int len,int type,int cycle)
{
	int lop,cnt=0;
	if(cycle<3) cycle=3;
	else if(cycle<5) cycle++;
	else if(cycle<7) cycle+=9;
	else cycle+=15;

	for(lop=0;lop*8<len;lop++,buf+=8) {
		if(lop<20 || (type==0 && lop%cycle==0)){ // des
			BitConvert(buf,BitSwapTable1);
			BitConvert4(buf);
			BitConvert(buf,BitSwapTable2);
		} else {
			if(cnt==7 && type==0){
				int a;
				BYTE tmp[8];
				*(DWORD*)tmp     = *(DWORD*)buf;
				*(DWORD*)(tmp+4) = *(DWORD*)(buf+4);
				cnt=0;
				buf[0]=tmp[3];
				buf[1]=tmp[4];
				buf[2]=tmp[6];
				buf[3]=tmp[0];
				buf[4]=tmp[1];
				buf[5]=tmp[2];
				buf[6]=tmp[5];
				a=tmp[7];
				if(a==0x00) a=0x2b;
				else if(a==0x2b) a=0x00;
				else if(a==0x01) a=0x68;
				else if(a==0x68) a=0x01;
				else if(a==0x48) a=0x77;
				else if(a==0x77) a=0x48;
				else if(a==0x60) a=0xff;
				else if(a==0xff) a=0x60;
				else if(a==0x6c) a=0x80;
				else if(a==0x80) a=0x6c;
				else if(a==0xb9) a=0xc0;
				else if(a==0xc0) a=0xb9;
				else if(a==0xeb) a=0xfe;
				else if(a==0xfe) a=0xeb;
				buf[7]=a;
			}
			cnt++;
		}
	}
}

/* Decode an encoded filename; only needed for version 1 archives */
static unsigned char *
decode_filename (unsigned char *buf, int len)
{
	int i;

	for (i = 0; i < len; i += 8) {
		NibbleSwap (&buf[i], 8);
		BitConvert (&buf[i], BitSwapTable1);
		BitConvert4 (&buf[i]);
		BitConvert (&buf[i], BitSwapTable2);
	}
	return buf;
}


static void
debug (char *format, ...)
{
	#ifdef DEBUG
	FILE *f;
	va_list ap;

	f = fopen ("debug.txt", "a");
	if (!f) return;

	va_start (ap, format);
	vfprintf (f, format, ap);
	va_end (ap);
	fclose (f);
	#endif /* DEBUG */
}



/**********************
 * PUBLIC FUNCTIONS
 **********************/


GRFEXPORT Grf *
grf_open (const char *fname, GrfError *error)
{
	Grf *grf;
	FILE *f;
	long grf_size;
	unsigned char grf_header[46];

	if (!fname) {
		if (error) *error = GE_BADARGS;
		return NULL;
	}

	grf = (Grf *) calloc (sizeof (Grf), 1);
	if (!grf) {
		if (error) *error = GE_NOMEM;
		return NULL;
	}

	grf->f = f = fopen (fname, "rb");
	if (!f) {
		if (error) *error = GE_CANTOPEN;
		free (grf);
		return NULL;
	}

	debug ("----------------\n"
		"sprite_load(%s)\n", fname);

	/* Check whether the file has the 'Master of Magic' header */
	fread (grf_header, 1, 46, f);
	if (strncmp ((char *) grf_header, "Master of Magic", 15) != 0) {
		/* Not a valid GRF file */
		if (error) *error = GE_INVALID;
		free (grf);
		fclose (f);
		return NULL;
	}

	grf->version = getlong (grf_header + 42) >> 8;
	debug ("Version: %d\n", grf->version);

	/* Get the size of the file; we'll need it later */
	fseek (f, 0, SEEK_END);
	grf_size = ftell (f);
	debug ("Size:\t\t\t%ld bytes\n"
		"File list offset:\t%ld\n",
		grf_size, 46 + getlong (grf_header + 30));

	/* Now seek to the beginning of the file list header. */
	if (fseek (f, 46 + getlong (grf_header + 30), SEEK_SET) != 0) {
		/* Cannot seek to specified offset; corrupted? */
		if (error) *error = GE_CORRUPTED;
		free (grf);
		fclose (f);
		return NULL;
	}


	if (grf->version == 1) {
		unsigned long filelist_size;
		unsigned char *filelist_data;
		unsigned long entry, index, offset;
		unsigned long filelist_entries;
		unsigned long directory_index_count;

		filelist_size = grf_size - ftell (f);
		debug ("File list size: %ld bytes\n", filelist_size);

		filelist_data = (unsigned char *) calloc (1, filelist_size);
		if (!filelist_data) {
			fclose (f);
			if (error) *error = GE_NOMEM;
			free (grf);
			return NULL;
		}

		fread (filelist_data, 1, filelist_size, f);


		/* The file list may contain directory indices. We don't want that,
		   so we first calculate how many directory index entries there are.
		   Then we calculate how big grf->files has to be. */
		filelist_entries = getlong (grf_header + 38) - getlong (grf_header + 34) - 7;
		for (entry = 0, offset = 0, directory_index_count = 0; entry < filelist_entries; entry++) {
			unsigned long ofs2;
			int type;

			ofs2 = offset + getlong (filelist_data + offset) + 4;
			type = filelist_data[ofs2 + 12];
			if (type == 0)
				directory_index_count++;
			offset = ofs2 + 17;
		}


		grf->nfiles = filelist_entries - directory_index_count;
		debug ("nfiles: %d\n"
			"Allocating %d bytes of memory for file list structure.\n",
			grf->nfiles,
			sizeof (GrfFile) * grf->nfiles);
		grf->files = (GrfFile *) calloc (sizeof (GrfFile), grf->nfiles);

		for (entry = 0, index = 0, offset = 0; entry < filelist_entries; entry++) {
			unsigned long ofs2;
			int type;

			ofs2 = offset + getlong (filelist_data + offset) + 4;
			type = filelist_data[ofs2 + 12];

			/* Type 0 is a directory index; skip that */
			if (type != 0) {
				unsigned char *name;			/* Filename */
				unsigned long compressed_len;		/* Compressed file size */
				unsigned long compressed_len_aligned;	/* Not sure what this is but it's used for decoding the data */
				unsigned long real_len;			/* Real (uncompressed) file size */
				unsigned long pos;			/* Position of the real file data */
				long cycle;
				char *ext;

				name = decode_filename (filelist_data + offset + 6, filelist_data[offset] - 6);
				compressed_len_aligned = getlong (filelist_data + ofs2 + 4) - 37579;
				real_len = getlong (filelist_data + ofs2 + 8);
				pos = getlong (filelist_data + ofs2 + 13) + 46;

				/* Detect the file's "cycle". This contains information about how the file entry's encoded */
				compressed_len = 0;
				cycle = 0;
				/* Only files with an extension are encoded */
				if ((ext = strrchr ((const char *) name, '.')) != NULL) {
					compressed_len = getlong (filelist_data + ofs2) - getlong (filelist_data + ofs2 + 8) - 715;
					if (strcasecmp (ext, ".gnd") != 0 && strcasecmp (ext, ".gat") != 0
					 && strcasecmp (ext, ".act") != 0 && strcasecmp (ext, ".str") != 0) {
						unsigned long i;
						for (i = 10, cycle = 1; compressed_len >= i; i *= 10, cycle++);
					}
				}

				grf->files[index].name = strdup ((const char *) name);
				grf->files[index].compressed_len = compressed_len;
				grf->files[index].compressed_len_aligned = compressed_len_aligned;
				grf->files[index].real_len = real_len;
				grf->files[index].pos = pos;
				grf->files[index].cycle = cycle;
				grf->files[index].type = type;

				index++;
			}

			offset = ofs2 + 17;
		}
		free (filelist_data);

	} else if (grf->version == 2) {
		/* The file list header contains two sections:
		   1. Information about the number of files and how big the file list data is.
		   2. The actual file list itself (compressed).
		 */
		unsigned char size_header[8];	/* The header that contains information about sizes */
		uLongf compressed_size;		/* Size of the compressed file list data */
		uLongf decompressed_size;	/* Size of the decompressed file list data */

		unsigned char *rBuf;		/* Temporarily store the compress file list data */
		unsigned char *filelist_data;	/* The decompressed file list data */

		unsigned long entry;
		int offset;


		/* Get size information */
		fread (size_header, 1, 8, f);
		compressed_size = getlong (size_header);
		decompressed_size = getlong (size_header + 4);
		debug ("File header compressed:\t\t%ld bytes\n"
			"File header decompressed:\t%ld bytes\n",
			compressed_size, decompressed_size);

		if (compressed_size > (uLongf) (grf_size - ftell (f))) {
			fclose (f);
			if (error) *error = GE_CORRUPTED;
			free (grf);
			return NULL;
		}

		/* Allocate a buffer to store the raw (compressed) file list data */
		rBuf = (unsigned char *) malloc (compressed_size);
		if (!rBuf) {
			fclose (f);
			if (error) *error = GE_NOMEM;
			free (grf);
			return NULL;
		}
		fread (rBuf, 1, compressed_size, f);

		/* Allocate a buffer to store the decompressed file list data */
		filelist_data = (unsigned char *) malloc (decompressed_size);
		if (!filelist_data) {
			free (rBuf);
			free (filelist_data);
			fclose (f);
			if (error) *error = GE_NOMEM;
			free (grf);
			return NULL;
		}

		/* Decompress the file list data */
		decode_zip (filelist_data, &decompressed_size, rBuf, compressed_size);
		free (rBuf);

		/* Store the entire file list into an array */
		grf->nfiles = getlong (grf_header + 0x26) - 7;
		debug ("nfiles: %ld\n"
			"Allocating %d bytes of memory for file list structure.\n",
			grf->nfiles,
			sizeof (GrfFile) * grf->nfiles);

		grf->files = (GrfFile *) calloc (sizeof (GrfFile), grf->nfiles);
		if (!grf->files) {
			free (filelist_data);
			fclose (f);
			free (grf);
			if (error) *error = GE_NOMEM;
			return NULL;
		}

		debug ("Reading file list...\n");

		for (entry = 0, offset = 0; entry < grf->nfiles; entry++){
			char *name;	/* This entry's filename */
			int type;
			int ofs2;

			name = strdup ((char *) (filelist_data + offset));
			ofs2 = offset + strlen (name) + 1;
			type = filelist_data[ofs2 + 12];

			if (type == 1 || type == 3 || type == 5) {
				unsigned long compressed_len;		/* Compressed file size */
				unsigned long compressed_len_aligned;	/* Not sure what this is but it's used for decoding the data */
				unsigned long real_len;			/* Real (uncompressed) file size */
				unsigned long pos;			/* Position of the real file data */
				long cycle;

				compressed_len = getlong (filelist_data + ofs2);
				compressed_len_aligned = getlong (filelist_data + ofs2 + 4);
				real_len = getlong (filelist_data + ofs2 + 8);
				pos = getlong (filelist_data + ofs2 + 13) + 0x2e;

				/* Detect the file's "cycle". This contains information about how the file entry's encoded */
				if (type == 3) {
					unsigned long i;
					for (i = 10, cycle = 1; compressed_len >= i; i *= 10, cycle++);
				} else if (type == 5) {
					cycle = 0;
				} else {	/* if (type == 1) */
					cycle = -1;
				}

				grf->files[entry].compressed_len = compressed_len;
				grf->files[entry].compressed_len_aligned = compressed_len_aligned;
				grf->files[entry].real_len = real_len;
				grf->files[entry].pos = pos;
				grf->files[entry].cycle = cycle;
			}

			grf->files[entry].name = name;
			grf->files[entry].type = type;

			/* Calculate next entry's offset */
			offset += strlen ((char *) (filelist_data + offset)) + 18;
		}

		free (filelist_data);
		debug ("Done!\n");

	} else {
		if (error) *error = GE_NSUP;
		free (grf);
		fclose (f);
		return NULL;
	}

	grf->filename = strdup (fname);
	return grf;
}


GRFEXPORT GrfFile *
grf_find (Grf *grf, char *fname, unsigned long *index)
{
	unsigned long i;

	if (!grf || !fname) return NULL;

	for (i = 0; i < grf->nfiles; i++) {
		if (strcmp (grf->files[i].name, fname) == 0) {
			if (index) *index = i;
			return &(grf->files[i]);
		}
	}
	return NULL;
}


GRFEXPORT void *
grf_get (Grf *grf, char *fname, unsigned long *size, GrfError *error)
{
	unsigned long index;

	if (!grf || !fname) {
		if (error) *error = GE_BADARGS;
		return NULL;
	}

	if (!grf_find (grf, fname, &index)) {
		if (error) *error = GE_NOTFOUND;
		return NULL;
	}
	return grf_index_get (grf, index, size, error);
}


GRFEXPORT void *
grf_index_get (Grf *grf, unsigned long index, unsigned long *size, GrfError *error)
{
	GrfFile *file;
	unsigned char *buf, *decbuf;

	if (!grf) {
		if (error) *error = GE_BADARGS;
		return NULL;
	}

	if (index < 0 || index >= grf->nfiles) {
		if (error) *error = GE_INDEX;
		return NULL;
	}

	file = &(grf->files[index]);
	buf = (unsigned char *) calloc (file->compressed_len_aligned + 1024, 1);
	if (!buf) {
		if (error) *error = GE_NOMEM;
		return NULL;
	}
	fseek (grf->f, file->pos, SEEK_SET);
	fread (buf, 1, file->compressed_len_aligned, grf->f);

	if (file->type == 1 || file->type == 3 || file->type == 5) {
		uLongf len;

		decbuf = (unsigned char *) calloc (file->real_len + 1024, 1);

		/* Some data are encoded. They must be decoded first before they can be decompressed. */
		if (file->cycle >= 0) {
			decode_des_etc (buf, file->compressed_len_aligned,
				file->cycle == 0, file->cycle);
		}

		/* Now, decompress the data and return it */
		len = file->real_len;
		decode_zip (decbuf, &len, buf, file->compressed_len);
		if (size) *size = len;

		if (len != file->real_len) {
			fprintf (stderr, "decode_zip size miss match err: %ld != %ld\n", len, file->real_len);
		}

		free (buf);

	} else
		decbuf = buf;

	return decbuf;
}


GRFEXPORT int
grf_extract (Grf *grf, char *fname, const char *writeToFile, GrfError *error)
{
	unsigned long index;

	if (!grf || !fname) {
		if (error) *error = GE_BADARGS;
		return 0;
	}

	if (!grf_find (grf, fname, &index)) {
		if (error) *error = GE_NOTFOUND;
		return 0;
	}
	return grf_index_extract (grf, index, writeToFile, error);
}


GRFEXPORT int
grf_index_extract (Grf *grf, unsigned long index, const char *writeToFile, GrfError *error)
{
	void *buf;
	unsigned long size;
	FILE *f;

	if (!writeToFile) {
		if (error) *error = GE_BADARGS;
		return 0;
	}

	buf = grf_index_get (grf, index, &size, error);
	if (!buf) return 0;

	f = fopen (writeToFile, "wb");
	if (!f) {
		free (buf);
		if (error) *error = GE_WRITE;
		return 0;
	}

	fwrite (buf, size, 1, f);
	fclose (f);
	free (buf);
	return 1;
}


GRFEXPORT void
grf_free (Grf *grf)
{
	unsigned long i;

	if (!grf) return;
	if (grf->f) fclose (grf->f);
	if (grf->filename) free (grf->filename);

	if (grf->files) {
		for (i = 0; i < grf->nfiles; i++) {
			if (grf->files[i].name)
				free (grf->files[i].name);
		}
		free (grf->files);
	}

	free (grf);
}


GRFEXPORT const char *
grf_strerror (GrfError error)
{
	switch (error) {
	case GE_BADARGS:
		return "Bad arguments passed to function.";
	case GE_CANTOPEN:
		return "Cannot open file.";
	case GE_INVALID:
		return "Not a valid GRF archive.";
	case GE_CORRUPTED:
		return "The GRF archive appears to be corrupted.";
	case GE_NOMEM:
		return "Not enough free memory.";
	case GE_NSUP:
		return "GRF archives of this version is not supported.";
	case GE_NOTFOUND:
		return "File not found inside GRF file.";
	case GE_INDEX:
		return "Invalid index.";
	case GE_WRITE:
		return "Cannot write to destination file.";
	default:
		return "Unknown error.";
	};
}


#ifdef __cplusplus
	}
#endif /* __cplusplus */
