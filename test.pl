# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..10\n"; }
END {print "not ok 1\n" unless $loaded;}
use Getopt::Declare;
$loaded = 1;
print "ok 1\n";
$count=2;

sub ok
{
	print "not " if defined($_[0]) && !$_[0];
	print "ok $count\n";
	$count++;
}

sub debug { print @_ if 0 }

######################### End of black magic.

@ARGV = ("bee",'BB BB',
	 "-aA", "s e e",
	 "remainder",
	 '+d', '1', '2', '3', '-1',
	 '-yz',
	 '+d', '1', '2', '3', '-1', 'a'
	);

my $args = new Getopt::Declare (q
{
	-a <aval>	option 1
				{ ::debug "matched $_PARAM_\t($_VAL_)\n" }

	bee <bval:qs>	option 2
				{ ::debug "matched $_PARAM_\t($_VAL_)\n" }

	<c>		option 3
				{ ::debug "matched $_PARAM_\t($_VAL_)\n" }

	+d <dval:n>...	option 4 [repeatable]
				{ ::debug "matched $_PARAM_\t($_VAL_)\n" }

	-1		option 5
				{ ::debug "matched $_PARAM_\t($_VAL_)\n" }

	<d>		option 6
				{ ::debug "rejected $_PARAM_\t($_VAL_)\n" }
				{ reject }
				{ ::debug "matched $_PARAM_\t($_VAL_)\n" }

	-y		option 7
				{ ::debug "matched $_PARAM_\t($_VAL_)\n" }

	-z		option 8
				{ ::debug "matched $_PARAM_\t($_VAL_)\n" }

});

ok $args;
ok $args->{-a} eq "A";
ok $args->{bee} eq "BB BB";
ok $args->{"<c>"} eq "s e e";
ok join(',',@{$args->{'+d'}}) eq '1,2,3,1,2,3';
ok !($args->{'<d>'});
ok $args->{'-1'};
ok @ARGV==3;
ok $ARGV[0] eq 'remainder';
