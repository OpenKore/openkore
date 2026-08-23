# LastRO 封包长度参考（网页客户端 69.35）

> 快照日期：2026-08-23<br>
> 客户端来源：[Online.js?69.35](https://post.lastro.cn/ro/Online.js?69.35)<br>
> 对照表：`tables/kRO/Ragexe_2021_11_03/recvpackets.txt`<br>
> 范围：网页客户端已注册的 **629 个 ZC（服务器 → 客户端）封包**。

## 结论与本次修复

LastRO 的自动念咒流程使用的发送封包 `CZ.SELECTAUTOSPELL` 是 `0x01CE`：
`u16 switch (0x01CE) + u32 SKID`，总长 **6 字节**。现有 `sendAutoSpell` 的编码与网页客户端一致，
因此不能把该发送封包本身当作断线根因。地图初始化还包括一个独立的挑战流程：收到 `0AD5`
后必须按网页算法回复 `0AFA`，否则地图服务器会等待确认并超时断线。

此前已经修复 `ZC.NOTIFY_SETTARGET`（`0x0AF1`）：网页客户端定义为
`u16 switch + u32 mobid + u8 value`，总长 **7 字节**；原表错写为 `102`。日志中的连续帧
`F1 0A 3B 04 00 00 01` 也直接验证了该长度。

本轮根据同一网页客户端中逐字段的固定结构，核对并修正了 **45 个新增条目**（连同已修复的 `0AF1`，共 **46 个已确认条目**）。其中 `0AD2` 和 `0AF9` 是按剩余数据计算记录数的变长列表，已改为 `-1`；`0AF8` 与 `0AF1` 都是 7 字节目标通知；`0AFA` 的网页结构是两个 24 字节名称、一个 AID 和一个拒绝码，总长 58 字节。

这些长度由浏览器端的读取字段直接相加得到，并不把“同名但属于其他协议世代”的定义混用。这样可以避免固定长度过大吞掉后续封包，或固定长度过小留下半包，导致 TCP 接收流失步。

## 审计结果

| 结果 | 数量 | 含义 |
| --- | ---: | --- |
| 一致 | 601 | 网页客户端静态长度与 OpenKore 表一致 |
| 长度不一致（待调查） | 0 | 尚未有足够证据修改的差异 |
| 表缺失 | 15 | 网页客户端注册了封包，而当前表没有该 switch |
| 动态/未静态声明 | 10 | JS 没有为该注册项提供静态 `.size` 值 |
| 条件/占位（保留） | 2 | JS 的 `.size=0` 是条件解析占位，不是线上的实际长度 |
| LastRO 特殊处理（保留） | 1 | LastRO 专用分帧，不能按通用网页定义替换 |

当前审计中没有未处理的固定长度差异；保留项是有意的协议分支，不是遗漏。

## 已确认的保留项

- `00AA REQ_WEAR_EQUIP_ACK`：网页脚本把 `.size` 写成 0，但解析体按日期条件读取 9 字节；表中保留 9。
- `0999 ACK_WEAR_EQUIP_V5`：同样是占位长度，字段结构实际读取 11 字节；表中保留 11。
- `0AD6 CARDCONNECTION_RECHARGE_LIST`：网页脚本声明变长，但 LastRO 先发送 2 字节标记，再发送由 `0000` 接收的 2560 字节零帧；表中保留 2，并由 LastRO 专用 receiver 处理。
- `0AD5 SECOND_CHECK`：网页脚本确认其接收长度为 10 字节。LastRO 地图服务器会发送这个请求，但实测 OpenKore 自动回复 10 字节 `0AFA CHECK_BIN` 后会被断开；因此仅按 10 字节解析以维持接收流同步，不自动发送确认包。网页端的回复逻辑不能单独证明该回复可用于 OpenKore 的地图进入状态。
- 网页脚本会重复定义同名 ZC。审计按 switch 选择定义：`011A USE_SKILL` 使用 15，`01D6 NOTIFY_MAPPROPERTY2` 使用 4，`099B NOTIFY_MAPPROPERTY2` 使用 8；不能用名称的最后一次赋值覆盖全部世代。

## 使用规则

- `ZC` 是服务器发给客户端的封包；本表只审计网页客户端的 ZC 注册表，不替代发送封包定义。
- 固定长度为总字节数，包含 2 字节 little-endian switch；`-1` 表示由封包长度字段决定的变长包。
- `.size=0` 在该网页脚本中表示旧式/条件解析占位，不能直接写入 `recvpackets.txt`。
- 更新 `recvpackets.txt` 前，应同时确认 switch 对应的网页字段结构、协议世代和 LastRO 原始接收数据；错误的固定长度会使后续整个 TCP 流失步。
- 重新审计时，固定记录来源 URL、客户端版本，并按“注册号 → ZC 名称 → switch 对应的 `.size`”生成结果；同名定义必须保留候选值。

## 完整对照表

| Switch | 网页客户端 ZC 名称 | JS 静态长度 | OpenKore 长度 | 结果 | 证据/说明 |
| --- | --- | ---: | ---: | --- | --- |
| `0003` | `ES_RESULT` | 6 | — | 表缺失 |  |
| `0073` | `ACCEPT_ENTER` | 11 | 11 | 一致 |  |
| `0074` | `REFUSE_ENTER` | 3 | 3 | 一致 |  |
| `0075` | `NOTIFY_INITCHAR` | 11 | 11 | 一致 | 网页客户端固定结构（本轮核对） |
| `0076` | `NOTIFY_UPDATECHAR` | 9 | 9 | 一致 |  |
| `0077` | `NOTIFY_UPDATEPLAYER` | 5 | 5 | 一致 |  |
| `0078` | `NOTIFY_STANDENTRY` | 58 | 58 | 一致 | 网页客户端固定结构（本轮核对） |
| `0079` | `NOTIFY_NEWENTRY` | 53 | 53 | 一致 |  |
| `007A` | `NOTIFY_ACTENTRY` | 58 | 58 | 一致 |  |
| `007B` | `NOTIFY_MOVEENTRY` | 60 | 60 | 一致 |  |
| `007C` | `NOTIFY_STANDENTRY_NPC` | 42 | 42 | 一致 | 网页客户端固定结构（本轮核对） |
| `007F` | `NOTIFY_TIME` | 6 | 6 | 一致 |  |
| `0080` | `NOTIFY_VANISH` | 7 | 7 | 一致 |  |
| `0083` | `ACCEPT_QUIT` | 2 | 2 | 一致 |  |
| `0084` | `REFUSE_QUIT` | 2 | 2 | 一致 |  |
| `0086` | `NOTIFY_MOVE` | 16 | 16 | 一致 |  |
| `0087` | `NOTIFY_PLAYERMOVE` | 12 | 12 | 一致 |  |
| `0088` | `STOPMOVE` | 10 | 10 | 一致 |  |
| `008A` | `NOTIFY_ACT` | 29 | 29 | 一致 |  |
| `008B` | `NOTIFY_ACT_POSITION` | 23 | 23 | 一致 |  |
| `008D` | `NOTIFY_CHAT` | -1 | -1 | 一致 |  |
| `008E` | `NOTIFY_PLAYERCHAT` | -1 | -1 | 一致 |  |
| `008F` | `ENTRY_ACK` | 6 | — | 表缺失 |  |
| `0091` | `NPCACK_MAPMOVE` | 22 | 22 | 一致 |  |
| `0092` | `NPCACK_SERVERMOVE` | 28 | 28 | 一致 |  |
| `0093` | `NPCACK_ENABLE` | 2 | 2 | 一致 |  |
| `0095` | `ACK_REQNAME` | 30 | 30 | 一致 |  |
| `0096` | `UNK1` | 4 | 4 | 一致 | 网页客户端固定结构（本轮核对） |
| `0098` | `ACK_WHISPER` | 3 | 3 | 一致 |  |
| `009A` | `BROADCAST` | -1 | -1 | 一致 |  |
| `009C` | `CHANGE_DIRECTION` | 9 | 9 | 一致 |  |
| `009D` | `ITEM_ENTRY` | — | 19 | 动态/未静态声明 |  |
| `009E` | `ITEM_FALL_ENTRY` | 17 | 17 | 一致 | 网页客户端固定结构（本轮核对） |
| `00A0` | `ITEM_PICKUP_ACK` | 23 | 23 | 一致 | 网页客户端固定结构（本轮核对） |
| `00A1` | `ITEM_DISAPPEAR` | 6 | 6 | 一致 |  |
| `00A3` | `NORMAL_ITEMLIST` | -1 | -1 | 一致 |  |
| `00A4` | `EQUIPMENT_ITEMLIST` | -1 | -1 | 一致 |  |
| `00A5` | `STORE_NORMAL_ITEMLIST` | -1 | -1 | 一致 |  |
| `00A6` | `STORE_EQUIPMENT_ITEMLIST` | -1 | -1 | 一致 |  |
| `00A8` | `USE_ITEM_ACK` | 7 | 7 | 一致 |  |
| `00AA` | `REQ_WEAR_EQUIP_ACK` | 0 | 9 | 条件/占位（保留） | JS .size=0 是条件占位；当前日期分支实际读取 9 字节 |
| `00AC` | `REQ_TAKEOFF_EQUIP_ACK` | 7 | 7 | 一致 |  |
| `00AF` | `ITEM_THROW_ACK` | 6 | 6 | 一致 |  |
| `00B0` | `PAR_CHANGE` | 8 | 8 | 一致 |  |
| `00B1` | `LONGPAR_CHANGE` | 8 | 8 | 一致 |  |
| `00B3` | `RESTART_ACK` | 3 | 3 | 一致 |  |
| `00B4` | `SAY_DIALOG` | -1 | -1 | 一致 |  |
| `00B5` | `WAIT_DIALOG` | 6 | 6 | 一致 |  |
| `00B6` | `CLOSE_DIALOG` | 6 | 6 | 一致 |  |
| `00B7` | `MENU_LIST` | -1 | -1 | 一致 |  |
| `00BC` | `STATUS_CHANGE_ACK` | 6 | 6 | 一致 |  |
| `00BD` | `STATUS` | 44 | 44 | 一致 |  |
| `00BE` | `STATUS_CHANGE` | 5 | 5 | 一致 |  |
| `00C0` | `EMOTION` | 7 | 7 | 一致 |  |
| `00C2` | `USER_COUNT` | 6 | 6 | 一致 |  |
| `00C3` | `SPRITE_CHANGE` | 8 | 8 | 一致 |  |
| `00C4` | `SELECT_DEALTYPE` | 6 | 6 | 一致 |  |
| `00C6` | `PC_PURCHASE_ITEMLIST` | -1 | -1 | 一致 |  |
| `00C7` | `PC_SELL_ITEMLIST` | -1 | -1 | 一致 |  |
| `00CA` | `PC_PURCHASE_RESULT` | 3 | 3 | 一致 |  |
| `00CB` | `PC_SELL_RESULT` | 3 | 3 | 一致 |  |
| `00CD` | `ACK_DISCONNECT_CHARACTER` | 3 | 3 | 一致 |  |
| `00D1` | `SETTING_WHISPER_PC` | 4 | 4 | 一致 |  |
| `00D2` | `SETTING_WHISPER_STATE` | 4 | 4 | 一致 |  |
| `00D4` | `WHISPER_LIST` | -1 | -1 | 一致 |  |
| `00D6` | `ACK_CREATE_CHATROOM` | 3 | 3 | 一致 |  |
| `00D7` | `ROOM_NEWENTRY` | -1 | -1 | 一致 |  |
| `00D8` | `DESTROY_ROOM` | 6 | 6 | 一致 |  |
| `00DA` | `REFUSE_ENTER_ROOM` | 3 | 3 | 一致 |  |
| `00DB` | `ENTER_ROOM` | -1 | -1 | 一致 |  |
| `00DC` | `MEMBER_NEWENTRY` | 28 | 28 | 一致 |  |
| `00DD` | `MEMBER_EXIT` | 29 | 29 | 一致 |  |
| `00DF` | `CHANGE_CHATROOM` | -1 | -1 | 一致 |  |
| `00E1` | `ROLE_CHANGE` | 30 | 30 | 一致 |  |
| `00E5` | `REQ_EXCHANGE_ITEM` | 26 | 26 | 一致 |  |
| `00E7` | `ACK_EXCHANGE_ITEM` | 3 | 3 | 一致 |  |
| `00E9` | `ADD_EXCHANGE_ITEM` | 19 | 19 | 一致 | 网页客户端固定结构（本轮核对） |
| `00EA` | `ACK_ADD_EXCHANGE_ITEM` | 5 | 5 | 一致 |  |
| `00EC` | `CONCLUDE_EXCHANGE_ITEM` | 3 | 3 | 一致 |  |
| `00EE` | `CANCEL_EXCHANGE_ITEM` | 2 | 2 | 一致 |  |
| `00F0` | `EXEC_EXCHANGE_ITEM` | 3 | 3 | 一致 |  |
| `00F1` | `EXCHANGEITEM_UNDO` | 2 | 2 | 一致 |  |
| `00F2` | `NOTIFY_STOREITEM_COUNTINFO` | 6 | 6 | 一致 |  |
| `00F4` | `ADD_ITEM_TO_STORE` | 21 | 21 | 一致 | 网页客户端固定结构（本轮核对） |
| `00F6` | `DELETE_ITEM_FROM_STORE` | 8 | 8 | 一致 |  |
| `00F8` | `CLOSE_STORE` | 2 | 2 | 一致 |  |
| `00FA` | `ACK_MAKE_GROUP` | 3 | 3 | 一致 |  |
| `00FB` | `GROUP_LIST` | -1 | -1 | 一致 |  |
| `00FD` | `ACK_REQ_JOIN_GROUP` | 27 | 27 | 一致 |  |
| `00FE` | `REQ_JOIN_GROUP` | 30 | 30 | 一致 |  |
| `0101` | `GROUPINFO_CHANGE` | 6 | 6 | 一致 |  |
| `0104` | `ADD_MEMBER_TO_GROUP` | 79 | 79 | 一致 |  |
| `0105` | `DELETE_MEMBER_FROM_GROUP` | 31 | 31 | 一致 |  |
| `0106` | `NOTIFY_HP_TO_GROUPM` | 10 | 10 | 一致 |  |
| `0107` | `NOTIFY_POSITION_TO_GROUPM` | 10 | 10 | 一致 |  |
| `0109` | `NOTIFY_CHAT_PARTY` | -1 | -1 | 一致 |  |
| `010A` | `MVP_GETTING_ITEM` | 6 | 6 | 一致 |  |
| `010B` | `MVP_GETTING_SPECIAL_EXP` | 6 | 6 | 一致 |  |
| `010C` | `MVP` | 6 | 6 | 一致 |  |
| `010D` | `THROW_MVPITEM` | 2 | 2 | 一致 |  |
| `010E` | `SKILLINFO_UPDATE` | 11 | 11 | 一致 |  |
| `010F` | `SKILLINFO_LIST` | -1 | -1 | 一致 |  |
| `0110` | `ACK_TOUSESKILL` | — | 14 | 动态/未静态声明 |  |
| `0111` | `ADD_SKILL` | 39 | 39 | 一致 |  |
| `0114` | `NOTIFY_SKILL` | 31 | 31 | 一致 |  |
| `0115` | `NOTIFY_SKILL_POSITION` | 35 | 35 | 一致 |  |
| `0117` | `NOTIFY_GROUNDSKILL` | 18 | 18 | 一致 |  |
| `0119` | `STATE_CHANGE` | 13 | 13 | 一致 |  |
| `011A` | `USE_SKILL` | 15 | 15 | 一致 | 同名定义候选：15、17（按 switch 匹配） |
| `011C` | `WARPLIST` | 68 | 68 | 一致 |  |
| `011E` | `ACK_REMEMBER_WARPPOINT` | 3 | 3 | 一致 |  |
| `011F` | `SKILL_ENTRY` | 16 | 16 | 一致 |  |
| `0120` | `SKILL_DISAPPEAR` | 6 | 6 | 一致 |  |
| `0121` | `NOTIFY_CARTITEM_COUNTINFO` | 14 | 14 | 一致 |  |
| `0122` | `CART_EQUIPMENT_ITEMLIST` | -1 | -1 | 一致 |  |
| `0123` | `CART_NORMAL_ITEMLIST` | -1 | -1 | 一致 |  |
| `0124` | `ADD_ITEM_TO_CART` | 21 | 21 | 一致 | 网页客户端固定结构（本轮核对） |
| `0125` | `DELETE_ITEM_FROM_CART` | 8 | 8 | 一致 |  |
| `012B` | `CARTOFF` | 2 | 2 | 一致 |  |
| `012C` | `ACK_ADDITEM_TO_CART` | 3 | 3 | 一致 |  |
| `012D` | `OPENSTORE` | 4 | 4 | 一致 |  |
| `0131` | `STORE_ENTRY` | 86 | 86 | 一致 |  |
| `0132` | `DISAPPEAR_ENTRY` | 6 | 6 | 一致 |  |
| `0133` | `PC_PURCHASE_ITEMLIST_FROMMC` | -1 | -1 | 一致 |  |
| `0135` | `PC_PURCHASE_RESULT_FROMMC` | 7 | 7 | 一致 |  |
| `0136` | `PC_PURCHASE_MYITEMLIST` | -1 | -1 | 一致 |  |
| `0137` | `DELETEITEM_FROM_MCSTORE` | 6 | 6 | 一致 |  |
| `0139` | `ATTACK_FAILURE_FOR_DISTANCE` | 16 | 16 | 一致 |  |
| `013A` | `ATTACK_RANGE` | 4 | 4 | 一致 |  |
| `013B` | `ACTION_FAILURE` | 4 | 4 | 一致 |  |
| `013C` | `EQUIP_ARROW` | 4 | 4 | 一致 |  |
| `013D` | `RECOVERY` | 6 | 6 | 一致 |  |
| `013E` | `USESKILL_ACK` | 24 | 24 | 一致 |  |
| `0141` | `COUPLESTATUS` | 14 | 14 | 一致 |  |
| `0142` | `OPEN_EDITDLG` | 6 | 6 | 一致 |  |
| `0144` | `COMPASS` | 23 | 23 | 一致 |  |
| `0145` | `SHOW_IMAGE` | 19 | 19 | 一致 |  |
| `0147` | `AUTORUN_SKILL` | 39 | 39 | 一致 |  |
| `0148` | `RESURRECTION` | 8 | 8 | 一致 |  |
| `014A` | `ACK_GIVE_MANNER_POINT` | 6 | 6 | 一致 |  |
| `014B` | `NOTIFY_MANNER_POINT_GIVEN` | 27 | 27 | 一致 |  |
| `014C` | `MYGUILD_BASIC_INFO` | -1 | -1 | 一致 |  |
| `014E` | `ACK_GUILD_MENUINTERFACE` | 6 | 6 | 一致 |  |
| `0150` | `GUILD_INFO` | 110 | 110 | 一致 |  |
| `0152` | `GUILD_EMBLEM_IMG` | -1 | -1 | 一致 |  |
| `0154` | `MEMBERMGR_INFO` | -1 | -1 | 一致 |  |
| `0156` | `ACK_REQ_CHANGE_MEMBERS` | -1 | -1 | 一致 |  |
| `0158` | `ACK_OPEN_MEMBER_INFO` | 2 | — | 表缺失 |  |
| `015A` | `ACK_LEAVE_GUILD` | 66 | 66 | 一致 |  |
| `015C` | `ACK_BAN_GUILD` | 90 | 90 | 一致 |  |
| `015E` | `ACK_DISORGANIZE_GUILD_RESULT` | 6 | 6 | 一致 |  |
| `015F` | `ACK_DISORGANIZE_GUILD` | 42 | 42 | 一致 |  |
| `0160` | `POSITION_INFO` | -1 | -1 | 一致 |  |
| `0162` | `GUILD_SKILLINFO` | -1 | -1 | 一致 |  |
| `0164` | `OTHER_GUILD_LIST` | -1 | -1 | 一致 |  |
| `0166` | `POSITION_ID_NAME_INFO` | -1 | -1 | 一致 |  |
| `0167` | `RESULT_MAKE_GUILD` | 3 | 3 | 一致 |  |
| `0169` | `ACK_REQ_JOIN_GUILD` | 3 | 3 | 一致 |  |
| `016A` | `REQ_JOIN_GUILD` | 30 | 30 | 一致 |  |
| `016C` | `UPDATE_GDID` | 43 | 43 | 一致 |  |
| `016D` | `UPDATE_CHARSTAT` | 14 | 14 | 一致 |  |
| `016F` | `GUILD_NOTICE` | 182 | 182 | 一致 |  |
| `0171` | `REQ_ALLY_GUILD` | 30 | 30 | 一致 |  |
| `0173` | `ACK_REQ_ALLY_GUILD` | 3 | 3 | 一致 |  |
| `0174` | `ACK_CHANGE_GUILD_POSITIONINFO` | -1 | -1 | 一致 |  |
| `0176` | `ACK_GUILD_MEMBER_INFO` | 106 | 106 | 一致 |  |
| `0177` | `ITEMIDENTIFY_LIST` | -1 | -1 | 一致 |  |
| `0179` | `ACK_ITEMIDENTIFY` | 5 | 5 | 一致 |  |
| `017B` | `ITEMCOMPOSITION_LIST` | -1 | -1 | 一致 |  |
| `017D` | `ACK_ITEMCOMPOSITION` | 7 | 7 | 一致 |  |
| `017F` | `GUILD_CHAT` | -1 | -1 | 一致 |  |
| `0181` | `ACK_REQ_HOSTILE_GUILD` | 3 | 3 | 一致 |  |
| `0182` | `MEMBER_ADD` | 106 | 106 | 一致 |  |
| `0184` | `DELETE_RELATED_GUILD` | 10 | 10 | 一致 |  |
| `0185` | `ADD_RELATED_GUILD` | 34 | 34 | 一致 |  |
| `0186` | `COLLECTORDEAD` | 6 | — | 表缺失 |  |
| `0188` | `ACK_ITEMREFINING` | 8 | 8 | 一致 |  |
| `0189` | `NOTIFY_MAPINFO` | 4 | 4 | 一致 |  |
| `018B` | `ACK_REQ_DISCONNECT` | 4 | 4 | 一致 |  |
| `018C` | `MONSTER_INFO` | 29 | 29 | 一致 |  |
| `018D` | `MAKABLEITEMLIST` | -1 | -1 | 一致 |  |
| `018F` | `ACK_REQMAKINGITEM` | — | 8 | 动态/未静态声明 |  |
| `0191` | `TALKBOX_CHATCONTENTS` | 86 | 86 | 一致 | 网页客户端固定结构（本轮核对） |
| `0192` | `UPDATE_MAPINFO` | 24 | 24 | 一致 |  |
| `0194` | `ACK_REQNAME_BYGID` | 30 | 30 | 一致 |  |
| `0195` | `ACK_REQNAMEALL` | 102 | 102 | 一致 |  |
| `0196` | `MSG_STATE_CHANGE` | 9 | 9 | 一致 |  |
| `0199` | `NOTIFY_MAPPROPERTY` | 4 | 4 | 一致 |  |
| `019A` | `NOTIFY_RANKING` | 14 | 14 | 一致 |  |
| `019B` | `NOTIFY_EFFECT` | 10 | 10 | 一致 |  |
| `019E` | `START_CAPTURE` | 2 | 2 | 一致 |  |
| `01A0` | `TRYCAPTURE_MONSTER` | 3 | 3 | 一致 |  |
| `01A2` | `PROPERTY_PET` | 37 | 37 | 一致 |  |
| `01A3` | `FEED_PET` | 7 | 7 | 一致 |  |
| `01A4` | `CHANGESTATE_PET` | 11 | 11 | 一致 |  |
| `01A6` | `PETEGG_LIST` | -1 | -1 | 一致 |  |
| `01AA` | `PET_ACT` | 10 | 10 | 一致 |  |
| `01AB` | `PAR_CHANGE_USER` | 12 | 12 | 一致 |  |
| `01AC` | `SKILL_UPDATE` | 6 | 6 | 一致 |  |
| `01AD` | `MAKINGARROW_LIST` | -1 | -1 | 一致 |  |
| `01B0` | `NPCSPRITE_CHANGE` | 11 | 11 | 一致 |  |
| `01B1` | `SHOWDIGIT` | 7 | 7 | 一致 |  |
| `01B3` | `SHOW_IMAGE2` | 67 | 67 | 一致 |  |
| `01B4` | `CHANGE_GUILD` | 12 | 12 | 一致 |  |
| `01B6` | `GUILD_INFO2` | 114 | 114 | 一致 |  |
| `01B8` | `GUILD_ZENY_ACK` | 3 | 3 | 一致 |  |
| `01B9` | `DISPEL` | 6 | 6 | 一致 |  |
| `01C1` | `REPLY_REMAINTIME` | 14 | 14 | 一致 |  |
| `01C2` | `INFO_REMAINTIME` | 10 | 10 | 一致 |  |
| `01C3` | `BROADCAST2` | -1 | -1 | 一致 |  |
| `01C4` | `ADD_ITEM_TO_STORE2` | 22 | 22 | 一致 | 网页客户端固定结构（本轮核对） |
| `01C5` | `ADD_ITEM_TO_CART2` | 22 | 22 | 一致 | 网页客户端固定结构（本轮核对） |
| `01C8` | `USE_ITEM_ACK2` | — | 15 | 动态/未静态声明 |  |
| `01C9` | `SKILL_ENTRY2` | 97 | 97 | 一致 |  |
| `01CC` | `MONSTER_TALK` | 9 | 9 | 一致 |  |
| `01CD` | `AUTOSPELLLIST` | 30 | 30 | 一致 |  |
| `01CF` | `DEVOTIONLIST` | 28 | 28 | 一致 |  |
| `01D0` | `SPIRITS` | 8 | 8 | 一致 |  |
| `01D1` | `BLADESTOP` | 14 | 14 | 一致 |  |
| `01D2` | `COMBODELAY` | 10 | 10 | 一致 |  |
| `01D3` | `SOUND` | 35 | 35 | 一致 |  |
| `01D4` | `OPEN_EDITDLGSTR` | 6 | 6 | 一致 |  |
| `01D6` | `NOTIFY_MAPPROPERTY2` | 4 | 4 | 一致 | 同名定义候选：4、8（按 switch 匹配） |
| `01D7` | `SPRITE_CHANGE2` | — | 15 | 动态/未静态声明 |  |
| `01D8` | `NOTIFY_STANDENTRY2` | 54 | 54 | 一致 | 网页客户端固定结构（本轮核对） |
| `01D9` | `NOTIFY_NEWENTRY2` | 53 | 53 | 一致 | 网页客户端固定结构（本轮核对） |
| `01DA` | `NOTIFY_MOVEENTRY2` | 60 | 60 | 一致 | 网页客户端固定结构（本轮核对） |
| `01DE` | `NOTIFY_SKILL2` | 33 | 33 | 一致 |  |
| `01E0` | `ACK_ACCOUNTNAME` | 30 | 30 | 一致 |  |
| `01E1` | `SPIRITS2` | 8 | 8 | 一致 |  |
| `01E2` | `REQ_COUPLE` | 34 | 34 | 一致 |  |
| `01E4` | `START_COUPLE` | 2 | 2 | 一致 |  |
| `01E6` | `COUPLENAME` | 26 | 26 | 一致 |  |
| `01E9` | `ADD_MEMBER_TO_GROUP2` | 81 | 81 | 一致 |  |
| `01EA` | `CONGRATULATION` | 6 | 6 | 一致 |  |
| `01EB` | `NOTIFY_POSITION_TO_GUILDM` | 10 | 10 | 一致 |  |
| `01EC` | `GUILD_MEMBER_MAP_CHANGE` | 26 | 26 | 一致 |  |
| `01EE` | `NORMAL_ITEMLIST2` | -1 | -1 | 一致 |  |
| `01EF` | `CART_NORMAL_ITEMLIST2` | -1 | -1 | 一致 |  |
| `01F0` | `STORE_NORMAL_ITEMLIST2` | -1 | -1 | 一致 |  |
| `01F2` | `UPDATE_CHARSTAT2` | 20 | 20 | 一致 |  |
| `01F3` | `NOTIFY_EFFECT2` | 10 | 10 | 一致 |  |
| `01F4` | `REQ_EXCHANGE_ITEM2` | 32 | 32 | 一致 |  |
| `01F5` | `ACK_EXCHANGE_ITEM2` | 9 | 9 | 一致 |  |
| `01F6` | `REQ_BABY` | 34 | 34 | 一致 |  |
| `01F8` | `START_BABY` | 2 | 2 | 一致 |  |
| `01FC` | `REPAIRITEMLIST` | -1 | -1 | 一致 |  |
| `01FE` | `ACK_ITEMREPAIR` | 5 | 5 | 一致 |  |
| `01FF` | `HIGHJUMP` | 10 | 10 | 一致 |  |
| `0201` | `FRIENDS_LIST` | -1 | -1 | 一致 |  |
| `0205` | `DIVORCE` | 26 | 26 | 一致 |  |
| `0206` | `FRIENDS_STATE` | 35 | 35 | 一致 |  |
| `0207` | `REQ_ADD_FRIENDS` | 34 | 34 | 一致 |  |
| `0209` | `ADD_FRIENDS_LIST` | 36 | 36 | 一致 |  |
| `020A` | `DELETE_FRIENDS` | 10 | 10 | 一致 |  |
| `020E` | `STARSKILL` | 32 | 32 | 一致 |  |
| `0210` | `ACK_PVPPOINT` | 22 | 22 | 一致 |  |
| `0214` | `ACK_STATUS_GM` | 42 | 42 | 一致 |  |
| `0215` | `SKILLMSG` | 6 | 6 | 一致 |  |
| `0216` | `BABYMSG` | 6 | 6 | 一致 |  |
| `0219` | `BLACKSMITH_RANK` | 282 | 282 | 一致 |  |
| `021A` | `ALCHEMIST_RANK` | 282 | 282 | 一致 |  |
| `021B` | `BLACKSMITH_POINT` | 10 | 10 | 一致 |  |
| `021C` | `ALCHEMIST_POINT` | 10 | 10 | 一致 |  |
| `021E` | `LESSEFFECT` | 6 | 6 | 一致 |  |
| `021F` | `NOTIFY_PKINFO` | 66 | 66 | 一致 |  |
| `0220` | `NOTIFY_CRAZYKILLER` | 10 | 10 | 一致 |  |
| `0221` | `NOTIFY_WEAPONITEMLIST` | -1 | -1 | 一致 |  |
| `0223` | `ACK_WEAPONREFINE` | 8 | 8 | 一致 | 网页客户端固定结构（本轮核对） |
| `0224` | `TAEKWON_POINT` | 10 | 10 | 一致 |  |
| `0226` | `TAEKWON_RANK` | 282 | 282 | 一致 |  |
| `0227` | `GAME_GUARD` | 18 | 18 | 一致 |  |
| `0229` | `STATE_CHANGE3` | 15 | 15 | 一致 |  |
| `022A` | `NOTIFY_STANDENTRY3` | 58 | 58 | 一致 | 网页客户端固定结构（本轮核对） |
| `022B` | `NOTIFY_NEWENTRY3` | 57 | 57 | 一致 | 网页客户端固定结构（本轮核对） |
| `022C` | `NOTIFY_MOVEENTRY3` | 65 | 65 | 一致 | 网页客户端固定结构（本轮核对） |
| `022E` | `PROPERTY_HOMUN` | 71 | 71 | 一致 | 网页客户端固定结构（本轮核对） |
| `022F` | `FEED_HOM` | — | 7 | 动态/未静态声明 |  |
| `0230` | `CHANGESTATE_MER` | 12 | 12 | 一致 |  |
| `0235` | `HOM_SKILLINFO_LIST` | -1 | -1 | 一致 |  |
| `0239` | `HOM_SKILLINFO_UPDATE` | 11 | 11 | 一致 |  |
| `023A` | `REQ_STORE_PASSWORD` | 4 | 4 | 一致 |  |
| `023C` | `RESULT_STORE_PASSWORD` | 6 | 6 | 一致 |  |
| `0240` | `MAIL_REQ_GET_LIST` | -1 | -1 | 一致 |  |
| `0242` | `MAIL_REQ_OPEN` | -1 | -1 | 一致 |  |
| `0245` | `MAIL_REQ_GET_ITEM` | 3 | 3 | 一致 |  |
| `0249` | `MAIL_REQ_SEND` | 3 | 3 | 一致 |  |
| `024A` | `MAIL_RECEIVE` | 70 | 70 | 一致 |  |
| `0250` | `AUCTION_RESULT` | 3 | 3 | 一致 |  |
| `0252` | `AUCTION_ITEM_REQ_SEARCH` | -1 | -1 | 一致 |  |
| `0253` | `STARPLACE` | 3 | 3 | 一致 |  |
| `0255` | `ACK_MAIL_ADD_ITEM` | 5 | 5 | 一致 |  |
| `0256` | `ACK_AUCTION_ADD_ITEM` | 5 | 5 | 一致 |  |
| `0257` | `ACK_MAIL_DELETE` | 8 | 8 | 一致 |  |
| `025A` | `MAKINGITEM_LIST` | -1 | -1 | 一致 |  |
| `025E` | `AUCTION_ACK_MY_SELL_STOP` | 4 | 4 | 一致 |  |
| `025F` | `AUCTION_WINDOWS` | 6 | 6 | 一致 |  |
| `0260` | `MAIL_WINDOWS` | 6 | 6 | 一致 |  |
| `0274` | `ACK_MAIL_RETURN` | 8 | 8 | 一致 |  |
| `0278` | `NOTIFY_PCBANG` | 2 | 2 | 一致 |  |
| `027A` | `HUNTINGLIST` | -1 | -1 | 一致 |  |
| `027B` | `PCBANG_EFFECT` | 14 | 14 | 一致 |  |
| `027D` | `PROPERTY_MERCE` | 62 | 62 | 一致 |  |
| `027E` | `SHANDA_PROTECT` | -1 | -1 | 一致 |  |
| `0280` | `GANGSI_POINT` | 12 | 12 | 一致 |  |
| `0282` | `GANGSI_RANK` | 284 | 284 | 一致 |  |
| `0283` | `AID` | 6 | 6 | 一致 |  |
| `0284` | `NOTIFY_EFFECT3` | 14 | 14 | 一致 |  |
| `0285` | `DEATH_QUESTION` | 6 | 6 | 一致 |  |
| `0287` | `PC_CASH_POINT_ITEMLIST` | -1 | -1 | 一致 |  |
| `0289` | `PC_CASH_POINT_UPDATE` | 12 | 12 | 一致 |  |
| `028A` | `NPC_SHOWEFST_UPDATE` | 18 | 18 | 一致 |  |
| `0291` | `MSG` | 4 | 4 | 一致 |  |
| `0293` | `BOSS_INFO` | 70 | 70 | 一致 |  |
| `0294` | `READ_BOOK` | 10 | 10 | 一致 |  |
| `0295` | `EQUIPMENT_ITEMLIST2` | -1 | -1 | 一致 |  |
| `0296` | `STORE_EQUIPMENT_ITEMLIST2` | -1 | -1 | 一致 |  |
| `0297` | `CART_EQUIPMENT_ITEMLIST2` | -1 | -1 | 一致 |  |
| `0298` | `CASH_TIME_COUNTER` | 10 | 10 | 一致 |  |
| `0299` | `CASH_ITEM_DELETE` | — | 8 | 动态/未静态声明 |  |
| `029A` | `ITEM_PICKUP_ACK2` | 27 | 27 | 一致 | 网页客户端固定结构（本轮核对） |
| `029B` | `MER_INIT` | 80 | 80 | 一致 |  |
| `029C` | `MER_PROPERTY` | 66 | 66 | 一致 |  |
| `029D` | `MER_SKILLINFO_LIST` | -1 | -1 | 一致 |  |
| `029E` | `MER_SKILLINFO_UPDATE` | 11 | 11 | 一致 |  |
| `02A2` | `MER_PAR_CHANGE` | 8 | 8 | 一致 |  |
| `02A3` | `GAMEGUARD_LINGO_KEY` | 18 | — | 表缺失 |  |
| `02AA` | `REQ_CASH_PASSWORD` | 4 | 4 | 一致 |  |
| `02AC` | `RESULT_CASH_PASSWORD` | 6 | 6 | 一致 |  |
| `02B1` | `ALL_QUEST_LIST` | -1 | -1 | 一致 |  |
| `02B2` | `ALL_QUEST_MISSION` | -1 | -1 | 一致 |  |
| `02B3` | `ADD_QUEST` | 107 | 107 | 一致 |  |
| `02B4` | `DEL_QUEST` | 6 | 6 | 一致 |  |
| `02B5` | `UPDATE_MISSION_HUNT` | -1 | -1 | 一致 |  |
| `02B7` | `ACTIVE_QUEST` | 7 | 7 | 一致 |  |
| `02B8` | `ITEM_PICKUP_PARTY` | 22 | 22 | 一致 | 网页客户端固定结构（本轮核对） |
| `02B9` | `SHORTCUT_KEY_LIST` | 191 | 191 | 一致 |  |
| `02BB` | `EQUIPITEM_DAMAGED` | 8 | 8 | 一致 |  |
| `02BC` | `NOTIFY_PCBANG_PLAYING_TIME` | 6 | 6 | 一致 |  |
| `02BF` | `SRPACKETR2_INIT` | 12 | — | 表缺失 |  |
| `02C1` | `NPC_CHAT` | -1 | -1 | 一致 |  |
| `02C2` | `FORMATSTRING_MSG` | -1 | -1 | 一致 |  |
| `02C5` | `PARTY_JOIN_REQ_ACK` | 30 | 30 | 一致 |  |
| `02C6` | `PARTY_JOIN_REQ` | 30 | 30 | 一致 |  |
| `02C9` | `PARTY_CONFIG` | 3 | 3 | 一致 |  |
| `02CB` | `MEMORIALDUNGEON_SUBSCRIPTION_INFO` | 65 | 65 | 一致 |  |
| `02CC` | `MEMORIALDUNGEON_SUBSCRIPTION_NOTIFY` | 4 | 4 | 一致 |  |
| `02CD` | `MEMORIALDUNGEON_INFO` | 71 | 71 | 一致 |  |
| `02CE` | `MEMORIALDUNGEON_NOTIFY` | 10 | 10 | 一致 |  |
| `02D0` | `EQUIPMENT_ITEMLIST3` | -1 | -1 | 一致 |  |
| `02D1` | `STORE_EQUIPMENT_ITEMLIST3` | -1 | -1 | 一致 |  |
| `02D2` | `CART_EQUIPMENT_ITEMLIST3` | -1 | -1 | 一致 |  |
| `02D3` | `NOTIFY_BIND_ON_EQUIP` | 4 | 4 | 一致 |  |
| `02D4` | `ITEM_PICKUP_ACK3` | 29 | 29 | 一致 | 网页客户端固定结构（本轮核对） |
| `02D5` | `ISVR_DISCONNECT` | 2 | 2 | 一致 |  |
| `02D7` | `EQUIPWIN_MICROSCOPE` | -1 | -1 | 一致 |  |
| `02D9` | `CONFIG` | 10 | 10 | 一致 |  |
| `02DA` | `CONFIG_NOTIFY` | 3 | 3 | 一致 |  |
| `02DC` | `BATTLEFIELD_CHAT` | -1 | -1 | 一致 |  |
| `02DD` | `BATTLEFIELD_NOTIFY_CAMPINFO` | 32 | 32 | 一致 |  |
| `02DE` | `BATTLEFIELD_NOTIFY_POINT` | 6 | 6 | 一致 |  |
| `02DF` | `BATTLEFIELD_NOTIFY_POSITION` | 36 | 36 | 一致 |  |
| `02E0` | `BATTLEFIELD_NOTIFY_HP` | 34 | 34 | 一致 |  |
| `02E1` | `NOTIFY_ACT2` | 33 | 33 | 一致 |  |
| `02E7` | `MAPPROPERTY` | -1 | -1 | 一致 |  |
| `02E8` | `NORMAL_ITEMLIST3` | -1 | -1 | 一致 |  |
| `02E9` | `CART_NORMAL_ITEMLIST3` | -1 | -1 | 一致 |  |
| `02EA` | `STORE_NORMAL_ITEMLIST3` | -1 | -1 | 一致 |  |
| `02EB` | `ACCEPT_ENTER2` | 13 | 13 | 一致 |  |
| `02EC` | `NOTIFY_MOVEENTRY4` | 67 | 67 | 一致 | 网页客户端固定结构（本轮核对） |
| `02ED` | `NOTIFY_NEWENTRY4` | 59 | 59 | 一致 | 网页客户端固定结构（本轮核对） |
| `02EE` | `NOTIFY_STANDENTRY4` | 60 | 60 | 一致 | 网页客户端固定结构（本轮核对） |
| `02EF` | `NOTIFY_FONT` | 8 | 8 | 一致 |  |
| `02F0` | `PROGRESS` | 10 | 10 | 一致 |  |
| `02F2` | `PROGRESS_CANCEL` | 2 | 2 | 一致 |  |
| `035D` | `SIMPLE_CASHSHOP_POINT_ITEMLIST` | -1 | -1 | 一致 |  |
| `043D` | `SKILL_POSTDELAY` | 8 | 8 | 一致 |  |
| `043E` | `SKILL_POSTDELAY_LIST` | -1 | -1 | 一致 |  |
| `043F` | `MSG_STATE_CHANGE2` | 25 | 25 | 一致 |  |
| `0440` | `MILLENNIUMSHIELD` | 10 | 10 | 一致 |  |
| `0441` | `SKILLINFO_DELETE` | 4 | 4 | 一致 |  |
| `0442` | `SKILL_SELECT_REQUEST` | -1 | -1 | 一致 |  |
| `0444` | `SIMPLE_CASH_POINT_ITEMLIST` | -1 | -1 | 一致 |  |
| `0446` | `QUEST_NOTIFY_EFFECT` | 14 | 14 | 一致 |  |
| `0449` | `HACKSH_ERROR_MSG` | 4 | 4 | 一致 |  |
| `07D2` | `ES_LIST` | 6 | — | 表缺失 |  |
| `07D5` | `ES_READY` | 4 | — | 表缺失 |  |
| `07D6` | `ES_GOTO` | 4 | — | 表缺失 |  |
| `07D8` | `REQ_GROUPINFO_CHANGE_V2` | 8 | 8 | 一致 |  |
| `07D9` | `SHORTCUT_KEY_LIST_V2` | 268 | 268 | 一致 |  |
| `07DB` | `HO_PAR_CHANGE` | 8 | 8 | 一致 |  |
| `07DD` | `SEEK_PARTY` | 54 | 54 | 一致 |  |
| `07DF` | `SEEK_PARTY_MEMBER` | 54 | 54 | 一致 |  |
| `07E0` | `ES_NOTI_MYINFO` | 58 | 58 | 一致 |  |
| `07E1` | `SKILLINFO_UPDATE2` | 15 | 15 | 一致 |  |
| `07E2` | `MSG_VALUE` | 8 | 8 | 一致 |  |
| `07E3` | `ITEMLISTWIN_OPEN` | 6 | 6 | 一致 |  |
| `07E6` | `MSG_SKILL` | 8 | 8 | 一致 |  |
| `07EB` | `BATTLE_FIELD_LIST` | -1 | -1 | 一致 |  |
| `07ED` | `JOIN_BATTLE_FIELD` | 10 | 10 | 一致 |  |
| `07EF` | `CANCEL_BATTLE_FIELD` | 8 | 8 | 一致 |  |
| `07F1` | `ACK_BATTLE_STATE_MONITOR` | 18 | 18 | 一致 |  |
| `07F2` | `BATTLE_NOTI_START_STEP` | 8 | 8 | 一致 |  |
| `07F3` | `BATTLE_JOIN_NOTI_DEFER` | 6 | 6 | 一致 |  |
| `07F4` | `BATTLE_JOIN_DISABLE_STATE` | 3 | 3 | 一致 |  |
| `07F6` | `NOTIFY_EXP` | 14 | 14 | 一致 |  |
| `07F7` | `NOTIFY_MOVEENTRY5` | -1 | -1 | 一致 |  |
| `07F8` | `NOTIFY_NEWENTRY5` | -1 | -1 | 一致 |  |
| `07F9` | `NOTIFY_STANDENTRY5` | -1 | -1 | 一致 |  |
| `07FA` | `DELETE_ITEM_FROM_BODY` | 8 | 8 | 一致 |  |
| `07FB` | `USESKILL_ACK2` | 25 | 25 | 一致 |  |
| `07FC` | `CHANGE_GROUP_MASTER` | 10 | 10 | 一致 |  |
| `07FE` | `PLAY_NPC_BGM` | 26 | 26 | 一致 |  |
| `07FF` | `DEFINE_CHECK` | 8 | — | 表缺失 |  |
| `0800` | `PC_PURCHASE_ITEMLIST_FROMMC2` | -1 | -1 | 一致 |  |
| `0803` | `PARTY_BOOKING_ACK_REGISTER` | 4 | 4 | 一致 |  |
| `0805` | `PARTY_BOOKING_ACK_SEARCH` | -1 | -1 | 一致 |  |
| `0807` | `PARTY_BOOKING_ACK_DELETE` | 4 | 4 | 一致 |  |
| `0809` | `PARTY_BOOKING_NOTIFY_INSERT` | 50 | 50 | 一致 |  |
| `080A` | `PARTY_BOOKING_NOTIFY_UPDATE` | 18 | 18 | 一致 |  |
| `080B` | `PARTY_BOOKING_NOTIFY_DELETE` | 6 | 6 | 一致 |  |
| `080D` | `SIMPLE_CASH_BTNSHOW` | 3 | 3 | 一致 |  |
| `080E` | `NOTIFY_HP_TO_GROUPM_R2` | 14 | 14 | 一致 |  |
| `080F` | `ADD_EXCHANGE_ITEM2` | 20 | 20 | 一致 | 网页客户端固定结构（本轮核对） |
| `0810` | `OPEN_BUYING_STORE` | 3 | 3 | 一致 |  |
| `0812` | `FAILED_OPEN_BUYING_STORE_TO_BUYER` | 8 | 8 | 一致 |  |
| `0813` | `MYITEMLIST_BUYING_STORE` | -1 | -1 | 一致 |  |
| `0814` | `BUYING_STORE_ENTRY` | 86 | 86 | 一致 |  |
| `0816` | `DISAPPEAR_BUYING_STORE_ENTRY` | 6 | 6 | 一致 |  |
| `0818` | `ACK_ITEMLIST_BUYING_STORE` | -1 | -1 | 一致 |  |
| `081A` | `FAILED_TRADE_BUYING_STORE_TO_BUYER` | 4 | 4 | 一致 |  |
| `081B` | `UPDATE_ITEM_FROM_BUYING_STORE` | 10 | 10 | 一致 | 网页客户端固定结构（本轮核对） |
| `081C` | `ITEM_DELETE_BUYING_STORE` | 10 | 10 | 一致 |  |
| `081D` | `EL_INIT` | 22 | 22 | 一致 |  |
| `081E` | `EL_PAR_CHANGE` | 8 | 8 | 一致 |  |
| `081F` | `BROADCAST4` | -1 | -1 | 一致 |  |
| `0820` | `COSTUME_SPRITE_CHANGE` | 11 | 11 | 一致 |  |
| `0824` | `FAILED_TRADE_BUYING_STORE_TO_SELLER` | 8 | 8 | 一致 |  |
| `0836` | `SEARCH_STORE_INFO_ACK` | -1 | -1 | 一致 |  |
| `0837` | `SEARCH_STORE_INFO_FAILED` | 3 | 3 | 一致 |  |
| `0839` | `ACK_BAN_GUILD_SSO` | 66 | 66 | 一致 |  |
| `083A` | `OPEN_SEARCH_STORE_INFO` | 5 | 5 | 一致 |  |
| `083D` | `SSILIST_ITEM_CLICK_ACK` | 6 | 6 | 一致 |  |
| `0845` | `OPEN_CASHSHOP_RESULT` | 10 | 10 | 一致 |  |
| `0849` | `OPEN_CASHSHOP_RESULT2` | 16 | 16 | 一致 |  |
| `084B` | `ITEM_FALL_ENTRY2` | 19 | 19 | 一致 | 网页客户端固定结构（本轮核对） |
| `0856` | `NOTIFY_MOVEENTRY6` | -1 | -1 | 一致 |  |
| `0857` | `NOTIFY_NEWENTRY6` | -1 | -1 | 一致 |  |
| `0858` | `NOTIFY_STANDENTRY6` | -1 | -1 | 一致 |  |
| `0859` | `EQUIPWIN_MICROSCOPE2` | -1 | -1 | 一致 |  |
| `08B3` | `SHOWSCRIPT` | -1 | -1 | 一致 |  |
| `08C0` | `ACK_SE_CASH_ITEM_LIST2` | -1 | -1 | 一致 |  |
| `08C7` | `SKILL_ENTRY3` | -1 | -1 | 一致 |  |
| `08C8` | `NOTIFY_ACT3` | 34 | 34 | 一致 |  |
| `08CA` | `ZC_ACK_SCHEDULER_CASHITEM` | -1 | -1 | 一致 |  |
| `08D0` | `REQ_WEAR_EQUIP_ACK2` | 9 | 9 | 一致 |  |
| `08D1` | `REQ_TAKEOFF_EQUIP_ACK2` | 7 | 7 | 一致 |  |
| `08D2` | `FASTMOVE` | 10 | 10 | 一致 |  |
| `08D6` | `CLOSE_SCRIPT` | 6 | 6 | 一致 |  |
| `08E2` | `NAVIGATETO` | 27 | 27 | 一致 |  |
| `08FE` | `HUNTING_QUEST_INFO` | -1 | -1 | 一致 |  |
| `08FF` | `MSG_STATE_CHANGE3` | 24 | 24 | 一致 |  |
| `0908` | `ITEM_FAVORITE` | 5 | 5 | 一致 |  |
| `090F` | `NOTIFY_STANDENTRY7` | -1 | -1 | 一致 |  |
| `0914` | `NOTIFY_MOVEENTRY7` | -1 | -1 | 一致 |  |
| `0915` | `NOTIFY_NEWENTRY7` | -1 | -1 | 一致 |  |
| `0977` | `NOTIFY_MONSTER_HP` | 14 | 14 | 一致 |  |
| `097A` | `ALL_QUEST_LIST_V2` | -1 | -1 | 一致 |  |
| `097D` | `ACK_RANKING` | 288 | 288 | 一致 |  |
| `097E` | `UPDATE_RANKING_POINT` | 12 | 12 | 一致 |  |
| `097F` | `SELECTCART` | 11 | 11 | 一致 | 网页客户端固定结构（本轮核对） |
| `0983` | `MSG_STATE_CHANGE4` | 29 | 29 | 一致 |  |
| `0984` | `MSG_STATE_CHANGE5` | 28 | 28 | 一致 |  |
| `0990` | `ITEM_PICKUP_ACK5` | 31 | 31 | 一致 | 网页客户端固定结构（本轮核对） |
| `0991` | `NORMAL_ITEMLIST4` | -1 | -1 | 一致 |  |
| `0992` | `EQUIPMENT_ITEMLIST4` | -1 | -1 | 一致 |  |
| `0993` | `CART_NORMAL_ITEMLIST4` | -1 | -1 | 一致 |  |
| `0994` | `CART_EQUIPMENT_ITEMLIST4` | -1 | -1 | 一致 |  |
| `0995` | `STORE_NORMAL_ITEMLIST4` | -1 | -1 | 一致 |  |
| `0996` | `STORE_EQUIPMENT_ITEMLIST4` | -1 | -1 | 一致 |  |
| `0997` | `EQUIPWIN_MICROSCOPE_V5` | -1 | -1 | 一致 |  |
| `0999` | `ACK_WEAR_EQUIP_V5` | 0 | 11 | 条件/占位（保留） | JS .size=0 是条件占位；字段结构实际读取 11 字节 |
| `099A` | `ACK_TAKEOFF_EQUIP_V5` | 9 | 9 | 一致 |  |
| `099B` | `NOTIFY_MAPPROPERTY2` | 8 | 8 | 一致 | 同名定义候选：4、8（按 switch 匹配） |
| `099F` | `SKILL_ENTRY4` | -1 | -1 | 一致 |  |
| `09CA` | `SKILL_ENTRY5` | -1 | -1 | 一致 |  |
| `09CB` | `USE_SKILL2` | — | 17 | 动态/未静态声明 |  |
| `09CD` | `MSG_COLOR` | 8 | 8 | 一致 |  |
| `09DB` | `NOTIFY_MOVEENTRY8` | -1 | -1 | 一致 |  |
| `09DC` | `NOTIFY_STANDENTRY8` | -1 | -1 | 一致 |  |
| `09DD` | `NOTIFY_NEWENTRY8` | -1 | -1 | 一致 |  |
| `09DE` | `WHISPER` | -1 | -1 | 一致 |  |
| `09DF` | `ACK_WHISPER2` | 7 | 7 | 一致 |  |
| `09E5` | `DELETEITEM_FROM_MCSTORE2` | 18 | 18 | 一致 |  |
| `09E6` | `UPDATE_ITEM_FROM_BUYING_STORE2` | — | 24 | 动态/未静态声明 |  |
| `09E7` | `NOTIFY_UNREADMAIL` | 3 | 3 | 一致 |  |
| `09EB` | `ACK_READ_MAIL` | -1 | -1 | 一致 |  |
| `09ED` | `ACK_WRITE_MAIL` | 3 | 3 | 一致 |  |
| `09F0` | `ACK_MAIL_LIST` | -1 | -1 | 一致 |  |
| `09F2` | `ACK_ZENY_FROM_MAIL` | 12 | 12 | 一致 |  |
| `09F4` | `ACK_ITEM_FROM_MAIL` | 12 | 12 | 一致 |  |
| `09F6` | `ACK_DELETE_MAIL` | 11 | 11 | 一致 |  |
| `09F7` | `PROPERTY_HOMUN_2` | 75 | 75 | 一致 | 网页客户端固定结构（本轮核对） |
| `09F8` | `ALL_QUEST_LIST_V3` | -1 | -1 | 一致 |  |
| `09F9` | `ADD_QUEST_EX` | 143 | 143 | 一致 |  |
| `09FA` | `UPDATE_MISSION_HUNT_EX` | -1 | -1 | 一致 |  |
| `09FC` | `PET_EVOLUTION_RESULT` | 6 | 6 | 一致 |  |
| `09FD` | `NOTIFY_MOVEENTRY9` | -1 | -1 | 一致 |  |
| `09FE` | `NOTIFY_STANDENTRY9` | -1 | -1 | 一致 |  |
| `09FF` | `NOTIFY_NEWENTRY9` | -1 | -1 | 一致 |  |
| `0A00` | `SHORTCUT_KEY_LIST_V3` | 269 | 269 | 一致 |  |
| `0A05` | `ACK_ADD_ITEM_TO_MAIL` | 53 | 53 | 一致 | 网页客户端固定结构（本轮核对） |
| `0A07` | `ACK_REMOVE_ITEM_MAIL` | 9 | 9 | 一致 |  |
| `0A09` | `ADD_EXCHANGE_ITEM3` | 45 | 45 | 一致 | 网页客户端固定结构（本轮核对） |
| `0A0A` | `ADD_ITEM_TO_STORE3` | 47 | 47 | 一致 | 网页客户端固定结构（本轮核对） |
| `0A0B` | `ADD_ITEM_TO_CART3` | 47 | 47 | 一致 | 网页客户端固定结构（本轮核对） |
| `0A0C` | `ITEM_PICKUP_ACK6` | 56 | 56 | 一致 | 网页客户端固定结构（本轮核对） |
| `0A0D` | `EQUIPMENT_ITEMLIST5` | -1 | — | 表缺失 |  |
| `0A0F` | `CART_EQUIPMENT_ITEMLIST5` | -1 | -1 | 一致 |  |
| `0A10` | `STORE_EQUIPMENT_ITEMLIST5` | -1 | -1 | 一致 |  |
| `0A12` | `ACK_OPEN_WRITE_MAIL` | 27 | 27 | 一致 |  |
| `0A14` | `CHECK_RECEIVE_CHARACTER_NAME` | 10 | 10 | 一致 |  |
| `0A15` | `GOLDPCCAFE_POINT` | 12 | 12 | 一致 |  |
| `0A17` | `DYNAMICNPC_CREATE_RESULT` | 6 | 6 | 一致 |  |
| `0A18` | `ACCEPT_ENTER3` | 14 | 14 | 一致 |  |
| `0A23` | `ALL_ACH_LIST` | -1 | -1 | 一致 |  |
| `0A24` | `ACH_UPDATE` | 66 | 66 | 一致 |  |
| `0A26` | `REQ_ACH_REWARD_ACK` | 7 | 7 | 一致 |  |
| `0A27` | `RECOVERY2` | 8 | 8 | 一致 |  |
| `0A28` | `OPENSTORE2` | 3 | 3 | 一致 |  |
| `0A2D` | `EQUIPWIN_MICROSCOPE_V6` | -1 | -1 | 一致 |  |
| `0A2F` | `ACK_CHANGE_TITLE` | 7 | 7 | 一致 |  |
| `0A30` | `ACK_REQNAMEALL2` | 106 | 106 | 一致 |  |
| `0A37` | `ITEM_PICKUP_ACK_V7` | 59 | 59 | 一致 | 网页客户端固定结构（本轮核对） |
| `0A3B` | `HAT_EFFECT` | -1 | -1 | 一致 |  |
| `0A41` | `SKILL_SCALE` | 18 | 18 | 一致 |  |
| `0A43` | `ADD_MEMBER_TO_GROUP3` | 85 | 85 | 一致 |  |
| `0A44` | `GROUP_LIST2` | -1 | -1 | 一致 |  |
| `0A4A` | `PRIVATE_AIRSHIP_RESPONSE` | 6 | 6 | 一致 |  |
| `0A4E` | `RANDOM_COMBINE_ITEM_UI_OPEN` | 6 | 6 | 一致 |  |
| `0A50` | `ACK_RANDOM_COMBINE_ITEM` | 4 | 4 | 一致 |  |
| `0A51` | `CHECK_RECEIVE_CHARACTER_NAME2` | 34 | 34 | 一致 |  |
| `0A78` | `CAMERA_INFO` | 15 | 15 | 一致 |  |
| `0A82` | `ACK_BAN_GUILD_SSO2` | 46 | 46 | 一致 |  |
| `0A83` | `ACK_LEAVE_GUILD2` | 46 | 46 | 一致 |  |
| `0A84` | `GUILD_INFO3` | 94 | 94 | 一致 |  |
| `0A9A` | `EQUIPSWITCH_REMOVE` | 10 | 10 | 一致 |  |
| `0A9B` | `EQUIPSWITCH_LIST` | -1 | -1 | 一致 |  |
| `0AA0` | `REFINE_OPEN_WINDOW` | 2 | 2 | 一致 |  |
| `0AA2` | `REFINE_ADD_ITEM` | -1 | -1 | 一致 |  |
| `0AA5` | `PKT_MC_GUILDMEMBERLIST2` | -1 | -1 | 一致 |  |
| `0AB2` | `PARTY_DEAD` | 7 | 7 | 一致 |  |
| `0AB4` | `RANDOM_UPGRADE_ITEM_UI_OPEN` | 6 | 6 | 一致 |  |
| `0AB7` | `ACK_RANDOM_UPGRADE_ITEM` | 4 | 4 | 一致 |  |
| `0ABD` | `PARTY_JOB_AND_LEVEL` | 10 | 10 | 一致 |  |
| `0ABE` | `WARPLIST2` | -1 | -1 | 一致 |  |
| `0AC2` | `ACK_MAIL_LIST3` | -1 | -1 | 一致 |  |
| `0ACB` | `UPDATE_EXP` | 12 | 12 | 一致 |  |
| `0ACC` | `NOTIFY_EXP2` | 18 | 18 | 一致 |  |
| `0AD1` | `ATTACK_SKILLINFO_LIST` | -1 | -1 | 一致 |  |
| `0AD2` | `ADDIS_SKILLINFO_LIST` | -1 | -1 | 一致 | 网页客户端固定结构（本轮核对） |
| `0AD3` | `TOUCH_SKILLINFO_LIST` | -1 | -1 | 一致 |  |
| `0AD4` | `QOATTACK_SKILLINFO_LIST` | -1 | -1 | 一致 |  |
| `0AD5` | `SECOND_CHECK` | 10 | 10 | 仅解析 | 保持 10 字节接收边界；不自动发送 `0AFA CHECK_BIN`，否则实测会断线 |
| `0AD6` | `CARDCONNECTION_RECHARGE_LIST` | -1 | 2 | LastRO 特殊处理（保留） | LastRO 专用：2 字节标记后由 0000 接收 2560 字节零帧 |
| `0AD8` | `CARDCONNECTION_RECHARGE_UPDATE` | 9 | 9 | 一致 | 网页客户端固定结构（本轮核对） |
| `0ADA` | `BROADCAST_ITEMREFINING_RESULT` | 32 | 32 | 一致 |  |
| `0ADC` | `CARDCONNECTION_ENABLE_UPDATE` | 6 | 6 | 已修正 | 4 个配置标志加 2 字节包头；旧值 5 会使后续包头错位 |
| `0ADD` | `ITEM_FALL_ENTRY3` | — | 24 | 动态/未静态声明 |  |
| `0ADE` | `WEIGHT_LIMIT` | 6 | 6 | 一致 |  |
| `0ADF` | `ACK_REQNAME3` | 58 | 58 | 一致 |  |
| `0AE2` | `UI_OPEN` | 7 | 7 | 一致 |  |
| `0AE4` | `ADD_MEMBER_TO_GROUP4` | 89 | 89 | 一致 |  |
| `0AE5` | `GROUP_LIST3` | -1 | -1 | 一致 |  |
| `0AE7` | `PARTY_REQ_MASTER_TO_JOIN` | 38 | 38 | 一致 |  |
| `0AE9` | `CARDCONNECTION_CANCEL_UPDATE` | 9 | 9 | 一致 | 网页客户端固定结构（本轮核对） |
| `0AEA` | `CARDCONNECTION_ACTIVATE_UPDATE` | 5 | — | 表缺失 |  |
| `0AF0` | `NOTIFY_ATTENDANCE` | 10 | 10 | 一致 |  |
| `0AF1` | `NOTIFY_SETTARGET` | 7 | 7 | 一致 | 网页客户端固定结构（本轮核对） |
| `0AF5` | `NOTIFY_LOADINFO` | 58 | 58 | 一致 |  |
| `0AF6` | `NOTIFY_RELOADINFOS` | 7 | 7 | 一致 |  |
| `0AF7` | `ACK_REQNAME_BYGID2` | 32 | 32 | 一致 |  |
| `0AF8` | `NOTIFY_SETTARGET2` | 7 | 7 | 一致 | 网页客户端固定结构（本轮核对） |
| `0AF9` | `SKILL_AUTOSHADOWSPELL` | -1 | -1 | 一致 | 网页客户端固定结构（本轮核对） |
| `0AFA` | `PARTY_JOIN_REQ_ACK_FROM_MASTER` | 58 | 58 | 一致 | 网页客户端固定结构（本轮核对） |
| `0AFB` | `AUTOSPELLLIST2` | -1 | -1 | 一致 |  |
| `0AFC` | `NOTIFY_OFFLINEMSG` | 30 | 30 | 一致 |  |
| `0B08` | `INVENTORY_START` | -1 | -1 | 一致 |  |
| `0B09` | `INVENTORY_ITEMLIST` | -1 | -1 | 一致 |  |
| `0B0B` | `INVENTORY_END` | 4 | 4 | 一致 |  |
| `0B15` | `ACK_OPEN_MSGBOX_EXTEND_BODYITEM_SIZE` | 7 | 7 | 一致 |  |
| `0B17` | `ACK_EXTEND_BODYITEM_SIZE` | 3 | 3 | 一致 |  |
| `0B18` | `EXTEND_BODYITEM_SIZE` | 4 | 4 | 一致 |  |
| `0B1A` | `USESKILL_ACK3` | 29 | 29 | 一致 |  |
| `0B1B` | `NOTIFY_ACTORINIT` | 2 | 2 | 一致 |  |
| `0B1D` | `PING_LIVE` | 2 | 2 | 一致 |  |
| `0B20` | `HORTCUT_KEY_LIST` | 271 | 271 | 一致 |  |
| `0B31` | `ADD_SKILL2` | 17 | 17 | 一致 |  |
| `0B33` | `SKILLINFO_UPDATE3` | 17 | 17 | 一致 |  |
| `0B37` | `EQUIPWIN_MICROSCOPE3` | -1 | -1 | 一致 |  |
| `0B39` | `INVENTORY_ITEMLIST_EQUIP` | -1 | -1 | 一致 |  |
| `0B3D` | `PC_PURCHASE_ITEMLIST_FROMMC3` | -1 | -1 | 一致 |  |
| `0B3F` | `ACK_ADD_ITEM_RODEX` | 64 | 64 | 一致 |  |
| `0B40` | `PC_PURCHASE_MYITEMLIST2` | -1 | -1 | 一致 |  |
| `0B41` | `ITEM_PICKUP_ACK_V8` | 70 | 70 | 一致 |  |
| `0B42` | `ADD_EXCHANGE_ITEM4` | 62 | 62 | 一致 |  |
| `0B43` | `CHANGE_ITEM_OPTION` | 48 | 48 | 一致 |  |
| `0B44` | `ADD_ITEM_TO_STORE4` | 58 | 58 | 一致 |  |
| `0B45` | `ADD_ITEM_TO_CART4` | 58 | 58 | 一致 |  |
| `0B47` | `CHANGE_GUILD2` | 14 | 14 | 一致 |  |
| `0B4E` | `NPC_MARKET_PURCHASE_RESULT` | -1 | -1 | 一致 |  |
| `0B63` | `ACK_READ_RODEX` | -1 | -1 | 一致 |  |
| `0B67` | `ITEM_PICKUP_PARTY2` | 33 | 33 | 一致 |  |
| `0B6E` | `SE_CASHSHOP_OPEN` | 14 | 14 | 一致 |  |
| `0B77` | `PC_PURCHASE_ITEMLIST2` | -1 | -1 | 一致 |  |
| `0B78` | `NPC_BARTER_MARKET_ITEMINFO` | -1 | -1 | 一致 |  |
| `0B79` | `NPC_EXPANDED_BARTER_MARKET_ITEMINFO` | -1 | -1 | 一致 |  |
| `0B7A` | `NPC_MARKET_OPEN` | -1 | -1 | 一致 |  |
| `0B7B` | `GUILD_INFO4` | 118 | 118 | 一致 |  |
| `0B7C` | `BAN_LIST` | -1 | -1 | 一致 |  |
| `0B7D` | `MEMBERMGR_INFO2` | -1 | -1 | 一致 |  |
| `0B8D` | `REPUTE_INFO` | -1 | -1 | 一致 |  |
| `0B8F` | `OPEN_REFORM_UI` | 6 | 6 | 一致 |  |
| `0B92` | `ITEM_REFORM_ACK` | 5 | 5 | 一致 |  |
| `0BA4` | `PROPERTY_HOMUN4` | 85 | 85 | 一致 |  |
| `0BA5` | `HO_PAR_CHANGE2` | 12 | 12 | 一致 |  |
| `0BF2` | `RS_CREATE_INSTANCE` | 3 | — | 表缺失 |  |
| `0BF4` | `RS_DEL_INSTANCE` | 3 | — | 表缺失 |  |
| `0BF6` | `RS_ENTER_INSTANCE` | 3 | — | 表缺失 |  |
