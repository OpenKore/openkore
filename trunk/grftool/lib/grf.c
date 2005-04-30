/*
 *  libgrf
 *  grf.c - read and manipulate GRF/GPF files
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
 *
 * Notes:
 * GRF - GRAVITY Resource File (usually using version 0x1xx)
 * GPF - GRAVITY Patch File (usually using version 0x2xx)
 *
 * A couple letters appear while generating keys for DES. In order of
 * appearance (as they are used, not from top to bottom of this code)
 * they are (P, r, e), (n, k) with the first set used to decrypt 0x101
 * and 0x102 file names, and the 2nd set used to decrypt data...
 * Prenk = Prank? Lame ass GRAVITY joke I guess.
 */

#include "grftypes.h"
#include "grfsupport.h"
#include "grfcrypt.h"
#include "grf.h"

#include <zlib.h>
#include <string.h>
#include <stdlib.h>

GRFEXTERN_BEGIN

/* Headers */
#define GRF_HEADER		"Master of Magic"
#define GRF_HEADER_LEN		(sizeof(GRF_HEADER) - 1)	/* -1 to strip
								 * null terminator
								 */
#define GRF_HEADER_MID_LEN	(sizeof(GRF_HEADER) + 0xE)	/* -1 + 0xF */
#define GRF_HEADER_FULL_LEN	(sizeof(GRF_HEADER) + 0x1E)	/* -1 + 0x1F */


/** Special file extensions.
 *
 * Files with these extentions are handled differently in GPFs.
 */
static const char specialExts[][5] = {
	".gnd",
	".gat",
	".act",
	".str"
};

static const char crypt_watermark[] = { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E };


/*********************
 * Private Functions *
 *********************/

/** Simplicity Macro.
 *
 * Macro to make it easier to call GRF_CheckExtFunc
 */
#define GRF_CheckExt(a, b) GRF_CheckExtFunc(a, b, sizeof(b))


/** Private function to check filename extensions.
 *
 * Checks the last 4 characters of a filename for
 * a specific extension
 *
 * @param filename The filename to search for the extension
 * @param extlist A list of each extension to search for
 * @param listsize The number of extensions in the list
 * @return 0 if none of the extensions match, 1 if a match was found
 */
static int
GRF_CheckExtFunc(const char *filename, const char extlist[][5], size_t listsize)
{
	uint32_t i;

	if (listsize < 1)
		return 0;

	/* Find the last X bytes of the filename, where X is extension size */
	i = (uint32_t) strlen(filename);
	if (i < 4)
		return 0;
	filename += (i - 4);

	/* Check if the file has any of the extensions */
	for (i = 0; i< listsize; i++)
		if (strcasecmp(filename, extlist[i]) == 0)
			return 1;

	return 0;
}


#ifdef GRF_FIXED_KEYSCHEDULE
/** Private function to convert a int32_t into an ASCII character string.
 *
 * @warning dst is not checked for sanity (valid pointer, max length, etc)
 *
 * @param dst A character string to store the data in
 * @param src int32_t to be converted into an ASCII string
 * @param base The base to use while converting
 * @return A duplicate pointer to the data
 */
static char *
GRF_ltoa(char *dst, int32_t src, uint8_t base)
{
	char *dst2,*orig;
	uint8_t num;

	/* Grab the original pointer */
	orig=dst;

	/* Add negative sign if needed */
	if (base==0xA && src<0) {
		*dst=0x2D;
		dst++;
		src=-src;
	}

	/* Going to need another pointer to dst, to reverse the string */
	dst2=dst;

	/* Generate the string with digits in wrong order */
	while (src>0) {
		/* Grab the next digit */
		num=src%base;
		src/=base;

		/* Convert the digit to an ASCII character */
		if (num<0xA)
			/* 0-9 */
			num+=0x30;
		else
			/* A-F */
			num+=0x57;

		/* Append it to the cstring */
		*dst=(char)num;
		dst++;
	}

	/* Add the nul-terminator */
	*dst=0;
	dst--;

	/* Swap the character string into correct order */
	for (;dst2<dst;dst2++,dst--) {
		/* Swap */
		num=*dst2;
		*dst2=*dst;
		*dst=num;
	}

	/* Return the string */
	return orig;
}
#endif /* defined(GRF_FIXED_KEYSCHEDULE) */


/** Private utility function to swap the nibbles of each byte in a string.
 *
 * @warning Pointers are not checked for validity
 * @note dst should be able to hold at least len characters, and
 *		src should hold at least len characters
 *
 * @param dst Pointer to destination (nibble-swapped) data
 * @param src Pointer to source (unswapped) data
 * @param len Length of data to swap
 * @return A duplicate pointer to data stored by dst
 */
static uint8_t *
GRF_SwapNibbles(uint8_t *dst, const uint8_t *src, uint32_t len)
{
	uint8_t *orig;
	orig = dst;

	for (; len > 0; dst++, src++, len--)
		*dst = (*src << 4) | (*src >> 4);

	return orig;
}


#ifdef GRF_FIXED_KEYSCHEDULE
/** Private function to generate a key for crypting data.
 *
 * @warning Pointers aren't checked
 *
 * @param key Pointer to the 8 bytes in which the key should be stored
 * @param src String to retrieve parts of data for key generation
 * @return Duplicate pointer to data stored at by key
 */
static char *
GRF_GenerateDataKey(char *key, const char *src)
{
	uint32_t i,len;
	const char *nopath;

	/* Get only the filename */
	nopath=src;
	for(i=0;i<strlen(src);i++)
		if (src[i]=='\\' || src[i]=='/')
			nopath=(src+i+1);

	/* First and last characters of the key */
	key[0]='n';
	key[7]='k';

	/* Use the filename as the middle section of the key */
	len=strlen(nopath);
	if (len<6) {
		/* Copy the entire filename */
		memcpy(key+1,nopath,len);

		/* Repeat the filename */
		memcpy(key+len+1,nopath,6-len);

		/* Not sure what anything extra is supposed to be, but
		 * GRAVITY doesn't have any handlers, and I highly doubt there
		 * is going to be a filename 2 characters or less
		 */
	}
	else
		/* Just use the first 6 bytes */
		memcpy(key+1,nopath,6);
	/* Our key is done, now go make us proud. You key, you! */
	return key;
}
#else /* !defined(GRF_FIXED_KEYSCHEDULE) */
/*! \brief Macro to take place of a blank function
 */
# define GRF_GenerateDataKey(k,s) (k)
#endif /* defined(GRF_FIXED_KEYSCHEDULE) */

/*! \brief Private function to read GRF0x1xx headers
 *
 * Reads the information about files within the archive...
 * for archive versions 0x01xx
 *
 * \todo Watch for any files with version 0x104 or greater,
 *	and patchers to decrypt them
 *
 * \param grf Pointer to the Grf struct to read to
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \param callback Function to call for each read file. It should return 0 if
 *		everything is fine, 1 if everything is fine (but further
 *		reading should stop), or -1 if there has been an error
 * \return 0 if everything went fine, 1 if something went wrong
 */
static int GRF_readVer1_info(Grf *grf, GrfError *error, GrfOpenCallback callback) {
	int callbackRet;
	uint32_t i,offset,len,len2;
	char namebuf[GRF_NAMELEN], keyschedule[0x80], *buf;

#ifdef GRF_FIXED_KEYSCHEDULE
	char key[8];

	/* Numbers used for decryption */
	uint32_t keynum,	/* Numeric part of the key */
		keygen101,	/* version 0x101 keygen method */
		keygen102;	/* version 0x102 keygen method */
#endif /* defined(GRF_FIXED_KEYSCHEDULE) */

	/* Make sure we can handle the version */
	if (grf->version>0x103) {
		GRF_SETERR(error,GE_NSUP,GRF_readVer1_info);
		return 1;
	}

	/* Grab the offset of the table */
	if (ftell(grf->f)==-1) {
		GRF_SETERR(error,GE_ERRNO,ftell);
		return 1;
	}
	offset=ftell(grf->f);

	/* Grab the length of the table */
	len=(grf->len)-offset;

	/* Allocate memory for, and grab the table */
	if ((buf=(char*)malloc(len))==NULL) {
		GRF_SETERR(error,GE_ERRNO,malloc);
		return 1;
	}
	if (fseek(grf->f,offset,SEEK_SET)) {
		free(buf);
		GRF_SETERR(error,GE_ERRNO,fseek);
		return 1;
	}
	if (!fread(buf,len,1,grf->f)) {
		free(buf);
		if (feof(grf->f))
			/* When would it ever get here? Oh well, just in case */
			GRF_SETERR(error,GE_CORRUPTED,fread);
		else
			GRF_SETERR(error,GE_ERRNO,fread);
		return 1;
	}

#undef NEVER_DEFINED
#ifdef NEVER_DEFINED
	/* GRAVITY has a version check here, even though it is impossible
	 * to get this far without version being greater than 0xFF and less
	 * than 0x200
	 */
	if (version == 0) {
		/* We're not dumb, so I won't bother coding here */
	}
#endif /* NEVER_DEFINED */

#ifdef GRF_FIXED_KEYSCHEDULE
	keygen102 = 1;
	keygen101 = 95001;
#else /* GRF_FIXED_KEYSCHEDULE */
	/* Make sure our keyschedule is just like their broken one will be */
	memset(keyschedule, 0, 0x80);
#endif /* GRF_FIXED_KEYSCHEDULE */

	/* Read information about each file */
	for (i=offset=0;i<grf->nfiles;i++
	#ifdef GRF_FIXED_KEYSCHEDULE
		, keygen102 += 5, keygen101 -= 2
	#endif /* GRF_FIXED_KEYSCHEDULE */
	) {
		/* Get the name length */
		len = LittleEndian32(buf + offset);
		offset += 4;

		/* Decide how to decode the name */
		if (grf->version < 0x101) {
			/* Make sure name isn't too long */
			len2 = (uint32_t) strlen(buf + offset);  /* NOTE: size_t => uint32_t conversion */
			if (len2 >= GRF_NAMELEN) {
				/* We can't handle names this long, and
				 * neither can the older patch clients,
				 * so the data must be corrupt... I guess
				 */
				GRF_SETERR(error,GE_CORRUPTED,GRF_readVer1_info);
				free(buf);
				return 1;
			}

			/* Swap nibbles into the name */
			GRF_SwapNibbles((uint8_t*)grf->files[i].name, (uint8_t*)(buf+offset), len2);
		}
		else if (grf->version<0x104) {
			/* Skip the first 2 bytes */
			offset+=2;

			/* Make sure we don't overflow */
			len2=len-6;
			if (len2>=GRF_NAMELEN) {
				GRF_SETERR(error,GE_CORRUPTED,GRF_readVer1_info);
				free(buf);
				return 1;
			}

			/* Swap nibbles into DES decryption buffer */
			GRF_SwapNibbles((uint8_t*)namebuf, (uint8_t*)(buf+offset), len2);

/* GRAVITY's DES implementation is broken and ignores the key, even
 * though they go through and generate the key in the following way
 */
#ifdef GRF_FIXED_KEYSCHEDULE
			/* Decide how to generate the key */
			if (grf->version==0x101)
				keynum=keygen101;
			else {	/* version 102 */
				keynum=0x7BB5-(keygen102>>1);

				keynum*=3;
				/* In the patch client assembly it looks
				 * equivalent of:
				 * keynum+=2*keynum;
				 */
			}

			/* Make sure the numeric part of the key is 5 digits */
			if (keynum<10000)
				keynum+=85000;

			/* Generate the key */
			GRF_ltoa((key+2),keynum,0xA);
			key[0]='P';
			key[1]='r';
			key[7]='e';

			/* Key should now look like: "Pr95007e" for first
			 * file of a 0x102 file...
			 * Lets use it! (except GRAVITY can't code)
			 */

			/* Generate key schedule */
			DES_CreateKeySchedule(keyschedule, key);
#endif /* GRF_FIXED_KEYSCHEDULE */

			/* Decrypt the name */
			GRF_MixedProcess(grf->files[i].name, namebuf, len2, 1, keyschedule, GRFCRYPT_DECRYPT);

			/* Subtract 2 from len for the 2 bytes we skipped
			 * over
			 */
			len-=2;
		}

		/* Skip past the name */
		offset+=len;

		/* Grab the rest of the file information */
		grf->files[i].compressed_len=LittleEndian32(buf+offset)-LittleEndian32(buf+offset+8)-0x02CB;
		grf->files[i].compressed_len_aligned=LittleEndian32(buf+offset+4)-0x92CB;
		grf->files[i].real_len=LittleEndian32(buf+offset+8);
		grf->files[i].flags=*(uint8_t*)(buf+offset+0xC);
		grf->files[i].pos=LittleEndian32(buf+offset+0xD)+GRF_HEADER_FULL_LEN;
		grf->files[i].hash=GRF_NameHash(grf->files[i].name);

		/* Check if the file is a special file */
		if (GRF_CheckExt(grf->files[i].name,specialExts))
			grf->files[i].flags|=GRFFILE_FLAG_0x14_DES;
		else
			grf->files[i].flags|=GRFFILE_FLAG_MIXCRYPT;

		/* Go to the next file */
		offset+=0x11;

		/* Run the callback, if we have one */
		if (callback) {
			if ((callbackRet=callback(&(grf->files[i]),error))<0) {
				/* Callback function had an error, so we
				 * have an error
				 */
				return 1;
			}
			else if (callbackRet>0) {
				/* Callback function found the file it needed,
				 * just exit now
				 */
				return 0;
			}
		}
	}

	/* Calling functions will set success...
	GRF_SETERR(error,GE_SUCCESS,GRF_readVer1_info);
	*/
	return 0;
}

