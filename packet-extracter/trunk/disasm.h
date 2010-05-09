//
//
// This program was written by Sang Cho, associate professor at 
//                                       the department of 
//                                       computer science and engineering
//                                       chongju university
// language used: gcc 
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
//   Copyright (C) 1997,1998                                 by Sang Cho.
//
// Permission is granted to make and distribute verbatim copies of this
// program provided the copyright notice and this permission notice are
// preserved on all copies.
//
// File: disasm.h 

/* standard clib */                     
# include <stdio.h> 
# include <stdlib.h>
# include <stdarg.h>
# include <string.h>
# include <ctype.h>

# define pr1ntf(x)         if(printMode==1)printf(x);else
# define pr2ntf(x,y)       if(printMode==1)printf(x,y);else
# define pr3ntf(x,y,z)     if(printMode==1)printf(x,y,z);else
# define pushTrace(z)      if(debugx>254) printTrace();else debugTab[debugx++]=z
# define popTrace()        debugx--
# define TOINT(u)          (int)(u)

typedef void               *LPVOID;
typedef char                CHAR;
typedef short               WCHAR;
typedef short               SHORT;
typedef long                LONG;
typedef unsigned short      USHORT;
typedef unsigned long       DWORD;
typedef unsigned long long  LONGLONG;
typedef LONGLONG           *PLONGLONG;
typedef int                 BOOL;
typedef unsigned char       BYTE;
typedef unsigned short      WORD;
typedef BYTE               *PBYTE;
typedef WORD               *PWORD;
typedef DWORD              *PDWORD;
typedef int boolean;    /* BOOLEAN is returned by a PREDICATE */

/* pedump hooks */
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

extern     IMAGE_SECTION_HEADER    shdr[];

/* yylex hooks */
extern  int        fsize;
extern  int        yyfirsttime;
extern  int        GotEof;
extern  PBYTE      yyfp, yypmax;

typedef struct __key_ {
int     class;
DWORD   c_pos;
DWORD   c_ref;
} _key_, *PKEY;

typedef struct _history{
short   m;     //nextMode
short   f;     //fatalError
short   l;     //number of labels deleted
DWORD   r;     //lastReset
DWORD   c;     //cur_position;
DWORD   s;     //eraseUncertain start
DWORD   e;     //eraseUncertain end
} history, *PHISTORY;

typedef struct __labels {
int     priority;
DWORD   ref;
} _labels;

typedef struct _node {
DWORD        pos1;
DWORD        pos2;
short        red;
short        rclass;
short        rcount;
struct _node *left;
struct _node *right;
} node, *PNODE;

typedef struct _node1 {
DWORD        pos2;
short        red;
short        rclass;
struct _node1 *left;
struct _node1 *right;
} node1, *PNODE1;

/* hooks to link pedump and decoder and printing */

extern LPVOID     lpFile;
extern LPVOID     lpMap;
extern LPVOID     lpMap1;
extern int        nSections;         // number of sections
extern DWORD      imagebaseRVA; /* image base of the file + code RVA */
extern int        CodeOffset;    /* starting point of code   */
extern int        CodeSize;      /* size of code             */
extern int        vCodeOffset;   /* starting point of code   */
extern int        vCodeSize;     /* size of code             */
extern int        MapSize;       /* size of code map         */
extern DWORD      maxRVA;        /* the largest RVA of sections */
extern int        maxRVAsize;    /* size of that section */

extern int        jLc;
extern int        addLabelsNum;
extern int        ErrorRecoverNum;
extern int        eraseUncertainNum;
extern int        resetNum;
extern int        totZero;
extern int        needJump;              // well it is return or jmp instruction
extern DWORD      needJumpNext;          // possible instruction after return or jmp
extern int        needCall;              // it is call 
extern DWORD      needCallRef;          // the target of call
extern DWORD      needCallNext;          // position following call instruction
extern int        printCol;
extern int        moreprint;            // need to print more

