# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: Search.pm,v 1.43 2002/10/01 19:55:13 brian Exp $

package Slash::Search;

use strict;
use Slash::Utility;
use Slash::DB::Utility;
use vars qw($VERSION);
use base 'Slash::DB::Utility';

($VERSION) = ' $Revision: 1.43 $ ' =~ /\$Revision:\s+([^\s]+)/;

# FRY: And where would a giant nerd be? THE LIBRARY!

#################################################################
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'Search'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect();

	return $self;
}

####################################################################################
# This has been changed. Since we no longer delete comments
# it is safe to have this run against stories.
sub findComments {
	my($self, $form, $start, $limit, $sort) = @_;
	# select comment ID, comment Title, Author, Email, link to comment
	# and SID, article title, type and a link to the article
	my $query = $self->sqlQuote($form->{query});
	my $constants = getCurrentStatic();
	my $columns;
	$columns .= "discussions.section as section, discussions.url as url, discussions.uid as author_uid,";
	$columns .= "discussions.title as title, pid, subject, ts, date, comments.uid as uid, ";
	$columns .= "comments.cid as cid, discussions.id as did ";
	$columns .= ", TRUNCATE( " . $self->_score('comments.subject', $form->{query}, $constants->{search_method}) . ", 1) as score "
		if $form->{query};

	my $tables = "comments, discussions";

	my $key = " MATCH (comments.subject) AGAINST ($query) ";

	# Welcome to the join from hell -Brian
	my $where;
	$where .= " comments.sid = discussions.id ";
	$where .= "	  AND $key "
			if $form->{query};

	if ($form->{sid}) {
		if ($form->{sid} !~ /^\d+$/) {
			$where .= "     AND discussions.sid=" . $self->sqlQuote($form->{sid})
		} else {
			$where .= "     AND discussions.id=" . $self->sqlQuote($form->{sid})
		}
	}
	$where .= "     AND points >= " .  $self->sqlQuote($form->{threshold})
			if defined($form->{threshold});

	my $slashdb = getCurrentDB();
	my $section = $slashdb->getSection(); 
	if ($form->{section}) {
		if ($form->{section} ne $constants->{section}) {
			if ($section->{type} eq 'collected') {
				if (!$section->{contained}
					|| scalar(@{$section->{contained}}) == 0
					|| (grep { $form->{section} eq $_ } @{$section->{contained}})
				) {
					$where .= " AND discussions.section = ". $self->sqlQuote($form->{section});
				} else {
					# Section doesn't belong to this contained section
					return;
				}
			} else  {
				# Means we are dealing with a contained section and this is not the contained section
				return;
			}
		} else {
			$where .= " AND discussions.section = ". $self->sqlQuote($form->{section});
		}
	} else {
		if ($section->{type} eq 'collected') {
			$where .= " AND discussions.section IN ('" . join("','", @{$section->{contained}}) . "')" 
				if $section->{contained} && @{$section->{contained}};
		} else {
			$where .= " AND discussions.section = " . $self->sqlQuote($section->{section});
		}
	}

	my $other;
	$other .= " HAVING score > 0 "
		if $form->{query};
	if ($form->{query} && $sort == 2) {
		$other = " ORDER BY score DESC ";
	} else {
		$other = " ORDER BY cid DESC ";
	}


	$other .= " LIMIT $start, $limit" if $limit;
	my $search = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other );

	return $search;
}


####################################################################################
# This has been changed. Since we no longer delete comments
# it is safe to have this run against stories.
# Original with comment body
#sub findComments {
#	my($self, $form, $start, $limit) = @_;
#	# select comment ID, comment Title, Author, Email, link to comment
#	# and SID, article title, type and a link to the article
#	my $query = $self->sqlQuote($form->{query});
#	my $columns = "section, stories.sid, stories.uid as author, discussions.title as title, pid, subject, stories.writestatus as writestatus, time, date, comments.uid as uid, comments.cid as cid ";
#	$columns .= ", TRUNCATE((((MATCH (comments.subject) AGAINST($query) + (MATCH (comment_text.comment) AGAINST($query)))) / 2), 1) as score "
#		if $form->{query};
#
#	my $tables = "stories, comments, comment_text, discussions";
#
#	my $key = " (MATCH (comments.subject) AGAINST ($query) or MATCH (comment_text.comment) AGAINST ($query)) ";
#
#
#	$limit = " LIMIT $start, $limit" if $limit;
#
#	# Welcome to the join from hell -Brian
#	my $where;
#	$where .= " comments.cid = comment_text.cid ";
#	$where .= " AND comments.sid = discussions.id ";
#	$where .= " AND discussions.sid = stories.sid ";
#	$where .= "	  AND $key "
#			if $form->{query};
#
#	$where .= "     AND stories.sid=" . $self->sqlQuote($form->{sid})
#			if $form->{sid};
#	$where .= "     AND points >= $form->{threshold} "
#			if $form->{threshold};
#	$where .= "     AND section=" . $self->sqlQuote($form->{section})
#			if $form->{section};
#
#	my $other;
#	if ($form->{query}) {
#		$other = " ORDER BY score DESC, time DESC ";
#	} else {
#		$other = " ORDER BY date DESC, time DESC ";
#	}
#
#
#	my $sql = "SELECT $columns FROM $tables WHERE $where $other $limit";
#
#	my $cursor = $self->{_dbh}->prepare($sql);
#	$cursor->execute;
#
#	my $search = $cursor->fetchall_arrayref;
#	return $search;
#}

