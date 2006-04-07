
                       Portable UnRAR version


   1. General

   This package includes freeware Unrar C++ source and a few makefiles
   (makefile.bcc, makefile.msc+msc.dep, makefile.unix). Unrar source
   is subset of RAR and generated from RAR source automatically,
   by a small program removing blocks like '#ifndef UNRAR ... #endif'.
   Such method is not perfect and you may find some RAR related
   stuff unnecessary in Unrar, especially in header files.

   If you wish to port Unrar to a new platform, you may need to edit
   '#define LITTLE_ENDIAN' in os.hpp and data type definitions
   in rartypes.hpp.

   It is important to provide 1 byte alignment for structures
   in model.hpp. Now it contains '#pragma pack(1)' directive,
   but your compiler may require something else. Though Unrar
   should work with other model.hpp alignments, its memory 
   requirements may increase significantly. Alignment in other
   modules is not important.

   If you use Borland C++ makefile (makefile.bcc), you need to define
   BASEPATHCC environment (or makefile) variable containing
   the path to Borland C++ installation.

   Makefile.unix contains both Linux and IRIX compiler option sets.
   Linux is selected by default. If you need to compile Unrar for IRIX,
   just uncomment corresponding lines.


   2. Unrar binaries

   If you compiled Unrar for OS, which is not present in "Downloads"
   and "RAR extras" on www.rarlab.com, we will appreciate if you send
   us the compiled executable to place it to our site.


   3. Acknowledgements

   This source includes parts of code written by the following authors:

   Dmitry Shkarin     PPMII text compression
   Dmitry Subbotin    Carryless rangecoder
   Szymon Stefanek    AES encryption
   Brian Gladman      AES encryption
   Steve Reid         SHA-1 hash function
   Marcus Herbert     makefile.unix file
   Tomasz Klim        fixes for libunrar.so


   4. Legal stuff

   Unrar source may be used in any software to handle RAR archives
   without limitations free of charge, but cannot be used to re-create
   the RAR compression algorithm, which is proprietary. Distribution
   of modified Unrar source in separate form or as a part of other
   software is permitted, provided that it is clearly stated in
   the documentation and source comments that the code may not be used
   to develop a RAR (WinRAR) compatible archiver.

   More detailed license text is available in license.txt.
