#!/usr/bin/env python3
"""
ROla Packet Analyzer - Advanced Pattern Detection
Captura, analisa padrões repetidos e gera relatórios com sugestões de formato Perl
"""

import argparse
import sys
import time
import threading
import json
import os
import signal
from datetime import datetime
from collections import defaultdict, Counter
import socket
import struct
import ipaddress
from pathlib import Path

try:
    from scapy.all import *
    from scapy.layers.inet import IP, TCP
    from scapy.layers.l2 import Ether
except ImportError:
    print("Erro: Scapy não está instalado. Execute: pip install scapy")
    sys.exit(1)

try:
    from colorama import init, Fore, Back, Style
    init()
    COLORS_AVAILABLE = True
except ImportError:
    COLORS_AVAILABLE = False
    class Fore:
        RED = GREEN = BLUE = YELLOW = CYAN = MAGENTA = WHITE = RESET = ""
    class Back:
        BLACK = RESET = ""
    class Style:
        BRIGHT = RESET_ALL = ""

# Mapeamento de opcodes para identificação de pacotes
SEND_PACKETS = {
    0x0C26: 'master_login',
    0x0065: 'game_login',
    0x0066: 'char_login',
    0x0067: 'char_create',
    0x0068: 'char_delete',
    0x0436: 'map_login',
    0x007D: 'map_loaded',
    0x007E: 'sync',
    0x0085: 'character_move',
    0x0089: 'actor_action',
    0x008C: 'public_chat',
    0x0090: 'npc_talk',
    0x0094: 'actor_info_request',
    0x0096: 'private_message',
    0x0099: 'gm_broadcast',
    0x009B: 'actor_look_at',
    0x009F: 'item_take',
    0x00A2: 'item_drop',
    0x00A7: 'item_use',
    0x00A9: 'send_equip',
    0x00AB: 'send_unequip_item',
    0x00B2: 'restart',
    0x00B8: 'npc_talk_response',
    0x00B9: 'npc_talk_continue',
    0x00BB: 'send_add_status_point',
    0x00BF: 'send_emotion',
    0x00C1: 'request_user_count',
    0x00C5: 'request_buy_sell_list',
    0x00C8: 'buy_bulk',
    0x00C9: 'sell_bulk',
    0x00CC: 'gm_kick',
    0x00CE: 'gm_kick_all',
    0x00CF: 'ignore_player',
    0x00D0: 'ignore_all',
    0x00D3: 'get_ignore_list',
    0x00D5: 'chat_room_create',
    0x00D9: 'chat_room_join',
    0x00DE: 'chat_room_change',
    0x00E0: 'chat_room_bestow',
    0x00E2: 'chat_room_kick',
    0x00E3: 'chat_room_leave',
    0x00E4: 'deal_initiate',
    0x00E6: 'deal_reply',
    0x00E8: 'deal_item_add',
    0x00EB: 'deal_finalize',
    0x00ED: 'deal_cancel',
    0x00EF: 'deal_trade',
    0x00F3: 'storage_item_add',
    0x00F5: 'storage_item_remove',
    0x00F7: 'storage_close',
    0x00FC: 'party_join_request',
    0x00FF: 'party_join',
    0x0100: 'party_leave',
    0x0102: 'party_setting',
    0x0103: 'party_kick',
    0x0108: 'party_chat',
    0x0112: 'send_add_skill_point',
    0x0113: 'skill_use',
    0x0116: 'skill_use_location',
    0x011B: 'warp_select',
    0x011D: 'memo_request',
    0x0126: 'cart_add',
    0x0127: 'cart_get',
    0x0128: 'storage_to_cart',
    0x0129: 'cart_to_storage',
    0x012A: 'companion_release',
    0x012E: 'shop_close',
    0x0130: 'send_entering_vending',
    0x0134: 'buy_bulk_vender',
    0x013F: 'gm_item_mob_create',
    0x0140: 'gm_move_to_map',
    0x0143: 'npc_talk_number',
    0x0146: 'npc_talk_cancel',
    0x0149: 'alignment',
    0x014D: 'guild_check',
    0x014F: 'guild_info_request',
    0x0151: 'guild_emblem_request',
    0x0159: 'guild_leave',
    0x015B: 'guild_kick',
    0x015D: 'guild_break',
    0x0165: 'guild_create',
    0x0168: 'guild_join_request',
    0x016B: 'guild_join',
    0x016E: 'guild_notice',
    0x0170: 'guild_alliance_request',
    0x0172: 'guild_alliance_reply',
    0x0178: 'identify',
    0x017A: 'card_merge_request',
    0x017C: 'card_merge',
    0x017E: 'guild_chat',
    0x0187: 'ban_check',
    0x018A: 'quit_request',
    0x018E: 'make_item_request',
    0x0190: 'skill_use_location_text',
    0x0193: 'actor_name_request',
    0x0197: 'gm_reset_state_skill',
    0x0198: 'gm_change_cell_type',
    0x019C: 'gm_broadcast_local',
    0x019D: 'gm_change_effect_state',
    0x019F: 'pet_capture',
    0x01A1: 'pet_menu',
    0x01A5: 'pet_name',
    0x01A7: 'pet_hatch',
    0x01A9: 'pet_emotion',
    0x01AE: 'make_arrow',
    0x01AF: 'change_cart',
    0x01B2: 'shop_open',
    0x01BA: 'gm_remove',
    0x01BB: 'gm_shift',
    0x01BC: 'gm_recall',
    0x01BD: 'gm_summon_player',
    0x01C0: 'request_remain_time',
    0x01CE: 'auto_spell',
    0x01D5: 'npc_talk_text',
    0x01DB: 'secure_login_key_request',
    0x01DD: 'master_login',
    0x01DF: 'gm_request_account_name',
    0x01E7: 'novice_dori_dori',
    0x01ED: 'novice_explosion_spirits',
    0x01F7: 'adopt_reply_request',
    0x01F9: 'adopt_request',
    0x01FA: 'master_login',
    0x01FD: 'repair_item',
    0x0202: 'friend_request',
    0x0203: 'friend_remove',
    0x0204: 'client_hash',
    0x0208: 'friend_response',
    0x0212: 'manner_by_name',
    0x0213: 'gm_request_status',
    0x0217: 'rank_blacksmith',
    0x0218: 'rank_alchemist',
    0x021D: 'less_effect',
    0x0222: 'refine_item',
    0x0225: 'rank_taekwon',
    0x022D: 'homunculus_command',
    0x0231: 'homunculus_name',
    0x0232: 'actor_move',
    0x0233: 'slave_attack',
    0x0234: 'slave_move_to_master',
    0x0237: 'rank_killer',
    0x023B: 'storage_password',
    0x023F: 'mailbox_open',
    0x0241: 'mail_read',
    0x0243: 'mail_delete',
    0x0244: 'mail_attachment_get',
    0x0246: 'mail_remove',
    0x0247: 'mail_attachment_set',
    0x0248: 'mail_send',
    0x024B: 'auction_add_item_cancel',
    0x024C: 'auction_add_item',
    0x024D: 'auction_create',
    0x024E: 'auction_cancel',
    0x024F: 'auction_buy',
    0x0251: 'auction_search',
    0x0254: 'starplace_agree',
    0x025B: 'cook_request',
    0x025C: 'auction_info_self',
    0x025D: 'auction_sell_stop',
    0x0273: 'mail_return',
    0x0275: 'game_login',
    0x0288: 'cash_dealer_buy',
    0x0292: 'auto_revive',
    0x029F: 'mercenary_command',
    0x02B0: 'master_login',
    0x02B6: 'send_quest_state',
    0x02BA: 'hotkey_change',
    0x02C4: 'party_join_request_by_name',
    0x02C7: 'party_join_request_by_name_reply',
    0x02CF: 'memorial_dungeon_command',
    0x02D6: 'view_player_equip_request',
    0x02D8: 'misc_config_set',
    0x02DB: 'battleground_chat',
    0x02F1: 'notify_progress_bar_complete',
    0x035F: 'character_move',
    0x0360: 'sync',
    0x0361: 'actor_look_at',
    0x0362: 'item_take',
    0x0363: 'item_drop',
    0x0364: 'storage_item_add',
    0x0365: 'storage_item_remove',
    0x0366: 'skill_use_location',
    0x0367: 'skill_use_location_text',
    0x0368: 'actor_info_request',
    0x0369: 'actor_name_request',
    0x0437: 'actor_action',
    0x0438: 'skill_use',
    0x0439: 'item_use',
    0x0443: 'skill_select',
    0x0447: 'blocking_play_cancel',
    0x044A: 'client_version',
    0x07DA: 'party_leader',
    0x07D7: 'party_setting',
    0x07E4: 'item_list_window_selected',
    0x07E7: 'captcha_answer',
    0x0801: 'buy_bulk_vender',
    0x0802: 'booking_register',
    0x0804: 'booking_search',
    0x0806: 'booking_delete',
    0x0808: 'booking_update',
    0x0811: 'buy_bulk_openShop',
    0x0815: 'buy_bulk_closeShop',
    0x0817: 'buy_bulk_request',
    0x0819: 'buy_bulk_buyer',
    0x0825: 'token_login',
    0x0827: 'char_delete2',
    0x0829: 'char_delete2_accept',
    0x082B: 'char_delete2_cancel',
    0x0835: 'search_store_info',
    0x0838: 'search_store_request_next_page',
    0x083B: 'search_store_close',
    0x083C: 'search_store_select',
    0x0842: 'recall_sso',
    0x0843: 'remove_aid_sso',
    0x0844: 'cash_shop_open',
    0x0846: 'req_cash_tabcode',
    0x0848: 'cash_shop_buy',
    0x084A: 'cash_shop_close',
    0x08B5: 'pet_capture',
    0x08B8: 'send_pin_password',
    0x08BA: 'new_pin_password',
    0x08C1: 'macro_start',
    0x08C2: 'macro_stop',
    0x08C9: 'request_cashitems',
    0x096E: 'merge_item_request',
    0x0970: 'char_create',
    0x0974: 'merge_item_cancel',
    0x097C: 'rank_general',
    0x0987: 'master_login',
    0x098D: 'clan_chat',
    0x098F: 'char_delete2_accept',
    0x0998: 'send_equip',
    0x09A1: 'sync_received_characters',
    0x09A7: 'banking_deposit_request',
    0x09A9: 'banking_withdraw_request',
    0x09AB: 'banking_check_request',
    0x09D0: 'gameguard_reply',
    0x09D4: 'sell_buy_complete',
    0x09D6: 'buy_bulk_market',
    0x09D8: 'market_close',
    0x09E1: 'guild_storage_item_add',
    0x09E2: 'guild_storage_item_remove',
    0x09E3: 'cart_to_guild_storage',
    0x09E4: 'guild_storage_to_cart',
    0x09E8: 'rodex_open_mailbox',
    0x09E9: 'rodex_close_mailbox',
    0x09EA: 'rodex_read_mail',
    0x09EE: 'rodex_next_maillist',
    0x09EF: 'rodex_refresh_maillist',
    0x09F1: 'rodex_request_zeny',
    0x09F3: 'rodex_request_items',
    0x09F5: 'rodex_delete_mail',
    0x09FB: 'pet_evolution',
    0x0A03: 'rodex_cancel_write_mail',
    0x0A04: 'rodex_add_item',
    0x0A06: 'rodex_remove_item',
    0x0A08: 'rodex_open_write_mail',
    0x0A13: 'rodex_checkname',
    0x0A16: 'dynamicnpc_create_request',
    0x0A19: 'roulette_window_open',
    0x0A1B: 'roulette_info_request',
    0x0A1D: 'roulette_close',
    0x0A1F: 'roulette_start',
    0x0A21: 'roulette_claim_prize',
    0x0A25: 'achievement_get_reward',
    0x0A2E: 'send_change_title',
    0x0A39: 'char_create',
    0x0A46: 'stylist_change',
    0x0A49: 'private_airship_request',
    0x0A52: 'captcha_register',
    0x0A54: 'captcha_upload_request_ack',
    0x0A56: 'macro_reporter_ack',
    0x0A5A: 'macro_detector_download',
    0x0A5C: 'macro_detector_answer',
    0x0A69: 'captcha_preview_request',
    0x0A6C: 'macro_reporter_select',
    0x0A68: 'open_ui_request',
    0x0A6E: 'rodex_send_mail',
    0x0A76: 'master_login',
    0x0A97: 'equip_switch_add',
    0x0A99: 'equip_switch_remove',
    0x0A9C: 'equip_switch_run',
    0x0AA1: 'refineui_select',
    0x0AA3: 'refineui_refine',
    0x0AA4: 'refineui_close',
    0x0AAC: 'master_login',
    0x0AC0: 'rodex_open_mailbox',
    0x0AC1: 'rodex_refresh_maillist',
    0x0ACE: 'equip_switch_single',
    0x0ACF: 'master_login',
    0x0AE8: 'change_dress',
    0x0AEF: 'attendance_reward_request',
    0x0AF4: 'skill_use_location',
    0x0B10: 'start_skill_use',
    0x0B11: 'stop_skill_use',
    0x0B14: 'inventory_expansion_request',
    0x0B19: 'inventory_expansion_rejected',
    0x0B1C: 'ping',
    0x0B21: 'hotkey_change',
    0x0C23: 'send_otp_login'
}

