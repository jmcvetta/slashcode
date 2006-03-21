#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: bookmark.pl,v 1.1 2006/03/21 20:37:15 tvroom Exp $

use strict;
use Slash;
use Slash::Constants qw(:web);
use Slash::Display;
use Slash::Utility;
use URI;

#################################################################
sub main {
	my $form    = getCurrentForm();
	my $user    = getCurrentUser();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $postflag = $user->{state}{post};

	my %ops = (
		bookmark 	=> [!$user->{is_anon}, \&bookmark, 0 ],
		save		=> [!$user->{is_anon}, \&saveBookmark, 1 ]
	);
	
	redirect("/login.pl") if $user->{is_anon};
	
	$ops{default} = $ops{bookmark};
	my $op = lc($form->{op} || 'default');
	$op = 'default' if !$ops{$op} || !$ops{$op}[ALLOWED];
	$op = 'default' if $ops{$op}[2] && !$postflag;
	
	header() if $op ne "save";
	$ops{$op}[FUNCTION]->($constants, $slashdb, $user, $form);
	footer() if $op ne "save";
}

#################################################################
sub bookmark {
	my($constants, $slashdb, $user, $form, $options) = @_;
	$options ||= {};
	my $fudgedurl = fudgeurl($form->{url});
	my $url_id;
	$url_id = $slashdb->getUrlIfExists($fudgedurl) if $fudgedurl;

	my $tags_str = $form->{tags};
	if ($url_id && !$form->{op}) {
		my $tags = getObject('Slash::Tags');
		my $tag_ar = my $now_tags_ar = $tags->getTagsByNameAndIdArrayref("urls", $url_id, { uid => $user->{uid} });
		$tags_str = join ' ', sort map { $_->{tagname}} @$tag_ar;
		
	}
	
	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('bookmark');
	unless ($rkey->create) {
		$options->{errors}{reskey} = $rkey->errstr;
	}
	if ($form->{state}) {
		unless($rkey->touch) {
			$options->{errors}{reskey} = $rkey->errstr;
		}
	};
	print slashDisplay("bookmark", { 
			fudgedurl => $fudgedurl, 
			errors => $options->{errors},
			tags_string => $tags_str
		}, 
	{ Return => 1 });
}

sub saveBookmark {
	my ($constants, $slashdb, $user, $form) = @_;

	my $reskey = getObject('Slash::ResKey');
	my $rkey = $reskey->key('bookmark');
	
	my $fudgedurl = fudgeurl($form->{url});
	my $bookmarkoptions;

	my $scheme = undef;
	if ($fudgedurl) {
		my $uri = new URI $fudgedurl;
		$scheme = $uri->scheme if $uri && $uri->can("scheme");
	}		
	

	$bookmarkoptions->{errors}{invalidurl} = 1 if (!$fudgedurl && $form->{url}) || ($form->{url} && !$scheme);
	$bookmarkoptions->{errors}{missingfields} = 1 if !$form->{url} || !$form->{title} || !$form->{tags};
	$bookmarkoptions->{errors}{noscheme} = 1 if ($form->{url} && !$scheme);
	unless ($rkey->use) {
		$bookmarkoptions->{errors}{reskey} = $rkey->errstr
	}
	
	if ($bookmarkoptions->{errors}) {
		header();
		bookmark($constants, $slashdb, $user, $form, $bookmarkoptions);
		footer();
		return;
	}
	
	my $data = {
			url => $fudgedurl,
			initialtitle => $form->{title}
	};
	
	my $url_id = $slashdb->getUrlCreate($data);
	
	my $bookmark = getObject("Slash::Bookmark");
	my $bookmark_data = {
		url_id 		=> $url_id,
		uid    		=> $user->{uid},
		title		=> strip_attribute($form->{title}),
	};

	my $bookmark_id;
	my $user_bookmark = $bookmark->getUserBookmarkByUrlId($user->{uid}, $url_id);
	use Data::Dumper;
	if ($user_bookmark) {
		$bookmark_data->{bookmark_id} = $user_bookmark->{bookmark_id};
		$bookmark->updateBookmark($bookmark_data);
	} else {
		$bookmark_data->{"-createdtime"} = 'NOW()';
		$bookmark_id= $bookmark->createBookmark($bookmark_data);
	}
	
	my $tags = getObject('Slash::Tags');

	$tags->setTagsForGlobj($url_id, "urls", $form->{tags});

	my $strip_title = strip_attribute($form->{title});
	my $strip_url = strip_attribute($form->{url});
	
	if ($form->{redirect} eq "journal") {
		redirect("/journal.pl?op=edit&description=$strip_title&article=$strip_url");
	} elsif ($form->{redirect} eq "submit") {
		redirect("/submit.pl?subj=$strip_title&story=$strip_url");
	} else {
		redirect($form->{url});
	}

}

createEnvironment();
main();

1;
