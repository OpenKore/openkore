#!/usr/bin/python
import ParserBase

# This class implements the parser #
# for Aegis-style warp scripts.    #
# Stupid Gravity and their stupid  #
# script format. Stupid.           #
class Parser(ParserBase.ParserBase):
    def warp_parse(self,lines):
        inwarp = 0

        for line in lines:
            if len(line) == 0 or line[0] == '/': continue

            line = line.lstrip().rstrip().split(' ')
            if inwarp and line[0] == 'moveto':
                dst = src + [line[1].replace('"',''),line[2],line[3]]
                self.warps.append(' '.join(dst))
                inwarp = 0
            elif not inwarp and line[0] == 'warp':
                src = [line[1].replace('"',''),line[-4],line[-3]]
                inwarp = 1
            else:
                continue

        self.warpAmt = len(self.warps)