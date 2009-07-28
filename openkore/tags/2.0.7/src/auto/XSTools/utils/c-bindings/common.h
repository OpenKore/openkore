#ifndef _OCB_COMMON_H_
#define _OCB_COMMON_H_

#ifndef STDCALL
	#ifdef WIN32
		#define STDCALL __stdcall
	#else
		#define STDCALL
	#endif
#endif

#ifndef O_DECLARE
	#ifdef __cplusplus
		#define O_DECL(type) extern "C" type STDCALL
	#else
		#define O_DECL(type) type STDCALL
	#endif
#endif

#endif /* _OCB_COMMON_H_ */
