#!/usr/bin/python
import ParserBase

# This class implements the parser #
# for Athena-style warp scripts.   #
# Yeah yeah, it's primitive. But   #
# works perfectly.                 #
class Parser(ParserBase.ParserBase):
    def warp_parse(self,lines):
        for l in lines:
            if l[:2] == '//' or len(l) < 5: continue

            try: l = l.split(',')
            except: continue

            if len(l) == 8:
                self.warps.append('%s %s %s %s %s %s' % (l[0],l[1][:3],l[2][:3],l[5],l[6][:3],l[7][:3]))
                self.warpAmt += 1