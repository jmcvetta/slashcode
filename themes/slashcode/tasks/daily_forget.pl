#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: daily_forget.pl,v 1.13 2004/10/19 18:18:55 jamiemccarthy Exp $

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '2 7 * * *';
$task{$me}{timespec_panic_1} = ''; # if panic, this can wait
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtualuser, $constants, $slashdb, $user) = @_;
	my $forgotten1 = $slashdb->forgetCommentIPs;
	my $forgotten2 = $slashdb->forgetSubmissionIPs;
	my $forgotten3 = $slashdb->forgetOpenProxyIPs;
	my $forgotten4 = $slashdb->forgetUsersLogtokens;
	my $forgotten5 = $slashdb->forgetUsersLastLookTime;
	my $forgotten6 = $slashdb->forgetUsersMailPass;
	my $forgotten7 = $slashdb->forgetRemarks;
	my $forgotten8 = $slashdb->forgetStoryTextRendered;
	return "forgot approx $forgotten1 comment IPs, $forgotten2 submission IPs, $forgotten3 open proxy IPs, $forgotten4 logtokens";
};

1;

