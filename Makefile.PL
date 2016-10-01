use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'MVC::Neaf',
    AUTHOR              => q{Konstantin S. Uvarin <khedin@gmail.com>},
    VERSION_FROM        => 'lib/MVC/Neaf.pm',
    ABSTRACT_FROM       => 'lib/MVC/Neaf.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'     => 0.87,
        'URI::Escape'    => 0,
        'LWP::UserAgent' => 0,
        'Plack::Request' => 0,
        'Template'       => 0,
        'JSON::XS'       => 1.4,
        'HTTP::Headers'  => 0,
        'Digest::SHA'    => 0,
        'parent'         => 0,
        'CGI'            => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'MVC-Neaf-*' },
);
