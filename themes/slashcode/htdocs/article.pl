#!/usr/local/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: article.pl,v 1.30 2003/02/13 20:04:14 brian Exp $

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

##################################################################
sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();

	my $story;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	$reader ||= $slashdb;

	#Yeah, I am being lazy and paranoid  -Brian
	#Always check the main DB for story status since it will always be accurate -Brian
	if (!($user->{author} || $user->{is_admin})
		&& !$slashdb->checkStoryViewable($form->{sid})) {
		$story = '';
	} else {
		$story = $reader->getStory($form->{sid});
	}

	if ($story) {
		my $SECT = $slashdb->getSection($story->{section});
    # This should be a getData call for title
		my $title = "$constants->{sitename} | $story->{title}";
		$story->{introtext} = parseSlashizedLinks($story->{introtext});
		$story->{bodytext} =  parseSlashizedLinks($story->{bodytext});

		my $authortext;
		if ($user->{is_admin} ) {
			my $future = $reader->getStoryByTimeAdmin('>', $story, "3");
			$future = [ reverse(@$future) ];
			my $past = $reader->getStoryByTimeAdmin('<', $story, "3");

			$authortext = slashDisplay('futurestorybox', {
							past => $past,
							future => $future,
						}, { Return => 1 });
		}

		# set things up to use the <LINK> tag in the header
		my $next = $reader->getStoryByTime('>', $story, $SECT);
		my $prev = $reader->getStoryByTime('<', $story, $SECT);

		my $links = {
			title	=> $title,
			story	=> $story,
			'link'	=> {
				section	=> $SECT,
				prev	=> $prev,
				'next'	=> $next,
				author	=> $story->{uid},
			},
		};
		header($links, $story->{section});

		my $pollbooth = pollbooth($story->{qid}, 1)
			if $story->{qid};

		slashDisplay('display', {
			poll			=> $pollbooth,
			section			=> $SECT,
			section_block		=> $slashdb->getBlock($SECT->{section}),
			show_poll		=> $pollbooth ? 1 : 0,
			story			=> $story,
			authortext		=> $authortext,
			'next'			=> $next,
			prev			=> $prev,
		});

		#Still not happy with this logic -Brian
		if ($story->{discussion}) {
			my $discussion = $reader->getDiscussion($story->{discussion});
			# This is to get tid in comments. It would be a mess to pass it directly to every comment -Brian
			my $tids = $reader->getStoryTopicsJustTids($story->{sid}); 
			my $tid_string = join('&amp;tid=', @$tids);
			$user->{state}{tid} = $tid_string;
			# If no comments ever have existed just skip the display of the comment header bar -Brian
			printComments($discussion)
				if $discussion && !($discussion->{commentcount} > 0 && $discussion->{commentstatus} eq 'disabled');
		}
	} else {
		my $message = getData('no_such_sid');
		header($message, $form->{section});
		print $message;
	}

	footer();
	if ($story) {
		writeLog($story->{sid} || $form->{sid});
	} else {
		writeLog($form->{sid});
	}
}

createEnvironment();
main();
1;
