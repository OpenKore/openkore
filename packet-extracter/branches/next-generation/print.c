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
// File: print.c 

# define max_col 12
# define my_ON   0
# define my_OFF  1
# define WINAPI

# include "disasm.h"

LPVOID WINAPI TranslateFunctionName (char *);
void   WINAPI TranslateParameters (char **, char **, char **);
DWORD  Get32Address(DWORD);
int    isGoodAddress(DWORD);
DWORD  AddressCheck(DWORD);
int    isThisSecure(DWORD);
int    referCount(DWORD);
void   showDots();
void   e64toasc();

int gotJmpRef = 0;
int specifierFlag = my_OFF;
int lclass=0;
int  ref=0;
int dref=0;
int dmark=0;
int printCol=0;
int tempref[8]={0,};
int temppos[8]={0,};
int reg=-1;

char  *reg8String[] = {  "al",  "cl",  "dl",  "bl",  "ah",  "ch",  "dh",  "bh"};
char *reg16String[] = {  "ax",  "cx",  "dx",  "bx",  "sp",  "bp",  "si",  "di"};
char *reg32String[] = { "eax", "ecx", "edx", "ebx", "esp", "ebp", "esi", "edi"};
char *reg64String[] = { "mm0", "mm1", "mm2", "mm3", "mm4", "mm5", "mm6", "mm7"};
char *SregString [] = {  "es",  "cs",  "ss",  "ds",  "fs",  "gs",  "##",  "##"};
char *mod16String[] = {"bx+si","bx+di","bp+si","bp+di","si","di",  "bp",  "bx"};

/* *********************************************************************** */
/* Original Part of grammar generated data                                 */
/* *********************************************************************** */



int  print_m_byte()
{
    if (m_byte>127)     {pr2ntf("-%02X",256-m_byte);}
	else                {pr2ntf("+%02X",m_byte);}
    printCol+=3;
    return m_byte;
}
int  print_m_dword()
{
    if (addressOveride) {pr2ntf("%04X",m_dword);}
    else                {pr2ntf("%08X", m_dword);}
    if (addressOveride) printCol+=4; else printCol+=8;
	print_ref(m_dword);
    return m_dword;
}
int  print_i_byte()
{
    if (i_byte>127)     {pr2ntf("-%02X",256-i_byte);}
	else                {pr2ntf("%02X",i_byte);}
    if (i_byte>127) printCol+=3; else printCol+=2;
    return i_byte;
}
int  print_i_byte32()
{
int r;
    r = ((i_byte>127)?256-i_byte:i_byte);
    if (i_byte>127)
    {
        if (operandOveride||addressOveride) {pr2ntf("-%03X",r);}
        else                                {pr2ntf("-%03X",r);} printCol+=1;
    }
    else
    {
        if (operandOveride||addressOveride) {pr2ntf("%03X",r);} 
        else                                {pr2ntf("%03X",r);} 
    }
    if (operandOveride||addressOveride) printCol+=4; else printCol+=8;
    return r;
}


int  print_i_dword()
{

    if (operandOveride||addressOveride)     {pr2ntf("%04X", i_dword);}
    else                                    {pr2ntf("%08X", i_dword);}
    if (operandOveride||addressOveride) printCol+=4; else printCol+=8;
	
	print_ref(i_dword);

    return i_dword;
}
int  print_i_word()
{
    pr2ntf("%04X", i_word);
    printCol+=4;
    return i_word;
}
int  print_rel8()
{
    ref = cur_position + i_col + ((i_byte>127)?i_byte-256:i_byte);
     if (addressOveride)  {pr2ntf("%04X",ref);} 
	else                 {pr2ntf("%08X",ref);}
    {   if (i_opcode == 0xEB) lclass = 1; else lclass = 2; }
    if (addressOveride) printCol+=4; else printCol+=8;

	print_ref(ref);

    return ref;
}
int  print_rel32()
{
    ref = cur_position + i_col + i_dword;
    if (addressOveride)  {pr2ntf("%04X",ref);} 
	else                 {pr2ntf("%08X",ref);}
    if (addressOveride) printCol+=4; else printCol+=8;

	print_ref(ref);

    return ref;
}


void print_ref_real(DWORD ref) {
 char* sym = getNonCode(ref);
 if(sym==NULL) {
	 sym = getSymbol(ref);
 }
 if(sym!=NULL) {
	 pr2ntf(" {%s} ",sym);
 }
}

void print_import(DWORD addr);

BOOL print_symbols = 0;

void print_ref(DWORD ref) {
	DWORD r;
    if(!print_symbols) return;

	print_ref_real(ref);
	r = getOffset(ref);
	if((r>0) && (r<fsize-4)) { 
		print_ref_real(*(PDWORD)((int)r+(int)lpFile));
		print_import(*(PDWORD)((int)r+(int)lpFile));
	} 
}


int  print_moff()
{
    prefix();
    if(addressOveride)  {pr2ntf("[%04X]",i_dword);}
    else                
	{
		pr2ntf("[%08X]",i_dword);
		print_ref(i_dword);
	}
    if (addressOveride) printCol+=6; else printCol+=10;
    return i_dword;
}
int  r___(int n)
{
    switch(n)
    {
        case  8: pr2ntf("%s", reg8String [regTable[i_mod]]); break;
        case 16: pr2ntf("%s", reg16String[regTable[i_mod]]); break;
        case 32: pr2ntf("%s", reg32String[regTable[i_mod]]); break;
        case 64: pr2ntf("%s", reg64String[regTable[i_mod]]); break;
        default: fatalError=100;
    }
    return i_mod;
}
int  mm____()
{
    pr2ntf("%s", reg64String[regTable[i_mod]]);
    return i_mod;
}
int  mmm___()
{
    pr2ntf("%s", reg64String[rmTable[i_mod]]);
    return i_mod;
}
int  rm_m32 (n)
int n;
{
    switch(n)
    {
        case  8: pr2ntf("%s", reg8String [rmTable[i_mod]]); printCol+=2; break;
        case 16: pr2ntf("%s", reg16String[rmTable[i_mod]]); printCol+=2; break;
        case 32: pr2ntf("%s", reg32String[rmTable[i_mod]]); printCol+=3; break;
        case 64: pr2ntf("%s", reg64String[rmTable[i_mod]]); printCol+=3; break;
        default: fatalError=101;
    }
    return i_mod;
}
int  rm_m16 (n)
int n;
{
    pr2ntf("%s", mod16String[rmTable[i_mod]]); 
    printCol+=strlen(mod16String[rmTable[i_mod]]);
    return i_mod;
}
int  reg_s ()
{
    pr2ntf("%s", reg32String[regTable[i_sib]]);
    printCol+=strlen(reg32String[regTable[i_sib]]);
    return i_sib;
}
int  base()
{
    pr2ntf("%s", reg32String[rmTable[i_sib]]);
    printCol+=strlen(reg32String[rmTable[i_sib]]);
    return i_sib;
}
int  scaledindex()
{
int c;
    c=modTable[i_sib];
    c=c/2;
    if (c>0) c--;
    switch(c)     /* now c is SS of sib byte */
    {
        case  0:               reg_s();              break;
        case  1: pr1ntf("2*"); reg_s(); printCol+=2; break;
        case  2: pr1ntf("4*"); reg_s(); printCol+=2; break;
        case  3: pr1ntf("8*"); reg_s(); printCol+=2; break;
        default: fatalError=103;
    }
    return i_sib;
}
void specifier (n)
int n;
{ 
    if (nextMode) return;
    switch(n)
    {
        case  8: pr1ntf("byte");  printCol+=4; break;
        case 16: pr1ntf("word");  printCol+=4; break;
        case 32: pr1ntf("dword"); printCol+=5; break;
        case 64: pr1ntf("qword"); printCol+=5; break;
        default: ;  //assert(false);
    }
    prefix();
}

int  prefix()
{
    if (i_psp>1)
    {
                 if  (prefixStack[i_psp-2] ==  38)
            {    pr1ntf (" es:");   printCol+=4;  }
            else if  (prefixStack[i_psp-2] ==  46)
            {    pr1ntf (" cs:");   printCol+=4;  }
            else if  (prefixStack[i_psp-2] ==  54)
            {    pr1ntf (" ss:");   printCol+=4;  }
            else if  (prefixStack[i_psp-2] ==  62)
            {    pr1ntf (" ds:");   printCol+=4;  }
            else if  (prefixStack[i_psp-2] == 100)
            {    pr1ntf (" fs:");   printCol+=4;  }
            else if  (prefixStack[i_psp-2] == 101)
            {    pr1ntf (" gs:");   printCol+=4;  }
    }
	if (i_psp>0)
    {
                 if  (prefixStack[i_psp-1] ==  38)
            {    pr1ntf (" es:");   printCol+=4;  }
            else if  (prefixStack[i_psp-1] ==  46)
            {    pr1ntf (" cs:");   printCol+=4;  }
            else if  (prefixStack[i_psp-1] ==  54)
            {    pr1ntf (" ss:");   printCol+=4;  }
            else if  (prefixStack[i_psp-1] ==  62)
            {    pr1ntf (" ds:");   printCol+=4;  }
            else if  (prefixStack[i_psp-1] == 100)
            {    pr1ntf (" fs:");   printCol+=4;  }
            else if  (prefixStack[i_psp-1] == 101)
            {    pr1ntf (" gs:");   printCol+=4;  }
    }    
	return 1;
}

int  r_m_  (n)
{
    if (addressOveride==0) return r_m_32(n);
    else return r_m_16(n);
}

int  r_m_32  (int n)
{
int    c, rr;

    rr=32;

    c=modTable[i_mod];
    switch(c)
    {
        case  1: specifier(n);
                 pr1ntf("["); ref = rm_m32(rr); pr1ntf("]");         
                 printCol+=2; return -1;
        case  2: specifier(n);
                 if (sibTable[i_sib]==1)  /* sib star */ 
                 {
                     pr1ntf("[");
                     if (regTable[i_sib]!=4)
                     {scaledindex(); pr1ntf("+"); gotJmpRef=1;} 
                     ref = print_m_dword(); pr1ntf("]");
                     printCol+=3;
                 }
                 else                     /* sib non star */
                 {
                     pr1ntf("["); base(); pr1ntf("+"); 
                     ref = scaledindex(); pr1ntf("]");
                     printCol+=3;
                 }
                 return ref;
        case  3: specifier(n);
                 pr1ntf("["); ref = print_m_dword(); pr1ntf("]"); 
                 printCol+=2; return ref;
        case  4: specifier(n);
                 pr1ntf("["); rm_m32(rr); 
                 print_m_byte(); pr1ntf("]");
                 printCol+=2; return -1;
        case  5: specifier(n);
                 pr1ntf("["); base();   
                 if (regTable[i_sib]!=4)
                 {pr1ntf("+"); scaledindex(); printCol+=1;} 
                 print_m_byte(); pr1ntf("]");
                 printCol+=2; return -1;
        case  6: specifier(n);
                 pr1ntf("["); rm_m32(rr); 
                 pr1ntf("+"); ref = print_m_dword(); pr1ntf("]");
                 printCol+=3; return ref;
        case  7: specifier(n);
                 pr1ntf("["); base(); pr1ntf("+"); 
                 if (regTable[i_sib]!=4)
                 {scaledindex(); pr1ntf("+"); printCol+=1;}  
                 ref = print_m_dword(); pr1ntf("]");
                 printCol+=3; return ref;
        case  8:
                 rm_m32(n);
                 return -1;
        default: fatalError=105;
    }
	return 1;
}

int  r_m_16  (n)
int n;
{
int    c, rr;

    rr=16; 

    c=mod16Table[i_mod];
    switch(c)
    {
        case  1: specifier(n);
                 pr1ntf("["); rm_m16(rr); pr1ntf("]");         
                 printCol+=2; return -1;
        case  2: specifier(n);
                 pr1ntf("["); ref = print_m_dword(); pr1ntf("]"); 
                 printCol+=2; return ref;
        case  3: specifier(n);
                 pr1ntf("["); rm_m16(rr); 
                 print_m_byte(); pr1ntf("]");
                 printCol+=2; return -1;
        case  4: specifier(n);
                 pr1ntf("["); rm_m16(rr); 
                 pr1ntf("+"); print_m_dword(); pr1ntf("]");
                 printCol+=3; return -1;
        case  5: 
                 rm_m32(n);
                 return -1;
        default: fatalError=105;
    }
	return 1;
}


int  Sreg__()
{
    pr2ntf("%s", SregString[regTable[i_mod]]);
    printCol+=strlen(SregString[regTable[i_mod]]);
    return i_mod;
}
int  m16_32()
{
    pr1ntf("m16:m32"); ref = r_m_ ( 0);
    printCol+=7;
    return ref;
}
int  m32_32()
{
    pr1ntf("m32:m32"); ref = r_m_ ( 0);
    printCol+=7;
    return ref;
}
int  m_____()
{
int    rr;

    if (operandOveride||addressOveride) rr=16; else rr=32;

    return r_m_ (rr);
}

void nmonicprint()
{
    if (opclass==1) 
    {
        switch(i_opclass)
        {
            case  0: print0case();
                     break;
            case  1: print1case();
                     break;
            case  2: print2case();
                     break;
            case  3: print3case();
                     break;
            case  4: print4case();
                     break; 
            case  5: print5case();
                     break;
            case  6: print6case();
                     break;
            case  7: print7case();
                     break;
            case  8: print8case();
                     break;
            case  9: print9case();
                     break;
            case 10: print10case();
                     break;
            case 11: print11case();
                     break;
            case 12: print12case();
                     break;
            case 13: print13case();   
                     break;
            case 14: print14case();
                     break;
            case 15: print15case();
                     break;
            case 16: print16case();
                     break;
            default: ; // assert(false);
        }
    }
    else 
    {   
        switch(i_opclass)
        {
            case  0: print20case();
                     break;
            case  1: print21case();
                     break;
            case  2: print22case();
                     break;
            case  3: print23case();
                     break;
            case  4: print24case();
                     break;
            case  5: print25case();
                     break;
            default: ; //assert(false);
        }
    }    
} /* end of nmonicprint() */


int addressfix()
{
    //if (GotEof) return 0;
    if (0<NumberOfBytesProcessed) a_loc = NumberOfBytesProcessed;
    cur_position = getRVA(CodeOffset + a_loc + delta)+imageBase;
    i_mod=0; i_dword=0; m_dword=0;
    return 1;
} /* end of addressprint() */

int addressprint1(int c)
{
static int cc=0;
int        d, dd;
BYTE       b;
char*	   symbol;

    if (GotEof) return 0;    
    //if (nextMode)     return 0;
    if (c>1)  d=1; else  d=c;
    if (cc>1)dd=1; else dd=cc;
    
    if (c!=cc && cc==2 && imb >0)
    {
        bodyprint21(); 
        needspacing=0; imb=0;
        showDots();
    }

    if (d!=dd)
    {
        pr1ntf("\n"); needspacing=0; imb=0;
        showDots();
    }
    else 
    {
        if (needspacing){ pr1ntf("\n"); needspacing=0; }
    }

    
    if (cur_position==entryPoint+imageBase)
        {pr1ntf("\n//******************** Program Entry Point ********");}

    
	symbol = getSymbol(cur_position);
	if(symbol!=NULL) {
		pr2ntf("\n\nDEBUG :: %s",symbol); 
	}
	b=getMap(cur_position); 
         if (b & MAP_ANCHOR_SET)  printExportName();
    else if (b & MAP_ENTRY_SET)  printEntryMark();
    else if (b==0x2F) printDataMark();
    else if (b==0x2E) printDataMark();
    else if (b==0x2D) printDataMark();
    else if (b&0x20)  printLabelMark();

    if (c!=cc)
    {
        pr2ntf("\n:%08X ", (int)cur_position);
    }
    else 
    {
        if (c<2)
        {pr2ntf("\n:%08X ", (int)cur_position);}
        else if (imb==0)
        { 
            pr2ntf("\n:%08X ", (int)cur_position);
            imb=0;
        }
    }
    cc=c;
    return 1;
} /* end of addressprint() */

