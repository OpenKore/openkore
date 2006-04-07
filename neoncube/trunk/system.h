// $Id$

// *
// *   gryff, a GRF archive management utility, src/system.h
// *   Copyright (C) 2003-2005 Rasqual Twilight
// *
// *   This program is distributed in the hope that it will be useful,
// *   but WITHOUT ANY WARRANTY; without even the implied warranty of
// *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// *

// * system.h
// * Advanced system functions
// *
// *@author $Author$
// *@version $Revision$
// *

#ifndef __SYSTEM_H__
#define __SYSTEM_H__

#pragma once

namespace Memory
{
	/**
		Gets system memory alignment (mem granularity)
	**/
	static DWORD GetAlignment()
	{
	SYSTEM_INFO info;
		::GetSystemInfo (&info);
		return info.dwAllocationGranularity;
	}

	/**
		Rounds an address to the closest inferior aligned bound
	**/
	static uintptr_t RoundDown(uintptr_t value, DWORD dwAlignement = 0)
	{
		if ( !dwAlignement )
		{
			dwAlignement = Memory::GetAlignment();
		}
		return (value & ~((dwAlignement) - 1));
	}
};

#endif // !defined(__SYSTEM_H__)
