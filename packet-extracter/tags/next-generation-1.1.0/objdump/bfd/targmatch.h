#if !defined (SELECT_VECS) || defined (HAVE_i386pe_vec)

{ "i[3-7]86-*-mingw32*", NULL },{ "i[3-7]86-*-cygwin*", NULL },{ "i[3-7]86-*-winnt", NULL },{ "i[3-7]86-*-pe",
&i386pe_vec },
#endif
