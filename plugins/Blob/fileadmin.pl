#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: fileadmin.pl,v 1.12 2005/03/11 19:58:06 pudge Exp $

use strict;
use Slash 2.003;
use Slash::Blob;
use Slash::Display;
use Slash::Utility;

use vars qw($VERSION);

($VERSION) = ' $Revision: 1.12 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $gSkin     = getCurrentSkin();
	my $blobdb    = getObject('Slash::Blob');

	my $ops = {
		listFilesForStories	=> {
			function => \&listFilesForStories,
		},
		editBySid   		=> {
			function => \&editBySid,
		},
		listAll			=> {
			function => \&listAll,
		},
		editFile		=> {
			function => \&editFile,
		},
		addFileForStory		=> {
			function => \&addFileForStory,
		},
		deleteFilesForStory	=> {
			function => \&deleteFilesForStory,
		},
	};


	my $op = $form->{op};
	$op = exists $ops->{$op} 
		? $op 
		: $form->{sid}
			? 'editBySid'
			: 'listFilesForStories';

	# admin.pl is not for regular users
	unless ($user->{is_admin}) {
		redirect("$gSkin->{rootdir}/");
		return;
	}

	header() or return;

	$ops->{$op}{function}->($slashdb, $constants, $user, $form, $blobdb);

	footer();
}

##################################################################
sub listFilesForStories { 
	my($slashdb, $constants, $user, $form ,$blobdb) = @_;

	my $files = $blobdb->getFilesForStories();

	slashDisplay('liststories', {
		files	=> $files,
	});


}

##################################################################
sub editBySid { 
	my($slashdb, $constants, $user, $form, $blobdb) = @_;
	return unless $form->{sid};

	my $files = $blobdb->getFilesForStory($form->{sid});

	slashDisplay('listsid', {
		files	=> $files,
		sid	=> $form->{sid},
	});


}

##################################################################
sub addFileForStory {
	my($slashdb, $constants, $user, $form, $blobdb) = @_;

	if ($form->{file_content}) {
		my $data;
		if ($form->{file_content}) {
			my $upload = $form->{query_apache}->upload;
			if ($upload) {
				my $temp_body;
				my $fh = $upload->fh;
				local $/;
				$data = <$fh>;
			}
			$form->{file_content} =~ s|^.*?([^/:\\]+)$|$1|;
		}

		my $content = {
			seclev		=> $form->{seclev},
			filename	=> $form->{file_content},
			content_type	=> $form->{content_type},
			data		=> $data,
			sid		=> $form->{sid},
			description	=> $form->{description},
		};

		unless ($blobdb->createFileForStory($content)) {
			print "<p><b>File not saved, check logs for errors</b><br>";
			printf "Filename: %s, description: %s, data size: %dK</p>",
				strip_literal($form->{file_content}),
				strip_literal($form->{description}),
				length($data) / 1024;
		}
	}

	if ($form->{delete}) {
		if (ref($form->{_multi}{delete}) eq 'ARRAY') {
			for (@{$form->{_multi}{delete}}) {
				$blobdb->deleteStoryFile($_);
			}
		} else {
			$blobdb->deleteStoryFile($form->{delete});
		}
	}

	editBySid(@_);
}

##################################################################
# Stubbed Out
sub listAll { 
}

##################################################################
# Stubbed Out
sub editFile { 
}

##################################################################

createEnvironment();
main();
1;
