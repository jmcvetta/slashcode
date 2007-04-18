#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: im_messages.pl,v 1.3 2007/04/18 16:29:14 entweichen Exp $

use strict;

use Slash;
use Slash::Constants ':slashd';
use Slash::Utility;
use Net::OSCAR ':standard';
use Digest::MD5;

use vars qw(%task $me);

$! = 0;
$task{$me}{timespec} = '* * * * *';
$task{$me}{on_startup} = 1;
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {

my ($virtual_user, $constants, $slashdb, $user) = @_;
my ($exit_flag, $online);

	$SIG{INT} = $SIG{TERM} = sub { ++$exit_flag; };

	my $in;
	map { $in .= "'$_',"; } getMessageCodesByType("IM");
	chop($in);
	
	my $sysmessage_code = getMessageCodeByName("System Messages");

	my $im_mode = getMessageDeliveryByName("IM");
	
	my $screenname = $slashdb->sqlSelect("value", "vars", "name = 'im_screenname'");
	
	my $oscar = Net::OSCAR->new();
	$oscar->set_callback_auth_challenge(\&auth_challenge);
	$oscar->set_callback_signon_done(sub { ++$online; });
	$oscar->signon(screenname => $screenname, password => undef);
	$oscar->timeout(30);

	until ($exit_flag) {
		$oscar->do_one_loop();
		
		# Wait until we're fully online (signon_done() is called).
		next unless $online;
	
		# Pull out all IM compatible messages	
		my $messages =
			$slashdb->sqlSelectAllHashref("id", "id, user, code, message", "message_drop", "code IN($in)");

		foreach my $id (keys %$messages) {
			my $im_names;
			# If it's System Message, pull out admins. Exclusive to forwarding Jabber messages.
			if ($messages->{$id}->{"code"} eq $sysmessage_code->{"code"}) {
				$im_names =
					$slashdb->sqlSelectColArrayref("uid", "users", "seclev >= '" . $sysmessage_code->{"seclev"} . "'");
			}
			else {
				# Single user
				push(@$im_names, $messages->{$id}->{"user"});
			}

			foreach my $name (@$im_names) {
				# Skip this person if they don't want IM messages for this code.
				next if ($im_mode != getUserMessageDeliveryPref($name, $messages->{$id}->{"code"}));
				
				# Look up IM nick for this uid
				my $im_name =
					$slashdb->sqlSelect("value", "users_param", "uid = '" . $name . "' and name = 'aim'");
				push(@{$messages->{$id}->{"im_name"}}, $im_name) if $im_name;
			}
			
			foreach my $name (@{$messages->{$id}->{"im_name"}}) {
				#$oscar->send_im($name, $messages->{$id}->{"message"});
				sleep(1);
			}
			
			#$slashdb->sqlDelete("message_drop", "id = " . $messages->{$id}->{"id"}) if @{$messages->{$id}->{"im_name"}};

			delete $messages->{$id};
		}
	}

	$oscar->signoff();
	
	return;

};


sub getMessageCodesByType {

my ($type) = @_;
my @message_codes = ();

	my $slashdb = getCurrentDB();
	my $code = $slashdb->sqlSelect("bitvalue", "message_deliverymodes", "name = '$type'");
	my $delivery_codes =
		$slashdb->sqlSelectAllHashref("code", "code, delivery_bvalue", "message_codes", "delivery_bvalue >= $code");
	foreach my $delivery_code (keys %$delivery_codes) {
		push(@message_codes, $delivery_codes->{$delivery_code}->{"code"})
			if ($delivery_codes->{$delivery_code}->{"delivery_bvalue"} & $code);
	}

	return(@message_codes);

}


sub getMessageCodeByName {

my ($name) = @_;

	my $slashdb = getCurrentDB();
	my $code = $slashdb->sqlSelectHashref("code, seclev", "message_codes", "type = '$name'");

	return($code);

}


sub getMessageDeliveryByName {

my ($name) = @_;

	my $slashdb = getCurrentDB();
	my $code = $slashdb->sqlSelect("code", "message_deliverymodes", "name = '$name'");

	return($code);

}


sub getUserMessageDeliveryPref {

my ($uid, $code) = @_;

	my $slashdb = getCurrentDB();
	my $pref = $slashdb->sqlSelect("mode", "users_messages", "uid = '$uid' and code = '$code'");

	return($pref);

}


sub auth_challenge {

my ($oscar, $challenge, $hash) = @_;

	my $slashdb = getCurrentDB();
	my $password = $slashdb->sqlSelect("value", "vars", "name = 'im_password'");
	my $md5 = Digest::MD5->new;
	$md5->add($challenge);
	$md5->add($password);
	$md5->add($hash);
	$oscar->auth_response($md5->digest, 1);

}

1;