int addressprint()
{
    addressfix();
    addressprint1(1);
    return 1;
}

int bodyprint(int c)
{
         if (c==0) bodyprint0();
    else if (c==1) bodyprint1();
    else if (c==2) bodyprint2();
    else if (c==3) bodyprint3();
    else if (c==4) bodyprint4();
    else if (c==5) bodyprint5();
    else if (c==6) bodyprint6();
	return 1;
}

int bodyprint0()
{
int            i,r;
    
    if (GotEof) return 0; 
    if (finished) {finished=0; return 1;}

    r=cur_position;

    //if (nextMode==0)
    for(i=i_col;i<max_col;i++)pr1ntf("  ");

    nmonicprint();

    if (nextMode)
    {
        pushTrace(303);
        if (lclass) EnterLabel(lclass, ref, cur_position);
        popTrace();
        //if (dmc)   fatalError=999,dmc=0;
    }
    else
    {
        if (getMap(r)&0x10) printString();
    }

    lclass = 0;
    ref   = 0;
    dref   = 0;
    a_loc_save=a_loc;
    i_col_save=i_col;
    i_psp=0; 
    i_col=0;
    addressOveride = 0;
    operandOveride = 0;
    printCol = 0;

    return 1;
}

int bodyprint1()
{
int       i, j, n;
    
    if (GotEof) return 0; 

    pushTrace(302);
    if (nextMode>0)
    EnterLabel(166, m_dword, cur_position);
    else
    {
		for(i=i_col;i<max_col;i++)pr1ntf("  ");
        pr2ntf ("DWORD %08X", m_dword); 

		print_ref(m_dword);

		printCol = 14; 
        for(i=printCol;i<26;i++)pr1ntf(" ");
        n=m_dword; pr1ntf(";; "); 
        j=n%256; n/=256; if(isprint(j)){pr2ntf("%c",j);}else {pr1ntf(".");}
        j=n%256; n/=256; if(isprint(j)){pr2ntf("%c",j);}else {pr1ntf(".");}
        j=n%256; n/=256; if(isprint(j)){pr2ntf("%c",j);}else {pr1ntf(".");} 
                         if(isprint(n)){pr2ntf("%c",n);}else {pr1ntf(".");}
    }
    popTrace();

    lclass = 0;
    ref   = 0;
    dref   = 0;
    a_loc_save=a_loc;
    i_col_save=i_col;
    i_psp=0; 
    i_col=0;
    operandOveride = 0;
    printCol=0;
    return 1;
}

int bodyprint2()
{
static int   m=16;
BYTE         b;

    if ((b=getMap(cur_position))&0x30) dmark=cur_position;
   
    switch(lclass)
    {
        case 515: m=16; break;
        case 517: m=10; break;
        case 518: case 528: 
                  m= 8; break;
        case 524: m=4;
        default:  m=16;
    }

    mbytes[imb++]=m_byte;
    if (imb==m || (b=getMap(cur_position+1))==0x2F || b==0x1F) 
        bodyprint21();
    // this place is not good place to process EOF case but it is also very effective.
    //  May.19.1998 sang cho
    if (GotEof)
    { 
        bodyprint21();
        addressfix();
    }
    return 1;
}



int bodyprint21()
{
int           i, j;
unsigned char c;
double        d=0;
float         f;
char          s[256];
    
    //if (GotEof) return 0; 

    for(i=0;i<imb;i++)pr2ntf("%02X ",mbytes[i]);
    for(   ;i<16; i++)pr1ntf("   "); pr1ntf("  ");

    j=lclass;
    //for(i=i_col;i<max_col;i++)pr1ntf("  ");   
    //    if (j==515) 
    //{
    //}
    //else 
    if (j==517) 
    {
        e64toasc((PWORD)toFile(dmark),s,16);
        pr2ntf(";; %s",s); printCol+=26; if(d<0) printCol++; 
    }
    //else if (j==518) 
    //{
    //}
    else if (j==524)
    {
        f=*(float *)(toFile(dmark));
        if(f>=0.) {pr1ntf(";;  ");} else {pr1ntf(";; ");}
        pr2ntf("%e",f);
    }
    else if (j==528) 
    {
        d=*(double *)(toFile(dmark));
        if(d>=0.) {pr1ntf(";;  ");} else {pr1ntf(";; ");}
        pr2ntf("%23.16e",d); printCol+=26; if(d<0) printCol++; 
    }
    else            
    {
        for(i=0;i<imb;i++)pr2ntf("%c",isprint(c=mbytes[i])?c:'.');
    }
    if (getMap(cur_position+1)==0x1F); else lclass=0;

    imb   = 0;
    //lclass = 0;
    ref   = 0;
    dref   = 0;
    dmark  = 0;
    a_loc_save=a_loc;
    i_col_save=i_col;
    i_psp=0; 
    i_col=0;
    operandOveride = 0;
    return 1;
}


int bodyprint3()
{
    if (GotEof) return 0; 
    
    imb++;
    
    lclass = 0;
    ref   = 0;
    dref   = 0;
    a_loc_save=a_loc;
    i_col_save=i_col;
    i_psp=0; 
    i_col=0;
    operandOveride = 0;
    return 1;
}

int bodyprint4()
{
int  i, j, n;
    
    if (GotEof) return 0; 
    
    n=stringBuf[0];j=0;
    for (i=0;i<n+1;i++)
    {if(j++==16) {pr1ntf("\n          ");j=1;}pr2ntf("%02X ",stringBuf[i]);} 
    for(i=j;i<max_col+4;i++)pr1ntf("   "); pr1ntf("  ");
    pr2ntf (";;p %c",'"');

    n=stringBuf[0];
    for (i=1;i<n+1;i++)pr2ntf("%c",stringBuf[i]);
    pr2ntf("%c",'"');

    lclass = 0;
    ref   = 0;
    dref   = 0;
    a_loc_save=a_loc;
    i_col_save=i_col;
    i_psp=0; 
    i_col=0;
    operandOveride = 0;
    return 1;
}

int bodyprint5()
{
int  i, j;

    if (GotEof) return 0; 
    
    i=0; j=0;
    while(stringBuf[i]>-1)
    {if(j++==16) {pr1ntf("\n          ");j=1;}pr2ntf("%02X ",stringBuf[i++]);}
    for(i=j;i<max_col+4;i++)pr1ntf("   "); pr1ntf("  ");
    pr2ntf (";;n %c",'"');
    i=0;
    while(isprint(stringBuf[i])) pr2ntf("%c",stringBuf[i++]);
    pr2ntf("%c",'"');
    
    lclass = 0;
    ref   = 0;
    dref   = 0;
    a_loc_save=a_loc;
    i_col_save=i_col;
    i_psp=0; 
    i_col=0;
    operandOveride = 0;
    return 1;
}

int bodyprint6()
{
int       i, j, n;
    
    if (GotEof) return 0; 

    pushTrace(392);
    if (nextMode>0);
    else
    {
        for(i=i_col;i<max_col;i++) pr1ntf("  ");
        pr2ntf ("WORD %04X", m_dword); printCol = 9; 
        for(i=printCol;i<26;i++) pr1ntf(" ");
        n=m_dword; pr1ntf(";; "); 
        j=n%256; n/=256; if(isprint(j)) {pr2ntf("%c",j);} else {pr1ntf(".");}
                         if(isprint(n)) {pr2ntf("%c",n);} else {pr1ntf(".");}
    }
    popTrace();
    
    lclass = 0;
    ref   = 0;
    dref   = 0;
    a_loc_save=a_loc;
    i_col_save=i_col;
    i_psp=0; 
    i_col=0;
    operandOveride = 0;
    printCol=0;
    return 1;
}

int isEntry(DWORD pos)
{
BYTE   b=getMap(pos);

    if (isGoodAddress(pos)
        &&((b&0x40)==0x40)) return 1;
    else return 0;
}

int GotName(int class, DWORD pos, DWORD pos1)
{
    int    i;
	int    r;
    char  *p;
    _key_  k;
    PKEY   pk;
				
	r=((int)pos);
    if ((int)lpFile<r&&r<(int)lpFile+fsize)
    {
        k.c_ref=pos; k.c_pos=-1; k.class=0;
        pk = searchBtreeX(&k);
        
        if ((pk!=NULL)&&((int)piNameBuff<=TOINT(pk->c_pos))
          &&(TOINT(pk->c_pos)<(int)piNameBuff+piNameBuffSize))
        {  
            pr1ntf("\n");
			for(i=0;i<28;i++)pr1ntf(" ");
            p=strtok((char *)(pk->c_pos),".");
            if (class<10) {pr2ntf(";;jmp %s",p);} else {pr2ntf(";;call %s",p);}
            pr1ntf(".");
            
            if (*(PBYTE)(r+2)==0x00 && *(PBYTE)(r+3)==0x80)
            {
                pr2ntf("Thunk:%04X",*(short *)r);
            }
            else
            {
                p=TranslateFunctionName((char *)r);
                pr2ntf("%s",p); 
            }
            return 1;
        }
    }
    if ((int)peNameBuff<r&&r<(int)peNameBuff+peNameBuffSize)
    {
        pr1ntf("\n");
		for(i=0;i<28;i++)pr1ntf(" ");
        p=TranslateFunctionName((char *)r);
        pr2ntf(";;%s",p);
        return 1;
    }
    if (isEntry(pos1) && ref!=pos1) 
    {
        pr2ntf(" ;; %08X",(int)pos1);

		print_ref(pos1);

        return 1;
    }
    return 0;
}

int printName(DWORD pos)
{
DWORD          r;
_key_          k, k1, k2, k3;
PKEY           pk;
int            found;
// this is very tricky.. i need to be extremely careful. oct.31,1997sangcho
        

        k.c_ref=pos; k.c_pos=-1; k.class=0;
        pk = searchBtree1(&k);

        if(pk==NULL) return 0;

        k1=*pk;  
		
		k.c_ref=k1.c_pos; k.c_pos=-1; k.class=0; 
		pk=searchBtreeX(&k);
		if (pk!=NULL) found=1;
		else found=0;
        
		if (found || AddressCheck(k1.c_pos))
        {
			char* symbol = getSymbol(k1.c_pos);
			if(symbol!=NULL) {
				printf(" {%s}",symbol);
			}

            r=k1.c_pos;
            k.c_ref=r;  k.c_pos=-1; k.class=0;
            
            pk = searchBtreeX(&k);
            
			if (pk!=NULL)
			{
			    return GotName(pk->class, pk->c_pos, k1.c_pos);
			}
			
			pk = searchBtree1(&k);
      
			if(pk==NULL) 
            {
                if (isEntry(k1.c_pos) && ref!=k1.c_pos) 
                {
                    pr2ntf(" ;; %08X",(int)(k1.c_pos));
					print_ref((int)(k1.c_pos));
                    return 1;
                }
                return 0; 
            }

            k2=*pk;
            k.c_ref=k2.c_pos; k.c_pos=-1; k.class=0;
            
            pk = searchBtreeX(&k);
            
            if(pk==NULL)
            {
                if (isEntry(k1.c_pos) && ref!=k1.c_pos) 
                {
                    pr2ntf(" ;; %08X",(int)(k1.c_pos));
					print_ref((int)(k1.c_pos));
                    return 1;
                }
                return 0; 
            }

            k3=*pk;
            return GotName(k3.class, k3.c_pos, k1.c_pos);
        }
       
        return 1;
}


int printExportName1(DWORD ref)
{
int            r;
_key_          k;
PKEY           pk;
PBYTE          p;
        
    k.c_ref=ref; k.c_pos=-1; k.class=0;
    pk = searchBtreeX(&k);
    if(pk==NULL) return 0;
    r=((int)(pk->c_pos));
    if ((int)peNameBuff<r&&r<(int)peNameBuff+peNameBuffSize)
    {
        p=TranslateFunctionName((char *)r);
        pr2ntf("%s",p);
    }
    return 1;
}

int printExportName()
{
BYTE          b, d;
    d=getByteFile(cur_position);
    if (d==0xC3) 
    {
        b=getMap(cur_position);
        if (b&0x40) return printEntryMark();
        if (b&0x20) return printLabelMark();
        return 1;
    }
    pr1ntf("\n=========\n");
    printExportName1(cur_position);
    pr1ntf("\n=========");
    return 1;
}

int printEntryMark()
{
    pr1ntf("\n=========");
	return 1;
}

int printLabelMark()
{
    pr1ntf("\n---------");
	return 1;
}

int printDataMark()
{
_key_          k;
PKEY           pk;
int            c;

    k.c_ref=cur_position; k.c_pos=-1; k.class=0;
    pk = searchBtree3(&k);
    if (pk==NULL) {pr1ntf("\n---------");return 1;}
    c=pk->class;  lclass=c;
         if (c==514) {pr1ntf("\n#########..DWORD..");}
    else if (c==515) {pr1ntf("\n#########..14/24bytes.");}
    else if (c==516) {pr1ntf("\n#########..WORD...");}
    else if (c==517) {pr1ntf("\n#########..80real..");}
    else if (c==518) {pr1ntf("\n#########..8bytes...");}
    else if (c==524) {pr1ntf("\n#########..32real.");}
    else if (c==528) {pr1ntf("\n#########..64real.");}
    else             {pr1ntf("\n#########");}
    return 1;
}

int printString()
{
DWORD          r;
_key_          k;
PKEY           pk;
PBYTE          p;
        
    k.c_ref=cur_position; k.c_pos=-1; k.class=0;
    pk = searchBtree1(&k);
    if(pk==NULL) return 0;
    r=pk->c_pos;
    p=toFile(r);
    pr1ntf("\n                      (StringData)");
	pr2ntf("%c",'"');
	
	while(isprint(*p) || ((*p==0)&&(*(p+2)==0)&&(*(p+1)!=0) )) {
		if(*p!=0) {
			pr2ntf("%c",*p);
		}
		p++;
	}

	if (*p==0x0D && *(p+1)==0x0A) {pr1ntf(" <cr><lf>");}
	else if (*p==0x0A) 
	{ 
	    pr1ntf(" <lf>");
	    if (*(p+1)==0x0A) {pr1ntf(" <lf>");}	
	} 
	else if (*p==0x09)
	{ 
	    pr1ntf(" <t>");
	    if (*(p+1)==0x09) {pr1ntf(" <t>");}
	}
	pr2ntf("%c",'"');
    return 1;
}

