# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: FireHose.pm,v 1.101 2007/03/21 22:25:48 tvroom Exp $

package Slash::FireHose;

=head1 NAME

Slash::FireHose - Perl extension for FireHose


=head1 SYNOPSIS

	use Slash::FireHose;


=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use DBIx::Password;
use Slash;
use Slash::Display;
use Slash::Utility;
use Slash::Slashboxes;
use Slash::Tags;
use Data::JavaScript::Anon;

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';
use vars qw($VERSION);

($VERSION) = ' $Revision: 1.101 $ ' =~ /\$Revision:\s+([^\s]+)/;
sub createFireHose {
	my($self, $data) = @_;
	$data->{dept} ||= "";
	$data->{discussion} = 0 if !defined $data->{discussion} || !$data->{discussion};
	$data->{-createtime} = "NOW()" if !$data->{createtime} && !$data->{-createtime};
	$data->{discussion} ||= 0 if defined $data->{discussion};

	my $text_data = {};
	$text_data->{title} = delete $data->{title};
	$text_data->{introtext} = delete $data->{introtext};
	$text_data->{bodytext} = delete $data->{bodytext};

	$self->sqlInsert("firehose", $data);
	$text_data->{id} = $self->getLastInsertId({ table => 'firehose', prime => 'id' });

	my $searchtoo = getObject('Slash::SearchToo');
	if ($searchtoo) {
		$searchtoo->storeRecords(firehose => $text_data->{id}, { add => 1 });
	}

	$self->sqlInsert("firehose_text", $text_data);

}

sub createUpdateItemFromJournal {
	my($self, $id) = @_;
	my $journal_db = getObject("Slash::Journal");
	my $journal = $journal_db->get($id);
	if ($journal) {
		my $globjid = $self->getGlobjidCreate("journals", $journal->{id});
		my $globjid_q = $self->sqlQuote($globjid);
		my($itemid) = $self->sqlSelect("*", "firehose", "globjid=$globjid_q");
		if ($itemid) {
			my $introtext = balanceTags(strip_mode($journal->{article}, $journal->{posttype}), { deep_nesting => 1 });
			$self->setFireHose($itemid, { introtext => $introtext, title => $journal->{description}, tid => $journal->{tid}, discussion => $journal->{discussion}});
		} else {
			$self->createItemFromJournal($id);
		}
	}
}

sub getFireHoseColors {
	my($self, $array) = @_;
	my $constants = getCurrentStatic();
	my $color_str = $constants->{firehose_color_labels};
	my @colors = split(/\|/, $color_str);
	return \@colors if $array;
	my $colors = {};
	my $i=1;
	foreach (@colors) {
		$colors->{$_} = $i++;
	}
	return $colors;
}



sub createItemFromJournal {
	my($self, $id) = @_;
	my $user = getCurrentUser();
	my $journal_db = getObject("Slash::Journal");
	my $journal = $journal_db->get($id);
	my $introtext = balanceTags(strip_mode($journal->{article}, $journal->{posttype}), { deep_nesting => 1 });
	if ($journal) {
		my $globjid = $self->getGlobjidCreate("journals", $journal->{id});
		my $popularity = $journal->{promotetype} eq "publicize" 
			? $self->getMidPopularityForColorLevel(5) 
			: $self->getMidPopularityForColorLevel(6);
		my $type = $user->{acl}{vendor} ? "vendor" : "journal";
		my $data = {
			title 			=> $journal->{description},
			globjid 		=> $globjid,
			uid 			=> $journal->{uid},
			attention_needed 	=> "yes",
			public 			=> "yes",
			introtext 		=> $introtext,
			popularity		=> $popularity,
			editorpop		=> $popularity,
			tid			=> $journal->{tid},
			srcid			=> $id,
			discussion		=> $journal->{discussion},
			type			=> $type
		};
		$self->createFireHose($data);
	}

}

sub createUpdateItemFromBookmark {
	my($self, $id, $options) = @_;
	$options ||= {};
	my $bookmark_db = getObject("Slash::Bookmark");
	my $bookmark = $bookmark_db->getBookmark($id);
	my $url_globjid = $self->getGlobjidCreate("urls", $bookmark->{url_id});
	my $type = $options->{type} || "bookmark";
	my($count) = $self->sqlCount("firehose", "globjid=$url_globjid");
	my $popularity = defined $options->{popularity}
		? $options->{popularity}
		: $type eq "feed"
			? $self->getMidPopularityForColorLevel(6)
			: $self->getMidPopularityForColorLevel(7);
	my $activity   = defined $options->{activity} ? $options->{activity} : 1;

	if ($count) {
		# $self->sqlUpdate("firehose", { -popularity => "popularity + 1" }, "globjid=$url_globjid");
	} else {
		

		my $data = {
			globjid 	=> $url_globjid,
			title 		=> $bookmark->{title},
			url_id 		=> $bookmark->{url_id},
			uid 		=> $bookmark->{uid},
			popularity 	=> $popularity,
			editorpop	=> $popularity,
			activity 	=> $activity,
			public 		=> "yes",
			type		=> $type,
			srcid		=> $id
		};
		$data->{introtext} = $options->{introtext} if $options->{introtext};
		$self->createFireHose($data)
	}

}

sub createItemFromSubmission {
	my($self, $id) = @_;
	my $submission = $self->getSubmission($id);
	if ($submission) {
		my $globjid = $self->getGlobjidCreate("submissions", $submission->{subid});
		my $midpop = $self->getMinPopularityForColorLevel(5);
		my $data = {
			title 			=> $submission->{subj},
			globjid 		=> $globjid,
			uid 			=> $submission->{uid},
			introtext 		=> $submission->{story},
			popularity 		=> $midpop,
			editorpop 		=> $midpop,
			public 			=> "yes",
			attention_needed 	=> "yes",
			type 			=> "submission",
			primaryskid		=> $submission->{primaryskid},
			tid 			=> $submission->{tid},
			srcid 			=> $id,
			ipid 			=> $submission->{ipid},
			subnetid 		=> $submission->{subnetid},
			email			=> $submission->{email},
			emaildomain		=> $submission->{emaildomain},
			name			=> $submission->{name},
		};
		$self->createFireHose($data);
	}

}

sub updateItemFromStory {
	my($self, $id) = @_;
	my $constants = getCurrentStatic();
	my %ignore_skids = map {$_ => 1 } @{$constants->{firehose_story_ignore_skids}};
	my $story = $self->getStory($id, "", 1);
	if ($story) {
		my $globjid = $self->getGlobjidCreate("stories", $story->{stoid});
		my $id = $self->getFireHoseIdFromGlobjid($globjid);
		if ($id) {
			# If a story is getting its primary skid to an ignored value set its firehose entry to non-public
			my $public = ($story->{neverdisplay} || $ignore_skids{$story->{primaryskid}}) ? "no" : "yes";
			my $data = {
				title 		=> $story->{title},
				uid		=> $story->{uid},
				createtime	=> $story->{time},
				introtext	=> parseSlashizedLinks($story->{introtext}),
				bodytext	=> parseSlashizedLinks($story->{bodytext}),
				primaryskid	=> $story->{primaryskid},
				tid 		=> $story->{tid},
				public		=> $public,
				dept		=> $story->{dept},
				discussion	=> $story->{discussion},
			};
			$self->setFireHose($id, $data);
		}
	}
}

sub createItemFromStory {
	my($self, $id) = @_;
	my $constants = getCurrentStatic();
	# If a story is created with an ignored primary skid it'll never be created as a firehose entry currently
	my %ignore_skids = map {$_ => 1 } @{$constants->{firehose_story_ignore_skids}};
	my $story = $self->getStory($id, '', 1);

	my $popularity = $self->getMidPopularityForColorLevel(2);
	if ($story->{story_topics_rendered}{$constants->{mainpage_nexus_tid}}) {
		$popularity = $self->getMidPopularityForColorLevel(1);
	}

	if ($story && !$ignore_skids{$story->{primaryskid}}) {
		my $globjid = $self->getGlobjidCreate("stories", $story->{stoid});
		my $public = $story->{neverdisplay} ? "no" : "yes";
		my $data = {
			title 		=> $story->{title},
			globjid 	=> $globjid,
			uid		=> $story->{uid},
			createtime	=> $story->{time},
			introtext	=> parseSlashizedLinks($story->{introtext}),
			bodytext	=> parseSlashizedLinks($story->{bodytext}),
			popularity	=> $popularity,
			editorpop	=> $popularity,
			primaryskid	=> $story->{primaryskid},
			tid 		=> $story->{tid},
			srcid		=> $id,
			type 		=> "story",
			public		=> $public,
			dept		=> $story->{dept},
			discussion	=> $story->{discussion},
		};
		$self->createFireHose($data);
	}
}

