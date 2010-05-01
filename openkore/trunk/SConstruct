# -*-python-*-
# This is the main SCons script which defines compilation rules.
# See http://www.scons.org/ for more information.
#
# If you wish to tweak the build system but aren't familiar with SCons,
# then simply edit these variables:

# Extra directories in which the C(++) compiler should look for
# header files.
# Example: EXTRA_INCLUDE_DIRECTORIES = ['/foo', '/bar']
EXTRA_INCLUDE_DIRECTORIES = []

# Extra directories in which the linker should search for libraries.
# Example: EXTRA_LIBRARY_DIRECTORIES = ['/opt/foo/lib', '/tmp/bar/lib']
EXTRA_LIBRARY_DIRECTORIES = []

# Extra arguments to be passed to the compiler during the compilation
# stage (not during the linking stage).
EXTRA_COMPILER_FLAGS = ['-Wall', '-g', '-O2', '-pipe']

####################

import os
import sys
import subprocess

### Platform configuration ###

platform = str(ARGUMENTS.get('OS', Platform()))
cygwin = platform == "cygwin"
darwin = platform == "darwin"
win32 = cygwin or platform == "win32"
have_ncurses = False
READLINE_LIB = 'readline'

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
		if cygwin:
			# Maybe the user just installed ActivePerl and wperl isn't
			# in PATH yet. So add the default Perl installation folder
			# to PATH.
			os.environ['PATH'] += os.path.pathsep + "/cygdrive/c/Perl/bin"
		ret = subprocess.call(["wperl", ".perltest.pl"])
	else:
		ret = subprocess.call(["perl", ".perltest.pl"])
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
			def cygpath(path):
				f = os.popen('cygpath --unix "' + path + '"', 'r')
				if f == None:
					return path
				else:
					line = f.readline()
					line = line.rstrip("\n")
					line = line.rstrip("\r")
					f.close()
					return line
			perlconfig['perl'] = cygpath(perlconfig['perl'])
			perlconfig['coredir'] = cygpath(perlconfig['coredir'])
	return ret == 0

def CheckReadline(context, conf):
	context.Message('Checking for GNU readline 4.3 or higher...')
	result = context.TryCompile("""
		#include <stdio.h>
		#include <readline/readline.h>
		#if !defined(RL_READLINE_VERSION)
			#error "You do not have the GNU readline development headers installed!"
		#elif RL_READLINE_VERSION < 0x0403
			#error "Your version of GNU readline is too old. Please install version 4.3 or higher."
		#endif
""", '.c')
	context.Result(result)
	return result

def CheckLibCurl(context):
	context.Message('Checking for libcurl...')
	(input, output, error) = os.popen3('curl-config --version', 'r')
	if input != None:
		input.close()
	if error != None:
		error.close()
	if output != None:
		version = "\n".join(output.readlines())
		output.close()
		version = version.rstrip("\n")
		version = version.rstrip("\r")
		result = version
	else:
		result = False
	context.Result(result)
	return result


conf = Configure(env, custom_tests = {
	'CheckPerl' : CheckPerl,
	'CheckReadline' : CheckReadline,
	'CheckLibCurl'  : CheckLibCurl
})
if not conf.CheckPerl():
	print "You do not have Perl installed! Read:"
	print "http://www.openkore.com/wiki/index.php/How_to_run_OpenKore_on_Linux/Unix#Perl.27s_Time::HiRes_module"
	Exit(1)
if not win32:
	have_ncurses = conf.CheckLib('ncurses')
	if not conf.CheckReadline(conf):
		print "You don't have GNU readline installed, or your version of GNU readline is not recent enough! Read:"
		print "http://www.openkore.com/wiki/index.php/How_to_run_OpenKore_on_Linux/Unix#GNU_readline"
		Exit(1)

	if darwin:
		has_readline_5 = conf.CheckLib('readline.5')
		sys.stdout.write('Checking whether Readline 5 is available...')
		sys.stdout.flush
		if has_readline_5:
			READLINE_LIB = 'readline.5'
			sys.stdout.write(" yes\n")
		else:
			sys.stdout.write(" no\n")

	if not conf.CheckLibCurl():
		print "You don't have libcurl installed. Please download it at:";
		print "http://curl.haxx.se/libcurl/";
		Exit(1)
conf.Finish()


### Environment setup ###

# Standard environment for programs
env['CCFLAGS'] = [] + EXTRA_COMPILER_FLAGS
env['LINKFLAGS'] = []
env['LIBPATH'] = [] + EXTRA_LIBRARY_DIRECTORIES
env['LIBS'] = []
env['CPPDEFINES'] = []
env['CPPPATH'] = [] + EXTRA_INCLUDE_DIRECTORIES
if cygwin:
	env['CCFLAGS'] += ['-mno-cygwin']
	env['LINKFLAGS'] += ['-mno-cygwin']