extern char      *piNameBuff;   // import module name buffer
extern char      *pfNameBuff;   // import functions in the module name buffer
extern char      *peNameBuff;   // export function name buffer
extern char      *pmNameBuff;   // menu name buffer
extern char      *pdNameBuff;   // dialog name buffer
extern int        piNameBuffSize;       // import module name buffer
extern int        pfNameBuffSize;       // import functions in the module name buffer
extern int        peNameBuffSize;       // export function name buffer
extern int        pmNameBuffSize;   // menu name buffer
extern int        pdNameBuffSize;       // dialog name buffer

/* hooks to link disassembler and decoder and printing */
extern int        nextMode;
extern int        printMode;
extern DWORD      lastReset;
extern int        fatalError;
extern int        errorcount;          /* number of errors */
extern int        NumberOfBytesProcessed;
extern int        addressOveride;       /* address size overide  */
extern int        operandOveride;   /* operand size overide..*/
extern DWORD      label_start_pos;  /* label start position of case jump block */
extern DWORD      min_label; 
extern DWORD      cur_position;
extern int        dmc;
extern DWORD      dmLabels[];
extern int        labelClass;
extern int        finished;
extern int        a_loc;
extern int        a_loc_save;
extern int        i_col;
extern int        i_col_save;
extern int        i_psp;
extern int        prefixStack[];
extern int        opclass;
extern int        modclass;
extern int        i_opclass;
extern int        i_opcode;
extern int        i_mod;
extern int        opclassSave;
extern int        opsave;
extern int        modsave;
extern int        i_sib;
extern int        i_byte;
extern int        i_word;
extern int        i_dword;
extern int        m_byte;
extern int        needspacing;
extern int        byteaddress;
extern int        imb;
extern int        mbytes[];
extern int        stringBuf[];
extern int        m_dword;
extern DWORD      lastAnchor;
extern int        leaveFlag;
extern int        delta;


extern DWORD      imageBase;
extern DWORD      entryPoint; 
extern int        opcodeTable[]; 
extern int        opcode2Table[];
extern int        repeatgroupTable[];
extern int        modTable[];
extern int        mod16Table[];
extern int        sibTable[];
extern int        regTable[];
extern int        rmTable[];

extern int        debugx;
extern int        debugTab[];

/* for label processing */
extern int        hsize;
extern int        width;
extern LPVOID     headerS;
extern LPVOID     headerD;

// functions in pedump.c
int    pedump (int,char **);
LPVOID GetActualAddress (LPVOID,DWORD);

