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
// File: decoder.c 


# define PREFIX 99
# define max_col 12

# include "disasm.h"

/* *********************************************************************** */
/* grammar control data                                   */
/* *********************************************************************** */

int opcodeTable[] = {
/*        0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F   */
/* -----------------------------------------------------------------------*/
/*00*/    6,  6,  6,  6,  1,  4,  0,  0,  6,  6,  6,  6,  1,  4,  0, -1,    
/*10*/    6,  6,  6,  6,  1,  4,  0,  0,  6,  6,  6,  6,  1,  4,  0,  0,    
/*20*/    6,  6,  6,  6,  1,  4, 99,  0,  6,  6,  6,  6,  1,  4, 99,  0,    
/*30*/    6,  6,  6,  6,  1,  4, 99,  0,  6,  6,  6,  6,  1,  4, 99,  0,    
/*40*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    
/*50*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    
/*60*/    0,  0,  6,  6, 99, 99, 99, 99,  4,  8,  1,  7,  0,  0,  0,  0,    
/*70*/    1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,    
/*80*/   10, 11, -1, 10,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  9,    
/*90*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  5, 15,  0,  0,  0,  0,    
/*A0*/   44, 44, 44, 44,  0,  0,  0,  0,  1,  4,  0,  0,  0,  0,  0,  0,    
/*B0*/    1,  1,  1,  1,  1,  1,  1,  1,  4,  4,  4,  4,  4,  4,  4,  4,    
/*C0*/   10, 10,  2,  0,  6,  6, 10, 11,  3,  0,  2,  0,  0,  1,  0,  0,    
/*D0*/    9,  9,  9,  9,  1,  1, -1,  0, 12, 12, 12, 12, 12, 12, 12, 12,    
/*E0*/    1,  1,  1,  1,  1,  1,  1,  1,  4,  4,  5,  1,  0,  0,  0,  0,    
/*F0*/    0,  0, 16, 16,  0,  0, 14, 14,  0,  0,  0,  0,  0,  0,  9, 13};    
/* -----------------------------------------------------------------------*/

int opcode2Table[] = {
/*        0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F   */
/* -----------------------------------------------------------------------*/
/*00*/    4,  4,  2,  2, -1, -1,  0, -1,  0,  0, -1,  0, -1, -1, -1, -1,    
/*10*/   -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,    
/*20*/    2,  2,  2,  2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,    
/*30*/    0,  0,  0,  0,  0,  0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,    
/*40*/    2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,    
/*50*/   -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,    
/*60*/    2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2, -1, -1,  2,  2,    
/*70*/   -1,  5,  5,  5,  2,  2,  2,  0, -1, -1, -1, -1, -1, -1,  2,  2,    
/*80*/    1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,    
/*90*/    2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,    
/*A0*/    0,  0,  0,  2,  3,  2, -1, -1,  0,  0,  0,  2,  3,  2,  4,  2,    
/*B0*/    2,  2,  2,  2,  2,  2,  2,  2, -1, -1,  5,  2,  2,  2,  2,  2,    
/*C0*/    2,  2, -1, -1, -1, -1, -1,  4,  0,  0,  0,  0,  0,  0,  0,  0,    
/*D0*/   -1,  2,  2,  2, -1,  2, -1, -1,  2,  2, -1,  2,  2,  2, -1,  2,    
/*E0*/   -1,  2,  2, -1, -1,  2, -1, -1,  2,  2, -1,  2,  2,  2, -1,  2,    
/*F0*/   -1,  2,  2,  2, -1,  2, -1, -1,  2,  2,  2, -1,  2,  2,  2, -1};
/* -----------------------------------------------------------------------*/

int repeatgroupTable[] = {
/*        0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F   */
/* -----------------------------------------------------------------------*/
/*00*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    
/*10*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    
/*20*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    
/*30*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    
/*40*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    
/*50*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    
/*60*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  2,  2,  2,  2,    
/*70*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    
/*80*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    
/*90*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    
/*A0*/    0,  0,  0,  0,  2,  2,  1,  1,  0,  0,  2,  2,  2,  2,  1,  1,    
/*B0*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    
/*C0*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    
/*D0*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    
/*E0*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    
/*F0*/    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0};    
/* -----------------------------------------------------------------------*/

