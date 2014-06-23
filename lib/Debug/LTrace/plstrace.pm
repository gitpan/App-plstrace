package Debug::LTrace::plstrace;

use 5.010001;
use warnings;
use strict;

use Devel::Symdump;
use Hook::LexWrap;
use SHARYANTO::String::Util qw/qqquote/;
use Time::HiRes qw/time/;

our $VERSION = '0.01'; # VERSION
our $DATE = '2014-06-23'; # DATE

my %import_params;
my @permanent_objects;

sub import {
    shift;
    $import_params{ ${ \scalar caller } } = [@_];
}

# External constructor
sub new {
    return unless defined wantarray;
    my $self = shift->_new( scalar caller, @_ );
    $self;
}

# Internal constructor
sub _new {
    my ( $class, $trace_package, @params ) = @_;
    my $self;

    # Parse input parameters
    foreach my $p (@params) {
        if ($p =~ /^(-\w+)(?:=(.*))?/) {
            # option
            if ($1 eq '-t') {
                # additive options
                $self->{$1}++;
            } else {
                $self->{$1} = defined($2) ? $2 : 1;
            }
            next;
        }

        #process sub
        $p = $trace_package . '::' . $p unless $p =~ m/::/;
        push @{ $self->{subs} }, (
            $p =~ /^(.+)::\*(\*?)$/
            ? Devel::Symdump ->${ \( $2 ? 'rnew' : 'new' ) }($1)->functions()
            : $p
            );
    }

    bless $self, $class;
    $self->_start_trace();
    #use DD; dd $self;
    $self;
}

# Bind all hooks for tracing
sub _start_trace {
    my ($self) = @_;
    return unless ref $self;

    $self->{wrappers} = {};
    my @messages;

    foreach my $sub ( @{ $self->{subs} } ) {
        next if $self->{wrappers}{$sub};    # Skip already wrapped

        $self->{wrappers}{$sub} = Hook::LexWrap::wrap(
            $sub,
            pre => sub {
                pop();
                #my ( $pkg, $file, $line ) = caller(0);
                #my ($caller_sub) = ( caller(1) )[3];

                my $args = join(", ", map {$self->_esc($_)} @_);
                my $start_time = time();
                my $msg = "> $sub($args)";
                $msg = $self->_fmttime($start_time) . " $msg" if $self->{-show_time};
                warn "$msg\n";
                unshift @messages, [ "$sub($args)", $start_time ];
            },
            post => sub {
                my $end_time = time();
                my $wantarray = ( caller(0) )[5];
                my $call_data = shift(@messages);

                my $res = defined($wantarray) ? " = ".$self->_esc($wantarray ? pop : [pop]) : '';
                my $msg = "< $call_data->[0]$res";
                $msg = $self->_fmttime($call_data->[1]) . " $msg" if $self->{-show_time};
                $msg .= sprintf(" <%.6f>", $end_time - $call_data->[1] ) if $self->{-show_spent_time};
                warn "$msg\n";
            } );
    }

    # defaults
    $self->{-strsize} //= 32;

    $self;
}

sub _esc {
    my ($self, $data) = @_;
    if (!defined($data)) {
        "undef";
    } elsif (ref $data) {
        "$data";
    } elsif (length($data) > $self->{-strsize}) {
        qqquote(substr($data,0,$self->{-strsize}))."...";
    } else {
        qqquote($data);
    }
}

sub _fmttime {
    my ($self, $time) = @_;

    my @lt = localtime($time);
    if ($self->{-show_time} > 10) {
        sprintf "%010.6f", $time - $self->{-start_time};
    } elsif ($self->{-show_time} > 2) {
        sprintf "%.6f", $time;
    } elsif ($self->{-show_time} > 1) {
        my $frac = ($time - int($time)) * 1000_000;
        sprintf "%02d:%02d:%02d.%06d", $lt[2], $lt[1], $lt[0], $frac;
    } else {
        sprintf "%02d:%02d:%02d", $lt[2], $lt[1], $lt[0];
    }
}

INIT {
    while ( my ( $package, $params ) = each %import_params ) {
        push @permanent_objects, __PACKAGE__->_new( $package, @$params ) if @$params;
    }
}

1;
# ABSTRACT: Implement plstrace (internal module)

__END__

=pod

=encoding UTF-8

=head1 NAME

Debug::LTrace::plstrace - Implement plstrace (internal module)

=head1 VERSION

This document describes version 0.01 of Debug::LTrace::plstrace (from Perl distribution App-plstrace), released on 2014-06-23.

=for Pod::Coverage ^(.+)$

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/App-plstrace>.

=head1 SOURCE

Source repository is at L<https://github.com/sharyanto/perl-App-plstrace>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-plstrace>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
