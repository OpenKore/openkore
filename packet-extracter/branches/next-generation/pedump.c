//
//
// This program was written by Sang Cho, associate professor at 
//                                       the department of 
//                                       computer science and engineering
//                                       chongju university
// this program is based on the program pefile.c
// which is written by Randy Kath(Microsoft Developmer Network Technology Group)
// in june 12, 1993.
// I have investigated P.E. file format as thoroughly as possible,
// but I cannot claim that I am an expert yet, so some of its information  
// may give you wrong results.
//
//
//
// language used: djgpp
// date of creation: September 28, 1997
//
// date of first release: October 15, 1997
//
// date of second release: August 30, 1998 (alpha version)
//
//
//      you can contact me: e-mail address: sangcho@alpha94.chongju.ac.kr
//                            hitel id: chokhas
//                        phone number: (0431) 229-8491    +82-431-229-8491
//
//            real address: Sang Cho
//                      Computer and Information Engineering
//                      ChongJu University
//                      NaeDok-Dong 36 
//                      ChongJu 360-764
//                      South Korea
//
//   Copyright (C) 1997, 1998                            by Sang Cho.
//
//   Permission is granted to make and distribute verbatim copies of this
// program provided the copyright notice and this permission notice are
// preserved on all copies.
//
//
// File: pedump.c ( I included header file into source file. )

# include "disasm.h"

#define VOID                void
#define BOOLEAN             boolean
#define FALSE               0
#define TRUE                1
#define CONST               const
#define LOWORD(l)           ((WORD)(l))
#define WINAPI

//
// Image Format
//

#define IMAGE_DOS_SIGNATURE                 0x5A4D      // MZ
#define IMAGE_OS2_SIGNATURE                 0x454E      // NE
#define IMAGE_OS2_SIGNATURE_LE              0x454C      // LE
#define IMAGE_VXD_SIGNATURE                 0x454C      // LE
#define IMAGE_NT_SIGNATURE                  0x00004550  // PE00

typedef struct _IMAGE_DOS_HEADER {      // DOS .EXE header
    WORD   e_magic;                     // Magic number
    WORD   e_cblp;                      // Bytes on last page of file
    WORD   e_cp;                        // Pages in file
    WORD   e_crlc;                      // Relocations
    WORD   e_cparhdr;                   // Size of header in paragraphs
    WORD   e_minalloc;                  // Minimum extra paragraphs needed
    WORD   e_maxalloc;                  // Maximum extra paragraphs needed
    WORD   e_ss;                        // Initial (relative) SS value
    WORD   e_sp;                        // Initial SP value
    WORD   e_csum;                      // Checksum
    WORD   e_ip;                        // Initial IP value
    WORD   e_cs;                        // Initial (relative) CS value
    WORD   e_lfarlc;                    // File address of relocation table
    WORD   e_ovno;                      // Overlay number
    WORD   e_res[4];                    // Reserved words
    WORD   e_oemid;                     // OEM identifier (for e_oeminfo)
    WORD   e_oeminfo;                   // OEM information; e_oemid specific
    WORD   e_res2[10];                  // Reserved words
    LONG   e_lfanew;                    // File address of new exe header
  } IMAGE_DOS_HEADER, *PIMAGE_DOS_HEADER;

//
// File header format.
//



typedef struct _IMAGE_FILE_HEADER {
    WORD    Machine;
    WORD    NumberOfSections;
    DWORD   TimeDateStamp;
    DWORD   PointerToSymbolTable;
    DWORD   NumberOfSymbols;
    WORD    SizeOfOptionalHeader;
    WORD    Characteristics;
} IMAGE_FILE_HEADER, *PIMAGE_FILE_HEADER;

#define IMAGE_SIZEOF_FILE_HEADER             20

#define IMAGE_FILE_RELOCS_STRIPPED           0x0001  // Relocation info stripped from file.
#define IMAGE_FILE_EXECUTABLE_IMAGE          0x0002  // File is executable  (i.e. no unresolved externel references).
#define IMAGE_FILE_LINE_NUMS_STRIPPED        0x0004  // Line nunbers stripped from file.
#define IMAGE_FILE_LOCAL_SYMS_STRIPPED       0x0008  // Local symbols stripped from file.
#define IMAGE_FILE_BYTES_REVERSED_LO         0x0080  // Bytes of machine word are reversed.
#define IMAGE_FILE_32BIT_MACHINE             0x0100  // 32 bit word machine.
#define IMAGE_FILE_DEBUG_STRIPPED            0x0200  // Debugging info stripped from file in .DBG file
#define IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP   0x0400  // If Image is on removable media, copy and run from the swap file.
#define IMAGE_FILE_NET_RUN_FROM_SWAP         0x0800  // If Image is on Net, copy and run from the swap file.
#define IMAGE_FILE_SYSTEM                    0x1000  // System File.
#define IMAGE_FILE_DLL                       0x2000  // File is a DLL.
#define IMAGE_FILE_UP_SYSTEM_ONLY            0x4000  // File should only be run on a UP machine
#define IMAGE_FILE_BYTES_REVERSED_HI         0x8000  // Bytes of machine word are reversed.


#define IMAGE_FILE_MACHINE_UNKNOWN           0
#define IMAGE_FILE_MACHINE_I386              0x014c  // Intel 386.
#define IMAGE_FILE_MACHINE_R3000             0x0162  // MIPS little-endian, 0x160 big-endian
#define IMAGE_FILE_MACHINE_R4000             0x0166  // MIPS little-endian
#define IMAGE_FILE_MACHINE_R10000            0x0168  // MIPS little-endian
#define IMAGE_FILE_MACHINE_WCEMIPSV2         0x0169  // MIPS little-endian WCE v2
#define IMAGE_FILE_MACHINE_ALPHA             0x0184  // Alpha_AXP
#define IMAGE_FILE_MACHINE_POWERPC           0x01F0  // IBM PowerPC Little-Endian
#define IMAGE_FILE_MACHINE_SH3               0x01a2  // SH3 little-endian
#define IMAGE_FILE_MACHINE_SH3E              0x01a4  // SH3E little-endian
#define IMAGE_FILE_MACHINE_SH4               0x01a6  // SH4 little-endian
#define IMAGE_FILE_MACHINE_ARM               0x01c0  // ARM Little-Endian
#define IMAGE_FILE_MACHINE_THUMB             0x01c2
#define IMAGE_FILE_MACHINE_IA64              0x0200  // Intel 64
#define IMAGE_FILE_MACHINE_MIPS16            0x0266  // MIPS
#define IMAGE_FILE_MACHINE_MIPSFPU           0x0366  // MIPS
#define IMAGE_FILE_MACHINE_MIPSFPU16         0x0466  // MIPS
#define IMAGE_FILE_MACHINE_ALPHA64           0x0284  // ALPHA64
#define IMAGE_FILE_MACHINE_AXP64             IMAGE_FILE_MACHINE_ALPHA64
#define IMAGE_FILE_MACHINE_CEF               0xC0EF



//
// Directory format.
//

typedef struct _IMAGE_DATA_DIRECTORY {
    DWORD   VirtualAddress;
    DWORD   Size;
} IMAGE_DATA_DIRECTORY, *PIMAGE_DATA_DIRECTORY;

#define IMAGE_NUMBEROF_DIRECTORY_ENTRIES    16

//
// Optional header format.
//

typedef struct _IMAGE_OPTIONAL_HEADER {
    //
    // Standard fields.
    //

    WORD    Magic;
    BYTE    MajorLinkerVersion;
    BYTE    MinorLinkerVersion;
    DWORD   SizeOfCode;
    DWORD   SizeOfInitializedData;
    DWORD   SizeOfUninitializedData;
    DWORD   AddressOfEntryPoint;
    DWORD   BaseOfCode;
    DWORD   BaseOfData;

    //
    // NT additional fields.
    //

    DWORD   ImageBase;
    DWORD   SectionAlignment;
    DWORD   FileAlignment;
    WORD    MajorOperatingSystemVersion;
    WORD    MinorOperatingSystemVersion;
    WORD    MajorImageVersion;
    WORD    MinorImageVersion;
    WORD    MajorSubsystemVersion;
    WORD    MinorSubsystemVersion;
    DWORD   Win32VersionValue;
    DWORD   SizeOfImage;
    DWORD   SizeOfHeaders;
    DWORD   CheckSum;
    WORD    Subsystem;
    WORD    DllCharacteristics;
    DWORD   SizeOfStackReserve;
    DWORD   SizeOfStackCommit;
    DWORD   SizeOfHeapReserve;
    DWORD   SizeOfHeapCommit;
    DWORD   LoaderFlags;
    DWORD   NumberOfRvaAndSizes;
    IMAGE_DATA_DIRECTORY DataDirectory[IMAGE_NUMBEROF_DIRECTORY_ENTRIES];
} IMAGE_OPTIONAL_HEADER, *PIMAGE_OPTIONAL_HEADER;


typedef struct _IMAGE_NT_HEADERS {
    DWORD Signature;
    IMAGE_FILE_HEADER FileHeader;
    IMAGE_OPTIONAL_HEADER OptionalHeader;
} IMAGE_NT_HEADERS, *PIMAGE_NT_HEADERS;


// Directory Entries


#define IMAGE_DIRECTORY_ENTRY_EXPORT          0   // Export Directory
#define IMAGE_DIRECTORY_ENTRY_IMPORT          1   // Import Directory
#define IMAGE_DIRECTORY_ENTRY_RESOURCE        2   // Resource Directory
#define IMAGE_DIRECTORY_ENTRY_EXCEPTION       3   // Exception Directory
#define IMAGE_DIRECTORY_ENTRY_SECURITY        4   // Security Directory
#define IMAGE_DIRECTORY_ENTRY_BASERELOC       5   // Base Relocation Table
#define IMAGE_DIRECTORY_ENTRY_DEBUG           6   // Debug Directory
//      IMAGE_DIRECTORY_ENTRY_COPYRIGHT       7   // (X86 usage)
#define IMAGE_DIRECTORY_ENTRY_ARCHITECTURE    7   // Architecture Specific Data
#define IMAGE_DIRECTORY_ENTRY_GLOBALPTR       8   // RVA of GP
#define IMAGE_DIRECTORY_ENTRY_TLS             9   // TLS Directory
#define IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG    10   // Load Configuration Directory
#define IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT   11   // Bound Import Directory in headers
#define IMAGE_DIRECTORY_ENTRY_IAT            12   // Import Address Table
#define IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT   13   // Delay Load Import Descriptors
#define IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR 14   // COM Runtime descriptor

//
// Section header format.
//

/*
#define IMAGE_SIZEOF_SHORT_NAME              8

typedef struct _IMAGE_SECTION_HEADER {
    BYTE    Name[IMAGE_SIZEOF_SHORT_NAME];
    union {
        DWORD   PhysicalAddress;
        DWORD   VirtualSize;
    } Misc;
    DWORD   VirtualAddress;
    DWORD   SizeOfRawData;
    DWORD   PointerToRawData;
    DWORD   PointerToRelocations;
    DWORD   PointerToLinenumbers;
    WORD    NumberOfRelocations;
    WORD    NumberOfLinenumbers;
    DWORD   Characteristics;
} IMAGE_SECTION_HEADER, *PIMAGE_SECTION_HEADER;
 */

#define IMAGE_SIZEOF_SECTION_HEADER          40


//
// Export Format
//

typedef struct _IMAGE_EXPORT_DIRECTORY {
    DWORD   Characteristics;
    DWORD   TimeDateStamp;
    WORD    MajorVersion;
    WORD    MinorVersion;
    DWORD   Name;
    DWORD   Base;
    DWORD   NumberOfFunctions;
    DWORD   NumberOfNames;
    PDWORD  *AddressOfFunctions;
    PDWORD  *AddressOfNames;
    PWORD   *AddressOfNameOrdinals;
} IMAGE_EXPORT_DIRECTORY, *PIMAGE_EXPORT_DIRECTORY;

//
// Import Format
//

typedef struct _IMAGE_IMPORT_BY_NAME {
    WORD    Hint;
    BYTE    Name[1];
} IMAGE_IMPORT_BY_NAME, *PIMAGE_IMPORT_BY_NAME;

#define IMAGE_ORDINAL_FLAG 0x80000000
#define IMAGE_ORDINAL(Ordinal) (Ordinal & 0xffff)


//
// Resource Format.
//

//
// Resource directory consists of two counts, following by a variable length
// array of directory entries.  The first count is the number of entries at
// beginning of the array that have actual names associated with each entry.
// The entries are in ascending order, case insensitive strings.  The second
// count is the number of entries that immediately follow the named entries.
// This second count identifies the number of entries that have 16-bit integer
// Ids as their name.  These entries are also sorted in ascending order.
//
// This structure allows fast lookup by either name or number, but for any
// given resource entry only one form of lookup is supported, not both.
// This is consistant with the syntax of the .RC file and the .RES file.
//

// Predefined resource types ... there may be some more, but I don't have
//                               the information yet.  .....sang cho.....

#define    RT_NEWRESOURCE   0x2000
#define    RT_ERROR         0x7fff
#define    RT_CURSOR        1
#define    RT_BITMAP        2
#define    RT_ICON          3
#define    RT_MENU          4
#define    RT_DIALOG        5
#define    RT_STRING        6
#define    RT_FONTDIR       7
#define    RT_FONT          8
#define    RT_ACCELERATORS  9
#define    RT_RCDATA        10
#define    RT_MESSAGETABLE  11
#define    RT_GROUP_CURSOR  12
#define    RT_GROUP_ICON    14
#define    RT_VERSION       16
#define    NEWBITMAP        (RT_BITMAP|RT_NEWRESOURCE)
#define    NEWMENU          (RT_MENU|RT_NEWRESOURCE)
#define    NEWDIALOG        (RT_DIALOG|RT_NEWRESOURCE)


typedef struct _IMAGE_RESOURCE_DIRECTORY {
    DWORD   Characteristics;
    DWORD   TimeDateStamp;
    WORD    MajorVersion;
    WORD    MinorVersion;
    WORD    NumberOfNamedEntries;
    WORD    NumberOfIdEntries;
//  IMAGE_RESOURCE_DIRECTORY_ENTRY DirectoryEntries[1];
} IMAGE_RESOURCE_DIRECTORY, *PIMAGE_RESOURCE_DIRECTORY;

#define IMAGE_RESOURCE_NAME_IS_STRING        0x80000000
#define IMAGE_RESOURCE_DATA_IS_DIRECTORY     0x80000000

//
// Each directory contains the 32-bit Name of the entry and an offset,
// relative to the beginning of the resource directory of the data associated
// with this directory entry.  If the name of the entry is an actual text
// string instead of an integer Id, then the high order bit of the name field
// is set to one and the low order 31-bits are an offset, relative to the
// beginning of the resource directory of the string, which is of type
// IMAGE_RESOURCE_DIRECTORY_STRING.  Otherwise the high bit is clear and the
// low-order 16-bits are the integer Id that identify this resource directory
// entry. If the directory entry is yet another resource directory (i.e. a
// subdirectory), then the high order bit of the offset field will be
// set to indicate this.  Otherwise the high bit is clear and the offset
// field points to a resource data entry.
//

typedef struct _IMAGE_RESOURCE_DIRECTORY_ENTRY {
    DWORD    Name;
    DWORD    OffsetToData;
} IMAGE_RESOURCE_DIRECTORY_ENTRY, *PIMAGE_RESOURCE_DIRECTORY_ENTRY;

//
// For resource directory entries that have actual string names, the Name
// field of the directory entry points to an object of the following type.
// All of these string objects are stored together after the last resource
// directory entry and before the first resource data object.  This minimizes
// the impact of these variable length objects on the alignment of the fixed
// size directory entry objects.
//

typedef struct _IMAGE_RESOURCE_DIRECTORY_STRING {
    WORD    Length;
    CHAR    NameString[ 1 ];
} IMAGE_RESOURCE_DIRECTORY_STRING, *PIMAGE_RESOURCE_DIRECTORY_STRING;


typedef struct _IMAGE_RESOURCE_DIR_STRING_U {
    WORD    Length;
    WCHAR   NameString[ 1 ];
} IMAGE_RESOURCE_DIR_STRING_U, *PIMAGE_RESOURCE_DIR_STRING_U;


//
// Each resource data entry describes a leaf node in the resource directory
// tree.  It contains an offset, relative to the beginning of the resource
// directory of the data for the resource, a size field that gives the number
// of bytes of data at that offset, a CodePage that should be used when
// decoding code point values within the resource data.  Typically for new
// applications the code page would be the unicode code page.
//

typedef struct _IMAGE_RESOURCE_DATA_ENTRY {
    DWORD   OffsetToData;
    DWORD   Size;
    DWORD   CodePage;
    DWORD   Reserved;
} IMAGE_RESOURCE_DATA_ENTRY, *PIMAGE_RESOURCE_DATA_ENTRY;

//                                       
// BitmapInfoHeader used in DIB Header (Icons, Cursors, Group ...s)
//

typedef struct tagBITMAPINFOHEADER {    /* bmih */
    DWORD   biSize;
    LONG    biWidth;
    LONG    biHeight;
    WORD    biPlanes;
    WORD    biBitCount;
    DWORD   biCompression;
    DWORD   biSizeImage;
    LONG    biXPelsPerMeter;
    LONG    biYPelsPerMeter;
    DWORD   biClrUsed;
    DWORD   biClrImportant;
} BITMAPINFOHEADER, *PBITMAPINFOHEADER;

typedef struct tagRGBQUAD {     /* rgbq */
    BYTE    rgbBlue;
    BYTE    rgbGreen;
    BYTE    rgbRed;
    BYTE    rgbReserved;
} RGBQUAD, *PRGBQUAD;

// Icon Resources       ... addes by Sang Cho

typedef struct ICONDIR {
    WORD          idReserved;
    WORD          idType;
    WORD          idCount;
//ICONDIRENTRY idEntries[1];
} ICONHEADER, *PICONHEADER;

struct IconDirectoryEntry {
    BYTE  bWidth;
    BYTE  bHeight;
    BYTE  bColorCount;
    BYTE  bReserved;
    WORD  wPlanes;
    WORD  wBitCount;
    DWORD dwBytesInRes;
    DWORD dwImageOffset;
} ICONDIRENTRY, *PICONDIRENTRY;


//  Menu Resources       ... added by .....sang cho....

// Menu resources are composed of a menu header followed by a sequential list
// of menu items. There are two types of menu items: pop-ups and normal menu
// itmes. The MENUITEM SEPARATOR is a special case of a normal menu item with
// an empty name, zero ID, and zero flags.

typedef struct _IMAGE_MENU_HEADER{
    WORD   wVersion;      // Currently zero
    WORD   cbHeaderSize;  // Also zero
} IMAGE_MENU_HEADER, *PIMAGE_MENU_HEADER;

typedef struct _IMAGE_POPUP_MENU_ITEM{
    WORD   fItemFlags;  
    WCHAR  szItemText[1];
} IMAGE_POPUP_MENU_ITEM, *PIMAGE_POPUP_MENU_ITEM;

typedef struct _IMAGE_NORMAL_MENU_ITEM{
    WORD   fItemFlags;  
    WORD   wMenuID;
    WCHAR  szItemText[1];
} IMAGE_NORMAL_MENU_ITEM, *PIMAGE_NORMAL_MENU_ITEM;

#define GRAYED       0x0001 // GRAYED keyword
#define INACTIVE     0x0002 // INACTIVE keyword
#define BITMAP       0x0004 // BITMAP keyword
#define OWNERDRAW    0x0100 // OWNERDRAW keyword
#define CHECKED      0x0008 // CHECKED keyword
#define POPUP        0x0010 // used internally
#define MENUBARBREAK 0x0020 // MENUBARBREAK keyword
#define MENUBREAK    0x0040 // MENUBREAK keyword
#define ENDMENU      0x0080 // used internally


// Dialog Box Resources .................. added by sang cho.

