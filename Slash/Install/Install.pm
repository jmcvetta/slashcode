# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id: Install.pm,v 1.19 2002/05/21 16:11:51 pudge Exp $

package Slash::Install;
use strict;
use DBIx::Password;
use Slash;
use Slash::DB;
use File::Copy;
use File::Find;
use File::Path;
use vars qw($VERSION);
use base 'Slash::DB::Utility';

# BENDER: Like most of life's problems, this one can be solved with bending.

($VERSION) = ' $Revision: 1.19 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
	my($class, $user) = @_;
	my $self = {};
	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;
	$self->{slashdb} = Slash::DB->new($user);

	return $self;
}

sub create {
	my($self, $values) = @_;
	$self->sqlInsert('site_info', $values);
}

sub delete {
	my($self, $key) = @_;
	my $sql = "DELETE from site_info WHERE name = " . $self->sqlQuote($key);
	$self->sqlDo($sql);
}

sub deleteByID  {
	my($self, $key) = @_;
	my $sql = "DELETE from site_info WHERE param_id=$key";
	$self->sqlDo($sql);
}

sub get {
	my($self, $key) = @_;
	my $count = $self->sqlCount('site_info', "name=" . $self->sqlQuote($key));
	my $hash;
	if ($count > 1) {
		$hash = $self->sqlSelectAllHashref('param_id', '*', 'site_info', "name=" . $self->sqlQuote($key));
	} else {
		$hash = $self->sqlSelectHashref('*', 'site_info', "name=" . $self->sqlQuote($key));
	}

	return $hash;
}

sub exists {
	my($self, $key, $value) = @_;
	return unless $key;
	my $where;
	$where .= "name=" . $self->sqlQuote($key);
	$where .= " AND value=" . $self->sqlQuote($value) if $value;
	my $count = $self->sqlCount('site_info', $where);

	return $count;
}

sub getValue {
	my($self, $key) = @_;
	my $count = $self->sqlCount('site_info', "name=" . $self->sqlQuote($key));
	my $value;
	unless ($count > 1) {
		($value) = $self->sqlSelect('value', 'site_info', "name=" . $self->sqlQuote($key));
	} else {
		$value = $self->sqlSelectColArrayref('value', 'site_info', "name=" . $self->sqlQuote($key));
	}

	return $value;
}

sub getByID {
	my($self, $id) = @_;
	my $return = $self->sqlSelectHashref('*', 'site_info', "param_id = $id");

	return $return;
}

sub readTemplateFile {
	my($self, $filename) = @_;
	return unless -f $filename;
	my $fh = gensym;
	open($fh, "< $filename\0") or die "Can't open $filename to read from: $!";
	my @file = <$fh>;
	my %val;
	my $latch;
	for (@file) {
		if (/^__(.*)__$/) {
			$latch = $1;
			next;
		}
		$val{$latch} .= $_ if $latch;
	}
	$val{'tpid'} = undef if $val{'tpid'};
	{
		# Make chomp() remove all newlines, not just 1.  These fields
		# are used in ways sensitive to extraneous whitespace.
		local $/ = "";
		for (qw| name page section lang seclev |) {
			chomp($val{$_}) if $val{$_};
		}
	}
	for (qw| description title template |) {
		chomp($val{$_}) if $val{$_};
	}

	return \%val;
}

sub writeTemplateFile {
	my($self, $filename, $template) = @_;
	my $fh = gensym;
	open($fh, "> $filename\0") or die "Can't open $filename to write to: $!";
	for (qw(section description title page lang name template seclev)) { #(keys %$template) {
		next if ($_ eq 'tpid');
		print $fh "__${_}__\n";
		$template->{$_} =~ s/\015\012/\n/g;
		print $fh "$template->{$_}\n";
	}
	close $fh;
}

sub installTheme {
	my($self, $answer, $themes, $symlink) = @_;
	$themes ||= $self->{'_themes'};

	$self->_install($themes->{$answer}, $symlink);
}

sub installThemes {
	my($self, $answers, $themes, $symlink) = @_;
	$themes ||= $self->{'_themes'};

	for my $answer (@$answers) {
		for (keys %$themes) {
			if ($answer eq $themes->{$_}{installorder}) {
				$self->_install($themes->{$_}, $symlink, 0);
			}
		}
	}
}

sub installPlugin {
	my($self, $answer, $plugins, $symlink) = @_;
	$plugins ||= $self->{'_plugins'};

	$self->_install($plugins->{$answer}, $symlink, 1);
}