int print0case()  
{                 
    switch(i_opcode)
    {
        case 0x06:  pr1ntf("push es"); printCol+=7; break;   
        case 0x07:  pr1ntf("pop es");  printCol+=6; break;   
        case 0x0E:  pr1ntf("push cs"); printCol+=7; break;   
        case 0x16:  pr1ntf("push ss"); printCol+=7; break;     
        case 0x17:  pr1ntf("pop ss");  printCol+=6; break;    
        case 0x1E:  pr1ntf("push ds"); printCol+=7; break;     
        case 0x1F:  pr1ntf("pop ds");  printCol+=6; break;    
        case 0x27:  pr1ntf("daa");     printCol+=3; break; 
        case 0x2F:  pr1ntf("das");     printCol+=3; break;     
        case 0x37:  pr1ntf("aaa");     printCol+=3; break;     
        case 0x3F:  pr1ntf("aas");     printCol+=3; break;     
        case 0x40:  if (operandOveride){pr1ntf("inc ax"); printCol+=6;}
                    else               {pr1ntf("inc eax");printCol+=7;}
                    break;   
        case 0x41:  if (operandOveride){pr1ntf("inc cx"); printCol+=6;}
                    else               {pr1ntf("inc ecx");printCol+=7;}
                    break;   
        case 0x42:  if (operandOveride){pr1ntf("inc dx"); printCol+=6;}
                    else               {pr1ntf("inc edx");printCol+=7;}
                    break;     
        case 0x43:  if (operandOveride){pr1ntf("inc bx"); printCol+=6;}
                    else               {pr1ntf("inc ebx");printCol+=7;}
                    break;   
        case 0x44:  if (operandOveride){pr1ntf("inc sp"); printCol+=6;}
                    else               {pr1ntf("inc esp");printCol+=7;}
                    break;   
        case 0x45:  if (operandOveride){pr1ntf("inc bp"); printCol+=6;}
                    else               {pr1ntf("inc ebp");printCol+=7;}
                    break;   
        case 0x46:  if (operandOveride){pr1ntf("inc si"); printCol+=6;}
                    else               {pr1ntf("inc esi");printCol+=7;}
                    break;   
        case 0x47:  if (operandOveride){pr1ntf("inc di"); printCol+=6;}
                    else               {pr1ntf("inc edi");printCol+=7;}
                    break;  
        case 0x48:  if (operandOveride){pr1ntf("dec ax"); printCol+=6;}
                    else               {pr1ntf("dec eax");printCol+=7;}
                    break;   
        case 0x49:  if (operandOveride){pr1ntf("dec cx"); printCol+=6;}
                    else               {pr1ntf("dec ecx");printCol+=7;}
                    break;   
        case 0x4A:  if (operandOveride){pr1ntf("dec dx"); printCol+=6;}
                    else               {pr1ntf("dec edx");printCol+=7;}
                    break;     
        case 0x4B:  if (operandOveride){pr1ntf("dec bx"); printCol+=6;}
                    else               {pr1ntf("dec ebx");printCol+=7;}
                    break;   
        case 0x4C:  if (operandOveride){pr1ntf("dec sp"); printCol+=6;}
                    else               {pr1ntf("dec esp");printCol+=7;}
                    break;   
        case 0x4D:  if (operandOveride){pr1ntf("dec bp"); printCol+=6;}
                    else               {pr1ntf("dec ebp");printCol+=7;}
                    break;   
        case 0x4E:  if (operandOveride){pr1ntf("dec si"); printCol+=6;}
                    else               {pr1ntf("dec esi");printCol+=7;}
                    break;   
        case 0x4F:  if (operandOveride){pr1ntf("dec di"); printCol+=6;}
                    else               {pr1ntf("dec edi");printCol+=7;}
                    break; 
        case 0x50:  if (operandOveride){pr1ntf("push ax"); printCol+=7;}
                    else               {pr1ntf("push eax");printCol+=8;}
                    break;   
        case 0x51:  if (operandOveride){pr1ntf("push cx"); printCol+=7;}
                    else               {pr1ntf("push ecx");printCol+=8;}
                    break;   
        case 0x52:  if (operandOveride){pr1ntf("push dx"); printCol+=7;}
                    else               {pr1ntf("push edx");printCol+=8;}
                    break;     
        case 0x53:  if (operandOveride){pr1ntf("push bx"); printCol+=7;}
                    else               {pr1ntf("push ebx");printCol+=8;} 
                    break;   
        case 0x54:  if (operandOveride){pr1ntf("push sp"); printCol+=7;}
                    else               {pr1ntf("push esp");printCol+=8;}
                    break;   
        case 0x55:  if (operandOveride){pr1ntf("push bp"); printCol+=7;}
                    else               {pr1ntf("push ebp");printCol+=8;}
                    break;   
        case 0x56:  if (operandOveride){pr1ntf("push si"); printCol+=7;}
                    else               {pr1ntf("push esi");printCol+=8;}
                    break;   
        case 0x57:  if (operandOveride){pr1ntf("push di"); printCol+=7;}
                    else               {pr1ntf("push edi");printCol+=8;}
                    break;  
        case 0x58:  if (operandOveride){pr1ntf("pop ax"); printCol+=6;}
                    else               {pr1ntf("pop eax");printCol+=7;}
                    break;   
        case 0x59:  if (operandOveride){pr1ntf("pop cx"); printCol+=6;}
                    else               {pr1ntf("pop ecx");printCol+=7;}
                    break;   
        case 0x5A:  if (operandOveride){pr1ntf("pop dx"); printCol+=6;}
                    else               {pr1ntf("pop edx");printCol+=7;}
                    break;     
        case 0x5B:  if (operandOveride){pr1ntf("pop bx"); printCol+=6;}
                    else               {pr1ntf("pop ebx");printCol+=7;}
                    break;   
        case 0x5C:  if (operandOveride){pr1ntf("pop sp"); printCol+=6;}
                    else               {pr1ntf("pop esp");printCol+=7;}
                    break;   
        case 0x5D:  if (operandOveride){pr1ntf("pop bp"); printCol+=6;}
                    else               {pr1ntf("pop ebp");printCol+=7;}
                    break;   
        case 0x5E:  if (operandOveride){pr1ntf("pop si"); printCol+=6;}
                    else               {pr1ntf("pop esi");printCol+=7;}
                    break;   
        case 0x5F:  if (operandOveride){pr1ntf("pop di"); printCol+=6;}
                    else               {pr1ntf("pop edi");printCol+=7;}
                    break; 
        case 0x60:  pr1ntf("pushad");               printCol+=6;  break;  
        case 0x61:  pr1ntf("popad");                printCol+=5;  break;   
        case 0x6C:  pr1ntf("ins byte, port[dx]");   printCol+=18; break;   
        case 0x6D:  pr1ntf("ins dword, port[dx]");  printCol+=19; break;   
        case 0x6E:  pr1ntf("outs port[dx], byte");  printCol+=19; break;     
        case 0x6F:  pr1ntf("outs port[dx], dword"); printCol+=20; break;    
        case 0x90:  pr1ntf("nop");                  printCol+=3;  break;     
        case 0x91:  if (operandOveride){pr1ntf("xchg ax, cx")  ;printCol+=11;}
                    else               {pr1ntf("xchg eax, ecx");printCol+=13;}
                    break;    
        case 0x92:  if (operandOveride){pr1ntf("xchg ax, dx")  ;printCol+=11;}
                    else               {pr1ntf("xchg eax, edx");printCol+=13;}
                    break; 
        case 0x93:  if (operandOveride){pr1ntf("xchg ax, bx")  ;printCol+=11;}
                    else               {pr1ntf("xchg eax, ebx");printCol+=13;}
                    break;     
        case 0x94:  if (operandOveride){pr1ntf("xchg ax, sp")  ;printCol+=11;}
                    else               {pr1ntf("xchg eax, esp");printCol+=13;}
                    break;     
        case 0x95:  if (operandOveride){pr1ntf("xchg ax, bp")  ;printCol+=11;}
                    else               {pr1ntf("xchg eax, ebp");printCol+=13;}
                    break;     
        case 0x96:  if (operandOveride){pr1ntf("xchg ax, si")  ;printCol+=11;}
                    else               {pr1ntf("xchg eax, esi");printCol+=13;}
                    break;   
        case 0x97:  if (operandOveride){pr1ntf("xchg ax, di")  ;printCol+=11;}
                    else               {pr1ntf("xchg eax, edi");printCol+=13;}
                    break;   
        case 0x98:  pr1ntf("cbw");                  printCol+=3;  break;   
        case 0x99:  if (operandOveride) {pr1ntf("cwd");}
                    else                {pr1ntf("cdq");} printCol+=3;    
                    break;   
        case 0x9C:  pr1ntf("pushfd");               printCol+=6;  break;   
        case 0x9D:  pr1ntf("popfd");                printCol+=5;  break;   
        case 0x9E:  pr1ntf("sahf");                 printCol+=4;  break;   
        case 0x9F:  pr1ntf("lahf");                 printCol+=4;  break;   
        case 0xA4:  pr1ntf("movsb");                printCol+=5;  break;   
        case 0xA5:  if (operandOveride) {pr1ntf ("movsw");}
                    else                {pr1ntf ("movsd");} printCol+=5; 
                    break;   
        case 0xA6:  pr1ntf("cmpsb");                printCol+=5;  break;   
        case 0xA7:  if (operandOveride) {pr1ntf ("cmpsw");}
                    else                {pr1ntf ("cmpsd");} printCol+=5;
                    break;   
        case 0xAA:  pr1ntf("stosb");                printCol+=5;  break;
        case 0xAB:  if (operandOveride) {pr1ntf ("stosw");}
                    else                {pr1ntf ("stosd");} printCol+=5;
                    break;    
        case 0xAC:  pr1ntf("lodsb");                printCol+=5;  break;   
        case 0xAD:  if (operandOveride) {pr1ntf ("lodsw");}
                    else                {pr1ntf ("lodsd");} printCol+=5;
                    break;   
        case 0xAE:  pr1ntf("scasb");                printCol+=5;  break;   
        case 0xAF:  if (operandOveride) {pr1ntf ("scasw");}
                    else                {pr1ntf ("scasd");} printCol+=5;
                    break;   
        case 0xC3:  pr1ntf("ret");  needspacing=1;           printCol+=3;
                    lastAnchor=cur_position+i_col-1;
                    needJump=1;     needJumpNext=cur_position+i_col;
                    pushTrace(145);
                    if(nextMode>0) orMap(lastAnchor, MAP_ANCHOR_SET);
                    popTrace();
                    break;   
        case 0xC9:  pr1ntf("leave");                printCol+=5;  break;   
        case 0xCB:  pr1ntf("ret(far)");    needspacing=1;    printCol+=8; 
                    lastAnchor=cur_position+i_col-1;
                    needJump=1;     needJumpNext=cur_position+i_col;
                    pushTrace(146);
                    if(nextMode>0) orMap(lastAnchor, MAP_ANCHOR_SET);
                    popTrace();
                    //leaveFlag=cur_position+i_col;
                    break;   
        case 0xCC:  pr1ntf("int 03");               printCol+=6;  break;   
        case 0xCE:  pr1ntf("into");                 printCol+=4;  break;   
        case 0xCF:  if (operandOveride){pr1ntf ("iret"); printCol+=4;}
                    else               {pr1ntf ("iretd");printCol+=5;}
                    break;   
        case 0xD7:  pr1ntf("xlatb");                printCol+=5;  break;   
        case 0xEC:  pr1ntf("in al, port[dx]");      printCol+=15; break;   
        case 0xED:  if (operandOveride){pr1ntf ("in ax, port[dx]"); printCol+=15;}
                    else               {pr1ntf ("in eax, port[dx]");printCol+=16;}
                    break;   
        case 0xEE:  pr1ntf("out port[dx], al");     printCol+=16; break;   
        case 0xEF:  if (operandOveride){pr1ntf ("out port[dx], ax"); printCol+=16;}
                    else               {pr1ntf ("out port[dx], eax");printCol+=17;}
                    break;   
        case 0xF0:  pr1ntf("lock");                 printCol+=4;  break;   
        case 0xF4:  pr1ntf("hlt");                  printCol+=3;  break;   
        case 0xF5:  pr1ntf("cmc");                  printCol+=3;  break;   
        case 0xF8:  pr1ntf("clc");                  printCol+=3;  break;  
        case 0xF9:  pr1ntf("stc");                  printCol+=3;  break;   
        case 0xFA:  pr1ntf("cli");                  printCol+=3;  break;   
        case 0xFB:  pr1ntf("sti");                  printCol+=3;  break;   
        case 0xFC:  pr1ntf("cld");                  printCol+=3;  break;     
        case 0xFD:  pr1ntf("std");                  printCol+=3;  break;
        default:    fatalError=107;return -1;
    }
    return 0;
}

int print1case()
{
    switch(i_opcode)
    {
        case 0x04:  pr1ntf("add al, ");    print_i_byte(); printCol+=8; break;   
        case 0x0C:  pr1ntf("or al, ");     print_i_byte(); printCol+=7; break;   
        case 0x14:  pr1ntf("adc al, ");    print_i_byte(); printCol+=8; break;   
        case 0x1C:  pr1ntf("sbb al, ");    print_i_byte(); printCol+=8; break;     
        case 0x24:  pr1ntf("and al, ");    print_i_byte(); printCol+=8; break;    
        case 0x2C:  pr1ntf("sub al, ");    print_i_byte(); printCol+=8; break;     
        case 0x34:  pr1ntf("xor al, ");    print_i_byte(); printCol+=8; break;    
        case 0x3C:  pr1ntf("cmp al, ");    print_i_byte(); printCol+=8; break; 
        case 0x6A:  pr1ntf("push ");       print_i_byte32(); printCol+=5; break;     
        case 0x70:  pr1ntf("jo ");         print_rel8();   printCol+=3; break;     
        case 0x71:  pr1ntf("jno ");        print_rel8();   printCol+=4; break;     
        case 0x72:  pr1ntf("jc ");         print_rel8();   printCol+=3; break;   
        case 0x73:  pr1ntf("jae ");        print_rel8();   printCol+=4; break;   
        case 0x74:  pr1ntf("je ");         print_rel8();   printCol+=3; break;   
        case 0x75:  pr1ntf("jne ");        print_rel8();   printCol+=4; break;   
        case 0x76:  pr1ntf("jbe ");        print_rel8();   printCol+=4; break;   
        case 0x77:  pr1ntf("ja ");         print_rel8();   printCol+=3; break;   
        case 0x78:  pr1ntf("js ");         print_rel8();   printCol+=3; break;   
        case 0x79:  pr1ntf("jns ");        print_rel8();   printCol+=4; break;   
        case 0x7A:  pr1ntf("jpe ");        print_rel8();   printCol+=4; break;   
        case 0x7B:  pr1ntf("jpo ");        print_rel8();   printCol+=4; break;   
        case 0x7C:  pr1ntf("jl ");         print_rel8();   printCol+=3; break;   
        case 0x7D:  pr1ntf("jge ");        print_rel8();   printCol+=4; break;   
        case 0x7E:  pr1ntf("jle ");        print_rel8();   printCol+=4; break;   
        case 0x7F:  pr1ntf("jg ");         print_rel8();   printCol+=3; break;   
        case 0xA8:  pr1ntf("test al, ");   print_i_byte(); printCol+=9; break;   
        case 0xB0:  pr1ntf("mov al, ");    print_i_byte(); printCol+=8; break;   
        case 0xB1:  pr1ntf("mov cl, ");    print_i_byte(); printCol+=8; break;   
        case 0xB2:  pr1ntf("mov dl, ");    print_i_byte(); printCol+=8; break;   
        case 0xB3:  pr1ntf("mov bl, ");    print_i_byte(); printCol+=8; break;   
        case 0xB4:  pr1ntf("mov ah, ");    print_i_byte(); printCol+=8; break;   
        case 0xB5:  pr1ntf("mov ch, ");    print_i_byte(); printCol+=8; break;   
        case 0xB6:  pr1ntf("mov dh, ");    print_i_byte(); printCol+=8; break;   
        case 0xB7:  pr1ntf("mov bh, ");    print_i_byte(); printCol+=8; break;   
        case 0xCD:  pr1ntf("int ");        print_i_byte(); printCol+=4; break;   
        case 0xD4:  pr1ntf("aam ");                        printCol+=4; break;   
        case 0xD5:  pr1ntf("aad ");                        printCol+=4; break;   
        case 0xE0:  pr1ntf("loopne ");     print_rel8();   printCol+=7; break;   
        case 0xE1:  pr1ntf("loope ");      print_rel8();   printCol+=6; break;   
        case 0xE2:  pr1ntf("loop ");       print_rel8();   printCol+=5; break;   
        case 0xE3:  pr1ntf("jecxz ");      print_rel8();   printCol+=6; break;   
        case 0xE4:  pr1ntf("in al, port["); print_i_byte(); pr1ntf("]");  printCol+=13; break;   
        case 0xE5:  pr1ntf("in eax, port[");print_i_byte(); pr1ntf("]");  printCol+=14; break;   
        case 0xE6:  pr1ntf("out port["); print_i_byte(); pr1ntf("], al"); printCol+=14; break;   
        case 0xE7:  pr1ntf("out port["); print_i_byte(); pr1ntf("], eax");printCol+=15; break;
        case 0xEB:  pr1ntf("jmp ");        ref=print_rel8();                printCol+=4;
                    if (nextMode>0)
                    {
                        if (isThisSecure(ref) || referCount(ref)>2 || 
                            (opclassSave==2 && (opsave & 0x80)) )  
                        {
                            lastAnchor=cur_position+i_col-1;
                            pushTrace(147);
                            orMap(lastAnchor, MAP_ANCHOR_SET);
                            popTrace();
                        }
                    }
                    break;
        default:    fatalError=109;return -1;
    }
    return 0;

}

