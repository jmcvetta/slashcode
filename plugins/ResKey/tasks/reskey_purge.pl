#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: reskey_purge.pl,v 1.1 2005/06/22 22:09:36 pudge Exp $

use strict;

use Slash::Constants qw(:slashd :reskey);

use vars qw( %task $me );

$task{$me}{timespec} = '0 0 0 * *';
$task{$me}{timespec_panic_1} = 1; # if panic, this can wait
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;


};

1;

