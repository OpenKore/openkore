//
//
// This program was written by Sang Cho, associate professor at
//                                       the department of
//                                       computer science and engineering
//                                       chongju university
// language used: gcc
//
// date of second release: August 30, 1998 (alpha version)
// many fixed after release: October 9, 1998
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
//   Copyright (C) 1997,1998,1999,2001,2002,2003                  by Sang Cho.
//
// Permission is granted to make and distribute verbatim copies of this
// program provided the copyright notice and this permission notice are
// preserved on all copies.
//
// File: main.c

# include "disasm.h"

#define  INT_MAX   0x7FFFFFFF

#define  jLmax     50000
#define  hMax      5120
#define  hintMax   1024
#define  NAMEMAX   256
#define  COLSIZE   78

//FILE     *d_fp;
int      nextMode=0;           // some role in preprocessing
int      printMode=0;
int      zeroCheckMode=0;
int      lineno=0;
int      errorCount=0;
int      debugx=0;
int      debugTab[256]={0,};
char     mname[NAMEMAX];
int      fsize;
int      showDotsNum=0;

// Enable or disable additional info for print
DWORD    debugAdd  = 0;
DWORD    debugAdd1 = 0;

int      jLc;
_labels  pArray[jLmax];
_labels  suspicious[hMax]; // I am lazy so i will use _labes to store suspicious places...

int      dmc=0;
DWORD    dmLabels[32];
int      HintCnt=0;
_key_    Hints[hintMax]; // I am lazy so i will use _key_ structure to store hints...
int      hCnt=0;
history  History[hMax];
int      needJump=0;
DWORD    needJumpNext;
int      needCall=0;
DWORD    needCallRef, needCallNext;
DWORD    fatalPosition;
DWORD    fatalReference;

// *********************************************************
// ****************** main here ****************************
// *********************************************************

int main(argc,argv)
int argc; char **argv;
{
FILE     *my_fp;
//extern FILE  *d_fp;
int       i, n;
DWORD     r;
char      fname[NAMEMAX];

    if (argc == 2)
    {
        strcpy(fname, argv[1]);
        my_fp = fopen (argv[1], "rb");
        if (my_fp == NULL)
        {
        fprintf (stderr,"canNOTopenFILE: %s\n", argv[1]);
        exit (0);
        }
    }
    else if (argc == 3)
    {
        strcpy(fname, argv[1]);
        strcpy(mname, argv[2]);
        my_fp = fopen (argv[1], "rb");

        if (my_fp == NULL)
        {
        fprintf (stderr,"canNOTopenFILE: %s\n", argv[1]);
        exit (0);
        }

        readHint();
    }
    else
    {
         fprintf (stderr,"\nusage: disasm input_file_name > output_file_name");
		 fprintf (stderr,"\nversion 0.25 released February 3, 2003\n");
         exit (0);
    }

    fseek (my_fp, 0L, SEEK_END);
    fsize = ftell (my_fp);
    rewind (my_fp);

    lpFile = (void *) calloc (fsize,1);
    if (lpFile == NULL)
    {
        fprintf (stderr,"canNOTallocateMEMORY");
        exit (0);
    }

    printf ("Disassembly of File: %s\n\n", argv[1]);
    n = fread (lpFile, fsize, 1, my_fp);

    if (n == -1)
    {
        fprintf(stderr,"failed to read the FILE");
        exit (0);
    }

    // I need to connect pedump and preprocessing.

    initHeaders();

    pedump (argc, argv);     /* put together */

	//Myfinish();

    tryAnyAddress();
    tryPascalStrings();

	//Myfinish();
    printf ("\n");
    //printf ("\n*************** BEGINNING OF PROCESSING  ************************** \n");
    fprintf (stderr,"\n*************** PREPROCESSING BEGINS ************************** \n");

	showDotsNum=0;
    //fprintf(stderr,"entryPoint=%08X imageBase=%08X imagebaseRVA=%08X CodeOffset=%08X\n",
    //                (int)entryPoint, (int)imageBase, (int)imagebaseRVA, CodeOffset);
    //fprintf(stderr,"CodeSize=%08X",CodeSize);

    if (entryPoint>0) resetDisassembler(imageBase+entryPoint);
	else              resetDisassembler(imagebaseRVA);
    orMap(imageBase+entryPoint,0x40);
    EnterLabel(2048, imageBase+entryPoint, imageBase);

    nextMode = 1;       // to say now preprocessing is started.
    zeroCheckMode=1;
    printMode = 0;
    //printMode= 1;

    while (1)
    {
        debugx=0;
        /*-------------*/pushTrace(1000);
        Disassembler();
        /*-------------*/popTrace();
        if (fatalError) ErrorRecover();

        // I have to make sure there is no looping.
        // in a micro level or macro level. think BIG.... be happy.... october 27,1997
        /*-------------*/pushTrace(1010);
        r=GetNextOne();
        /*-------------*/popTrace();
        /*-------------*/pushTrace(1020);
        resetDisassembler(r);
        /*-------------*/popTrace();
        if (r==0) break;
    }

    if (debugAdd>0) MapSummary();
    //ReportMap();

    //Myfinish();
    /*-----------------*/pushTrace(1030);
    PostProcessing1();
    /*-----------------*/popTrace();

    //printf ("\n*************** END OF PREPROCESSING **************************** ");
    if (fatalError)
    {
        //printf("\nError=%d",fatalError);
        fatalError=0;
    }

    if (debugAdd>0)
	{
        printf ("\n\n*************** LABELS COLLECTED ARE: source side ******************** ");
        printf ("\n");

        sortTrees1();

        printf ("\n\n*************** LABELS COLLECTED ARE: destination ******************** ");
        printf ("\n");

        sortTrees();
    }

    /*-----------------*/pushTrace(1040);
    LabelProcess();
    /*-----------------*/popTrace();

    //ReportMap();

    //Myfinish();exit(0);
	#ifdef WIN32
	fprintf (stderr,"\n*************** DEBUG SYMBOLS BEGINS ************************** \n");
    printf ("\n\n+++++++++++++++++++ DEBUG SYMBOLS LISTING +++++++++++++++++++ \n");

	if(!getDebugInfo(fname)) {
	    fprintf (stderr,"\n Symbols Memory Allocated : %d\n",namesSize);
	} else {
	    printf ("\nFailed to get debug info\n");
	}
	#endif /* WIN32 */

    printf ("\n\n+++++++++++++++++++ ASSEMBLY CODE LISTING +++++++++++++++++++");
    printf ("\n//********************** Start of Code in Object CODE **************");
    printf ("\nProgram Entry Point = %08X (%s File Offset:%08X)\n",
            (int)(imageBase+entryPoint),argv[1],CodeOffset);
    fprintf (stderr,"\n\n*************** LISTING BEGINS *************************** \n");

	showDotsNum=0;
    nextMode = 0;        // to say now preporcessing is finished.
    zeroCheckMode=0;
    printMode=1;
    print_symbols = -1;
    resetDisassembler(imagebaseRVA);

    while (!GotEof)
    {
        debugx=0;
        /*-------------*/pushTrace(1050);
        Disassembler();
        /*-------------*/popTrace();

        if(GotEof) break;
        if(getOffset(cur_position)<CodeOffset+CodeSize)
           fprintf(stderr,"\na little disassemble error near :%08X\n", (int)cur_position);
        if(getOffset(cur_position)<CodeOffset+CodeSize)
           fprintf(stdout,"\na little disassemble error near :%08X\n", (int)cur_position);
        fatalError=0;
        i=ReadOneByte();
        addressfix();
        a_loc++;   i_col=0;
        pr3ntf("\n:%08X %02X",(int)cur_position, i);
    }

    Xreference();

    //sortTrees1();sortTrees();

	/* close files and release memory NOW */
    if (debugAdd>0) fprintf (stderr,
    "\naddL=%5d reset=%5d ErrorR=%5d eraseU=%5d totalZero=%08X",
     addLabelsNum, resetNum, ErrorRecoverNum, eraseUncertainNum,totZero);

    if (debugAdd>0) reportHistory();

	printf ("\n*************** END OF LISTING ********************************** \n");
    fprintf(stderr,"\n");

	Myfinish();
	return 1;
}
// **********************************************************************
// **************************end of main ********************************
// **********************************************************************

//
// all the functions used in the main
//

// **************************************
// disassembler block starts here
// **************************************

void initDisassembler()
{
    yyfirsttime = 1;                     // to refresh position from the file
    a_loc = 0;
    a_loc_save = 0;
    i_col = 0;
    i_col_save = 0;
    i_psp = 0;
    GotEof =0;
    lineno=0;
    NumberOfBytesProcessed = -1;
    operandOveride = 0;
    addressOveride = 0;
    dmc = 0;
    fatalError = 0;
    needJump=0;
    needCall=0;
    needCallRef=0;
    needCallNext=0;
    needJumpNext=0;
}

int   resetNum=0;
DWORD lastReset=0;
int   resetHistogram[256]={0,};

void  resetDisassembler(DWORD ref)
{
//int      i;

    initDisassembler();
    vCodeOffset = getOffset(ref);
    vCodeSize   = CodeOffset-vCodeOffset+CodeSize;
    delta       = vCodeOffset - CodeOffset;

    lastReset    = ref;
    cur_position = ref;

    // mark start position here.
    /*----------*/pushTrace(1060);
    if (nextMode) orMap(ref, 0x20);
    /*----------*/popTrace();

    //printf("\nresetDisassembler :%08X getByte=%02X",ref,getByteFile(ref));
	//if(nextMode)
	//fprintf(stderr,"\nresetDisassembler :%08X getByte=%02X",ref,getByteFile(ref));
    resetHistogram[getByteFile(ref)]+=1;
    resetNum++;
}

int      envSave[32];
void pushEnvironment()
{
    envSave[ 0]=yyfirsttime;
    envSave[ 1]=a_loc;
    envSave[ 2]=a_loc_save;
    envSave[ 3]=i_col;
    envSave[ 4]=i_col_save;
    envSave[ 5]=i_psp;
    envSave[ 6]=NumberOfBytesProcessed;
    envSave[ 7]=operandOveride;
    envSave[ 8]=addressOveride;
    envSave[ 9]=vCodeOffset;
    envSave[10]=vCodeSize;
    envSave[11]=dmc;
    envSave[12]=delta;
    envSave[13]=(int)cur_position;
    envSave[14]=needJump;
    envSave[15]=needCall;
    envSave[16]=GotEof;
    envSave[17]=(int)yyfp;
    envSave[18]=(int)yypmax;
    envSave[19]=nextMode;
    envSave[20]=printMode;
    envSave[21]=zeroCheckMode;
    envSave[22]=needJumpNext;
}

void popEnvironment()
{
    yyfirsttime             = envSave[ 0];
    a_loc                   = envSave[ 1];
    a_loc_save              = envSave[ 2];
    i_col                   = envSave[ 3];
    i_col_save              = envSave[ 4];
    i_psp                   = envSave[ 5];
    NumberOfBytesProcessed  = envSave[ 6];
    operandOveride          = envSave[ 7];
    addressOveride          = envSave[ 8];
    vCodeOffset             = envSave[ 9];
    vCodeSize               = envSave[10];
    dmc                     = envSave[11];
    delta                   = envSave[12];
    cur_position     = (DWORD)envSave[13];
    needJump                = envSave[14];
    needCall                = envSave[15];
    GotEof                  = envSave[16];
    yyfp             = (PBYTE)envSave[17];
    yypmax           = (PBYTE)envSave[18];
    nextMode                = envSave[19];
    printMode               = envSave[20];
    zeroCheckMode           = envSave[21];
    needJumpNext            = envSave[22];
}

void showDots()
{
static int n=0;

    n++;
    if (n%20==0)
	{
	    fprintf(stderr,".");
		showDotsNum++; if (showDotsNum%COLSIZE==0) fprintf(stderr,"\n");
    }
}


//
// the engine of this program
//
void Disassembler()
{
//static BYTE   bb=0x00;
int       tok;
BYTE      c;
int       choice;
//int       i;

    showDots();

    while (!GotEof)
    {
            /*-----------*/pushTrace(1100);
            addressfix();
            /*-----------*/popTrace();

            c = getMap(cur_position);

            if (nextMode)
            {
                     if (c==0x0E)       {fatalError=256;break;}
                else if ((c&0x08)==0x08){needJump=1;    break;}
                else if ((c&0x05)==0x05){needJump=1;    break;}
                choice=0;
            }
            else
            {
                      if ((c&0x0F)==0x0E)  choice=1;   // address
                 else if ((c&0x0F)==0x0D)  choice=6;   // ward
                 else if ((c&0x0F)==0x0F)  choice=2;   // byte data
                 else if ((c&0x0F)==0x0C)  choice=3;   // CC block
                 else if ((c&0x0F)==0x0B)  choice=4;   // Pascal String
                 else if ((c&0x0F)==0x09)  choice=5;   // NULL   String
                 else               choice=0;
            }
            /*------------*/pushTrace(1110);
            addressprint1(choice);
            /*------------*/popTrace();
            /*------------*/pushTrace(1120);
            tok = instruction(choice);
            /*------------*/popTrace();
            if (tok==0) {fatalError=-1; break;}
            /*------------*/pushTrace(1130);
            bodyprint(choice);
            /*------------*/popTrace();
            lineno++;
            /*------------*/pushTrace(1140);
            markCodes();
            /*------------*/popTrace();
            if (nextMode&&needJump)break;
            //if (nextMode&&needCall)break;
            /*------------*/pushTrace(1150);
            if (zeroCheckMode)
            {checkZeros(); checkCrossing();}
            /*------------*/popTrace();
            if (fatalError) break;
   }

    /* go round the loop */

}

void Disassembler1()
{
//static int bb=0;
int       tok;
BYTE      c;
int       i, limit;

    if (nextMode) limit=CodeSize; else limit=48;
    for(i=0;i<limit;i++)
    {
            /*-----------*/pushTrace(1200);
            addressfix();
            /*-----------*/popTrace();
            c = getMap(cur_position);

                 if ((c&0x08)==0x08) return;
            else if ((c&0x05)==0x05) return;
            /*-----------*/pushTrace(1210);
            addressprint1(0);
            /*-----------*/popTrace();
            /*-----------*/pushTrace(1220);
            tok = instruction(0);
            /*-----------*/popTrace();
            if (tok==0) {fatalError=-11; break;}
            /*-----------*/pushTrace(1230);
            bodyprint(0);
            /*-----------*/popTrace();

            lineno++;
            /*-----------*/pushTrace(1240);
            markCodes();
            /*-----------*/popTrace();
            /*-----------*/pushTrace(1250);
            if (zeroCheckMode)
            {
                checkZeros1();
                checkCrossing();
            }
            /*-----------*/popTrace();
            if (fatalError) break;
            if (needJump) break;
            //if (needCall||needJump) break;
    }
    /* go round the loop */
}

// **************************************************
// disassembler monitoring or surporting functions
// **************************************************

/* ---------------------------------------------------------------------
 * the possible error cases:
 *    -1, -11, 100~399, 900, 990 = unrecovable cur_position must be erased.
 *    992 = Address blocks has been decoded as instruction stream
 *          so referenced position must be erased. - emergency case.
 *    -2 = cur instruction passes over the next instruction
 *         3 possible cases: (1) me-OK,you-NOT (2) me-NOT,you-OK (3) me-NOT,you-NOT
 *    -3,-4,-5,-6,-7 = zero check error
 *         2 possible cases: (1) good code - data, (2) bad code
 *    994 = reference of cur instruction touches data
 *        = reference of cur instruction touches body of some other instruction
 *         3 possible cases: (1) me-OK,you-NOT (2) me-NOT,you-OK (3) me-NOT,you-NOT
 *    999 = some other instruction touches my body
 *         3 possible cases: (1) me-OK,you-NOT (2) me-NOT,you-OK (3) me-NOT,you-NOT
 * ----------------------------------------------------------------------
 */

void markCodes()
{
int       i;
DWORD     r;

    r=cur_position;
    if (nextMode)
    {
        if (i_opcode==0xCC && getByteFile(r-1)==0xCC && getByteFile(r+1)==0xCC)
        {
            /*------------*/pushTrace(1300);
            setMap(r,0x0C);
            /*------------*/popTrace();
        }
        else
        {
            if (nextMode==1)
            {
                /*-----------*/pushTrace(1310);
                orMap(r, 0x05);
                /*-----------*/popTrace();
                for(i=1;i<i_col_save;i++)
                if(getMap(r+(DWORD)i)&0x40)
                {
                    fatalError=900;
                    break;
                }
                else
                {
                    /*--------*/pushTrace(1320);
                    orMap(r+(DWORD)i,0x04);
                    /*--------*/popTrace();
                }
            }
            else
            {
                /*------------*/pushTrace(1330);
                orMap(r, 0x07);
                /*------------*/popTrace();
                for(i=1;i<i_col_save;i++)
                if(getMap(r+(DWORD)i)&0x40)
                {
                    fatalError=900;
                    break;
                }
                else
                {
                    /*--------*/pushTrace(1340);
                    orMap(r+(DWORD)i,0x06);
                    /*--------*/popTrace();
                }
            }
            if(fatalError==0)
            for(i=1;i<i_col_save;i++)
                if (getMap(r+(DWORD)i)&0x20)
                {
                   dmLabels[dmc++]=r+(DWORD)i;
                   fatalError=999;
                   /*---------*/pushTrace(1350);
                   exMap(r+(DWORD)i,0x20);
                   /*---------*/popTrace();
                }
        }
    }
}