int modTable[] = {
/*        0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F   */
/* -----------------------------------------------------------------------*/
/*00*/    1,  1,  1,  1,  2,  3,  1,  1,  1,  1,  1,  1,  2,  3,  1,  1,    
/*10*/    1,  1,  1,  1,  2,  3,  1,  1,  1,  1,  1,  1,  2,  3,  1,  1,    
/*20*/    1,  1,  1,  1,  2,  3,  1,  1,  1,  1,  1,  1,  2,  3,  1,  1,    
/*30*/    1,  1,  1,  1,  2,  3,  1,  1,  1,  1,  1,  1,  2,  3,  1,  1,    
/*40*/    4,  4,  4,  4,  5,  4,  4,  4,  4,  4,  4,  4,  5,  4,  4,  4,    
/*50*/    4,  4,  4,  4,  5,  4,  4,  4,  4,  4,  4,  4,  5,  4,  4,  4,    
/*60*/    4,  4,  4,  4,  5,  4,  4,  4,  4,  4,  4,  4,  5,  4,  4,  4,    
/*70*/    4,  4,  4,  4,  5,  4,  4,  4,  4,  4,  4,  4,  5,  4,  4,  4,    
/*80*/    6,  6,  6,  6,  7,  6,  6,  6,  6,  6,  6,  6,  7,  6,  6,  6,    
/*90*/    6,  6,  6,  6,  7,  6,  6,  6,  6,  6,  6,  6,  7,  6,  6,  6,    
/*A0*/    6,  6,  6,  6,  7,  6,  6,  6,  6,  6,  6,  6,  7,  6,  6,  6,    
/*B0*/    6,  6,  6,  6,  7,  6,  6,  6,  6,  6,  6,  6,  7,  6,  6,  6,    
/*C0*/    8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,    
/*D0*/    8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,    
/*E0*/    8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,    
/*F0*/    8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8};    
/* -----------------------------------------------------------------------*/

int mod16Table[] = {
/*        0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F   */
/* -----------------------------------------------------------------------*/
/*00*/    1,  1,  1,  1,  1,  1,  2,  1,  1,  1,  1,  1,  1,  1,  2,  1,    
/*10*/    1,  1,  1,  1,  1,  1,  2,  1,  1,  1,  1,  1,  1,  1,  2,  1,    
/*20*/    1,  1,  1,  1,  1,  1,  2,  1,  1,  1,  1,  1,  1,  1,  2,  1,    
/*30*/    1,  1,  1,  1,  1,  1,  2,  1,  1,  1,  1,  1,  1,  1,  2,  1,    
/*40*/    3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,    
/*50*/    3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,    
/*60*/    3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,    
/*70*/    3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,    
/*80*/    4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,    
/*90*/    4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,    
/*A0*/    4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,    
/*B0*/    4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,    
/*C0*/    5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,    
/*D0*/    5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,    
/*E0*/    5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,    
/*F0*/    5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5};    
/* -----------------------------------------------------------------------*/


int sibTable[] = {
/*        0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F   */
/* -----------------------------------------------------------------------*/
/*00*/    2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2,    
/*10*/    2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2,    
/*20*/    2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2,    
/*30*/    2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2,    
/*40*/    2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2,    
/*50*/    2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2,    
/*60*/    2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2,    
/*70*/    2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2,    
/*80*/    2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2,    
/*90*/    2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2,    
/*A0*/    2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2,    
/*B0*/    2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2,    
/*C0*/    2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2,    
/*D0*/    2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2,    
/*E0*/    2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2,    
/*F0*/    2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2};    
/* -----------------------------------------------------------------------*/

