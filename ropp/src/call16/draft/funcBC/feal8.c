/* FEAL8 */

/*
Version of 20 September 1989.
*/
/* FEAL8 - Implementation of NTT's FEAL-8 cipher. ---------------------------
Version of 11 September 1989.
*/

typedef unsigned char ByteType ;

void SetKey( ByteType * ) ;
void Encrypt( ByteType *Plain, ByteType *Cipher ) ;
void Decrypt( ByteType *Cipher, ByteType *Plain ) ;

#include "feal8.h"
#ifdef DEBUG
#include <stdio.h>
#endif

typedef unsigned long HalfWord ;

typedef unsigned int QuarterWord ;

QuarterWord K[16] ;
HalfWord K89, K1011, K1213, K1415 ;

/*
     Decrypt a block, using the last key set.
*/
void Decrypt( ByteType *Cipher, ByteType *Plain )
{
    HalfWord L, R, NewL ;
    int r ;
    HalfWord MakeH1( ByteType * ) ;
    HalfWord f( HalfWord, QuarterWord ) ;
    void DissH1( HalfWord, ByteType * ) ;

    R = MakeH1( Cipher ) ;
    L = MakeH1( Cipher+4 ) ;
    R ^= K1213 ;
    L ^= K1415 ;
    L ^= R ;

    for ( r = 7 ; r >= 0 ; --r )
    {
     NewL = R ^ f( L, K[r] ) ;
     R = L ;
     L = NewL ;
    }

    R ^= L ;
    R ^= K1011 ;
    L ^= K89 ;

    DissH1( L, Plain ) ;
    DissH1( R, Plain + 4 ) ;
}

/*
     Disassemble the given halfword into 4 bytes.
*/
void DissH1( HalfWord H, ByteType *D )
{
    union {
     HalfWord All ;
     ByteType Byte[4] ;
    } T ;

    T.All = H ;
    *D++ = T.Byte[0] ;
    *D++ = T.Byte[1] ;
    *D++ = T.Byte[2] ;
    *D   = T.Byte[3] ;
}

/*
     Disassemble a quarterword into two Bytes.
*/
void DissQ1( QuarterWord Q, ByteType *B )
{
    union {
     QuarterWord All ;
     ByteType Byte[2] ;
    } QQ ;

    QQ.All = Q ;
    *B++ = QQ.Byte[0] ;
    *B   = QQ.Byte[1] ;
}

/*
     Encrypt a block, using the last key set.
*/
void Encrypt( ByteType *Plain, ByteType *Cipher )
{
    HalfWord L, R, NewR ;
    int r ;
    HalfWord MakeH1( ByteType * ) ;
    HalfWord f( HalfWord, QuarterWord ) ;
    void DissH1( HalfWord, ByteType * ) ;

    L = MakeH1( Plain ) ;
    R = MakeH1( Plain+4 ) ;
    L ^= K89 ;
    R ^= K1011 ;
    R ^= L ;

    for ( r = 0 ; r < 8 ; ++r )
    {
     NewR = L ^ f( R, K[r] ) ;
     L = R ;
     R = NewR ;
    }

    L ^= R ;
    R ^= K1213 ;
    L ^= K1415 ;

    DissH1( R, Cipher ) ;
    DissH1( L, Cipher + 4 ) ;
}

/*
     Evaluate the f function.
*/
HalfWord f( HalfWord AA, QuarterWord BB )
{
    ByteType f1, f2 ;
    union {
     unsigned long All ;
     ByteType Byte[4] ;
    } RetVal, A ;
    union {
     unsigned int All ;
     ByteType Byte[2] ;
    } B ;
    ByteType S0( ByteType, ByteType ) ;
    ByteType S1( ByteType, ByteType ) ;

    A.All = AA ;
    B.All = BB ;
    f1 = A.Byte[1] ^ B.Byte[0] ^ A.Byte[0] ;
    f2 = A.Byte[2] ^ B.Byte[1] ^ A.Byte[3] ;
    f1 = S1( f1, f2 ) ;
    f2 = S0( f2, f1 ) ;
    RetVal.Byte[1] = f1 ;
    RetVal.Byte[2] = f2 ;
    RetVal.Byte[0] = S0( A.Byte[0], f1 ) ;
    RetVal.Byte[3] = S1( A.Byte[3], f2 ) ;
    return RetVal.All ;
}

