#########################################################################
#  OpenKore - WxWidgets Interface
#
#  Copyright (c) 2005,2007 OpenKore development team 
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: Notebook control which supports undocking of its children
#
# This is a special notebook control. It hides the tab when there's only one child.
# All children in this notebook control will have a title bar, and can be detached
# into a dialog.
#
# This control is designed to only contain one instance for each type of child
# controls. For example, in OpenKore you can only have one Advanced Configuration
# panel.

package Interface::Wx::DockNotebook;

use strict;
use Wx ':everything';
use Wx::Event qw(EVT_NOTEBOOK_PAGE_CHANGING EVT_TIMER);
use base qw(Wx::Panel);
use Interface::Wx::DockNotebook::Page;


##############################
### CATEGORY: Constructor
##############################

##
# Interface::Wx::DockNotebook->new(parent, id)
# parent: The parent window. Must not be undef.
# id: The window identifier.
# Returns: a new Interface::Wx::DockNotebook control.
#
# Creates a new Interface::Wx::DockNotebook control.
# You can add pages by using $docknotebook->newPage()
sub new {
	my ($class, $parent, $id) = @_;
	my $self = $class->SUPER::new($parent, $id);
	my $sizer = $self->{sizer} = new Wx::BoxSizer(wxVERTICAL);
	$self->{dialogs} = [];
	$self->SetSizer($sizer);

	EVT_NOTEBOOK_PAGE_CHANGING($self, $id, \&onPageChanging);

	return $self;
}


##############################
### CATEGORY: Methods
##############################

##
# $docknotebook->newPage(show_buttons, title, [select = 1])
# show_buttons: Whether this page should have detach/close buttons.
# title: a title for this tab.
# Returns: a Interface::Wx::DockNotebook::Page control.
#
# Adds a new page to the notebook.
#
# See also: Interface::Wx::DockNotebook::Page->set()
#
# Example:
# my $page;
#
# $page = $docknotebook->newPage(1, "Tab 1");
# $page->set(new Wx::Button($page, -1, "Click Me!"));
#
# $page = $docknotebook->newPage(1, "Tab 2");
# $page->set(new Wx::Button($page, -1, "Hello World"));
sub newPage {
	my ($self, $show_buttons, $title, $select) = @_;
	my $page;
	$select = 1 if (!defined $select);

	if (!$self->{page} && !$self->{notebook}) {
		# This is the first child
		$page = new Interface::Wx::DockNotebook::Page($self, $show_buttons, $title);
		$self->{sizer}->Add($page, 1, wxGROW);
		$self->{page} = $page;

	} else {
		# We have multiple children.
		if (!$self->{notebook}) {
			# Create a notebook if we haven't done so already
			$self->{notebook} = new Wx::Notebook($self, wxID_ANY);
			$self->{sizer}->Add($self->{notebook}, 1, wxGROW);

			# Reparent the first page
			$self->{sizer}->Detach($self->{page});
			$self->{page}->Reparent($self->{notebook});
			$self->{notebook}->AddPage($self->{page}, $self->{page}{title});
			$self->Layout;
		}

		# Finally, add the new page
		$page = new Interface::Wx::DockNotebook::Page($self->{notebook}, $show_buttons, $title);
		$self->{notebook}->AddPage($page, $title, $select);

		delete $self->{page};
	}

	return $page;
}

