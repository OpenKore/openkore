/*
 *  libgrf
 *  rgz.c - library functions to manipulate RGZ files
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
 *
 * Notes:
 * RGZ - Ragnarok GZip
 */

/* Include headers needed for RGZ handling */
#include "rgz.h"	/* RGZ basics */
#include <zlib.h>	/* For GZip support */
#include <stdlib.h>
#include <string.h>

GRFEXTERN_BEGIN

/* This needs an update, badly */
#if 0
/*! \brief Open a RGZ file and read its contents, using a callback
 *
 * \param fname Filename of the RGZ file
 * \param error Pointer to a struct/enum for error reporting
 * \param callback Function to call for each read file. It should return 0 if
 *		everything is fine, 1 if everything is fine (but further
 *		reading should stop), or -1 if there has been an error
 * \return A pointer to a newly created Rgz struct
 */
GRFEXPORT Rgz *rgz_callback_open(const char *fname, RgzError *error, int (*callback)(RgzFile*,RgzError*)) {
	int type,len,end,callbackRet;
	Rgz *rgz;
	RgzFile *curfile=NULL;
	gzFile rgzfile;
	char name[0x100];	/* As long as len is stored as a byte,
				 * name cannot exceed 0xFF bytes
				 */

	/* Make sure our arguments are valid */
	if (!fname) {
		RGZ_SETERR(error,GE_BADARGS,rgz_callback_open);
		return NULL;
	}

	/* Allocate memory for grf */
	if ((rgz=(Rgz*)calloc(1,sizeof(Rgz)))==NULL) {
		RGZ_SETERR(error,GE_ERRNO,calloc);
		return NULL;
	}

	/* Allocate memory for rgz filename */
	if ((rgz->filename=(char*)malloc(sizeof(char)*(strlen(fname)+1)))==NULL) {
		RGZ_SETERR(error,GE_ERRNO,malloc);
		rgz_free(rgz);
		return NULL;
	}

	/* Copy the filename */
	strcpy(rgz->filename,fname);
	
	/* Open the file */
	if ((rgz->f=fopen(fname,"rb"))==NULL) {
		RGZ_SETERR(error,GE_ERRNO,fopen);
		rgz_free(rgz);
		return NULL;
	}

	/* Open the file with zlib's GZip functions */
	if ((rgzfile=gzdopen(dup(fileno(rgz->f)),"r+b"))==NULL) {
		RGZ_SETERR(error,GE_ERRNO,gzdopen);
		rgz_free(rgz);
		return NULL;
	}

	/* Set the Rgz type */
	rgz->type=GRF_TYPE_RGZ;

	/* Loop around, reading the file names and lengths */
	end=0;
	while (!end) {
		/* Grab the next data type */
		if ((type=gzgetc(rgzfile))<0) {
			RGZ_SETERR_2(error,GE_ZLIBFILE,gzgetc,rgzfile);
			rgz_free(rgz);
			return NULL;
		}

		/* Read the length of the name */
		if ((len=gzgetc(rgzfile))<0) {
			RGZ_SETERR_2(error,GE_ZLIBFILE,gzgetc,rgzfile);
			rgz_free(rgz);
			return NULL;
		}

		/* Read the name */
		if (gzread(rgzfile,name,len)<0) {
			RGZ_SETERR_2(error,GE_ZLIBFILE,gzread,rgzfile);
			rgz_free(rgz);
			return NULL;
		}

		/* Check if it needs a file entry */
		if (type==RGZ_TYPE_DIRECTORY || type==RGZ_TYPE_FILE) {
			/* Allocate memory for another entry */
			rgz->nfiles++;
			if ((rgz->files=(RgzFile*)realloc(rgz->files,sizeof(RgzFile)*rgz->nfiles))==NULL) {
				RGZ_SETERR(error,GE_ERRNO,realloc);
				rgz_free(rgz);
				return NULL;
			}

			/* Grab the file into curfile */
			curfile=&(rgz->files[rgz->nfiles-1]);

			/* Copy the filename */
			strncpy(curfile->name,name,len);

			/* Hash the filename */
			curfile->hash=RGZ_NameHash(name);
		}

		/* Decide what type of file it is */
		switch (type) {
		case RGZ_TYPE_DIRECTORY:
			/* Setup the entry information */
			curfile->compressed_len_aligned=GRFFILE_DIR_SZFILE;
			curfile->compressed_len=GRFFILE_DIR_SZSMALL;
			curfile->real_len=GRFFILE_DIR_SZORIG;
			curfile->pos=GRFFILE_DIR_OFFSET;
			curfile->type=0;

			break;
		case RGZ_TYPE_EOF:
			end=1;
			break;

		case RGZ_TYPE_FILE:
			/* Setup the entry information */
			curfile->compressed_len_aligned=
			curfile->compressed_len=0;
			curfile->type=GRFFILE_FLAG_FILE;
			
			/* Read the file size */
			if (gzread(rgzfile,name,4)<1) {
				RGZ_SETERR_2(error,GE_ZLIBFILE,gzread,rgzfile);
				rgz_free(rgz);
				return NULL;
			}
			curfile->real_len=LittleEndian32(name);

			/* Read the offset */
			if ((len=gztell(rgzfile))<0) {
				RGZ_SETERR_2(error,GE_ZLIBFILE,gztell,rgzfile);
				rgz_free(rgz);
				return NULL;
			}
			curfile->pos=len;

			/* Skip ahead to the next file */
			if (gzseek(rgzfile,(z_off_t)curfile->real_len,SEEK_CUR)<0) {
				RGZ_SETERR_2(error,GE_ZLIBFILE,gzseek,rgzfile);
				rgz_free(rgz);
				return NULL;
			}

			break;
		}

		/* Call our callback function */
		if (callback && !end) {
			if ((callbackRet=callback(curfile,error))<0) {
				/* Callback function had an error, so we have
				 * an error
				 */
				rgz_free(rgz);
				return NULL;
			}
			else if (callbackRet>0) {
				/* Callback function signalled to stop */
				break;
			}
		}
	}

	/* Close the gzip-opened file */
	if (gzclose(rgzfile)!=Z_OK) {
		RGZ_SETERR_2(error,GE_ZLIBFILE,gzseek,rgzfile);
		rgz_free(rgz);
		return NULL;
	}

	return rgz;
}

