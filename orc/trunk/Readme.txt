### Howto setup Code::Blocks ###

1.) Download Code::Blocks IDE, with MINGW compiler from http://www.codeblocks.org/downloads.shtml
2.) Install Code::Blocks into C:\CodeBlocks

3.) Start Code::Blocks, open the DevPack Plugin, set the directory for installation to C:\CodeBlocks
     Download and install the following devpacks in that order:

		zlib
		libjpeg
		libpng
		SDL, SDL_Sound, SDL_Mixer, SDL_Image (without TIFF support?)

		libgrf (Get it from http://openkore.sourceforge.net/grftool/)
		
		TODO: ## WE SHOULD BUILD A DEVPACK for LIBGRF ##
		
		Extract libgrf to C:\CodeBlocks\include\libgrf
		
		Copy C:\CodeBlocks\include\libgrf\headers\*.*  to  C:\CodeBlocks\include\libgrf\
		Copy C:\CodeBlocks\include\libgrf\dll\grf.dll  to  C:\CodeBlocks\dll
		Copy C:\CodeBlocks\include\libgrf\dll\grf.def, grf.exp, grf.lib  to  C:\CodeBlocks\lib

4.) Close Code::Blocks

### Howto compile ORC on Windows using Code::Blocks ###

### 4.) How to Checkout from SVN with CodeBlocks... (not possible yet, yawn!)

[code]
mkdir C:\Projects\Orc
cd C:\Projects\Orc
svn checkout https://svn.sourceforge.net/svnroot/openkore/orc/trunk
[/code]

5.) Open "Orc.cbp" with Code::Blocks
6.) Press CTRL+F9 and it should compile
