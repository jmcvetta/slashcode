#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: search.pl,v 1.41 2002/05/29 21:07:04 brian Exp $

use strict;
use Slash;
use Slash::Display;
use Slash::Search;
use Slash::Utility;
use Slash::XML;

#################################################################
sub main {
	my %ops = (
		comments	=> \&commentSearch,
		users		=> \&userSearch,
		stories		=> \&storySearch,
		polls		=> \&pollSearch,
		journals	=> \&journalSearch,
		submissions	=> \&submissionSearch,
		rss		=> \&rssSearch,
	);
	my %ops_rss = (
		comments	=> \&commentSearchRSS,
		users		=> \&userSearchRSS,
		stories		=> \&storySearchRSS,
		polls		=> \&pollSearchRSS,
		journals	=> \&journalSearchRSS,
		submissions	=> \&submissionSearchRSS,
		rss		=> \&rssSearchRSS,
	);

	my $constants = getCurrentStatic();
	my $form = getCurrentForm();
	my $user = getCurrentUser();
	# Backwards compatibility, we now favor tid over topic 
	$form->{tid} ||= $form->{topic};

	if ($constants->{search_soap_enabled}) {
		my $r = Apache->request;
		if ($r->header_in('SOAPAction')) {
			require SOAP::Transport::HTTP;
			# security problem previous to 0.55
			if (SOAP::Lite->VERSION >= 0.55) {
				if ($user->{state}{post}) {
					$r->method('POST');
				}
				$user->{state}{packagename} = __PACKAGE__;
				return SOAP::Transport::HTTP::Apache->dispatch_to
					('Slash::Search::SOAP')->handle;
			}
		}
	}

	my($slashdb, $searchDB);
	if ($constants->{search_db_user}) {
		$slashdb  = getObject('Slash::DB', $constants->{search_db_user});
		$searchDB = getObject('Slash::Search', $constants->{search_db_user});
	} else {
		$slashdb  = getCurrentDB();
		$searchDB = Slash::Search->new(getCurrentVirtualUser());
	}

	# Set some defaults
	$form->{query}		||= '';
	$form->{section}	||= '';
	$form->{'sort'}		||= 1;
	$form->{section}	= '' if $form->{section} eq 'index'; # XXX fix this right, do a {realsection}
	$form->{threshold}	= getCurrentUser('threshold') if !defined($form->{threshold});

	# get rid of bad characters
	$form->{query} =~ s/[^A-Z0-9'. :\/]/ /gi;

	# truncate query length
	if (length($form->{query}) > 40) {
		$form->{query} = substr($form->{query}, 0, 40);
	}

	# Handle multiple topic selection if enabled.
	if ($constants->{multitopics_enabled}) {
		for (grep { /^topic_./ } keys %{$form}) {
			$form->{selected_topics}{$1} = 1 if /^topic_(\d+)$/;
		}
		$form->{selected_topics}{$form->{topic}} = 1 if $form->{tid};
	}

	# The default search operation is to search stories.
	$form->{op} ||= 'stories';
	if ($form->{op} eq 'rss' && !$user->{is_admin}) {
		$form->{op} = 'stories'
			unless $constants->{search_rss_enabled};
	} elsif ($form->{op} eq 'submissions' && !$user->{is_admin}) {
		$form->{op} = 'stories'
			unless $constants->{submiss_view};
	}

	if ($form->{content_type} eq 'rss') {
		# Here, panic mode is handled within the individual funcs.
		# We want to return valid (though empty) RSS data even
		# when search is down.
		$form->{op} = 'stories' if !exists($ops_rss{$form->{op}});
		$ops_rss{$form->{op}}->($form, $constants, $slashdb, $searchDB);
	} else {
		header("$constants->{sitename}: Search $form->{query}", $form->{section});
		titlebar("99%", "Searching $form->{query}");
		$form->{op} = 'stories' if !exists($ops{$form->{op}});

		# Here, panic mode is handled without needing to call the
		# individual search subroutines;  we're going to tell the
		# user the same thing in each case anyway.
		if ($constants->{panic} >= 1 or $constants->{search_google}) {
			slashDisplay('nosearch');
		} else {
			if ($ops{$form->{op}}) {
				$ops{$form->{op}}->($form, $constants, $slashdb, $searchDB);
			}
		}

		footer();
	}

	writeLog($form->{query})
		if $form->{op} =~ /^(?:comments|stories|users|polls|journals|submissions|rss)$/;
}


#################################################################
# Ugly isn't it?
sub _authors {
	my $slashdb = getCurrentDB();
	my $authors = $slashdb->getDescriptions('all-authors');
	my %newauthors = %$authors;
	$newauthors{''} = getData('all_authors');

	return \%newauthors;
}

#################################################################
# Ugly isn't it?
sub _topics {
	my $slashdb = getCurrentDB();
	my $section = getCurrentForm('section');

	my $topics;
	if ($section) {
		$topics = $slashdb->getDescriptions('topics_section', $section);
	} else {
		$topics = $slashdb->getDescriptions('topics');
	}

	my %newtopics = %$topics;
	$newtopics{''} = getData('all_topics');

	return \%newtopics;
}

#################################################################
sub _sort {
	my $slashdb = getCurrentDB();
	my $sort = $slashdb->getDescriptions('sortorder');

	return $sort;
}

#################################################################
# Ugly isn't it?
sub _sections {
	my $slashdb = getCurrentDB();
	my $sections = $slashdb->getDescriptions('sections');
	my %newsections = %$sections;
	$newsections{''} = getData('all_sections');

	return \%newsections;
}

#################################################################
# Ugly isn't it?
sub _subsections {
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $subsections = $slashdb->getDescriptions('section_subsection', $form->{section}, 1)
		if $form->{section};
	return undef
		unless (keys %$subsections);
	my %newsections = %$subsections;
	$newsections{''} = getData('all_subsections');

	return \%newsections;
}

#################################################################
sub _buildargs {
	my($form) = @_;
	my $uri;

	for (qw[threshold query author op topic tid section]) {
		my $x = "";
		$x =  $form->{$_} if defined $form->{$_} && $x eq "";
		$x =~ s/ /+/g;
		$uri .= "$_=$x&" unless $x eq "";
	}
	$uri =~ s/&$//;

	return fixurl($uri);
}

#################################################################
sub commentSearch {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $comments = $searchDB->findComments($form, $start, $constants->{search_default_display} + 1, $form->{sort});
	slashDisplay('searchform', {
		sections	=> _sections(),
		topics		=> _topics(),
		tref		=> $slashdb->getTopic($form->{tid}),
		op		=> $form->{op},
		'sort'		=> _sort(),
		threshhold 	=> 1,
	});

	if (@$comments) {
		# check for extra articles ... we request one more than we need
		# and if we get the extra one, we know we have extra ones, and
		# we pop it off
		my $forward;
		if (@$comments == $constants->{search_default_display} + 1) {
			pop @$comments;
			$forward = $start + $constants->{search_default_display};
		} else {
			$forward = 0;
		}

		# if there are less than search_default_display remaning,
		# just set it to 0
		my $back;
		if ($start > 0) {
			$back = $start - $constants->{search_default_display};
			$back = $back > 0 ? $back : 0;
		} else {
			$back = -1;
		}

		slashDisplay('commentsearch', {
			comments	=> $comments,
			back		=> $back,
			forward		=> $forward,
			args		=> _buildargs($form),
			start		=> $start,
		});
	} else {
		print getData('nocomments');
	}
}

#################################################################
sub userSearch {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $users = $searchDB->findUsers($form, $start, $constants->{search_default_display} + 1, $form->{sort}, $form->{journal_only});
	slashDisplay('searchform', {
		op		=> $form->{op},
		'sort'		=> _sort(),
		journal_option	=> 1,
	});

	if (@$users) {
		# check for extra articles ... we request one more than we need
		# and if we get the extra one, we know we have extra ones, and
		# we pop it off
		my $forward;
		if (@$users == $constants->{search_default_display} + 1) {
			pop @$users;
			$forward = $start + $constants->{search_default_display};
		} else {
			$forward = 0;
		}

		# if there are less than search_default_display remaning,
		# just set it to 0
		my $back;
		if ($start > 0) {
			$back = $start - $constants->{search_default_display};
			$back = $back > 0 ? $back : 0;
		} else {
			$back = -1;
		}

		slashDisplay('usersearch', {
			users		=> $users,
			back		=> $back,
			forward		=> $forward,
			args		=> _buildargs($form),
		});
	} else {
		print getData('nousers');
	}
}

#################################################################
sub storySearch {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $stories = $searchDB->findStory($form, $start, $constants->{search_default_display} + 1, $form->{sort});

	slashDisplay('searchform', {
		sections	=> _sections(),
		subsections	=> _subsections(),
		topics		=> _topics(),
		tref		=> $slashdb->getTopic($form->{tid}),
		op		=> $form->{op},
		authors		=> _authors(),
		'sort'		=> _sort(),
	});

	if (@$stories) {
		# check for extra articles ... we request one more than we need
		# and if we get the extra one, we know we have extra ones, and
		# we pop it off
		my $forward;
		if (@$stories == $constants->{search_default_display} + 1) {
			pop @$stories;
			$forward = $start + $constants->{search_default_display};
		} else {
			$forward = 0;
		}

		# if there are less than search_default_display remaning,
		# just set it to 0
		my $back;
		if ($start > 0) {
			$back = $start - $constants->{search_default_display};
			$back = $back > 0 ? $back : 0;
		} else {
			$back = -1;
		}

		slashDisplay('storysearch', {
			stories		=> $stories,
			back		=> $back,
			forward		=> $forward,
			args		=> _buildargs($form),
			start		=> $start,
		});
	} else {
		print getData('nostories');
	}
}

#################################################################
sub pollSearch {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $polls = $searchDB->findPollQuestion($form, $start, $constants->{search_default_display} + 1, $form->{sort});
	slashDisplay('searchform', {
		op		=> $form->{op},
		topics		=> _topics(),
		tref		=> $slashdb->getTopic($form->{tid}),
		'sort'		=> _sort(),
	});

	if (@$polls) {
		# check for extra articles ... we request one more than we need
		# and if we get the extra one, we know we have extra ones, and
		# we pop it off
		my $forward;
		if (@$polls == $constants->{search_default_display} + 1) {
			pop @$polls;
			$forward = $start + $constants->{search_default_display};
		} else {
			$forward = 0;
		}

		# if there are less than search_default_display remaning,
		# just set it to 0
		my $back;
		if ($start > 0) {
			$back = $start - $constants->{search_default_display};
			$back = $back > 0 ? $back : 0;
		} else {
			$back = -1;
		}

		slashDisplay('pollsearch', {
			polls		=> $polls,
			back		=> $back,
			forward		=> $forward,
			args		=> _buildargs($form),
			start		=> $start,
		});
	} else {
		print getData('nopolls');
	}
}

#################################################################
sub commentSearchRSS {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $comments;
	if ($constants->{panic} >= 1 or $constants->{search_google}) {
		$comments = [ ];
	} else {
		$comments = $searchDB->findComments($form, $start, 15, $form->{sort});
	}

	my @items;
	for my $entry (@$comments) {
		my $time = timeCalc($entry->{date});
		push @items, {
			title	=> "$entry->{subject} ($time)",
			'link'	=> ($constants->{absolutedir} . "/comments.pl?sid=$entry->{did}&cid=$entry->{cid}"),
		};
	}

	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} Comment Search",
			'link'		=> "$constants->{absolutedir}/search.pl",
			description	=> "$constants->{sitename} Comment Search",
		},
		image	=> 1,
		items	=> \@items
	});
}