sub getFireHoseCount {
	my($self) = @_;
	my $pop = $self->getMidPopularityForColorLevel(6);
	my $user = getCurrentUser();
	my $pop_q = $self->sqlQuote($pop);
	my $signoff_label = "sign$user->{uid}\ed";

	#XXXFH - add time limit later?
	return $self->sqlCount("firehose", "editorpop >= $pop_q and rejected='no' and accepted='no' and type!='story'");
}

sub getFireHoseEssentials {
	my($self, $options) = @_;

	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $colors = $self->getFireHoseColors();

	$options ||= {};
	$options->{limit} ||= 50;

	my($items, $results, $doublecheck) = ([], {}, 0);
	# for now, only bother to try searchtoo if there is a qfilter value to search on
	if (!$options->{no_search} && $constants->{firehose_searchtoo} && $options->{qfilter}) {
		my $searchtoo = getObject('Slash::SearchToo');
		if ($searchtoo && $searchtoo->handled('firehose')) {
			my(%opts, %query);
			$query{query}		= $options->{qfilter}			if defined $options->{qfilter};
			$query{category}	= $options->{category} || 'none'	if $options->{category} || $user->{is_admin};
			if ($options->{ids}) {
				if (ref($options->{ids}) eq 'ARRAY' && @{$options->{ids}} < 1) {
					return([], {});
				}
				$query{id}		= $options->{ids}		if $options->{ids};
			}

			# attention_needed not indexed right now
			for (qw(attention_needed public accepted rejected type primaryskid)) {
				$query{$_}	= $options->{$_}		if $options->{$_};
			}

			# still need sorting and filtering by date
			$opts{records_max}	= $options->{limit}		unless $options->{nolimit};
			$opts{records_start}	= $options->{offset}		if $options->{offset};
			$opts{sort}		= 3;  # sorting handled by caller

			# just a few options to carry over
			$opts{carryover} = {
				map { ($_ => $options->{$_}) } qw(tagged_by_uid orderdir orderby ignore_nix)
			};

#use Data::Dumper; print STDERR Dumper \%query, \%opts;
#print STDERR "[[ 0 ]]\n";
			$results = $searchtoo->findRecords(firehose => \%query, \%opts);
			$items = delete $results->{records};
#printf STDERR "[[ 4 : %d : %d : %d ]]\n\n", $results->{records_matches}, $results->{records_returned}, scalar @$items;
#print STDERR Dumper $results;

			return($items, $results) if ! @$items;

			$options->{ids} = [ map { $_->{id} } @$items ];
			$doublecheck = 1;
		}
	}

	# sometimes we just pass options to searchtoo and get them back later
	if ($options->{carryover}) {
		my $co = $options->{carryover};
		@{$options}{keys %$co} = values %$co;
		delete $options->{carryover};
	}

#use Data::Dumper; print STDERR Dumper $options;

	$options->{orderby} ||= "createtime";
	$options->{orderdir} = uc($options->{orderdir}) eq "ASC" ? "ASC" : "DESC";
	#($user->{is_admin} && $options->{orderby} eq "createtime" ? "ASC" :"DESC");

	my @where;
	my $tables = "firehose";
	if ($options->{tagged_by_uid}) {
		my $tag_by_uid_q = $self->sqlQuote($options->{tagged_by_uid});
		$tables .= ", tags";
		push @where, "tags.globjid=firehose.globjid";
		push @where, "tags.uid = $tag_by_uid_q";

		if ($options->{ignore_nix}) {
			my $downlabel = $constants->{tags_downvote_tagname} || 'nix';
			my $tags = getObject("Slash::Tags");
			my $nix_id = $tags->getTagnameidFromNameIfExists($downlabel);
			push @where, "tags.tagnameid != $nix_id";
		}
	}
	my $columns = "firehose.*";

	if ($options->{createtime_no_future} && !$doublecheck) {
		push @where, "createtime <= NOW()";
	}

	if ($options->{createtime_subscriber_future}) {
		my $future_secs = $constants->{subscribe_future_secs};
		push @where, "createtime <= DATE_ADD(NOW(), INTERVAL $future_secs SECOND)";
	}

	if ($options->{attention_needed} && !$doublecheck) {
		push @where, "attention_needed = " . $self->sqlQuote($options->{attention_needed});
	}

	if ($options->{public} && !$doublecheck) {
		push @where, "public = " . $self->sqlQuote($options->{public});
	}

	if ($options->{accepted}) {
		push @where, "accepted = " . $self->sqlQuote($options->{accepted});
	}

	if ($options->{rejected}) {
		push @where, "rejected = " . $self->sqlQuote($options->{rejected});
	}

	if ($options->{type} && !$doublecheck) {
		push @where, "type = " . $self->sqlQuote($options->{type});
	}

	if ($options->{primaryskid}) {
		push @where, "primaryskid = " . $self->sqlQuote($options->{primaryskid});
	}

	if (defined $options->{category} || $user->{is_admin}) {
		$options->{category} ||= '';
		push @where, "category = " . $self->sqlQuote($options->{category});
	}

	if (($options->{filter} || $options->{fetch_text}) && !$doublecheck) {
		$tables .= ",firehose_text";
		push @where, "firehose.id=firehose_text.id";

		if ($options->{filter}) {
			# sanitize $options->{filter};
			$options->{filter} =~ s/[^a-zA-Z0-9_]+//g;
			push @where, "firehose_text.title like '%" . $options->{filter} . "%'";
		}

		if ($options->{fetch_text}) {
			$columns .= ",firehose_text.*";
		}
	}

	if ($options->{createtime_gte} && !$doublecheck) {
		push @where, "createtime >= " . $self->sqlQuote($options->{createtime_gte});
	}
	if ($options->{last_update_gte} && !$doublecheck) {
		push @where, "last_update >= " . $self->sqlQuote($options->{last_update_gte});
	}

	if ($options->{ids}) {
		return($items, $results) if @{$options->{ids}} < 1;
		my $id_str = join ",", map { $self->sqlQuote($_) } @{$options->{ids}};
		push @where, "firehose.id IN ($id_str)";
	}

	# XXX Update to support timezones eventually
	my $dur_q = $self->sqlQuote($options->{duration});
	my $st_q  = $self->sqlQuote("$options->{startdate} 00:000:00");

	if ($options->{startdate}) {
		push @where, "createtime >= $st_q";
		

		if ($options->{duration} && $options->{duration} >= 0 ) {
			push @where, "createtime <= DATE_ADD($st_q, INTERVAL $dur_q DAY)";
		}
	} elsif (defined $options->{duration} && $options->{duration} >= 0) {
		push @where, "createtime >= DATE_SUB(NOW(), INTERVAL $dur_q DAY)";
	}

	if ($options->{color}) {
		if ($colors->{$options->{color}}) {
			my $pop = $self->getMinPopularityForColorLevel($colors->{$options->{color}});
			my $pop_q = $self->sqlQuote($pop);
			if ($user->{is_admin} && !$user->{firehose_usermode}) {
				push @where, "editorpop >= $pop_q";
			} else {
				push @where, "popularity >= $pop_q";
			}
		}
	}
	if ($user->{is_admin}) {
		my $signoff_label = "sign" . $user->{uid} . "ed";

		if ($options->{unsigned}) {
			push @where, "signoffs NOT LIKE \"\%$signoff_label\%\"";
		}

		if ($options->{signed}) {
			push @where, "signoffs LIKE \"\%$signoff_label\%\"";
		}
	}

	if ($options->{uid}) {
		my $uid_q = $self->sqlQuote($options->{uid});
		push @where, "uid=$uid_q";
	}

	my $limit_str = "";
	my $where = (join ' AND ', @where) || "";

	my $offset = defined $options->{offset} ? $options->{offset} : '';
	$offset = '' if $offset !~ /^\d+$/;
	$offset = "$offset, " if length $offset;
	$limit_str = "LIMIT $offset $options->{limit}" unless $options->{nolimit};

	my $other = '';
	$other .= " GROUP BY firehose.id " if $options->{tagged_by_uid};
	$other .= "ORDER BY $options->{orderby} $options->{orderdir} $limit_str"; # unless $doublecheck;

#print STDERR "[\nSELECT $columns\nFROM   $tables\nWHERE  $where\n$other\n]\n";
	my $hr_ar = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other);

	# make sure these items (from SearchToo) still match -- pudge
	if ($doublecheck) {
		my %hrs = map { ( $_->{id}, 1 ) } @$hr_ar;
		my @tmp_items;
		for my $item (@$items) {
			push @tmp_items, $item if $hrs{$item->{id}};
		}
		$items = \@tmp_items;

	# Add globj admin notes to the firehouse hashrefs.
	} else {
		my $globjids = [ map { $_->{globjid} } @$hr_ar ];
		my $note_hr = $self->getGlobjAdminnotes($globjids);
		for my $hr (@$hr_ar) {
			$hr->{note} = $note_hr->{ $hr->{globjid} } || '';
		}
	}

	$items = $hr_ar;
	return($items, $results);
}