int ErrorRecoverNum=0;
history my_h;
void ErrorRecover()
{
//int     i;

    //printf("\nError Recover %08X::code=%5d  ", cur_position, fatalError);
    my_h.m=nextMode;
    my_h.f=fatalError;
    my_h.r=lastReset;
    my_h.c=cur_position;

         if (fatalError==256)
    {
        /*------------*/pushTrace(1400);
        trySomeAddress(cur_position);
        /*------------*/popTrace();
    }
    else if (fatalError==999)
    {
         //fprintf(stdout,"\n:%08X ",cur_position);
         //for(i=cur_position-2;i<cur_position+i_col_save+3;i++)
         //fprintf(stdout," %02X",getMap(i));
         //fprintf(stdout,"\n:%08X ",cur_position);
         //for(i=cur_position-2;i<cur_position+i_col_save+3;i++)
         //fprintf(stdout," %02X",getByteFile(i));

        /*------------*/pushTrace(1410);
         if (dmc>0) clearSomeBadGuy(&my_h);
        /*------------*/popTrace();
    }
    else if (fatalError!=0)
    {
        //for(i=cur_position-2;i<cur_position+3;i++)
        //fprintf(stdout," %02X",getMap(i));
        /*------------*/pushTrace(1420);
        eraseUncertain(cur_position, &my_h);
        /*------------*/popTrace();
        //fprintf(stderr,"=%d",fatalError);
    }
    //getch();
    /*------------*/pushTrace(1415);
    if (dmc>0) clearSomeBadGuy(&my_h);
    /*------------*/popTrace();
    ErrorRecoverNum++;
    dmc=0;
    fatalError=0;
}


void clearSomeBadGuy(PHISTORY ph)
{
int   i;
    //fprintf(stderr,"\n Clear Some Bad Guy ");
    for (i=0;i<dmc;i++)
    {
        /*-----------*/pushTrace(1450);
        eraseCarefully(dmLabels[i], ph);
        /*-----------*/popTrace();
    }

    dmc=0;
    //for (i=0;i<dmc;i++)
    //   fprintf(stderr,"\ndmLabels==%08X",dmLabels[i]);//,getch();
    if(nextMode==3)
    {
        //fprintf(stderr,"**************** LOOK HERE ********************");
        //getch();
    }
}

//
// minimum filter to check if this is code or not.
//
void checkZeros()
{
static int  colsave=-1;

    if (i_opcode==0x90 && opsave==0 && modsave==0) fatalError=-4;
    if (i_opcode==0 && i_mod==0 && opsave==0x90) fatalError=-5;
    if (i_opcode==0 && i_mod==0 && opsave==0xC3) fatalError=-6;
    if (i_opcode==opsave && i_opcode <0x0A
     && i_col_save == colsave && i_mod<0x0A && i_mod == modsave)
    {
       fatalError=-7;
       //fprintf(stderr,"\nWWW %08X -7::",cur_position);
    }
    if (i_opcode==0 && i_mod==0 && opsave==0 && modsave==0) fatalError=-3;
    opclassSave=opclass; opsave=i_opcode; modsave=i_mod; colsave=i_col_save;
}

void checkZeros1()
{
static int opsave1=-1, modsave1=-1, colsave1=-1;

    if (i_opcode==0x90 && opsave1==0 && modsave1==0) fatalError=-4;
    if (i_opcode==0 && i_mod==0 && opsave1==0x90) fatalError=-5;
    if (i_opcode==0 && i_mod==0 && opsave1==0xC3) fatalError=-6;
    if (i_opcode==opsave1 && i_opcode <0x1F
     && i_col_save == colsave1 && i_mod<0x1F && i_mod == modsave1) fatalError=-7;
    if (i_opcode==0 && i_mod==0 && opsave1==0 && modsave1==0) fatalError=-3;
    //if (i_opcode==opsave1 && i_col_save == colsave1) fatalError=-1;
    opsave1=i_opcode; modsave1=i_mod; colsave1=i_col_save;
}

//extern FILE *d_fp;

void checkCrossing()
{
DWORD      i;
DWORD      r=0;

    for(i=cur_position+1;i<cur_position+i_col_save;i++) if (getMap(i)&0x49) break;
    if (i==cur_position+i_col_save)  return;
    if (getByteFile(cur_position)==0x00)
    {
        /*-------------*/pushTrace(1460);
        setMap(cur_position,0x0F);
        /*-------------*/popTrace();
        return;
    }

    //fprintf(d_fp,"\n.cc. %08X: nM=%d :",cur_position,nextMode);
    //for(i=cur_position;i<cur_position+i_col_save;i++)
    //    fprintf(d_fp,"%02X ",getByteFile(i));
    //fprintf(d_fp,"\n.cc. %08X:      :",cur_position);
    //for(i=cur_position;i<cur_position+i_col_save;i++)
    //    fprintf(d_fp,"%02X ",getMap(i));

    //if ((getMap(i)&0xF0)==0xF0) r=tryToSaveIt(cur_position+i_col_save);
    if (r==0) fatalError=-8;
    else
    {
        //fprintf(stderr," GOTIT %08X-%08X ", cur_position,r);
        /*--------------*/pushTrace(1470);
        for(i=cur_position;i<r;i++) setMap(i,0x00);
        /*--------------*/popTrace();
        /*--------------*/pushTrace(1480);
        saveIt(cur_position);
        /*--------------*/popTrace();
        //getch();
    }
}

// *****************************************

DWORD GetNextOne()
{
DWORD    r, rr;
BYTE   b;

    if (needJump==1)
    {
        /*--------------*/pushTrace(1490);
        rr=isItStartAnyWay(needJumpNext);
        if (rr) addLabels(needJumpNext, 2);
        /*--------------*/popTrace();
        needJump=0;    needJumpNext=0;
    }
    while(1)
    {
        r=getLabels();
        r=AddressCheck(r);
        if (r==0) break;
        b=getMap(r);
        if((b&0x0F)==0x00) break;
    }
    return r;
}

int isThisGoodRef(DWORD ref, DWORD s, DWORD e)
{
DWORD    r;
_key_  k;
PKEY   pk;

    k.c_ref=ref; k.c_pos=-1; k.class=0;
    pk = searchBtree3(&k);
    if (pk==NULL) return 0;
    r=pk->c_pos;
    if (isGoodAddress(r)&&(r<s||e<r)) return 1;
    return 0;
}

int tryToSaveIt(DWORD ref)
{
//int      i, j, n, r, s, pos;
//BYTE     b, d;

    if (!isGoodAddress(ref)) return 0;

    //if((getMap(ref)&0x05)==0x05)return 1;
    pushEnvironment();
    nextMode=0;
    zeroCheckMode=0;
    //printMode=0;

    resetDisassembler(ref);

    /*-----------*/pushTrace(1500);
    Disassembler1();
    /*-----------*/popTrace();

    if (fatalError==0)
    {
        popEnvironment();
        fprintf(stderr,".");
		showDotsNum++; if (showDotsNum%COLSIZE==0) fprintf(stderr,"\n");
        return 1;
    }
    popEnvironment();
    return 0;
}

void saveIt(DWORD ref)
{
//int      i, j, n, r, s, pos;
//BYTE     b, d;
DWORD      r;

    if (!isGoodAddress(ref)) return;

    pushEnvironment();
    nextMode=1;
    zeroCheckMode=0;
    //printMode=0;

    resetDisassembler(ref);

    /*-----------*/pushTrace(1550);
    Disassembler1();
    /*-----------*/popTrace();

    if (fatalError==0)
    {
        r=cur_position;
        popEnvironment();
        return;
    }
    popEnvironment();
}

int isItStartAnyWay(DWORD ref)
{
static BYTE    CodeTab[100]={
       0x0F,0x2D,0x31,0x32,0x33,0x39,0x3A,0x3B,0x3D,0x46,0x47,
       0x50,0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5A,0x5B,0x5D,0x5E,0x5F,
       0x64,0x66,0x68,0x6A,0x7C,0x7D,0x80,0x81,0x83,0x84,0x85,0x88,0x89,0x8A,0x8B,0x8D,
       0xA1,0xA8,0xA9,0xAC,0xB0,0xB2,0xB3,0xB8,0xB9,0xBA,0xBB,0xBD,0xBE,0xBF,
       0xC1,0xC2,0xC3,0xC6,0xC7,0xC8,0xD9,0xDB,0xDD,0xDF,0xE8,0xE9,0xEB,0xF6,0xF7,0xFF,0x00,};
int    i, j, tok;
DWORD  r, t;
BYTE   b, c, d;

    //fprintf(stderr, "1");

    if (ref==0) return 0;
    if (nextMode>0 && ref==needJumpNext)
    {
        r=ref;
        while((b=getByteFile(r))==0x00 && getMap(r)==0x00) {setMap(r++,0x0F);}
        i = getIntFile(r);
        if (i==-1)
        {
            setMap(r,0x0F); setMap(r+1,0x0F); setMap(r+2,0x0F); setMap(r+3,0x0F);
        }
    }
    b = getByteFile(ref);
    if (b==0) return 0;
    //if (ref==debugAdd)fprintf(stderr,"\nisItstartAnyWay=%08X %02X",ref,getMap(ref)),getch();
    if (strchr(CodeTab,b)==NULL) return 0;
    if (getMap(ref)&0x0F) return 0;

    //if (ref==debugAdd){fprintf(stderr,"\nisItstartAnyWay=%08X 2",ref);getch();}
    pushEnvironment();
    nextMode=0;
    zeroCheckMode=1;
    //printMode=0;

    resetDisassembler(ref);

    /*-----------*/pushTrace(1600);
    for(i=0;i<48;i++)
    {
            addressfix();
            c = getMap(cur_position);
            b = getByteFile(cur_position);
            if (b==0x00)
            {
                for(r=ref;r<cur_position;r++) if((getMap1(r)&0x04)==0x00) break;
                if (r>=cur_position-1) {fatalError=-9; break;}
            }

                 if ((c&0x08)==0x08) break;
            else if ((c&0x05)==0x05) break;
            addressprint1(0);
            tok = instruction(0);
            if (tok==0) {fatalError=-11; break;}
            bodyprint(0);
            for(j=1;j<i_col_save;j++)
            {
                d=getMap(cur_position+j);
                if (d&0x49) { fatalError=-99; break; }
            }
            if (b==0xEB)
            {
                r=getByteFile(cur_position+1);
                if(r>127) r-=256;
                r+=cur_position+2;
                if ((getMap(r)&0x05)==0x05)
                {
                    for(t=r;t<r+256;t++)
                    {
                        if(getMap(t) & MAP_ANCHOR_SET || (getMap(t)&0x04)==0x00) break;
                    }
					if((getMap(t)&0x04)&&(t<r+256)) break;
                }
            }
            if (zeroCheckMode)
            {
                checkZeros1();
            }
            if (fatalError) break;
            if (needJump) break;
    }
    /*-----------*/popTrace();

    if (fatalError==0)
    {
        popEnvironment();
        //if (ref==debugAdd)
        //{fprintf(stderr,"\nisItstartAnyWay=%08X OK ",ref);getch();}
        return ref;
    }
    //if (ref==debugAdd)
    //{fprintf(stderr,"\nisItstartAnyWay=%08X NOTOK %d",ref,fatalError);
    // getch();}
    fatalError=0;
    popEnvironment();
    return 0;
}

void trySomeAddress(DWORD ref)
{
DWORD      i, r, rr, rmax;

     r=ref;
     rmax=imageBase+getRVA(CodeOffset+CodeSize-1)+1;

     while((getMap(r)&0x0E)==0x0E){r++;}

     fprintf(stderr,".");
	 showDotsNum++; if (showDotsNum%COLSIZE==0) fprintf(stderr,"\n");

     // I don't know why I am doing this way but somehow it makes sense.
     for (i=r;i<rmax;i+=4)
     {
         rr=getIntFile(i);
         if (AddressCheck(rr) > 0)
         {
             if ((getMap(i+0)==0x00)
               &&(getMap(i+1)==0x00)
               &&(getMap(i+2)==0x00)
               &&(getMap(i+3)==0x00))
             {
                 /*---------*/pushTrace(1700);
                 EnterLabel(166, rr,i);
                 /*---------*/popTrace();
             }
         }
         else break;
     }
}

void  tryAnyAddress()
{
//static int col=0;
DWORD    r, rmax;
DWORD    rmaxTab[32], rstartTab[32];
int      i, j, k, n, num, c;
DWORD    s, e, ss;
BYTE     b, d;

    fprintf(stderr,".");
	showDotsNum++; if (showDotsNum%COLSIZE==0) fprintf(stderr,"\n");

    num=nSections;
    if (num>32) {num=32; fprintf(stderr,"\n...please increase the size...");}
    j=0;
    for (i=0;i<num;i++)
    {
        c=(int)shdr[i].Characteristics;
        if ((c&0x60000020)==0x60000020 || c==0xC0000040)
        {
            rstartTab[j]     = imageBase+shdr[i].VirtualAddress;
            rmaxTab[j]       = imageBase+shdr[i].VirtualAddress+shdr[i].SizeOfRawData;
            j++;
        }
    }
    num=j;

    /*
    for (i=0;i<num;i++)
    {
        fprintf(stderr,"\nrstartTab[i]=%08X,rmaxTab[i]=%08X",rstartTab[i],rmaxTab[i]);
    }*/

    fprintf(stderr,".");
	showDotsNum++; if (showDotsNum%COLSIZE==0) fprintf(stderr,"\n");
    for(k=0;k<num;k++)
    {
        r=rstartTab[k]; rmax=rmaxTab[k];
        while(r<rmax)
        {
             if (AddressCheck(getIntFile(r)) > 0)
             {
                 if (AddressCheck(getIntFile(r+1)) > 0
                   ||AddressCheck(getIntFile(r+2)) > 0
                   ||AddressCheck(getIntFile(r+3)) > 0)
                 {
                     r++;
                 }
                 else
                 {
                     //fprintf(stderr,"\nsetAnyAddress=%08X %08X",r,getIntFile(r));
					 //getch();
					 setAnyAddress(r); r+=4;
                 }
             }
             else
             {
                 r++;
             }
        }
    }

    fprintf(stderr,".");
	showDotsNum++; if (showDotsNum%COLSIZE==0) fprintf(stderr,"\n");
    for(k=0;k<num;k++)
    {
        r=rstartTab[k]; rmax=rmaxTab[k];
        while(r<rmax)
        {
             b=getByteFile(r);d=getByteFile(r+4);
             if ((b==0xE8)&&(isGoodAddress(s=r+5+getIntFile(r+1))))
             {
                 /*--------------*/pushTrace(1710);
                 if (!isItAnyAddress(s) && isItFirstTime(s) && isItStartAnyWay(s))
                 {
                     addLabels(s, 64);
                     addRef(1710,s,r);
                     r+=5;
                 }
                 else r++;
                 /*--------------*/popTrace();
             }
             else r++;
        }

        r=rstartTab[k]; rmax=rmaxTab[k];
        while(r<rmax)
        {
             n=trySomeMoreAddress(r,rmax,&ss);
             if (n==0) r=rmax;
             else
             {
                 for(s=ss;s<ss+4*n;s+=4)
                 {
                     e=getIntFile(s);
                     /*--------------*/pushTrace(1720);
                     if (isGoodAddress(e)&&!isItAnyAddress(e)
                         &&isItFirstTime(e)&&isItStartAnyWay(e))
                     { addLabels(e, 16); addRef(1720,e,s);}
                     //if(e==0x0045605C)fprintf(stderr,"\nGOTaddLabels2 from%08X",s),getch();
                     /*--------------*/popTrace();
                 }
                 r=ss+4*n;
             }
        }
    }
}

int tryMoreAddress(DWORD s, DWORD e, PDWORD start)
{
DWORD   i, r;

	//fprintf(stderr,"\ntryMoreAddress s=%08X e=%08X ", (int)s, (int)e);
    for (i=s;i<e;i++) if (isItAnyAddress(i)) break;
    if (i==e) {*start=0; return 0;}
    r=i;
    for (i=r+4;getOffset(i)<CodeOffset+CodeSize;i+=4) if (!isItAnyAddress(i)) break;
    *start=r;
    return (i-r)/4;
}

int trySomeMoreAddress(DWORD s, DWORD e, PDWORD start)
{
DWORD   i, r, rmax;

    r=s;
    rmax=e+CodeSize;
    while(1)
    {
        for (;r<e;r++) if (isItAnyAddress(r)) break;
        if (r==e) {*start=0; return 0;}
        for (i=r+4;i<rmax;i+=4) if (!isItAnyAddress(i)) break;
        *start=r;
        if (i-r >12) return (i-r)/4;
        r++;
    }
}

int looksLikeMenus(DWORD ref)
{
DWORD    i, n;

    for (i=ref;i<ref+12;i++) if (getIntFile(i)==-1) break;
    if (i==ref+12) return 0;
    i=ref; while(isprint(getByteFile(i))) i--; n=i;
    for (i=n;i>n-12;i--) if (getIntFile(i)==-1) break;
    if (i==n-12) return 0;
    return 1;
}

void showPascalString(DWORD ref)
{
DWORD     i;
int       n;
    n = getByteFile(ref);
    orMap1(ref,0x07);
    //fprintf(stderr,"\n:%08X..pascalString..",ref);
	print_ref(ref);
    printf("\n:%08X..pascalString..",(int)ref);
    //for (i=ref+1;i<ref+n+1;i++) fprintf(stderr,"%c",getByteFile(i));
    for (i=ref+1;i<ref+n+1;i++) {orMap1(i,0x06); printf("%c",getByteFile(i));}
}