// A dialog box is contained in a single resource and has a header and 
// a portion repeated for each control in the dialog box.
// The item DWORD IStyle is a standard window style composed of flags found
// in WINDOWS.H.
// The default style for a dialog box is:
// WS_POPUP | WS_BORDER | WS_SYSMENU
// 
// The itme marked "Name or Ordinal" are :
// If the first word is an 0xffff, the next two bytes contain an ordinal ID.
// Otherwise, the first one or more WORDS contain a double-null-terminated string.
// An empty string is represented by a single WORD zero in the first location.
// 
// The WORD wPointSize and WCHAR szFontName entries are present if the FONT
// statement was included for the dialog box. This can be detected by checking
// the entry IStyle. If IStyle & DS_SETFONT ( which is 0x40), then these
// entries will be present.

typedef struct _IMAGE_DIALOG_BOX_HEADER1{
    DWORD  IStyle;
    DWORD  IExtendedStyle;    // New for Windows NT
    WORD   nControls;         // Number of Controls
    WORD   x;
    WORD   y;
    WORD   cx;
    WORD   cy;
//      N_OR_O MenuName;         // Name or Ordinal ID
//      N_OR_O ClassName;                // Name or Ordinal ID
//      WCHAR  szCaption[];
//      WORD   wPointSize;       // Only here if FONT set for dialog
//      WCHAR  szFontName[];     // This too
} IMAGE_DIALOG_HEADER, *PIMAGE_DIALOG_HEADER;

typedef union _NAME_OR_ORDINAL{    // Name or Ordinal ID
    struct _ORD_ID{
        WORD   flgId;
    WORD   Id;
    } ORD_ID;
    WCHAR  szName[1];      
} NAME_OR_ORDINAL, *PNAME_OR_ORDINAL;

// The data for each control starts on a DWORD boundary (which may require
// some padding from the previous control), and its format is as follows:

typedef struct _IMAGE_CONTROL_DATA{
    DWORD   IStyle;
    DWORD   IExtendedStyle;
    WORD    x;
    WORD    y;
    WORD    cx;
    WORD    cy;
    WORD    wId;
//  N_OR_O  ClassId;
//  N_OR_O  Text;
//  WORD    nExtraStuff;
} IMAGE_CONTROL_DATA, *PIMAGE_CONTROL_DATA;

#define BUTTON       0x80
#define EDIT         0x81
#define STATIC       0x82
#define LISTBOX      0x83
#define SCROLLBAR    0x84
#define COMBOBOX     0x85

// The various statements used in a dialog script are all mapped to these
// classes along with certain modifying styles. The values for these styles
// can be found in WINDOWS.H. All dialog controls have the default styles
// of WS_CHILD and WS_VISIBLE. A list of the default styles used follows:
//
// Statement           Default Class         Default Styles
// CONTROL             None                  WS_CHILD|WS_VISIBLE
// LTEXT               STATIC                ES_LEFT
// RTEXT               STATIC                ES_RIGHT
// CTEXT               STATIC                ES_CENTER
// LISTBOX             LISTBOX               WS_BORDER|LBS_NOTIFY
// CHECKBOX            BUTTON                BS_CHECKBOX|WS_TABSTOP
// PUSHBUTTON          BUTTON                BS_PUSHBUTTON|WS_TABSTOP
// GROUPBOX            BUTTON                BS_GROUPBOX
// DEFPUSHBUTTON       BUTTON                BS_DFPUSHBUTTON|WS_TABSTOP
// RADIOBUTTON         BUTTON                BS_RADIOBUTTON
// AUTOCHECKBOX        BUTTON                BS_AUTOCHECKBOX
// AUTO3STATE          BUTTON                BS_AUTO3STATE
// AUTORADIOBUTTON     BUTTON                BS_AUTORADIOBUTTON
// PUSHBOX             BUTTON                BS_PUSHBOX
// STATE3              BUTTON                BS_3STATE
// EDITTEXT            EDIT                  ES_LEFT|WS_BORDER|WS_TABSTOP
// COMBOBOX            COMBOBOX              None
// ICON                STATIC                SS_ICON
// SCROLLBAR           SCROLLBAR             None
///

#define WS_OVERLAPPED   0x00000000L
#define WS_POPUP        0x80000000L
#define WS_CHILD        0x40000000L
#define WS_CLIPSIBLINGS 0x04000000L
#define WS_CLIPCHILDREN 0x02000000L
#define WS_VISIBLE      0x10000000L
#define WS_DISABLED     0x08000000L
#define WS_MINIMIZE     0x20000000L
#define WS_MAXIMIZE     0x01000000L
#define WS_CAPTION      0x00C00000L
#define WS_BORDER       0x00800000L
#define WS_DLGFRAME     0x00400000L
#define WS_VSCROLL      0x00200000L
#define WS_HSCROLL      0x00100000L
#define WS_SYSMENU      0x00080000L
#define WS_THICKFRAME   0x00040000L
#define WS_MINIMIZEBOX  0x00020000L
#define WS_MAXIMIZEBOX  0x00010000L
#define WS_GROUP        0x00020000L
#define WS_TABSTOP      0x00010000L

// other aliases
#define WS_OVERLAPPEDWINDOW (WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX)
#define WS_POPUPWINDOW  (WS_POPUP | WS_BORDER | WS_SYSMENU)
#define WS_CHILDWINDOW  (WS_CHILD)
#define WS_TILED        WS_OVERLAPPED
#define WS_ICONIC       WS_MINIMIZE
#define WS_SIZEBOX      WS_THICKFRAME
#define WS_TILEDWINDOW  WS_OVERLAPPEDWINDOW

#define WS_EX_DLGMODALFRAME     0x00000001L
#define WS_EX_NOPARENTNOTIFY    0x00000004L
#define WS_EX_TOPMOST           0x00000008L
#define WS_EX_ACCEPTFILES       0x00000010L
#define WS_EX_TRANSPARENT       0x00000020L

#define BS_PUSHBUTTON           0x00000000L
#define BS_DEFPUSHBUTTON        0x00000001L
#define BS_CHECKBOX             0x00000002L
#define BS_AUTOCHECKBOX         0x00000003L
#define BS_RADIOBUTTON          0x00000004L
#define BS_3STATE               0x00000005L
#define BS_AUTO3STATE           0x00000006L
#define BS_GROUPBOX             0x00000007L
#define BS_USERBUTTON           0x00000008L
#define BS_AUTORADIOBUTTON      0x00000009L
#define BS_OWNERDRAW            0x0000000BL
#define BS_LEFTTEXT             0x00000020L

#define ES_LEFT         0x00000000L
#define ES_CENTER       0x00000001L
#define ES_RIGHT        0x00000002L
#define ES_MULTILINE    0x00000004L
#define ES_UPPERCASE    0x00000008L
#define ES_LOWERCASE    0x00000010L
#define ES_PASSWORD     0x00000020L
#define ES_AUTOVSCROLL  0x00000040L
#define ES_AUTOHSCROLL  0x00000080L
#define ES_NOHIDESEL    0x00000100L
#define ES_OEMCONVERT   0x00000400L
#define ES_READONLY     0x00000800L
#define ES_WANTRETURN   0x00001000L

#define LBS_NOTIFY            0x0001L
#define LBS_SORT              0x0002L
#define LBS_NOREDRAW          0x0004L
#define LBS_MULTIPLESEL       0x0008L
#define LBS_OWNERDRAWFIXED    0x0010L
#define LBS_OWNERDRAWVARIABLE 0x0020L
#define LBS_HASSTRINGS        0x0040L
#define LBS_USETABSTOPS       0x0080L
#define LBS_NOINTEGRALHEIGHT  0x0100L
#define LBS_MULTICOLUMN       0x0200L
#define LBS_WANTKEYBOARDINPUT 0x0400L
#define LBS_EXTENDEDSEL       0x0800L
#define LBS_DISABLENOSCROLL   0x1000L

#define SS_LEFT             0x00000000L
#define SS_CENTER           0x00000001L
#define SS_RIGHT            0x00000002L
#define SS_ICON             0x00000003L
#define SS_BLACKRECT        0x00000004L
#define SS_GRAYRECT         0x00000005L
#define SS_WHITERECT        0x00000006L
#define SS_BLACKFRAME       0x00000007L
#define SS_GRAYFRAME        0x00000008L
#define SS_WHITEFRAME       0x00000009L
#define SS_SIMPLE           0x0000000BL
#define SS_LEFTNOWORDWRAP   0x0000000CL
#define SS_BITMAP           0x0000000EL

//
// Debug Format
//

typedef struct _IMAGE_DEBUG_DIRECTORY {
    DWORD   Characteristics;
    DWORD   TimeDateStamp;
    WORD    MajorVersion;
    WORD    MinorVersion;
    DWORD   Type;
    DWORD   SizeOfData;
    DWORD   AddressOfRawData;
    DWORD   PointerToRawData;
} IMAGE_DEBUG_DIRECTORY, *PIMAGE_DEBUG_DIRECTORY;

#define IMAGE_DEBUG_TYPE_UNKNOWN          0
#define IMAGE_DEBUG_TYPE_COFF             1
#define IMAGE_DEBUG_TYPE_CODEVIEW         2
#define IMAGE_DEBUG_TYPE_FPO              3
#define IMAGE_DEBUG_TYPE_MISC             4
#define IMAGE_DEBUG_TYPE_EXCEPTION        5
#define IMAGE_DEBUG_TYPE_FIXUP            6
#define IMAGE_DEBUG_TYPE_OMAP_TO_SRC      7
#define IMAGE_DEBUG_TYPE_OMAP_FROM_SRC    8


typedef struct _IMAGE_DEBUG_MISC {
    DWORD       DataType;               // type of misc data, see defines
    DWORD       Length;                 // total length of record, rounded to four
                    // byte multiple.
    BOOLEAN     Unicode;                // TRUE if data is unicode string
    BYTE        Reserved[ 3 ];
    BYTE        Data[ 1 ];              // Actual data
} IMAGE_DEBUG_MISC, *PIMAGE_DEBUG_MISC;


//
// Debugging information can be stripped from an image file and placed
// in a separate .DBG file, whose file name part is the same as the
// image file name part (e.g. symbols for CMD.EXE could be stripped
// and placed in CMD.DBG).  This is indicated by the IMAGE_FILE_DEBUG_STRIPPED
// flag in the Characteristics field of the file header.  The beginning of
// the .DBG file contains the following structure which captures certain
// information from the image file.  This allows a debug to proceed even if
// the original image file is not accessable.  This header is followed by
// zero of more IMAGE_SECTION_HEADER structures, followed by zero or more
// IMAGE_DEBUG_DIRECTORY structures.  The latter structures and those in
// the image file contain file offsets relative to the beginning of the
// .DBG file.
//
// If symbols have been stripped from an image, the IMAGE_DEBUG_MISC structure
// is left in the image file, but not mapped.  This allows a debugger to
// compute the name of the .DBG file, from the name of the image in the
// IMAGE_DEBUG_MISC structure.
//

typedef struct _IMAGE_SEPARATE_DEBUG_HEADER {
    WORD        Signature;
    WORD        Flags;
    WORD        Machine;
    WORD        Characteristics;
    DWORD       TimeDateStamp;
    DWORD       CheckSum;
    DWORD       ImageBase;
    DWORD       SizeOfImage;
    DWORD       NumberOfSections;
    DWORD       ExportedNamesSize;
    DWORD       DebugDirectorySize;
    DWORD       SectionAlignment;
    DWORD       Reserved[2];
} IMAGE_SEPARATE_DEBUG_HEADER, *PIMAGE_SEPARATE_DEBUG_HEADER;

#define IMAGE_SEPARATE_DEBUG_SIGNATURE  0x4944

#define IMAGE_SEPARATE_DEBUG_FLAGS_MASK 0x8000
#define IMAGE_SEPARATE_DEBUG_MISMATCH   0x8000  // when DBG was updated, the
                        // old checksum didn't match.


//
// End Image Format
//


#define SIZE_OF_NT_SIGNATURE    sizeof (DWORD)
#define MAXRESOURCENAME         13

/* global macros to define header offsets into file */
/* offset to PE file signature                      */
#define NTSIGNATURE(a) ((LPVOID)((BYTE *)a       +  \
             ((PIMAGE_DOS_HEADER)a)->e_lfanew))

/* DOS header identifies the NT PEFile signature dword
   the PEFILE header exists just after that dword   */
#define PEFHDROFFSET(a) ((LPVOID)((BYTE *)a      +  \
             ((PIMAGE_DOS_HEADER)a)->e_lfanew    +  \
             SIZE_OF_NT_SIGNATURE))

/* PE optional header is immediately after PEFile header */
#define OPTHDROFFSET(a) ((LPVOID)((BYTE *)a      +  \
             ((PIMAGE_DOS_HEADER)a)->e_lfanew    +  \
             SIZE_OF_NT_SIGNATURE                +  \
             sizeof (IMAGE_FILE_HEADER)))

/* section headers are immediately after PE optional header */
#define SECHDROFFSET(a) ((LPVOID)((BYTE *)a      +  \
             ((PIMAGE_DOS_HEADER)a)->e_lfanew    +  \
             SIZE_OF_NT_SIGNATURE                +  \
             sizeof (IMAGE_FILE_HEADER)          +  \
             sizeof (IMAGE_OPTIONAL_HEADER)))


typedef struct tagImportDirectory
    {
    DWORD    dwRVAFunctionNameList;
    DWORD    dwUseless1;
    DWORD    dwUseless2;
    DWORD    dwRVAModuleName;
    DWORD    dwRVAFunctionAddressList;
    }IMAGE_IMPORT_MODULE_DIRECTORY, * PIMAGE_IMPORT_MODULE_DIRECTORY;


/* global prototypes for functions in pefile.c */
/* PE file header info */
BOOL    WINAPI GetDosHeader (LPVOID, PIMAGE_DOS_HEADER);
DWORD   WINAPI ImageFileType (LPVOID);
BOOL    WINAPI GetPEFileHeader (LPVOID, PIMAGE_FILE_HEADER);

/* PE optional header info */
BOOL    WINAPI GetPEOptionalHeader (LPVOID, PIMAGE_OPTIONAL_HEADER);
LPVOID  WINAPI GetModuleEntryPoint (LPVOID);
int     WINAPI NumOfSections (LPVOID);
LPVOID  WINAPI GetImageBase (LPVOID);
LPVOID  WINAPI ImageDirectoryOffset (LPVOID, DWORD);
LPVOID  WINAPI ImageDirectorySection (LPVOID, DWORD);

/* PE section header info */
int     WINAPI GetSectionNames (LPVOID, char **);
BOOL    WINAPI GetSectionHdrByName (LPVOID, PIMAGE_SECTION_HEADER, char *);

//
// structur to store string tokens
//
typedef struct _Str_P {
    char    flag;                 // string_flag '@' or '%' or '#'
    char    *pos;                 // starting postion of string
    int     length;       // length of string
    BOOL    wasString;    // if it were stringMode or not
} Str_P;

/* import section info */
int    WINAPI GetImportModuleNames (LPVOID, char  **);
int    WINAPI GetImportFunctionNamesByModule (LPVOID, char *, char  **);

// import function name reporting
int    WINAPI GetStringLength (char *);
int    WINAPI GetPreviousParamString (char *, char *);
int    WINAPI TranslateParameters (char **, char **, char **);
BOOL   WINAPI StringExpands (char **, char **, char **, Str_P *);
LPVOID WINAPI TranslateFunctionName (char *);

/* export section info */
int     WINAPI GetExportFunctionNames (LPVOID, char **);

/* resource section info */
int    WINAPI GetNumberOfResources (LPVOID);
int    WINAPI GetListOfResourceTypes (LPVOID, char **);
int    WINAPI MenuScan (int *, WORD **);
int    WINAPI MenuFill (char **, WORD **);
void   WINAPI StrangeMenuFill (char **, WORD **, int);
int    WINAPI GetContentsOfMenu (LPVOID, char **);
int    WINAPI PrintMenu (int, char **);
int    WINAPI PrintStrangeMenu (char **);
int    WINAPI dumpMenu (char **,int);

/* debug section info */
BOOL   WINAPI IsDebugInfoStripped (LPVOID);
int    WINAPI RetrieveModuleName (LPVOID, char **);
BOOL   WINAPI IsDebugFile (LPVOID);
BOOL   WINAPI GetSeparateDebugHeader (LPVOID, PIMAGE_SEPARATE_DEBUG_HEADER);


/* copy dos header information to structure */
BOOL  WINAPI GetDosHeader (
    LPVOID               lpFile,
    PIMAGE_DOS_HEADER    pHeader)
{
    /* dos header rpresents first structure of bytes in file */
    if (*(USHORT *)lpFile == IMAGE_DOS_SIGNATURE)
    memcpy((LPVOID)pHeader, lpFile, sizeof (IMAGE_DOS_HEADER));
    else
    return FALSE;

    return TRUE;
}

/* return file signature */
DWORD  WINAPI ImageFileType (
    LPVOID    lpFile)
{
    /* dos file signature comes first */
    if (*(USHORT *)lpFile == IMAGE_DOS_SIGNATURE)
    {
    /* determine location of PE File header from dos header */
    if (LOWORD (*(DWORD *)NTSIGNATURE (lpFile)) == IMAGE_OS2_SIGNATURE ||
        LOWORD (*(DWORD *)NTSIGNATURE (lpFile)) == IMAGE_OS2_SIGNATURE_LE)
        return (DWORD)LOWORD(*(DWORD *)NTSIGNATURE (lpFile));

    else if (*(DWORD *)NTSIGNATURE (lpFile) == IMAGE_NT_SIGNATURE)
        return IMAGE_NT_SIGNATURE;

    else
        return IMAGE_DOS_SIGNATURE;
    }

    else
    /* unknown file type */
    return 0;
}

/* copy file header information to structure */
BOOL  WINAPI GetPEFileHeader (
    LPVOID                lpFile,
    PIMAGE_FILE_HEADER    pHeader)
{
    /* file header follows dos header */
    if (ImageFileType (lpFile) == IMAGE_NT_SIGNATURE)
    memcpy((LPVOID)pHeader,  PEFHDROFFSET (lpFile), sizeof (IMAGE_FILE_HEADER));
    else
    return FALSE;

    return TRUE;
}

/* copy optional header info to structure */
BOOL WINAPI GetPEOptionalHeader (
    LPVOID                    lpFile,
    PIMAGE_OPTIONAL_HEADER    pHeader)
{
    /* optional header follows file header and dos header */
    if (ImageFileType (lpFile) == IMAGE_NT_SIGNATURE)
    memcpy ((LPVOID)pHeader,  OPTHDROFFSET (lpFile), sizeof (IMAGE_OPTIONAL_HEADER));
    else
    return FALSE;

    return TRUE;
}

/* function returns the entry point for an exe module lpFile must
   be a memory mapped file pointer to the beginning of the image file */
LPVOID  WINAPI GetModuleEntryPoint (
    LPVOID    lpFile)
{
    PIMAGE_OPTIONAL_HEADER   poh = (PIMAGE_OPTIONAL_HEADER)OPTHDROFFSET (lpFile);

    if (poh != NULL)
    return (LPVOID)(poh->AddressOfEntryPoint);
    else
    return NULL;
}

/* return the total number of sections in the module */
int   WINAPI NumOfSections (
    LPVOID    lpFile)
{
    /* number os sections is indicated in file header */
    return ((int)((PIMAGE_FILE_HEADER)PEFHDROFFSET (lpFile))->NumberOfSections);
}

/* retrieve entry point */
LPVOID  WINAPI GetImageBase (
    LPVOID    lpFile)
{
    PIMAGE_OPTIONAL_HEADER   poh = (PIMAGE_OPTIONAL_HEADER)OPTHDROFFSET (lpFile);

    if (poh != NULL)
    return (LPVOID)(poh->ImageBase);
    else
    return NULL;
}

//
// This function is written by sang cho
//                                                 .. october 5, 1997
//
/* function returns the actual address of given RVA,      lpFile must
   be a memory mapped file pointer to the beginning of the image file */