##
# $docknotebook->closePage(page)
# page: Either an Interface::Wx::DockNotebook::Page object, or the title of a page.
#
# Close a page. If the page has been detached to a dialog, then the dialog will be closed.
sub closePage {
	my ($self, $page) = @_;
	my $notebook = $self->{notebook};

	if (!ref($page)) {
		$page = $self->hasPage($page);
		return if (!$page);
		if ($page->{dialog}) {
			$page->{dialog}->Close;
			return;
		}
	}

	if ($notebook) {
		my $n = $notebook->GetPageCount;

		for (my $i = 0; $i < $n; $i++) {
			if ($notebook->GetPage($i) == $page) {
				$notebook->DeletePage($i);
				last;
			}
		}

		if ($n == 2) {
			# The notebook only has 1 item left; we want to
			# reparent the page and then get rid of the notebook

			# I cannot reparent the page itself due to a bug in WxWidgets,
			# so create a new page and reparent the old page's child
			$page = $notebook->GetPage(0);
			my $page2 = new Interface::Wx::DockNotebook::Page($self, $page->{show_buttons}, $page->{title});
			$page->{child}->Reparent($page2);
			$page2->set($page->{child});
			$self->{sizer}->Add($page2, 1, wxGROW);
			$notebook->DeletePage(0);

			$self->{sizer}->Detach($notebook);
			$notebook->Destroy;
			delete $self->{notebook};
			$self->Layout;

			$self->{page} = $page2;
		}

	} else {
		$self->{sizer}->Detach($page);
		$page->Destroy;
		delete $self->{page};
		$self->Layout;
	}
}

##
# $docknotebook->hasPage(title)
# Returns: the Interface::Wx::DockNotebook::Page object which has the same title, or undef or nothing found.
#
# Check whether the notebook contains a page with title $title.
sub hasPage {
	my ($self, $title) = @_;
	my $notebook = $self->{notebook};

	foreach (@{$self->{dialogs}}) {
		next if (!$_);
		if ($_->{title} eq $title) {
			return $_;
		}
	}

	if (!$notebook) {
		if ($self->{page} && $self->{page}{title} eq $title) {
			return $self->{page};
		} else {
			return;
		}
	}

	my $n = $notebook->GetPageCount;
	for (my $i = 0; $i < $n; $i++) {
		if ($notebook->GetPage($i)->{title} eq $title) {
			return $notebook->GetPage($i);
		}
	}
	return;
}

##
# $docknotebook->hasPage(title)
# Returns: 1 on success, 0 on failure.
#
# Make sure the page with title $title is visible. If the page has been
# detached to a dialog, then that dialog will be raised.
sub switchPage {
	my ($self, $title) = @_;
	my $notebook = $self->{notebook};

	foreach (@{$self->{dialogs}}) {
		next if (!$_);
		if ($_->{title} eq $title) {
			$_->{dialog}->Raise;
			return 1;
		}
	}

	if (!$notebook) {
		if ($self->{page} && $self->{page}{title} eq $title) {
			return 1;
		} else {
			return 0;
		}
	}

	my $n = $notebook->GetPageCount;
	for (my $i = 0; $i < $n; $i++) {
		if ($notebook->GetPage($i)->{title} eq $title) {
			$notebook->SetSelection($i);
			return 1;
		}
	}
	return 0;
}

sub nextPage {
	my ($self) = @_;
	return unless ($self->{notebook});
	my $i = $self->{notebook}->GetSelection;
	$self->{notebook}->SetSelection($i + 1) if ($i < $self->{notebook}->GetPageCount);
}

sub prevPage {
	my ($self) = @_;
	return unless ($self->{notebook});
	my $i = $self->{notebook}->GetSelection;
	$self->{notebook}->SetSelection($i - 1) if ($i > 0);
}


####################
# Private
####################


sub onPageChanging {
	my ($self, $event) = @_;
	my $focus = Wx::Window::FindFocus;
	my $sub;

	if (!$focus) {
		my $page = $self->{notebook}->GetPage($event->GetSelection);
		$sub = sub {
			$page->{child}->SetFocus;
		} if ($page && $page->{child});

	} elsif ($focus->isa('Interface::Wx::Input')) {
		$sub = sub {
			my ($from, $to) = $focus->GetSelection;
			$focus->SetFocus;
			$focus->SetSelection($from, $to);
		};

	} else {
		$event->Skip;
		return;
	}

	if ($sub) {
		my $timer = new Wx::Timer($self, 1300);
		EVT_TIMER($self, 1300, $sub);
		$timer->Start(10, 1);
	}
}


1;