RECV_PACKETS = {
    0x0069: 'account_server_info',
    0x006A: 'login_error',
    0x006B: 'received_characters_info',
    0x006C: 'login_error_game_login_server',
    0x006D: 'character_creation_successful',
    0x006E: 'character_creation_failed',
    0x006F: 'character_deletion_successful',
    0x0070: 'character_deletion_failed',
    0x0071: 'received_character_ID_and_Map',
    0x0072: 'received_characters',
    0x0073: 'map_loaded',
    0x0074: 'map_load_error',
    0x0075: 'changeToInGameState',
    0x0077: 'changeToInGameState',
    0x0078: 'actor_exists',
    0x09FE: 'actor_connected',
    0x007A: 'changeToInGameState',
    0x09FD: 'actor_moved',
    0x007C: 'actor_spawned',
    0x007F: 'received_sync',
    0x0080: 'actor_died_or_disappeared',
    0x0081: 'errors',
    0x0086: 'actor_display',
    0x0087: 'character_moves',
    0x0088: 'actor_movement_interrupted',
    0x008A: 'actor_action',
    0x008D: 'public_chat',
    0x008E: 'self_chat',
    0x0091: 'map_change',
    0x0092: 'map_changed',
    0x0095: 'actor_info',
    0x0097: 'private_message',
    0x0098: 'private_message_sent',
    0x009A: 'system_chat',
    0x009C: 'actor_look_at',
    0x009D: 'item_exists',
    0x009E: 'item_appeared',
    0x00A0: 'inventory_item_added',
    0x00A1: 'item_disappeared',
    0x00A3: 'inventory_items_stackable',
    0x00A4: 'inventory_items_nonstackable',
    0x00A5: 'storage_items_stackable',
    0x00A6: 'storage_items_nonstackable',
    0x00A8: 'use_item',
    0x00AA: 'equip_item',
    0x00AC: 'unequip_item',
    0x00AF: 'inventory_item_removed',
    0x00B0: 'stat_info',
    0x00B1: 'stat_info',
    0x00B3: 'switch_character',
    0x00B4: 'npc_talk',
    0x00B5: 'npc_talk_continue',
    0x00B6: 'npc_talk_close',
    0x00B7: 'npc_talk_responses',
    0x00BC: 'stats_added',
    0x00BD: 'stats_info',
    0x00BE: 'stat_info',
    0x00C0: 'emoticon',
    0x00C2: 'users_online',
    0x00C3: 'sprite_change',
    0x00C4: 'npc_store_begin',
    0x00C6: 'npc_store_info',
    0x00C7: 'npc_sell_list',
    0x00CA: 'buy_result',
    0x00CB: 'sell_result',
    0x00D1: 'ignore_player_result',
    0x00D2: 'ignore_all_result',
    0x00D4: 'whisper_list',
    0x00D6: 'chat_created',
    0x00D7: 'chat_info',
    0x00D8: 'chat_removed',
    0x00DA: 'chat_join_result',
    0x00DB: 'chat_users',
    0x00DC: 'chat_user_join',
    0x00DD: 'chat_user_leave',
    0x00DF: 'chat_modified',
    0x00E1: 'chat_newowner',
    0x00E5: 'deal_request',
    0x00E7: 'deal_begin',
    0x0A09: 'deal_add_other',
    0x00EA: 'deal_add_you',
    0x00EC: 'deal_finalize',
    0x00EE: 'deal_cancelled',
    0x00F0: 'deal_complete',
    0x00F2: 'storage_opened',
    0x0A0A: 'storage_item_added',
    0x00F6: 'storage_item_removed',
    0x00F8: 'storage_closed',
    0x00FA: 'party_organize_result',
    0x00FB: 'party_users_info',
    0x00FD: 'party_invite_result',
    0x00FE: 'party_invite',
    0x0101: 'party_exp',
    0x0104: 'party_join',
    0x0105: 'party_leave',
    0x0106: 'party_hp_info',
    0x0107: 'party_location',
    0x0108: 'item_upgrade',
    0x0109: 'party_chat',
    0x010A: 'mvp_item',
    0x010B: 'mvp_you',
    0x010C: 'mvp_other',
    0x010E: 'skill_update',
    0x010F: 'skills_list',
    0x0110: 'skill_use_failed',
    0x0111: 'skill_add',
    0x0114: 'skill_use',
    0x0117: 'skill_use_location',
    0x0119: 'character_status',
    0x011A: 'skill_used_no_damage',
    0x011C: 'warp_portal_list',
    0x011E: 'memo_success',
    0x011F: 'area_spell',
    0x0120: 'area_spell_disappears',
    0x0121: 'cart_info',
    0x0122: 'cart_items_nonstackable',
    0x0123: 'cart_items_stackable',
    0x0124: 'cart_item_added',
    0x0125: 'cart_item_removed',
    0x012B: 'cart_off',
    0x012C: 'cart_add_failed',
    0x012D: 'shop_skill',
    0x0131: 'vender_found',
    0x0132: 'vender_lost',
    0x0133: 'vender_items_list',
    0x0135: 'vender_buy_fail',
    0x0136: 'vending_start',
    0x0137: 'shop_sold',
    0x0139: 'monster_ranged_attack',
    0x013A: 'attack_range',
    0x013B: 'arrow_none',
    0x013C: 'arrow_equipped',
    0x013D: 'hp_sp_changed',
    0x013E: 'skill_cast',
    0x0141: 'stat_info2',
    0x0142: 'npc_talk_number',
    0x0144: 'minimap_indicator',
    0x0145: 'npc_image',
    0x0147: 'item_skill',
    0x0148: 'resurrection',
    0x014A: 'manner_message',
    0x014B: 'GM_silence',
    0x014C: 'guild_allies_enemy_list',
    0x014E: 'guild_master_member',
    0x0150: 'guild_info',
    0x0152: 'guild_emblem',
    0x0154: 'guild_members_list',
    0x0156: 'guild_update_member_position',
    0x015A: 'guild_leave',
    0x015C: 'guild_expulsion',
    0x015E: 'guild_broken',
    0x0160: 'guild_member_setting_list',
    0x0162: 'guild_skills_list',
    0x0163: 'guild_expulsion_list',
    0x0166: 'guild_members_title_list',
    0x0167: 'guild_create_result',
    0x0169: 'guild_invite_result',
    0x016A: 'guild_request',
    0x016C: 'guild_name',
    0x016D: 'guild_member_online_status',
    0x016F: 'guild_notice',
    0x0171: 'guild_ally_request',
    0x0173: 'guild_alliance',
    0x0174: 'guild_position_changed',
    0x0177: 'identify_list',
    0x0179: 'identify',
    0x017B: 'card_merge_list',
    0x017D: 'card_merge_status',
    0x017F: 'guild_chat',
    0x0181: 'guild_opposition_result',
    0x0182: 'guild_member_add',
    0x0184: 'guild_unally',
    0x0185: 'guild_alliance_added',
    0x0187: 'sync_request',
    0x0188: 'item_upgrade',
    0x0189: 'no_teleport',
    0x018B: 'quit_response',
    0x018C: 'sense_result',
    0x018D: 'makable_item_list',
    0x018F: 'refine_result',
    0x0191: 'talkie_box',
    0x0192: 'map_change_cell',
    0x0194: 'character_name',
    0x0195: 'actor_info',
    0x0196: 'actor_status_active',
    0x0199: 'map_property',
    0x019A: 'pvp_rank',
    0x019B: 'unit_levelup',
    0x019E: 'pet_capture_process',
    0x01A0: 'pet_capture_result',
    0x01A2: 'pet_info',
    0x01A3: 'pet_food',
    0x01A4: 'pet_info2',
    0x01A6: 'egg_list',
    0x01AA: 'pet_emotion',
    0x01AB: 'stat_info',
    0x01AC: 'actor_trapped',
    0x01AD: 'arrowcraft_list',
    0x01B0: 'monster_typechange',
    0x01B3: 'npc_image',
    0x01B4: 'guild_emblem_update',
    0x01B5: 'account_payment_info',
    0x01B6: 'guild_info',
    0x01B9: 'cast_cancelled',
    0x01C1: 'remain_time_info',
    0x01C3: 'local_broadcast',
    0x01C4: 'storage_item_added',
    0x01C5: 'cart_item_added',
    0x01C8: 'item_used',
    0x01C9: 'area_spell',
    0x01CD: 'sage_autospell',
    0x01CF: 'devotion',
    0x01D0: 'revolving_entity',
    0x01D1: 'blade_stop',
    0x01D2: 'combo_delay',
    0x01D3: 'sound_effect',
    0x01D4: 'npc_talk_text',
    0x01D6: 'map_property2',
    0x01D7: 'sprite_change',
    0x01D8: 'actor_exists',
    0x01D9: 'actor_connected',
    0x01DA: 'actor_moved',
    0x01DC: 'secure_login_key',
    0x01DE: 'skill_use',
    0x01E0: 'GM_req_acc_name',
    0x01E1: 'revolving_entity',
    0x01E6: 'marriage_partner_name',
    0x01E9: 'party_join',
    0x01EA: 'married',
    0x01EB: 'guild_location',
    0x01EC: 'guild_member_map_change',
    0x01EE: 'inventory_items_stackable',
    0x01EF: 'cart_items_stackable',
    0x01F0: 'storage_items_stackable',
    0x01F2: 'guild_member_online_status',
    0x01F3: 'misc_effect',
    0x01F4: 'deal_request',
    0x01F5: 'deal_begin',
    0x01F6: 'adopt_request',
    0x01FC: 'repair_list',
    0x01FE: 'repair_result',
    0x01FF: 'high_jump',
    0x0201: 'friend_list',
    0x0205: 'divorced',
    0x0206: 'friend_logon',
    0x0207: 'friend_request',
    0x0209: 'friend_response',
    0x020A: 'friend_removed',
    0x020D: 'character_ban_list',
    0x020E: 'taekwon_packets',
    0x020F: 'pvp_point',
    0x0215: 'gospel_buff_aligned',
    0x0216: 'adopt_reply',
    0x0219: 'top10_blacksmith_rank',
    0x021A: 'top10_alchemist_rank',
    0x021B: 'blacksmith_points',
    0x021C: 'alchemist_point',
    0x0221: 'upgrade_list',
    0x0223: 'upgrade_message',
    0x0224: 'taekwon_rank',
    0x0226: 'top10_taekwon_rank',
    0x0227: 'gameguard_request',
    0x0229: 'character_status',
    0x022A: 'actor_exists',
    0x022B: 'actor_connected',
    0x022C: 'actor_moved',
    0x022E: 'homunculus_property',
    0x022F: 'homunculus_food',
    0x0230: 'homunculus_info',
    0x0235: 'skills_list',
    0x0238: 'top10_pk_rank',
    0x0239: 'skill_update',
    0x023A: 'storage_password_request',
    0x023C: 'storage_password_result',
    0x023E: 'storage_password_request',
    0x0240: 'mail_refreshinbox',
    0x0242: 'mail_read',
    0x0245: 'mail_getattachment',
    0x0249: 'mail_send',
    0x024A: 'mail_new',
    0x0250: 'auction_result',
    0x0252: 'auction_item_request_search',
    0x0253: 'starplace',
    0x0255: 'mail_setattachment',
    0x0256: 'auction_add_item',
    0x0257: 'mail_delete',
    0x0259: 'gameguard_grant',
    0x025A: 'cooking_list',
    0x025D: 'auction_my_sell_stop',
    0x025F: 'auction_windows',
    0x0260: 'mail_window',
    0x0274: 'mail_return',
    0x0276: 'account_server_info',
    0x027B: 'premium_rates_info',
    0x0283: 'account_id',
    0x0284: 'GANSI_RANK',
    0x0287: 'cash_dealer',
    0x0289: 'cash_buy_fail',
    0x028A: 'character_status',
    0x0291: 'message_string',
    0x0293: 'boss_map_info',
    0x0294: 'book_read',
    0x0295: 'inventory_items_nonstackable',
    0x0296: 'storage_items_nonstackable',
    0x0297: 'cart_items_nonstackable',
    0x0298: 'rental_time',
    0x0299: 'rental_expired',
    0x029A: 'inventory_item_added',
    0x029B: 'mercenary_init',
    0x029D: 'skills_list',
    0x02A2: 'stat_info',
    0x02A6: 'gameguard_request',
    0x02AA: 'cash_password_request',
    0x02AC: 'cash_password_result',
    0x02AD: 'login_pin_code_request',
    0x02AE: 'initialize_message_id_encryption',
    0x02B1: 'quest_all_list',
    0x02B2: 'quest_all_mission',
    0x02B3: 'quest_add',
    0x02B4: 'quest_delete',
    0x02B5: 'quest_update_mission_hunt',
    0x02B7: 'quest_active',
    0x02B8: 'party_show_picker',
    0x02B9: 'hotkeys',
    0x02C1: 'npc_chat',
    0x02C5: 'party_invite_result',
    0x02C6: 'party_invite',
    0x02C9: 'party_allow_invite',
    0x02CA: 'login_error_game_login_server',
    0x02CB: 'instance_window_start',
    0x02CC: 'instance_window_queue',
    0x02CD: 'instance_window_join',
    0x02CE: 'instance_window_leave',
    0x02D0: 'inventory_items_nonstackable',
    0x02D1: 'storage_items_nonstackable',
    0x02D2: 'cart_items_nonstackable',
    0x02D4: 'inventory_item_added',
    0x02D5: 'isvr_disconnect',
    0x02D7: 'show_eq',
    0x02D9: 'misc_config_reply',
    0x02DA: 'show_eq_msg_self',
    0x02DC: 'battleground_message',
    0x02DD: 'battleground_emblem',
    0x02DE: 'battleground_score',
    0x02DF: 'battleground_position',
    0x02E0: 'battleground_hp',
    0x02E1: 'actor_action',
    0x02E7: 'map_property',
    0x02E8: 'inventory_items_stackable',
    0x02E9: 'cart_items_stackable',
    0x02EA: 'storage_items_stackable',
    0x02EB: 'map_loaded',
    0x02EC: 'actor_exists',
    0x02ED: 'actor_connected',
    0x02EE: 'actor_moved',
    0x02EF: 'font',
    0x02F0: 'progress_bar',
    0x02F2: 'progress_bar_stop',
    0x02F7: 'guild_name',
    0x040C: 'local_broadcast',
    0x043D: 'skill_post_delay',
    0x043E: 'skill_post_delaylist',
    0x043F: 'actor_status_active',
    0x0440: 'millenium_shield',
    0x0441: 'skill_delete',
    0x0442: 'sage_autospell',
    0x0444: 'cash_item_list',
    0x0446: 'minimap_indicator',
    0x0449: 'hack_shield_alarm',
    0x07D8: 'party_exp',
    0x07D9: 'hotkeys',
    0x07DB: 'stat_info',
    0x07E1: 'skill_update',
    0x07E2: 'message_string',
    0x07E3: 'skill_exchange_item',
    0x07E6: 'skill_msg',
    0x07E8: 'captcha_image',
    0x07E9: 'captcha_answer',
    0x07F6: 'exp',
    0x07F7: 'actor_exists',
    0x07F8: 'actor_connected',
    0x07F9: 'actor_moved',
    0x07FA: 'inventory_item_removed',
    0x07FB: 'skill_cast',
    0x07FC: 'party_leader',
    0x07FD: 'special_item_obtain',
    0x07FE: 'sound_effect',
    0x07FF: 'define_check',
    0x0800: 'vender_items_list',
    0x0803: 'booking_register_request',
    0x0805: 'booking_search_request',
    0x0807: 'booking_delete_request',
    0x0809: 'booking_insert',
    0x080A: 'booking_update',
    0x080B: 'booking_delete',
    0x080E: 'party_hp_info',
    0x080F: 'deal_add_other',
    0x0810: 'open_buying_store',
    0x0812: 'open_buying_store_fail',
    0x0813: 'open_buying_store_item_list',
    0x0814: 'buying_store_found',
    0x0816: 'buying_store_lost',
    0x0818: 'buying_store_items_list',
    0x081A: 'buying_buy_fail',
    0x081B: 'buying_store_update',
    0x081C: 'buying_store_item_delete',
    0x081D: 'elemental_info',
    0x081E: 'stat_info',
    0x0824: 'buying_store_fail',
    0x0828: 'char_delete2_result',
    0x082A: 'char_delete2_accept_result',
    0x082C: 'char_delete2_cancel_result',
    0x082D: 'received_characters_info',
    0x0836: 'search_store_result',
    0x0837: 'search_store_fail',
    0x0839: 'guild_expulsion',
    0x083A: 'search_store_open',
    0x083D: 'search_store_pos',
    0x083E: 'login_error',
    0x0845: 'cash_shop_open_result',
    0x0849: 'cash_shop_buy_result',
    0x084B: 'item_appeared',
    0x0856: 'actor_moved',
    0x0857: 'actor_exists',
    0x0858: 'actor_connected',
    0x0859: 'show_eq',
    0x08B3: 'show_script',
    0x08B4: 'pet_capture_process',
    0x08B6: 'pet_capture_result',
    0x08B9: 'login_pin_code_request',
    0x08BB: 'login_pin_new_code_result',
    0x08C7: 'area_spell',
    0x08C8: 'actor_action',
    0x08CA: 'cash_shop_list',
    0x08CB: 'rates_info',
    0x08CD: 'actor_movement_interrupted',
    0x08CF: 'revolving_entity',
    0x08D2: 'high_jump',
    0x08E2: 'navigate_to',
    0x08FE: 'quest_update_mission_hunt',
    0x08FF: 'actor_status_active',
    0x0900: 'inventory_items_stackable',
    0x0901: 'inventory_items_nonstackable',
    0x0902: 'cart_items_stackable',
    0x0903: 'cart_items_nonstackable',
    0x0906: 'show_eq',
    0x0908: 'inventory_item_favorite',
    0x090F: 'actor_connected',
    0x0914: 'actor_moved',
    0x0915: 'actor_exists',
    0x096D: 'merge_item_open',
    0x096F: 'merge_item_result',
    0x0975: 'storage_items_stackable',
    0x0976: 'storage_items_nonstackable',
    0x0977: 'monster_hp_info',
    0x097A: 'quest_all_list',
    0x097B: 'rates_info2',
    0x097D: 'top10',
    0x097E: 'rank_points',
    0x0983: 'actor_status_active',
    0x0984: 'actor_status_active',
    0x0985: 'skill_post_delaylist',
    0x0988: 'clan_user',
    0x098A: 'clan_info',
    0x098D: 'clan_leave',
    0x098E: 'clan_chat',
    0x0990: 'inventory_item_added',
    0x0991: 'inventory_items_stackable',
    0x0992: 'inventory_items_nonstackable',
    0x0993: 'cart_items_stackable',
    0x0994: 'cart_items_nonstackable',
    0x0995: 'storage_items_stackable',
    0x0996: 'storage_items_nonstackable',
    0x0997: 'show_eq',
    0x0999: 'equip_item',
    0x099A: 'unequip_item',
    0x099B: 'map_property3',
    0x099D: 'received_characters',
    0x099F: 'area_spell_multiple2',
    0x09A0: 'sync_received_characters',
    0x09A6: 'banking_check',
    0x09A8: 'banking_deposit',
    0x09AA: 'banking_withdraw',
    0x09BB: 'storage_opened',
    0x09BF: 'storage_closed',
    0x09CA: 'area_spell_multiple3',
    0x09CB: 'skill_used_no_damage',
    0x09CD: 'message_string',
    0x09CF: 'gameguard_request',
    0x09D1: 'progress_bar_unit',
    0x09D5: 'npc_market_info',
    0x09D7: 'npc_market_purchase_result',
    0x09DA: 'guild_storage_log',
    0x09DB: 'actor_moved',
    0x09DC: 'actor_connected',
    0x09DD: 'actor_exists',
    0x09DE: 'private_message',
    0x09DF: 'private_message_sent',
    0x09E5: 'shop_sold_long',
    0x09E7: 'unread_rodex',
    0x09EB: 'rodex_read_mail',
    0x09ED: 'rodex_write_result',
    0x09F0: 'rodex_mail_list',
    0x09F2: 'rodex_get_zeny',
    0x09F4: 'rodex_get_item',
    0x09F6: 'rodex_delete',
    0x09F7: 'homunculus_property',
    0x09F8: 'quest_all_list',
    0x09F9: 'quest_add',
    0x09FA: 'quest_update_mission_hunt',
    0x09FC: 'pet_evolution_result',
    0x09FF: 'actor_exists',
    0x0A00: 'hotkeys',
    0x0A05: 'rodex_add_item',
    0x0A07: 'rodex_remove_item',
    0x0A0B: 'cart_item_added',
    0x0A0C: 'inventory_item_added',
    0x0A0D: 'inventory_items_nonstackable',
    0x0A0F: 'cart_items_nonstackable',
    0x0A10: 'storage_items_nonstackable',
    0x0A12: 'rodex_open_write',
    0x0A14: 'rodex_check_player',
    0x0A15: 'gold_pc_cafe_point',
    0x0A17: 'dynamicnpc_create_result',
    0x0A18: 'map_loaded',
    0x0A1A: 'roulette_window',
    0x0A1C: 'roulette_info',
    0x0A20: 'roulette_window_update',
    0x0A22: 'roulette_recv_item',
    0x0A23: 'achievement_list',
    0x0A24: 'achievement_update',
    0x0A26: 'achievement_reward_ack',
    0x0A27: 'hp_sp_changed',
    0x0A28: 'open_store_status',
    0x0A2D: 'show_eq',
    0x0A2F: 'change_title',
    0x0A30: 'actor_info',
    0x0A34: 'senbei_amount',
    0x0A36: 'monster_hp_info_tiny',
    0x0A37: 'inventory_item_added',
    0x0A38: 'open_ui',
    0x0A3B: 'hat_effect',
    0x0A43: 'party_join',
    0x0A44: 'party_users_info',
    0x0A47: 'stylist_res',
    0x0A4A: 'private_airship_type',
    0x0A4B: 'map_change',
    0x0A4C: 'map_changed',
    0x0A51: 'rodex_check_player',
    0x0A53: 'captcha_upload_request',
    0x0A55: 'captcha_upload_request_status',
    0x0A57: 'macro_reporter_status',
    0x0A58: 'macro_detector',
    0x0A59: 'macro_detector_image',
    0x0A5B: 'macro_detector_show',
    0x0A5D: 'macro_detector_status',
    0x0A6A: 'captcha_preview',
    0x0A6B: 'captcha_preview_image',
    0x0A6D: 'macro_reporter_select',
    0x0A6F: 'message_string',
    0x0A7B: 'EAC_key',
    0x0A7D: 'rodex_mail_list',
    0x0A82: 'guild_expulsion',
    0x0A83: 'guild_leave',
    0x0A84: 'guild_info',
    0x0A89: 'offline_clone_found',
    0x0A8A: 'offline_clone_lost',
    0x0A8D: 'vender_items_list',
    0x0A91: 'buying_store_items_list',
    0x0A95: 'misc_config',
    0x0A96: 'deal_add_other',
    0x0A98: 'equip_item_switch',
    0x0A9A: 'unequip_item_switch',
    0x0A9B: 'equip_switch_log',
    0x0A9D: 'equip_switch_run_res',
    0x0AA0: 'refineui_opened',
    0x0AA2: 'refineui_info',
    0x0AA5: 'guild_members_list',
    0x0AA8: 'misc_config',
    0x0AB2: 'party_dead',
    0x0AB8: 'move_interrupt',
    0x0AB9: 'item_preview',
    0x0ABD: 'partylv_info',
    0x0ABE: 'warp_portal_list',
    0x0AC2: 'rodex_mail_list',
    0x0AC4: 'account_server_info',
    0x0AC5: 'received_character_ID_and_Map',
    0x0AC7: 'map_changed',
    0x0AC9: 'account_server_info',
    0x0ACA: 'errors',
    0x0ACB: 'stat_info',
    0x0ACC: 'exp',
    0x0ACD: 'login_error',
    0x0ADA: 'refine_status',
    0x0ADC: 'misc_config',
    0x0ADD: 'item_appeared',
    0x0ADE: 'overweight_percent',
    0x0ADF: 'actor_info',
    0x0AE0: 'login_error',
    0x0AE2: 'open_ui',
    0x0AE3: 'received_login_token',
    0x0AE4: 'party_join',
    0x0AE5: 'party_users_info',
    0x0AF0: 'action_ui',
    0x0AF7: 'character_name',
    0x0AFB: 'sage_autospell',
    0x0AFD: 'guild_position',
    0x0AFE: 'quest_update_mission_hunt',
    0x0AFF: 'quest_all_list',
    0x0B03: 'show_eq',
    0x0B05: 'offline_clone_found',
    0x0B08: 'item_list_start',
    0x0B09: 'item_list_stackable',
    0x0B0A: 'item_list_nonstackable',
    0x0B0B: 'item_list_end',
    0x0B0C: 'quest_add',
    0x0B13: 'item_preview',
    0x0B18: 'inventory_expansion_result',
    0x0B1A: 'skill_cast',
    0x0B1B: 'load_confirm',
    0x0B1D: 'ping',
    0x0B20: 'hotkeys',
    0x0B2F: 'homunculus_property',
    0x0B31: 'skill_add',
    0x0B32: 'skills_list',
    0x0B33: 'skill_update',
    0x0B39: 'item_list_nonstackable',
    0x0B3D: 'vender_items_list',
    0x0B41: 'inventory_item_added',
    0x0B44: 'storage_item_added',
    0x0B45: 'cart_item_added',
    0x0B47: 'char_emblem_update',
    0x0B5F: 'rodex_mail_list',
    0x0B60: 'account_server_info',
    0x0B6F: 'character_creation_successful',
    0x0B72: 'received_characters',
    0x0B73: 'revolving_entity',
    0x0B76: 'homunculus_property',
    0x0B77: 'npc_store_info',
    0x0B7B: 'guild_info',
    0x0B7C: 'guild_expulsion_list',
    0x0B7D: 'guild_members_list',
    0x0B7E: 'guild_member_add',
    0x0B8D: 'repute_info',
    0x0BA4: 'homunculus_property',
    0x0C32: 'account_server_info'
}

