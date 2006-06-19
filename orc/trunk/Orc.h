#ifndef Orc_H
#define Orc_H

/* FOO */
#define _STR(x) #x
#define STR(x) _STR(x)

/* VERSION DEFINITIONS */
#define VER_MAJOR	0
#define VER_MINOR	0
#define VER_RELEASE	2
#define VER_BUILD	STR(SVN_REV)
#define VER_STRING  STR(VER_MAJOR) "." STR(VER_MINOR) "." STR(VER_RELEASE)

/* VERSION INFORMATION */
#define COMPANY_NAME        "Opencore community"
#define FILE_VERSION        VER_STRING
#define FILE_DESCRIPTION    "Open Ragnarok Client"
#define INTERNAL_NAME       "Orc"
#define LEGAL_COPYRIGHT     ""
#define LEGAL_TRADEMARKS    ""
#define ORIGINAL_FILENAME   "Orc.exe"
#define PRODUCT_NAME        "Open Ragnarok Client"
#define PRODUCT_VERSION     VER_STRING

/* THIS IS THE APPLICATION TITLE */
#define APPTITLE            PRODUCT_NAME " " PRODUCT_VERSION " (Rev: " VER_BUILD ")"

#endif /* Orc_H */
