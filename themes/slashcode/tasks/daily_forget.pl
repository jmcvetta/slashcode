#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: daily_forget.pl,v 1.14 2004/10/28 16:48:35 jamiemccarthy Exp $

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '2 7 * * *';
$task{$me}{timespec_panic_1} = ''; # if panic, this can wait
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtualuser, $constants, $slashdb, $user) = @_;
	my @forgotten = (
		$slashdb->forgetCommentIPs,
		$slashdb->forgetSubmissionIPs,
		$slashdb->forgetOpenProxyIPs,
		$slashdb->forgetUsersLogtokens,
		$slashdb->forgetUsersLastLookTime,
		$slashdb->forgetUsersMailPass,
		$slashdb->forgetRemarks,
		$slashdb->forgetStoryTextRendered,
		$slashdb->forgetErrnotes,
		$slashdb->forgetRemarks,
	);
	return "forgotten: '@forgotten'";
};

1;

