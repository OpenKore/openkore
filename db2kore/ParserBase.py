#!/usr/bin/python
import os

# Base parser class. This implements the global  #
# functions used by both parser implementations. #
class ParserBase:
    def __init__(self):
        self.tWarpAmt = 0
        self.tMobAmt = 0
        self.ignore = []
        self.warps = []


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
            if f in self.ignore: continue

            f = '%s%s%s' % (dirname,os.sep,f)

            if os.path.isdir(f): continue
            if f in self.ignore: continue

            self.warpAmt = 0

            if v: print 'Processing %s...' % f,

            raw = open(f,'r').read().rstrip().split('\n')

            self.warp_parse(raw)

            if v: print 'Done. %s warps found.' % self.warpAmt
            self.tWarpAmt += self.warpAmt