#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: zoo.pl,v 1.11 2002/01/05 14:30:16 jamie Exp $

use strict;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:web);
use Slash::Display;
use Slash::Utility;
use Slash::Zoo;
use Slash::XML;
use vars qw($VERSION);

($VERSION) = ' $Revision: 1.11 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub main {
	my $zoo   = getObject('Slash::Zoo');
	my $constants = getCurrentStatic();
	my $slashdb   = getCurrentDB();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $formname = 'zoo';
	my $formkey = $form->{formkey};

	# require POST and logged-in user for these ops
	my $user_ok   = $user->{state}{post} && !$user->{is_anon};

	# possible value of "op" parameter in form
	my $ops = {
		add		=> { 
			check => $user_ok,		
			formkey    => ['formkey_check', 'valid_check'],
			function => \&action		
		},
		'delete'		=> { 
			check => $user_ok,		
			formkey    => ['formkey_check', 'valid_check'],
			function => \&action		
		},
		addcheck		=> { 
			check => $user->{seclev},		
			formkey    => ['generate_formkey'],
			function => 	\&check		
		}, 
		deletecheck		=> { 
			check => $user->{seclev},		
			formkey    => ['generate_formkey'],
			function => \&check		
		},
		check		=> { 
			check => $user->{seclev},		
			formkey    => ['generate_formkey'],
			function => \&check		
		},
		friends		=> { 
			check => 1,			
			function => \&friends		
		},
		fans		=> { 
			check => 1,			
			function => \&fans		
		},
		foes		=> { 
			check => 1,			
			function => \&foes		
		},
		freaks		=> { 
			check => 1,			
			function => \&freaks		
		},
		default		=> { 
			check => 0,			
			function => \&list	
		},
	};

	my ($note, $error_flag);
	my $op = $form->{'op'};
	if ($user->{seclev} < 100) {
		if ($ops->{$op}{formkey}) {
			for my $check (@{$ops->{$op}{formkey}}) {
				$error_flag = formkeyHandler($check, $formname, $formkey, \$note);
				$ops->{$op}{update_formkey} = 1 if $check eq 'formkey_check';
				last if $error_flag;
			}
		}
	}
	if ($error_flag) {
		header();
		print $note;
		footer();
		return;
	}

	if ($ops->{$op}{update_formkey} && $user->{seclev} < 100 && ! $error_flag) {
		# successful save action, no formkey errors, update existing formkey
		# why assign to an unused variable? -- pudge
		my $updated = $slashdb->updateFormkey($formkey, length($ENV{QUERY_STRING}));
	}
	errorLog("zoo.pl error_flag '$error_flag'") if $error_flag;

	if (!$op || !exists $ops->{$op} || !$ops->{$op}->{check}) {
		redirect($constants->{rootdir});
		return;
	}

	$ops->{$op}->{function}->($zoo, $constants, $user, $form, $slashdb);
	footer()
		unless ($form->{content_type} eq 'rss');
}

sub list {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	_printHead("mainhead");

	my $friends = $zoo->getFriends($user->{uid});
	if (@$friends) {
		slashDisplay('plainlist', { friends => $friends });
	} else {
		print getData('nofriends');
	}
}

sub friends {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	my ($uid, $nick);
	if ($form->{uid} || $form->{nick}) {
		$uid = $form->{uid} ? $form->{uid} : $slashdb->getUserUID($form->{nick});
		$nick = $form->{nick} ? $form->{nick} : $slashdb->getUser($uid, 'nickname');
	} else {
		$uid = $user->{uid};
		$nick = $user->{nick};
	}

	my $editable = ($uid == $user->{uid} ? 1 : 0);
	my $friends = $zoo->getFriends($uid); 
		
	if ($form->{content_type} eq 'rss') {
		_rss($friends, $nick, 'friends');
	} else {
		if ($editable) {
			_printHead("yourfriendshead");
		} else {
			_printHead("friendshead", { nickname => $nick });
		}
		
		if (@$friends) {
			slashDisplay('plainlist', { people => $friends, editable => $editable });
		} else {
			if ($editable) {
				print getData('yournofriends');
			} else {
				print getData('nofriends', { nickname => $nick });
			}
		}
	}
}

sub foes {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	my ($uid, $nick);
	if ($form->{uid} || $form->{nick}) {
		$uid = $form->{uid} ? $form->{uid} : $slashdb->getUserUID($form->{nick});
		$nick = $form->{nick} ? $form->{nick} : $slashdb->getUser($uid, 'nickname');
	} else {
		$uid = $user->{uid};
		$nick = $user->{nick};
	}

	my $editable = ($uid == $user->{uid} ? 1 : 0);
	my $foes = $zoo->getFoes($uid); 

	if ($form->{content_type} eq 'rss') {
		_rss($foes, $nick, 'foes');
	} else {
		if ($editable) {
			_printHead("yourfoeshead");
		} else {
			_printHead("foeshead", { nickname => $nick });
		}
		
		if (@$foes) {
			slashDisplay('plainlist', { people => $foes, editable => $editable });
		} else {
			if ($editable) {
				print getData('yournofoes');
			} else {
				print getData('nofoes', { nickname => $nick });
			}
		}
	}
}

