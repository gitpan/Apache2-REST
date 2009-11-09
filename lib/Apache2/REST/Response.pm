package Apache2::REST::Response ;

use strict ;
use warnings ;

use base qw/Class::AutoAccess/ ;

=head1 NAME

Apache2::REST::Response - Container for an API Response.

=head2 SYNOPSIS

 ... 
 $resp->status(Apache2::Const::HTTP_OK) ;
 $resp->message('Everything went smootly') ;
 $resp->data()->{'item'} = 'This is the returned item' ;
 ...

=cut

=head2 new

Builds a new one.

=cut

sub new{
    my ( $class ) = @_ ;
    
    my $self = {
        'status' => Apache2::Const::HTTP_OK ,
        'message' => '' ,
        'data' => {},
    };
    return bless $self , $class ;
}

=head2 status

Get/Sets the HTTP status of this response

=cut

=head2 message

Get/Sets a more explicit message related to the status

=cut

=head2 data

Hash of the actual data returned by the handler (see L<Apache2::REST::Handler> ).


=cut

1;
