use strict;
use warnings;
use utf8;
use Test::More;

use Command::Run;

# basic nofork code reference
my $result = Command::Run->new(
    command => [sub { print "from code" }],
    nofork  => 1,
)->run;
is $result->{data}, "from code", 'nofork: code reference execution';
is $result->{result}, 0, 'nofork: exit status 0';
ok !defined $result->{pid}, 'nofork: no pid returned';

# code reference with arguments via @ARGV
$result = Command::Run->new(
    command => [sub { print "@ARGV" }, 'a', 'b', 'c'],
    nofork  => 1,
)->run;
is $result->{data}, "a b c", 'nofork: @ARGV';

# code reference with arguments via @_
$result = Command::Run->new(
    command => [sub { print "@_" }, 'x', 'y', 'z'],
    nofork  => 1,
)->run;
is $result->{data}, "x y z", 'nofork: @_';

# code reference with stdin
$result = Command::Run->new(
    command => [sub { print scalar <STDIN> }],
    stdin   => "stdin data",
    nofork  => 1,
)->run;
is $result->{data}, "stdin data", 'nofork: stdin';

# stderr redirect
$result = Command::Run->new(
    command => [sub { print "out"; print STDERR "err" }],
    stderr  => 'redirect',
    nofork  => 1,
)->run;
like $result->{data}, qr/out/, 'nofork: stdout with redirect';
like $result->{data}, qr/err/, 'nofork: stderr merged';

# stderr capture
$result = Command::Run->new(
    command => [sub { print "out"; print STDERR "err" }],
    stderr  => 'capture',
    nofork  => 1,
)->run;
is $result->{data}, "out", 'nofork: stdout with capture';
is $result->{error}, "err", 'nofork: stderr captured';

# stderr pass-through (default)
$result = Command::Run->new(
    command => [sub { print "out" }],
    nofork  => 1,
)->run;
is $result->{data}, "out", 'nofork: stdout default';
is $result->{error}, '', 'nofork: stderr empty by default';

# die handling
$result = Command::Run->new(
    command => [sub { die "test error\n" }],
    nofork  => 1,
)->run;
isnt $result->{result}, 0, 'nofork: die gives non-zero result';

# die with partial output
$result = Command::Run->new(
    command => [sub { print "before"; die "oops\n" }],
    nofork  => 1,
)->run;
is $result->{data}, "before", 'nofork: output captured before die';
isnt $result->{result}, 0, 'nofork: die result non-zero';

# stdout/stderr scalar references
my ($out, $err);
Command::Run->new(
    command => [sub { print "data"; print STDERR "error" }],
    nofork  => 1,
    stdout  => \$out,
    stderr  => \$err,
)->run;
is $out, "data", 'nofork: stdout reference';
is $err, "error", 'nofork: stderr reference';

# result and error methods
my $cmd = Command::Run->new(
    command => [sub { print "data"; print STDERR "error" }],
    stderr  => 'capture',
    nofork  => 1,
);
$cmd->run;
is $cmd->result->{data}, "data", 'nofork: result method';
is $cmd->error, "error", 'nofork: error method';
is $cmd->data, "data", 'nofork: data method';

# @ARGV and $0 are restored after execution
my @save_argv = @ARGV;
my $save_0 = $0;
Command::Run->new(
    command => [sub { }, 'test_arg'],
    nofork  => 1,
)->run;
is_deeply \@ARGV, \@save_argv, 'nofork: @ARGV restored';
is $0, $save_0, 'nofork: $0 restored';

# nofork via run() temporary parameter
$cmd = Command::Run->new(command => [sub { print "hello" }]);
$result = $cmd->run(nofork => 1);
is $result->{data}, "hello", 'nofork: via run() temporary parameter';

# stdin via run() temporary parameter
$result = Command::Run->new(
    command => [sub { print scalar <STDIN> }],
    nofork  => 1,
)->run(stdin => "temp stdin");
is $result->{data}, "temp stdin", 'nofork: stdin via run() temporary parameter';

# stdin via run() temporary parameter (fork path)
$result = Command::Run->new(
    command => [sub { print scalar <STDIN> }],
)->run(stdin => "fork temp stdin");
is $result->{data}, "fork temp stdin", 'fork: stdin via run() temporary parameter';

# nofork via with()
$result = Command::Run->new
    ->command(sub { print "chained" })
    ->with(nofork => 1)
    ->run;
is $result->{data}, "chained", 'nofork: via with()';

# nofork ignored for external commands (falls through to fork)
$result = Command::Run->new(
    command => ['echo', 'external'],
    nofork  => 1,
)->run;
is $result->{data}, "external\n", 'nofork: ignored for external commands';
ok defined $result->{pid}, 'nofork: external command has pid';

# UTF-8 handling
$result = Command::Run->new(
    command => [sub { binmode STDOUT, ':utf8'; print "日本語\n" }],
    nofork  => 1,
)->run;
is $result->{data}, "日本語\n", 'nofork: UTF-8 output';

# path method works with nofork
$cmd = Command::Run->new(
    command => [sub { print "path test" }],
    nofork  => 1,
);
$cmd->update;
like $cmd->path, qr{^/(dev/fd|proc/self/fd)/\d+$}, 'nofork: path method';
is $cmd->data, "path test", 'nofork: data after update';

done_testing;
