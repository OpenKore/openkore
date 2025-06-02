CXX = g++
CXXFLAGS = -shared -fPIC -O2 -Wall -Wno-unknown-pragmas
LIBS = -lws2_32 -luser32 -lkernel32
TARGET = recv.asi
SOURCE = Recv/recv.cpp

$(TARGET): $(SOURCE)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(SOURCE) $(LIBS)

clean:
	del $(TARGET)

.PHONY: clean