LPVOID  WINAPI GetActualAddress (
    LPVOID    lpFile,
    DWORD     dwRVA)
{
    //PIMAGE_OPTIONAL_HEADER   poh = (PIMAGE_OPTIONAL_HEADER)OPTHDROFFSET (lpFile);
    PIMAGE_SECTION_HEADER    psh = (PIMAGE_SECTION_HEADER)SECHDROFFSET (lpFile);
    int                      nSections = NumOfSections (lpFile);
    int                      i = 0;

    if (dwRVA == 0) return 0;

    /* locate section containing image directory */
    while (i++<nSections)
    {
        if (psh->VirtualAddress <= (DWORD)dwRVA &&
        psh->VirtualAddress + psh->SizeOfRawData > (DWORD)dwRVA)
        break;
        psh++;
    }

    if (i > nSections)
    return 0;

    /* return image import directory offset */
    return (LPVOID)(((int)lpFile + (int)dwRVA - psh->VirtualAddress) +
                   (int)psh->PointerToRawData);
}

//
// This function is modified by sang cho
//
//
/* return offset to specified IMAGE_DIRECTORY entry */
LPVOID  WINAPI ImageDirectoryOffset (
    LPVOID    lpFile,
    DWORD     dwIMAGE_DIRECTORY)
{
    PIMAGE_OPTIONAL_HEADER   poh = (PIMAGE_OPTIONAL_HEADER)OPTHDROFFSET (lpFile);
    PIMAGE_SECTION_HEADER    psh = (PIMAGE_SECTION_HEADER)SECHDROFFSET (lpFile);
    int                      nSections = NumOfSections (lpFile);
    int                      i = 0;
    LPVOID                   VAImageDir;

    /* must be 0 thru (NumberOfRvaAndSizes-1) */
    if (dwIMAGE_DIRECTORY >= poh->NumberOfRvaAndSizes)
    return NULL;

    /* locate specific image directory's relative virtual address */
    VAImageDir = (LPVOID)poh->DataDirectory[dwIMAGE_DIRECTORY].VirtualAddress;

    if (VAImageDir == NULL) return NULL;
    /* locate section containing image directory */
    while (i++<nSections)
    {
        if (psh->VirtualAddress <= (DWORD)VAImageDir &&
        psh->VirtualAddress + psh->SizeOfRawData > (DWORD)VAImageDir)
        break;
        psh++;
    }

    if (i > nSections)
    return NULL;

    /* return image import directory offset */
    return (LPVOID)(((int)lpFile + (int)VAImageDir - psh->VirtualAddress) +
                   (int)psh->PointerToRawData);
}

/* function retrieve names of all the sections in the file */
int WINAPI GetSectionNames (
    LPVOID    lpFile,
    char      **pszSections)
{
    int                      nSections = NumOfSections (lpFile);
    int                      i, nCnt = 0;
    PIMAGE_SECTION_HEADER    psh;
    char                     *ps;


    if (ImageFileType (lpFile) != IMAGE_NT_SIGNATURE ||
    (psh = (PIMAGE_SECTION_HEADER)SECHDROFFSET (lpFile)) == NULL)
    return 0;

    /* count the number of chars used in the section names */
    for (i=0; i<nSections; i++)
    nCnt += strlen (psh[i].Name) + 1;

    /* allocate space for all section names from heap */
    ps = *pszSections = (char *)calloc (nCnt, 1);


    for (i=0; i<nSections; i++)
    {
        strcpy (ps, psh[i].Name);
        ps += strlen (psh[i].Name) + 1;
    }

    return nCnt;
}

/* function gets the function header for a section identified by name */
BOOL    WINAPI GetSectionHdrByName (
    LPVOID                   lpFile,
    IMAGE_SECTION_HEADER     *sh,
    char                     *szSection)
{
    PIMAGE_SECTION_HEADER    psh;
    int                      nSections = NumOfSections (lpFile);
    int                      i;


    if ((psh = (PIMAGE_SECTION_HEADER)SECHDROFFSET (lpFile)) != NULL)
    {
    /* find the section by name */
        for (i=0; i<nSections; i++)
        {
        if (!strcmp (psh->Name, szSection))
            {
            /* copy data to header */
            memcpy ((LPVOID)sh, (LPVOID)psh, sizeof (IMAGE_SECTION_HEADER));
            return TRUE;
            }
        else psh++;
        }
    }
    return FALSE;
}

//
// This function is modified by sang cho
//
//
/* get import modules names separated by null terminators, return module count */
int  WINAPI GetImportModuleNames (
    LPVOID    lpFile,
    char      **pszModules)
{
    PIMAGE_IMPORT_MODULE_DIRECTORY  pid = (PIMAGE_IMPORT_MODULE_DIRECTORY)
    ImageDirectoryOffset (lpFile, IMAGE_DIRECTORY_ENTRY_IMPORT);
    //
    // sometimes there may be no section for idata or edata
    // instead rdata or data section may contain these sections ..
    // or even module names or function names are in different section.
    // so that's why we need to get actual address of RVAs each time.
    //         ...................sang cho..................
    //
    // PIMAGE_SECTION_HEADER     psh = (PIMAGE_SECTION_HEADER)
    // ImageDirectorySection (lpFile, IMAGE_DIRECTORY_ENTRY_IMPORT);
    // BYTE                  *pData = (BYTE *)pid;
    // DWORD            *pdw = (DWORD *)pid;
    int               nCnt = 0, nSize = 0, i;
    char             *pModule[1024];  /* hardcoded maximum number of modules?? */
    int               pidTab[1024];
    char                 *psz;

    if (pid == NULL) return 0;

    // pData = (BYTE *)((int)lpFile + psh->PointerToRawData - psh->VirtualAddress);

    /* extract all import modules */
    while (pid->dwRVAModuleName)
    {
    /* allocate temporary buffer for absolute string offsets */
        //pModule[nCnt] = (char *)(pData + pid->dwRVAModuleName);
        pModule[nCnt] = (char *)GetActualAddress (lpFile, pid->dwRVAModuleName);
        pidTab[nCnt] = (int)pid;
        nSize += strlen (pModule[nCnt]) + 1 + 4;

    /* increment to the next import directory entry */
        pid++;
        nCnt++;
    }

    /* copy all strings to one chunk of memory */
	if(*pszModules != NULL) {
		free(*pszModules);
	}
    *pszModules = (char *)calloc(nSize, 1);
    piNameBuffSize = nSize;
    psz = *pszModules;
    for (i=0; i<nCnt; i++)
    {
        *(int *)psz = pidTab[i]; 
        strcpy (psz+4, pModule[i]);
        psz += strlen (psz+4) + 1 + 4;
    }
    return nCnt;
}

//
// This function is rewritten by sang cho
//
//
/* get import module function names separated by null terminators, return function count */
int  WINAPI GetImportFunctionNamesByModule (
    LPVOID      lpFile,
    char       *pszModule,
    char      **pszFunctions)
{
    PIMAGE_IMPORT_MODULE_DIRECTORY  pid;
    
    //
    // sometimes there may be no section for idata or edata
    // instead rdata or data section may contain these sections ..
    // or even module names or function names are in different section.
    // so that's why we need to get actual address each time.
    //         ...................sang cho..................
    //
    
    int              nCnt = 0, nSize = 0;
    int              nnid = 0;
    int              mnlength, i;
    DWORD            dwFunctionName;
    DWORD            dwFunctionAddress;
    char             name[128];
    char             buff[256];             // enough for any string ??
    char            *psz;
    DWORD           *pdw;
    int              r,rr;
    _key_            k;


    pid = (PIMAGE_IMPORT_MODULE_DIRECTORY)(*(DWORD *)pszModule);

    /* exit if the module is not found */
    if (!pid->dwRVAModuleName)
    return 0;

    // I am doing this to get rid of .dll from module name
    strcpy (name, pszModule+4);
    mnlength = strlen (pszModule+4);
    for (i=0; i<mnlength; i++) if (name[i] == '.') break;
    name[i] = 0;
    mnlength = i;

    /* count number of function names and length of strings */
    dwFunctionName = pid->dwRVAFunctionNameList;
    
    // IMAGE_IMPORT_BY_NAME OR IMAGE_THUNK_DATA
    // modified by Sang Cho
    
    //fprintf(stderr,"pid = %08X dwFunctionName = %08X name = %s", 
    //(int)pid-(int)lpFile, dwFunctionName,name),getch();

    // modified by sang cho 1998.1.24

    if (dwFunctionName==0) dwFunctionName = pid->dwRVAFunctionAddressList;

    while (dwFunctionName &&
       *(pdw=(DWORD *)GetActualAddress (lpFile, dwFunctionName)) )      
    {
        if ((*pdw) & 0x80000000 )   nSize += mnlength + 11 + 1 + 6;
        else nSize += strlen ((char *)GetActualAddress (lpFile, *pdw+2)) + 1+6;
        dwFunctionName += 4;
        nCnt++;
    }
    
    /* allocate memory  for function names */
    *pszFunctions = (char *)calloc (nSize, 1);
    psz = *pszFunctions;

    //
    // I modified this part to store function address (4 bytes),
    //                               ord number (2 bytes),
    //                                                      and      name strings (which was there originally)
    // so that's why there are 6 more bytes...... +6,  or +4 and +2 etc.
    // these informations are used where they are needed.
    //                      ...........sang cho..................
    //
    /* copy function names to mempry pointer */
    dwFunctionName = pid->dwRVAFunctionNameList;
    // modified by sang cho 1998.1.24
    if (dwFunctionName==0) dwFunctionName = pid->dwRVAFunctionAddressList;
    dwFunctionAddress = pid->dwRVAFunctionAddressList;
    while (dwFunctionName                          &&
       *(pdw=(DWORD *)GetActualAddress (lpFile, dwFunctionName)) )
    {
        if ((*pdw) & 0x80000000)
        {
        r=*(int *)psz=(int)(*(DWORD *)GetActualAddress (lpFile, dwFunctionAddress));
            psz += 4;
        *(short *)psz=*(short *)pdw;
        psz += 2;        rr=(int)pdw;
        sprintf(buff, "%s:NoName%04d", name, nnid++);
        strcpy (psz, buff);     psz += strlen (buff) + 1;
            // this one is needed to link import function names to codes..
            k.class=992; k.c_ref= r; k.c_pos=-rr;
            MyBtreeInsertX(&k);
            k.class=0; k.c_ref=-rr; k.c_pos=(int)pszModule+4;
            MyBtreeInsertX(&k);
        }
        else
        {
        r=*(int *)psz=(int)(*(DWORD *)GetActualAddress (lpFile, dwFunctionAddress));
            psz += 4;
        *(short *)psz=(*(short *)GetActualAddress(lpFile, *pdw));
        psz += 2;        rr=(int)GetActualAddress(lpFile, *pdw + 2);
        strcpy (psz, (char *)rr);
        psz += strlen ((char *)GetActualAddress(lpFile, *pdw + 2)) + 1;
        
            // this one is needed to link import function names to codes..
            k.class=991; k.c_ref= r; k.c_pos=rr;
            MyBtreeInsertX(&k);
            k.class=0; k.c_ref=rr; k.c_pos=(int)pszModule+4;
            MyBtreeInsertX(&k);
        }
        dwFunctionName += 4;
        dwFunctionAddress += 4;
    }

    return nCnt;
}

//
// This function is written by sang cho
//                                                         October 6, 1997
//
/* get numerically expressed string length */
int WINAPI GetStringLength (
    char      *psz)
{
    if (!isdigit (*psz)) return 0; 
    if (isdigit (*(psz+1))) return (*psz - '0')*10 + *(psz+1) - '0';
    else return *psz - '0';
}

//
// This function is written by sang cho
//                                                         October 12, 1997
//

/* translate parameter part of condensed name */
int   WINAPI GetPreviousParamString ( 
    char       *xpin,                     // read-only source
    char       *xpout)                            // translated result
{
    int         n=0;
    char       *pin, *pout;           

    pin  = xpin;
    pout = xpout;

    pin--;
    if (*pin == ',') pin--;
    else { //printf ("\n **error PreviousParamString1 char = %02X %s", *pin, pin); 
	      return (0); }

    while (*pin)
    {
         if (*pin == '>') n++;
        else if (*pin == '<') n--;
        else if (*pin == ')') n++;
        
        if (n > 0) 
        {
            if (*pin == '(') n--;
        }
        else if (strchr (",(", *pin)) break;
        pin--;
    }

    //printf("\n ----- %s", pin);
    if (strchr (",(", *pin)) {pin++;} // printf("\n %s", pin); }
    else { printf ("\n **error PreviousParamString2"); return (0); }

    n = xpin - pin - 1;
    strncpy (pout, pin, n);
    *(pout + n) = 0;
	return 1;
}

//
// This function is written by sang cho
//                                                         October 10, 1997
//

/* translate parameter part of condensed name */
int   WINAPI TranslateParameters ( 
    char      **ppin,                     // read-only source
    char      **ppout,                            // translated result
    char      **pps)                                          // parameter stack
{
    int         i, n;
    char        c;
    char        name[128];
    char        *pin, *pout, *ps;           

    //printf(" %c ", **in);
    pin  = *ppin;
    pout = *ppout;
    ps   = *pps;
    c = *pin;
    switch (c)
    {
        // types processing
        case 'b': strcpy (pout, "byte");       pout +=  4; pin++;  break;
        case 'c': strcpy (pout, "char");       pout +=  4; pin++;  break; 
        case 'd': strcpy (pout, "double");     pout +=  6; pin++;  break;
        case 'f': strcpy (pout, "float");      pout +=  5; pin++;  break;
        case 'g': strcpy (pout, "long double");pout += 11; pin++;  break;
        case 'i': strcpy (pout, "int");        pout +=  3; pin++;  break; 
        case 'l': strcpy (pout, "long");       pout +=  4; pin++;  break;
        case 's': strcpy (pout, "short");      pout +=  5; pin++;  break; 
        case 'v': strcpy (pout, "void");       pout +=  4; pin++;  break;
        // postfix processing
        case 'M':
        case 'p': 
            if (*(pin+1) == 'p') { *ps++ = 'p'; pin += 2; }
            else { *ps++ = '*'; pin++; }
            *ppin = pin; *ppout = pout; *pps = ps;
            return 1;
        case 'q':
            *pout++ = '('; pin++;
            *ps++ = 'q';
            *ppin = pin; *ppout = pout; *pps = ps;
            return 1;
        case 'r':
            if (*(pin+1) == 'p') { *ps++ = 'r'; pin += 2; }
            else { *ps++ = '&'; pin++; }
            *ppin = pin; *ppout = pout; *pps = ps;
            return 1;
        // repeat processing
        case 't':
            if (isdigit(*(pin+1)))
            { 
                n = *(pin+1) - '0'; pin++; pin++;
                if (GetPreviousParamString (pout, name))
				{
                    strcpy (pout, name); pout += strlen (name);
                    for (i=1; i<n; i++)
                    {
                        *pout++ = ',';
                        strcpy (pout, name); pout += strlen (name);
                    }
                }
				else return 0;
			}
            else pin++;
            break;
        // prefix processing
        case 'u':
            strcpy (pout, "u");        pout +=  1; pin++;  
            *ppin = pin; *ppout = pout; *pps = ps;
            return 1;
        case 'x':
            strcpy (pout, "const ");   pout +=  6; pin++;  
            *ppin = pin; *ppout = pout; *pps = ps;
            return 1;
        case 'z':
            strcpy (pout, "static ");  pout +=  7; pin++;  
            *ppin = pin; *ppout = pout; *pps = ps;
            return 1;
        default:  strcpy (pout, "!1!");pout +=  3; *pout++=*pin++;
            *ppin = pin; *ppout = pout; *pps = ps;
            return 1;
    }
    // need to process postfix finally
    c = *(ps-1);
    if (strchr ("tqx", c))
    { if (*(pin)&& !strchr( "@$%", *(pin))) *pout++ = ','; 
      *ppin = pin; *ppout = pout; *pps = ps; return 1; }
    switch (c)
    {
        case 'r': strcpy (pout, "*&");  pout += 2;  ps--; break;
        case 'p': strcpy (pout, "**");  pout += 2;  ps--; break;
        case '&': strcpy (pout, "&");   pout += 1;  ps--; break;
        case '*': strcpy (pout, "*");   pout += 1;  ps--; break;
        default:  strcpy (pout, "!2!"); pout += 3;  ps--; break;
    }
    if (*(pin) && !strchr( "@$%", *(pin))) *pout++ = ',';
    *ppin = pin; *ppout = pout; *pps = ps;
	return 1;
}

//
// This function is written by sang cho
//                                                         October 11, 1997
//

/* translate parameter part of condensed name */
BOOL   WINAPI StringExpands ( 
    char      **ppin,                     // read-only source
    char      **ppout,                            // translated result
    char      **pps,                                          // parameter stack
    Str_P      *pcstr)                    // currently stored string
{
    // int         n;
    // char        c;
    char        *pin, *pout, *ps;  
    Str_P       c_str;
    BOOL        stringMode = TRUE;

    pin  = *ppin;
    pout = *ppout;
    ps   = *pps;
    c_str = *pcstr;

         if (strncmp (pin, "bctr", 4) == 0)
    {  strncpy (pout, c_str.pos, c_str.length); 
       pout += c_str.length; pin += 4; }
    else if (strncmp (pin, "bdtr", 4) == 0)
    {  *pout++ = '~'; 
       strncpy (pout, c_str.pos, c_str.length);     
       pout += c_str.length; pin += 4; }
    else if (*pin == 'o')    
    {  strcpy(pout, "const ");             pout +=  6;  pin++;
       stringMode = FALSE;
    }
    else if (*pin == 'q')    
    {  *pout++ = '(';  pin++;
       *ps++ = 'q';    stringMode = FALSE;
    }
    else if (*pin == 't')
    {
       //if (*(ps-1) == 't') { *pout++ = ','; pin++; }       // this also got me...
       //else                                                                                          october 12  .. sang
       {  *pout++ = '<';  pin++;
          *ps++ = 't';        
       }
       stringMode = FALSE;
    }
    else if (strncmp (pin, "xq", 2) == 0)
    {  *pout++ = '('; pin += 2;
       *ps++ = 'x'; *ps++ = 'q';
       stringMode = FALSE;
    }
    else if (strncmp (pin, "bcall", 5) == 0)
    {  strcpy (pout, "operator ()");       pout += 11; pin += 5; }
    else if (strncmp (pin, "bsubs", 5) == 0)
    {  strcpy (pout, "operator []");       pout += 11; pin += 5; }
    else if (strncmp (pin, "bnwa", 4) == 0) 
    {  strcpy (pout, "operator new[]");    pout += 14; pin += 4; }
    else if (strncmp (pin, "bdla", 4) == 0) 
    {  strcpy (pout, "operator delete[]"); pout += 17; pin += 4; }
    else if (strncmp (pin, "bnew", 4) == 0)
    {  strcpy (pout, "operator new");      pout += 12; pin += 4; }
    else if (strncmp (pin, "bdele", 5) == 0)
    {  strcpy (pout, "operator delete");   pout += 15; pin += 5; }
    else if (strncmp (pin, "blsh", 4) == 0)
    {  strcpy (pout, "operator <<");       pout += 11; pin += 4; }
    else if (strncmp (pin, "brsh", 4) == 0)
    {  strcpy (pout, "operator >>");       pout += 11; pin += 4; }
    else if (strncmp (pin, "binc", 4) == 0)
    {  strcpy (pout, "operator ++");       pout += 11; pin += 4; }
    else if (strncmp (pin, "bdec", 4) == 0)
    {  strcpy (pout, "operator --");       pout += 11; pin += 4; }
    else if (strncmp (pin, "badd", 4) == 0)
    {  strcpy (pout, "operator +");        pout += 10; pin += 4; }
    else if (strncmp (pin, "brplu", 5) == 0)
    {  strcpy (pout, "operator +=");       pout += 11; pin += 5; }
    else if (strncmp (pin, "bdiv", 4) == 0)
    {  strcpy (pout, "operator /");        pout += 10; pin += 4; }
    else if (strncmp (pin, "brdiv", 5) == 0)
    {  strcpy (pout, "operator /=");       pout += 11; pin += 5; }
    else if (strncmp (pin, "bmul", 4) == 0)
    {  strcpy (pout, "operator *");        pout += 10; pin += 4; }
    else if (strncmp (pin, "brmul", 5) == 0)
    {  strcpy (pout, "operator *=");       pout += 11; pin += 5; }
    else if (strncmp (pin, "basg", 4) == 0)
    {  strcpy (pout, "operator =");        pout += 10; pin += 4; }
    else if (strncmp (pin, "beql", 4) == 0)
    {  strcpy (pout, "operator ==");       pout += 11; pin += 4; }
    else if (strncmp (pin, "bneq", 4) == 0)
    {  strcpy (pout, "operator !=");       pout += 11; pin += 4; }
    else if (strncmp (pin, "bor", 3) == 0)
    {  strcpy (pout, "operator |");        pout += 10; pin += 3; }
    else if (strncmp (pin, "bror", 4) == 0)
    {  strcpy (pout, "operator |=");       pout += 11; pin += 4; }
    else if (strncmp (pin, "bcmp", 4) == 0)
    {  strcpy (pout, "operator ~");        pout += 10; pin += 4; }
    else if (strncmp (pin, "bnot", 4) == 0)
    {  strcpy (pout, "operator !");        pout += 10; pin += 4; }
    else if (strncmp (pin, "band", 4) == 0)
    {  strcpy (pout, "operator &");        pout += 10; pin += 4; }
    else if (strncmp (pin, "brand", 5) == 0)
    {  strcpy (pout, "operator &=");       pout += 11; pin += 5; }
    else if (strncmp (pin, "bxor", 4) == 0)
    {  strcpy (pout, "operator ^");        pout += 10; pin += 4; }
    else if (strncmp (pin, "brxor", 5) == 0)
    {  strcpy (pout, "operator ^=");       pout += 11; pin += 5; }
    else     
    {  
       strcpy (pout, "!$$$!"); pout += 5; 
    }
    *ppin = pin; *ppout = pout; *pps = ps;
    return stringMode;
}   // end of '$' processing

