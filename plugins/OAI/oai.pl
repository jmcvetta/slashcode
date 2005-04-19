#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: oai.pl,v 1.1 2005/04/19 20:32:13 pudge Exp $

use strict;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:web);
use Slash::Display;
use Slash::Utility;
use Slash::XML;
use vars qw($VERSION);

($VERSION) = ' $Revision: 1.1 $ ' =~ /\$Revision:\s+([^\s]+)/;


sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $gSkin     = getCurrentSkin();

	my $allowed = 1;  # XXX

	if (!$allowed) {
		redirect("$gSkin->{rootdir}/");
		return;
	}

	my $request = $form->{verb};
	my %args;
	for (keys %$form) {
		next if /^(?:verb|query_apache)$/;
		$args{$_} = $form->{$_};
	}

	xmlDisplay('OAI', {
		request => $request,
		args	=> \%args
	});
}

createEnvironment();
main();

1;
