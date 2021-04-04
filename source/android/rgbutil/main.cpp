/*
 * copyright
 */

#include <fstream>
#include <iostream>
#include <cutils/properties.h>

#include <cv.h>

#include <YUVTransform.h>
#include <TransformByCv.h>

int main(int argc, char** argv)
{
    int debug = property_get_int32("trans.debug", 0);

    if (argc < 5) {
        std::cerr << "parameter err, debug: " << debug << std::endl;
        return -1;
    }

    int srcw = 0;
    int srch = 0;
    int scalew = 0;
    int scaleh = 0;

    sscanf(argv[1], "%d", &srcw);
    sscanf(argv[2], "%d", &srch);
    sscanf(argv[3], "%d", &scalew);
    sscanf(argv[4], "%d", &scaleh);

    if (debug) {
        std::cout << "transform NV21 to RGB/BGR start.." << std::endl;
        std::cout << "srcw: " << srcw << std::endl;
        std::cout << "srch: " << srch << std::endl;
        std::cout << "scalew: " << scalew << std::endl;
        std::cout << "scaleh: " << scalew << std::endl;
        std::cout << "input: " << argv[5] << std::endl;
    }

    std::string fileName;
    std::ifstream fileList(argv[5]);

    size_t nv21Size = srcw * srch * 1.5;

    unsigned char* pNV21 = new unsigned char[nv21Size];
    unsigned char* pBGR = new unsigned char[srcw * srch * 3];
    unsigned char* pScaleBGR = new unsigned char[scalew * scaleh * 3];

    char* tpNV21 = reinterpret_cast<char *>(pNV21);
    char* tpScaleBGR = reinterpret_cast<char *>(pScaleBGR);

    while (std::getline(fileList, fileName)) {
        std::ifstream in(fileName, std::ifstream::binary);
        if (!in.is_open() || !in.good()) {
            std::cerr << "Failed to open input file: " << fileName << std::endl;
            goto streamerr;
        }

        if (!in.read(tpNV21, nv21Size)) {
            std::cerr << "Failed to read the contents" << fileName << std::endl;
            goto streamerr;
        }

        NV21ToBGR(pNV21, pBGR, srcw, srch);
        rgbResizeByCv(pBGR, pScaleBGR, srcw, srch, scalew, scaleh,
                      srcw * 3, scalew * 3, IPL_DEPTH_8U, 3);


        int writenum;
        FILE* scvtwriteFile;

        char cfileOut[64];
        sprintf(cfileOut, "cvt_%s_%d_%d.raw", fileName.c_str(), scalew, scaleh);

        scvtwriteFile = fopen(cfileOut, "wb");
        if (scvtwriteFile == nullptr) {
            std::cout << "write file error!" << std::endl;
        }
        writenum = fwrite(pScaleBGR, 1, scalew * scaleh * 3, scvtwriteFile);
        if (writenum != scalew * scaleh * 3) {
            std::cout << "write file error!" << std::endl;
        }
        fclose(scvtwriteFile);

        /*std::string fileOut = "cvt_" + fileName;
        std::ofstream os(fileOut, std::ofstream::binary);
        if (!os) {
            std::cerr << "Failed to open output file: " << fileOut << std::endl;
            goto streamerr;
        }

        if (!os.write(tpScaleBGR, scalew * scaleh * 3)) {
            std::cerr << "Failed to write data to: " << fileOut << std::endl;
            goto streamerr;
        }*/
    }

streamerr:
    delete[] pScaleBGR;
    delete[] pBGR;
    delete[] pNV21;

    tpNV21 = nullptr;
    tpScaleBGR = nullptr;

    if (debug) std::cout << "transform NV21 to RGB/BGR end." << std::endl;

    return 0;
}