//----------------------------------------------------------------------
// structure to store string tokens
//----------------------------------------------------------------------
//typedef struct _Str_P {
//    char    flag;               // string_flag '@' or '%' or '#'
//    char    *pos;               // starting postion of string
//    int     length;     // length of string
//    BOOL    wasString;    // if it were stringMode or not
//} Str_P;
//----------------------------------------------------------------------
//
// I think I knocked it down finally. But who knows? 
//                            october 12, 1997 ... sang
//
// well I have to rewrite whole part of TranslateFunctionName..
// this time I am a little bit more experienced than 5 days ago.
// or am i??? anyway i use stacks instead of recurcive calls
// and i hope this will take care of every symptoms i have experienced..
//                                                        october 10, 1997 .... sang
// It took a lot of time for me to figure out what is all about....
// but still some prefixes like z (static) 
//     -- or some types like b (byte) ,g (long double) ,s (short) --
//         -- or postfix  like M ( * )
//     -- or $or ( & ) which is pretty wierd.         .. added.. october 12
//     -- also $t business is quite tricky too. (templates) 
//             there may be a lot of things undiscovered yet....
// I am not so sure my interpretation is correct or not
// If I am wrong please let me know.
//                             october 8, 1997 .... sang
//

//
// This function is written by sang cho
//                                                         October 5, 1997
//

/* translate condesed import function name */
LPVOID WINAPI TranslateFunctionName (
    char      *psz)
{
    
    
    int                                 i, n;
    char                    c, cc;

    static char             buff[512];      // result of translation

    int                     is=0;
    char                    pStack[32]; // parameter processing stack
    Str_P                   sStack[32]; // String processing stack
    Str_P                   tok;        // String token
    Str_P                   c_str;      // current string 

    int                     iend=0;
    char                    *endTab[8];  // end of string position check

    char                   *ps;
    char                           *pin, *pout;
    BOOL                    stringMode=TRUE;

    if (*psz != '@') return psz;
    c = 0;
    pin  = psz;
    pout = buff;
    ps   = pStack;
    
    //................................................................
    // serious users may need to run the following code.
    // so I may need to include some flag options...
    // If you want to know about how translation is done,
    // you can just revive following line and you can see it.
    //                                                 october 6, 1997 ... sang cho
    //printf ("\n................................... %s", psz); // for debugging...
    
    //pa = pb = pout;
    pin++;                                             
    tok.flag = 'A'; tok.pos = pout; tok.length = 0;     tok.wasString = stringMode;
    sStack[is++] = tok;       // initialize sStack with dummy marker
    
    while (*pin)
    {
        while (*pin)
        {
        c = *pin;

            //---------------------------------------------
            // check for the end of number specified string
            //---------------------------------------------
            
            if (iend>0)
            {
                for (i=0;i<iend;i++) if (pin == endTab[i]) break;
                if (i<iend) 
                { 
                    // move the end of endTab to ith position
                    endTab[i] = endTab[iend-1]; iend--;

                    // get top of the string stack
                    tok = sStack[is-1];

                    // I am expecting '#' token from stack
                    if (tok.flag != '#') 

                    { printf("\n**some serious error1** %c is = %d char = %c", 
                      tok.flag, is, *pin); 
                      exit(0);}

                    // pop '#' token  I am happy now.
                    else
                    {       //if (c)
                        //printf("\n pop # token ... current char = %c", c);
                        //else printf("\n pop percent token..next char = NULL");
                        is--;       
                    }

                    stringMode = tok.wasString;

                    if (!stringMode) 
                    {
                        // need to process postfix finally
                        cc = *(ps-1);
                        if (strchr ("qtx", cc))
                        {    if (!strchr ("@$%", c)) *pout++ = ',';
                        }
                        else
                        {
                switch (cc)
                {
        case 'r': strcpy (pout, "*&");  pout += 2;  ps--; break;
        case 'p': strcpy (pout, "**");  pout += 2;  ps--; break;
        case '&': strcpy (pout, "&");   pout += 1;  ps--; break;
        case '*': strcpy (pout, "*");   pout += 1;  ps--; break;
        default:  strcpy (pout, "!3!"); pout += 3;  ps--; break;
                }
                            if (!strchr ("@$%", c)) *pout++ = ',';
                        }
                    }
                    // string mode restored...
                    else;
                }
                else ; // do nothing.. 
            }

            //------------------------------------------------
            // special control symbol processing:
            //------------------------------------------------

            if (strchr ("@$%", c))  break;

            //---------------------------------------------------------------
            // string part processing : no '$' met yet 
            //                       or inside of '%' block
            //                       or inside of '#' block (numbered string)
            //---------------------------------------------------------------

            else if (stringMode)     *pout++ = *pin++;
            //else if (is > 1)         *pout++ = *pin++;

            //------------------------------------------------ 
            // parameter part processing: '$' met
            //------------------------------------------------

            else                 // parameter processing
            {
                if (!isdigit (c)) 
				{
				    if(!TranslateParameters (&pin, &pout, &ps)) return psz;
                }
				else         // number specified string processing
                {
                    n = GetStringLength (pin);
                    if (n<10) pin++; else pin += 2;

                    // push '#' token
                    //if (*pin)
                    //printf("\n push # token .. char = %c", *pin);
                    //else printf("\n push percent token..next char = NULL");
                    tok.flag = '#'; tok.pos = pout; 
                    tok.length = 0; tok.wasString = stringMode;
                    sStack[is++] = tok;

                    // mark end of input string
                    endTab[iend++] = pin + n; 
                    stringMode = TRUE;
                }
            }       
        }   // end of inner while loop
        //
        // beginning of new string or end of string ( quotation mark )
        //
        if (c == '%')
        {
            pin++;               // anyway we have to proceed...
        tok = sStack[is-1];  // get top of the sStack
            if (tok.flag == '%') 
            {                                       
                // pop '%' token and set c_str 
                //if (*pin)
                //printf("\n pop percent token..next char = %c", *pin);
                //else printf("\n pop percent token..next char = NULL");
                is--;
                c_str = tok; c_str.length = pout - c_str.pos; 
                if (*(ps-1) == 't') 
                { 
                    *pout++ = '>'; ps--;  
                    stringMode = tok.wasString;
                }
                else { printf("\n**some string error3** stack = %c", *(ps-1)); 
                exit(0); }
            }
            else if (tok.flag == 'A' || tok.flag == '#')
            {
                // push '%' token
                //if (*pin)
                //printf("\n push percent token..next char = %c", *pin);
                //else printf("\n push percent token..next char = NULL");
                tok.flag = '%'; tok.pos = pout; tok.length = 0;
                tok.wasString = stringMode;
                sStack[is++] = tok;      
            }
            else  { printf("\n**some string error5**"); exit(0); }
        }
        //
        // sometimes we need string to use as constructor name or destructor name
        //
        else if (c == '@') // get string from previous marker  upto here. 
        { 
            pin++;
            tok = sStack[is-1];
            c_str.flag = 'S'; 
            c_str.pos = tok.pos;
            c_str.length = pout - tok.pos;
            c_str.wasString = stringMode;
            *pout++ = ':'; *pout++ = ':';
        }
        //
        // we need to take care of parameter control sequence
        //
        else if (c == '$') // need to precess template or parameter part
        {
            pin++;
            if (stringMode) 
                stringMode = StringExpands (&pin, &pout, &ps, &c_str);
            else
            {       // template parameter mode I guess  "$t"
                if (is>1) 
                {  
                    if (*pin == 't') pin++;
                    else { printf("\nMYGOODNESS1 %c", *pin); exit(0);}
                    //ps--;
                    //if (*ps == 't') *pout++ = '>';
                    //else { printf("\nMYGOODNESS2"); exit(0);}
                    *pout++ = ','; //pin++; ..this almost blowed me....
                }
                // real parameter mode I guess
                // unexpected case is found ... humm what can I do...
                else
                {  
                    // this is newly found twist.. it really hurts.
                    if (ps <= pStack)
                    {  if (*pin == 'q') { *ps++ = 'q'; *pout++ = '('; pin++; }
                       else {printf("\n** I GIVEUP ***"); exit(0);}
                       continue;
                    }
                    ps--;
                    while (*ps != 'q') 
                    {       if (*ps == '*') *pout++ = '*';
                       else if (*ps == '&') *pout++ = '&';
                       else if (*ps == 'p'){*pout++ = '*'; *pout++ = '*'; }
                       else if (*ps == 'r'){*pout++ = '*'; *pout++ = '&'; }
                       else {printf("\n*** SOMETHING IS WRONG1*** char= %c",*pin); 
                       exit(0);}
                       ps--;
                    }
                *pout++ = ')'; 
                    ps--;
                    while (*ps != 'q') 
                    {       if (*ps == '*') *pout++ = '*';
                       else if (*ps == '&') *pout++ = '&';
                       else if (*ps == 'p'){*pout++ = '*'; *pout++ = '*'; }
                       else if (*ps == 'r'){*pout++ = '*'; *pout++ = '&'; }
                       else {printf("\n*** SOMETHING IS WRONG2***"); exit(0);}
                       ps--;
                    }
                ps++; *pout++ = ',';
                }
            }
        }   // end of '$' processing
    }       // end of outer while loop
    //
    // need to process remaining parameter stack
    //
    while (ps>pStack)
    {
        ps--;
        switch(*ps)
        {
            case 't': *pout++ = '>';                      break;
        case 'q': *pout++ = ')';                      break;
        case 'x': strcpy (pout, " const"); pout += 6; break;
        case 'r': strcpy (pout, "*&");     pout += 2; break;
            case 'p': strcpy (pout, "**");     pout += 2; break;
            case '&': *pout++ = '&';                      break;
            case '*': *pout++ = '*';                      break;
            default:  strcpy (pout, "!4!");    pout += 3; *pout++ = *ps;
        }
    }
    *pout = 0;
    return buff;
}

//
// This function is written by sang cho
//
//

/* get exported function names separated by null terminators, return count of functions */
int  WINAPI GetExportFunctionNames (
    LPVOID    lpFile,
    char      **pszFunctions)
{
    //PIMAGE_SECTION_HEADER      psh;
    PIMAGE_EXPORT_DIRECTORY    ped;
    //DWORD                      dwBase;
    DWORD                      imageBase;                 //===========================
    char                          *pfns[40960]={NULL,}; // maximum number of functions
                                                    //=============================  
    char                       buff[256];        // enough for any string ??
    char                      *psz = NULL;            //===============================
    DWORD                     *pdwAddress;
    DWORD                     *pdw1;
    DWORD                     *pdwNames;
    WORD                      *pwOrd;
    int                                i, nCnt=0, ntmp=0;
    int                        enid=0, ordBase=1; // usally ordBase is 1....
    int                        enames=0;

    /* get section header and pointer to data directory for .edata section */
    ped = (PIMAGE_EXPORT_DIRECTORY)
    ImageDirectoryOffset(lpFile, IMAGE_DIRECTORY_ENTRY_EXPORT);

    if (ped == NULL) return 0;

    //
    // sometimes there may be no section for idata or edata
    // instead rdata or data section may contain these sections ..
    // or even module names or function names are in different section.
    // so that's why we need to get actual address each time.
    //         ...................sang cho..................
    //
    //psh = (PIMAGE_SECTION_HEADER)
    //ImageDirectorySection(lpFile, IMAGE_DIRECTORY_ENTRY_EXPORT);

    //if (psh == NULL) return 0;

    //dwBase = (DWORD)((int)lpFile + psh->PointerToRawData - psh->VirtualAddress);


    /* determine the offset of the export function names */

    pdwAddress = (DWORD *)GetActualAddress (lpFile, (DWORD)ped->AddressOfFunctions);

    imageBase = (DWORD)GetImageBase (lpFile);
    
    ordBase = ped->Base;

    if (ped->NumberOfNames > 0)
    {
    pdwNames = (DWORD *)
               GetActualAddress (lpFile, (DWORD)ped->AddressOfNames);
        pwOrd = (WORD *)
            GetActualAddress (lpFile, (DWORD)ped->AddressOfNameOrdinals);
        pdw1 = pdwAddress;

    /* figure out how much memory to allocate for all strings */
        for (i=0; i < (int)ped->NumberOfNames; i++)
        {
            nCnt += strlen ((char *)
                    GetActualAddress (lpFile, *(DWORD *)pdwNames)) + 1 + 6;
            pdwNames++;
        }
        // get the number of unnamed functions
        for (i=0; i < (int)ped->NumberOfFunctions; i++)
            if (*pdw1++) ntmp++;
        // add memory required to show unnamed functions.
        if (ntmp > (int)ped->NumberOfNames)
            nCnt += 18*(ntmp - (int)ped->NumberOfNames);

    /* allocate memory  for function names */
        
        *pszFunctions = (char *)calloc (nCnt, 1);
        peNameBuffSize=nCnt;
        pdwNames = (DWORD *)GetActualAddress (lpFile, (DWORD)ped->AddressOfNames);

    /* copy string pointer to buffer */
        
        for (i=0; i < (int)ped->NumberOfNames; i++)
        {
            pfns[(int)(*pwOrd)+ordBase] = 
            (char *)GetActualAddress (lpFile, *(DWORD *)pdwNames);
            pdwNames++;
            pwOrd++;
        }

        psz = *pszFunctions;
    }       
    if (nCnt==0)
    {
    // get the number of unnamed functions
         nCnt += 18*(int)ped->NumberOfFunctions;
    /* allocate memory  for function names */
        *pszFunctions = (char *)calloc (nCnt, 1);
         peNameBuffSize=nCnt;
         psz=*pszFunctions;
    }
    for (i=ordBase; i < (int)ped->NumberOfFunctions + ordBase; i++)
    {
        if (*pdwAddress > 0)
        {
            *(DWORD *)psz = imageBase + *pdwAddress;
        psz += 4;
        *(WORD *)psz = (WORD)(i);
        psz += 2;
        if (pfns[i])
            {
                strcpy (psz, pfns[i]);
                psz += strlen(psz) + 1;
            }
        else
            {
                sprintf (buff, "ExpFn%04d()", enid++);
                strcpy (psz, buff);
                psz += 12;
            }
            enames++;
        }
        pdwAddress++;
    }
    return enames;
}


/* determine the total number of resources in the section */
int     WINAPI GetNumberOfResources (
    LPVOID    lpFile)
{
    PIMAGE_RESOURCE_DIRECTORY          prdRoot, prdType;
    PIMAGE_RESOURCE_DIRECTORY_ENTRY    prde;
    int                                nCnt=0, i;


    /* get root directory of resource tree */
    if ((prdRoot = (PIMAGE_RESOURCE_DIRECTORY)ImageDirectoryOffset
            (lpFile, IMAGE_DIRECTORY_ENTRY_RESOURCE)) == NULL)
    return 0;

    /* set pointer to first resource type entry */
    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)((DWORD)prdRoot + sizeof (IMAGE_RESOURCE_DIRECTORY));

    /* loop through all resource directory entry types */
    for (i=0; i<prdRoot->NumberOfIdEntries; i++)
    {
    /* locate directory or each resource type */
    prdType = (PIMAGE_RESOURCE_DIRECTORY)((int)prdRoot + (int)prde->OffsetToData);

    /* mask off most significant bit of the data offset */
    prdType = (PIMAGE_RESOURCE_DIRECTORY)((DWORD)prdType ^ 0x80000000);

    /* increment count of name'd and ID'd resources in directory */
    nCnt += prdType->NumberOfNamedEntries + prdType->NumberOfIdEntries;

    /* increment to next entry */
    prde++;
    }

    return nCnt;
}

//
// This function is rewritten by sang cho
//
//

/* name each type of resource in the section */
int     WINAPI GetListOfResourceTypes (
    LPVOID    lpFile,
    char      **pszResTypes)
{
    PIMAGE_RESOURCE_DIRECTORY          prdRoot;
    PIMAGE_RESOURCE_DIRECTORY_ENTRY    prde;
	PBYTE                              pMem;
	PWORD                              pw;
    char                    buff[32];
    int                                nCnt, i, j, n;
    DWORD                  prdeName;


    /* get root directory of resource tree */
    if ((prdRoot = (PIMAGE_RESOURCE_DIRECTORY)ImageDirectoryOffset
            (lpFile, IMAGE_DIRECTORY_ENTRY_RESOURCE)) == NULL)
    return 0;

    /* allocate enuff space  to cover all types */
    nCnt = prdRoot->NumberOfNamedEntries * 256 + prdRoot->NumberOfIdEntries * (32);
    *pszResTypes = (char *)calloc (nCnt, 1);
    if ((pMem = *pszResTypes) == NULL)
    return 0;

    /* set pointer to first resource type entry */
    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)((DWORD)prdRoot + sizeof (IMAGE_RESOURCE_DIRECTORY));

	/* loop through all resource directory entry types */
	for (i=0; i<prdRoot->NumberOfNamedEntries; i++)
    {
		pw = (PWORD)((DWORD)prdRoot + (prde->Name ^ 0x80000000));

        if (!isalpha(*(PBYTE)pw))
		{
		    n=(int)(*(PBYTE)pw++); 
			for(j=0;j<n;j++)*pMem++ = *(PBYTE)pw++; 
			*pMem=0; pMem++;    
		}
		else
		{
			while(*pw) *pMem++ = *(PBYTE)pw++; 
			*pMem=0; pMem++;
		}
        prde++;
    }

    /* loop through all resource directory entry types */
    for (i=0; i<prdRoot->NumberOfIdEntries; i++)
    {
        prdeName=prde->Name;

    //if (LoadString (hDll, prde->Name, pMem, MAXRESOURCENAME))
    //    pMem += strlen (pMem) + 1;
    //
    // modified by ...................................Sang Cho..
    // I can't user M/S provied funcitons here so I have to figure out
    // how to do above functions. But I can settle down with the following
    // code, which works pretty good for me.
    //
        if      (prdeName== 1){strcpy(pMem, "RT_CURSOR");       pMem+=10;}
        else if (prdeName== 2){strcpy(pMem, "RT_BITMAP");       pMem+=10;}
        else if (prdeName== 3){strcpy(pMem, "RT_ICON  ");       pMem+=10;}
        else if (prdeName== 4){strcpy(pMem, "RT_MENU  ");       pMem+=10;}
        else if (prdeName== 5){strcpy(pMem, "RT_DIALOG");       pMem+=10;}
        else if (prdeName== 6){strcpy(pMem, "RT_STRING");       pMem+=10;}
        else if (prdeName== 7){strcpy(pMem, "RT_FONTDIR");      pMem+=11;}
        else if (prdeName== 8){strcpy(pMem, "RT_FONT  ");       pMem+=10;}
        else if (prdeName== 9){strcpy(pMem, "RT_ACCELERATORS"); pMem+=16;}
        else if (prdeName==10){strcpy(pMem, "RT_RCDATA");       pMem+=10;}
        else if (prdeName==11){strcpy(pMem, "RT_MESSAGETABLE"); pMem+=16;}
        else if (prdeName==12){strcpy(pMem, "RT_GROUP_CURSOR"); pMem+=16;}
        else if (prdeName==14){strcpy(pMem, "RT_GROUP_ICON  "); pMem+=16;}
        else if (prdeName==16){strcpy(pMem, "RT_VERSION");      pMem+=11;}
        else if (prdeName==17){strcpy(pMem, "RT_DLGINCLUDE  "); pMem+=16;}
        else if (prdeName==19){strcpy(pMem, "RT_PLUGPLAY    "); pMem+=16;}
        else if (prdeName==20){strcpy(pMem, "RT_VXD   ");       pMem+=10;}
        else if (prdeName==21){strcpy(pMem, "RT_ANICURSOR   "); pMem+=16;}
        else if (prdeName==22){strcpy(pMem, "RT_ANIICON");      pMem+=11;}
        else if (prdeName== 0x2002)
                {strcpy(pMem, "RT_NEWBITMAP");    pMem+=13;}
        else if (prdeName== 0x2004)
                {strcpy(pMem, "RT_NEWMENU");      pMem+=11;}
        else if (prdeName== 0x2005)
                {strcpy(pMem, "RT_NEWDIALOG");    pMem+=13;}
        else if (prdeName== 0x7fff)
                {strcpy(pMem, "RT_ERROR ");       pMem+=10;}
        else    {sprintf(buff, "RT_UNKNOWN:%08X", (int)prdeName);
                 strcpy(pMem, buff);              pMem+=20;}
        prde++;
    }

    return prdRoot->NumberOfNamedEntries+prdRoot->NumberOfIdEntries;
}

