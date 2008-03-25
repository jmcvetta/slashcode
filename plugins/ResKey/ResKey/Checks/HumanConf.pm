# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: HumanConf.pm,v 1.1 2008/03/25 18:46:24 pudge Exp $

package Slash::ResKey::Checks::HumanConf;

use warnings;
use strict;

use Slash::Utility;
use Slash::Constants ':reskey';

use base 'Slash::ResKey::Key';

our($VERSION) = ' $Revision: 1.1 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub updateResKey {
	my($self) = @_;
	return unless useHumanConf($self);

	my $user = getCurrentUser();
	return unless $user;

	my $hc = getObject('Slash::HumanConf');
	return unless $hc;

	$hc->updateFormkeyHCValue($user->{state}{hcid}, $self->reskey);
}

sub doCheckCreate {
	my($self) = @_;

	return RESKEY_SUCCESS unless useHumanConf($self);

	my $hc = getObject('Slash::HumanConf');

	if (!$hc || !$hc->createFormkeyHC($self->resname, { frkey => $self->reskey, needs_hc => 1 })) {
		return(RESKEY_DEATH, ["HumanConf failure"]);
	}

	return RESKEY_SUCCESS;
}

sub doCheckTouch {
	my($self) = @_;
	return RESKEY_SUCCESS unless useHumanConf($self);

	my $hc = getObject('Slash::HumanConf');
	if (!$hc || !$hc->reloadFormkeyHC($self->resname, { frkey => $self->reskey, needs_hc => 1 })) {
		return(RESKEY_DEATH, ['hcinvalid']);
	}

	return RESKEY_SUCCESS;
}

sub doCheckUse {
	my($self) = @_;
	return RESKEY_SUCCESS unless useHumanConf($self);

	my $hc = getObject('Slash::HumanConf');
	return(RESKEY_DEATH, ["HumanConf failure"]) if !$hc;

	# form->{hcanswer} 
	my $return = $hc->validFormkeyHC($self->resname, { frkey => $self->reskey, needs_hc => 1 });
	if ($return ne 'ok') {
		$hc->reloadFormkeyHC($self->resname, { frkey => $self->reskey, needs_hc => 1 });
		if ($return =~ /retry/) {
			return(RESKEY_FAILURE, [$return]);
		} else {
			return(RESKEY_DEATH, [$return]);
		}
	}

	return RESKEY_SUCCESS;
}


sub useHumanConf {
	return 1;	# for testing!
	my($self) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();


	return 0 if
			# HumanConf is not running...
		   !$constants->{plugin}{HumanConf}
		|| !$constants->{hc};

	# stolen from comments.pl
	if ($self->resname eq 'comments') {
		return 0 if
				# ...or it's turned off for comments...
			   $constants->{hc_sw_comments} == 0
				# ...or it's turned off for logged-in users
				# and this user is logged-in...
			|| $constants->{hc_sw_comments} == 1
			   && !$user->{is_anon}
				# ...or it's turned off for logged-in users
				# with high enough karma, and this user
				# qualifies.
			|| $constants->{hc_sw_comments} == 2
			   && !$user->{is_anon}
		   	&&  $user->{karma} > $constants->{hc_maxkarma};
	}

	return 1;
}

1;