#################################################################
sub userSearchRSS {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $users;
	if ($constants->{panic} >= 1 or $constants->{search_google}) {
		$users = [ ];
	} else {
		$users = $searchDB->findUsers($form, $start, 15, $form->{sort});
	}

	my @items;
	for my $entry (@$users) {
		my $time = timeCalc($entry->{journal_last_entry_date});
		push @items, {
			title	=> $entry->{nickname},
			'link'	=> ($constants->{absolutedir} . '/users.pl?nick=' . $entry->{nickname}),
		};
	}

	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} User Search",
			'link'		=> "$constants->{absolutedir}/search.pl",
			description	=> "$constants->{sitename} User Search",
		},
		image	=> 1,
		items	=> \@items
	});
}

#################################################################
sub storySearchRSS {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $stories;
	if ($constants->{panic} >= 1 or $constants->{search_google}) {
		$stories = [ ];
	} else {
		$stories = $searchDB->findStory($form, $start, 15, $form->{sort});
	}

	my @items;
	for my $entry (@$stories) {
		my $time = timeCalc($entry->{time});
		push @items, {
			title	=> "$entry->{title} ($time)",
			'link'	=> ($constants->{absolutedir} . '/article.pl?sid=' . $entry->{sid}),
		};
	}

	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} Story Search",
			'link'		=> "$constants->{absolutedir}/search.pl",
			description	=> "$constants->{sitename} Story Search",
		},
		image	=> 1,
		items	=> \@items
	});
}