//
// This function is written by sang cho
//                                                         October 12, 1997
//

/* copy menu information */
void  WINAPI StrangeMenuFill (
    char      **psz,              // results
    WORD      **pMenu,            // read-only
    int         size)
{
    WORD      *pwd;
    WORD      *ptr, *pmax;

    pwd = *pMenu;
    pmax = (WORD *)((DWORD)pwd + size);
    ptr = (WORD *)(*psz);
    
    while (pwd < pmax)
    {
        *ptr++=*pwd++;
    }
    *psz = (char *)ptr;
    *pMenu = pwd;
}

//
// This function is written by sang cho
//                                                         October 1, 1997
//

/* obtain menu information */
int     WINAPI MenuScan (
    int        *len,
    WORD      **pMenu)
{
    WORD      *pwd;
    WORD       flag, flag1;
    WORD       id, ispopup;

    pwd = *pMenu;
    
    flag = *pwd;  // so difficult to correctly code this so let's try this
    pwd++;
    (*len) += 2;                      // flag store
    if ((flag & 0x0010) == 0)
    {
        ispopup = flag;
        id = *pwd;
        pwd++;
        (*len) += 2;                  // id store
		
		while (*pwd) {(*len)++; pwd++;}
        (*len)++;                             // name and null character
        pwd++;                               // skip double null
        
		*pMenu = pwd;
        return (int)flag;
	}
    else 
    {
        ispopup = flag;

        while (*pwd) {(*len)++; pwd++;}
        (*len)++;                             // name and null character
        pwd++;                               // skip double null
                       // popup node: need to go on...
        while (1)
        {       
            *pMenu = pwd;
            flag1 = (WORD)MenuScan (len, pMenu);
            pwd = *pMenu;
            if (flag1 & 0x0080) break; 
        }
        *pMenu = pwd;
        return flag;
    }
}

//
// This function is written by sang cho
//                                                         October 2, 1997

/* copy menu information */
int     WINAPI MenuFill (
    char      **psz,
    WORD      **pMenu)
{
    char      *ptr;
    WORD      *pwd;
    WORD       flag, flag1;
    WORD       id;

    ptr = *psz;
    pwd = *pMenu;
   
    flag = *pwd;  // so difficult to correctly code this so let's try this
    pwd++;  
	if ((flag & 0x0010) == 0)
    {
        *(WORD *)ptr = flag;             // flag store
        ptr += 2;
        *(WORD *)ptr = id = *pwd;          // id store
        ptr += 2;
        pwd++;

		while (*pwd)                                             // name extract
        {
            *ptr = *(char *)pwd;
			if(!isprint(*ptr)) *ptr='.';
            ptr++; pwd++;
        } //name and null character
        *ptr=0;
        ptr++;
        pwd++;   		                // skip double null
		
		*pMenu = pwd;
        *psz = ptr;
        return (int)flag;
    }
    else 
    {
        *(WORD *)ptr = flag;             // flag store
        ptr += 2;
   
        while (*pwd)                     // name extract
        {
            *ptr = *(char *)pwd;
			if(!isprint(*ptr)) *ptr='.';
            ptr++; pwd++;
        } //name and null character
        *ptr=0;
        ptr++;
        pwd++;                          // skip double null
   
                     // popup node: need to go on...
        while (1)
        {       
            //num++;
            *pMenu = pwd;
            *psz = ptr;
            flag1 = (WORD)MenuFill (psz, pMenu);
            pwd = *pMenu;
            ptr = *psz;
            if (flag1 & 0x0080) break; 
        }
    
        *pMenu = pwd;
        *psz = ptr;
        return flag;
	}
}


//
//==============================================================================
// The following program is based on preorder-tree-traversal.
// once you understand how to traverse..... 
// the rest is pretty straight forward.
// still we need to scan it first and fill it next time.
// and finally we can print it.
//
// This function is written by sang cho
//                                                         September 29, 1997
//                                                         revised october 2, 1997
//                             revised october 12, 1997
// ..............................................................................
// ------------------------------------------------------------------------------
// I use same structure - which is used in P.E. programs - for my reporting.
// So, my structure is as follows:
//        # of menu name is stored else where ( in directory I suppose )
//     supermenuname                    null terminated string, only ascii is considered.
//         flag                 tells : node is a leaf or a internal node.
//         popupname                    null terminated string
//              
//              flag                normal menu flag (leaf node)
//                      id                                  normal menu id
//              name                    normal menu name
//         or                            or
//              flag                        popup menu flag (internal node)
//              popupname                   popup menu name 
//             
//                 flag                             it may folows
//                         id                                   normal menu id
//                 name                                 normal menu name
//             or                                 or
//                 flag                                 popup menu
//                 popupname                    popup menu name
//                                 .........
//                                it goes on like this,
//                                 but usually, it only goes a few steps,...
// ------------------------------------------------------------------------------

/* scan menu and copy menu */
int     WINAPI GetContentsOfMenu (
    LPVOID    lpFile,
    char      **pszResTypes)
{
    PIMAGE_RESOURCE_DIRECTORY          prdType, prdName, prdLanguage;
    PIMAGE_RESOURCE_DIRECTORY_ENTRY    prde, prde1;
    PIMAGE_RESOURCE_DIR_STRING_U       pMenuName;
    PIMAGE_RESOURCE_DATA_ENTRY         prData;
    PIMAGE_MENU_HEADER                 pMenuHeader;
    PIMAGE_POPUP_MENU_ITEM             pPopup;
    char                    buff[256];
    int                     i,j; 
    int                     size;
    int                     sLength, nMenus;
    WORD                    flag;
    WORD                   *pwd;
    char                   *pMem;


    /* get root directory of resource tree */
    if ((prdType = (PIMAGE_RESOURCE_DIRECTORY)ImageDirectoryOffset
            (lpFile, IMAGE_DIRECTORY_ENTRY_RESOURCE)) == NULL)
    return 0;

    /* set pointer to first resource type entry */
    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdType + sizeof (IMAGE_RESOURCE_DIRECTORY) 
		   + prdType->NumberOfNamedEntries*8);
 
    for (i=0; i<prdType->NumberOfIdEntries; i++)
    {
    if (prde->Name == RT_MENU) break;
    prde++;
    }
    if (prde->Name != RT_MENU) return 0; 

    prdName = (PIMAGE_RESOURCE_DIRECTORY)
          ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000) ); 
    if (prdName == NULL) return 0;

    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdName + sizeof (IMAGE_RESOURCE_DIRECTORY));

    // sometimes previous code tells you lots of things hidden underneath
    // I wish I could save all the revisions I made ... but again .... sigh.
    //                                  october 12, 1997    sang
    //dwBase = (DWORD)((int)lpFile + psh->PointerToRawData - psh->VirtualAddress);

    nMenus=prdName->NumberOfNamedEntries + prdName->NumberOfIdEntries;
    sLength=0;
    
    for (i=0; i<prdName->NumberOfNamedEntries; i++)
    {
        pMenuName = (PIMAGE_RESOURCE_DIR_STRING_U) 
            ((DWORD)prdType + (prde->Name ^ 0x80000000));
        sLength += pMenuName->Length + 1;
        
        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        pMenuHeader =  (PIMAGE_MENU_HEADER)
                   GetActualAddress (lpFile, prData->OffsetToData);
        
        //
        // normally wVersion and cbHeaderSize should be zero
        // but if it is not then nothing is known to us...
        // so let's do our best ... namely guessing .... and trying ....
        //                      ... and suffering   ... 
        // it gave me many sleepless (not exactly but I like to say this) nights.
        //

        // strange case
        if (pMenuHeader->wVersion | pMenuHeader->cbHeaderSize)
        {
            //isStrange = TRUE;
            pwd = (WORD *)((DWORD)pMenuHeader + 16);
            size = prData->Size;
            // expect to return the length needed to report.
            // sixteen more bytes to do something
            sLength += 16+size;
            //StrangeMenuScan (&sLength, &pwd, size);   
        }
        // normal case
        else
        {
            pPopup = (PIMAGE_POPUP_MENU_ITEM)
                 ((DWORD)pMenuHeader + sizeof (IMAGE_MENU_HEADER));
            while (1)
            {       
                flag = (WORD)MenuScan (&sLength, (WORD **)(&pPopup) );
                if (flag & 0x0080) break;
            }
        }
        prde++;
    }
    for (i=0; i<prdName->NumberOfIdEntries; i++)
    {
        sLength += 12;
        
        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        pMenuHeader =  (PIMAGE_MENU_HEADER)
                   GetActualAddress (lpFile, prData->OffsetToData);
        // strange case
        if (pMenuHeader->wVersion | pMenuHeader->cbHeaderSize)
        {
            pwd = (WORD *)((DWORD)pMenuHeader + 16);
            size = prData->Size;
            // expect to return the length needed to report.
            // sixteen more bytes to do something
            sLength += 16+size;
            //StrangeMenuScan (&sLength, &pwd, size);
        }
        // normal case
        else
        {
            pPopup = (PIMAGE_POPUP_MENU_ITEM)
                 ((DWORD)pMenuHeader + sizeof (IMAGE_MENU_HEADER));
            while (1)
            {       
                flag = (WORD)MenuScan (&sLength, (WORD **)(&pPopup) );
                if (flag & 0x0080) break; 
            }
        }
        prde++;
    }
    //
    // allocate memory for menu names
    //
    *pszResTypes = (char *)calloc (sLength, 1);

    pMem = *pszResTypes;
    //
    // and start all over again
    //
    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdName + sizeof (IMAGE_RESOURCE_DIRECTORY));

    for (i=0; i<prdName->NumberOfNamedEntries; i++)
    {
        pMenuName = (PIMAGE_RESOURCE_DIR_STRING_U) 
            ((DWORD)prdType + (prde->Name ^ 0x80000000));
        
        
        for (j=0; j<pMenuName->Length; j++)
            *pMem++ = (char)(pMenuName->NameString[j]);
        *pMem = 0;
        pMem++;
        

        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        pMenuHeader =  (PIMAGE_MENU_HEADER)
                   GetActualAddress (lpFile, prData->OffsetToData);
        // strange case
        if (pMenuHeader->wVersion | pMenuHeader->cbHeaderSize)
        {
            pwd = (WORD *)((DWORD)pMenuHeader);
            size = prData->Size;
            strcpy (pMem, ":::::::::::"); pMem +=12;
            *(int *)pMem = size;          pMem += 4;
            StrangeMenuFill (&pMem, &pwd, size);
        }
        // normal case
        else
        {
            pPopup = (PIMAGE_POPUP_MENU_ITEM)
                 ((DWORD)pMenuHeader + sizeof (IMAGE_MENU_HEADER));
            while (1)
        {       
            flag = (WORD)MenuFill (&pMem, (WORD **)(&pPopup) );
        if (flag & 0x0080) break; 
        }
        }
    prde++;
    }
    for (i=0; i<prdName->NumberOfIdEntries; i++)
    {
        
        sprintf (buff, "MenuId_%04X", (int)(prde->Name));
        strcpy (pMem, buff);
        pMem += strlen (buff) + 1;

        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        pMenuHeader =  (PIMAGE_MENU_HEADER)
                   GetActualAddress (lpFile, prData->OffsetToData);
        // strange case
        if (pMenuHeader->wVersion | pMenuHeader->cbHeaderSize)
        {
            pwd = (WORD *)((DWORD)pMenuHeader);
            size = prData->Size;
            strcpy (pMem, ":::::::::::"); pMem +=12;
            *(int *)pMem = size;          pMem += 4;
            StrangeMenuFill (&pMem, &pwd, size);
        }
        // normal case
        else
        {
            pPopup = (PIMAGE_POPUP_MENU_ITEM)
                 ((DWORD)pMenuHeader + sizeof (IMAGE_MENU_HEADER));
            while (1)
            {
                flag = (WORD)MenuFill (&pMem, (WORD **)(&pPopup) );
                if (flag & 0x0080) break; 
            }
        }
        prde++;
    }

    return nMenus;
}


//
// This function is written by sang cho
//                                                         October 12, 1997

/* print contents of menu */
int     WINAPI PrintStrangeMenu (
    char      **psz)
{
    
    //int                     i, j, l;
    int                     num;
    //WORD                    flag1, flag2;
    //char                    buff[128];
    char                   *ptr, *pmax;

    //return dumpMenu (psz, size);

    ptr  = *psz;

    if(strncmp (ptr, ":::::::::::", 11) != 0) 
    {
        printf ("\n#### I don't know why!!!");
        dumpMenu (psz, 1024);
        exit (0);
    }

    ptr += 12;
    num = *(int *)ptr;
    ptr += 4;
    pmax = ptr+num;

    *psz = ptr;
    return dumpMenu (psz, num);

    // I will write some code later...

}


//
// This function is written by sang cho
//                                                         October 2, 1997

/* print contents of menu */
int     WINAPI PrintMenu1 (
    int         indent,
    char      **psz)
{
    
    int                     j, k, l;
    WORD                    id; //, num;
    WORD                    flag, flag1;
    char                    buff[128];
    char                   *ptr;

	ptr = *psz;
	flag = *(WORD *)ptr;
	ptr += 2;
	if ((flag&0x0010)==0x0000)
	{
	    printf ("\n");
        for (j=0; j<indent; j++) printf (" ");
        id = *(WORD *)ptr;
        ptr += 2;
        strcpy (buff, ptr);
        l = strlen (ptr);
        ptr += l+1;
        if (strchr (buff, 0x09) != NULL)
        {
            for (k=0; k<l; k++) if (buff[k] == 0x09) break;
            for (j=0; j<l-k; j++) buff[31-j]=buff[l-j];
            for (j=k; j<32+k-l; j++) buff[j]=32;
        }
        if (strchr (buff, 0x08) != NULL)
        {
            for (k=0; k<l; k++) if (buff[k] == 0x08) break;
            for (j=0; j<l-k; j++) buff[31-j]=buff[l-j];
            for (j=k; j<32+k-l; j++) buff[j]=32;
        }
		printf ("%s", buff);
        l = strlen (buff);
        for (j=l; j<32; j++) printf(" ");
        printf ("[ID=%04Xh]", id);
        *psz = ptr;
		return (int)flag;
	}
	else
	{
	    printf ("\n");
		printf ("%s  {Popup}",ptr);
		ptr += strlen (ptr) + 1;
        *psz = ptr;
	
		while (1)
        {       
            *psz = ptr;
			flag1=(WORD)PrintMenu1 (indent+5, psz);
            ptr = *psz;
            if (flag1 & 0x0080) break; 
        }
	    *psz = ptr;
        return (int)flag;
	}
}

//
// This function is written by sang cho
//                                                         September 4, 1998

/* print contents of menu */
int     WINAPI PrintMenu (
    int         indent,
    char      **psz)
{
    WORD                    flag;
	
	while (1)
    {       
	    flag=(WORD)PrintMenu1 (indent, psz);
		if (flag & 0x0080) break; 
    }
    return (int)flag;
}


//
// This function is written by sang cho
//                                                         October 2, 1997

/* the format of menu is not known so I'll do my best */
int     WINAPI dumpMenu (
    char      **psz,
    int         size)
{
    
    int                                 i, j, k, n, l,c;
    char                    buff[32];
    char                           *ptr, *pmax;

    ptr  = *psz;
    pmax = ptr+size;
    for (i=0; i<(size/16)+1; i++)
    {
        n = 0;
        for (j=0; j<16; j++)
        {
            c = (int)(*ptr);
            if (c<0) c+=256;
            buff[j] = c;
            printf ("%02X",c);
            ptr++; 
            if (ptr >= pmax) break;
            n++;
            if (n%4 == 0) printf (" "); 
        }
        n++; if (n%4 == 0) printf (" ");
        l = j;
        j++;
        for (; j<16; j++) 
        { n++; if (n%4 == 0) printf ("   "); else printf ("  "); }
        printf ("   ");
        for (k=0; k<l; k++)
            if (isprint(c=buff[k])) printf("%c", c); else printf(".");
        printf ("\n");
        if (ptr >= pmax) break;
    }

    *psz = ptr;
	return 1;
}

//
// This function is written by sang cho
//                                                         October 13, 1997

/* scan dialog box and copy dialog box */
int     WINAPI GetContentsOfDialog (
    LPVOID    lpFile,
    char      **pszResTypes)
{
    PIMAGE_RESOURCE_DIRECTORY          prdType, prdName, prdLanguage;
    PIMAGE_RESOURCE_DIRECTORY_ENTRY    prde, prde1;
    PIMAGE_RESOURCE_DIR_STRING_U       pDialogName;
    PIMAGE_RESOURCE_DATA_ENTRY         prData;
    PIMAGE_DIALOG_HEADER               pDialogHeader;
    char                    buff[32];
    int                     i,j; 
    int                     size;
    int                     sLength, nDialogs;
    //WORD                    flag;
    WORD                   *pwd;
    char                   *pMem; 


    /* get root directory of resource tree */
    if ((prdType = (PIMAGE_RESOURCE_DIRECTORY)ImageDirectoryOffset
            (lpFile, IMAGE_DIRECTORY_ENTRY_RESOURCE)) == NULL)
    return 0;

    /* set pointer to first resource type entry */
    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdType + sizeof (IMAGE_RESOURCE_DIRECTORY)
		   + prdType->NumberOfNamedEntries*8);
 
    for (i=0; i<prdType->NumberOfIdEntries; i++)
    {
    if (prde->Name == RT_DIALOG) break;
    prde++;
    }
    if (prde->Name != RT_DIALOG) return 0; 

    prdName = (PIMAGE_RESOURCE_DIRECTORY)
          ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000) ); 
    if (prdName == NULL) return 0;

    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdName + sizeof (IMAGE_RESOURCE_DIRECTORY));


    nDialogs=prdName->NumberOfNamedEntries + prdName->NumberOfIdEntries;
    sLength=0;
    
    for (i=0; i<prdName->NumberOfNamedEntries; i++)
    {
        pDialogName = (PIMAGE_RESOURCE_DIR_STRING_U) 
              ((DWORD)prdType + (prde->Name ^ 0x80000000));
        sLength += pDialogName->Length + 1;
        
        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        size = prData->Size; 
        sLength += 4+size;       
        prde++;
    }
    for (i=0; i<prdName->NumberOfIdEntries; i++)
    {
        sLength += 14;
        
        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        size = prData->Size; 
        sLength += 4+size;       
        prde++;
    }
    //
    // allocate memory for menu names
    //
    *pszResTypes = (char *)calloc (sLength, 1);

    pMem = *pszResTypes;
    //
    // and start all over again
    //
    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdName + sizeof (IMAGE_RESOURCE_DIRECTORY));

    for (i=0; i<prdName->NumberOfNamedEntries; i++)
    {
        pDialogName = (PIMAGE_RESOURCE_DIR_STRING_U) 
              ((DWORD)prdType + (prde->Name ^ 0x80000000));
        
        
        for (j=0; j<pDialogName->Length; j++)
            *pMem++ = (char)(pDialogName->NameString[j]);
        *pMem = 0;
        pMem++;
        

        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        pDialogHeader =  (PIMAGE_DIALOG_HEADER)
                 GetActualAddress (lpFile, prData->OffsetToData);
     
        
        
        pwd = (WORD *)((DWORD)pDialogHeader);
        size = prData->Size;
        *(int *)pMem = size;          pMem += 4;
        StrangeMenuFill (&pMem, &pwd, size);
        
    prde++;
    }
    for (i=0; i<prdName->NumberOfIdEntries; i++)
    {
        
        sprintf (buff, "DialogId_%04X", (int)(prde->Name));
        strcpy (pMem, buff);
        pMem += strlen (buff) + 1;

        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) 
        {   printf ("\nprdLanguage = NULL"); exit (0); }
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) 
        {   printf ("\nprData = NULL"); exit (0); }

        pDialogHeader =  (PIMAGE_DIALOG_HEADER)
                 GetActualAddress (lpFile, prData->OffsetToData);
        
        
        pwd = (WORD *)((DWORD)pDialogHeader);
        size = prData->Size;
        *(int *)pMem = size;          pMem += 4;
        StrangeMenuFill (&pMem, &pwd, size);
        
        prde++;
    }

    return nDialogs;
}

