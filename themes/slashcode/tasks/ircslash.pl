#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: ircslash.pl,v 1.4 2004/10/28 14:57:30 jamiemccarthy Exp $

use strict;

use Data::Dumper;

use Slash;
use Slash::Constants ':slashd';
use Slash::Display;
use Slash::Utility;

use vars qw(
	%task	$me	$task_exit_flag
	$irc	$conn	$nick	$channel
	$next_remark_id	$next_handle_remarks
	$hushed
	%stoid
);

$task{$me}{timespec} = '* * * * *';
$task{$me}{on_startup} = 1;
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;
	return unless $constants->{ircslash};
	require Net::IRC;
	my $start_time = time;

	ircinit();

	$next_handle_remarks = 0;
	while (!$task_exit_flag) {
		$irc->do_one_loop();
		Time::HiRes::sleep(0.5); # don't waste CPU
		if (time() >= $next_handle_remarks) {
			my $remark_delay = $constants->{ircslash_remarks_delay} || 5;
			$next_handle_remarks = time() + $remark_delay;
			handleRemarks();
		}
	}

	ircshutdown();

	return sprintf("got SIGUSR1, exiting after %d seconds", time - $start_time);
};

sub ircinit {
	my $constants = getCurrentStatic();
	my $server =	$constants->{ircslash_server}
				|| 'irc.slashnet.org';
	my $port =	$constants->{ircslash_port}
				|| 6667;
	my $ircname =	$constants->{ircslash_ircname}
				|| "$constants->{sitename} slashd";
	my $username =	$constants->{ircslash_username}
				|| ( map { s/\W+//g; $_ } $ircname )[0];
	$nick =		$constants->{ircslash_nick}
				|| substr($username, 0, 9);
	my $ssl =	$constants->{ircslash_ssl}
				|| 0;
	
	$hushed = 0;

	$irc = new Net::IRC;
	$conn = $irc->newconn(	Nick =>		$nick,
				Server =>	$server,
				Port =>		$port,
				Ircname =>	$ircname,
				Username =>	$username,
				SSL =>		$ssl		);

	$conn->add_global_handler(376,	\&on_connect);
	$conn->add_global_handler(433,	\&on_nick_taken);
	$conn->add_handler('msg',	\&on_msg);
	$conn->add_handler('public',	\&on_public);
}

sub ircshutdown {
	slashdLog("got SIGUSR1, quitting");
	eval {
		$conn->quit("exiting");
	};
	if ($@) {
		slashdLog("error on quit: $@");
	}
	eval {
		$conn->disconnect();
	};
	if ($@) {
		slashdLog("error on disconnect: $@");
	}
}

sub on_connect {
	my($self) = @_;
	my $constants = getCurrentStatic();
	$channel = $constants->{ircslash_channel} || '#ircslash';
	my $password = $constants->{ircslash_channel_password} || '';
	slashdLog("joining $channel" . ($password ? " (with password)" : ""));
	$self->join($channel, $password);
}

sub on_nick_taken {
	my($self) = @_;
	my $constants = getCurrentStatic();
	$nick = $constants->{ircslash_nick} if $constants->{ircslash_nick};
	$nick .= int(rand(10));
	$self->nick($nick);
}

# The only response right now to a private message is to "pong" it
# if it is a "ping".

sub on_msg {
	my($self, $event) = @_;

	my($arg) = $event->args();
	if ($arg =~ /ping/i) {
		$self->privmsg($nick, "pong");
	}
}

sub on_public {
	my($self, $event) = @_;
	my $constants = getCurrentStatic();

	my($arg) = $event->args();
	if (my($cmd) = $arg =~ /^$nick\b\S*\s*(.+)/) {
		handleCmd($self, $cmd, $event);
	}
}

############################################################

sub getIRCData {
	my($value, $hashref) = @_;
	return getData($value, { data => $hashref }, 'ircslash');
}

############################################################

{
my %cmds = (
	hush		=> \&cmd_hush,
	unhush		=> \&cmd_unhush,
	ignore		=> \&cmd_ignore,
	unignore	=> \&cmd_unignore,
	'exit'		=> \&cmd_exit,
);
sub handleCmd {
	my($self, $cmd, $event) = @_;
	my $responded = 0;
	for my $key (sort keys %cmds) {
		if (my($text) = $cmd =~ /\b$key\b\S*\s*(.*)/i) {
			my $func = $cmds{$key};
			&$func($self, {
				text	=> $text,
				key	=> $key,
				event	=> $event,
			});
			$responded = 1;
			last;
		}
	}
	# OK, none of those commands matched.  Try the template, or
	# our default response.
	if (!$responded) {
		# See if the template wants to field this.
		my $cmd_lc = lc($cmd);
		my $text = slashDisplay('responses',
			{ value => $cmd_lc },
			{ Page => 'ircslash', Return => 1, Nocomm => 1 });
		$text =~ s/^\s+//; $text =~ s/\s+$//;
		if ($text) {
			$self->privmsg($channel, $text);
		}
	}
}
}

sub cmd_hush {
	my($self, $info) = @_;
	if (!$hushed) {
		$hushed = 1;
		slashdLog("hushed: " . Dumper($info));
		$self->nick("$nick-hushed");
	}
}

sub cmd_unhush {
	my($self, $info) = @_;
	if ($hushed) {
		$hushed = 0;
		slashdLog("unhushed: " . Dumper($info));
		$self->nick("$nick");
	}
}

sub cmd_exit {
	my($self, $info) = @_;
	$self->privmsg($channel, getIRCData('exiting'));
	$task_exit_flag = 1;
}

sub cmd_ignore {
	my($self, $info) = @_;
	my($uid) = $info->{text} =~ /(\d+)/;
	my $slashdb = getCurrentDB();
	my $user = $slashdb->getUser($uid);
	if (!$user || !$user->{uid}) {
		$self->privmsg($channel, getIRCData('nosuchuser', { uid => $uid }));
	} elsif ($user->{noremarks}) {
		$self->privmsg($channel, getIRCData('alreadyignoring',
			{ nickname => $user->{nickname}, uid => $uid }));
	} else {
		$slashdb->setUser($uid, { noremarks => 1 });
		$self->privmsg($channel, "Ignoring $user->{nickname} ($uid)");
		slashdLog("ignoring $uid");
	}
}

sub cmd_unignore {
	my($self, $info) = @_;
	my($uid) = $info->{text} =~ /(\d+)/;
	my $slashdb = getCurrentDB();
	my $user = $slashdb->getUser($uid);
	if (!$user || !$user->{uid}) {
		$self->privmsg($channel, "No such user $uid");
	} elsif (!$user->{noremarks}) {
		$self->privmsg($channel, "Wasn't ignoring $user->{nickname} ($uid)");
	} else {
		$slashdb->setUser($uid, { noremarks => undef });
		$self->privmsg($channel, "No longer ignoring $user->{nickname} ($uid)");
		slashdLog("unignored $uid");
	}
}

############################################################

sub handleRemarks {
	my $slashdb = getCurrentDB();
	return if $hushed;

	my $constants = getCurrentStatic();
	$next_remark_id ||= $slashdb->getVar('ircslash_nextremarkid', 'value', 1) || 1;

	my $remarks_ar = $slashdb->getRemarksStarting($next_remark_id);
	return unless $remarks_ar && @$remarks_ar;

	my %story = ( );
	my %stoid_count = ( );
	my %uid_count = ( );
	my $max_rid = 0;
	for my $remark_hr (@$remarks_ar) {
		my $stoid = $remark_hr->{stoid};
		$stoid_count{$stoid}++;
		$story{$stoid} = $slashdb->getStory($stoid);
		my $uid = $remark_hr->{uid};
		$uid_count{$uid}++;
		$max_rid = $remark_hr->{rid} if $remark_hr->{rid} > $max_rid;
	}
	
	# First pass:  outright strip out remarks from abusive users
	my %uid_blocked = ( );
	for my $uid (keys %uid_count) {
		# If a user's been ignored, block it.
		my $remark_user = $slashdb->getUser($uid);
		if ($remark_user->{noremarks}) {
			$uid_blocked{$uid} = 1;
		}
		# Or if a user has sent more than this many remarks in a day.
		elsif ($slashdb->getUserRemarkCount($uid, 86400      ) > $constants->{ircslash_remarks_max_day}) {
			$uid_blocked{$uid} = 1;
		}
		# Or if a user has sent more than this many remarks in a month.
		elsif ($slashdb->getUserRemarkCount($uid, 86400 *  30) > $constants->{ircslash_remarks_max_month}) {
			$uid_blocked{$uid} = 1;
		}
		# Or if a user has sent more than this many remarks in a year.
		elsif ($slashdb->getUserRemarkCount($uid, 86400 * 365) > $constants->{ircslash_remarks_max_year}) {
			$uid_blocked{$uid} = 1;
		}
	}

	# We should have a second pass in here to delay/join up remarks
	# about stories that are getting lots of remarks, so we don't
	# hear over and over about the same story.
	my $regex = regexSid();
	my $sidprefix = "$constants->{absolutedir_secure}/article.pl?sid=";
	STORY: for my $stoid (sort { $stoid_count{$a} <=> $stoid_count{$b} } %stoid_count) {
		my $url = "$sidprefix$story{$stoid}{sid}";
		my $remarks = "<$url>";
		my $do_send_msg = 0;
		my @stoid_remarks =
			grep { $_->{stoid} == $stoid }
			grep { ! $uid_blocked{$_->{uid}} }
			@$remarks_ar;
		REMARK: for my $i (0..$#stoid_remarks) {
			my $remark_hr = $stoid_remarks[$i];
			next if $uid_blocked{$remark_hr->{uid}};
			if ($i >= 3) {
				# OK, that's enough about this one story.
				# Summarize the rest.
				$remarks .= " (and " . (@stoid_remarks-$i) . " more)";
				last REMARK;
			}
			$do_send_msg = 1;
			$remarks .= " $remark_hr->{uid}:";
			if ($remark_hr->{remark} =~ $regex) {
				$remarks .= qq{<$sidprefix$remark_hr->{remark}>};
			} else {
				$remarks .= qq{"$remark_hr->{remark}"};
			}
		}
		if ($do_send_msg) {
			$conn->privmsg($channel, $remarks);
			# Every time we post remarks into the channel, we
			# wait a little longer before checking and sending
			# again.  This is so we don't flood.
			$next_handle_remarks += 20;
		}
	}
	$next_remark_id = $max_rid + 1;
	$slashdb->setVar('ircslash_nextremarkid', $next_remark_id);
}

1;