int regTable[] = {
/*        0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F   */
/* -----------------------------------------------------------------------*/
/*00*/    0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  1,  1,  1,  1,    
/*10*/    2,  2,  2,  2,  2,  2,  2,  2,  3,  3,  3,  3,  3,  3,  3,  3,    
/*20*/    4,  4,  4,  4,  4,  4,  4,  4,  5,  5,  5,  5,  5,  5,  5,  5,    
/*30*/    6,  6,  6,  6,  6,  6,  6,  6,  7,  7,  7,  7,  7,  7,  7,  7,    
/*40*/    0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  1,  1,  1,  1,    
/*50*/    2,  2,  2,  2,  2,  2,  2,  2,  3,  3,  3,  3,  3,  3,  3,  3,    
/*60*/    4,  4,  4,  4,  4,  4,  4,  4,  5,  5,  5,  5,  5,  5,  5,  5,    
/*70*/    6,  6,  6,  6,  6,  6,  6,  6,  7,  7,  7,  7,  7,  7,  7,  7,    
/*80*/    0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  1,  1,  1,  1,    
/*90*/    2,  2,  2,  2,  2,  2,  2,  2,  3,  3,  3,  3,  3,  3,  3,  3,    
/*A0*/    4,  4,  4,  4,  4,  4,  4,  4,  5,  5,  5,  5,  5,  5,  5,  5,    
/*B0*/    6,  6,  6,  6,  6,  6,  6,  6,  7,  7,  7,  7,  7,  7,  7,  7,    
/*C0*/    0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  1,  1,  1,  1,    
/*D0*/    2,  2,  2,  2,  2,  2,  2,  2,  3,  3,  3,  3,  3,  3,  3,  3,    
/*E0*/    4,  4,  4,  4,  4,  4,  4,  4,  5,  5,  5,  5,  5,  5,  5,  5,    
/*F0*/    6,  6,  6,  6,  6,  6,  6,  6,  7,  7,  7,  7,  7,  7,  7,  7};    
/* -----------------------------------------------------------------------*/

int rmTable[] = {
/*        0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F   */
/* -----------------------------------------------------------------------*/
/*00*/    0,  1,  2,  3,  4,  5,  6,  7,  0,  1,  2,  3,  4,  5,  6,  7,    
/*10*/    0,  1,  2,  3,  4,  5,  6,  7,  0,  1,  2,  3,  4,  5,  6,  7,    
/*20*/    0,  1,  2,  3,  4,  5,  6,  7,  0,  1,  2,  3,  4,  5,  6,  7,    
/*30*/    0,  1,  2,  3,  4,  5,  6,  7,  0,  1,  2,  3,  4,  5,  6,  7,    
/*40*/    0,  1,  2,  3,  4,  5,  6,  7,  0,  1,  2,  3,  4,  5,  6,  7,    
/*50*/    0,  1,  2,  3,  4,  5,  6,  7,  0,  1,  2,  3,  4,  5,  6,  7,    
/*60*/    0,  1,  2,  3,  4,  5,  6,  7,  0,  1,  2,  3,  4,  5,  6,  7,    
/*70*/    0,  1,  2,  3,  4,  5,  6,  7,  0,  1,  2,  3,  4,  5,  6,  7,    
/*80*/    0,  1,  2,  3,  4,  5,  6,  7,  0,  1,  2,  3,  4,  5,  6,  7,    
/*90*/    0,  1,  2,  3,  4,  5,  6,  7,  0,  1,  2,  3,  4,  5,  6,  7,    
/*A0*/    0,  1,  2,  3,  4,  5,  6,  7,  0,  1,  2,  3,  4,  5,  6,  7,    
/*B0*/    0,  1,  2,  3,  4,  5,  6,  7,  0,  1,  2,  3,  4,  5,  6,  7,    
/*C0*/    0,  1,  2,  3,  4,  5,  6,  7,  0,  1,  2,  3,  4,  5,  6,  7,    
/*D0*/    0,  1,  2,  3,  4,  5,  6,  7,  0,  1,  2,  3,  4,  5,  6,  7,    
/*E0*/    0,  1,  2,  3,  4,  5,  6,  7,  0,  1,  2,  3,  4,  5,  6,  7,    
/*F0*/    0,  1,  2,  3,  4,  5,  6,  7,  0,  1,  2,  3,  4,  5,  6,  7};    
/* -----------------------------------------------------------------------*/

/* *********************************************************************** */
/* hooks between disassembler and printing                                 */
/* *********************************************************************** */
int a_loc=0;
int a_loc_save=0;
int i_col=0;
int i_col_save=0;
int i_psp=0;
int prefixStack[8];
int opclass;
int modclass;
int i_opclass;        
int i_opcode;
int i_mod;
int opclassSave=-1;
int opsave=-1;
int modsave=-1;
int i_sib;
int i_byte;
int i_word;
int i_dword;
int m_byte;
int m_dword;
int needspacing=0;
int byteaddress=0;
int stringBuf[4096];
int imb=0;
int mbytes[64];
int NumberOfBytesProcessed=-1;  // we need to keep track of bytes processed.
                              // I don't know why I need to start from -1.... but anyway
                             // this is needed to process