// functions in main.c
void  initDisassembler();
void  resetDisassembler(DWORD);
void  pushEnvironment();
void  popEnvironment();
void  showDots();
void  Disassembler();
void  Disassembler1();
void  markCodes();
void  ErrorRecover();
void  clearSomeBadGuy(PHISTORY);
void  checkZeros();
void  checkZeros1();
void  checkCrossing();
DWORD GetNextOne();
int   isThisGoodRef(DWORD,DWORD,DWORD);
int   tryToSaveIt(DWORD);
void  saveIt(DWORD);
int   isItStartAnyWay(DWORD);
void  trySomeAddress(DWORD);
void  tryAnyAddress();
int   tryMoreAddress    (DWORD,DWORD,PDWORD);
int   trySomeMoreAddress(DWORD,DWORD,PDWORD);
int   looksLikeMenus(DWORD);
void  showPascalString(DWORD);
void  showNullString(DWORD);
void  markStrings(DWORD,DWORD);
int   maybePartof(DWORD);
void  markAddress(DWORD,DWORD);
void  markAddress1(DWORD,DWORD);
void  tryPascalStrings();
void  checkOneInstructionFiller(DWORD);
void  changeToAddress(DWORD,DWORD);
void  changeToBytes(DWORD,DWORD);
void  changeToCode(DWORD,DWORD);
void  changeToDword(DWORD,DWORD);
void  changeToFloat(DWORD,DWORD);
void  changeToDouble(DWORD,DWORD);
void  changeToQuad(DWORD,DWORD);
void  changeTo80Real(DWORD,DWORD);
void  changeToWord(DWORD,DWORD);
void  changeToNullString(DWORD);
void  changeToPascalString(DWORD);
void  PostProcessing2(DWORD,DWORD);
int   checkWellDone(DWORD,DWORD);
void  PostProcessing1();
void  printTrace();
void  peekTrace();
void  MapSummary();
void  ReportMap();
void  reportHistory();
void  readHint();
int   stringCheck(int,DWORD,DWORD);
void  labelBody1(int,DWORD,DWORD);
void  labelPP(PNODE1,DWORD);
void  labelBody(PNODE);
void  labelP(PNODE);
void  LabelProcess();
void  xrefBody1(int,DWORD,DWORD);
void  xrefPP(PNODE1,DWORD);
void  xrefBody(PNODE);
void  xrefP(PNODE);
void  Xreference();
void  eraseUncertain(DWORD,PHISTORY);
void  eraseUncertain1(DWORD,PHISTORY);
void  eraseCarefully(DWORD,PHISTORY);
int   isLabelCheckable(DWORD);
void  setAddress(DWORD);
void  setAnyAddress(DWORD);
int   isItAnyAddress(DWORD);
int   touchAnyAddress(DWORD);
int   isAddressBlock(DWORD);
void  setFirstTime(DWORD);
int   isItFirstTime(DWORD);
void  MyBtreeInsertDual(int,DWORD,DWORD);
void  MyBtreeDeleteDual(int,DWORD,DWORD);
int   BadEnter(DWORD,DWORD);
void  EnterLabel(int,DWORD,DWORD);
void  markData(int,DWORD,DWORD);
void  DeleteLabels(DWORD);
int   isGoodAddress(DWORD);
DWORD AddressCheck(DWORD);
int   getNumExeSec ();
DWORD getOffset (DWORD);
DWORD getRVA (DWORD);
DWORD Get32Address(DWORD);
int   isThisSecure(DWORD);
int   isNotGoodJump(DWORD);
PBYTE toFile(DWORD);
BYTE  getByteFile(DWORD);
int   getIntFile(DWORD);
char* getSymbol(DWORD);
BYTE  getMap(DWORD);
void  setMap(DWORD,BYTE);
void  orMap(DWORD,BYTE);
void  exMap(DWORD,BYTE);
BYTE  getMap1(DWORD);
void  setMap1(DWORD,BYTE);
void  orMap1(DWORD,BYTE);
void  exMap1(DWORD,BYTE);
DWORD Get16_32Address(DWORD);
void  Myfinish();
void  initHeaders();
void  deleteTrees1(PNODE1);
void  deleteTrees(PNODE);
void  deleteHeaders();
PNODE1 searchTT1(PNODE1,DWORD);
PNODE1 searchTT(PNODE1,DWORD,DWORD);
PNODE searchT(PNODE,DWORD,DWORD);
PNODE searchTree(LPVOID,DWORD,DWORD);
PKEY searchBtree1(PKEY);
PKEY searchBtree3(PKEY);
PKEY searchBtreeX(PKEY);
int   referCount(DWORD);
int   referCount1(DWORD);
int   insertTree(LPVOID,int,DWORD,DWORD);
int   MyBtreeInsert(PKEY);
int   MyBtreeInsertX(PKEY);
int   MyBtreeInsertEx(PKEY);
int   deleteTree(LPVOID,DWORD,DWORD);
int   MyBtreeDelete(PKEY);
int   sortT(PNODE1,DWORD);
int   sortTree(PNODE);
int   sortTrees();
int   sortTrees1();
PNODE1 rotate1(PNODE1*,PNODE1,DWORD,DWORD);
PNODE  rotate (PNODE* ,PNODE, DWORD,DWORD);
int   insertTT(PNODE1*,int,DWORD,DWORD);
int   insertSecond(PNODE,int,DWORD,DWORD);
int   insertT (PNODE* ,int,DWORD,DWORD);
PNODE1 findSeed1(PNODE1*,DWORD,DWORD);
PNODE  findSeed (PNODE*, DWORD,DWORD);
void  make_leaf_red1(PNODE1*,DWORD,DWORD);
void  make_leaf_red (PNODE*, DWORD,DWORD);
int   deleteTT(PNODE1*,DWORD,DWORD);
int   deleteT (PNODE*, DWORD,DWORD);
int   heapLTE(_labels,_labels);
int   heapLT (_labels,_labels);
void  initHeap();
int   upHeap  (_labels a[], int);
void  downHeap(_labels a[], int,int);
_labels  getHeap(int*);
int   putHeap(int*,int,DWORD);
int   getLabels();
void  addRef(int,DWORD,DWORD);
int   countRef(DWORD);
void  addLabels(DWORD,int);

