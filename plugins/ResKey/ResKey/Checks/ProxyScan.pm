# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: ProxyScan.pm,v 1.2 2005/09/13 21:57:45 pudge Exp $

package Slash::ResKey::Checks::ProxyScan;

use warnings;
use strict;

use Slash::Utility;
use Slash::Constants ':reskey';

use base 'Slash::ResKey::Key';

our($VERSION) = ' $Revision: 1.2 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub _Check {
	my($self) = @_;

	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();

	if ($constants->{"reskey_checks_adminbypass_$self->{resname}"} && $user->{is_admin}) {
		return RESKEY_SUCCESS;
	}

	if ($slashdb->getAL2($user->{srcids}, 'trusted')) {
		my $is_proxy = $slashdb->checkForOpenProxy($user->{srcids}{ip});
		if ($is_proxy) {
			return(RESKEY_DEATH, ['open proxy', {
				unencoded_ip	=> $ENV{REMOTE_ADDR},
				port		=> $is_proxy,
			}]);
		}
	}

	return RESKEY_SUCCESS;
}


1;