#################################################################
sub pollSearchRSS {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $stories;
	if ($constants->{panic} >= 1 or $constants->{search_google}) {
		$stories = [ ];
	} else {
		$stories = $searchDB->findPollQuestion($form, $start, 15, $form->{sort});
	}

	my @items;
	for my $entry (@$stories) {
		my $time = timeCalc($entry->{date});
		push @items, {
			title	=> "$entry->{question} ($time)",
			'link'	=> ($constants->{absolutedir} . 'pollBooth.pl?qid=' . $entry->{qid}),
		};
	}

	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} Poll Search",
			'link'		=> "$constants->{absolutedir}/search.pl",
			description	=> "$constants->{sitename} Poll Search",
		},
		image	=> 1,
		items	=> \@items
	});
}

#################################################################
# Do not enable -Brian
sub findRetrieveSite {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $feeds = $searchDB->findRetrieveSite($form->{query}, $start, $constants->{search_default_display} + 1, $form->{sort});

	# check for extra feeds ... we request one more than we need
	# and if we get the extra one, we know we have extra ones, and
	# we pop it off
	my $forward;
	if (@$feeds == $constants->{search_default_display} + 1) {
		pop @$feeds;
		$forward = $start + $constants->{search_default_display};
	} else {
		$forward = 0;
	}

	# if there are less than search_default_display remaning,
	# just set it to 0
	my $back;
	if ($start > 0) {
		$back = $start - $constants->{search_default_display};
		$back = $back > 0 ? $back : 0;
	} else {
		$back = -1;
	}

	slashDisplay('retrievedsites', {
		feeds		=> $feeds,
		back		=> $back,
		forward		=> $forward,
		start		=> $start,
	});
}