/*
     Evaluate the FK function.
*/
HalfWord FK( HalfWord AA, HalfWord BB )
{
    ByteType FK1, FK2 ;
    union {
     unsigned long All ;
     ByteType Byte[4] ;
    } RetVal, A, B ;
    ByteType S0( ByteType, ByteType ) ;
    ByteType S1( ByteType, ByteType ) ;

    A.All = AA ;
    B.All = BB ;
    FK1 = A.Byte[1] ^ A.Byte[0] ;
    FK2 = A.Byte[2] ^ A.Byte[3] ;
    FK1 = S1( FK1, FK2 ^ B.Byte[0] ) ;
    FK2 = S0( FK2, FK1 ^ B.Byte[1] ) ;
    RetVal.Byte[1] = FK1 ;
    RetVal.Byte[2] = FK2 ;
    RetVal.Byte[0] = S0( A.Byte[0], FK1 ^ B.Byte[2] ) ;
    RetVal.Byte[3] = S1( A.Byte[3], FK2 ^ B.Byte[3] ) ;
    return RetVal.All ;
}

/*
     Assemble a HalfWord from the four bytes provided.
*/
HalfWord MakeH1( ByteType *B )
{
    union {
     unsigned long All ;
     ByteType Byte[4] ;
    } RetVal ;

    RetVal.Byte[0] = *B++ ;
    RetVal.Byte[1] = *B++ ;
    RetVal.Byte[2] = *B++ ;
    RetVal.Byte[3] = *B ;
    return RetVal.All ;
}

/*
     Make a halfword from the two quarterwords given.
*/
HalfWord MakeH2( QuarterWord *Q )
{
    ByteType B[4] ;
    void DissQ1( QuarterWord, ByteType * ) ;

    DissQ1( *Q++, B ) ;
    DissQ1( *Q, B+2 ) ;
    return MakeH1( B ) ;
}

/*
     Evaluate the Rot2 function.
*/
ByteType Rot2( ByteType X )
{
    static int First = 1 ;
    static ByteType RetVal[ 256 ] ;

    if ( First )
    {
     int i, High, Low ;
     for ( i = 0, High = 0, Low = 0 ; i < 256 ; ++i )
     {
	 RetVal[ i ] = High + Low ;
	 High += 4 ;
	 if ( High > 255 )
	 {
	  High = 0 ;
	  ++Low ;
	 }
     }
     First = 0 ;
    }
    return RetVal[ X ] ;
}

ByteType S0( ByteType X1, ByteType X2 )
{
    ByteType Rot2( ByteType X ) ;

    return Rot2( ( X1 + X2 ) & 0xff ) ;
}

ByteType S1( ByteType X1, ByteType X2 )
{
    ByteType Rot2( ByteType X ) ;

    return Rot2( ( X1 + X2 + 1 ) & 0xff ) ;
}

/*
     KP points to an array of 8 bytes.
*/
void SetKey( ByteType *KP )
{
    union {
     HalfWord All ;
     ByteType Byte[4] ;
    } A, B, D, NewB ;
    union {
     QuarterWord All ;
     ByteType Byte[2] ;
    } Q ;
    int i ;
    QuarterWord *Out ;
    HalfWord FK( HalfWord, HalfWord ) ;
    HalfWord MakeH2( QuarterWord * ) ;

    A.Byte[0] = *KP++ ;
    A.Byte[1] = *KP++ ;
    A.Byte[2] = *KP++ ;
    A.Byte[3] = *KP++ ;
    B.Byte[0] = *KP++ ;
    B.Byte[1] = *KP++ ;
    B.Byte[2] = *KP++ ;
    B.Byte[3] = *KP ;
    D.All = 0 ;

    for ( i = 1, Out = K ; i <= 8 ; ++i )
    {
     NewB.All = FK( A.All, B.All ^ D.All ) ;
     D = A ;
     A = B ;
     B = NewB ;
     Q.Byte[0] = B.Byte[0] ;
     Q.Byte[1] = B.Byte[1] ;
     *Out++ = Q.All ;
     Q.Byte[0] = B.Byte[2] ;
     Q.Byte[1] = B.Byte[3] ;
     *Out++ = Q.All ;
    }
    K89 = MakeH2( K+8 ) ;
    K1011 = MakeH2( K+10 ) ;
    K1213 = MakeH2( K+12 ) ;
    K1415 = MakeH2( K+14 ) ;
}


