NASM=nasm -f elf
NASMOBJ=func_4.o func_56.o func_9a.o func_bc.o func_f.o

CC=gcc
CFLAGS= -Wall -fPIC
COBJ=call16_funcs.o cast.o mcg_cipher.o misty1.o rmd128.o snefru.o

CXX=g++
CXXFLAGS=$(CFLAGS)
CXXOBJ=call16.o

.PHONY: clean

libropp.so: $(NASMOBJ) $(COBJ) $(CXXOBJ)
	$(CXX) $(NASMOBJ) $(COBJ) $(CXXOBJ) -fPIC -shared -o libropp.so

func_4.o: func_4.asm
	$(NASM) $< -o $@
func_56.o: func_56.asm
	$(NASM) $< -o $@
func_9a.o: func_9a.asm
	$(NASM) $< -o $@
func_bc.o: func_bc.asm
	$(NASM) $< -o $@
func_f.o: func_f.asm
	$(NASM) $< -o $@

call16.o: call16.cpp call16.h
	$(CXX) -c $(CXXFLAGS) $< -o $@
call16_funcs.o: call16_funcs.c
	$(CXX) -c $(CFLAGS) $< -o $@

cast.o: cast.c
	$(CC) -c $(CFLAGS) $< -o $@
msg_cipher.o: msg_cipher.c
	$(CC) -c $(CFLAGS) $< -o $@
misty1.o: misty1.c
	$(CC) -c $(CFLAGS) $< -o $@
rmd128.o: rmd128.c
	$(CC) -c $(CFLAGS) $< -o $@
snefru.o: snefru.c
	$(CC) -c $(CFLAGS) $< -o $@

clean:
	rm -f *.o *.so
