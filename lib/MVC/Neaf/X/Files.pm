package MVC::Neaf::X::Files;

use strict;
use warnings;
our $VERSION = 0.1602;

=head1 NAME

MVC::Neaf::X::Files - serve static content for Not Even A Framework.

=head1 SYNOPSIS

     use MVC::Neaf qw(:sugar);

     neaf static "/path/in/url" => "/local/path", %options;

These options would go to this module's new() method described below.

=head1 DESCRIPTION

Serving static content in production via a perl application framework
is a bad idea.
However, forcing the user to run a separate web-server just to test
their CSS, JS, and images is an even worse one.

So this module is here to fill the gap.

=head1 METHODS

=cut

use MVC::Neaf::Util qw(http_date);
use parent qw(MVC::Neaf::X);

=head2 new( %options )

%options may include:

=over

=item * buffer - buffer size for serving files.
Currently this is also the size below which in-memory caching is on,
but this MAY change in the future.

=item * cache_ttl - if given, files below the buffer size will be stored
in memory for cache_ttl seconds.
B<EXPERIMENTAL>. Cache API is not yet established.

=back

=cut

sub new {
    my ($class, %options) = @_;

    defined $options{root}
        or $class->my_croak( "option 'root' is required" );

    $options{buffer} ||= 4096;
    $options{buffer} =~ /^(\d+)$/
        or $class->my_croak( "option 'buffer' must be a positive integer" );

    return $class->SUPER::new(%options);
};

=head2 serve_file( $path )

Create a Neaf-compatible response using given path.
The response is like follows:

    {
        -content => (file content),
        -headers => (length, name etc),
        -type => (content-type),
        -continue => (serve the rest of the file, if needed),
    };

Will C<die 404;> if file is not there.

=cut

# Enumerate most common file types. Patches welcome.
our %ExtType = (
    css  => 'text/css',
    gif  => 'image/gif',
    htm  => 'text/html',
    html => 'text/html',
    jpeg => 'image/jpeg',
    jpg  => 'image/jpeg',
    js   => 'application/javascript',
    png  => 'image/png',
    txt  => 'text/plain',
);

sub serve_file {
    my ($self, $file) = @_;

    my $bufsize = $self->{buffer};
    my $dir = $self->{root};
    my $time = time;
    my @header;

    # sanitize file path before caching
    $file = "/$file";
    $file =~ s#/+#/#g;
    $file =~ s#/$##;

    if (my $data = $self->{cache_content}{$file}) {
        if ($data->{expire} < $time) {
            delete $self->{cache_content}{$file};
        } else {
            push @header, content_disposition => $data->{disposition}
                if $data->{disposition};
            $data->{expire_head} ||= http_date( $data->{expire} );
            push @header, expires => $data->{expire_head};
            return {
                -content => $data->{data},
                -type => $data->{type},
                -headers=>\@header,
            };
        };
    };

    # don't let unsafe paths through
    $file =~ m#/../# and die 404;
    $file =~ m#(^|/)\.# and die 404
        unless $self->{allow_dots};

    # open file
    my $xfile = join "", $dir, $file;

    die 404 if -d $xfile; # Sic! Don't reveal directory structure
    my $ok = open (my $fd, "<", "$xfile");
    if (!$ok) {
        # TODO Warn
        die 404;
    };
    binmode $fd;

    my $size = [stat $fd]->[7];
    local $/ = \$bufsize;
    my $buf = <$fd>;

    # determine type, fallback to extention
    my $type;
    $xfile =~ m#(?:^|/)([^\/]+?(?:\.(\w+))?)$#;
    $type = $ExtType{lc $2} if defined $2;

    my $show_name = $1;
    $show_name =~ s/[\"\x00-\x19\\]/_/g;

    my $disposition = ($type && $type =~ qr#^text|^image|javascript#)
        ? ''
        : "attachment; filename=\"$show_name\"";
    push @header, content_disposition => $disposition
            if $disposition;

    # return whole file if possible
    if ($size < $bufsize) {
        if ($self->{cache_ttl}) {
            my %content;
            $content{data} = $buf;
            $content{expire} = $time + $self->{cache_ttl};
            $content{type} = $type;
            $content{disposition} = $disposition;
            $self->{cache_content}{$file} = \%content;
        };
        return { -content => $buf, -type => $type, -headers => \@header }
    };

    # If file is big, print header & first data chunk ASAP
    # then do the rest via a second callback
    push @header, content_length => $size;
    my $continue = sub {
        my $req = shift;

        local $/ = \$bufsize; # MUST do it again
        while (<$fd>) {
            $req->write($_);
        };
        $req->close;
    };

    return { -content => $buf, -type => $type, -continue => $continue, -headers => \@header };
};

=head2 make_handler

Returns a Neaf-compatible hander sub.

=cut

sub make_handler {
    my $self = shift;

    # callback to be installed via stock ->route() mechanism
    my $handler = sub {
        my $req = shift;

        my $file = $req->path_info();
        return $self->serve_file( $file );
    }; # end handler sub

    return $handler;
};

1;
