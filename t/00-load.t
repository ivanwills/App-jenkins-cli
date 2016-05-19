#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::Warnings;

BEGIN {
    use_ok( 'App::jenkins-cli' );
}

diag( "Testing App::jenkins-cli $App::jenkins-cli::VERSION, Perl $], $^X" );
done_testing();
