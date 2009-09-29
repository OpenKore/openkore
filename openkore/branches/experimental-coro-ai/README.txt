=========================
### OpenKore AI 2008 Project (what-will-become-3.0)
=========================

kLabMouse:
- Almoust Fully Refactored Code base.
- Fully Multi Thread (the implementation may change a bit).
- Added 'Misc::*' Classes to handle operations by type.
- Added 'KoreStage' to hanle first Kore preparations.
- Added Utils::CodeRef to handle Thread safe 'CODE' ref (Ugly Implementation, may have some Bugs).
- Deleted all Network/AI/Environment (I'll add them later, starting from AI).
- Globals.pm now can share varuables to other threads (Be carefull when you change thouse).
- Deleted WX and other Interfaces (I'll add them later, when AI and Networking will be done).
- Also Deleted some not so usefull stuff. (May-be I'll add them Later).

Technology:
- FLD2 implementation

=========================
### TODO:
=========================
1) Finish and Test SmartMatch system. (Use overloading of '~~' operator)
2) Implement basic Networking (client/server), not protocol specific.
3) Implement Environment Objects based on known RO data.
4) Implement RO Networking Protocol (xKore mode's too).
5) Implement Basic Tasks
6) Implement Complex Tasks
7) Implement AI Modules
8) Implement build in Macro language (may-be base on Parse::Gnaw ???)
9) Anything I've forgot???


=========================
#### Perl Modules that are not Included:
=========================
B

AnyEvent 4.86
common-sense 0.03
EV 3.7
Event 1.11
Guard 1.021
Coro 5.161
Internals 1.1
 
WX:
Alien-wxWidgets
Wx-Perl-Packager 0.03
wxWidgets 2.8.8

