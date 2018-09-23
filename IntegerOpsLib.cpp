#include "IntegerOpsLib.h"

/**
#################################################################
## CLIOBcd - Large BCD Number
#################################################################
**/

int64_t *CLIOBcd::MakeData(const char *strNum)
{
    int64_t *pBCD = 0;
    size_t ilen = strlen(strNum);
    int64_t iCount = 0;
    int64_t iSign = 0;
    bool bSignFound = false;
    bool bZeroFound = false;
    bool bHex = false;
    int iFirst = -1;

    // Count digits, check for sign and check number syntax. 
    for (int i = 0; i < ilen; ++i) {
        char c = strNum[i];
        switch (c) {
        case ' ':
            break;
        case '-':
            if (bSignFound || bZeroFound || bHex || iCount > 0) throw ELIOBadNumberFormat();
            bSignFound = true;
            iSign = 1;
            break;
        case '+':
            if (bSignFound || bZeroFound || bHex || iCount > 0) throw ELIOBadNumberFormat();
            bSignFound = true;
            break;
        case '0':
            iCount += (iCount > 0);
            bZeroFound = true;
            break;
        case '1': case '2': case '3': case '4': case '5':
        case '6': case '7': case '8': case '9':
            if (iFirst < 0) {
                iFirst = i;
            }
            ++iCount;
            break;
        case 'A': case 'B': case 'C': case 'D': case 'E': case 'F':
        case 'a': case 'b': case 'c': case 'd': case 'e': case 'f':
            if (!bHex) throw ELIOBadNumberFormat();
            if (iFirst < 0) {
                iFirst = i;
            }
            ++iCount;
            break;
        case 'X': case 'x':
            if (iCount > 0 || !bZeroFound || bHex) throw ELIOBadNumberFormat();
            bHex = true;
            bZeroFound = false;
            break;
        default:
            throw ELIOBadNumberFormat();
            break;
        }
    }

    if (iCount == 0 && (!bZeroFound || iSign==1) ) ELIOBadNumberFormat();

    // Create BCD number
    pBCD = LIOMakeBCD(iCount);

    if (!pBCD) throw ELIOMemoryError();

    // Copy Sign and character length to BCD number
    pBCD[2] = iCount;
    pBCD[3] = iSign;
    pBCD[4] = bHex ? 16 : 10;

    unsigned char *pData = reinterpret_cast<unsigned char *>(&pBCD[5]) + iCount;
    // Convert from wchar_t to BCD and copy to BCD number. Node data is reversed in order
    //    to enfoce little endian convention
    for (int i = iFirst; i < ilen; ++i) {
        char c = strNum[i];

        if (c >= '0' && c <= '9') {
            *(--pData) = (unsigned char)(c - '0');
        } else if (c >= 'a' && c <= 'f') {
            *(--pData) = (unsigned char)(c - 'a' + 10);
        } else if (c >= 'A' && c <= 'F') {
            *(--pData) = (unsigned char)(c - 'A' + 10);
        }

    }
    return pBCD;
}

/**
*****************************************************************
**
*****************************************************************
**/

