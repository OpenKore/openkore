#!/usr/bin/python
import os

# Base parser class. This implements the global  #
# functions used by both parser implementations. #
class ParserBase:
    def __init__(self):
        self.tWarpAmt = 0
        self.tMobAmt = 0
        self.ignore = []


    # Just adds a file to the ignore list. #
    def add_ignore(self,file):
        self.ignore.append(file)


    # Write a list to a file after joining #
    # it with newlines.                    #
    def write(self,oFile,indata):
        open(oFile,'w').write('\n'.join(indata))


    # Kind of a wrapper function to parse #
    # all the warp scripts.               #
    def warp_run(self,parent='.',verbose=1):
        self.warps = []
        os.path.walk(parent,self.warp_check,verbose)


    # Callback for os.path.walk in warp_run. #
    # Calls the actual parser on the script  #
    # contents. Also displays the number of  #
    # warps found.                           #
    def warp_check(self,v,dirname,names):
        for f in names:
            if f in ignore: continue

            f = '%s%s%s' % (dirname,os.sep,f)

            if os.path.isdir(f): continue
            if f in ignore: continue

            self.warpAmt = 0

            if v: print 'Processing %s...' % f,

            raw = open(f,'r').read().rstrip().split('\n')

            self.warp_parse(raw)

            if v: print 'Done. %s warps found.' % warpAmt
            self.tWarpAmt += self.warpAmt


# This class implements the parser #
# for Athena-style warp scripts.   #
# Yeah yeah, it's primitive. But   #
# works perfectly.                 #
class AthenaParser(ParserBase):
    def warp_parse(self,lines):
        for l in lines:
            if l[:2] == '//' or len(l) < 5: continue

            try: l = l.split(',')
            except: continue

            if len(l) == 8:
                self.warps.append('%s %s %s %s %s %s' % (l[0],l[1][:3],l[2][:3],l[5],l[6][:3],l[7][:3]))
                self.warpAmt += 1


# This class implements the parser #
# for Aegis-style warp scripts.    #
# Stupid Gravity and their stupid  #
# script format. Stupid.           #
class AegisParser(ParserBase):
    def warp_parse(self,lines):
        inwarp = 0
        for l in lines:
            if len(line) == 0 or line[0] == '/': continue

            line = line.lstrip().rstrip().split(' ')
            if inwarp and line[0] == 'moveto':
                dst = src + [line[1].replace('"',''),line[2],line[3]]
                warps.append(' '.join(dst))
                inwarp = 0
            elif not inwarp and line[0] == 'warp':
                src = [line[1].replace('"',''),line[-4],line[-3]]
                inwarp = 1
            else:
                continue


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
    parent = '.'

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

    if source == 'athena': p = AthenaParser()
    elif source == 'aegis': p = AegisParser()
    else: sys.exit('How\'d you trick the software into getting this far with incorrect options?')

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