sub getUserFireHoseVotesForGlobjs {
	my($self, $uid, $globjs) = @_;
	my $constants = getCurrentUser();

	return {} if !$globjs;
	$globjs = [$globjs] if !ref $globjs;
	return {} if @$globjs < 1;
	my $uid_q = $self->sqlQuote($uid);
	my $glob_str = join ",", map { $self->sqlQuote($_) } @$globjs;
	
	my $upvote   = $constants->{tags_upvote_tagname}   || 'nod';
	my $downvote = $constants->{tags_downvote_tagname} || 'nix';

	my $tags = getObject("Slash::Tags", { db_type => "reader" });
	my $upid = $tags->getTagnameidCreate($upvote);
	my $dnid = $tags->getTagnameidCreate($downvote);

	my $results = $self->sqlSelectAllKeyValue(
		"globjid,tagnameid",
		"tags", 
		"globjid in ($glob_str) and inactivated is NULL AND uid = $uid_q AND tagnameid IN ($upid,$dnid)"
	);

	foreach (keys %$results) {
		$results->{$_} = "up" if $results->{$_} == $upid;
		$results->{$_} = "down" if $results->{$_} == $dnid;
	}
	
	return $results;
}

sub getFireHose {
	my($self, $id) = @_;

	my $mcd = $self->getMCD();
	my $mcdkey = "$self->{_mcd_keyprefix}:firehose";
	if ($mcd) {
		my $item = $mcd->get("$mcdkey:$id");
		return $item if $item;
	}

	# XXX cache this eventually
	my $id_q = $self->sqlQuote($id);
	my $answer = $self->sqlSelectHashref("*", "firehose", "id=$id_q");
	my $append = $self->sqlSelectHashref("*", "firehose_text", "id=$id_q");

	for my $key (keys %$append) {
		$answer->{$key} = $append->{$key};
	}

	# globj adminnotes are never the empty string, they are undef
	# instead.  Firehose notes are/were designed to never be undef,
	# the empty string instead.
	$answer->{note} = $self->getGlobjAdminnote($answer->{globjid}) || '';
	
	if ($mcd && $answer->{title}) {
		my $item = $mcd->set("$mcdkey:$id", $answer);
	}

	return $answer;
}

sub getFireHoseIdFromGlobjid {
	my($self, $globjid) = @_;
	my $globjid_q = $self->sqlQuote($globjid);
	return $self->sqlSelect("id", "firehose", "globjid=$globjid_q");
}

sub fetchItemText {
	my $form = getCurrentForm();
	my $firehose = getObject("Slash::FireHose");
	my $user = getCurrentUser();
	my $id = $form->{id};
	return unless $id && $firehose;
	my $item = $firehose->getFireHose($id);
	my $tags_top = $firehose->getFireHoseTagsTop($item);

	if ($user->{is_admin}) {
		$firehose->setFireHoseSession($item->{id});
	}
	my $data = {
		item		=> $item,
		mode		=> "bodycontent",
		tags_top	=> $tags_top,
	};

	my $retval = slashDisplay("dispFireHose", $data, { Return => 1, Page => "firehose" });
	return $retval;
}

sub rejectItemBySubid {
	my($self, $subid) = @_;
	if (!ref $subid) {
		$subid = [$subid];
	}
	return unless ref $subid eq "ARRAY";
	my $str;
	if (@$subid > 0) {
		$str = join ',', map { $self->sqlQuote($_) }  @$subid;
		my $ids = $self->sqlSelectColArrayref("id", "firehose", "type='submission' AND srcid IN ($str)");
		foreach (@$ids) {
			$self->setFireHose($_, { rejected => 'yes' });
		}
	}
}

sub rejectItem {
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	my $constants = getCurrentStatic();
	my $firehose = getObject("Slash::FireHose");
	my $tags = getObject("Slash::Tags");
	my $id = $form->{id};
	my $id_q = $firehose->sqlQuote($id);
	return unless $id && $firehose;
	my $item = $firehose->getFireHose($id);
	if ($item) {
		$firehose->setFireHose($id, { rejected => "yes" });
		if ($item->{globjid}) {
			my $downvote = $constants->{tags_downvote_tagname} || 'nix';
			$tags->createTag({
				uid	=>	$user->{uid},
				name	=> 	$downvote,
				globjid	=>	$item->{globjid},
				private	=> 	1
			});
		}
		
		if ($item->{type} eq "submission") {
			if ($item->{srcid}) {
				my $n_q = $firehose->sqlQuote($item->{srcid});
				my $uid = getCurrentUser('uid');
				my $rows = $firehose->sqlUpdate('submissions',
					{ del => 1 }, "subid=$n_q AND del=0"
				);
				if ($rows) {
					$firehose->setUser($uid,
						{ -deletedsubmissions => 'deletedsubmissions+1' }
					);
				}
			}
		}
	}
}

sub ajaxSaveOneTopTagFirehose {
	my($slashdb, $constants, $user, $form, $options) = @_;
	my $tags = getObject("Slash::Tags");
	my $id = $form->{id};
	my $tag = $form->{tags};
	my $firehose = getObject("Slash::FireHose");
	my $item = $firehose->getFireHose($id);
	if ($item) {
		$firehose->setSectionTopicsFromTagstring($id, $tag);
		my($table, $itemid) = $tags->getGlobjTarget($item->{globjid});
		my $now_tags_ar = $tags->getTagsByNameAndIdArrayref($table, $itemid, { uid => $user->{uid}});
		my @tags = sort Slash::Tags::tagnameorder map { $_->{tagname} } @$now_tags_ar;
		push @tags, $tag;
		my $tagsstring = join ' ', @tags;
		my $newtagspreloadtext = $tags->setTagsForGlobj($itemid, $table, $tagsstring);
	}
}

sub ajaxRemoveUserTab {
	my($slashdb, $constants, $user, $form, $options) = @_;
	$options->{content_type} = 'application/json';
	return if $user->{is_anon};
	if ($form->{tabid}) {
		my $tabid_q = $slashdb->sqlQuote($form->{tabid});
		my $uid_q   = $slashdb->sqlQuote($user->{uid});
		$slashdb->sqlDelete("firehose_tab", "tabid=$tabid_q AND uid=$uid_q");
	}
	my $firehose = getObject("Slash::FireHose");
	my $opts = $firehose->getAndSetOptions();
	my $html = {};
	$html->{fhtablist} = slashDisplay("firehose_tabs", { nodiv => 1, tabs => $opts->{tabs} }, { Return => 1});

	return Data::JavaScript::Anon->anon_dump({
		html	=> $html
	});
}

