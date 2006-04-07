#ifndef GRFCACHE_H
#define GRFCACHE_H

#include <windows.h>
#include <libgrf/grf.h>

#include <string>
#include <hash_map>

class GrfCache
{
private:
	struct FileMappingInfo
	{
		HANDLE hFile;
		HANDLE hFileMapping;
	};
	typedef stdext::hash_map< std::string, Grf* > GrfEnsemble;
	typedef stdext::hash_map< std::string, FileMappingInfo > MappingsEnsemble;
public:
	GrfCache() {}
	~GrfCache() throw()
	{
		empty_all();
	}

	Grf *get(const std::string& name) throw(int, GrfError)
	{
		Grf *pGrf;
		GrfError errorcode;
		if ( m.find(name) != m.end() )
		{
			return m[name];
		}
		try
		{
			pGrf = grf_open(name.c_str(), "rb", &errorcode);
		}
		catch(...)
		{
			throw 0;
		}
		if ( pGrf == 0 )
		{
			throw errorcode;
		}
		m[name] = pGrf;
		return pGrf;
	}

	HANDLE getFileMapping(const std::string& name)
	{
		FileMappingInfo mappingInfo;
		if ( m_FileMappings.find(name) != m_FileMappings.end() )
		{
			return m_FileMappings[name].hFileMapping;
		}
		mappingInfo.hFile = ::CreateFile(name.c_str(), GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
		if ( mappingInfo.hFile == INVALID_HANDLE_VALUE )
		{
			return 0;
		}
		DWORD dwFileSize = ::GetFileSize(mappingInfo.hFile, NULL);
		if ( dwFileSize == 0 )
		{
			::CloseHandle(mappingInfo.hFile);
			return 0;
		}
		// NULL ACL token
		mappingInfo.hFileMapping = ::CreateFileMapping(mappingInfo.hFile, NULL, PAGE_READONLY, 0, dwFileSize, NULL /*name*/);
		if ( !mappingInfo.hFileMapping )
		{
			::CloseHandle(mappingInfo.hFile);
			return 0;
		}
		m_FileMappings[name] = mappingInfo;
		return mappingInfo.hFileMapping;
	}

	HANDLE getFileFromMapping(HANDLE hMapping)
	{
		for ( MappingsEnsemble::iterator it = m_FileMappings.begin(); it != m_FileMappings.end(); ++it )
		{
			FileMappingInfo &mappingInfo = it->second;
			if ( mappingInfo.hFileMapping == hMapping )
			{
				return (mappingInfo.hFile);
			}
		}
	}

	void empty_all()
	{
		for ( GrfEnsemble::iterator it = m.begin(); it != m.end(); ++it )
		{
			try
			{
				grf_free(it->second);
			}
			catch(...)
			{}
		}
		m.clear();
		for ( MappingsEnsemble::iterator it = m_FileMappings.begin(); it != m_FileMappings.end(); ++it )
		{
			FileMappingInfo &mappingInfo = it->second;
			::CloseHandle(mappingInfo.hFileMapping);
			::CloseHandle(mappingInfo.hFile);
		}
		m_FileMappings.clear();
	}


private:
	GrfEnsemble m;
	MappingsEnsemble m_FileMappings;
private:
	GrfCache(const GrfCache&) {}
	GrfCache& operator=(const GrfCache&) {}
};

#endif
