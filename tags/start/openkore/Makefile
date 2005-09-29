CXX=g++
CXXFLAGS=-Wall -O3 -funroll-loops -finline-functions -march=i586 -mcpu=i686

.PHONY: all clean

all: Tools.so

Tools.so: Tools.cpp
	$(CXX) -shared -fPIC $(CXXFLAGS) Tools.cpp -o Tools.so

clean:
	rm -f Tools.so
