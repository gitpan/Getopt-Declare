package Getopt::Declare;

use strict;
use vars qw($VERSION);
use UNIVERSAL qw(isa);

$VERSION = '1.05';


package Getopt::Declare::StartOpt;

sub new        { bless {} }
sub matcher    { '(?:()' }
sub code       { '' }
sub cachecode  { '' }
sub trailer    { undef }
sub ows	       { return $_[1]; }

package Getopt::Declare::EndOpt;

sub new        { bless {} }
sub matcher    { '())?' }
sub code       { '' }
sub cachecode  { '' }
sub trailer    { undef }
sub ows	       { return $_[1]; }

package Getopt::Declare::ScalarArg;

my %stdtype = ();

sub _reset_stdtype
{
	%stdtype = 
	(
		':i'	=> { pattern => '(?:(?:%T[+-]?)%D+)' },
		':n'	=> { pattern => '(?:(?:%T[+-]?)(?:%D+(?:%T\.%D*)?(?:%T[eE]%D+)?'
					. '|%T\.%D+(?:%T[eE]%D+)?))' },
		':s'	=> { pattern => '(?:%T(?:\S|\0))+' },
		':qs'	=> { pattern => q{"(?:\\"|[^"])*"|'(?:\\'|[^"])*|(?:%T(?:\S|\0))+} },
		':id'	=> { pattern => '%T[a-zA-Z_](?:%T\w)*' },
		':if'	=> { pattern => '%F(?:%T(?:\S|\0))+',
			     action => '{reject($_VAL_ ne "-" && ! -r $_VAL_, "in parameter \'$_PARAM_\' (file \"$_VAL_\" is not readable)")}' },
		':of'	=> { pattern => '%F(?:%T(?:\S|\0))+',
			     action => '{reject ($_VAL_ ne "-" && -e $_VAL_ && ! -w $_VAL_ , "in parameter \'$_PARAM_\' (file \"$_VAL_\" is not writable)")}' },
		''	=> { pattern => ':s', ind => 1 },

		':+i'	=> { pattern => ':i',
			     action => '{reject ($_VAL_<=0, "in parameter \'$_PARAM_\' ($_VAR_ must be an integer greater than zero)")}',
			     ind => 1},

		':+n'	=> { pattern => ':n',
			     action => '{reject ($_VAL_<=0, "in parameter \'$_PARAM_\' ($_VAR_ must be a number greater than zero)")}',
			     ind => 1},

		':0+i'	=> { pattern => ':i',
			     action => '{reject ($_VAL_<0, "in parameter \'$_PARAM_\' ($_VAR_ must be an positive integer)")}',
			     ind => 1},

		':0+n'	=> { pattern => ':n',
			     action => '{reject ($_VAL_<0, "in parameter \'$_PARAM_\' ($_VAR_ must be a positive number)")}',
			     ind => 1},

	);
}

sub stdtype	# ($typename)
{
	my $name = shift;
	my %seen = ();
	while (!$seen{$name} && $stdtype{$name} && $stdtype{$name}->{ind})
		{ $seen{$name} = 1; $name = $stdtype{$name}->{pattern} }

	return undef if $seen{$name} || !$stdtype{$name};
	return $stdtype{$name}->{pattern};
}

sub stdactions	# ($typename)
{
	my $name = shift;
	my %seen = ();
	my @actions = ();
	while (!$seen{$name} && $stdtype{$name} && $stdtype{$name}->{ind})
	{
		$seen{$name} = 1;
		push @actions, $stdtype{$name}->{action}
			if $stdtype{$name}->{action};
		$name = $stdtype{$name}->{pattern}
	}
	push @actions, $stdtype{$name}->{action}
		if $stdtype{$name}->{action};

	return @actions;
}

sub addtype 	# ($abbrev, $pattern, $action, $ref)
{
	my $typeid = ":$_[0]";
	unless ($_[1] =~ /\S/) { $_[1] = ":s" , $_[3] = 1; }
	$stdtype{$typeid} = {};
	$stdtype{$typeid}->{pattern} = "(?:$_[1])" if $_[1] && !$_[3];
	$stdtype{$typeid}->{pattern} = ":$_[1]" if $_[1] && $_[3];
	$stdtype{$typeid}->{action} = $_[2] if $_[2];
	$stdtype{$typeid}->{ind} = $_[3];
}

sub new		# ($self, $name, $type, $nows)
{
	bless
	{	name => $_[1],
		type => $_[2],
		nows => $_[3],
	}, ref($_[0])||$_[0];
}

sub matcher	# ($self, $trailing)
{
	my ($self, $trailing) = @_;
	#WAS: $trailing = $trailing ? '(?!\Q'.$trailing.'\E)' : '';
	$trailing = $trailing ? '(?!'.quotemeta($trailing).')' : '';
	my $stdtype = stdtype($self->{type});

	if (!$stdtype && $self->{type} =~ m#\A:/([^/]+)/\Z#) { $stdtype = $1; }
	if (!$stdtype)
	{
		die "Error: bad type in Getopt::Declare parameter variable specification near '<$self->{name}$self->{type}>'\n";
	}
	$stdtype =~ s/\%D/(?:$trailing\\d)/g;
	$stdtype =~ s/\%T/$trailing/g;
	unless ($stdtype =~ s/\%F//)
	{
		$stdtype = Getopt::Declare::Arg::negflagpat().$stdtype;
	}
	return "(?:$stdtype)";
}

sub code	# ($self, $pos, $package)
{
	my $code = '
		$_VAR_ = q|<' . $_[0]->{name} . '>|;
		$_VAL_ = $' . ($_[1]+1) . '||undef;
		$_VAL_ =~ tr/\0/ / if $_VAL_;';

	my @actions = stdactions($_[0]->{type});
	foreach ( @actions )
	{
		s/(\s*\{)/$1 package $_[2]; /;
		$code .= "\n\t\tdo $_;";
	}

	$code .= '
		my $' . $_[0]->{name} . ' = $_VAL_;';

	return $code;
}

sub cachecode	# ($self, $ownerflag, $itemcount)
{
	return "\t\t\$self->{'$_[1]'}{'<$_[0]->{name}>'} = \$$_[0]->{name};\n"
		if $_[2] > 1;
	return "\t\t\$self->{'$_[1]'} = \$$_[0]->{name};\n";
}

sub trailer { '' };	# MEANS TRAILING PARAMETER VARIABLE

sub ows	      
{
	return '(?:\s|\0)*('.$_[1].')' unless $_[0]->{nows};
	return '('.$_[1].')';
}


package Getopt::Declare::ArrayArg;

use vars qw { @ISA };
@ISA = qw ( Getopt::Declare::ScalarArg );

sub matcher	# ($self, $trailing)
{
	my ($self, $trailing) = @_;
	my $suffix = (defined $trailing && !$trailing) ? '\s+' : '';
	my $scalar = $self->SUPER::matcher($trailing);

	return $scalar.'(?:\s+'.$scalar.')*'.$suffix;
}

sub code	# ($self, $pos, $package)
{
	my $code = '
		$_VAR_ = q|<' . $_[0]->{name} . '>|;
		$_VAL_ = undef;
		my @' . $_[0]->{name} . ' =
			map { tr/\0/ /; $_ } split " ", $'.($_[1]+1)."||'';\n";


	my @actions = Getopt::Declare::ScalarArg::stdactions($_[0]->{type});
	if (@actions)
	{
		$code .= '
		foreach $_VAL_ ( @' . $_[0]->{name} . ' )
		{';
		foreach ( @actions )
		{
			s/(\s*\{)/$1 package $_[2]; /;
			$code .= "\t\t\tdo $_;\n";
		}
		$code .= '
		}';
	}
	return $code;
}

sub cachecode	# ($self, $ownerflag, $itemcount)
{
	return "\t\t\$self->{'$_[1]'}{'<$_[0]->{name}>'} = []
			unless \$self->{'$_[1]'}{'<$_[0]->{name}>'};
		push \@{\$self->{'$_[1]'}{'<$_[0]->{name}>'}}, \@$_[0]->{name};\n"
			if $_[2] > 1;
	return "\t\t\$self->{'$_[1]'} = []
			unless \$self->{'$_[1]'};
		push \@{\$self->{'$_[1]'}}, \@$_[0]->{name};\n";
}


package Getopt::Declare::Punctuator;

sub new		# ($self, $text, $nows)
{
	bless { text => $_[1], nows => $_[2] }
}

sub matcher	# ($self, $trailing)
{
	#WAS: Getopt::Declare::Arg::negflagpat() . '\Q' . $_[0]->{text} . '\E';
	Getopt::Declare::Arg::negflagpat() . quotemeta($_[0]->{text});
}

sub code	# ($self, $pos)
{
	"
		\$_PUNCT_{'" . $_[0]->{text} . "'" . '} = $' . ($_[1]+1) . ";\n";
}

sub cachecode	# ($self, $ownerflag, $itemcount)
{
	return "\t\t\$self->{'$_[1]'}{'$_[0]->{text}'} = \$_PUNCT_{'$_[0]->{text}'};\n"
		if $_[2] > 1;
	return "\t\t\$self->{'$_[1]'} = \$_PUNCT_{'$_[0]->{text}'};\n";
}

sub trailer  { $_[0]->{text} };

sub ows	      
{
	return '(?:\s|\0)*('.$_[1].')' unless $_[0]->{nows};
	return '('.$_[1].')';
}


package Getopt::Declare::Arg;

use Text::Balanced qw( extract_bracketed );

my $nextID = 0;

my @helpcmd = qw( -help --help -Help --Help -HELP --HELP -h -H );
my %helpcmd = map { $_ => 1 } @helpcmd;

sub besthelp { foreach ( @helpcmd ) { return $_ if exists $helpcmd{$_}; } }
sub helppat  { return join '|', keys %helpcmd; }

my @versioncmd = qw( -version --version -Version --Version
		     -VERSION --VERSION -v -V );
my %versioncmd = map { $_ => 1 } @versioncmd;

sub bestversion {foreach (@versioncmd) { return $_ if exists $versioncmd{$_}; }}
sub versionpat  { return join '|', keys %versioncmd; }

my @flags;
my $posflagpat = '';
my $negflagpat = '';
sub negflagpat
{
	$negflagpat = join '', map { "(?!".quotemeta($_).")" } @flags
		if !$negflagpat && @flags;
	return $negflagpat;
}

sub posflagpat
{
	$posflagpat = '(?:'.join('|', map { quotemeta($_) } @flags).')'
		if !$posflagpat && @flags;
	return $posflagpat;
}

sub new		# ($class, $spec, $desc, $dittoflag)
{
	my ($class,$spec,$desc,$ditto) = @_;
	my $first = 1;
	my $arg;
	my $nows;

	my $self =
	{
		flag 	     => '',
		args	     => [],
		actions	     => [],
		ditto	     => $ditto,
		required     => 0,
		requires     => '',
		ID	     => $nextID++,
		desc	     => $spec,
		items	     => 0,
	};

	$self->{desc} =~ s/\A\s*(.*?)\s*\Z/$1/;

	while ($spec)
	{
	# OPTIONAL
		if ($spec =~ s/\A(\s*)\[/$1/)
		{
			push @{$self->{args}}, new Getopt::Declare::StartOpt;
			next;
		}
		elsif ($spec =~ s/\A\s*\]//)
		{
			push @{$self->{args}}, new Getopt::Declare::EndOpt;
			next;
		}

	# ARG

		($arg,$spec,$nows) = extract_bracketed($spec,'<>');
		if ($arg)
		{
			$arg =~ m/\A(\s*)(<)([a-zA-Z]\w*)(:[^>]+|)>/ or
				die "Error: bad Getopt::Declare parameter variable specification near '$arg'\n";

			my @details = ( $3, $4, !$first && !length($nows) );  # NAME,TYPE,NOWS

			if ($spec =~ s/\A\.\.\.//)	# ARRAY ARG
			{
				push @{$self->{args}},
					new Getopt::Declare::ArrayArg (@details);
			}
			else	# SCALAR ARG
			{
				push @{$self->{args}},
					new Getopt::Declare::ScalarArg (@details);
			}
			$self->{items}++;
			next;
		}

	# PUNCTUATION

		elsif ( $spec =~ s/\A(\s*)((\\.|[^] \t\n[<])+)// )
		{
			my ($ows, $punct) = ($1,$2);
			$punct =~ s/\\(?!\\)(.)/$1/g;
			if ($first) { $self->{flag} = $punct; push @flags, $punct; }

			else	    { push @{$self->{args}},
					new Getopt::Declare::Punctuator ($punct,!length($ows));
				      $self->{items}++; }

		}

		else { last; }

	}
	continue
	{
		$first = 0;
	}

	delete $helpcmd{$self->{flag}} if exists $helpcmd{$self->{flag}};

	bless $self;
}

sub code
{
	my ($self, $owner,$package) = @_;

	my $code = "\n";
	my $flag = $self->{flag};
	my $clump = $owner->{clump};
	my $i = 0;
	my $nocase = (Getopt::Declare::_nocase() || $self->{nocase} ? 'i' : '');

	$code .= (!$self->{repeatable})
			? q#	    param: while (!$_FOUND_{'# . $self->name . q#'}#
			: q#	    param: while (1#;

	if ($flag && ($clump==1 && $flag !~ /\A[^a-z0-9]+[a-z0-9]\Z/i
		  || ($clump<3 && @{$self->{args}} )))
	{
		$code .= q# && !$_lastprefix#;
	}

	$code .= q#)
	    {
		pos $_args = $_nextpos if defined $_args;
		%_PUNCT_ = ();#;

	if ($flag)
	{
		#WAS: $_args =~ m/\G(?:\s|\0)*\Q# . $flag . q#\E/g# . $nocase
		$code .= q#
	
		$_args && $_args =~ m/\G(?:\s|\0)*# . quotemeta($flag) . q#/g# . $nocase
		. q# or last;
		$_errormsg = q|incorrect specification of '# . $flag . q#' parameter| unless $_errormsg;

		#;
	}
	elsif ((Getopt::Declare::ScalarArg::stdtype($self->{args}[0]{type})||'') !~ /\%F/)
	{
		$code .= q#
	
		last if $_errormsg;

		#;
	}

	$code .= q#
		$_PARAM_ = '# . $self->name . q#';
		#;
	my @trailer;
	$#trailer = @{$self->{args}};
	for ($i=$#{$self->{args}} ; $i>0 ; $i-- )
	{
		$trailer[$i-1] = $self->{args}[$i]->trailer();
		$trailer[$i-1] = $trailer[$i] unless defined $trailer[$i-1];
	}

	if (@{$self->{args}})
	{
		$code .= '
			$_args && $_args =~ m/\G';

		for ($i=0; $i < @{$self->{args}} ; $i++ )
		{
		    $code .=
			$self->{args}[$i]->ows($self->{args}[$i]->matcher($trailer[$i]))
		}

		$code .= '/gx' . $nocase . ' or last;'
	}


	for ($i=0; $i < @{$self->{args}} ; $i++ )
	{
		$code .= $self->{args}[$i]->code($i,$package);	#, $flag ????
	}

	foreach my $action ( @{$self->{actions}} )
	{
		$action =~ s{(\s*\{)}
			    { $1 package $package; };
		$code .= "\n\t\tdo " . $action . ";\n";
	}

	if ($flag && $self->{items}==0)
	{
		$code .= "\n\t\t\$self->{'$flag'} = '$flag';\n";
	}
	foreach my $subarg ( @{$self->{args}} )
	{
		$code .= $subarg->cachecode($self->name,$self->{items});
	}

	if ($flag =~ /\A([^a-z0-9]+)/i)	{ $code .= '$_lastprefix = "'.quotemeta($1).'";'."\n" }
	else				{ $code .= '$_lastprefix = "";' }

	if ($flag)
	{
	    $code .= q#
		if (exists $_invalid{'# . $flag . q#'})
		{
			$_errormsg = q|parameter '# . $flag
				  . q#' not allowed with parameter '|
				  . $_invalid{'# . $flag . q#'} . q|'|;
			last;
		}
		else
		{
			foreach (#
			. ($owner->{mutex}{$flag}
			    ? join(',', map {"'$_'"} @{$owner->{mutex}{$flag}})
			    : '()')
			. q#)
			{
				$_invalid{$_} = '# . $flag . q#';
			}
		}
		#
	}

	$code .= q#
		$_FOUND_{'# . $self->name . q#'} = 1;
		next arg if pos $_args;
		$_nextpos = length $_args;
		last arg;
	}

		  #;
}

sub name
{
	my $self = shift;
	return $self->{flag} || "<$self->{args}[0]{name}>";
}


package Getopt::Declare;

use Text::Balanced qw( :ALL );
use Text::Tabs	   qw( expand );

# PREDEFINED GRAMMARS

my %_predef_grammar = 
(
	"-PERL" =>
q{	-<varname:id>		Set $<varname> to 1 [repeatable]
				{ no strict "refs"; ${"::$varname"} = 1 }

},
			
	"-AWK" =>
q{	<varname:id>=<val>	Set $<varname> to <val> [repeatable]
				{no strict "refs";  ${"::$varname"} = $val }
  	<varname:id>=		Set $<varname> to '' [repeatable]
				{no strict "refs";  ${"::$varname"} = '' }

},
);
my $_predef_grammar = join '|', keys %_predef_grammar;

sub _quoteat
{
	my $text = shift;
	$text =~ s/\A\@/\\\@/;
	$text =~ s/([^\\])\@/$1\\\@/;
	$text;
}

sub new		# ($self, $grammar; $source)
{
# HANDLE SHORT-CIRCUITS

	return 0 if @_==3 && (!defined($_[2]) || $_[2] eq '-SKIP'); 

# SET-UP

	my ($_class, $_grammar) = @_;

# PREDEFINED GRAMMAR?

	if ($_grammar =~ /\A(-[A-Z]+)+/)
	{
		my $predef = $_grammar;
		my %seen = ();
		$_grammar = '';
		$predef =~ s{($_predef_grammar)}{ do {$_grammar .= $_predef_grammar{$1} unless $seen{$1}; $seen{$1} = 1; ""} }ge;
		return undef if $predef || !$_grammar;
	}

# PRESERVE ESCAPED '['s

	$_grammar =~ s/\\\[/\255/g;

# SET-UP

	local $_ = $_grammar;
	my @_args = ();
	my $_mutex = {};
	my $_action;
	my $_all_repeatable = 0;
	my $_lastdesc = undef;
	_nocase(0);
	Getopt::Declare::ScalarArg::_reset_stdtype();

# CONSTRUCT GRAMMAR
	
	while (length $_ > 0)
	{
	# COMMENT:
		s/\A[ 	]*#.*\n// and next;

	# TYPE DIRECTIVE:

		#WAS: if (m/\A\s*\[pvtype:/ and $_action = extract_codeblock($_,'[{}]'))
		if (m/\A\s*\[pvtype:/ and $_action = extract_codeblock($_,'[]'))
		{
			$_action =~ s/.*?\[pvtype:\s*//;
			_typedef($_action);
			next;
		}

	# ACTION
		if ($_action = extract_codeblock)
		{
			# WAS: eval q{no strict;my $ref = sub }._quoteat($_action).q{;1}
			my $_check_action = $_action;
			$_check_action =~ s{(\s*\{)}
			    { $1 sub defer(&); sub finish(;\$); sub reject(;\$\$); };
			eval q{no strict;my $ref = sub }.$_check_action.q{;1}
			   or die "Error: bad action in Getopt::Declare specification:"
				. "\n\n$_action\n\n$@\n";
			if ($#_args < 0)
			{
				die "Error: unattached action in Getopt::Declare specification:\n$_action\n"
				    . "\t(did you forget the tab after the preceding parameter specification?)\n"
			}
			push @{$_args[$#_args]->{actions}}, $_action;
			next;
		}
		elsif (m/\A(\s*[{].*)/)
		{
			die "Error: incomplete action in Getopt::Declare specification:\n$1.....\n" 
			    . "\t(did you forget a closing '}'?)\n";
		}

	# ARG + DESC:
		if ( s/\A(.*?\S.*?)(\t.*\n)// )
		{
			my $spec = $1;
			my $desc = $2;
			my $ditto;

			$desc .= $1 while s/\A((?![ 	]*({|\n)|.*?\S.*?\t.*?\S).*?\S.*\n)//;
			
			$_lastdesc and $desc =~ s/\A\s*\[ditto\]/$_lastdesc/
				  and $ditto = 1;
			$_lastdesc = $desc;

			my $arg = new Getopt::Declare::Arg($spec,$desc,$ditto) ;
			push @_args, $arg;

			_infer($desc, $arg, $_mutex);
			next;
		}


	# OTHERWISE: DECORATION

		s/((?:(?!\[pvtype:).)*)(\n|(?=\[pvtype:))//;
		my $decorator = $1;
		_infer($decorator, undef, $_mutex);
		$_all_repeatable = 1 if $decorator =~ /\[repeatable\]/;
	}

	my $_lastactions;
	foreach ( @_args )
	{
		if ($_lastactions && $_->{ditto} && !@{$_->{actions}})
			{ $_->{actions} = $_lastactions }
		else
			{ $_lastactions = $_->{actions} }

		if ($_all_repeatable)
		{
			$_->{repeatable} = 1;
		}
	}

	@_args = sort
	{
		length($b->{flag}) <=> length($a->{flag})
				   or
 	  $b->{flag} eq $a->{flag} and $#{$b->{args}} <=> $#{$a->{args}}
				   or
		          $a->{ID} <=> $b->{ID}

	} @_args;

# CONSTRUCT OBJECT ITSELF

	my $clump = ($_grammar =~ /\[cluster:\s*none\s*\]/i)     ? 0
		  : ($_grammar =~ /\[cluster:\s*singles?\s*\]/i) ? 1
		  : ($_grammar =~ /\[cluster:\s*flags?\s*\]/i)   ? 2
		  : ($_grammar =~ /\[cluster:\s*any\s*\]/i)      ? 3
		  : ($_grammar =~ /\[cluster:(.*)\s*\]/i)  	 ?
			die "Error: unknown clustering mode: [cluster:$1]\n"
		  :						   3;

	my $self = bless
	{
		args	=> [@_args],
		mutex	=> $_mutex,
		usage	=> $_grammar,
		helppat => Getopt::Declare::Arg::helppat(),
		verspat => Getopt::Declare::Arg::versionpat(),
		strict	=> $_grammar =~ /\[strict\]/i,
		clump	=> $clump,
		source  => '',
		'caller'  => scalar caller(),
	}, ref($_class)||$_class;

# VESTIGAL DEBUGGING CODE

	 open (CODE, ">.CODE")
	 	and print CODE $self->code($self->{'caller'})
	 	and close CODE;

# DO THE PARSE (IF APPROPRIATE)


	if (@_==3) { return undef unless defined $self->parse($_[2]) }
	else	   { return undef unless defined $self->parse(); }

	return $self;
}

sub _get_nextline { scalar <> }

sub _load_sources	# ( \$_get_nextline, @files )
{
	my $text  = '';
	my @found = ();
	my $gnlref = shift;
	foreach ( @_ )
	{
		open FILE, $_ or next;
		if (-t FILE)
		{
			push @found, '<STDIN>';
			$$gnlref = \&_get_nextline;
		}
		else
		{
			push @found, $_;
			$text .= join "\n", <FILE>;
		}
	}
	return undef unless @found;
	$text = <STDIN> unless $text;
	return ( $text, join(" or ",@found));
}


sub parse	# ($self;$source)
{
	my ( $self, $source ) = @_;
	my $_args = ();
	my $_get_nextline = sub { undef };
	if (@_>1)
	{
		if (!defined $source)
		{
			return 0;
		}
		elsif (isa($source,'CODE'))
		{
			$_get_nextline = $source;
			$_args = &{$_get_nextline}($self);
			$source = '[SUB]';
		}
		elsif (isa($source,'GLOB'))
		{
			if (-t *$source)
			{
				$_get_nextline = \&_get_nextline ;
				$_args = <STDIN>;
				$source = '<STDIN>';
			}
			else
			{
				$_args = join ' ', (<$source>);
				$_args =~ tr/\t\n/ /s;
				$source = ref($source);
			}
		}
		elsif (isa($source,'IO::Handle'))
		{
			if (!($source->fileno) && -t)
			{
				$_get_nextline = \&_get_nextline ;
				$_args = <STDIN>;
				$source = '<STDIN>';
			}
			else
			{
				$_args = join ' ', (<$source>);
				$_args =~ tr/\t\n/ /s;
				$source = ref($source);
			}
		}
		elsif (ref($source) eq 'ARRAY')
		{
			if (@$source == 1 && (!defined($source->[0])
					      || $source->[0] eq '-BUILD'
				              || $source->[0] eq '-SKIP') )
			{
				return 0;
			}
			elsif (@$source == 1 && $source->[0] eq '-STDIN')
			{
				$_get_nextline = \&_get_nextline ;
				$_args = <STDIN>;
				$source = '<STDIN>';
			}
			elsif (@$source == 1 && $source->[0] eq '-CONFIG')
			{
				my $progname = "$0rc";
				$progname =~ s#.*/##;
				($_args,$source) = _load_sources(\$_get_nextline,"$ENV{HOME}/.$progname", ".$progname");
			}
			else
			{
				my $stdin;
				($_args,$source) = _load_sources(\$_get_nextline,@$source);
			}
		}
		else  # LITERAL STRING TO PARSE
		{
			$_args = $source;
			substr($source,7) = '...' if length($source)>7;
			$source = "\"$source\"";
		}
		return 0 unless defined $_args;
		$source = " (in $source)";
	}
	else
	{
		foreach (@ARGV) { $_ =~ tr/ \t\n/\0\0\0/; }
		$_args = join(' ', @ARGV);
		$source = '';
	}

	$self->{source} = $source;
	
	if (!eval $self->code($self->{'caller'}))
	{
		die "Error: in generated parser code:\n$@\n"
			if $@;
		return undef;
	}

	return 1;
}

sub type # ($abbrev, $pattern, $action)
{
	&Getopt::Declare::ScalarArg::addtype;
}

sub _enbool
{
	my $expr = shift;
	$expr =~ s/\s*\|\|\s*/ or /g;
	$expr =~ s/\s*&&\s*/ and /g;
	$expr =~ s/\s*!\s*/ not /g;
	return $expr;
}

sub _enfound
{
	my $expr = shift;
	my $original = $expr;
	$expr =~ s/((?:&&|\|\|)?\s*(?:[!(]\s*)*)([^ \t\n|&\)]+)/$1\$_FOUND_{'$2'}/gx;
	die "Error: bad condition in [requires: $original]\n"
		unless eval 'no strict; my $ref = sub { '.$expr.' }; 1';
	return $expr;
}

my $_nocase = 0;

sub _nocase
{
	$_nocase = $_[0] if $_[0];
	return $_nocase;
}

sub _infer  # ($desc, $arg, $mutex)
{
	my ($desc, $arg, $mutex) = @_;

	_mutex($mutex, split(' ',$1))
		while $desc =~ s/\[mutex:\s*(.*?)\]//i;

	if ( $desc =~ m/\[no\s*case\]/i)
	{
		if ($arg) { $arg->{nocase} = 1 }
		else	  { _nocase(1); }
	}

	if (defined $arg)
	{
		_exclude($mutex, $arg->name, (split(' ',$1)))
			if $desc =~ m/.*\[excludes:\s*(.*?)\]/i;
		$arg->{requires} = $1
			if $desc =~ m/.*\[requires:\s*(.*?)\]/i;

		$arg->{required}   = ( $desc =~ m/\[required\]/i );
		$arg->{repeatable} = ( $desc =~ m/\[repeatable\]/i );
	}

	_typedef($desc) while $desc =~ s/.*?\[pvtype:\s*//;
}

sub _typedef
{
	my $desc = $_[0];
	my ($name,$pat,$action,$ind);

	($name,$desc) = (extract_quotelike($desc))[5,1];
	do { $desc =~ s/\A\s*([^] \t\n]+)// and $name = $1 } unless $name;
	die "Error: bad type directive (missing type name): [pvtype: "
	   . substr($desc,0,index($desc,']')||20). "....\n"
		unless $name;

	($pat,$desc,$ind) = (extract_quotelike($desc,'\s*:?\s*'))[5,1,2];
	do { $desc =~ s/\A\s*(:?)\s*([^] \t\n]+)//
		and $pat = $2 and $ind = $1 } unless $pat;
	$pat = '' unless $pat;

	$action = extract_codeblock($desc) || '';
	die "Error: bad type directive (expected closing ']' but found"
	    . "'$1' instead): [pvtype: $name " . ($pat?"/$pat/":'')
	    . " $action $1$2....\n" if $desc =~ /\A\s*([^] \t\n])(\S*)/;

	Getopt::Declare::ScalarArg::addtype($name,$pat,$action,$ind=~/:/);
}

sub _ditto	# ($original, $desc)
{
	my ($original, $extra) = @_;
	chomp $original;
	$original =~ s/\S/"/g;
	1 while $original =~ s/"("+)"/ $1 /g;
	$original =~ s/""/" /g;
	return "$original$extra\n";
}

sub _mutex	# (\%mutex, @list)
{
	my ($mref, @mutexlist) = @_;

	foreach my $flag ( @mutexlist )
	{
		$mref->{$flag} = [] unless $mref->{$flag};
		foreach my $otherflag ( @mutexlist )
		{
			next if ($flag eq $otherflag);
			push @{$mref->{$flag}}, $otherflag;
		}
	}
}

sub _exclude	# (\%mutex, $excluded, @list)
{
	my ($mref, $excluded, @mutexlist) = @_;

	foreach my $flag ( @mutexlist )
	{
		unless ($flag eq $excluded)
		{
			$mref->{$flag} = [] unless $mref->{$flag};
			push @{$mref->{$excluded}}, $flag;
			push @{$mref->{$flag}}, $excluded;
		}
	}
}

sub version
{
	# my $filedate = localtime(time - 86400 * -M $0);
	my $filedate = localtime((stat $0)[9]);
	if ($::VERSION) { print "\n\t$0: version $::VERSION  ($filedate)\n\n" }
	else		{ print "\n\t$0: version dated $filedate\n\n" }
	exit $_[1] if defined $_[1];
}

sub usage
{
	my $self = $_[0];
	local $_ = $self->{usage};
	
	my $lastdesc = undef;

	my $usage = '';
	my $uoff;
	my $decfirst;
	my $ditto;

	while (length $_ > 0)
	{
	# COMMENT:
		s/\A[ 	]*#.*\n// and next;

	# TYPE DIRECTIVE:

		if (m/\A\s*\[pvtype:/ and extract_codeblock($_,'[{}]'))
		{
			next;
		}

	# ACTION
		extract_codeblock
			and do { s/\A[ 	]*\n//;
				 $decfirst = 0 unless defined $decfirst;
				 next; };

	# ARG + DESC:
		if ( s/\A(.*?\S.*?\t+)(.*?\n)// )
		{
			$decfirst = 0 unless defined $decfirst;

			my ($spec) = expand $1;
			my ($desc) = expand $2;

			$desc .= (expand $1)[0]
				while s/\A((?![ 	]*({|\n)|.*?\S.*?\t.*?\S).*?\S.*\n)//;

			next if $desc =~ /\[undocumented\]/i;

			$uoff = 0;
			$spec =~ s/(<[a-zA-Z]\w*):([^>]+)>/$uoff+=1+length $2 and "$1>"/ge;
			$ditto = $desc =~ /\A\s*\[ditto\]/;
			$desc =~ s/^\s*\[.*?\]\s*\n//gm;
			$desc =~ s/\[.*?\]//g;

			if ($ditto)
				{ $desc = ($lastdesc? _ditto($lastdesc,$desc) : "" ) }
			elsif ($desc =~ /\A\s*\Z/)
				{ next; }
			else
				{ $lastdesc = $desc; }

			$usage .= $spec . ' ' x $uoff . $desc;

			next;
		};


	# OTHERWISE, DECORATION
		if (s/((?:(?!\[pvtype:).)*)(\n|(?=\[pvtype:))//)
		{
			my $desc = $1.($2||'');
			$desc =~ s/^(\s*\[.*?\])+\s*\n//gm;
			$desc =~ s/\[.*?\]//g;
			$decfirst = 1 unless defined $decfirst
						or $desc =~ m/\A\s*\Z/;
			$usage .= $desc;
		}
	}

	my $required = '';

	foreach my $arg ( @{$self->{args}} )
	{
		if ($arg->{required})
		{
			$required .= ' ' . $arg->{desc} . ' ';
		}
	}

	$usage =~ s/\255/[/g;	# REINSTATE ESCAPED '['s

	$required =~ s/<([a-zA-Z]\w*):[^>]+>/<$1>/g;

	my $helpcmd = Getopt::Declare::Arg::besthelp;
	my $versioncmd = Getopt::Declare::Arg::bestversion;

	my $PAGER = \*STDOUT;

	if (eval { require IO::Pager })
	{
		$PAGER = new IO::Pager ( resume => 1 );
	}

	unless ($self->{source})
	{
		print $PAGER  "\nUsage: $0 [options] $required\n";
		print $PAGER  "       $0 $helpcmd\n" if $helpcmd;
		print $PAGER  "       $0 $versioncmd\n" if $versioncmd;
		print $PAGER  "\n" unless $decfirst && $usage =~ /\A[ \t]*\n/;
	}
	print $PAGER  "Options:\n" unless $decfirst;
	print $PAGER  $usage;

	exit $_[1] if defined $_[1];
}

sub code
{
	my $self = shift;
	my $package = shift||'main';
	my $code = q#

	do
	{
	  my @_deferred = ();
	  my @_unused = ();
	  sub # . $package . q#::defer (&);
	  {
	    package # . $package . q#; local $^W;
	    *defer = sub (&) { push @_deferred, $_[0]; }
	  }
	  my %_FOUND_ = ();
	  my $_errors = 0;
	  my $_nextpos;
	  my %_invalid = ();
	  my $_lastprefix = '';
	  my $_finished = 0;
	  my %_PUNCT_;
	  my $_errormsg;
	  my $_VAL_;
	  my $_VAR_;
	  my $_PARAM_;

	  sub # . $package . q#::reject (;$$);
	  sub # . $package . q#::finish (;$);

	  {
	    package # . $package . q#; local $^W; 
	    *reject = sub (;$$) { local $^W; if (!defined($_[0]) || $_[0]) { $_errormsg = $_[1] if defined $_[1]; last param; } };
	    *finish = sub (;$) { if (!defined($_[0]) || $_[0]) { $_finished = 1; } };
	  }

	  $_nextpos = 0;
	  arg: while (!$_finished)
	  {
		$_errormsg = '';
		# . ( $self->{clump} ? q#
		while ($_lastprefix)
		{
			my $substr = substr($_args,$_nextpos);
			$substr =~ m/\A(?!\s|\0|\Z)#
				. Getopt::Declare::Arg::negflagpat() . q#/
				or do { $_lastprefix='';last};
			"$_lastprefix$substr" =~ m/\A(#
				.  Getopt::Declare::Arg::posflagpat()
				. q#)/
				or do { $_lastprefix='';last};
			substr($_args,$_nextpos,0) = $_lastprefix;
			last;
		}
		# : '') . q#
		pos $_args = $_nextpos if defined $_args;

		$self->usage(0) if $_args && $_args =~ m/\G# . $self->{helppat} . q#(\s|\0)/g;
		$self->version(0) if $_args && $_args =~ m/# . $self->{verspat} . q#(\s|\0)/;

	#;

	foreach my $arg ( @{$self->{args}} )
	{
		$code .= $arg->code($self,$package);
	}
	
	$code .= q#

	  if ($_lastprefix)
	  {
		  pos $_args = $_nextpos+length($_lastprefix);
		  $_lastprefix = '';
		  next;
	  }
	
	  pos $_args = $_nextpos;
	  $_args && $_args =~ m/\G(?:\s|\0)*(\S+)/g or last;
	  push @_unused, $1;
	  if ($_errormsg) { print STDERR "Error"."$self->{source}: $_errormsg\n" }

	  $_errors++ if ($_errormsg);
	  }
	  continue
	  {
		$_nextpos = pos $_args if defined $_args;
		if (defined $_args and $_args =~ m/\G(\s|\0)*\Z/g)
		{
			$_args = &{$_get_nextline}($self);
			last unless defined($_args);
			$_nextpos = 0;
			$_lastprefix = '';
		}
	  }
	  #;

	foreach my $arg ( @{$self->{args}} )
	{
		next unless $arg->{required};
		$code .= q#
	  do { print STDERR "Error"."$self->{source}".': required parameter # . $arg->name . q# not found.',"\n"; $_errors++ }
		unless $_FOUND_{'# . $arg->name . q#'}#;
		if ($self->{mutex}{$arg->name})
		{
			foreach my $mutex (@{$self->{mutex}{$arg->name}})
			{
				$code .= q# or $_FOUND_{'# . $mutex . q#'}#;
			}
		}
		$code .= ';';
	}
	
	foreach my $arg ( @{$self->{args}} )
	{
		if ($arg->{requires})
		{
			$code .= q#
	  do { print STDERR q|Error|.$self->{source}.q|: parameter '# . $arg->name
		  . q#' can only be specified with '# . _enbool($arg->{requires})
		  . q#'|,"\n"; $_errors++ }
		if $_FOUND_{'# . $arg->name . "'} && !(" . _enfound($arg->{requires}) . ');'
		}
	}

	$code .= q#
		push @_unused, split(' ', substr($_args,$_nextpos))
			if $_args && $_nextpos && length($_args) >= $_nextpos;
		#;

	if ($self->{strict})
	{
		$code .= q#
		unless ($_nextpos < length($_args||''))
		{
			foreach (@_unused)
			{
				tr/\0/ /;
				print STDERR "Error"."$self->{source}: unrecognizable argument ('$_')\n";
				$_errors++;
			}
		}
		#
	}

	$code .= q#

	  if ($_errors && !$self->{source})
	  {
		print STDERR "\n(try '$0 ".'# . Getopt::Declare::Arg::besthelp
				. q#'."' for more information)\n";
	  }

	  unless ($self->{source})
	  {
		  @ARGV = ();
		  foreach ( @_unused ) { tr/\0/ /; push @ARGV, $_; }
	  }

	  unless ($_errors) { foreach (@_deferred) { &$_ } }

	  !$_errors;

	}
	#;
}

1;
__END__