env.Replace(CXXFLAGS = env['CCFLAGS'])


# Environment for libraries
libenv = env.Clone()
if win32:
	if cygwin:
		libenv['CCFLAGS'] += ['-mdll']
	libenv['CPPDEFINES'] += ['WIN32']
elif not darwin:
	libenv['CCFLAGS'] += ['-fPIC']
	libenv['LINKFLAGS'] += ['-fPIC']
libenv.Replace(CXXFLAGS = libenv['CCFLAGS'])

if cygwin:
	# We want to build native Win32 DLLs on Cygwin
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
		ret = subprocess.call([command[0], command])
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
		return subprocess.call([command[0], command])

	NativeDLLBuilder = Builder(action = linkDLLAction,
		emitter = '$LIBEMITTER',
		suffix = 'dll',
		src_suffix = '$OBJSUFFIX',
		src_builder = 'SharedObject')
elif darwin:
	def linkBundleAction(target, source, env):
		sources = []
		for f in source:
			sources += [str(f)]

		command = [env['CXX'], '-flat_namespace', '-bundle',
			'-undefined', 'dynamic_lookup',
			'-o', str(target[0])] + sources
		if env.has_key('LIBPATH'):
			for dir in env['LIBPATH']:
				command += ['-L' + dir]
		if env.has_key('LIBS'):
		 	for flag in env['LIBS']:
				command += ['-l' + flag]

		print ' '.join(command)
		return subprocess.call([command[0], command])

	NativeDLLBuilder = Builder(action = linkBundleAction,
				   emitter = '$LIBEMITTER',
				   prefix = '',
				   suffix = 'bundle',
				   src_suffix = '$OBJSUFFIX',
				   src_builder = 'SharedObject')
else:
	NativeDLLBuilder = libenv['BUILDERS']['SharedLibrary']
libenv['BUILDERS']['NativeDLL'] = NativeDLLBuilder


# Environment for Perl libraries
perlenv = libenv.Clone()
if win32:
	# Windows
	perlenv['CCFLAGS'] += Split('-Wno-comments -include stdint.h')
	perlenv['CPPDEFINES'] += Split('__MINGW32__ WIN32IO_IS_STDIO ' +
		'_UINTPTR_T_DEFINED CHECK_FORMAT')
	#perlenv['LIBS'] += ['perl58']
	perlenv['LIBS'] += ['perl510']
	perlenv['LIBPATH'] += [perlconfig['coredir']]
elif not darwin:
	# Unix (except MacOS X)
	perlenv['CCFLAGS'] += Split('-D_REENTRANT -D_GNU_SOURCE' +
		' -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64')
else:
	# MacOS X
	perlenv['CCFLAGS'] += ['-no-cpp-precomp', '-DPERL_DARWIN',
			      '-fno-strict-aliasing']
	perlenv['LIBS'] += ['perl']
	perlenv['LIBPATH'] += [perlconfig['coredir']]
	# Add default Fink header directory to header search path.
	# But give system's default include paths higher priority.
	perlenv['CPPPATH'] += ['/usr/include', '/usr/local/include', '/sw/include']

perlenv['CPPPATH'] += [perlconfig['coredir']]
perlenv['CCFLAGS'] += ['-DVERSION=\\"1.0\\"', '-DXS_VERSION=\\"1.0\\"']
perlenv.Replace(CXXFLAGS = perlenv['CCFLAGS'])


def buildXS(target, source, env):
	global perlconfig

	code = '''
	use strict;
	my $out = shift;
	my $file = shift;

	close STDOUT;
	if (!open(STDOUT, ">", $out)) {
		print STDERR "Cannot open $out for writing: $!\n";
		exit 1;
	}
	select STDOUT;
	do $file;
	'''

	print "Creating", str(target[0]), "..."
	command = [
		#perlconfig['perl'],
		'-e',
		code,
		str(target[0]),
		perlconfig['xsubpp'],
		'-C++',
		'-typemap',
		perlconfig['typemap'],
		str(source[0])]
	return subprocess.call([perlconfig['perl'], command])

perlenv.Append(BUILDERS = { 'XS' : Builder(action = buildXS) })


### Invoke SConscripts ###

Export('env libenv perlenv platform win32 cygwin darwin have_ncurses READLINE_LIB')
sconscripts = []
if not int(ARGUMENTS.get('TESTS_ONLY', 0)):
	sconscripts += ['src/auto/XSTools/SConscript']
sconscripts += ['src/test/SConscript']
SConscript(sconscripts)