/*! \brief Extract a file inside a .RGZ file into memory
 *
 * \param rgz Pointer to information about the RGZ to extract from
 * \param fname Exact filename of the file to be extracted
 * \param size Pointer to a location in memory where the size of memory
 *	extracted should be stored
 * \param error Pointer to a RgzErrorType struct/enum for error reporting
 * \return A pointer to data that has been extracted, NULL if an error
 *	has occurred
 */
GRFEXPORT void *rgz_get (Rgz *rgz, const char *fname, uint32_t *size, RgzError *error) {
	uint32_t i;

	/* Make sure we've got valid arguments */
	if (!rgz || !fname) {
		RGZ_SETERR(error,GE_BADARGS,rgz_get);
		return NULL;
	}

	/* Find the file inside the RGZ */
	if (!rgz_find(rgz,fname,&i)) {
		RGZ_SETERR(error,GE_NOTFOUND,rgz_get);
		return NULL;
	}

	/* Get the file from its index */
	return rgz_index_get(rgz,i,size,error);
}

/*! \brief Extract to a file
 *
 * \param rgz Pointer to information about the RGZ to extract from
 * \param rgzname Full filename of the Rgz::files file to extract
 * \param file Filename to write the data to
 * \param error Pointer to a RgzErrorType struct/enum for error reporting
 * \return The number of successfully extracted files
 */
GRFEXPORT int rgz_extract(Rgz *rgz, const char *rgzname, const char *file, RgzError *error) {
	uint32_t i;

	if (!rgz || !rgzname) {
		RGZ_SETERR(error,GE_BADARGS,rgz_extract);
		return 0;
	}

	if (!rgz_find(rgz,rgzname,&i)) {
		RGZ_SETERR(error,GE_NOTFOUND,rgz_extract);
		return 0;
	}

	return rgz_index_extract(rgz,i,file,error);
}

/*! \brief Extract to a file, taking index instead of filename
 *
 * \param rgz Pointer to information about the RGZ to extract from
 * \param index The Rgz::files index number to extract
 * \param file Filename to write the data to
 * \param error Pointer to a RgzErrorType struct/enum for error reporting
 * \return The number of successfully extracted files
 */
