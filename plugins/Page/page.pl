#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: page.pl,v 1.1 2002/06/14 20:57:05 patg Exp $

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::Page;
use Data::Dumper;

sub main {
	my $slashdb	= getCurrentDB();
	my $constants	= getCurrentStatic();
	my $user	= getCurrentUser();
	my $form	= getCurrentForm();
	my $index	= getObject('Slash::Page');

	if ($form->{op} eq 'userlogin' && !$user->{is_anon}) {
		my $refer = $form->{returnto} || $ENV{SCRIPT_NAME};
		redirect($refer);
		return;
	}

	my $section;
	if ($form->{section}) {
		$section = $slashdb->getSection($form->{section});
	} else {
		$section->{section} = 'index';
		$section->{issue} = 1;
	}

	my $title = getData('head', { section => $section });
	header($title, $section->{section} ne 'index' ? $section->{section} : '');
	slashDisplay('index', { index => $index});

	footer();

	writeLog($form->{section});
}
#################################################################
createEnvironment();
main();

1;
