# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: Slash.pm,v 1.38 2002/01/29 17:59:45 pater Exp $

package Slash;

# BENDER: It's time to kick some shiny metal ass!

=head1 NAME

Slash - the BEAST

=head1 SYNOPSIS

	use Slash;  # figure the rest out ;-)

=head1 DESCRIPTION

Slash is the code that runs Slashdot.

=head1 FUNCTIONS

=cut

use strict;  # ha ha ha ha ha!
use Symbol 'gensym';

use Slash::Constants ':people';
use Slash::DB;
use Slash::Display;
use Slash::Utility;
use Time::Local;

use base 'Exporter';
use vars qw($VERSION @EXPORT);

$VERSION   	= '2.003000';  # v2.3.0
# note: those last two lines of functions will be moved elsewhere
@EXPORT		= qw(
	getData
	gensym

	dispComment displayStory displayThread dispStory
	getOlderStories moderatorCommentLog printComments
);

# all of these will also get moved elsewhere
# @EXPORT_OK = qw(
# 	getCommentTotals reparentComments selectComments
# );

# this is the worst damned warning ever, so SHUT UP ALREADY!
$SIG{__WARN__} = sub { warn @_ unless $_[0] =~ /Use of uninitialized value/ };

# BENDER: Fry, of all the friends I've had ... you're the first.


########################################################
# Behold, the beast that is threaded comments
sub selectComments {
	my($header, $cid) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my($min, $max) = ($constants->{comment_minscore}, 
			  $constants->{comment_maxscore});
	my $num_scores = $max - $min + 1;

	my $comments; # One bigass struct full of comments
	foreach my $x (0..$num_scores-1) {
		$comments->{0}{totals}[$x] = 
		$comments->{0}{natural_totals}[$x] = 0;
	}

	# When we pull comment text from the DB, we only want to cache it if
	# there's a good chance we'll use it again.
	my $cache_read_only = 0;
	$cache_read_only = 1 if $header->{writestatus} eq 'archived';
	$cache_read_only = 1 if timeCalc($header->{ts}, '%s') <
		time - 3600 * $constants->{comment_cache_max_hours};

	my $thisComment = $slashdb->getCommentsForUser(
		$header->{id}, 
		$cid, 
		$cache_read_only
	);
	return ( {}, 0 ) unless $thisComment;

	# We first loop through the comments and assign bonuses and
	# and such.
	for my $C (@$thisComment) {
		# By setting pid to zero, we remove the threaded
		# relationship between the comments
		$C->{pid} = 0 if $user->{commentsort} > 3; # Ignore Threads

		# User can setup to give points based on size.
		$C->{points}++ if length($C->{comment}) > $user->{clbig}
			&& $C->{points} < $max && $user->{clbig} != 0;

		# User can setup to give points based on size.
		$C->{points}-- if length($C->{comment}) < $user->{clsmall}
			&& $C->{points} > $min && $user->{clsmall};

		# If the user is AC and we think AC's suck
		$C->{points} = -1 if ($user->{anon_comments} && isAnon($C->{uid}));

		# Adjust reasons. Do we need a reason?
		# Are you threatening me?
		my $reason =  $constants->{reasons}[$C->{reason}];
		$C->{points} += $user->{"reason_alter_$reason"} 
				if ($user->{"reason_alter_$reason"});

		# Keep your friends close but your enemies closer.
		# Or ignore them, we don't care.
		$C->{points} += $user->{people_bonus_friend}
			if ($user->{people}{$C->{uid}} == FRIEND);
		$C->{points} += $user->{people_bonus_foe}
			if ($user->{people}{$C->{uid}} == FOE);

		# fix points in case they are out of bounds
		$C->{points} = $min if $C->{points} < $min;
		$C->{points} = $max if $C->{points} > $max;
	}

	# If we are sorting by highest score we resort to figure in bonuses
	@$thisComment = sort { $b->{points} <=> $a->{points} || $a->{cid} <=> $b->{cid} } @$thisComment
		if $user->{commentsort} == 3;

	# This loop mainly takes apart the array and builds 
	# a hash with the comments in it.  Each comment is
	# is in the index of the hash (based on its cid).
	for my $C (@$thisComment) {
		# So we save information. This will only have data if we have 
		# happened through this cid while it was a pid for another
		# comments. -Brian
		my $tmpkids = $comments->{$C->{cid}}{kids};
		my $tmpvkids = $comments->{$C->{cid}}{visiblekids};

		# We save a copy of the comment in the root of the hash
		# which we will use later to find it via its cid
		$comments->{$C->{cid}} = $C;

		# Kids is what displayThread will actually use.
		$comments->{$C->{cid}}{kids} = $tmpkids;
		$comments->{$C->{cid}}{visiblekids} = $tmpvkids;

		# The comment pushes itself onto it own kids structure 
		# which should make it the first -Brian
		push @{$comments->{$C->{pid}}{kids}}, $C->{cid};

		# The next line deals with hitparade -Brian
		$comments->{0}{totals}[$C->{points} - $min]++;  # invert minscore

		# This deals with what will appear.
		$comments->{$C->{pid}}{visiblekids}++
			if $C->{points} >= ($user->{threshold} || $min);

		# Can't mod in a discussion that you've posted in.
		# Just a point rule -Brian
		$user->{points} = 0 if $C->{uid} == $user->{uid}; # Mod/Post Rule
	}

	my $count = @$thisComment;

	# Cascade comment point totals down to the lowest score, so
	# (2, 1, 3, 5, 4, 2, 1) becomes (18, 16, 15, 12, 7, 3, 1).
	for my $x (reverse(0..$num_scores-2)) {
		$comments->{0}{totals}[$x] += $comments->{0}{totals}[$x + 1];
		$comments->{0}{natural_totals}[$x]+=
			$comments->{0}{natural_totals}[$x + 1];
	}

	if ($form->{ssi} && $header->{sid}) {
	# DEPRECATED!
	#	$slashdb->updateCommentTotals($header->{sid}, $comments)
	#		if $form->{mode} ne 'archive';
	
		# If we are refreshing, PRINT the totals so freshenup/archive 
		# tasks can update without having to redo all of the work.
		my $hp = join ',', @{$comments->{0}{totals}};
		print STDERR "count $count, hitparade $hp\n";
	}

	reparentComments($comments, $header);
	return($comments, $count);
}

