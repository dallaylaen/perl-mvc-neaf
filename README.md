# NAME

MVC::Neaf stands for Not Even A Framework.

# OVERVIEW

Neaf offers very simple rules to build very simple applications.
For the lazy, by the lazy.

**Model** is assumed to be a regular Perl module, and is totally out of scope.

**View** is assumed to have just one method, `show()`,
which receives a hashref and returns rendered context as scalar.

**Controller** is reduced to just one function, which gets a request object
and is expected to return a hashref.

A pre-defined set of dash-prefixed control keys allows to control the
framework's behaviour while all other keys are just sent to the view.

**Request** object will depend on the underlying web-server.
The same app, verbatim, should be able to run as PSGI app, CGI script, or
Apache handler.

# FOUNDATIONS

* Start out simple, then scale up.

* Enough magic already.

* Zeroconf: everything can be configured, nothing needs to.

* It's not software unless you can run it.

# EXAMPLE

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

* GET, POST requests, uploads, redirects, and cookies are supported

* Template::Toolkit view out of the box

* json/jsonp view out of the box

* can serve raw content (e.g. generated images)

* sanitized query parameters out of the box

# BUGS

Lots of them. Still in alpha stage.

Patches and proposals are welcome.

# ACKNOWLEDGEMENTS

Eugene Ponizovsky aka IPH had great influence over my understanding of MVC.

Ideas were shamelessly stolen from PSGI, Dancer, and Catalyst.

# LICENSE AND COPYRIGHT

Copyright 2016 Konstantin S. Uvarin aka KHEDIN

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

