#ifndef _FILEREADER_H_
#define _FILEREADER_H_

/**
 * Abstract interface for reading files. See UnixFileReader and WinFileReader.
 */
class FileReader {
public:
	virtual ~FileReader ();

	/**
	 * Return the file size.
	 *
	 * @return The file size in bytes.
	 */
	virtual unsigned int getSize () = 0;

	/**
	 * Read a 32-bit unsigned integer at the specified offset in the file.
	 *
	 * @param offset The offset to read from.
	 * @return An integer read from the file.
	 */
	virtual unsigned int readInt (unsigned int offset) = 0;

	/**
	 * Read a string at the specified offset in the file.
	 *
	 * @param offset The offset to read from.
	 * @return A string read from the file. This string may or may not
	 *         be NULL-terminated, depending on the content of the file.
	 */
	virtual const char  *readStr (unsigned int offset) = 0;
};

#endif /* _FILEREADER_H_ */
