# Unit test for Network
package NetworkTest;

use Test::More;
use Network::Receive;
use Network::Send;

sub start {
	print "### Starting NetworkTest\n";
	testServerTypeTree();
}

sub testServerTypeTree {
	use_ok($_) for map {("Network::Receive::$_", "Network::Send::$_")} qw(
		ServerType0
		ServerType1
		ServerType2
		ServerType3
		ServerType4
		ServerType5
		ServerType6
		ServerType7
		ServerType8
		ServerType8_1
		ServerType8_2
		ServerType8_3
		ServerType8_4
		ServerType8_5
		ServerType9
		ServerType10
		ServerType11
		ServerType12
		ServerType13
		ServerType14
		ServerType15
		ServerType16
		ServerType17
		ServerType18
		ServerType19
		ServerType20
		ServerType21
		ServerType22
		bRO
		bRO::Thor
		euRO
		fRO
		idRO
		iRO
		mRO
		pRO
		rRO
		tRO
		twRO
		kRO::RagexeRE_0
	);
}

1;
