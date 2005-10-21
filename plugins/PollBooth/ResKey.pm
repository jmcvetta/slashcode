# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: ResKey.pm,v 1.1 2005/10/21 18:22:56 pudge Exp $

package Slash::PollBooth::ResKey;

use warnings;
use strict;

use Digest::MD5 'md5_hex';
use Slash::Utility;
use Slash::Constants ':reskey';

use base 'Slash::ResKey::Key';

our($VERSION) = ' $Revision: 1.1 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub doCheck {
	my($self) = @_;

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my $qid = $self->opts->{qid};

	return(RESKEY_DEATH, ['no qid', {}, 'pollBooth']) unless $qid;

	my $md5;
	if ($constants->{poll_fwdfor}) {
		$md5 = md5_hex($ENV{REMOTE_ADDR} . $ENV{HTTP_X_FORWARDED_FOR});
	} else {
		$md5 = md5_hex($ENV{REMOTE_ADDR});
	}
	my $qid_quoted = $slashdb->sqlQuote($qid);

	# Yes, qid/id/uid is a key in pollvoters.
	my($voters) = $slashdb->sqlSelect('id', 'pollvoters',
		"qid=$qid_quoted AND id='$md5' AND uid=$user->{uid}"
	);

	if ($voters) {
		return(RESKEY_DEATH, ['already voted', {}, 'pollBooth']);
	}

	return RESKEY_SUCCESS;
}

1;
