/*
 *  ORC - Open Ragnarok Client
 *  gnd_ground.cpp - Resource Ground File Loader
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

#include "gnd_ground.h"

/*
 It's the side length of one tile square
*/
#define TILE_WIDTH 10.0
// #define L 10.0


#include "grf_interface.h"
extern CGRF_Interface* g_pGrfInterface;


GND::GND(char* szGrfPath, int watertype) {
    uint32_t filesize;
    void*    filedata;
    filedata = g_pGrfInterface->GetGND(szGrfPath, &filesize);
    if( filedata == NULL || !LoadFromMemory(filedata, filesize) ) {
        printf("Could not load GND file \"%s\"...", szGrfPath);
        return;
    }
    watertex = new GLuint[32];
    LoadWater(watertype);
}

GND::~GND() {}

void GND::LoadWater(int type) {
    char grfpath[256];
    glGenTextures(32, watertex);

    // 워터 isnt that the thing after szTextureName ?
    for(int i=0; i<iNumTextures-1; i++) {
        sprintf(grfpath,"워터\\water%d%02d.jpg", type, i);
        //LoadGRFTexture (grffile, textures_name[i], textures[i], NULL, extract);
        CSDL_GL_Texture* temp = new CSDL_GL_Texture( grfpath, 192 );
        watertex[ i ] = temp->m_iID;

        //LoadTextureAlpha (ragnapath, texname, watertex[i],192);
        //BuildTexture (texname, watertex[i],128);
        glTexParameterf(watertex[i],GL_TEXTURE_WRAP_S,GL_REPEAT);
        glTexParameterf(watertex[i],GL_TEXTURE_WRAP_T,GL_REPEAT);

        delete temp;
    }
}

void GND::DisplayWater(int frameno, float wavephase, float waterlevel, CFrustum* pFrustum) {

    CVector3 vTriangle[3];
    CVector3 vNormal;

    float h1=0, h2=0, h3=0, h4=0, ph=0;
    int i=0, j=0;

    float Rot[16] = { 1, 0, 0, 0,
                        0, 0, 1, 0,
                        0, -1, 0, 0,
                        0, 0, 0, 1 };

    glPushMatrix();

    //Rotate 90 degrees about the z axis
    glMultMatrixf(Rot);

    //Center it
    glTranslatef(-iSizeX*TILE_WIDTH/2, -iSizeY*TILE_WIDTH/2, waterlevel);

    pFrustum->CalculateFrustum();

    float Mat[16];
    glGetFloatv(GL_MODELVIEW_MATRIX, &Mat[0]);

    glDisable(GL_LIGHTING);

    glEnable(GL_BLEND);
    glColor4f(1, 1, 1, 0.75);

    glFrontFace(GL_CW);

    for (i = 0; i < iSizeY; i++)
        for (j = 0; j < iSizeX; j++) {
            int tilesup;
            int tileside;
            int tileotherside;


            if (pFrustum->CubeInFrustum(j*TILE_WIDTH, i*TILE_WIDTH, h1,TILE_WIDTH*2)) {

                h1 = sinf(j*5 + wavephase) + sinf(i*7 + wavephase);
                h2 = sinf(j*5 + wavephase) + sinf((i+1)*7 + wavephase);
                h3 = sinf((j+1)*5 + wavephase) + sinf((i+1)*7 + wavephase);
                h4 = sinf((j+1)*5 + wavephase) + sinf(i*7 + wavephase);

                vTriangle[0] = MatrixMultVect3f(Mat, j*TILE_WIDTH,     i*TILE_WIDTH,	   h1);
                vTriangle[1] = MatrixMultVect3f(Mat, j*TILE_WIDTH,     (i+1)*TILE_WIDTH, h2);
                vTriangle[2] = MatrixMultVect3f(Mat, (j+1)*TILE_WIDTH, (i+1)*TILE_WIDTH, h3);

                vNormal = Normal(vTriangle);

                glBindTexture(GL_TEXTURE_2D, watertex[frameno]);

                //number of blocks to occupy per texture
                int n = 5;
                float t1,t2,s1,s2;

                t1 = (float(j % n)) / float(n);
                t2 = (float(j % n)+1) / float(n);
                s1 = (float(i % n)) / float(n);
                s2 = (float(i % n)+1) / float(n);

                glBegin(GL_QUADS);
                glNormal3f(vNormal.x,vNormal.y,vNormal.z);

                glTexCoord2f(t1, s1);
                glVertex3f(j*TILE_WIDTH, i*TILE_WIDTH, h1);

                glTexCoord2f(t1, s2);
                glVertex3f(j*TILE_WIDTH, (i+1)*TILE_WIDTH, h2);

                glTexCoord2f(t2, s2);
                glVertex3f((j+1)*TILE_WIDTH, (i+1)*TILE_WIDTH, h3);

                glTexCoord2f(t2, s1);
                glVertex3f((j+1)*TILE_WIDTH, i*TILE_WIDTH, h4);

                glEnd();

            }
        }

    glEnable(GL_LIGHTING);

    glPopMatrix();
}