sub ajaxFireHoseSetOptions {
	my($slashdb, $constants, $user, $form, $options) = @_;
	$options->{content_type} = 'application/json';
	my $firehose = getObject("Slash::FireHose");
	my $opts = $firehose->getAndSetOptions();
	my $html = {};
	$html->{fhtablist} = slashDisplay("firehose_tabs", { nodiv => 1, tabs => $opts->{tabs} }, { Return => 1});
	$html->{fhoptions} = slashDisplay("firehose_options", { nowrapper => 1, options => $opts }, { Return => 1});
	$html->{fhadvprefpane} = slashDisplay("fhadvprefpane", { options => $opts }, { Return => 1});

	my $values = {};
	$values->{'firehose-filter'} = $opts->{fhfilter};
	my $eval_last = "";
	if ($form->{tab}) {
		$eval_last = "firehose_slider_set_color('$opts->{color}')";
	}

	return Data::JavaScript::Anon->anon_dump({
		html		=> $html,
		value		=> $values,
		eval_last	=> $eval_last
	});
}

sub ajaxSaveNoteFirehose {
	my($slashdb, $constants, $user, $form) = @_;
	my $id = $form->{id};
	my $note = $form->{note};
	if ($note && $id) {
		my $firehose = getObject("Slash::FireHose");
		$firehose->setFireHose($id, { note => $note });
	}
	return $note || "Note";
}

sub ajaxSaveFirehoseTab {
	my($slashdb, $constants, $user, $form) = @_;
	return if $user->{is_anon};
	my $firehose = getObject("Slash::FireHose");

	my $max_named_tabs = $constants->{firehose_max_tabs} || 10;

	my $tabid = $form->{tabid};
	my $tabname = $form->{tabname};
	$tabname =~ s/^\s+|\s+$//g;
	my $message = "";

	my $user_tabs = $firehose->getUserTabs();
	my %other_tabnames = map { lc($_->{tabname}) => $_->{tabid} } grep { $_->{tabid} != $tabid } @$user_tabs;
	my $original_name = "";
	foreach (@$user_tabs) {
		$original_name = $_->{tabname} if $tabid == $_->{tabid};
	}
	if ($tabname && $tabid) {
		if (length($tabname) == 0 || length($tabname) > 16) {
			$message .= "You specified a tabname that was either too long or too short\n";
		} elsif ($tabname =~/^untitled$/) {
			$message .= "Can't rename a tab to untitled, that name is reserved<br>";
		} elsif ($tabname =~ /[^A-Za-z0-9_-]/) {
			$message .= "You attempted to use unallowed characters in your tab name, stick to alpha numerics<br>";
		} elsif ($original_name eq "untitled" && @$user_tabs >= $max_named_tabs) {
			$message .= "You have too many named tabs, you need to delete one before you can save another";
		} else {
			my $uid_q = $slashdb->sqlQuote($user->{uid});
			my $tabid_q = $slashdb->sqlQuote($tabid);
			my $tabname_q = $slashdb->sqlQuote($tabname);
		
			$slashdb->sqlDelete("firehose_tab", "uid=$uid_q and tabname=$tabname_q and tabid!=$tabid_q");
			$slashdb->sqlUpdate("firehose_tab", { tabname => $tabname }, "tabid=$tabid_q");
			$slashdb->setUser($user->{uid}, { last_fhtab_set => $slashdb->getTime() });
		}
	}

	my $opts = $firehose->getAndSetOptions();
	my $html = {};
	$html->{fhtablist} = slashDisplay("firehose_tabs", { nodiv => 1, tabs => $opts->{tabs} }, { Return => 1});
	$html->{message_area} = $message;
	return Data::JavaScript::Anon->anon_dump({
		html	=> $html
	});
}


sub ajaxGetUserFirehose {
	my($slashdb, $constants, $user, $form) = @_;
	my $id = $form->{id};
	my $globjid;

	my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
	my $firehose_reader = getObject('Slash::FireHose', {db_type => 'reader'});

	my $item = $firehose_reader->getFireHose($id);
	if ($item) {
		$globjid = $item->{globjid};
	}
#	print STDERR "ajaxGetUserFirehose id: $id globjid: $globjid\n\n";
#print STDERR scalar(localtime) . " ajaxGetUserFirehose for stoid=$stoid sidenc=$sidenc tr=$tags_reader\n";
	if (!$globjid || $globjid !~ /^\d+$/ || $user->{is_anon} || !$tags_reader) {
		return getData('error', {}, 'tags');
	}
	my $uid = $user->{uid};

	my $tags_ar = $tags_reader->getTagsByGlobjid($globjid, { uid => $uid });
	my @tags = sort  map { $_->{tagname} } @$tags_ar;
#print STDERR scalar(localtime) . " ajaxGetUserFirehose for stoid=$stoid uid=$uid tags: '@tags' tags_ar: " . Dumper($tags_ar);

	my @newtagspreload = @tags;
	push @newtagspreload,
		grep { $tags_reader->tagnameSyntaxOK($_) }
		split /[\s,]+/,
		($form->{newtagspreloadtext} || '');
	my $newtagspreloadtext = join ' ', @newtagspreload;
	#print STDERR "ajaxGetUserFirehose $newtagspreloadtext\n\n";

	return slashDisplay('tagsfirehosedivuser', {
		id =>		$id,
		newtagspreloadtext =>	$newtagspreloadtext,
	}, { Return => 1 });
}

sub ajaxGetAdminFirehose {
	my($slashdb, $constants, $user, $form) = @_;
	my $id = $form->{id};

	if (!$id || !$user->{is_admin}) {
		return getData('error', {}, 'tags');
	}

	return slashDisplay('tagsfirehosedivadmin', {
		id =>		$id,
		tags_admin_str =>	'',
	}, { Return => 1 });
}



