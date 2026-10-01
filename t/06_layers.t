use strict;
use warnings;
use utf8;
use Test::More;

use Command::Run;

# Encoding layers pushed on STDIN/STDOUT during nofork execution must
# not accumulate across executions.
# cf. https://github.com/kaz-utashiro/perl-perlio-leak-bench

sub layers { scalar(() = PerlIO::get_layers(shift)) }

my %handle = (STDOUT => \*STDOUT, STDIN => \*STDIN);

for my $raw (0, 1) {
    my %before = map { $_ => layers($handle{$_}) } keys %handle;
    my $data;
    for (1 .. 10) {
        my $result = Command::Run->new(
            command => [sub { print "j: ", scalar <STDIN> }],
            stdin   => "\x{3042}\n",
            nofork  => 1,
            raw     => $raw,
        )->run;
        $data = $result->{data};
    }
    is $data, "j: \x{3042}\n", "nofork raw=$raw: data correct after repeated runs";
    for my $h (sort keys %handle) {
        is layers($handle{$h}), $before{$h},
            "nofork raw=$raw: $h layer count unchanged";
    }
}

# The caller's own layers must come back exactly as they were -- as a
# list, not merely the same count.  This is the case that would break
# if perl ever made binmode ':encoding' idempotent (perl/perl5#10454),
# or made re-opening over a dup reset the layer stack: an
# unconditional ':pop' would then take away a layer the caller set, or
# the restore would drop it.  See perl/perl5 and perl-perlio-leak-bench.
for my $raw (0, 1) {
    binmode STDOUT, ':encoding(utf8)';
    binmode STDIN,  ':encoding(utf8)';
    my %before = map { $_ => [ PerlIO::get_layers($handle{$_}) ] } keys %handle;
    for (1 .. 3) {
        Command::Run->new(
            command => [sub { print "k: ", scalar <STDIN> }],
            stdin   => "\x{3042}\n",
            nofork  => 1,
            raw     => $raw,
        )->run;
    }
    for my $h (sort keys %handle) {
        is_deeply [ PerlIO::get_layers($handle{$h}) ], $before{$h},
            "nofork raw=$raw: $h keeps the caller's layer list";
    }
    binmode STDOUT, ':pop';
    binmode STDIN,  ':pop';
}

done_testing;
