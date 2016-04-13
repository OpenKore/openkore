#
# $Id: GuiTest.pm,v 1.14 2001/12/01 23:34:50 erngui Exp $
#

=head1 NAME

Win32::GuiTest - Perl GUI Test Utilities

=head1 SYNOPSIS

  use Win32::GuiTest qw(FindWindowLike GetWindowText
    SetForegroundWindow SendKeys);

  $Win32::GuiTest::debug = 0; # Set to "1" to enable verbose mode

  my @windows = FindWindowLike(0, "^Microsoft Excel", "^XLMAIN\$");
  for (@windows) {
      print "$_>\t'", GetWindowText($_), "'\n";
      SetForegroundWindow($_);
      SendKeys("%fn~a{TAB}b{TAB}{BS}{DOWN}");
  }

=head1 INSTALLATION

    perl makefile.pl
    nmake
    nmake test
    nmake install

If you are using ActivePerl 5.6
(http://www.activestate.com/Products/ActivePerl/index.html)
you can install the binary package I am including instead. You will need
to enter PPM (Perl Package Manager) from the command-line. Once you have
extracted the files I send you to a directory of your machine, enter PPM
 and do like this:

    C:\TEMP>ppm
    PPM interactive shell (2.0) - type 'help' for available commands.
    PPM> install C:\temp\win32-guitest.ppd
    Install package 'C:\temp\win32-guitest.ppd?' (y/N): Y
    Retrieving package 'C:\temp\win32-guitest.ppd'...
    Writing C:\Perl\site\lib\auto\Win32\GuiTest\.packlist
    PPM>

I extracted them to 'c:\temp', please use the directory where you extracted
the files instead.


=head1 DESCRIPTION

Most GUI test scripts I have seen/written for Win32 use some variant of Visual
Basic (e.g. MS-VB or MS-Visual Test). The main reason is the availability of
the SendKeys function.

A nice way to drive Win32 programs from a test script is to use OLE Automation
(ActiveX Scripting), but not all Win32 programs support this interface. That's
where SendKeys comes handy.

Some time ago Al Williams published a Delphi version in Dr. Dobb's
(http://www.ddj.com/ddj/1997/careers1/wil2.htm). I ported it to C and
packaged it using h2xs...

The tentative name for this module is Win32::GuiTest (mostly because I plan to
include more GUI testing functions).

I've created a Yahoo Group for the module that you can join at
   http://groups.yahoo.com/group/perlguitest/join

=head1 VERSION

    1.3

=head1 CHANGES


0.01  Wed Aug 12 21:58:13 1998

    - original version; created by h2xs 1.18

0.02  Sun Oct 25 20:18:17 1998

    - Added several Win32 API functions (typemap courtesy
      of Win32::APIRegistry):
        SetForegroundWindow
	GetDesktopWindow
	GetWindow
	GetWindowText
	GetClassName
	GetParent
	GetWindowLong
	SetFocus

    - Ported FindWindowLike (MS-KB, Article ID: Q147659) from VB to
      Perl. Instead of using VB's "like", I used Perl regexps.

0.03  Sun Oct 31 18:31:52 1999

    - Perhaps first version released thru CPAN (user: erngui).

    - Changed name from Win32::Test to Win32::GuiTest

    - Fixed bug: using strdup resulted in using system malloc and
      perl's free, resulting in a runtime error.
      This way we always use perl's malloc. Got the idea from
      'ext\Dynaloader\dl_aix.xs:calloc'.

0.04  Fri Jan 7 17:44:00 2000

    - Fixed Compatibility with ActivePerl 522. Thanks to
      Johannes Maehner <johanm@camline.com> for the initial patch.
      There were two main issues:
        /1/ ActivePerl (without CAPI=TRUE) compiles extensions in C++ mode
            (some casts from void*, etc.. were needed).
        /2/ The old typemap + buffers.h I was using had been rendered
            incompatible by changes in ActivePerl. As the incompatible typemaps
            were redundant, I deleted them.
      Now it works on ActivePerl (both using 'perl makefile.pl'
      and 'perl makefile.pl CAPI=TRUE') and on CPAN perl
      (http://www.perl.com/CPAN/src/stable.zip).

    - As requests for changes keep comming in, I've decided to put it all
      under version control (cvs if you're curious about it).

0.05 Sat Mar 11 23:11:42 2000

    - Added support for sending function keys (e.g. "%{F4}"). A new test
      script is added to the distribution (eg\notepad.pl) to test
      this functionality.

    - Code cleanup to make adding new keywords easier.

0.06 Sun Mar 12 01:51:18 2000

    - Added support for sending mouse events.
      Thanks to Ben Shern <shernbj@louisville.stortek.com> for the idea
      and original code. Also added 'eg\paint.pl' to the distribution to
      test this functionality.

    - Code cleanup.


0.07 Sun Nov 19 13:02:00 2000

    - Added MouseMoveAbsPix to allow moving the mouse to an absolute pixel
      coordinate instead of using mouse_event's (0, 0) to (65535, 65535)
      coordinates.
      Thanks to Phill Wolf <pbwolf@bellatlantic.net> for the idea
      and original code. Also added 'eg\paint_abs.pl' to the distribution
      to test this functionality.

    - Added binaries for the ActivePerl distribution.

0.08 Sun Dec 17 19:33:07 2000

    - Added WMGetText to allow getting the content of an EDIT window. See
      'eg\notepad_text.pl' for more details.
      Thanks to Mauro <m_servizi@yahoo.it> from Italy for the idea.

0.09 Thu Jan 4 22:30:50 2001

    - Added {SPC} action to sendkeys to simulate hitting the spacebar.
      Thanks to Sohrab Niramwalla <sohrab.niramwalla@utoronto.ca> for the
      idea.

1.00 Sun May 13 22:02:01 2001

    - Fixed a bug in FindWindowLike that caused duplicated window handles to
      be returned.

    - Simplified the logic in FindWindowLike.

    - Added IsChild and GetChildDepth functions. Exported GetChildWindows.

    - Added more tests (tightening the net in XP-speak)

    - Added 'eg\spy--.pl' to the distribution.

1.10 Sun Jun 17 19:54:27 2001

    - Added GetWindowRect, GetScreenRes, ScreenToNorm and NormToScreen,
      following suggestion and code from Frank van Dijk <fvdijk@oke.nl>.

    - Added SendMessage, PostMessage, GetCursorPos, AttachWin,
      additional SendKeys flags (Windows keys and context menu),
      WMSetText, GetCaretPos, GetFocus, GetActiveWindow, GetForegroundWindow,
      SetActiveWindow, EnableWindow, IsWindowEnabled, IsWindowVisible and
      ShowWindow (+ constants to use it).

      Thanks to Jarek Jurasz <jurasz@imb.uni-karlsruhe.de> for all of them.

      Jarek also provided two scripts: 'eg\showmouse.pl' and 'eg\showwin.pl'.
      I found showwin very interesting (if somewhat dangerous!).

      He also fixed an export list problem (WMGetKey was mentioned instead
      of WMGetText) and added export tags :ALL and :SW, so that full module
      functionality can be imported with

                   use Win32::GuiTest qw(:ALL :SW);

    - Added IsWindow, ScreenToClient, ClientToScreen, IsCheckedButton and
      IsGrayedButton.

    - SendKeys now takes an optional parameter to change the default 50 ms
      delay between keystrokes. Suggested by Wilson P. Snyder II
      <wsnyder@world.std.com>.

1.20 Wed Jul 18 20:44:11  2001

    - Added GetComboText, GetComboContents, GetListText and GetListContents
      to allow easy extraction of data from list and combo boxes.

    - Added 'eg\fonts.pl' to show the new functionality. This script opens
      the Notepad "Font" dialog and prints to stdout the contents of the Font
      combobox.

    - Fixed bug in SendMessage (and others), where the return value was lost
      Caused by a missing OUTPUT tag.

    - Added IsKeyPressed function. Suggested by Rudi Farkas.
      See 'eg\keypress.pl' for a demo. Works even if the script
      is running in the background.

1.30 Sat Dec  1 20:50:02 2001

    - Fixed bad POD formating. Added podchecker and html pod generation to makedist.bat.

    - Added PushButton and PushChildButton. Based on code from an anonymous contributor. Thanks!
      See 'eg\pushbutton.pl' for an example.

    - Fixed a problem when building with Active State, build 526.

=cut

package Win32::GuiTest;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $debug %EXPORT_TAGS);

require Exporter;
require DynaLoader;
require AutoLoader;

@ISA = qw(Exporter DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	
);

@EXPORT_OK = qw(
                $debug
                ClientToScreen
                FindWindowLike
                GetChildDepth
                GetChildWindows
                GetClassName
                GetCursorPos
                GetDesktopWindow
                GetComboText
                GetComboContents
                GetListText
                GetListContents
                GetParent
                GetScreenRes
                GetWindow
                GetWindowID
                GetWindowLong
                GetWindowRect
                GetWindowText
                IsCheckedButton
                IsChild
                IsGrayedButton
                IsWindow
                MouseMoveAbsPix
                NormToScreen
                PostMessage
                ScreenToClient
                ScreenToNorm
                SendKeys
                SendLButtonDown
                SendLButtonUp
                SendMButtonDown
                SendMButtonUp
                SendMessage
                SendMouse
                SendMouseMoveAbs
                SendMouseMoveRel
                SendRButtonDown
                SendRButtonUp
                SetForegroundWindow
                WMGetText
                EnableWindow
                GetActiveWindow
                GetCaretPos
                GetCursorPos
                GetFocus
                GetForegroundWindow
                IsWindowEnabled
                IsWindowVisible
                PostMessage
                SendMessage
                SetActiveWindow
                ShowWindow
                WMSetText
                IsKeyPressed
                PushButton
                PushChildButton
                );

%EXPORT_TAGS = (
    'ALL' => \@EXPORT_OK,
    'SW' => [qw(SW_HIDE SW_SHOWNORMAL
    SW_NORMAL SW_SHOWMINIMIZED SW_SHOWMAXIMIZED SW_MAXIMIZE SW_SHOWNOACTIVATE
    SW_SHOW SW_MINIMIZE SW_SHOWMINNOACTIVE SW_SHOWNA SW_RESTORE SW_SHOWDEFAULT
    SW_FORCEMINIMIZE SW_MAX)]);

Exporter::export_ok_tags('SW');

                             
$VERSION = '1.3';

$debug = 0;

bootstrap Win32::GuiTest $VERSION;

sub GWL_ID      { -12;  }
sub GW_HWNDNEXT { 2;    }
sub GW_CHILD    { 5;    }   

sub SW_HIDE             { 0; }
sub SW_SHOWNORMAL       { 1; }
sub SW_NORMAL           { 1; }
sub SW_SHOWMINIMIZED    { 2; }
sub SW_SHOWMAXIMIZED    { 3; }
sub SW_MAXIMIZE         { 3; }
sub SW_SHOWNOACTIVATE   { 4; }
sub SW_SHOW             { 5; }
sub SW_MINIMIZE         { 6; }
sub SW_SHOWMINNOACTIVE  { 7; }
sub SW_SHOWNA           { 8; }
sub SW_RESTORE          { 9; }
sub SW_SHOWDEFAULT      { 10; }
sub SW_FORCEMINIMIZE    { 11; }
sub SW_MAX              { 11; }

sub WM_LBUTTONDOWN      { 0x0201; }
sub WM_LBUTTONUP        { 0x0202; }

=head1 FUNCTIONS

=over 8


=item $debug

When set enables the verbose mode.


=item SendKeys KEYS [DELAY]

Sends keystrokes to the active window as if typed at the keyboard using the
optional delay between keystrokes (default is 50 ms and should be OK for
most uses).

The keystrokes to send are specified in KEYS. There are several
characters that have special meaning. This allows sending control codes
and modifiers:

	~ means ENTER
	+ means SHIFT
	^ means CTRL
	% means ALT

The parens allow character grouping. You may group several characters, so
that a specific keyboard modifier applies to all of them.

E.g. SendKeys("ABC") is equivalent to SendKeys("+(abc)")

The curly braces are used to quote special characters (SendKeys("{+}{{}")
sends a '+' and a '{'). You can also use them to specify certain named actions:

	Name          Action

	{BACKSPACE}   Backspace
	{BS}          Backspace
	{BKSP}        Backspace
	{BREAK}       Break
	{CAPS}        Caps Lock
	{DELETE}      Delete
	{DOWN}        Down arrow
	{END}         End
	{ENTER}       Enter (same as ~)
	{ESCAPE}      Escape
	{HELP}        Help key
	{HOME}        Home
	{INSERT}      Insert
	{LEFT}        Left arrow
	{NUMLOCK}     Num lock
	{PGDN}        Page down
	{PGUP}        Page up
	{PRTSCR}      Print screen
	{RIGHT}       Right arrow
	{SCROLL}      Scroll lock
	{TAB}         Tab
	{UP}          Up arrow
	{PAUSE}       Pause
        {F1}          Function Key 1
        ...           ...
        {F24}         Function Key 24
        {SPC}         Spacebar
        {SPACE}       Spacebar
        {SPACEBAR}    Spacebar
        {LWI}         Left Windows Key
        {RWI}         Right Windows Key
        {APP}         Open Context Menu Key

All these named actions take an optional integer argument, like in {RIGHT 5}.
For all of them, except PAUSE, the argument means a repeat count. For PAUSE
it means the number of milliseconds SendKeys should pause before proceding.

In this implementation, SendKeys always returns after sending the keystrokes.
There is no way to tell if an application has processed those keys when the
function returns.

=back

=cut

sub SendKeys {
    my $keys  = shift;
    my $delay = shift;
    $delay = 50 unless defined($delay);
    #print "<$delay>";
    SendKeysImp($keys, $delay);
}

=over 8

=item SendMouse COMMAND

This function emulates mouse input.  The COMMAND parameter is a string
containing one or more of the following substrings:

        {LEFTDOWN}    left button down
        {LEFTUP}      left button up
        {MIDDLEDOWN}  middle button down
	{MIDDLEUP}    middle button up
	{RIGHTDOWN}   right button down
	{RIGHTUP}     right button up
	{LEFTCLICK}   left button single click
	{MIDDLECLICK} middle button single click
	{RIGHTCLICK}  right button single click
	{ABSx,y}      move to absolute coordinate ( x, y )
        {RELx,y}      move to relative coordinate ( x, y )

Note: Absolute mouse coordinates range from 0 to 65535.
      Relative coordinates can be positive or negative.
      If you need pixel coordinates you can use MouseMoveAbsPix.

Also equivalent low-level functions are available:

    SendLButtonUp()
        SendLButtonDown()
        SendMButtonUp()
        SendMButtonDown()
        SendRButtonUp()
        SendRButtonDown()
        SendMouseMoveRel(x,y)
    SendMouseMoveAbs(x,y)

=back

=cut

sub SendMouse {
    my $command = shift;

    # Split out each command block enclosed in curly braces.
    my @list = ( $command =~ /{(.+?)}/g );
    my $item;

    foreach $item ( @list ) {
        if ( $item =~ /leftdown/i )      { SendLButtonDown (); }
        elsif ( $item =~ /leftup/i )	 { SendLButtonUp   (); }
        elsif ( $item =~ /middledown/i ) { SendMButtonDown (); }
        elsif ( $item =~ /middleup/i )	 { SendMButtonUp   (); }
        elsif ( $item =~ /rightdown/i )	 { SendRButtonDown (); }
        elsif ( $item =~ /rightup/i )	 { SendRButtonUp   (); }
        elsif ( $item =~ /leftclick/i )	{
            SendLButtonDown ();
            SendLButtonUp ();
        }
        elsif ( $item =~ /middleclick/i ) {
            SendMButtonDown ();
            SendMButtonUp ();
        }
        elsif ( $item =~ /rightclick/i ) {
            SendRButtonDown ();
            SendRButtonUp ();
        }
        elsif ( $item =~ /abs(-?\d+),(-?\d+)/i ) { SendMouseMoveAbs($1,$2); }
        elsif ( $item =~ /rel(-?\d+),(-?\d+)/i ) { SendMouseMoveRel($1,$2); }
        else  { warn "GuiTest: Unmatched mouse command! \n"; }
    }
}


=over 8

=item MouseMoveAbsPix(X,Y)

Move the mouse cursor to the screen pixel indicated as parameter.


    # Moves to x=200, y=100 in pixel coordinates.
    MouseMoveAbsPix(200, 100);



=item FindWindowLike WINDOW, TITLEPATTERN, CLASSPATTERN, CHILDID

Finds the window handles of the windows matching the specified parameters and
returns them as a list.

You may specify the handle of the window to search under. The routine
searches through all of this windows children and their children recursively.
If 'undef' then the routine searches through all windows. There is also a
regexp used to match against the text in the window caption and another regexp
used to match against the text in the window class. If you pass a child ID
number, the functions will only match windows with this id. In each case
undef matches everything.

=back

=cut

sub FindWindowLike {
    my $hWndStart  = shift || GetDesktopWindow(); # Where to start
    my $WindowText = shift; # Regexp
    my $Classname  = shift; # Regexp
    my $ID         = shift; # Op. ID
    my $maxlevel   = shift; 

    my @found;

    #DbgShow("Children < @hwnds >\n");
    for my $hwnd (GetChildWindows($hWndStart)) {
        next if $maxlevel && GetChildDepth($hWndStart, $hwnd) > $maxlevel;
            
        # Get the window text and class name:
        my $sWindowText = GetWindowText($hwnd);
        my $sClassname  = GetClassName($hwnd);

	#DbgShow("($hwnd, $sWindowText, $sClassname) has ". scalar @children . 
        #        " children < @children >\n");

        # If window is a child get the ID:
        my $sID;
        if (GetParent($hwnd) != 0) {
            $sID = GetWindowLong($hwnd, GWL_ID);   
        }
        # Check that window matches the search parameters:
        my $patwnd   = "$WindowText";
	my $patclass = "$Classname";
	
	DbgShow("Using pattern ($patwnd, $patclass)\n")
            if $patwnd or $patclass;

	if ((!$patwnd   || $sWindowText =~ /$patwnd/) && 
            (!$patclass || $sClassname =~ /$patclass/))
        {
            DbgShow("Matched $1\n") if $1;
            if (!$ID) {   
                # If find a match add handle to array:   
		push @found, $hwnd;
            } elsif ($sID) {   
                if ($sID == $ID) {
                    # If find a match add handle to array:
                    push @found, $hwnd;
                }   
            }   
            DbgShow("Window Found(" . 
                "Text  : '$sWindowText'" .
		" Class : '$sClassname'" .
		" Handle: '$hwnd')\n");   
        }
    }

    #DbgShow("FindWin found < @found >\n");
    return @found;
}

sub DbgShow {
    my $string = shift;
    print $string if $debug;
}

sub GetWindowID {
    return GetWindowLong(shift, GWL_ID);
}

=over 8

=item PushButton BUTTON [, DELAY]

Equivalent to

    PushChildButton(GetForegroundWindow, BUTTON, DELAY)

=back

=cut

sub PushButton {
    my $button = shift;
    my $delay  = shift;

    PushChildButton(GetForegroundWindow(), $button, $delay);
}

=over 8

=item PushChildButton( parent, button [, delay] )

Allows generating a mouse click on a particular button.

parent - the parent window of the button

button - either the text in a button (e.g. "Yes") or the control ID
of a button.

delay - the time (0.25 means 250 ms) to wait between the mouse down
and the mouse up event. This is useful for debugging.

=back

=cut

sub PushChildButton {
    my $parent = shift;
    my $button = shift;
    my $delay  = shift;
    $delay = 0 unless defined($delay);
    for my $child (GetChildWindows($parent)) {
        my $childtext = GetWindowText($child);
	my $childid = GetWindowID($child);
        # Is correct text or correct window ID?
	if ($childtext =~ /$button/i || ($button =~ /^\d+$/ && $childid == $button)) {
            # Need to use PostMessage.  SendMessage won't return when certain dialogs come up.
	    PostMessage($child, WM_LBUTTONDOWN, 0, 0);
	    # Allow for user to see that button is being pressed by waiting some ms.
	    select(undef, undef, undef, $delay) if $delay;
            PostMessage($child, WM_LBUTTONUP, 0, 0);
            return;
	}
    }
}


# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__


=head1 COPYRIGHT

The SendKeys function is based on the Delphi sourcecode
published by Al Williams  E<lt>http://www.al-williams.com/awc/E<gt>
in Dr.Dobbs  E<lt>http://www.ddj.com/ddj/1997/careers1/wil2.htmE<gt>.

Copyright (c) 1998-2001 Ernesto Guisado. All rights reserved. This program
is free software; You may distribute it and/or modify it under the
same terms as Perl itself.

=head1 AUTHOR

Ernesto Guisado E<lt>erngui@acm.orgE<gt>, E<lt>http://triumvir.orgE<gt>

=cut


