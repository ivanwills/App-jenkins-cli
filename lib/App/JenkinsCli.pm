package App::JenkinsCli;

# Created on: 2016-05-20 07:52:28
# Create by:  Ivan Wills
# $Id$
# $Revision$, $HeadURL$, $Date$
# $Revision$, $Source$, $Date$

use Moo;
use warnings;
use version;
use Carp;
use Scalar::Util;
use List::Util;
#use List::MoreUtils;
use Data::Dumper qw/Dumper/;
use English qw/ -no_match_vars /;
use Jenkins::API;
use Term::ANSIColor qw/colored/;

our $VERSION = version->new('0.0.1');

has [qw/base_url api_key api_pass test/] => (
    is => 'rw',
);
has jenkins => (
    is   => 'rw',
    lazy => 1,
    builder => '_jenkins',
);

sub _jenkins {
    my ($self) = @_;

    return Jenkins::API->new({
        base_url => $self->base_url,
        api_key  => $self->api_key,
        api_pass => $self->api_pass,
    });
};

sub ls { shift->list(@_) }
sub list {
    my ($self, $opt, $query) = @_;
    my $jenkins = $self->jenkins();

    my $data = $jenkins->_json_api([qw/api json/], { extra_params => { depth => 1 } });
    my %colour_map = map {
            ( $_ => [ split /\s+/, $opt->colors->{$_} ] )
        }
        keys %{ $opt->colors };

    for my $job (sort @{ $data->{jobs} }) {
        next if $query && $job->{name} !~ /$query/;
        my $name = $job->{name};
        my $extra = '';

        if ( $job->{color} =~ s/_anime// ) {
            $extra = '*';
        }

        # map "jenkins" colours to real colours
        my $color = $colour_map{$job->{color}} || [$job->{color}];

        print colored($color, $name), " $extra\n";
    }

    return;
}

sub start {
    my ($self, $opt, $job, @extra) = @_;
    my $jenkins = $self->jenkins();

    _error("Must start build with job name!\n") if !$job;

    my $result = $jenkins->_json_api(['job', $job, 'api', 'json']);
    if ( ! $result->{buildable} ) {
        warn "Job is not buildable!\n";
        return 1;
    }
    if ( $result->{inQueue} && ! $opt->force ) {
        warn $result->{queueItem}{why} . "\n";
        warn "View at $result->{url}\n";
        return 0;
    }
    die "Not yet!\n";

    $jenkins->trigger_build($job);

    sleep 1;

    $result = $jenkins->_json_api(['job', $job, 'api', 'json']);
    print "View at $result->{url}\n";
    warn Dumper $result;

    return;
}

sub delete {
    my ($self, $opt, $job, @extra) = @_;

    _error("Must start build with job name!\n") if !$job;

    $self->jenkins->delete_project($job);

    return;
}

sub conf { shift->config(@_) }
sub config {
    my ($self, $opt, $job, @extra) = @_;
    my $jenkins = $self->jenkins();

    _error("Must start build with job name!\n") if !$job;

    my $result = $jenkins->_json_api(['job', $job, 'api', 'json']);

    print "$job\n";

    return;
}

1;

__END__

=head1 NAME

App::JenkinsCli - Comamndline tool for interacting with Jenkins

=head1 VERSION

This documentation refers to App::JenkinsCli version 0.0.1

=head1 SYNOPSIS

   use App::JenkinsCli;

   # Brief but working code example(s) here showing the most common usage(s)
   # This section will be as far as many users bother reading, so make it as
   # educational and exemplary as possible.


=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 C<ls ($opt, $query)>

=head2 C<list ($opt, $query)>

List all jobs, optionally filtering with C<$query>

=head2 C<start ($opt, $job)>

Start C<$jpb>

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Ivan Wills (ivan.wills@gmail.com).

Patches are welcome.

=head1 AUTHOR

Ivan Wills - (ivan.wills@gmail.com)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2016 Ivan Wills (14 Mullion Close, Hornsby Heights, NSW Australia 2077).
All rights reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.  This program is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