/*! \brief Private function to read GRF0x2xx headers
 *
 * Reads the information about files within the archive...
 * for archive versions 0x02xx
 *
 * \todo Find GRF versions other than just 0x200 (do any exist?)
 *
 * \param grf Pointer to the Grf struct to read to
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \param callback Function to call for each read file. It should return 0 if
 *		everything is fine, 1 if everything is fine (but further
 *		reading should stop), or -1 if there has been an error
 * \return 0 if everything went fine, 1 if something went wrong
 */
static int GRF_readVer2_info(Grf *grf, GrfError *error, GrfOpenCallback callback) {
	int callbackRet;
	uint32_t i,offset,len,len2;
	int z;
	uLongf zlen;
	char *buf, *zbuf;

	/* Check grf */
	if (grf->version != 0x200) {
		GRF_SETERR(error,GE_NSUP,GRF_readVer2_info);
		return 1;
	}

	/* Read the original and compressed sizes */
	if ((buf=(char*)malloc(8))==NULL) {
		GRF_SETERR(error,GE_ERRNO,malloc);
		return 1;
	}
	if (!fread(buf,8,1,grf->f)) {
		free(buf);
		if (feof(grf->f))
			GRF_SETERR(error,GE_CORRUPTED,GRF_readVer2_info);
		else
			GRF_SETERR(error,GE_ERRNO,fread);
		return 1;
	}

	/* Allocate memory and read the compressed file table */
	len=LittleEndian32(buf);
	if ((zbuf=(char*)malloc(len))==NULL) {
		free(buf);
		GRF_SETERR(error,GE_ERRNO,malloc);
		return 1;
	}
	if (!fread(zbuf,len,1,grf->f)) {
		free(buf);
		free(zbuf);
		if (feof(grf->f))
			GRF_SETERR(error,GE_CORRUPTED,GRF_readVer2_info);
		else
			GRF_SETERR(error,GE_ERRNO,fread);
		return 1;
	}

	if (0==(len2=LittleEndian32(buf+4))) {
		free(zbuf);
		return 0;
	}
	/* Allocate memory and uncompress the compressed file table */
	if ((buf=(char*)realloc(buf,len2))==NULL) {
		free(zbuf);
		GRF_SETERR(error, GE_ERRNO, realloc);
		return 1;
	}
	zlen = len2;
	z = uncompress((Bytef*) buf, &zlen, (const Bytef *) zbuf, (uLong) len);
	if (z != Z_OK) {
		free(buf);
		free(zbuf);
		GRF_SETERR_2(error, GE_ZLIB, uncompress, (ssize_t) z);  /* NOTE: int => ssize_t /-signed-/ => uintptr* conversion */
		return 1;
	}

	/* Free the compressed file table */
	free(zbuf);

	/* Read information about each file */
	for (i = offset = 0; i < grf->nfiles; i++) {
		/* Grab the filename length */
		len = (uint32_t) strlen(buf + offset) + 1;  /* NOTE: size_t => uint32_t conversion */

		/* Make sure its not too large */
		if (len>=GRF_NAMELEN) {
			free(buf);
			GRF_SETERR(error,GE_CORRUPTED,GRF_readVer2_info);
			return 1;
		}

		/* Grab filename */
		memcpy(grf->files[i].name,buf+offset,len);
		offset+=len;

		/* Grab the rest of the information */
		grf->files[i].compressed_len=LittleEndian32(buf+offset);
		grf->files[i].compressed_len_aligned=LittleEndian32(buf+offset+4);
		grf->files[i].real_len=LittleEndian32(buf+offset+8);
		grf->files[i].flags=*(uint8_t*)(buf+offset+0xC);
		grf->files[i].pos=LittleEndian32(buf+offset+0xD)+GRF_HEADER_FULL_LEN;
		grf->files[i].hash=GRF_NameHash(grf->files[i].name);

		/* Advance to the next file */
		offset+=0x11;

		/* Run the callback, if we have one */
		if (callback) {
			if ((callbackRet=callback(&(grf->files[i]),error))<0) {
				/* Callback function had an error, so we
				 * have an error
				 */
				return 1;
			}
			else if (callbackRet>0) {
				/* Callback function found the file it needed,
				 * just exit now
				 */
				return 0;
			}
		}
	}

	/* Calling functions will set success...
	GRF_SETERR(error,GE_SUCCESS,GRF_readVer2_info);
	*/
	return 0;
}

/*! \brief Private function to find unused space in a GRF file
 *
 * \warning This function assumes the files have been sorted with
 *	grf_sort() using GRF_OffsetSort();
 *
 * \param grf GRF file to search for the unused space in
 * \param len Amount of contiguous unused space we need to find before we
 *	return
 * \return The first offset in the GRF in which at least len amount of
 *	unused space was found, or 0 if none was found
 */
static uint32_t
GRF_find_unused (Grf *grf, uint32_t len)
{
	/* (compiler warnings) uint32_t  i,startAt=GRF_HEADER_FULL_LEN,curAmt; */
	GrfFile *cur;
	uint32_t beginEmpty, amtEmpty;

	if ( grf->nfiles == 0 ) {
		return 0;
	}

	/* Grab the first file in the linked list */
	cur = grf->first;

	/* Ignore files that have not been sorted yet */
	while (cur!=NULL && cur->next!=NULL &&
	  (cur->flags & GRFFILE_FLAG_FILE) != 0 &&
	  cur->real_len != 0 &&
	  cur->pos != 0)
		cur=cur->next;

	/* Loop through, checking each file's pos against the
	 * end of the data for the previous file
	 */
	while (cur!=NULL && cur->next!=NULL) {
		beginEmpty=cur->pos+cur->compressed_len_aligned;
		amtEmpty=cur->next->pos-beginEmpty;

		/* Check if we have enough empty space */
		if (amtEmpty >= len)
			return beginEmpty;

		cur=cur->next;
	}

	/* No fitting space found, tell 'em to append it */
	return 0;

	/* \todo write an acceptable implementation */
#if 0
	/* Space between GRF_HEADER_FULL_LEN and first entry is lost:
	entries[0..k] sorted, entries [k..j] are 0-pos'd, entries [j..nfiles] sorted
	*/
	/* Find first file entry */
	for(i=0;i<grf->nfiles &&
		((grf->files[i].type & GRFFILE_FLAG_FILE) == 0 ||
		grf->files[i].real_len == 0 ||
		grf->files[i].pos == 0);++i) {
	}
#error BAD: .pos modified between calls of function
		/* Check if there is enough space before the first entry */
	if (startAt + len <= grf->files[i].pos )
		return startAt;

	startAt=grf->files[i].pos+grf->files[i].compressed_len_aligned;

	/* Find open spaces between two entries */
	for(i=0;i<grf->nfiles-1;) {
		/* Ignore the files with bogus offsets */
		if ((grf->files[i].type & GRFFILE_FLAG_FILE) != 0 &&
			grf->files[i].real_len != 0 &&
			grf->files[i].pos != 0 ) {
			/* Check if there is enough space, that is to say,
			 * enough space (len) between the end of previous entry (startAt)
			 * and the beginning of next (grf->files[i+1].pos).
			 * Beware of unsigned!
			 */
			uint32_t j,next_pos;
			startAt=grf->files[i].pos+grf->files[i].compressed_len_aligned;
			/* Find first file entry */
			for(j=i+1;j<grf->nfiles &&
				((grf->files[j].type & GRFFILE_FLAG_FILE) == 0 ||
				grf->files[j].real_len == 0 ||
				grf->files[j].pos == 0);++j) {
			}
			if (startAt + len <= grf->files[j].pos )
				return startAt;

			/* Find the new startpoint. This is only valid because files are offset-sorted. */
			startAt=grf->files[j].pos+grf->files[j].compressed_len_aligned;
			i = j;
		}
		else
		{
			++i;
		}
	}
#endif  /* 0 */
}

