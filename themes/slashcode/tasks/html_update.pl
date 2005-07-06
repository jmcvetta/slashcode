#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: html_update.pl,v 1.1 2005/07/06 21:56:15 pudge Exp $

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '0 0 0 * *';
$task{$me}{timespec_panic_1} = 1; # if panic, this can wait
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;

	# XXX use reader?  do we care about the small atomicity problem,
	# which is exacerbated by using a reader?
	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	# stories, users bios/footers, authors bios ... what else?
	my %sets = (
		comments  => {
			table	=> 'comment_text',
			id	=> 'cid',
			fields	=> ['comment'],
		},
		usersig   => {
			table	=> 'users',
			id	=> 'uid',
			fields	=> ['sig'],
		},
		userbio   => {
			table	=> 'users_info',
			id	=> 'uid',
			fields	=> ['bio'],
		},
		userspace => {
			table	=> 'users_prefs',
			id	=> 'uid',
			fields	=> ['mylinks'],
		},
		stories   => {
			table	=> 'story_text',
			id	=> 'stoid',
			fields	=> ['title', 'introtext', 'bodytext', 'relatedtext'],
		},
	);


	my $time  = time();
	my $limit = 3_000;
	my $update_num = 10_000;

	for my $name (keys %sets) {
		my $set = $sets{$name};

		# max is last comment posted under "old" spec, (needs to be figured out manually)
		# lst is last comment updated here
		$set->{max} = $constants->{"html_update_$set->{table}_max"};
		$set->{lst} = $constants->{"html_update_$set->{table}_lst"};

		unless ($set->{max}) {
			($set->{max}) = $slashdb->sqlSelect("MAX($set->{id})", $set->{table});
			$slashdb->setVar("html_update_$set->{table}_max", $set->{max});
		}

		# old table is the previous data itself
		$set->{table_old} = $set->{table} . '_old';

		while ($set->{lst} < $set->{max}) {
			my $next = $set->{lst} + 1;
			my $max = $set->{lst} + $update_num;
			$max = $set->{max} if $max > $set->{max};

			slashdLog("Updating HTML for $name $next through $set->{max}");

			my $cols = join ',', $set->{id}, @{$set->{fields}};
			my $fetch = $reader->sqlSelectAllHashref(
				$set->{id}, $cols, $set->{table},
				"$set->{id} >= $next AND $set->{id} <= $max"
			);

			last unless keys %$fetch;

			for my $id (sort { $a <=> $b } keys %$fetch) {
				my(%oldhtml, %html);
				for my $field (@{$set->{fields}}) {
					$oldhtml{$field} = $fetch->{$id}{$field};
					$html{$field}    = _html_update_fix($fetch->{$id}{$field});
				}

				$slashdb->sqlInsert($set->{table_old}, {
					$set->{id} => $id,
					%oldhtml
				});

				if ($name eq 'stories') {
					# slower, but more correct
					my $story = $reader->getStory($id);
					@{$story}{keys %html} = values %html;
					$story->{is_dirty} = 1;
					$slashdb->updateStory($id, $story);
				} else {
					$slashdb->sqlUpdate($set->{table}, \%html,
						"$set->{id} = $id"
					);
				}

				$set->{lst} = $id;

				if ($set->{lst} =~ /000$/) {
					slashdLog("Updated HTML for $name through $set->{lst}");
				}
			}

			slashdLog("Done updating HTML for $name $next through $set->{max}");

			last if time() > $time + $limit;
		}

		$slashdb->setVar("html_update_$set->{table}_lst", $set->{lst})
			if $set->{lst} ne $constants->{"html_update_$set->{table}_lst"};
	}
};

sub _html_update_fix {
	my($html, $strip) = @_;

	# we can strip page-widening stuff, but for now, we don't,
	# as we have no solution in CSS to page-widening at this point
	$html =~ s!<nobr>(.|&#?\w+;)<wbr></nobr> !$1!gi if $strip;

	$html = balanceTags(strip_html($html), { deep_nesting => 1 });

	return $html;
}


1;

__END__

DROP TABLE IF EXISTS comment_text_old;
CREATE TABLE comment_text_old (
	cid mediumint UNSIGNED NOT NULL,
	comment text NOT NULL,
	PRIMARY KEY (cid)
);

DROP TABLE IF EXISTS users_old;
CREATE TABLE users_old (
	uid mediumint UNSIGNED NOT NULL,
	sig varchar(200),
	PRIMARY KEY (uid),
);

DROP TABLE IF EXISTS users_info_old;
CREATE TABLE users_info_old (
	uid mediumint UNSIGNED NOT NULL,
	bio text,
	PRIMARY KEY (uid),
);

DROP TABLE IF EXISTS users_prefs_old;
CREATE TABLE users_prefs_old (
	uid mediumint UNSIGNED NOT NULL,
	mylinks varchar(255) DEFAULT '' NOT NULL,
	PRIMARY KEY (uid),
);

DROP TABLE IF EXISTS story_text_old;
CREATE TABLE story_text_old (
	stoid MEDIUMINT UNSIGNED NOT NULL,
	title VARCHAR(100) DEFAULT '' NOT NULL,
	introtext text,
	bodytext text,
	relatedtext text,
	PRIMARY KEY (stoid)
);



INSERT INTO vars VALUES ('html_update_comment_text_max', 0, 'last posted under old spec');
INSERT INTO vars VALUES ('html_update_comment_text_lst', 0, 'last processed');

INSERT INTO vars VALUES ('html_update_users_max', 0, 'last posted under old spec');
INSERT INTO vars VALUES ('html_update_users_lst', 0, 'last processed');

INSERT INTO vars VALUES ('html_update_users_info_max', 0, 'last posted under old spec');
INSERT INTO vars VALUES ('html_update_users_info_lst', 0, 'last processed');

INSERT INTO vars VALUES ('html_update_users_prefs_max', 0, 'last posted under old spec');
INSERT INTO vars VALUES ('html_update_users_prefs_lst', 0, 'last processed');

INSERT INTO vars VALUES ('html_update_story_text_max', 0, 'last posted under old spec');
INSERT INTO vars VALUES ('html_update_story_text_lst', 0, 'last processed');



REPLACE INTO vars VALUES ('html_update_comment_text_lst', 0, 'last processed');
REPLACE INTO vars VALUES ('html_update_users_lst', 0, 'last processed');
REPLACE INTO vars VALUES ('html_update_users_info_lst', 0, 'last processed');
REPLACE INTO vars VALUES ('html_update_users_prefs_lst', 0, 'last processed');
REPLACE INTO vars VALUES ('html_update_story_text_lst', 0, 'last processed');

