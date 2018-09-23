#pragma once

#include <stdint.h>
#include <iostream>

class CLIOBcd;
class CLIOInt;

extern "C" {

	int64_t *LIOMakeBCD(int64_t iSize);
	int64_t *LIOMakeInt(int64_t iSize);

	int64_t LIODestroyBCD(int64_t *);	
	int64_t LIODestroyInt(int64_t *);

	int64_t *LIOCopyBCD(const int64_t *);
	int64_t *LIOCopyInt(const int64_t *);

	int64_t *LIOAdd(const int64_t *, const int64_t *);
	int64_t *LIOSub(const int64_t *, const int64_t *);
	int64_t *LIOMul(const int64_t *, const int64_t *);
	int64_t *LIODiv(const int64_t *, const int64_t *);
	int64_t *LIOMod(const int64_t *, const int64_t *);
	int64_t *LIONeg(const int64_t *);

	int64_t *LIOConvertDecToInt(const int64_t *);
	int64_t *LIOConvertIntToDec(const int64_t *);

	int64_t *LIOConvertHexToInt(const int64_t *);
	int64_t *LIOConvertIntToHex(const int64_t *);

	int64_t *LIOConvertBCDToInt(const int64_t *);
	int64_t *LIOConvertIntToBCD(const int64_t *, const int64_t);

	int64_t *LIOMakeUnsignedInt(const uint64_t);
	int64_t *LIOMakeSignedInt(const int64_t);

}

class ELIOBadNumberFormat {};
class ELIOMemoryError {};

/**
#################################################################
## CLIOBcd - Large Integer
#################################################################
**/

//__declspec(dllexport)

class __declspec(dllexport) CLIOBcd
{

public:

	CLIOBcd() { m_pBCD = 0; }

	CLIOBcd(const char *strNum)
	{
		m_pBCD = MakeData(strNum);
		m_pBCD[0] = 1;
	}

	CLIOBcd(const wchar_t *strNum)
	{
		m_pBCD = MakeData(strNum);
		m_pBCD[0] = 1;
	}

	CLIOBcd(const CLIOBcd &clP1) 
	{
		if ((this->m_pBCD = clP1.m_pBCD)) ++*this->m_pBCD;
	}

	
	CLIOBcd(const CLIOInt &clInt, int iBase=10);


	CLIOBcd operator=(const CLIOBcd &clP1)
	{
		// Save current BCD so we can check for zero references.
		//   We do things in this order inc case this->m_pBCD == clP1.m_pBCD
		int64_t *pTemp = this->m_pBCD;
		if ((this->m_pBCD = clP1.m_pBCD)) ++this->m_pBCD[0];
		if (pTemp && --pTemp[0] == 0) LIODestroyBCD(pTemp);
		return *this;
	}



	~CLIOBcd();

	friend class CLIOInt;
	friend __declspec(dllexport) std::ostream & operator<<(std::ostream &os, const CLIOBcd& clP1);

private:

	static int64_t *MakeData(const char *strNum);
	static int64_t *MakeData(const wchar_t *strNum);

private:


	int64_t *m_pBCD;


};

/**
#################################################################
## CLIOInt - Large Integer
#################################################################
**/

class __declspec(dllexport) CLIOInt
{

public:

	CLIOInt() { this->m_pNum = 0; }

	CLIOInt(const CLIOBcd &clBCD)
	{
		if (clBCD.m_pBCD) {
			// this->m_pNum = LIOConvertBCDToInt(clBCD.m_pBCD);
			this->m_pNum = LIOConvertDecToInt(clBCD.m_pBCD);
			this->m_pNum[0] = 1;
		} else {
			this->m_pNum = 0;
		}
	}

	CLIOInt(const CLIOInt &clP1) 
	{
		if ((this->m_pNum = clP1.m_pNum)) ++*this->m_pNum;
	}

	CLIOInt(const char *strNum)
	{
		int64_t *pTemp = CLIOBcd::MakeData(strNum);
		this->m_pNum = LIOConvertBCDToInt(pTemp);
		this->m_pNum[0] = 1;
		LIODestroyBCD(pTemp);
	}

	CLIOInt(const wchar_t *strNum)
	{
		int64_t *pTemp = CLIOBcd::MakeData(strNum);
		this->m_pNum = LIOConvertBCDToInt(pTemp);
		this->m_pNum[0] = 1;
		LIODestroyBCD(pTemp);
	}

	CLIOInt(const uint64_t iNum)
	{
		this->m_pNum = LIOMakeUnsignedInt(iNum);
		this->m_pNum[0] = 1;
	}

	CLIOInt(const int64_t iNum)
	{
		this->m_pNum = LIOMakeSignedInt(iNum);
		this->m_pNum[0] = 1;
	}

	CLIOInt(const unsigned long iNum)
	{
		this->m_pNum = LIOMakeUnsignedInt((uint64_t) iNum);
		this->m_pNum[0] = 1;
	}

	CLIOInt(const long iNum)
	{
		this->m_pNum = LIOMakeSignedInt((int64_t) iNum);
		this->m_pNum[0] = 1;
	}

	CLIOInt(const unsigned int iNum)
	{
		this->m_pNum = LIOMakeUnsignedInt((uint64_t) iNum);
		this->m_pNum[0] = 1;
	}

	CLIOInt(const int iNum)
	{
		this->m_pNum = LIOMakeSignedInt((int64_t) iNum);
		this->m_pNum[0] = 1;
	}

	CLIOInt::~CLIOInt()
		{
		if ( m_pNum && --m_pNum[0] == 0) {
			LIODestroyInt(m_pNum);
		}
	}

