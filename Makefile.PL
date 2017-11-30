use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                 => 'MVC::Neaf',
    AUTHOR               => q{Konstantin S. Uvarin <khedin@gmail.com>},
    VERSION_FROM         => 'lib/MVC/Neaf.pm',
    ABSTRACT_FROM        => 'lib/MVC/Neaf.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    MIN_PERL_VERSION     => 5.008,
    PL_FILES             => {},
    PREREQ_PM => {
        'Digest::SHA'    => 0, # not present in 5.8 TODO use SHA3
        'ExtUtils::MakeMaker' => 6.64, # for TEST_REQUIRES
        'HTTP::Headers'  => 0,
        'JSON'           => 0,
        'overload'       => 0,
        'parent'         => 0, # not present in 5.8
        'Plack::Request' => 0,
        'Template'       => 0,
        'URI::Escape'    => 0,
    },
    TEST_REQUIRES => {
        'Test::More'     => 0.87, # done_testing
        'Test::Warn'     => 0,
        'File::Temp'     => 0,
    },
    META_MERGE => {
        "meta-spec" => { version => 2 },
        prereqs => {
            develop => {
                requires => {
                    'DBD::SQLite'    => 0, # sql-based session
                    'DBI'            => 0,
                    'GD::Simple'     => 0, # for png example
                    'LWP::UserAgent' => 0, # it depends on it
                    (($] < 5.010) ? () : ('Validator::LIVR' => 0)),
                }
            },
            runtime => {
                recommends => {
                    'JSON::XS' => 0,
                },
            },
        },
    },
    dist                 => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean                => { FILES => 'MVC-Neaf-*' },
);
