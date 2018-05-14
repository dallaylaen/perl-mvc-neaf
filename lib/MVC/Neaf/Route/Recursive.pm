package MVC::Neaf::Route::Recursive;

use strict;
use warnings FATAL => qw(all);

=head1 NAME

MVC::Neaf::Route::Recursive - route resolution class for Not Even A Framework.

=head1 METHODS

=cut

use Scalar::Util qw(blessed);
use Encode;
use Carp;
use Data::Dumper;

use parent qw(MVC::Neaf::Route);
use MVC::Neaf::Util qw(run_all run_all_nodie http_date);

=head2 handle_request

    handle_request( $req )

This is the CORE of Not Even A Framework.
Should not be called directly - use C<run()> instead.

C<handle_request> really boils down to

    my ($self, $req) = @_;

    my $req->path =~ /($self->{GIANT_ROUTING_RE})/
        or die 404;

    my $route = $self->{ROUTES}{$1}{ $req->method }
        or die 405;

    my $reply_hash = $route->{CODE}->($req);

    my $content = $reply_hash->{-view}->render( $reply_hash );

    return [ $reply_hash->{-status}, [...], [ $content ] ];

The rest 200+ lines of it, spread across this module and L<MVC::Neaf::Route>,
are for running callbacks, handling corner cases, and substituting sane defaults.

=cut

sub handle_request {
    my ($self, $req) = @_;

    confess "Bareword usage forbidden"
        unless blessed $self;

    # OUCH
    $req->{route} = $self;

    my $data = eval {
        my $hash = $self->dispatch_logic( $req, '', $req->path );

        # TODO 0.30 More suitable error message, force logging error
        die "NEAF: FATAL: Controller must return hash at ".$req->endpoint_origin."\n"
            unless ref $hash and UNIVERSAL::isa($hash, 'HASH');
        # TODO 0.30 Also accept (&convert) hash headers
        die "NEAF: FATAL: '-headers' must be an even-sized array at ".$req->endpoint_origin."\n"
            if defined $hash->{-headers}
                and (ref $hash->{-headers} ne 'ARRAY' or @{ $hash->{-headers} } % 2);

        # Apply path-based defaults
        my $def = $req->route->default;
        exists $hash->{$_} or $hash->{$_} = $def->{$_} for keys %$def;

        $req->_set_reply( $hash );

        if (my $hooks = $req->route->hooks->{pre_content}) {
            run_all_nodie( $hooks, sub {
                    $req->log_error( "NEAF: WARN: pre_content hook failed: $@" )
            }, $req );
        };

        # TODO 0.90 dispatch_view must belong to req->route
        warn "DEBUG data is ".((ref $hash) || (defined $hash ? 'scalar' : 'undef'))
            unless ref $hash eq 'HASH';
        $hash->{-content} ||= $self->dispatch_view( $req );
        confess "No content after render"
            unless $hash->{-content};
        $hash;
    };

    if (!$data) {
        # Failed. TODO 0.30: do it better, still convoluted logic
        $data = $self->error_to_reply( $req, $@ );
        $req->_set_reply( $data );
        confess "No content after error"
            unless $data->{-content};
    };

    # Encode content, fix headers
    $self->mangle_headers( $req );

    # Apply hooks
    if (my $hooks = $req->route->hooks->{pre_cleanup}) {
        $req->postpone( $hooks );
    };
    if (my $hooks = $req->route->hooks->{pre_reply}) {
        run_all_nodie( $hooks, sub {
                $req->log_error( "NEAF: WARN: pre_reply hook failed: $@" )
        }, $req );
    };

    # DISPATCH CONTENT
    my $content = \$data->{-content};
    $$content = '' if $req->method eq 'HEAD';
    if ($data->{-continue} and $req->method ne 'HEAD') {
        $req->postpone( $data->{'-continue'}, 1 );
        $req->postpone( sub { $_[0]->write( $$content ); }, 1 );
        return $req->do_reply( $data->{-status} );
    } else {
        return $req->do_reply( $data->{-status}, $$content );
    };
    # END DISPATCH CONTENT
};

=head2 INTERNAL LOGIC

The following methods are part of NEAF's core and should not be called
unless you want something I<very> special.

The following terminology is used hereafter:

=over

=item * prefix - part of URI path preceding what's currently being processed;

=item * stem - part of URI that matched given NEAF route;

=item * suffix - anything after the matching part
but before query parameters (the infamous C<path_info>).

=back

When recursive routing is applied, C<prefix> is left untouched,
C<stem> becomes prefix, and C<suffix> is split into new C<stem> + C<suffix>.

When a leaf route is found, it matches $suffix to its own regex
and either dies 404 or proceeds with application logic.

=head2 find_route( $method, $suffix )

Find subtree that matches given ($method, $suffix) pair.

May die 404 or 405 if no suitable route is found.

Otherwise returns (route, new_stem, new_suffix).

=cut

sub find_route {
    my ($self, $method, $path) = @_;

    # Lookup the rules for the given path
    $path =~ $self->{route_re} and my $node = $self->{route}{$1}
        or die "404\n";
    my ($stem, $suffix) = ($1, $2);
    my $route = $node->{ $method };
    unless ($route) {
        die MVC::Neaf::Exception->new(
            -status => 405,
            -headers => [Allow => join ", ", keys %$node]
        );
    };

    return ($route, $stem, $suffix);
};

=head2 dispatch_logic

    dispatch_logic( $req, $prefix, $suffix )

Find a matching route and apply it to the request.

