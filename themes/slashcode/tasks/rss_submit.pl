#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: rss_submit.pl,v 1.7 2004/07/13 19:07:49 jamiemccarthy Exp $

use strict;

use File::Path;
use Slash::Constants ':slashd';

use vars qw( %task $me );

my $total_freshens = 0;

$task{$me}{timespec} = '1-59/3 * * * *';
$task{$me}{timespec_panic_1} = '1-59/10 * * * *';
$task{$me}{timespec_panic_2} = '';
$task{$me}{on_startup} = 1;
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my %updates;
	return 0
		unless $constants->{rss_store};

	my @time_long_ago = localtime(time-86400*$constants->{rss_expire_days});
	my $weekago = sprintf "%4d-%02d-%02d", 
		$time_long_ago[5] + 1900, $time_long_ago[4] + 1, $time_long_ago[3];

	my $added_submissions = 0;
	# First, we grab as many submissions as possible
	my $rss_ar = $slashdb->getRSSNotProcessed($constants->{rss_process_number});
	for my $rss (@$rss_ar) {
		my $subid;
		my $block = $slashdb->getBlock($rss->{bid});
		my $description = $rss->{description} ? $rss->{description} : $rss->{title};
		if ($block->{autosubmit} eq 'yes') {
			my $blockskin = $slashdb->getSkin($block->{skin});
			my $submission = {
				email	=> $rss->{link},
				name	=> $block->{title},
				story	=> $description,
				subj	=> $rss->{title},
				skid	=> $blockskin->{skid},
			};
			$subid = $slashdb->createSubmission($submission);
			if (!$subid) {
				use Data::Dumper;
				slashdLog("failed to createSubmission, rss: " . Dumper($rss) . "submission: " . Dumper($submission));
			} else {
				$added_submissions++;
			}
		}
		$slashdb->setRSS($rss->{id}, { processed => 'yes', subid => $subid });	
	}

	$slashdb->expireRSS($constants->{rss_process_number});

	return $added_submissions ?
		"totaladded Submissions $added_submissions" : '';
};

1;
