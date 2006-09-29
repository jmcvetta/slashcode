#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: search_index.pl,v 1.2 2006/09/29 03:33:05 pudge Exp $

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '2-59/5 * * * *';
$task{$me}{timespec_panic_1} = ''; # if panic, this can wait
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtualuser, $constants, $slashdb, $user) = @_;

	my $searchtoo = getObject('Slash::SearchToo');

	slashdLog("Backing up index");
	$searchtoo->copyBackup;
	$searchtoo->backup(1);

	slashdLog("Fetching records to index");
	my $records = $searchtoo->getStoredRecords;

	for my $type (keys %$records) {
		my $records_type = $records->{$type};

		my(@iids_d, @delete, @iids_a, @add);
		for my $i (0 .. $#{$records_type}) {
			if ($records_type->[$i]{status} eq 'deleted') {
				push @delete, $records_type->[$i]{id};
				push @iids_d, $records_type->[$i]{iid};
			} else {
				push @add, {
					id	=> $records_type->[$i]{id},
					status	=> $records_type->[$i]{status}
				};
				push @iids_a, $records_type->[$i]{iid};
			}
		}

		$searchtoo->getRecords($type => \@add);

		slashdLog(sprintf( "Deleting %d '$type' records", scalar @delete ));
		my $deleted = $searchtoo->deleteRecords($type => \@delete) || 0;
		slashdLog(sprintf( "Indexing %d '$type' records", scalar @add ));
		my $added = $searchtoo->addRecords($type => \@add) || 0;

		if (@iids_a && @iids_a != $added) {
			slashdLog(sprintf(
				"Warning, expected to index %d, indexed %d",
				scalar(@iids_a), $added
			));
		} else {
			$searchtoo->deleteStoredRecords(\@iids_a);
		}

		if (@iids_d && @iids_d != $deleted) {
			slashdLog(sprintf(
				"Warning, expected to delete %d, deleted %d",
				scalar(@iids_d), $deleted
			));
		} else {
			$searchtoo->deleteStoredRecords(\@iids_d);
		}
	}

	$searchtoo->backup(0);
	$searchtoo->moveLive;

	slashdLog("Moved new index live");
};

1;

