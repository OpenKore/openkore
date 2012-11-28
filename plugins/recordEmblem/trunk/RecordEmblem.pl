# Plugin emblemRecord by KeplerBR
# Thanks to EternalHarvest and HwapX
#
# The plugin will collect the emblems of the guilds of players who are close and save on the folder logs
# For more information, see the topic: http://forums.openkore.com/viewtopic.php?f=34&t=18466

package emblemRecord;
	use strict;
	use warnings;
	use Plugins;
	use Log qw(message warning error);
	use Globals;
	use Settings;

	use Compress::Zlib; # http://search.cpan.org/dist/Compress-Zlib/ 

	#Register Plugin and Hooks
	Plugins::register("emblemRecord", "Collect and save the emblems on the folder logs", \&on_unload);
		my $hooks = Plugins::addHooks(
			['charNameUpdate', \&start_request],
			['packet/guild_emblem', \&save_emblem],
		);
	
	#On Unload code
	sub on_unload {
		Plugins::delHook("charNameUpdate", $hooks);
		Plugins::delHook("packet/guild_emblem", $hooks);
	}

	#On Action
	sub start_request {
		my $hookname = shift;
		my $args = shift;

		my $guildID = unpack("v1", $args->{player}{guildID});
		my $emblemID = unpack("v1", $args->{player}{emblemID});
		my $caminho = $Settings::logs_folder . "\emblem - GuildID " . $guildID . " - EmblemID " . $emblemID . ".bmp";

		if ($guildID && $emblemID && !-e $caminho) {
			$messageSender->sendGuildRequestEmblem($guildID);
		}
	}

	sub save_emblem {
		my ($self, $args) = @_;
		my $guildID = unpack("v1", $args->{guildID});
		my $emblemID = unpack("v1", $args->{emblemID});
		my $emblemBtye = $args->{emblem};

		# Uncompress -> Requires module Zlib
		my $emblemUncompressed = uncompress($emblemBtye);

		# Loop to change the color pink to white
		# Treatment was done for emblems the 8-bit and 24-bit
		# The amount of bits are at offset 0x1C
		#
		# --> In a 8-bit BMP file, the header occupies about 54 bytes. But it does not matter to
		#      us, so lets skip that part. It will read the color table, and when it finds the
		#      pink color, it will replace it to white
		#     The size of the color table is informed at offset 0x2E - it informs the amount
		#      of colors. If offset 0X2E is 0, the default value of the table is used: 2 ^ bits
		#     2 ^ bits = 2 ^ 8 = 256
		#     Each color occupies 4 bytes
		# --> In a 24-bit BMP file, the header occupies about 54 bytes. But it does not matter to
		#      us, so lets skip that part. Then will be reading the following bytes to get the
		#      color pink, if found, will be substituted for white
		#     The emblems always has the size 24x24, with the header, equivalent to about 1782
		#      bytes, or 3564 characters
		#     Each color occupies 3 bytes
		my $emblemHex = unpack("H*", $emblemUncompressed);
		if (substr($emblemHex, 56, 2) == '08') {
		# Treatment for 8-bit BMP
			my $lengthColorTable = hex(substr($emblemHex, 92, 2));
			$lengthColorTable = 256 if ($lengthColorTable == 0);
			$lengthColorTable = $lengthColorTable * 8;
			my $byte1; my $byte2; my $byte3;
			for (my $i = 108; $i <= $lengthColorTable + 108; $i += 8) {
				$byte1 = hex(substr($emblemHex, $i, 2));
				$byte2 = hex(substr($emblemHex, $i + 2, 2));
				$byte3 = hex(substr($emblemHex, $i + 4, 2));
				if ($byte1 > 249 && $byte2 < 151 && $byte3 > 249) { # For some reason, the pink part has more than only one tone
					substr($emblemHex, $i + 2, 2) = 'FF';
				}
			}
		} else {
		# Treatment for 24-bit BMP
			my $byte1; my $byte2; my $byte3;
			for (my $i = 108; $i < 3564; $i += 6) {
				$byte1 = hex(substr($emblemHex, $i, 2));
				$byte2 = hex(substr($emblemHex, $i + 2, 2));
				$byte3 = hex(substr($emblemHex, $i + 4, 2));
				if ($byte1 > 249 && $byte2 < 151 && $byte3 > 249) {
					substr($emblemHex, $i + 2, 2) = 'FF';
				}
			}
		}

		# Save emblem
		my $nameFile = "emblem - GuildID " . $guildID . " - EmblemID " . $emblemID . ".bmp";
		my $file = $Settings::logs_folder . "/" . $nameFile;
		open my $DUMP, '>:raw', $file;
		print $DUMP pack("H*", $emblemHex);
		close $DUMP or error "[Plugin recordEmblem] Unable to close $nameFile: $!";

		# Finalize
		message "Emblem $nameFile has been saved to: $Settings::logs_folder \n";
	}
	1;