########################################################
sub reparentComments {
	my($comments) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $depth = $constants->{max_depth} || 7;

	return if $user->{state}{noreparent} || (!$depth && !$user->{reparent});

	# adjust depth for root pid or cid
	if (my $cid = $form->{cid} || $form->{pid}) {
		while ($cid && (my($pid) = $slashdb->getComment($cid, 'pid'))) {
			$depth++;
			$cid = $pid;
		}
	}

	# You know, we do assume comments are linear -Brian
	for my $x (sort { $a <=> $b } keys %$comments) {
		next if $x == 0;

		my $pid = $comments->{$x}{pid};
		my $reparent;

		# do threshold reparenting thing
		if ($user->{reparent} && $comments->{$x}{points} >= $user->{threshold}) {
			my $tmppid = $pid;
			while ($tmppid && $comments->{$tmppid}{points} < $user->{threshold}) {
				$tmppid = $comments->{$tmppid}{pid};
				$reparent = 1;
			}

			if ($reparent && $tmppid >= ($form->{cid} || $form->{pid})) {
				$pid = $tmppid;
			} else {
				$reparent = 0;
			}
		}

		if ($depth && !$reparent) { # don't reparent again!
			# set depth of this comment based on parent's depth
			$comments->{$x}{depth} = ($pid ? $comments->{$pid}{depth} : 0) + 1;

			# go back each pid until we find one with depth less than $depth
			while ($pid && $comments->{$pid}{depth} >= $depth) {
				$pid = $comments->{$pid}{pid};
				$reparent = 1;
			}
		}

		if ($reparent) {
			# remove child from old parent
			if ($pid >= ($form->{cid} || $form->{pid})) {
				@{$comments->{$comments->{$x}{pid}}{kids}} =
					grep { $_ != $x }
					@{$comments->{$comments->{$x}{pid}}{kids}}
			}

			# add child to new parent
			$comments->{$x}{realpid} = $comments->{$x}{pid};
			$comments->{$x}{pid} = $pid;
			push @{$comments->{$pid}{kids}}, $x;
		}
	}
}

#========================================================================

=head2 printComments(SID [, PID, CID])

