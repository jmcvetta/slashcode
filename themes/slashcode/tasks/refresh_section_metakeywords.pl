#!/usr/bin/perl -w
#
# $Id: refresh_section_metakeywords.pl,v 1.1 2003/07/22 15:25:32 vroom Exp $
#
# SlashD Task (c) OSDN 2001
#
# Description: refreshes the static "metakeywordsd" template for use
# in HTML output.

use strict;

use Slash::Display;

use vars qw( %task $me );

$task{$me}{timespec} = '49 0-23/3 * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{on_startup} = 1;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;
	my $sections = $slashdb->getSections();
        my $sect;
	my $tmpl;
        my %topics_index;
        my $stories_per_section=10;
        my $topics_per_section=10;
	$tmpl.="[% SWITCH user.currentSection %]\n";
	foreach my $s(keys %$sections){
		$sect.="$s handled\n";
                 
		my $stories_ref=$slashdb->sqlSelectColArrayref("sid","stories","time<now() and section='$s'","order by time desc limit $stories_per_section");
	        if(@$stories_ref){
	                my $sid_str=join ',', map{$_="'$_'"} @$stories_ref;
			my $tid_ref=$slashdb->sqlSelectColArrayref("tid","story_topics","sid in($sid_str)","limit $topics_per_section",{distinct=>1});
                	if(@$tid_ref){
                		my $tid_str=join ',', @$tid_ref;
				my $topic_ref=$slashdb->sqlSelectColArrayref("alttext","topics","tid in($tid_str)","limit $topics_per_section",{distinct=>1});
			        $tmpl.="[% CASE '$s' %]\n";	
		        	$tmpl.=join(', ',@$topic_ref)."\n";	
                                $topics_index{$_}++ for @$topic_ref;
			} 
	        }       
	}
	$tmpl .= "[% CASE 'index' %]\n";
	$tmpl .=  join(', ',(sort{$topics_index{$b} <=> $topics_index{$a}} keys %topics_index)[0..($topics_per_section-1)])."\n";
	$tmpl.="[% END %]\n";

	# If it exists, we update it, if not, we create it.  The final "1" arg
	# means to ignore errors.
	my $tpid = $slashdb->getTemplateByName(
		'metakeywordsd', 'tpid', 0, '', '', 1
	);

	my(%template) = ( 
		name => 'metakeywordsd',
		tpid => $tpid, 
		template => $tmpl,
	);
	if ($tpid) {
		$slashdb->setTemplate($tpid, \%template);
	} else {
		$slashdb->createTemplate(\%template);
	}

	return "section meta-keywords refreshed\n$sect";
};

1;

