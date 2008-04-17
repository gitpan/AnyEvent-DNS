#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'AnyEvent::DNS' );
}

diag( "Testing AnyEvent::DNS $AnyEvent::DNS::VERSION, Perl $], $^X" );