int print2case()
{
    if (i_opcode==0xC2)
    {
        pr2ntf("ret %04X", i_word);    needspacing=1; 
        needJump=1;     needJumpNext=cur_position+i_col;
    }
    else
    {
        pr2ntf("ret %04X", i_word);    needspacing=1; 
        needJump=1;     needJumpNext=cur_position+i_col;
    }
    printCol+=8;
    lastAnchor = cur_position+i_col-1;
    pushTrace(148);
    if(nextMode>0) orMap(lastAnchor, MAP_ANCHOR_SET);
    popTrace();
    //leaveFlag=cur_position+i_col;
    return 0;
}

int print3case()
{
    pr2ntf("enter %04X, ", i_word); print_i_byte();
    printCol+=10;
    return 0;
}

int print4case()
{
    switch(i_opcode)
    {
        case 0x05:  if (operandOveride){pr1ntf ("add ex, "); printCol+=8;}
                    else               {pr1ntf ("add eax, ");printCol+=9;}  
                    print_i_dword();     
                    break;   
        case 0x0D:  if (operandOveride){pr1ntf ("or ax, ");  printCol+=7;}
                    else               {pr1ntf ("or eax, "); printCol+=8;}   
                    print_i_dword();     
                    break;   
        case 0x15:  if (operandOveride){pr1ntf ("adc ax, "); printCol+=8;}
                    else               {pr1ntf ("adc eax, ");printCol+=9;}  
                    print_i_dword();     
                    break;   
        case 0x1D:  if (operandOveride){pr1ntf ("sbb ax, "); printCol+=8;}
                    else               {pr1ntf ("sbb eax, ");printCol+=9;}  
                    print_i_dword();     
                    break;     
        case 0x25:  if (operandOveride){pr1ntf ("and ax, "); printCol+=8;}
                    else               {pr1ntf ("and eax, ");printCol+=9;}  
                    print_i_dword();     
                    break; 
        case 0x2D:  if (operandOveride){pr1ntf ("sub ax, "); printCol+=8;}
                    else               {pr1ntf ("sub eax, ");printCol+=9;}  
                    print_i_dword();     
                    break;      
        case 0x35:  if (operandOveride){pr1ntf ("xor ax, "); printCol+=8;}
                    else               {pr1ntf ("xor eax, ");printCol+=9;}  
                    print_i_dword();     
                    break;     
        case 0x3D:  if (operandOveride){pr1ntf ("cmp ax, "); printCol+=8;}
                    else               {pr1ntf ("cmp eax, ");printCol+=9;}  
                    print_i_dword();     
                    break;  
        case 0x68:  pr1ntf("push ");    ref=print_i_dword();     // this is OK 
        // well I really don't know it is reasonably safe to do this.
        // I think when we push some (possible) address references into stack
        // there is strong reason to do so. that's why i am doing this. i guess...
                    lclass=512;         printCol+=5; 
                    break;     
        case 0xA0:  pr1ntf("mov al, byte");    print_moff(); printCol+=12;        
                    break;     
        case 0xA1:  if (operandOveride){pr1ntf ("mov ax, word");  printCol+=12;}
                    else               {pr1ntf ("mov eax, dword");printCol+=14;}  
                    ref=print_moff();
                    if (isGoodAddress(ref)) 
                    {if (operandOveride) lclass=516; else lclass=1024;}
                    break;     
        case 0xA2:  pr1ntf("mov byte");print_moff();pr1ntf(", al");printCol+=12; 
                    break;
        case 0xA3:  if (operandOveride){pr1ntf ("mov word"); printCol+=12;}
                    else               {pr1ntf ("mov dword");printCol+=14;}
                    print_moff();
                    if (operandOveride){pr1ntf (", ax");}
                    else               {pr1ntf (", eax");}
                    break;
        case 0xA9:  if (operandOveride){pr1ntf ("test ax, "); printCol+= 9;}
                    else               {pr1ntf ("test eax, ");printCol+=10;} 
                    print_i_dword();     
                    break;   
        case 0xB8:  if (operandOveride){pr1ntf ("mov ax, "); printCol+=8;}
                    else               {pr1ntf ("mov eax, ");printCol+=9;}  
                    ref=print_i_dword();lclass=1024;     
                    break;   
        case 0xB9:  if (operandOveride){pr1ntf ("mov cx, "); printCol+=8;}
                    else               {pr1ntf ("mov ecx, ");printCol+=9;}  
                    ref=print_i_dword();lclass=1024;     
                    break;   
        case 0xBA:  if (operandOveride){pr1ntf ("mov dx, "); printCol+=8;}
                    else               {pr1ntf ("mov edx, ");printCol+=9;}  
                    ref=print_i_dword();lclass=1024;     
                    break;   
        case 0xBB:  if (operandOveride){pr1ntf ("mov bx, "); printCol+=8;}
                    else               {pr1ntf ("mov ebx, ");printCol+=9;}  
                    ref=print_i_dword();lclass=1024;     
                    break;   
        case 0xBC:  if (operandOveride){pr1ntf ("mov sp, "); printCol+=8;}
                    else               {pr1ntf( "mov esp, ");printCol+=9;}  
                    ref=print_i_dword();lclass=1024;     
                    break;   
        case 0xBD:  if (operandOveride){pr1ntf ("mov bp, "); printCol+=8;}
                    else               {pr1ntf ("mov ebp, ");printCol+=9;}  
                    ref=print_i_dword();lclass=1024;     
                    break;   
        case 0xBE:  if (operandOveride){pr1ntf ("mov si, "); printCol+=8;}
                    else               {pr1ntf ("mov esi, ");printCol+=9;}  
                    ref=print_i_dword();lclass=1024;     
                    break;   
        case 0xBF:  if (operandOveride){pr1ntf ("mov di, "); printCol+=8;}
                    else               {pr1ntf ("mov edi, ");printCol+=9;}  
                    ref=print_i_dword();lclass=1024;     
                    break;   
        case 0xE8:  pr1ntf("call "); 
                    lclass = 11;        printCol+=5;
                    ref = print_rel32();
                    needCall=1;
                    if (nextMode) {
                        if (isGoodAddress(ref))
                        {
                            needCallRef=ref;
                            needCallNext=cur_position+i_col;
                            lastAnchor=cur_position+i_col-1;
                            pushTrace(158);
                            if(nextMode>0) orMap(lastAnchor, MAP_ANCHOR_SET);
                            popTrace();
                        }
                        else fatalError=-18;
                    }
                    else printName(cur_position); 
                    break;
                                        
        case 0xE9:  pr1ntf("jmp ");  ref = print_rel32();       
                    lclass =  3;      printCol+=4;
                    lastAnchor=cur_position+i_col-1;
                    needJump=1;     needJumpNext=cur_position+i_col;
                    if (nextMode>0) 
                    {
                        if (! isGoodAddress(ref)) {lclass=0; fatalError=990;}
                        else
                        {       
                            pushTrace(149);
                            orMap(lastAnchor, MAP_ANCHOR_SET);
                            popTrace();
                        }
                    }
                    else printName(cur_position);
                    //leaveFlag=cur_position+i_col;
                    break;            
        default:    fatalError=111;return -1;
    }
    return 0;

}

int print5case()
{
    if (i_opcode==0x9A)
    {
        pr3ntf("call far %04X:%08X", i_word,i_dword);
        {lclass=15; ref=i_dword;}
        printCol+=22;
    }
    else
    {
        pr3ntf("jmp far %04X:%08X", i_word,i_dword);
        needJump=1;     needJumpNext=cur_position+i_col;
        {lclass=7; ref=i_dword;}
        printCol+=21;
    }
    return 0;
}

int print6case()  
{
int    rr;

    if (operandOveride) rr=16; else rr=32;

    switch(i_opcode)
    {
          case 0x00: pr1ntf("add ");    ref=r_m_( 8);  pr1ntf(", ");  r___( 8);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x01: pr1ntf("add ");    ref=r_m_(rr);  pr1ntf(", ");  r___(rr);  printCol+=6; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x02: pr1ntf("add ");    r___( 8);  pr1ntf(", ");  ref=r_m_( 8);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x03: pr1ntf("add ");    r___(rr);  pr1ntf(", ");  ref=r_m_(rr);  printCol+=6; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x08: pr1ntf("or ");     ref=r_m_( 8);  pr1ntf(", ");  r___( 8);  printCol+=5; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x09: pr1ntf("or ");     ref=r_m_(rr);  pr1ntf(", ");  r___(rr);  printCol+=5; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x0A: pr1ntf("or ");     r___( 8);  pr1ntf(", ");  ref=r_m_( 8);  printCol+=5; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x0B: pr1ntf("or ");     r___(rr);  pr1ntf(", ");  ref=r_m_(rr);  printCol+=5; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x10: pr1ntf("adc ");    ref=r_m_( 8);  pr1ntf(", ");  r___( 8);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x11: pr1ntf("adc ");    ref=r_m_(rr);  pr1ntf(", ");  r___(rr);  printCol+=6; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x12: pr1ntf("adc ");    r___( 8);  pr1ntf(", ");  ref=r_m_( 8);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x13: pr1ntf("adc ");    r___(rr);  pr1ntf(", ");  ref=r_m_(rr);  printCol+=6; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x18: pr1ntf("sbb ");    ref=r_m_( 8);  pr1ntf(", ");  r___( 8);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x19: pr1ntf("sbb ");    ref=r_m_(rr);  pr1ntf(", ");  r___(rr);  printCol+=6; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x1A: pr1ntf("sbb ");    r___( 8);  pr1ntf(", ");  ref=r_m_( 8);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x1B: pr1ntf("sbb ");    r___(rr);  pr1ntf(", ");  ref=r_m_(rr);  printCol+=6; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x20: pr1ntf("and ");    ref=r_m_( 8);  pr1ntf(", ");  r___( 8);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x21: pr1ntf("and ");    ref=r_m_(rr);  pr1ntf(", ");  r___(rr);  printCol+=6; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x22: pr1ntf("and ");    r___( 8);  pr1ntf(", ");  ref=r_m_( 8);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x23: pr1ntf("and ");    r___(rr);  pr1ntf(", ");  ref=r_m_(rr);  printCol+=6; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x28: pr1ntf("sub ");    ref=r_m_( 8);  pr1ntf(", ");  r___( 8);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x29: pr1ntf("sub ");    ref=r_m_(rr);  pr1ntf(", ");  r___(rr);  printCol+=6; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x2A: pr1ntf("sub ");    r___( 8);  pr1ntf(", ");  ref=r_m_( 8);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x2B: pr1ntf("sub ");    r___(rr);  pr1ntf(", ");  ref=r_m_(rr);  printCol+=6; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x30: pr1ntf("xor ");    ref=r_m_( 8);  pr1ntf(", ");  r___( 8);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x31: pr1ntf("xor ");    ref=r_m_(rr);  pr1ntf(", ");  r___(rr);  printCol+=6; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x32: pr1ntf("xor ");    r___( 8);  pr1ntf(", ");  ref=r_m_( 8);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x33: pr1ntf("xor ");    r___(rr);  pr1ntf(", ");  ref=r_m_(rr);  printCol+=6; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x38: pr1ntf("cmp ");    ref=r_m_( 8);  pr1ntf(", ");  r___( 8);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x39: pr1ntf("cmp ");    ref=r_m_(rr);  pr1ntf(", ");  r___(rr);  printCol+=6; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x3A: pr1ntf("cmp ");    r___( 8);  pr1ntf(", ");  ref=r_m_( 8);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x3B: pr1ntf("cmp ");    r___(rr);  pr1ntf(", ");  ref=r_m_(rr);  printCol+=6; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x62: pr1ntf("bound ");  r___(rr);  pr1ntf(", ");  ref=m32_32();  printCol+=8; 
                   if (isGoodAddress(ref)) lclass=518;
                   break; 
          case 0x63: pr1ntf("arpl ");   ref=r_m_(16);  pr1ntf(", ");  r___(16);  printCol+=7; 
                   if (isGoodAddress(ref)) lclass=516;
                   break; 
          case 0x84: pr1ntf("test ");   ref=r_m_( 8);  pr1ntf(", ");  r___( 8);  printCol+=7; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x85: pr1ntf("test ");   ref=r_m_(rr);  pr1ntf(", ");  r___(rr);  printCol+=7; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x86: pr1ntf("xchg ");   ref=r_m_( 8);  pr1ntf(", ");  r___( 8);  printCol+=7; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x87: pr1ntf("xchg ");   ref=r_m_(rr);  pr1ntf(", ");  r___(rr);  printCol+=7; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x88: pr1ntf("mov ");    ref=r_m_( 8);  pr1ntf(", ");  r___( 8);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x89: pr1ntf("mov ");    ref=r_m_(rr);  pr1ntf(", ");  r___(rr);  printCol+=6; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=1024;}
                   break; 
          case 0x8A: pr1ntf("mov ");    r___( 8);  pr1ntf(", ");  ref=r_m_( 8);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
          case 0x8B: pr1ntf("mov ");    r___(rr);  pr1ntf(", ");  ref=r_m_(rr);     printCol+=6; 
                   reg=regTable[i_mod]; tempref[reg]=ref; temppos[reg]=cur_position;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=1024;}
                   break; 
          case 0x8C: pr1ntf("mov ");    ref=r_m_(16);  pr1ntf(", ");  Sreg__();  printCol+=6; 
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=1024;}
                   break; 
          case 0x8D: pr1ntf("lea ");    r___(rr);  pr1ntf(", ");  ref=m_____();  printCol+=6; 
                   reg=regTable[i_mod]; tempref[reg]=ref; temppos[reg]=cur_position;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break; 
          case 0x8E: pr1ntf("mov ");    Sreg__();  pr1ntf(", ");  ref=r_m_(16);  printCol+=6; 
                   if (isGoodAddress(ref)) lclass=516;
                   break; 
          case 0xC4: pr1ntf("les es:"); r___(rr);  pr1ntf(", ");  ref=m16_32();  printCol+=9; 
                   if (isGoodAddress(ref)) lclass=516;
                   break; 
          case 0xC5: pr1ntf("lds ds:"); r___(rr);  pr1ntf(", ");  ref=m16_32();  printCol+=9; 
                   if (isGoodAddress(ref)) lclass=516;
                   break;
        default:   fatalError=113;return -1;
    }
    return 0;
}

