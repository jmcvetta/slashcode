#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: pubkey.pl,v 1.7 2005/02/08 23:31:55 pudge Exp $

use strict;
use Slash 2.001;	# require Slash 2.1
use Slash::Display;
use Slash::Utility;
use Slash::XML;
use vars qw($VERSION);

($VERSION) = ' $Revision: 1.7 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub main {
	my $slashdb   = getCurrentDB();
	my $user      = getCurrentUser();
	my $nick      = getCurrentForm('nick');
	my $content;

	my $uid;
	if ($nick) {
		$uid = $slashdb->getUserUID($nick);
		$content = $slashdb->getUser($uid, 'pubkey') || getData('no_key');
	} else {
		$content = getData('no_nick');
	}

	http_send({
		content_type	=> 'text/plain',
		filename	=> "pubkey-$uid.asc",
		do_etag		=> 1,
		dis_type	=> 'inline',
		content		=> $content
	});
}


createEnvironment();
main();
1;
