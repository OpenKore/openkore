/*
Include the original file
*/
#include "../CORE/perl.h"

/*
Fixes error: use of undeclared identifier 'dNOOP'

Read more:
http://www.veripool.org/issues/732-Verilog-Perl-Not-able-to-install-on-Verilog-Language-Mac-10-9-2
*/
#ifdef PERL_DARWIN
#ifdef dNOOP
#undef dNOOP
#define dNOOP
#endif
#endif