sub fans {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	my ($uid, $nick);
	if ($form->{uid} || $form->{nick}) {
		$uid = $form->{uid} ? $form->{uid} : $slashdb->getUserUID($form->{nick});
		$nick = $form->{nick} ? $form->{nick} : $slashdb->getUser($uid, 'nickname');
	} else {
		$uid = $user->{uid};
		$nick = $user->{nick};
	}
	my $editable = ($uid == $user->{uid} ? 1 : 0);
	my $fans = $zoo->getFans($uid);

	if ($form->{content_type} eq 'rss') {
		_rss($fans, $nick, 'fans');
	} else {
		if ($editable) {
			_printHead("yourfanshead");
		} else {
			_printHead("fanshead",{ nickname => $nick });
		}
		if (@$fans) {
			slashDisplay('plainlist', { people => $fans, editable => $editable });
		} else {
			if ($editable) {
				print getData('yournofans');
			} else {
				print getData('nofans', { nickname => $nick });
			}
		}
	}
}

sub freaks {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	my ($uid, $nick);
	if ($form->{uid} || $form->{nick}) {
		$uid = $form->{uid} ? $form->{uid} : $slashdb->getUserUID($form->{nick});
		$nick = $form->{nick} ? $form->{nick} : $slashdb->getUser($uid, 'nickname');
	} else {
		$uid = $user->{uid};
		$nick = $user->{nick};
	}
	my $editable = ($uid == $user->{uid} ? 1 : 0);
	my $freaks = $zoo->getFreaks($uid);

	if ($form->{content_type} eq 'rss') {
		_rss($freaks, $nick, 'freaks');
	} else {
		if ($editable) {
			_printHead("yourfreakshead");
		} else {
			_printHead("freakshead",{ nickname => $nick });
		}
		if (@$freaks) {
			slashDisplay('plainlist', { people => $freaks, editable => $editable });
		} else {
			if ($editable) {
				print getData('yournofreaks');
			} else {
				print getData('nofreaks', { nickname => $nick });
			}
		}
	}
}

sub action {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	if ($form->{uid} == $user->{uid} || $form->{uid} == $constants->{anonymous_coward_uid}  ) {
			_printHead("mainhead");
			print getData("over_socialized");
			return;
	} else {
		if ( $form->{op} eq 'delete' || $form->{type} eq 'neutral') {
			if ($form->{uid}) {
				$zoo->delete($user->{uid}, $form->{uid});
			} else {
				for my $uid (grep { $_ = /^del_(\d+)$/ ? $1 : 0 } keys %$form) {
					$zoo->delete($user->{uid}, $uid);
				}
			}
		} else {
			if ($form->{uid}) {
				if ($form->{type} eq 'foe') {
					$zoo->setFoe($user->{uid}, $form->{uid});
				} elsif ($form->{type} eq 'friend') {
					$zoo->setFriend($user->{uid}, $form->{uid});
				}
			}
		}
	}
	# This is just to make sure the next view gets it right
	if ($form->{type} eq 'foe') {
		redirect($constants->{rootdir} . "/my/foes/");
		return;
	} else {
		redirect($constants->{rootdir} . "/my/friends/");
		return;
	}
}

sub check {
	my($zoo, $constants, $user, $form, $slashdb) = @_;

	_printHead("mainhead");
	if ($form->{uid}) {
		if ($zoo->count($form->{uid}) > $constants->{people_max}) {
			print getData("over_socialized");
			return 0;
		}
		
		if ($form->{uid} == $user->{uid} || $form->{uid} == $constants->{anonymous_coward_uid}  ) {
			print getData("no_go");
			return 0;
		}

		my $type =  $form->{op} eq 'deletecheck' ? 'neutral' : ($form->{type} eq 'foe' ? 'foe' : 'friend');
		my $nickname = $slashdb->getUser($form->{uid}, 'nickname');
		slashDisplay('confirm', { 
			uid => $form->{uid},
			nickname => $nickname,
			type => $type,
		});
	} else {
		print getData("no_uid");
	}
}

sub _printHead {
	my($head, $data) = @_;
	my $title = getData($head, $data);
	header($title);
	slashDisplay("zoohead", { title => $title });
}

sub _rss {
	my ($entries, $nick, $type) = @_;
	my $constants = getCurrentStatic();
	my @items;
	for my $entry (@$entries) {
		push @items, {
			title	=> $entry->[1],
			'link'	=> ($constants->{absolutedir} . '/~' . fixparam($entry->[1])  . "/"),
		};
	}

	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} $nick's ${type}",
			'link'		=> "$constants->{absolutedir}/",
			description	=> "$constants->{sitename} $nick's ${type}",
		},
		image	=> 1,
		items	=> \@items
	});
}

createEnvironment();
main();
1;
