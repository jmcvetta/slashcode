use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
# $Id: Makefile.PL,v 1.1 2006/09/27 02:07:59 jamiemccarthy Exp $
WriteMakefile(
    'NAME'	=> 'Slash::Tagbox::FHPopularity',
    'VERSION_FROM' => 'FHPopularity.pm', # finds $VERSION
    'PM'	=> { 'FHPopularity.pm' =>   '$(INST_LIBDIR)/FHPopularity.pm' },
);