sub ajaxFireHoseGetUpdates {
	my($slashdb, $constants, $user, $form, $options) = @_;
	$options->{content_type} = 'application/json';
	my $firehose = getObject("Slash::FireHose");
	my $firehose_reader = getObject('Slash::FireHose', {db_type => 'reader'});
	my $id_str = $form->{ids};
	my $update_time = $form->{updatetime};
	my @ids = grep {/^\d+$/} split (/,/, $id_str);
	my %ids = map { $_ => 1 } @ids;
	my %ids_orig = ( %ids ) ;
	my $opts = $firehose->getAndSetOptions({ no_set => 1 });
	my($items, $results) = $firehose_reader->getFireHoseEssentials($opts);
	my $future = {};
	my $globjs = [];	
	foreach (@$items) {
		push @$globjs, $_->{globjid} if $_->{globjid} 
	}

	my $votes = $firehose->getUserFireHoseVotesForGlobjs($user->{uid}, $globjs);
	my $html = {};
	my $updates = [];

	my $adminmode = $user->{is_admin};
	$adminmode = 0 if $user->{is_admin} && $user->{firehose_usermode};
	my $ordered = [];
	my $now = $slashdb->getTime();
	my $added = {};


	foreach (@$items) {
		my $item = $firehose_reader->getFireHose($_->{id});
		my $tags_top = $firehose_reader->getFireHoseTagsTop($item);
		$future->{$_->{id}} = 1 if $item->{createtime} gt $now;
		if ($ids{$_->{id}}) {
			if ($item->{last_update} ge $update_time) {
				my $url 	= $slashdb->getUrl($item->{url_id});
				my $the_user  	= $slashdb->getUser($item->{uid});
				$html->{"title-$_->{id}"} = slashDisplay("formatHoseTitle", { adminmode => $adminmode, item => $item, showtitle => 1, url => $url, the_user => $the_user, options => $opts }, { Return => 1 });
				$html->{"tags-top-$_->{id}"} = slashDisplay("firehose_tags_top", { tags_top => $tags_top, id => $_->{id}, item => $item }, { Return => 1 });
				my $introtext = $item->{introtext};
				slashDisplay("formatHoseIntro", { introtext => $introtext, url => $url, $item => $item }, { Return => 1 });
				$html->{"text-$_->{id}"} = $introtext;
				$html->{"fhtime-$_->{id}"} = timeCalc($item->{createtime});
				# updated
			}
		} else {
			# new
			$update_time = $_->{last_update} if $_->{last_update} gt $update_time && $_->{last_update} lt $now;
			push @$updates, ["add", $_->{id}, slashDisplay("dispFireHose", { mode => $opts->{mode}, item => $item, tags_top => $tags_top, vote => $votes->{$item->{globjid}}, options => $opts }, { Return => 1, Page => "firehose" })];
			$added->{$_->{id}}++;
		}
		push @$ordered, $item->{id};
		delete $ids{$_->{id}};
	}

	my $prev;
	my $next_to_old = {};
	my $i = 0;
	my $pos;

	foreach (@$ordered) {
		$next_to_old->{$prev} = $_ if $prev && $ids_orig{$_} && $added->{$prev};
		$next_to_old->{$_} = $prev if $ids_orig{$prev} && $added->{$_};
		$prev = $_;
		$pos->{$_} = $i;
		$i++;
	}

	my $target_pos = 100;
	if (scalar (keys %$next_to_old) == 1) {
		my ($key) = keys %$next_to_old;
		$target_pos = $pos->{$key};
		print STDERR "Target pos: $target_pos\n";
		
	}
	
	@$updates  = sort {
		$next_to_old->{$a->[1]} <=> $next_to_old->{$b->[1]} ||
		abs($pos->{$b->[1]} - $target_pos) <=> abs($pos->{$a->[1]} - $target_pos);
	} @$updates;

	foreach (keys %ids) {
		push @$updates, ["remove", $_, ""];
	}


	$html->{"fh-paginate"} = slashDisplay("paginate", { contentsonly => 1, page => $form->{page}, options => $opts }, { Return => 1, Page => "firehose"});
	$html->{local_last_update_time} = timeCalc($slashdb->getTime(), "%H:%M");
	$html->{gmt_update_time} = " (".timeCalc($slashdb->getTime(), "%H:%M", 0)." GMT) " if $user->{is_admin};

	my $data_dump =  Data::JavaScript::Anon->anon_dump({
		html		=> $html,
		updates		=> $updates,
		update_time	=> $update_time,
		ordered		=> $ordered,
		future		=> $future,
	});
	my $reskey_dump = "";
	my $reskey = getObject("Slash::ResKey");
	my $user_rkey = $reskey->key('ajax_user_static', { no_state => 1 });
	$reskey_dump .= "reskey_static = '" . $user_rkey->reskey() . "';\n" if $user_rkey->create();
	return "$data_dump\n$reskey_dump";

}

sub ajaxUpDownFirehose {
	my($slashdb, $constants, $user, $form, $options) = @_;
	$options->{content_type} = 'application/json';
	my $id = $form->{id};
	return unless $id;

	my $firehose = getObject('Slash::FireHose');
	my $tags = getObject('Slash::Tags');
	my $item = $firehose->getFireHose($id);
	return if !$item;

	my($dir) = $form->{dir};
	my $upvote   = $constants->{tags_upvote_tagname}   || 'nod';
	my $downvote = $constants->{tags_downvote_tagname} || 'nix';
	my $tag;
	if ($dir eq "+") {
		$tag = $upvote;
	} elsif ($dir eq "-") {
		$tag = $downvote;
	}
	return if !$tag;

	my($table, $itemid) = $tags->getGlobjTarget($item->{globjid});
	my $now_tags_ar = $tags->getTagsByNameAndIdArrayref($table, $itemid, { uid => $user->{uid}});
	my @tags = sort Slash::Tags::tagnameorder map { $_->{tagname} } @$now_tags_ar;
	push @tags, $tag;
	my $tagsstring = join ' ', @tags;
	# XXX Tim, I need you to look this over. - Jamie 2006/09/19
	my $newtagspreloadtext = $tags->setTagsForGlobj($itemid, $table, $tagsstring);
	my $html  = {};
	my $value = {};

	my $votetype = $dir eq "+" ? "Up" : $dir eq "-" ? "Down" : "";
	$html->{"updown-$id"} = "Voted $votetype";
	$value->{"newtags-$id"} = $newtagspreloadtext;

	return Data::JavaScript::Anon->anon_dump({
		html	=> $html,
		value	=> $value
	});
}

sub ajaxCreateForFirehose {
	my($slashdb, $constants, $user, $form, $options) = @_;
	$options->{content_type} = 'application/json';
	my $id = $form->{id};
	my $tags = getObject('Slash::Tags');
	my $tagsstring = $form->{tags};
	my $firehose = getObject('Slash::FireHose');

	if (!$id || $user->{is_anon} || !$tags) {
		return getData('error', {}, 'tags');
	}
	my $item = $firehose->getFireHose($id);
	if (!$item || !$item->{globjid}) {
		return getData('error', {}, 'tags');
	}
	my($table, $itemid) = $tags->getGlobjTarget($item->{globjid});
	if (!$itemid || !$table) {
		return getData('error', {}, 'tags');
	}
	my $newtagspreloadtext = $tags->setTagsForGlobj($itemid, $table, $tagsstring);

	if ($user->{is_admin}) {
		$firehose->setSectionTopicsFromTagstring($id, $tagsstring);
	}

	my $retval = slashDisplay('tagsfirehosedivuser', {
		id =>		$id,
		newtagspreloadtext =>	$newtagspreloadtext,
	}, { Return => 1 });

#print STDERR scalar(localtime) . " ajaxCreateForFirehose 4 for id=$id tagnames='@tagnames' newtagspreloadtext='$newtagspreloadtext' returning: $retval\n";

	return $retval;
}

sub ajaxGetFormContents {
	my($slashdb, $constants, $user, $form) = @_;
	return unless $user->{is_admin} && $form->{id};
	my $firehose = getObject("Slash::FireHose");
	my $id = $form->{id};
	my $item = $firehose->getFireHose($id);
	return unless $item;
	my $url;
	$url = $slashdb->getUrl($item->{url_id}) if $item->{url_id};
	my $the_user = $slashdb->getUser($item->{uid});
	slashDisplay('fireHoseForm', { item => $item, url => $url, the_user => $the_user }, { Return => 1});
}

sub ajaxGetAdminExtras {
	my($slashdb, $constants, $user, $form, $options) = @_;
	$options->{content_type} = 'application/json';
	return unless $user->{is_admin} && $form->{id};
	my $firehose = getObject("Slash::FireHose");
	my $item = $firehose->getFireHose($form->{id});
	return unless $item;
	my $subnotes_ref = $firehose->getMemoryForItem($item);
	my $similar_stories = $firehose->getSimilarForItem($item);
	my $num_from_uid = 0;
	my $accepted_from_uid = 0;
	my $num_with_emaildomain = 0;
	my $accepted_from_emaildomain = 0;
	my $num_with_ipid = 0;
	my $accepted_from_ipid = 0;
	if ($item->{type} eq "submission") {
		$accepted_from_uid = $slashdb->countSubmissionsFromUID($item->{uid}, { del => 2 });
		$num_from_uid = $slashdb->countSubmissionsFromUID($item->{uid});
		$accepted_from_emaildomain = $slashdb->countSubmissionsWithEmaildomain($item->{emaildomain}, { del => 2 });
		$num_with_emaildomain = $slashdb->countSubmissionsWithEmaildomain($item->{emaildomain});
		$num_with_ipid = $slashdb->countSubmissionsFromIPID($item->{ipid});
		$accepted_from_ipid = $slashdb->countSubmissionsFromIPID($item->{ipid}, { del => 2});
	}

	my $the_user = $slashdb->getUser($item->{uid});

	my $byline = getData("byline", {
		item				=> $item,
		the_user			=> $the_user,
		adminmode			=> 1,
		extras 				=> 1,
		hidediv				=> 1,
		num_from_uid    		=> $num_from_uid,
		accepted_from_uid 		=> $accepted_from_uid,
		num_with_emaildomain 		=> $num_with_emaildomain,
		accepted_from_emaildomain 	=> $accepted_from_emaildomain,
		accepted_from_ipid		=> $accepted_from_ipid,
		num_with_ipid			=> $num_with_ipid,
	}, "firehose");

	my $admin_extras = slashDisplay("admin_extras", {
		item				=> $item,
		subnotes_ref			=> $subnotes_ref,
		similar_stories			=> $similar_stories,
	}, { Return => 1 });

	return Data::JavaScript::Anon->anon_dump({
		html => {
			"details-$item->{id}" 		=> $byline,
			"admin-extras-$item->{id}" 	=> $admin_extras
		}
	});
}