void showNullString(DWORD ref)
{
DWORD     i;
int       n;
    //fprintf(stderr,"\n:%08X....NullString..",ref);
	print_ref(ref);
    printf("\n:%08X....NullString..",(int)ref);
    for (i=ref;i<ref+256;i++) if (!isprint(getByteFile(i))) break;
    n=i-ref;
    orMap1(ref,0x05);
    //fprintf(stderr,"%c",getByteFile(ref));
    //for (i=ref+1;i<ref+n;i++) fprintf(stderr, "%c",getByteFile(i));
    printf("%c",getByteFile(ref));
    for (i=ref+1;i<ref+n;i++) {orMap1(i,0x04); printf("%c",getByteFile(i));}
    if (getByteFile(i)==0x00) {orMap1(i,0x04);} else
    if (getByteFile(i)==0x0D && getByteFile(i+1)==0x0A)
    { orMap1(i,0x04);orMap1(i+1,0x04); printf(" <cr><lf>");} else
    if (getByteFile(i)==0x0A)
    {
        orMap1(i,0x04); printf(" <lf>");
        if (getByteFile(i+1)==0x0A) {orMap1(i+1,0x04); printf(" <lf>");} else
        if (getByteFile(i+1)==0x00) {orMap1(i+1,0x04);}
    } else
    if (getByteFile(i)==0x09)
    {
        orMap1(i,0x04); printf(" <t>");
        if (getByteFile(i+1)==0x09) {orMap1(i+1,0x04); printf(" <t>");} else
        if (getByteFile(i+1)==0x00) {orMap1(i+1,0x04);}
    }
    if (getByteFile(i)==0x00) {orMap1(i,0x04);}
}

void markStrings(DWORD s, DWORD e)
{
DWORD    i;
BYTE     b, d;

    /*-------------*/pushTrace(1800);
    i=s;
    while(i<e)
    {
        while(i<e)
        {b=getMap1(i); d=getMap(i); if((b&0x05)==0x05 && (d==0x00 || (d&0x08)))break; i++;}
        if ((b&0x07)==0x07)
        {
            setMap(i++,0x0B);
            while(i<e+256)
            {
                b=getMap1(i);
                if ((b&0x07)==0x06) setMap(i++,0x0A);
                else break;
            }
        }
        else if ((b&0x07)==0x05)
        {
            setMap(i++,0x09);
            while(i<e+256)
            {
                b=getMap1(i);
                if ((b&0x07)==0x04) setMap(i++,0x08);
                else break;
            }
        }
        else i++;
        if ((b&0x05)!=0x05) i++;
    }
    /*-------------*/popTrace();
}

int     maybePartof(DWORD r)
{
int   i, m, o;
    o=opcodeTable[getByteFile(r-1)];
    if (o==4||o==44) return 1;
    i=opcodeTable[getByteFile(r-2)];
    m=modTable[o];
    if (5<i&&i<12&&(m==3||m==6)) return 1;
    if (i==11 && (m==1||m==8)) return 1;
    if (i==13 && rmTable[o]==5 && (m==3||m==6)) return 1;
    return 0;
}

void markAddress(DWORD s, DWORD e)
{
DWORD    i;
int      n;
BYTE     b, d;

    /*-------------*/pushTrace(1850);
    i=s;
    while (i<e)
    {
        b=getMap1(i); d=getMap(i); n=getIntFile(i);
        if (d==0x00 && getMap(i+1)==0x00 && getMap(i+2)==0x00  && getMap(i+3)==0x00
            && (b&0x34)==0x30 && !maybePartof(i))
        {
            setMap(i,0x0E); setMap(i+1,0x0E); setMap(i+2,0x0E), setMap(i+3,0x0E);
            if (isGoodAddress(n) && (getMap(n)&0x25)==0x25 && referCount(n)==0)
                EnterLabel(167,n,i);
            i+=3;
        }
        else if (d==0x00 && n==-1)
        {setMap(i,0x0E); setMap(i+1,0x0E); setMap(i+2,0x0E), setMap(i+3,0x0E); i+=3;}
        i++;
    }
    /*-------------*/popTrace();
}

void markAddress1(DWORD s, DWORD e)
{
DWORD    i;
int      n;
BYTE     b, d;

    /*-------------*/pushTrace(1850);
    i=s;
    while (i<e)
    {
        b=getMap1(i); d=getMap(i); n=getIntFile(i);
        if ((b&0x3C)==0x30 &&
              d==0x0F && getMap(i+1)==0x0F && getMap(i+2)==0x0F  && getMap(i+3)==0x0F)
        {setMap(i,0x0E); setMap(i+1,0x0E); setMap(i+2,0x0E), setMap(i+3,0x0E); i+=3;}
        else if (d==0x0F && n==-1)
        {setMap(i,0x0E); setMap(i+1,0x0E); setMap(i+2,0x0E), setMap(i+3,0x0E); i+=3;}
        i++;
    }
    /*-------------*/popTrace();
}

void tryPascalStrings()
{
//static int col=0;
DWORD    r, rmax;
int      num;
DWORD    rmaxTab[32], rstartTab[32];
DWORD    i;
int      j, k, n, c, a, l;
BYTE     b, d;

    num=nSections;
    if (num>32) {num=32; fprintf(stderr,"\n...please increase the size...");}
    j=0;
    for (i=0;i<num;i++)
    {
        c=(int)shdr[i].Characteristics;
        if ((c&0x60000020)==0x60000020)
        {
            rstartTab[j]     = imageBase+shdr[i].VirtualAddress;
            rmaxTab[j]       = rstartTab[j]+shdr[i].SizeOfRawData;
            j++;
        }
    }
    num=j;

    fprintf(stderr,".");
	showDotsNum++; if (showDotsNum%COLSIZE==0) fprintf(stderr,"\n");
    printf("\n\n+++++++++++++++++++ Possible Strings Inside Code Block +++++++++++++++++++ \n");
    for(k=0;k<num;k++)
    {
        r=rstartTab[k]; rmax=rmaxTab[k];
        l=0;
        while(r<rmax)
        {

             while(!isprint(b=getByteFile(r))) r++;
             if (getMap1(r-1)) n=0;
             else n=getByteFile(r-1);
             i=r;      a=0;     c=0;
             while(isprint(b=getByteFile(i)))
             {if(isalnum(b)||b==0x20||b=='\\')a++;c++;i++;}
             if ((n>4 || (n>2 && r<l+8)) && n<31 && n<=c && ((n<=a) || (n>8)))
             {showPascalString(r-1); r=r+n; l=r;}
             else if (c>4
                      && (   b==0x00
                         || (b==0x0A && ((d=getByteFile(i+1))==0x0A || isprint(d) || d==0x00))
                         || (b==0x0D && ((d=getByteFile(i+1))==0x0A))
                         || (b==0x09 && ((d=getByteFile(i+1))==0x09 || d==0x00))
                         )
                     )
             {
                 if(c>5||!touchAnyAddress(i-1)||looksLikeMenus(i-1))
                 showNullString(r);
                 while (getMap1(i)==0x04) i++;
                 if(getByteFile(i)==0x00) i++; r=i; l=r;
             }
             else r++;
        }
    }
}

void checkOneInstructionFiller(DWORD r)
{
    /*--------------*/pushTrace(1900);
    if (getMap(r)==0 && getMap(r+1)==0 && getMap(r+2)!=0 &&
        getByteFile(r)==0x8B && getByteFile(r+1)==0xC0)
    {setMap(r,0x05); setMap(r+1,0x04);}
    /*--------------*/popTrace();
    return;
}

void changeToAddress(DWORD s, DWORD e)
{
}

void changeToBytes(DWORD s, DWORD e)
{
}

void changeToCode(DWORD s, DWORD e)
{
DWORD   i;
BYTE    b;

    //fprintf(stderr,"\nGEE YOU GOT ME s=%08X e=%08X",s,e);getch();
    for (i=s;i<e;i++) {b=getMap(i);exMap(i,(b&0x0F));}
    nextMode=3;
    zeroCheckMode=1;
    //printMode=0;

    resetDisassembler(s);
    Disassembler1();
}

void changeToDword(DWORD s, DWORD e)
{
}

void changeToFloat(DWORD s, DWORD e)
{
}

void changeToDouble(DWORD s, DWORD e)
{
}

void changeToQuad(DWORD s, DWORD e)
{
}

void changeTo80Real(DWORD s, DWORD e)
{
DWORD    i;

    //fprintf(stderr,"\nchangeTo80Real %08X %08X",s,e),getch();
    if (e==0)
    {
        if(getMap(s)&0x20); else setMap(s,0x1F);
        for(i=s+1;i<s+10;i++)setMap(i,0x0F);
    }
    else if(e>s && (e-s)%10==0)
    {
        for(i=s;i<e;i++)
        {
            orMap(i,0x0F);
            if((i-s)%10==0)
            {
                if(getMap(i)&0x20); else orMap(i,0x10);
            }
        }
    }
}

void changeToWord(DWORD s, DWORD e)
{
}

void changeToNullString(DWORD r)
{
}

void changeToPascalString(DWORD r)
{
}

void PostProcessing2(DWORD s, DWORD e)
{
DWORD    i, r;
int      n, nn, nz;
DWORD    rs, re, ri, rr, rt, rmax;
DWORD    ts, te;
int      cBox[256];
BYTE     b;

    fprintf(stderr,"*");
	showDotsNum++; if (showDotsNum%COLSIZE==0) fprintf(stderr,"\n");
    r        = s;
    rmax     = e;
    r=rmax-1;
    while(getByteFile(r)==0 && (getMap(r) & MAP_ANCHOR_SET )==0)r--;
    r++;
    while(r<rmax)
    {
        /*---------*/pushTrace(1910);
        setMap(r, 0x0F); r++;
        /*---------*/popTrace();
    }
    // I got something which is not processed yet.
    // I'll set everything to byte data whew...
    r=s;
    while(r<rmax)
    {
        if ((getMap(r)&0x0C)==0)
        {
            //checkOneInstructionFiller(r);
            /*---------*/pushTrace(1920);
            setMap(r, 0x0F);
            /*---------*/popTrace();
        }
        r++;
    }
    // now i am doing something should be done.
    // i am trying to find code blocks which lies between
    // some address blocks or byte blocks which is imcomplete
    // namely, which does not have return or jmp statement.
    // so it should looks like
    // {START|address|byte}code{address|byte|END}
    // if this code block ends with C3 or C2 something or
    // one of jmp statment it is OK
    // otherwise there is some problem.

    r=s;
    ri=r;
    fprintf(stderr,".");
	showDotsNum++; if (showDotsNum%COLSIZE==0) fprintf(stderr,"\n");
    //fprintf(stderr, " p1");
    while(r<rmax)
    {
        while((b=getMap(r))&0x08)
        {
            if (b==0x2F)
            {
                /*----------*/pushTrace(1930);
                setMap(r, 0x0F); rr=r;
                /*----------*/popTrace();
            }
            r++;
        }
        rs=r;n=0;rt=0;
        for(i=0;i<256;i++)cBox[i]=0;
        while((r<rmax)&&(((b=getMap(r))&0x08)==0x00))
        {
            if ((getMap(r)&0x05)==0x05)
            {
                cBox[getByteFile(r)]+=1;
                n++;ri=r;
                if (touchAnyAddress(ri))
                {
                    //if(rs<=debugAdd&&debugAdd<=rs+0x200)
                    //    fprintf(stderr,"\ntouchAnyAddress=%08X",ri);
                    rt++;
                }
                //{
                //
                //}
            }
            r++;
        }
        re=r;nn=0;nz=0;
        for(i=0x41;i<0x5B;i++)nn+=cBox[i];
        for(i=0x61;i<0x7B;i++)nn+=cBox[i];
        nn+=cBox[0x00]+cBox[0x90];
        nz+=cBox[0x00]+cBox[0x01]+cBox[0x02]+cBox[0x03];
        nz+=rt; // I don't know whether this is OK or Not

        /*
        if (rs<=debugAdd&&debugAdd<=re)
        {
            fprintf(stderr,"\n*********YO YO***********");
            fprintf(stderr,"\nn=%3d nn=%3d nz=%3d rs=%08X re=%08X rt=%3d getMap()=%02X",
                            n,nn,nz,rs,re,rt,getMap(debugAdd));
            getch();
        }*/

        if((nn*3>n*2)||(nz*2>n)||(n==1&&isNotGoodJump(rs))||
        (n<16
        &&(cBox[0xC2]+cBox[0xC3]==0)
        &&(getByteFile(ri)!=0xE9)
        &&(getByteFile(ri)!=0xE8)
        &&(getByteFile(ri)!=0xFF)))
        {
            // try to save partial results
            r=rs;
            while(r<re)
            {
                for(i=r;i<re;i++) if ((getMap(i) & MAP_ANCHOR_SET)== MAP_ANCHOR_SET) break;
                if(i<re)te=i+1;else te=i;
                for(i=r;i<te;i++) if ((getMap(i)&0x60)&&(isThisGoodRef(i,r,re))) break;
                ts=i;
                /*--------------*/pushTrace(1940);
                for(i=r;i<ts;i++) setMap(i,0x0F);
                /*--------------*/popTrace();
                if(r<te) r=te;
                else r++;
            }
        }
        r=re;
    }

    // now for some final touch,,
    // namely clear some garbage code which clings to byte data

    //fprintf(stderr, " p2");
    fprintf(stderr,".");
	showDotsNum++; if (showDotsNum%COLSIZE==0) fprintf(stderr,"\n");
    r=s;
    while(r<rmax)
    {
        //fprintf(stderr, " r==%08X",r);
        while((r<rmax)&&((getMap(r)&0x0F)==0x0F)){r++;}
        while((r<rmax)&&((getMap(r)&0x0F)!=0x0F)){r++;}
        if (getMap(r-1)==0x0C && getMap(r-2)==0x0F)
        {
            /*--------------*/pushTrace(1950);
            setMap(r-1,0x0F);
            /*--------------*/popTrace();
            continue;
        }
        if((getMap(r-1) & MAP_ANCHOR_SET)==0)
        {
            re=r;r--;
            while(r>s && ((b=getMap(r)) & MAP_ANCHOR_SET)==0x00 && !(b&0x40)){r--;}
            if(((b=getMap(r))&0x40)||(b&0x0C)==0x0C){r=re;continue;}
            r++;

            while(r<re)
            {
                if((getMap(r)&0x08)==0x08) { r=re; break; }      // 0x0C -> 0x08 .. check it..
                /*------------*/pushTrace(1960);
                setMap(r, 0x0F); r++;
                /*------------*/popTrace();
            }
        }
    }

    // now for some real final touch,,                 nov.10,1997 -sangcho-
    // namely clear some garbage code which clings hard to byte data

    //fprintf(stderr, " p3");
    fprintf(stderr,".");
	showDotsNum++; if (showDotsNum%COLSIZE==0) fprintf(stderr,"\n");
    r=s;
    while(r<rmax)
    {
        while((r<rmax)&&((getMap(r)&0x08)==0x08)){r++;}
        while((r<rmax)&&((getMap(r)&0x08)!=0x08)){r++;}

        //if((getMap(r-1) & MAP_ANCHOR_SET))
        {
            re=r;
            r--;
            //if((getMap(r-1)&0x88)==0)
            if((getMap(r)&0x88)==0)
            {
                r--;
                while(((b=getMap(r))&0x88)==0&&!(b&0x40)){r--;}
                if(getMap(r)&0x40){r=re;continue;}
                r++;
                rs=r;n=0;
                for(i=0;i<256;i++)cBox[i]=0;
                while((r<re)&&((getMap(r)&0x08)==0x00))
                {
                    if ((getMap(r)&0x05)==0x05){cBox[getByteFile(r)]+=1;n++;ri=r;}
                    r++;
                }
                nz=0;
                for(i=0;i<0x33;i++)nz+=cBox[i];
                nz-=cBox[0xC3]*n+cBox[0xE9]+cBox[0xFF];
                //nz=cBox[0x00]+cBox[0x01]+cBox[0x02]+cBox[0x03];
                if((nz*2>n)||(n==1&&isNotGoodJump(rs)))
                {
                    r=rs;
                    while(r<re)
                    {
                        if(getMap(r)&0x40){r=re;break;}
                        /*------------*/pushTrace(1970);
                        setMap(r, 0x0F); r++;
                        /*------------*/popTrace();
                    }
                }
            }
            r=re;
        }
    }

    // now for some real final touch,,                 nov.12,1997 -sangcho-
    // namely clear some garbage code which clings hard to byte data
    // this time we need to
    // find the code block which clings after byte data and which is dead.
    // so no outside reference is made, then you need to check out
    // carefully what is code and what is byte,
    // so this is what i do:
    // if each instruction is in ascii character range including
    // 00 and 20 and 2A you treat them as byte data.
    // but if you find 55 then you are almost done!
    // and check if next byte is something 8B or not.
    // if it is then you are really done.
    // and convert everything between start to just before 55 to
    // byte data!

    //fprintf(stderr, " p4");
    fprintf(stderr,".");
	showDotsNum++; if (showDotsNum%COLSIZE==0) fprintf(stderr,"\n");
    r=s;
    while(r<rmax)
    {
        while((r<rmax)&&((getMap(r)&0x08)!=0x08)){r++;}
        while((r<rmax)&&((getMap(r)&0x08)==0x08)){r++;}
        if(getMap(r)&0x40)   continue;
        if(!(getMap(r)&0x02))continue;
        rs=r;
        while((r<rmax)&&!((b=getMap(r))&0x02)&&!(b&MAP_ANCHOR_SET)){r++;}
        if(!(getMap(r)&0x02))continue;
        re=r;
        r=rs;
        while((r<rmax)&&(getByteFile(r)<0x80)){r++;}
        if((getByteFile(r)==0x8B)
         &&(getByteFile(r-1)==0x55)){rr=r-1;}
        else {r=re;continue;}
        r=rs;nn=0;
        while(r<rr)
        {
            if((getMap(r)&0x20)&&referCount(r)>0)nn++;
            r++;
        }
        if(nn){r=re;continue;}

        r=rs;
        /*--------------*/pushTrace(1980);
        while(r<rr){ setMap(r, 0x0F); r++; }
        /*--------------*/popTrace();
        r=re;
    }

    //fprintf(stderr,"1$");
}