/*! \brief Private function to compress and encrypt (if needed), and write one file
 *
 * \param grf Pointer to the Grf struct to read from
 * \param index GrfFile to flush
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \return Number of files compressed, encrypted, and written
 */
static int GRF_flushFile(Grf *grf, uint32_t i, GrfError *error) {
	Bytef *comp_dat,*enc_dat=0,*write_dat;
	uLong size_bound;
	uLongf comp_len;
	char keyschedule[0x80], key[8];
	uint32_t write_offset;
	GrfFile *cur = NULL;
	
	size_bound = compressBound(grf->files[i].real_len);
	
	/* Make sure size_bound will be a multiple of 8, in case the file should be encrypted
	 * and uses the entire buffer
	 */
	size_bound+=size_bound%8;

	if (0==(comp_dat = (Bytef *)calloc(1,size_bound))) {
		GRF_SETERR(error,GE_ERRNO,malloc);
		return 0;
	}
	compress(comp_dat, &comp_len, grf->files[i].data, grf->files[i].real_len);
	grf->files[i].compressed_len = comp_len;
	
	/* Encrypt the data as well */
	grf->files[i].compressed_len_aligned = grf->files[i].compressed_len;
	if ((grf->files[i].flags & (GRFFILE_FLAG_MIXCRYPT | GRFFILE_FLAG_0x14_DES))) {
		/* Ensure our buffer will be a multiple of 8 */
		grf->files[i].compressed_len_aligned += grf->files[i].compressed_len % 8;
		
		/* Allocate the memory */
		if (0==(enc_dat=(Bytef*)realloc(enc_dat,grf->files[i].compressed_len_aligned))) {
			free(comp_dat);
			GRF_SETERR(error,GE_ERRNO,malloc);
			return 0;
		}
		
		/* Create a key and use it to generate the key schedule */
		DES_CreateKeySchedule(keyschedule,GRF_GenerateDataKey(key,grf->files[i].name));
		
		/* Encrypt the data */
		GRF_Process(enc_dat,comp_dat,grf->files[i].compressed_len_aligned,grf->files[i].flags,grf->files[i].compressed_len,keyschedule,GRFCRYPT_ENCRYPT);
		
		write_dat = enc_dat;
	}
	else
	{
		write_dat = comp_dat;
	}

	/* Remember the position prior to writing */
	write_offset = GRF_find_unused(grf, grf->files[i].compressed_len_aligned);
	if ( write_offset == 0 ) {
		/* grf_find_unused returned 0 -> append */
		if (fseek(grf->f, 0, SEEK_END)) {
			free(comp_dat);
			free(enc_dat);
			GRF_SETERR(error,GE_ERRNO,fseek);
			return 0;
		}
		if (ftell(grf->f)==-1) {
			free(comp_dat);
			free(enc_dat);
			GRF_SETERR(error,GE_ERRNO,ftell);
			return 0;
		}
		write_offset = ftell(grf->f);  /* not -1 */
	}
	else if (fseek(grf->f, (long)write_offset, SEEK_SET)) {
		free(comp_dat);
		free(enc_dat);
		GRF_SETERR(error,GE_ERRNO,fseek);
		return 0;
	}
	grf->files[i].pos = write_offset;

	/* Take the file out of the linked list */
	if (grf->files[i].prev)
		grf->files[i].prev->next=grf->files[i].next;
	if (grf->files[i].next)
		grf->files[i].next->prev=grf->files[i].prev;
	
	/* Find a spot in the linked list for the file */
	cur = grf->first;
	while (cur!=NULL && cur->pos<write_offset)
		cur=cur->next;
		
	/* Set the files next and prev */
	if (cur==NULL) {
		grf->files[i].prev=grf->last;
		grf->files[i].next=NULL;
	}
	else {
		grf->files[i].prev=cur;
		grf->files[i].next=cur->next;
	}
	
	/* Move the file after its prev, and before its next */
	cur=&(grf->files[i]);
	if (cur->next!=NULL) cur->next->prev=cur;
	if (cur->prev!=NULL) cur->prev->next=cur;

	/* Write the data to its spot */
	if (fwrite(write_dat, grf->files[i].compressed_len_aligned, 1U, grf->f) < 1U) {
		free(comp_dat);
		free(enc_dat);
		if (feof(grf->f))
			GRF_SETERR(error,GE_CORRUPTED,fwrite);  /* !!? Cannot write because of end of file */
		else
			GRF_SETERR(error,GE_ERRNO,fwrite);
		return 0;
	}
	
	/* Clean up */
	free(comp_dat);
	free(enc_dat);
	
	return 1;
}

/*! \brief Private function to restructure GRF0x1xx archives
 *
 * Generate the information about files within the archive
 * for archive versions 0x01xx, and updates the file header
 *
 * \todo Watch for any files with version 0x104 or greater,
 *	and patchers to decrypt them
 *
 * \param grf Pointer to the Grf struct to read from
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \param callback Function to call for each file being flushed to disk.
 *		The first parameter received by this function is the address of a
 *		GrfFile structure which contains information about the file that is
 *		about to be processed. The files that reside in memory have their
 *		compressed_len field set to zero and their real_len non-zero.
 *		The function should return 0 if everything is fine, 1 if the file
 *		shall not be written but processing may continue, 2 if any further
 *		compression shall be stopped, leaving uncompressed files in memory, but
 *		flushing those already compressed, or -1 if there has been an error
 * \return 0 if an error occurred, 1 if all is good
 */
