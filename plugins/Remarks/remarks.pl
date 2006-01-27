#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: remarks.pl,v 1.1 2006/01/27 04:08:26 pudge Exp $

use strict;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:web);
use Slash::Display;
use Slash::Utility;
use Slash::XML;
use vars qw($VERSION);

($VERSION) = ' $Revision: 1.1 $ ' =~ /\$Revision:\s+([^\s]+)/;


sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $gSkin     = getCurrentSkin();
	my $remarks   = getObject('Slash::Remarks');

	if (! $user->{is_admin}) {
		redirect("$gSkin->{rootdir}/");
		return;
	}

	my %ops = (
		display		=> \&display,
		save_prefs	=> \&save_prefs,

		default		=> \&display
	);

	my $op = $form->{op};
	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED]) {
		$op = 'default';
	}

	header('Remarks', '', { admin => 1 }) or return;

	$ops{$op}->($slashdb, $constants, $user, $form, $gSkin, $remarks);

	footer();
}


sub display {
	my($slashdb, $constants, $user, $form, $gSkin, $remarks) = @_;

	my $remarks_ref = $remarks->getRemarks;

	slashDisplay('display', { remarks_ref => $remarks_ref });
}

sub save_prefs {
	my($slashdb, $constants, $user, $form, $gSkin) = @_;

}

createEnvironment();
main();

1;
