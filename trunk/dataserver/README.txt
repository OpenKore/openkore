TABLE OF CONTENTS

	1. Introduction
	2. Installation on Unix/Linux
	3. Installation on Windows
	4. Usage


1. Introduction
---------------
OpenKore uses quite some memory. This becomes a problem if you
run many instances of OpenKore at the same time.

This shared data server project is an attempt to lower OpenKore's
memory usage. OpenKore loads table files at startup. Each OpenKore
instance duplicates the file's data. Many table files almost never
change. The idea is that the shared data server loads these table
files instead of OpenKore. When OpenKore needs the data, it will
ask the server and retrieve only the data that it needs at the moment.
So the table files are only loaded once - by the shared data server.


2. Installation on Unix/Linux
-----------------------------

There is no installation procedure. You just have to compile the
server. After that, you can put it anywhere you want.

Compile the server by typing these commands:

      cd main
      make

This will generate the binary 'dataserver'.

Now read paragraph 4, "Usage".


3. Installation on Windows
--------------------------

(TODO: write this)

If you want to compile the source code on Windows, you'll have to
install Scons (http://www.scons.org). In the dataserver folder, type:

       scons


4. Usage
--------

Step 1: Copy OpenKore plugin

Inside the 'plugin' folder you will find 'dataserver.pl'. Copy this
plugin to your OpenKore plugins folder. Alternatively, you can use
OpenKore's --plugin argument:

      openkore.pl --plugins=/path/to/dataserver/plugin


Step 2: Run the shared data server

You must run the shared data server before you start OpenKore.

      cd main
      ./dataserver --tables /path/to/openkore/tables/folder


Step 3: Run OpenKore

You can now run OpenKore. The plugin will take care of everything.
You don't have to configure anything.
