package  Apache2::REST::Handler::test::user ;

use base qw/Apache2::REST::Handler/  ;

=head1 NAME

Apache2::REST::Handler::test::user - Test dummy user handler

=cut


=head2 GET

Echoes a message.

=cut

sub GET{
    my ( $self , $req , $resp ) = @_ ;
    
    $resp->data()->{'user_message'} = 'You are accessing user '.$self->userid() ;
    return Apache2::Const::HTTP_OK ;
}

=head2 isAuth

Allows GET

=cut

sub isAuth{
    my ( $self , $method , $req ) = @_ ;
    
    ## if not no auth token
    return $method eq 'GET' ;
    
}




1;
