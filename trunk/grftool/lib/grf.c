/*
 *  libgrf
 *  grf.c - read and manipulate GRF/GPF files
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
#define GRF_HEADER_LEN		(sizeof(GRF_HEADER)-1)	/* -1 to strip
							 * null terminator
							 */
#define GRF_HEADER_MID_LEN	(sizeof(GRF_HEADER)+0xE)	/* -1 + 0xF */
#define GRF_HEADER_FULL_LEN	(sizeof(GRF_HEADER)+0x1E)	/* -1 + 0x1F */

/*! \brief Special file extensions
 *
 * Files with these extentions are handled differently in GPFs
 */
static const char specialExts[][5] = {
	".gnd",
	".gat",
	".act",
	".str"
};

/********************
* Private Functions *
********************/

/*! \brief Simplicity Macro
 *
 * Macro to make it easier to call GRF_CheckExtFunc
 */
#define GRF_CheckExt(a,b) GRF_CheckExtFunc(a,b,sizeof(b))
/*! \brief Private function to check filename extensions
 *
 * Checks the last 4 characters of a filename for
 * a specific extension
 *
 * \param filename The filename to search for the extension
 * \param extlist A list of each extension to search for
 * \param listsize The number of extensions in the list
 * \return 0 if none of the extensions match, 1 if a match was found
 */
static int GRF_CheckExtFunc(const char *filename, const char extlist[][5], size_t listsize) {
	uint32_t i;

	if (listsize<1)
		return 0;

	/* Find the last X bytes of the filename, where X is extension size */
	i=strlen(filename);
	if (i<4) return 0;
	filename+=(i-4);

	/* Check if the file has any of the extensions */
	for (i=0;i<listsize;i++)
		if (!strcasecmp(filename,extlist[i]))
			return 1;

	return 0;
}

#ifdef GRF_FIXED_KEYSCHEDULE
/*! \brief Private function to convert a int32_t into an ASCII character string
 *
 * \warning dst is not checked for sanity (valid pointer, max length, etc)
 *
 * \param dst A character string to store the data in
 * \param src int32_t to be converted into an ASCII string
 * \param base The base to use while converting
 * \return A duplicate pointer to the data
 */