// functions in decoder.c
int instruction(int c);
int databody(int c);
int labeldata();
int worddata();
int instructionbody();
int byte();
int bytex();
int op();
int pascalstring();
int nullstring();
int word();
int dword();
int adword();
int wdword();
int pword();
int prefixes();
int onebyteinstr();
int twobyteinstr();
int modrm();
int modrm1();
int modrm2();
int sib();
int labelstartposition();
int label1();
int opext();
int opextg();
int ReadOneByte();
int PeekOneByte();
int PeekSecondByte();

// functions in print.c
int  print_m_byte();
int  print_m_dword();
int  print_i_byte();
int  print_i_byte32();
int  print_i_dword();
int  print_i_word();
int  print_rel8();
int  print_rel32();
int  print_moff();
int  r___(int);
int  mm____();
int  rm_m32 (int);
int  rm_m16 (int);
int  reg_s ();
int  base();
int  scaledindex();
void specifier (int);
int  prefix();
int  r_m_  (int);
int  r_m_32  (int);
int  r_m_16  (int);
int  Sreg__();
int  m16_32();
int  m32_32();
int  m_____();
void nmonicprint();
int addressfix();
int addressprint1(int);
int addressprint();
int bodyprint(int);
int bodyprint0();
int bodyprint1();
int bodyprint2();
int bodyprint21();
int bodyprint3();
int bodyprint4();
int bodyprint5();
int bodyprint6();
int isEntry(DWORD);
int GotName(int,DWORD,DWORD);
int printName(DWORD);
int printExportName1(DWORD);
int printExportName();
int printEntryMark();
int printLabelMark();
int printDataMark();
int printString();
int print0case(); 
int print1case();
int print2case();
int print3case();
int print4case();
int print5case();
int print6case(); 
int print7case();
int print8case();
int print9case();
int print10case();
int print11case();
int print12case();
int print13case();
int print14case();
int print15case();
int print16case();
int print20case();
int print21case();
int print22case();
int print23case();
int print24case();
int print25case();

// functions in ieee.c
double ConvertFromIeeeExtended(PBYTE);

// Additional defines for readable code 

#define MAP_UNPROCESSED				0x00
#define MAP_INSTRUCTION_START			0x01
#define MAP_SUSPICIOUS_CODE			0x02
#define MAP_PROCESSED_INSTRUCTIONS		0x04
#define MAP_DATA				0x08
#define MAP_LABEL_HERE				0x10
#define MAP_LABEL_SET				0x20
#define MAP_ENTRY_SET				0x40
#define MAP_ANCHOR_SET				0x80


// functions in debug.c
extern int* hasDebug;
extern char* names;
extern int namesSize;
extern int getDebugInfo(char* fname);
extern char* getNonCode(DWORD data);
void print_ref(DWORD);
extern BOOL print_symbols;