static int GRF_flushVer1(Grf *grf, GrfError *error, GrfFlushCallback callback) {
	int callbackRet;
	int processOnlyReady = 0;
	uLong table_len;
	uint32_t i,offset,len,table_maxlen;
	uint32_t write_offset, write_offset_le;
	uint32_t dummy_seed = 0, dummy_seed_le = 0;
	uint32_t e_count = 0, e_count_le;
	char *buf, namebuf[GRF_NAMELEN], keyschedule[0x80];

#ifdef GRF_FIXED_KEYSCHEDULE
	char key[8];

	/* Numbers used for decryption */
	uint32_t keynum,	/* Numeric part of the key */
		keygen101,	/* version 0x101 keygen method */
		keygen102;	/* version 0x102 keygen method */
#endif /* defined(GRF_FIXED_KEYSCHEDULE) */


	/* compute an upper bound for the table size.
	 * Actually, it is a little larger because there are extra members.
	 * However, when reading, the nfiles value found in the grf header
	 * is relied upon to read only as much as necessary.
	 */
	table_maxlen = grf->nfiles * sizeof(GrfFile);

	/* Allocate memory for the table */
	if ((buf=(char*)malloc(table_maxlen))==NULL) {
		GRF_SETERR(error,GE_ERRNO,malloc);
		return 0;
	}
	
#ifdef GRF_FIXED_KEYSCHEDULE
	keygen102=1;
	keygen101=95001;
#else /* GRF_FIXED_KEYSCHEDULE */
	/* Make sure our keyschedule is just like their broken one will be */
	memset(keyschedule,0,0x80);
#endif /* GRF_FIXED_KEYSCHEDULE */

	/* compress in-memory files */
	/* Write information about each file */
	for (i=offset=0;i<grf->nfiles;++i
#ifdef GRF_FIXED_KEYSCHEDULE
,keygen102+=5,keygen101-=2
#endif /* GRF_FIXED_KEYSCHEDULE */
	) {
		/* Run the callback, if we have one */
		if (callback && 0!=(callbackRet=callback(&(grf->files[i]),error))) {
			if (callbackRet<0) {
				/* Callback function had an error, so we
				 * have an error
				 */
				free(buf);
				return 0;
			}
			else if (callbackRet==1) {
				/* skip entry */
				continue;
			}
			else {
				/* Callback function doesn't want to process in-memory files any further,
				 * flush remaining, already ready-to-flush data to fall back to a working state.
				 */
				processOnlyReady = 1;
			}
		}

		/* \todo check if empty files interfere with encryption
		 *
		 * -- They shouldn't... 0 % 8 = 0, which makes it a "multiple of 8"
		 */
		if ( grf->files[i].compressed_len == 0 &&
		  grf->files[i].compressed_len_aligned == 0 &&
		  grf->files[i].pos == 0 &&
		  grf->files[i].real_len != 0 ) {  /* compress only non-empty files */
			/* Skip non-ready entries
			 *
			 * Faithful: using "continue;" would skip over adding the entry
			 * information to the table This would effectively "delete"
			 * any file that was updated but not ready by not writing its
			 * old file information to the table...
			 */
			if ( processOnlyReady != 1 ) {
				/* Flush the entry to disk. For directories, there is nothing to do,
				 * since special values are set and available when reading the fileinfo table
				 */
				if ((grf->files[i].flags & GRFFILE_FLAG_FILE)) {
					/* Most files in versions 0x01xx use MIXCRYPT, only special ones use 0x14_DES */
					if (GRF_CheckExt(grf->files[i].name,specialExts))
						grf->files[i].flags=(grf->files[i].flags & ~GRFFILE_FLAG_MIXCRYPT) | GRFFILE_FLAG_0x14_DES;
					else
						grf->files[i].flags=(grf->files[i].flags & ~GRFFILE_FLAG_0x14_DES) | GRFFILE_FLAG_MIXCRYPT;
					
					/* Compress, encrypt, and write the file */
					if (GRF_flushFile(grf,i,error)) {
						free(buf);
						return 0;
					}
				}
				else {
					/* File flag isn't set, but special values for directories
					 * aren't set either?
					 */
				}
			}
		}

		/* Format for 0x01xx entries
		 * - uint32_t (4 bytes) = namelen
		 * - string (namelen bytes) = filename (encrypted various ways
		 *   depending on minor GRF version)
		 * - uint32_t = compressed_len + real_len + 0x02CB
		 * - uint32_t = compressed_len_aligned + 0x92CB
		 * - uint32_t = real_len
		 * - uint8_t = type (flags really, was named type for old version compatibility)
		 * - uint32_t = pos - GRF_HEADER_FULL_LEN
		 */

		/* Compute the filename length */
		len = (uint32_t) strlen(grf->files[i].name) + 1;  /* NOTE: size_t => uint32_t conversion */

		/* Decide how to encrypt the name */
		if (grf->version < 0x101) {
			*(uint32_t*)(buf+offset) = len;
			
			/* Swap nibbles into the buffer */
			GRF_SwapNibbles((uint8_t*)(buf+offset+4), (uint8_t*)grf->files[i].name, len);
			
			offset+=4+len;
		}
		else if (grf->version<0x104) {
			*(uint32_t*)(buf+offset) = len+6;
			offset+=4;
			
#ifdef GRF_FIXED_KEYSCHEDULE
			/* Decide how to generate the key */
			if (grf->version==0x101)
				keynum=keygen101;
			else {
				keynum=0x7BB5-(keygen102>>1);
				keynum*=3;
			}
			
			/* Make sure the numeric part of the key is 5 digits */
			if (keynum<10000)
				keynum+=85000;
			
			/* Generate the key */
			GRF_ltoa((key+2),keynum,0xA);
			key[0]='P';
			key[1]='r';
			key[7]='e';
			
			/* Key should now look like: "Pr95007e" for first
			 * file of a 0x102 file...
			 * Lets use it! (except GRAVITY can't code)
			 */
	
			/* Generate key schedule */
			DES_CreateKeySchedule(keyschedule, key);
#endif /* GRF_FIXED_KEYSCHEDULE */
			
			/* Encrypt the name */
			GRF_MixedProcess(namebuf, grf->files[i].name, len, 1, keyschedule, GRFCRYPT_ENCRYPT);
			
			/* Swap the encrypted nibbles into the buffer */
			GRF_SwapNibbles((uint8_t*)(buf+offset+6), (uint8_t*)namebuf, len);
			
			offset+=len+6;
		}
		
		/* Copy the rest of the information */
		*(uint32_t*)(buf+offset)     = ToLittleEndian32(grf->files[i].compressed_len+grf->files[i].real_len+0x02CB);
		*(uint32_t*)(buf+offset+4)   = ToLittleEndian32(grf->files[i].compressed_len_aligned+0x92CB);
		*(uint32_t*)(buf+offset+8)   = ToLittleEndian32(grf->files[i].real_len);
		/* Encryption method is determined by file extension in 0x01xx GRFs, so just write the file flag */
		*(uint8_t*)(buf+offset+0xC)  = grf->files[i].flags & GRFFILE_FLAG_FILE;
		*(uint32_t*)(buf+offset+0xD) = ToLittleEndian32(grf->files[i].pos-GRF_HEADER_FULL_LEN);
		
		/* Advance to the next file */
		offset+=0x11;
		++e_count;
	}
	
	/* this is the real table length - note to optimizers: extra variable, equiv. to offset */
	table_len = offset;
	
	/*! \todo Find the last used byte so we can overwrite any trailing, unused data */
	
	/* Write the table at the end of the file */
	if (fseek(grf->f, 0, SEEK_END)) {
		free(buf);
		GRF_SETERR(error,GE_ERRNO,fseek);
		return 0;
	}
	if (ftell(grf->f)==-1) {
		free(buf);
		GRF_SETERR(error,GE_ERRNO,ftell);
		return 0;
	}
	write_offset = ftell(grf->f); /* not -1 */
	
	/* Write the file informations */
	if (fwrite(buf, table_len, 1U, grf->f) < 1U) {
		free(buf);
		if (feof(grf->f))
			GRF_SETERR(error,GE_CORRUPTED,fwrite); /* !!? Cannot write because of end of file */
		else
			GRF_SETERR(error,GE_ERRNO,fwrite);
		return 0;
	}
	
	/* Clean up */
	free(buf);
	
	/* seek to header and update information. Do not forget to alter
	 * the offset of the table information, write_offset, before writing it.
	 */
	if (fseek(grf->f, GRF_HEADER_MID_LEN, SEEK_SET)) {
		GRF_SETERR(error,GE_ERRNO,fseek);
		return 0;
	}

	/* Format for file header
	 * - uint32_t (4 bytes) = location of fileinfo AFTER the main header. (for
	 *   example, if file info was at position 1000 and main header is size
	 *   GRF_HEADER_FULL_LEN, this number would be 1000-GRF_HEADER_FULL_LEN)
	 * - uint32_t (4 bytes) = part 1 of num_files (i'll explain these in a bit)
	 * - uint32_t (4 bytes) = part 2 of num_files
	 * - uint32_t (4 bytes) = version
	 * When determining the number of files in the GRF/GPF, the client subtracts
	 * part1 from part2, and then from that subtracts 7 (ie, part2-part1-7).
	 * I'm not sure how the number for part1 is decided.
	 * For 0x200 it seems that part1 is always 0x00000000, other than that I'm not sure.
	 * It shouldn't really matter because that is all it seems it is used for.
	 */

	/*! \todo Find how 0x01xx version GRFs dummy_seed is generated */
	/* dummy_seed=0; */

	write_offset_le = ToLittleEndian32(write_offset-GRF_HEADER_FULL_LEN);
	/* dummy_seed_le = ToLittleEndian32(dummy_seed); */
	e_count_le = ToLittleEndian32(e_count+dummy_seed+7);

	if (fwrite(&write_offset_le, sizeof(uint32_t), 1U, grf->f) < 1U ||
	  fwrite(&dummy_seed_le, sizeof(uint32_t), 1U, grf->f) < 1U ||
	  fwrite(&e_count_le, sizeof(uint32_t), 1U, grf->f) < 1U) {
		GRF_SETERR(error,GE_ERRNO,fwrite);
		return 0;
	}
	
	return 1;	
}

/*! \brief Private function to restructure GRF0x2xx archives
 *
 * Generate the information about files within the archive
 * for archive versions 0x02xx, and updates the file header
 *
 * \todo Find GRF versions other than just 0x200 (do any exist?)
 *
 * \param grf Pointer to the Grf struct to read from
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \param callback Function to call for each file being flushed to disk.
 *		The first parameter received by this function is the address of a
 *		GrfFile structure which contains information about the file that is
 *		about to be processed. The files that reside in memory have their
 *		compressed_len field set to zero and their real_len non-zero.
 *		The function should return 0 if everything is fine, 1 if the file
 *		shall not be written but processing may continue, 2 if any further
 *		compression shall be stopped, leaving uncompressed files in memory, but
 *		flushing those already compressed, or -1 if there has been an error
 * \return 0 if an error occurred, 1 if all is good
 */
