use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
# $Id: Makefile.PL,v 1.1 2006/10/10 20:37:22 jamiemccarthy Exp $
WriteMakefile(
    'NAME'	=> 'Slash::Tagbox::FHEditorPop',
    'VERSION_FROM' => 'FHEditorPop.pm', # finds $VERSION
    'PM'	=> { 'FHEditorPop.pm' =>   '$(INST_LIBDIR)/FHEditorPop.pm' },
);
