package Apache2::REST::Request ;
use Apache2::Request ;

use base qw(Apache2::Request);

use Encode ;

=head2 NAME

Apache2::REST::Request - Apache2::Request subclass.

=cut

=head2 new

See L<Apache2::Request>

=cut

sub new {
    my($class, @args) = @_;
    my $self = {
        r => Apache2::Request->new(@args) ,
        'paramEncoding' => 'UTF-8' ,
    };
    return bless $self,  $class;
}

=head2 param

See L<Apache2::Request::param> .

This decodes the param according to $this->paramEncoding

=cut

sub param{
    my ( $self , @args ) = @_ ;
    if ( wantarray ){
        my @ret = $self->{r}->param(@args) ;
        return map{ Encode::decode($self->paramEncoding() , $_ ) } @ret  ;
    }
    my $ret = $self->{r}->param(@args) ;
    return Encode::decode($self->paramEncoding() , $ret );
}

=head2 paramEncoding

Gets/Set the paramEncoding of this Request

=cut

sub paramEncoding{
    my ( $self , $v ) = @_ ;
    if ( $v ){ $self->{'paramEncoding'} = $v ;}
    return $self->{'paramEncoding'} ;
}

1;
