#!/usr/bin/perl -w

# $Id: topic_popup_static.pl,v 1.2 2004/06/29 17:18:50 pudge Exp $

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

	Slash::Utility::Anchor::getSkinColors();
	for my $type ('css', 'js') {
		my $new = Slash::Admin::PopupTree::getPopupTree({}, {}, { type => $type, Nocomm => 1 });
		next unless $new;

		my $file = catfile($constants->{basedir}, "admin-topic-popup.$type");
		save2file($file, $new);
	}
};

1;
