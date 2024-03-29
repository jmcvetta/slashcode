#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: authors.pl,v 1.15 2005/03/11 19:58:24 pudge Exp $

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

sub main {
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $form      = getCurrentForm();

	my $section = $reader->getSection($form->{section});
	my $list    = $reader->getAuthorDescription();

	header("$constants->{sitename}: Authors", $section->{section}) or return;
	slashDisplay('main', {
		list	=> $list,
		title	=> "The Authors",
		admin	=> getCurrentUser('seclev') >= 1000,
		'time'	=> timeCalc(scalar localtime),
	});

	footer();
}

createEnvironment();
main();
