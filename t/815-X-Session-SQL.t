#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf::X::Session::SQL;

# Check prerequisites - don't want extra dependency
if (!eval { require DBD::SQLite }) {
    plan skip_all => "DBD::SQLite not found, skipping SQL/DBI session test";
    exit 0;
};

require DBI;
my $dbh = DBI->connect("dbi:SQLite:dbname=:memory:", '', '', { RaiseError => 1 } );

$dbh->do( <<"SQL" );
    CREATE TABLE my_sess (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id varchar(80) UNIQUE NOT NULL,
        user INT,
        raw varchar(4096)
    );
SQL

my %opt = ( dbh => $dbh, table => 'my_sess' );
my $engine = eval {
    MVC::Neaf::X::Session::SQL->new( %opt );
};
note "ERR (missing args): $@";
like $@, qr/id_as/, "no id field = no go";

$opt{id_as} = 'session_id';
$engine = eval {
    MVC::Neaf::X::Session::SQL->new( %opt );
};
note "ERR (missing args): $@";
like $@, qr/one of .* must/i, "no stored data = no go";

$engine = MVC::Neaf::X::Session::SQL->new(
    %opt, index_by => [ 'user' ], content_as => 'raw' );

note explain $engine;

my $ret = $engine->save_session( 'foobared', { user => 42, somedata => [5] } );

note "save = ", explain $ret;
is $ret->{id}, 'foobared', "id round trip";

$dbh->do( "UPDATE my_sess SET user = 137" );

$ret = $engine->load_session( 'foobared' );

note "load = ", explain $ret;
$ret = $ret->{data};
is $ret->{somedata}[0], 5, "deep data preserved";
is $ret->{user}, 137, "user updated just fine";

done_testing;
