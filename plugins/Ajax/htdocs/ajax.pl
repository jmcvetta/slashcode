#!/usr/bin/perl
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: ajax.pl,v 1.48 2007/08/08 19:01:06 pudge Exp $

use strict;
use warnings;

use Data::JavaScript::Anon;

use Slash 2.003;	# require Slash 2.3.x
use Slash::Display;
use Slash::Utility;
use vars qw($VERSION);

($VERSION) = ' $Revision: 1.48 $ ' =~ /\$Revision:\s+([^\s]+)/;

##################################################################
sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $gSkin     = getCurrentSkin();

	my $ops = getOps();
	my $op = $form->{op} || '';
#	print STDERR "AJAX1 $$: $user->{uid}, $op\n";

	if (!$ops->{$op}) {
		errorLog("No Ajax op '$op' found");
		$op = 'default';
	}
	
#	print STDERR "AJAX2 $$: $user->{uid}, $op\n";

	$op = 'default' unless $ops->{$op}{function} || (
		$ops->{$op}{class} && $ops->{$op}{subroutine}
	);
#	print STDERR "AJAX3 $$: $user->{uid}, $op\n";

#$Slash::ResKey::DEBUG = 2;

	$ops->{$op}{function} ||= loadCoderef($ops->{$op}{class}, $ops->{$op}{subroutine});
	$op = 'default' unless $ops->{$op}{function};
	
#	print STDERR "AJAX4 $$: $user->{uid}, $op\n";

	$form->{op} = $op;  # save for others to use

	my $reskey_name = $ops->{$op}{reskey_name} || 'ajax_base';
	$ops->{$op}{reskey_type} ||= 'use';
	
#	print STDERR "AJAX5 $$: $user->{uid}, $op\n";

	if ($reskey_name ne 'NA') {
		my $reskey = getObject('Slash::ResKey');
		my $rkey = $reskey->key($reskey_name);
		if (!$rkey) {
			print STDERR scalar(localtime) . " ajax.pl main no rkey for op='$op' name='$reskey_name'\n";
			return;
		}
		if ($ops->{$op}{reskey_type} eq 'createuse') {
			$rkey->createuse;
		} else {
			$rkey->use;
		}
		if (!$rkey->success) {
			if ($form->{msgdiv}) {
				header_ajax({ content_type => 'application/json' });
				(my $msgdiv = $form->{msgdiv}) =~ s/[^\w-]+//g;
				print Data::JavaScript::Anon->anon_dump({
					html	=> { $msgdiv => $rkey->errstr },
				});
			}
			printf STDERR "AJAXE %d: UID:%d, op:%s: %s (%s:%s:%s:%s:%s:%s:%s)\n",
				$$, $user->{uid}, $op, $rkey->errstr, $rkey->reskey,
				$rkey->type, $rkey->resname, $rkey->rkrid, $rkey->code, $rkey->static,
				$user->{srcids}{ 24 };
			return;
		}
	}
#	print STDERR "AJAX6 $$: $user->{uid}, $op\n";

	my $options = {};
	my $retval = $ops->{$op}{function}->(
		$slashdb, $constants, $user, $form, $options
	);

	if ($retval) {
		header_ajax($options);
		print $retval;
	}

	# XXX: do anything on error?  a standard error dialog?  or fail silently?
}