sub setSectionTopicsFromTagstring {
	my($self, $id, $tagstring) = @_;
	my $constants = getCurrentStatic();

	my @tags = split(/\s+/, $tagstring);
	my $data = {};

	my %categories = map { ($_, $_) } (qw(hold quik),
		(ref $constants->{submit_categories}
			? map {lc($_)} @{$constants->{submit_categories}}
			: ()
		)
	);

	foreach (@tags) {
		my $skid = $self->getSkidFromName($_);
		my $tid = $self->getTidByKeyword($_);
		if ($skid) {
			$data->{primaryskid} = $skid;
		}
		if ($tid) {
			$data->{tid} = $tid;
		}
		if ($categories{lc($_)}) {
			$data->{category} = lc($_);
		}
	}
	$self->setFireHose($id, $data) if keys %$data > 0;

}

sub setFireHose {
	my($self, $id, $data) = @_;
	return unless $id && $data;
	my $id_q = $self->sqlQuote($id);
	
	my $mcd = $self->getMCD();
	my $mcdkey = "$self->{_mcd_keyprefix}:firehose";

	if (!exists($data->{last_update}) && !exists($data->{-last_update})) {
		my @non_trivial = grep {!/^(activity|toptags)$/} keys %$data;
		if (@non_trivial > 0) {
			$data->{-last_update} = 'NOW()';
		} else {
			$data->{-last_update} = 'last_update';
		}
	}

	# Admin notes used to be stored in firehose.note;  that column is
	# now gone and that data goes in globj_adminnote.  The note is
	# stored on the object that the firehose points to.
	if (exists $data->{note}) {
		my $note = delete $data->{note};
		# XXX once getFireHose does caching, use that instead of an sqlSelect
		my $globjid = $self->sqlSelect('globjid', 'firehose', "id=$id_q");
		warn "no globjid for firehose '$id'" if !$globjid;
		$self->setGlobjAdminnote($globjid, $note);
	}

	return if !keys %$data;

	my $text_data = {};

	$text_data->{title} = delete $data->{title} if defined $data->{title};
	$text_data->{introtext} = delete $data->{introtext} if defined $data->{introtext};
	$text_data->{bodytext} = delete $data->{bodytext} if defined $data->{bodytext};

	$self->sqlUpdate('firehose', $data, "id=$id_q");
	$self->sqlUpdate('firehose_text', $text_data, "id=$id_q") if keys %$text_data;
	
	if ($mcd) {
		 $mcd->delete("$mcdkey:$id", 3);
	}

	my $searchtoo = getObject('Slash::SearchToo');
	if ($searchtoo) {
		my $status = 'changed';
# for now, no deletions ... this is what it would look like if we did!
#		$status = 'deleted' if $data->{accepted} eq 'yes' || $data->{rejected} eq 'yes';
		$searchtoo->storeRecords(firehose => $id, { $status => 1 });
	}
}

sub dispFireHose {
	my($self, $item, $options) = @_;
	$options ||= {};

	slashDisplay('dispFireHose', {
		item		=> $item,
		mode		=> $options->{mode},
		tags_top	=> $options->{tags_top},
		options		=> $options->{options},
		vote		=> $options->{vote}
	}, { Page => "firehose",  Return => 1 });
}

sub getMemoryForItem {
	my($self, $item) = @_;
	my $user = getCurrentUser();
	$item = $self->getFireHose($item) if $item && !ref $item;
	return [] unless $item && $user->{is_admin};
	my $subnotes_ref = [];
	my $sub_memory = $self->getSubmissionMemory();
	foreach my $memory (@$sub_memory) {
		my $match = $memory->{submatch};

		if ($item->{email} =~ m/$match/i ||
		    $item->{name}  =~ m/$match/i ||
		    $item->{title}  =~ m/$match/i ||
		    $item->{ipid}  =~ m/$match/i ||
		    $item->{introtext} =~ m/$match/i) {
			push @$subnotes_ref, $memory;
		}
	}
	return $subnotes_ref;
}

sub getSimilarForItem {
	my($self, $item) = @_;
	my $user 	= getCurrentUser();
	my $constants   = getCurrentStatic();
	$item = $self->getFireHose($item) if $item && !ref $item;
	return [] unless $item && $user->{is_admin};
	my $num_sim = $constants->{similarstorynumshow} || 5;
	my $reader = getObject("Slash::DB", { db_type => "reader" });
	my $storyref = {
		title 		=> $item->{title},
		introtext 	=> $item->{introtext}
	};
	if ($item->{type} eq "story") {
		my $story = $self->getStory($item->{srcid});
		$storyref->{sid} = $story->{sid} if $story && $story->{sid};
	}
	my $similar_stories = [];
	$similar_stories = $reader->getSimilarStories($storyref, $num_sim) if $user->{is_admin};

	# Truncate that data to a reasonable size for display.

	if ($similar_stories && @$similar_stories) {
		for my $sim (@$similar_stories) {
			# Display a max of five words reported per story.
			$#{$sim->{words}} = 4 if $#{$sim->{words}} > 4;
			for my $word (@{$sim->{words}}) {
				# Max of 12 chars per word.
				$word = substr($word, 0, 12);
			}
			$sim->{title} = chopEntity($sim->{title}, 35);
		}
	}
	return $similar_stories;
}