Prints all that comment stuff.

=over 4

=item Parameters

=over 4

=item SID

The story ID to print comments for.

=item PID

The parent ID of the comments to print.

=item CID

The comment ID to print.

=back

=item Return value

None.

=item Dependencies

The 'printCommentsMain', 'printCommNoArchive',
and 'printCommComments' template blocks.

=back

=cut

sub printComments {
	my($discussion, $pid, $cid) = @_;
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();

	unless ($discussion) {
		print getData('no_such_sid');
		return 0;
	}

	$pid ||= 0;
	$cid ||= 0;
	my $lvl = 0;

	# Get the Comments
	my($comments, $count) = selectComments($discussion, $cid || $pid);

	# Should I index or just display normally?
	my $cc = 0;
	if ($comments->{$cid || $pid}{visiblekids}) {
		$cc = $comments->{$cid || $pid}{visiblekids};
	}

	$lvl++ if $user->{mode} ne 'flat' && $user->{mode} ne 'archive'
		&& $cc > $user->{commentspill}
		&& ( $user->{commentlimit} > $cc ||
		     $user->{commentlimit} > $user->{commentspill} );

	if ($discussion->{type} eq 'archived') {
		$user->{state}{comment_read_only} = 1;
		slashDisplay('printCommNoArchive');
	}

	slashDisplay('printCommentsMain', {
		comments	=> $comments,
		title		=> $discussion->{title},
		'link'		=> $discussion->{url},
		count		=> $count,
		sid		=> $discussion->{id},
		cid		=> $cid,
		pid		=> $pid,
		lvl		=> $lvl,
	});

	return if $user->{state}{nocomment} || $user->{mode} eq 'nocomment';

	my($comment, $next, $previous);
	if ($cid) {
		my($next, $previous);
		$comment = $comments->{$cid};
		if (my $sibs = $comments->{$comment->{pid}}{kids}) {
			for (my $x = 0; $x < @$sibs; $x++) {
			($next, $previous) = ($sibs->[$x+1], $sibs->[$x-1])
			  if $sibs->[$x] == $cid;
			}
		}

		$next = $comments->{$next} if $next;
		$previous = $comments->{$previous} if $previous;
	}

	slashDisplay('printCommComments', {
		can_moderate	=> 
			( ($user->{seclev} >= 100 || $user->{points}) &&
			  !$user->{is_anon} ) &&
			getCurrentStatic('allow_moderation'),
		comment		=> $comment,
		comments	=> $comments,
		'next'		=> $next,
		previous	=> $previous,
		sid		=> $discussion->{id},
		cid		=> $cid,
		pid		=> $pid,
		cc		=> $cc,
		lcp		=> linkCommentPages($discussion->{id}, $pid, $cid, $cc),
		lvl		=> $lvl,
	});
}

#========================================================================

=head2 moderatorCommentLog(SID, CID)

Prints a table detailing the history of moderation of
a particular comment.

=over 4

=item Parameters

=over 4

=item SID

Comment's story ID.

=item CID

Comment's ID.

=back

=item Return value

The HTML.

=item Dependencies

The 'modCommentLog' template block.

=back

=cut

sub moderatorCommentLog {
	my($type, $value) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $seclev = getCurrentUser('seclev');
	my $mod_admin = $seclev >= $constants->{modviewseclev} ? 1 : 0;

	my $asc_desc = $type eq 'cid' ? 'ASC' : 'DESC';
	my $limit = $type eq 'cid' ? 0 : 100;
	my $mods = $slashdb->getModeratorCommentLog($asc_desc, $limit,
		$type, $value);

	if (!$mod_admin) {
		# Eliminate inactive moderations from the list.
		$mods = [ grep { $_->{active} } @$mods ];
	}
	return unless @$mods; # skip it, if no mods to show

	my(@return, @reasonHist, $reasonTotal);

	for my $mod (@$mods) {
		next unless $mod->{active};
		$reasonHist[$mod->{reason}]++;
		$reasonTotal++;
	}

	my $show_cid    = ($type eq 'cid') ? 0 : 1;
	my $show_modder = $mod_admin ? 1 : 0;
	slashDisplay('modCommentLog', {
		# modviewseclev
		mod_admin	=> $mod_admin, 
		mods		=> $mods,
		reasonTotal	=> $reasonTotal,
		reasonHist	=> \@reasonHist,
		show_cid	=> $show_cid,
		show_modder	=> $show_modder,
	}, { Return => 1, Nocomm => 1 });
}

