import os

### Platform configuration ###

platform = str(ARGUMENTS.get('OS', Platform()))
cygwin = platform == "cygwin"
win32 = cygwin or platform == "windows"
have_ncurses = False

perlconfig = {}
env = Environment()

def CheckPerl(context):
	global cygwin
	global win32
	global perlconfig

	context.Message('Checking Perl configuration ...')
	source = '''
	use strict;
	use Config;
	use File::Spec;

	sub search {
		my $paths = shift;
		my $file = shift;
		foreach (@{$paths}) {
			if (-f "$_/$file") {
				return "$_/$file";
				last;
			}
		}
		return;
	}

	my $coredir = File::Spec->catfile($Config{installarchlib}, "CORE");

	open(F, ">", ".perlconfig.txt");
	print F "perl=$Config{perlpath}\\n";
	print F "typemap=" . search(\\@INC, "ExtUtils/typemap") . "\\n";
	print F "xsubpp=" . search(\\@INC, "ExtUtils/xsubpp" || search([File::Spec->path()], "xsubpp")) . "\\n";
	print F "coredir=$coredir\\n";
	close F;
	'''

	f = file(".perltest.pl", "w")
	f.write(source)
	f.close()

	if win32:
		ret = os.spawnlp(os.P_WAIT, "wperl", "wperl", ".perltest.pl")
	else:
		ret = os.spawnlp(os.P_WAIT, "perl", "perl", ".perltest.pl")
	context.Result(ret == 0)

	os.unlink(".perltest.pl")
	if ret == 0:
		f = file(".perlconfig.txt", "r")
		while 1:
			line = f.readline()
			if line == "":
				break
			line = line.rstrip("\n")
			line = line.rstrip("\r")
			[name, value] = line.split("=", 2)
			perlconfig[name] = value
		f.close()
		os.unlink(".perlconfig.txt")

		if cygwin:
			# Convert paths to Cygwin-compatible paths
			perlconfig['perl'] = perlconfig['perl'].replace('\\', '/')
			perlconfig['coredir'] = perlconfig['coredir'].replace('\\', '/')
	return ret == 0

conf = Configure(env, custom_tests = {'CheckPerl' : CheckPerl})
conf.CheckPerl()
if not win32:
	have_ncurses = conf.CheckLib('ncurses')
conf.Finish()


### Environment setup ###

env['CFLAGS'] = ['-Wall', '-g', '-O2']
env['LINKFLAGS'] = []
env['LIBPATH'] = []
env['LIBS'] = []
env['CPPDEFINES'] = []
env['INCLUDE'] = []
if cygwin:
	env['CFLAGS'] += ['-mno-cygwin']
	env['LINKFLAGS'] += ['-mno-cygwin']
env['CCFLAGS'] = env['CFLAGS']


libenv = env.Copy()
if win32:
	if cygwin:
		libenv['CFLAGS'] += ['-mdll']
	libenv['CPPDEFINES'] += ['WIN32']
else:
	libenv['CFLAGS'] += ['-fPIC']
	libenv['LINKFLAGS'] += ['-fPIC']
libenv['CCFLAGS'] = libenv['CFLAGS']

if cygwin:
	def linkDLLAction(target, source, env):
		sources = []
		for f in source:
			sources += [str(f)]

		(temp, dllname) = os.path.split(str(target[0]))
		(targetName, temp) = os.path.splitext(str(target[0]))
		command = ['dlltool', '--dllname', dllname,
			'-z', targetName + '.def',
			'-l', targetName + '.lib',
			'--export-all-symbols',
			'--add-stdcall-alias'] + sources
		print ' '.join(command)
		ret = os.spawnvp(os.P_WAIT, command[0], command)
		if ret != 0:
			return 0

		command = ['dllwrap', '--driver=g++', '--target=i386-mingw32',
			'--def', targetName + '.def', '-mno-cygwin'] + \
			sources + ['-o', str(target[0])]
		if env.has_key('LIBPATH'):
			for dir in env['LIBPATH']:
				command += ['-L' + dir]
		if env.has_key('LIBS'):
		 	for flag in env['LIBS']:
				command += ['-l' + flag]
		command += ['-lstdc++']

		print ' '.join(command)
		return os.spawnvp(os.P_WAIT, command[0], command)

	NativeDLLBuilder = Builder(action = linkDLLAction,
		emitter = '$LIBEMITTER',
		suffix = 'dll',
		src_suffix = '$OBJSUFFIX',
		src_builder = 'SharedObject')
else:
	NativeDLLBuilder = libenv['BUILDERS']['SharedLibrary']
libenv['BUILDERS']['NativeDLL'] = NativeDLLBuilder


perlenv = libenv.Copy()
if win32:
	perlenv['CFLAGS'] += Split('-Wno-comments -D__MINGW32__' +
		' -DWIN32IO_IS_STDIO -D_INTPTR_T_DEFINED -D_UINTPTR_T_DEFINED')
	perlenv['LIBS'] += ['perl58']
	perlenv['LIBPATH'] += [perlconfig['coredir']]
else:
	perlenv['CFLAGS'] += Split('-D_REENTRANT -D_GNU_SOURCE' +
		' -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64')
perlenv['CFLAGS'] += ["-I" + perlconfig['coredir'],
		'-DVERSION=\\"1.0\\"', '-DXS_VERSION=\\"1.0\\"']
perlenv['CCFLAGS'] = perlenv['CFLAGS']

def buildXS(target, source, env):
	global perlconfig

	code = '''
	use strict;
	my $out = shift;
	my $file = shift;

	open(STDOUT, ">", $out);
	do $file;
	'''

	print "Creating", str(target[0]), "..."
	command = [
		perlconfig['perl'],
		'-e',
		code,
		str(target[0]),
		perlconfig['xsubpp'],
		'-C++',
		'-typemap',
		perlconfig['typemap'],
		str(source[0])]
	return os.spawnvp(os.P_WAIT, perlconfig['perl'], command)

perlenv['BUILDERS']['XS'] = Builder(action = buildXS)


### Invoke SConscripts ###

Export('env libenv perlenv win32 cygwin have_ncurses')
SConscript('src/auto/XSTools/SConscript')