//
// This function is written by sang cho
//                                                         October 14, 1997

/* print contents of dialog */
int     WINAPI PrintNameOrOrdinal (
    char      **psz)
{    
    char                           *ptr;

    ptr = *psz;
    if (*(WORD *)ptr == 0xFFFF) 
    {       ptr += 2; 
        printf ("%04X", *(WORD *)ptr);
        ptr += 2;
    }
    else 
    { 
        printf ("%c", '"');
        while (*(WORD *)ptr) 
		{ if(isprint(*ptr))printf("%c", *ptr); else printf("."); ptr+= 2; } 
        ptr += 2;
        printf ("%c", '"');
    }
    *psz = ptr;
	return 1;
}

//
// This function is written by sang cho
//                                                         October 14, 1997

/* print contents of dialog */
int     WINAPI PrintDialog (
    char      **psz)
{    
    int                     i; 
    int                     num, size;
    DWORD                   flag;
    WORD                    class;
    char                    *ptr, *pmax;
    BOOL                    isStrange=FALSE;

    ptr  = *psz;
    size = *(int *)ptr;
    ptr += 4;
    pmax = ptr+size;
    
    // IStype of Dialog Header
    flag = *(DWORD *)ptr;
    //
    // check if flag is right or not
    // it has been observed that some dialog information is strange
    // and extra work is needed to fix that ... so let's try something
    //
    
    if ((flag & 0xFFFF0000) == 0xFFFF0000)
    {
        flag = *(DWORD *)(ptr+12);  
        num = *(short *)(ptr+16); 
        isStrange = TRUE;
        ptr += 26;
    }
    else 
    {
        num  = *(short *)(ptr+8);
        ptr += 18;
    }
    printf (", # of Controls=%03d, Caption:%c", num, '"');
    
    // Menu name
         if (*(WORD *)ptr == 0xFFFF) ptr += 4;                // ordinal
    else { while (*(WORD *)ptr) ptr += 2; ptr += 2; } // name
    
    // Class name
         if (*(WORD *)ptr == 0xFFFF) ptr += 4;                // ordinal
    else { while (*(WORD *)ptr) ptr += 2; ptr += 2; } // name

    // Caption
    while (*(WORD *)ptr) { printf("%c", *ptr); ptr+= 2; }
    ptr += 2;
    printf ("%c", '"');
    
    // FONT present
    if (flag & 0x00000040)
    {
        if (isStrange) ptr += 6; else ptr += 2;      // FONT size
        while (*(WORD *)ptr)  ptr += 2;                          // WCHARs
        ptr += 2;                                    // double null  
    }

    // strange case adjust
    if (isStrange) ptr += 8;

    // DWORD padding
    if ((ptr-*psz) % 4) ptr += 4 - ((ptr-*psz) % 4);

    // start reporting .. finally
    for (i=0; i<num; i++)
    {
        flag = *(DWORD *)ptr;
        if (isStrange) ptr += 14; else ptr += 16;
        printf ("\n     Control::%03d - ID:", i+1);
        
        // Control ID
        printf ("%04X, Class:", *(WORD *)ptr);
        ptr += 2;
       
        // Control Class
        if (*(WORD *)ptr == 0xFFFF) 
        {   
            ptr += 2;  class = *(WORD *)ptr;   ptr += 2;
            switch (class)
            {
                case 0x80: printf ("BUTTON   ");        break;       
                case 0x81: printf ("EDIT     ");        break;    
                case 0x82: printf ("STATIC   ");        break;    
                case 0x83: printf ("LISTBOX  ");        break;    
                case 0x84: printf ("SCROLLBAR");        break;    
                case 0x85: printf ("COMBOBOX ");        break;    
                default:   printf ("%04X     ", class); break;
            }
        }
        else PrintNameOrOrdinal (&ptr);

        printf (" Text:");

        // Text
        PrintNameOrOrdinal (&ptr);

        // nExtraStuff
        ptr += 2;
        
        // strange case adjust
        if (isStrange) ptr += 8;

        // DWORD padding
        if ((ptr-*psz) % 4) ptr += 4 - ((ptr-*psz) % 4);
    }

    *psz = pmax;
	return 1;
}
 
//
// This function is written by sang cho
//                                                         September 5, 1998

/* scan string and copy string */
int     WINAPI GetContentsOfString (
    LPVOID    lpFile,
    char      **pszResTypes)
{
    PIMAGE_RESOURCE_DIRECTORY          prdType, prdName, prdLanguage;
    PIMAGE_RESOURCE_DIRECTORY_ENTRY    prde, prde1;
    PIMAGE_RESOURCE_DIR_STRING_U       pStringName;
    PIMAGE_RESOURCE_DATA_ENTRY         prData;
    PWORD                              pStringHeader;
    char                    buff[256];
    int                     i,j; 
    int                     size;
    int                     sLength, nStrings;
    WORD                   *pwd;
    char                   *pMem; 

    /* get root directory of resource tree */
    if ((prdType = (PIMAGE_RESOURCE_DIRECTORY)ImageDirectoryOffset
            (lpFile, IMAGE_DIRECTORY_ENTRY_RESOURCE)) == NULL)
    return 0;

    /* set pointer to first resource type entry */
    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdType + sizeof (IMAGE_RESOURCE_DIRECTORY)
		   + prdType->NumberOfNamedEntries*8);
 
    for (i=0; i<prdType->NumberOfIdEntries; i++)
    {
    if (prde->Name == RT_STRING) break;
    prde++;
    }
    if (prde->Name != RT_STRING) return 0; 

    prdName = (PIMAGE_RESOURCE_DIRECTORY)
          ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000) ); 
    if (prdName == NULL) return 0;

    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdName + sizeof (IMAGE_RESOURCE_DIRECTORY));


    nStrings=prdName->NumberOfNamedEntries + prdName->NumberOfIdEntries;
    sLength=0;
    
    for (i=0; i<prdName->NumberOfNamedEntries; i++)
    {
        pStringName = (PIMAGE_RESOURCE_DIR_STRING_U) 
              ((DWORD)prdType + (prde->Name ^ 0x80000000));
        sLength += pStringName->Length + 1;
        
        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        size = prData->Size; 
        sLength += 4+size;       
        prde++;
    }
    for (i=0; i<prdName->NumberOfIdEntries; i++)
    {
        sLength += 14;
        
        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        size = prData->Size; 
        sLength += 4+size;       
        prde++;
    }
    //
    // allocate memory for menu names
    //
    *pszResTypes = (char *)calloc (sLength, 1);

    pMem = *pszResTypes;
    //
    // and start all over again
    //
    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdName + sizeof (IMAGE_RESOURCE_DIRECTORY));

    for (i=0; i<prdName->NumberOfNamedEntries; i++)
    {
        pStringName = (PIMAGE_RESOURCE_DIR_STRING_U) 
              ((DWORD)prdType + (prde->Name ^ 0x80000000));
        
        
        for (j=0; j<pStringName->Length; j++)
            *pMem++ = (char)(pStringName->NameString[j]);
        *pMem = 0;
        pMem++;
        

        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        pStringHeader =  (PWORD)
                 GetActualAddress (lpFile, prData->OffsetToData);
     
        
        
        pwd = pStringHeader;
        size = prData->Size;
        *(int *)pMem = size;          pMem += 4;
        StrangeMenuFill (&pMem, &pwd, size);
        
        prde++;
    }
    for (i=0; i<prdName->NumberOfIdEntries; i++)
    {
        
        sprintf (buff, "StringId_%04X", (int)(prde->Name));
        strcpy (pMem, buff);
        pMem += strlen (buff) + 1;

        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) 
        {   printf ("\nprdLanguage = NULL"); exit (0); }
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) 
        {   printf ("\nprData = NULL"); exit (0); }

        pStringHeader =  (PWORD)
                 GetActualAddress (lpFile, prData->OffsetToData);
        
        
        pwd = pStringHeader;
        size = prData->Size;
        *(int *)pMem = size;          pMem += 4;
        StrangeMenuFill (&pMem, &pwd, size);
        
        prde++;
    }

    return nStrings;
}

//
// This function is written by sang cho
//                                                         September 5, 1998

/* print contents of string */
int     WINAPI PrintString (
    char      **psz)
{    
    int                     i; 
	int                     num, size;
    char                    *ptr, *pmax;

    ptr  = *psz;
    size = *(int *)ptr;
    ptr += 4;
    pmax = ptr+size;
    
   	while (ptr<pmax)
	{
		num=*ptr;
		ptr+=2;
	   
	    i=0;   if(num<0) num+=256;
		if (num>0) {printf ("\n    ");  printf ("%c",'"');}
        while (i<num) 
		{ 
		    if  (*ptr==0x09) printf("<t>");
			else if	(*ptr==0x0D && *(ptr+2)==0x0A) {printf("<nl>"); ptr+=2; i++;}
			else if (isprint(*ptr)) printf("%c", *ptr);
			else printf(".");
			ptr+= 2; i++;
		}
        if (num>0) printf ("%c", '"');
    }
    
    *psz = pmax;
	return 1;
}

//
// This function is written by sang cho
//                                                         September 6, 1998

/* scan icon and copy icon */
int     WINAPI GetContentsOfIcon (
    LPVOID    lpFile,
    char      **pszResTypes)
{
    PIMAGE_RESOURCE_DIRECTORY          prdType, prdName, prdLanguage;
    PIMAGE_RESOURCE_DIRECTORY_ENTRY    prde, prde1;
    PIMAGE_RESOURCE_DIR_STRING_U       pIconName;
    PIMAGE_RESOURCE_DATA_ENTRY         prData;
    PWORD                              pIconHeader;
    char                    buff[256];
    int                     i,j; 
    int                     size;
    int                     sLength, nIcons;
    WORD                   *pwd;
    char                   *pMem; 

    /* get root directory of resource tree */
    if ((prdType = (PIMAGE_RESOURCE_DIRECTORY)ImageDirectoryOffset
            (lpFile, IMAGE_DIRECTORY_ENTRY_RESOURCE)) == NULL)
    return 0;

    /* set pointer to first resource type entry */
    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdType + sizeof (IMAGE_RESOURCE_DIRECTORY)
		   +prdType->NumberOfNamedEntries*8);
 
    for (i=0; i<prdType->NumberOfIdEntries; i++)
    {
    if (prde->Name == RT_ICON) break;
    prde++;
    }
    if (prde->Name != RT_ICON) return 0; 

    prdName = (PIMAGE_RESOURCE_DIRECTORY)
          ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000) ); 
    if (prdName == NULL) return 0;

    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdName + sizeof (IMAGE_RESOURCE_DIRECTORY));


    nIcons=prdName->NumberOfNamedEntries + prdName->NumberOfIdEntries;
    sLength=0;
    
    for (i=0; i<prdName->NumberOfNamedEntries; i++)
    {
        pIconName = (PIMAGE_RESOURCE_DIR_STRING_U) 
              ((DWORD)prdType + (prde->Name ^ 0x80000000));
        sLength += pIconName->Length + 1;
        
        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        size = prData->Size; 
        sLength += 4+size;       
        prde++;
    }
    for (i=0; i<prdName->NumberOfIdEntries; i++)
    {
        sLength += 14;
        
        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        size = prData->Size; 
        sLength += 4+size;       
        prde++;
    }
    //
    // allocate memory for icon names
    //
    *pszResTypes = (char *)calloc (sLength, 1);

    pMem = *pszResTypes;
    //
    // and start all over again
    //
    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdName + sizeof (IMAGE_RESOURCE_DIRECTORY));

    for (i=0; i<prdName->NumberOfNamedEntries; i++)
    {
        pIconName = (PIMAGE_RESOURCE_DIR_STRING_U) 
              ((DWORD)prdType + (prde->Name ^ 0x80000000));
        
        
        for (j=0; j<pIconName->Length; j++)
            *pMem++ = (char)(pIconName->NameString[j]);
        *pMem = 0;
        pMem++;
        

        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        pIconHeader =  (PWORD)
                 GetActualAddress (lpFile, prData->OffsetToData);
     
        
        
        pwd = pIconHeader;
        size = prData->Size;
        *(int *)pMem = size;          pMem += 4;
        StrangeMenuFill (&pMem, &pwd, size);
        
        prde++;
    }
    for (i=0; i<prdName->NumberOfIdEntries; i++)
    {
        
        sprintf (buff, "IconId_%04X", (int)(prde->Name));
        strcpy (pMem, buff);
        pMem += strlen (buff) + 1;

        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) 
        {   printf ("\nprdLanguage = NULL"); exit (0); }
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) 
        {   printf ("\nprData = NULL"); exit (0); }

        pIconHeader =  (PWORD)
                 GetActualAddress (lpFile, prData->OffsetToData);
        
        
        pwd = pIconHeader;
        size = prData->Size;
        *(int *)pMem = size;          pMem += 4;
        StrangeMenuFill (&pMem, &pwd, size);
        
        prde++;
    }

    return nIcons;
}

//
// This function is written by sang cho
//                                                         September 6, 1998

/* print contents of icon */
int     WINAPI PrintIcon (
    char      **psz)
{    

    int                     i; 
	int                     j,k,l,n,c;
	int                     h,w,nc,ww;
	//char                    buff[256];
	int                     a[256][256];
	int                     m[256][256];
	int                     color[256];
	char *                  show[]=
	{"  ",". "," .","+,",", ",",+","'+","aa","^^","+!","!!","#$","!/","@$","$$","##"};
	int                     size; //num
    char                    *ptr, *pmax;
	unsigned char           r,g,b;

	return 0;
    ptr  = *psz;
    size = *(int *)ptr;
	pmax = ptr+size+4;

	n    = *(int *)(ptr+4);
	h    = *(int *)(ptr+12); h/=2;
	w    = *(int *)(ptr+ 8); 
	l    = *(short *)(ptr + 18);
	nc   = 1; for(i=0;i<l;i++)nc*=2;
	ww   = (w+(8/l)-1)/(8/l); ww=(ww+3)/4; ww=ww*4;

	//fprintf(stderr,"\nprintIcon h=%d w=%d nc=%d ",h,w,nc);getch();

    if(h>0 && h<256)
    {
	
        ptr += (n+4);
	    for (i=0;i<nc;i++)
	    {
	        r=*ptr++;g=*ptr++;b=*ptr++;ptr++;
		    c=r+g+b;
		         if (c==0) color[i]=15;
		    else if (c<=128)
		    {
		        if(r>g&&r>b) color[i]=11;else
			    if(g>r&&g>b) color[i]=13;else color[i]=14;
		    }
		    else if (c==255)
		    {
		        if(r>g&&r>b) color[i]=3;else
			    if(g>r&&g>b) color[i]=5;else color[i]=6;
		    }
		    else if (c==256)
		    {
		        if(r<g&&r<b) color[i]=12;else
			    if(g<r&&g<b) color[i]=10;else color[i]=9;
		    }
		    else if (c<=384) color[i]=7;
		    else if (c<=510)
		    {    
		        if(r<g&&r<b) color[i]=4;else
			    if(g<r&&g<b) color[i]=2;else color[i]=1;
		    }
		    else if (c<=576) color[i]=8;
		    else             color[i]=0;
	    }
	    for (i=0;i<h;i++)
	    {
	        for (j=0;j<ww;j++)
		    {
		        b=*ptr++;
				if (l==8) {
				a[h-1-i][j]  = b;
		        		  }
			    else if (l==4) {
				a[h-1-i][j+j]  = b / 16;
			    a[h-1-i][j+j+1]= b % 16;
		        		  }
				else if(l==2)
				          {
			    for (k=0;k<4;k++) 
			    {
			        r=(b>>(6-2*k))&0x03;
				    if      (r==0x03) a[h-1-i][4*j+k]=15; 
					else if (r==0x02) a[h-1-i][4*j+k]=10;
					else if (r==0x01) a[h-1-i][4*j+k]=5;
					else              a[h-1-i][4*j+k]=0;
				}
				          }
				else if(l==1)
				          {
			    for (k=0;k<8;k++) 
			    {
			        if ((b>>(7-k))&0x01)
				    a[h-1-i][8*j+k]=15; else a[h-1-i][8*j+k]=0;
			    }
				          }
				else a[i][j]=0;
			}
	    }
	    for (i=0;i<h;i++)
	    {
	        for (j=0;j<w/8;j++)
		    {
		        b=*ptr++;
			    for (k=0;k<8;k++) 
			    {
			        if ((b>>(7-k))&0x01)
				    m[h-1-i][8*j+k]=1; else m[h-1-i][8*j+k]=0;
			    }
		    }
	    }
    }

	printf("   height=%3d  width=%3d  # of bits=%3d ", h, w, l);
	if (moreprint)
	{
	    printf("\n\n");
		for (i=0;i<h;i++)
	    {
	        for (j=0;j<w;j++)
		    {
		        if (color[a[i][j]]<15) printf("%s",show[color[a[i][j]]]);
			    else if (m[i][j])      printf("#~"); else printf("##");
		    }
		    printf("\n");
	    }
	}

	*psz=pmax;
	return 1;
}

//
// This function is written by sang cho
//                                                         September 10, 1998