int print7case()
{
int    rr;

    if (operandOveride) rr=16; else rr=32;

    pr1ntf("imul "); r___(rr); 
    if (modTable[i_mod]<8 || regTable[i_mod]!=rmTable[i_mod])
    {   pr1ntf(", "); ref=r_m_(rr); printCol+=2;}
    pr1ntf(", "); 
    print_i_byte();
    printCol+=7;
    if (isGoodAddress(ref)) 
    {if (operandOveride) lclass=516; else lclass=514;}
    return 0;
}

int print8case()
{
int    rr;

    if (operandOveride) rr=16; else rr=32;

    pr1ntf("imul "); r___(rr); 
    if (modTable[i_mod]<8 || regTable[i_mod]!=rmTable[i_mod])
    {   pr1ntf(", "); ref=r_m_(rr); printCol+=2;}
    pr1ntf(", "); 
    print_i_dword();
    printCol+=7;
    if (isGoodAddress(ref)) 
    {if (operandOveride) lclass=516; else lclass=514;}
    return 0;
}

int print9case()
{
int    rr;

    if (operandOveride) rr=16; else rr=32;

    specifierFlag = my_ON;
    switch(i_opcode)
    {
        case 0x8F: 
                   if (regTable[i_mod]>0)
                   {  
                       fatalError=115;
                       specifierFlag = my_OFF;
                       return -1;
                   }
                   pr1ntf("pop "); ref=r_m_(rr); printCol+=4;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;
        case 0xD0:
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("rol "); break;
                       case 1: pr1ntf("ror "); break;
                       case 2: pr1ntf("rcl "); break;
                       case 3: pr1ntf("rcr "); break;
                       case 4: pr1ntf("shl "); break;
                       case 5: pr1ntf("shr "); break;
                       case 7: pr1ntf("sar "); break;
                       default:    fatalError=117;
                   }
                   ref=r_m_( 8); pr1ntf(", 1"); printCol+=7;
                   if (isGoodAddress(ref)) lclass=520;
                   break;
        case 0xD1:
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("rol "); break;
                       case 1: pr1ntf("ror "); break;
                       case 2: pr1ntf("rcl "); break;
                       case 3: pr1ntf("rcr "); break;
                       case 4: pr1ntf("shl "); break;
                       case 5: pr1ntf("shr "); break;
                       case 7: pr1ntf("sar "); break;
                       default:    fatalError=118;
                   }
                   ref=r_m_(rr); pr1ntf(", 1"); printCol+=7;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;
        case 0xD2:
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("rol "); break;
                       case 1: pr1ntf("ror "); break;
                       case 2: pr1ntf("rcl "); break;
                       case 3: pr1ntf("rcr "); break;
                       case 4: pr1ntf("shl "); break;
                       case 5: pr1ntf("shr "); break;
                       case 7: pr1ntf("sar "); break;
                       default:    fatalError=119;
                   }
                   ref=r_m_( 8); pr1ntf(", cl"); printCol+=8;
                   if (isGoodAddress(ref)) lclass=520;
                   break;
        case 0xD3:
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("rol "); break;
                       case 1: pr1ntf("ror "); break;
                       case 2: pr1ntf("rcl "); break;
                       case 3: pr1ntf("rcr "); break;
                       case 4: pr1ntf("shl "); break;
                       case 5: pr1ntf("shr "); break;
                       case 7: pr1ntf("sar "); break;
                       default:    fatalError=121;
                   }
                   ref=r_m_(rr); pr1ntf(", cl"); printCol+=8;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;
        case 0xFE:
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("inc "); ref=r_m_( 8); printCol+=4; break;
                       case 1: pr1ntf("dec "); ref=r_m_( 8); printCol+=4; break;
                       default: fatalError=123;
                   }
                   if (isGoodAddress(ref)) lclass=520;
                   break;
        default: fatalError=125;
    }
    specifierFlag=my_OFF;
    return 0;
}

int print10case()
{
int    rr;

    if (operandOveride) rr=16; else rr=32;

    switch(i_opcode)
    {
        case 0x80: 
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("add ");  printCol+=6; break;
                       case 1: pr1ntf("or ");   printCol+=5; break;
                       case 2: pr1ntf("adc ");  printCol+=6; break;
                       case 3: pr1ntf("sbb ");  printCol+=6; break;
                       case 4: pr1ntf("and ");  printCol+=6; break;
                       case 5: pr1ntf("sub ");  printCol+=6; break;
                       case 6: pr1ntf("xor ");  printCol+=6; break;
                       case 7: pr1ntf("cmp ");  printCol+=6; break;
                       default:    fatalError=127;
                   }
                   ref=r_m_( 8); pr1ntf(", "); print_i_byte();
                   if (isGoodAddress(ref)) lclass=520;
                   break;
        case 0x83:
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("add ");  printCol+=6; break;
                       case 1: pr1ntf("or ");   printCol+=5; break;
                       case 2: pr1ntf("adc ");  printCol+=6; break;
                       case 3: pr1ntf("sbb ");  printCol+=6; break;
                       case 4: pr1ntf("and ");  printCol+=6; break;
                       case 5: pr1ntf("sub ");  printCol+=6; break;
                       case 6: pr1ntf("xor ");  printCol+=6; break;
                       case 7: pr1ntf("cmp ");  printCol+=6; break;
                       default:    fatalError=129;
                   }
                   ref=r_m_(rr); pr1ntf(", "); print_i_byte32();
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;
                   
        case 0xC0:
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("rol ");  break;
                       case 1: pr1ntf("ror ");  break;
                       case 2: pr1ntf("rcl ");  break;
                       case 3: pr1ntf("rcr ");  break;
                       case 4: pr1ntf("shl ");  break;
                       case 5: pr1ntf("shr ");  break;
                       case 7: pr1ntf("sar ");  break;
                       default:    fatalError=131;
                   }
                   ref=r_m_( 8); pr1ntf(", "); printCol+=6; print_i_byte();
                   if (isGoodAddress(ref)) lclass=520;
                   break;
        case 0xC1:
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("rol ");  break;
                       case 1: pr1ntf("ror ");  break;
                       case 2: pr1ntf("rcl ");  break;
                       case 3: pr1ntf("rcr ");  break;
                       case 4: pr1ntf("shl ");  break;
                       case 5: pr1ntf("shr ");  break;
                       case 7: pr1ntf("sar ");  break;
                       default:    fatalError=133;
                   }
                   ref=r_m_(rr); pr1ntf(", "); printCol+=6; print_i_byte();
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;
        case 0xC6:
                   if (regTable[i_mod]==0)
                   {
                       pr1ntf("mov "); ref=r_m_( 8); 
                       pr1ntf(", "); print_i_byte();  printCol+=6; 
                       if (isGoodAddress(ref)) lclass=520;
                   }
                   else fatalError=135;
                   break;
        default: fatalError=137;
    }
    return 0;
}

int print11case()  
{
int    rr;

    if (operandOveride) rr=16; else rr=32;

    if (i_opcode==0xC7)
    {
        if (regTable[i_mod]>0)
        {
            fatalError=139;
            return -1;
        }
        pr1ntf("mov "); dref=r_m_(rr); pr1ntf(", "); 
        ref=print_i_dword();
        {if (operandOveride) lclass=516; else lclass=514;}
		if (nextMode>0)
		{
            if (isGoodAddress(dref)) EnterLabel(lclass,dref,cur_position);
            lclass=1024;
        }
		printCol+=6; 
        return 0;
    }
    else        /* is should be 0x81 otherwise i*am*in*big*trouble */
    {
        switch(regTable[i_mod])
        {
            case 0: pr1ntf("add ");  printCol+=6; break;
            case 1: pr1ntf("or ");   printCol+=5; break;
            case 2: pr1ntf("adc ");  printCol+=6; break;
            case 3: pr1ntf("sbb ");  printCol+=6; break;
            case 4: pr1ntf("and ");  printCol+=6; break;
            case 5: pr1ntf("sub ");  printCol+=6; break;
            case 6: pr1ntf("xor ");  printCol+=6; break;
            case 7: pr1ntf("cmp ");  printCol+=6; break;
            default:   fatalError=141;
        }
        ref=r_m_(rr); pr1ntf(", "); print_i_dword();
        if (isGoodAddress(ref)) 
        {if (operandOveride) lclass=516; else lclass=514;}
    }
    return 0;
}

