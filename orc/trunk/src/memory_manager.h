/*
 *  ORC - Open Ragnarok Client
 *  memory_manager.h -
 *
 *  Copyright (C) 2006 Crypticode <crypticode@users.sf.net>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 *  $Id$
 *
 */


// TODO: implement memory manager

void dump(void* p, int len) {
    unsigned char* start = (unsigned char*)p;
    unsigned char* end = start + len;

    printf("           ");
    for(int i=0; i<16; i++) printf("%02X ", i);
    printf("\n");
    printf("--------------------------------------------------------------------------------\n");

    for(unsigned char* pos=start, c=1, m=0; pos<end; pos++,c++) {
        if(m == 0) {
            if(c == 1) printf("%08xh: ", pos-start );
            printf("%02X", *pos);
            if(c != 16) printf(" ");
            if(c == 16) {
                printf(" | ");
                m=1;
                c=0;
                pos-=16;
            } else if(pos == end-1) {
                int j=((16-c));
                if(j > 0) {
                    for(int i=0; i<j; i++) printf("-- ");
                    printf("| ");
                }
                m=1;
                pos-=c;
                c=0;
            }
        } else {
            if(*pos <= 16) printf(".");
            else printf("%c", *pos);
            if(c == 16) {
                printf("\n");
                m=0;
                c=0;
            }
        }
    }
}
