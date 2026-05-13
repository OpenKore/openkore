package NPCConversationTest;

use strict;
use Test::More;

use Globals qw(%ai_v %talk $messageSender);
use Plugins;
use NPC::Conversation;

{
	package NPCConversationTest::MessageSenderMock;

	sub new {
		my ($class) = @_;
		return bless { calls => [] }, $class;
	}

	sub _push_call {
		my ($self, $method, @args) = @_;
		push @{$self->{calls}}, [$method, @args];
		return 1;
	}

	sub calls {
		my ($self) = @_;
		return $self->{calls};
	}

	sub clear {
		my ($self) = @_;
		$self->{calls} = [];
	}

	sub sendTalk            { shift->_push_call('sendTalk',            @_); }
	sub sendTalkContinue    { shift->_push_call('sendTalkContinue',    @_); }
	sub sendTalkResponse    { shift->_push_call('sendTalkResponse',    @_); }
	sub sendTalkNumber      { shift->_push_call('sendTalkNumber',      @_); }
	sub sendTalkText        { shift->_push_call('sendTalkText',        @_); }
	sub sendTalkCancel      { shift->_push_call('sendTalkCancel',      @_); }
	sub sendNPCBuySellList  { shift->_push_call('sendNPCBuySellList',  @_); }
}

sub _npc_id {
	return pack('V', $_[0]);
}

sub _last_call {
	my ($mock) = @_;
	return $mock->calls->[-1];
}

sub _reset_world {
	NPC::Conversation::reset(reason => 'unit_test_reset');
	undef %talk;
	delete $ai_v{'npc_talk'};
}

sub start {
	print "### Starting NPCConversationTest\n";

	local $messageSender = NPCConversationTest::MessageSenderMock->new();

	test_reset();
	test_text_flow();
	test_responses_flow($messageSender);
	test_number_and_text_input($messageSender);
	test_close_flow($messageSender);
}

sub test_reset {
	_reset_world();

	NPC::Conversation::on_text_packet(
		npc_id   => _npc_id(1001),
		name_id  => 2001,
		npc_name => 'Guide',
		text     => 'Hello there',
	);

	ok(NPC::Conversation::is_open(), 'conversation opened before reset');
	NPC::Conversation::reset(reason => 'test_reset');

	ok(NPC::Conversation::is_closed(), 'reset closes conversation');
	is(NPC::Conversation::current_state(), 'CLOSED', 'reset returns closed state');
	is(NPC::Conversation::text(), '', 'reset clears text');
	is_deeply(NPC::Conversation::responses(), [], 'reset clears responses');
	ok(!exists $talk{ID}, 'legacy %talk cleared');
	ok(!exists $ai_v{'npc_talk'}, 'legacy ai_v npc_talk cleared');
}

sub test_text_flow {
	_reset_world();

	NPC::Conversation::on_text_packet(
		npc_id   => _npc_id(2002),
		name_id  => 3002,
		npc_name => 'Kafra Employee',
		text     => 'Welcome adventurer',
	);
	NPC::Conversation::on_text_packet(
		npc_id   => _npc_id(2002),
		name_id  => 3002,
		npc_name => 'Kafra Employee',
		text     => 'How may I help you?',
	);

	ok(NPC::Conversation::is_open(), 'text packet opens conversation');
	is(NPC::Conversation::prompt_state(), 'TEXT', 'text packet sets TEXT state');
	ok(NPC::Conversation::has_text(), 'conversation has text');
	is_deeply(
		NPC::Conversation::text_lines(),
		['Welcome adventurer', 'How may I help you?'],
		'text lines are preserved in order'
	);
	like(NPC::Conversation::text(), qr/How may I help you\?/, 'joined text contains latest line');
	is($talk{msg}, "Welcome adventurer\nHow may I help you?", 'legacy talk message stays synchronized');
}

