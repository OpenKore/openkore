// -- use tabs, not spaces
// -- tab spacing is 4 characters
// -- no /* */ comments
//
#ifndef  PPENGINE_H
#define  PPENGINE_H

#include "../typedefs.h"

//---------------------------------------------------------------------------
class PPBlock
{
public:
	PPBlock();
	~PPBlock();

	void			Reset();
	void			Add(dword data);

	dword operator	[](unsigned int index) const;
	unsigned int	GetSize() const;

private:
	dword			*buffer;
	unsigned int	currentPos, bufLen;
};

//---------------------------------------------------------------------------
#define PPENGINE_BUFSIZE	512

class PPEngine
{
public:
	PPEngine();
	~PPEngine();

	void AddKey(dword data);
	dword GetKey(unsigned int index) const;

	void SetSync(dword sync);
	void SetMapSync(dword mapSync);
	void SetAccId(dword accId);

	// generates packet to destAddr and returns length of packet
	unsigned int Encode(byte *dest, word type);

	// decodes packet from src and peeks given number of keys. 
	// Use GetKey() to actually get the keys
	void Decode(byte *src, unsigned int keys);

	// copy external packet to internal buffer
	void SetPacket(byte *packet, dword len);

private:
	PPBlock			inputKeys, outputKeys;
	dword			serverMapSync, clientSync, clientAccId;
	byte			pktBuffer[PPENGINE_BUFSIZE];
};

#endif
