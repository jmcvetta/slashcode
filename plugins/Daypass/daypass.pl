#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: daypass.pl,v 1.2 2005/03/11 19:58:06 pudge Exp $

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

##################################################################
sub main {
	my $gSkin = getCurrentSkin();
	my $daypass_reader = getObject('Slash::Daypass', { db_type => 'reader' });
print STDERR "dp_r: " . Dumper($daypass_reader);
	my $dps = $daypass_reader->getDaypassesAvailable();
print STDERR "dps: " . Dumper($dps);
	if (!$dps || !@$dps) {
		redirect($gSkin->{rootdir});
	}

	my $daypass_writer = getObject('Slash::Daypass');
	my $form = getCurrentForm();
	my $dpk = $form->{dpk} || "";
	if ($dpk) {
		# Strip this form field.
		$dpk =~ /^(\w+)$/;
		$dpk = $1 || "";
	}

	if ($dpk) {
		if ($daypass_writer->confirmDaypasskey($dpk)) {
			# Pause to allow replication to catch up, so when
			# the user gets back to the homepage, they will
			# show up as having the daypass.
			sleep 2;
		}
		# For now we always redirect back to the homepage --
		# whether the key was matched successfully or not!
		redirect($gSkin->{rootdir});
	}

	my $adnum = $daypass_reader->getDaypassAdnum();
	$dpk = $daypass_writer->createDaypassKey();
	if (!$dpk) {
		# Something went wrong.  We can't show the user a key.
		redirect($gSkin->{rootdir});
	}

	header(getData('head')) or return;

	slashDisplay('main', {
		adnum	=> $adnum,
		dpk	=> $dpk,
	});

	footer();
}

#################################################################
createEnvironment();
main();

1;