static int
GRF_flushVer2(Grf *grf, GrfError *error, GrfFlushCallback callback)
{
	int callbackRet;
	int processOnlyReady = 0;
	uLong table_len;
	uint32_t i,offset,len,table_maxlen;
	int z;
	uLongf zlen;
	uLong zlenmax;
	uint32_t table_len_le;
	uint32_t zlen_le;
	uint32_t write_offset, write_offset_le;
	uint32_t dummy_seed = 0, dummy_seed_le = 0;
	uint32_t e_count = 0, e_count_le;
	char *buf, *zbuf;

	/* compute an upper bound for the table size.
	 * Actually, it is a little larger because there are extra members.
	 * However, when reading, the nfiles value found in the grf header
	 * is relied upon to read only as much as necessary.
	 */
	table_maxlen = grf->nfiles * sizeof(GrfFile);
	zlenmax = compressBound(table_maxlen);

	/* Allocate memory for the table */
	if ((buf=(char*)malloc(table_maxlen))==NULL) {
		GRF_SETERR(error,GE_ERRNO,malloc);
		return 0;
	}
	if ((zbuf=(char*)malloc(zlenmax))==NULL) {
		free(buf);
		GRF_SETERR(error,GE_ERRNO,malloc);
		return 0;
	}

	/* compress in-memory files */
	/* Write information about each file */
	for (i=offset=0;i<grf->nfiles;++i) {
		/* Run the callback, if we have one */
		if (callback && 0!=(callbackRet=callback(&(grf->files[i]),error))) {
			if (callbackRet<0) {
				/* Callback function had an error, so we
				 * have an error
				 */
				free(buf);
				free(zbuf);
				return 0;
			}
			else if (callbackRet==1) {
				/* skip entry */
				continue;
			}
			else {
				/* Callback function doesn't want to process in-memory files any further,
				 * flush remaining, already ready-to-flush data to fall back to a working state.
				 */
				processOnlyReady = 1;
			}
		}

		/* \todo check if empty files interfere with encryption
		 *
		 * -- They shouldn't... 0 % 8 = 0, which makes it a "multiple of 8"
		 */
		if ( grf->files[i].compressed_len == 0 &&
		  grf->files[i].compressed_len_aligned == 0 &&
		  grf->files[i].pos == 0 &&
		  grf->files[i].real_len != 0 ) {  /* compress only non-empty files */
			/* Skip non-ready entries
			 *
			 * Faithful: using "continue;" would skip over adding the entry
			 * information to the table This would effectively "delete"
			 * any file that was updated but not ready by not writing its
			 * old file information to the table...
			 */
			if ( processOnlyReady != 1 ) {
				/* Flush the entry to disk. For directories, there is nothing to do,
				 * since special values are set and available when reading the fileinfo table
				 */
				if ((grf->files[i].flags & GRFFILE_FLAG_FILE)) {
					/* If the GRF doesn't allow encryption, don't encrypt
					 *
					 * (btw, should we reverse this and change the header watermark
					 *  if we want to add encrypted data?)
					 */
					if (!grf->allowCrypt)
						grf->files[i].flags&=~(GRFFILE_FLAG_MIXCRYPT | GRFFILE_FLAG_0x14_DES);
					
					/* Compress, encrypt, and write the file */
					if (GRF_flushFile(grf,i,error)) {
						free(buf);
						free(zbuf);
						return 0;
					}
				}
				else {
					/* File flag isn't set, but special values for directories
					 * aren't set either?
					 */
				}
			}
		}

		/* Format for 0x02xx entries
		 * - string = name (nul terminated, use strlen to find namelen if
		 *   needed. also this isn't encrypted at all)
		 * - uint32_t = compressed_len
		 * - uint32_t = compressed_len_aligned
		 * - uint32_t = real_len
		 * - uint8_t = type
		 * - uint32_t = pos
		 */

		/* Compute the filename length */
		len = (uint32_t) strlen(grf->files[i].name) + 1;  /* NOTE: size_t => uint32_t conversion */
		/* Copy filename */
		memcpy(buf+offset,grf->files[i].name,len);
		offset+=len;

		/* Copy the rest of the information */
		*(uint32_t*)(buf+offset)     = ToLittleEndian32(grf->files[i].compressed_len);
		*(uint32_t*)(buf+offset+4)   = ToLittleEndian32(grf->files[i].compressed_len_aligned);
		*(uint32_t*)(buf+offset+8)   = ToLittleEndian32(grf->files[i].real_len);
		*(uint8_t*)(buf+offset+0xC)  = grf->files[i].flags;
		*(uint32_t*)(buf+offset+0xD) = ToLittleEndian32(grf->files[i].pos-GRF_HEADER_FULL_LEN);
		/* Advance to the next file */
		offset+=0x11;
		++e_count;
	}

	/* this is the table real length - note to optimizers: this is an extra variable,
	 * equivalent to offset
	 */
	table_len = offset;

	/* Compress buf into zbuf, storing actual length in zlen */
	z = compress((Bytef *) zbuf, &zlen, (const Bytef *)buf, table_len);
	if (z != Z_OK) {
		free(buf);
		free(zbuf);
		GRF_SETERR_2(error, GE_ZLIB, compress, (ssize_t) z);  /* NOTE: uint => ssize_t /-signed-/ => uintptr* conversion */
		return 0;
	}

	free(buf); buf = 0;

	/* Write the compressed table at an unused position */
	write_offset = GRF_find_unused(grf, 2*sizeof(uint32_t)+zlen);
	if ( write_offset == 0 ) {
		/* grf_find_unused returned 0 -> append */
		if (fseek(grf->f, 0, SEEK_END)) {
			free(zbuf);
			GRF_SETERR(error,GE_ERRNO,fseek);
			return 0;
		}
		if (ftell(grf->f)==-1) {
			free(zbuf);
			GRF_SETERR(error,GE_ERRNO,ftell);
			return 0;
		}
		write_offset = ftell(grf->f);  /* not -1 */
	}
	else if (fseek(grf->f, (long)write_offset, SEEK_SET)) {
		free(zbuf);
		GRF_SETERR(error,GE_ERRNO,fseek);
		return 0;
	}

	write_offset_le = ToLittleEndian32(write_offset-GRF_HEADER_FULL_LEN);
	zlen_le = ToLittleEndian32(zlen);
	table_len_le = ToLittleEndian32(table_len);
	/* dummy_seed_le = ToLittleEndian32(dummy_seed); */
	e_count_le = ToLittleEndian32(e_count+dummy_seed+7);
	/* Format for Table info
	 * - uint32_t = compressed_filetable_len
	 * - uint32_t = real_filetable_len
	 * - void * (compressed_filetable_len bytes) = zlib compressed filetable
	 */
	if (fwrite(&zlen_le, sizeof(uint32_t), 1U, grf->f) < 1U ||
	  fwrite(&table_len_le, sizeof(uint32_t), 1U, grf->f) < 1U ||
	  fwrite(zbuf, zlen, 1U, grf->f) < 1U) {
		free(zbuf);
		if (feof(grf->f))
			GRF_SETERR(error,GE_CORRUPTED,fwrite);  /* !!? Cannot write because of end of file */
		else
			GRF_SETERR(error,GE_ERRNO,fwrite);
		return 0;
	}
	free(zbuf);

	/* seek to header and update information. Do not forget to alter
	 * the offset of the compressed table block, write_offset, before writing it.
	 */
	if (fseek(grf->f, GRF_HEADER_MID_LEN, SEEK_SET)) {
		GRF_SETERR(error,GE_ERRNO,fseek);
		return 0;
	}
	/* Format for file header
	 * - uint32_t (4 bytes) = location of fileinfo AFTER the main header. (for
	 *   example, if file info was at position 1000 and main header is size
	 *   GRF_HEADER_FULL_LEN, this number would be 1000-GRF_HEADER_FULL_LEN)
	 * - uint32_t (4 bytes) = part 1 of num_files (i'll explain these in a bit)
	 * - uint32_t (4 bytes) = part 2 of num_files
	 * - uint32_t (4 bytes) = version
	 * When determining the number of files in the GRF/GPF, the client subtracts
	 * part1 from part2, and then from that subtracts 7 (ie, part2-part1-7).
	 * I'm not sure how the number for part1 is decided.
	 * For 0x200 it seems that part1 is always 0x00000000, other than that I'm not sure.
	 * It shouldn't really matter because that is all it seems it is used for.
	 */

	if (fwrite(&write_offset_le, sizeof(uint32_t), 1U, grf->f) < 1U ||
	  fwrite(&dummy_seed_le, sizeof(uint32_t), 1U, grf->f) < 1U ||
	  fwrite(&e_count_le, sizeof(uint32_t), 1U, grf->f) < 1U) {
		GRF_SETERR(error,GE_ERRNO,fwrite);
		return 0;
	}

	return 1;

}


/********************
 * Public Functions *
 ********************/

/** Open or create a GRF file and read its contents.
 *
 * If the file is created, a valid header is produced. It is updated when file is closed
 * using grf_close() or when grf_callback_flush() is called.
 *
 * @see GrfOpenCallback, grf_open
 *
 * @param fname Filename of the GRF file
 * @param mode Character sequence specifying the mode to open the file in, according to fopen(3).
 *             For maximal compatibility, recommended flags are @b "rb" for read-only mode,
 *             @b "r+b" for read-write mode (modifying an archive), or @b "w+b" to create a new
 *             empty grf file. Do not use mode "a" (append), or a mode where reading is impossible.
 * @param error [out] Pointer to a GrfError variable for error reporting. May be NULL.
 * @param callback Pointer to a GrfOpenCallback function. This function is called every time a file in
 *                 the index is read. You can use it to implement a loading progress bar, for example.
 * @return A pointer to a newly created Grf struct
 */
GRFEXPORT Grf *
grf_callback_open (const char *fname, const char *mode, GrfError *error, GrfOpenCallback callback)
{
	char buf[GRF_HEADER_FULL_LEN];
	uint32_t i, zero = 0, zero_fcount = ToLittleEndian32(7), create_ver = ToLittleEndian32(0x0200);
	int z;
	Grf *grf;
	uLongf zlen;
	uLong zlenmax;
	uint32_t zlen_le;
	char *zbuf;


	if (!fname || !mode) {
		GRF_SETERR(error,GE_BADARGS,grf_callback_open);
		return NULL;
	}

	/* Allocate memory for grf */
	if ((grf=(Grf*)calloc(1,sizeof(Grf)))==NULL) {
		GRF_SETERR(error,GE_ERRNO,malloc);
		return NULL;
	}

	/* Allocate memory for grf filename */
	if ((grf->filename = (char*) malloc (sizeof(char) * strlen(fname) + 1)) == NULL) {
		grf_free(grf);
		GRF_SETERR(error, GE_ERRNO, malloc);
		return NULL;
	}

	/* Copy the filename */
	strcpy(grf->filename,fname);

	/* Open the file */
	if ((grf->f = fopen(grf->filename, mode))==NULL) {
		grf_free(grf);
		GRF_SETERR(error,GE_ERRNO,fopen);
		return NULL;
	}

	grf->allowWrite = strchr(mode, '+') == NULL && strchr(mode, 'w') == NULL? 0 : 1;

	/* Create an empty table for new files */
	if ( strchr(mode, 'w') != NULL ) {
		zlenmax = compressBound(0);
		if ((zbuf=(char*)malloc(zlenmax))==NULL) {
			GRF_SETERR(error,GE_ERRNO,malloc);
			return NULL;
		}
		/* storing "compressed" length into zlen */
		if ((z=compress((Bytef*)zbuf, &zlen, (const Bytef*)buf, 0))!=Z_OK) {
			GRF_SETERR_2(error,GE_ZLIB,compress,(ssize_t)z);  /* NOTE: uint => ssize_t /-signed-/ => uintptr* conversion */
			return NULL;
		}
		zlen_le = ToLittleEndian32(zlen);

		if (0==fwrite(GRF_HEADER, GRF_HEADER_LEN, 1, grf->f) ||               /* MoM header */
		  0==fwrite(&crypt_watermark, sizeof(crypt_watermark), 1, grf->f) ||  /* 00 01 ... */
		  0==fwrite(&zero, sizeof(uint32_t), 1U, grf->f) ||                   /* offset */
		  0==fwrite(&zero, sizeof(uint32_t), 1U, grf->f) ||                   /* seed */
		  0==fwrite(&zero_fcount, sizeof(uint32_t), 1U, grf->f) ||            /* filecount + 7 */
		  0==fwrite(&create_ver, sizeof(uint32_t), 1U, grf->f) ||             /* 0x200 */
		  0==fwrite(&zlen_le, sizeof(uint32_t), 1U, grf->f) ||                /* comp tbl size */
		  0==fwrite(&zero, sizeof(uint32_t), 1U, grf->f) ||                   /* nfiles */
		  0==fwrite(zbuf, zlen, 1U, grf->f)) {                                /* table */
			free(zbuf);
			GRF_SETERR(error,GE_ERRNO,fwrite);
			return NULL;
		}
		free(zbuf);
		if (0!=fseek(grf->f,0,SEEK_SET)) {
			GRF_SETERR(error,GE_ERRNO,fseek);
			return NULL;
		}
	}

	/* Read the header */
	if (!fread(buf, GRF_HEADER_FULL_LEN, 1, grf->f)) {
		if (feof(grf->f))
			GRF_SETERR(error,GE_INVALID,grf_callback_open);
		else
			GRF_SETERR(error,GE_ERRNO,fread);
		grf_free(grf);
		return NULL;
	}

	/* Check the header */
	if (memcmp(buf, GRF_HEADER, GRF_HEADER_LEN)) {
		grf_free(grf);
		GRF_SETERR(error,GE_INVALID,grf_callback_open);
		return NULL;
	}

	/* Continued header check...
	 *
	 * GRF files that allow encryption of the files inside the archive
	 * have a hex header following "Master of Magic" (not including
	 * the nul-terminator) that looks like:
	 * 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E
	 *
	 * GRF files that do not allow it have a hex header that looks like:
	 * 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	 *
	 * GRF files that do not allow it are generally found after a
	 * "Ragnarok.exe /repak" command has been issued
	 */
	if (buf[GRF_HEADER_LEN+1]==1) {
		grf->allowCrypt=1;
		/* 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E */
		for (i=0;i<0xF;i++)
			if (buf[GRF_HEADER_LEN+i] != (int)i) {
				grf_free(grf);
				GRF_SETERR(error,GE_CORRUPTED,grf_callback_open);
				return NULL;
			}
	}
	else if (buf[GRF_HEADER_LEN]==0) {
		grf->allowCrypt=0;
		/* 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 */
		for (i=0;i<0xF;i++)
			if (buf[GRF_HEADER_LEN+i] != 0) {
				grf_free(grf);
				GRF_SETERR(error,GE_CORRUPTED,grf_callback_open);
				return NULL;
			}
	}
	else {
		grf_free(grf);
		GRF_SETERR(error,GE_CORRUPTED,grf_callback_open);
		return NULL;
	}

	/* Okay, so we finally are sure that its a valid GRF/GPF file.
	 * now its time to read info from it
	 */

	/* Set the type of archive this is */
	grf->type=GRF_TYPE_GRF;

	/* Read the version */
	grf->version=LittleEndian32(buf+GRF_HEADER_MID_LEN+0xC);

	/* Read the number of files */
	grf->nfiles=LittleEndian32(buf+GRF_HEADER_MID_LEN+8)-LittleEndian32(buf+GRF_HEADER_MID_LEN+4)-7;

	/* Create the array of files */
	if (grf->nfiles) {
		if ((grf->files=(GrfFile*)calloc(grf->nfiles,sizeof(GrfFile)))==NULL) {
			grf_free(grf);
			GRF_SETERR(error,GE_ERRNO,calloc);
			return NULL;
		}
	}

	/* Grab the filesize */
	if (fseek(grf->f, 0, SEEK_END)) {
		grf_free(grf);
		GRF_SETERR(error,GE_ERRNO,fseek);
		return NULL;
	}
	if (ftell(grf->f)==-1) {
		grf_free(grf);
		GRF_SETERR(error,GE_ERRNO,ftell);
		return NULL;
	}
	grf->len=ftell(grf->f);

	/* Seek to the offset of the file tables */
	if (fseek(grf->f, LittleEndian32(buf+GRF_HEADER_MID_LEN)+GRF_HEADER_FULL_LEN, SEEK_SET)) {
		grf_free(grf);
		GRF_SETERR(error,GE_ERRNO,fseek);
		return NULL;
	}

	/* Run a different function to read the file information based on
	 * the major version number
	 */
	switch (grf->version&0xFF00) {
	case 0x0200:
		i=GRF_readVer2_info(grf,error,callback);
		break;
	case 0x0100:
		i=GRF_readVer1_info(grf,error,callback);
		break;
	default:
		GRF_SETERR(error,GE_NSUP,grf_callback_open);
		i=1;
	}

	if (i) {
		grf_free(grf);
		return NULL;
	}

	GRF_SETERR(error,GE_SUCCESS,grf_callback_open);
	return grf;
}