####################################################################################
# I am beginnign to hate all the options.
sub findUsers {
	my($self, $form, $start, $limit, $sort, $with_journal) = @_;
	# userSearch REALLY doesn't need to be ordered by keyword since you
	# only care if the substring is found.
	my $query = $self->sqlQuote($form->{query});
	my $constants = getCurrentStatic();

	my $columns = 'fakeemail,nickname,users.uid as uid,journal_last_entry_date ';
	$columns .= ", TRUNCATE( " . $self->_score('nickname', $form->{query}, $constants->{search_method}) . ", 1) as score "
		if $form->{query};

	my $key = " MATCH (nickname) AGAINST ($query) ";
	my $tables = 'users';
	my $where .= ' seclev > 0 ';
	$where .= " AND $key" 
			if $form->{query};
	$where .= " AND journal_last_entry_date IS NOT NULL" 
			if $with_journal;


	my $other;
	$other .= " HAVING score > 0 "
		if $form->{query};
	if ($form->{query} && $sort == 2) {
		$other = " ORDER BY score "
	} else {
		$other = " ORDER BY users.uid "
	}

	$other .= " LIMIT $start, $limit" if $limit;
	my $users = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other );

	return $users;
}

####################################################################################
sub findStory {
	my($self, $form, $start, $limit, $sort) = @_;
	$start ||= 0;

	my $constants = getCurrentStatic();

	my $query = $self->sqlQuote($form->{query});
	my $columns;
	$columns .= "title, stories.sid as sid, "; 
	$columns .= "time, commentcount, stories.section as section,";
	$columns .= "tid, ";
	$columns .= "introtext ";
	$columns .= ", TRUNCATE((( " . $self->_score('title', $form->{query}, $constants->{search_method}) . "  + " .  $self->_score('introtext,bodytext', $form->{query}, $constants->{search_method}) .") / 2), 1) as score "
		if $form->{query};

	my $tables = "stories,story_text";

	my $other;
	$other .= " HAVING score > 0 "
		if $form->{query};
	if ($form->{query} && $sort == 2) {
		$other = " ORDER BY score DESC";
	} else {
		$other = " ORDER BY time DESC";
	}

	# The big old searching WHERE clause, fear it
	my $where = "stories.sid = story_text.sid ";
	$where .= " AND  (MATCH (stories.title) AGAINST ($query) or MATCH (introtext,bodytext) AGAINST ($query)) "
		if $form->{query};

	$where .= " AND time < now() AND stories.writestatus != 'delete' ";
	$where .= " AND stories.uid=" . $self->sqlQuote($form->{author})
		if $form->{author};
	$where .= " AND stories.submitter=" . $self->sqlQuote($form->{submitter})
		if $form->{submitter};
	$where .= " AND stories.subsection=" . $self->sqlQuote($form->{subsection})
		if $form->{subsection};
	$where .= " AND displaystatus != -1";

	my $slashdb = getCurrentDB();
	my $section = $slashdb->getSection(); 
	if ($form->{section}) {
		if ($form->{section} ne $constants->{section}) {
			if ($section->{type} eq 'collected') {
				if (!$section->{contained}
					|| scalar(@{$section->{contained}}) == 0
					|| (grep { $form->{section} eq $_ } @{$section->{contained}})
				) {
					$where .= " AND stories.section = " . $self->sqlQuote($form->{section});
				} else {
					# Section doesn't belong to this contained section
					# Tecnically we should return nothing but users are too dumb for that :)  -Brian
					$where .= " AND stories.section = " . $self->sqlQuote($form->{section});
				}
			} else  {
				# Means we are dealing with a contained section and this is not the contained section
				# Tecnically we should return nothing but users are too dumb for that :)  -Brian
				$where .= " AND stories.section = " . $self->sqlQuote($form->{section});
			}
		} else {
			$where .= " AND stories.section = " . $self->sqlQuote($form->{section});
		}
	} else {
		if ($section->{type} eq 'collected') {
			$where .= " AND stories.section IN ('" . join("','", @{$section->{contained}}) . "')" 
				if $section->{contained} && @{$section->{contained}};
		} else {
			$where .= " AND stories.section = " . $self->sqlQuote($section->{section});
		}
	}

	if (ref($form->{_multi}{tid}) eq 'ARRAY') {
		$where .= " AND tid IN (" . join(",", @{$form->{_multi}{tid}}) . ") "; 
	} else {
		$where .= " AND tid=" . $self->sqlQuote($form->{tid})
			if $form->{tid};
	}
	
	$other .= " LIMIT $start, $limit" if $limit;
	my $stories = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other );

	return $stories;
}

