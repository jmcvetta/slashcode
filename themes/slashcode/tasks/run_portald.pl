#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: run_portald.pl,v 1.5 2004/04/02 00:43:06 pudge Exp $

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '37 * * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $portald = "$constants->{sbindir}/portald";
	if (-e $portald and -x _) {
		system("$portald $virtual_user");
	} else {
		slashdLog("$me cannot find $portald or not executable");
	}

	return ;
};

1;