sub getAndSetOptions {
	my($self, $opts) = @_;
	my $user 	= getCurrentUser();
	my $constants 	= getCurrentStatic();
	my $form 	= getCurrentForm();
	$opts 	        ||= {};
	my $options 	= {};

	my $types = { feed => 1, bookmark => 1, submission => 1, journal => 1, story => 1, vendor => 1 };
	my $modes = { full => 1, fulltitle => 1};

	my $mode = $form->{mode} || $user->{firehose_mode};
	$mode = $modes->{$mode} ? $mode : "fulltitle";
	$options->{mode} = $mode;
	$options->{pause} = $user->{firehose_paused};
	$options->{duration} = defined $form->{duration} ? $form->{duration} : $user->{firehose_duration};

	if (defined $form->{pause}) {
		$self->setUser($user->{uid}, { firehose_paused => $form->{pause} ? 1 : 0 });
		$options->{pause} = $form->{pause} ? 1 : 0;
	}

	if (defined $form->{startdate}) {
		if ($form->{startdate} =~ /^\d{8}$/) {
			my ($y, $m, $d) = $form->{startdate} =~ /(\d{4})(\d{2})(\d{2})/;
			if ($y) {
				$options->{startdate} = "$y-$m-$d";
			}
		}
	}
	$options->{startdate} = "" if !$options->{startdate};
	

	my $colors = $self->getFireHoseColors();

	if ($form->{color} && $colors->{$form->{color}}) {
		$options->{color} = $form->{color};
	}
	$options->{color} ||= $user->{firehose_color};

	if ($form->{orderby}) {
		if ($form->{orderby} eq "popularity") {
			if ($user->{is_admin} && !$user->{firehose_usermode}) {
				$options->{orderby} = "editorpop";
			} else {
				$options->{orderby} = "popularity";
			}
		} else {
			$options->{orderby} = "createtime";
		}

	} else {
		$options->{orderby} = $user->{firehose_orderby} || "createtime";
	}

	if ($form->{orderdir}) {
		if (uc($form->{orderdir}) eq "ASC") {
			$options->{orderdir} = "ASC";
		} else {
			$options->{orderdir} = "DESC";
		}

	} else {
		$options->{orderdir} = $user->{firehose_orderdir} || "DESC";
	}

	my $fhfilter;


	if (defined $form->{fhfilter}) {
		$fhfilter = $form->{fhfilter};
		$options->{fhfilter} = $fhfilter;
	} else {
		$fhfilter = $user->{firehose_fhfilter};
		$options->{fhfilter} = $fhfilter;
	}
	
	# XXX
	my $user_tabs = $self->getUserTabs();
	my %user_tab_names = map { $_->{tabname} => 1 } @$user_tabs;
	my %firehose_tabs_given = map { $_ => 1 }split (/\|/, $user->{firehose_tabs_given});
	my @tab_fields = qw(tabname filter mode color orderdir orderby);
	my $tabs_given = "";

	my $system_tabs = $self->getSystemDefaultTabs();
	foreach my $tab (@$system_tabs) {
		my $data = {};
		foreach (@tab_fields) {
			$data->{$_} = $tab->{$_};
			
			if ($tab->{$_} eq "User" && $_ eq "tabname") {
				$data->{$_} = $user->{nickname};
				$data->{$_} =~ s/[^A-Za-z0-9_-]//g;
				if(length $data->{$_} > 16) {
					$data->{$_} = substr($data->{$_}, 0, 16);
				}
				$data->{$_} = "User" if length($data->{$_}) == 0;
			}
			foreach my $field (qw(uid nickname)) {
				$data->{$_} =~ s/{$field}/$user->{$field}/g;
			}
		}
		if (!$user_tab_names{$tab->{tabname}} && !$firehose_tabs_given{$tab->{tabname}}) {
			$self->createUserTab($user->{uid}, $data); 
			$tabs_given .= $tab->{tabname} ."|";
			$self->setUser($user->{uid}, { firehose_tabs_given => $tabs_given });
		}
	}
	$user_tabs = $self->getUserTabs();


	
	my $tab_compare = { mode => "mode", orderdir => "orderdir", color => "color", orderby => "orderby", filter => "fhfilter" };

	my $tab_match = 0;
	foreach my $tab (@$user_tabs) {
		my $equal = 1;
		foreach (keys %$tab_compare) {
			$options->{$tab_compare->{$_}} ||= "";
			if ($tab->{$_} ne $options->{$tab_compare->{$_}}) {
				$equal = 0;
				#print STDERR "$tab->{tabname} -> $_ doesn't match\n";
			}
		}
		if ($equal) {
			# print STDERR "Tab match $tab->{tabname}\n";
			$tab_match = 1;
			$tab->{active} = 1;
		}
	}

	if (!$tab_match) {
		my $data = {};
		foreach (keys %$tab_compare) {
			$data->{$_} = $options->{$tab_compare->{$_}} || '';
		}
		$self->createOrReplaceUserTab($user->{uid}, "untitled", $data);
		$user_tabs = $self->getUserTabs();
		foreach (@$user_tabs) {
			$_->{active} = 1 if $_->{tabname} eq "untitled" 
		}
	}

	if (defined $form->{tab}) {
		my $tabnames_hr = {};
		foreach (@$user_tabs) {
			$tabnames_hr->{$_->{tabname}} = $_;
		}
		if ($tabnames_hr->{$form->{tab}}) {
			my $curtab = $tabnames_hr->{$form->{tab}};
			$mode = $options->{mode} = $curtab->{mode};
			$options->{orderby} = $curtab->{orderby};
			$options->{orderdir} = $curtab->{orderdir};
			$options->{color} = $curtab->{color};
			$fhfilter = $options->{fhfilter} = $curtab->{filter};

			$_->{active} = $_->{tabname} eq $form->{tab} ? 1 : 0  foreach @$user_tabs;
		}
	}


	
	if ($mode eq "full") {
		if ($user->{is_admin}) {
			$options->{limit} = 25;
		} else {
			$options->{limit} = 15;
		}
	} else {
		if ($user->{is_admin}) {
			$options->{limit} = 50;
		} else {
			$options->{limit} = 30;
		}
	}
	if ($user->{is_admin} && $form->{setusermode}) {
		$self->setUser($user->{uid}, { firehose_usermode => $form->{firehose_usermode} ? 1 : "" });
	}

	if ($form->{setfield}) {
		foreach (qw(nodates nobylines)) {
			if ($form->{defined}) {
				$options->{$_} = $form->{$_} ? 1 : 0;
			} else {
				$options->{$_} = $user->{"firehose_$_"};
			}
		}
	}
	$options->{nodates}   = defined $form->{nodates} ? $form->{nodates}   : $user->{firehose_nodates};
	$options->{nobylines} = defined $form->{nobylines} ? $form->{nobylines} : $user->{firehose_nobylines};

	my $page = $form->{page} || 0;
	$options->{page} = $page;
	if ($page) {
		$options->{offset} = $page * $options->{limit};
	}


	$fhfilter =~ s/^\s+|\s+$//g;
	my $fh_ops = $self->splitOpsFromString($fhfilter);
	

	my $skins = $self->getSkins();
	my %skin_names = map { $skins->{$_}{name} => $_ } keys %$skins;

	my %categories = map { ($_, $_) } (qw(hold quik),
		(ref $constants->{submit_categories}
			? map {lc($_)} @{$constants->{submit_categories}}
			: ()
		)
	);

	my $authors = $self->getAuthors();
	my %author_names = map { lc($authors->{$_}{nickname}) => $_ } keys %$authors;
	my $fh_options = {};
	foreach (@$fh_ops) {
		if ($types->{$_} && !defined $fh_options->{type}) {
			$fh_options->{type} = $_;
		} elsif ($user->{is_admin} && $categories{$_} && !defined $fh_options->{category}) {
			$fh_options->{category} = $_;
		} elsif ($skin_names{$_} && !defined $fh_options->{primaryskid}) {
			$fh_options->{primaryskid} = $skin_names{$_};
		} elsif ($user->{is_admin} && $_ eq "rejected") {
			$fh_options->{rejected} = "yes";
		} elsif ($_ eq "accepted") {
			$fh_options->{accepted} = "yes";
		} elsif ($user->{is_admin} && $_ eq "signed") {
			$fh_options->{signed} = 1;
		} elsif ($user->{is_admin} && $_ eq "unsigned") {
			$fh_options->{unsigned} = 1;
		} elsif (/^author:/) {
			my $nick = $_;
			my $uid;
			$nick =~ s/author://g;
			if ($nick) {
				$uid = $self->getUserUID($nick);
				$uid ||= $user->{uid};
			}
			$fh_options->{uid} = $uid;
		} elsif (/^user:/) {
			my $nick = $_;
			$nick =~ s/user://g;
			my $uid;
			if ($nick) {
				$uid = $self->getUserUID($nick);
			}
			$uid ||= $user->{uid};
			$fh_options->{tagged_by_uid} = $uid;
			$fh_options->{ignore_nix} = 1;
		} else {
			if (!defined $fh_options->{filter}) {
				$fh_options->{filter} = $_;
				$fh_options->{filter} =~ s/[^a-zA-Z0-9_-]+//g;
			}
			# Don't filter this
			$fh_options->{qfilter} .= $_ . ' ';
		}
	}

	if ($form->{color} && $colors->{$form->{color}}) {
		$fh_options->{color} = $form->{color};
	}

	foreach (keys %$fh_options) {
		$options->{$_} = $fh_options->{$_};
	}

	if (!$user->{is_anon} && !$opts->{no_set}) {
		my $data_change = {};
		foreach (keys %$options) {
			$data_change->{"firehose_$_"} = $options->{$_} if !defined $user->{"firehose_$_"} || $user->{"firehose_$_"} ne $options->{$_};
		}
		$self->setUser($user->{uid}, $data_change) if keys %$data_change > 0;
	}

	$options->{tabs} = $user_tabs;

	if ($user->{is_admin} && $form->{setusermode}) {
		$options->{firehose_usermode} = $form->{firehose_usermode} ? 1 : "";
	}

	my $adminmode = 0;
	$adminmode = 1 if $user->{is_admin};
	if (defined $options->{firehose_usermode}) {
		$adminmode = 0 if $options->{firehose_usermode};
	} else {
		$adminmode = 0 if $user->{firehose_usermode};
	}

	$options->{public} = "yes";
	if ($adminmode) {
		# $options->{attention_needed} = "yes";
		$options->{accepted} = "no" if !$options->{accepted};
		$options->{rejected} = "no" if !$options->{rejected};
		$options->{duration} ||= -1;
	} else  {
		$options->{accepted} = "no" if !$options->{accepted};
		$options->{duration} ||= 1;
		if ($user->{is_subscriber}) {
			$options->{createtime_subscriber_future} = 1;
		} else {
			$options->{createtime_no_future} = 1;
		}
	}
	return $options;
}