int checkWellDone(DWORD s, DWORD e)
{
DWORD     i;
BYTE      b;

    //return PostProcessing2(s, e);
    for (i=s;i<e;i++)
    {
        if((getMap(i)&0x05)==0x05 && touchAnyAddress(i) && isAddressBlock(i)) break;
    }
    if(i<e)
    {
        //fprintf(stdout, "\n**!! fatalError = %3d getMap=%02X cur_position=%08X i=%08X",
        //        fatalError, getMap(cur_position), cur_position,i);

        my_h.m=nextMode;
        my_h.f=2000;
        my_h.r=lastReset;
        my_h.c=cur_position;
        /*-----------*/pushTrace(2000);
        eraseUncertain(i, &my_h);
        /*-----------*/popTrace();
        return 0;
    }
    if (((b=getMap(cur_position))&0x05)!=0x05&&!(b&0x08))
    {
        //fprintf(stderr, "\n!! fatalError = %3d getMap=%02X cur_position=%08X ",
        //        fatalError, getMap(cur_position), cur_position);
        //fprintf(stdout, "\n!! fatalError = %3d getMap=%02X cur_position=%08X ",
        //        fatalError, getMap(cur_position), cur_position);

        my_h.m=nextMode;
        my_h.f=2010;
        my_h.r=lastReset;
        my_h.c=cur_position;
        /*-----------*/pushTrace(2010);
        eraseUncertain(cur_position, &my_h);
        /*-----------*/popTrace();
    }
	return 1;
}


void PostProcessing1()
{
//static   BYTE bb=0xFF;
DWORD    r, s, e, rmax;
DWORD    rmaxTab[16], rstartTab[16];
DWORD    i, ss, pos;
int      k, n, num;
//BYTE     b, d;
_key_    y;

    //ReportMap();
    //printMode=1;
    num=getNumExeSec();
    if (num>16) {num=16; fprintf(stderr,"\n...please increase the size...");}
    for (i=0;i<num;i++)
    {
        rstartTab[i]     = imageBase+shdr[i].VirtualAddress;
        rmaxTab[i]       = rstartTab[i]+shdr[i].SizeOfRawData;
    }

	//fprintf(stderr,".1.");
    fprintf(stderr,".");
	showDotsNum++; if (showDotsNum%COLSIZE==0) fprintf(stderr,"\n");
    for(k=0;k<num;k++)
    {
        r=rstartTab[k]; rmax=rmaxTab[k];
		s=0; e=0;
		//{fprintf(stderr," continue1 ");}
        while(r<rmax)
        {
		    //{fprintf(stderr,"\n continue2 ");}
            if (s<r && r<e) s=r;
			else
			{
			    while(r<rmax)
			    {
			        if((getMap(r)&0x0F)==0x00) break;
				    r++;
			    }
				s=r;
			}
			if(s<e) e=e;
			else
			{
                while(r<rmax)
			    {
			        if(getMap(r)&0x0F) break;
				    r++;
			    }
                e=r;
			}

			//{fprintf(stderr,"\n 11 ");}

            /*------------*/pushTrace(2110);
            n=tryMoreAddress(s, e, &pos);
            /*------------*/popTrace();

			//{fprintf(stderr,"\n 12 ");}

            //
            // this is for some special considerations like instruction which ends
            // with address that follows address block case.
            //
            if (s==pos) ss=s; else ss=pos+4;

            if (n==0) {r=e; continue;}
            //
            // this case deals with CCCC"address" case
            //
            if (n==1)
            {
                i=pos;
                if ((e-s)<8
                 && getByteFile(s)==0xCC
                 && isGoodAddress(getIntFile(i))
                 && referCount(i)>0)
                {
                    /*-------------*/pushTrace(2120);
                    setMap(i  ,0x0E); setMap(i+1,0x0E);
                    setMap(i+2,0x0E); setMap(i+3,0x0E);
                    /*-------------*/popTrace();
                    /*-------------*/pushTrace(2130);
                    MyBtreeInsertDual(167, getIntFile(i), i);
                    /*-------------*/popTrace();
                    for (i=s;i<e;i++)
                        if (getByteFile(i)==0xCC && getMap(i)==0x00)
                        {
                            /*-------*/pushTrace(2140);
                            setMap(i,0x0C);
                            /*-------*/popTrace();
                        }
                        else break;
                }
            }
            //
            // not significant to set address blocks
            //
            if (n<=3)
            {
                // report some suspicious case here...
                r=pos+4*n;
				//fprintf(stderr,"\n%08X=%08X+4*%04X",(int)r,(int)pos,n);//getch();
				continue;
            }

            r=pos+4*n;

			//fprintf(stderr,"\n...%08X=%08X+4*%04X",(int)r,(int)pos,n);//getch();

            //
            // well ss is either pos or pos+4 depending on whether s==pos or not
            //
            for(i=ss;i<pos+n*4;i+=4)
            {
                if(isGoodAddress(getIntFile(i)))
                {
                    /*-----------*/pushTrace(2150);
                    setMap(i  ,0x0E); setMap(i+1,0x0E);
                    setMap(i+2,0x0E); setMap(i+3,0x0E);
                    /*-----------*/popTrace();
                    /*-----------*/pushTrace(2160);
                    MyBtreeInsertDual(167, getIntFile(i), i);
                    /*-----------*/popTrace();
                }
            }
        }
    }

	//fprintf(stderr,".2.");
    fprintf(stderr,".");
	showDotsNum++; if (showDotsNum%COLSIZE==0) fprintf(stderr,"\n");
    for(k=0;k<num;k++)
    {
        r=rstartTab[k]; rmax=rmaxTab[k];

        markStrings(r,rmax);

        while(r<rmax)
        {
            while(r<rmax)
            {
                if((getMap(r)&0x0F)==0x00) break; r++;
            }
            s=r;
            while(r<rmax)
            {
                if(getMap(r)&0x0F) break; r++;
            }
            e=r;
            for(i=s;i<e;i++)
            {
                // i don't want to revive nop 0x90
				showDots();
                while(i<e&&!isItStartAnyWay(i))i++;

                /*
                if(s<=debugAdd&&debugAdd<e)
                {
                fprintf(stderr,
                "\n...*** reset=%08X map=%02X %02X fatalError=%3d op=%02X m=%02X col=%d",
                                i,getMap(i),getMap(i+1),fatalError,i_opcode,i_mod,i_col_save);
                }*/
                if (fatalError==0) break;
            }
            if (i<e)
            {
                nextMode=3;
                resetDisassembler(i);
                /*-----------*/pushTrace(2210);
                Disassembler1();
                /*-----------*/popTrace();

                if (fatalError)
                {
                    //fprintf(stderr, "\n! fatalError = %3d getMap=%02X cur_position=%08X ",
                    //fatalError, getMap(cur_position), cur_position);
                    //fprintf(stdout, "\n! fatalError = %3d getMap=%02X cur_position=%08X ",
                    //fatalError, getMap(cur_position), cur_position);

                    my_h.m=nextMode;
                    my_h.f=2220;
                    my_h.r=lastReset;
                    my_h.c=cur_position;
                    /*----------*/pushTrace(2220);
                    eraseUncertain(cur_position, &my_h);
                    /*----------*/popTrace();
                }
                else
                {
                    /*----------*/pushTrace(2230);
                    checkWellDone(i, cur_position);
                    /*----------*/popTrace();
                }

                r=cur_position+1; // could be very dangerous ...
            }
        }
    }

    fprintf(stderr,".");
	showDotsNum++; if (showDotsNum%COLSIZE==0) fprintf(stderr,"\n");
    for(k=0;k<num;k++)
    {
        r=rstartTab[k]; rmax=rmaxTab[k];
        /*---------*/pushTrace(2240);
        PostProcessing2(r, rmax);
        /*---------*/popTrace();
        /*---------*/pushTrace(2250);
        markAddress1(r, rmax);
        /*---------*/popTrace();
    }

    fprintf(stderr,".");
	showDotsNum++; if (showDotsNum%COLSIZE==0) fprintf(stderr,"\n");
    for(k=0;k<HintCnt;k++)
    {
        y=Hints[k];
        i=y.class; r=y.c_pos; rmax=y.c_ref;
        switch(i)
        {
            case  1: changeToAddress(r,rmax); break;
            case  2: changeToBytes(r,rmax);   break;
            case  3: changeToCode(r, rmax);   break;
            case  4: changeToDword(r,rmax);   break;
            case  5: changeToFloat(r,rmax);   break;
            case  6: changeToDouble(r,rmax);  break;
            case  7: changeToQuad(r,rmax);    break;
            case  8: changeTo80Real(r,rmax);  break;
            case  9: changeToWord(r,rmax);    break;
            case 10: changeToNullString(r);   break;
            case 11: changeToPascalString(r); break;
            case 12:                          break;
            default: fprintf(stderr,"\nSOMETHING IS WRONG"); Myfinish();
        }
    }
}

// ***************************************
// some reporting functions
// ***************************************
void  printTrace()
{
int i;
    fprintf(stderr,"\n..Traces are...\n");
    for (i=0;i<debugx;i++) fprintf(stderr,"%3d:%4d, ",i,debugTab[i]);
    //getch();
    debugx=0;
}
void  peekTrace()
{
int i;
    fprintf(stderr,"\n..Traces are...\n");
    for (i=0;i<debugx;i++) fprintf(stderr,"%3d:%4d, ",i,debugTab[i]);
}

int totZero=0;
void  MapSummary()
{
DWORD    s, e, r, rmax;
int      n;

    r=imagebaseRVA;
    rmax=imageBase+getRVA(CodeOffset+CodeSize-1)+1;
    n=0;
    printf("\n+++++++++++++++++++ Somewhat Suspicious Blocks +++++++++++++++++++ \n");
    while(r<rmax)
    {
        while(r<rmax && getMap(r)>0) r++;
        s=r;
        while(r<rmax && getMap(r)==0) r++;
        e=r;
        printf("\nzero blocks::%08X-%08X", (int)s, (int)e);
        n+=e-s;
    }
    //printf("\nTotal zero blocks=%08X\n",n);
    //fprintf(stderr,"\nTotal zero blocks=%08X",n);
    totZero=n;
}

void  ReportMap()
{
DWORD    r, rmax;
int      n;

    r=imagebaseRVA;
    rmax=imageBase+getRVA(CodeOffset+CodeSize-1)+1;
    n=0;
    while(r<rmax)
    {
        if(n%24==0)printf("\n%08X:",(int)r);
        printf(" %02X",getMap(r));
         r++; n++;
    }
    printf("\n");
}

extern int addLabelsHistogram[];

void reportHistory()
{
history  h;
int      i;

    printf("\nListings of History");
    for (i=0;i<256;i++)
    {
        if (i%6==0) printf("\n");
        printf("%02X:%4d-%4d ",i,resetHistogram[i],addLabelsHistogram[i]);
    }
    printf("\nErrors occured..");
    for (i=0;i<hCnt;i++)
    {
        h=History[i];
        printf("\ni=%4d m=%3d f=%4d l=%3d r=%08X c=%08X :: s=%08X e=%08X",
               i+1, h.m, h.f, h.l, (int)(h.r), (int)(h.c), (int)(h.s), (int)(h.e));
    }
}

void readHint()
{
FILE           *fp;
char            line[80];
int             i;
int             a, b;
BYTE            c;
_key_           k;

    //fprintf(stderr,"\nreadHint()");
    fp=fopen(mname, "r");
    while(1)
    {
        for(i=0;i<80;i++)line[i]=0;
        fscanf(fp,"%s",line);
        c=line[0];
        if (c=='x') break;
        switch(c)
        {
            case 'a': k.class= 1; sscanf(line,"%*2c%08X", &a);
			          k.c_pos=a; k.c_ref=0;     break;
            case 'A': k.class= 1; sscanf(line,"%*2c%08X%*c%08X", &a, &b);
			          k.c_pos=a; k.c_ref=b;     break;
            case 'b': k.class= 2; sscanf(line,"%*2c%08X", &a);
			          k.c_pos=a; k.c_ref=0;     break;
            case 'B': k.class= 2; sscanf(line,"%*2c%08X%*c%08X", &a, &b);
			          k.c_pos=a; k.c_ref=b;     break;
            case 'c': k.class= 3; sscanf(line,"%*2c%08X", &a);
			          k.c_pos=a; k.c_ref=0;     break;
            case 'C': k.class= 3; sscanf(line,"%*2c%08X%*c%08X", &a, &b);
			          k.c_pos=a; k.c_ref=b;     break;
            case 'd': k.class= 4; sscanf(line,"%*2c%08X", &a);
			          k.c_pos=a; k.c_ref=0;     break;
            case 'D': k.class= 4; sscanf(line,"%*2c%08X%*c%08X", &a, &b);
			          k.c_pos=a; k.c_ref=b;     break;
            case 'f': k.class= 5; sscanf(line,"%*2c%08X", &a);
			          k.c_pos=a; k.c_ref=0;     break;
            case 'F': k.class= 5; sscanf(line,"%*2c%08X%*c%08X", &a, &b);
			          k.c_pos=a; k.c_ref=b;     break;
            case 'g': k.class= 6; sscanf(line,"%*2c%08X", &a);
			          k.c_pos=a; k.c_ref=0;     break;
            case 'G': k.class= 6; sscanf(line,"%*2c%08X%*c%08X", &a, &b);
			          k.c_pos=a; k.c_ref=b;     break;
            case 'q': k.class= 7; sscanf(line,"%*2c%08X", &a);
			          k.c_pos=a; k.c_ref=0;     break;
            case 'Q': k.class= 7; sscanf(line,"%*2c%08X%*c%08X", &a, &b);
			          k.c_pos=a; k.c_ref=b;     break;
			case 'r': case 'R':
			          moreprint=1;              break;
            case 't': k.class= 8; sscanf(line,"%*2c%08X", &a);
			          k.c_pos=a; k.c_ref=0;     break;
            case 'T': k.class= 8; sscanf(line,"%*2c%08X%*c%08X", &a, &b);
			          k.c_pos=a; k.c_ref=b;     break;
            case 'w': k.class= 9; sscanf(line,"%*2c%08X", &a);
			          k.c_pos=a; k.c_ref=0;     break;
            case 'W': k.class= 9; sscanf(line,"%*2c%08X%*c%08X", &a, &b);
			          k.c_pos=a; k.c_ref=b;     break;
            case 'n': k.class=10; sscanf(line,"%*2c%08X", &a);
			          k.c_pos=a; k.c_ref=0;     break;
            case 'N': k.class=10; sscanf(line,"%*2c%08X%*c%08X", &a, &b);
			          k.c_pos=a; k.c_ref=b;     break;
            case 'p': k.class=11; sscanf(line,"%*2c%08X", &a);
			          k.c_pos=a; k.c_ref=0;     break;
            case 'P': k.class=11; sscanf(line,"%*2c%08X%*c%08X", &a, &b);
			          k.c_pos=a; k.c_ref=b;     break;
            case 'u': k.class=12; sscanf(line,"%*2c%08X%*c%08X", &a, &b);
			          debugAdd=a; debugAdd1=b;     break;
            default:  k.class= 0;                  break;
        }
        if (k.class==0) break;
        Hints[HintCnt++]=k;
    }
    fclose(fp);
}


int stringCheck(int c, DWORD ref, DWORD pos)
{
int    n;
DWORD  rmax;
PBYTE  q, qq;

    rmax=imageBase+getRVA(CodeOffset+CodeSize-1)+1;
    if(pos<imagebaseRVA) return 1;
    if(pos>rmax) return 1;
    q=toFile(ref);
    switch(c)
    {
        case 512: case 513: case 520: case 1024:
            n=q?strlen(q):0;
            qq=q;
            if(n>0) while(qq<q+n&&isprint(*qq))qq++;
			if(n>0) while(qq<q+n&&isspace(*qq))qq++;
			if ((n>0&&qq==q+n)||(getMap1(ref)&0x05)==0x05)
            {
                if (getMap(pos)==0) break;
                /*----------*/pushTrace(2300);
                if (getMap(pos)&0x05) orMap(pos, 0x10);
                /*----------*/popTrace();
            }
        default: ; // assert(false);
    }
    return 1;
}