int addressOveride=0;       // prefix 0x64
int operandOveride=0;      // this is needed to process
                          // prefix 0x66: operand size overide

DWORD label_start_pos;     /* labe start position of case jump block */
DWORD min_label; 
DWORD cur_position;
int   labelClass;
int   finished;
DWORD lastAnchor=0;
int   leaveFlag=0;
int   delta=0;

int   result=0;

/* *********************************************************************** */
/* Original Part of grammar generated sources                              */
/* *********************************************************************** */

int instruction(int c)
{
int  r;

   if (c==0)
   {    
      while(prefixes());
      r=instructionbody();
   }
   else r=databody(c);
   return r;
}
int databody(int c)
{
         if(c==1) return labeldata();
   else if (c==2) return bytex();
   else if (c==3) return byte();
   else if (c==4) return pascalstring();
   else if (c==5) return nullstring();
   else if (c==6) return worddata();
   else return 0;
}
int labeldata()
{
int r;
   r = dword();
   m_dword=result;
   return r;
}
int worddata()
{
int r;
   r = word();
   m_dword=result;
   return r;
}
int instructionbody()
{
int r;
   if (PeekOneByte()!=0x0F) 
               { r=onebyteinstr(); opclass=1; return r;} 
   else {byte(); r=twobyteinstr(); opclass=2; return r;}
}
int byte()
{
int x;
   x=ReadOneByte();
   if(printMode==1)printf("%02X", x);else;
   a_loc++;  i_col++;  result=x;
   return 1;
}
int bytex()
{
int x;
   x=ReadOneByte();
   m_byte=x;                                                                             
   a_loc++;  i_col++;  result=x;
   return 1;
}
int op()
{
int x;
   x=ReadOneByte();
   if(printMode==1)printf("%02X", x);else;
   a_loc++;  i_col++;  result=x;
   return 1;
}
int pascalstring()
{
int i, n, x;
    x=ReadOneByte();
    //if(printMode==1)printf("%02X ", x);else;
    a_loc++; i_col++; result=x;
    stringBuf[0]=x;      
    n=x;
    for(i=1;i<n+1;i++)
    { x=ReadOneByte(); //if(printMode==1)printf("%02X ", x);else; 
    a_loc++; i_col++; result=x; stringBuf[i]=x;}
    return 1;
}
int nullstring()
{
int i, x;
    i=0;
    while(1)
    { x=ReadOneByte(); //if(printMode==1)printf("%02X ", x);else; 
    a_loc++; i_col++; result=x; stringBuf[i++]=x; if(!isprint(PeekOneByte()))break;}
    while(getMap(cur_position+i_col)==0x08)
    {
        x=ReadOneByte(); //if(printMode==1)printf("%02X ", x);else; 
        stringBuf[i++]=x; a_loc++; i_col++; 
    }
    stringBuf[i]=-1;
    return 1;
}
int word()
{
int x,y;
   byte(); x=result;
   byte(); y=result;
   result=y*256+x;
   return 1;
}
int dword()
{
int x1,x2,x3,x4;
   byte(); x1=result;
   byte(); x2=result;
   byte(); x3=result;
   byte(); x4=result;
   result=((x4*256+x3)*256+x2)*256+x1;
   return 1;
}
int adword()
{
   if (addressOveride) return word(); else return dword();
}
int wdword()
{
   if (operandOveride) return word(); else return dword();
}
int pword()
{
int r;
   r=word();  if (!r) return 0; i_word=result;
   r=dword(); if (!r) return 0; i_dword=result;
   return 1;
}   
int prefixes()
{
int r;
   if (opcodeTable[PeekOneByte()]==PREFIX)
   {
      r=op(); if (!r) return 0; 
      prefixStack[i_psp++]=result;
      if (result==102) operandOveride=1;
      if (result==103) addressOveride=1;
      return 1;
   }
   else return 0;
}
int onebyteinstr()
{
int r, b, x, y, y1, y2;
   b=PeekOneByte();
   //fprintf(stderr, "b=%02X",b),getch();
   switch(opcodeTable[b])
   {
      case  0: r=op();     if(!r) return 0; x=result; 
               //fprintf(stderr, "x=%02X",x),getch();
               i_opclass=0; i_opcode=x;                
               break;
      case  1: r=op();     if(!r) return 0; x=result; 
               r=byte();   if(!r) return 0; y=result;
               i_opclass=1; i_opcode=x; i_byte=y;      
               break;
      case  2: r=op();     if(!r) return 0; x=result;
               r=word();   if(!r) return 0; y=result;
               i_opclass=2; i_opcode=x; i_word=y;      
               break;
      case  3: r=op();     if(!r) return 0; x=result;
               r=word();   if(!r) return 0; y1=result;
               r=byte();   if(!r) return 0; y2=result;
               i_opclass=3; i_opcode=x; i_word=y1; i_byte=y2; 
               break;
      case     4: r=op();     if(!r) return 0; x=result;
               r=wdword(); if(!r) return 0; y=result;
               i_opclass=4; i_opcode=x; i_dword=y;
               break;
      case 44: r=op();     if(!r) return 0; x=result;
               r=adword(); if(!r) return 0; y=result;
               i_opclass=4; i_opcode=x; i_dword=y;
               break;
      case  5: r=op();     if(!r) return 0; x=result;
               r=pword();  if(!r) return 0; 
               i_opclass=5; i_opcode=x; 
               break;
      case  6: r=op();     if(!r) return 0; x=result;
               r=modrm();  if(!r) return 0; 
               i_opclass=6; i_opcode=x; 
               break;
      case  7: r=op();     if(!r) return 0; x=result;
               r=modrm();  if(!r) return 0;
               r=byte();   if(!r) return 0; y=result;
               i_opclass=7; i_opcode=x; i_byte=y; 
               break;
      case  8: r=op();     if(!r) return 0; x=result;
               r=modrm();  if(!r) return 0;
               r=wdword(); if(!r) return 0; y=result;
               i_opclass=8; i_opcode=x; i_dword=y; 
               break;
      case  9: r=op();     if(!r) return 0; x=result;
               r=opext();  if(!r) return 0;
               i_opclass=9; i_opcode=x;  
               break;
      case 10: r=op();     if(!r) return 0; x=result;
               r=opext();  if(!r) return 0;
               r=byte();   if(!r) return 0; y=result;
               i_opclass=10; i_opcode=x; i_byte=y; 
               break;
      case 11: r=op();     if(!r) return 0; x=result;
               r=opext();  if(!r) return 0;
               r=wdword(); if(!r) return 0; y=result;
               i_opclass=11; i_opcode=x; i_dword=y; 
               break;
      case 12: r=op();     if(!r) return 0; x=result;
               r=opextg(); if(!r) return 0;
               i_opclass=12; i_opcode=x;  
               break;
      case 13: r=op();     if(!r) return 0; x=result; // case jump block
               b=PeekOneByte();
               if (b==36) 
               { 
                  b=PeekSecondByte();
                  if (rmTable[b]==5)
                  {
                     r=op(); if(!r) return 0; y1=result;
                     r=op(); if(!r) return 0; y2=result;
                     i_opclass=13;
                     i_opcode=x;
                     i_mod=y1;
                     i_sib=y2;
                     r=labelstartposition(); if(!r) return 0;
   // ..................................................................            
                     if (nextMode) 
                     {
                        r=label1(); 
                        finished=1;
                        if(!r) return 1;   // need to be careful ...
                     }
                     return 1;
                  }
               }
               //else
               {
                  b=PeekOneByte();
                  if (regTable[b]<7)
                  {
                     r=opext(); if(!r) return 0;
                     i_opclass=13; i_opcode=x;
                  }
                  else return 0;
               }
               break;
      case 14: r=op();     if(!r) return 0; x=result; // test group
               if (x==246)
               {
                  b=PeekOneByte();
                  if (regTable[b]==0)
                  {
                     r=opext();   if(!r) return 0;
                     r=byte();    if(!r) return 0; y=result;
                     i_opclass=14; i_opcode=x; i_byte=y;
                  }
                  else if (regTable[b]>1)
                  {
                     r=opext();   if(!r) return 0;
                     i_opclass=14; i_opcode=x;
                  }
                  else return 0;
               }
               else
               {
                  b=PeekOneByte();
                  if (regTable[b]==0)
                  {
                     r=opext();   if(!r) return 0;
                     r=wdword();    if(!r) return 0; y=result;
                     i_opclass=14; i_opcode=x; i_dword=y;
                  }
                  else 
                  {
                     r=opext();   if(!r) return 0;
                     i_opclass=14; i_opcode=x;
                  }
               }
               break;
      case 15: r=op();     if(!r) return 0; x=result; // wait group
               i_opclass=15; i_opcode=x;
               b=PeekOneByte();
               if (b==217)
               {
                  b=PeekSecondByte();
                  if (regTable[b]==6||regTable[b]==7)
                  {
                     r=op();    if(!r) return 0; y=result;
                     r=opext(); if(!r) return 0;
                     i_opcode=y; prefixStack[i_psp++]=x;
                  }
               }
               else if (b==219)
               {
                  b=PeekSecondByte();
                  if (b==226||b==227)
                  {
                     r=op();    if(!r) return 0; y1=result;
                     r=op();    if(!r) return 0; y2=result;
                     i_opcode=y1; i_mod=y2; prefixStack[i_psp++]=x;   
                  }
               }
               else if (b==221)
               {
                  b=PeekSecondByte();
                  if (regTable[b]==6||regTable[b]==7)
                  {
                     r=op();    if(!r) return 0; y=result;
                     r=opext(); if(!r) return 0;
                     i_opcode=y; prefixStack[i_psp++]=x;
                  }
               }
               else if (b==223)
               {
                  b=PeekSecondByte();
                  if (b==224)
                  {
                     r=op();    if(!r) return 0; y1=result;
                     r=op();    if(!r) return 0; y2=result;
                     i_opcode=y1; i_mod=y2; prefixStack[i_psp++]=x;
                  }
               }
               break;
      case 16: r=op();     if(!r) return 0; x=result; // repeat group
               if (x==242)
               {
                  while(prefixes());
                  b=PeekOneByte();
                  if (repeatgroupTable[b]==1)
                  {
                     r=op();      if(!r) return 0; y=result;
                     i_opclass=16; i_opcode=y; prefixStack[i_psp++]=x;
                  }
                  else return 0;
               }
               else
               {
                  while(prefixes());
                  b=PeekOneByte();
                  if (repeatgroupTable[b]>0)
                  {
                     r=op();      if(!r) return 0; y=result;
                     i_opclass=16; i_opcode=y; prefixStack[i_psp++]=x;  
                  }
                  else return 0;
               }
               break;
      default: return 0;
   }
   return 1;
}
int twobyteinstr()
{
int r, b, x, y;
   b=PeekOneByte();
   switch(opcode2Table[b])
   {
      case 0: r=op();     if(!r) return 0; x=result;
              i_opclass=0; i_opcode=x;
              break;
      case 1: r=op();     if(!r) return 0; x=result;
              r=adword(); if(!r) return 0; y=result;
              i_opclass=1; i_opcode=x; i_dword=y;
              break;
      case 2: r=op();     if(!r) return 0; x=result;
              r=modrm();  if(!r) return 0;
              i_opclass=2; i_opcode=x;
              break;
      case 3: r=op();     if(!r) return 0; x=result;
              r=modrm();  if(!r) return 0;
              r=byte();   if(!r) return 0; y=result;
              i_opclass=3; i_opcode=x; i_byte=y;
              break;
      case 4: r=op();     if(!r) return 0; x=result;
              r=opext();  if(!r) return 0;
              i_opclass=4; i_opcode=x;
              break;
      case 5: r=op();     if(!r) return 0; x=result;
              r=opext();  if(!r) return 0;
              r=byte();   if(!r) return 0; y=result;
              i_opclass=5; i_opcode=x; i_byte=y;
              break;
      default:
              return 0;
   }
   return 1;
}
int modrm()
{
        if (addressOveride==0) return modrm1();
   else if (addressOveride==1) return modrm2();
   else return 0;
}
int modrm1()
{
int  r, b, x, y, y1, y2;

   b=PeekOneByte();
   switch(modTable[b])
   {
      case 1: r=op();    if(!r) return 0; x=result;
              i_mod=x;
              break;
      case 2: r=op();    if(!r) return 0; x=result;
              r=op();    if(!r) return 0; y=result;
              i_mod=x;   i_sib=y;
              if (sibTable[y]==1)
              {
                 r=dword(); if(!r) return 0; y1=result;
                 m_dword=y1;
              }
              break;
      case 3: r=op();    if(!r) return 0; x=result;
              r=dword(); if(!r) return 0; y=result;
              i_mod=x;      m_dword=y;
              break;
      case 4: r=op();    if(!r) return 0; x=result;
              r=byte();  if(!r) return 0; y=result;
              i_mod=x;     m_byte=y;
              break;
      case 5: r=op();    if(!r) return 0; x=result;
              r=sib();   if(!r) return 0; y1=result;
              r=byte();  if(!r) return 0; y2=result;
              i_mod=x;     i_sib=y1; m_byte=y2;
              break;
      case 6: r=op();    if(!r) return 0; x=result;
              r=dword(); if(!r) return 0; y=result;
              i_mod=x;     m_dword=y;
              break;
      case 7: r=op();    if(!r) return 0; x=result;
              r=sib();   if(!r) return 0; y1=result;
              r=dword(); if(!r) return 0; y2=result;
              i_mod=x;     i_sib=y1; m_dword=y2;
              break;
      case 8: r=op();    if(!r) return 0; x=result;
              i_mod=x;
              break;
      default: return 0;
   }
   return 1;
}
int modrm2()
{
int  r, b, x, y;
   b=PeekOneByte();
   switch(mod16Table[b])
   {
      case 1: r=op();   if(!r) return 0; x=result;
              i_mod=x;
              break;
      case 2: r=op();   if(!r) return 0; x=result;
              r=word(); if(!r) return 0; y=result;
              i_mod=x;  m_dword=y;
              break;
      case 3: r=op();   if(!r) return 0; x=result;
              r=byte(); if(!r) return 0; y=result;
              i_mod=x;  m_byte=y;
              break;
      case 4: r=op();   if(!r) return 0; x=result;
              r=word(); if(!r) return 0; y=result;
              i_mod=x;  m_dword=y;
              break;
      case 5: r=op();   if(!r) return 0; x=result;
              i_mod=x;
              break;
      default: return 0;
   }
   return 1;
}
int sib()
{
   return byte();
}
int labelstartposition()
{
int r;
   r=dword(); if(!r) return 0;
   m_dword=result;
   label_start_pos=(DWORD)m_dword;
   opclass=1;
   if(nextMode>0)bodyprint0();
   return 1;
}
int label1()
{
DWORD r, rr, s;
   // I like to give this guy some more priority or power to overide some constraints
   // namely It is worth try to find label blocks.... I guess
   r=label_start_pos+4;s=r;
   while (isLabelCheckable(r))
   {
       rr=(DWORD)getIntFile(r);
       if (!isGoodAddress(rr)) return 1;
       i_col=4;
       pushTrace(305);
       if (nextMode>0) EnterLabel(166, rr, r); 
       popTrace();
       r+=4;
   }
   return 1;
}
int opext()
{
   return modrm();
}
int opextg()
{
   return opext();
}
//...................................................................

/* globals */

int             fatalError = 0;         // flow control
int             errorcount = 0;         // to use counting errors
int             GotEof=0;
int             yyfirsttime=1;
unsigned char   c;
PBYTE           yyfp, yypmax;

int ReadOneByte()
{
    if (yyfirsttime)
    {
        yyfirsttime=0; GotEof=0; 
        yyfp   = (PBYTE)((int)lpFile + vCodeOffset);
        yypmax = (PBYTE)((int)lpFile + CodeOffset + CodeSize);
    }                                                       
    if (GotEof) return EOF;
    c = *yyfp++;
    if (yyfp >= yypmax ) {GotEof = 1;}
    return (int)c;
}
int PeekOneByte()
{
    if (yyfirsttime) {
	c = *(PBYTE)((int)lpFile + vCodeOffset);
        return  (int) c;
    }
    if (GotEof) return EOF;
    if (yyfp >= yypmax ) return EOF; 
    else {
        c = *(yyfp);
	return (int) c;
    }
}
int PeekSecondByte()
{
    if (GotEof) return EOF;
    if (yyfp+1 >= yypmax ) return EOF; 
    else {
	c = *(yyfp+1);	
	return (int) c;
   }
}
