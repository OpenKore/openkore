# command processor programs
RM=rm -f

# common compiler and linker executables/options/libraries
CC=gcc
CC_FLAGS=-Wall -O3 -DGRF_STATIC
LD=gcc
LD_FLAGS=

# project specific
CC_FLAGS+= -Izlib -Ilibgrf
LD_FLAGS+= -lz

OBJS=grfcrypt.o grfsupport.o grf.o gx.o
################################################################################################
# build target
all : gx
	

# for cleaning up

clean :
	-$(RM) $(OBJS) 2> /dev/null

relink : removeexe all

removeexe :
	-$(RM) gx 2> /dev/null



# source/target file dependencies
grfcrypt.o : libgrf/grfcrypt.c
	$(CC) $(CC_FLAGS) -c libgrf/grfcrypt.c

grfsupport.o : libgrf/grfsupport.c
	$(CC) $(CC_FLAGS) -c libgrf/grfsupport.c

grf.o : libgrf/grf.c
	$(CC) $(CC_FLAGS) -c libgrf/grf.c

gx.o : gx.c
	$(CC) $(CC_FLAGS) -c gx.c


# linkage

gx : $(OBJS)
	$(LD) -o $@ $^ $(LD_FLAGS)
