# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: PopupTree.pm,v 1.1 2004/06/17 16:11:53 jamiemccarthy Exp $

package Slash::Admin::PopupTree;

=head1 NAME

Slash::Admin::PopupTree


=head1 SYNOPSIS

	# basic example of usage


=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;
use HTML::PopupTreeSelect '1.4';

use base 'HTML::PopupTreeSelect';
use vars qw($VERSION);

($VERSION) = ' $Revision: 1.1 $ ' =~ /\$Revision:\s+([^\s]+)/;

#========================================================================

=head2 getPopupTree( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub getPopupTree {
	my($stid, $stid_names) = @_;
	my $reader	= getObject('Slash::DB', { db_type => 'reader' });
	my $constants	= getCurrentStatic();
	my $tree	= $reader->getTopicTree;

	my $data;
	my %topics;
	for my $tid (map  { $_->[0] }
	             sort { $a->[1] cmp $b->[1] }
	             map  { [ $_, lc $tree->{$_}{textname} ] } keys %$tree) {
		my $top = $tree->{$tid};
		@{$topics{$tid}}{qw(value label height width image)} = (
			$tid, @{$top}{qw(textname height width image)}
		);

		if (scalar keys %{$top->{parent}}) {
			$topics{$tid}{parent} = $top->{parent};
			for my $pid (keys %{$top->{parent}}) {
				push @{$topics{$pid}{children}}, $topics{$tid};
			}
		} else {
			push @$data, $topics{$tid};
		}
	}

	HTML::PopupTreeSelect::reset_id();

	# most of the stuff below (name, title, etc.) should be in vars or getData
	my $select = Slash::Admin::PopupTree->new(
		name			=> 'slashtopics',
		data			=> $data,
		slashtopics		=> \%topics,
		stid			=> $stid,
		stid_names		=> $stid_names,
		slashorig		=> $tree,
		title			=> 'Select a Category',
		button_label		=> 'Choose',
		onselect		=> 'slashtopics_main_add',
		form_field_form		=> 'slashstoryform',
		hide_selects		=> 0,
		scrollbars		=> 1,
		width			=> 300,
		height			=> 300,
		image_path		=> $constants->{imagedir} . '/',
	);

	return $select->output;
}

sub output {
	my($self, $template) = @_;
	return $self->SUPER::output(1);
}

sub _output_generate {
	my($self, $template, $param) = @_;
	$param->{slashtopics} = $self->{slashtopics};
	$param->{stid}        = $self->{stid};
	$param->{stid_names}  = $self->{stid_names};

	return slashDisplay('topic_popup_tree', $param, { Return => 1, Page => 'admin' });
}

# there's a little black spot on the sun today
{
	my $id = 1;
	no warnings 'redefine';
	sub HTML::PopupTreeSelect::next_id { $id++ }
	sub HTML::PopupTreeSelect::reset_id { $id = 1 }
}

1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id: PopupTree.pm,v 1.1 2004/06/17 16:11:53 jamiemccarthy Exp $