#========================================================================

=head2 displayThread(SID, PID, LVL, COMMENTS)

Displays an entire thread.  w00p!

=over 4

=item Parameters

=over 4

=item SID

The story ID.

=item PID

The parent ID.

=item LVL

What level of the thread we're at.

=item COMMENTS

Arrayref of all our comments.

=back

=item Return value

The thread.

=item Dependencies

The 'displayThread' template block.

=back

=cut

sub displayThread {
	my($sid, $pid, $lvl, $comments, $const) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	$lvl ||= 0;
	my $displayed = 0;
	my $mode = getCurrentUser('mode');
	my $indent = 1;
	my $full = my $cagedkids = !$lvl;
	my $hidden = my $skipped = 0;
	my $return = '';

	# Archive really doesn't exist anymore -Brian 
	# Yes it does! - Cliff 9/18/01
	# 
	# FYI: 'archive' means we're to write the story to .shtml at the close
	# of the discussion without page breaks.
	if ($user->{mode} eq 'flat' || $user->{mode} eq 'archive') {
		$indent = 0;
		$full = 1;
	} elsif ($user->{mode} eq 'nested') {
		$indent = 1;
		$full = 1;
	}

	unless ($const) {
		for (map { ($_ . "begin", $_ . "end") }
			qw(table cage cagebig indent comment)) {
			$const->{$_} = getData($_, '', '');
		}
	}

	for my $cid (@{$comments->{$pid}{kids}}) {
		my $comment = $comments->{$cid};

		$skipped++;
		$form->{startat} ||= 0;
		next if $skipped < $form->{startat};
		$form->{startat} = 0; # Once We Finish Skipping... STOP

		if ($comment->{points} < $user->{threshold}) {
			if ($user->{is_anon} || ($user->{uid} != $comment->{uid})) {
				$hidden++;
				next;
			}
		}

		my $highlight = 1 if $comment->{points} >= $user->{highlightthresh};
		my $finish_list = 0;

		if ($full || $highlight) {
			if ($lvl && $indent) {
				$return .= $const->{tablebegin} .
					dispComment($comment) . $const->{tableend};
				$cagedkids = 0;
			} else {
				$return .= dispComment($comment);
			}
			$displayed++;
		} else {
			my $pntcmt = @{$comments->{$comment->{pid}}{kids}} > $user->{commentspill};
			$return .= $const->{commentbegin} .
				linkComment($comment, $pntcmt, 1);
			$finish_list++;
		}

		if ($comment->{kids}) {
			$return .= $const->{cagebegin} if $cagedkids;
			$return .= $const->{indentbegin} if $indent;
			$return .= displayThread($sid, $cid, $lvl+1, $comments, $const);
			$return .= $const->{indentend} if $indent;
			$return .= $const->{cageend} if $cagedkids;
		}

		$return .= $const->{commentend} if $finish_list;

		last if $displayed >= $user->{commentlimit};
	}

	if ($hidden && ! $user->{hardthresh} && $user->{mode} ne 'archive') {
		$return .= $const->{cagebigbegin} if $cagedkids;
		my $link = linkComment({
			sid		=> $sid,
			threshold	=> $constants->{comment_minscore},
			pid		=> $pid,
			subject		=> getData('displayThreadLink', { 
						hidden => $hidden 
					   }, ''),
		});
		$return .= slashDisplay('displayThread', { 'link' => $link },
			{ Return => 1, Nocomm => 1 });
		$return .= $const->{cagebigend} if $cagedkids;
	}

	return $return;
}

#========================================================================

=head2 dispComment(COMMENT)

Displays a particular comment.

=over 4

=item Parameters

=over 4

=item COMMENT

Hashref of comment data.
If the 'no_moderation' key of the COMMENT hashref exists, the
moderation elements of the comment will not be displayed.

=back

=item Return value

The comment to display.

=item Dependencies

The 'dispComment' template block.

=back

=cut