#################################################################
# Do not enable -Brian
sub findRetrieveSiteRSS {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $feeds = $searchDB->findFeeds($form->{query}, $start, 15, $form->{sort});

	# I am aware that the link has to be improved.
	my @items;
	for my $entry (@$feeds) {
		my $time = timeCalc($entry->{'time'});
		push @items, {
			title	=> "$entry->{title} ($time)",
			'link'	=> ($constants->{absolutedir} . "/users.pl?op=preview&bid=entry->{bid} %]"),
		};
	}

	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} Retrieve Site Search",
			'link'		=> "$constants->{absolutedir}/search.pl",
			description	=> "$constants->{sitename} Retrieve Site Search",
		},
		image	=> 1,
		items	=> \@items
	});
}

#################################################################
sub journalSearch {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $entries = $searchDB->findJournalEntry($form, $start, $constants->{search_default_display} + 1, $form->{sort});
	slashDisplay('searchform', {
		op		=> $form->{op},
		'sort'		=> _sort(),
	});

	# check for extra articles ... we request one more than we need
	# and if we get the extra one, we know we have extra ones, and
	# we pop it off
	if (@$entries) {
		my $forward;
		if (@$entries == $constants->{search_default_display} + 1) {
			pop @$entries;
			$forward = $start + $constants->{search_default_display};
		} else {
			$forward = 0;
		}

		# if there are less than search_default_display remaning,
		# just set it to 0
		my $back;
		if ($start > 0) {
			$back = $start - $constants->{search_default_display};
			$back = $back > 0 ? $back : 0;
		} else {
			$back = -1;
		}

		slashDisplay('journalsearch', {
			entries		=> $entries,
			back		=> $back,
			forward		=> $forward,
			args		=> _buildargs($form),
			start		=> $start,
		});
	} else {
		print getData('nojournals');
	}
}

#################################################################
sub journalSearchRSS {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $entries = $searchDB->findJournalEntry($form, $start, 15, $form->{sort});

	my @items;
	for my $entry (@$entries) {
		my $time = timeCalc($entry->{date});
		push @items, {
			title	=> "$entry->{description} ($time)",
			'link'	=> ($constants->{absolutedir} . '/~' . fixparam($entry->{nickname}) . '/journal/' . $entry->{id}),
		};
	}

	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} Journal Search",
			'link'		=> "$constants->{absolutedir}/search.pl",
			description	=> "$constants->{sitename} Journal Search",
		},
		image	=> 1,
		items	=> \@items
	});
}

#################################################################
sub submissionSearch {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $entries = $searchDB->findSubmission($form, $start, $constants->{search_default_display} + 1, $form->{sort});
	slashDisplay('searchform', {
		op		=> $form->{op},
		sections	=> _sections(),
		topics		=> _topics(),
		submission_notes => $slashdb->getDescriptions('submission-notes'),
		tref		=> $slashdb->getTopic($form->{tid}),
		'sort'		=> _sort(),
	});

	# check for extra articles ... we request one more than we need
	# and if we get the extra one, we know we have extra ones, and
	# we pop it off
	if (@$entries) {
		for(@$entries) {
			$_->{story} = substr(strip_plaintext($_->{story}),0,80);
		}
		my $forward;
		if (@$entries == $constants->{search_default_display} + 1) {
			pop @$entries;
			$forward = $start + $constants->{search_default_display};
		} else {
			$forward = 0;
		}

		# if there are less than search_default_display remaning,
		# just set it to 0
		my $back;
		if ($start > 0) {
			$back = $start - $constants->{search_default_display};
			$back = $back > 0 ? $back : 0;
		} else {
			$back = -1;
		}

		slashDisplay('subsearch', {
			entries		=> $entries,
			back		=> $back,
			forward		=> $forward,
			args		=> _buildargs($form),
			start		=> $start,
		});
	} else {
		print getData('nosubmissions');
	}
}