bool GND::LoadGAT(void* pData, uint32_t nSize) {
    unsigned char* pNeedle = (unsigned char*)pData;

    memcpy(&gat.header, pNeedle, 4);
    pNeedle += 4;

    memcpy(&gat.iUnknown,  pNeedle, sizeof(unsigned short));
    pNeedle += sizeof(unsigned short);

    memcpy(&gat.sizeX,  pNeedle, sizeof(int));
    pNeedle += sizeof(int);

    memcpy(&gat.sizeY,  pNeedle, sizeof(int));
    pNeedle += sizeof(int);

    gat.gatdata = (ro_gat_t *) malloc(sizeof(ro_gat_t) * gat.sizeX * gat.sizeY);
    memcpy(gat.gatdata, pNeedle, sizeof(ro_gat_t) * gat.sizeX * gat.sizeY);

    return true;
}



bool GND::LoadFromMemory(void* pData, uint32_t nSize) {

    READ(dwFileID, 0, 4);

    if( dwFileID != GNDHEADER ) { // "GRGN"
        printf("No valid GND header...\n");
        return false;
    }

    READ(bMajorVersion, 4, 1);
    READ(bMinorVersion, 5, 1);

    READ(iSizeX, 6, 4);
    READ(iSizeY, 10, 4);

    READ(fUnknown1, 14, 4);
    READ(iNumTextures, 18, 4);
    READ(iUnknown2, 22, 4);

    ro_string_t szTextureNames[iNumTextures];
//    ro_string_t szUnknown3[iNumTextures]; // TODO: identify

    printf("Loading .GND file version 0x%02X%02X...\n", bMajorVersion, bMinorVersion);

    for(int i=0; i<iNumTextures; i++) {
        READ(szTextureNames[i], 26 + (i * 80), 40);
//        MEMCPY(szUnknown3[i], pData, nSize, 66 + (i * 80), 40);
        printf("Loading ground texture: \"%s\"\n", szTextureNames[i]);
//        printf("Extra data: \"%s\"\n", szUnknown3[i]);
    }

    textures = new GLuint[iNumTextures];
    glGenTextures(iNumTextures, textures);

    for(int i=0; i<iNumTextures; i++) {
        //LoadGRFTexture (grffile, textures_name[i], textures[i], NULL, extract);
        CSDL_GL_Texture* temp = new CSDL_GL_Texture( szTextureNames[i], 255 );
        textures[ i ] = temp->m_iID;
        delete temp;
    }

    unsigned long iOffset = 26 + (iNumTextures * 80);

    READ(nlightmaps, iOffset, 4);
//    READ(nlightmaps, iOffset+4, 4);
//    READ(nlightmaps, iOffset+8, 4);
//    READ(nlightmaps, iOffset+12, 4);
    iOffset += 16;

    lightmaps = new ro_lightmap_t[nlightmaps];
    READ(lightmaps[0], iOffset, sizeof(ro_lightmap_t) * nlightmaps);
    iOffset += sizeof(ro_lightmap_t) * nlightmaps;

    READ(ntiles, iOffset, 4);
    iOffset += 4;

    tiles = new ro_tile_t[ntiles];
    READ(tiles[0], iOffset, sizeof(ro_tile_t) *  ntiles);
    iOffset += sizeof(ro_tile_t) * ntiles;

    cubes = new ro_cube_t[iSizeX*iSizeY];
    READ(cubes[0], iOffset, sizeof(ro_cube_t) *  iSizeX * iSizeY);
    iOffset += sizeof(ro_cube_t) *  iSizeX * iSizeY;

    return true;
}

