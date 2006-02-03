# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: User.pm,v 1.5 2006/02/03 23:43:46 pudge Exp $

package Slash::ResKey::Checks::User;

use warnings;
use strict;

use Slash::Utility;
use Slash::Constants ':reskey';

use base 'Slash::ResKey::Key';

our($VERSION) = ' $Revision: 1.5 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub doCheck {
	my($self) = @_;

	my $user = getCurrentUser();
	my $check_vars = $self->getCheckVars;

	if ($check_vars->{adminbypass} && $user->{is_admin}) {
		return RESKEY_SUCCESS;
	}

	for my $check (qw(is_admin seclev is_subscriber karma)) {
		my $value = $check_vars->{"user_${check}"};
		if (defined $value && length $value && (!$user->{$check} || $user->{$check} < $value)) {
			return(RESKEY_DEATH, ["$check too low", { needed => $value }]);
		}
	}

	return RESKEY_SUCCESS;
}

1;