	CLIOInt &operator=(const CLIOInt &clP1)
	{
		// Save current number so we can check for zero references.
		//   We do things in this order inc case this->m_pNum == clP1.m_pNum
		int64_t *pTemp = this->m_pNum;
		if ((this->m_pNum = clP1.m_pNum)) ++this->m_pNum[0];
		if (pTemp && --pTemp[0] == 0) LIODestroyInt(pTemp);
		return *this;
	}

	CLIOInt &operator=(const CLIOBcd &clP1)
	{
		int64_t *pTemp = this->m_pNum;
		if (clP1.m_pBCD) {
			this->m_pNum = LIOConvertBCDToInt(clP1.m_pBCD);
			this->m_pNum[0] = 1;
		} else {
			this->m_pNum = 0;
		}
		if (pTemp && --pTemp[0] == 0) LIODestroyInt(pTemp);
		return *this;
	}

	CLIOInt &operator=(const char *strNum)
	{
		int64_t *pTemp = this->m_pNum;
		int64_t *pData = CLIOBcd::MakeData(strNum);
		this->m_pNum = LIOConvertBCDToInt(pData);
		this->m_pNum[0] = 1;
		LIODestroyBCD(pData);
		if (pTemp && --pTemp[0] == 0) LIODestroyInt(pTemp);
		return *this;
	}

	CLIOInt &operator=(const wchar_t *strNum)
	{
		int64_t *pTemp = this->m_pNum;
		int64_t *pData = CLIOBcd::MakeData(strNum);
		this->m_pNum = LIOConvertBCDToInt(pData);
		this->m_pNum[0] = 1;
		LIODestroyBCD(pData);
		if (pTemp && --pTemp[0] == 0) LIODestroyInt(pTemp);
		return *this;
	}

	CLIOInt &operator=(const uint64_t iNum)
	{
		int64_t *pTemp = this->m_pNum;
		this->m_pNum = LIOMakeUnsignedInt(iNum);
		this->m_pNum[0] = 1;
		if (pTemp && --pTemp[0] == 0) LIODestroyInt(pTemp);
		return *this;
	}

	CLIOInt &operator=(const int64_t iNum)
	{
		int64_t *pTemp = this->m_pNum;
		this->m_pNum = LIOMakeSignedInt(iNum);
		this->m_pNum[0] = 1;
		if (pTemp && --pTemp[0] == 0) LIODestroyInt(pTemp);
		return *this;
	}

	CLIOInt &operator=(const unsigned long iNum)
	{
		int64_t *pTemp = this->m_pNum;
		this->m_pNum = LIOMakeUnsignedInt((uint64_t) iNum);
		this->m_pNum[0] = 1;
		if (pTemp && --pTemp[0] == 0) LIODestroyInt(pTemp);
		return *this;
	}

	CLIOInt &operator=(const long iNum)
	{
		int64_t *pTemp = this->m_pNum;
		this->m_pNum = LIOMakeSignedInt((int64_t) iNum);
		this->m_pNum[0] = 1;
		if (pTemp && --pTemp[0] == 0) LIODestroyInt(pTemp);
		return *this;
	}

	CLIOInt &operator=(const unsigned int iNum)
	{
		int64_t *pTemp = this->m_pNum;
		this->m_pNum = LIOMakeUnsignedInt((uint64_t) iNum);
		this->m_pNum[0] = 1;
		if (pTemp && --pTemp[0] == 0) LIODestroyInt(pTemp);
		return *this;
	}

	CLIOInt &operator=(const int iNum)
	{
		int64_t *pTemp = this->m_pNum;
		this->m_pNum = LIOMakeSignedInt((int64_t) iNum);
		this->m_pNum[0] = 1;
		if (pTemp && --pTemp[0] == 0) LIODestroyInt(pTemp);
		return *this;
	}

	CLIOInt operator+(const CLIOInt &clP1) 
	{
		if (this->m_pNum == 0 || clP1.m_pNum == 0)
			return CLIOInt();
		else
			return CLIOInt(LIOAdd(this->m_pNum, clP1.m_pNum));
	}

	CLIOInt operator-(const CLIOInt &clP1) 
	{
		if (this->m_pNum == 0 || clP1.m_pNum == 0)
			return CLIOInt();
		else
			return CLIOInt(LIOSub(this->m_pNum, clP1.m_pNum));
	}

	CLIOInt operator*(const CLIOInt &clP1) 
	{
		if (this->m_pNum == 0 || clP1.m_pNum == 0)
			return CLIOInt();
		else
			return CLIOInt(LIOMul(this->m_pNum, clP1.m_pNum));
	}

	CLIOInt operator/(const CLIOInt &clP1) 
	{
		if (this->m_pNum == 0 || clP1.m_pNum == 0)
			return CLIOInt();
		else
			return CLIOInt(LIODiv(this->m_pNum, clP1.m_pNum));
	}

	CLIOInt operator%(const CLIOInt &clP1) 
	{
		if (this->m_pNum == 0 || clP1.m_pNum == 0)
			return CLIOInt();
		else
			return CLIOInt(LIOMod(this->m_pNum, clP1.m_pNum));
	}

	CLIOInt operator-() 
	{
		if (this->m_pNum == 0)
			return CLIOInt();
		else
			return CLIOInt(LIONeg(this->m_pNum));
	}

	friend class CLIOBcd;
	friend __declspec(dllexport) std::ostream & operator<<(std::ostream &os, const CLIOInt& clP1);

private: 

	
	CLIOInt(int64_t *pNum)
	{
		this->m_pNum = pNum;
		if ((this->m_pNum = pNum))++this->m_pNum[0];
	}


public:


	int64_t *m_pNum;


};

