/*
 * OpenKore - Padded Packet Emulator.
 * Copyright (c) 2007 kLabMouse, Japplegame, and many other contributors
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See http://www.gnu.org/licenses/gpl.html for the full license.
 */

/**
 * Padded packets algorithms interface.
 *
 * The padded packets system use a variety of hashing algorithms,
 * depending on certain factors such as the last received map sync ID,
 * account ID, the packet to pad, etc. This header provides a unified
 * interface for calling the correct hashing algorithm.
 */

#ifndef _ALGORITHMS_H_
#define _ALGORITHMS_H_

#include "../typedefs.h"

namespace OpenKore {
namespace PaddedPackets {

	/**
	 * Generate a hash using the correct hashing algorithm,
	 * based on the given parameters.
	 */
	dword createHash(int map_sync, int sync, int account_id, short packet);

	/**
	 * Generate a hash using a specific algorithm and a specific key.
	 * This is mostly useful for debugging purposes.
	 */
	dword createHash(int algorithm_id, dword key);

} // PaddedPackets
} // OpenKore

#endif /* _ALGORITHMS_H_ */