sub dispComment {
	my($comment) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my($comment_shrunk, %reasons);

	if ($form->{mode} ne 'archive' &&
	    length($comment->{comment}) > $user->{maxcommentsize} &&
	    $form->{cid} ne $comment->{cid})
	{
		# We remove the domain tags so that strip_html will not
		# consider </a blah> to be a non-approved tag.  We'll
		# add them back at the last step.  In-between, we chop
		# the comment down to size, then massage it to make sure
		# we still have good HTML after the chop.
		$comment_shrunk = $comment->{comment};
		$comment_shrunk =~ s{</A[^>]+>}{</A>}gi;
		$comment_shrunk = chopEntity($comment_shrunk, $user->{maxcommentsize});
		$comment_shrunk = strip_html($comment_shrunk);
		$comment_shrunk = balanceTags($comment_shrunk);
		$comment_shrunk = addDomainTags($comment_shrunk);
	}

	for my $html ($comment->{comment}, $comment->{sig}, $comment_shrunk) {
		$html = parseDomainTags($html, $comment->{fakeemail});
	}

	if ($user->{sigdash} && $comment->{sig} && !isAnon($comment->{uid})) {
		$comment->{sig} = "--<BR>$comment->{sig}";
	}

	my @reasons = ( );
	@reasons = @{$constants->{reasons}}
		if $constants->{reasons} and ref($constants->{reasons}) eq 'ARRAY';
	for (0 .. scalar(@reasons) - 1) {
		$reasons{$_} = $reasons[$_];
	}

	# I wonder if much of this logic should be moved out to the theme.
	# This logic can then be placed at the theme level and would eventually
	# become what is put into $comment->{no_moderation}. As it is, a lot
	# of the functionality of the moderation engine is intrinsically linked
	# with how things behave on Slashdot.	- Cliff 6/6/01
	# I rearranged the order of these tests (check anon first for speed)
	# and pulled some of the tests from dispComment/_hard_dispComment
	# back here as well, just to have it all in one place. - Jamie 2001/08/17
	my $can_mod =	!$user->{is_anon} &&
			$constants->{allow_moderation} &&
			!$comment->{no_moderation} &&
			!$user->{state}{comment_read_only} &&
			( ( $user->{points} > 0 &&
			    $user->{willing} &&
			    $comment->{uid} != $user->{uid} &&
			    $comment->{lastmod} != $user->{uid} &&
			    $comment->{ipid} ne $user->{ipid} &&
			    (    !$constants->{mod_same_subnet_forbid}
			      || $comment->{subnetid} ne $user->{subnetid} )
			) || (
			    $user->{seclev} >= 100 &&
			    $constants->{authors_unlimited}
			) );

	# don't inherit these ...
	for (qw(sid cid pid date subject comment uid points lastmod
		reason nickname fakeemail homepage sig)) {
		$comment->{$_} = '' unless exists $comment->{$_};
	}

	return _hard_dispComment(
		$comment, $constants, $user, $form, $comment_shrunk,
		$can_mod, \%reasons
	) if $constants->{comments_hardcoded} && !$user->{light};

	return slashDisplay('dispComment', {
		%$comment,
		comment_shrunk	=> $comment_shrunk,
		reasons		=> \%reasons,
		can_mod		=> $can_mod,
		is_anon		=> isAnon($comment->{uid}),
	}, { Return => 1, Nocomm => 1 });
}

#========================================================================

=head2 dispStory(STORY, AUTHOR, TOPIC, FULL, OTHER)

Display a story.

=over 4

=item Parameters

=over 4

=item STORY

Hashref of data about the story.

=item AUTHOR

Hashref of data about the story's author.

=item TOPIC

Hashref of data about the story's topic.

=item FULL

Boolean for show full story, or just the
introtext portion.

=item OTHER

Hash with parameters such as alternate template.

=back

=item Return value

Story to display.

=item Dependencies

The 'dispStory' template block.

=back

=cut


