#!/usr/bin/perl -w

###############################################################################
# comments.pl - this code displays comments for a particular story id 
#
# Copyright (C) 1997 Rob "CmdrTaco" Malda
# malda@slashdot.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#
#  $Id: comments.pl,v 1.20 2000/08/16 17:00:08 pudge Exp $
###############################################################################
use strict;
use Date::Manip;
use Compress::Zlib;
use vars '%I';
use lib '../';
use Slash;


##################################################################
sub main {
	*I = getSlashConf();
	getSlash();

	my $id = getFormkeyId($I{U}{uid});

	# Seek Section for Appropriate L&F
	my $sct = $I{dbh}->quote($I{F}{sid}) || "''";
	my($s, $title, $commentstatus) = sqlSelect(
		"section,title,commentstatus","newstories","sid=$sct"
	);
	my $SECT = getSection($s);

	$I{F}{pid} ||= "0";
	$title ||= "Comments";
	
	header("$SECT->{title}: $title", $SECT->{section});

	if ($I{U}{uid} < 1 and length($I{F}{upasswd}) > 1) {
		print "<P><B>Login for \"$I{F}{unickname}\" has failed</B>.  
			Please try again. $I{F}{op}<BR><P>";
		$I{F}{op} = "Preview";
	}

	# Find out user's karma.
	($I{U}{karma}) = sqlSelect("karma", "users_info", "uid=$I{U}{uid}")
		if $I{U}{uid} > 0;

	unless ($I{F}{sid}) {
		# Posting from outside discussions...
		$I{F}{sid} = $ENV{HTTP_REFERER} ? crypt($ENV{HTTP_REFERER}, 0) : '';
		$I{story_time} = sqlSelect("time", "stories", "sid = '$I{F}{sid}'"); 
		$I{story_time} ||= "now()";
		unless (sqlSelect("title", "discussions", "sid='$I{F}{sid}'")) {
			sqlInsert("discussions", {
				sid	=> $I{F}{sid},
				title	=> '',
				ts	=> $I{story_time},
				url	=> $ENV{HTTP_REFERER}
			});
		}
	}

	if ($I{F}{op} eq "Submit") {

		if (checkSubmission("comments", $I{post_limit}, $I{max_posts_allowed}, $id)) {
			submitComment();
		}

	} elsif ($I{F}{op} eq "Edit" || $I{F}{op} eq "post" 
			||
		$I{F}{op} eq "Preview" || $I{F}{op} eq "Reply") {

		if ($I{F}{op} eq 'Reply') {
			insertFormkey("comments", $id, $I{F}{sid});
		} else {
			updateFormkeyId();
		}

		editComment($id);


	} elsif ($I{F}{op} eq "delete" && $I{U}{aseclev}) {
		titlebar("99%", "Delete $I{F}{cid}");

		my $delCount = deleteThread($I{F}{sid}, $I{F}{cid});
		$I{dbh}->do("UPDATE stories SET commentcount=commentcount-$delCount,
			writestatus=1 WHERE sid=" . $I{dbh}->quote($I{F}{sid})
		);
		print "Deleted $delCount items from story $I{F}{sid}\n";

	} elsif ($I{F}{op} eq "moderate") {
		titlebar("99%", "Moderating $I{F}{sid}");
		moderate();
		printComments($I{F}{sid}, $I{F}{pid}, $I{F}{cid}, $commentstatus);

	} elsif ($I{F}{op} eq "Change") {
		saveChanges() if $I{U}{uid} > 0;
		printComments($I{F}{sid}, $I{F}{cid}, $I{F}{cid}, $commentstatus);

	} elsif ($I{F}{cid}) {
		printComments($I{F}{sid}, $I{F}{cid},$I{F}{cid}, $commentstatus);

	} elsif($I{F}{sid}) {
		printComments($I{F}{sid}, $I{F}{pid}, "", $commentstatus);

	} else {
		commentIndex();
	}

	writelog("comments", $I{F}{sid});

	footer();
}