void labelBody1(int class, DWORD ref, DWORD pos)
{
int    c;
DWORD  r, rr;
BYTE   b, bb;

    c = class;
    r = ref;
    rr= pos;
    //if (r==0x0100139C) fprintf(stderr,"\nTADA...TADA...c=%3d rr=%08X mr=%02X mrr=%02X",
    //                                c,rr,getMap(r),getMap(rr));
    if (CodeOffset+CodeSize<=getOffset(r))
        {stringCheck(c, r, rr); return;}
    b=getMap(r);
    if (b==0)         return;
    if ((b&0x05)!=0x05 && (b&0x08)==0) return;
    bb=getMap(rr);
    if ((b==0x0F)&&(bb==0x0F)) return;

    switch(c)
    {
        case 1: case 2:
            if (bb==0)              break;
            if (b==0x0F)            break;
            if ((b&0x20)&&(bb&0x05)==0x05) break;
            /*-----------*/pushTrace(2310);
            if (bb&0x05) orMap(r, 0x20);
            /*-----------*/popTrace();
            break;
        case 3: case 4:
            if (bb==0)              break;
            if (b==0x0F)            break;
            if (b==0x0F)              break;
            if ((b&0x20)&&(bb&0x05)==0x05) break;
            /*-----------*/pushTrace(2320);
            if (bb&0x05) orMap(r, 0x20);
            /*-----------*/popTrace();
            break;
        case 5: case 7: case 9:
            if (bb==0)              break;
            if (b==0x0F)            break;
            if ((b&0x20)&&(bb&0x05)==0x05) break;
            /*-----------*/pushTrace(2330);
            if (bb&0x05) orMap(r, 0x20);
            /*-----------*/popTrace();
            break;
        case 11: case 13: case 15: case 17:
            if (bb==0)              break;
            if (b==0x0F)            break;
            if ((b&0x40)&&(bb&0x05)==0x05) break;
            /*-----------*/pushTrace(2340);
            if (bb&0x05) orMap(r, 0x60);
            /*-----------*/popTrace();
            break;
        case 133:
            break;
        case 165: case 166:    case 167:
            if (bb==0)                      break;
            if ((b&0x20)&&(bb&0x0E)==0x0E)   break;
            /*-----------*/pushTrace(2350);
            if ((bb&0x0E)==0x0E) orMap(r, 0x20);
            /*-----------*/popTrace();
            break;
        case 514:
            if (bb==0)      break;
            if (b!=0x0E)    break;
            /*-----------*/pushTrace(2360);
            orMap(r, 0x20);
            /*-----------*/popTrace();
            break;
        case 516:
            if (bb==0)      break;
            if (b!=0x0D)    break;
            /*-----------*/pushTrace(2370);
            orMap(r, 0x20);
            /*-----------*/popTrace();
            break;
        case 515: case 517: case 518: case 519: case 520: case 524: case 528:
            if (bb==0)      break;
            if (b!=0x0F)    break;
            /*-----------*/pushTrace(2372);
            orMap(r, 0x20);
            /*-----------*/popTrace();
            break;
        case 512: case 513: case 1024:
            if (bb==0)              break;
            if ((b&0x08)==0x08) {stringCheck(c, r, rr); break;}
            if ((b&0x05)==0x05) orMap(r,0x20);
            break;
        case 2048:
            /*-----------*/pushTrace(2380);
            orMap(r, 0xE0);
            /*-----------*/popTrace();
            break;
        default: ; // assert(false);
    }
}

void labelPP(PNODE1 pn, DWORD pos1)
{
    if (pn==NULL) return;
    labelPP(pn->left, pos1);
    labelBody1(pn->rclass, pos1, pn->pos2);
    labelPP(pn->right, pos1);
}

void labelBody(PNODE pn)
{
PNODE1    pc;

    if (pn->rcount>1)
    {
        pc=(PNODE1)(pn->pos2);
        labelPP(pc, pn->pos1);
    }
    else if (pn->rcount==1) labelBody1(pn->rclass, pn->pos1, pn->pos2);
}

void labelP(PNODE pn)
{
    if (pn==NULL) return;
    labelP(pn->left);
    labelBody(pn);
    labelP(pn->right);
}

void LabelProcess()
{
int      i, k;
DWORD    r, rmax;
BYTE     b;
PNODE    *ppn;
_key_    y;
    // I need to recycle one bit of Map,.... november 16,1997 -sangcho-

	r=imagebaseRVA;
    rmax=imageBase+getRVA(CodeOffset+CodeSize-1)+1;
    /*----------*/pushTrace(2400);
    while(r<rmax){b=getMap(r); exMap(r, b&0xF0);r++;}
    /*----------*/popTrace();

    for (i=0; i<hsize; i++)
    {
       // FIX ME !!!!!!!!!!!!!!!!! TAG
       ppn = headerD;
       ppn += i;
       if ((*ppn)!=NULL) labelP(*ppn);
    }

    for(k=0;k<HintCnt;k++)
    {
        y=Hints[k];
        i=y.class; r=y.c_pos; rmax=y.c_ref;
        switch(i)
        {
            case  8: changeTo80Real(r,rmax);  break;
            default: ; // assert(false);
        }
    }
}

void xrefBody1(int class, DWORD ref, DWORD pos)
{
static int   col=0;
static DWORD sr=0;
int      c;
DWORD    r, rr;
BYTE     b, d;

    c = class;
    r = ref;
    rr= pos;
    b=getMap(r);
    if (b==0)         return;
    if (b!=0x0F && b!=0x2E && (b&0x25)!=0x25) return;
    if (c==1||c==2)      return;
    d=getByteFile(r);

    if (sr!=r)
    {
        if ((b&0x80)&&(d!=0xC3))
        {
            printf("\n**%08X::",(int)r);printExportName1(r);
            if(rr>imagebaseRVA)
            {printf("\n            %08X,",(int)rr);col=1;}
            else col=7;
        }
        else if (b&0x40)
        {
            if (rr>0)printf("\n==%08X::%08X,",(int)r,(int)rr);
            else     printf("\n==%08X::",(int)r);  col=1;
        }
        else if (513<c && c<525)
        {
            if (rr>0)printf("\n##%08X::%08X,",(int)r,(int)rr);
            else     printf("\n##%08X::",(int)r); col=1;
        }
        else if (b&0x20)
        {
            if (rr>0)printf("\n--%08X::%08X,",(int)r,(int)rr);
            else     printf("\n--%08X::",(int)r); col=1;
        }
    }
    else
    {
        print_ref(rr);
		if (col%7==0) printf("\n            %08X,",(int)rr);
        else printf("%08X,",(int)rr);           col++;
    }
    sr=r;
}

void xrefPP(PNODE1 pn, DWORD pos1)
{
    if (pn==NULL) return;
    xrefPP(pn->left, pos1);
    xrefBody1(pn->rclass, pos1, pn->pos2);
    xrefPP(pn->right, pos1);
}

void xrefBody(PNODE pn)
{
PNODE1    pc;

    if (pn->rcount>1)
    {
        pc=(PNODE1)(pn->pos2);
        xrefPP(pc, pn->pos1);
    }
    else if (pn->rcount==1) xrefBody1(pn->rclass, pn->pos1, pn->pos2);
}

void xrefP(PNODE pn)
{
    if (pn==NULL) return;
    xrefP(pn->left);
    xrefBody(pn);
    xrefP(pn->right);
}

void Xreference()
{
int      i;
PNODE    *ppn;

    printf("\n\n*************** Cross Reference Listing ****************");
    for (i=0; i<hsize; i++)
    {
       // FIX ME !!!!!!!!!!! TAG
       ppn = headerD;
       ppn += i;
       if ((*ppn)!=NULL) xrefP(*ppn);
    }
}


// ************************************
// main cleaning agent
// ************************************

int eraseUncertainNum=0;

void eraseUncertain(DWORD ref, PHISTORY ph)
{
//static   BYTE bb=0xFF;
int      n;
DWORD    r, s, e, rmax;
BYTE     b;

    //ReportMap();

    //if (nextMode==1)
    //{
    //    fprintf(stderr,"\n>>> THIS SHOULD'NT HAPPEN <<< fatalError=%3d :%08X ",
    //    fatalError, cur_position);getch();
    //}

    r = 0;
    rmax=imageBase+getRVA(CodeOffset+CodeSize-1)+1;

    if (ref>imagebaseRVA)
    for (r=ref-1;r>imagebaseRVA;r--)
    {
        if (((b=getMap(r))==0x00)||(b&0x88)) break;
        //fprintf(stderr, "b=%02X ",b);
    }
    //fprintf(stderr, "b=%02X ",b);
    // start position to erase
    s = r+1;
    if ((b=getMap(r))==0 || (b&0x88))s=r+1; else s=r;
    //fprintf(stderr, "\ns==%08X ",s);
    r=ref;
    if (getMap(r)) { r++;}
    for (;r<rmax;r++)
    if (((b=getMap(r))==0x00)||(b&0x08)||(b&0x60))break;
    // end position to erase (before this point)
    e = r;
    //fprintf(stderr, "\ne==%08X ",e);
    // I need to do something here, delete labels generated at this point
    n = 0;

    for (r=s;r<e;r++)
    {
        if(getMap(r)&0x40){r=e;break;}
        if (getMap(r)&0x10)
        {
            //fprintf(stderr, " dl ");
            //fprintf(stdout, " dl ");
            n++;
            DeleteLabels(r);
            /*-------------*/pushTrace(2500);
            setMap(r, 0x00);
            /*-------------*/popTrace();
        }
        else
        {
            /*-------------*/pushTrace(2510);
            setMap(r, 0x00);
            /*-------------*/popTrace();
        }
        //ReportMap();
    }
    if (e>s)
    {
        //markStrings(s, e);
        //fprintf(stdout, "\n(%08X)eraseUncertain: %08X - %08X =%3d labels are deleted",
        //                ref, s, e,n);
    }
    ph->s=s; ph->e=e; ph->l=n;
    //if (e>s)
    //fprintf(stderr, "\n(%08X)eraseUncertain: %08X - %08X =%3d labels are deleted\n",
    //                ref, s, e, n);
    //ReportMap();
    //exit(0);
    eraseUncertainNum++;
    if (hCnt<hMax) History[hCnt++]=*ph; else {fprintf(stderr,"hCnt over");exit(0);}
}


void eraseUncertain1(DWORD ref, PHISTORY ph)
{
//static   BYTE  bb=0xFF;
int            cBox[256];
int            i, n, nn;
DWORD          r, s, e, rr, rmax;
BYTE           b;

    rmax=imageBase+getRVA(CodeOffset+CodeSize-1)+1;
    for (r=ref-1;r>imagebaseRVA;r--)
    if (((b=getMap(r))==0x00)||(b&0x88)) break;
    // start position to erase
    s = r+1;
    r=ref;
    if (getMap(r)) { r++;}
    for (;r<rmax;r++)
    if (((b=getMap(r))==0x00)||(b&0x08)||(b&0x40)||((b&0x22)==0x22))break;
    // end position to erase (before this point)
    e = r;
    // I need to do something here, delete labels generated at this point
    n = 0;  r=s; nn=0;
    for(i=0;i<256;i++)cBox[i]=0;
    while(r<e)
    {
        if(getByteFile(r)==0x55&&getByteFile(r+1)>0x80)break;
        cBox[getByteFile(r)]+=1;r++;nn++;
    }
    rr=r;
    if ((cBox[0xC2]+cBox[0xC3]==0) &&
       ((cBox[0x81]+cBox[0x83]+cBox[0x89]+cBox[0x8B])*100<nn))
    {
        r=s;
        while(r<rr)
        {
            /*----------*/pushTrace(2510);
            if (getMap(r)&0x10) {DeleteLabels(r); n++;}
            /*----------*/popTrace();
            /*----------*/pushTrace(2520);
            setMap(r, 0x00); r++;
            /*----------*/popTrace();
        }
        while(r<e)
        {
            /*----------*/pushTrace(2530);
            if (getMap(r)&0x10) {DeleteLabels(r); n++;}
            /*----------*/popTrace();
            /*----------*/pushTrace(2540);
            setMap(r, 0x00); r++;
            /*----------*/popTrace();
        }
    }
    else
    for (r=s;r<e;r++)
    {
        if(getMap(r)&0x40){r=e;break;}
        if (getMap(r)&0x10) { DeleteLabels(r); n++; }
        // i have to take care of very bad situation here.
        if (getMap(r)&0x20)
        {
            if (referCount(r)<3)
            {
                /*-------*/pushTrace(2550);
                setMap(r, 0x00);
                /*-------*/popTrace();
            }
            else
            {
                /*-------*/pushTrace(2560);
                setMap(r, 0x20);
                /*-------*/popTrace();
            }
        }
        else
        {
            /*-----------*/pushTrace(2570);
            setMap(r, 0x00);
            /*-----------*/popTrace();
        }
    }
    if (e>s)
    {
        //markStrings(s, e);

//fprintf(stderr, "\n@(%08X)eraseUncertain1: %08X - %08X ... %3d labels are deleted\n",ref,
//          s,e,n);
//fprintf(stdout, "\n@(%08X)eraseUncertain1: %08X - %08X ... %3d labels are deleted\n",ref,
//          s,e,n);
    }
    ph->s=s; ph->e=e; ph->l=n;
    //if(!isGoodAddress(s))
    //fprintf(stderr,"\nRRR..%08X s=%08X",ref,s),getch();
    if (hCnt<5012) History[hCnt++]=*ph; else {fprintf(stderr,"hCnt over");exit(0);}
}

void eraseCarefully(DWORD ref, PHISTORY ph)
{
//int      i, n;
_key_    k;
PKEY     pk;

    //fprintf(stdout,"\neraseCarefully::%08X=<=%08X",ref,cur_position);
    k.c_ref=ref; k.c_pos=-1; k.class=0;
    pk = searchBtree3(&k);
    if (pk==NULL) return;
    //{fprintf(stderr, " NOT FOUND ");fprintf(stdout, " NOT FOUND ");
    // return 1;}
    //fprintf(stdout," ::%08X",pk->c_pos);

    /*-----------*/pushTrace(2600);
    eraseUncertain1(pk->c_pos, ph);
    /*-----------*/popTrace();
}

// *******************************************
// label handling functions
// *******************************************

int isLabelCheckable(DWORD r)
{
   if (getMap(r  )>0) return 0;
   if (getMap(r+1)>0) return 0;
   if (getMap(r+2)>0) return 0;
   if (getMap(r+3)>0) return 0;
   return 1;
}

void setAddress(DWORD pos)
{
    /*-----------*/pushTrace(2650);
    if(isLabelCheckable(pos))
    {
        setMap(pos  , 0x0E);   setMap(pos+1, 0x0E);
        setMap(pos+2, 0x0E);   setMap(pos+3, 0x0E);
    }
    /*-----------*/popTrace();
}

void setAnyAddress(DWORD pos)
{
    /*-----------*/pushTrace(2660);
    orMap1(pos  ,0x30);
    orMap1(pos+1,0x20);
    orMap1(pos+2,0x20);
    orMap1(pos+3,0x20);
    /*-----------*/popTrace();
}

int isItAnyAddress(DWORD pos)
{
    if ((getMap1(pos  )&0x30)!=0x30) return 0;
    if ((getMap1(pos+1)&0x30)!=0x20) return 0;
    if ((getMap1(pos+2)&0x30)!=0x20) return 0;
    if ((getMap1(pos+3)&0x30)!=0x20) return 0;
    return 1;
}

int touchAnyAddress(DWORD pos)
{
    if ((getMap1(pos)&0x30)==0x20) return 1;
    return 0;
}

int isAddressBlock(DWORD pos)
{
DWORD   i, r, rmax;

    r=pos-3;
    rmax=pos+128;
    while(1)
    {
        for (;r<rmax;r++) if (isItAnyAddress(r)) break;
        for (i=r+4;i<rmax;i+=4) if (!isItAnyAddress(i)) break;
        if (i-r >12) return 1;
        return 0;
    }
}

void setFirstTime(DWORD pos)
{
    /*--------*/pushTrace(2670);
    if (nextMode==0) orMap1(pos,MAP_ANCHOR_SET); else orMap1(pos,MAP_ENTRY_SET);
    /*--------*/popTrace();
}

int isItFirstTime(DWORD pos)
{
BYTE    b;

    if (nextMode==0) b=MAP_ANCHOR_SET; else b=MAP_ENTRY_SET;
    if ((getMap1(pos)&b)==0x00) return 1;
    return 0;
}

void MyBtreeInsertDual(int class, DWORD ref, DWORD pos)
{
_key_    k;

	k.class = class;
    k.c_pos = pos;
    k.c_ref = ref;
    MyBtreeInsert(&k);
    k.class = -class;
    k.c_pos = ref;
    k.c_ref = pos;
    MyBtreeInsert(&k);  // we can use this .. for erase uncertain case.
}

void MyBtreeDeleteDual(int class, DWORD ref, DWORD pos)
{
_key_    k;

    k.class = class;
    k.c_pos = pos;
    k.c_ref = ref;
    MyBtreeDelete(&k);
    k.class = -class;
    k.c_pos = ref;
    k.c_ref = pos;
    MyBtreeDelete(&k);  // we can use this .. for erase uncertain case.
}

int BadEnter(DWORD ref, DWORD pos)
{
int    col;
BYTE   b;

    b=getMap(ref);
    if (i_col>0) col=i_col; else col=i_col_save;
    if (pos<=ref&&ref<pos+col)
    {fatalError=998;
    //if(nextMode)fprintf(stderr," 998 p=%08X r=%08X ics=%d ",pos,ref,i_col_save);
    return 1;}
    if ((b&0x0F)==0x00) return 0;
    if ((b&0x0F)==0x05) return 0;
    if ((b&0x0F)==0x07) return 0;

    //fprintf(stderr,"\n%02X ::pos=%08X:ref=%08X:",b,pos,ref);
    //fprintf(stdout,"%02X:pos=%08X:ref=%08X:",b,pos,ref);
    fatalPosition=pos;
    fatalReference=ref;

    //for(i=ref-2;i<ref+3;i++)
    //fprintf(stderr," %02X",getMap(i));
    fatalError=998;
    return 1;
}

//=======================================================================
// I need to describe the intended usage of _key_ and its fields.
// as you can see the _key_ structure consists of three fields
//  _key_ ::= class,  c_pos, c_ref
// class tells what kind of reference we are dealing with
// the table shows:
//-----------------------------------------------------------------------
//  class of reference  |unconditional(jump or call)|  conditional jump |
// ----------------------------------------------------------------------
// Jmp  Short Rel Disp  |                1          |            2      |
// Jmp  Near  Rel Disp  |                3          |            4      |
// Jmp  Near  Abs Indir |                5          |          ***      |
// Jmp  Far   Absolute  |                7          |          ***      |
// Jmp  Far   Abs Indir |                9          |          ***      |
// Call Near  Rel Disp  |               11          |          ***      |
// Call Near  Abs Indir |               13          |          ***      |
// Call Far   Absolute  |               15          |          ***      |
// Call Far   Abs Indir |               17          |          ***      |
//-----------------------------------------------------------------------
// Jmp indirect instruction                                    133      |
// Jmp indirect address holding place                          165      |
// the reference which is adjacent to above 165                166      |
// it looks like case 166                                      167      |
// the possible reference by   --  push dword                  512      |
// the possible reference by   --  push [reg or mem]           513      |
// the data reference     4 bytes                              514      |
// the data reference     4 bytes (32 real)                    524      |
// the data reference 14/24 bytes                              515      |
// the data reference     2 bytes                              516      |
// the data reference    10 bytes                              517      |
// the data reference     8 bytes                              518      |
// the data reference     8 bytes (64 real)                    528      |
// the data reference 94/108 bytes                             519      |
// the data reference     1 byte                               520      |
// the possible reference by   --  mov [reg or mem], dword    1024      |
// the definitive reference by export function block          2048      |
//-----------------------------------------------------------------------