/* scan bitmap and copy bitmap */
int     WINAPI GetContentsOfBitmap (
    LPVOID    lpFile,
    char      **pszResTypes)
{
    PIMAGE_RESOURCE_DIRECTORY          prdType, prdName, prdLanguage;
    PIMAGE_RESOURCE_DIRECTORY_ENTRY    prde, prde1;
    PIMAGE_RESOURCE_DIR_STRING_U       pBitmapName;
    PIMAGE_RESOURCE_DATA_ENTRY         prData;
    PWORD                              pBitmapHeader;
    char                    buff[256];
    int                     i,j; 
    int                     size;
    int                     sLength, nBitmaps;
    WORD                   *pwd;
    char                   *pMem; 

    /* get root directory of resource tree */
    if ((prdType = (PIMAGE_RESOURCE_DIRECTORY)ImageDirectoryOffset
            (lpFile, IMAGE_DIRECTORY_ENTRY_RESOURCE)) == NULL)
    return 0;

    /* set pointer to first resource type entry */
    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdType + sizeof (IMAGE_RESOURCE_DIRECTORY)
		   +prdType->NumberOfNamedEntries*8);
 
    for (i=0; i<prdType->NumberOfIdEntries; i++)
    {
    if (prde->Name == RT_BITMAP) break;
    prde++;
    }
    if (prde->Name != RT_BITMAP) return 0; 

    prdName = (PIMAGE_RESOURCE_DIRECTORY)
          ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000) ); 
    if (prdName == NULL) return 0;

    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdName + sizeof (IMAGE_RESOURCE_DIRECTORY));


    nBitmaps=prdName->NumberOfNamedEntries + prdName->NumberOfIdEntries;
    sLength=0;
    
    for (i=0; i<prdName->NumberOfNamedEntries; i++)
    {
        pBitmapName = (PIMAGE_RESOURCE_DIR_STRING_U) 
              ((DWORD)prdType + (prde->Name ^ 0x80000000));
        sLength += pBitmapName->Length + 1;
        
        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        size = prData->Size; 
        sLength += 4+size;       
        prde++;
    }
    for (i=0; i<prdName->NumberOfIdEntries; i++)
    {
        sLength += 14;
        
        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        size = prData->Size; 
        sLength += 4+size;       
        prde++;
    }
    //
    // allocate memory for bitmap names
    //
    *pszResTypes = (char *)calloc (sLength, 1);

    pMem = *pszResTypes;
    //
    // and start all over again
    //
    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdName + sizeof (IMAGE_RESOURCE_DIRECTORY));

    for (i=0; i<prdName->NumberOfNamedEntries; i++)
    {
        pBitmapName = (PIMAGE_RESOURCE_DIR_STRING_U) 
              ((DWORD)prdType + (prde->Name ^ 0x80000000));
        
        
        for (j=0; j<pBitmapName->Length; j++)
            *pMem++ = (char)(pBitmapName->NameString[j]);
        *pMem = 0;
        pMem++;
        

        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        pBitmapHeader =  (PWORD)
                 GetActualAddress (lpFile, prData->OffsetToData);
     
        
        
        pwd = pBitmapHeader;
        size = prData->Size;
        *(int *)pMem = size;          pMem += 4;
        StrangeMenuFill (&pMem, &pwd, size);
        
        prde++;
    }
    for (i=0; i<prdName->NumberOfIdEntries; i++)
    {
        
        sprintf (buff, "BitmapId_%04X", (int)(prde->Name));
        strcpy (pMem, buff);
        pMem += strlen (buff) + 1;

        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) 
        {   printf ("\nprdLanguage = NULL"); exit (0); }
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) 
        {   printf ("\nprData = NULL"); exit (0); }

        pBitmapHeader =  (PWORD)
                 GetActualAddress (lpFile, prData->OffsetToData);
        
        
        pwd = pBitmapHeader;
        size = prData->Size;
        *(int *)pMem = size;          pMem += 4;
        StrangeMenuFill (&pMem, &pwd, size);
        
        prde++;
    }

    return nBitmaps;
}

//
// This function is written by sang cho
//                                                         September 10, 1998

/* print contents of bitmap */
int     WINAPI PrintBitmap (
    char      **psz)
{    
    int                     i;
	int                     noprint=0;
	int                     j,k,l,n,c,e = 0;
	int                     h,w,nc,ww=0;
	//char                    buff[256];
	int                     a[512][512];
	int                     color[256];
	char *                  show[]=
	{"  ",". "," .","+,",", ",",+","'+","aa","^^","+!","!!","#$","!/","@$","$$","##"};
	int                     size; //num
    char                    *ptr, *pmax;
	unsigned char           r,g,b;

    ptr  = *psz;
    size = *(int *)ptr;
	pmax = ptr+size+4;

	n    = *(int *)(ptr+4);
	if (n==12) // strange form
	{
	    h=*(short*)(ptr+10);
		w=*(short*)(ptr+8);
		l=*(short*)(ptr+12);
		nc=1; for(i=0;i<l;i++)nc*=2;
	}
	else
	{
	    h    = *(int *)(ptr+12); 
	    w    = *(int *)(ptr+ 8); 
	    l    = *(short *)(ptr + 18);
	    e    = *(int *)(ptr+20);
	    nc   = 1; for(i=0;i<l;i++)nc*=2;
	}
	if (0<l && l<=8) ww   = (w+(8/l)-1)/(8/l); else ww=ww*4;
	ww=(ww+3)/4; ww=ww*4;

	//fprintf(stderr,"\nprintBitmap h=%d w=%d nc=%d size=%d",h,w,nc,size);getch();

    if(h>0 && h<512 && l<=8 && 12<n)
    {
	
        ptr += (n+4);
	    for (i=0;i<nc;i++)
	    {
	        r=*ptr++;g=*ptr++;b=*ptr++;ptr++;
		    c=r+g+b;
		         if (c==0) color[i]=15;
		    else if (c<=128)
		    {
		        if(r>g&&r>b) color[i]=11;else
			    if(g>r&&g>b) color[i]=13;else color[i]=14;
		    }
		    else if (c==255)
		    {
		        if(r>g&&r>b) color[i]=3;else
			    if(g>r&&g>b) color[i]=5;else color[i]=6;
		    }
		    else if (c==256)
		    {
		        if(r<g&&r<b) color[i]=12;else
			    if(g<r&&g<b) color[i]=10;else color[i]=9;
		    }
		    else if (c<=384) color[i]=7;
		    else if (c<=510)
		    {    
		        if(r<g&&r<b) color[i]=4;else
			    if(g<r&&g<b) color[i]=2;else color[i]=1;
		    }
		    else if (c<=576) color[i]=8;
		    else             color[i]=0;
	    }
		if (e==0)
		{
	        for (i=0;i<h;i++)
	        {
	            for (j=0;j<ww;j++)
		        {
		            b=*ptr++;
				    if (l==8) 
					{
				        a[h-1-i][j]  = b;
		        	}
			        else if (l==4) 
					{
				        a[h-1-i][j+j]  = b / 16;
			            a[h-1-i][j+j+1]= b % 16;
		        	}
				    else if(l==2)
				    {
			            for (k=0;k<4;k++) 
			            {
			                r=(b>>(6-2*k))&0x03;
				            if      (r==0x03) a[h-1-i][4*j+k]=15; 
					        else if (r==0x02) a[h-1-i][4*j+k]=10;
					        else if (r==0x01) a[h-1-i][4*j+k]=5;
					        else              a[h-1-i][4*j+k]=0;
				        }
				    }
				    else if(l==1)
				    {
			            for (k=0;k<8;k++) 
			            {
			                if ((b>>(7-k))&0x01)
				            a[h-1-i][8*j+k]=15; else a[h-1-i][8*j+k]=0;
			            }
				    }
				    else a[h-1-i][j]=0;
			    }
	        }
		}
		else
		{
		    if (l==8)
			{
			    i=h-1;j=0;
				while(ptr<pmax)
				{
				    r=*ptr++; g=*ptr++;
				    if(r>0)					   // repeat mode (normal)
				    {
				        for(k=0;k<r;k++) 
						{
						    a[i][j++]=g; 
				        }
					}
					else
					{
					    if(g==0) {i--;j=0;}		// end of line
						else if (g==1) break;	// end of bitmap
						else if (g==2) 			// delta
						{
						    r=*ptr++; g=*ptr++;
							j+=r; i-=g;
						}
						else					// absolute mode
						{
						    for(k=0;k<g;k++) 
						    {
						        r=*ptr++; b=*ptr++;
								a[i][j++]=r; 
							    k++; if (k>=g) break;
							    a[i][j++]=b;
				            }
						}
					}
				}
			}
			else if (l==4)
			{
			    i=h-1;j=0;
				while(ptr<pmax)
				{
				    r=*ptr++; g=*ptr++;
				    if(r>0)					   // repeat mode (normal)
				    {
				        for(k=0;k<r;k++) 
						{
						    a[i][j++]=g/16; 
							k++; if (k>=r) break;
							a[i][j++]=g%16;    
				        }
					}
					else
					{
					    if(g==0) {i--;j=0;}		// end of line
						else if (g==1) break;	// end of bitmap
						else if (g==2) 			// delta
						{
						    r=*ptr++; g=*ptr++;
							j+=r; i-=g;
						}
						else					// absolute mode
						{
						    for(k=0;k<g;k++) 
						    {
						        r=*ptr++; b=*ptr++;
								a[i][j++]=r/16; 
							    k++; if (k>=g) break;
							    a[i][j++]=r%16;
								k++; if (k>=g) break;
								a[i][j++]=b/16; 
							    k++; if (k>=g) break;
							    a[i][j++]=b%16;
				            }
						}
					}
				}
			}
			else noprint=1;
		}    
    }
	else noprint=1;
	
	printf("   height=%3d  width=%3d  # of bits=%3d ", h, w, l);
	if (moreprint && !noprint)
	{
	    printf("\n\n");
		for (i=0;i<h;i++)
	    {
	        for (j=0;j<w;j++)
		    {
		        printf("%s",show[color[a[i][j]]]);
		    }
		    printf("\n");
	    }
	}

	*psz=pmax;
	return 1;
}


//
// This function is written by sang cho
//                                                         September 9, 1998

/* scan cursor and copy cursor */
int     WINAPI GetContentsOfCursor (
    LPVOID    lpFile,
    char      **pszResTypes)
{
    PIMAGE_RESOURCE_DIRECTORY          prdType, prdName, prdLanguage;
    PIMAGE_RESOURCE_DIRECTORY_ENTRY    prde, prde1;
    PIMAGE_RESOURCE_DIR_STRING_U       pCursorName;
    PIMAGE_RESOURCE_DATA_ENTRY         prData;
    PWORD                              pCursorHeader;
    char                    buff[256];
    int                     i,j; 
    int                     size;
    int                     sLength, nCursors;
    WORD                   *pwd;
    char                   *pMem; 

    /* get root directory of resource tree */
    if ((prdType = (PIMAGE_RESOURCE_DIRECTORY)ImageDirectoryOffset
            (lpFile, IMAGE_DIRECTORY_ENTRY_RESOURCE)) == NULL)
    return 0;

    /* set pointer to first resource type entry */
    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdType + sizeof (IMAGE_RESOURCE_DIRECTORY)
		   +prdType->NumberOfNamedEntries*8);
 
    for (i=0; i<prdType->NumberOfIdEntries; i++)
    {
        if (prde->Name == RT_CURSOR) break;
        prde++;
    }
    if (prde->Name != RT_CURSOR) return 0; 

    prdName = (PIMAGE_RESOURCE_DIRECTORY)
          ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000) ); 
    if (prdName == NULL) return 0;

    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdName + sizeof (IMAGE_RESOURCE_DIRECTORY)
		   +prdName->NumberOfNamedEntries*8);


    nCursors=prdName->NumberOfNamedEntries + prdName->NumberOfIdEntries;
	sLength=0;
    
    for (i=0; i<prdName->NumberOfNamedEntries; i++)
    {
        pCursorName = (PIMAGE_RESOURCE_DIR_STRING_U) 
              ((DWORD)prdType + (prde->Name ^ 0x80000000));
        sLength += pCursorName->Length + 1;
        
        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        size = prData->Size; 
        sLength += 4+size;       
        prde++;
    }
	
    for (i=0; i<prdName->NumberOfIdEntries; i++)
    {
        sLength += 14;
        
        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        size = prData->Size; 
        sLength += 4+size;       
        prde++;
    }
	
    //
    // allocate memory for cursor names
    //
    *pszResTypes = (char *)calloc (sLength, 1);

    pMem = *pszResTypes;
    //
    // and start all over again
    //
    prde = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
           ((DWORD)prdName + sizeof (IMAGE_RESOURCE_DIRECTORY)
		   +prdName->NumberOfNamedEntries*8);

    for (i=0; i<prdName->NumberOfNamedEntries; i++)
    {
        pCursorName = (PIMAGE_RESOURCE_DIR_STRING_U) 
              ((DWORD)prdType + (prde->Name ^ 0x80000000));
        
        
        for (j=0; j<pCursorName->Length; j++)
            *pMem++ = (char)(pCursorName->NameString[j]);
        *pMem = 0;
        pMem++;
        

        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) continue;
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) continue;
        
        pCursorHeader =  (PWORD)
                 GetActualAddress (lpFile, prData->OffsetToData);
     
        
        
        pwd = pCursorHeader;
        size = prData->Size;
        *(int *)pMem = size;          pMem += 4;
        StrangeMenuFill (&pMem, &pwd, size);
        
        prde++;
    }
	
    for (i=0; i<prdName->NumberOfIdEntries; i++)
    {
        
        sprintf (buff, "CursorId_%04X", (int)(prde->Name));
        strcpy (pMem, buff);
        pMem += strlen (buff) + 1;

        prdLanguage = (PIMAGE_RESOURCE_DIRECTORY)
              ((DWORD)prdType + (prde->OffsetToData ^ 0x80000000));
        if (prdLanguage == NULL) 
        {   printf ("\nprdLanguage = NULL"); exit (0); }
        
        prde1 = (PIMAGE_RESOURCE_DIRECTORY_ENTRY)
            ((DWORD)prdLanguage + sizeof (IMAGE_RESOURCE_DIRECTORY)
			+prdLanguage->NumberOfNamedEntries*8);
        
        prData = (PIMAGE_RESOURCE_DATA_ENTRY)
             ((DWORD)prdType + prde1->OffsetToData);
        if (prData == NULL) 
        {   printf ("\nprData = NULL"); exit (0); }

        pCursorHeader =  (PWORD)
                 GetActualAddress (lpFile, prData->OffsetToData);
        
        
        pwd = pCursorHeader;
        size = prData->Size;
        *(int *)pMem = size;          pMem += 4;
        StrangeMenuFill (&pMem, &pwd, size);
        
        prde++;
    }
    return nCursors;
}

//
// This function is written by sang cho
//                                                         September 9, 1998

/* print contents of cursor */
int     WINAPI PrintCursor (
    char      **psz)
{    
    int                     i; 
	int                     j,k,l,n,c;
	int                     h,w,nc,ww;
	int                     x,y;
	//char                    buff[256];
	int                     a[256][256];
	int                     m[256][256];
	int                     color[256];
	char *                  show[]=
	{"  ",". "," .","+,",", ",",+","'+","aa","^^","+!","!!","#$","!/","@$","$$","##"};
	int                     size; //num
    char                    *ptr, *pmax;
	unsigned char           r,g,b;

	/*
    ptr = *psz;
    printf("\n");
	size = *(int *)ptr;
	pmax = ptr+size+4;

    for (i=0; i<(size/16)+1; i++)
    {
        n = 0;
        for (j=0; j<16; j++)
        {
            c = (int)(*ptr);
            if (c<0) c+=256;
            buff[j] = c;
            printf ("%02X",c);
            ptr++; 
            if (ptr >= pmax) break;
            n++;
            if (n%4 == 0) printf (" "); 
        }
        n++; if (n%4 == 0) printf (" ");
        l = j;
        j++;
        for (; j<16; j++) 
        { n++; if (n%4 == 0) printf ("   "); else printf ("  "); }
        printf ("   ");
        for (k=0; k<l; k++)
            if (isprint(c=buff[k])) printf("%c", c); else printf(".");
        printf ("\n");
        if (ptr >= pmax) break;
    }
    *psz=pmax;
	return 1;*/
	
	ptr  = *psz;
    size = *(int *)ptr;
	pmax = ptr+size+4;

	x    = *(short*)(ptr+4);
	y    = *(short*)(ptr+6);ptr+=4;
	n    = *(int *)(ptr+4);
	h    = *(int *)(ptr+12); h/=2;
	w    = *(int *)(ptr+ 8); 
	l    = *(short *)(ptr + 18);
	nc   = 1; for(i=0;i<l;i++)nc*=2;
	ww   = (w+(8/l)-1)/(8/l); ww=(ww+3)/4; ww=ww*4;

	//fprintf(stderr,"\nprintCursor h=%d w=%d nc=%d ",h,w,nc);getch();

    if(h>0 && h<256)
    {
	
        ptr += (n+4);
	    for (i=0;i<nc;i++)
	    {
	        r=*ptr++;g=*ptr++;b=*ptr++;ptr++;
		    c=r+g+b;
		         if (c==0) color[i]=15;
		    else if (c<=128)
		    {
		        if(r>g&&r>b) color[i]=11;else
			    if(g>r&&g>b) color[i]=13;else color[i]=14;
		    }
		    else if (c==255)
		    {
		        if(r>g&&r>b) color[i]=3;else
			    if(g>r&&g>b) color[i]=5;else color[i]=6;
		    }
		    else if (c==256)
		    {
		        if(r<g&&r<b) color[i]=12;else
			    if(g<r&&g<b) color[i]=10;else color[i]=9;
		    }
		    else if (c<=384) color[i]=7;
		    else if (c<=510)
		    {    
		        if(r<g&&r<b) color[i]=4;else
			    if(g<r&&g<b) color[i]=2;else color[i]=1;
		    }
		    else if (c<=576) color[i]=8;
		    else             color[i]=0;
	    }
	    for (i=0;i<h;i++)
	    {
	        for (j=0;j<ww;j++)
		    {
		        b=*ptr++;
				if (l==8) {
				a[h-1-i][j]  = b;
		        		  }
			    else if (l==4) 
				          {
				a[h-1-i][j+j]  = b / 16;
			    a[h-1-i][j+j+1]= b % 16;
		        		  }
				else if(l==2)
				          {
			    for (k=0;k<4;k++) 
			    {
			        r=(b>>(6-2*k))&0x03;
				    if      (r==0x03) a[h-1-i][4*j+k]=15; 
					else if (r==0x02) a[h-1-i][4*j+k]=10;
					else if (r==0x01) a[h-1-i][4*j+k]=5;
					else              a[h-1-i][4*j+k]=0;
				}
				          }
				else if(l==1)
				          {
			    for (k=0;k<8;k++) 
			    {
			        if ((b>>(7-k))&0x01)
				    a[h-1-i][8*j+k]=15; else a[h-1-i][8*j+k]=0;
			    }
				          }
				else a[i][j]=0;
			}
	    }
	    for (i=0;i<h;i++)
	    {
	        for (j=0;j<w/8;j++)
		    {
		        b=*ptr++;
			    for (k=0;k<8;k++) 
			    {
			        if ((b>>(7-k))&0x01)
				    m[h-1-i][8*j+k]=1; else m[h-1-i][8*j+k]=0;
			    }
		    }
	    }
    }
	printf("   height=%3d  width=%3d  # of bits=%3d (hotx=%d,hoty=%d)", 
		       h, w, l, x, y);
	if (moreprint)
	{
	    printf("\n\n");
		for (i=0;i<h;i++)
	    {
	        for (j=0;j<w;j++)
		    {
		        if (color[a[i][j]]<15) printf("%s",show[color[a[i][j]]]);
			    else if (m[i][j])      printf(".."); else printf("##");
		    }
		    printf("\n");
	    }
	}
	
	*psz=pmax;
	return 1;
}



/* function indicates whether debug  info has been stripped from file */
BOOL    WINAPI IsDebugInfoStripped (
    LPVOID    lpFile)
{
    PIMAGE_FILE_HEADER    pfh;

    pfh = (PIMAGE_FILE_HEADER)PEFHDROFFSET (lpFile);

    return (pfh->Characteristics & IMAGE_FILE_DEBUG_STRIPPED);
}

/* retrieve the module name from the debug misc. structure */
int    WINAPI RetrieveModuleName (
    LPVOID    lpFile,
    char      **pszModule)
{

    PIMAGE_DEBUG_DIRECTORY    pdd;
    PIMAGE_DEBUG_MISC         pdm = NULL;
    int                       nCnt = 0;

    if (!(pdd = (PIMAGE_DEBUG_DIRECTORY)ImageDirectoryOffset (lpFile, IMAGE_DIRECTORY_ENTRY_DEBUG)))
    return 0;

    while (pdd->SizeOfData)
    {
    if (pdd->Type == IMAGE_DEBUG_TYPE_MISC)
        {
        pdm = (PIMAGE_DEBUG_MISC)((DWORD)pdd->PointerToRawData + (DWORD)lpFile);
        *pszModule = (char *)calloc ((nCnt = (strlen (pdm->Data)))+1, 1);
        // may need some unicode business here...above
        memcpy (*pszModule, pdm->Data, nCnt);

        break;
        }

    pdd ++;
    }

    if (pdm != NULL)
    return nCnt;
    else
    return 0;
}