sub installPlugins {
	my($self, $answers, $plugins, $symlink) = @_;
	$plugins ||= $self->{'_plugins'};

	for my $answer (@$answers) {
		for (keys %$plugins) {
			if ($answer eq $plugins->{$_}{order}) {
				$self->_install($plugins->{$_}, $symlink, 1);
			}
		}
	}
}

sub _install {
	my($self, $hash, $symlink, $flag) = @_;
	# Yes, performance wise this is questionable, if getValue() was
	# cached.... who cares this is the install. -Brian
	if ($self->exists('hash', $hash->{name})) {
		print STDERR "Plugin $hash->{name} has already been installed\n";
		return;
	}
	if ($flag) {
		return if $self->exists('plugin', $hash->{name});

		$self->create({
			name            => 'plugin',
			value           => $hash->{'name'},
			description     => $hash->{'description'},
		});
	} else {
		# not sure if this is what we want, but leave it
		# in until someone complains.  really, we should
		# have reinstall theme/plugin methods or
		# something.  -- pudge
		return if $self->exists('theme', $hash->{name});

		$self->create({
			name            => 'theme',
			value           => $hash->{'name'},
			description     => $hash->{'description'},
		});
	}
	my $hostname = $self->getValue('basedomain');
	my $email = $self->getValue('adminmail');
	my $driver = $self->getValue('db_driver');
	my $prefix_site = $self->getValue('site_install_directory');
	my $SLASH_PREFIX = $self->getValue('base_install_directory');

	my %stuff = ( # [relative directory, executable]
		htdoc		=> ["htdocs",			1],
		htdoc_code	=> ["htdocs/code",		0],
		htdoc_faq	=> ["htdocs/faq",		0],
		sbin		=> ["sbin",			1],
		image		=> ["htdocs/images",		0],
		image_award	=> ["htdocs/images/awards",	0],
		image_banner	=> ["htdocs/images/banners",	0],
		image_faq	=> ["htdocs/images/faq",	0],
		topic		=> ["htdocs/images/topics",	0],
		task		=> ["tasks",			1],
		misc		=> ["misc",			1],
	);

	for my $section (keys %stuff) {
		next unless exists $hash->{$section} && @{$hash->{$section}};
		my $instdir = "$prefix_site/$stuff{$section}[0]";
		mkpath $instdir, 0, 0755;

		for (@{$hash->{$section}}) {
			# I hope no one tries to embed spaces in their
			# theme/plugin... heh!
			# Yes, this should actually be specific, and not
			# take shorcuts.  What is it trying to do? -- pudge
			my($oldfilename, $dir) = split;
			my $filename = $oldfilename;
			$filename =~ s/^.*\/(.*)$/$1/;
			$dir =~ s/\s*$// if $dir;
			# Allow third parameter as relative directory
			# for 'htdoc=' or 'image=' lines.
			if ($dir &&
			    ($section eq 'htdoc' || $section eq 'image'))
			{
				if ($dir !~ m{^topics/}) {
					$dir =~ s{^([^/])}{/$1};
					$dir =~ s{/$}{};
					mkpath "$instdir$dir", 0, 0755 
						if ! -d "$instdir/$dir";
				} else {
					# Uh-uh! Use 'topic=...'
					$dir = '';
				}
			} else {
				$dir = '';
			}
			my $old = "$hash->{dir}/$oldfilename";
			my $new = "$instdir$dir/$filename";

			# I don't think we should delete the file first,
			# but it is a thought. -- pudge
			# unlink $new;
			if ($symlink) {
				symlink $old, $new;
			} else {
				copy $old, $new;
				my $mode = $stuff{$section}[1] ? 0755 : 0644;
				chmod $mode, $new;
			}
		}
	}

	my($sql, @sql, @create);

	if ($hash->{"${driver}_schema"}) {
		my $schema_file = "$hash->{dir}/" . $hash->{"${driver}_schema"};
		my $fh = gensym;
		if (open($fh, "< $schema_file\0")) {
			while (<$fh>) {
				chomp;
				next if /^#/;
				next if /^$/;
				next if /^ $/;
				push @create, $_;
			}
			close $fh;
		} else {
			warn "Can't open $schema_file: $!";
		}

		$sql = join '', @create;
		@sql = split /;/, $sql;
	}

	if ($hash->{"${driver}_dump"}) {
		my $dump_file = "$hash->{dir}/" . $hash->{"${driver}_dump"};
		my $fh = gensym;
		if (open($fh, "< $dump_file\0")) {
			while (<$fh>) {
				# A theme's dump.sql may wish to override
				# the main defaults.sql, so we should allow
				# REPLACE and UPDATE here. - Jamie
				next unless /^(INSERT|DELETE|REPLACE|UPDATE)\b/i;
				# what is this for?  multiline SQL?
				# maybe be more explicit, or provide a comment:
				#   until ($_ =~ /;\s*$/) { $_ .= <$fh> }
				# The syntax is just subobvious.  -- pudge
				$_ .= <$fh> while $_ !~ /;\s*$/;
				chomp;
				s/www\.example\.com/$hostname/g;
				s/admin\@example\.com/$email/g;
				s|/usr/local/slash|$SLASH_PREFIX|g;
				push @sql, $_;
			}
			close $fh;
		} else {
 			warn "Can't open $dump_file: $!";
 		}
 	}

	for (@sql) {
		next unless $_;
		s/;\s*$//;
		unless ($self->sqlDo($_)) {
			print "Failed on :$_:\n";
		}
	}
	@sql = ();

	if ($hash->{plugin}) {
		for (sort {
			$hash->{plugin}{$a}{installorder} <=> $hash->{plugin}{$b}{installorder}
			||
			$a cmp $b
		} keys %{$hash->{plugin}}) {
			$self->installPlugin($_, 0, $symlink);
		}
	}

	if ($hash->{'template'}) {
		for (@{$hash->{'template'}}) {
			my $id;
			my $template = $self->readTemplateFile("$hash->{'dir'}/$_");
			if ($template and ($id = $self->{slashdb}->existsTemplate($template))) {
				$self->{slashdb}->setTemplate($id, $template);
			} elsif ($template) {
				$self->{slashdb}->createTemplate($template);
			} else {
				warn "Can't open template file $_: $!";
			}
		}
	}

	if ($hash->{"${driver}_prep"}) {
		my $prep_file = "$hash->{dir}/" . $hash->{"${driver}_prep"};
		my $fh = gensym;
		if (open($fh, "< $prep_file\0")) {
			while (<$fh>) {
				next unless (/^INSERT/i or /^UPDATE/i or /^DELETE/i or /^REPLACE/i or /^ALTER/i or /^CREATE/i);
				# what is this for?  multiline SQL?
				# maybe be more explicit, or provide a comment:
				#   until ($_ =~ /;\s*$/) { $_ .= <$fh> }
				# The syntax is just subobvious.  -- pudge
				$_ .= <$fh> while $_ !~ /;\s*$/;
				chomp;
				s/www\.example\.com/$hostname/g;
				s/admin\@example\.com/$email/g;
				s|/usr/local/slash|$SLASH_PREFIX|g;
				push @sql, $_;
			}
			close $fh;
		} else {
 			warn "Can't open $prep_file: $!";
 		}
 	}

	for (@sql) {
		next unless $_;
		s/;$//;
		unless ($self->sqlDo($_)) {
			print "Failed on :$_:\n";
		}
	}
	@sql = ();

	if ($hash->{note}) {
		my $file = "$hash->{dir}/$hash->{note}";
		my $fh = gensym;
		if (open($fh, "< $file\0")) {
			print <$fh>;
			close $fh;
		} else {
			warn "Can't open $file: $!";
		}
	}
}