class PacketPattern:
    """Classe para análise de padrões em pacotes"""
    
    def __init__(self, opcode, data):
        self.opcode = opcode
        self.length = len(data)
        self.data = data
        self.hex_data = data.hex().upper()
        
    def get_structure_signature(self):
        """Gera uma assinatura da estrutura do pacote"""
        if len(self.data) < 2:
            return "empty"
            
        signature = []
        
        # Analisa cada posição para detectar padrões
        for i in range(2, len(self.data)):  # Pula os 2 primeiros bytes (opcode)
            byte_val = self.data[i]
            
            # Detecta padrões comuns
            if byte_val == 0:
                signature.append('0')
            elif 32 <= byte_val <= 126:  # ASCII printável
                signature.append('A')
            elif byte_val == 0xFF:
                signature.append('F')
            else:
                signature.append('X')
        
        return ''.join(signature)

class PacketAnalyzer:
    def __init__(self, target_ip, target_port, interface=None, output_dir=None, quiet=False, filter_opcodes=None):
        self.target_ip = target_ip
        self.target_port = target_port
        self.interface = interface
        self.output_dir = output_dir or "packet_analysis"
        self.quiet = quiet
        self.filter_opcodes = filter_opcodes  # Lista de opcodes para filtrar (None = todos)
        
        # Verifica se o IP é uma rede CIDR
        self.is_network = False
        self.target_network = None
        try:
            # Tenta interpretar como rede CIDR
            self.target_network = ipaddress.ip_network(target_ip, strict=False)
            self.is_network = True
            if not self.quiet:
                print(f"Detectada rede CIDR: {self.target_network}")
        except ValueError:
            # Se não for CIDR, tenta como IP único
            try:
                ipaddress.ip_address(target_ip)
                self.is_network = False
            except ValueError:
                raise ValueError(f"IP/rede inválida: {target_ip}")
        
        # Verifica se a porta é wildcard
        self.any_port = (str(target_port).lower() in ['*', 'any', 'all'])
        if self.any_port and not self.quiet:
            print("Capturando pacotes de qualquer porta")
        
        # Criar diretório de output
        Path(self.output_dir).mkdir(exist_ok=True)
        
        # Estatísticas básicas
        self.packets_received = 0
        self.packets_sent = 0
        self.total_packets = 0
        self.filtered_packets = 0  # Contador de pacotes filtrados
        
        # Análise avançada
        self.opcodes_data = defaultdict(list)  # opcode -> [PacketPattern]
        self.opcode_patterns = defaultdict(Counter)  # opcode -> {structure: count}
        self.opcode_lengths = defaultdict(set)  # opcode -> {lengths}
        self.packet_examples = defaultdict(list)  # opcode -> [raw_data]
        
        # Timeline de pacotes
        self.packet_timeline = []  # Lista com histórico completo de pacotes
        
        # Controle
        self.running = False
        self.start_time = None
        
    def print_header(self):
        """Imprime cabeçalho da aplicação"""
        if not self.quiet:
            print(f"{Fore.CYAN}{'='*80}")
            print(f"{Fore.CYAN}ROla Packet Analyzer - Advanced Pattern Detection")
            
            if self.is_network:
                target_display = f"Network: {self.target_network}"
            else:
                target_display = f"IP: {self.target_ip}"
            
            if self.any_port:
                target_display += " | Port: ANY"
            else:
                target_display += f" | Port: {self.target_port}"
                
            print(f"{Fore.CYAN}{target_display}")
            print(f"{Fore.CYAN}Output Dir: {self.output_dir}")
            if self.interface:
                print(f"{Fore.CYAN}Interface: {self.interface}")
            
            # Mostra informações sobre filtros de opcodes
            if self.filter_opcodes:
                opcodes_str = ', '.join(f'0x{opcode:04X}' for opcode in self.filter_opcodes)
                print(f"{Fore.YELLOW}Filtro Opcodes: {opcodes_str}")
                # Mostra os nomes dos pacotes se conhecidos
                opcode_names = []
                for opcode in self.filter_opcodes:
                    send_name = SEND_PACKETS.get(opcode)
                    recv_name = RECV_PACKETS.get(opcode)
                    if send_name and recv_name:
                        opcode_names.append(f"{send_name}/{recv_name}")
                    elif send_name:
                        opcode_names.append(f"{send_name} (send)")
                    elif recv_name:
                        opcode_names.append(f"{recv_name} (recv)")
                    else:
                        opcode_names.append("unknown")
                
                if opcode_names:
                    print(f"{Fore.YELLOW}Tipos: {', '.join(opcode_names)}")
            
            print(f"{Fore.CYAN}{'='*80}{Style.RESET_ALL}")
            print()
    
    def analyze_packet_structure(self, data):
        """Analisa a estrutura de um pacote e sugere formato Perl"""
        if len(data) < 2:
            return None, []
            
        # Extrai componentes
        components = []
        param_names = []
        pos = 2  # Pula opcode
        
        # Analisa tamanho total
        total_len = len(data)
        
        # Detecta padrões comuns
        while pos < total_len:
            remaining = total_len - pos
            
            if remaining >= 4:
                # Testa se pode ser um ID de 4 bytes
                bytes_4 = data[pos:pos+4]
                if self._looks_like_id(bytes_4):
                    components.append('a4')
                    param_names.append('targetID')
                    pos += 4
                    continue
            
            if remaining >= 2:
                # Testa se pode ser um short (v)
                short_val = struct.unpack('<H', data[pos:pos+2])[0]
                if self._looks_like_length_or_id(short_val, remaining):
                    components.append('v')
                    param_names.append('len' if short_val == total_len else 'value')
                    pos += 2
                    continue
            
            if remaining >= 1:
                # Verifica se é string ASCII
                string_len = self._detect_string_length(data, pos)
                if string_len > 0:
                    if data[pos + string_len - 1] == 0:  # Null-terminated
                        components.append(f'Z{string_len}')
                        param_names.append('string_data')
                    else:
                        components.append(f'a{string_len}')
                        param_names.append('data')
                    pos += string_len
                    continue
                
                # Single byte
                components.append('C')
                param_names.append('byte_value')
                pos += 1
        
        # Se sobrou dados, adiciona como a*
        if pos < total_len:
            components.append('a*')
            param_names.append('remaining_data')
        
        format_template = ' '.join(components)
        return format_template, param_names
    
    def _looks_like_id(self, bytes_data):
        """Verifica se 4 bytes parecem um ID"""
        # IDs geralmente não são todos zeros ou todos 0xFF
        if bytes_data == b'\x00\x00\x00\x00' or bytes_data == b'\xFF\xFF\xFF\xFF':
            return False
        # Se tem pelo menos um byte não-zero
        return any(b != 0 for b in bytes_data)
    
    def _looks_like_length_or_id(self, value, remaining_bytes):
        """Verifica se um valor de 2 bytes parece um tamanho ou ID"""
        # Tamanhos válidos são geralmente <= remaining bytes
        if value <= remaining_bytes + 2:  # +2 para o próprio campo
            return True
        # IDs podem ser qualquer valor
        return True
    
    def _detect_string_length(self, data, start_pos):
        """Detecta o comprimento de uma string ASCII"""
        pos = start_pos
        ascii_count = 0
        
        while pos < len(data):
            byte_val = data[pos]
            
            # Null terminator
            if byte_val == 0:
                return pos - start_pos + 1
            
            # ASCII printável
            if 32 <= byte_val <= 126:
                ascii_count += 1
                pos += 1
                if ascii_count >= 3:  # Pelo menos 3 chars ASCII consecutivos
                    continue
            else:
                break
        
        # Retorna tamanho se encontrou string ASCII válida
        return pos - start_pos if ascii_count >= 3 else 0
    
    def identify_packet_type(self, opcode, direction):
        """Identifica o tipo de pacote baseado no opcode e direção"""
        if direction == "SEND":
            return SEND_PACKETS.get(opcode, f'unknown_send_0x{opcode:04X}')
        else:
            return RECV_PACKETS.get(opcode, f'unknown_recv_0x{opcode:04X}')
        
    def generate_packet_name(self, opcode, pattern):
        """Gera nome sugerido para o pacote"""
        opcode_hex = f"{opcode:04X}"
        
        # Nomes conhecidos baseados em padrões comuns
        if 'Z' in pattern and 'a4' in pattern:
            return 'login_packet'
        elif 'a4' in pattern and 'C' in pattern:
            return 'actor_action'
        elif pattern.count('v') >= 2:
            return 'coordinate_packet'
        elif 'a*' in pattern:
            return 'variable_data'
        else:
            return f'packet_{opcode_hex.lower()}'
        
    def format_packet_data(self, data, direction, timestamp):
        """Formata os dados do pacote para análise"""
        if len(data) < 2:
            return None
            
        # Extrai opcode
        opcode = struct.unpack('<H', data[:2])[0]
        
        # Cria padrão do pacote
        pattern = PacketPattern(opcode, data)
        self.opcodes_data[opcode].append(pattern)
        
        # Analisa estrutura
        structure_sig = pattern.get_structure_signature()
        self.opcode_patterns[opcode][structure_sig] += 1
        self.opcode_lengths[opcode].add(len(data))
        
        # Salva exemplo (máximo 10 por opcode)
        if len(self.packet_examples[opcode]) < 10:
            self.packet_examples[opcode].append({
                'direction': direction,
                'timestamp': timestamp.isoformat(),
                'data': data.hex().upper(),
                'length': len(data)
            })
        
        # Identifica o tipo de pacote
        packet_type = self.identify_packet_type(opcode, direction)
        
        # Adiciona ao timeline
        timeline_entry = {
            'timestamp': timestamp.isoformat(),
            'time_formatted': timestamp.strftime('%H:%M:%S.%f')[:-3],
            'direction': direction,
            'opcode': f'0x{opcode:04X}',
            'opcode_int': opcode,
            'packet_type': packet_type,
            'length': len(data),
            'data_hex': data.hex().upper(),
            'data_raw': ' '.join(f'{b:02X}' for b in data),
            'is_known': opcode in (SEND_PACKETS if direction == "SEND" else RECV_PACKETS)
        }
        
        self.packet_timeline.append(timeline_entry)
        
        if not self.quiet:
            # Cor baseada na direção
            if direction == "RECV":
                color = Fore.GREEN
                direction_text = f"{Back.BLACK}{Fore.GREEN} RECV {Style.RESET_ALL}"
            else:
                color = Fore.BLUE
                direction_text = f"{Back.BLACK}{Fore.BLUE} SEND {Style.RESET_ALL}"
            
            print(f"{color}[{timestamp.strftime('%H:%M:%S.%f')[:-3]}] {direction_text} "
                  f"Opcode: 0x{opcode:04X} | Size: {len(data)} bytes{Style.RESET_ALL}")
            
            # Dump hexadecimal simples
            hex_data = ' '.join(f'{b:02X}' for b in data)
            print(f"{Fore.YELLOW}Raw: {hex_data}{Style.RESET_ALL}")
            print("-" * 60)
        
        return opcode
        
    def print_hex_dump(self, data):
        """Imprime dump hexadecimal formatado"""
        bytes_per_line = 16
        
        for i in range(0, len(data), bytes_per_line):
            # Offset
            offset = f"{i:04X}:"
            print(f"{Fore.BLUE}{offset:<6}{Style.RESET_ALL}", end="")
            
            # Bytes em hex
            hex_part = ""
            ascii_part = ""
            
            for j in range(bytes_per_line):
                if i + j < len(data):
                    byte_val = data[i + j]
                    hex_part += f"{byte_val:02X} "
                    
                    # Parte ASCII
                    if 32 <= byte_val <= 126:
                        ascii_part += chr(byte_val)
                    else:
                        ascii_part += "."
                else:
                    hex_part += "   "
                    ascii_part += " "
                    
                # Espaço extra no meio
                if j == 7:
                    hex_part += " "
            
            print(f"{Fore.GREEN}{hex_part}{Style.RESET_ALL} | {Fore.RED}{ascii_part}{Style.RESET_ALL}")
            
    def _ip_matches_target(self, ip_str):
        """Verifica se um IP corresponde ao target (IP único ou rede)"""
        try:
            ip_addr = ipaddress.ip_address(ip_str)
            if self.is_network:
                return ip_addr in self.target_network
            else:
                return str(ip_addr) == self.target_ip
        except:
            return False
    
    def _port_matches_target(self, port):
        """Verifica se uma porta corresponde ao target"""
        if self.any_port:
            return True
        return port == self.target_port

    def packet_handler(self, packet):
        """Processa cada pacote capturado"""
        try:
            if not packet.haslayer(TCP) or not packet.haslayer(IP):
                return
                
            ip_layer = packet[IP]
            tcp_layer = packet[TCP]
            
            # Verifica se é o IP/rede e porta que queremos monitorar
            src_ip_matches = self._ip_matches_target(ip_layer.src)
            dst_ip_matches = self._ip_matches_target(ip_layer.dst)
            src_port_matches = self._port_matches_target(tcp_layer.sport)
            dst_port_matches = self._port_matches_target(tcp_layer.dport)
            
            is_from_server = src_ip_matches and src_port_matches
            is_to_server = dst_ip_matches and dst_port_matches
            
            if not (is_from_server or is_to_server):
                return
                
            # Extrai payload
            if tcp_layer.payload:
                payload = bytes(tcp_layer.payload)
                if len(payload) >= 2:
                    # Extrai opcode para verificar filtro
                    opcode = struct.unpack('<H', payload[:2])[0]
                    
                    # Aplica filtro de opcodes se especificado
                    if self.filter_opcodes and opcode not in self.filter_opcodes:
                        self.filtered_packets += 1
                        return
                    
                    timestamp = datetime.now()
                    
                    if is_from_server:
                        direction = "RECV"
                        self.packets_received += 1
                    else:
                        direction = "SEND"
                        self.packets_sent += 1
                    
                    self.total_packets += 1
                    
                    # Analisa o pacote
                    self.format_packet_data(payload, direction, timestamp)
                    
        except Exception as e:
            if not self.quiet:
                print(f"{Fore.RED}Erro ao processar pacote: {e}{Style.RESET_ALL}")
            
    def print_statistics(self):
        """Imprime estatísticas dos pacotes"""
        if self.total_packets == 0 or self.quiet:
            return
            
        print(f"\n{Fore.CYAN}{'='*60}")
        print(f"ESTATÍSTICAS DE ANÁLISE")
        print(f"{'='*60}{Style.RESET_ALL}")
        
        elapsed = (datetime.now() - self.start_time).total_seconds()
        
        # Estatísticas de pacotes conhecidos vs desconhecidos
        known_packets = sum(1 for entry in self.packet_timeline if entry['is_known'])
        unknown_packets = len(self.packet_timeline) - known_packets
        
        print(f"{Fore.WHITE}Tempo de execução: {elapsed:.1f}s")
        print(f"Total de pacotes: {self.total_packets}")
        print(f"Pacotes recebidos: {self.packets_received}")
        print(f"Pacotes enviados: {self.packets_sent}")
        
        # Mostra estatísticas de filtro se aplicável
        if self.filter_opcodes:
            print(f"Pacotes filtrados: {self.filtered_packets}")
            print(f"Taxa de filtragem: {(self.filtered_packets/(self.total_packets + self.filtered_packets)*100):.1f}%" if (self.total_packets + self.filtered_packets) > 0 else "0%")
        
        print(f"Opcodes únicos: {len(self.opcodes_data)}")
        print(f"Pacotes conhecidos: {known_packets}")
        print(f"Pacotes desconhecidos: {unknown_packets}")
        print(f"Taxa de identificação: {(known_packets/len(self.packet_timeline)*100):.1f}%" if self.packet_timeline else "0%")
        print(f"Taxa: {self.total_packets/elapsed:.2f} pacotes/s{Style.RESET_ALL}")
        
        if self.opcodes_data:
            print(f"\n{Fore.YELLOW}Top 10 Opcodes Analisados:{Style.RESET_ALL}")
            sorted_opcodes = sorted(self.opcodes_data.items(), key=lambda x: len(x[1]), reverse=True)[:10]
            
            print(f"{'Opcode':<8} {'Count':<8} {'Lengths':<15} {'Patterns'}")
            print("-" * 50)
            
            for opcode, patterns in sorted_opcodes:
                lengths = list(self.opcode_lengths[opcode])
                pattern_count = len(self.opcode_patterns[opcode])
                
                lengths_str = str(lengths[0]) if len(lengths) == 1 else f"{min(lengths)}-{max(lengths)}"
                
                print(f"0x{opcode:04X}   {len(patterns):<8} {lengths_str:<15} {pattern_count}")
        
        print()
    
    def start_statistics_thread(self):
        """Thread para imprimir estatísticas periodicamente"""
        def stats_loop():
            counter = 0
            while self.running:
                time.sleep(1)  # Verifica a cada segundo
                counter += 1
                if counter >= 30 and self.running:  # Estatísticas a cada 30 segundos
                    self.print_statistics()
                    counter = 0
                    
        if not self.quiet:
            thread = threading.Thread(target=stats_loop, daemon=True)
            thread.start()
        
    def save_packet_timeline(self):
        """Salva timeline completo dos pacotes"""
        # Timeline em formato JSON estruturado
        timeline_json_file = Path(self.output_dir) / "packet_timeline.json"
        with open(timeline_json_file, 'w', encoding='utf-8') as f:
            json.dump(self.packet_timeline, f, indent=2, ensure_ascii=False)
        
        # Timeline em formato texto organizado e legível
        timeline_txt_file = Path(self.output_dir) / "packet_timeline.txt"
        with open(timeline_txt_file, 'w', encoding='utf-8') as f:
            f.write("═" * 100 + "\n")
            f.write("TIMELINE DE PACOTES - ANÁLISE ROla PACKET ANALYZER\n")
            f.write("═" * 100 + "\n")
            
            if self.is_network:
                target_str = f"Target Network: {self.target_network}"
            else:
                target_str = f"Target IP: {self.target_ip}"
            
            if self.any_port:
                target_str += " | Port: ANY"
            else:
                target_str += f" | Port: {self.target_port}"
                
            f.write(f"{target_str}\n")
            f.write(f"Análise iniciada: {self.start_time.isoformat() if self.start_time else 'N/A'}\n")
            f.write(f"Total de pacotes: {len(self.packet_timeline)}\n")
            f.write("═" * 100 + "\n\n")
            
            # Escreve cada pacote do timeline
            for entry in self.packet_timeline:
                # Cabeçalho do pacote
                known_status = "✓ CONHECIDO" if entry['is_known'] else "⚠ DESCONHECIDO"
                direction_symbol = "←" if entry['direction'] == "RECV" else "→"
                
                f.write(f"[{entry['time_formatted']}] {direction_symbol} {entry['direction']} - {entry['opcode']} ({entry['packet_type']}) - {known_status}\n")
                f.write(f"Tamanho: {entry['length']} bytes\n")
                
                # Dados do pacote em hexadecimal formatado
                f.write("Dados: ")
                hex_data = entry['data_raw']
                # Quebra linha a cada 32 bytes (64 caracteres hex + espaços)
                line_length = 48  # 16 bytes * 3 chars cada (XX ) = 48 chars
                for i in range(0, len(hex_data), line_length):
                    if i > 0:
                        f.write("       ")  # Indentação para linhas subsequentes
                    f.write(hex_data[i:i+line_length] + "\n")
                
                # Separador entre pacotes
                f.write("-" * 80 + "\n\n")
        
        # Timeline em formato CSV para análise em planilhas
        timeline_csv_file = Path(self.output_dir) / "packet_timeline.csv"
        with open(timeline_csv_file, 'w', encoding='utf-8') as f:
            f.write("Timestamp,Time_Formatted,Direction,Opcode,Packet_Type,Length,Is_Known,Data_Hex\n")
            for entry in self.packet_timeline:
                f.write(f'"{entry["timestamp"]}","{entry["time_formatted"]}","{entry["direction"]}",')
                f.write(f'"{entry["opcode"]}","{entry["packet_type"]}",{entry["length"]},')
                f.write(f'{entry["is_known"]},"{entry["data_hex"]}"\n')
                
        if not self.quiet:
            print(f"{Fore.GREEN}Timeline salvo em:{Style.RESET_ALL}")
            print(f"  • JSON: {timeline_json_file}")
            print(f"  • TXT:  {timeline_txt_file}")
            print(f"  • CSV:  {timeline_csv_file}")

    def save_packet_examples(self):
        """Salva exemplos de pacotes em pastas por opcode"""
        examples_dir = Path(self.output_dir) / "examples"
        examples_dir.mkdir(exist_ok=True)
        
        for opcode, examples in self.packet_examples.items():
            opcode_dir = examples_dir / f"0x{opcode:04X}"
            opcode_dir.mkdir(exist_ok=True)
            
            # Salva exemplos individuais
            for i, example in enumerate(examples):
                example_file = opcode_dir / f"example_{i+1}.json"
                with open(example_file, 'w', encoding='utf-8') as f:
                    json.dump(example, f, indent=2, ensure_ascii=False)
            
            # Salva resumo do opcode
            summary = {
                'opcode': f"0x{opcode:04X}",
                'total_examples': len(examples),
                'unique_lengths': list(self.opcode_lengths[opcode]),
                'patterns': dict(self.opcode_patterns[opcode])
            }
            
            summary_file = opcode_dir / "summary.json"
            with open(summary_file, 'w', encoding='utf-8') as f:
                json.dump(summary, f, indent=2, ensure_ascii=False)
    
    def generate_perl_analysis(self):
        """Gera análise completa com sugestões de formato Perl"""
        analysis = {
            'session_info': {
                'target_ip': str(self.target_network) if self.is_network else self.target_ip,
                'target_port': 'ANY' if self.any_port else self.target_port,
                'is_network': self.is_network,
                'any_port': self.any_port,
                'start_time': self.start_time.isoformat() if self.start_time else None,
                'end_time': datetime.now().isoformat(),
                'total_packets': self.total_packets,
                'packets_received': self.packets_received,
                'packets_sent': self.packets_sent,
                'filtered_packets': self.filtered_packets,
                'filter_opcodes': [f'0x{opcode:04X}' for opcode in self.filter_opcodes] if self.filter_opcodes else None
            },
            'opcode_analysis': {},
            'perl_suggestions': {}
        }
        
        for opcode, patterns in self.opcodes_data.items():
            if not patterns:
                continue
                
            # Analisa o padrão mais comum
            most_common_pattern = patterns[0]  # Pega o primeiro como exemplo
            format_template, param_names = self.analyze_packet_structure(most_common_pattern.data)
            packet_name = self.generate_packet_name(opcode, format_template or '')
            
            # Estatísticas do opcode
            opcode_hex = f"0x{opcode:04X}"
            lengths = list(self.opcode_lengths[opcode])
            pattern_distribution = dict(self.opcode_patterns[opcode])
            
            analysis['opcode_analysis'][opcode_hex] = {
                'count': len(patterns),
                'unique_lengths': lengths,
                'is_fixed_length': len(lengths) == 1,
                'pattern_distribution': pattern_distribution,
                'examples_count': len(self.packet_examples[opcode])
            }
            
            # Sugestão Perl
            if format_template and param_names:
                perl_suggestion = {
                    'packet_name': packet_name,
                    'format_template': format_template,
                    'parameter_names': param_names,
                    'perl_format': f"'{opcode:04X}' => ['{packet_name}', '{format_template}', [qw({' '.join(param_names)})]]"
                }
                
                analysis['perl_suggestions'][opcode_hex] = perl_suggestion
        
        return analysis
    
    def save_analysis_report(self):
        """Salva relatório completo da análise"""
        if not self.quiet:
            print(f"\n{Fore.CYAN}Gerando relatório de análise...{Style.RESET_ALL}")
        
        # Gera análise
        analysis = self.generate_perl_analysis()
        
        # Salva relatório principal
        report_file = Path(self.output_dir) / "packet_analysis_report.json"
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(analysis, f, indent=2, ensure_ascii=False)
        
        # Salva sugestões Perl em formato mais legível
        perl_file = Path(self.output_dir) / "perl_suggestions.txt"
        with open(perl_file, 'w', encoding='utf-8') as f:
            f.write("# ROla Packet Analysis - Perl Format Suggestions\n")
            f.write(f"# Generated: {datetime.now().isoformat()}\n")
            if self.is_network:
                target_str = f"# Target Network: {self.target_network}"
            else:
                target_str = f"# Target IP: {self.target_ip}"
            
            if self.any_port:
                target_str += " | Port: ANY"
            else:
                target_str += f" | Port: {self.target_port}"
                
            f.write(f"{target_str}\n")
            
            # Adiciona informações sobre filtros se aplicados
            if self.filter_opcodes:
                opcodes_str = ', '.join(f'0x{opcode:04X}' for opcode in self.filter_opcodes)
                f.write(f"# Filtered Opcodes: {opcodes_str}\n")
                f.write(f"# Filtered Packets: {self.filtered_packets}\n")
            
            f.write("\n")
            
            f.write("# Packet format suggestions:\n")
            for opcode_hex, suggestion in analysis['perl_suggestions'].items():
                f.write(f"\n# {opcode_hex} - {suggestion['packet_name']}\n")
                f.write(f"{suggestion['perl_format']},\n")
                
                # Adiciona comentários explicativos
                format_parts = suggestion['format_template'].split()
                param_parts = suggestion['parameter_names']
                
                if len(format_parts) == len(param_parts):
                    f.write("# ")
                    for fmt, param in zip(format_parts, param_parts):
                        f.write(f"{fmt}={param}, ")
                    f.write("\n")
        
        # Salva exemplos por opcode
        self.save_packet_examples()
        
        # Salva timeline de pacotes
        self.save_packet_timeline()
        
        if not self.quiet:
            print(f"{Fore.GREEN}Relatório salvo em: {report_file}{Style.RESET_ALL}")
            print(f"{Fore.GREEN}Sugestões Perl salvas em: {perl_file}{Style.RESET_ALL}")
            print(f"{Fore.GREEN}Exemplos salvos em: {Path(self.output_dir) / 'examples'}{Style.RESET_ALL}")
        
    def _signal_handler(self, signum, frame):
        """Manipulador de sinal para Ctrl+C"""
        if not self.quiet:
            print(f"\n{Fore.YELLOW}Sinal de interrupção recebido. Parando análise...{Style.RESET_ALL}")
        self.running = False
        
    def _setup_signal_handlers(self):
        """Configura manipuladores de sinal multiplataforma"""
        signal.signal(signal.SIGINT, self._signal_handler)
        
        # Para Windows, também configura SIGBREAK se disponível
        if hasattr(signal, 'SIGBREAK'):
            signal.signal(signal.SIGBREAK, self._signal_handler)
        
        # Para sistemas Unix, também configura SIGTERM
        if hasattr(signal, 'SIGTERM'):
            signal.signal(signal.SIGTERM, self._signal_handler)
        
    def start_capture(self):
        """Inicia a captura de pacotes"""
        # Configura manipuladores de sinal para Ctrl+C
        self._setup_signal_handlers()
        
        try:
            self.print_header()
            
            # Constrói filtro BPF baseado no target
            if self.is_network:
                # Para redes, usa net em vez de host
                if self.any_port:
                    bpf_filter = f"tcp and net {self.target_network}"
                else:
                    bpf_filter = f"tcp and net {self.target_network} and port {self.target_port}"
            else:
                # Para IP único
                if self.any_port:
                    bpf_filter = f"tcp and host {self.target_ip}"
                else:
                    bpf_filter = f"tcp and host {self.target_ip} and port {self.target_port}"
            
            if not self.quiet:
                print(f"{Fore.GREEN}Iniciando análise de pacotes...")
                print(f"Filtro: {bpf_filter}")
                if self.interface:
                    print(f"Interface: {self.interface}")
                print(f"{Fore.CYAN}═══ PRESSIONE Ctrl+C PARA PARAR E GERAR RELATÓRIO ═══{Style.RESET_ALL}\n")
            
            self.running = True
            self.start_time = datetime.now()
            
            # Inicia thread de estatísticas
            self.start_statistics_thread()
            
            # Inicia captura com timeout para tornar mais responsivo
            while self.running:
                try:
                    # Usar timeout menor para ser mais responsivo ao Ctrl+C
                    packets = sniff(
                        iface=self.interface,
                        filter=bpf_filter,
                        prn=self.packet_handler,
                        store=0,
                        timeout=0.5,  # Timeout de 0.5 segundo para verificar self.running
                        stop_filter=lambda p: not self.running
                    )
                    
                    # Se não capturou pacotes e ainda está rodando, continua
                    if not self.running:
                        break
                        
                except Exception as e:
                    if self.running:  # Só mostra erro se ainda estiver rodando
                        if not self.quiet:
                            print(f"{Fore.RED}Erro durante captura: {e}{Style.RESET_ALL}")
                        time.sleep(0.1)  # Pequena pausa antes de tentar novamente
                    break
            
        except KeyboardInterrupt:
            if not self.quiet:
                print(f"\n{Fore.YELLOW}Análise interrompida pelo usuário{Style.RESET_ALL}")
        except PermissionError:
            print(f"{Fore.RED}Erro: Permissões insuficientes. Execute como administrador/root{Style.RESET_ALL}")
        except Exception as e:
            print(f"{Fore.RED}Erro durante análise: {e}{Style.RESET_ALL}")
        finally:
            self.running = False
            if not self.quiet:
                print(f"\n{Fore.CYAN}═══ FINALIZANDO ANÁLISE ═══{Style.RESET_ALL}")
            self.print_statistics()
            self.save_analysis_report()
            if not self.quiet:
                print(f"\n{Fore.GREEN}✓ Análise concluída com sucesso!{Style.RESET_ALL}")
            
    def stop_capture(self):
        """Para a captura"""
        self.running = False