################################################################################
# DEad code at the moment -Brian
sub findRetrieveSite {
#	my($self, $query, $start, $limit, $sort) = @_;
#	$query = $self->sqlQuote($query);
#	$limit = " LIMIT $start, $limit" if $limit;
#
#	# Welcome to the join from hell -Brian
#	my $sql = " SELECT bid,title, MATCH (description,title,block) AGAINST($query) as score  FROM blocks WHERE rdf IS NOT NULL AND url IS NOT NULL and retrieve=1 AND MATCH (description,title,block) AGAINST ($query) $limit";
#
#
#	$self->sqlConnect();
#	my $cursor = $self->{_dbh}->prepare($sql);
#	$cursor->execute;
#
#	my $search = $cursor->fetchall_arrayref;
#	return $search;
}

####################################################################################
sub findJournalEntry {
	my($self, $form, $start, $limit, $sort) = @_;
	$start ||= 0;
	my $constants = getCurrentStatic();

	my $query = $self->sqlQuote($form->{query});
	my $columns;
	$columns .= "users.nickname as nickname, journals.description as description, ";
	$columns .= "journals.id as id, date, users.uid as uid, article";
	$columns .= ", TRUNCATE((( " . $self->_score('description', $form->{query}, $constants->{search_method}) . " + " .  $self->_score('article', $form->{query}, $constants->{search_method}) .") / 2), 1) as score "
		if $form->{query};
	my $tables = "journals, journals_text, users";
	my $other;
	$other .= " HAVING score > 0 "
		if ($form->{query});
	if ($form->{query} && $sort == 2) {
		$other .= " ORDER BY score DESC";
	} else {
		$other .= " ORDER BY date DESC";
	}

	# The big old searching WHERE clause, fear it
	my $key = " (MATCH (description) AGAINST ($query) or MATCH (article) AGAINST ($query)) ";
	my $where = "journals.id = journals_text.id AND journals.uid = users.uid ";
	$where .= " AND $key" if $form->{query};
	$where .= " AND users.nickname=" . $self->sqlQuote($form->{nickname})
		if $form->{nickname};
	$where .= " AND users.uid=" . $self->sqlQuote($form->{uid})
		if $form->{uid};
	$where .= " AND tid=" . $self->sqlQuote($form->{tid})
		if $form->{tid};
	
	$other .= " LIMIT $start, $limit" if $limit;
	my $stories = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other );

	return $stories;
}

####################################################################################
sub findPollQuestion {
	my($self, $form, $start, $limit, $sort) = @_;
	$start ||= 0;
	my $constants = getCurrentStatic();

	my $query = $self->sqlQuote($form->{query});
	my $columns = "qid, question, voters, date";
	$columns .= ", TRUNCATE( " . $self->_score('question', $form->{query}, $constants->{search_method}) . ", 1) as score "
		if $form->{query};
	my $tables = "pollquestions";
	my $other;
	$other .= " HAVING score > 0 "
		if ($form->{query});
	if ($form->{query} && $sort == 2) {
		$other = " ORDER BY score DESC";
	} else {
		$other = " ORDER BY date DESC";
	}

	# The big old searching WHERE clause, fear it
	my $key = " MATCH (question) AGAINST ($query) ";
	my $where = " 1 = 1 ";
	$where .= " AND $key" if $form->{query};
	$where .= " AND date < now() ";
	$where .= " AND uid=" . $self->sqlQuote($form->{uid})
		if $form->{uid};
	$where .= " AND topic=" . $self->sqlQuote($form->{tid})
		if $form->{tid};
	
	my $sql = "SELECT $columns FROM $tables WHERE $where $other";

	$other .= " LIMIT $start, $limit" if $limit;
	my $stories = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other );

	return $stories;
}

