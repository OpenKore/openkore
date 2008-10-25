Introduction
------------
OpenKore uses quite some memory. This becomes a problem if you
run many instances of OpenKore at the same time.

This shared data server project is an attempt to lower OpenKore's
memory usage. OpenKore loads table files at startup. Each OpenKore
instance duplicates the file's data. Many table files almost never
change. The idea is that the shared data server loads these table
files instead of OpenKore. When OpenKore needs the data, it will
ask the server and retrieve only the data that it needs at the moment.
So the table files are only loaded once - by the shared data server.

Currently, this software only works on Unix. If anybody would like to
help porting to Windows, please let me know.


Using shared data server
------------------------

1. COMPILATION

First you must compile the server by typing these commands:

      cd main
      make


2. COPY OPENKORE PLUGIN

Inside the 'plugin' folder you will find 'dataserver.pl'. Copy this
plugin to your OpenKore plugins folder. Alternatively, you can use
OpenKore's --plugin argument:

      openkore.pl --plugins=/path/to/dataserver/plugin


3. RUN THE SHARED DATA SERVER

You must run the shared data server before you start OpenKore.

      cd main
      ./dataserver --tables /path/to/openkore/tables/folder


4. RUN OPENKORE

You can now run OpenKore. The plugin will take care of everything.
You don't have to configure anything.

