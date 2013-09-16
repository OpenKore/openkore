#ifndef _REMOTE_H_
#define _REMOTE_H_

#ifdef __cplusplus
extern "C" {
#endif

char *remote_control_init (const char *address, unsigned int port);
void  remote_control_end  ();

#ifdef __cplusplus
}
#endif

#endif /* _REMOTE_H_ */