//=======================================================================
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
// this one tell what is lpMap and its intended usage...               //
//---------------------------------------------------------------------//
// I can use lpMap (code check buffer?)                                //
//---------------------------------------------------------------------//
//       0x00: unprocessed                                             //
//       0x01: starting position of instruction  (masked)              //
//       0x02: gray mark(suspicious code)        (masked)              //
//       0x04: processed instructions            (masked)              //
//       0x08: data(address, byte, CC block)     (no masking)          //
//             0x09,0x08                         NULL string           //
//             0x0B,0x0A                         Pascal string         //
//             0x0C: cc block                      "                   //
//             0x0E: address                       "                   //
//             0x0F: byte                          "                   //
//       0x10: label generated here              (masked)              //
//       0x20: label or not                      (masked)              //
//       0x40: entry or not                      (masked)              //
//       0x80: anchor set                        (masked)              //
//---------------------------------------------------------------------//


// this function tries to record all the possible entries and labels
// and data references we can find and decipher.
void EnterLabel(int class, DWORD ref, DWORD pos)
{
DWORD          i, r, rr;
BYTE           b;

    //{fprintf(stderr,"EnterLabel::class=%5dX,ref=%08X\n",class,ref);getch();}

    i = 0;
    if (getOffset(ref)<CodeOffset) return;
    if (!AddressCheck(pos)) return;
    if (getOffset(ref)<CodeOffset+CodeSize)
    {
        switch(class)
        {
            case 1: case 2: case 3: case 4: case 7:
                 /*----------*/pushTrace(3000);
                 MyBtreeInsertDual(class, ref, pos);
                 /*----------*/popTrace();
                 if (BadEnter(ref,pos)) break; //need to store something here.
                 /*----------*/pushTrace(3010);
                 if (class>2 && isItStartAnyWay(ref)) addLabels(ref, 256);
                 /*----------*/popTrace();
                 /*----------*/pushTrace(3020);
                 orMap(ref, 0x20);
                 /*----------*/popTrace();
                 /*----------*/pushTrace(3030);
                 orMap(pos, 0x10);
                 /*----------*/popTrace();
                 break;
            case 11: case 15: case 2048:
                 /*----------*/pushTrace(3040);
                 MyBtreeInsertDual(class, ref, pos);
                 /*----------*/popTrace();
                 if (BadEnter(ref,pos)) break; //need to store something here.
                 /*----------*/pushTrace(3050);
                 if (isItStartAnyWay(ref)) addLabels(ref, 512);
                 /*----------*/popTrace();
                 /*----------*/pushTrace(3060);
                 orMap(ref, 0x40);
                 /*----------*/popTrace();
                 /*----------*/pushTrace(3070);
                 orMap(pos, 0x10);
                 /*----------*/popTrace();
                 break;
            case 166: case 167:
            // mark that address data
                 /*----------*/pushTrace(3080);
                 addLabels(ref,128);
                 /*----------*/popTrace();
                 /*----------*/pushTrace(3090);
                 setAddress(pos);
                 /*----------*/popTrace();
                 /*----------*/pushTrace(3100);
                 MyBtreeInsertDual(class, ref, pos);
                 /*----------*/popTrace();
                 if (BadEnter(ref,pos)) break;
                 /*----------*/pushTrace(3110);
                 orMap(ref, 0x20);
                 /*----------*/popTrace();
                 break;
            case 512: case 513: case 514: case 515: case 516: case 517:
            case 518: case 519: case 520: case 524: case 528: case 1024:
 				 /*----------*/pushTrace(3120);
                 MyBtreeInsertDual(class, ref, pos);
                 /*----------*/popTrace();
                 /*----------*/pushTrace(3130);
                 markData(class, ref, pos);
                 /*----------*/popTrace();
				 break;
//-------------------------------------------------------------------//
// now it is indirect address reference and we need to take some     //
// serious actions, namely if it is preventable than it is OK        //
// but if bad deed is already done we need to UNDO it.               //
// this requires couple of things.                                   //
// first we need to store indirect references in some convenient way //
// and every time we need to check whether we touch it or not.       //
// second we need to store all the anchors and start positions       //
// so we can easily determine how much we need to UNDO.              //
//                          october 24, 1997 late night-- sang cho   //
//-------------------------------------------------------------------//
            case 5: case 9: case 13: case 17: case 133:
            // mark that address data

                 //
                 // the following code is for some special interuptive case:::
                 // I need to check the validity of this part somehow...
                 //
                 if(getMap(ref)!=0x0E&&!isLabelCheckable(ref))
                 {
                     if(isGoodAddress(getIntFile(ref))
                     &&    isGoodAddress(getIntFile(ref+4))
                     && isGoodAddress(getIntFile(ref+8)))
                     for(i=ref;i<ref+CodeSize;i+=4)
                     {
                         if(getMap(i)==0x0E) break;
                         if(!isGoodAddress(getIntFile(i))) break;
                         /*
                         if(debugAdd-3<=i&&i<=debugAdd)
                         {
                             fprintf(stderr,"\nGOD SAVE US");
                             fprintf(stderr,"getMap(%08X)=%02X",ref,getMap(ref));
                         }*/
                         /*----------*/pushTrace(3150);
                         setMap(i,  0x00);setMap(i+1,0x00);
                         setMap(i+2,0x00);setMap(i+3,0x00);
                         /*----------*/popTrace();
                     }
                     if ((b=getMap(i))!=0x0E&&(b&0x05)!=0x05)
                     {
                     // emergency erase - I cannot wait until ErrorRecover,
                     // but is this OK or WHAT?
                         my_h.m=nextMode;
                         my_h.f=992;
                         my_h.r=lastReset;
                         my_h.c=cur_position;
                         /*----------*/pushTrace(3160);
                         eraseUncertain(i, &my_h);
                         /*----------*/popTrace();
                     }
                 }

                 /*---------*/pushTrace(3170);
                 setAddress(ref);
                 /*---------*/popTrace();
                 /*---------*/pushTrace(3180);
                 MyBtreeInsertDual(class, ref, pos);
                 /*---------*/popTrace();
                 /*---------*/pushTrace(3190);
                 orMap(pos, 0x10);
                 /*---------*/popTrace();
            // I am forming chain of label references.
            // also new class is defined here.
                 r = Get32Address(ref);
                 if (r>0)
                 {
                       if (AddressCheck(r))
                     {
                         if (BadEnter(r,ref)) break;
                         /*---------*/pushTrace(3200);
                         MyBtreeInsertDual(class+32, r, ref);
                         /*---------*/popTrace();

                         if (class<13||17<class)
                         {
                             if (!(getMap(r)&0x20))
                             {
                                 /*---------*/pushTrace(3210);
                                 if (isGoodAddress(r)) addLabels(r,64);
                                 orMap(r, 0x20);
                                 /*---------*/popTrace();
                             }
                         }
                         else
                         {
                             /*----------*/pushTrace(3220);
                             addLabels(r,128);
                             orMap(r, 0x40);
                             /*----------*/popTrace();
                         }
                     }
                 }
                    break;
            // I need to UNDO that bad deed, I once did.
            // but this one is in the middle of printing really something untouchable,
            // so what should I do, can I preempt it and proceed what I have to do?
            // well... if I am more careful I think I can do that.
            // OK this is fixed now, I can progress as I wished.   october 25, 1997
            // the following code is move to above position....^^^^^.....
            //if (ref<pos+4) { eraseUncertain(ref); break; }

            default: ; // assert(false);
        }
    }
 //
 // if reference is out of code range what can I do?
 // I have to think about it a while, meantime I'll just
 // do the thing I can do.
 //
    else
    {
        switch(class)
        {
            case 3: case 4:
                 fatalError=950;
                 break;
            case 7: case 11: case 15:
                 r = Get32Address(ref);
                 if (r>0)
                 {
                     if (class==7 )
                     {
                          /*----------*/pushTrace(3250);
                         if (isGoodAddress(r))
                         addLabels(r,32);
                         /*----------*/popTrace();
                     }
                     /*--------------*/pushTrace(3260);
                     MyBtreeInsertDual(class, r, pos);
                     /*--------------*/popTrace();
                 }
                 break;
            case 166: case 167:
            // mark that address data
                 /*-----------*/pushTrace(3270);
                 setAddress(pos);
                 /*-----------*/popTrace();
                 /*-----------*/pushTrace(3280);
                 MyBtreeInsertDual(class, ref, pos);
                 /*-----------*/popTrace();
                 break;
            case 512: case 513: case 514: case 515: case 516: case 517:
            case 518: case 519: case 520: case 524: case 528: case 1024:
                 /*-----------*/pushTrace(3290);
                 MyBtreeInsertDual(class, ref, pos);
                 /*-----------*/popTrace();
                 break;
            case 5: case 9: case 13: case 17: case 133:
            // mark that address data
                 r = Get32Address(ref);
                 if (r>0)
                 {
                     /*-----------*/pushTrace(3300);
                     MyBtreeInsertDual(class, r, pos);
                     /*-----------*/popTrace();

            // I am forming chain of label references.
            // also new class is defined here.
                 rr = Get32Address(r);
                     if (rr>0)
                     {
                         if (class<13||class>17)
                         {
                             /*------------*/pushTrace(3310);
                             if(isGoodAddress(rr))
                             addLabels(rr,16);
                             /*------------*/popTrace();
                         }
                         /*-----------*/pushTrace(3320);
                         MyBtreeInsertDual(class+32, rr, r);
                          /*-----------*/popTrace();
                     }
                 }
            default: ; // assert(false);
        }
    }
}

void markData(int class, DWORD ref, DWORD pos)
{
BYTE    a, b, c, d;
DWORD   i;

    /*-----------*/pushTrace(3400);
    switch(class)
    {
        case 512:
             a=getMap(ref); b=getMap(ref+1); c=getMap(ref+2); d=getMap(ref+3);
             if ((a==0||(a&0x08))&&(b==0||(b&0x08))
               &&(c==0||(c&0x08))&&(d==0||(d&0x08)))
             {
                 if (isItStartAnyWay(ref)) addLabels(ref, 1);
                 else if(isGoodAddress(getIntFile(ref)))
                 {
                     setMap(ref,0x0E);   setMap(ref+1,0x0E);
                     setMap(ref+2,0x0E); setMap(ref+3,0x0E);
                 }
             }

             break;
        case 513:
             a=getMap(ref); b=getMap(ref+1); c=getMap(ref+2); d=getMap(ref+3);
             if ((a==0||(a&0x08))&&(b==0||(b&0x08))
               &&(c==0||(c&0x08))&&(d==0||(d&0x08)))
             {
                 if(isGoodAddress(getIntFile(ref)))
                 {
                     setMap(ref,0x0E);   setMap(ref+1,0x0E);
                     setMap(ref+2,0x0E); setMap(ref+3,0x0E);
                 }
             }
             break;
        case 514:
             a=getMap(ref); b=getMap(ref+1); c=getMap(ref+2); d=getMap(ref+3);
             if ((a==0||(a&0x08))&&(b==0||(b&0x08))
               &&(c==0||(c&0x08))&&(d==0||(d&0x08)))
             {
                 setMap(ref,0x0E);   setMap(ref+1,0x0E);
                 setMap(ref+2,0x0E); setMap(ref+3,0x0E);
             }
             else if (a==0x0E && b==0x0E && c==0x0E && d==0x0E);
             else
             {
                 //fprintf(stderr, "\nmarkData error class=%3d ref=%08X pos=%08X ",
                 //        class, ref, pos);
                 //fprintf(stderr, "%02X %02X %02X %02X ", a,b,c,d);
                 fatalError=994;
                 //getch();
             }
             break;
        case 515:
             for (i=ref;i<ref+14;i++)
             {   a=getMap(i); if ((a!=0 && a!=0x0F)) break;   }
             if (i==ref+14)
                 for (i=ref;i<ref+14;i++) {setMap(i,0x0F); orMap1(i,0x08);}
             else
             {
                 //fprintf(stderr, "\nmarkData error class=%3d ref=%08X pos=%08X ",
                 //        class, ref, pos);
                 //fprintf(stderr, "%02X ", a);
                 fatalError=994;
                 //getch();
             }
             break;
        case 516:

             a=getMap(ref); b=getMap(ref+1);
             if ((a==0||a==0x0F)&&(b==0||b==0x0F))
             { setMap(ref,0x0D);   setMap(ref+1,0x0D);}
             else if(a==0x0D && b==0x0D);
             else
             {
                 //fprintf(stderr, "\nmarkData error class=%3d ref=%08X pos=%08X ",
                 //        class, ref, pos);
                 //fprintf(stderr, "%02X %02X ", a, b);
                 fatalError=994;
                 //getch();
             }
             break;
        case 517:
             for (i=ref;i<ref+10;i++)
             {   a=getMap(i); if ((a!=0x00 && a!=0x0F)) break;   }
             if (i==ref+10)
             {
                 for (i=ref;i<ref+10;i++) {setMap(i,0x0F); orMap1(i,0x08); }
             }
             else
             {
                 //fprintf(stderr, "\nmarkData error class=%3d ref=%08X pos=%08X i=%08X ",
                 //        class, ref, pos, i);
                 //fprintf(stderr, "%02X ", a);
                 fatalError=994;
                 //getch();
             }
             break;
        case 518: case 528:
             for (i=ref;i<ref+8;i++)
             {   a=getMap(i); if ((a!=0x00 && a!=0x0F)) break;   }
             if (i==ref+8)
                 for (i=ref;i<ref+8;i++) {setMap(i,0x0F); orMap1(i,0x08); }
             else
             {
                 //fprintf(stderr, "\nmarkData error class=%3d ref=%08X pos=%08X ",
                 //        class, ref, pos);
                 //fprintf(stderr, "%02X ", a);
                 fatalError=994;
                 //getch();
             }
             break;
        case 519:
             for (i=ref;i<ref+94;i++)
             {   a=getMap(i); if ((a!=0x00 && a!=0x0F)) break;   }
             if (i==ref+94)
                 for (i=ref;i<ref+94;i++) {setMap(i,0x0F); orMap1(i,0x08); }
             else
             {
                 //fprintf(stderr, "\nmarkData error class=%3d ref=%08X pos=%08X ",
                 //        class, ref, pos);
                 //fprintf(stderr, "%02X ", a);
                 fatalError=994;
                 //getch();
             }
             break;
        case 520:
             a=getMap(ref);
             if ((a==0||a==0x0F)) {setMap(ref,0x0F); orMap1(ref,0x08); }
             else
             {
                 fatalError=994;
                 //fprintf(stderr, "\nmarkData error class=%3d ref=%08X pos=%08X ",
                 //        class, ref, pos);
                 //fprintf(stderr, "%02X ", a);
                 fatalError=994;
                 //getch();
             }
             break;
        case 524:
             a=getMap(ref); b=getMap(ref+1); c=getMap(ref+2); d=getMap(ref+3);
             if ((a==0||(a&0x08))&&(b==0||(b&0x08))
               &&(c==0||(c&0x08))&&(d==0||(d&0x08)))
             {
                 setMap(ref,0x0F);   setMap(ref+1,0x0F);
                 setMap(ref+2,0x0F); setMap(ref+3,0x0F);
                 orMap1(ref,0x08);   orMap1(ref+1,0x08);
                 orMap1(ref+2,0x08); orMap1(ref+3,0x08);
             }
             else if (a==0x0F && b==0x0F && c==0x0F && d==0x0F);
             else
             {
                 //fprintf(stderr, "\nmarkData error class=%3d ref=%08X pos=%08X ",
                 //        class, ref, pos);
                 //fprintf(stderr, "%02X %02X %02X %02X ", a,b,c,d);
                 fatalError=994;
                 //getch();
             }
             break;
        case 1024:
             a=getMap(ref); b=getMap(ref+1); c=getMap(ref+2); d=getMap(ref+3);
             if ((a==0||(a&0x08))&&(b==0||(b&0x08))
               &&(c==0||(c&0x08))&&(d==0||(d&0x08)))
             {
                 if(isGoodAddress(getIntFile(ref)))
                 {
                     setMap(ref,0x0E);   setMap(ref+1,0x0E);
                     setMap(ref+2,0x0E); setMap(ref+3,0x0E);
                 }
             }
             break;
        default: ; // assert(false);
    }
    /*-----------*/popTrace();
}

// this is inverse of EnterLabel, but... who knows!
void DeleteLabels(DWORD pos)
{
//int            r;
BYTE           b;
_key_          k, k1, k2, k3;
PKEY           pk;

    k.c_ref=pos; k.c_pos=-1; k.class=0;
    pk = searchBtree1(&k);
    if(pk==NULL) return;
    k1=*pk;
    k.class=-k1.class; k.c_pos=k1.c_ref; k.c_ref=k1.c_pos;
    pk = searchBtree1(&k);
    if(pk==NULL) return;
    k2=*pk;
    if(k2.class==133 || k2.class==5 || k2.class==9)
    {
        k.c_ref=k2.c_ref;     k.c_pos=0; k.class=0;
        pk = searchBtree1(&k);
        if (pk)
        {
            k3=*pk;
            MyBtreeDeleteDual(-(k3.class), k3.c_pos, k3.c_ref);
            b=getMap(k3.c_pos);
            /*---------*/pushTrace(3500);
            if (b&0x20) exMap(k3.c_pos, 0x20);
            /*---------*/popTrace();
        }
    }

    // we have to delete k1 and k2
    MyBtreeDeleteDual(k2.class, k2.c_ref, k2.c_pos);
    b=getMap(k2.c_ref);
    /*---------*/pushTrace(3510);
    if (b&0x20) exMap(k2.c_ref, 0x20);
    /*---------*/popTrace();
    //fprintf(stdout,"deleted label==%5d::%08X<<%08X\n",k2.class,k2.c_ref,k2.c_pos);
}