GRFEXPORT int rgz_index_extract(Rgz *rgz, uint32_t index, const char *file, RgzError *error) {
	void *buf;
	uint32_t size,i;
	FILE *f;

	/* Make sure we have a filename to write to */
	if (!file) {
		RGZ_SETERR(error,GE_BADARGS,rgz_index_extract);
		return 0;
	}

	/* Read the data */
	if ((buf=rgz_index_get(rgz,index,&size,error))==NULL) {
		/* Check if the file actually has no data */
		if (error->type != GE_NODATA)
			return 0;
	}

	/* Open the file we should write to */
	if ((f=fopen(file,"wb"))==NULL) {
		free(buf);
		RGZ_SETERR(error,GE_ERRNO,fopen);
		return 0;
	}

	/* Write the data */
	if (0==(i=fwrite(buf,size,1,f))) {
		RGZ_SETERR(error,GE_ERRNO,fwrite);
	}

	/* Clean up and return */
	fclose(f);
	free(buf);
	return (i)? 1:0;
}

/*! \brief Extract a file into memory, taking index instead of name
 *
 * \warning Memory will be leaked unless the pointer returned is properly
 *	freed by calling __rgz_free_memory__()
 *
 * \param rgz Pointer to information about the RGZ to extract from
 * \param index Index of the file to be extracted
 * \param size Pointer to a location in memory where the size of memory
 *	extracted should be stored
 * \param error Pointer to a RgzErrorType struct/enum for error reporting
 * \return A pointer to data that has been extracted, NULL if an error
 *	has occurred
 */
GRFEXPORT void *rgz_index_get (Rgz *rgz, uint32_t index, uint32_t *size, RgzError *error) {
	RgzFile *rf;
	gzFile rgzfile;
	char *outbuf;

	/* Make sure we've got valid arguments */
	if (!rgz || rgz->type!=GRF_TYPE_RGZ) {
		RGZ_SETERR(error,GE_BADARGS,rgz_index_get);
		return NULL;
	}
	if (index>=rgz->nfiles) {
		RGZ_SETERR(error,GE_INDEX,rgz_index_get);
		return NULL;
	}

	/* Grab the file information */
	rf=&(rgz->files[index]);

	/* Check to see if the file is actually a directory entry */
	if (!(rf->type & GRFFILE_FLAG_FILE)) {
		/*! \todo Create a directory contents listing instead
		 *	of just returning "<directory>"
		 */
		*size=12;
		return "<directory>";
	}
	
	/* Return NULL if there is no data */
	if (!rf->real_len) {
		RGZ_SETERR(error,GE_NODATA,rgz_index_get);
		return NULL;
	}

	/* Allocate memory to hold the data */
	if ((outbuf=(char*)malloc(rf->real_len+1))==NULL) {
		RGZ_SETERR(error,GE_ERRNO,malloc);
		return NULL;
	}

	/* Open the file with zlib's GZip functions */
	if ((rgzfile=gzdopen(dup(fileno(rgz->f)),"r+b"))==NULL) {
		RGZ_SETERR(error,GE_ERRNO,gzdopen);
		free(outbuf);
		return NULL;
	}

	/* Seek to the location in the file */
	if (gzseek(rgzfile,rf->pos,SEEK_SET)<0) {
		RGZ_SETERR_2(error,GE_ZLIBFILE,gzseek,rgzfile);
		free(outbuf);
		return NULL;
	}

	/* Read the data */
	if (gzread(rgzfile,outbuf,rf->real_len)<(int)rf->real_len) {
		RGZ_SETERR_2(error,GE_ZLIBFILE,gzread,rgzfile);
		free(outbuf);
		return NULL;
	}

	/* Close the file */
	if (gzclose(rgzfile)!=Z_OK) {
		RGZ_SETERR_2(error,GE_ZLIBFILE,gzclose,rgzfile);
		free(outbuf);
		return NULL;
	}

	/* Set the size */
	*size=rf->real_len;

	/* Throw a nul-terminator on the extra byte we allocated */
	outbuf[*size]=0;

	/* Return the data */
	return outbuf;
}

/*! \brief Frees allocated memory (same rationale as __grf_free_memory__())
 *
 * \param buf Pointer to memory area to be freed
 */
GRFEXPORT void __rgz_free_memory__(void *buf) {
	free(buf);
}
#endif /* 0 */

GRFEXTERN_END
