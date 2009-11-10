package Apache2::REST::Handler::bin ;
use strict ;

use base qw/Apache2::REST::Handler/ ;

=head1 NAME

Apache2::REST::Handler::bin - Proof of concept for binary output.

=cut


=head2 GET

Ouputs a small gif

=cut

sub GET{
    my ( $self , $req , $resp ) = @_ ;
    
    $req->requestedFormat('bin') ;
    $resp->binMimeType('image/gif') ;
    
    my $bin = "GIF89a" ;
    $bin .= pack("CC",01,00);
    $bin .= pack("CCCCCCCC",1,0,128,0,0,255,255,255);
    $bin .= pack("CCCCCCCC",0,0,0,33,249,4,1,0);
    $bin .= pack("CCCCCCCC",0,0,0,44,0,0,0,0);
    $bin .= pack("CCCCCCCC",1,0,1,0,0,2,2,68);
    $bin .= pack("CCC",1,0,59);
    $resp->bin($bin) ;
    
    return Apache2::Const::HTTP_OK ;    
}

=head2 isAuth

Allows GET

=cut

sub isAuth{
    my ( $self , $met , $req ) = @_ ;
    return $met eq 'GET' ;
}



1;
