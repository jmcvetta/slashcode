# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: Remarks.pm,v 1.5 2006/02/14 21:30:36 tvroom Exp $

package Slash::Remarks;

=head1 NAME

Slash::Remarks - Perl extension for Remarks


=head1 SYNOPSIS

	use Slash::Remarks;


=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use DBIx::Password;
use Slash;
use Slash::Display;
use Slash::Utility;

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';
use vars qw($VERSION);

($VERSION) = ' $Revision: 1.5 $ ' =~ /\$Revision:\s+([^\s]+)/;

########################################################
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'Remarks'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

########################################################
sub getRemarks {
	my($self, $options) = @_;

	my $max = $options->{max} || 100;

	my $remarks = $self->sqlSelectAllHashrefArray(
		'rid, uid, stoid, time, remark, type, priority',
		'remarks',
		'',
		"ORDER BY rid DESC LIMIT $max"
	);

	return $remarks || [];
}

########################################################
sub createRemark {
	my($self, $remark, $options) = @_;

	my $remark_t = $self->truncateStringForCharColumn($remark, 'remarks', 'remark');

	$self->sqlInsert('remarks', {
		uid		=> $options->{uid}	|| getCurrentAnonymousCoward('uid'),
		stoid		=> $options->{stoid}	|| 0,
		type 		=> $options->{type}	|| 'user',
		priority	=> $options->{priority}	|| 0,
		-time		=> 'NOW()',
		remark		=> $remark_t,
	});
}

########################################################
sub getRemarksStarting {
	my($self, $starting, $options) = @_;
	return [ ] unless $starting;

	my $starting_q = $self->sqlQuote($starting);
	my $type_clause = $options->{type}
		? ' AND type=' . $self->sqlQuote($options->{type})
		: '';

	return $self->sqlSelectAllHashrefArray(
		'rid, stoid, remarks.uid, remark, karma, remarks.type',
		'remarks, users_info',
		"remarks.uid=users_info.uid AND rid >= $starting_q $type_clause"
	);
}

########################################################
sub getUserRemarkCount {
	my($self, $uid, $secs_back) = @_;
	return 0 unless $uid && $secs_back;

	return $self->sqlCount(
		'remarks',
		"uid = $uid
		 AND time >= DATE_SUB(NOW(), INTERVAL $secs_back SECOND)"
	);
}


########################################################
sub displayRemarksTable {
	my($self, $options) = @_;

	$self           ||= getObject('Slash::Remarks');
	$options        ||= {};
	$options->{max} ||= 30;

	my $remarks_ref = $self->getRemarks($options);
	return slashDisplay('display', {
		remarks_ref	=> $remarks_ref,
		print_whole	=> $options->{print_whole},
		print_div	=> $options->{print_div},
		remarks_max	=> $options->{max},
	}, { Page => 'remarks', Return => 1 });
}

########################################################
sub ajaxFetch {
	my($slashdb, $constants, $user, $form) = @_;
	my $self = getObject('Slash::Remarks');
	my $options = {};

	$options->{max} = $form->{limit} || 30;

	if ($form->{op} eq 'remarks_create') {
		$options->{print_div} = 1;
		$self->createRemark($form->{remark}, {
			uid	=> $user->{uid},
			type	=> 'system',
		});
	}
	
	return $self->displayRemarksTable($options);
}

1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id: Remarks.pm,v 1.5 2006/02/14 21:30:36 tvroom Exp $
