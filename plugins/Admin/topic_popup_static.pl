#!/usr/bin/perl -w

# $Id: topic_popup_static.pl,v 1.1 2004/06/25 06:45:43 pudge Exp $

use strict;

use Slash::Constants ':slashd';
use Slash::Admin::PopupTree;

use vars qw( %task $me );

# these files will almost never change, but it doesn't cost much to run,
# so once an hour is fine
$task{$me}{timespec} = '50 * * * *';
$task{$me}{timespec_panic_1} = ''; # if panic, we can wait
$task{$me}{on_startup} = 1;
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	for my $type ('css', 'js') {
		my $new = Slash::Admin::PopupTree::getPopupTree({}, {}, { type => $type, Nocomm => 1 });
		next unless $new;

		my $file = catfile($constants->{basedir}, "admin-topic-popup.$type");
		save2file($file, $new);
	}
};

1;
