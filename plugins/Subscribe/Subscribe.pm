# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: Subscribe.pm,v 1.6 2002/02/21 03:59:31 jamie Exp $

package Slash::Subscribe;

use strict;
use Slash;
use Slash::Utility;
use Slash::DB::Utility;

use vars qw($VERSION);

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision: 1.6 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
        my($class) = @_;
        my $self = { };

	my $slashdb = getCurrentDB();
        my $plugins = $slashdb->getDescriptions('plugins');
        return unless $plugins->{Subscribe};

        bless($self, $class);

        return $self;
}

########################################################
# Internal.
sub _subscribeDecisionPage {
	my($self, $trueOnOther, $r) = @_;

        my $user = getCurrentUser();
	my $uid = $user->{uid} || 0;
        return 0 if !$user
                ||  !$uid
                ||   $user->{is_anon};

	return 0 if !$user->{hits_paidfor}
                || ( $user->{hits_bought}
			&& $user->{hits_bought} >= $user->{hits_paidfor} );

	my $decision = 0;
        $r ||= Apache->request;
        my $uri = $r->uri;
        if ($uri eq '/') {
                $uri = 'index';
        } else {
                $uri =~ s{^.*/([^/]+)\.pl$}{$1};
        }
	if ($uri =~ /^(index|article|comments)$/) {
		$decision = 1 if $user->{"buypage_$uri"};
	} elsif ($trueOnOther) {
		$decision = 1 if $user->{buypage_index}
			or $user->{buypage_article}
			or $user->{buypage_comments};
	}
	if (getCurrentStatic('subscribe_debug')) {
		print STDERR "_subscribeDecisionPage $trueOnOther $decision $user->{uid}"
			. " $user->{hits_bought} $user->{hits_paidfor}"
			. " uri '$uri'\n";
	}
	return $decision;
}

sub adlessPage {
	my($self, $r) = @_;
	return $self->_subscribeDecisionPage(1, $r);
}

sub buyingThisPage {
	my($self, $r) = @_;
	return $self->_subscribeDecisionPage(0, $r);
}

# By default, allow readers to buy x pages for $y, 2x pages for $2y,
# etc.  If you want to have n-for-the-price-of-m sales or whatever,
# change the logic here.
sub convertDollarsToPages {
	my($self, $amount) = @_;
	my $constants = getCurrentStatic();
	return sprintf("%0.0f", $amount*$constants->{paypal_num_pages}/
		$constants->{paypal_amount});
}

# When readers cancel a subscription, how much money to refund?
sub convertPagesToDollars {
	my($self, $pages) = @_;
	my $constants = getCurrentStatic();
	return sprintf("%0.02f", $pages*$constants->{paypal_amount}/
		$constants->{paypal_num_pages});
}


########################################################
# Keys expected in the $payment hashref are:
#	uid		user id
#	email		user email address, or blank
#	payment_gross	total payment before fees
#	payment_net	payment received by site after fees
#	pages		number of pages user will receive
#	transaction_id	(optional) any ID you'd use to identify this payment
#	data		(optional) any additional data
sub insertPayment {
	my($self, $payment) = @_;
	my $slashdb = getCurrentDB();
	my $success = 1; # set to 0 on insert failure

	# If no transaction id was given, we'll be making up one of our own.
	# We'll have to make up our own and retry it if it fails.
	my $create_trans = !defined($payment->{transaction_id});
	my $num_retries = 50;

	while (1) {
		if ($create_trans) {    
			$payment->{transaction_id} = substr(
				Digest::MD5::md5_hex(join(":",
					$payment->{uid}, $payment->{data},
					time, $$, rand(2**30)
				)), 0, 17
			);
		}
		$success = $slashdb->sqlInsert("subscribe_payments", $payment);
		last if $success || !$create_trans || --$num_retries <= 0;
	}

	return $success;
}

1;

__END__

# Below is the stub of documentation.

=head1 NAME

Slash::Subscribe - Let users buy adless pages

=head1 SYNOPSIS

	use Slash::Subscribe;

=head1 DESCRIPTION

This plugin lets users purchase adless pages at /subscribe.pl, with
built-in (but optional) support for using Paypal.

Understanding its code will be easier after recognizing that one of its
design goals was to distinguish the act of "paying for" adless pages,
in which money (probably) trades hands, from the act of "buying," in
which adless pages are actually viewed.  After "paying for" a page, you
can still get your money back, but after you "bought" it, no refund.

=head1 AUTHOR

Jamie McCarthy, jamie@mccarthy.vg

=head1 SEE ALSO

perl(1).

=cut
