use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'      => 'Slash::Moderation',
    'VERSION_FROM' => 'Moderation.pm', # finds $VERSION
    'PM'        => {
	'Moderation.pm' => '$(INST_LIBDIR)/Moderation.pm',
    },
);