/** Extract a file inside a GRF file into memory.
 *
 * @param grf    Pointer to a Grf structure, as returned by grf_callback_open()
 * @param fname  Exact filename of the file to be extracted
 * @param size   Pointer to a location in memory where the size of memory
 *               extracted should be stored.
 * @param error  Pointer to a GrfErrorType struct/enum for error reporting
 * @return       A pointer to data that has been extracted, NULL if an error
 *               has occurred. The pointer must not be freed manually.
 */
GRFEXPORT void *
grf_get (Grf *grf, const char *fname, uint32_t *size, GrfError *error)
{
	uint32_t i;

	/* Make sure we've got valid arguments */
	if (!grf || !fname) {
		GRF_SETERR(error,GE_BADARGS,grf_get);
		return NULL;
	}

	/* Find the file inside the GRF */
	if (!grf_find(grf,fname,&i)) {
		GRF_SETERR(error,GE_NOTFOUND,grf_get);
		return NULL;
	}

	/* Get the file from its index */
	return grf_index_get(grf,i,size,error);
}


/*! \brief Extract a file (pointed to by its index) into memory
 *
 * \param grf Pointer to a Grf structure, as returned by grf_callback_open()
 * \param index Index of the file to be extracted
 * \param size Pointer to a location in memory where the size of memory
 *	extracted should be stored
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \return A pointer to data that has been extracted, NULL if an error
 *	has occurred. The pointer must not be freed manually.
 */
GRFEXPORT void *
grf_index_get (Grf *grf, uint32_t index, uint32_t *size, GrfError *error)
{
	uLongf zlen;
	int z;
	uint32_t rsiz, zsiz;
	char *zbuf;

	/* Make sure we've got valid arguments */
	if (!grf || grf->type!=GRF_TYPE_GRF) {
		GRF_SETERR(error,GE_BADARGS,grf_index_get);
		return NULL;
	}
	if (index>=grf->nfiles) {
		GRF_SETERR(error,GE_INDEX,grf_index_get);
		return NULL;
	}

	/* Check to see if the file is actually a directory entry */
	if (GRFFILE_IS_DIR(grf->files[index])) {
		/*! \todo Create a directory contents listing instead
		 *	of just returning "<directory>"
		 */
		*size = 12;
		return "<directory>";
	}

	/* Return NULL if there is no data */
	if (!grf->files[index].real_len) {
		GRF_SETERR(error,GE_NODATA,grf_index_get);
		*size=0;
		return NULL;
	}

	/* Check to see if the filedata has has been extracted already
	 * (or never compressed/encrypted)
	 */
	if (grf->files[index].data) {
		*size = grf->files[index].real_len;
		return grf->files[index].data;
	}

	/* Retrieve the unencrypted block */
	if ((zbuf = grf_index_get_z(grf, index, &zsiz, &rsiz, error))==NULL) {
		return NULL;
	}

	/* Allocate memory to write into */
	/* grf->files[i].data */
	if ((grf->files[index].data=(char*)malloc(rsiz+1))==NULL) {
		GRF_SETERR(error,GE_ERRNO,malloc);
		return NULL;
	}

	/* Make sure uncompress doesn't modify our file information */
	zlen = rsiz;

	/* Set success first, in case of Z_DATA_ERROR */
	GRF_SETERR(error,GE_SUCCESS,grf_index_get);

	/* Uncompress the data, and catch any errors */
	if ((z=uncompress((Bytef*)grf->files[index].data,&zlen,(const Bytef *)zbuf, (uLong)zsiz))!=Z_OK) {
		/* Ignore Z_DATA_ERROR */
		if (z == Z_DATA_ERROR) {
			/* Set an error, just don't crash out */
			GRF_SETERR_2(error,GE_ZLIB,uncompress,(ssize_t)z);  /* NOTE: uint => ssize_t /-signed-/ => uintptr* conversion */

		} else {
			free(grf->files[index].data);
			grf->files[index].data = NULL;
			GRF_SETERR_2(error,GE_ZLIB,uncompress,(ssize_t)z);  /* NOTE: uint => ssize_t /-signed-/ => uintptr* conversion */
			return NULL;
		}
	}
	*size = zlen;

#undef NEVER_DEFINED
#ifdef NEVER_DEFINED
	/* Check for different sizes */
	if (zlen!=gfile->real_len) {
		/* Something might be wrong, but I've never
		 * seen this happen
		 */
	}
#endif /* NEVER_DEFINED */

	/* Throw a nul-terminator on the extra byte we allocated */
	*(char*)(grf->files[index].data + *size) = 0;

	grf->files[index].real_len = zlen;

	/* Return our decrypted, uncompressed data */
	return grf->files[index].data;
}


/*! \brief Retrieve the compressed block of a file (pointed to by its index)
 *
 * \sa grf_get_z
 * \sa grf_index_get
 *
 * \param grf Pointer to a Grf structure, as returned by grf_callback_open()
 * \param index Index of the file to be retrieved
 * \param size [out] Pointer to a location in memory where the size of the memory
 *	block should be stored
 * \param usize [out] Pointer to a location in memory where the size of data
 *	once uncompressed should be stored
 * \param error [out] Pointer to a GrfError variable for error reporting. May be NULL.
 * \return A pointer to a memory block corresponding to the requested file, NULL if an error
 *	has occurred. This block shall not be free()'d, the user should make a separate copy instead.
 *	If the requested file is a directory, the special value GRFFILE_DIR_OFFSET is returned,
 *	cast to void* and *size is set to GRFFILE_DIR_SZFILE, *usize to GRFFILE_DIR_SZORIG.
 */
GRFEXPORT void *grf_index_get_z(Grf *grf, uint32_t index, uint32_t *size, uint32_t *usize, GrfError *error) {
	GrfFile *gfile;
	char keyschedule[0x80], key[8], *buf, *zbuf;

	/* Make sure we've got valid arguments */
	if (!grf || grf->type!=GRF_TYPE_GRF) {
		GRF_SETERR(error,GE_BADARGS,grf_index_get_z);
		return NULL;
	}
	if (index>=grf->nfiles) {
		GRF_SETERR(error,GE_INDEX,grf_index_get_z);
		return NULL;
	}

	/* Check to see if the file is actually a directory entry */
	if (GRFFILE_IS_DIR(grf->files[index])) {
		*size=GRFFILE_DIR_SZFILE;
		*usize=GRFFILE_DIR_SZORIG;
		return (void *)GRFFILE_DIR_OFFSET;
	}

	/* Grab the file information */
	gfile=&(grf->files[index]);

	/* Return NULL if there is no data */
	if (!gfile->real_len) {
		GRF_SETERR(error,GE_NODATA,grf_index_get_z);
		return NULL;
	}

	/* Allocate memory to hold compressed, but not encrypted data */
	if ((zbuf=(char*)malloc(gfile->compressed_len_aligned))==NULL) {
		GRF_SETERR(error,GE_ERRNO,malloc);
		return NULL;
	}

	/* Allocate memory to hold data read directly from the GRF,
	 * may or may not be encrypted
	 */
	if ((buf=(char*)malloc(gfile->compressed_len_aligned))==NULL) {
		free(zbuf);
		GRF_SETERR(error,GE_ERRNO,malloc);
		return NULL;
	}

	/* Read the data */
	if (fseek(grf->f,gfile->pos,SEEK_SET)) {
		free(buf);
		free(zbuf);
		GRF_SETERR(error,GE_ERRNO,fseek);
		return NULL;
	}
	if (!fread(buf,gfile->compressed_len_aligned,1,grf->f)) {
		free(buf);
		free(zbuf);
		if (feof(grf->f))
			GRF_SETERR(error,GE_CORRUPTED,grf_index_get);
		else
			GRF_SETERR(error,GE_ERRNO,grf_index_get);
		return NULL;
	}

	/* Create a key and use it to generate the key schedule */
	DES_CreateKeySchedule(keyschedule,GRF_GenerateDataKey(key,gfile->name));

	/* Decrypt the data (if its encrypted) */
	GRF_Process(zbuf,buf,gfile->compressed_len_aligned,gfile->flags,gfile->compressed_len,keyschedule,GRFCRYPT_DECRYPT);

	free(buf);

	*size=gfile->compressed_len_aligned;
	*usize=gfile->real_len;
	free(grf->zbuf);
	grf->zbuf = zbuf;
	return (void *)zbuf;
}

