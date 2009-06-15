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
#### Perl Modules that are not Included:
=========================
B

threads:
threads-1.71
threads-shared-1.26
Thread-Suspend-1.19
Thread-Semaphore-2.09
Thread-Queue-2.11
Thread-Queue-Any-0.09
Bundle-Thread-1.09
Internals-1.1

 
WX:
Alien-wxWidgets
Wx-Perl-Packager-0.03
wxWidgets-2.8.8