sub dispStory {
	my($story, $author, $topic, $full, $other) = @_;
	my $slashdb      = getCurrentDB();
	my $constants    = getCurrentStatic();
	my $form_section = getCurrentForm('section');
	my $template_name = $other->{story_template} ? $other->{story_template} : 'dispStory';

	my $section = $slashdb->getSection($story->{section});

	$topic->{image} = "$constants->{imagedir}/topics/$topic->{image}" 
		if $topic->{image} =~ /^\w+\.\w+$/; 
	my %data = (
		story	=> $story,
		section => $section,
		topic	=> $topic,
		author	=> $author,
		full	=> $full,
		magic	=> (!$full && (index($story->{title}, ':') == -1)
			&& ($story->{section} ne $constants->{defaultsection})
			&& ($story->{section} ne $form_section)),
		width	=> $constants->{titlebar_width}
	);

	return slashDisplay($template_name, \%data, 1);
}

#========================================================================

=head2 displayStory(SID, FULL, OTHER)

Display a story by SID (frontend to C<dispStory>).

=over 4

=item Parameters

=over 4

=item SID

Story ID to display.

=item FULL

Boolean for show full story, or just the
introtext portion.

=item OTHER 

hash containing other parameters such as 
alternate template name 

=back

=item Return value

A list of story to display, hashref of story data,
hashref of author data, and hashref of topic data.

=back

=cut

sub displayStory {
	# caller is the pagename of the calling script
	my($sid, $full, $other) = @_;	# , $caller  no longer needed?  -- pudge

	my $slashdb = getCurrentDB();
	my $story = $slashdb->getStory($sid);
	my $author = $slashdb->getAuthor($story->{uid},
		['nickname', 'fakeemail', 'homepage']);
	my $topic = $slashdb->getTopic($story->{tid});

	# convert the time of the story (this is database format)
	# and convert it to the user's prefered format
	# based on their preferences

	# An interesting note... this is pretty much the
	# only reason this function is even needed.
	# Everything else can easily be done with
	# dispStory(). Even this could be worked
	# into the logic for the template Display
	#  -Brian

	# well, also, dispStory needs a story reference, not an SID,
	# though that could be changed -- pudge

	$story->{storytime} = timeCalc($story->{'time'});

	# get extra data from section table for this story
	# (if exists)
	# this only needs to run for slashdot
	# why is this commented out?  -- pudge
	# Its basically an undocumented feature
	# that Slash uses.
	#$slashdb->setSectionExtra($full, $story);

	my $return = dispStory($story, $author, $topic, $full, $other);
	return($return, $story, $author, $topic);
}


#========================================================================

=head2 getOlderStories(STORIES, SECTION)

Get older stories for older stories box.

=over 4

=item Parameters

=over 4

=item STORIES

Array ref of the "essentials" of the stories to display, gotten from
getStoriesEssentials.

=item SECTION

Hashref of section data.

=back

=item Return value

The older stories.

=item Dependencies

The 'getOlderStories' template block.

=back

=cut

sub getOlderStories {
	my($stories, $section) = @_;
	my($count, $newstories, $today, $stuff);
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	for (@$stories) {
		my($sid, $sect, $title, $time, $commentcount, $day, $hp, $secs, $tid) = @{$_}; 
		my($w, $m, $d, $h, $min, $ampm) = split m/ /, $time;
		$d =~ s/^0//;
		push @$newstories, {
			sid		=> $sid,
			section		=> $sect,
			title		=> $title,
			'time'		=> $time,
			commentcount	=> $commentcount,
			day		=> $day,
			w		=> $w,
			'm'		=> $m,
			d		=> $d,
			h		=> $h,
			min		=> $min,
			ampm		=> $ampm,
			secs		=> $secs,
			'link'		=> linkStory({
				'link'	=> $title,
				sid	=> $sid,
				tid	=> $tid,
				section	=> $sect
			})
		};
	}

	my $yesterday;
	if ($form->{issue}) {
		my($y, $m, $d) = $form->{issue} =~ /^(\d\d\d\d)(\d\d)(\d\d)$/;
		$yesterday = timeCalc(scalar localtime(
			timelocal(0, 0, 12, $d, $m - 1, $y - 1900) - 86400
		), '%Y%m%d');
	} else {
		$yesterday = $slashdb->getDay(1);
	}

	$form->{start} ||= 0;

	if ($section->{section} eq 'index') {
		# XXX Fake it...
		$section->{artcount} = 15;
	}

	slashDisplay('getOlderStories', {
		stories		=> $newstories,
		section		=> $section,
		cur_time	=> time,
		yesterday	=> $yesterday,
		start		=> $section->{artcount} + $form->{start} + scalar(@$stories),
	}, 1);
}