int64_t *CLIOBcd::MakeData(const wchar_t *strNum)
{
    int64_t *pBCD = 0;
    size_t ilen = wcslen(strNum);
    int64_t iCount = 0;
    int64_t iSign = 0;
    bool bSignFound = false;
    bool bZeroFound = false;
    bool bHex = false;
    int iFirst = -1;

    // Count digits, check for sign and check number syntax. 
    for (int i = 0; i < ilen; ++i) {
        wchar_t c = strNum[i];
        switch (c) {
        case L' ':
            break;
        case L'-':
            if (bSignFound || bZeroFound || bHex || iCount > 0) throw ELIOBadNumberFormat();
            bSignFound = true;
            iSign = 1;
            break;
        case L'+':
            if (bSignFound || bZeroFound || bHex || iCount > 0) throw ELIOBadNumberFormat();
            bSignFound = true;
            break;
        case L'0':
            iCount += (iCount > 0);
            bZeroFound = true;
            break;
        case L'1': case L'2': case L'3': case L'4': case L'5':
        case L'6': case L'7': case L'8': case L'9':
            if (iFirst < 0) {
                iFirst = i;
            }
            ++iCount;
            break;
        case L'A': case L'B': case L'C': case L'D': case L'E': case L'F':
        case L'a': case L'b': case L'c': case L'd': case L'e': case L'f':
            if (!bHex) throw ELIOBadNumberFormat();
            if (iFirst < 0) {
                iFirst = i;
            }
            ++iCount;
            break;
        case L'X': case L'x':
            if (iCount > 0 || !bZeroFound || bHex) throw ELIOBadNumberFormat();
            bHex = true;
            bZeroFound = false;
            break;
        default:
            throw ELIOBadNumberFormat();
            break;
        }
    }

    if (iCount == 0 && (!bZeroFound || iSign==1) ) ELIOBadNumberFormat();

    // Create BCD number
    pBCD = LIOMakeBCD(iCount);

    if (!pBCD) throw ELIOMemoryError();

    // Copy Sign and character length to BCD number
    pBCD[2] = iCount;
    pBCD[3] = iSign;
    pBCD[4] = bHex ? 16 : 10;

    unsigned char *pData = reinterpret_cast<unsigned char *>(&pBCD[5]) + iCount;
    // Convert from wchar_t to BCD and copy to BCD number. Node data is reversed in order
    //    to enfoce little endian convention
    for (int i = iFirst; i < ilen; ++i) {
        wchar_t c = strNum[i];

        if (c >= L'0' && c <= L'9') {
            *(--pData) = (unsigned char)(c - L'0');
        } else if (c >= L'a' && c <= L'f') {
            *(--pData) = (unsigned char)(c - L'a' + 10) ;
        } else if (c >= L'A' && c <= L'F') {
            *(--pData) = (unsigned char)(c - L'A' + 10);
        }

    }
    return pBCD;
}

/**
*****************************************************************
**
*****************************************************************
**/

CLIOBcd::CLIOBcd(const CLIOInt &clInt, int iBase)
{
    if (clInt.m_pNum) {
        this->m_pBCD = LIOConvertIntToBCD(clInt.m_pNum, iBase);
        this->m_pBCD[0] = 1;
    } else {
        this->m_pBCD = 0;
    }
}
    
/**
*****************************************************************
**
*****************************************************************
**/

CLIOBcd::~CLIOBcd()
{
    if ( m_pBCD && --m_pBCD[0] == 0) {
        LIODestroyBCD(m_pBCD);
    }
}


/**
*****************************************************************
**
*****************************************************************
**/

__declspec(dllexport) std::ostream & operator<<(std::ostream &os, const CLIOBcd& clP1)
{
    if (clP1.m_pBCD) {
        if (clP1.m_pBCD[2] != 0) {
            if (clP1.m_pBCD[3] != 0) {
                os << (unsigned char) '-';
            }
            unsigned char *ptr = ((unsigned char *)&clP1.m_pBCD[5]) + clP1.m_pBCD[2] - 1;
            for (int i = 0; i < clP1.m_pBCD[2]; ++i) {
                os << (unsigned char)(*ptr + '0');
                --ptr;
            }
        } else {
            os << "0";
        }
    } else {
        os << "#NaN";
    }
    return os;
}

/**
*****************************************************************
**
*****************************************************************
**/

__declspec(dllexport) std::ostream & operator<<(std::ostream &os, const CLIOInt& clInt)
{
    if (clInt.m_pNum) {
        if (clInt.m_pNum[2] != 0) {
            int64_t iBase = os.flags() & std::ostream::hex ? 16 : 10;
            int64_t *pBCD = LIOConvertIntToBCD(clInt.m_pNum, iBase);
            if (pBCD[3] != 0) {
                os << '-';
            }
            if (os.flags() & std::ostream::showbase && os.flags() & std::ostream::hex) {
                os << "0x";
            }
            if (pBCD[2] > 0) {
                unsigned char *ptr = ((unsigned char *)&pBCD[5]) + pBCD[2] - 1;
                for (int i = 0; i < pBCD[2]; ++i) {
                    os << (unsigned char)(*ptr + (*ptr < '\x0a' ? '0' : ('A' - '\x0a')));
                    --ptr;
                }
            }
            LIODestroyBCD(pBCD);
        } else {
            if (os.flags() & std::ostream::showbase && os.flags() & std::ostream::hex) {
                os << "0x0";
            } else {
                os << "0";
            }
        }
    } else {
        os << "#NaN";
    }
    return os;
}
