#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: blob.pl,v 1.1 2003/02/21 19:49:35 brian Exp $

use strict;
use Slash;
use Slash::Search;
use Slash::Display;
use Slash::Utility;
use Slash::XML;

#################################################################
sub main {
	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $blob = getObject("Slash::Blob", { db_type => 'reader' });
	
	unless ($form->{id}) {
		redirect("404.pl");
	}
	
	my $data = $blob->get($form->{id});
	if (!$data || $user->{seclev} < $data->{seclev}) {
		redirect("404.pl");
	}

	my $r = Apache->request;
	$r->header_out('Cache-Control', 'private');
	$r->content_type($data->{mime_type});
	$r->status(200);
	$r->send_http_header;
	$r->rflush;
	$r->print($data->{data});
	$r->rflush;
	$r->status(200);
}

#################################################################
1;