int print12case()
{
int    rr;

    if (operandOveride) rr=16; else rr=32;

    switch(i_opcode)
    {
        case 0xD8: 
            if (i_mod<0xC0)
            {
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("fadd ");   printCol+=5; break;
                       case 1: pr1ntf("fmul ");   printCol+=5; break;
                       case 2: pr1ntf("fcom ");   printCol+=5; break;
                       case 3: pr1ntf("fcomp ");  printCol+=6; break;
                       case 4: pr1ntf("fsub ");   printCol+=5; break;
                       case 5: pr1ntf("fsubr ");  printCol+=6; break;
                       case 6: pr1ntf("fdiv ");   printCol+=5; break;
                       case 7: pr1ntf("fdivr ");  printCol+=6; break;
                       default:    fatalError=143;
                   }
                   pr1ntf("32real"); ref=r_m_( 0); printCol+=6;
                   if (isGoodAddress(ref)) lclass=524;
            }
            else
            {
                if (i_mod<0xC8)      {pr2ntf("fadd st(0), st(%1d)",  i_mod-0xC0);printCol+=17;}
                else if (i_mod <0xD0){pr2ntf("fmul st(0), st(%1d)",  i_mod-0xC8);printCol+=17;}
                else if (i_mod==0xD1){pr1ntf("fcom")                            ;printCol+=4; }
                else if (i_mod <0xD8){pr2ntf("fcom st(0), st(%1d)",  i_mod-0xD0);printCol+=17;}
                else if (i_mod==0xD9){pr1ntf("fcomp")                           ;printCol+=5; }
                else if (i_mod <0xE0){pr2ntf("fcomp st(0), st(%1d)", i_mod-0xD8);printCol+=18;}
                else if (i_mod <0xE8){pr2ntf("fsub st(0), st(%1d)",  i_mod-0xE0);printCol+=17;}
                else if (i_mod <0xF0){pr2ntf("fsubr st(0), st(%1d)", i_mod-0xE8);printCol+=18;}
                else if (i_mod <0xF8){pr2ntf("fdiv st(0), st(%1d)",  i_mod-0xF0);printCol+=17;}
                else                 {pr2ntf("fdivr st(0), st(%1d)", i_mod-0xF8);printCol+=18;}
            }
            break;
        case 0xD9: 
            if (i_mod<0xC0)
            {
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("fld ");   pr1ntf("32real");    ref=r_m_( 0);
                               printCol+=10;      if (isGoodAddress(ref)) lclass=524;
                               break;
                       case 2: pr1ntf("fst ");   pr1ntf("32real");    ref=r_m_( 0);
                               printCol+=10;      if (isGoodAddress(ref)) lclass=524;
                               break;
                       case 3: pr1ntf("fstp ");  pr1ntf("32real");    ref=r_m_( 0);
                               printCol+=11;      if (isGoodAddress(ref)) lclass=524;
                               break;
                       case 4: pr1ntf("fldenv ");pr1ntf("14/28byte"); ref=r_m_( 0);
                               printCol+=16;      if (isGoodAddress(ref)) lclass=515;
                               break;
                       case 5: pr1ntf("fldcw "); pr1ntf("2byte");     ref=r_m_( 0);
                               printCol+=11;      if (isGoodAddress(ref)) lclass=516;
                               break;
                       case 6: pr1ntf("fnstenv ");pr1ntf("14/28byte");ref=r_m_( 0);
                               printCol+=17;      if (isGoodAddress(ref)) lclass=515;
                               break;
                       case 7: pr1ntf("fnstcw ");pr1ntf("2byte");     ref=r_m_( 0);
                               printCol+=12;      if (isGoodAddress(ref)) lclass=516;
                               break;
                       default:    fatalError=145;
                   }
            }
            else
            {
                if (i_mod<0xC8)      {pr2ntf("fld st(%1d)",  i_mod-0xC0) ;printCol+=9; }
                else if (i_mod==0xC9){pr1ntf("fxch")                     ;printCol+=4; }
                else if (i_mod <0xD0){pr2ntf("fxch st(%1d)",  i_mod-0xC8);printCol+=10;}
                else
                {
                    switch(i_mod)
                    {
                        case 0xD0: pr1ntf("fnop");      printCol+=4; break;        
                        case 0xE0: pr1ntf("fchs");        printCol+=4; break;
                        case 0xE1: pr1ntf("fabs");        printCol+=4; break;
                        case 0xE4: pr1ntf("ftst");        printCol+=4; break;
                        case 0xE5: pr1ntf("fxam");        printCol+=4; break;    
                        case 0xE8: pr1ntf("fld1");        printCol+=4; break;
                        case 0xE9: pr1ntf("fldl2t");    printCol+=6; break;
                        case 0xEA: pr1ntf("fldl2e");    printCol+=6; break;
                        case 0xEB: pr1ntf("fldpi");        printCol+=5; break;
                        case 0xEC: pr1ntf("fldlg2");    printCol+=6; break;
                        case 0xED: pr1ntf("fldln2");    printCol+=6; break;
                        case 0xEE: pr1ntf("fldz");        printCol+=4; break;
                        case 0xF0: pr1ntf("f2xm1");        printCol+=5; break;
                        case 0xF1: pr1ntf("fyl2x");        printCol+=5; break;
                        case 0xF2: pr1ntf("fptan");        printCol+=5; break;
                        case 0xF3: pr1ntf("fpatan");    printCol+=6; break;
                        case 0xF4: pr1ntf("fxtract");    printCol+=7; break;
                        case 0xF5: pr1ntf("fprem1");    printCol+=6; break;
                        case 0xF6: pr1ntf("fdecstp");    printCol+=7; break;
                        case 0xF7: pr1ntf("fincstp");    printCol+=7; break;
                        case 0xF8: pr1ntf("fprem");        printCol+=5; break;
                        case 0xF9: pr1ntf("fyl2xp1");    printCol+=7; break;
                        case 0xFA: pr1ntf("fsqrt");        printCol+=5; break;
                        case 0xFB: pr1ntf("fsincos");    printCol+=7; break;
                        case 0xFC: pr1ntf("frndint");    printCol+=7; break;
                        case 0xFD: pr1ntf("fscale");    printCol+=6; break;
                        case 0xFE: pr1ntf("fsin");        printCol+=4; break;
                        case 0xFF: pr1ntf("fcos");        printCol+=4; break;
                        default:   fatalError=202;
                    }
                }
            }
            break;
        case 0xDA: 
            if (i_mod<0xC0)
            {
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("fiadd ");  ref=r_m_(rr); printCol+=6; break;
                       case 1: pr1ntf("fimul ");  ref=r_m_(rr); printCol+=6; break;
                       case 2: pr1ntf("ficom ");  ref=r_m_(rr); printCol+=6; break;
                       case 3: pr1ntf("ficomp "); ref=r_m_(rr); printCol+=7; break;
                       case 4: pr1ntf("fisub ");  ref=r_m_(rr); printCol+=6; break;
                       case 5: pr1ntf("fisubr "); ref=r_m_(rr); printCol+=7; break;
                       case 6: pr1ntf("fidiv ");  ref=r_m_(rr); printCol+=6; break;
                       case 7: pr1ntf("fidivr "); ref=r_m_(rr); printCol+=7; break;
                       default:    fatalError=204;
                   }
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
            }
            else
            {
                if (i_mod<0xC8)      {pr2ntf("fcmovb st(0), st(%1d)", i_mod-0xC0);printCol+=19;}
                else if (i_mod <0xD0){pr2ntf("fcmove st(0), st(%1d)", i_mod-0xC8);printCol+=19;}
                else if (i_mod <0xD8){pr2ntf("fcmovbe st(0), st(%1d)",i_mod-0xD0);printCol+=20;}
                else if (i_mod <0xE0){pr2ntf("fcmovu st(0), st(%1d)", i_mod-0xD8);printCol+=19;}
                else if (i_mod==0xE9){pr1ntf("fucompp")                          ;printCol+=7; }
            }
            break;
        case 0xDB: 
            if (i_mod<0xC0)
            {
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("fild ");  ref=r_m_(rr);                  printCol+=5; 
                               if (isGoodAddress(ref)) 
                               {if (operandOveride) lclass=516; else lclass=514;}
                               break;
                       case 2: pr1ntf("fist ");  ref=r_m_(rr);                  printCol+=5; 
                               if (isGoodAddress(ref)) 
                               {if (operandOveride) lclass=516; else lclass=514;}
                               break;
                       case 3: pr1ntf("fistp "); ref=r_m_(rr);                  printCol+=6; 
                               if (isGoodAddress(ref)) 
                               {if (operandOveride) lclass=516; else lclass=514;}
                               break;
                       case 5: pr1ntf("fld ");  pr1ntf("80real"); ref=r_m_( 0); printCol+=10;
                               if (isGoodAddress(ref)) lclass=517;
                               break;
                       case 7: pr1ntf("fstp "); pr1ntf("80real"); ref=r_m_( 0); printCol+=11;
                               if (isGoodAddress(ref)) lclass=517;
                               break;
                       default:    fatalError=206;
                   }
            }
            else
            {
                if (i_mod<0xC8)      {pr2ntf("fcmovnb st(0), st(%1d)", i_mod-0xC0);printCol+=20;}
                else if (i_mod <0xD0){pr2ntf("fcmovne st(0), st(%1d)", i_mod-0xC8);printCol+=20;}
                else if (i_mod <0xD8){pr2ntf("fcmovnbe st(0), st(%1d)",i_mod-0xD0);printCol+=21;}
                else if (i_mod <0xE0){pr2ntf("fcmovnu st(0), st(%1d)", i_mod-0xD8);printCol+=20;}
                else if (i_mod==0xE2){pr1ntf("fnclex")                            ;printCol+=6;    }
                else if (i_mod==0xE3){pr1ntf("fninit")                            ;printCol+=6;    }
                else if (i_mod <0xE8) fatalError=208;
                else if (i_mod <0xF0){pr2ntf("fucomi st(0), st(%1d)", i_mod-0xE8) ;printCol+=19;}
                else if (i_mod <0xF8){pr2ntf("fcomi st(0), st(%1d)", i_mod-0xF0)  ;printCol+=18;}
            }
            break;
        case 0xDC: 
            if (i_mod<0xC0)
            {
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("fadd "); pr1ntf("64real"); ref=r_m_( 0); printCol+=11; 
                               if (isGoodAddress(ref)) lclass=528;
                               break;
                       case 1: pr1ntf("fmul "); pr1ntf("64real"); ref=r_m_( 0); printCol+=11; 
                               if (isGoodAddress(ref)) lclass=528;
                               break;
                       case 2: pr1ntf("fcom "); pr1ntf("64real"); ref=r_m_( 0); printCol+=11; 
                               if (isGoodAddress(ref)) lclass=528;
                               break;
                       case 3: pr1ntf("fcomp ");pr1ntf("64real"); ref=r_m_( 0); printCol+=12; 
                               if (isGoodAddress(ref)) lclass=528;
                               break;
                       case 4: pr1ntf("fsub "); pr1ntf("64real"); ref=r_m_( 0); printCol+=11; 
                               if (isGoodAddress(ref)) lclass=528;
                               break;
                       case 5: pr1ntf("fsubr ");pr1ntf("64real"); ref=r_m_( 0); printCol+=12; 
                               if (isGoodAddress(ref)) lclass=528;
                               break;
                       case 6: pr1ntf("fdiv "); pr1ntf("64real"); ref=r_m_( 0); printCol+=11; 
                               if (isGoodAddress(ref)) lclass=528;
                               break;
                       case 7: pr1ntf("fdivr ");pr1ntf("64real"); ref=r_m_( 0); printCol+=12; 
                               if (isGoodAddress(ref)) lclass=528;
                               break;
                       default:    fatalError=210;
                   }
            }
            else
            {
                if (i_mod<0xC8)      {pr2ntf("fadd st(0), st(%1d)", i_mod-0xC0);printCol+=17;}
                else if (i_mod <0xD0){pr2ntf("fmul st(0), st(%1d)", i_mod-0xC8);printCol+=17;}
                else if (i_mod <0xE0) fatalError=212;
                else if (i_mod <0xE8){pr2ntf("fsub st(0), st(%1d)",i_mod-0xE0);printCol+=18;}
                else if (i_mod <0xF0){pr2ntf("fsubr st(0), st(%1d)", i_mod-0xD8);printCol+=17;}
                else if (i_mod <0xF8){pr2ntf("fdiv st(0), st(%1d)",i_mod-0xF0);printCol+=18;}
                else                 {pr2ntf("fdivr st(0), st(%1d)", i_mod-0xF8);printCol+=17;}
            }
            break;
        case 0xDD: 
            if (i_mod<0xC0)
            {
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("fld ");  pr1ntf("64real");   ref=r_m_( 0); printCol+=10; 
                               if (isGoodAddress(ref)) lclass=528;
                               break;
                       case 2: pr1ntf("fst ");  pr1ntf("64real");   ref=r_m_( 0); printCol+=10; 
                               if (isGoodAddress(ref)) lclass=528;
                               break;
                       case 3: pr1ntf("fstp "); pr1ntf("64real");   ref=r_m_( 0); printCol+=11; 
                               if (isGoodAddress(ref)) lclass=528;
                               break;
                       case 4: pr1ntf("frstor ");pr1ntf("94/108byte");ref=r_m_( 0);printCol+=17;
                               if (isGoodAddress(ref)) lclass=519;
                               break;
                       case 6: pr1ntf("fnsave ");pr1ntf("94/108byte");ref=r_m_( 0);printCol+=17;
                               if (isGoodAddress(ref)) lclass=519;
                               break;
                       case 7: pr1ntf("fnstsw ");pr1ntf("2byte"); ref=r_m_( 0);   printCol+=12; 
                               if (isGoodAddress(ref)) lclass=516;
                               break;
                       default:    fatalError=214;
                   }
            }
            else
            {
                if (i_mod<0xC8)      {pr2ntf("ffree st(%1d)", i_mod-0xC0);printCol+=11;}
                else if (i_mod <0xD0) fatalError=216;
                else if (i_mod <0xD8){pr2ntf("fst st(%1d)",   i_mod-0xD0);printCol+=9; }
                else if (i_mod <0xE0){pr2ntf("fstp st(%1d)",  i_mod-0xD8);printCol+=10;}
                else if (i_mod==0xE1){pr1ntf("fucom")                    ;printCol+=5; }
                else if (i_mod <0xE8){pr2ntf("fucom st(%1d)", i_mod-0xE0);printCol+=11;}
                else if (i_mod==0xE9){pr1ntf("fucomp")                   ;printCol+=6; }
                else if (i_mod <0xF0){pr2ntf("fucomp st(%1d)",i_mod-0xE8);printCol+=12;}
                else fatalError=218;
            }
            break;
        case 0xDE: 
            if (i_mod<0xC0)
            {
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("fiadd ");  pr1ntf("16int");ref=r_m_( 0); printCol+=6; 
                               if (isGoodAddress(ref)) lclass=516;
                               break;
                       case 1: pr1ntf("fimul ");  pr1ntf("16int");ref=r_m_( 0); printCol+=6; 
                               if (isGoodAddress(ref)) lclass=516;
                               break;
                       case 2: pr1ntf("ficom ");  pr1ntf("16int");ref=r_m_( 0); printCol+=6; 
                               if (isGoodAddress(ref)) lclass=516;
                               break;
                       case 3: pr1ntf("ficomp "); pr1ntf("16int");ref=r_m_( 0); printCol+=7; 
                               if (isGoodAddress(ref)) lclass=516;
                               break;
                       case 4: pr1ntf("fisub ");  pr1ntf("16int");ref=r_m_( 0); printCol+=6; 
                               if (isGoodAddress(ref)) lclass=516;
                               break;
                       case 5: pr1ntf("fisubr "); pr1ntf("16int");ref=r_m_( 0); printCol+=7; 
                               if (isGoodAddress(ref)) lclass=516;
                               break;
                       case 6: pr1ntf("fidiv ");  pr1ntf("16int");ref=r_m_( 0); printCol+=6; 
                               if (isGoodAddress(ref)) lclass=516;
                               break;
                       case 7: pr1ntf("fidivr "); pr1ntf("16int");ref=r_m_( 0); printCol+=7; 
                               if (isGoodAddress(ref)) lclass=516;
                               break;
                       default:    fatalError=220;
                   }
            }
            else
            {
                 if(i_mod==0xC1)      {pr1ntf("faddp")                            ;printCol+=5;    }
                 else if (i_mod <0xC8){pr2ntf("faddp st(%1d), st(0)", i_mod-0xC0) ;printCol+=18;}
                 else if (i_mod==0xC9){pr1ntf("fmulp")                            ;printCol+=5;    }
                 else if (i_mod <0xD0){pr2ntf("fmulp st(%1d), st(0)", i_mod-0xC8) ;printCol+=18;}
                 else if (i_mod==0xD9){pr1ntf("fcompp")                           ;printCol+=6;    }
                 else if (i_mod <0xE0) fatalError=222;                               
                 else if (i_mod==0xE1){pr1ntf("fsubrp");                          ;printCol+=6;    }
                 else if (i_mod <0xE8){pr2ntf("fsubrp st(%1d), st(0)", i_mod-0xE0);printCol+=19;}
                 else if (i_mod==0xE9){pr1ntf("fsubp")                               ;printCol+=5;    }
                 else if (i_mod <0xF0){pr2ntf("fsubp st(%1d), st(0)", i_mod-0xE8) ;printCol+=18;}
                 else if (i_mod==0xF1){pr1ntf("fdivrp")                           ;printCol+=6;    }
                 else if (i_mod <0xF8){pr2ntf("fdivrp st(%1d), st(0)", i_mod-0xF0);printCol+=18;}
                 else if (i_mod==0xF9){pr1ntf("fdivp")                            ;printCol+=5;    }
                 else                 {pr2ntf("fdivp st(%1d), st(0)", i_mod-0xF8) ;printCol+=18;}
            }
            break;
        case 0xDF: 
            if (i_mod<0xC0)
            {
                   switch(regTable[i_mod])
                   {
                       case 0: pr1ntf("fild ");  pr1ntf("16int");ref=r_m_( 0); printCol+=10; 
                               if (isGoodAddress(ref)) lclass=516;
                               break;
                       case 2: pr1ntf("fist ");  pr1ntf("16int");ref=r_m_( 0); printCol+=10; 
                               if (isGoodAddress(ref)) lclass=516;
                               break;
                       case 3: pr1ntf("fistp "); pr1ntf("16int");ref=r_m_( 0); printCol+=11; 
                               if (isGoodAddress(ref)) lclass=516;
                               break;
                       case 4: pr1ntf("fbld ");  pr1ntf("80bcd");ref=r_m_( 0); printCol+=10; 
                               if (isGoodAddress(ref)) lclass=517;
                               break;
                       case 5: pr1ntf("fild ");  pr1ntf("64int");ref=r_m_( 0); printCol+=10; 
                               if (isGoodAddress(ref)) lclass=528;
                               break;
                       case 6: pr1ntf("fbstp "); pr1ntf("80bcd");ref=r_m_( 0); printCol+=11; 
                               if (isGoodAddress(ref)) lclass=517;
                               break;
                       case 7: pr1ntf("fistp "); pr1ntf("64int");ref=r_m_( 0); printCol+=11; 
                               if (isGoodAddress(ref)) lclass=528;
                               break;
                       default:                     fatalError=224;
                   }
            }
            else
            {
                 if(i_mod <0xDF)       fatalError=226;
                 else if (i_mod==0xE0){pr1ntf("fnstsw ax")                         ;printCol+=9; }
                 else if (i_mod <0xE8) fatalError=228;
                 else if (i_mod <0xF0){pr2ntf("fucomip st(0), st(%1d)", i_mod-0xE8);printCol+=20;}
                 else if (i_mod <0xF8){pr2ntf("fcomip st(0), st(%1d)", i_mod-0xF0) ;printCol+=19;}
                 else                  fatalError=230;
            }
            break;
        default:                       fatalError=232;
    }
    return 0;
} /* print12case() */
 

int print13case()
{
int    rr;

    if (operandOveride) rr=16; else rr=32;

    switch(regTable[i_mod])
    {                             
        case 0: pr1ntf("inc ");            ref=r_m_(rr);  printCol+=4; 
                if (isGoodAddress(ref)) 
                {if (operandOveride) lclass=516; else lclass=514;}
                break;
        case 1: pr1ntf("dec ");            ref=r_m_(rr);  printCol+=4; 
                if (isGoodAddress(ref)) 
                {if (operandOveride) lclass=516; else lclass=514;}
                break;
        case 2: pr1ntf("call ");                      printCol+=4;
                ref = r_m_(rr);
                lclass=13;
                if (nextMode)
                {    
                    if (i_mod>=0xD0)
                    {
                        reg=rmTable[i_mod];
                        if (temppos[reg]+128>cur_position) 
                        ref=tempref[reg]; temppos[reg]=cur_position;
                    }
                }
                else printName(cur_position);
                break;
        case 3: pr1ntf("call ");     ref = m16_32(); lclass=17;  printCol+=4;
                break;
        case 4: pr1ntf("jmp ");                                     printCol+=4;
                ref=r_m_(32);
                
                if (gotJmpRef) 
                {   lclass=128+5; gotJmpRef=0;  } 
                else lclass=5;
                if (i_mod>=0xD0)
                {
                    reg=rmTable[i_mod];
                    if (temppos[reg]+128>cur_position) 
                    ref=tempref[reg]; temppos[reg]=cur_position;
                }
                
                needJump=1;     needJumpNext=cur_position+i_col;
                if (nextMode)
                {
                    // it is OK to mark anchor...because it will not be erased easily??
                    lastAnchor=cur_position+i_col-1;
                    pushTrace(150);
                    orMap(lastAnchor, MAP_ANCHOR_SET);
                    popTrace();
                }
                else printName(cur_position);
                break;
        case 5: pr1ntf("jmp ");      ref = m16_32();   lclass = 9;  printCol+=4;
                needJump=1;     needJumpNext=cur_position+i_col;
                break;
        case 6: pr1ntf("push ");     ref =  r_m_(rr);                printCol+=5;
                lclass = 513;
        // well I really don't know it is reasonably safe to do this.
        // I think when we push some (possible) address references into stack
        // there is strong reason to do so. that's why i am doing this. i guess...
                break;
        default: fatalError=234;
    }  
    return 0;
}