/*! \brief Retrieve the compressed block of a file
 *
 * \sa grf_index_get_z
 * \sa grf_get
 *
 * \param grf Pointer to a Grf structure, as returned by grf_callback_open()
 * \param fname Exact filename of the file to be extracted
 * \param size [out] Pointer to a location in memory where the size of the memory
 *	block should be stored
 * \param error [out] Pointer to a GrfError variable for error reporting. May be NULL.
 * \param usize [out] Pointer to a location in memory where the size of data
 *	once uncompressed should be stored
 * \return A pointer to a memory block corresponding to the requested file, NULL if an error
 *	has occurred. This block shall not be free()'d, the user should make a separate copy instead.
 *	If the requested file is a directory, the special value GRFFILE_DIR_OFFSET is returned,
 *	cast to void* and *size is set to GRFFILE_DIR_SZFILE, *usize to GRFFILE_DIR_SZORIG.
 */
GRFEXPORT void *grf_get_z (Grf *grf, const char *fname, uint32_t *size, uint32_t *usize, GrfError *error) {
	uint32_t i;

	/* Make sure we've got valid arguments */
	if (!grf || !fname) {
		GRF_SETERR(error,GE_BADARGS,grf_get);
		return NULL;
	}

	/* Find the file inside the GRF */
	if (!grf_find(grf,fname,&i)) {
		GRF_SETERR(error,GE_NOTFOUND,grf_get);
		return NULL;
	}

	/* Get the file from its index */
	return grf_index_get_z(grf,i,size,usize,error);
}


/** Retrieve an uncompressed block of data from a file.
 *
 * @see grf_get
 * @see grf_index_chunk_get
 *
 * @param grf      Pointer to a Grf structure, as returned by grf_callback_open()
 * @param fname    Full filename of the GrfFile to read from
 * @param buf      Pointer to a buffer to write the chunk into
 * @param offset   Offset inside the GrfFile to begin reading
 * @param len      [in] Amount of data to read into buf
 *                 [out] Amount of data actually read
 * @param error    Pointer to a GrfErrorType struct/enum for error reporting
 * @return If successful, it returns buf. Otherwise, NULL
 */
GRFEXPORT void *
grf_chunk_get (Grf *grf, const char *fname, char *buf, uint32_t offset, uint32_t *len, GrfError *error)
{
	uint32_t i;
	
	/* Check our arguments */
	if (!grf || !fname || grf->type!=GRF_TYPE_GRF) {
		GRF_SETERR(error,GE_BADARGS,grf_chunk_get);
		*len=0;
		return NULL;
	}
	
	/* Use grf_find() to get the index */
	if (!grf_find(grf,fname,&i)) {
		GRF_SETERR(error,GE_NOTFOUND,grf_chunk_get);
		*len=0;
		return NULL;
	}
	
	/* Use grf_index_chunk_get() */
	return grf_index_chunk_get(grf, i, buf, offset, len, error);
}


/** Retrieve a decompressed block of data from a file.
 *
 * @see grf_index_get()
 * @see grf_chunk_get()
 *
 * @param grf     Pointer to a Grf structure, as returned by grf_callback_open()
 * @param index   Index of the Grf::files entry to be deleted
 * @param buf     Pointer to a buffer to write the chunk into
 * @param offset  Offset inside the GrfFile to begin reading
 * @param len     [in] Amount of data to read into buf.
 *		  [out] Amount of data actually read, 0 if error or no data
 * @param error   Pointer to a GrfErrorType struct/enum for error reporting
 * @return If successful, a duplicate pointer to buf. Otherwise, NULL
 */
GRFEXPORT void *
grf_index_chunk_get (Grf *grf, uint32_t index, char *buf, uint32_t offset, uint32_t *len, GrfError *error)
{
	void *fullbuf;
	uint32_t fullsize;
	
	/* Check our arguments */
	if (!grf || !buf || !len) {
		GRF_SETERR(error,GE_BADARGS,grf_index_chunk_get);
		*len=0;
		return NULL;
	}
	
	/* Extract our file */
	if ((fullbuf=grf_index_get(grf,index,&fullsize,error))==NULL) {
		*len=0;
		return NULL;
	}
	
	/* Decide how much data we actually have to give 'em */
	if (offset>=fullsize) {
		GRF_SETERR(error,GE_NODATA,grf_index_chunk_get);
		*len=0;
		return NULL;
	}
	if (*len>fullsize-offset)
		*len=fullsize-offset;
	
	/* Copy the memory */
	memcpy(buf, (void *) ((char *) (fullbuf) + offset), *len);

	/* Return the memory */
	return buf;
}

/** Extract a file in the archive to an external file.
 *
 * @param grf Pointer to a Grf structure, as returned by grf_callback_open()
 * @param grfname Full filename of the Grf::files file to extract
 * @param file Filename to write the data to
 * @param error Pointer to a GrfError structure for error reporting
 * @return The number of successfully extracted files
 */
GRFEXPORT int
grf_extract (Grf *grf, const char *grfname, const char *file, GrfError *error)
{
	uint32_t i;

	if (!grf || !grfname || grf->type!=GRF_TYPE_GRF) {
		GRF_SETERR (error, GE_BADARGS, grf_extract);
		return 0;
	}

	if (!grf_find (grf,grfname, &i)) {
		GRF_SETERR (error, GE_NOTFOUND, grf_extract);
		return 0;
	}
	return grf_index_extract (grf, i, file, error);
}

/** Extract to a file, taking index instead of filename.
 *
 * @param grf Pointer to a Grf structure, as returned by grf_callback_open()
 * @param index The Grf::files index number to extract
 * @param file Filename to write the data to
 * @param error Pointer to a GrfErrorType struct/enum for error reporting
 * @return The number of successfully extracted files
 */
GRFEXPORT int
grf_index_extract (Grf *grf, uint32_t index, const char *file, GrfError *error)
{
	void *buf;
	char *fixedname;
	uint32_t size,i;
	FILE *f;

	/* Make sure we have a filename to write to */
	if (!file) {
		GRF_SETERR (error, GE_BADARGS, grf_index_extract);
		return 0;
	}

	/* Normalize the filename */
	if ((fixedname = (char *) malloc (strlen (file) + 1)) == NULL) {
		GRF_SETERR (error, GE_ERRNO, malloc);
		return 0;
	}
	GRF_normalize_path (fixedname,file);

	/* Read the data */
	if ((buf = grf_index_get (grf, index, &size, error)) == NULL) {
		/* Check if the file actually has no data */
		if (error->type != GE_NODATA)
			return 0;
	}

	/* Open the file we should write to */
	f = fopen (fixedname, "wb");
	if (f == NULL) {
		free(buf);
		grf->files[index].data = NULL;
		GRF_SETERR (error, GE_ERRNO, fopen);
		return 0;
	}

	/* Write the data */
	i = (uint32_t) fwrite (buf, size, 1, f);
	if (0 == i) {  /* NOTE: size_t => uint32_t conversion */
		GRF_SETERR (error, GE_ERRNO, fwrite);
	}

	/* Clean up and return */
	fclose (f);
	free (buf);
	grf->files[index].data = NULL;
	return (i) ? 1 : 0;
}

/*! \brief Delete a file from the file table
 *
 * \param grf Pointer to a Grf structure, as returned by grf_callback_open()
 * \param fname Exact filename of the file to be deleted
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \return The number of files deleted from the GRF archive
 */
GRFEXPORT int
grf_del(Grf *grf, const char *fname, GrfError *error)
{
	uint32_t i;

	/* Make sure we've got valid arguments */
	if (!grf || !fname) {
		GRF_SETERR(error,GE_BADARGS,grf_del);
		return 0;
	}

	if (grf->allowWrite == 0) {
		GRF_SETERR(error,GE_BADMODE,grf_del);
		return 0;
	}

	/* Find the file inside the GRF */
	if (!grf_find(grf,fname,&i)) {
		GRF_SETERR(error,GE_NOTFOUND,grf_del);
		return 0;
	}

	/* Delete the file, using its index */
	return grf_index_del(grf,i,error);
}


/** Delete a file from the file table, taking index instead of name.
 *
 * @param grf   Pointer to information about the GRF to delete from.
 * @param index Index of the Grf::files entry to be deleted.
 * @param error Pointer to a GrfError structure for error reporting.
 * @return The number of files deleted from the GRF archive.
 */
GRFEXPORT int
grf_index_del (Grf *grf, uint32_t index, GrfError *error)
{
	uint32_t i;

	/* Check our arguments */
	if (grf == NULL) {
		GRF_SETERR (error, GE_BADARGS, grf_index_del);
		return 0;
	}
	if (grf->allowWrite == 0) {
		GRF_SETERR (error,GE_BADMODE, grf_index_del);
		return 0;
	}

	/* Check the index */
	if (index >= grf->nfiles) {
		GRF_SETERR (error, GE_INDEX, grf_index_del);
		return 0;
	}

	/* Free the memory stored by GrfFile::data */
	free (grf->files[index].data);

	/* Loop through, moving each entry forward */
	for (i = index; i < grf->nfiles - 1; i++) {
		memcpy(&(grf->files[i]),&(grf->files[i+1]),sizeof(GrfFile));
	}

	/* 1 fewer file */
	grf->nfiles--;

	/* Resize the GrfFile array */
	grf->files = (GrfFile *) realloc (grf->files, grf->nfiles * sizeof (GrfFile));
	if (grf->files == NULL) {
		/* Bomb out? It just doesn't seem the best option */
		GRF_SETERR (error, GE_ERRNO, realloc);

		/* Really return 0? The file was removed though... */
		return 0;
	}

	GRF_SETERR (error, GE_SUCCESS, grf_index_del);
	return 1;
}