#========================================================================

=head2 getData(VALUE [, PARAMETERS, PAGE])

Returns snippets of data associated with a given page.

=over 4

=item Parameters

=over 4

=item VALUE

The name of the data-snippet to process and retrieve.

=item PARAMETERS

Data stored in a hashref which is to be passed to the retrieved snippet.

=item PAGE

The name of the page to which VALUE is associated.

=back

=item Return value

Returns data snippet with all necessary data interpolated.

=item Dependencies

Gets little snippets of data, determined by the value parameter, from
a data template. A data template is a colletion of data snippets
in one template, which are grouped together for efficiency. Each
script can have it's own data template (specified by the PAGE
parameter). If PAGE is unspecified, snippets will be retrieved from
the last page visited by the user as determined by Slash::Apache::User.

=back

=cut

sub getData {
	my($value, $hashref, $page) = @_;
	$hashref ||= {};
	$hashref->{value} = $value;
	my %opts = ( Return => 1, Nocomm => 1 );
	$opts{Page} = $page || 'NONE' if defined $page;
	return slashDisplay('data', $hashref, \%opts);
}

########################################################
# this sucks, but it is here for now
sub _hard_dispComment {
	my($comment, $constants, $user, $form, $comment_shrunk, $can_mod, $reasons) = @_;

	my($comment_to_display, $score_to_display, $user_to_display, 
		$time_to_display, $comment_link_to_display, $userinfo_to_display);

	if ($comment_shrunk) {
		# Guess what should be in a template? -Brian
		my $link = linkComment({
			sid	=> $comment->{sid},
			cid	=> $comment->{cid},
			pid	=> $comment->{cid},
			subject	=> 'Read the rest of this comment...'
		}, 1);
		$comment_to_display = "$comment_shrunk<P><B>$link</B>";
	} elsif ($user->{nosigs}) {
		$comment_to_display = $comment->{comment};
	} else {
		$comment_to_display  = "$comment->{comment}<BR>$comment->{sig}";
	}

	$time_to_display = timeCalc($comment->{date});
	unless ($user->{noscores}) {
		$score_to_display .= "(Score:$comment->{points}";

		if ($comment->{reason}) {
			$score_to_display .= ", $reasons->{$comment->{reason}}";
		}

		$score_to_display .= ")";
	}

	$comment_link_to_display = qq|<A HREF="$constants->{rootdir}/comments.pl?sid=$comment->{sid}&cid=$comment->{cid}">#$comment->{cid}</A>|;

	if (isAnon($comment->{uid})) {
		$user_to_display = $comment->{nickname};
	} else {
		my $nick = fixparam($comment->{nickname});

		$userinfo_to_display = qq|<BR><FONT SIZE="-1">(<A HREF="$constants->{rootdir}/~$nick/">User #$comment->{uid} Info</A>|;

		my $homepage = $comment->{homepage} || '';
		$homepage = '' if length($homepage) <= 8;
		if (length($homepage) > 50) {
			$homepage = substr($homepage, 0, 20) . "..." . substr($homepage, -20, 20);
		}
		$homepage = strip_literal($homepage);
		$userinfo_to_display .= qq[ | <A HREF="$comment->{homepage}">$homepage</A>]
			if $homepage;

		$userinfo_to_display .= sprintf(' | Last Journal: <A HREF="%s/~%s/journal/">%s</A>',
			$constants->{rootdir}, $nick, timeCalc($comment->{journal_last_entry_date})
		) if $comment->{journal_last_entry_date} =~ /[1-9]/;

		$userinfo_to_display .= ')</FONT>';

		# This is wrong, must be fixed before we ship -Brian
		# i think it is right now -- pudge
		if ($comment->{fakeemail}) {
			my $mail_literal = strip_literal($comment->{fakeemail});
			my $mail_param = fixparam($comment->{fakeemail});
			my $nick_literal = strip_literal($comment->{nickname});
			$user_to_display = qq| <A HREF="mailto:$mail_param">$nick_literal</A> (<B><FONT SIZE="2">$mail_literal)</FONT></B>|;
		} else {
			$user_to_display = strip_literal($comment->{nickname});
		}
	}

	my $ipidinfo_to_display = '';
	my $people_display;
	unless ($user->{is_anon} || isAnon($comment->{uid}) || $comment->{uid} == $user->{uid}) {
		if ($user->{people}{$comment->{uid}} == FRIEND) {
			$people_display = qq|<A HREF="$constants->{rootdir}/zoo.pl?op=deletecheck&amp;uid=$comment->{uid}"><IMG BORDER=0 SRC="$constants->{imagedir}/friend.gif" ALT="Friend" TITLE="Friend"></A>|;
		} elsif ($user->{people}{$comment->{uid}} == FOE) {
			$people_display = qq|<A HREF="$constants->{rootdir}/zoo.pl?op=deletecheck&amp;uid=$comment->{uid}"><IMG BORDER=0 SRC="$constants->{imagedir}/foe.gif" ALT="Foe" TITLE="Foe"></A> |;
		} else {
			$people_display = qq|<A HREF="$constants->{rootdir}/zoo.pl?op=addcheck&amp;type=friend&amp;uid=$comment->{uid}"><IMG BORDER=0 SRC="$constants->{imagedir}/neutral.gif" ALT="Alter Relationship" TITLE="Alter Relationship"></A>|;
		}
	}
	
	if ($user->{seclev} >= 100 and $comment->{ipid} and $comment->{subnetid}) {
		my $vislength = $constants->{id_md5_vislength};
		my $short_ipid = $comment->{ipid};
		$short_ipid = substr($short_ipid, 0, $vislength) if $vislength;
		my $short_subnetid = $comment->{subnetid};
		$short_subnetid = substr($short_subnetid, 0, $vislength) if $vislength;
		$ipidinfo_to_display = <<EOT;
<BR><FONT FACE="$constants->{mainfontface}" SIZE=1>IPID:
<A HREF="$constants->{rootdir}/users.pl?op=userinfo&amp;userfield=$comment->{ipid}&amp;fieldname=ipid">$short_ipid</A>&nbsp;&nbsp;SubnetID: 
<A HREF="$constants->{rootdir}/users.pl?op=userinfo&amp;userfield=$comment->{subnetid}&amp;fieldname=subnetid">$short_subnetid</A></FONT>
EOT
	}

	my $title = qq|<A NAME="$comment->{cid}"><B>$comment->{subject}</B></A>|;
	my $return = <<EOT;
			<TR><TD BGCOLOR="$user->{bg}[2]">
				<FONT SIZE="3" COLOR="$user->{fg}[2]">
				$title $score_to_display
				</FONT>
				<BR>by $user_to_display on $time_to_display ($comment_link_to_display) $people_display
				$userinfo_to_display $ipidinfo_to_display 
			</TD></TR>
			<TR><TD>
				$comment_to_display
			</TD></TR>
EOT

	if ($user->{mode} ne 'archive' and $comment->{nickname} ne "-") {
		my $reply = (linkComment({
			sid	=> $comment->{sid},
			pid	=> $comment->{cid},
			op	=> 'Reply',
			subject	=> 'Reply to This',
		}) . " | ") unless $user->{state}{comment_read_only};

		my $parent = linkComment({
			sid	=> $comment->{sid},
			cid	=> $comment->{pid},
			pid	=> $comment->{pid},
			subject	=> 'Parent',
		}, 1);
		my $mod_select = '';
		if ($can_mod and !$user->{state}{comment_read_only}) {
			$mod_select = " | "
				. createSelect("reason_$comment->{cid}",
					$reasons, '', 1, 1);
		}

		my $deletion = qq? | <INPUT TYPE="CHECKBOX" NAME="del_$comment->{cid}">?
			if $user->{is_admin} and !$user->{state}{comment_read_only};

		$return .= <<EOT;
			<TR><TD>
				<FONT SIZE="2">
				[ $reply$parent$mod_select$deletion ]
				</FONT>
			</TD></TR>
			<TR><TD>
EOT
	}
	return $return;
}

1;

__END__

=head1 BENDER'S TOP TEN MOST FREQUENTLY UTTERED WORDS

=over 4

=item 1.

ass

=item 2.

daffodil

=item 3.

shiny

=item 4.

my

=item 5.

bite

=item 6.

pimpmobile

=item 7.

up

=item 8.

yours

=item 9.

chumpette

=item 10.

chump

=back
