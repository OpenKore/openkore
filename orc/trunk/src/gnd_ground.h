#ifndef GND_H
#define GND_H

#include "3d_math.h"
#include "3d_frustum.h"

#include "ro_types.h"

typedef unsigned char ro_lightmap_t[256];

typedef struct {
    unsigned char a;
    unsigned char R;
    unsigned char G;
    unsigned char B;
}
ro_gat_rgba_t;

typedef struct {
    ro_gat_rgba_t layer[5];
}
ro_gat_t;

typedef struct {
    char header[4];
    unsigned short iUnknown;
    int sizeX;
    int sizeY;
    ro_gat_t *gatdata;
}
ro_gatfile_t;

typedef struct {
    float u1;
    float u2;
    float u3;
    float u4;
    float v1;
    float v2;
    float v3;
    float v4;

    unsigned short text;
    unsigned short lmap;

    int todo;
}
ro_tile_t;

typedef struct {
    float y1;
    float y2;
    float y3;
    float y4;
    int tilesup;
    int tileotherside;
    int tileside;
}
ro_cube_t;

/*
typedef struct {
	char filecode[4];
	short magicnumber;
    int sizeX;
    int sizeY;
    char unk1[4];
    int ntextures;
    char unk2[4];
} gnd_header_t;
*/



class GND {
public:
    GND(char* szGrfPath, int waterlevel);
    virtual ~GND();

    bool LoadFromMemory(void* pData, uint32_t nSize);
    bool LoadGAT(void* pData, uint32_t nSize);

    void LoadWater(int type);
    void Display(CFrustum* pFrustum);
    void DisplayGat(CFrustum* pFrustum);
    void DisplayWater(int frameno, float wavephase, float waterlevel, CFrustum* pFrustum);

private:
    unsigned long dwFileID;
    char bMajorVersion, bMinorVersion;
    long iSizeX;
    long iSizeY;
    float fUnknown1; // TODO: identify
    long iNumTextures;
    long iUnknown2; // TODO: identify

    ro_string_t *textures_name;
    ro_gatfile_t gat;
    GLuint *watertex;
    GLuint *textures;
    ro_cube_t *cubes;
    ro_tile_t *tiles;
    int ntiles;
    ro_lightmap_t *lightmaps;
    int nlightmaps;
};

#endif // GND_H
