use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::TagDataView',
    'VERSION_FROM' => 'TagDataView.pm', # finds $VERSION
    'PM'	=> { 'TagDataView.pm' => '$(INST_LIBDIR)/TagDataView.pm' },
);
