# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: AnonNoPost.pm,v 1.4 2005/09/14 18:59:12 pudge Exp $

package Slash::ResKey::Checks::AL2::AnonNoPost;

use warnings;
use strict;

use Slash::ResKey::Checks::AL2;
use Slash::Utility;
use Slash::Constants ':reskey';

use base 'Slash::ResKey::Key';

our($VERSION) = ' $Revision: 1.4 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub _Check {
	my($self) = @_;

	my $user = getCurrentUser();
	my $form = getCurrentForm();

	if ($user->{is_anon} || $form->{postanon}) {
		return AL2Check(
			$self, 'nopost',
			{ uid => getCurrentAnonymousCoward('uid') },
		);
	} else {
		return RESKEY_NOOP;
	}
}

1;