####################################################################################
sub findSubmission {
	my($self, $form, $start, $limit, $sort) = @_;
	$start ||= 0;
	my $constants = getCurrentStatic();

	my $query = $self->sqlQuote($form->{query});
	my $columns = "subid, subj, time, story";
	$columns .= ", TRUNCATE( " . $self->_score('subj,story', $form->{query}, $constants->{search_method}) . ", 1) as score "
		if $form->{query};
	my $tables = "submissions";
	my $other;
	$other .= " HAVING score > 0 "
		if ($form->{query});
	if ($form->{query} && $sort == 2) {
		$other = " ORDER BY score DESC";
	} else {
		$other = " ORDER BY time DESC";
	}

	# The big old searching WHERE clause, fear it
	my $key = " MATCH (subj,story) AGAINST ($query) ";
	my $where = " 1 = 1 ";
	$where .= " AND $key" if $form->{query};
	$where .= " AND uid=" . $self->sqlQuote($form->{uid})
		if $form->{uid};
	$where .= " AND tid=" . $self->sqlQuote($form->{tid})
		if $form->{tid};
	$where .= " AND note=" . $self->sqlQuote($form->{note})
		if $form->{note};
	
	$other .= " LIMIT $start, $limit" if $limit;
	my $stories = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other );

	return $stories;
}

####################################################################################
sub findRSS {
	my($self, $form, $start, $limit, $sort) = @_;
	$start ||= 0;
	my $constants = getCurrentStatic();

	my $query = $self->sqlQuote($form->{query});
	my $columns = "title, link, description, created";
	$columns .= ", TRUNCATE( " . $self->_score('title,description', $form->{query}, $constants->{search_method}) . ", 1) as score "
		if $form->{query};
	my $tables = "rss_raw";
	my $other;
	$other .= " HAVING score > 0 "
		if ($form->{query});
	if ($form->{query} && $sort == 2) {
		$other = " ORDER BY score DESC";
	} else {
		$other = " ORDER BY created DESC";
	}

	# The big old searching WHERE clause, fear it
	my $key = " MATCH (title,description) AGAINST ($query) ";
	my $where = " 1 = 1 ";
	$where .= " AND $key" if $form->{query};
	$where .= " AND bid=" . $self->sqlQuote($form->{bid})
		if $form->{bid};
	
	$other .= " LIMIT $start, $limit" if $limit;
	my $stories = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other );

	return $stories;
}

####################################################################################
sub findDiscussion {
	my($self, $form, $start, $limit, $sort) = @_;
	my $constants = getCurrentStatic();
	$start ||= 0;

	my $query = $self->sqlQuote($form->{query});
	my $columns = "*";
	$columns .= ", TRUNCATE( " . $self->_score('title', $form->{query}, $constants->{search_method}) . ", 1) as score "
		if $form->{query};
	my $tables = "discussions";
	my $other;
	$other .= " HAVING score > 0 "
		if ($form->{query});
	if ($form->{query} && $sort == 2) {
		$other = " ORDER BY score DESC";
	} elsif ($sort == 3) {
		$other = " ORDER BY last_update DESC";
	} else {
		$other = " ORDER BY ts DESC";
	}

	# The big old searching WHERE clause, fear it
	my $key = " MATCH (title) AGAINST ($query) ";
	my $where = " ts <= now() ";
	$where .= " AND $key" 
		if $form->{query};
	$where .= " AND type=" . $self->sqlQuote($form->{type})
		if $form->{type};
	$where .= " AND topic=" . $self->sqlQuote($form->{tid})
		if $form->{tid};
	$where .= " AND section=" . $self->sqlQuote($form->{section})
		if $form->{section};
	$where .= " AND uid=" . $self->sqlQuote($form->{uid})
		if $form->{uid};
	$where .= " AND approved = " . $self->sqlQuote($form->{approved})
		if defined($form->{approved})
			&& $constants->{discussion_approval};
	
	$other .= " LIMIT $start, $limit" if $limit;
#	print STDERR "select $columns from $tables where $where $other\n";
	my $stories = $self->sqlSelectAllHashrefArray($columns, $tables, $where, $other );

	return $stories;
}

sub _score {
	my ($self, $col, $query, $method) = @_;
	if ($method) {
		my $terms;
		for (split / /, $query) {
			$terms .= $self->sqlQuote($_) . ",";
		}
		chop($terms);
		return "($method($col, $terms))";
	} else {
		$query =  $self->sqlQuote($query);
		return "\n(MATCH ($col) AGAINST($query))\n";
	}
}

#################################################################
sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect unless $ENV{GATEWAY_INTERFACE};
}

1;
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::Search - Slash Search module

=head1 SYNOPSIS

	use Slash::Search;

=head1 DESCRIPTION

Slash search module.

Blah blah blah.

=head1 SEE ALSO

Slash(3).

=cut
