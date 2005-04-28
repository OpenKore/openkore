#include  <stdlib.h>
#include  <stdio.h>
#include  <string.h>
#include  <errno.h>

#include <sys/types.h>
#include <sys/stat.h>

#if defined(WIN32)
# include  <windows.h>
# include  <tchar.h>
# include  <direct.h>
# define MKDIR_FLAGS 0
# define IS_INVALID_READ_PTR(ptr,type) IsBadReadPtr((ptr), sizeof(type))
# define mkdir(path,modeflags) _mkdir(path)
# define S_ISDIR(__m) ( ( ( __m ) & _S_IFMT ) == _S_IFDIR )
# define STAT _stat
#else /* defined(WIN32) */
# include  <unistd.h>
# define MKDIR_FLAGS (S_IRWXU | S_IRWXG | S_IRWXO)
# define IS_INVALID_READ_PTR(ptr,type) 0
# define STAT stat
#endif /* defined(WIN32) */

#if !defined(MAX_PATH)
	#define MAX_PATH 260
#endif

	/* libgrf */
#include  <grf.h>


	/* directory separator character for Grf files */
#define DIRSEP '\\'
#define FORWARD_DIRSEP '/'



static void print_usage();
static int ProcessGrf(const Grf *, GrfError *);
static int build_path(const char *path);
enum {
	E_OK, E_ARG, E_ERRNO, E_GETLASTERROR, E_GRFERROR
};

#if !defined(EXTRACT_AS_UNICODE)
static const char GX[] = "Grf Extract 1.0.0a - using libgrf by the OpenKore community.\n";
#else
static const char GX[] = "Grf Extract 1.0.0Ua - using libgrf by the OpenKore community.\nThis version extracts paths as Unicode.\n";
#endif



  /*
   * 0: success
   * 1: partial success
   * 2: failure
   */
int main(int argc, char* argv[])
{
	unsigned int  uTotal = 0, uDone = 0;
	Grf           *pGrf = NULL;
	GrfError      grferror;
	int           i, nExtractCode;

	if ( argc < 2 )
	{
		print_usage();
		return 2;
	}

	for ( i = 1; i < argc; ++i )
	{
		if ( NULL == (pGrf = grf_open(argv[i], "rb", &grferror)) )
		{
			fprintf(stderr, "open failed [%s]: Reason: (%s)\n", argv[i], grf_strerror(grferror));
		}
		else
		{
			nExtractCode = ProcessGrf(pGrf, &grferror);
			if ( nExtractCode != E_OK )
			{
				fprintf(stderr, "extract failed [%s]: code: (%d)\n", argv[i], nExtractCode);
 				if ( nExtractCode == E_ERRNO )
 				{
 					fprintf(stderr, "System message: (%s)\n", strerror(errno));
 				}
#if defined(WIN32)
				else if ( nExtractCode == E_GETLASTERROR )
 				{
					char  buf[4096];
					if ( !FormatMessage (FORMAT_MESSAGE_FROM_SYSTEM
					                     | FORMAT_MESSAGE_IGNORE_INSERTS,
					                     NULL,
					                     GetLastError(),
					                     MAKELANGID (LANG_NEUTRAL, SUBLANG_DEFAULT),
					                     buf, sizeof(buf)/sizeof(buf[0]), NULL) )
					{
						strcpy(buf, "Unable to get error");
					}
					fprintf(stderr, "Windows system message: (%s)\n", buf);
				}
#endif
				else if ( nExtractCode == E_GRFERROR )
 				{
					fprintf(stderr, "libgrf api message: (%s)\n", grf_strerror(grferror));
				}
			}
			grf_free(pGrf);
			pGrf = NULL;
			++uDone;
		}
		++uTotal;
	}
	return uDone == uTotal ? 0 : uDone != 0 ? 1 : 2;
}

static void print_usage()
{
	fprintf(stderr, GX);
	fprintf(stderr, "Copyright 2004, Rasqual Twilight - GNU GPL.\n");
	fprintf(stderr, "  Usage: gx [file path(s)]\n");
}

	/* Do things in the Grf.
	 * Returns one of the error codes E_OK, E_ARG, E_ERRNO, E_GRFERROR
	 */