int print14case()
{
int    rr;

    if (operandOveride) rr=16; else rr=32;

    if (i_opcode==0xF6)
    {
        switch(regTable[i_mod])
        {
            case 0: pr1ntf("test "); ref=r_m_( 8); pr1ntf(", "); print_i_byte(); printCol+=7; 
                    if (isGoodAddress(ref)) lclass=520;
                    break;
            case 2:    pr1ntf("not ");  ref=r_m_( 8);                               printCol+=4; 
                    if (isGoodAddress(ref)) lclass=520;
                    break;
            case 3:    pr1ntf("neg ");  ref=r_m_( 8);                               printCol+=4; 
                    if (isGoodAddress(ref)) lclass=520;
                    break;
            case 4:    pr1ntf("mul ");  ref=r_m_( 8);                               printCol+=4; 
                    if (isGoodAddress(ref)) lclass=520;
                    break;
            case 5:    pr1ntf("imul "); ref=r_m_( 8);                               printCol+=4; 
                    if (isGoodAddress(ref)) lclass=520;
                    break;
            case 6:    pr1ntf("div ");  ref=r_m_( 8);                               printCol+=4; 
                    if (isGoodAddress(ref)) lclass=520;
                    break;
            case 7:    pr1ntf("idiv "); ref=r_m_( 8);                               printCol+=5; 
                    if (isGoodAddress(ref)) lclass=520;
                    break;
            default: fatalError=303;
        }
    }
    else if (i_opcode==0xF7)
    {
        switch(regTable[i_mod])
        {
            case 0:    pr1ntf("test "); ref=r_m_(rr); pr1ntf(", "); print_i_dword(); printCol+=7; 
                    break;
            case 2:    pr1ntf("not ");  ref=r_m_(rr);                                printCol+=4;
                    break;
            case 3:    pr1ntf("neg ");  ref=r_m_(rr);                                printCol+=4;
                    break;
            case 4:    pr1ntf("mul ");  ref=r_m_(rr);                                printCol+=4; 
                    break;
            case 5:    pr1ntf("imul "); ref=r_m_(rr);                                printCol+=5; 
                    break;
            case 6:    pr1ntf("div ");  ref=r_m_(rr);                                printCol+=4;
                    break;
            case 7:    pr1ntf("idiv "); ref=r_m_(rr);                                printCol+=5; 
                    break;
            default: fatalError=305;
        }
        if (isGoodAddress(ref)) 
        {if (operandOveride) lclass=516; else lclass=514;}
    }
    else fatalError=307;
    return 0;
}

int print15case()
{
int    rr;

    if (operandOveride) rr=16; else rr=32;

    if (i_opcode==0xD9)
    {
        if (regTable[i_mod]==6)
        {
            pr1ntf("fstenv 14/28byte"); ref=r_m_(rr);  printCol+=16;
            if (isGoodAddress(ref)) lclass=515;
        }
        else if (regTable[i_mod]==7)
        {
            pr1ntf("fstcw 2byte");      ref=r_m_(rr);  printCol+=11;
            if (isGoodAddress(ref)) lclass=516;
        }
        else fatalError=309;
    }
    else if (i_opcode==0xDB)
    {
        if (i_mod==0xE2)      {pr1ntf("fclex ");}            
        else if (i_mod==0xE3) {pr1ntf("finit ");}             
        else fatalError=311;  printCol+=6;
    }
    else if (i_opcode==0xDD)
    {
        if (regTable[i_mod]==6)
        {
            pr1ntf("fsave 94/108byte"); ref=r_m_(rr); printCol+=16;
            if (isGoodAddress(ref)) lclass=519;
        }
        else if (regTable[i_mod]==7)
        {
            pr1ntf("fstsw 2byte");      ref=r_m_(rr); printCol+=11;
            if (isGoodAddress(ref)) lclass=516;
        }
        else fatalError=313;
    }
    else if (i_opcode==0xDF)
    {
        if (i_mod==0xE0) {pr1ntf("fstsw ax ");}     
        else fatalError=315;     printCol+=9;
    }
    else if (i_opcode==0x9B) {pr1ntf("wait");     printCol+=4;}  
    else fatalError=317;
    return 0;
}

int print16case()
{
int    rr;

    if (operandOveride) rr=16; else rr=32;

    if (prefixStack[i_psp-1]==0xF2)
    {
        switch(i_opcode)
        {
            case 0xA6: pr1ntf("repne cmpsb"); printCol+=11; break;
            case 0xA7: if (operandOveride) {pr1ntf("repne cmpsw");}
                       else                {pr1ntf("repne cmpsd");} printCol+=11; break;
            case 0xAE: pr1ntf("repne scasb"); printCol+=11; break;
            case 0xAF: if (operandOveride) {pr1ntf("repne scasw");}
                       else                {pr1ntf("repne scasd");} printCol+=11; break;
            default: fatalError=319;
        }
    }
    else if (prefixStack[i_psp-1]==0xF3)
    {
        switch(i_opcode)
        {
            case 0x6C: pr1ntf("rep ins byte"); 
                       ref=r_m_( 8);pr1ntf(", port[dx]"); printCol+=22; 
                       if (isGoodAddress(ref)) lclass=520;
                       break;
            case 0x6D: if (operandOveride){pr1ntf("rep ins word") ;printCol+=12;}
                       else               {pr1ntf("rep ins dword");printCol+=13;}
                       ref=r_m_(rr);pr1ntf(", port[dx]");            printCol+=10;
                       if (isGoodAddress(ref)) 
                       {if (operandOveride) lclass=516; else lclass=514;}
                       break; 
            case 0x6E: pr1ntf("rep outs port[dx], byte");             printCol+=23;
                       ref=r_m_( 8);
                       if (isGoodAddress(ref)) lclass=520;
                       break;
            case 0x6F: if (operandOveride){pr1ntf("rep outs port[dx], word");printCol+=23;}
                       else{pr1ntf("rep outs port[dx], dword")              ;printCol+=24;} 
                       r_m_(rr); 
                       break;
            case 0xA4: pr1ntf("rep movsb");                        printCol+=9;   
                       break;
            case 0xA5: if (operandOveride) {pr1ntf("rep movsw");}
                       else                {pr1ntf("rep movsd");}    printCol+=9;       
                       break;
            case 0xA6: pr1ntf("repe cmpsb");                       printCol+=10;   
                       break;
            case 0xA7: if (operandOveride) {pr1ntf("repe cmpsw");}
                       else                {pr1ntf("repe cmpsd");}   printCol+=10;   
                       break;
            case 0xAA: pr1ntf("rep stosb");                        printCol+=9;   
                       break;
            case 0xAB: if (operandOveride) {pr1ntf("rep stosw");}
                       else                {pr1ntf("rep stosd");}    printCol+=9;   
                       break;
            case 0xAC: pr1ntf("rep lods al");                      printCol+=11;   
                       break;
            case 0xAD: if (operandOveride){pr1ntf("rep lods ax") ;printCol+=11;}
                       else               {pr1ntf("rep lods eax");printCol+=12;}    
                       break;
            case 0xAE: pr1ntf("repe scasb");                       printCol+=10;   
                       break;
            case 0xAF: if (operandOveride) {pr1ntf("repe scasw");}
                       else                {pr1ntf("repe scasd");}   printCol+=10;   
                       break; 
            default: fatalError=321;
        }
    }
    else fatalError=323;
    return 0;
}

/* *************************************************************** */
/* *************************************************************** */
/*         2 byte opcode printing starts here!                     */
/* *************************************************************** */
/* *************************************************************** */
int print20case()
{
    switch(i_opcode)
    {
        case 0x06:  pr1ntf("clts");      printCol+=4;  break;
        case 0x08:  pr1ntf("invd");      printCol+=4;  break;
        case 0x09:  pr1ntf("wbinvd");    printCol+=6;  break; 
        case 0x0B:  pr1ntf("ud2");       printCol+=3;  break;   
        case 0x30:  pr1ntf("wrmsr");     printCol+=5;  break;
        case 0x31:  pr1ntf("rdtsc");     printCol+=5;  break;
        case 0x32:  pr1ntf("rdmsr");     printCol+=5;  break;
        case 0x33:  pr1ntf("rdpmc");     printCol+=5;  break;
        case 0x34:  pr1ntf("sysenter");     printCol+=8;  break;
        case 0x35:  pr1ntf("sysexit");     printCol+=7;  break;
        case 0x77:  pr1ntf("emms");      printCol+=4;  break;   
        case 0xA0:  pr1ntf("push fs");   printCol+=7;  break;   
        case 0xA1:  pr1ntf("pop fs");    printCol+=6;  break;  
        case 0xA2:  pr1ntf("cpuid");     printCol+=5;  break;   
        case 0xA8:  pr1ntf("push gs");   printCol+=7;  break;   
        case 0xA9:  pr1ntf("pop gs");    printCol+=6;  break;   
        case 0xAA:  pr1ntf("rsm");         printCol+=3;  break;   
        case 0xC8:  pr1ntf("bswap eax"); printCol+=9;  break;   
        case 0xC9:  pr1ntf("bswap ecx"); printCol+=9;  break;   
        case 0xCA:  pr1ntf("bswap edx"); printCol+=9;  break;   
        case 0xCB:  pr1ntf("bswap ebx"); printCol+=9;  break;   
        case 0xCC:  pr1ntf("bswap esp"); printCol+=9;  break;   
        case 0xCD:  pr1ntf("bswap ebp"); printCol+=9;  break;   
        case 0xCE:  pr1ntf("bswap esi"); printCol+=9;  break;   
        case 0xCF:  pr1ntf("bswap edi"); printCol+=9;  break;   
        default:    fatalError=325;
    }
    return 0;
}

int print21case()
{
    switch(i_opcode)
    {
        case 0x80:  pr1ntf("jo ");     printCol+=3;  break;
        case 0x81:  pr1ntf("jno ");     printCol+=4;  break;
        case 0x82:  pr1ntf("jb ");     printCol+=3;  break;
        case 0x83:  pr1ntf("jae ");     printCol+=4;  break;
        case 0x84:  pr1ntf("je ");     printCol+=3;  break;
        case 0x85:  pr1ntf("jne ");     printCol+=4;  break;
        case 0x86:  pr1ntf("jbe ");     printCol+=4;  break;
        case 0x87:  pr1ntf("ja ");     printCol+=3;  break;
        case 0x88:  pr1ntf("js ");     printCol+=3;  break;
        case 0x89:  pr1ntf("jns ");     printCol+=4;  break;
        case 0x8A:  pr1ntf("jpe ");     printCol+=4;  break;
        case 0x8B:  pr1ntf("jpo ");     printCol+=4;  break;
        case 0x8C:  pr1ntf("jl ");     printCol+=3;  break;
        case 0x8D:  pr1ntf("jge ");     printCol+=4;  break;
        case 0x8E:  pr1ntf("jle ");     printCol+=4;  break;
        case 0x8F:  pr1ntf("jg ");     printCol+=3;  break;
        default:    fatalError=327;
    }    
    ref = print_rel32();  lclass =  4; 
    return 0;
}