sub test_responses_flow {
	my ($mock) = @_;
	_reset_world();
	$mock->clear;

	NPC::Conversation::on_responses_packet(
		npc_id    => _npc_id(3003),
		name_id   => 4003,
		npc_name  => 'Warp Girl',
		responses => ['Prontera', 'Payon', 'Alberta'],
	);

	ok(NPC::Conversation::has_responses(), 'responses packet registers menu entries');
	is(NPC::Conversation::response_count(), 3, 'response count matches packet');
	ok(NPC::Conversation::expects_response(), 'response state expects a selection');
	is_deeply(
		NPC::Conversation::legacy_responses(),
		['Prontera', 'Payon', 'Alberta', 'Cancel Chat'],
		'legacy response list includes synthetic cancel item'
	);

	ok(NPC::Conversation::select_response(1), 'valid response is sent');
	is_deeply(
		_last_call($mock),
		['sendTalkResponse', _npc_id(3003), 1],
		'response selection preserves historical 0-based protocol index'
	);
	is(NPC::Conversation::current_state(), 'WAITING_SERVER', 'selecting a response moves local state to WAITING_SERVER');

	$mock->clear;
	NPC::Conversation::on_responses_packet(
		npc_id    => _npc_id(3003),
		name_id   => 4003,
		npc_name  => 'Warp Girl',
		responses => ['Prontera', 'Payon'],
	);
	ok(NPC::Conversation::cancel(), 'menu cancel is sent through synthetic cancel index');
	is_deeply(
		_last_call($mock),
		['sendTalkResponse', _npc_id(3003), 2],
		'cancel uses appended cancel index for compatibility'
	);

	$mock->clear;
	NPC::Conversation::reset(reason => 'invalid_select_test');
	ok(!NPC::Conversation::select_response(0), 'invalid selection is rejected when no menu is open');
	is(scalar @{$mock->calls}, 0, 'invalid selection does not send a packet');
}

sub test_number_and_text_input {
	my ($mock) = @_;
	_reset_world();
	$mock->clear;

	NPC::Conversation::on_number_input_packet(
		npc_id   => _npc_id(4004),
		name_id  => 5004,
		npc_name => 'Quiz Master',
	);
	ok(NPC::Conversation::expects_number(), 'number input state is detected');
	ok(NPC::Conversation::send_number(10), 'numeric reply is sent');
	is_deeply(_last_call($mock), ['sendTalkNumber', _npc_id(4004), 10], 'number reply uses low-level sender');

	NPC::Conversation::on_text_input_packet(
		npc_id   => _npc_id(5005),
		name_id  => 6005,
		npc_name => 'Registration Clerk',
	);
	ok(NPC::Conversation::expects_text(), 'text input state is detected');
	ok(NPC::Conversation::send_text('OpenKore'), 'text reply is sent');
	is_deeply(_last_call($mock), ['sendTalkText', _npc_id(5005), 'OpenKore'], 'text reply uses low-level sender');
}

sub test_close_flow {
	my ($mock) = @_;
	_reset_world();
	$mock->clear;

	NPC::Conversation::on_text_packet(
		npc_id   => _npc_id(6006),
		name_id  => 7006,
		npc_name => 'Quest NPC',
		text     => 'Quest complete.',
	);
	NPC::Conversation::on_close_packet(
		npc_id   => _npc_id(6006),
		name_id  => 7006,
		npc_name => 'Quest NPC',
	);

	is(NPC::Conversation::prompt_state(), 'CLOSING', 'close packet moves conversation into CLOSING state');
	like(NPC::Conversation::text(), qr/Quest complete\./, 'closing state preserves latest text for inspection');
	ok(NPC::Conversation::close(), 'close sends final cancel packet');
	is_deeply(_last_call($mock), ['sendTalkCancel', _npc_id(6006)], 'close delegates to talk cancel packet');
	ok(NPC::Conversation::is_closed(), 'close fully resets conversation');
}

1;
