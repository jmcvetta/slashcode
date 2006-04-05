# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: Bookmark.pm,v 1.4 2006/03/29 22:46:39 pudge Exp $

package Slash::Bookmark;

=head1 NAME

Slash::Console - Perl extension for Bookmars 


=head1 SYNOPSIS

	use Slash::Bookmark;


=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use DBIx::Password;
use Slash;
use Slash::Display;
use Slash::Utility;

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';
use vars qw($VERSION);

($VERSION) = ' $Revision: 1.4 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub createBookmark {
	my($self, $data) = @_;
	$self->sqlInsert("bookmarks", $data);
	my $id = $self->getLastInsertId();
	return $id;
}

sub getUserBookmarkByUrlId {
	my($self, $uid, $url_id) = @_;
	my $uid_q = $self->sqlQuote($uid);
	my $url_id_q = $self->sqlQuote($url_id);
	return $self->sqlSelectHashref("*", "bookmarks", "uid=$uid_q AND url_id=$url_id_q");
}

sub updateBookmark {
	my($self, $bookmark) = @_;
	$self->sqlUpdate("bookmarks", $bookmark, "bookmark_id = $bookmark->{bookmark_id}");
}

sub getRecentBookmarks {
	my($self, $limit) = @_;
	$limit ||= 50;

	return $self->sqlSelectAllHashrefArray("*", "bookmarks, urls", "bookmarks.url_id = urls.url_id", "ORDER by bookmarks.createdtime DESC LIMIT $limit");
}

sub getPopularBookmarks {
	my($self, $days, $limit) = @_;
	$days  ||= 3;
	$limit ||= 50;

	my $time_clause = " AND bookmarks.createdtime >= DATE_SUB(NOW(), INTERVAL $days DAY)";
	
	return $self->sqlSelectAllHashrefArray("count(*) AS cnt, bookmarks.title, urls.*", "bookmarks, urls", "bookmarks.url_id = urls.url_id $time_clause", "GROUP BY urls.url_id ORDER by 1 DESC, bookmarks.createdtime DESC  LIMIT $limit");
	
}

1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id: Bookmark.pm,v 1.4 2006/03/29 22:46:39 pudge Exp $