int print22case()
{
int    rr;

    if (operandOveride) rr=16; else rr=32;

    switch(i_opcode)
    {
        case 0x02: pr1ntf("lar ");       r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=6;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x03: pr1ntf("lsl ");       r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=6;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x20: pr1ntf("mov "); r___(rr);pr2ntf(", cr%1d", rmTable[i_mod]);printCol+=9;
                   break;    
        case 0x21: pr1ntf("mov "); r___(rr);pr2ntf(", dr%1d", rmTable[i_mod]);printCol+=9; 
                   break;   
        case 0x22: pr2ntf("mov cr%1d, ",rmTable[i_mod]);       r___(rr);printCol+=9;
                   break;    
        case 0x23: pr2ntf("mov dr%1d, ",rmTable[i_mod]);       r___(rr);printCol+=9;
                   break;    
        case 0x40: pr1ntf("cmovo ");     r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=8;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x41: pr1ntf("cmovno ");    r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=9;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x42: pr1ntf("cmovb ");     r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=8;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x43: pr1ntf("cmovae ");    r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=9;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x44: pr1ntf("cmove ");     r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=8;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x45: pr1ntf("cmovne ");    r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=9;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x46: pr1ntf("cmovbe ");    r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=9;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x47: pr1ntf("cmova ");     r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=8;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x48: pr1ntf("cmovs ");     r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=8;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x49: pr1ntf("cmovns ");    r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=9;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x4A: pr1ntf("cmovpe ");    r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=9;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x4B: pr1ntf("cmovpo ");    r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=9;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x4C: pr1ntf("cmovl ");     r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=8;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x4D: pr1ntf("cmovge ");    r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=9;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x4E: pr1ntf("cmovle ");    r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=9;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x4F: pr1ntf("cmovg ");     r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=8;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x60: pr1ntf("punpcklbw "); mm____();pr1ntf(", ");ref=r_m_(64);printCol+=12;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x61: pr1ntf("punpcklwd "); mm____();pr1ntf(", ");ref=r_m_(64);printCol+=12;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x62: pr1ntf("punpckldq "); mm____();pr1ntf(", ");ref=r_m_(64);printCol+=12;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x63: pr1ntf("packsswb ");  mm____();pr1ntf(", ");ref=r_m_(64);printCol+=11;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x64: pr1ntf("pcmpgtb ");   mm____();pr1ntf(", ");ref=r_m_(64);printCol+=10;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x65: pr1ntf("pcmpgtw ");   mm____();pr1ntf(", ");ref=r_m_(64);printCol+=10;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x66: pr1ntf("pcmpgtd ");   mm____();pr1ntf(", ");ref=r_m_(64);printCol+=10;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x67: pr1ntf("packuswb ");  mm____();pr1ntf(", ");ref=r_m_(64);printCol+=11;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x68: pr1ntf("punpckhbw "); mm____();pr1ntf(", ");ref=r_m_(64);printCol+=12;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x69: pr1ntf("punpckhwd "); mm____();pr1ntf(", ");ref=r_m_(64);printCol+=12;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x6A: pr1ntf("punpckhdq "); mm____();pr1ntf(", ");ref=r_m_(64);printCol+=12;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x6B: pr1ntf("packssdw ");  mm____();pr1ntf(", ");ref=r_m_(64);printCol+=11;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x6E: pr1ntf("movd ");      mm____();pr1ntf(", ");ref=r_m_(rr);printCol+=7;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0x6F: pr1ntf("movq ");      mm____();pr1ntf(", ");ref=r_m_(64);printCol+=7;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x74: pr1ntf("pcmpeqb ");   mm____();pr1ntf(", ");ref=r_m_(64);printCol+=10;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x75: pr1ntf("pcmpeqw ");   mm____();pr1ntf(", ");ref=r_m_(64);printCol+=10;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x76: pr1ntf("pcmpeqd ");   mm____();pr1ntf(", ");ref=r_m_(64);printCol+=10;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x7E: pr1ntf("movd ");      r_m_(rr);pr1ntf(", ");ref=mm____();printCol+=7;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x7F: pr1ntf("movq ");      r_m_(64);pr1ntf(", ");ref=mm____();printCol+=7;
                   if (isGoodAddress(ref)) lclass=518;
                   break;    
        case 0x90: pr1ntf("seto ");      ref=r_m_( 8);                      printCol+=5;
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
        case 0x91: pr1ntf("setno ");     ref=r_m_( 8);                      printCol+=6;
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
        case 0x92: pr1ntf("setb ");      ref=r_m_( 8);                      printCol+=5;
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
        case 0x93: pr1ntf("setae ");     ref=r_m_( 8);                      printCol+=6;
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
        case 0x94: pr1ntf("sete ");      ref=r_m_( 8);                      printCol+=5;
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
        case 0x95: pr1ntf("setne ");     ref=r_m_( 8);                      printCol+=6;
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
        case 0x96: pr1ntf("setbe ");     ref=r_m_( 8);                      printCol+=6;
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
        case 0x97: pr1ntf("seta ");      ref=r_m_( 8);                      printCol+=5;
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
        case 0x98: pr1ntf("sets ");      ref=r_m_( 8);                      printCol+=5;
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
        case 0x99: pr1ntf("setns ");     ref=r_m_( 8);                      printCol+=6;
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
        case 0x9A: pr1ntf("setpe ");     ref=r_m_( 8);                      printCol+=6;
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
        case 0x9B: pr1ntf("setpo ");     ref=r_m_( 8);                      printCol+=6;
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
        case 0x9C: pr1ntf("setl ");      ref=r_m_( 8);                      printCol+=5;
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
        case 0x9D: pr1ntf("setge ");     ref=r_m_( 8);                         printCol+=6;
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
        case 0x9E: pr1ntf("setle ");     ref=r_m_( 8);                         printCol+=6;
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
        case 0x9F: pr1ntf("setg ");      ref=r_m_( 8);                         printCol+=5;
                   if (isGoodAddress(ref)) lclass=520;
                   break; 
        case 0xA3: pr1ntf("bt ");        ref=r_m_(rr);pr1ntf(", ");r___(rr);printCol+=5;
                   if (isGoodAddress(ref))
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0xA5: pr1ntf("shld ");      ref=r_m_(rr);pr1ntf(", ");r___(rr);printCol+=11;
                                                  pr1ntf(", cl");       
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;
        case 0xAB: pr1ntf("bts ");       ref=r_m_(rr);pr1ntf(", ");r___(rr);printCol+=6;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0xAD: pr1ntf("shrd ");      ref=r_m_(rr);pr1ntf(", ");r___(rr);printCol+=11;      
                                                  pr1ntf(", cl");       
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;
        case 0xAF: pr1ntf("imul ");      r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=7;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0xB0: pr1ntf("cmpxchg ");   ref=r_m_( 8);pr1ntf(", ");r___( 8);printCol+=10;
                   if (isGoodAddress(ref)) lclass=520;
                   break;    
        case 0xB1: pr1ntf("cmpxchg ");   ref=r_m_(rr);pr1ntf(", ");r___(rr);printCol+=10;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0xB2: pr1ntf("lss ");       r___(rr);pr1ntf(", ");ref=m16_32();printCol+=6;
                   if (isGoodAddress(ref)) lclass=516;
                   break;   
        case 0xB3: pr1ntf("btr ");       ref=r_m_(rr);pr1ntf(", ");r___(rr);printCol+=6;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0xB4: pr1ntf("lfs ");       r___(rr);pr1ntf(", ");ref=m16_32();printCol+=6;
                   if (isGoodAddress(ref)) lclass=516;
                   break;   
        case 0xB5: pr1ntf("lgs ");       r___(rr);pr1ntf(", ");ref=m16_32();printCol+=6;
                   if (isGoodAddress(ref)) lclass=516;
                   break;   
        case 0xB6: pr1ntf("movzx ");     r___(rr);pr1ntf(", ");ref=r_m_( 8);printCol+=8;
                   if (isGoodAddress(ref)) lclass=520;
                   break;    
        case 0xB7: pr1ntf("movzx ");     r___(rr);pr1ntf(", ");ref=r_m_(16);printCol+=8;
                   if (isGoodAddress(ref)) lclass=516;
                   break;    
        case 0xBB: pr1ntf("btc ");       ref=r_m_(rr);pr1ntf(", ");r___(rr);printCol+=6;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0xBC: pr1ntf("bsf ");       r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=6;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0xBD: pr1ntf("bsr ");         r___(rr);pr1ntf(", ");ref=r_m_(rr);printCol+=6;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0xBE: pr1ntf("movsx ");     r___(rr);pr1ntf(", ");ref=r_m_( 8);printCol+=8;
                   if (isGoodAddress(ref)) lclass=520;
                   break;    
        case 0xBF: pr1ntf("movsx ");     r___(rr);pr1ntf(", ");ref=r_m_(16);printCol+=8;
                   if (isGoodAddress(ref)) lclass=516;
                   break;    
        case 0xC0: pr1ntf("xadd ");      ref=r_m_( 8);pr1ntf(", ");r___( 8);printCol+=7;
                   if (isGoodAddress(ref)) lclass=520;
                   break;    
        case 0xC1: pr1ntf("xadd ");      ref=r_m_(rr);pr1ntf(", ");r___(rr);printCol+=7;
                   if (isGoodAddress(ref)) 
                   {if (operandOveride) lclass=516; else lclass=514;}
                   break;    
        case 0xD1: pr1ntf("psrlw ");     mm____();pr1ntf(", ");ref=r_m_(64);printCol+=8;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xD2: pr1ntf("psrld ");     mm____();pr1ntf(", ");ref=r_m_(64);printCol+=8;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xD3: pr1ntf("psrlq ");     mm____();pr1ntf(", ");ref=r_m_(64);printCol+=8;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xD5: pr1ntf("pmullw ");    mm____();pr1ntf(", ");ref=r_m_(64);printCol+=9;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xD8: pr1ntf("psubusb ");   mm____();pr1ntf(", ");ref=r_m_(64);printCol+=10;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xD9: pr1ntf("psubusw ");   mm____();pr1ntf(", ");ref=r_m_(64);printCol+=10;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xDB: pr1ntf("pand ");      mm____();pr1ntf(", ");ref=r_m_(64);printCol+=7;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xDC: pr1ntf("paddusb ");   mm____();pr1ntf(", ");ref=r_m_(64);printCol+=10;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xDD: pr1ntf("paddusw ");   mm____();pr1ntf(", ");ref=r_m_(64);printCol+=10;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xDF: pr1ntf("pandn ");     mm____();pr1ntf(", ");ref=r_m_(64);printCol+=8;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xE1: pr1ntf("psraw ");     mm____();pr1ntf(", ");ref=r_m_(64);printCol+=8;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xE2: pr1ntf("psrad ");     mm____();pr1ntf(", ");ref=r_m_(64);printCol+=8;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xE5: pr1ntf("pmulhw ");    mm____();pr1ntf(", ");ref=r_m_(64);printCol+=9;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xE8: pr1ntf("psubsb ");    mm____();pr1ntf(", ");ref=r_m_(64);printCol+=9;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xE9: pr1ntf("psubsw ");    mm____();pr1ntf(", ");ref=r_m_(64);printCol+=9;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xEB: pr1ntf("por ");       mm____();pr1ntf(", ");ref=r_m_(64);printCol+=5;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xEC: pr1ntf("paddsb ");    mm____();pr1ntf(", ");ref=r_m_(64);printCol+=9;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xED: pr1ntf("paddsw ");    mm____();pr1ntf(", ");ref=r_m_(64);printCol+=9;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xEF: pr1ntf("pxor ");      mm____();pr1ntf(", ");ref=r_m_(64);printCol+=7;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xF1: pr1ntf("psllw ");     mm____();pr1ntf(", ");ref=r_m_(64);printCol+=8;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xF2: pr1ntf("pslld ");     mm____();pr1ntf(", ");ref=r_m_(64);printCol+=8;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xF3: pr1ntf("psllq ");     mm____();pr1ntf(", ");ref=r_m_(64);printCol+=8;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xF5: pr1ntf("pmaddwd ");   mm____();pr1ntf(", ");ref=r_m_(64);printCol+=10;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xF8: pr1ntf("psubb ");     mm____();pr1ntf(", ");ref=r_m_(64);printCol+=8;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xF9: pr1ntf("psubw ");     mm____();pr1ntf(", ");ref=r_m_(64);printCol+=8;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xFA: pr1ntf("psubd ");     mm____();pr1ntf(", ");ref=r_m_(64);printCol+=8;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xFC: pr1ntf("paddb ");     mm____();pr1ntf(", ");ref=r_m_(64);printCol+=8;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xFD: pr1ntf("paddw ");     mm____();pr1ntf(", ");ref=r_m_(64);printCol+=8;
                   if (isGoodAddress(ref)) lclass=518;
                   break;   
        case 0xFE: pr1ntf("paddd ");     mm____();pr1ntf(", ");ref=r_m_(64);printCol+=8;
                   if (isGoodAddress(ref)) lclass=518;
                   break;
        default: fatalError=329;
    }
    return 0;
}

int print23case()
{
int    rr;

    if (operandOveride) rr=16; else rr=32;

    if (i_opcode==0xA4) 
    {
        pr1ntf("shld "); r_m_(rr);
        pr1ntf(", ");    r___(rr);
        pr1ntf(", ");    print_i_byte();  printCol+=9;
    }
    else
    {
        pr1ntf("shrd "); r_m_(rr);
        pr1ntf(", ");    r___(rr);
        pr1ntf(", ");    print_i_byte();  printCol+=9;
    }
    return 0;
}

int print24case()
{
int    rr;

    if (operandOveride) rr=16; else rr=32;

    if (i_opcode==0x00)
    {    
        switch(regTable[i_mod])
        {
            case 0: pr1ntf("sldt "); ref=r_m_(rr); printCol+=5; 
                    if (isGoodAddress(ref)) 
                    {if (operandOveride) lclass=516; else lclass=514;}
                    break;           
            case 1: pr1ntf("str ");  ref=r_m_(16); printCol+=4; 
                    if (isGoodAddress(ref)) lclass=516;
                    break;
            case 2: pr1ntf("lldt "); ref=r_m_(16); printCol+=5; 
                    if (isGoodAddress(ref)) lclass=516;
                    break;
            case 3: pr1ntf("ltr ");  ref=r_m_(16); printCol+=4; 
                    if (isGoodAddress(ref)) lclass=516;
                    break;
            case 4: pr1ntf("verr "); ref=r_m_(16); printCol+=5; 
                    if (isGoodAddress(ref)) lclass=516;
                    break;
            case 5: pr1ntf("verw "); ref=r_m_(16); printCol+=5; 
                    if (isGoodAddress(ref)) lclass=516;
                    break;
            default: fatalError=331;
        }
    }
    else if (i_opcode==0x01)
    {
        switch(regTable[i_mod])
        {
            case 0: pr1ntf("sgdt ");   ref=m_____(); printCol+=5; 
                    if (isGoodAddress(ref)) 
                    {if (operandOveride) lclass=516; else lclass=514;}
                    break;
            case 1: pr1ntf("sidt ");   ref=m_____(); printCol+=5; 
                    if (isGoodAddress(ref)) 
                    {if (operandOveride) lclass=516; else lclass=514;}
                    break;
            case 2: pr1ntf("lgdt ");   ref=m16_32(); printCol+=5; 
                    if (isGoodAddress(ref)) lclass=516;
                    break;
            case 3: pr1ntf("lidt ");   ref=m16_32(); printCol+=5; 
                    if (isGoodAddress(ref)) lclass=516;
                    break;
            case 4: pr1ntf("smsw ");   ref=r_m_(rr); printCol+=5; 
                    if (isGoodAddress(ref)) 
                    {if (operandOveride) lclass=516; else lclass=514;}
                    break;
            case 6: pr1ntf("lmsw ");   ref=r_m_(16); printCol+=5; 
                    if (isGoodAddress(ref)) lclass=516;
                    break;
            case 7: pr1ntf("invlpg "); ref=m_____(); printCol+=7; 
                    if (isGoodAddress(ref)) 
                    {if (operandOveride) lclass=516; else lclass=514;}
                    break;
            default: fatalError=333;
        }
    }
    else if (i_opcode==0xAE)
    {
             if (regTable[i_mod]==0) {pr1ntf("fxsave") ;printCol+=6;}
        else if (regTable[i_mod]==1) {pr1ntf("fxrstor");printCol+=7;}
        else fatalError=334;
    }
    else if (i_opcode==0xC7 && regTable[i_mod]==1)
    {
        pr1ntf("comxchg8b 64bit");     printCol+=15; 
        m_____();
    }
    else fatalError=335;
    return 0;
}

int print25case()
{
int    k;
int    rr;

    if (operandOveride) rr=16; else rr=32;

    k = regTable[i_mod];
    if (i_opcode==0x71)
    {
        if (k==2) 
        {
            pr1ntf("psrlw "); mmm___(); pr1ntf(", "); print_i_byte(); printCol+=8; 
        }
        else if (k==4)
        {
            pr1ntf("psraw "); mmm___(); pr1ntf(", "); print_i_byte(); printCol+=8; 
        }
        else if (k==6)
        {
            pr1ntf("psllw "); mmm___(); pr1ntf(", "); print_i_byte(); printCol+=8; 
        }
        else fatalError=337;
    }
    else if (i_opcode==0x72)
    {
        if (k==2)
        {
            pr1ntf("psrld "); mmm___(); pr1ntf(", "); print_i_byte(); printCol+=8; 
        }
        else if (k==4)
        {
            pr1ntf("psrad "); mmm___(); pr1ntf(", "); print_i_byte(); printCol+=8; 
        }
        else if (k==6)
        {
            pr1ntf("pslld "); mmm___(); pr1ntf(", "); print_i_byte(); printCol+=8; 
        }
        else fatalError=339;
    }
    else if (i_opcode==0x73)
    {
        if (k==2)
        {
            pr1ntf("psrlq "); mmm___(); pr1ntf(", "); print_i_byte(); printCol+=8; 
        }
        else if (k==6)
        {
            pr1ntf("psllq "); mmm___(); pr1ntf(", "); print_i_byte(); printCol+=8; 
        }
        else fatalError=341;
    }
    else if (i_opcode==0xBA)
    {
        if (k==4)
        {
            pr1ntf("bt ");    ref=r_m_(rr); pr1ntf(", "); print_i_byte32(); printCol+=5;
            if (isGoodAddress(ref)) 
            {if (operandOveride) lclass=516; else lclass=514;}
        }
        else if (k==5)
        {
            pr1ntf("bts ");   ref=r_m_(rr); pr1ntf(", "); print_i_byte32();    printCol+=6; 
            if (isGoodAddress(ref)) 
            {if (operandOveride) lclass=516; else lclass=514;}
        }
        else if (k==6)
        {
            pr1ntf("btr ");   ref=r_m_(rr); pr1ntf(", "); print_i_byte32();    printCol+=6; 
            if (isGoodAddress(ref)) 
            {if (operandOveride) lclass=516; else lclass=514;}
        }
        else if (k==7)
        {
            pr1ntf("btc ");   ref=r_m_(rr); pr1ntf(", "); print_i_byte32();    printCol+=6; 
            if (isGoodAddress(ref)) 
            {if (operandOveride) lclass=516; else lclass=514;}
        }
        else fatalError=343;
    }
    else fatalError=345;
    return 0;
}