#################################################################
sub submissionSearchRSS {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $entries = $searchDB->findSubmission($form, $start, 15, $form->{sort});

	my @items;
	for my $entry (@$entries) {
		my $time = timeCalc($entry->{time});
		push @items, {
			title		=> "$entry->{subj} ($time)",
			'link'		=> ($constants->{absolutedir} . '/submit.pl?subid=' . $entry->{subid}),
			'description'	=> $entry->{story},
		};
	}

	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} Submission Search",
			'link'		=> "$constants->{absolutedir}/search.pl",
			description	=> "$constants->{sitename} Submission Search",
		},
		image	=> 1,
		items	=> \@items
	});
}

#################################################################
sub rssSearch {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $entries = $searchDB->findRSS($form, $start, $constants->{search_default_display} + 1, $form->{sort});
	slashDisplay('searchform', {
		op		=> $form->{op},
		'sort'		=> _sort(),
	});

	# check for extra articles ... we request one more than we need
	# and if we get the extra one, we know we have extra ones, and
	# we pop it off
	if (@$entries) {
		for(@$entries) {
			$_->{title} = strip_plaintext($_->{title});
			$_->{description} = substr(strip_plaintext($_->{description}),0,80);
		}
		my $forward;
		if (@$entries == $constants->{search_default_display} + 1) {
			pop @$entries;
			$forward = $start + $constants->{search_default_display};
		} else {
			$forward = 0;
		}

		# if there are less than search_default_display remaning,
		# just set it to 0
		my $back;
		if ($start > 0) {
			$back = $start - $constants->{search_default_display};
			$back = $back > 0 ? $back : 0;
		} else {
			$back = -1;
		}

		slashDisplay('rsssearch', {
			entries		=> $entries,
			back		=> $back,
			forward		=> $forward,
			args		=> _buildargs($form),
			start		=> $start,
		});
	} else {
		print getData('norss');
	}
}

#################################################################
sub rssSearchRSS {
	my($form, $constants, $slashdb, $searchDB) = @_;

	my $start = $form->{start} || 0;
	my $entries = $searchDB->findRSS($form, $start, 15, $form->{sort});

	my @items;
	for my $entry (@$entries) {
		my $time = timeCalc($entry->[2]);
		push @items, {
			title	=> "$entry->{title} ($time)",
			'link'	=> $entry->{link}, # No, this is not right -Brian
			'description'	=> $entry->{description},
		};
	}

	xmlDisplay(rss => {
		channel => {
			title		=> "$constants->{sitename} RSS Search",
			'link'		=> "$constants->{absolutedir}/search.pl",
			description	=> "$constants->{sitename} RSS Search",
		},
		image	=> 1,
		items	=> \@items
	});
}

#################################################################
createEnvironment();
main();

#=======================================================================
#package Slash::Search;
#use Slash::Utility;
#
#sub getDBUsers {
#	my $constants = getCurrentStatic();
#	my ($slashdb, $searchDB);
#	if ($constants->{search_db_user}) {
#		$slashdb  = getObject('Slash::DB', $constants->{search_db_user});
#		$searchDB = getObject('Slash::Search', $constants->{search_db_user});
#	} else {
#		$slashdb  = getCurrentDB();
#		$searchDB = Slash::Search->new(getCurrentVirtualUser());
#	}
#	return($slashdb, $searchDB);
#}
#
#
##=======================================================================
#package Slash::Search::SOAP;
#use Slash::Utility;
#
#sub findStory {
#	my($class, $query) = @_;
#	my $user      = getCurrentUser();
#	my $constants = getCurrentStatic();
#	my($slashdb, $searchDB) = Slash::Search::getDBUsers();
#
#	my $stories;
#	if ($constants->{panic} >= 1 or $constants->{search_google}) {
#		$stories = [ ];
#	} else {
#		$stories = $searchDB->findStory({ query => $query }, 0, 15);
#	}
#
#	return $stories;
#}

#################################################################
1;
