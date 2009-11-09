package Apache2::REST;

use warnings;
use strict;

use APR::Table ();

use Apache2::Request ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Response ();
use Apache2::RequestUtil ();

use Apache2::REST::Handler ;
use Apache2::REST::Response ;
use Apache2::REST::Request ;

use Data::Dumper ;

our $VERSION = '0.01';

=head1 NAME

Apache2::REST - Micro framework for REST API implementation under apache2/mod_perl2/apreq2

=head1 VERSION

Version 0.01

=head1 QUICK TUTORIAL

=head2 1. Implement a Apache2::REST::Handler

This module will handle the root resource of your REST API.

   package MyApp::REST::API ;
   use warnings ;
   use strict ;
    
   # Implement the GET HTTP method.
   sub GET{
       my ($self, $request, $response) = @_ ;
       $response->data()->{'api_mess'} = 'Hello, this is MyApp REST API' ;
       return Apache2::Const::HTTP_OK ;
   }
   # Authorize the GET method.
   sub isAuth{
      my ($self, $method, $req) = @ _; 
      return $method eq 'GET';
   }
   1 ;

=head2 2. Configure apache2

Apache2::REST is a mod_perl2 handler.

In your apache configuration:

   # Make sure you
   LoadModule apreq_module modules/mod_apreq2.so
   LoadModule perl_module modules/mod_perl.so

   # Load Apache2::REST
   PerlModule Apache2::REST 
   # Let Apache2::REST handle the /
   # and set the root handler of the API
   <Location />
      SetHandler perl-script
      PerlSetVar Apache2RESTHandlerRootClass "MyApp::REST::API"
      PerlResponseHandler  Apache2::REST
   </Location>

See L<Apache2::REST::Handler> for  about how to implement a handler.

Then access C<http://yourhost/>. You should see your greeting message from your MyApp::REST::API handler.

See L<Apache2::REST::Overview> for more details about how it works.

=head1 CONFIGURATION

This mod_perl2 handler supports the following configurations (Via PerlSetVar):

=head2  Supported variables

=head3 Apache2RESTAPIBase

The base of the API application. If ommitted, C</> is assumed. Use this to implement your API
as a sub directory of your server.

Example:

    <Location /api/>
      ...
      PerlSetVar Apache2RESTAPIBase "/api/" ;
    </Location>

=head3 Apache2RESTHandlerRootClass  

root class of your API implementation. If ommitted, this module will feature the demo implementation
Accessible at C<http://localhost/test/> (providing you installed this at the root of the server)

Example:
    
    PerlSetVar Apache2RESTHandlerRootClass "MyApp::REST::API"

=head3 Apache2RESTParamEncoding

Encoding of the parameters sent to this API. Default is UTF-8.
Must be a value compatible with L<Encode>

Example:
    
    PerlSetVar Apache2RESTParamEncoding "UTF-8"

=head3 Apache2RESTAppAuth

Specifies the module to use for application authentication.
See L<Apache2::REST::AppAuth> for API.

Example:
    
    PerlSetVar Apache2RESTAppAuth "MyApp::REST::AppAuth"

=head3 Apache2RESTWriterSelectMethod

Use this to specify the writer selection method. If not specifid the writer is selected using the C<fmt> parameter.

Valid values are:

    param (the default) - With this method, the writer is selected from the fmt parameter. For instance '?fmt=json'
    extension - With this method, the writer is selected from the url extension. For instance : '/test.json'

Example:
    
    When using 'param' (default) ask for json format like this: http://localhost/test/?fmt=json
    When using 'extension' : http://localhost/test.json
    
=head3 Apache2RESTWriterDefault

Sets the default writer. If ommitted, the default is C<xml>. Available writers are C<xml>, C<json>, C<yaml>, C<perl>

=head2 command line REST client

This module comes with a commandline REST client to test your API:

   $ restclient
   usage: restclient -r <resource URL> [ -m <http method> ] [ -p <http paramstring> ] [ -h <http headers(param syntax)> ]

It is written as a thin layer on top of L<REST::Client>

=cut

sub handler{
    my $r = shift ;
    
    my $req = Apache2::REST::Request->new($r);
    my $paramEncoding = $r->dir_config('Apache2RESTParamEncoding') || '';
    if ( $paramEncoding  ){
        $req->paramEncoding($paramEncoding) ;
    }
    ## Response object
    my $resp = Apache2::REST::Response->new() ;
    my $retCode = undef ;

    my $uri = $req->uri() ;
    if ( my $base = $r->dir_config('Apache2RESTAPIBase')){
        $uri =~ s/^\Q$base\E// ;
    }
    
    my $wtMethod = $r->dir_config('Apache2RESTWriterSelectMethod') || 'param' ;
    my $format = 'xml' ;
    if ( $wtMethod eq 'param' ){ $format = $req->param('fmt') || 'xml' ; }
    if ( $wtMethod eq 'extension'){ ( $format ) = ( $uri =~ /\.(\w+)$/ ) ; $uri =~ s/\.\w+$// ;  $format ||= 'xml' ;}

    
    ## Application level authorisation part
    my $appAuth = $r->dir_config('Apache2RESTAppAuth') || '' ;
    if ( $appAuth ){
        eval "require $appAuth;";
        if ( $@ ){
            die "Cannot find AppAuth class $appAuth (from conf Apache2RESTAppAuth)\n" ;
        }
        my $appAuth = $appAuth->new() ;
        $appAuth->init($req) ;
        ## The header
        ## Ok the header is there
        ## Authorize will set message and return true (authorize) or false.
        my $isAuth = $appAuth->authorize($req , $resp ) ;
        unless( $isAuth ){
            $retCode = Apache2::Const::HTTP_UNAUTHORIZED ;
            goto output ;
        }
    }
    
    
    my $handlerRootClass = $r->dir_config('Apache2RESTHandlerRootClass') || 'Apache2::REST::Handler' ;
    
    eval "require $handlerRootClass;";
    if ( $@ ){
        die "Cannot find root class $handlerRootClass (from conf Apache2RESTHandlerRootClass): $@\n" ;
    }
    
    my $topHandler = $handlerRootClass->new() ;
    
    my @stack = split('\/+' , $uri);
    # Protect against empty fragments.
    @stack = grep { length($_)>0 } @stack ;
    
    
    
    $retCode = $topHandler->handle(\@stack , $req , $resp ) ;
    
  output:
    ## Load the writer for the given format
    ## Default is xml
    my $wClass = 'Apache2::REST::Writer::'.$format ;
    eval "require $wClass;" ;
    if ( $@ ){
        ## Silently fail to default writer
        require Apache2::REST::Writer::xml ;
        $wClass = 'Apache2::REST::Writer::xml' ;
    }
    my $writer = $wClass->new() ;
    
    
    $r->content_type($writer->mimeType()) ;
    
    my $respTxt = $writer->asBytes($resp) ;
    if ( $retCode && ( $retCode  != Apache2::Const::HTTP_OK ) ){
        $r->status($retCode);
    }
    print $respTxt  ;
    return  Apache2::Const::OK ;
    
}


=head1 AUTHOR

Jerome Eteve, C<< <jerome at eteve.net> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-apache2-rest at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Apache2-REST>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Apache2::REST


=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Apache2-REST>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Apache2-REST>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Apache2-REST>

=item * Search CPAN

L<http://search.cpan.org/dist/Apache2-REST>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Careerjet Ltd, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Apache2::REST