##################################################################
sub getSectionPrefsHTML {
	my($slashdb, $constants, $user, $form) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my %story023_default = (
		author	=> { },
		nexus	=> { },
		topic	=> { },
	);

	my %prefs = ( );

	for my $field (qw(
		story_never_nexus 	story_always_nexus	story_brief_always_nexus
		story_full_brief_nexus	story_full_best_nexus	story_brief_best_nexus
	)) {
		for my $id (
			grep /^\d+$/,
			split /,/,
			($user->{$field} || "")
		) {
			$prefs{$field}{$id} = 1;
		}
	}

	my $topic_tree = $reader->getTopicTree();
	my $nexus_tids_ar = $reader->getStorypickableNexusChildren($constants->{mainpage_nexus_tid});
	my $nexus_hr = { };
	my $skins = $reader->getSkins();

	my $hide_nexus;
	foreach(keys %$skins) {
		$hide_nexus->{$skins->{$_}->{nexus}} = 1 if $skins->{$_}{skinindex} eq "no";
	}

	for my $tid (@$nexus_tids_ar) {
		$nexus_hr->{$tid} = $topic_tree->{$tid}{textname} if !$hide_nexus->{$tid};
	}
	my @nexustid_order = sort {
		($b == $constants->{mainpage_nexus_tid}) <=> ($a == $constants->{mainpage_nexus_tid})
		||
		lc $nexus_hr->{$a} cmp lc $nexus_hr->{$b}
	} keys %$nexus_hr;

	my $first_val = "";
	my $multiple_values = 0;
	for my $tid (@nexustid_order) {
		if ($prefs{story_never_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 0;
		} elsif ($prefs{story_always_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 5;
		} elsif ($prefs{story_full_brief_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 4;
		} elsif ($prefs{story_brief_always_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 3;
		} elsif ($prefs{story_full_best_nexus}{$tid}) {
			$story023_default{nexus}{$tid} = 2;
		} elsif ($prefs{story_brief_best_nexus}) {
			$story023_default{nexus}{$tid} = 1;
		} else {
			if ($constants->{brief_sectional_mainpage}) {
				$story023_default{nexus}{$tid} = 4;
			} else {
				$story023_default{nexus}{$tid} = 2;
			}
		}
		$first_val = $story023_default{nexus}{$tid} if $first_val eq "";
		$multiple_values = 1 if $story023_default{nexus}{$tid} != $first_val;
	}

	my $master_value = !$multiple_values ? $first_val : "";

	return slashDisplay("sectionpref",
		{
			nexusref		=> $nexus_hr,
			nexustid_order		=> \@nexustid_order,
			story023_default	=> \%story023_default,
			multiple_values		=> $multiple_values,
			master_value		=> $master_value,
		},
		{ Return => 1 }
	);
}

sub setSectionNexusPrefs() {
	my ($slashdb, $constants, $user, $form) = @_;
	
	my $nexus_tids_ar = $slashdb->getStorypickableNexusChildren($constants->{mainpage_nexus_tid}, 1);

	my @story_always_nexus 		= split ",", $user->{story_always_nexus} || "";
	my @story_full_brief_nexus 	= split ",", $user->{story_full_brief_nexus} || "";
	my @story_brief_always_nexus 	= split ",", $user->{story_brief_always_nexus} || "";
	my @story_full_best_nexus 	= split ",", $user->{story_full_best_nexus} || "";
	my @story_brief_best_nexus 	= split ",", $user->{story_brief_best_nexus} || "";
	my @story_never_nexus 		= split ",", $user->{story_never_nexus} || "";

	my $update = {};

	foreach my $key (keys %$form) {
		my $value = $form->{$key};
		if ($key =~ /^nexustid(\d+)$/) {
			my $tid = $1;
			if ($value >= 0 && $value <= 5 && $value =~ /^\d+$/) {
				$update->{$tid} = $value;
			}
		} elsif ($key eq "nexus_master") {
			if ($value >= 1 && $value <= 5 && $value =~ /^\d+$/) {
				foreach my $tid (@$nexus_tids_ar) {
					$update->{$tid} = $value;
				}
			}
		}
			
	}


	foreach my $tid (keys %$update) {
		my $value = $update->{$tid};

		# First remove tid in question from all arrays
		@story_always_nexus 		= grep { $_ != $tid } @story_always_nexus; 
		@story_full_brief_nexus 	= grep { $_ != $tid } @story_full_brief_nexus;
		@story_brief_always_nexus 	= grep { $_ != $tid } @story_brief_always_nexus;
		@story_full_best_nexus 		= grep { $_ != $tid } @story_full_best_nexus;
		@story_brief_best_nexus 	= grep { $_ != $tid } @story_brief_best_nexus;
		@story_never_nexus 		= grep { $_ != $tid } @story_never_nexus;
			
		# Then add it to the correct array
		if ($value == 5) {
			push @story_always_nexus, $tid;
		} elsif ($value == 4) {
			push @story_full_brief_nexus, $tid;
		} elsif ($value == 3) {
			push @story_brief_always_nexus, $tid;
		} elsif ($value == 2) {
			push @story_full_best_nexus, $tid;
		} elsif ($value == 1) {
			push @story_brief_best_nexus, $tid;
		} elsif ($value == 0) {
			push @story_never_nexus, $tid;
		}
	}

	my $story_always_nexus       	= join ",", @story_always_nexus;
	my $story_full_brief_nexus   	= join ",", @story_full_brief_nexus;
	my $story_brief_always_nexus 	= join ",", @story_brief_always_nexus;
	my $story_full_best_nexus	= join ",", @story_full_best_nexus;
	my $story_brief_best_nexus	= join ",", @story_brief_best_nexus;
	my $story_never_nexus       	= join ",", @story_never_nexus;
				
	$slashdb->setUser($user->{uid}, {
			story_always_nexus => $story_always_nexus,
			story_full_brief_nexus => $story_full_brief_nexus,
			story_brief_always_nexus => $story_brief_always_nexus,
			story_full_best_nexus	=> $story_full_best_nexus,
			story_brief_best_nexus	=> $story_brief_best_nexus,
			story_never_nexus	=> $story_never_nexus
		}
	);

	return getData('set_section_prefs_success_msg');
}

###################
# comments

sub readRest {
	my($slashdb, $constants, $user, $form) = @_;
	my $cid = $form->{cid} or return;
	my $sid = $form->{sid} or return;

	$user->{state}{ajax_accesslog_op} = 'comments_read_rest';

	my $comment = $slashdb->getComment($cid) or return;
	return unless $comment->{sid} == $sid;

	my $texts   = $slashdb->getCommentTextCached(
		{ $cid => $comment },
		[ $cid ],
		{ full => 1 }
	) or return;

	return $texts->{$cid} || '';
}

sub fetchComments {
	my($slashdb, $constants, $user, $form, $options) = @_;

	my $cids    = [ grep /^\d+$/, split /,/, ($form->{cids} || '') ];
	my $id      = $form->{discussion_id} || 0;
	my $cid     = $form->{cid} || 0; # root id
	my $max_cid = $form->{max_cid};

	$user->{state}{ajax_accesslog_op} = "ajax_comments_fetch";
#use Data::Dumper; print STDERR Dumper [ $cids, $id, $cid, $max_cid ];
	# XXX error?
	return unless $id && (defined($max_cid) || @$cids);

	my $discussion = $slashdb->getDiscussion($id);
	if ($discussion->{type} eq 'archived') {
		$user->{state}{discussion_archived} = 1;
	}
	$user->{mode} = 'thread';
	$user->{reparent} = 0;
	$user->{state}{max_depth} = $constants->{max_depth} + 3;

	my($comments) = Slash::selectComments(
		$discussion,
		$cid,
		{
			commentsort	=> 0,
			threshold	=> -1
		}
	);

	# XXX error?
	return unless $comments && keys %$comments;

	my %data;
	if (defined($max_cid)) {
		$cids = [ map { $_->[0] }
			@{$slashdb->sqlSelectAll(
				'cid', 'comments',
				'sid = ' . $slashdb->sqlQuote($id) . ' AND ' .
				'cid > ' . $slashdb->sqlQuote($max_cid),
				'ORDER BY date ASC'
			)}
		];

		if (@$cids) {
			my @cid_data = map {{
				uid    => $comments->{$_}{uid},
				pid    => $comments->{$_}{pid},
				points => $comments->{$_}{points},
				kids   => []
			}} @$cids;

			$data{new_cids_order} = [ @$cids ];
			$data{new_cids_data}  = \@cid_data;

			my %cid_map = map { ($_ => 1) } @$cids;
			$data{new_thresh_totals} = commentCountThreshold(
				{ map { ($_ => $comments->{$_}) } grep { $cid_map{$_} } keys %$comments },
				0,
				{ map { ($_ => 1) } grep { !$comments->{$_}{pid} } @$cids }
			);
		}
#use Data::Dumper; print STDERR Dumper \$comments, \%data;
	}

	# pieces_cids are comments that were oneline and need the extra display stuff for full
	# abbrev_cids are comments that were oneline/abbreviated and need to be non-abbrev
	# hidden_cids are comments that were hidden (noshow) and need to be displayed (full or oneline)

	my %pieces = split /[,;]/, $form->{pieces}      || '';
	my %abbrev = split /[,;]/, $form->{abbreviated} || '';
	my(@hidden_cids, @pieces_cids, @abbrev_cids, %get_pieces_cids, %keep_hidden);
	my(%html, %html_append_substr);

	# prune out hiddens we don't need, if threshold is sent (which means
	# we are not asking for a specific targetted comment(s) to highlight,
	# but just adjusting for a threshold or getting new comments
	if ($form->{threshold} && $form->{highlightthresh}) {
		for (my $i = 0; $i < @$cids; $i++) {
			my $class = 'oneline';
			my $cid = $cids->[$i];
			my $comment = $comments->{$cid};
			if ($comment->{points} < $form->{threshold}) {
				if ($user->{is_anon} || ($user->{uid} != $comment->{uid})) {
					$class = 'hidden';
					$keep_hidden{$cid} = 1;
				}
			}
			$class = 'full' if $comment->{points} >= $form->{highlightthresh}
				&& $class ne 'hidden';
			$comment->{class} = $class;

			if ($class eq 'oneline') {
				$get_pieces_cids{$cid} = 1;
			}
		}
	}

	for my $cid (@$cids) {
		if (exists $pieces{$cid}) {
			push @pieces_cids, $cid;
			if (exists $abbrev{$cid}) {
				push @abbrev_cids, $cid;
			}
		} elsif (!$keep_hidden{$cid}) {
			push @hidden_cids, $cid;
		}
	}

	my $comment_text = $slashdb->getCommentTextCached(
		$comments, [@hidden_cids, @abbrev_cids], { full => 1 },
	);

	for my $cid (keys %$comment_text) {
		$comments->{$cid}{comment} = $comment_text->{$cid};
	}

	# for dispComment
	$form->{mode} = 'archive';

	for my $cid (@hidden_cids) {
		$html{'comment_' . $cid} = Slash::dispComment($comments->{$cid}, {
			noshow_show => 1,
			pieces      => $get_pieces_cids{$cid}
		});
	}

	for my $cid (@pieces_cids) {
		@html{'comment_otherdetails_' . $cid, 'comment_sub_' . $cid} =
			Slash::dispComment($comments->{$cid}, {
				show_pieces => 1
			});
	}

	for my $cid (@abbrev_cids) {
		@html_append_substr{'comment_body_' . $cid} = substr($comments->{$cid}{comment}, $abbrev{$cid});
	}

# XXX update noshow_comments, pieces_comments -- pudge
#use Data::Dumper; print STDERR Dumper \@hidden_cids, \@pieces_cids, \@abbrev_cids, \%get_pieces_cids, \%keep_hidden, \%pieces, \%abbrev, \%html, \%html_append_substr, $form, \%data;

	$options->{content_type} = 'application/json';
	return Data::JavaScript::Anon->anon_dump({
		update_data        => \%data,
		html               => \%html,
		html_append_substr => \%html_append_substr
	});
}

sub updateD2prefs {
	my($slashdb, $constants, $user, $form) = @_;
	my %save;
	for my $pref (qw(threshold highlightthresh)) {
		$save{"d2_$pref"} = $form->{$pref} if defined $form->{$pref};
	}
	for my $pref (qw(comments_control)) {
		$save{$pref} = $form->{$pref} if defined $form->{$pref};
	}

	$slashdb->setUser($user->{uid}, \%save);
}

# comments
###################


##################################################################
sub default { }

##################################################################
sub header_ajax {
	my($options) = @_;
	my $ct = $options->{content_type} || 'text/plain';

	my $r = Apache->request;
	$r->content_type($ct);
	$r->header_out('Cache-Control', 'no-cache');
	$r->send_http_header;
}

##################################################################
sub getOps {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();

	my $table_cache         = "_ajaxops_cache";
	my $table_cache_time    = "_ajaxops_cache_time";
	$slashdb->_genericCacheRefresh('ajaxops', $constants->{block_expire});
	if ($slashdb->{$table_cache_time} && $slashdb->{$table_cache}) {
		return $slashdb->{$table_cache};
	}

	my $ops = $slashdb->sqlSelectAllHashref(
		'op', 'op, class, subroutine, reskey_name, reskey_type', 'ajax_ops'
	);

	my %mainops = (
		comments_read_rest	=> {
			function	=> \&readRest,
			reskey_name	=> 'ajax_base',
			reskey_type	=> 'createuse',
		},
		comments_fetch		=> {
			function	=> \&fetchComments,
			reskey_name	=> 'ajax_user_static',
			reskey_type	=> 'createuse',
		},
		comments_set_prefs	=> {
			function	=> \&updateD2prefs,
			reskey_name	=> 'ajax_user_static',
			reskey_type	=> 'createuse',
		},
		getSectionPrefsHTML => {
			function	=> \&getSectionPrefsHTML,
			reskey_name	=> 'ajax_user',
			reskey_type	=> 'createuse',
		},
		setSectionNexusPrefs => {
			function	=> \&setSectionNexusPrefs,
			reskey_name	=> 'ajax_user',
			reskey_type	=> 'createuse',
		},
#		tagsGetUserStory => {
#			function	=> \&tagsGetUserStory,
#			reskey_type	=> 'createuse',
#		},
#		tagsCreateForStory => {
#			function	=> \&tagsCreateForStory,
#			reskey_type	=> 'createuse',
#		},
		default	=> {
			function	=> \&default,		
		},
	);

	for (keys %mainops) {
		$ops->{$_} ||= $mainops{$_};
	}

	if ($slashdb->{$table_cache_time}) {
		$slashdb->{$table_cache} = $ops;
	}

	return $ops;
}

##################################################################
createEnvironment();
main();
1;