sub getFireHoseTagsTop {
	my($self, $item) = @_;
	my $user 	= getCurrentUser();
	my $constants 	= getCurrentStatic();
	my $tags_top	 = [];
	if ($user->{is_admin}) {
		if ($item->{type} eq "story") {
			push @$tags_top, "$item->{type}:5";
		} else {
			push @$tags_top, "$item->{type}:6";
		}
	} else {
		push @$tags_top, ($item->{type});
	}
	
	if ($item->{primaryskid} && $item->{primaryskid} != $constants->{mainpage_skid}) {
		my $the_skin = $self->getSkin($item->{primaryskid});
		push @$tags_top, "$the_skin->{name}:2";
	}
	if ($item->{tid}) {
		my $the_topic = $self->getTopic($item->{tid});
		push @$tags_top, "$the_topic->{keyword}:3";
	}
	my %seen_tags = map { $_ => 1 } @$tags_top;
	
	push @$tags_top, map { "$_:0" } grep {!$seen_tags{$_}} split (/\s+/, $item->{toptags});

	return $tags_top;
}

sub getMinPopularityForColorLevel {
	my($self, $level) = @_;
	my $slashdb = getCurrentDB();
	my $levels = $slashdb->getVar('firehose_slice_points', 'value', 1);
	my @levels = split(/\|/, $levels);
	return $levels[$level - 1 ];
}

sub getMidPopularityForColorLevel {
	my($self, $level) = @_;
	my $slashdb = getCurrentDB();
	my $levels = $slashdb->getVar('firehose_slice_points', 'value', 1);
	my @levels = split(/\|/, $levels);
	my $min = $levels[$level - 1 ];

	my $maxindex = $level - 2;
	my $max = $maxindex >= 0 && defined $levels[$maxindex] ? $levels[$maxindex] : $levels[$level - 1] + 5;
	return (($min + $max) / 2);
}

sub getPopLevelForPopularity {
	my($self, $pop) = @_;
	my $slashdb = getCurrentDB();
	my $levels = $slashdb->getVar('firehose_slice_points', 'value', 1);
	my @levels = split(/\|/, $levels);
	my $i = 0;
	for ($i=0; $i< $#levels; $i++) {
		return $i+1 if $pop >= $levels[$i];
	}
	return $i + 1;
}

sub listView {
	my ($self) = @_;
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $firehose_reader = getObject('Slash::FireHose', {db_type => 'reader'});
	my $options = $self->getAndSetOptions();

	my($items, $results) = $firehose_reader->getFireHoseEssentials($options);
	my $globjs;

	foreach (@$items) {
		push @$globjs, $_->{globjid} if $_->{globjid} 
	}

	my $votes = $self->getUserFireHoseVotesForGlobjs($user->{uid}, $globjs);

	my $itemstext;
	my $maxtime = $slashdb->getTime();
	my $now = $slashdb->getTime();
	my $colors = $self->getFireHoseColors(1);
	my $colors_hash = $self->getFireHoseColors();
	
	foreach (@$items) {
		$maxtime = $_->{createtime} if $_->{createtime} gt $maxtime && $_->{createtime} lt $now;
		my $item =  $firehose_reader->getFireHose($_->{id});
		my $tags_top = $firehose_reader->getFireHoseTagsTop($item);
		$itemstext .= $self->dispFireHose($item, {
			mode		=> $options->{mode},
			tags_top	=> $tags_top,
			options		=> $options,
			vote		=> $votes->{$item->{globjid}},
		});
	}
	my $Slashboxes = displaySlashboxes();
	my $refresh_options;
	$refresh_options->{maxtime} = $maxtime;
	if (uc($options->{orderdir}) eq "ASC") {
		$refresh_options->{insert_new_at} = "bottom";
	} else {
		$refresh_options->{insert_new_at} = "top";
	}
	slashDisplay("list", {
		itemstext	=> $itemstext, 
		page		=> $options->{page}, 
		options		=> $options,
		refresh_options	=> $refresh_options,
		votes		=> $votes,
		colors		=> $colors,
		colors_hash	=> $colors_hash,
		tabs		=> $options->{tabs},
		slashboxes	=> $Slashboxes
	}, { Page => "firehose", Return => 1});
}

sub setFireHoseSession {
	my ($self, $id) = @_;
	my $user = getCurrentUser();
	my $item = $self->getFireHose($id);
	my $data = {};
	$data->{lasttitle} = $item->{title};
	if ($item->{type} eq "story") {
		my $story = $self->getStory($item->{srcid});
		$data->{last_sid} = $story->{sid} if $story && $story->{sid};
	} 

	if (!$data->{last_sid}) {
		$data->{last_fhid} = $item->{id};
	}
	$data->{last_subid} ||= '';
	$data->{last_sid} ||= '';
	$self->setSession($user->{uid}, $data);
}

sub getUserTabs {
	my($self, $options) = @_;
	$options ||= {};
	my $user = getCurrentUser();
	my $uid_q = $self->sqlQuote($user->{uid});
	my @where;
	push @where, "uid=$uid_q";
	push @where, "tabname like '$options->{prefix}%'";
	my $where = join ' AND ', @where;

	my $tabs = $self->sqlSelectAllHashrefArray("*", "firehose_tab", $where, "order by tabname asc");
	@$tabs = sort { 
			$b->{tabname} eq "untitled" ? -1 : 
				$a->{tabname} eq "untitled" ? 1 : 0	||
			$b->{tabname} eq "User" ? -1 : 
				$a->{tabname} eq "User" ? 1 : 0	||
			$a->{tabname} cmp $b->{tabname} 
	} @$tabs;
	return $tabs;
}

sub getSystemDefaultTabs {
	my($self) = @_;
	return $self->sqlSelectAllHashrefArray("*", "firehose_tab", "uid='0'")
}

sub createUserTab {
	my($self, $uid, $data) = @_;
	$data->{uid} = $uid;
	$self->sqlInsert("firehose_tab", $data);
}

sub createOrReplaceUserTab {
	my($self, $uid, $name, $data) = @_;
	return if !$uid;
	$data ||= {};
	$data->{uid} = $uid;
	$data->{tabname} = $name;
	$self->sqlReplace("firehose_tab", $data);
}

sub ajaxFirehoseListTabs {
	my($slashdb, $constants, $user, $form) = @_;
	my $firehose = getObject("Slash::FireHose");
	my $tabs = $firehose->getUserTabs({ prefix => $form->{prefix}});
	@$tabs = map { $_->{tabname}} grep { $_->{tabname} ne "untitled" } @$tabs;
	return join "\n", @$tabs;
}

sub splitOpsFromString {
	my ($self, $str) = @_;
	my @fh_ops_orig = map { lc($_) } split((/\s+|"/), $str);
	my @fh_ops;
	
	my $in_quotes = 0;
	my $cur_op = "";
	foreach (@fh_ops_orig) {
		if (!$in_quotes && $_ eq '"') {
			$in_quotes = 1;
		} elsif ($in_quotes) {
			if ($_ eq '"') {
				push @fh_ops, $cur_op;
				$cur_op = "";
				$in_quotes = 0;
			} else {
				$cur_op .= $_;
			}
		} elsif (/\S+/) {
			push @fh_ops, $_;
		}
	}
	return \@fh_ops;
}


1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id: FireHose.pm,v 1.101 2007/03/21 22:25:48 tvroom Exp $