def parse_opcodes(opcodes_str):
    """Parse opcodes from string format. Supports hex (0x09CF) and decimal (2511)"""
    if not opcodes_str:
        return None
    
    opcodes = []
    parts = opcodes_str.split(',')
    
    for part in parts:
        part = part.strip()
        if not part:
            continue
            
        try:
            # Try hex format first (0x09CF)
            if part.lower().startswith('0x'):
                opcode = int(part, 16)
            else:
                # Try decimal format
                opcode = int(part)
            
            if 0 <= opcode <= 0xFFFF:
                opcodes.append(opcode)
            else:
                raise ValueError(f"Opcode {part} fora do range válido (0-65535)")
                
        except ValueError as e:
            raise ValueError(f"Opcode inválido '{part}': {e}")
    
    return opcodes if opcodes else None

def analyze_log_file(log_file):
    """Analisa um arquivo de log salvo anteriormente"""
    try:
        with open(log_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            
        print(f"{Fore.CYAN}{'='*60}")
        print(f"ANÁLISE DO LOG: {log_file}")
        print(f"{'='*60}{Style.RESET_ALL}")
        
        session_info = data.get('session_info', {})
        print(f"Target: {session_info.get('target_ip')}:{session_info.get('target_port')}")
        print(f"Início: {session_info.get('start_time')}")
        print(f"Fim: {session_info.get('end_time')}")
        print()
        
        stats = data.get('statistics', {})
        print(f"Total de pacotes: {stats.get('total_packets', 0)}")
        print(f"Pacotes recebidos: {stats.get('packets_received', 0)}")
        print(f"Pacotes enviados: {stats.get('packets_sent', 0)}")
        print(f"Opcodes únicos: {stats.get('unique_opcodes', 0)}")
        print()
        
        if 'packet_types' in stats:
            print(f"{Fore.YELLOW}Opcodes mais frequentes:{Style.RESET_ALL}")
            sorted_opcodes = sorted(stats['packet_types'].items(), key=lambda x: x[1], reverse=True)[:10]
            
            for opcode_str, count in sorted_opcodes:
                opcode = int(opcode_str)
                print(f"0x{opcode:04X}: {count} pacotes")
        
    except Exception as e:
        print(f"{Fore.RED}Erro ao analisar log: {e}{Style.RESET_ALL}")

def get_available_interfaces():
    """Lista interfaces de rede disponíveis com nomes amigáveis"""
    try:
        from scapy.arch import get_if_list
        from scapy.config import conf
        
        interfaces = []
        
        # Tenta usar as interfaces do Scapy com nomes amigáveis
        if hasattr(conf, 'ifaces'):
            for iface_name, iface in conf.ifaces.items():
                try:
                    # Pega informações da interface
                    name = iface.name if hasattr(iface, 'name') else iface_name
                    description = iface.description if hasattr(iface, 'description') else None
                    
                    # Cria nome amigável
                    if description and description != name:
                        friendly_name = f"{name} ({description})"
                    else:
                        friendly_name = name
                    
                    # Simplifica nomes conhecidos do Windows
                    if "Loopback" in friendly_name:
                        friendly_name = "Loopback Interface"
                    elif "Ethernet" in description if description else False:
                        friendly_name = f"Ethernet - {description.split('Ethernet')[-1].strip()}"
                    elif "Wi-Fi" in description if description else False:
                        friendly_name = f"Wi-Fi - {description.split('Wi-Fi')[-1].strip()}"
                    elif "Wireless" in description if description else False:
                        friendly_name = f"Wireless - {description.split('Wireless')[-1].strip()}"
                    
                    interfaces.append({
                        'name': name,
                        'friendly_name': friendly_name,
                        'description': description
                    })
                except:
                    continue
        
        # Fallback para lista básica se não conseguir informações detalhadas
        if not interfaces:
            basic_interfaces = get_if_list()
            for iface in basic_interfaces:
                interfaces.append({
                    'name': iface,
                    'friendly_name': iface,
                    'description': None
                })
        
        return interfaces
    except Exception as e:
        print(f"Erro ao obter interfaces: {e}")
        return []

def main():
    parser = argparse.ArgumentParser(
        description="ROla Packet Analyzer - Analisa padrões e gera sugestões Perl",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos de uso:
  python packet_analyzer.py 192.168.1.100 6900
  python packet_analyzer.py 172.65.0.0/16 *
  python packet_analyzer.py 35.198.41.33 10009 -o analysis_output
  python packet_analyzer.py 10.0.0.0/8 any -i "Wi-Fi" -q
  python packet_analyzer.py 192.168.1.100 6900 --filter-opcodes 0x09CF,0x09D0
  python packet_analyzer.py 10.0.0.1 6900 --filter-opcodes 2511,2512 -q
        """
    )
    
    parser.add_argument('ip', nargs='?', help='IP/rede do servidor para monitorar (ex: 192.168.1.100 ou 172.65.0.0/16)')
    parser.add_argument('port', nargs='?', help='Porta do servidor para monitorar (número ou * para qualquer porta)')
    parser.add_argument('-i', '--interface', help='Interface de rede específica (use nome ou número da lista)')
    parser.add_argument('-o', '--output', help='Arquivo para salvar os pacotes capturados (JSON)')
    parser.add_argument('-q', '--quiet', action='store_true', help='Modo silencioso (apenas estatísticas)')
    parser.add_argument('--analyze', help='Analisa um arquivo de log existente')
    parser.add_argument('--list-interfaces', action='store_true', 
                       help='Lista as interfaces de rede disponíveis')
    parser.add_argument('--filter-opcodes', 
                       help='Filtra apenas opcodes específicos (ex: 0x09CF,0x09D0 para GameGuard ou 2511,2512)')
    
    args = parser.parse_args()
    
    # Análise de arquivo de log
    if args.analyze:
        analyze_log_file(args.analyze)
        return
    
    # Lista interfaces se solicitado
    if args.list_interfaces:
        interfaces = get_available_interfaces()
        print(f"{Fore.CYAN}Interfaces de rede disponíveis:{Style.RESET_ALL}")
        print()
        
        for i, iface in enumerate(interfaces, 1):
            print(f"{Fore.WHITE}{i:2d}.{Style.RESET_ALL} {Fore.GREEN}{iface['friendly_name']}{Style.RESET_ALL}")
            if iface['description'] and iface['description'] != iface['friendly_name']:
                print(f"     {Fore.YELLOW}Descrição: {iface['description']}{Style.RESET_ALL}")
            print(f"     {Fore.CYAN}Nome técnico: {iface['name']}{Style.RESET_ALL}")
            print()
        
        print(f"{Fore.YELLOW}Dica: Use o número, nome amigável ou nome técnico com -i{Style.RESET_ALL}")
        return
    
    # Valida argumentos
    if not args.ip or args.port is None:
        parser.print_help()
        return
        
    # Valida IP/rede
    try:
        # Primeiro tenta como rede CIDR
        try:
            ipaddress.ip_network(args.ip, strict=False)
        except ValueError:
            # Se não for CIDR, tenta como IP único
            ipaddress.ip_address(args.ip)
    except ValueError:
        print(f"{Fore.RED}Erro: IP/rede inválida '{args.ip}'. Use formato IP (192.168.1.100) ou CIDR (172.65.0.0/16){Style.RESET_ALL}")
        return
        
    # Valida porta
    port_str = str(args.port).lower()
    if port_str in ['*', 'any', 'all']:
        target_port = '*'
    else:
        try:
            target_port = int(args.port)
            if not (1 <= target_port <= 65535):
                print(f"{Fore.RED}Erro: Porta deve estar entre 1 e 65535 ou usar * para qualquer porta{Style.RESET_ALL}")
                return
        except (ValueError, TypeError):
            print(f"{Fore.RED}Erro: Porta inválida '{args.port}'. Use um número (1-65535) ou * para qualquer porta{Style.RESET_ALL}")
            return
    
    # Parse opcodes filter
    filter_opcodes = None
    if args.filter_opcodes:
        try:
            filter_opcodes = parse_opcodes(args.filter_opcodes)
            if filter_opcodes and not args.quiet:
                opcodes_str = ', '.join(f'0x{opcode:04X}' for opcode in filter_opcodes)
                print(f"Filtro de opcodes aplicado: {opcodes_str}")
        except ValueError as e:
            print(f"{Fore.RED}Erro: {e}{Style.RESET_ALL}")
            return
    
    # Resolve interface se especificada
    interface_name = None
    if args.interface:
        interfaces = get_available_interfaces()
        
        # Tenta encontrar por número
        try:
            interface_index = int(args.interface) - 1
            if 0 <= interface_index < len(interfaces):
                interface_name = interfaces[interface_index]['name']
                if not args.quiet:
                    print(f"Usando interface: {interfaces[interface_index]['friendly_name']}")
            else:
                print(f"{Fore.RED}Erro: Número de interface inválido. Use --list-interfaces{Style.RESET_ALL}")
                return
        except ValueError:
            # Tenta encontrar por nome amigável ou técnico
            found = False
            for iface in interfaces:
                if (args.interface.lower() in iface['friendly_name'].lower() or 
                    args.interface == iface['name']):
                    interface_name = iface['name']
                    if not args.quiet:
                        print(f"Usando interface: {iface['friendly_name']}")
                    found = True
                    break
            
            if not found:
                print(f"{Fore.RED}Erro: Interface '{args.interface}' não encontrada. Use --list-interfaces{Style.RESET_ALL}")
                return
    
    # Gera nome de diretório padrão se necessário
    output_dir = args.output
    if not output_dir:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        # Sanitiza nome do arquivo removendo caracteres especiais
        safe_ip = args.ip.replace('/', '_').replace(':', '_')
        safe_port = str(target_port).replace('*', 'any')
        output_dir = f"analysis_{safe_ip}_{safe_port}_{timestamp}"
        
        # Adiciona info do filtro no nome do diretório
        if filter_opcodes:
            opcodes_str = '_'.join(f'{opcode:04X}' for opcode in filter_opcodes)
            output_dir += f"_opcodes_{opcodes_str}"
        
        if not args.quiet:
            print(f"Salvando análise em: {output_dir}")
    
    # Cria e inicia o analisador
    analyzer = PacketAnalyzer(args.ip, target_port, interface_name, output_dir, args.quiet, filter_opcodes)
    
    try:
        analyzer.start_capture()
    except KeyboardInterrupt:
        if not args.quiet:
            print(f"\n{Fore.YELLOW}Programa encerrado{Style.RESET_ALL}")

if __name__ == "__main__":
    main() 