static int ProcessGrf(const Grf *pGrf, GrfError *pGrfError)
{
	uint32_t FileIdx;
	uint32_t FilesCnt;
	GrfFile  *pEntry = NULL;

	if ( !pGrf || IS_INVALID_READ_PTR(pGrf, Grf)
	  || !pGrfError || IS_INVALID_READ_PTR(pGrfError, GrfError) )
	{
		return E_ARG;
	}

	FilesCnt = pGrf->nfiles;
	if ( FilesCnt != 0 )
	{
		pEntry = pGrf->files;
	}
#ifdef _DEBUG
	fprintf(stderr, "= Processing archive %s =-\n"
	" + length = %u bytes\n"
	" + files = %u entries\n"
	" + version = 0x%04x\n", pGrf->filename, pGrf->len, FilesCnt, pGrf->version);
#endif
	for ( FileIdx = 0U; FileIdx < FilesCnt; ++FileIdx, ++pEntry )
	{
		char  strTargetDir[MAX_PATH];
		int  errorcode;

		*strTargetDir = '\0';
		GRF_normalize_path(strTargetDir, pEntry->name);
		if ( GRFFILE_IS_DIR(*pEntry) )
		{
			if ( strlen(strTargetDir) > 0 )
			{
#if defined(_DEBUG) && defined(_VERBOSEDEBUG)
				fprintf(stderr, "==(d) %s\n", pEntry->name);
#endif
				errno = 0;
				if ( E_OK != (errorcode=build_path(strTargetDir)) && !(errorcode == E_ERRNO && errno == EEXIST) )
				{
					return errorcode;
				}
			}
		}
		else
		{
			char  *pDirSep;
			int  errorcode;
				/* Creating sub dirs recursively */
				/* FIXME? possible bug due to MB chars? should walk the string
				 * instead of strrchr()ing
				 */
			pDirSep = strrchr(pEntry->name, DIRSEP);
			if ( pDirSep != NULL )
			{
				errno = 0;
				if ( E_OK != (errorcode=build_path(strTargetDir)) && !(errorcode == E_ERRNO && errno == EEXIST) )
				{
#if defined(_DEBUG) && defined(_VERBOSEDEBUG)
					fprintf(stderr, "==(D) %s\n", strTargetDir);
#endif
					return errorcode;
				}
				++pDirSep;
			}
			else
			{
				pDirSep = pEntry->name;
			}
			  /* "pDirSep" shall point to the first character of the file name */
#if defined(_DEBUG) && defined(_VERBOSEDEBUG)
			fprintf(stderr, "==(F) %s  [%s]\n", strTargetDir, pDirSep);
#endif
			if ( !grf_index_extract((Grf*)pGrf, FileIdx, pEntry->name, pGrfError) )
			{
				return E_GRFERROR;
			}
#if defined(WIN32) && defined(EXTRACT_AS_UNICODE)
			{
				WCHAR  AstrTargetFile[MAX_PATH], WstrTargetFile[MAX_PATH];
				MultiByteToWideChar(1252, 0, pEntry->name, -1, AstrTargetFile, MAX_PATH);
				MultiByteToWideChar(949, 0, pEntry->name, -1, WstrTargetFile, MAX_PATH);  /* CP-949 */
				if ( !MoveFileExW(AstrTargetFile, WstrTargetFile, MOVEFILE_REPLACE_EXISTING) )
				{
					return E_GETLASTERROR;
				}
			}
#endif

		}
	}
	return E_OK;
}


/*
 * simplified permissions-less version of build_path() stolen from PostgreSQL initdb.c
 * wasted for Win32 compatibility... well, grab the original if you need a better version.
 */

/* source stolen from FreeBSD /src/bin/mkdir/mkdir.c and adapted */

/*
 * this tries to build all the elements of a path to a directory a la mkdir -p
 * we assume the path is in canonical form, i.e. uses NATIVE_DIRSEP as the separator
 * we also assume it isn't null.
 *
 */

static int
build_path(const char *path)
{
	struct STAT sb;
	int         last,
	            retval;
	char        strTargetDir[MAX_PATH];
	char        *p = strTargetDir;
	strncpy(p, path, MAX_PATH);
	p[MAX_PATH-1] = 0;

	retval = E_OK;

#ifdef WIN32

	/* skip network and drive specifiers for win32 */
	if (strlen(p) >= 2)
	{
		if (p[0] == FORWARD_DIRSEP && p[1] == FORWARD_DIRSEP)
		{
			/* network drive */
			p = strchr(p + 2, FORWARD_DIRSEP);
			if (p == NULL)
				return 1;
		}
		else if (p[1] == ':' &&
		        ((p[0] >= 'a' && p[0] <= 'z') ||
		        (p[0] >= 'A' && p[0] <= 'Z')))
		{
			/* local drive */
			p += 2;
		}
	}
#endif   /* WIN32 */

	if (p[0] == FORWARD_DIRSEP)            /* Skip leading FORWARD_DIRSEP. */
		++p;
	for (last = 0; !last; ++p)
	{
		if (p[0] == '\0')
			last = 1;
		else if (p[0] != FORWARD_DIRSEP)
	            continue;
		*p = '\0';
		if (p[1] == '\0')
			last = 1;
#if defined(_DEBUG) && defined(_VERBOSEDEBUG)
		fprintf(stderr, "*** mkdir(%s)\n", strTargetDir);
#endif
#if defined(WIN32) && defined(EXTRACT_AS_UNICODE)
		if (!last)
		{
			WCHAR  WstrTargetDir[MAX_PATH];
			MultiByteToWideChar(949, 0, strTargetDir, -1, WstrTargetDir, MAX_PATH);  /* CP-949 */
			if ( !CreateDirectoryW(WstrTargetDir, NULL) && GetLastError() != ERROR_ALREADY_EXISTS )
			{
				retval = E_GETLASTERROR;
				break;
			}
		}
#endif  /* Create in two versions for now */
		if (!last && mkdir(strTargetDir, MKDIR_FLAGS) < 0)
		{
			if (errno == EEXIST || errno == EISDIR)
			{
				if (STAT(strTargetDir, &sb) < 0)
				{
					retval = E_ERRNO;
					break;
				}
				else if (!S_ISDIR(sb.st_mode))
				{
					if (last)
						errno = EEXIST;
					else
						errno = ENOTDIR;
					retval = E_ERRNO;
					break;
				}
			}
			else
			{
				retval = E_ERRNO;
				break;
			}
		}

		if (!last)
			*p = FORWARD_DIRSEP;
	}
	return (retval);
}
