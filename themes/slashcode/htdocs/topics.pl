#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: topics.pl,v 1.28 2003/07/25 17:40:27 pudge Exp $

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

#################################################################
sub main {
	my $form    = getCurrentForm();
	my $user    = getCurrentUser();

	my $data = ($form->{op} eq 'hierarchy') ? { admin => 1, adminmenu => 'info', tab_selected => 'hierarchy' } : {};
	header(getData('head'), $form->{section}, $data) or return;

	print createMenu('topics');

	if ($form->{op} eq 'hierarchy') {
		hierarchy();
	} elsif ($form->{op} eq 'toptopics') {
		topTopics();
	} else {
		listTopics();
	}

	footer();
}

#################################################################
sub hierarchy {
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $section = $slashdb->getSection();

	my(@topics, %parents);
	my $topics = $slashdb->getTopics(1); # Don't cache

	for my $topic (values %$topics) {
		if ($topic->{parent_topic}) {
			push(@{$parents{$topic->{parent_topic}}{child}}, $topic);
		}
		my $children = $parents{$topic->{tid}}{child};
		$parents{$topic->{tid}} = $topic;
		$parents{$topic->{tid}}{child} = $children;
	}
	
	for my $parent (values %parents) {
		# We remove children that have no children. No Welfare state for us! 
		if ($parent->{child}) {
			my @children = sort({ $a->{alttext} cmp $b->{alttext} } @{$parent->{child}});
			$parent->{child} = \@children;
		}
		next if $parent->{parent_topic};
		push @topics, $parent;
	}
	@topics = sort({ $a->{alttext} cmp $b->{alttext} } @topics);

	slashDisplay('hierarchy', {
		topics		=> \@topics,
	});
}

#################################################################
sub topTopics {
	my $reader    = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();
	my $form      = getCurrentForm();

	my $limit = $form->{limit}
		? $form->{limit}
		: $form->{all}
			? 0
			: -1;  # use default
	my $topics = $reader->getTopNewsstoryTopics($limit);

	for my $topic (@$topics) {
		my $limit = $topic->{count} > 10
			? 10
			: $topic->{count} < 3 || $form->{all}
				? 3
				: $topic->{count};

		my $stories = $reader->getStoriesEssentials(
			$limit, '', $topic->{tid}
		);
		$#{$stories} = $limit - 1;
		$topic->{stories} = $stories;
	}

	slashDisplay('topTopics', {
		title		=> 'Recent Topics',
		width		=> '90%',
		topics		=> $topics,
		currtime	=> timeCalc(scalar localtime),
	});
}

#################################################################
sub listTopics {
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();

	my $topics = $reader->getTopics;
	
	if ($form->{section}) {
		my %new_topics;
		my $ids = $reader->getDescriptions('topics_section', $form->{section});
		for (keys %$topics) {
			$new_topics{$_} = $topics->{$_} if $ids->{$_};
		}
		$topics = \%new_topics;
	}

	slashDisplay('listTopics', {
		title		=> 'Current Topic Categories',
		width		=> '90%',
		topic_admin	=> getCurrentUser('seclev') >= 500,
		topics		=> [ values %$topics ],
	});

}

#################################################################
createEnvironment();
main();

1;
