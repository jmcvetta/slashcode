#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: dilemma.pl,v 1.2 2004/07/30 17:51:53 jamiemccarthy Exp $

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

##################################################################
sub main {
	my $form	= getCurrentForm();
	my $constants	= getCurrentStatic();

	header(getData('head')) or return;

	my $dilemma_reader = getObject('Slash::Dilemma', { db_type => 'reader' });
	my $dilemma_db = getObject('Slash::Dilemma');

	my $info = $dilemma_reader->getDilemmaInfo();
	my $species_hr = $dilemma_reader->getDilemmaSpeciesInfo();

	slashDisplay('maininfo', {
		info		=> $info,
		species		=> $species_hr,
	});

	footer();
}

#################################################################
createEnvironment();
main();

1;
