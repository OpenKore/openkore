use ExtUtils::ParseXS qw(process_file);

process_file(	filename => 'Rijndael.xs',
				output => 'Rijndael.xs.cpp',
				'C++' => 1,
				typemap => 'typemap',
				#hiertype => 1,
				#except => 1,
				#prototypes => 1,
				#versioncheck => 1,
				#linenumbers => 1,
				#optimize => 1,
			);