// **********************************************
// address checking or getactual address. etc...
// **********************************************

int isGoodAddress(DWORD ref)
{
DWORD   r=getOffset(ref);
_key_  k;
PKEY   pk;

    if ((int)r < CodeOffset)
	{
	    k.c_ref=ref; k.c_pos=-1; k.class=0;
		pk=searchBtreeX(&k);
		if (pk==NULL) return 0;
		else return ref;
	}

    if ((int)r<CodeOffset+CodeSize) return 1;
    return 0;
}

DWORD AddressCheck(DWORD ref)
{
_key_  k;
PKEY   pk;

    if (ref < imagebaseRVA)
	{
	    k.c_ref=ref; k.c_pos=-1; k.class=0;
		pk=searchBtreeX(&k);
		if (pk==NULL) return 0;
		else return ref;
	}

    //if (ref<imagebaseRVA) return 0;
    if (ref<imageBase+maxRVA+maxRVAsize) return ref;
    return 0;
}


int getNumExeSec ()
{
int        i, c, n=0;

    /* locate section containing image directory */
    for(i=0;i<nSections;i++)
    {
        c = (int)shdr[i].Characteristics;
		if ((c&0x60000020)==0x60000020)n++;
    }

    return n;
}

DWORD getOffset (DWORD ref)
{
int        i;

    if (ref == 0) return 0;

    /* locate section containing image directory */
    for(i=0;i<nSections;i++)
    {
        if (shdr[i].VirtualAddress <= ref-imageBase &&
        ref-imageBase < shdr[i].VirtualAddress + shdr[i].SizeOfRawData)
        break;
    }

    if (i >= nSections)
    return 0;

    /* return image import directory offset */
    return ref - imageBase - (int)shdr[i].VirtualAddress + (int)shdr[i].PointerToRawData;
}

DWORD getRVA (DWORD off)
{
int        i;

    if (off == 0) return 0;

    /* locate section containing image directory */
    for(i=0;i<nSections;i++)
    {
        if ((int)shdr[i].PointerToRawData <= off &&
        off < (int)shdr[i].PointerToRawData + (int)shdr[i].SizeOfRawData)
        break;
    }

    if (i >= nSections)
    return 0;

    /* return image import directory offset */
    return off - (int)shdr[i].PointerToRawData + (int)shdr[i].VirtualAddress;
}

DWORD Get32Address(DWORD ref)
{
DWORD     r, off;
_key_  k;
PKEY   pk;

    off = getOffset(ref);
    if (off < CodeOffset)
	{
	    k.c_ref=ref; k.c_pos=-1; k.class=0;
		pk=searchBtreeX(&k);
		if (pk==NULL) return 0;
		else return ref;
	}

    if (off<CodeOffset+CodeSize)
        return AddressCheck(getIntFile(ref));
    r=(DWORD)GetActualAddress(lpFile, ref-imageBase);
    if (r) return (*(PDWORD)(r));
    return 0;
}

int isThisSecure(DWORD ref)
{
DWORD   r;

    if ((getMap(ref)&0x05)!=0x05) return 0;
    for (r=ref;r<ref+256;r++)
        if(getMap(r)&0x80) return 1;
    return 0;
}


int isNotGoodJump(DWORD ref)
{
BYTE    b;
DWORD   r;
_key_   k;
PKEY    pk;

    b=getByteFile(ref);
    if (b==0xC3) return 0;
    if (b==0xC2) return 0;
    if (b==0xE9||b==0xFF)
    {
        k.class=0;k.c_ref=ref;k.c_pos=0;
        pk=searchBtree1(&k);
        if(!pk)return 0;
        r=pk->c_pos;
        if(!AddressCheck(r))
        {
            k.c_ref=r;k.c_pos=0;k.class=0;
            pk=searchBtree1(&k);
            if(pk==NULL)return 1;
            else return 0;
        }
        if(getOffset(r)<CodeOffset+CodeSize&&(getMap(r)&0x20))return 0;
        if(getOffset(r)>CodeOffset+CodeSize&&referCount(r)>0)return 0;
    }
    return 1;
}

PBYTE toFile(DWORD ref)
{
DWORD   r=getOffset(ref);

    if(r<0) return 0;
    if(r>fsize) return 0;
    return (PBYTE)((int)r+(int)lpFile);
}

BYTE getByteFile(DWORD ref)
{
DWORD   r=getOffset(ref);

    if(r<0) return 0;
    if(r>fsize-4) return 0;
    return *(PBYTE)((int)r+(int)lpFile);
}

int  getIntFile(DWORD ref)
{
DWORD   r=getOffset(ref);

    if(r<0) return 0;
    if(r>=fsize) return 0;
    return *(int *)((int)r+(int)lpFile);
}

char* getSymbol(DWORD ref) {
	DWORD   r=getOffset(ref);

    if(r<0) return NULL;
    if(r>=CodeSize) return NULL;
	if(hasDebug && hasDebug[r]>0) return names+hasDebug[r];
		else return NULL;
}

BYTE getMap(DWORD ref)
{
DWORD   r=getOffset(ref);

    if(r<CodeOffset) return 0;
    if(r>=CodeOffset+CodeSize) return 0;
    return *(PBYTE)((int)r+(int)lpMap);
}

void setMap(DWORD ref, BYTE c)
{
DWORD   r=getOffset(ref);
//int   i;
/*
if(ref==debugAdd||ref==debugAdd1)
{
    fprintf(stderr,"\nsetMap(%08X) (%02X)to %02X from c_pos=%08X f=%d ",
                   ref, getMap(ref),c,cur_position,fatalError);
    for(i=0;i<debugx;i++)fprintf(stderr," dp=%4d",debugTab[i]);
    getch();
}*/
    if(r<CodeOffset) return;
    if(r>=CodeOffset+CodeSize) return;
    *(PBYTE)((int)r+(int)lpMap)=c;
}

void orMap(DWORD ref, BYTE c)
{
DWORD   r=getOffset(ref);
//int   i;
/*
if(ref==debugAdd||ref==debugAdd1)
{
    fprintf(stderr,"\norMap(%08X) to %02X from c_pos=%08X (%02X)",
                   ref,c,cur_position, getMap(ref));
    for(i=0;i<debugx;i++)fprintf(stderr," dp=%4d",debugTab[i]);
    getch();
}*/

    if(r<CodeOffset) return;
    if(r>=CodeOffset+CodeSize) return;
    *(PBYTE)((int)r+(int)lpMap)|=c;
}

void exMap(DWORD ref, BYTE c)
{
DWORD   r=getOffset(ref);

    if(r<CodeOffset) return;
    if(r>=CodeOffset+CodeSize) return;
    *(PBYTE)((int)r+(int)lpMap)^=c;
}

BYTE getMap1(DWORD ref)
{
DWORD   r=getOffset(ref);

    if(r<CodeOffset) return 0;
    if(r>=CodeOffset+CodeSize) return 0;
    return *(PBYTE)((int)r+(int)lpMap1);
}

void setMap1(DWORD ref, BYTE c)
{
DWORD   r=getOffset(ref);

    if(r<CodeOffset) return;
    if(r>=CodeOffset+CodeSize) return;
    *(PBYTE)((int)r+(int)lpMap1)=c;
}

void orMap1(DWORD ref, BYTE c)
{
DWORD   r=getOffset(ref);

    if(r<CodeOffset) return;
    if(r>=CodeOffset+CodeSize) return;
    *(PBYTE)((int)r+(int)lpMap1)|=c;
}

void exMap1(DWORD ref, BYTE c)
{
DWORD   r=getOffset(ref);
/*
if(ref==debugAdd||ref==debugAdd1)
{
    fprintf(stderr,"\nexMap1(%08X) to %02X from debugPoint=%3d c_pos=%08X",
                   ref,c,debugPoint,cur_position);
    getch();
}*/

    if(r<CodeOffset) return;
    if(r>=CodeOffset+CodeSize) return;
    *(PBYTE)((int)r+(int)lpMap1)^=c;
}


//
// I cannot actually compute m16:m32 far address value
// so I will only record m32 part of it, hope it actually works.
//
DWORD Get16_32Address(DWORD ref)
{
    return Get32Address(ref);
}

// *************************************
// miscellaneous functions
// *************************************

void Myfinish()
{
    free ((void *)piNameBuff);
    free ((void *)peNameBuff);
    free ((void *)lpFile);
    free ((void *)lpMap);
    free ((void *)lpMap1);
    deleteHeaders();
    //fclose(d_fp);
    exit(0);
}


/* =============================================================
I am using very strange looking data structure to store labels.
There are two parts of it.
   1. source part
   2. destination part

   we have node
   struct
   {
         DWORD  pos1
         DWORD  pos2   // i don't like to use union structure so i will just
         WORD   red;
         WORD   rclass // use type casting  (node *)pos2 ...
         WORD   rcount
         node*  left
         node * right
    }

    node1
    struct
    {
         DWORD  pos2
         short  rclass
         node1* left
         node1* right
    }


I. source part looks like this:
    there are fsize/256 + 1 many headers for labels.
    if the number of headers exceeds 64K then it is adjusted to 64K.
    each header is a pointer to a node and there are some nodes linked to this header.
    these nodes are only generated between 256 byte range of code.
    so the number of nodes cannot be too big.
    each nodes are linked in binary search tree as first integer as a key
    usually rcount == 1 and that is it, but
    if rcount > 1 then pos2 points to the second level of nodes
    that are linked as binary search tree fashion.
    when there are case jump block we can think all the addresses are
    used by this case jump instruction so there are many source side references.
    but this is not direct reference, anyway we need to store counter part of
    this information into destination side too.

II. destination part looks like this:
    there are fsize/256 + 1 many headers for labels.
    each header is a pinter to a node and there are some nodes linked to this header.
    these nodes are destinations between 256 byte range of code.
    each node may have children nodes which are linked through down pointer.( pos2)
    when rcount == 1 then there are no children.
    if   rcount >  1 then pos2 points to the second level of nodes (children nodes)

----------------------------------------------------------------------------
 */
int      asize;
int      hsize;
int      width;
LPVOID   headerS;
LPVOID   headerD;

void initHeaders()
{
    asize = fsize/8 + 1;
    hsize = fsize/256;
    width =    256;
    while(hsize>64*1024){hsize/=2;width*=2;}
    hsize+=1;
    headerS=(LPVOID)calloc(hsize*4,1);
    if (headerS==NULL) {fprintf(stderr,"Cannot allocate headerS"); exit(1);}
    headerD=(LPVOID)calloc(hsize*4,1);
    if (headerD==NULL) {fprintf(stderr,"Cannot allocate headerD"); exit(1);}
    initHeap();
}

void deleteTrees1(PNODE1 pn)
{
    if (pn==NULL) return;
    deleteTrees1(pn->left);
    deleteTrees1(pn->right);
    free((void *)pn);
}

void deleteTrees(PNODE pn)
{
    //fprintf(stderr,"\n pn==%08X",pn);getch();
    //if (pn>0) fprintf(stderr," pn->left==%08X pn->right==%08X",pn->left, pn->right);
    if (pn==NULL) return;
    deleteTrees(pn->left);
    deleteTrees(pn->right);
    if (pn->rcount>1) deleteTrees1((PNODE1)(pn->pos2));
    free((void *)pn);
}

extern PNODE rHead;

void deleteHeaders()
{
int   i;
PNODE *pps, *ppd;

    for (i=0; i<hsize; i++)
    {
        ppd = headerD;
        ppd += i;
        deleteTrees(*ppd);
        pps = headerS;
        pps += i;
        deleteTrees(*pps);
    }
    deleteTrees(rHead);
    free((void *)headerD);
    free((void *)headerS);
}

// rewritten June 23, 1998 sangcho ... i really hope this will work.

_key_   my_key;
node    my_node;

PNODE1 searchTT1(PNODE1 base, DWORD pos)
{
PNODE1  s;

    if (base==NULL) return NULL;
    s=searchTT1(base->left, pos);
    if (s != NULL) return s;
    if (base->pos2 != 0) return base;
    s=searchTT1(base->right,pos);
    return s;
}


PNODE1 searchTT(PNODE1 base, DWORD pos1, DWORD pos2)
{
PNODE1  s;

    if (pos2==-1) return searchTT1(base, pos2);
    s = base;
    while (s != NULL && pos2 != s->pos2)
    {
        if (TOINT(pos2)<TOINT(s->pos2))
		     s = s->left;
        else s = s->right;
    }
    return s;
}

PNODE searchT(PNODE base, DWORD pos1, DWORD pos2)
{
PNODE  s;
PNODE1 r;

    s = base;

    while (s != NULL && pos1 != s->pos1)
    {
        if (TOINT(pos1)<TOINT(s->pos1))
		     s = s->left;
        else s = s->right;
    }
    if (s == NULL) return NULL;
    if (s->rcount==1 || pos2==0) return s;

    // this is dangerous place
    r=searchTT((PNODE1)(s->pos2), pos1, pos2);
    if (r == NULL) return NULL;

    my_node.pos1  =pos1;
    my_node.pos2  =r->pos2;
    my_node.rclass=r->rclass;
    my_node.rcount=1;
    return &my_node;
}

PNODE searchTree(LPVOID h, DWORD pos1, DWORD pos2)
{
int    pos;
PNODE *ppn;

    pos = pos1-imageBase;
    if (pos<0) pos=0;
    pos/=width;
    if (pos>=hsize) pos=hsize-1;
    ppn  = h;
    ppn += pos;
    return searchT(*ppn, pos1, pos2);
}

PKEY searchBtree1(PKEY k)
{
PNODE t;

    if (k->class>0) t=searchTree(headerD, k->c_ref, k->c_pos);
    else t=searchTree(headerS, k->c_ref, k->c_pos);
    if (t==NULL) return NULL;
    my_key.class=t->rclass;
    my_key.c_ref=t->pos1;
    my_key.c_pos=t->pos2;
    return &my_key;
}

PKEY searchBtree3(PKEY k)
{
PNODE t;

    t=searchTree(headerD, k->c_ref, k->c_pos);
    if (t==NULL) return NULL;
    my_key.class=t->rclass;
    my_key.c_ref=t->pos1;
    my_key.c_pos=t->pos2;
    return &my_key;
}

extern PNODE headerX;

PKEY searchBtreeX(PKEY k)
{
PNODE t;

    t=searchT(headerX, k->c_ref, k->c_pos);
    if (t==NULL) return NULL;
    my_key.class=t->rclass;
    my_key.c_ref=t->pos1;
    my_key.c_pos=t->pos2;
    return &my_key;
}

int  referCount(DWORD ref)
{
PNODE t;

    t = searchTree(headerD, ref, 0);
    if (t==NULL) return 0;
    return t->rcount;
}

int  referCount1(DWORD ref)
{
PNODE t;

    t = searchTree(headerS, ref, 0);
    if (t==NULL) return 0;
    return t->rcount;
}

int insertTree(LPVOID h, int class, DWORD pos1, DWORD pos2)
{
int   pos;
PNODE *ppn;

    //fprintf(stderr,"\nHERE 1 c=%3d r=%08X p=%08X",class,pos1,pos2),getch();

	pos = pos1-imageBase;
    if (pos<0) pos=0;
    pos/=width;
    if (pos>=hsize) pos=hsize-1;
    ppn = h;
    ppn += pos;
    return insertT(ppn, class, pos1, pos2);
}

PNODE headerX=NULL;

int MyBtreeInsertX(PKEY k)
{
    return insertT(&headerX, k->class, k->c_ref, k->c_pos);
    return 1;
}


int MyBtreeInsert(PKEY k)
{
    //fprintf(stderr,"\nHERE 0 c=%3d r=%08X p=%08X",k->class,k->c_ref,k->c_pos),getch();

    if (k->class>0)
         return insertTree(headerD, k->class, k->c_ref, k->c_pos);
    else return insertTree(headerS, k->class, k->c_ref, k->c_pos);
    return 1;
}

int  MyBtreeInsertEx(PKEY k)
{
//_key_    key;

    MyBtreeInsert(k);
	return 1;
}


int deleteTree(LPVOID h, DWORD pos1, DWORD pos2)
{
int   pos;
PNODE *ppn;

	pos = pos1-imageBase;
    if (pos<0) pos=0;
    pos/=width;
    if (pos>=hsize)pos=hsize-1;
    ppn  = h;
    ppn += pos;
    return deleteT(ppn, pos1, pos2);
}

// i can refuse to be deleted provied that reference count is big enough.
int  MyBtreeDelete(PKEY k)
{

    if (k->class>0)
         return deleteTree(headerD, k->c_ref, k->c_pos);
    else return deleteTree(headerS, k->c_ref, k->c_pos);
    return 1;
}

int   sortCol=0;

int sortT(PNODE1 pn, DWORD pos1)
{
    if (pn==NULL) return 0;
    sortT(pn->left, pos1);
    printf("%4d:%08X<%08X,", pn->rclass, (int)pos1, (int)(pn->pos2));
    if(sortCol++ % 4==0)printf("\n");
    sortT(pn->right, pos1);
    return 1;
}


