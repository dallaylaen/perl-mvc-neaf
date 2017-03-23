package MVC::Neaf::X::Session::SQL;

use strict;
use warnings;
our $VERSION = 0.1501;

=head1 NAME

MVC::Neaf::X::Session::SQL - SQL-based session backend for
Not Even A Framework.

=head1 DESCRIPTION

Store session data in a SQL table.
Consider a pre-existing DB connection and a low-traffic site where
having additional session storage (e.g. key-value) would be an overkill.

=head1 SYNOPSIS

    my $session_engine = MVC::Neaf::X::Session::SQL->new (
        dbh           => $my_db_conn,
        table         => 'session',
        id_as         => 'session_name',
        index_by      => [ 'user_id', ... ], # optional
        content_as    => 'json_data',        # optional but recommended
    );

=head1 METHODS

=cut

use Carp;
use parent qw(MVC::Neaf::X::Session::Base);

=head2 new (%options)

=cut

sub new {
    my ($class, %opt) = @_;

    my @missing = grep { !$opt{$_} } qw(dbh table id_as);
    $class->my_croak( "Mandatory parameters missing: @missing" )
        if @missing;

    # Setup all requests in advance so we can fail as early as possible
    my $dbh     = $opt{dbh};
    my $table   = $opt{table};
    my $id_as   = $opt{id_as};
    my $fields  = $opt{index_by};
    my $raw     = $opt{content_as};

    my @all_fields;
    push @all_fields, $opt{content_as} if defined $opt{content_as};
    push @all_fields, @{ $opt{index_by} } if $opt{index_by};
    $class->my_croak( "At least one of index_by or content_as MUST be present" )
        unless @all_fields;

    # OUCH ORM by hand...
    # We update BEFORE inserting just in case someone forgot unique key
    # don't do like this. Session_id MUST be indexed anyway.
    $opt{sql_upd} = sprintf "UPDATE %s SET %s WHERE %s = ?"
        , $table
        , join( ",", map { "$_=?" } @all_fields )
        , $id_as;

    $opt{sql_ins} = sprintf "INSERT INTO %s(%s) VALUES(%s)"
        , $table
        , join( ",", $id_as, @all_fields )
        , join( ",", ("?") x (@all_fields+1));

    $opt{sql_sel} = sprintf "SELECT %s FROM %s WHERE %s"
        , join( ",", $id_as, @all_fields )
        , $table
        , "$id_as = ?";

    # Now try to use at least SELECT statement to make sure that
    # the database provided actually has the needed table.

    my $sth_test = $dbh->prepare_cached( $opt{sql_sel} );

    $class->my_croak( "DB check failed for table '$table'/key '$id_as'/columns '@all_fields': ".$dbh->errstr )
        unless $sth_test->execute( "TestSessionId" );

    $sth_test->finish;
    $opt{index_by} ||= [];
    $opt{where_die} = "table $table for $id_as =";

    # Self-test passed, everything just as planned

    return $class->SUPER::new(%opt);
};

=head2 store( $id, $str, $hash )

Store data in database, using $hash as additional indexed fields if any defined.

=cut

sub store {
    my ($self, $id, $str, $hash) = @_;

    # ONLY want raw data as a parameter if we know WHERE to store it!
    my @param = $self->{content_as} ? ($str) : ();
    push @param, map { $hash->{$_} } @{ $self->{index_by} };

    my $sth_upd = $self->{dbh}->prepare_cached( $self->{sql_upd} );
    $sth_upd->execute( @param, $id );

    my $n = $sth_upd->rows;
    if ($n > 0) {
        carp "More than one row updated in $self->{where_die} '$id'"
            if $n > 1;
        return {};
    };

    $self->my_croak("Failed to UNDATE $self->{where_die} '$id': ".$self->{dbh}->errstr)
        if $n < 0;

    # all good, but need to insert
    my $sth_ins = $self->{dbh}->prepare_cached( $self->{sql_ins} );
    $sth_ins->execute( $id, @param );

    $self->my_croak( "Failed to INSERT into $self->{where_die} '$id': ".$self->{dbh}->errstr )
        unless $sth_ins->rows == 1;

    return {};
};

=head2 fetch( $id )

Fetch data from table.

Returns { data => stringified_data, orevvide => { individual_fields } }

=cut

sub fetch {
    my ($self, $id) = @_;

    my $sth_sel = $self->{dbh}->prepare_cached( $self->{sql_sel} );
    $sth_sel->execute( $id );
    my $override = $sth_sel->fetchrow_hashref;
    $sth_sel->finish;

    return unless $override;

    my $raw = $self->{content_as} ? delete $override->{ $self->{content_as} } : undef;

    return {
        data => $raw,
        override => $override,
    };
};

1;