sub getPluginList {
	my $plugin_list = _getList(@_, 'plugins', 'PLUGIN');
	setListOrder($plugin_list);
	setListInstallOrder($plugin_list);
	return $plugin_list;
}

sub getThemeList {
	my $theme_list = _getList(@_, 'themes', 'THEME');
	setListOrder($theme_list);
	# Don't care about installorder for themes, since only one
	# gets installed.
	return $theme_list;
}

sub getSiteTemplates {
	my($self) = @_;
	my @files;
	my @templates;
	my $prefix = $self->get('base_install_directory');
	$prefix = $prefix->{value};
	my $theme = $self->get('theme');
	$theme = $theme->{value};
	push(@files, "$prefix/themes/$theme/THEME");
	my $plugins = $self->get('plugin');
	my @plugins;
	for (keys %$plugins) {
		push @files, "$prefix/plugins/$plugins->{$_}{value}/PLUGIN";
	}
	for my $file (@files) {
		my $file_handle = gensym;
		open($file_handle, "$file");
		$file =~ s/PLUGIN//;
		$file =~ s/THEME//;
		while (my $line = <$file_handle>) {
			chomp($line);
			my($key, $val) = split(/=/, $line, 2);
			$key = lc $key;
			push @templates, "$file/$val"
				if ($key eq 'template');
		}
	}
	return \@templates;
}