void GND::Display(CFrustum* pFrustum) {

    CVector3 vTriangle[3];
    CVector3 vNormal;

    float Mat[16];

    // TODO: make similar, static matrices global ...
    float Rot[16] = {
                          1.0,  0.0, 0.0, 0.0,
                          0.0,  0.0, 1.0, 0.0,
                          0.0, -1.0, 0.0, 0.0,
                          0.0,  0.0, 0.0, 1.0
                      };

    glPushMatrix();     // Save current matrix
    glMultMatrixf(Rot); // Rotate 90 degrees about the z axis

    glTranslatef(-iSizeX*TILE_WIDTH/2, -iSizeY*TILE_WIDTH/2, 0); // Center it

    glGetFloatv(GL_MODELVIEW_MATRIX, &Mat[0]);

//    glEnable(GL_TEXTURE_2D);
    glColor4f(1.0f,1.0f,1.0f,1.0f);

    glFrontFace(GL_CCW);
    glDisable(GL_BLEND);

    // TODO: Eliminate multiple CalculateFrustum() calls per frame
    pFrustum->CalculateFrustum();

    for (int i = 0; i < iSizeY; i++)
        for (int j = 0; j < iSizeX; j++) {
            int tilesup;
            int tileside;
            int tileotherside;


            if (pFrustum->CubeInFrustum(j*TILE_WIDTH, i*TILE_WIDTH, cubes[i*iSizeX+j].y1,TILE_WIDTH*2)) {

                tilesup = cubes[i*iSizeX+j].tilesup;
                tileside = cubes[i*iSizeX+j].tileside;
                tileotherside = cubes[i*iSizeX+j].tileotherside;

                if (tileotherside != -1) {

                    //vTriangle[0] = MatrixMultVect3f(Mat, j*L,     (i+1)*L, cubes[i*sizeX+j].y3);
                    //vTriangle[1] = MatrixMultVect3f(Mat, (j+1)*L, (i+1)*L, cubes[(i+1)*sizeX+j].y1);
                    //vTriangle[2] = MatrixMultVect3f(Mat, (j+1)*L, (i+1)*L, cubes[i*sizeX+j].y4);

                    //vNormal = Normal(vTriangle);

                    glBindTexture(GL_TEXTURE_2D, textures[tiles[tileotherside].text]);

                    glBegin(GL_QUADS);
                    //glNormal3f(vNormal.x,vNormal.y,vNormal.z);

                    glTexCoord2f(tiles[tileotherside].u1, tiles[tileotherside].v1);
                    glVertex3f(j*TILE_WIDTH, (i+1)*TILE_WIDTH, cubes[i*iSizeX+j].y3);
                    glTexCoord2f(tiles[tileotherside].u2, tiles[tileotherside].v2);
                    glVertex3f((j+1)*TILE_WIDTH, (i+1)*TILE_WIDTH, cubes[i*iSizeX+j].y4);
                    glTexCoord2f(tiles[tileotherside].u4, tiles[tileotherside].v4);
                    glVertex3f((j+1)*TILE_WIDTH, (i+1)*TILE_WIDTH, cubes[(i+1)*iSizeX+j].y2);
                    glTexCoord2f(tiles[tileotherside].u3, tiles[tileotherside].v3);
                    glVertex3f(j*TILE_WIDTH, (i+1)*TILE_WIDTH, cubes[(i+1)*iSizeX+j].y1);
                    glEnd();
                }

                if (tileside != -1) {

                    //vTriangle[0] = MatrixMultVect3f(Mat, (j+1)*TILE_WIDTH, i*TILE_WIDTH,     cubes[i*sizeX+j].y4);
                    //vTriangle[1] = MatrixMultVect3f(Mat, (j+1)*TILE_WIDTH, i*TILE_WIDTH,     cubes[(i+1)*sizeX+j].y3);
                    //vTriangle[2] = MatrixMultVect3f(Mat, (j+1)*TILE_WIDTH, (i+1)*TILE_WIDTH, cubes[i*sizeX+j].y2);

                    //vNormal = Normal(vTriangle);

                    /*
                    glDisable(GL_TEXTURE_2D);
                    glBegin(GL_LINES);
                    	glColor3f(1.0,1.0,0.0);
                    		glVertex3f(vTriangle[0].x,vTriangle[0].y,vTriangle[0].z );
                    	glColor3f(1.0,0.0,0.0);
                    	glVertex3f(vNormal.x,vNormal.y,vNormal.z);
                    	glColor3f(1.0,1.0,1.0);
                    glEnd();
                    glEnable(GL_TEXTURE_2D);
                    */

                    glBindTexture(GL_TEXTURE_2D, textures[tiles[tileside].text]);

                    glBegin(GL_QUADS);
                    //glNormal3f(vNormal.x,vNormal.y,vNormal.z);

                    glTexCoord2f(tiles[tileside].u1, tiles[tileside].v1);
                    glVertex3f((j+1)*TILE_WIDTH, (i+1)*TILE_WIDTH, cubes[i*iSizeX+j].y4);
                    glTexCoord2f(tiles[tileside].u2, tiles[tileside].v2);
                    glVertex3f((j+1)*TILE_WIDTH, i*TILE_WIDTH, cubes[i*iSizeX+j].y2);
                    glTexCoord2f(tiles[tileside].u4, tiles[tileside].v4);
                    glVertex3f((j+1)*TILE_WIDTH, i*TILE_WIDTH, cubes[i*iSizeX+j+1].y1);
                    glTexCoord2f(tiles[tileside].u3, tiles[tileside].v3);
                    glVertex3f((j+1)*TILE_WIDTH, (i+1)*TILE_WIDTH, cubes[i*iSizeX+j+1].y3);
                    glEnd();
                }

                if (tilesup != -1) {


                    /*
                    vTriangle[0] = CVector3(j*TILE_WIDTH,     i*TILE_WIDTH,     cubes[i*sizeX+j].y1);
                    vTriangle[1] = CVector3((j+1)*TILE_WIDTH, i*TILE_WIDTH,     cubes[i*sizeX+j].y2);
                    vTriangle[2] = CVector3(j*TILE_WIDTH,     (i+1)*TILE_WIDTH, cubes[(i+1)*sizeX+j].y3);

                    vTriangle[0] = vTriangle[0] * Mat;
                    vTriangle[1] = vTriangle[1] * Mat;
                    vTriangle[2] = vTriangle[2] * Mat;

                    //vTriangle[0] = MatrixMultVect3f(Mat, j*TILE_WIDTH,     i*TILE_WIDTH,     cubes[i*sizeX+j].y1);
                    //vTriangle[2] = MatrixMultVect3f(Mat, (j+1)*TILE_WIDTH, i*TILE_WIDTH,     cubes[i*sizeX+j].y2);
                    //vTriangle[1] = MatrixMultVect3f(Mat, j*TILE_WIDTH,     (i+1)*TILE_WIDTH, cubes[(i+1)*sizeX+j].y3);

                    vNormal = Normal(vTriangle);
                    */
                    //glDisable(GL_LIGHTING);
                    glBindTexture(GL_TEXTURE_2D, textures[tiles[tilesup].text]);
                    glBegin(GL_QUADS);
//			if ((i+j)%2)
//			glColor3f(0.7, 0.7, 0.7);
                    //unsigned char r,g,b;

                    //r = gat.gatdata[(gat.sizeY - i) + (gat.sizeX - j) * gat.sizeX].layer[3].R;
                    //g = gat.gatdata[(gat.sizeY - i) + (gat.sizeX - j) * gat.sizeX].layer[3].G;
                    //b = gat.gatdata[(gat.sizeY - i) + (gat.sizeX - j) * gat.sizeX].layer[3].B;

                    //glColor3f(float(r)/255.0f,float(g)/255.0f,float(b)/255.0f);
                    //glColor3f(1.0f,1.0f,float(b)/255.0f);
                    //glColor3f(1.0f,1.0f,1.0f);

                    //glNormal3f(vNormal.x,vNormal.y,vNormal.z);
                    glTexCoord2f(tiles[tilesup].u1, tiles[tilesup].v1);
                    glVertex3f(j*TILE_WIDTH, i*TILE_WIDTH, cubes[i*iSizeX+j].y1);
                    glTexCoord2f(tiles[tilesup].u2, tiles[tilesup].v2);
                    glVertex3f((j+1)*TILE_WIDTH, i*TILE_WIDTH, cubes[i*iSizeX+j].y2);
                    glTexCoord2f(tiles[tilesup].u4, tiles[tilesup].v4);
                    glVertex3f((j+1)*TILE_WIDTH, (i+1)*TILE_WIDTH, cubes[i*iSizeX+j].y4);
                    glTexCoord2f(tiles[tilesup].u3, tiles[tilesup].v3);
                    glVertex3f(j*TILE_WIDTH, (i+1)*TILE_WIDTH, cubes[i*iSizeX+j].y3);

                    glColor3f(1.0f,1.0f,1.0f);

//			if ((i+j)%2)
//			glColor3f(1.0, 1.0, 1.0);

                    glEnd();
                    //glEnable(GL_LIGHTING);

                }

            }  //if g_frustum...

        }

    glPopMatrix();

}
