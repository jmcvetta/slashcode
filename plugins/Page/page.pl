#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: page.pl,v 1.7 2002/07/26 19:13:40 pudge Exp $

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

	my $section = $slashdb->getSection($form->{section});

	my $title = getData('head', { section => $section });
	header($title, $section->{section});
	slashDisplay('index', { 'index' => $index });

	footer();

	writeLog();
}
#################################################################
createEnvironment();
main();

1;
