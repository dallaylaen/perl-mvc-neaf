package MVC::Neaf::X::Files;

use strict;
use warnings;
our $VERSION = 0.1001;

=head1 NAME

MVC::Neaf::X::Files - serve static content for Not Even A Framework.

=head1 SYNOPSIS

     use MVC::Neaf;

     MVC::Neaf->static( "/path/in/url" => "/local/path", %options );

=head1 DESCRIPTION

=head1 METHODS

=cut

use parent qw(MVC::Neaf::X);

=head2 new( %options )

%options may include:

=over

=item * buffer - buffer size for serving files.

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

=head2 make_handler

Returns a Neaf-compatible hander sub.

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

sub make_handler {
    my $self = shift;

    my $bufsize = $self->{buffer};
    my $dir = $self->{root};

    # callback to be installed via stock ->route() mechanism
    my $handler = sub {
        my $req = shift;

        my $file = $req->path_info;

        # sanitize file path
        $file =~ m#/../# and die 404;
        $file =~ s#^/*#/#;
        $file =~ s#/*$##;
        $file =~ s#/+#/#g;

        my $time = time;

        if (my $data = $self->{cache_content}{$file}) {
            if ($data->{expire} < $time) {
                delete $self->{cache_content}{$file};
            } else {
                $req->set_header( content_disposition => $data->{disposition} )
                    if $data->{disposition};
                return { -content => $data->{data}, -type => $data->{type} };
            };
        };

        # open file
        my $xfile = join "", $dir, $file;

        die 403 if -d $xfile;
        my $ok = open (my $fd, "<", "$xfile");
        if (!$ok) {
            # TODO Warn
            die 404;
        };

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
        $req->set_header( content_disposition => $disposition )
                if $disposition;

        # return whole file if possible
        if ($size < $bufsize) {
            if ($self->{cache_ttl}) {
                $self->{cache_content}{$file}{data} = $buf;
                $self->{cache_content}{$file}{expire} = $time + $self->{cache_ttl};
                $self->{cache_content}{$file}{type} = $type;
                $self->{cache_content}{$file}{disposition} = $disposition;
            };
            return { -content => $buf, -type => $type }
        };

        # If file is big, print header & first data chunk ASAP
        # then do the rest via a second callback
        $req->header_out( content_length => set => $size );
        my $continue = sub {
            my $req = shift;

            local $/ = \$bufsize; # MUST do it again
            while (<$fd>) {
                $req->write($_);
            };
            $req->close;
        };

        return { -content => $buf, -type => $type, -continue => $continue };
    }; # end handler sub

    return $handler;
};

1;