int sortTree(PNODE pn)
{
    if (pn==NULL) return 0;
    sortTree(pn->left);
    if (pn->rcount>1) sortT((PNODE1)(pn->pos2), pn->pos1);
    if (pn->rcount==1){
    printf("%4d:%08X<%08X,", pn->rclass, (int)(pn->pos1), (int)(pn->pos2));
    if(sortCol++ % 4==0)printf("\n");}
    sortTree(pn->right);
    return 1;
}

int sortTrees()
{
int   i;
PNODE *ppd;

    for (i=0; i<hsize; i++)
    {
        ppd = headerD;
        ppd += i;
        sortTree(*ppd);
    }
    return 1;
}

int sortTrees1()
{
int   i;
PNODE *ppd;

    for (i=0; i<hsize; i++)
    {
		ppd = headerS;
        ppd += i;
		sortTree(*ppd);
    }
    return 1;
}

/*                                                           */
/*  RBTRSRCH.C  :  Red-Black tree Libaray                    */
/*                                                           */
/*                  Programmed By Lee,jaekyu                 */
/*                  modified   by Sang Cho                   */

node   my_node;


PNODE1 rotate1(PNODE1 *base, PNODE1 p, DWORD pos1, DWORD pos2)
{     /* single rotation */
PNODE1 child, gchild;

         if (p==NULL)        child=*base;
    else if (TOINT(pos2) < TOINT(p->pos2))
	     child = p->left;
    else child = p->right;
    if (TOINT(pos2) < TOINT(child->pos2))
    {
        gchild = child->left;
        child->left = gchild->right;
        gchild->right = child;
    }
    else
    {
        gchild = child->right;
        child->right = gchild->left;
        gchild->left = child;
    }
         if (p==NULL)           *base    = gchild;
    else if (TOINT(pos2) < TOINT(p->pos2))
	     p->left  = gchild;
    else p->right = gchild;
    return gchild;
}

PNODE rotate(PNODE *base, PNODE p, DWORD pos1, DWORD pos2)
{     /* single rotation */
PNODE child, gchild;

         if (p==NULL)        child=*base;
    else if (TOINT(pos1) < TOINT(p->pos1))
	     child = p->left;
    else
	     child = p->right;
    if (TOINT(pos1) < TOINT(child->pos1))
    {
        gchild = child->left;
        child->left = gchild->right;
        gchild->right = child;
    }
    else
    {
        gchild = child->right;
        child->right = gchild->left;
        gchild->left = child;
    }
         if (p==NULL)           *base    = gchild;
    else if (TOINT(pos1) < TOINT(p->pos1))
	     p->left  = gchild;
    else p->right = gchild;
    return gchild;
}

int  insertTT(PNODE1 *base, int class, DWORD pos1, DWORD pos2)
{
    PNODE1 t, p, g, gg;
    gg = g = p = NULL;
    t = *base;
    while (t != NULL)
    {
        if (pos2 == t->pos2)  return 0;

        if (t->left && t->right && t->left->red && t->right->red)
        {
            t->red = 1;        /* color flip */
            t->left->red = t->right->red = 0;
            if (p && p->red && g)  /* rotation needed */
            {
                g->red = 1;
                if (TOINT(pos2) < TOINT(g->pos2)
				 != TOINT(pos2) < TOINT(p->pos2))
                    p = rotate1(base, g, pos1, pos2);  /* double rotation */
                t = rotate1(base, gg, pos1, pos2);
                t->red = 0;
            }
            (*base)->red = 0;
        }

        gg = g;      g = p;      p = t;

        if (TOINT(pos2) < TOINT(t->pos2))
		     t = t->left;
        else t = t->right;
    }
    if ((t = (PNODE1)calloc(sizeof(node1),1)) == NULL)
        return 0;
    t->pos2 = pos2;
    t->rclass = class;
    t->left = NULL;
    t->right = NULL;
           if (p==NULL)        *base = t;
    else if (TOINT(pos2) < TOINT(p->pos2))
	     p->left = t;
    else p->right = t;
    t->red = 1;        /* paint color */
    if (p && p->red && g)  /* rotation needed */
    {
        g->red = 1;
        if (TOINT(pos2) < TOINT(g->pos2) != TOINT(pos2) < TOINT(p->pos2))
            p = rotate1(base, g, pos1, pos2);  /* double rotation */
        t = rotate1(base, gg, pos1, pos2);
        t->red = 0;
    }
    (*base)->red = 0;
    return 1;
}

int  insertSecond(PNODE t, int class, DWORD pos1, DWORD pos2)
{
DWORD   pos;

    if (t->pos2==pos2) return 0;
    if (t->rcount==1)
    {
        pos=t->pos2;
		t->pos2=0;
        insertTT((PNODE1*)&(t->pos2), t->rclass, pos1, pos);
        insertTT((PNODE1*)&(t->pos2), class, pos1, pos2);
        t->rcount=2;
        return 1;
    }
    if (insertTT((PNODE1*)&(t->pos2),class,pos1,pos2))
        {
            t->rcount += 1;
            return 1;
        }
    return 0;
}

int  insertT(PNODE *base, int class, DWORD pos1, DWORD pos2)
{
    PNODE t, p, g, gg;
    gg = g = p = NULL;
    t = *base;
    while ((t != NULL))
    {
        if (pos1==t->pos1)
            return insertSecond(t, class, pos1, pos2); /* equal key */

        if ( (t->left != NULL) && (t->right != NULL) && t->left->red && t->right->red)
        {
            t->red = 1;        /* color flip */
            t->left->red = t->right->red = 0;
            if (p && p->red && g)  /* rotation needed */
            {
                g->red = 1;
                if (TOINT(pos1) < TOINT(g->pos1) != TOINT(pos1) < TOINT(p->pos1))
                    p = rotate(base, g, pos1, pos2);  /* double rotation */
                t = rotate(base, gg, pos1, pos2);
                t->red = 0;
            }
            (*base)->red = 0;
        }

        gg = g;      g = p;      p = t;

        if (TOINT(pos1) < TOINT(t->pos1))  t = t->left;
        else                               t = t->right;
    }
    if ((t = (PNODE)calloc(sizeof(node),1)) == NULL)
        return 0;
    t->pos1 = pos1;
    t->pos2 = pos2;
    t->rclass = class;
    t->rcount = 1;
    t->left = NULL;
    t->right = NULL;
         if (p == NULL)      *base = t;
    else if (TOINT(pos1) < TOINT(p->pos1)) p->left = t;
    else                                   p->right = t;
    t->red = 1;        /* paint color */
    if (p && p->red && g)  /* rotation needed */
    {
        g->red = 1;
        if (TOINT(pos1) < TOINT(g->pos1) != TOINT(pos1) < TOINT(p->pos1))
            p = rotate(base, g, pos1, pos2);  /* double rotation */
        t = rotate(base, gg, pos1, pos2);
        t->red = 0;
    }
    (*base)->red = 0;
    return 1;
}

PNODE1 findSeed1(PNODE1 *base, DWORD pos1, DWORD pos2)
{
PNODE1    del, seed_parent, parent;
    seed_parent = NULL;
    parent = NULL;
    del = (*base);
    while (del != NULL)
    {
        if (TOINT(pos2) < TOINT(del->pos2))
        {
            if (del->red || (del->right && del->right->red))
                seed_parent = parent;
            parent = del;
            del = del->left;
        }
        else
        {
            if (del->red || (del->left && del->left->red))
                seed_parent = parent;
            parent = del;
            del = del->right;
        }
    }
    return seed_parent;
}


PNODE findSeed(PNODE *base, DWORD pos1, DWORD pos2)
{
PNODE    del, seed_parent, parent;
    seed_parent = NULL;
    parent = NULL;
    del = (*base);
    while (del != NULL)
    {
        if (TOINT(pos1) < TOINT(del->pos1))
        {
            if (del->red || (del->right && del->right->red))
                seed_parent = parent;
            parent = del;
            del = del->left;
        }
        else
        {
            if (del->red || (del->left && del->left->red))
                seed_parent = parent;
            parent = del;
            del = del->right;
        }
    }
    return seed_parent;
}

void make_leaf_red1(PNODE1 *base, DWORD pos1, DWORD pos2)
{
    PNODE1 seed_parent, seed, seed_child;
    seed_parent = findSeed1(base, pos1, pos2);
    if (seed_parent == NULL)
    {
        seed_parent = NULL;
        seed = *base;
        seed->red = 1;
    }
    else
    {
        if (seed_parent == NULL || TOINT(pos2) < TOINT(seed_parent->pos2))
            seed = seed_parent->left;
        else
            seed = seed_parent->right;
    }
    if (!seed->red)   /* sibling is red, reverse rotation */
    {
        if (TOINT(pos2) < TOINT(seed->pos2))  seed_child = seed->right;
        else                                  seed_child = seed->left;
        seed->red = 1;
        seed_child->red = 0;
        seed_parent = rotate1(base, seed_parent, pos1, seed_child->pos2);
    }
    while (seed->left && seed->right)
    {
        seed->red = 0;
        seed->right->red = seed->left->red = 1;
        if (TOINT(pos2) < TOINT(seed->pos2))
        {
            if ((seed->right->left  && seed->right->left->red)
             || (seed->right->right && seed->right->right->red))
            {   /* reverse rotation needed! */
                if (seed->right->left && seed->right->left->red)
                {
                    seed->right->red = 0;
                    rotate1(base, seed, pos1, seed->right->left->pos2);
                }
                else
                    seed->right->right->red = 0;
                rotate1(base, seed_parent, pos1, seed->right->pos2);
            }
            seed_parent = seed;
            seed = seed->left;
        }
        else
        {
            if ((seed->left->left  && seed->left->left->red)
             || (seed->left->right && seed->left->right->red))
            {
                if (seed->left->right && seed->left->right->red)
                {
                    seed->left->red = 0;
                    rotate1(base, seed, pos1, seed->left->right->pos2);
                }
                else
                    seed->left->left->red = 0;
                rotate1(base, seed_parent, pos1, seed->left->pos2);
            }
            seed_parent = seed;
            seed = seed->right;
        }
    }
}


void make_leaf_red(PNODE *base, DWORD pos1, DWORD pos2)
{
    PNODE seed_parent, seed, seed_child;
    seed_parent = findSeed(base, pos1, pos2);
    if (seed_parent == NULL)
    {
        seed_parent = NULL;
        seed = *base;
        seed->red = 1;
    }
    else
    {
        if (TOINT(pos1) < TOINT(seed_parent->pos1))
            seed = seed_parent->left;
        else
            seed = seed_parent->right;
    }
    if (!seed->red)   /* sibling is red, reverse rotation */
    {
        if (TOINT(pos1) < TOINT(seed->pos1))  seed_child = seed->right;
        else                                  seed_child = seed->left;
        seed->red = 1;
        seed_child->red = 0;
        seed_parent = rotate(base, seed_parent, seed_child->pos1, pos2);
    }
    while (seed->left && seed->right)
    {
        seed->red = 0;
        seed->right->red = seed->left->red = 1;
        if (TOINT(pos1) < TOINT(seed->pos1))
        {
            if ((seed->right->left  && seed->right->left->red)
             || (seed->right->right && seed->right->right->red))
            {   /* reverse rotation needed! */
                if (seed->right->left && seed->right->left->red)
                {
                    seed->right->red = 0;
                    rotate(base, seed, seed->right->left->pos1, pos2);
                }
                else
                    seed->right->right->red = 0;
                rotate(base, seed_parent, seed->right->pos1, pos2);
            }
            seed_parent = seed;
            seed = seed->left;
        }
        else
        {
            if ((seed->left->left  && seed->left->left->red)
             || (seed->left->right && seed->left->right->red))
            {
                if (seed->left->right && seed->left->right->red)
                {
                    seed->left->red = 0;
                    rotate(base, seed, seed->left->right->pos1, pos2);
                }
                else
                    seed->left->left->red = 0;
                rotate(base, seed_parent, seed->left->pos1, pos2);
            }
            seed_parent = seed;
            seed = seed->right;
        }
    }
}

int  deleteTT(PNODE1 *base, DWORD pos1, DWORD pos2)
{
PNODE1  parent, del, center, pcenter, son;
    parent = NULL;
    del = (*base);
    while (del && TOINT(pos2) < TOINT(del->pos2))
    {
        parent = del;
        if (TOINT(pos2) < TOINT(del->pos2))  del = del->left;
        else                                 del = del->right;
    }
    if (del == NULL) return 0;  /* can't find */
	if (del->pos2!=pos2)return 0;

    if (del->right && del->left)
    {
        pcenter = del;
        center = del->right;
        while (center->left != NULL)
        {
            pcenter = center;
            center = center->left;
        }

        del->pos2  =center->pos2;
        del->rclass=center->rclass;
        del = center;
        parent = pcenter;
        pos2   = del->pos2;
    }
    if (del->left || del->right)
    {  /* one child must be red */
        if (del->left)  son = del->left;
        else            son = del->right;
        son->red = 0;
    }
    else if (del->left == NULL && del->right == NULL)
    {  /* leaf node */
        if (!del->red) make_leaf_red1(base, pos1, del->pos2);
        son = NULL;
    }
    (*base)->red = 0;
         if (parent == NULL) *base=son;
    else if (TOINT(pos2) < TOINT(parent->pos2))
         parent->left = son;
    else parent->right = son;
    free(del);

    return 1;
}


int  deleteT(PNODE *base, DWORD pos1, DWORD pos2)
{
PNODE  parent, del, center, pcenter, son;
int    i;
    parent = NULL;
    del = (*base);
    while (del && TOINT(pos1) < TOINT(del->pos1))
    {
        parent = del;
        if ((int)pos1 < (int)(del->pos1))  del = del->left;
        else                               del = del->right;
    }
    if (del == NULL) return 0;  /* can't find */
	if (del->pos1!=pos1) return 0;
	// anyway found it

	if (del->rcount>1)
	{
	     i=deleteTT((PNODE1*)&(del->pos2), pos1, pos2);
	     if(i>0) del->rcount-=1;
		 return 1;
	}

    if (del->right && del->left)
    {
        pcenter = del;
        center = del->right;
        while (center->left != NULL)
        {
            pcenter = center;
            center = center->left;
        }

        del->pos1   =center->pos1;
        del->pos2   =center->pos2;
        del->rclass =center->rclass;
        del->rcount =center->rcount;
        del = center;
        parent = pcenter;
           pos1   = del->pos1;
        pos2   = del->pos2;
    }
    if (del->left || del->right)
    {  /* one child must be red */
        if (del->left)  son = del->left;
        else            son = del->right;
        son->red = 0;
    }
    else if (del->left == NULL && del->right == NULL)
    {  /* leaf node */
        if (!del->red) make_leaf_red(base, del->pos1, pos2);
        son = NULL;
    }
    (*base)->red = 0;
         if (parent == NULL) *base=son;
    else if (TOINT(pos1) < TOINT(parent->pos1))
         parent->left = son;
    else parent->right = son;
    free(del);

    return 1;
}

// Priority Queue routines

int  heapLTE(_labels x, _labels y)
{
    if (x.priority < y.priority) return 1;
    if (x.priority > y.priority) return 0;
    if (x.ref >= y.ref) return 1;
    return 0;
}

int  heapLT(_labels x, _labels y)
{
    if (x.priority < y.priority) return 1;
    if (x.priority > y.priority) return 0;
    if (x.ref > y.ref) return 1;
    return 0;
}

void initHeap()
{
    pArray[0].priority = INT_MAX;
    pArray[0].ref      = 0;
    jLc = 0;
}

int upHeap(_labels a[], int k)
{
_labels   v;
    //fprintf(stderr,"u");
    v = a[k];
    while(heapLTE(a[k/2],v))
    {
        a[k] = a[k/2];
        k /= 2;
    }
    a[k] = v;
    return k;
}

void downHeap(_labels a[], int n, int k)
{
_labels    v;
int        i;

    v = a[k];
    while(k <= n/2)
    {
        i = k + k;
        if (i < n && heapLT(a[i],a[i+1])) i++;
        if (heapLTE(a[i],v)) break;
        a[k] = a[i];
        k=i;
    }
    a[k] = v;
}



_labels  getHeap(int *n)
{
    _labels v = pArray[1];

    //fprintf(stderr,"g");
    pArray[1] = pArray[(*n)--];
    downHeap(pArray, *n, 1);
    return v;
}

int putHeap(int *n, int priority, DWORD ref)
{
int     i;
    //fprintf(stderr,"p");
    i=++(*n);
    pArray[i].priority = priority;
    pArray[i].ref      = ref;
    return upHeap(pArray, i);
}

int getLabels()
{
_labels  v;
int      r;
    while(jLc>0)
    {
        v = getHeap(&jLc);
        r = v.ref;
        if (isGoodAddress(r)) return r;
    }
	return 1;
}

PNODE rHead=NULL;

void addRef(int c, DWORD r, DWORD p)
{
    insertT(&rHead, c, r, p);
}

int  countRef(DWORD r)
{
PNODE    t;

    t=searchT(rHead, r, 0);
    if (t==NULL) return 0;
    return t->rcount;
}

int addLabelsNum=0;
int addLabelsHistogram[256]={0,};
void addLabels(DWORD r, int pri)
{
    if (!isItFirstTime(r)) return;
	if (r<imageBase) return;
    putHeap(&jLc, pri, r);
    addLabelsHistogram[getByteFile(r)]+=1;
    /*
    if (r==debugAdd)
    {
        fprintf(stderr,"\nn=%d c=%08X b=%02X r=%08X pri=%4d nj=%d njN=%08X",
                nextMode,cur_position,getByteFile(r),r,pri,needJump,needJumpNext);
        peekTrace();
        getch();
    }*/
    addLabelsNum++;
    setFirstTime(r);
}
