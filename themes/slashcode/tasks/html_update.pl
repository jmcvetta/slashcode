#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: html_update.pl,v 1.4 2005/07/19 16:56:51 jamiemccarthy Exp $

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );
$!=0;
$task{$me}{timespec} = '0 0 * * *';
$task{$me}{timespec_panic_1} = ''; # if panic, this can wait
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

	for my $name (reverse sort keys %sets) {
		my $set = $sets{$name};

		# max is last comment posted under "old" spec, (needs to be figured out manually)
		# lst is last comment updated here
		($set->{max}) = $slashdb->getVar("html_update_$set->{table}_max", 'value', 1);
		($set->{lst}) = $slashdb->getVar("html_update_$set->{table}_lst", 'value', 1);

		unless ($set->{max}) {
			($set->{max}) = $slashdb->sqlSelect("MAX($set->{id})", $set->{table});
			$slashdb->setVar("html_update_$set->{table}_max", $set->{max});
		}

		# old table is the previous data itself
		$set->{table_old} = $set->{table} . '_html_update_old';

		slashdLog("Attempting to update HTML for $name $set->{lst} through $set->{max}");
		while ($set->{lst} < $set->{max}) {
			my $next = $set->{lst} + 1;
			my $max = $set->{lst} + $update_num;
			$max = $set->{max} if $max > $set->{max};

			slashdLog("Updating HTML for $name $next through $set->{max}");

			my $cols = join ',', $set->{id}, @{$set->{fields}};
			my $fetch = $reader->sqlSelectAllHashref(
				$set->{id}, $cols, $set->{table},
				"$set->{id} BETWEEN $next AND $max"
			);

			last unless keys %$fetch;

			my $admin = 0;
			$admin = 1 if $name eq 'stories';

			for my $id (sort { $a <=> $b } keys %$fetch) {
				my(%oldhtml, %html, $ok);
				for my $field (@{$set->{fields}}) {
					if (length $fetch->{$id}{$field}) {
						$oldhtml{$field} = $fetch->{$id}{$field};
						$html{$field}    = _html_update_fix($fetch->{$id}{$field}, $field, 0, $admin);
						$ok = 1;
					}
				}
				next unless $ok;

				$slashdb->sqlInsert($set->{table_old}, {
					$set->{id} => $id,
					%oldhtml
				});

				if ($name eq 'stories') {
					$html{is_dirty} = 1;
					$html{-last_update} = 'last_update';
					my $success = $slashdb->setStory($id, \%html);
					if (!$success) {
						slashdLog("setStory failed for id=$id");
					}
				} else {
					if ($name =~ /^user/) {
						$slashdb->setUser_delete_memcached($id);
					}
					my $rows = $slashdb->sqlUpdate($set->{table}, \%html,
						"$set->{id} = $id"
					);
					if (!$rows) {
						slashdLog("update failed for $set->{table} $set->{id}=$id");
					}
				}

			} continue {
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
	my($html, $field, $strip, $admin) = @_;

	my $limit = 0;
	if ($field eq 'bio') {
		$limit = getCurrentStatic('users_bio_length') || 1024;
	} elsif ($field eq 'sig') {
		$limit = 120;
	} elsif ($field eq 'mylinks') {
		$limit = 255;
	}

	$html = chopEntity($html, $limit) if $limit;

	# we can strip page-widening stuff, but for now, we don't,
	# as we have no solution in CSS to page-widening at this point
	$html =~ s!<nobr>(.|&#?\w+;)<wbr></nobr> !$1!gi if $strip;

	if ($admin) {
		local $Slash::Utility::Data::approveTag::admin = 1;
		$html = cleanSlashTags($html);
		$html = strip_html($html);
		$html = slashizeLinks($html);
		$html = balanceTags($html);
	} else {
		$html = balanceTags(strip_html($html), { deep_nesting => 2 });
	}

	while ($limit > 0 && length($html) > $limit) {
		$limit -= 10;
		$html = balanceTags(chopEntity($html, $limit), { deep_nesting => 2 });
	}

	if ($html && $field =~ /^(?:sig|bio|comment)$/) {
		$html = addDomainTags($html);
	}

	return $html;
}


1;

__END__

DROP TABLE IF EXISTS comment_text_html_update_old;
CREATE TABLE comment_text_html_update_old (
	cid mediumint UNSIGNED NOT NULL,
	comment text NOT NULL,
	PRIMARY KEY (cid)
);

DROP TABLE IF EXISTS users_html_update_old;
CREATE TABLE users_html_update_old (
	uid mediumint UNSIGNED NOT NULL,
	sig varchar(200),
	PRIMARY KEY (uid)
);

DROP TABLE IF EXISTS users_info_html_update_old;
CREATE TABLE users_info_html_update_old (
	uid mediumint UNSIGNED NOT NULL,
	bio text,
	PRIMARY KEY (uid)
);

DROP TABLE IF EXISTS users_prefs_html_update_old;
CREATE TABLE users_prefs_html_update_old (
	uid mediumint UNSIGNED NOT NULL,
	mylinks varchar(255) DEFAULT '' NOT NULL,
	PRIMARY KEY (uid)
);

DROP TABLE IF EXISTS story_text_html_update_old;
CREATE TABLE story_text_html_update_old (
	stoid MEDIUMINT UNSIGNED NOT NULL,
	title VARCHAR(100) DEFAULT '' NOT NULL,
	introtext text,
	bodytext text,
	relatedtext text,
	PRIMARY KEY (stoid)
);



INSERT INTO vars VALUES ('html_update_comment_text_max', 0, 'last posted under old spec');
INSERT INTO vars VALUES ('html_update_comment_text_lst', 0, 'last comment processed by html_update');
INSERT INTO vars VALUES ('html_update_users_max',        0, 'last posted under old spec');
INSERT INTO vars VALUES ('html_update_users_lst',        0, 'last processed by html_update');
INSERT INTO vars VALUES ('html_update_users_info_max',   0, 'last posted under old spec');
INSERT INTO vars VALUES ('html_update_users_info_lst',   0, 'last processed by html_update');
INSERT INTO vars VALUES ('html_update_users_prefs_max',  0, 'last posted under old spec');
INSERT INTO vars VALUES ('html_update_users_prefs_lst',  0, 'last processed by html_update');
INSERT INTO vars VALUES ('html_update_story_text_max',   0, 'last posted under old spec');
INSERT INTO vars VALUES ('html_update_story_text_lst',   0, 'last processed by html_update');





#### in case you need to revert:
#REPLACE INTO vars VALUES ('html_update_comment_text_lst', 0, 'last processed by html_update');
#REPLACE INTO vars VALUES ('html_update_users_lst',        0, 'last processed by html_update');
#REPLACE INTO vars VALUES ('html_update_users_info_lst',   0, 'last processed by html_update');
#REPLACE INTO vars VALUES ('html_update_users_prefs_lst',  0, 'last processed by html_update');
#REPLACE INTO vars VALUES ('html_update_story_text_lst',   0, 'last processed by html_update');

#UPDATE story_text   AS good, story_text_html_update_old   AS old SET good.title = old.title, good.introtext = old.introtext, good.bodytext = old.bodytext, good.relatedtext = old.relatedtext WHERE good.stoid = old.stoid;
#UPDATE users        AS good, users_html_update_old        AS old SET good.sig = old.sig         WHERE good.uid = old.uid;
#UPDATE users_info   AS good, users_info_html_update_old   AS old SET good.bio = old.bio         WHERE good.uid = old.uid;
#
UPDATE users_prefs  AS good, users_prefs_html_update_old  AS old SET good.mylinks = old.mylinks WHERE good.uid = old.uid;
#UPDATE comment_text AS good, comment_text_html_update_old AS old SET good.comment = old.comment WHERE good.uid = old.uid;
