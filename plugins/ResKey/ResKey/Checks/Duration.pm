# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: Duration.pm,v 1.1 2005/06/27 23:31:40 pudge Exp $

package Slash::ResKey::Checks::Duration;

use warnings;
use strict;

use Slash::Utility;
use Slash::Constants ':reskey';

use base 'Slash::ResKey';

our($VERSION) = ' $Revision: 1.1 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub _Check {
	my($self) = @_;

	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();

	# maximum uses per timeframe
	{
		my $max_uses = $constants->{"reskey_checks_duration_max-uses_$self->{resname}"};
		my $limit = $constants->{"reskey_checks_duration_timeframe_$self->{resname}"};
		if ($max_uses && $limit) {
			my $where = $self->_whereUser;
			$where .= ' AND is_alive="no" AND ';
			$where .= "submit_ts > DATE_SUB(NOW(), INTERVAL $limit SECOND)";

			my $rows = $slashdb->sqlCount('reskeys', $where);
			if ($rows >= $max_uses) {
				return(RESKEY_DEATH, ['too many uses', {
					timeframe	=> $limit,
					max_uses	=> $max_uses,
					uses		=> $rows
				}]);
			}
		}
	}

	# minimum duration between uses
	{
		my $limit = $constants->{"reskey_checks_duration_uses_$self->{resname}"};
		if ($limit) {
			my $where = $self->_whereUser;
			$where .= ' AND is_alive="no" AND ';
			$where .= "submit_ts > DATE_SUB(NOW(), INTERVAL $limit SECOND)";

			my $rows = $slashdb->sqlCount('reskeys', $where);
			if ($rows) {
				return(RESKEY_FAILURE, ['use duration too short', { duration => $limit }]);
			}
		}
	}

	# minimum duration between creation and use
	{
		my $limit = $constants->{"reskey_checks_duration_creation-use_$self->{resname}"};
		if ($limit) {
			my $where = "rkid=$self->{rkid}";
			$where .= ' AND is_alive="no" AND ';
			$where .= "create_ts > DATE_SUB(NOW(), INTERVAL $limit SECOND)";

			my $rows = $slashdb->sqlCount('reskeys', $where);
			if ($rows) {
				return(RESKEY_FAILURE, ['creation-use duration too short', { duration => $limit }]);
			}
		}
	}

	return RESKEY_SUCCESS;
}


1;
