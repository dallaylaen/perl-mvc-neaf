# NAME

MVC::Neaf [ni:f] stands for Not Even A Framework.

# OVERVIEW

Neaf offers very simple rules to build very simple applications.
For the lazy, by the lazy.

It has a lot of similarities to
[Dancer](https://metacpan.org/pod/Dancer2) and
[Kelp](https://metacpan.org/pod/Kelp).

**Model** is assumed to be a regular Perl module, and is totally out of scope.

**View** is assumed to have just one method, `render()`,
which receives a hashref and returns a pair of (content, content-type).

**Controller** is reduced to just one function, which gets a request object
and is expected to return a hashref.

A pre-defined set of dash-prefixed control keys allows to control the
framework's behaviour while all other keys are just sent to the view.

**Request** object will depend on the underlying web-server.
The same app, verbatim, should be able to run as PSGI app, CGI script, or
Apache handler.
Request knows all you need to know about the outside world.

# FOUNDATIONS

* Start out simple, then scale up.

* Enough magic already. Use simple constructs where possible.

* Zeroconf: everything can be configured, nothing needs to.

* It's not software unless you can run it.

* Trust nobody. Validate the data.

* Force UTF8 if possible. It's 21st century.

# EXAMPLE

The following would produce a greeting message depending
on the `?name=` parameter.

    use strict;
    use warnings;
    use MVC::Neaf;

    MVC::Neaf->route( "/" => sub {
		my $req = shift;

		return {
			-template => \'Hello, [% name %]!',
			-type     => 'text/plain',
			name      => $req->param( name => qr/\w+/, "Stranger" ),
		},
    });

    MVC::Neaf->run;

# FEATURES

* GET, POST, and HEAD requests; uploads; redirects; and cookies
are supported.
Not quite impressive, but it's 95% of what's needed 95% of the time.

* Template::Toolkit view out of the box;

* json/jsonp view out of the box (with sanitized callbacks);

* can serve raw content (e.g. generated images);

* can serve static files.
No need for separate web server to test your CSS/images.

* sanitized query parameters and cookies out of the box.

* Easy to develop RESTful web-services.

# NOT SO BORING FEATURES

* CLI-based debugging via `perl <your_app.pl> --help|--list|--method GET`

* Can gather performance statistics if needed;

* Delayed and/or unspecified length replies supported;

* Cookie-based sessions supported out of the box.
Session backends have to be written yet, though.

* Form validation with resubmission ability.
[Validator::LIVR](https://metacpan.org/pod/Validator::LIVR)
supported, but not requires.

* Fancy error templates supported.

# EXAMPLES

The `example/` directory has an app explaining HTTP in a nutshell,
jsonp app and some 200-line wiki engine.

# BUGS

Lots of them. Still under heavy development.

* mod\_perl handler is a mess (but it works somehow);

* no session storage mechanisms supported out of the box;

Patches and proposals are welcome.

# CONTRIBUTING TO THIS PROJECT

Please see STYLE.md for the style guide.

# ACKNOWLEDGEMENTS

Eugene Ponizovsky aka IPH had great influence over my understanding of MVC.

Ideas were shamelessly stolen from PSGI, Dancer, and Catalyst.

# LICENSE AND COPYRIGHT

Copyright 2016 Konstantin S. Uvarin aka KHEDIN

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

