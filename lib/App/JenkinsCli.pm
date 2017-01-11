package App::JenkinsCli;

# Created on: 2016-05-20 07:52:28
# Create by:  Ivan Wills
# $Id$
# $Revision$, $HeadURL$, $Date$
# $Revision$, $Source$, $Date$

use Moo;
use warnings;
use Carp;
use Data::Dumper qw/Dumper/;
use English qw/ -no_match_vars /;
use Jenkins::API;
use Term::ANSIColor qw/colored/;
use File::ShareDir qw/dist_dir/;
use Path::Tiny;

our $VERSION = "0.004";

has [qw/base_url api_key api_pass test/] => (
    is => 'rw',
);
has jenkins => (
    is   => 'rw',
    lazy => 1,
    builder => '_jenkins',
);
has colours => (
    is       => 'rw',
    required => 1,
);
has colour_map => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return {
            map {
                ( $_ => [ split /\s+/, $self->colours->{$_} ] )
            }
            keys %{ $self->colours }
        };
    },
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

    $self->_action(1, $query, sub {
        my $name = $_->{name};
        my $extra = '';

        if ( $_->{color} =~ s/_anime// ) {
            $extra = '*';
        }

        if ( $opt->{verbose} ) {
            eval {
                my $details = $jenkins->_json_api(['job', $_->{name}, qw/api json/], { extra_params => { depth => 1 } });
                $extra .= "\t" . localtime( ( $details->{lastBuild}{timestamp} || 0 ) / 1000 );
            };
            $name = $self->base_url . 'job/' . $name;
        }

        # map "jenkins" colours to real colours
        my $color = $self->colour_map->{$_->{color}} || [$_->{color}];

        print colored($color, $name), " $extra\n";
    });

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
    my ($self, $opt, @jobs) = @_;

    _error("Job name required for deleting jobs!\n") if !@jobs;

    for my $job (@jobs) {
        my $result = $self->jenkins->delete_project($job);
        print $result ? "Deleted $job\n" : "Errored deleting $job\n";
    }

    return;
}

sub status {
    my ($self, $opt, $job, @extra) = @_;
    my $jenkins = $self->jenkins();

    _error("Job name required to show job status!\n") if !$job;

    my $result = $jenkins->_json_api(['job', $job, 'api', 'json'], { extra_params => { depth => 1 } });

    my $color = $self->colour_map->{$result->{color}} || [$result->{color}];
    print colored($color, $job), "\n";

    if ($opt->verbose) {
        for my $build (@{ $result->{builds} }) {
            print "$build->{displayName}\t$build->{result}\t";
            if ( $opt->verbose > 1 ) {
                for my $action (@{ $build->{actions} }) {
                    if ( $action->{lastBuiltRevision} ) {
                        print $action->{lastBuiltRevision}{SHA1};
                    }
                }
            }
            print "\n";
        }
    }

    return;
}

sub conf { shift->config(@_) }
sub config {
    my ($self, $opt, $job, @extra) = @_;
    my $jenkins = $self->jenkins();

    _error("Must provide job name to get it's configuration!\n") if !$job;

    print $jenkins->project_config($job);

    return;
}

sub queue {
    my ($self, $opt, $job, @extra) = @_;
    my $jenkins = $self->jenkins();

    my $queue = $jenkins->build_queue();

    if ( @{ $queue->{items} } ) {
        for my $item (@{ $queue->{items} }) {
            print $item;
        }
    }
    else {
        print "The queue is empty\n";
    }

    return;
}

sub create {
    my ($self, $opt, $job, $config, @extra) = @_;
    my $jenkins = $self->jenkins();

    my $success = $jenkins->create_job($job, $config);

    print $success ? "Created $job\n" : "Error creating $job\n";

    return;
}

sub load {
    my ($self, $opt, $job, $config, @extra) = @_;
    my $jenkins = $self->jenkins();

    print Dumper $jenkins->load_statistics();

    return;
}