sub _getList {
	my($self, $prefix, $subdir, $type) = @_;
	$self->{'_install_dir'} = $prefix;

	my $dh = gensym;
	unless (opendir($dh, "$prefix/$subdir")) {
		warn "Can't opendir $prefix/$subdir: $!";
		return;
	}

	my %hash;
	while (my $dir = readdir($dh)) {
		next if $dir =~ /^\.$/;
		next if $dir =~ /^\.\.$/;
		next if $dir =~ /^CVS$/;
		my $fh = gensym;
		open($fh, "< $prefix/$subdir/$dir/$type\0") or next;
		$hash{$dir}{dir} = "$prefix/$subdir/$dir";
		#This should be overridden by the actual name of the plugin
		$hash{$dir}{name} = $dir;

		my @info;
		{
			local $/;
			@info = split /\015\012?|\012/, <$fh>;
		}

		for (@info) {
			next if /^#/;
			my($key, $val) = split(/=/, $_, 2);
			$key = lc $key;
			if ($key =~ /^(
				htdoc | htdoc_code | htdoc_faq | 
				image | image_award | image_banner | image_faq |
				task | template | sbin | misc | topic
			)s?$/x) {
				push @{$hash{$dir}{$1}}, $val;
			} elsif ($key =~ /^(
				plugin | requiresplugin
			)s?$/x) {
				$hash{$dir}{$1}{$val} = 1;
			} else {
				$hash{$dir}{$key} = $val;
			}
		}
	}

	$self->{"_$subdir"} = \%hash;
	return \%hash;
}

##################################################
# Set the {order} field of each element of %$hr to
# 1 thru whatever, in ascii order of the elements' names.
sub setListOrder {
	my($hr) = @_;
	my $plugin;
	my @plugins = sort keys %$hr;

	my $i = 0;
	for $plugin (@plugins) { $hr->{$plugin}{order} = ++$i }
}

##################################################
# Set the {installorder} field of each element of %$hr to
# 1 thru whatever, in the order that the elements (plugins)
# should be installed (or where it doesn't matter, in ascii
# order).
sub setListInstallOrder {
	my($hr) = @_;
	my $plugin;
	my @plugins = sort keys %$hr;
	my $n_plugins = scalar @plugins;

	for $plugin (@plugins) { $hr->{$plugin}{installorder} = 0 }

	# This algorithm is a bit lame but it's simple and works.
	# Its lameness will suck an extra few milliseconds at install
	# time, which isn't a big deal.
	# Go through the list of plugins n times, where n = the number
	# of plugins itself, and each time fix at least one ordering
	# problem (probably more).  After all n times, the order will
	# be as correct as it's going to be (and by the way, recursive
	# looping "requires"ing is stupid but it won't break anything
	# and its results will be predictable).
	for (1..$n_plugins) {
		for my $dep (@plugins) {
			# If this plugin says it requires other plugins,
			# we loop through them all and set our installorder
			# to come after all theirs.
			if ($hr->{$dep}{requiresplugin}
				&& ref($hr->{$dep}{requiresplugin}) eq 'HASH') {
				my $new = $hr->{$dep}{installorder};
				my @reqs = keys %{$hr->{$dep}{requiresplugin}};
				for my $req (@reqs) {
					if ($hr->{$req}
						&& $hr->{$req}{installorder}+1
						 > $hr->{$dep}{installorder}) {
						$new = $hr->{$req}{installorder}+1;
					}
				}
				$hr->{$dep}{installorder} = $new;
			}
		}
	}

	# At this point, {installorder} should be accurate with duplicates.
	# Now make it unambiguous, and a permutation of {order}.  By
	# falling back on plugin name alphabetical order we make sure
	# ties are resolved predictably.
	@plugins = sort {
		$hr->{$a}{installorder} <=> $hr->{$b}{installorder}
		||
		$a cmp $b
	} @plugins;
	my $i = 0;
	for $plugin (@plugins) { $hr->{$plugin}{installorder} = ++$i }
}

sub reloadArmors {
	my($self, $armors) = @_;
	my $count = 0;

	$self->sqlDo('DELETE FROM spamarmors');
	for (@{$armors}) {
		$_->{'-armor_id'} = 'null';
		$self->sqlInsert('spamarmors', $_) && $count++;
	}

	return $count;
}

1;

__END__

=head1 NAME

Slash::Install - Install libraries for slash

=head1 SYNOPSIS

	use Slash::Install;

=head1 DESCRIPTION

This was deciphered from crop circles.

=head1 SEE ALSO

Slash(3).

=cut