/* determine if this is a valid debug file */
BOOL    WINAPI IsDebugFile (
    LPVOID    lpFile)
{
    PIMAGE_SEPARATE_DEBUG_HEADER    psdh;

    psdh = (PIMAGE_SEPARATE_DEBUG_HEADER)lpFile;

    return (psdh->Signature == IMAGE_SEPARATE_DEBUG_SIGNATURE);
}

/* copy separate debug header structure from debug file */
BOOL    WINAPI GetSeparateDebugHeader (
    LPVOID                          lpFile,
    PIMAGE_SEPARATE_DEBUG_HEADER    psdh)
{
    PIMAGE_SEPARATE_DEBUG_HEADER    pdh;

    pdh = (PIMAGE_SEPARATE_DEBUG_HEADER)lpFile;

    if (pdh->Signature == IMAGE_SEPARATE_DEBUG_SIGNATURE)
    {
    memcpy ((LPVOID)psdh, (LPVOID)pdh, sizeof (IMAGE_SEPARATE_DEBUG_HEADER));
    return TRUE;
    }

    return FALSE;
}

void printTimeDateStamp(DWORD tds)
{
LONGLONG tem;
int      i, iyear, iweek, idate, ihour, isecond;
int      monthDays[] ={31,28,31,30,31,30,31,31,30,31,30,31};
char    *monString[] ={"Jan","Feb","Mar","Apr","May","Jun",  
	                   "Jul","Aug","Sep","Oct","Nov","Dec"};
char    *weekString[]={"Sun","Mon","Tue","Wed","Thu","Fri","Sat"};

    // I don't have documentation about timedatestamp
	// so my best guess is to run some kind of reference software
	// Ida and dumppe gives different results 
	// I don't know which is right but I guess dumppe is right so 
	// I changed output accordingly.
	// If you think Ida is right then the following 8 should be 5.
	// 1998.2.27 sangcho
	tem  = (LONGLONG)tds;
	ihour=(int)(tem/3600)-8; isecond=(int)(tem%3600);
	idate=ihour/24; ihour=ihour%24;	 iweek=(idate+4)%7;
	iyear=idate/365; idate=idate-iyear*365;
	if (idate<(iyear+1)/4) {iyear=iyear-1; idate=idate+365;}
	idate -= (iyear+1)/4;  
	if ((iyear+2)%4==0) monthDays[1]+=1;
	for (i=0;i<11;i++)monthDays[i+1]=monthDays[i]+monthDays[i+1];
	for (i=0;i<12;i++)if (idate<monthDays[i]) break;
	if (i>0) idate-=monthDays[i-1];
	// summer time adjustment i hope this is right.	  1998.2.26 sangcho
	// daylight saving time is from the first sunday 2:00 Am of April to
	// the last sunday 2:00 Am of October
	     if ((3<i)&&(i<9)) ihour+=1; 
	else if (i==3)
	{
	          if (idate>6) ihour+=1;
		 else if (iweek==0){if (ihour>1) ihour+=1;}
		 else if (idate>=iweek) ihour+=1;
	}
	else if (i==9)
	{
	          if (idate<24) ihour+=1;
		 else if (iweek==0){if (ihour<2) ihour+=1;}
		 else if (idate<24+iweek) ihour+=1;
	}
	if (ihour>24) {ihour-=24; idate+=1;}
	if (idate+1>monthDays[i]) {idate-=monthDays[i];i+=1;}
	printf("T.DateStamp = %08X: ",(int)tds);
	printf("%s %s %02d %02d:%02d:%02d %4d\n", weekString[iweek], monString[i], 
	        idate+1, ihour, isecond/60, isecond%60, 1970+iyear);


}

/* I need to place these data here to keep integrity of codes */

LPVOID          lpFile;        /* pointer to the contents of the input file */
LPVOID          lpMap;         /* pointer to the map of codes processed */
LPVOID          lpMap1;        /* pointer to the map of codes processed */ 
int             nSections;              // number of sections
int             nResources;             // number of resources
int             nMenus;                 // number of menus
int             nDialogs;               // number of dialogs
int             nStrings;               // number of strings
int             nIcons;                 // number of icons
int             nCursors;               // number of cursors
int             nBitmaps;               // number of bitmaps
int             nAccelerators;          // number of accelerators
int             nImportedModules;       // number of imported modules
int             nFunctions;                     // number of functions in the imported module
int             nExportedFunctions;     // number of exported funcions
DWORD           imageBase;                      // image base of the file
DWORD           entryPoint;                     // entry point of the file
DWORD           imagebaseRVA;  /* imagebase + RVA of the code */
int             CodeOffset;    /* starting point of code   */
int             CodeSize;      /* size of code             */
int             vCodeOffset;    /* starting point of code   */
int             vCodeSize;      /* size of code             */
int             MapSize;       /* size of code map         */
DWORD           maxRVA;        /* the largest RVA of sections */
int             maxRVAsize;    /* size of that section */
int             moreprint=0;   /* need to print some more */

char           *piNameBuff;       // import module name buffer
char           *pfNameBuff;       // import functions in the module name buffer
char           *peNameBuff;       // export function name buffer
char           *pmNameBuff;       // menu name buffer
char           *pdNameBuff;       // dialog name buffer   
char           *psNameBuff;       // string name buffer
char           *pcNameBuff;       // cursor name buffer
char           *pbNameBuff;       // bitmap name buffer
char           *pnNameBuff;       // icon   name buffer
char           *paNameBuff;       // accelerator name buffer
int             piNameBuffSize;   // import module name buffer
int             pfNameBuffSize;   // import functions in the module name buffer
int             peNameBuffSize;   // export function name buffer
int             pmNameBuffSize;   // menu name buffer
int             pdNameBuffSize;   // dialog name buffer

//
// I tried to immitate the output of w32dasm disassembler.
// which is a pretty good program.
// but I am disappointed with this program and I myself 
// am writting a disassembler.
// This PEdump program is a byproduct of that project.
// so enjoy this program and I hope we will have a little more
// knowledge on windows programming world.
//                                                        .... sang cho

#define  MAXSECTIONNUMBER 32
#define  MAXNAMESTRNUMBER 40

    IMAGE_SECTION_HEADER            shdr [MAXSECTIONNUMBER];


void print_import(DWORD addr) {

    DWORD nImportedModules = GetImportModuleNames (lpFile, &piNameBuff);

    if (nImportedModules > 0)
    {
        char     *pnstr;
		char     *pst;
		DWORD		i,j;

		pnstr = piNameBuff;
        for (i=0; i < nImportedModules; i++)
        {
            nFunctions = GetImportFunctionNamesByModule (lpFile, pnstr, &pfNameBuff);
            pnstr += strlen ((char *)(pnstr+4)) + 1 + 4;
            pst = pfNameBuff;
            for (j=0;j < nFunctions;j++)
            {
				if((*(int *)pst) == addr) {
					 printf (" ->%08X %s",
						(*(int *)pst),
						(char*)TranslateFunctionName(pst+6));
				};
                pst += strlen ((char *)(pst+6)) + 1 + 6;
            }
            free ((void *)pfNameBuff);
        }
        //free ((void *)piNameBuff);
    }
    
}




int pedump (int argc,char **argv)
{
    DWORD                           fileType;
    
    IMAGE_DOS_HEADER                dosHdr;
    PIMAGE_FILE_HEADER              pfh;
    PIMAGE_OPTIONAL_HEADER          poh;
    PIMAGE_SECTION_HEADER           psh;
    //IMAGE_SECTION_HEADER            idsh;
    extern     IMAGE_SECTION_HEADER    shdr[];
    //PIMAGE_IMPORT_MODULE_DIRECTORY  pid;

    int         i, j, n;
	int         CodeSize1;
	int         c, nexes;
	DWORD       tds;
	DWORD       baseofcode,baseofdata;

    char     *pnstr;
    char     *pst;

    //unsigned char          *p, *q;
    _key_                   k;
    //PKEY                    pk;

    GetDosHeader (lpFile, &dosHdr);

    if (dosHdr.e_magic == IMAGE_DOS_SIGNATURE)
    {
        if ((dosHdr.e_lfanew > 4096) || (dosHdr.e_lfanew < 64))
        {
    printf ("This file is not PE format ... sorry, it looks like DOS format\n");
    exit (0);
        }
    }
    else 
    {
    printf ("This doesn't look like executable file .. sorry, ...\n");
    exit (0);
    }

    fileType = ImageFileType (lpFile);

    if (fileType != IMAGE_NT_SIGNATURE) 
    {
        printf ("This file is not PE format ... sorry,\n");
        exit (0);
    }
    
    //=====================================
    // now we can really start processing
    //=====================================

    pfh = (PIMAGE_FILE_HEADER) PEFHDROFFSET (lpFile);

    poh = (PIMAGE_OPTIONAL_HEADER) OPTHDROFFSET (lpFile);

    psh = (PIMAGE_SECTION_HEADER) SECHDROFFSET (lpFile);

    nSections = pfh->NumberOfSections;

    imageBase = poh->ImageBase;

    entryPoint = poh->AddressOfEntryPoint;

    CodeSize = poh->SizeOfCode;

	tds = pfh->TimeDateStamp;
	
	printTimeDateStamp(tds);

    if (psh == NULL) return 0;

    /* store section headers */
    
	nexes=0;
    for (i=0; i < nSections; i++)
    {       
        shdr[i] = *psh++;
		 c=(int)shdr[i].Characteristics;
        if ((c&0x60000020)==0x60000020) nexes++; 
    }

	if (CodeSize==0) CodeSize=shdr[0].SizeOfRawData;

    // get Code offset and size, Data offset and size
    maxRVA = 0;

	baseofcode=poh->BaseOfCode;
	baseofdata=poh->BaseOfData;
	if (baseofcode>=baseofdata) baseofcode=0;
	//fprintf(stderr,"\npoh->BaseOfCode=%08X",poh->BaseOfCode);getch();

    for (i=0; i < nSections; i++)
    {       
        if (baseofcode == shdr[i].VirtualAddress 
		 || (baseofcode == 0 && i == 0))
        {
            imagebaseRVA = imageBase + shdr[i].VirtualAddress;
            CodeOffset = shdr[i].PointerToRawData;
            CodeSize1 = shdr[i].SizeOfRawData;
			if (nexes==1 && CodeSize!=CodeSize1) CodeSize=CodeSize1;
			printf("Code Offset = %08X, Code Size = %08X \n", 
            (int)(shdr[i].PointerToRawData), CodeSize);
        }
        if (shdr[i].VirtualAddress>maxRVA) 
        {
            maxRVA = shdr[i].VirtualAddress;
            maxRVAsize = shdr[i].SizeOfRawData;
        }
        if (((shdr[i].Characteristics) & 0xC0000040) == 0xC0000040)
        //if (poh->BaseOfData == shdr[i].VirtualAddress)
        {
        printf ("Data Offset = %08X, Data Size = %08X \n",
            (int)(shdr[i].PointerToRawData), (int)(shdr[i].SizeOfRawData));
            break;
        }
    }
    for (   ; i < nSections; i++)
    {       
        if (shdr[i].VirtualAddress>maxRVA) 
        {
            maxRVA = shdr[i].VirtualAddress;
            maxRVAsize = shdr[i].SizeOfRawData;
        }
    }

    printf ("\n");
    
    printf ("Number of Objects = %04d (dec), Imagebase = %08Xh \n",
        nSections, (int)imageBase);

    // object name alignment
    for (i=0; i < nSections; i++)
    {
        for (j=0;j<7;j++) if (shdr[i].Name[j]==0) shdr[i].Name[j]=32;
        shdr[i].Name[7]=0;
    }
    for (i=0; i < nSections; i++)
        printf ("\n   Object%02d: %8s RVA: %08X Offset: %08X Size: %08X Flags: %08X ",
            i+1, shdr[i].Name, (int)(shdr[i].VirtualAddress), 
			(int)(shdr[i].PointerToRawData),
            (int)(shdr[i].SizeOfRawData), (int)(shdr[i].Characteristics));
    // Get List of Resources
    nResources = GetListOfResourceTypes (lpFile, &pnstr);
    pst = pnstr;
    printf ("\n");
    printf ("\n+++++++++++++++++++ RESOURCE INFORMATION +++++++++++++++++++");
    printf ("\n");
    if (nResources==0)
    printf ("\n        There are no Resources in This Application.\n");
    else
    {
        printf ("\nNumber of Resource Types = %4d (decimal)\n", nResources);
        for (i=0; i < nResources; i++)
        {
        printf ("\n   Resource Type %03d: %s",i+1, pst);
        pst += strlen ((char *)(pst)) + 1;
        }
        free ((void *)pnstr);
        
		nCursors = GetContentsOfCursor (lpFile, &pcNameBuff);
        
        if (nCursors > 0)
        {
            printf ("\n");
            printf ("\n+++++++++++++++++ CURSOR INFORMATION +++++++++++++++++++");
            printf ("\n");
			
			pst = pcNameBuff;
            printf ("\nNumber of Cursors = %4d (decimal)", nCursors);

            printf ("\n");

            for (i=0; i < nCursors; i++)
            {
                // Cursor ID print
                printf ("\nName: %s", pst);
                pst += (n=strlen (pst)) + 1;
				for(j=n;j<20;j++) printf(" ");
                PrintCursor (&pst);
            }                                                   
            free ((void *)pcNameBuff); 
		}

		nBitmaps = GetContentsOfBitmap (lpFile, &pbNameBuff);
        
        if (nBitmaps > 0)
        {
            printf ("\n");
            printf ("\n+++++++++++++++++ BITMAP INFORMATION +++++++++++++++++++");
            printf ("\n");
			
			pst = pbNameBuff;
            printf ("\nNumber of Bitmaps = %4d (decimal)", nBitmaps);

            printf ("\n");

            for (i=0; i < nBitmaps; i++)
            {
                // Bitmap ID print
                printf ("\nName: %s", pst);
                pst += (n=strlen (pst)) + 1;
				for(j=n;j<20;j++) printf(" ");
                PrintBitmap (&pst);
            }                                                   
            free ((void *)pbNameBuff); 
		}

		nIcons = GetContentsOfIcon (lpFile, &pnNameBuff);
        
        if (nIcons > 0)
        {
            printf ("\n");
            printf ("\n+++++++++++++++++ ICON INFORMATION +++++++++++++++++++");
            printf ("\n");
			
			pst = pnNameBuff;
            printf ("\nNumber of Icons = %4d (decimal)", nIcons);

            printf ("\n");

            for (i=0; i < nIcons; i++)
            {
                // Dialog ID print
                printf ("\nName: %s", pst);
                pst += (n=strlen (pst)) + 1;
				for(j=n;j<20;j++) printf(" ");
                PrintIcon (&pst);
            }                                                   
            free ((void *)pnNameBuff); 
		}


        nMenus = GetContentsOfMenu (lpFile, &pmNameBuff);
        
        if (nMenus > 0)
        {
            printf ("\n");
            printf ("\n+++++++++++++++++++ MENU INFORMATION +++++++++++++++++++");
            printf ("\n");
			
			pst = pmNameBuff;
            printf ("\nNumber of Menus = %4d (decimal)", nMenus);

            //dumpMenu(&pst, 8096); 
			for (i=0; i < nMenus; i++)
            {
                // menu ID print
                printf ("\n\n%s", pst);
                pst += strlen (pst) + 1;
                printf ("\n-------------");
                if (strncmp (pst, ":::::::::::", 11) == 0)
                {    
                    printf("\n");
                    PrintStrangeMenu (&pst);
                }
                else 
                {
                    PrintMenu (6, &pst);
                }
                //else PrintStrangeMenu(&pst);
            }                                               
            free ((void *)pmNameBuff); 
            printf ("\n");
        }

        nDialogs = GetContentsOfDialog (lpFile, &pdNameBuff);
        
        if (nDialogs > 0)
        {
            printf ("\n");
            printf ("\n+++++++++++++++++ DIALOG INFORMATION +++++++++++++++++++");
            printf ("\n");
			
			pst = pdNameBuff;
            printf ("\nNumber of Dialogs = %4d (decimal)", nDialogs);

            printf ("\n");

            for (i=0; i < nDialogs; i++)
            {
                // Dialog ID print
                printf ("\nName: %s", pst);
                pst += strlen (pst) + 1;
                PrintDialog (&pst);
            }                                                   
            free ((void *)pdNameBuff); 
            printf ("\n");
		}

        nStrings = GetContentsOfString (lpFile, &psNameBuff);
       
        if (nStrings > 0)
        {
            printf ("\n");
            printf ("\n+++++++++++++++++ STRING INFORMATION +++++++++++++++++++");
            printf ("\n");
			
			pst = psNameBuff;
            printf ("\nNumber of Strings = %4d (decimal)", nStrings);

            printf ("\n");

            for (i=0; i < nStrings; i++)
        {
                // String ID print
                printf ("\nName: %s", pst);
                pst += strlen (pst) + 1;
                PrintString (&pst);
        }                                                   
        }
        free ((void *)psNameBuff); 
        printf ("\n");
    }
    
    printf ("\n+++++++++++++++++++ IMPORTED FUNCTIONS +++++++++++++++++++\n");

    nImportedModules = GetImportModuleNames (lpFile, &piNameBuff);
    if (nImportedModules == 0)
    {
        printf("\n        There are no imported Functions in This Application.\n");
    }
    else
    {
        pnstr = piNameBuff;
        printf ("\nNumber of Imported Modules = %4d (decimal)\n", nImportedModules);
        for (i=0; i < nImportedModules; i++)
        {
        printf ("\n   Import Module %03d: %s",i+1, pnstr + 4);
        pnstr += strlen ((char *)(pnstr+4)) + 1 + 4;
        }
        
        printf("\n");
        printf("\n+++++++++++++++++++ IMPORT MODULE DETAILS +++++++++++++++++");
        pnstr = piNameBuff;
        for (i=0; i < nImportedModules; i++)
        {
            printf ("\n\n   Import Module %03d: %s \n",i+1, pnstr + 4);
            nFunctions = GetImportFunctionNamesByModule (lpFile, pnstr, &pfNameBuff);
            pnstr += strlen ((char *)(pnstr+4)) + 1 + 4;
            pst = pfNameBuff;
            for (j=0;j < nFunctions;j++)
            {
            printf ("\nAddr:%08X hint(%04X) Name: %s",
                    (*(int *)pst),(*(short *)(pst+4)), 
                        //(pst+6));
                        (char*)TranslateFunctionName(pst+6));
                pst += strlen ((char *)(pst+6)) + 1 + 6;
            }
            free ((void *)pfNameBuff);
        }
        //free ((void *)piNameBuff);
    }
    
    printf("\n");
    printf("\n+++++++++++++++++++ EXPORTED FUNCTIONS +++++++++++++++++++\n");

    nExportedFunctions = GetExportFunctionNames (lpFile, &peNameBuff);
    printf ("\nNumber of Exported Functions = %4d (decimal)\n", nExportedFunctions);
    

    MapSize = CodeSize + CodeOffset;
    lpMap = (void *) calloc (MapSize, 1);
    lpMap1 = (void *)calloc (MapSize, 1);
    if (lpMap==NULL || lpMap1==NULL) 
    {
        fprintf(stderr,"cannot allocate memory.");exit(0);
    }

    if (nExportedFunctions > 0)
    {
        pst = peNameBuff;
      
        for (i=0; i < nExportedFunctions; i++)
        {
            printf ("\nAddr:%08X Ord:%4d (%04Xh) Name: %s",
                   (*(int *)pst), (*(WORD *)(pst+4)), (*(WORD *)(pst+4)), 
                   //(pst+6));
                   (char*)TranslateFunctionName(pst+6));
            // this one is needed to link export function names to codes..
            k.class=2048; k.c_ref= *(int *)pst; k.c_pos=0;
            if (AddressCheck(k.c_ref))
            {
                MyBtreeInsertEx(&k);
                if(isGoodAddress(k.c_ref))
                    addLabels(k.c_ref,512);
                orMap(k.c_ref, 0x40);
                k.class=992; k.c_pos=(int)(pst+6);
                MyBtreeInsertX(&k);
            }
            pst += strlen ((char *)(pst+6)) + 6+1;
        }
        //free ((void *)peNameBuff);
    }       
    // free ((void *)lpFile);
	return 1;
}       
