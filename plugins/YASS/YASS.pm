# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: YASS.pm,v 1.9 2002/02/26 01:47:41 jamie Exp $

package Slash::YASS;

use strict;
use Slash;
use Slash::Utility;
use Slash::DB::Utility;

use vars qw($VERSION @EXPORT);
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision: 1.9 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
	my($class, $user) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'YASS'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

sub getURLsSids {
	my ($self) = @_;
	$self->sqlSelectAll("value, sid", "story_param", "name='url'");
}

sub create {
	my ($self, $hash) = @_;
	$hash->{-touched} = "now()";
	$self->sqlInsert($hash);
}

sub success {
	my ($self, $id) = @_;
	my $hash->{-touched} = "now()";
	$self->sqlUpdate($hash, "id = $id");
}

sub setURL {
	my ($self, $id, $url, $rdf) = @_;
	my $hash->{url} = $url;
	$hash->{rdf} = $rdf;
	$self->sqlUpdate($hash, "id = $id");
}

sub exists {
	my ($self, $sid, $url) = @_;
	my $q_url = $self->sqlQuote($url);
	my $q_sid = $self->sqlQuote($sid);
	my $return =  $self->sqlSelect('id', 'yass_sites', "sid = $q_sid AND url = $q_url");
	unless ($return) {
		$return = $self->sqlSelect('sid', 'yass_sites', "sid = $q_sid");
	}
	return $return;
}

sub failed {
	my ($self, $id) = @_;
	my $hash->{-touched} = "now()";
	$self->sqlUpdate($hash, "id = $id");
}


sub getActive {
	my ($self, $limit) = @_;
	my $failures = getCurrentStatic('yass_failures');
	$failures ||= '14';

	my $sid;

	my $order;
	if ($limit) {
		$order = "ORDER BY time DESC LIMIT $limit";
	} else {
		$order = "ORDER BY title ASC";
	}
	my $all = $self->sqlSelectAllHashrefArray(
		"yass_sites.sid as sid, url, title", 
		"yass_sites, stories", 
		"stories.sid = yass_sites.sid and failed < $failures",
		$order);

	return $all;
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__

# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::YASS - YASS system splace

=head1 SYNOPSIS

	use Slash::YASS;

=head1 DESCRIPTION

This is YASS, and just how useful is this to you? Its 
a site link system.

Blah blah blah.

=head1 AUTHOR

Brian Aker, brian@tangent.org

=head1 SEE ALSO

perl(1).

=cut
