package MVC::Neaf::Request::PSGI;

use strict;
use warnings;
our $VERSION = 0.11;

=head1 NAME

MVC::Neaf::Request::PSGI - Not Even A Framework: PSGI driver.

=head1 METHODS

=cut

use URI::Escape qw(uri_unescape);
use Encode;
use Plack::Request;

use parent qw(MVC::Neaf::Request);

=head2 new( env => $psgi_input )

Constructor.

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    $self->{driver} ||= Plack::Request->new( $self->{env} || {} );
    return $self;
};

=head2 do_get_client_ip

=cut

sub do_get_client_ip {
    my $self = shift;

    return $self->{driver}->address;
};

=head2 do_get_http_version()

=cut

sub do_get_http_version {
    my $self = shift;

    my $proto = $self->{driver}->protocol || '1.0';
    $proto =~ s#^HTTP/##;

    return $proto;
};

=head2 do_get_scheme()

=cut

sub do_get_scheme {
    my $self = shift;
    return $self->{driver}->scheme;
};

=head2 do_get_hostname()

=cut

sub do_get_hostname {
    my $self = shift;
    my $base = $self->{driver}->base;

    return $base =~ m#//([^:?/]+)# ? $1 : "localhost";
};

=head2 do_get_port()

=cut

sub do_get_port {
    my $self = shift;
    my $base = $self->{driver}->base;

    return $base =~ m#//([^:?/]+):(\d+)# ? $2 : "80";
};

=head2 do_get_method()

Return GET/POST.

=cut

sub do_get_method {
    my $self = shift;
    return $self->{driver}->method;
};

=head2 do_get_path()

Returns the path part of URI.

=cut

sub do_get_path {
    my $self = shift;

    my $path = $self->{env}{REQUEST_URI};
    $path = '' unless defined $path;

    $path =~ s#\?.*$##;
    $path =~ s#^/*#/#;

    return $path;
};

=head2 do_get_params()

Returns GET/POST parameters as a hash.

B<CAVEAT> Plack::Request's multivalue hash params are ignored for now.

=cut

sub do_get_params {
    my $self = shift;

    my %hash;
    foreach ( $self->{driver}->param ) {
        $hash{$_} = $self->{driver}->param( $_ );
    };

    return \%hash;
};

=head2 do_get_upload( "name" )

B<NOTE> This garbles Hash::Multivalue.

=cut

sub do_get_upload {
    my ($self, $id) = @_;

    $self->{driver_upload} ||= $self->{driver}->uploads;
    my $up = $self->{driver_upload}{$id}; # TODO don't garble multivalues

    return $up ? { tempfile => $up->path, filename => $up->filename } : ();
};

=head2 do_get_header_in

=cut

sub do_get_header_in {
    my $self = shift;

    return $self->{driver}->headers;
};

=head2 do_reply( $status_line, \%headers, $content )

Send reply to client. Not to be used directly.

B<NOTE> This function just returns its input and has no side effect,
rather relying on PSGI calling conventions.

=cut

sub do_reply {
    my ($self, $status, $content) = @_;

    my @header_array;
    $self->header_out->scan( sub {
            push @header_array, $_[0], $_[1];
    });

    # HACK - we're being returned by handler in MVC::Neaf itself in case of
    # PSGI being used.

    if ($self->{postponed}) {
        # Even hackier HACK. If we have a postponed action,
        # we must use PSGI functional interface to ensure
        # reply is sent to client BEFORE
        # postponed calls get executed.
        return sub {
            my $responder = shift;
            $self->{writer} = $responder->( [ $status, \@header_array ] );

            $self->{writer}->write( $content ) if defined $content;

            # Now we may need to output more stuff
            # So save writer inside self for callbacks to write to
            $self->execute_postponed;
            # close was not called by 1 of callbacks
            $self->do_close if $self->{continue};
        };
    };

    # Otherwise just return plain data.
    return [ $status, \@header_array, [ $content ]];
};

=head2 do_write( $data )

Write to socket in async content mode.

=cut

sub do_write {
    my ($self, $data) = @_;

    return unless defined $data;
    $self->{writer}->write( $data );
    return 1;
};

=head2 do_close()

Close client connection in async content mode.

=cut

sub do_close {
    my $self = shift;

    $self->{writer}->close;
};

1;