sub watch {
    my ($self, $opt, @jobs) = @_;
    my $jenkins = $self->jenkins();

    my $query = join '|', @jobs;
    my $first = 1;

    while (1) {
        print "\n" if !$first;
        $first = 0;

        $self->_action(1, $query, sub {
            my $name = $_->{name};
            my $extra = '';

            if ( $_->{color} =~ s/_anime// ) {
                $extra = '*';
            }

            # map "jenkins" colours to real colours
            my $color = $self->colour_map->{$_->{color}} || [$_->{color}];

            print colored($color, $name), " $extra\n";
        });
        sleep 10;
    }

    return;
}

sub enable {
    my ($self, $opt, $query) = @_;

    my $xsl = path(dist_dir('App-JenkinsCli'), 'enable.xsl');
    $self->_xslt_actions($opt, $query, $xsl);

    return;
}

sub disable {
    my ($self, $opt, $query) = @_;

    my $xsl = path(dist_dir('App-JenkinsCli'), 'disable.xsl');
    $self->_xslt_actions($opt, $query, $xsl);

    return;
}

sub change {
    my ($self, $opt, $query, $xsl) = @_;

    $self->_xslt_actions($opt, $query, $xsl);

    return;
}

sub _xslt_actions {
    my ($self, $opt, $query, $xsl) = @_;
    require XML::LibXML;
    require XML::LibXSLT;

    my $xslt = XML::LibXSLT->new();
    my $style_doc = XML::LibXML->load_xml(location => $xsl);
    my $stylesheet = $xslt->parse_stylesheet($style_doc);

    my $jenkins = $self->jenkins();

    my $data = $jenkins->_json_api([qw/api json/], { extra_params => { depth => 0 } });

    my %found;
    $self->_action(0, $query, sub {

        my $config = $jenkins->project_config($_->{name});
        my $dom = XML::LibXML->load_xml(string => $config);

        my $results = $stylesheet->transform($dom);
        my $output  = $stylesheet->output_as_bytes($results);

        warn "Updating $_->{name}\n" if $opt->{verbose};
        if ($opt->{test}) {
            print "$output\n";
        }
        else {
            my $success = $jenkins->set_project_config($_->{name}, $output);
            if (!$success) {
                warn "Error in updating $_->{name}\n";
                last;
            }
        }
    });

    return;
}

sub _action {
    my ($self, $depth, $query, $action) = @_;
    my $jenkins = $self->jenkins();

    my $data = $jenkins->_json_api([qw/api json/], { extra_params => { depth => $depth } });

    for my $job (sort @{ $data->{jobs} }) {
        next if $query && $job->{name} !~ /$query/;
        local $_ = $job;

        $action->();
    }

    return;
}


1;

__END__

=head1 NAME

App::JenkinsCli - Command line tool for interacting with Jenkins

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

Start C<$job>

=head2 C<delete ($opt, $job)>

Delete C<$job>

=head2 C<status ($opt, $job)>

Status of C<$job>

=head2 C<enable ($opt, $job)>

enable C<$job>

=head2 C<disable ($opt, $job)>

disable C<$job>

=head2 C<conf ($opt, $job)>

=head2 C<config ($opt, $job)>

Show the config of C<$job>

=head2 C<queue ($opt)>

Show the queue of running jobs

=head2 C<create ($opt, $job)>

Create a new Jenkins job

=head2 C<load ($opt)>

Show the load stats for the server

=head2 C<change ($opt, $query, $xsl)>

Run the XSLT file (C<$xsl>) over each job matching C<$query> to generate a
new config which is then sent back to Jenkins.

=head1 ATTRIBUTES

=over 4

=item base_url

The base URL of Jenkins

=item api_key

The username to access jenkins by

=item api_pass

The password to access jenkins by

=item test

Flag to not actually perform changes

=item jenkins

Internal L<Jenkins::API> object

=item colours

Mapping of Jenkins states to L<Term::ANSIColor>s

=back

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Ivan Wills (ivan.wills@gmail.com).

Patches are welcome.

=head1 ALSO SEE

Inspired by https://github.com/Netflix-Skunkworks/jenkins-cli

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
