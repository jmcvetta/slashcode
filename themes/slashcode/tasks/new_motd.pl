#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: new_motd.pl,v 1.5 2003/10/08 15:01:19 pater Exp $

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '12 * * * *';
$task{$me}{timespec_panic_1} = ''; # not important
$task{$me}{code} = sub {

	my($virtual_user, $constants, $slashdb, $user) = @_;

	return unless -x '/usr/local/games/fortune';
	chomp(my $t = `/usr/local/games/fortune -s`);

	if ($t) {
		my $tpid = $slashdb->getTemplateByName("motd", "tpid");
		$slashdb->setTemplate($tpid, { template => $t });
	}

	return ;
};

1;

