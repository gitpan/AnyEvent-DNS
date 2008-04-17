package AnyEvent::DNS;

use warnings;
use strict;
use AnyEvent;
use Net::DNS;

=head1 NAME

AnyEvent::DNS - Helper for non-blocking DNS queries with Net::DNS

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use AnyEvent::DNS;

    my $d = AnyEvent::DNS->new (
       timeout  => 10,
       resolver => [
          nameservers => [qw/127.0.0.1/]
       ]
    );

    $d->send (sub {
       my ($pkt, $err, $errdesc) = @_;
       if ($err) {
          warn "Couldn't lookup: $err/$errdesc\n";
       } else {
          print "lookup response: ".$pkt->string."\n";
       }
    }, 'www.google.de', 'A');

=head1 DESCRIPTION

This module is a thin wrapper to make non-blocking requests with L<Net::DNS>.
The main object, of the class L<AnyEvent::DNS>, is a wrapper object around
a L<Net::DNS::Resolver>. And you are able to send non-blocking lookup
queries, specify a timeout and assign a callback to process the results.

=head1 METHODS

=over 4

=item B<new (%args)>

This is the constructor for L<AnyEvent::DNS>, C<%args> can
have following keys:

=over 4

=item * C<timeout>

The timeout in seconds for a lookup requests sent via the C<send> method.
If not set, no timeout will be installed.

=item * C<resolver>

This key should have an array reference as value, which contains the
arguments passed to the L<Net::DNS::Resolver> constructor.

=back

=cut

sub new {
   my $this  = shift;
   my $class = ref($this) || $this;
   my $self  = { @_ };
   bless $self, $class;
   $self->{res} = Net::DNS::Resolver->new (@{$self->{resolver}});

   return $self
}

=item B<resolver>

Returns the internal L<Net::DNS::Resolver> object used
for queries.

=cut

sub resolver { $_[0]->{res} }

=item B<send ($cb, @bgsend_args)>

This method will send a query via the C<bgsend> method of L<Net::DNS::Resolver>
and take care of installing the watcher and timeouts and error reporting.

The callback C<$cb> will have following arguments:

   my ($pkt, $err, $errdesc) = @_;

Where C<$pkt> is the L<Net::DNS::Packet> object we got as response to the 
query. C<$err> is one of: C<'send failed'>, C<'timeout'>, C<'lookup failed'>,
indicating the general cause of the error. C<$errdesc> will contain the error
description as returned by the C<errorstring> method of L<Net::DNS::Resolver>.

If C<$err> is not defined the query was successful and C<$pkt> is set to
the response object.

See also L<Net::DNS::Packet> for more details about C<$pkt>.

=cut

sub send {
   my ($self, $cb, @args) = @_;
   my $id = ++$self->{id};
   my $sock = $self->{res}->bgsend (@args);
   unless ($sock) {
      $cb->(undef, 'send failed', $self->{res}->errorstring);
      return;
   }

   if ($self->{timeout}) {
      $self->{tout}->{$id} =
         AnyEvent->timer (after => $self->{timeout}, cb => sub {
            $cb->(undef, 'timeout', "lookup timeouted after $self->{timeout} seconds");
            delete $self->{wat}->{$id};
            delete $self->{tout}->{$id};
         });
   }

   $self->{wat}->{$id} =
      AnyEvent->io (poll => 'r', fh => $sock, cb => sub {
         delete $self->{tout}->{$id};
         delete $self->{wat}->{$id};

         my $p = $self->{res}->bgread ($sock);
         if ($p) {
            $cb->($p);
         } else {
            $cb->(undef, 'lookup failed', $self->{res}->errorstring);
         }
      });
}

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-anyevent-dns at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=AnyEvent-DNS>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AnyEvent::DNS

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/AnyEvent-DNS>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/AnyEvent-DNS>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=AnyEvent-DNS>

=item * Search CPAN

L<http://search.cpan.org/dist/AnyEvent-DNS>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2008 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of AnyEvent::DNS
