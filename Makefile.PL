
use ExtUtils::MakeMaker;
WriteMakefile(
		NAME	=> q[Getopt::Declare],
		VERSION => q[1.13],
    PREREQ_PM => { 'Text::Balanced'=> 0 },
);
