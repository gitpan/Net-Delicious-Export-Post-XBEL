use ExtUtils::MakeMaker;
WriteMakefile(NAME=>"Net::Delicious::Export::Post::XBEL",
	      ($[ >= 5.005) ?
	      (AUTHOR   => 'Aaron Straup Cope (cpan@aaronland.net)',
	       ABSTRACT => 'Export your del.icio.us posts as XBEL') : (),
	      VERSION_FROM => "lib/Net/Delicious/Export/Post/XBEL.pm",
	      'PREREQ_PM'    => {"Net::Delicious"          => '0.3',
				 "Net::Delicious::Export"  => '1.0',
				 "MD5"                     => 0,
				 "Test::More"              => 0,},
	     );
