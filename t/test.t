#!perl

use lib 'lib';
use strict;
use warnings;
use Test::More tests => 15;

BEGIN { use_ok( 'Getopt::Declare' ); }

my $spec = q{
	-a <aval>		option 1
				{ $_VAL_ = '<undef>' unless defined $_VAL_;
				  ::debug "matched $_PARAM_\t($_VAL_)\n" }
	bee <bval:qs>		option 2
				{ $_VAL_ = '<undef>' unless defined $_VAL_;
				  ::debug "matched $_PARAM_\t($_VAL_)\n" }
	<c>			option 3
				{ $_VAL_ = '<undef>' unless defined $_VAL_;
				  ::debug "matched $_PARAM_\t($_VAL_)\n" }
	+d <dval:n>...		option 4 [repeatable]
				{ $_VAL_ = '<undef>' unless defined $_VAL_;
				  ::debug "matched $_PARAM_\t($_VAL_)\n" }
	-1			option 5
				{ $_VAL_ = '<undef>' unless defined $_VAL_;
				  ::debug "matched $_PARAM_\t($_VAL_)\n" }
	--out <out:of>...	option 6
				{ $_VAL_ = '<undef>' unless defined $_VAL_;
				  ::debug "matched $_PARAM_\t($_VAL_)\n" }
	<d>			option 7
				{ $_VAL_ = '<undef>' unless defined $_VAL_;
				  ::debug "rejected $_PARAM_\t($_VAL_)\n" }
				{ reject }
				{ $_VAL_ = '<undef>' unless defined $_VAL_;
				  ::debug "matched $_PARAM_\t($_VAL_)\n" }
	-y			option 8
				{ $_VAL_ = '<undef>' unless defined $_VAL_;
				  ::debug "matched $_PARAM_\t($_VAL_)\n" }
	-z			option 9
				{ $_VAL_ = '<undef>' unless defined $_VAL_;
				  ::debug "matched $_PARAM_\t($_VAL_)\n" }
};

@ARGV = (
	  'bee',       'BB BB',
	  '--out',     'dummy.txt',
	  '-aA',
    's e e',
	  'remainder',
	  '+d',        '9', '1.2345', '1e3', '2.1E-01', '.3', '-1',
	  '-yz',
	  '+d',        '9', '1.2345', '1e3', '2.1E-01', '.3', '-1', 'a',
	);

ok my $args = Getopt::Declare->new($spec), 'new';
isa_ok $args, 'Getopt::Declare';
ok $args->version, 'version';
ok $args->usage, 'usage';
is $args->{'-a'}, 'A', 'Argument parsing';
is $args->{'bee'}, 'BB BB';
is $args->{'<c>'}, 's e e';
is join(',',@{$args->{'+d'}}), '9,1.2345,1e3,2.1E-01,.3,9,1.2345,1e3,2.1E-01,.3';
is $args->{'<d>'}, undef;
is $args->{'-1'}, -1;
is ${$args->{'--out'}}[0], 'dummy.txt';
is scalar @ARGV, 2;
is $ARGV[0], 'remainder';
is $ARGV[1], 'a';

#done_testing();

sub debug
{
        print @_ if 0;
}

