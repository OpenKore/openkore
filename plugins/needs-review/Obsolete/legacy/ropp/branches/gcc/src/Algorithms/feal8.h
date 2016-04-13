#ifndef _FEAL8_H_
#define _FEAL8_H_

#ifdef __cplusplus
	extern "C" {
#endif

void F8_SetKey(unsigned char *KP);
void F8_Encrypt(unsigned char *Plain, unsigned char *Cipher);
void F8_Decrypt(unsigned char *Cipher, unsigned char *Plain);

#ifdef __cplusplus
	}
#endif

#endif /* _FEAL8_H_ */