This is recursive, may die, and may spoil C<$req>.

Upon successful termination, a reply hash is returned.
See also L<MVC::Neaf::Route/dispatch_logic>.

=cut

sub dispatch_logic {
    my ($self, $req, $stem, $suffix) = @_;

    $self->post_setup
        unless $self->{lock};

    my $method = $req->method;

    # run pre_route hooks if any
    run_all( $self->{pre_route}{$method}, $req )
        if (exists $self->{pre_route}{$method});

    my ($route, $new_stem, $new_suffix) = $self->find_route( $method, $suffix );

    $route->dispatch_logic( $req, $new_stem, $new_suffix );
};

=head2 dispatch_view

Apply view to a request.

=cut

sub dispatch_view {
    my ($self, $req) = @_;

    my $data  = $req->reply;
    my $route = $req->route;

    my $content;

    # TODO 0.25 remove, set default( -view => JS ) instead
    if (!$data->{-view}) {
        if ($data->{-template}) {
            $data->{-view} = 'TT';
            warn $req->_message( "default -view=TT is DEPRECATED, will switch to JS in 0.25" );
        } else {
            $data->{-view} = 'JS';
        };
    };

    my $view = $self->get_view( $data->{-view} );
    eval {
        run_all( $route->hooks->{pre_render}, $req )
            if $route and $route->hooks->{pre_render};

        ($content, my $type) = blessed $view
            ? $view->render( $data ) : $view->( $data );
        $data->{-type} ||= $type;
    };

    if (!defined $content) {
        $req->log_error( "Request processed, but rendering failed: ". ($@ || "unknown error") );
        die MVC::Neaf::Exception->new(
            -status => 500,
            -reason => "Rendering error: $@"
        );
    };

    return $content;
};

=head2 error_to_reply

=cut

sub error_to_reply {
    my ($self, $req, $err) = @_;

    # Convert all errors to Neaf expt.
    if (!blessed $err) {
        $err = MVC::Neaf::Exception->new(
            -status   => $err,
            -nocaller => 1,
        );
    }
    elsif ( !$err->isa("MVC::Neaf::Exception")) {
        $err = MVC::Neaf::Exception->new(
            -status   => 500,
            -sudden   => 1,
            -reason   => $err,
            -nocaller => 1,
        );
    };

    # Now $err is guaranteed to be a Neaf error

    # Use on_error callback to fixup error or gather stats
    if( $err->is_sudden and exists $self->{on_error}) {
        eval {
            $self->{on_error}->($req, $err, $req->endpoint_origin);
            1;
        }
            or $req->log_error( "on_error callback failed: ".($@ || "unknown reason") );
    };

    # Try fancy error template
    if (my $tpl = $self->{error_template}{$err->status}) {
        my $ret = eval {
            my $data = $tpl->( $req,
                status => $err->status,
                caller => $req->endpoint_origin, # TODO 0.25 kill this
                error => $err,
            );
            $data->{-status}  ||= $err->status;
            $req->_set_reply( $data );
            $data->{-content} ||= $self->dispatch_view( $req );
            $data;
        };
        return $ret if $ret;
        $req->log_error( "error_template for ".$err->status." failed:"
            .( $@ || "unknown reason") );
    };

    # Options exhausted - return plain error message,
    #    keep track of reason on the inside
    $req->log_error( $err->reason )
        if $err->is_sudden;
    return $err->make_reply( $req );
};

=head2 mangle_headers

Fixup content & headers

=cut

sub mangle_headers {
    my ($self, $req) = @_;

    my $data = $req->reply;
    my $content = \$data->{-content};

    # TODO 0.25 Make sure content & status are ALWAYS there

    # Process user-supplied headers
    if (my $append = $data->{-headers}) {
        my $head = $req->header_out;
        for (my $i = 0; $i < @$append; $i+=2) {
            $head->push_header($append->[$i], $append->[$i+1]);
        };
    };

    # Encode unicode content NOW so that we don't lie about its length
    # Then detect ascii/binary
    if (Encode::is_utf8( $$content )) {
        # UTF8 means text, period
        $$content = encode_utf8( $$content );
        $data->{-type} ||= 'text/plain';
        $data->{-type} .= "; charset=utf-8"
            unless $data->{-type} =~ /; charset=/;
    } elsif (!$data->{-type}) {
        # Autodetect binary. Plain text is believed to be in utf8 still
        $data->{-type} = $$content =~ /^.{0,512}?[^\s\x20-\x7F]/s
            ? 'application/octet-stream'
            : 'text/plain; charset=utf-8';
    } elsif ($data->{-type} =~ m#^text/#) {
        # Some other text, mark as utf-8 just in case
        $data->{-type} .= "; charset=utf-8"
            unless $data->{-type} =~ /; charset=/;
    };

    # MANGLE HEADERS
    # NOTE these modifications remain stored in req
    my $head = $req->header_out;

    # The most standard ones...
    $head->init_header( content_type => $data->{-type} );
    $head->init_header( location => $data->{-location} )
        if $data->{-location};
    $head->push_header( set_cookie => $req->format_cookies );
    $head->init_header( content_length => length $$content )
        unless $data->{-continue};

    if ($data->{-status} == 200 and my $ttl = $req->route->cache_ttl) {
        $head->init_header( expires => http_date( time + $ttl ) );
    };

    # END MANGLE HEADERS
};

=head2 post_setup

Currently does nothing except locking.

=cut

sub post_setup {
    my $self = shift;

    # TODO maybe compile route_rex here
    $self->{lock}++;
};

1;