##################################################################
# Index of recent discussions: Used if comments.pl is called w/ no
# parameters
sub commentIndex {
	titlebar("90%", "Several Active Discussions");
	print qq!<MULTICOL COLS="2">\n!;

	my $c = sqlSelectMany("discussions.sid,discussions.title,discussions.url", <<SQL);
discussions,stories where displaystatus > -1 and discussions.sid=stories.sid and time <= now() order by time desc LIMIT 50
SQL

	while (my $C = $c->fetchrow_hashref) {
		$C->{title} ||= "untitled";
		print <<EOT;
	<LI><A HREF="$I{rootdir}/comments.pl?sid=$C->{sid}">$C->{title}</A>
	(<A HREF="$C->{url}">referer</A>)

EOT

	}

	print "</MULTICOL>\n\n";
	$c->finish;
}


##################################################################
# Save users preferences is they change them, and click the "Save" checkbox
sub saveChanges {
	return unless $I{U}{uid} > 0;

	sqlUpdate("users_comments", { 
		threshold	=> $I{U}{threshold}, 
		mode		=> $I{U}{mode},
		commentsort	=> $I{U}{commentsort}
	}, "uid=$I{U}{uid}") if defined $I{query}->param("savechanges");
}


##################################################################
# Welcome to one of the ancient beast functions.  The comment editor
# is the form in whcih you edit a comment.
sub editComment {
	my $id = shift;
	$I{U}{points} = 0;

	my $formkey_earliest = time() - $I{formkey_timeframe};

	my $reply = sqlSelectHashref(getDateFormat("date", "time") . ",
		subject,comments.points as points,comment,realname,nickname,
		fakeemail,homepage,cid,sid,users.uid as uid",
		"comments,users,users_info,users_comments",
		"sid=" . $I{dbh}->quote($I{F}{sid}) . "
		AND cid=" . $I{dbh}->quote($I{F}{pid}) . "
		AND users.uid=users_info.uid 
		AND users.uid=users_comments.uid 
		AND users.uid=comments.uid"
	);

	# Display parent comment if we got one
	if($I{F}{pid}) {
		titlebar("95%", " $reply->{subject}");
		print <<EOT;
<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0" WIDTH="95%" ALIGN="CENTER">
EOT
		dispComment($reply);
		print "\n</TABLE><P>\n\n";
	}

	if (!checkTimesPosted("comments", $I{max_posts_allowed}, $id, $formkey_earliest)) {
		my $max_posts_warn =<<EOT;
<P><B>Warning! you've exceeded max allowed submissions for the day :
$I{max_submissions_allowed}</B></P>
EOT
		errorMessage($max_posts_warn);
	}

	if (!$I{allow_anonymous} && (!$I{U}{uid} || $I{U}{uid} < 1)) {
	    print <<EOT;
Sorry, anonymous posting has been turned off.
Please <A HREF="$I{rootdir}/users.pl">register and log in</A>.
EOT
	    return;
	}

	
	if ($I{F}{postercomment}) {
		titlebar("95%", "Preview Comment"); 
		previewForm();
		print "<P>\n";
	}

	titlebar("95%", "Post Comment");
	print <<EOT;

<FORM ACTION="$ENV{SCRIPT_NAME}" METHOD="POST">

	<INPUT TYPE="HIDDEN" NAME="sid" VALUE="$I{F}{sid}">
	<INPUT TYPE="HIDDEN" NAME="pid" VALUE="$I{F}{pid}">
	<INPUT TYPE="HIDDEN" NAME="mode" VALUE="$I{U}{mode}">
	<INPUT TYPE="HIDDEN" NAME="startat" VALUE="$I{U}{startat}">
	<INPUT TYPE="HIDDEN" NAME="threshold" VALUE="$I{U}{threshold}">
	<INPUT TYPE="HIDDEN" NAME="commentsort" VALUE="$I{U}{commentsort}">

	<TABLE BORDER="0" CELLSPACING="0" CELLPADDING="1">

EOT

	 # put in hidden field if there's a formkey
        print qq(<INPUT type="hidden" name="formkey" value="$I{F}{formkey}">\n);

	print <<EOT if $I{U}{uid} < 1;
	<TR><TD> </TD><TD>
		You are not logged in.  You can login now using the
		convenient form below, or
		<A HREF="$I{rootdir}/users.pl">Create an Account</A>.
		Posts without proper registration are posted as
		<B>$I{U}{nickname}</B>
	</TD></TR>

	<INPUT TYPE="HIDDEN" NAME="rlogin" VALUE="userlogin">

	<TR><TD ALIGN="RIGHT">Nick</TD><TD>
		<INPUT TYPE="TEXT" NAME="unickname" VALUE="$I{F}{unickname}">

	</TD></TR><TR><TD ALIGN="RIGHT">Passwd</TD><TD>
		<INPUT TYPE="PASSWORD" NAME="upasswd">

	</TD></TR>

EOT

	print <<EOT;
	<TR><TD WIDTH="130" ALIGN="RIGHT">Name</TD><TD WIDTH="500">
		<A HREF="$I{rootdir}/users.pl">$I{U}{nickname}</A> [
EOT

	print $I{U}{uid} > 0 ? <<EOT1 : <<EOT2;
		<A HREF="$I{rootdir}/users.pl?op=userclose">Log Out</A> 
EOT1
		<A HREF="$I{rootdir}/users.pl">Create Account</A> 
EOT2
			
	print " ] </TD></TR>\n\n";

	print <<EOT if $I{U}{fakeemail};
	<TR><TD ALIGN="RIGHT">Email</TD>
		<TD>$I{U}{fakeemail}</TD></TR>

EOT

	print <<EOT if $I{U}{homepage};
	<TR><TD ALIGN="RIGHT">URL</TD>
		<TD><A HREF="$I{U}{homepage}">$I{U}{homepage}</A></TD></TR>

EOT

	print qq!\t<TR><TD ALIGN="RIGHT">Subject</TD>\n\n!;

	if ($I{F}{pid} && !$I{F}{postersubj}) { 
		$I{F}{postersubj} = $reply->{subject};
		$I{F}{postersubj} =~ s/^Re://i;
		$I{F}{postersubj} =~ s/\s\s/ /g;
		$I{F}{postersubj} = "Re:$I{F}{postersubj}";
	} 

	print "\t\t<TD>", $I{query}->textfield(
		-name		=> 'postersubj', 
		-default	=> $I{F}{postersubj}, 
		-size		=> 50,
		-maxlength	=> 50
	), "</TD></TR>\n\n";

	printf <<EOT, stripByMode($I{F}{postercomment}, 'literal');
	<TR>
		<TD ALIGN="RIGHT" VALIGN="TOP">Comment</TD>
		<TD><TEXTAREA WRAP="VIRTUAL" NAME="postercomment" ROWS="10"
		COLS="50">%s</TEXTAREA>
		<BR>(Use the Preview Button! Check those URLs!
		Don't forget the http://!)
	</TD></TR>

	<TR><TD> </TD><TD>
EOT

	my $checked = $I{F}{nobonus} ? ' CHECKED' : '';
	print qq!\t\t<INPUT TYPE="CHECKBOX"$checked NAME="nobonus"> No Score +1 Bonus\n!
		if $I{U}{karma} > $I{goodkarma} and $I{U}{uid} > 0;

        if ($I{allow_anonymous}) {
	    $checked = $I{F}{postanon} ? ' CHECKED' : '';
	    print qq!\t\t<INPUT TYPE="CHECKBOX"$checked NAME="postanon"> Post Anonymously<BR>\n!
		if $I{U}{karma} > -1 and $I{U}{uid} > 0;
        }

	print <<EOT;
		<INPUT TYPE="SUBMIT" NAME="op" VALUE="Submit">
		<INPUT TYPE="SUBMIT" NAME="op" VALUE="Preview">

EOT

	if ($I{F}{posttype}) {
		selectGeneric("postmodes", "posttype", "code", "name", $I{F}{posttype});
	} else {
		selectGeneric("postmodes", "posttype", "code", "name", $I{U}{posttype});
	}

	printf <<EOT, join "\n", map { "\t\t\t&lt;$_&gt;" } @{$I{approvedtags}};
	</TD></TR><TR>
		<TD VALIGN="TOP" ALIGN="RIGHT">Allowed HTML</TD><TD><FONT SIZE="1">
%s
		</FONT>
	</TD></TR>
</TABLE>


</FORM>

<B>Important Stuff:</B>
	<LI>Please try to keep posts on topic.
	<LI>Try to reply to other people comments instead of starting
		new threads.
	<LI>Read other people's messages before posting your own to
		avoid simply duplicating what has already been said.
	<LI>Use a clear subject that describes what your message is about.
	<LI>Offtopic, Inflammatory, Inappropriate, Illegal,
		or Offensive comments might be moderated.  (You can read
		everything, even moderated posts, by adjusting your 
		threshold on the User Preferences Page)

<P><FONT SIZE="2">Problems regarding accounts or comment posting 
	should be sent to
	<A HREF="mailto:$I{adminmail}">$I{siteadmin_name}</A>.</FONT>
EOT

}

##################################################################
# Validate comment, looking for errors
sub validateComment {
	my($comm, $subj, $preview) = @_;

	if (isTroll()) {
		print <<EOT;
This account or IP has been temporarily disabled. This means that either
this IP or user account has been moderated down more than 5 times in the
last 24 hours.  If you think this is unfair, you should contact
$I{adminmail}.  If you are being a troll, now is the time for you to
either grow up, or change your IP.
EOT

		return;
	}

	if (!$I{allow_anonymous} && ($I{U}{uid} < 1 || $I{F}{postanon})) { 
		print <<EOT;
Sorry, anonymous posting has been turned off.
Please <A HREF="$I{rootdir}/users.pl">register and log in</A>.
EOT

		return;
	}

	unless ($comm && $subj) {
		print <<EOT;
Cat got your tongue? (something important seems to be missing from your
comment ... like the body or the subject!)
EOT
		return;
	}

	$subj =~ s/\(Score(.*)//i;
	$subj =~ s/Score:(.*)//i;
	
	{  # fix unclosed tags
		my %tags;
		my $match = 'B|I|A|OL|UL|EM|TT|STRONG|BLOCKQUOTE|DIV';

		while ($comm =~ m|(<(/?)($match)\b[^>]*>)|igo) { # loop over tags
			my($tag, $close, $whole) = (uc $3, $2, $1);

			if ($close) {
				$tags{$tag}--;

				# remove orphaned close tags if count < 0
				while ($tags{$tag} < 0) {
					my $p = pos($comm) - length($whole);
					$comm =~ s|^(.{$p})</$tag>|$1|si;
					$tags{$tag}++;
				}

			} else {
				$tags{$tag}++;

				if (($tags{UL} + $tags{OL} + $tags{BLOCKQUOTE}) > 4) {
					editComment() and return unless $preview;
					print <<EOT;
You can only post nested lists and blockquotes four levels deep.
Please fix your UL, OL, and BLOCKQUOTE tags.
EOT

					return;
				}
			}	
		}

		for my $tag (keys %tags) {
			# add extra close tags
			while ($tags{$tag} > 0) {
				$comm .= "</$tag>";
				$tags{$tag}--;
			}
		}
	}

	my($dupRows) = sqlSelect(
		'count(*)', 'comments', 'sid=' . $I{dbh}->quote($I{F}{sid}) .
		' AND comment=' . $I{dbh}->quote($I{F}{postercomment})
	);

	if ($dupRows || !$I{F}{sid}) { 
		# $I{r}->log_error($ENV{SCRIPT_NAME} . " " . $insline);

		editComment() and return unless $preview;
		print <<EOT;
Something is wrong: parent=$I{F}{pid} dups=$dupRows discussion=$I{F}{sid}
<UL>
EOT

		print "<LI>Didja forget a subject?</LI>\n" unless $I{F}{postersubj};
		print "<LI>Duplicate.  Did you submit twice?</LI>\n" if $dupRows;
		print "<LI>Space aliens have eaten your data.</LI>\n" unless $I{F}{sid};
		print <<EOT;
<LI>Let us know if anything exceptionally strange happens</LI>
</UL>
EOT
		return;
	}

	if (length($I{F}{postercomment}) > 100) {
		local $_ = $I{F}{postercomment};
		my($w, $br); # Whitespace & BRs
		$w++ while m/\w/g;
		$br++ while m/<BR>/gi;

		if (($w / ($br + 1)) < 7) {
			editComment() and return unless $preview;
			return;
		}
	}

	# here begins the troll detection code - PMG 160200
	# hash ref from db containing regex, modifier (gi,g,..),field to be tested,
	# ratio of field (this makes up the {x,} in the regex, minimum match (hard minimum), 
	# minimum length (minimum length of that comment has to be to be tested), err_message 
	# message displayed upon failure to post if regex matches contents.
	# make sure that we don't select new filters without any regex data
	my $filter_hashref = sqlSelectAll("*","content_filters","regex != '' and field != ''");

	for (@$filter_hashref) {
		my($number_match, $regex);
		my $raw_regex		= $_->[1];
		my $modifier		= 'g' if $_->[2] =~ /g/;
		my $case		= 'i' if $_->[2] =~ /i/;
		my $field		= $_->[3];
		my $ratio		= $_->[4];
		my $minimum_match	= $_->[5];
		my $minimum_length	= $_->[6];
		my $err_message		= $_->[7];
		my $maximum_length	= $_->[8];
		my $isTrollish		= 0;
		
		next if ($minimum_length && length($I{F}{$field}) < $minimum_length);
		next if ($maximum_length && length($I{F}{$field}) > $maximum_length);

		if ($minimum_match) {
			$number_match = "{$minimum_match,}";
		} elsif ($ratio > 0) {
			$number_match = "{" . int(length($I{F}{$field}) * $ratio) . ",}";
		}

		$regex = $raw_regex . $number_match;
		my $tmp_regex = $regex;

		# DEBUG
		# print "<br>\n";
		# print "number $_->[0] regex $tmp_regex minimum_match $minimum_match modifier $modifier case $case<br>\n";

		$regex = $case eq 'i' ? qr/$regex/i : qr/$regex/;

		if ($modifier eq 'g') {
			$isTrollish = 1 if $I{F}{$field} =~ /$regex/g;
		} else {
			$isTrollish = 1 if $I{F}{$field} =~ /$regex/;
		}

		if ((length($I{F}{$field}) >= $minimum_length)
			&& $minimum_length && $isTrollish) {

			if (((length($I{F}{$field}) <= $maximum_length)
				&& $maximum_length) || $isTrollish) {

				editComment() and return unless $preview;
				print <<EOT;
<BR>Lameness filter encountered.  Post aborted.<BR><BR><B>$err_message</B><BR>
EOT
				return;
			}

		} elsif ($isTrollish) {
			editComment() and return unless $preview;
			print <<EOT;
<BR>Lameness filter encountered.  Post aborted.<BR><BR><B>$err_message</B><BR>
EOT
			return;
		}
	}

	# interpolative hash ref. Got these figures by testing out
	# several paragraphs of text and saw how each compressed
	# the key is the ratio it should compress, the array lower,upper
	# for the ratio. These ratios are _very_ conservative
	# a comment has to be absolute shit to trip this off
	my $limits = {
		1.3 => [10,19],
		1.1 => [20,29],
		.8 => [30,44],
		.5 => [45,99],
		.4 => [100,199],
		.3 => [200,299],
		.2 => [300,399],
		.1 => [400,1000000],
	};

	# Ok, one list ditch effort to skew out the trolls!
	if (length($I{F}{postercomment}) >= 10) {
		for (keys %$limits) {
			# DEBUG
			# print "ratio $_ lower $limits->{$_}->[0] upper $limits->{$_}->[1]<br>\n";
			# if it's within lower to upper
			if (length($I{F}{postercomment}) >= $limits->{$_}->[0]
				&& length($I{F}{postercomment}) <= $limits->{$_}->[1]) {

				# if is >= the ratio, then it's most likely a troll comment
				if ((length(compress($I{F}{postercomment})) /
					length($I{F}{postercomment})) <= $_) {

					editComment() and return unless $preview;
					# blammo luser
					print <<EOT;


<BR>Lameness filter encountered.  Post aborted.<BR><BR>
EOT
				}

			}
		}
	}

	return($comm, $subj);
}

##################################################################
# Previews a comment for submission
sub previewForm {
	$I{U}{sig} = "" if $I{F}{postanon};

	my $tempComment = stripByMode($I{F}{postercomment}, $I{F}{posttype});
	my $tempSubject = stripByMode(
		$I{F}{postersubj}, 'nohtml', $I{U}{aseclev}, 'B'
	);

	($tempComment, $tempSubject) = validateComment($tempComment, $tempSubject, 1);

	$tempComment .= '<BR>' . $I{U}{sig};

	my $preview = {
		nickname  => $I{F}{postanon} ? $I{anon_name} : $I{U}{nickname},
		pid	  => $I{F}{pid},
		homepage  => $I{F}{postanon} ? '' : $I{U}{homepage},
		fakeemail => $I{F}{postanon} ? '' : $I{U}{fakeemail},
		'time'	  => 'soon',
		subject	  => $tempSubject,
		comment	  => $tempComment
	};

	print <<EOT;
<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0" WIDTH="95%" ALIGN="CENTER">
EOT

	my $tm = $I{U}{mode};
	$I{U}{mode} = 'archive';
	dispComment($preview);       
	$I{U}{mode} = $tm;

	print "</TABLE>\n";
}


##################################################################
# Saves the Comment
sub submitComment {
	$I{F}{postersubj} = stripByMode(
		$I{F}{postersubj}, 'nohtml', $I{U}{aseclev}, ''
	);
	$I{F}{postercomment} = stripByMode($I{F}{postercomment}, $I{F}{posttype});

	($I{F}{postercomment}, $I{F}{postersubj}) =
		validateComment($I{F}{postercomment}, $I{F}{postersubj})
		or return;

	titlebar("95%", "Submitted Comment");

	my $ident = $ENV{REMOTE_ADDR};
	my $pts = 0;

	if($I{U}{uid} > 0 && !$I{F}{postanon} ) {
		$pts = $I{U}{defaultpoints};
		$pts-- if $I{U}{karma} < $I{badkarma};
		$pts++ if $I{U}{karma} > $I{goodkarma} and !$I{F}{nobonus};
		# Enforce proper ranges on comment points.
		$pts = $I{comment_minscore} if $pts < $I{comment_minscore};
		$pts = $I{comment_maxscore} if $pts > $I{comment_maxscore};
	}

	$I{dbh}->do("LOCK TABLES comments WRITE");
	my($maxCid) = sqlSelect(
		"max(cid)", "comments", "sid=" . $I{dbh}->quote($I{F}{sid})
	);

	$maxCid++; # This is gonna cause troubles
	my $insline = "INSERT into comments values (".
		$I{dbh}->quote($I{F}{sid}) . ",$maxCid," .
		$I{dbh}->quote($I{F}{pid}) . ",now(),'$ident'," .
		$I{dbh}->quote($I{F}{postersubj}) . "," .
		$I{dbh}->quote($I{F}{postercomment}) . "," .
		($I{F}{postanon} ? -1 : $I{U}{uid}) . ",$pts,-1,0)";

	# don't allow pid to be passed in the form.
	# This will keep a pid from being replace by
	# with other comment's pid
	if ($I{F}{pid} >= $maxCid || $I{F}{pid} < 0) {
		print "Don't you have anything better to do with your life?";
		return;
	}

	if ($I{dbh}->do($insline)) {
		$I{dbh}->do("UNLOCK TABLES");
		print <<EOT;
Comment Submitted. There will be a delay before the comment becomes part
of the static page.  What you submitted appears below.  If there is a
mistake, well, you should have used the Preview button!<P>
EOT

		# Update discussion
		my($dtitle) = sqlSelect(
			'title', 'discussions', "sid=" . $I{dbh}->quote($I{F}{sid})
		);

		unless ($dtitle) {
			sqlUpdate(
				"discussions",
				{ title => $I{F}{postersubj} },
				"sid=" . $I{dbh}->quote($I{F}{sid})
			) if $I{F}{sid};
		}

		my($ws) = sqlSelect(
			"writestatus", "stories", "sid=" . $I{dbh}->quote($I{F}{sid})
		);

		if ($ws == 0) {
			sqlUpdate(
				"stories",
				{ writestatus => 1 }, 
				"sid=" . $I{dbh}->quote($I{F}{sid})
			);
		}

		sqlUpdate(
			"users_info",
			{ -totalcomments => 'totalcomments+1' },
			"uid=" . $I{dbh}->quote($I{U}{uid}), 1
		);

		# successful submission		
		formSuccess($I{F}{formkey},$maxCid,length($I{F}{postercomment}));

		my($tc, $mp, $cpp) = getvars(
			"totalComments",
			"maxPoints",
			"commentsPerPoint"
		);

		setvar("totalComments", ++$tc);

		undoModeration($I{F}{sid});
		printComments($I{F}{sid}, $maxCid, $maxCid);

	} else {
		$I{dbh}->do("UNLOCK TABLES");
		$I{r}->log_error("$DBI::errstr $insline");
		print "<P>There was an unknown error in the submission.<BR>";
	}
}

##################################################################
# Handles moderation
sub moderate {
	my $totalDel = 0;
	my $hasPosted = hasPosted($I{F}{sid});

	print "\n<UL>\n";

	# Handle Deletions, Points & Reparenting
	foreach (sort keys %{$I{F}}) {
		if (/^del_(\d+)$/) { # && $I{U}{points}) {
			my $delCount = deleteThread($I{F}{sid}, $1);
			$totalDel += $delCount;
			sqlUpdate(
				"stories",
				{
					-commentcount => "commentcount-$delCount",
					writestatus	=> 1
				},
				"sid=" . $I{dbh}->quote($I{F}{sid}), 1
			);

			print <<EOT if $totalDel;
	<LI>Deleted $delCount items from story $I{F}{sid} under comment $I{F}{$_}</LI>
EOT

		} elsif (!$hasPosted && /^reason_(\d+)$/) {
			moderateCid($I{F}{sid}, $1, $I{F}{"reason_$1"});
		}
	}

	print "\n</UL>\n";

	if ($hasPosted && !$totalDel) {
		print "You've already posted something in this discussion<BR>";
	} elsif ($I{U}{aseclev} && $totalDel) {
		my($cc) = sqlSelect(
			"count(sid)", "comments", "sid=" . $I{dbh}->quote($I{F}{sid})
		);
		sqlUpdate(
			"stories",
			{ commentcount => $cc },
			"sid=" . $I{dbh}->quote($I{F}{sid})
		);
		print "$totalDel comments deleted.  Comment count set to $cc<BR>\n";
	}
}

##################################################################
# Handles moderation
# Moderates a specific comment
sub moderateCid {
	my($sid, $cid, $reason) = @_;
	# Check if $uid has seclev and Credits
	return unless $reason;
	
	if ($I{U}{points} < 1) {
		unless ($I{U}{aseclev} > 99 && $I{authors_unlimited}) {
			print "You don't have any moderator points.";
			return;
		}
	}

	my($cuid, $ppid, $subj, $points, $oldreason) = sqlSelect(
		"uid,pid,subject,points,reason","comments",
		"cid=$cid and sid='$sid'"
	);

	my($mid) = sqlSelect(
		"id", "moderatorlog",
		"uid=$I{U}{uid} and cid=$cid and sid='$sid'"
	);
	if ($mid) {
		print "<LI>$subj ($sid-$cid, <B>Already moderated</B>)</LI>";
		return;
	}

	my $modreason = $reason;
	my $val = "-1";
	if ($reason == 9) { # Overrated
		$val = "-1";
		$val = "+0" if $points < 0;
		$reason = $oldreason;
	} elsif ($reason == 10) { # Underrated
		$val = "+1";
		$val = "+0" if $points > 1;
		$reason = $oldreason;
	} elsif ($reason > $I{badreasons}) {
		$val = "+1";
	}

	my $scorecheck = $points + $val;
	# If the resulting score is out of comment score range, no further actions 
	# need be performed.
	if ($scorecheck < $I{comment_minscore} || $scorecheck > $I{comment_maxscore}) {
		# We should still log the attempt for M2, but marked as inactive so
		# we don't mistakenly undo it.
		sqlInsert("moderatorlog", {
			uid	=> $I{U}{uid},
			val	=> $val,
			sid	=> $sid,
			cid	=> $cid,
			reason	=> $modreason,
			-ts	=> 'now()',
			active => 0
		});

		print "<LI>$subj ($sid-$cid, <B>Comment already at limit</B>)</LI>";
		return;
	}

	my $strsql = "UPDATE comments SET
		points=points$val,
		reason=$reason,
		lastmod=$I{U}{uid}
		WHERE sid=" . $I{dbh}->quote($sid)."
		AND cid=$cid 
		AND points " .
			($val < 0 ? " > $I{comment_minscore}" : "") .
			($val > 0 ? " < $I{comment_maxscore}" : "");
	$strsql .= " AND lastmod<>$I{U}{uid}"
		unless $I{U}{aseclev} > 99 && $I{authors_unlimited};

	if ($val ne "+0" && $I{dbh}->do($strsql)) {
		sqlInsert("moderatorlog", {
			uid	=> $I{U}{uid},
			val	=> $val,
			sid	=> $sid,
			cid	=> $cid,
			reason	=> $modreason,
			-ts	=> 'now()'
		});


		# Adjust comment posters karma
		if ($cuid > 0) {
			if ($val > 0) {
				sqlUpdate("users_info", { -karma => "karma$val" },
					"uid=$cuid AND karma<$I{maxkarma}"
				);
			} elsif ($val < 0) {
				sqlUpdate("users_info", { -karma => "karma$val" },
					"uid=$cuid"
				);
			}
		}

		# Adjust moderators total mods
		sqlUpdate(
			"users_info",
			{ -totalmods => 'totalmods+1' }, 
			"uid=$I{U}{uid}"
		);

		# And deduct a point.
		$I{U}{points} = $I{U}{points} > 0 ? $I{U}{points} - 1 : 0;
		sqlUpdate(
			"users_comments",
			{ -points=>$I{U}{points} }, 
			"uid=$I{U}{uid}"
		); # unless ($I{U}{aseclev} > 99 && $I{authors_unlimited});

		print <<EOT;
	<LI>$val ($I{reasons}[$reason]) $subj
		($sid-$cid, <B>$I{U}{points}</B> points left)</LI>
EOT
	}
}

##################################################################
# Given an SID & A CID this will delete a comment, and all its replies
sub deleteThread {
	my($sid, $cid) = @_;
	my $delCount = 1;

	return unless $I{U}{aseclev} > 100;

	print "Deleting $cid from $sid, ";

	my $delkids = sqlSelectMany("cid", "comments", "sid='$sid' and pid='$cid'");

	while (my($scid) = $delkids->fetchrow_array) {
		$delCount += deleteThread($sid, $scid);
	}

	$delkids->finish;

	$I{dbh}->do("delete from comments WHERE sid=" .
		$I{dbh}->quote($sid) . " and cid=" . $I{dbh}->quote($cid)
	);

	print "<BR>";
	return $delCount;
}

##################################################################
# Checks if this user has posted in this discussion or not (to determine
# if they can moderate or not)
sub hasPosted {
	return if $I{U}{aseclev} > 99 && $I{authors_unlimited};
	my($sid) = @_;
	my($c) = sqlSelect("count(*)", "comments",
		"sid=" . $I{dbh}->quote($sid) . " and uid=$I{U}{uid}"
	);
	return $c;
}

##################################################################
# If you moderate, and then post, all your moderation is undone.
sub undoModeration {
	my($sid) = @_;
	return if $I{U}{uid} == -1 || ($I{U}{aseclev} > 99 && $I{authors_unlimited});
	my $c=sqlSelectMany("cid,val,active", "moderatorlog",
		"uid=$I{U}{uid} and sid=" . $I{dbh}->quote($sid)
	);

	while (my($cid, $val, $active) = $c->fetchrow) {
		# We undo moderation even for inactive records (but silently for 
		# inactive records)
		$I{dbh}->do("delete from moderatorlog where
			cid=$cid and uid=$I{U}{uid} and sid=" .
			$I{dbh}->quote($sid)
		);

		# If moderation wasn't actually performed, we should not change
		# the score.
		next if ! $active;

		# Insure scores still fall within the proper boundaries
		my $scorelogic = $val < 0 ? "points < $I{comment_maxscore}" :
									"points > $I{comment_minscore}";
		sqlUpdate(
			"comments",
			{ -points => "points+" . (-1 * $val) },
			"cid=$cid and sid=" . $I{dbh}->quote($sid) . " AND $scorelogic"
		);

		print "Undoing moderation to Comment #$cid<BR>";
	}	
	$c->finish;
}

##################################################################
# Troll Detection: essentially checks to see if this IP or UID has been abusing
# the system in the last 24 hours.
# 1=Troll 0=Good Little Goober
sub isTroll {
	return if $I{U}{aseclev} > 99;
	my($badIP, $badUID) = (0, 0);
	return 0 if $I{U}{uid} > 0 && $I{U}{karma} > -1;
	# Anonymous only checks HOST
	($badIP) = sqlSelect("sum(val)","comments,moderatorlog",
		"comments.sid=moderatorlog.sid AND comments.cid=moderatorlog.cid
		AND host_name='$ENV{REMOTE_ADDR}' AND moderatorlog.active=1
		AND (to_days(now()) - to_days(ts) < 3) GROUP BY host_name"
	);

	return 1 if $badIP < $I{down_moderations}; 

	if ($I{U}{uid} > 0) {
		($badUID) = sqlSelect("sum(val)","comments,moderatorlog",
			"comments.sid=moderatorlog.sid AND comments.cid=moderatorlog.cid
			AND comments.uid=$I{U}{uid} AND moderatorlog.active=1
			AND (to_days(now()) - to_days(ts) < 3)  GROUP BY comments.uid"
		);
	}

	return 1 if $badUID < $I{down_moderations};
	return 0;
}

main();
0;
