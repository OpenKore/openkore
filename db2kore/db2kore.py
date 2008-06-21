#!/usr/bin/python
import os

# Main code, used when the script is #
# run from the command line. Not     #
# gonna comment this because it      #
# should be pretty obvious.          #
if __name__ == '__main__':
    import sys,getopt

    opts, args = getopt.gnu_getopt(sys.argv[1:],'o:s:p:vhd:',['output=','source=','parser=','verbose','dir='])

    parser = 'portal'
    source = 'athena'
    verbosity = 1
    ignore = args
    parent_dir = '.'

    for o, a in opts:
        if o in ('-?','-h','--help'):
            print 'Usage: db2kore <OPTIONS> [IGNORE]'
            print
            print '-s\t--source\tSets source files.'
            print '\t\t\tAllowed values: athena aegis'
            print
            print '-o\t--output\tSet output filename.'
            print
            print '-p\t--parser\tSets parser to use.'
            #print '\t\t\tAllowed values: mob portal npc'
            print '\t\t\tAllowed values: portal'
            print
            print '-v\t--verbose\tTurns on verbose output.'
            print
            print '-d\t--dir\t\tSets working directory. Defaults to CWD.'
            print
            print '[IGNORE]\t\tSpace-delimeted list of files to ignore.'
            print
            print '-?\t--help\t\tPrints this message then exits.'
            sys.exit()

        if o in ('-s','--source'):
            if a in ('athena','aegis'): source = a
            else: sys.exit('Unknown source: %s' % a)

        if o in ('-o','--output'):
            ofile = a

        if o in ('-p','--parser'):
            if a in ('mob','portal'): parser = a
            else: sys.exit('Unknown parser: %s' % a)

        if o in ('-v','--verbose'):
            verbosity = 1

        if o in ('-d','--dir'):
            parent_dir = a

    if source == 'athena': from Athena import Parser
    elif source == 'aegis': from Aegis import Parser
    else: sys.exit('How\'d you trick the software into getting this far with incorrect options?')

    p = Parser()

    for i in ignore: p.add_ignore(i)

    # Remove this when mob support is added. #
    #parser = 'portal'
    #ofile = parser + '-' + source + '.txt'

    if parser == 'portal':
        p.warp_run(parent=parent_dir,verbose=verbosity)
        p.write(ofile,p.warps)
    #elif parser == 'mob':
    #    p.mob_run(parent=parent_dir,verbose=verbosity)
    #    p.write(ofile,p.mobs)
    #elif parser == 'npc':
    #    p.npc_run(parent=parent_dir,verbose=verbosity)
    #    p.write(ofile,p.npc)
    else: sys.exit('How\'d you trick the software into getting this far with incorrect options?')