# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: Apache.pm,v 1.6 2001/11/03 03:08:48 brian Exp $

package Slash::Apache;

use strict;
use Apache;
use Apache::SIG ();
use Apache::ModuleConfig;
use Apache::Constants qw(:common);
use Slash::DB;
use Slash::Display;
use Slash::Utility;
require DynaLoader;
require AutoLoader;
use vars qw($REVISION $VERSION @ISA $USER_MATCH);

@ISA		= qw(DynaLoader);
$VERSION   	= '2.001001';  # v2.1.1
($REVISION)	= ' $Revision: 1.6 $ ' =~ /\$Revision:\s+([^\s]+)/;

$USER_MATCH = qr{ \buser=(?!	# must have user, but NOT ...
	(?: nobody | %[20]0 )?	# nobody or space or null or nothing ...
	(?: \s | ; | $ )	# followed by whitespace, ;, or EOS
)}x;

bootstrap Slash::Apache $VERSION;

# BENDER: There's nothing wrong with murder, just as long
# as you let Bender whet his beak.

sub SlashVirtualUser ($$$) {
	my($cfg, $params, $user) = @_;

	# In case someone calls SlashSetVar before we have done the big mojo -Brian
	my $overrides = $cfg->{constants};

	createCurrentVirtualUser($cfg->{VirtualUser} = $user);
	createCurrentDB		($cfg->{slashdb} = Slash::DB->new($user));
	createCurrentStatic	($cfg->{constants} = $cfg->{slashdb}->getSlashConf($user));

	# placeholders ... store extra placeholders in DB?  :)
	for (qw[user form themes template cookie objects cache]) {
		$cfg->{$_} = '';
	}

	$cfg->{constants}{form_override} ||= {};

	if ($overrides) {
		@{$cfg->{constants}}{keys %$overrides} = values %$overrides;
	}

	my $anonymous_coward = $cfg->{slashdb}->getUser(
		$cfg->{constants}{anonymous_coward_uid}
	);

	# Lets just do this once
	my $timezones = $cfg->{slashdb}->getDescriptions('tzcodes');
	$anonymous_coward->{off_set} = $timezones->{ $anonymous_coward->{tzcode} };
	my $dateformats = $cfg->{slashdb}->getDescriptions('datecodes');
	$anonymous_coward->{'format'} = $dateformats->{ $anonymous_coward->{dfid} };

	createCurrentAnonymousCoward($cfg->{anonymous_coward} = $anonymous_coward);
	createCurrentUser($anonymous_coward);

	$cfg->{menus} = $cfg->{slashdb}->getMenus();
	# If this is not here this will go poorly.
	$cfg->{slashdb}->{_dbh}->disconnect;
}

sub SlashSetVar ($$$$) {
	my($cfg, $params, $key, $value) = @_;
	$cfg->{constants}{$key} = $value;
}

sub SlashSetForm ($$$$) {
	my($cfg, $params, $key, $value) = @_;
	$cfg->{constants}{form_override}{$key} = $value;
}

sub SlashCompileTemplates ($$$) {
	my($cfg, $params, $flag) = @_;
	return unless $flag;

	# set up defaults
	my $slashdb	= $cfg->{slashdb};
	my $constants	= $cfg->{constants};

	# caching must be on, along with unlimited cache size
	return unless $constants->{cache_enabled}
		  && !$constants->{template_cache_size};

	print STDERR "$cfg->{VirtualUser} ($$): Compiling All Templates Begin\n";

	my $templates = $slashdb->getTemplateNameCache();

	# temporarily turn off warnings and errors, see errorLog()
	# This is normally considered a big no no inside of Apache
	# since how will its own signal handlers be put back in place?
	# -Brian
	# what do you mean, put back in place?  when the function
	# finishes, they are all automatically reverted, because
	# of local() -- pudge
	local $Slash::Utility::NO_ERROR_LOG = 1;
	local $SIG{__WARN__} = 'IGNORE';
	local $slashdb->{_dbh}{PrintError};

	# this will call every template in turn, and it will
	# then be compiled; now, we will get errors in
	# the error log for templates that don't check
	# the input values; that can't easily be helped
	for my $t (keys %$templates) {
		my($name, $page, $section) = split /$;/, $t;
		slashDisplay($name, 0, {
			Page	=> $page,
			Section	=> $section,
			Return	=> 1,
			Nocomm	=> 1
		});
	}

	print STDERR "$cfg->{VirtualUser} ($$): Compiling All Templates Done\n";

	$cfg->{template} = Slash::Display::get_template(0, 0, 1);
	# let's make sure
	$slashdb->{_dbh}->disconnect;
}

sub IndexHandler {
	my($r) = @_;

	return DECLINED unless $r->is_main;
	my $constants = getCurrentStatic();
	my $uri = $r->uri;
	if ($constants->{rootdir}) {
		my $path = URI->new($constants->{rootdir})->path;
		$uri =~ s/^\Q$path//;
	}

	# Comment this in if you want to try having this do the right
	# thing dynamically
	# my $slashdb = getCurrentDB();
	# my $dbon = $slashdb->sqlConnect(); 
	my $dbon = ! -e "$constants->{datadir}/dboff";

	if ($uri eq '/') {
		my $basedir = $constants->{basedir};

		# $USER_MATCH defined above
		if ($dbon && $r->header_in('Cookie') =~ $USER_MATCH) {
			$r->uri('/index.pl');
			$r->filename("$basedir/index.pl");
			return OK;
		} else {
			$r->uri('/index.shtml');
			$r->filename("$basedir/index.shtml");
			writeLog('shtml');
			return OK;
		}
	}

	if ($uri eq '/authors.pl') {
		my $filename = $r->filename;
		my $basedir  = $constants->{basedir};

		if (!$dbon || $r->header_in('Cookie') !~ $USER_MATCH) {
			$r->uri('/authors.shtml');
			$r->filename("$basedir/authors.shtml");
			writeLog('shtml');
			return OK;
		}
	}

	if ($uri eq '/hof.pl') {
		my $basedir  = $constants->{basedir};

		$r->uri('/hof.shtml');
		$r->filename("$basedir/hof.shtml");
		writeLog('shtml');
		return OK;
	}

	if (!$dbon && $uri !~ /\.shtml/) {
		my $basedir  = $constants->{basedir};

		$r->uri('/index.shtml');
		$r->filename("$basedir/index.shtml");
		writeLog('shtml');
		$r->notes('SLASH_FAILURE' => "db"); # You should be able to find this in other processes
		return OK;
	}

	return DECLINED;
}

sub DESTROY { }


1;

__END__

=head1 NAME

Slash::Apache - Apache Specific handler for Slash

=head1 SYNOPSIS

	use Slash::Apache;

=head1 DESCRIPTION

This is what creates the SlashVirtualUser command for us
in the httpd.conf file.

=head1 SEE ALSO

Slash(3).

=cut