static char *GRF_ltoa(char *dst, int32_t src, uint8_t base) {
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

/*! \brief Private utility function to swap the nibbles of
 *	each byte in a string
 *
 * \warning Pointers are not checked for validity
 * \note dst should be able to hold at least len characters, and
 *		src should hold at least len characters
 *
 * \param dst Pointer to destination (nibble-swapped) data
 * \param src Pointer to source (unswapped) data
 * \param len Length of data to swap
 * \return A duplicate pointer to data stored by dst
 */
static uint8_t *GRF_SwapNibbles(uint8_t *dst, const uint8_t *src, uint32_t len) {
	uint8_t *orig;
	orig=dst;

	for (;len>0;dst++,src++,len--)
		*dst=(*src<<4) | (*src>>4);

	return orig;
}

#ifdef GRF_FIXED_KEYSCHEDULE
/*! \brief Private function to generate a key for crypting data
 *
 * \warning Pointers aren't checked
 *
 * \param key Pointer to the 8 bytes in which the key should be stored
 * \param src String to retrieve parts of data for key generation
 * \return Duplicate pointer to data stored at by key
 */
static char *GRF_GenerateDataKey(char *key, const char *src) {
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
		GRF_SETERR(error,GE_ERRNO,fseek);
		free(buf);
		return 1;
	}
	if (!fread(buf,len,1,grf->f)) {
		if (feof(grf->f))
			/* When would it ever get here? Oh well, just in case */
			GRF_SETERR(error,GE_CORRUPTED,fread);
		else
			GRF_SETERR(error,GE_ERRNO,fread);
		free(buf);
		return 1;
	}

#undef NEVER_DEFINED
#ifdef NEVER_DEFINED
	/* GRAVITY has a version check here, even though it is impossible
	 * to get this far without version being greater than 0xFF and less
	 * than 0x200
	 */
	if (version==0) {
		/* We're not dumb, so I won't bother coding here */
	}
#endif /* defined(NEVER_DEFINED) */

#ifdef GRF_FIXED_KEYSCHEDULE
	keygen102=1;
	keygen101=95001;
#else /* !defined(GRF_FIXED_KEYSCHEDULE) */
	/* Make sure our keyschedule is just like their broken one will be */
	memset(keyschedule,0,0x80);
#endif /* !defined(GRF_FIXED_KEYSCHEDULE) */

	/* Read information about each file */
	for (i=offset=0;i<grf->nfiles;i++
#ifdef GRF_FIXED_KEYSCHEDULE
,keygen102+=5,keygen101-=2
#endif /* defined(GRF_FIXED_KEYSCHEDULE) */
) {
		/* Get the name length */
		len=LittleEndian32(buf+offset);
		offset+=4;

		/* Decide how to decode the name */
		if (grf->version<0x101) {
			/* Make sure name isn't too long */
			len2=strlen(buf+offset);
			if (len2>=GRF_NAMELEN) {
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
#endif /* defined(GRF_FIXED_KEYSCHEDULE */

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
		grf->files[i].type=*(uint8_t*)(buf+offset+0xC);
		grf->files[i].pos=LittleEndian32(buf+offset+0xD)+GRF_HEADER_FULL_LEN;
		grf->files[i].hash=GRF_NameHash(grf->files[i].name);

		/* Check if the file is a special file */
		if (GRF_CheckExt(grf->files[i].name,specialExts))
			grf->files[i].type|=GRFFILE_FLAG_0x14_DES;
		else
			grf->files[i].type|=GRFFILE_FLAG_MIXCRYPT;

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
		if (feof(grf->f))
			GRF_SETERR(error,GE_CORRUPTED,GRF_readVer2_info);
		else
			GRF_SETERR(error,GE_ERRNO,fread);
		free(buf);
		return 1;
	}

	/* Allocate memory and read the compressed file table */
	len=LittleEndian32(buf);
	if ((zbuf=(char*)malloc(len))==NULL) {
		GRF_SETERR(error,GE_ERRNO,malloc);
		free(buf);
		return 1;
	}
	if (!fread(zbuf,len,1,grf->f)) {
		if (feof(grf->f))
			GRF_SETERR(error,GE_CORRUPTED,GRF_readVer2_info);
		else
			GRF_SETERR(error,GE_ERRNO,fread);
		free(buf);
		free(zbuf);
		return 1;
	}

	/* Allocate memory and uncompress the compressed file table */
	len2=LittleEndian32(buf+4);
	if ((buf=(char*)realloc(buf,len2))==NULL) {
		GRF_SETERR(error,GE_ERRNO,realloc);
		free(zbuf);
		return 1;
	}
	zlen=len2;
	if ((i=uncompress((Bytef*)buf, &zlen, (const Bytef*)zbuf, (uLong)len))!=Z_OK) {
		GRF_SETERR_2(error,GE_ZLIB,uncompress,i);
		free(buf);
		free(zbuf);
		return 1;
	}

	/* Free the compressed file table */
	free(zbuf);

	/* Read information about each file */
	for (i=offset=0;i<grf->nfiles;i++) {
		/* Grab the filename length */
		len=strlen(buf+offset)+1;

		/* Make sure its not too large */
		if (len>=GRF_NAMELEN) {
			GRF_SETERR(error,GE_CORRUPTED,GRF_readVer2_info);
			free(buf);
			return 1;
		}

		/* Grab filename */
		memcpy(grf->files[i].name,buf+offset,len);
		offset+=len;

		/* Grab the rest of the information */
		grf->files[i].compressed_len=LittleEndian32(buf+offset);
		grf->files[i].compressed_len_aligned=LittleEndian32(buf+offset+4);
		grf->files[i].real_len=LittleEndian32(buf+offset+8);
		grf->files[i].type=*(uint8_t*)(buf+offset+0xC);
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

	return 0;
}

/*******************
* Public Functions *
*******************/

/*! \brief Open a GRF file and read its contents
 *	(with callback)
 *
 * \param fname Filename of the GRF file
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \param callback Function to call for each read file. It should return 0 if
 *		everything is fine, 1 if everything is fine (but further
 *		reading should stop), or -1 if there has been an error
 * \return A pointer to a newly created Grf struct
 */
GRFEXPORT Grf *grf_callback_open (const char *fname, GrfError *error, GrfOpenCallback callback) {
	char buf[GRF_HEADER_FULL_LEN];
	uint32_t i;
	Grf *grf;

	if (!fname) {
		GRF_SETERR(error,GE_BADARGS,grf_callback_open);
		return NULL;
	}

	/* Allocate memory for grf */
	if ((grf=(Grf*)calloc(1,sizeof(Grf)))==NULL) {
		GRF_SETERR(error,GE_ERRNO,malloc);
		return NULL;
	}

	/* Allocate memory for grf filename */
	if ((grf->filename=(char*)malloc(sizeof(char)*(strlen(fname)+1)))==NULL) {
		GRF_SETERR(error,GE_ERRNO,malloc);
		grf_free(grf);
		return NULL;
	}

	/* Copy the filename */
	strcpy(grf->filename,fname);

	/* Open the file */
	if ((grf->f=fopen(grf->filename,"rb"))==NULL) {
		GRF_SETERR(error,GE_ERRNO,fopen);
		grf_free(grf);
		return NULL;
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
		GRF_SETERR(error,GE_INVALID,grf_callback_open);
		grf_free(grf);
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
			if (buf[GRF_HEADER_LEN+i] != i) {
				GRF_SETERR(error,GE_CORRUPTED,grf_callback_open);
				grf_free(grf);
				return NULL;
			}
	}
	else if (buf[GRF_HEADER_LEN]==0) {
		grf->allowCrypt=0;
		/* 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 */
		for (i=0;i<0xF;i++)
			if (buf[GRF_HEADER_LEN+i] != 0) {
				GRF_SETERR(error,GE_CORRUPTED,grf_callback_open);
				grf_free(grf);
				return NULL;
			}
	}
	else {
		GRF_SETERR(error,GE_CORRUPTED,grf_callback_open);
		grf_free(grf);
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
			GRF_SETERR(error,GE_ERRNO,calloc);
			grf_free(grf);
			return NULL;
		}
		if ((grf->filedatas=(void**)calloc(grf->nfiles,sizeof(void*)))==NULL) {
			GRF_SETERR(error,GE_ERRNO,calloc);
			grf_free(grf);
			return NULL;
		}
	}

	/* Grab the filesize */
	if (fseek(grf->f, 0, SEEK_END)) {
		GRF_SETERR(error,GE_ERRNO,fseek);
		grf_free(grf);
		return NULL;
	}
	if (ftell(grf->f)==-1) {
		GRF_SETERR(error,GE_ERRNO,ftell);
		grf_free(grf);
		return NULL;
	}
	grf->len=ftell(grf->f);

	/* Seek to the offset of the file tables */
	if (fseek(grf->f, LittleEndian32(buf+GRF_HEADER_MID_LEN)+GRF_HEADER_FULL_LEN, SEEK_SET)) {
		GRF_SETERR(error,GE_ERRNO,fseek);
		grf_free(grf);
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

	return grf;
}

/*! \brief Extract a file inside a .GRF file into memory
 *
 * This is basically the same as the one found in original libgrf
 *
 * \param grf Pointer to information about the GRF to extract from
 * \param fname Exact filename of the file to be extracted
 * \param size Pointer to a location in memory where the size of memory
 *	extracted should be stored
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \return A pointer to data that has been extracted, NULL if an error
 *	has occurred
 */
GRFEXPORT void *grf_get (Grf *grf, const char *fname, uint32_t *size, GrfError *error) {
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
 * \param grf Pointer to information about the GRF to extract from
 * \param index Index of the file to be extracted
 * \param size Pointer to a location in memory where the size of memory
 *	extracted should be stored
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \return A pointer to data that has been extracted, NULL if an error
 *	has occurred
 */
GRFEXPORT void *grf_index_get (Grf *grf, uint32_t index, uint32_t *size, GrfError *error) {
	uLongf zlen;
	int i;
	GrfFile *gfile;
	char keyschedule[0x80], key[8], *outbuf, *buf, *zbuf;

	/* Make sure we've got valid arguments */
	if (!grf || grf->type!=GRF_TYPE_GRF) {
		GRF_SETERR(error,GE_BADARGS,grf_index_get);
		return NULL;
	}
	if (index>=grf->nfiles) {
		GRF_SETERR(error,GE_INDEX,grf_index_get);
		return NULL;
	}

	/* Grab the file information */
	gfile=&(grf->files[index]);

	/* Check to see if the file is actually a directory entry */
	if (GRFFILE_IS_DIR(*gfile)) {
		/*! \todo Create a directory contents listing instead
		 *	of just returning "<directory>"
		 */
		*size=12;
		return "<directory>";
	}

	/* Return NULL if there is no data */
	if (!gfile->real_len) {
		GRF_SETERR(error,GE_NODATA,grf_index_get);
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
		GRF_SETERR(error,GE_ERRNO,malloc);
		free(zbuf);
		return NULL;
	}

	/* Read the data */
	if (fseek(grf->f,gfile->pos,SEEK_SET)) {
		GRF_SETERR(error,GE_ERRNO,fseek);
		free(buf);
		free(zbuf);
		return NULL;
	}
	if (!fread(buf,gfile->compressed_len_aligned,1,grf->f)) {
		if (feof(grf->f))
			GRF_SETERR(error,GE_CORRUPTED,grf_index_get);
		else
			GRF_SETERR(error,GE_ERRNO,grf_index_get);
		free(buf);
		free(zbuf);
		return NULL;
	}

	/* Create a key and use it to generate the key schedule */
	DES_CreateKeySchedule(keyschedule,GRF_GenerateDataKey(key,gfile->name));

	/* Decrypt the data (if its encrypted) */
	GRF_Process(zbuf,buf,gfile->compressed_len_aligned,gfile->type,gfile->compressed_len,keyschedule,GRFCRYPT_DECRYPT);

	/* Free some memory */
	free(buf);

	/* Allocate memory to write into */
	if ((outbuf=(char*)malloc(gfile->real_len+1))==NULL) {
		GRF_SETERR(error,GE_ERRNO,malloc);
		free(zbuf);
		return NULL;
	}

	/* Make sure uncompress doesn't modify our file information */
	zlen=gfile->real_len;

	/* Uncompress the data, and catch any errors */
	if ((i=uncompress((Bytef*)outbuf,&zlen,(const Bytef *)zbuf, (uLong)gfile->compressed_len))!=Z_OK) {
		/* Ignore Z_DATA_ERROR */
		if (i==Z_DATA_ERROR) {
			/* Set an error, just don't crash out */
			GRF_SETERR_2(error,GE_ZLIB,uncompress,i);
		}
		else {
			free(outbuf);
			free(zbuf);
			GRF_SETERR_2(error,GE_ZLIB,uncompress,i);
			return NULL;
		}
	}
	*size=zlen;

	/* Check for different sizes */
#undef NEVER_DEFINED
#ifdef NEVER_DEFINED
	if (zlen!=gfile->real_len) {
		/* Something might be wrong, but I've never
		 * seen this happen
		 */
	}
#endif /* defined(NEVER_DEFINED) */

	/* Free memory */
	free(zbuf);

	/* Throw a nul-terminator on the extra byte we allocated */
	outbuf[*size]=0;
	
	/* Set the pointer in grf->filedatas */
	free(grf->filedatas[index]);
	grf->filedatas[index]=outbuf;

	/* Return our decrypted, uncompressed data */
	return outbuf;
}

/*! \brief Extract to a file
 *
 * Basically the same as the one in original libgrf
 *
 * \param grf Pointer to information about the GRF to extract from
 * \param grfname Full filename of the Grf::files file to extract
 * \param file Filename to write the data to
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \return The number of successfully extracted files
 */
GRFEXPORT int grf_extract(Grf *grf, const char *grfname, const char *file, GrfError *error) {
	uint32_t i;

	if (!grf || !grfname) {
		GRF_SETERR(error,GE_BADARGS,grf_extract);
		return 0;
	}

	if (!grf_find(grf,grfname,&i)) {
		GRF_SETERR(error,GE_NOTFOUND,grf_extract);
		return 0;
	}
	return grf_index_extract(grf,i,file,error);
}

/*! \brief Extract to a file, taking index instead of filename
 *
 * Very similar to the original libgrf's grf_index_extract
 *
 * \param grf Pointer to information about the GRF to extract from
 * \param index The Grf::files index number to extract
 * \param file Filename to write the data to
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \return The number of successfully extracted files
 */
GRFEXPORT int grf_index_extract(Grf *grf, uint32_t index, const char *file, GrfError *error) {
	void *buf;
	char *fixedname;
	uint32_t size,i;
	FILE *f;

	/* Make sure we have a filename to write to */
	if (!file) {
		GRF_SETERR(error,GE_BADARGS,grf_index_extract);
		return 0;
	}
	
	/* Normalize the filename */
	if ((fixedname=(char*)malloc(strlen(file)+1))==NULL) {
		GRF_SETERR(error,GE_ERRNO,malloc);
		return 0;
	}
	GRF_normalize_path(fixedname,file);

	/* Read the data */
	if ((buf=grf_index_get(grf,index,&size,error))==NULL) {
		/* Check if the file actually has no data */
		if (error->type != GE_NODATA)
			return 0;
	}

	/* Open the file we should write to */
	if ((f=fopen(fixedname,"wb"))==NULL) {
		free(buf);
		grf->filedatas[index]=NULL;
		GRF_SETERR(error,GE_ERRNO,fopen);
		return 0;
	}

	/* Write the data */
	if (0==(i=fwrite(buf,size,1,f))) {
		GRF_SETERR(error,GE_ERRNO,fwrite);
	}

	/* Clean up and return */
	fclose(f);
	free(buf);
	grf->filedatas[index]=NULL;
	return (i)? 1 : 0;
}

/*! \brief Delete a file from the file table
 *
 * \param grf Pointer to information about the GRF to delete from
 * \param fname Exact filename of the file to be deleted
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \return The number of files deleted from the GRF archive
 */
GRFEXPORT int grf_del(Grf *grf, const char *fname, GrfError *error) {
	uint32_t i;

	/* Make sure we've got valid arguments */
	if (!grf || !fname) {
		GRF_SETERR(error,GE_BADARGS,grf_del);
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

/*! \brief Delete a file from the file table, taking index instead of name
 *
 * \param grf Pointer to information about the GRF to delete from
 * \param index Index of the Grf::files entry to be deleted
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \return The number of files deleted from the GRF archive
 */
GRFEXPORT int grf_index_del(Grf *grf, uint32_t index, GrfError *error) {
	return 0;
}

/*! \brief Replace the data of a file
 *
 * \param grf Pointer to information about the GRF to delete from
 * \param name Name of the file inside the GRF
 * \param data Pointer to the replacement data
 * \param len Length of the replacement data
 * \param flags Flags to store the data with
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \return The number of files successfully replaced
 */
GRFEXPORT int grf_replace(Grf *grf, const char *name, const void *data, uint32_t len, uint8_t flags, GrfError *error) {
	uint32_t i;

	/* Make sure we've got valid arguments */
	if (!grf || !name) {
		GRF_SETERR(error,GE_BADARGS,grf_replace);
		return 0;
	}

	/* Find the file inside the GRF */
	if (!grf_find(grf,name,&i)) {
		GRF_SETERR(error,GE_NOTFOUND,grf_replace);
		return 0;
	}

	/* Replace the file, using its index */
	return grf_index_replace(grf,i,data,len,flags,error);
}

/*! \brief Replace the data of a file
 *
 * \param grf Pointer to information about the GRF to delete from
 * \param index Index of the Grf::files entry to be replaced
 * \param data Pointer to the replacement data
 * \param len Length of the replacement data
 * \param flags Flags to store the data with
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \return The number of files successfully replaced
 */
GRFEXPORT int grf_index_replace(Grf *grf, uint32_t index, const void *data, uint32_t len, uint8_t flags, GrfError *error) {
	/*! \todo Write this code! */
	return 0;
}

/*! \brief Add a file
 *
 * \todo Write this! And its code!
 */
GRFEXPORT int grf_put(Grf *grf, const char *name, const void *data, uint32_t len, uint8_t flags, GrfError *error) {
	return 0;
}

/*! \brief Save modified data of a GRF file
 *
 * \note This may or may not (depending on how its written) leave data
 *	inside the GRF that is never used. A planned grf_repak
 *	will deal with this (and will completely restructure the GRF)
 *
 * \param grf Grf pointer to save data from
 * \param error Pointer to a struct/enum for error reporting
 * \return 0 if an error occurred, 1 if all is good
 */
GRFEXPORT int grf_flush(Grf *grf, GrfError *error) {
	/*! \todo Write this code! (pseudo-coded) */

	/* pseudo-code:

	grf_sort(offset)
	
	for each GrfFile with pos 0
		grf_find_unused
		fseek
		fwrite
	next

	compress(file_info_table)
	grf_find_unused
	fseek
	fwrite

	*/
	return 0;
}

/*! \brief Save and close a GRF file
 *
 * \param grf Grf pointer to save and close
 */
GRFEXPORT void grf_close(Grf *grf) {
	/* Ensure they're not sending us bullshit */
	if (!grf)
		return;

	/* Flush any data that hasn't been written yet */
	grf_flush(grf,NULL);	/* Any errors? Too bad, so sad */

	/* Close and free the GRF file */
	grf_free(grf);
}

/*! \brief Close a GRF file
 *
 * \warning This will not save any data!
 *
 * \param grf Grf pointer to free
 */
GRFEXPORT void grf_free(Grf *grf) {
	uint32_t i;
	
	/* Ensure we don't have access violations when freeing NULLs */
	if (!grf)
		return;

	/* Free the grf name */
	free(grf->filename);

	/* Free the array of files */
	free(grf->files);
	
	/* Free the array of file datas */
	for(i=0;i<grf->nfiles;i++)
		if (grf->filedatas[i])
			free(grf->filedatas[i]);
	free(grf->filedatas);

	/* Close the file */
	if (grf->f)
		fclose(grf->f);

	/* And finally, free the pointer itself */
	free(grf);
}

/*! \brief Completely restructure a GRF archive
 *
 * \param grf Filename of the original GRF
 * \param tmpgrf Filename to use temporarily while restructuring
 * \param error Pointer to a GrfErrorType struct/enum for error reporting
 * \return 0 if an error occurred, 1 if the repak failed
 */
GRFEXPORT int grf_repak(const char *grf, const char *tmpgrf, GrfError *error) {
	/*! \todo Write this code! */
	return 0;
}

GRFEXTERN_END

