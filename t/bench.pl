#!/usr/bin/env perl

=head1 NAME

bench.pl - Benchmark fork vs nofork performance in Command::Run

=head1 SYNOPSIS

    perl t/bench.pl              # default: 3 seconds per test
    perl t/bench.pl 1            # 1 second per test (quick)
    perl t/bench.pl 5            # 5 seconds per test (precise)

=head1 DESCRIPTION

Compares fork and nofork execution paths for code references with
varying data sizes. Uses wall clock time for measurement to avoid
issues with fork's high sys time inflating CPU-based timers.

Output-only tests measure the overhead of fork/pipe vs dup/tmpfile.
Stdin tests add the cost of writing input data to a tmpfile.

=cut

use strict;
use warnings;
use lib "lib";
use Command::Run;
use Benchmark qw(cmpthese timediff);
use Time::HiRes qw(time);

$| = 1;

my $duration = shift // 3;  # wall clock seconds per test

# Benchmark::countit uses CPU time, which undercounts when fork's
# sys time dominates.  This version uses wall clock time instead.
sub countit_wall {
    my ($seconds, $code) = @_;
    my $end = time() + $seconds;
    my $t0 = Benchmark->new;
    my $count = 0;
    while (time() < $end) {
        $code->();
        $count++;
    }
    my $td = timediff(Benchmark->new, $t0);
    $td->[5] = $count;
    $td;
}

my @tests;

# output only: 100B, 1KB, 10KB, 100KB
for my $size (100, 1000, 10000, 100000) {
    my $data = "x" x $size;
    my $r = Command::Run->new(command => sub { print $data });
    $r->run(nofork => 1);  # warm up
    my $label = $size >= 1000 ? ($size/1000)."KB" : $size."B";
    push @tests, [ "out $label",
        fork   => sub { $r->run },
        nofork => sub { $r->run(nofork => 1) },
    ];
}

# with stdin: 100B, 1KB, 10KB
for my $size (100, 1000, 10000) {
    my $input = "x" x $size;
    my $r = Command::Run->new(
        command => sub { my $in = do { local $/; <STDIN> }; print $in },
    );
    $r->run(nofork => 1, stdin => $input);  # warm up
    my $label = $size >= 1000 ? ($size/1000)."KB" : $size."B";
    push @tests, [ "in+out $label",
        fork   => sub { $r->run(stdin => $input) },
        nofork => sub { $r->run(nofork => 1, stdin => $input) },
    ];
}

my $total = scalar @tests;

for my $i (0 .. $#tests) {
    my ($label, %subs) = @{$tests[$i]};
    printf "[%d/%d] %s: ", $i + 1, $total, $label;
    my %result;
    for my $name (sort keys %subs) {
        print "$name..";
        $result{$name} = countit_wall($duration, $subs{$name});
        print "done ";
    }
    print "\n";
    cmpthese(\%result);
    print "\n";
}