/** Replace the data of an existing file inside the GRF archive.
 *
 * @param grf   Pointer to a Grf structure, as returned by grf_callback_open()
 * @param name  Name of the file inside the GRF.
 * @param data  Pointer to the replacement data.
 * @param len   Length of the replacement data.
 * @param flags Must be set to GRFFILE_FLAG_FILE.
 * @param error Pointer to a GrfError structure for error reporting.
 *
 * @return The number of files successfully replaced.
 *
 * @see grf_index_replace(), grf_put()
 */
GRFEXPORT int
grf_replace (Grf *grf, const char *name, const void *data, uint32_t len, uint8_t flags, GrfError *error)
{
	uint32_t i;

	/* Make sure we've got valid arguments */
	if (grf == NULL || name == NULL) {
		GRF_SETERR (error, GE_BADARGS, grf_replace);
		return 0;
	}
	if (grf->allowWrite == 0) {
		GRF_SETERR (error, GE_BADMODE, grf_replace);
		return 0;
	}

	/* Find the file inside the GRF */
	if (!grf_find (grf, name, &i)) {
		GRF_SETERR (error, GE_NOTFOUND, grf_replace);
		return 0;
	}

	/* Replace the file, using its index */
	return grf_index_replace (grf, i, data, len, flags, error);
}


/** Replace the data of a file.
 *
 * @param grf   Pointer to a Grf structure, as returned by grf_callback_open().
 * @param index Index of the Grf::files entry to be replaced.
 * @param data  Pointer to the replacement data.
 * @param len   Length of the replacement data.
 * @param flags Must be set to #GRFFILE_FLAG_FILE.
 * @param error Pointer to a GrfError structure for error reporting.
 *
 * @return The number of files successfully replaced
 *
 * @see grf_replace(), grf_put()
 */
GRFEXPORT int
grf_index_replace (Grf *grf, uint32_t index, const void *data, uint32_t len, uint8_t flags, GrfError *error)
{
	GrfFile *gf;

	/* Check our arguments */
	if (!grf || (!data && len>0)) {
		GRF_SETERR(error,GE_BADARGS,grf_index_replace);
		return 0;
	}
	if (grf->allowWrite == 0) {
		GRF_SETERR(error,GE_BADMODE,grf_index_del);
		return 0;
	}

	/* Check the index */
	if (index>=grf->nfiles) {
		GRF_SETERR(error,GE_INDEX,grf_index_replace);
		return 0;
	}

	gf=&(grf->files[index]);

	/* Make sure the data is longer than 0 bytes */
	if (len>0) {
		/* Reallocate the memory */
		if ((grf->files[index].data=(void*)realloc(grf->files[index].data,len))==NULL) {
			GRF_SETERR(error,GE_ERRNO,realloc);
			return 0;
		}

		/* Copy the memory */
		memcpy(grf->files[index].data,data,len);
	}
	else {
		/* Free anything that was there */
		free(grf->files[index].data);

		/* Point to NULL */
		grf->files[index].data=NULL;
	}

	/* Treat directories seperately */
	gf->flags=flags;
	if (flags&GRFFILE_FLAG_FILE) {
		/* Update old info */
		gf->real_len=len;

		/* These will be set with grf_callback_flush() when the data is compressed,
		 * encrypted, and written
		 */
		gf->compressed_len=/*0;*/
		gf->compressed_len_aligned=/*0;*/
		gf->pos=0;
	}
	else {
		gf->compressed_len=GRFFILE_DIR_SZSMALL;
		gf->compressed_len_aligned=GRFFILE_DIR_SZFILE;
		gf->real_len=GRFFILE_DIR_SZORIG;
		gf->pos=GRFFILE_DIR_OFFSET;
	}

	GRF_SETERR(error,GE_SUCCESS,grf_index_replace);
	return 1;
}


/** Add a file into a write-enabled grf archive.
 *
 * @warning Not testing when file already exists and trying to replace with a different type (is GRFFILE_FLAG_FILE set?). To be carefully debugged.
 *
 * @param grf   Pointer to a Grf structure, as returned by grf_callback_open().
 * @param name  Name of the destination file inside the GRF.
 * @param data  Pointer to the file data.
 * @param len   Length of the data.
 * @param flags Must be set to #GRFFILE_FLAG_FILE.
 * @param error Pointer to a GrfError structure for error reporting.
 *
 * @return The number of files successfully added.
 */
GRFEXPORT int
grf_put (Grf *grf, const char *name, const void *data, uint32_t len, uint8_t flags, GrfError *error)
{
	int i;
	uint32_t namelen;
	/* Since realloc() is used, it doesn't matter if we work on temporary buffers,
	 * because we are extending the realloc()'d buffers.
	 */
	GrfFile* realloc_files;


	/* Check our arguments */
	if (!grf || !name || (!data && len > 0)) {
		GRF_SETERR (error, GE_BADARGS, grf_put);
		return 0;
	}
	if (grf->allowWrite == 0) {
		GRF_SETERR (error, GE_BADMODE, grf_put);
		return 0;
	}
	namelen = (uint32_t) strlen(name) + 1;  /* NOTE: size_t => uint32_t conversion */

	/* Make sure its not too large */
	if (namelen >= GRF_NAMELEN) {
		/* Not very transparent in the way of passing errors */
		GRF_SETERR (error, GE_BADARGS, grf_put);
		return 0;
	}

	/* Try replacing an existing file.
	 * Note that this will set the error if replace failed.
	 */
	i = grf_replace(grf,name,data,len,flags,error);
	if (i > 0)
		return i;

	if (error->type != GE_NOTFOUND)
		return 0;

	/* The file does not exist */

	/* Resize the GrfFile array */
	if ((realloc_files = (GrfFile*)realloc(grf->files,(grf->nfiles+1)*sizeof(GrfFile)))==NULL) {
		GRF_SETERR(error,GE_ERRNO,realloc);
		return 0;
	}
	/* if the current function fails later on, the realloc_files buffer
	 * is larger than the expected size but it doesn't matter.
	 */
	grf->files = realloc_files;
	memset(&grf->files[grf->nfiles], 0x00, sizeof(GrfFile));

	/* Set filename */
	memcpy(grf->files[grf->nfiles].name,name,namelen);
	grf->files[grf->nfiles].hash=GRF_NameHash(name);

	/* This may be reverted if there's an error */
	++grf->nfiles;
	/* reusing code from grf_index_replace();
	 * Setting the rest of the information (about compression)
	 * has to be taken care of by grf_callback_flush()
	 */
	if (0==grf_index_replace(grf,grf->nfiles-1,data,len,flags,error)) {
		--grf->nfiles;
		return 0;
	}

	GRF_SETERR(error,GE_SUCCESS,grf_put);
	return 1;
}


/** Save modified data of a GRF file.
 *
 * @note This may or may not (depending on how its written) leave data
 *	inside the GRF that is never used. A planned grf_repak
 *	will deal with this (and will completely restructure the GRF)
 *
 * @param grf Pointer to a Grf structure, as returned by grf_callback_open()
 * @param error Pointer to a GrfError structure for error reporting
 * @param callback Function to call for each file being flushed to disk.
 *		The first parameter received by this function is the address of a
 *		GrfFile structure which contains information about the file that is
 *		about to be processed. The files that reside in memory have their
 *		compressed_len field set to zero and their real_len non-zero.
 *		The function should return 0 if everything is fine, 1 if the file
 *		shall not be written but processing may continue, 2 if any further
 *		compression shall be stopped, leaving uncompressed files in memory, but
 *		flushing those already compressed, or -1 if there has been an error
 * @return 0 if an error occurred, 1 if all is good
 *
 * @see grf_flush
 */
GRFEXPORT int
grf_callback_flush(Grf *grf, GrfError *error, GrfFlushCallback callback)
{
	int i;

	/* Sort the file infos by offset, to ensure GRF_find_unused will not return
	 * bogus information.
	 */
	grf_sort(grf, GRF_OffsetSort);

	/* Fix the linked list */
	if ((i = GRF_list_from_array(grf, error)) == 0)
		return i;

	switch (grf->version & 0xFF00) {
	case 0x0200:
		i = GRF_flushVer2(grf, error, callback);
		break;
	case 0x0100:
		i = GRF_flushVer1(grf, error, callback);
		break;
	default:
		GRF_SETERR(error, GE_NSUP, grf_callback_flush);
		i = 0;
	}

	if (i)
		i = GRF_array_from_list(grf, error);

	return i;
}


/** Save and close a GRF file, and free allocated memory.
 *
 * @param grf The Grf variable to close.
 */
GRFEXPORT void
grf_close(Grf *grf)
{
	/* Ensure they're not sending us bullshit */
	if (!grf)
		return;

	if (grf->allowWrite) {
		/* Flush any data that hasn't been written yet */
		grf_flush(grf, NULL);	/* Any errors? Too bad, so sad */
	}

	/* Close and free the GRF file */
	grf_free(grf);
}


/** Free the memory allocated by a Grf variable.
 *
 * @warning This will not save any data! You may want to use grf_close() instead.
 *
 * @param grf The Grf variable to close.
 */
GRFEXPORT void
grf_free(Grf *grf)
{
	uint32_t i;

	/* Ensure we don't have access violations when freeing NULLs */
	if (!grf)
		return;

	/* Free the grf name */
	free(grf->filename);

	/* Free the array of files */
	for (i = 0; i < grf->nfiles; i++)
		free(grf->files[i].data);

	/* Free the array of files */
	free(grf->files);

	free(grf->zbuf);

	/* Close the file */
	if (grf->f)
		fclose(grf->f);

	/* And finally, free the pointer itself */
	free(grf);
}


/** Completely restructure a GRF archive.
 *
 * @param grf    Filename of the original GRF
 * @param tmpgrf Filename to use temporarily while restructuring
 * @param error  Pointer to a GrfErrorType struct/enum for error reporting
 * @return 0 if an error occurred, 1 if repacking failed
 */
GRFEXPORT int
grf_repak(const char *grf, const char *tmpgrf, GrfError *error)
{
	/** @todo Write this code! */
	GRF_SETERR(error,GE_NOTIMPLEMENTED,grf_repak);
	return 0;
}


GRFEXTERN_END
