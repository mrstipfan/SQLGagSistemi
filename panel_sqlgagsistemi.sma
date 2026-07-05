#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <engine>

#pragma semicolon 1

#define PLUGIN  "[SQL GAG] Sistemi"
#define VERSION "3.1"
#define AUTHOR  "Onur MrStipFan MASALCI"

#define CONFIG_FILE "panel_sqlgagsistemi.ini"

#define MAX_REASONS     50
#define MAX_TIMES       50
#define MAX_TYPES       3
#define MAX_BAD_WORDS   100
#define TASK_CHECK      30001
#define TASK_VOICE_BLOCK 30050

#define MIN_REASON_LENGTH 3

enum _:GagTypeEnum
{
	TYPE_CHAT = 0,
	TYPE_VOICE,
	TYPE_BOTH
};

new const g_szSqlTypeText[][] =
{
	"Chat Gag",
	"Mikrofon Gag",
	"Chat + Mikrofon Gag"
};

new const g_szTableName[] = "gag_sistemi";

/* =========================
   SQL / CONFIG
========================= */

new Handle:g_hTuple = Empty_Handle;
new Handle:g_hSql   = Empty_Handle;

new g_szDbHost[64];
new g_szDbUser[64];
new g_szDbPass[64];
new g_szDbName[64];

new g_szMenuPrefix[64];
new g_szMenuGagsTitle[64];
new g_szMenuReasonsTitle[64];
new g_szMenuTimesTitle[64];
new g_szMenuTypesTitle[64];

new g_szChatPrefix[64];

new g_szGagSound[128];
new g_szUngagSound[128];
new g_szExpireGagSound[128];

new g_szReasons[MAX_REASONS][128];
new g_szCleanReasons[MAX_REASONS][128];
new g_iReasonCount;

new g_szTimeNames[MAX_TIMES][128];
new g_iGagTimes[MAX_TIMES];
new g_iTimeCount;

new g_szGagTypes[MAX_TYPES][128];
new g_szCleanGagTypes[MAX_TYPES][128];
new g_iGagTypeCount;

new Float:g_fHudX;
new Float:g_fHudY;
new Float:g_fHudHoldTime;
new Float:g_fHudFadeIn;
new Float:g_fHudFadeOut;
new g_iHudEffect;

new Float:g_fCheckExpiredInterval;
new Float:g_fDoubleCheckDelay;
new Float:g_fVoiceBlockingDelay;

new g_iGagAccess;
new g_iUngagAccess;
new g_iCleanAccess;
new g_iListAccess;

new bool:g_bLogsEnabled;
new g_szLogsFile[128];

new bool:g_bEnableChecks;

new bool:g_bBadWordsEnabled;
new g_iBadWordGagTime;
new g_iBadWordGagType;
new g_szBadWords[MAX_BAD_WORDS][32];
new g_iBadWordCount;

new g_iMaxReasons;
new g_iMaxTimes;
new g_iMaxBadWords;

/* =========================
   NEW JOIN SETTINGS
========================= */

new bool:g_bAnnounceExistingGagOnJoin;
new bool:g_bShowJoinInfoToPlayer;
new g_iJoinInfoSeconds;

new bool:g_bAutoGagOnJoinEnabled;
new g_iAutoGagOnJoinMinutes;
new g_iAutoGagOnJoinType;
new g_szAutoGagOnJoinReason[128];
new bool:g_bAutoGagOnJoinAnnounceAll;
new bool:g_bAutoGagOnlyOncePerMap;
new bool:g_bAutoGagSkipAdmins;

new bool:g_bAutoGagAppliedThisMap[33];

/* =========================
   PLAYER STATE
========================= */

new bool:g_bGagged[33];
new g_iPlayerGagType[33];
new g_iGagExpireTime[33];
new g_szGagReason[33][128];
new g_szGagAdmin[33][32];

/* =========================
   MENU STATE
========================= */

new g_iSelectedPlayer[33];
new g_iSelectedReason[33];
new g_iSelectedType[33];
new g_szCustomReason[33][128];

new g_iMenuGags = -1;
new g_iMenuReasons = -1;
new g_iMenuTimes = -1;
new g_iMenuTypes = -1;
new g_iMenuUngag = -1;

/* =========================
   FORWARDS
========================= */

public plugin_precache()
{
	loadConfiguration();

	if (g_szGagSound[0]) precache_sound(g_szGagSound);
	if (g_szUngagSound[0]) precache_sound(g_szUngagSound);
	if (g_szExpireGagSound[0]) precache_sound(g_szExpireGagSound);
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	loadConfiguration();

	register_concmd("csa_gag", "cmd_GagPlayer", g_iGagAccess, "<Nick> <Dakika> <Tur> <Sebep>");
	register_concmd("csa_gagmenu", "cmd_GagMenu", g_iGagAccess, "- Gag menusu");
	register_concmd("csa_ungagmenu", "cmd_UngagMenu", g_iUngagAccess, "- Ungag menusu");
	register_concmd("csa_cleangags", "cmd_CleanGags", g_iCleanAccess, "- Tum gagleri temizler");
	register_concmd("csa_gaglist", "cmd_GagList", g_iListAccess, "- Aktif gag listesi");

	register_clcmd("say /gagmenu", "cmd_GagMenuSay");
	register_clcmd("say !gagmenu", "cmd_GagMenuSay");
	register_clcmd("say .gagmenu", "cmd_GagMenuSay");

	register_clcmd("say_team /gagmenu", "cmd_GagMenuSay");
	register_clcmd("say_team !gagmenu", "cmd_GagMenuSay");
	register_clcmd("say_team .gagmenu", "cmd_GagMenuSay");

	register_clcmd("say /ungagmenu", "cmd_UngagMenuSay");
	register_clcmd("say !ungagmenu", "cmd_UngagMenuSay");
	register_clcmd("say .ungagmenu", "cmd_UngagMenuSay");

	register_clcmd("say_team /ungagmenu", "cmd_UngagMenuSay");
	register_clcmd("say_team !ungagmenu", "cmd_UngagMenuSay");
	register_clcmd("say_team .ungagmenu", "cmd_UngagMenuSay");

	register_clcmd("say", "hook_Say");
	register_clcmd("say_team", "hook_Say");
	register_clcmd("+voicerecord", "hook_Voice");
	register_clcmd("gag_custom_reason", "cmd_CustomReason");

	if (g_bEnableChecks)
	{
		register_event("HLTV", "event_NewRound", "a", "1=0", "2=0");
	}

	createStaticMenus();

	set_task(g_fCheckExpiredInterval, "task_CheckExpiredGags", TASK_CHECK, "", 0, "b");
}

public plugin_cfg()
{
	connectToDatabase();
	sqlCreateTable();
}

public plugin_end()
{
	if (g_iMenuGags != -1) menu_destroy(g_iMenuGags);
	if (g_iMenuReasons != -1) menu_destroy(g_iMenuReasons);
	if (g_iMenuTimes != -1) menu_destroy(g_iMenuTimes);
	if (g_iMenuTypes != -1) menu_destroy(g_iMenuTypes);
	if (g_iMenuUngag != -1) menu_destroy(g_iMenuUngag);

	if (g_hSql != Empty_Handle)
	{
		SQL_FreeHandle(g_hSql);
		g_hSql = Empty_Handle;
	}

	if (g_hTuple != Empty_Handle)
	{
		SQL_FreeHandle(g_hTuple);
		g_hTuple = Empty_Handle;
	}
}

public client_putinserver(id)
{
	resetPlayerGag(id);
	g_bAutoGagAppliedThisMap[id] = false;

	if (!is_user_bot(id) && !is_user_hltv(id))
	{
		set_task(g_fDoubleCheckDelay, "task_LoadPlayerGag", id);
		set_task(g_fDoubleCheckDelay + 0.2, "task_ProcessJoinFeatures", id);
	}
}

public client_disconnected(id)
{
	if (g_bGagged[id] && (g_iPlayerGagType[id] == TYPE_VOICE || g_iPlayerGagType[id] == TYPE_BOTH))
	{
		unblockPlayerVoice(id);
	}

	resetPlayerGag(id);
	g_bAutoGagAppliedThisMap[id] = false;
}

public task_LoadPlayerGag(id)
{
	if (!is_user_connected(id))
	{
		return;
	}

	loadPlayerGag(id);
}

public task_ProcessJoinFeatures(id)
{
	if (!is_user_connected(id))
	{
		return;
	}

	if (g_bGagged[id])
	{
		announceExistingGagOnJoin(id);

		if (g_bShowJoinInfoToPlayer && g_iJoinInfoSeconds > 0)
		{
			showJoinGagInfo(id);
		}
	}
	else
	{
		processAutoGagOnJoin(id);
	}
}

public event_NewRound()
{
	if (!g_bEnableChecks)
	{
		return;
	}

	for (new id = 1; id <= 32; id++)
	{
		if (is_user_connected(id) && !is_user_bot(id) && !is_user_hltv(id))
		{
			loadPlayerGag(id);
		}
	}
}

public task_CheckExpiredGags()
{
	if (g_hSql == Empty_Handle)
	{
		connectToDatabase();
		if (g_hSql == Empty_Handle)
		{
			return;
		}
	}

	new iNow = get_systime();

	new szQuery[256];
	formatex(szQuery, charsmax(szQuery),
		"DELETE FROM `%s` WHERE expire_time > 0 AND expire_time <= %d",
		g_szTableName, iNow);

	sqlSimpleQuery(szQuery);

	for (new id = 1; id <= 32; id++)
	{
		if (!is_user_connected(id) || !g_bGagged[id])
		{
			continue;
		}

		if (g_iGagExpireTime[id] > 0 && g_iGagExpireTime[id] <= iNow)
		{
			new iOldType = g_iPlayerGagType[id];

			if (iOldType == TYPE_VOICE || iOldType == TYPE_BOTH)
			{
				unblockPlayerVoice(id);
			}

			if (g_szExpireGagSound[0])
			{
				client_cmd(0, "spk ^"%s^"", g_szExpireGagSound);
			}

			sendChat(id, "%s Gag sureniz doldu. Artik konusabilirsiniz.", g_szChatPrefix);

			new szName[32], szLog[256];
			get_user_name(id, szName, charsmax(szName));
			formatex(szLog, charsmax(szLog), "Oyuncu %s icin gag suresi doldu (Tur: %s)", szName, g_szSqlTypeText[iOldType]);
			writeGagLog(szLog);

			resetPlayerGag(id);
		}
	}
}

/* =========================
   JOIN FEATURES
========================= */

stock announceExistingGagOnJoin(id)
{
	if (!g_bAnnounceExistingGagOnJoin)
	{
		return;
	}

	new szName[32];
	get_user_name(id, szName, charsmax(szName));

	if (g_iGagExpireTime[id] == 0)
	{
		sendChat(0, "%s Gagli oyuncu sunucuya giris yapti: ^3%s^1 | Tur: ^4%s^1 | Sure: ^3Kalici^1 | Sebep: ^3%s",
			g_szChatPrefix, szName, g_szSqlTypeText[g_iPlayerGagType[id]], g_szGagReason[id]);
	}
	else
	{
		new iLeft = (g_iGagExpireTime[id] - get_systime());
		if (iLeft < 0) iLeft = 0;

		sendChat(0, "%s Gagli oyuncu sunucuya giris yapti: ^3%s^1 | Tur: ^4%s^1 | Kalan: ^3%d sn^1 | Sebep: ^3%s",
			g_szChatPrefix, szName, g_szSqlTypeText[g_iPlayerGagType[id]], iLeft, g_szGagReason[id]);
	}
}

stock showJoinGagInfo(id)
{
	new szType[64];
	copy(szType, charsmax(szType), g_szSqlTypeText[g_iPlayerGagType[id]]);

	sendChat(id, "%s Sunucuya gagli olarak baglandiniz. Tur: ^4%s^1 | Sebep: ^3%s",
		g_szChatPrefix, szType, g_szGagReason[id]);

	if (g_iJoinInfoSeconds > 0)
	{
		sendChat(id, "%s Baglanti bilgilendirmesi: ^3%d sn boyunca gaglisiniz^1.",
			g_szChatPrefix, g_iJoinInfoSeconds);
	}
}

stock processAutoGagOnJoin(id)
{
	if (!g_bAutoGagOnJoinEnabled)
	{
		return;
	}

	if (!is_user_connected(id))
	{
		return;
	}

	if (g_bAutoGagSkipAdmins && (get_user_flags(id) & ADMIN_KICK))
	{
		return;
	}

	if (g_bAutoGagOnlyOncePerMap && g_bAutoGagAppliedThisMap[id])
	{
		return;
	}

	if (g_iAutoGagOnJoinMinutes < 0)
	{
		return;
	}

	applySystemGag(id, g_szAutoGagOnJoinReason, g_iAutoGagOnJoinMinutes, g_iAutoGagOnJoinType, g_bAutoGagOnJoinAnnounceAll);
	g_bAutoGagAppliedThisMap[id] = true;

	if (g_iJoinInfoSeconds > 0)
	{
		sendChat(id, "%s Baglanti kurali: ^3%d sn gaglisiniz^1.", g_szChatPrefix, g_iJoinInfoSeconds);
	}
}

stock applySystemGag(id, const szReason[], iMinutes, iType, bool:bAnnounceAll)
{
	if (!is_user_connected(id))
	{
		return;
	}

	if (g_hSql == Empty_Handle)
	{
		connectToDatabase();
		if (g_hSql == Empty_Handle)
		{
			return;
		}
	}

	new szPlayer[32], szAuthid[35], szIp[32];
	get_user_name(id, szPlayer, charsmax(szPlayer));
	get_user_authid(id, szAuthid, charsmax(szAuthid));
	get_user_ip(id, szIp, charsmax(szIp), 1);

	new szEA[64], szEP[64], szEPlayer[64], szEReason[256];
	sqlEscape(szAuthid, szEA, charsmax(szEA));
	sqlEscape(szIp, szEP, charsmax(szEP));
	sqlEscape(szPlayer, szEPlayer, charsmax(szEPlayer));
	sqlEscape(szReason, szEReason, charsmax(szEReason));

	new iExpire = (iMinutes > 0) ? (get_systime() + (iMinutes * 60)) : 0;

	new szDelete[256];
	formatex(szDelete, charsmax(szDelete),
		"DELETE FROM `%s` WHERE authid='%s' OR player_ip='%s'",
		g_szTableName, szEA, szEP);
	sqlSimpleQuery(szDelete);

	new szInsert[1024];
	formatex(szInsert, charsmax(szInsert),
		"INSERT INTO `%s` (`authid`,`player_ip`,`player_name`,`admin_name`,`reason`,`gag_minutes`,`expire_time`,`gag_type`,`gag_type_text`,`created_at`) VALUES ('%s','%s','%s','SYSTEM','%s',%d,%d,%d,'%s',%d)",
		g_szTableName,
		szEA, szEP, szEPlayer, szEReason,
		iMinutes, iExpire, iType, g_szSqlTypeText[iType], get_systime());

	sqlSimpleQuery(szInsert);

	g_bGagged[id] = true;
	g_iPlayerGagType[id] = iType;
	g_iGagExpireTime[id] = iExpire;
	copy(g_szGagReason[id], charsmax(g_szGagReason[]), szReason);
	copy(g_szGagAdmin[id], charsmax(g_szGagAdmin[]), "SYSTEM");

	if (iType == TYPE_VOICE || iType == TYPE_BOTH)
	{
		blockPlayerVoice(id);
	}

	if (bAnnounceAll)
	{
		if (iMinutes > 0)
		{
			sendChat(0, "%s Oyuncu ^3%s ^1sunucuya giriste otomatik ^4%s ^1aldi. Sure: ^3%d dk^1 | Sebep: ^3%s",
				g_szChatPrefix, szPlayer, g_szSqlTypeText[iType], iMinutes, szReason);
		}
		else
		{
			sendChat(0, "%s Oyuncu ^3%s ^1sunucuya giriste otomatik ^4%s ^1aldi. Sure: ^3Kalici^1 | Sebep: ^3%s",
				g_szChatPrefix, szPlayer, g_szSqlTypeText[iType], szReason);
		}
	}

	sendChat(id, "%s Sunucuya giriste otomatik ^4%s ^1uygulandi. Sebep: ^3%s",
		g_szChatPrefix, g_szSqlTypeText[iType], szReason);

	new szLog[256];
	formatex(szLog, charsmax(szLog),
		"SYSTEM oyuncu %s icin giriste otomatik gag uyguladi | Tur: %s | Sure: %d dk | Sebep: %s",
		szPlayer, g_szSqlTypeText[iType], iMinutes, szReason);
	writeGagLog(szLog);
}

/* =========================
   COMMANDS
========================= */

public cmd_GagMenu(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
	{
		return PLUGIN_HANDLED;
	}

	showGagPlayerMenu(id);
	return PLUGIN_HANDLED;
}

public cmd_GagMenuSay(id)
{
	if (!(get_user_flags(id) & g_iGagAccess))
	{
		return PLUGIN_HANDLED;
	}

	showGagPlayerMenu(id);
	return PLUGIN_HANDLED;
}

public cmd_UngagMenu(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
	{
		return PLUGIN_HANDLED;
	}

	showUngagPlayerMenu(id);
	return PLUGIN_HANDLED;
}

public cmd_UngagMenuSay(id)
{
	if (!(get_user_flags(id) & g_iUngagAccess))
	{
		return PLUGIN_HANDLED;
	}

	showUngagPlayerMenu(id);
	return PLUGIN_HANDLED;
}

public cmd_GagPlayer(id, level, cid)
{
	if (!cmd_access(id, level, cid, 5))
	{
		sendChat(id, "%s Kullanim: csa_gag <nick> <dakika> <tur> <sebep>", g_szChatPrefix);
		sendChat(id, "%s Turler: 0 = Chat Gag, 1 = Mikrofon Gag, 2 = Chat + Mikrofon Gag", g_szChatPrefix);
		return PLUGIN_HANDLED;
	}

	new szTarget[32], szMinutes[16], szType[8], szReason[128];
	read_argv(1, szTarget, charsmax(szTarget));
	read_argv(2, szMinutes, charsmax(szMinutes));
	read_argv(3, szType, charsmax(szType));

	szReason[0] = 0;
	new argc = read_argc();
	for (new i = 4; i < argc; i++)
	{
		new szArg[64];
		read_argv(i, szArg, charsmax(szArg));
		if (szReason[0]) add(szReason, charsmax(szReason), " ");
		add(szReason, charsmax(szReason), szArg);
	}

	if (!szTarget[0] || !szMinutes[0] || !szType[0] || !szReason[0])
	{
		sendChat(id, "%s Kullanim: csa_gag <nick> <dakika> <tur> <sebep>", g_szChatPrefix);
		return PLUGIN_HANDLED;
	}

	new target = cmd_target(id, szTarget, CMDTARGET_NO_BOTS);
	if (!target)
	{
		return PLUGIN_HANDLED;
	}

	new iMinutes = str_to_num(szMinutes);
	if (iMinutes < 0)
	{
		sendChat(id, "%s Sure 0 veya daha buyuk olmali.", g_szChatPrefix);
		return PLUGIN_HANDLED;
	}

	new iType = str_to_num(szType);
	if (iType < TYPE_CHAT || iType > TYPE_BOTH)
	{
		sendChat(id, "%s Gecersiz tur. 0 / 1 / 2 kullanin.", g_szChatPrefix);
		return PLUGIN_HANDLED;
	}

	if (strlen(szReason) < MIN_REASON_LENGTH)
	{
		sendChat(id, "%s Sebep cok kisa.", g_szChatPrefix);
		return PLUGIN_HANDLED;
	}

	applyPlayerGag(id, target, szReason, iMinutes, iType);
	return PLUGIN_HANDLED;
}

public cmd_CleanGags(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
	{
		return PLUGIN_HANDLED;
	}

	if (g_hSql == Empty_Handle)
	{
		connectToDatabase();
		if (g_hSql == Empty_Handle)
		{
			return PLUGIN_HANDLED;
		}
	}

	sqlSimpleQuery("DELETE FROM `gag_sistemi`");

	for (new i = 1; i <= 32; i++)
	{
		if (!is_user_connected(i))
		{
			continue;
		}

		if (g_bGagged[i] && (g_iPlayerGagType[i] == TYPE_VOICE || g_iPlayerGagType[i] == TYPE_BOTH))
		{
			unblockPlayerVoice(i);
		}

		resetPlayerGag(i);
	}

	new szAdmin[32];
	get_user_name(id, szAdmin, charsmax(szAdmin));

	sendChat(0, "%s Admin ^3%s ^1tum gagleri temizledi.", g_szChatPrefix, szAdmin);
	writeGagLog("Tum gagler temizlendi.");

	return PLUGIN_HANDLED;
}

public cmd_GagList(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
	{
		return PLUGIN_HANDLED;
	}

	if (g_hSql == Empty_Handle)
	{
		connectToDatabase();
		if (g_hSql == Empty_Handle)
		{
			return PLUGIN_HANDLED;
		}
	}

	new iNow = get_systime();
	new szQuery[256];
	formatex(szQuery, charsmax(szQuery),
		"SELECT player_name, admin_name, reason, gag_minutes, expire_time, gag_type_text FROM `%s` WHERE expire_time = 0 OR expire_time > %d",
		g_szTableName, iNow);

	new Handle:hQuery = SQL_PrepareQuery(g_hSql, szQuery);
	if (!SQL_Execute(hQuery))
	{
		new szErr[256];
		SQL_QueryError(hQuery, szErr, charsmax(szErr));
		log_amx("[SQL-GAG] Gag list SQL hata: %s", szErr);
		SQL_FreeHandle(hQuery);
		return PLUGIN_HANDLED;
	}

	if (SQL_NumResults(hQuery) <= 0)
	{
		sendChat(id, "%s Aktif gag yok.", g_szChatPrefix);
		SQL_FreeHandle(hQuery);
		return PLUGIN_HANDLED;
	}

	sendChat(id, "%s Aktif gag listesi:", g_szChatPrefix);

	new szPlayer[32], szAdmin[32], szReason[128], szType[64];
	new iMinutes, iExpire, iLeft;

	while (SQL_MoreResults(hQuery))
	{
		SQL_ReadResult(hQuery, 0, szPlayer, charsmax(szPlayer));
		SQL_ReadResult(hQuery, 1, szAdmin, charsmax(szAdmin));
		SQL_ReadResult(hQuery, 2, szReason, charsmax(szReason));
		iMinutes = SQL_ReadResult(hQuery, 3);
		iExpire = SQL_ReadResult(hQuery, 4);
		SQL_ReadResult(hQuery, 5, szType, charsmax(szType));

		if (iExpire == 0)
		{
			sendChat(id, "^4[SQL-GAG]^1 %s | Tur: ^3%s^1 | Sure: ^3Kalici^1 | Admin: ^3%s^1 | Sebep: ^3%s",
				szPlayer, szType, szAdmin, szReason);
		}
		else
		{
			iLeft = (iExpire - iNow) / 60;
			if (iLeft < 0) iLeft = 0;

			sendChat(id, "^4[SQL-GAG]^1 %s | Tur: ^3%s^1 | Kalan: ^3%d dk^1 | Orijinal: ^3%d dk^1 | Admin: ^3%s^1 | Sebep: ^3%s",
				szPlayer, szType, iLeft, iMinutes, szAdmin, szReason);
		}

		SQL_NextRow(hQuery);
	}

	SQL_FreeHandle(hQuery);
	return PLUGIN_HANDLED;
}

/* =========================
   MENU
========================= */

stock createStaticMenus()
{
	if (g_iMenuReasons != -1) menu_destroy(g_iMenuReasons);
	if (g_iMenuTypes != -1) menu_destroy(g_iMenuTypes);
	if (g_iMenuTimes != -1) menu_destroy(g_iMenuTimes);

	new szTitle[128];

	formatex(szTitle, charsmax(szTitle), "%s %s", g_szMenuPrefix, g_szMenuReasonsTitle);
	g_iMenuReasons = menu_create(szTitle, "handleMenuReasons");
	for (new i = 0; i < g_iReasonCount; i++)
	{
		menu_additem(g_iMenuReasons, g_szReasons[i], "");
	}

	formatex(szTitle, charsmax(szTitle), "%s %s", g_szMenuPrefix, g_szMenuTypesTitle);
	g_iMenuTypes = menu_create(szTitle, "handleMenuTypes");
	for (new i = 0; i < g_iGagTypeCount; i++)
	{
		menu_additem(g_iMenuTypes, g_szGagTypes[i], "");
	}

	formatex(szTitle, charsmax(szTitle), "%s %s", g_szMenuPrefix, g_szMenuTimesTitle);
	g_iMenuTimes = menu_create(szTitle, "handleMenuTimes");
	for (new i = 0; i < g_iTimeCount; i++)
	{
		menu_additem(g_iMenuTimes, g_szTimeNames[i], "");
	}

	menu_setprop(g_iMenuReasons, MPROP_BACKNAME, "Geri");
	menu_setprop(g_iMenuReasons, MPROP_NEXTNAME, "Ileri");
	menu_setprop(g_iMenuReasons, MPROP_EXITNAME, "Cikis");

	menu_setprop(g_iMenuTypes, MPROP_BACKNAME, "Geri");
	menu_setprop(g_iMenuTypes, MPROP_NEXTNAME, "Ileri");
	menu_setprop(g_iMenuTypes, MPROP_EXITNAME, "Cikis");

	menu_setprop(g_iMenuTimes, MPROP_BACKNAME, "Geri");
	menu_setprop(g_iMenuTimes, MPROP_NEXTNAME, "Ileri");
	menu_setprop(g_iMenuTimes, MPROP_EXITNAME, "Cikis");
}

stock showGagPlayerMenu(id)
{
	if (g_iMenuGags != -1)
	{
		menu_destroy(g_iMenuGags);
		g_iMenuGags = -1;
	}

	new szTitle[128];
	formatex(szTitle, charsmax(szTitle), "%s %s", g_szMenuPrefix, g_szMenuGagsTitle);
	g_iMenuGags = menu_create(szTitle, "handleMenuGags");

	new players[32], pnum;
	get_players(players, pnum, "ch");

	new szName[32], szItem[128], szData[8];
	new bool:bFound = false;

	for (new i = 0; i < pnum; i++)
	{
		new player = players[i];

		if (!is_user_connected(player) || is_user_bot(player) || is_user_hltv(player))
		{
			continue;
		}

		get_user_name(player, szName, charsmax(szName));

		if (g_bGagged[player])
		{
			formatex(szItem, charsmax(szItem), "\d%s \r[GAGLI]", szName);
		}
		else
		{
			copy(szItem, charsmax(szItem), szName);
		}

		num_to_str(player, szData, charsmax(szData));
		menu_additem(g_iMenuGags, szItem, szData);
		bFound = true;
	}

	if (!bFound)
	{
		menu_additem(g_iMenuGags, "\dOyuncu bulunamadi", "0");
	}

	menu_setprop(g_iMenuGags, MPROP_BACKNAME, "Geri");
	menu_setprop(g_iMenuGags, MPROP_NEXTNAME, "Ileri");
	menu_setprop(g_iMenuGags, MPROP_EXITNAME, "Cikis");

	menu_display(id, g_iMenuGags, 0);
}

stock showUngagPlayerMenu(id)
{
	if (g_iMenuUngag != -1)
	{
		menu_destroy(g_iMenuUngag);
		g_iMenuUngag = -1;
	}

	new szTitle[128];
	formatex(szTitle, charsmax(szTitle), "%s Ungag Oyuncu Sec", g_szMenuPrefix);
	g_iMenuUngag = menu_create(szTitle, "handleMenuUngag");

	new players[32], pnum;
	get_players(players, pnum, "ch");

	new szName[32], szItem[128], szData[8];
	new bool:bFound = false;

	for (new i = 0; i < pnum; i++)
	{
		new player = players[i];
		if (!is_user_connected(player) || !g_bGagged[player])
		{
			continue;
		}

		get_user_name(player, szName, charsmax(szName));
		formatex(szItem, charsmax(szItem), "%s \y[%s]", szName, g_szSqlTypeText[g_iPlayerGagType[player]]);
		num_to_str(player, szData, charsmax(szData));
		menu_additem(g_iMenuUngag, szItem, szData);
		bFound = true;
	}

	if (!bFound)
	{
		menu_additem(g_iMenuUngag, "\dAktif gagli oyuncu yok", "0");
	}

	menu_setprop(g_iMenuUngag, MPROP_BACKNAME, "Geri");
	menu_setprop(g_iMenuUngag, MPROP_NEXTNAME, "Ileri");
	menu_setprop(g_iMenuUngag, MPROP_EXITNAME, "Cikis");

	menu_display(id, g_iMenuUngag, 0);
}

public handleMenuGags(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		return PLUGIN_HANDLED;
	}

	new szData[8], szName[64];
	new access, callback;
	menu_item_getinfo(menu, item, access, szData, charsmax(szData), szName, charsmax(szName), callback);

	new player = str_to_num(szData);
	if (!is_user_connected(player))
	{
		showGagPlayerMenu(id);
		return PLUGIN_HANDLED;
	}

	g_iSelectedPlayer[id] = player;
	g_szCustomReason[id][0] = 0;

	menu_display(id, g_iMenuReasons, 0);
	return PLUGIN_HANDLED;
}

public handleMenuReasons(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		showGagPlayerMenu(id);
		return PLUGIN_HANDLED;
	}

	new player = g_iSelectedPlayer[id];
	if (!is_user_connected(player))
	{
		showGagPlayerMenu(id);
		return PLUGIN_HANDLED;
	}

	g_iSelectedReason[id] = item;

	if (item == 0)
	{
		sendChat(id, "%s Ozel sebep yazin.", g_szChatPrefix);
		client_cmd(id, "messagemode gag_custom_reason");
		return PLUGIN_HANDLED;
	}

	copy(g_szCustomReason[id], charsmax(g_szCustomReason[]), g_szCleanReasons[item]);
	menu_display(id, g_iMenuTypes, 0);

	return PLUGIN_HANDLED;
}

public cmd_CustomReason(id)
{
	new player = g_iSelectedPlayer[id];
	if (!is_user_connected(player))
	{
		showGagPlayerMenu(id);
		return PLUGIN_HANDLED;
	}

	new szReason[128];
	read_args(szReason, charsmax(szReason));
	remove_quotes(szReason);
	trim(szReason);

	if (strlen(szReason) < MIN_REASON_LENGTH)
	{
		sendChat(id, "%s Sebep cok kisa.", g_szChatPrefix);
		menu_display(id, g_iMenuReasons, 0);
		return PLUGIN_HANDLED;
	}

	copy(g_szCustomReason[id], charsmax(g_szCustomReason[]), szReason);
	menu_display(id, g_iMenuTypes, 0);

	return PLUGIN_HANDLED;
}

public handleMenuTypes(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_display(id, g_iMenuReasons, 0);
		return PLUGIN_HANDLED;
	}

	g_iSelectedType[id] = item;
	menu_display(id, g_iMenuTimes, 0);

	return PLUGIN_HANDLED;
}

public handleMenuTimes(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_display(id, g_iMenuTypes, 0);
		return PLUGIN_HANDLED;
	}

	new player = g_iSelectedPlayer[id];
	if (!is_user_connected(player))
	{
		showGagPlayerMenu(id);
		return PLUGIN_HANDLED;
	}

	applyPlayerGag(id, player, g_szCustomReason[id], g_iGagTimes[item], g_iSelectedType[id]);
	showGagPlayerMenu(id);

	return PLUGIN_HANDLED;
}

public handleMenuUngag(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		return PLUGIN_HANDLED;
	}

	new szData[8], szName[64];
	new access, callback;
	menu_item_getinfo(menu, item, access, szData, charsmax(szData), szName, charsmax(szName), callback);

	new player = str_to_num(szData);
	if (!is_user_connected(player))
	{
		showUngagPlayerMenu(id);
		return PLUGIN_HANDLED;
	}

	removePlayerGag(id, player);
	showUngagPlayerMenu(id);

	return PLUGIN_HANDLED;
}

/* =========================
   VOICE BLOCK HELPERS
========================= */

stock blockPlayerVoice(id)
{
	if (!is_user_connected(id))
	{
		return;
	}

	set_speak(id, SPEAK_MUTED);

	if (g_fVoiceBlockingDelay > 0.0)
	{
		remove_task(TASK_VOICE_BLOCK + id);
		set_task(g_fVoiceBlockingDelay, "task_BlockPlayerVoice", TASK_VOICE_BLOCK + id);
	}
}

public task_BlockPlayerVoice(iTaskId)
{
	new id = iTaskId - TASK_VOICE_BLOCK;

	if (!is_user_connected(id))
	{
		return;
	}

	if (g_bGagged[id] && (g_iPlayerGagType[id] == TYPE_VOICE || g_iPlayerGagType[id] == TYPE_BOTH))
	{
		set_speak(id, SPEAK_MUTED);
	}
}

stock unblockPlayerVoice(id)
{
	remove_task(TASK_VOICE_BLOCK + id);

	if (is_user_connected(id))
	{
		set_speak(id, SPEAK_NORMAL);
	}
}

/* =========================
   CHAT / VOICE BLOCK
========================= */

public hook_Say(id)
{
	if (!is_user_connected(id))
	{
		return PLUGIN_CONTINUE;
	}

	if (g_bGagged[id] && (g_iPlayerGagType[id] == TYPE_CHAT || g_iPlayerGagType[id] == TYPE_BOTH))
	{
		if (isGagExpired(id))
		{
			clearLocalGag(id);
			return PLUGIN_CONTINUE;
		}

		notifyGagged(id);
		return PLUGIN_HANDLED;
	}

	if (g_bBadWordsEnabled && !g_bGagged[id])
	{
		new szMsg[192], szLower[192];
		read_args(szMsg, charsmax(szMsg));
		remove_quotes(szMsg);
		copy(szLower, charsmax(szLower), szMsg);
		strtolower(szLower);

		for (new i = 0; i < g_iBadWordCount; i++)
		{
			new szWord[32];
			copy(szWord, charsmax(szWord), g_szBadWords[i]);
			strtolower(szWord);

			if (contain(szLower, szWord) != -1)
			{
				automaticBadWordGag(id, g_szBadWords[i]);
				return PLUGIN_HANDLED;
			}
		}
	}

	return PLUGIN_CONTINUE;
}

public hook_Voice(id)
{
	if (!is_user_connected(id))
	{
		return PLUGIN_CONTINUE;
	}

	if (g_bGagged[id] && (g_iPlayerGagType[id] == TYPE_VOICE || g_iPlayerGagType[id] == TYPE_BOTH))
	{
		if (isGagExpired(id))
		{
			clearLocalGag(id);
			return PLUGIN_CONTINUE;
		}

		notifyGagged(id);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

/* =========================
   CORE
========================= */

stock applyPlayerGag(admin, player, const szReason[], iMinutes, iType)
{
	if (!is_user_connected(player))
	{
		return;
	}

	if (g_hSql == Empty_Handle)
	{
		connectToDatabase();
		if (g_hSql == Empty_Handle)
		{
			return;
		}
	}

	new szAdmin[32], szPlayer[32], szAuthid[35], szIp[32];
	get_user_name(admin, szAdmin, charsmax(szAdmin));
	get_user_name(player, szPlayer, charsmax(szPlayer));
	get_user_authid(player, szAuthid, charsmax(szAuthid));
	get_user_ip(player, szIp, charsmax(szIp), 1);

	new szEA[64], szEP[64], szEPlayer[64], szEAdmin[64], szEReason[256];
	sqlEscape(szAuthid, szEA, charsmax(szEA));
	sqlEscape(szIp, szEP, charsmax(szEP));
	sqlEscape(szPlayer, szEPlayer, charsmax(szEPlayer));
	sqlEscape(szAdmin, szEAdmin, charsmax(szEAdmin));
	sqlEscape(szReason, szEReason, charsmax(szEReason));

	new iExpire = (iMinutes > 0) ? (get_systime() + (iMinutes * 60)) : 0;

	new szDelete[256];
	formatex(szDelete, charsmax(szDelete),
		"DELETE FROM `%s` WHERE authid='%s' OR player_ip='%s'",
		g_szTableName, szEA, szEP);
	sqlSimpleQuery(szDelete);

	new szInsert[1024];
	formatex(szInsert, charsmax(szInsert),
		"INSERT INTO `%s` (`authid`,`player_ip`,`player_name`,`admin_name`,`reason`,`gag_minutes`,`expire_time`,`gag_type`,`gag_type_text`,`created_at`) VALUES ('%s','%s','%s','%s','%s',%d,%d,%d,'%s',%d)",
		g_szTableName,
		szEA, szEP, szEPlayer, szEAdmin, szEReason,
		iMinutes, iExpire, iType, g_szSqlTypeText[iType], get_systime());

	sqlSimpleQuery(szInsert);

	g_bGagged[player] = true;
	g_iPlayerGagType[player] = iType;
	g_iGagExpireTime[player] = iExpire;
	copy(g_szGagReason[player], charsmax(g_szGagReason[]), szReason);
	copy(g_szGagAdmin[player], charsmax(g_szGagAdmin[]), szAdmin);

	if (iType == TYPE_VOICE || iType == TYPE_BOTH)
	{
		blockPlayerVoice(player);
	}

	if (iMinutes > 0)
	{
		sendChat(0, "%s Admin ^3%s ^1oyuncu ^3%s ^1icin ^4%s ^1uyguladi. Sure: ^3%d dk^1 | Sebep: ^3%s",
			g_szChatPrefix, szAdmin, szPlayer, g_szSqlTypeText[iType], iMinutes, szReason);

		sendChat(player, "%s Uzerinize ^4%s ^1uygulandi. Admin: ^3%s^1 | Sure: ^3%d dk^1 | Sebep: ^3%s",
			g_szChatPrefix, g_szSqlTypeText[iType], szAdmin, iMinutes, szReason);
	}
	else
	{
		sendChat(0, "%s Admin ^3%s ^1oyuncu ^3%s ^1icin ^4%s ^1uyguladi. Sure: ^3Kalici^1 | Sebep: ^3%s",
			g_szChatPrefix, szAdmin, szPlayer, g_szSqlTypeText[iType], szReason);

		sendChat(player, "%s Uzerinize ^4%s ^1uygulandi. Admin: ^3%s^1 | Sure: ^3Kalici^1 | Sebep: ^3%s",
			g_szChatPrefix, g_szSqlTypeText[iType], szAdmin, szReason);
	}

	showHudAction(szAdmin, szPlayer, g_szSqlTypeText[iType], szReason);

	if (g_szGagSound[0])
	{
		client_cmd(0, "spk ^"%s^"", g_szGagSound);
	}

	new szLog[256];
	if (iMinutes > 0)
	{
		formatex(szLog, charsmax(szLog),
			"Admin %s oyuncu %s icin %d dakika sureyle '%s' sebebiyle gag uyguladi (Tur: %s)",
			szAdmin, szPlayer, iMinutes, szReason, g_szSqlTypeText[iType]);
	}
	else
	{
		formatex(szLog, charsmax(szLog),
			"Admin %s oyuncu %s icin '%s' sebebiyle kalici gag uyguladi (Tur: %s)",
			szAdmin, szPlayer, szReason, g_szSqlTypeText[iType]);
	}
	writeGagLog(szLog);
}

stock removePlayerGag(admin, player)
{
	if (!is_user_connected(player))
	{
		return;
	}

	if (g_hSql == Empty_Handle)
	{
		connectToDatabase();
		if (g_hSql == Empty_Handle)
		{
			return;
		}
	}

	new szAdmin[32], szPlayer[32], szAuthid[35], szIp[32];
	get_user_name(admin, szAdmin, charsmax(szAdmin));
	get_user_name(player, szPlayer, charsmax(szPlayer));
	get_user_authid(player, szAuthid, charsmax(szAuthid));
	get_user_ip(player, szIp, charsmax(szIp), 1);

	new szEA[64], szEP[64];
	sqlEscape(szAuthid, szEA, charsmax(szEA));
	sqlEscape(szIp, szEP, charsmax(szEP));

	new szDelete[256];
	formatex(szDelete, charsmax(szDelete),
		"DELETE FROM `%s` WHERE authid='%s' OR player_ip='%s'",
		g_szTableName, szEA, szEP);

	sqlSimpleQuery(szDelete);

	new iOldType = g_iPlayerGagType[player];

	if (iOldType == TYPE_VOICE || iOldType == TYPE_BOTH)
	{
		unblockPlayerVoice(player);
	}

	resetPlayerGag(player);

	sendChat(0, "%s Admin ^3%s ^1oyuncu ^3%s ^1uzerindeki gag'i kaldirdi. Eski tur: ^4%s",
		g_szChatPrefix, szAdmin, szPlayer, g_szSqlTypeText[iOldType]);

	sendChat(player, "%s Gag'iniz admin ^3%s ^1tarafindan kaldirildi.",
		g_szChatPrefix, szAdmin);

	showHudAction(szAdmin, szPlayer, "Gag Kaldirildi", "");

	if (g_szUngagSound[0])
	{
		client_cmd(0, "spk ^"%s^"", g_szUngagSound);
	}

	new szLog[256];
	formatex(szLog, charsmax(szLog), "Admin %s oyuncu %s uzerindeki gag'i kaldirdi", szAdmin, szPlayer);
	writeGagLog(szLog);
}

stock loadPlayerGag(id)
{
	if (!is_user_connected(id))
	{
		return;
	}

	if (g_hSql == Empty_Handle)
	{
		connectToDatabase();
		if (g_hSql == Empty_Handle)
		{
			return;
		}
	}

	new szAuthid[35], szIp[32];
	get_user_authid(id, szAuthid, charsmax(szAuthid));
	get_user_ip(id, szIp, charsmax(szIp), 1);

	new szEA[64], szEP[64];
	sqlEscape(szAuthid, szEA, charsmax(szEA));
	sqlEscape(szIp, szEP, charsmax(szEP));

	new szQuery[512];
	formatex(szQuery, charsmax(szQuery),
		"SELECT admin_name, reason, expire_time, gag_type FROM `%s` WHERE (authid='%s' OR player_ip='%s') AND (expire_time=0 OR expire_time>%d) ORDER BY id DESC LIMIT 1",
		g_szTableName, szEA, szEP, get_systime());

	new Handle:hQuery = SQL_PrepareQuery(g_hSql, szQuery);
	if (!SQL_Execute(hQuery))
	{
		new szErr[256];
		SQL_QueryError(hQuery, szErr, charsmax(szErr));
		log_amx("[SQL-GAG] Oyuncu gag kontrol SQL hata: %s", szErr);
		SQL_FreeHandle(hQuery);
		return;
	}

	if (SQL_NumResults(hQuery) > 0)
	{
		g_bGagged[id] = true;
		SQL_ReadResult(hQuery, 0, g_szGagAdmin[id], charsmax(g_szGagAdmin[]));
		SQL_ReadResult(hQuery, 1, g_szGagReason[id], charsmax(g_szGagReason[]));
		g_iGagExpireTime[id] = SQL_ReadResult(hQuery, 2);
		g_iPlayerGagType[id] = SQL_ReadResult(hQuery, 3);

		if (g_iPlayerGagType[id] == TYPE_VOICE || g_iPlayerGagType[id] == TYPE_BOTH)
		{
			blockPlayerVoice(id);
		}
	}
	else
	{
		if (g_bGagged[id] && (g_iPlayerGagType[id] == TYPE_VOICE || g_iPlayerGagType[id] == TYPE_BOTH))
		{
			unblockPlayerVoice(id);
		}
		resetPlayerGag(id);
	}

	SQL_FreeHandle(hQuery);
}

stock automaticBadWordGag(id, const szWord[])
{
	if (!is_user_connected(id) || g_bGagged[id])
	{
		return;
	}

	new szReason[128];
	formatex(szReason, charsmax(szReason), "Kotu Kelime (%s)", szWord);
	applySystemGag(id, szReason, g_iBadWordGagTime, g_iBadWordGagType, true);

	copy(g_szGagAdmin[id], charsmax(g_szGagAdmin[]), "SYSTEM");
	sendChat(id, "%s Yasakli kelime kullandiginiz icin otomatik gag uygulandi.", g_szChatPrefix);
}

stock notifyGagged(id)
{
	if (!is_user_connected(id))
	{
		return;
	}

	if (isGagExpired(id))
	{
		clearLocalGag(id);
		return;
	}

	if (g_iGagExpireTime[id] == 0)
	{
		sendChat(id, "%s Uzerinizde ^4%s ^1var. Sure: ^3Kalici^1 | Admin: ^3%s^1 | Sebep: ^3%s",
			g_szChatPrefix, g_szSqlTypeText[g_iPlayerGagType[id]], g_szGagAdmin[id], g_szGagReason[id]);
	}
	else
	{
		new iLeft = (g_iGagExpireTime[id] - get_systime()) / 60;
		if (iLeft < 0) iLeft = 0;

		sendChat(id, "%s Uzerinizde ^4%s ^1var. Kalan sure: ^3%d dk^1 | Admin: ^3%s^1 | Sebep: ^3%s",
			g_szChatPrefix, g_szSqlTypeText[g_iPlayerGagType[id]], iLeft, g_szGagAdmin[id], g_szGagReason[id]);
	}
}

stock bool:isGagExpired(id)
{
	if (!g_bGagged[id])
	{
		return false;
	}

	if (g_iGagExpireTime[id] == 0)
	{
		return false;
	}

	return (g_iGagExpireTime[id] <= get_systime());
}

stock clearLocalGag(id)
{
	if (g_iPlayerGagType[id] == TYPE_VOICE || g_iPlayerGagType[id] == TYPE_BOTH)
	{
		unblockPlayerVoice(id);
	}

	resetPlayerGag(id);
}

stock resetPlayerGag(id)
{
	g_bGagged[id] = false;
	g_iPlayerGagType[id] = TYPE_CHAT;
	g_iGagExpireTime[id] = 0;
	g_szGagReason[id][0] = 0;
	g_szGagAdmin[id][0] = 0;
}

/* =========================
   SQL
========================= */

stock connectToDatabase()
{
	if (g_hSql != Empty_Handle)
	{
		return;
	}

	g_hTuple = SQL_MakeDbTuple(g_szDbHost, g_szDbUser, g_szDbPass, g_szDbName);

	new iErr, szErr[256];
	g_hSql = SQL_Connect(g_hTuple, iErr, szErr, charsmax(szErr));

	if (g_hSql == Empty_Handle)
	{
		log_amx("[SQL-GAG] SQL baglanti hatasi: %s (%d)", szErr, iErr);
	}
	else
	{
		server_print("[SQL-GAG] SQL baglanti basarili.");
	}
}

stock sqlCreateTable()
{
	if (g_hSql == Empty_Handle)
	{
		return;
	}

	new szQuery[1024];
	formatex(szQuery, charsmax(szQuery),
		"CREATE TABLE IF NOT EXISTS `%s` (\
		`id` INT NOT NULL AUTO_INCREMENT,\
		`authid` VARCHAR(35) NOT NULL,\
		`player_ip` VARCHAR(32) NOT NULL,\
		`player_name` VARCHAR(32) NOT NULL,\
		`admin_name` VARCHAR(32) NOT NULL,\
		`reason` VARCHAR(128) NOT NULL,\
		`gag_minutes` INT NOT NULL DEFAULT 0,\
		`expire_time` INT NOT NULL DEFAULT 0,\
		`gag_type` INT NOT NULL DEFAULT 0,\
		`gag_type_text` VARCHAR(64) NOT NULL DEFAULT 'Chat Gag',\
		`created_at` INT NOT NULL DEFAULT 0,\
		PRIMARY KEY (`id`),\
		KEY `authid` (`authid`),\
		KEY `player_ip` (`player_ip`),\
		KEY `expire_time` (`expire_time`)\
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
		g_szTableName);

	sqlSimpleQuery(szQuery);
}

stock bool:sqlSimpleQuery(const szQuery[])
{
	if (g_hSql == Empty_Handle)
	{
		return false;
	}

	new Handle:hQuery = SQL_PrepareQuery(g_hSql, szQuery);
	if (!SQL_Execute(hQuery))
	{
		new szErr[256];
		SQL_QueryError(hQuery, szErr, charsmax(szErr));
		log_amx("[SQL-GAG] SQL hata: %s | Query: %s", szErr, szQuery);
		SQL_FreeHandle(hQuery);
		return false;
	}

	SQL_FreeHandle(hQuery);
	return true;
}

stock sqlEscape(const szInput[], szOutput[], iLen)
{
	copy(szOutput, iLen, szInput);
	replace_all(szOutput, iLen, "\", "\\");
	replace_all(szOutput, iLen, "'", "\'");
}

/* =========================
   CONFIG LOAD
========================= */

stock loadConfiguration()
{
	new szPath[256];
	get_configsdir(szPath, charsmax(szPath));
	add(szPath, charsmax(szPath), "/");
	add(szPath, charsmax(szPath), CONFIG_FILE);

	if (!file_exists(szPath))
	{
		createDefaultConfig(szPath);
	}

	iniReadString(szPath, "Database", "DB_HOST", g_szDbHost, charsmax(g_szDbHost), "sql.csarea.net");
	iniReadString(szPath, "Database", "DB_USER", g_szDbUser, charsmax(g_szDbUser), "srv212_100_185_");
	iniReadString(szPath, "Database", "DB_PASS", g_szDbPass, charsmax(g_szDbPass), "");
	iniReadString(szPath, "Database", "DB_NAME", g_szDbName, charsmax(g_szDbName), "srv212_100_185_");

	iniReadString(szPath, "Menu", "MENU_PREFIX", g_szMenuPrefix, charsmax(g_szMenuPrefix), "\r[\yGAG SISTEMI\r]");
	iniReadString(szPath, "Menu", "MENU_GAGS_TITLE", g_szMenuGagsTitle, charsmax(g_szMenuGagsTitle), "Oyuncu Sec:");
	iniReadString(szPath, "Menu", "MENU_REASONS_TITLE", g_szMenuReasonsTitle, charsmax(g_szMenuReasonsTitle), "Sebep Sec:");
	iniReadString(szPath, "Menu", "MENU_TIMES_TITLE", g_szMenuTimesTitle, charsmax(g_szMenuTimesTitle), "Sure Sec:");
	iniReadString(szPath, "Menu", "MENU_TYPES_TITLE", g_szMenuTypesTitle, charsmax(g_szMenuTypesTitle), "Gag Turu Sec:");

	iniReadString(szPath, "Chat", "CHAT_PREFIX", g_szChatPrefix, charsmax(g_szChatPrefix), "&x04[SQL-GAG]&x01");

	g_iMaxReasons = iniReadInt(szPath, "Limitler", "MAX_REASONS", 10);
	g_iMaxTimes = iniReadInt(szPath, "Limitler", "MAX_TIMES", 10);
	g_iMaxBadWords = iniReadInt(szPath, "Limitler", "MAX_BAD_WORDS", 20);

	if (g_iMaxReasons > MAX_REASONS) g_iMaxReasons = MAX_REASONS;
	if (g_iMaxTimes > MAX_TIMES) g_iMaxTimes = MAX_TIMES;
	if (g_iMaxBadWords > MAX_BAD_WORDS) g_iMaxBadWords = MAX_BAD_WORDS;

	loadReasons(szPath);
	loadTimes(szPath);
	loadGagTypes(szPath);

	g_fHudX = iniReadFloat(szPath, "HUD", "HUD_X", -1.0);
	g_fHudY = iniReadFloat(szPath, "HUD", "HUD_Y", 0.25);
	g_fHudHoldTime = iniReadFloat(szPath, "HUD", "HUD_HOLDTIME", 5.0);
	g_fHudFadeIn = iniReadFloat(szPath, "HUD", "HUD_FADEIN", 0.1);
	g_fHudFadeOut = iniReadFloat(szPath, "HUD", "HUD_FADEOUT", 0.2);
	g_iHudEffect = iniReadInt(szPath, "HUD", "HUD_EFFECT", 2);

	g_fCheckExpiredInterval = iniReadFloat(szPath, "Gorevler", "CHECK_EXPIRED_INTERVAL", 30.0);
	g_fDoubleCheckDelay = iniReadFloat(szPath, "Gorevler", "DOUBLE_CHECK_DELAY", 1.0);
	g_fVoiceBlockingDelay = iniReadFloat(szPath, "Gorevler", "VOICE_BLOCKING_DELAY", 2.0);

	new szFlag[32];
	iniReadString(szPath, "Erisim", "GAG_ACCESS", szFlag, charsmax(szFlag), "ADMIN_SLAY");
	g_iGagAccess = accessStringToFlags(szFlag);

	iniReadString(szPath, "Erisim", "UNGAG_ACCESS", szFlag, charsmax(szFlag), "ADMIN_SLAY");
	g_iUngagAccess = accessStringToFlags(szFlag);

	iniReadString(szPath, "Erisim", "CLEAN_ACCESS", szFlag, charsmax(szFlag), "ADMIN_RCON");
	g_iCleanAccess = accessStringToFlags(szFlag);

	iniReadString(szPath, "Erisim", "LIST_ACCESS", szFlag, charsmax(szFlag), "ADMIN_SLAY");
	g_iListAccess = accessStringToFlags(szFlag);

	g_bBadWordsEnabled = bool:iniReadInt(szPath, "Kotu Kelimeler", "ENABLED", 1);
	g_iBadWordGagTime = iniReadInt(szPath, "Kotu Kelimeler", "GAG_TIME", 5);
	g_iBadWordGagType = iniReadInt(szPath, "Kotu Kelimeler", "GAG_TYPE", 0);

	loadBadWords(szPath);

	g_bLogsEnabled = bool:iniReadInt(szPath, "Logs", "LOGS_ENABLED", 1);
	iniReadString(szPath, "Logs", "LOGS_FILE", g_szLogsFile, charsmax(g_szLogsFile), "gagsystem.log");

	iniReadString(szPath, "Sounds", "GAG_SOUND", g_szGagSound, charsmax(g_szGagSound), "");
	iniReadString(szPath, "Sounds", "UNGAG_SOUND", g_szUngagSound, charsmax(g_szUngagSound), "");
	iniReadString(szPath, "Sounds", "EXPIRE_GAG_SOUND", g_szExpireGagSound, charsmax(g_szExpireGagSound), "");

	g_bEnableChecks = bool:iniReadInt(szPath, "Kontroller", "ENABLE_CHECKS", 1);

	g_bAnnounceExistingGagOnJoin = bool:iniReadInt(szPath, "Baglanti", "ANNOUNCE_EXISTING_GAG_ON_JOIN", 1);
	g_bShowJoinInfoToPlayer = bool:iniReadInt(szPath, "Baglanti", "SHOW_JOIN_INFO_TO_PLAYER", 1);
	g_iJoinInfoSeconds = iniReadInt(szPath, "Baglanti", "JOIN_INFO_SECONDS", 120);

	g_bAutoGagOnJoinEnabled = bool:iniReadInt(szPath, "Baglanti", "AUTO_GAG_ON_JOIN_ENABLED", 0);
	g_iAutoGagOnJoinMinutes = iniReadInt(szPath, "Baglanti", "AUTO_GAG_ON_JOIN_MINUTES", 2);
	g_iAutoGagOnJoinType = iniReadInt(szPath, "Baglanti", "AUTO_GAG_ON_JOIN_TYPE", 0);
	iniReadString(szPath, "Baglanti", "AUTO_GAG_ON_JOIN_REASON", g_szAutoGagOnJoinReason, charsmax(g_szAutoGagOnJoinReason), "Ilk giris susturma");
	g_bAutoGagOnJoinAnnounceAll = bool:iniReadInt(szPath, "Baglanti", "AUTO_GAG_ON_JOIN_ANNOUNCE_ALL", 0);
	g_bAutoGagOnlyOncePerMap = bool:iniReadInt(szPath, "Baglanti", "AUTO_GAG_ONLY_ONCE_PER_MAP", 1);
	g_bAutoGagSkipAdmins = bool:iniReadInt(szPath, "Baglanti", "AUTO_GAG_SKIP_ADMINS", 1);

	if (g_iAutoGagOnJoinType < TYPE_CHAT || g_iAutoGagOnJoinType > TYPE_BOTH)
	{
		g_iAutoGagOnJoinType = TYPE_CHAT;
	}

	if (g_iBadWordGagType < TYPE_CHAT || g_iBadWordGagType > TYPE_BOTH)
	{
		g_iBadWordGagType = TYPE_CHAT;
	}
}

stock loadReasons(const szPath[])
{
	g_iReasonCount = 0;

	new szKey[32], szValue[256], szDisplay[128], szClean[128];
	for (new i = 1; i <= g_iMaxReasons; i++)
	{
		formatex(szKey, charsmax(szKey), "REASON_%d", i);
		iniReadString(szPath, "Reasons", szKey, szValue, charsmax(szValue), "");

		if (!szValue[0])
		{
			continue;
		}

		splitPair(szValue, szDisplay, charsmax(szDisplay), szClean, charsmax(szClean));

		if (!szDisplay[0] || !szClean[0])
		{
			continue;
		}

		copy(g_szReasons[g_iReasonCount], charsmax(g_szReasons[]), szDisplay);
		copy(g_szCleanReasons[g_iReasonCount], charsmax(g_szCleanReasons[]), szClean);
		g_iReasonCount++;
	}
}

stock loadTimes(const szPath[])
{
	g_iTimeCount = 0;

	new szKey[32], szValue[256], szDisplay[128], szMinutes[64];
	for (new i = 1; i <= g_iMaxTimes; i++)
	{
		formatex(szKey, charsmax(szKey), "TIME_%d", i);
		iniReadString(szPath, "Sureler", szKey, szValue, charsmax(szValue), "");

		if (!szValue[0])
		{
			continue;
		}

		splitPair(szValue, szDisplay, charsmax(szDisplay), szMinutes, charsmax(szMinutes));

		if (!szDisplay[0])
		{
			continue;
		}

		copy(g_szTimeNames[g_iTimeCount], charsmax(g_szTimeNames[]), szDisplay);
		g_iGagTimes[g_iTimeCount] = str_to_num(szMinutes);
		g_iTimeCount++;
	}
}

stock loadGagTypes(const szPath[])
{
	g_iGagTypeCount = 0;

	new szKey[32], szValue[256], szDisplay[128], szClean[128];
	for (new i = 1; i <= MAX_TYPES; i++)
	{
		formatex(szKey, charsmax(szKey), "TYPE_%d", i);
		iniReadString(szPath, "GagTypes", szKey, szValue, charsmax(szValue), "");

		if (!szValue[0])
		{
			continue;
		}

		splitPair(szValue, szDisplay, charsmax(szDisplay), szClean, charsmax(szClean));

		if (!szDisplay[0] || !szClean[0])
		{
			continue;
		}

		copy(g_szGagTypes[g_iGagTypeCount], charsmax(g_szGagTypes[]), szDisplay);
		copy(g_szCleanGagTypes[g_iGagTypeCount], charsmax(g_szCleanGagTypes[]), szClean);
		g_iGagTypeCount++;
	}
}

stock loadBadWords(const szPath[])
{
	g_iBadWordCount = 0;

	new szKey[32], szValue[64];
	for (new i = 1; i <= g_iMaxBadWords; i++)
	{
		formatex(szKey, charsmax(szKey), "WORD_%d", i);
		iniReadString(szPath, "Kotu Kelimeler", szKey, szValue, charsmax(szValue), "");

		if (!szValue[0])
		{
			continue;
		}

		copy(g_szBadWords[g_iBadWordCount], charsmax(g_szBadWords[]), szValue);
		g_iBadWordCount++;
	}
}

stock createDefaultConfig(const szPath[])
{
	new fp = fopen(szPath, "wt");
	if (!fp)
	{
		log_amx("[SQL-GAG] Varsayilan config olusturulamadi: %s", szPath);
		return;
	}

	fputs(fp, "; SQL Gag Sistemi Yapilandirma Dosyasi^n");
	fputs(fp, "; Eklenti: Onur MrStipFan MASALCI - CSArea.net^n");
	fputs(fp, "; Otomatik olusturulan varsayilan yapilandirma^n^n");

	fputs(fp, "[Database]^n");
	fputs(fp, "DB_HOST = sql.csarea.net^n");
	fputs(fp, "DB_USER = srv212_100_185_^n");
	fputs(fp, "DB_PASS = ^n");
	fputs(fp, "DB_NAME = srv212_100_185_^n^n");

	fputs(fp, "[Menu]^n");
	fputs(fp, "MENU_PREFIX = \r[\ySQL GAG SISTEMI\r]^n");
	fputs(fp, "MENU_GAGS_TITLE = Oyuncu Sec:^n");
	fputs(fp, "MENU_REASONS_TITLE = Sebep Sec:^n");
	fputs(fp, "MENU_TIMES_TITLE = Sure Sec:^n");
	fputs(fp, "MENU_TYPES_TITLE = Gag Turu Sec:^n^n");

	fputs(fp, "[Chat]^n");
	fputs(fp, "CHAT_PREFIX = &x04[SQL-GAG]&x01^n^n");

	fputs(fp, "[Reasons]^n");
	fputs(fp, "REASON_1 = \r*\w Ozel Sebep...|Ozel Sebep^n");
	fputs(fp, "REASON_2 = \y*\w Spam|Spam^n");
	fputs(fp, "REASON_3 = \y*\w Hakaret/Asagilama|Hakaret/Asagilama^n");
	fputs(fp, "REASON_4 = \y*\w Reklam|Reklam^n");
	fputs(fp, "REASON_5 = \y*\w Kufur|Kufur^n");
	fputs(fp, "REASON_6 = \y*\w Mikrofon Spam|Mikrofon Spam^n");
	fputs(fp, "REASON_7 = \y*\w Uygunsuz Davranis|Uygunsuz Davranis^n^n");

	fputs(fp, "[Sureler]^n");
	fputs(fp, "TIME_1 = \r5 \wdakika|5^n");
	fputs(fp, "TIME_2 = \y15 \wdakika|15^n");
	fputs(fp, "TIME_3 = \y30 \wdakika|30^n");
	fputs(fp, "TIME_4 = \w1 \ysaat|60^n");
	fputs(fp, "TIME_5 = \w2 \ysaat|120^n");
	fputs(fp, "TIME_6 = \w6 \ysaat|360^n");
	fputs(fp, "TIME_7 = \w12 \ysaat|720^n");
	fputs(fp, "TIME_8 = \w1 \ygun|1440^n");
	fputs(fp, "TIME_9 = \w3 \ygun|4320^n");
	fputs(fp, "TIME_10 = \rKalici|0^n^n");

	fputs(fp, "[GagTypes]^n");
	fputs(fp, "TYPE_1 = \w*\y Sadece Chat|Chat^n");
	fputs(fp, "TYPE_2 = \w*\r Sadece Ses|Voice^n");
	fputs(fp, "TYPE_3 = \w*\g Chat + Ses|Chat + Voice^n^n");

	fputs(fp, "[HUD]^n");
	fputs(fp, "HUD_X = -1.0^n");
	fputs(fp, "HUD_Y = 0.25^n");
	fputs(fp, "HUD_HOLDTIME = 5.0^n");
	fputs(fp, "HUD_FADEIN = 0.1^n");
	fputs(fp, "HUD_FADEOUT = 0.2^n");
	fputs(fp, "HUD_EFFECT = 2^n^n");

	fputs(fp, "[Gorevler]^n");
	fputs(fp, "CHECK_EXPIRED_INTERVAL = 30.0^n");
	fputs(fp, "DOUBLE_CHECK_DELAY = 1.0^n");
	fputs(fp, "VOICE_BLOCKING_DELAY = 2.0^n^n");

	fputs(fp, "[Erisim]^n");
	fputs(fp, "GAG_ACCESS = ADMIN_SLAY^n");
	fputs(fp, "UNGAG_ACCESS = ADMIN_SLAY^n");
	fputs(fp, "CLEAN_ACCESS = ADMIN_RCON^n");
	fputs(fp, "LIST_ACCESS = ADMIN_SLAY^n^n");

	fputs(fp, "[Kotu Kelimeler]^n");
	fputs(fp, "ENABLED = 1^n");
	fputs(fp, "GAG_TIME = 20^n");
	fputs(fp, "GAG_TYPE = 2^n");
	fputs(fp, "WORD_1 = gay^n");
	fputs(fp, "WORD_2 = idiot^n");
	fputs(fp, "WORD_3 = stupid^n");
	fputs(fp, "WORD_4 = noob^n");
	fputs(fp, "WORD_5 = retard^n");
	fputs(fp, "WORD_6 = moron^n");
	fputs(fp, "WORD_7 = dumb^n");
	fputs(fp, "WORD_8 = loser^n^n");

	fputs(fp, "[Limitler]^n");
	fputs(fp, "MAX_REASONS = 50^n");
	fputs(fp, "MAX_TIMES = 50^n");
	fputs(fp, "MAX_BAD_WORDS = 50^n^n");

	fputs(fp, "[Logs]^n");
	fputs(fp, "LOGS_ENABLED = 1^n");
	fputs(fp, "LOGS_FILE = gagsystem.log^n^n");

	fputs(fp, "[Sounds]^n");
	fputs(fp, "GAG_SOUND = ^n");
	fputs(fp, "UNGAG_SOUND = ^n");
	fputs(fp, "EXPIRE_GAG_SOUND = ^n^n");

	fputs(fp, "[Kontroller]^n");
	fputs(fp, "ENABLE_CHECKS = 1^n^n");

	fputs(fp, "[Baglanti]^n");
	fputs(fp, "ANNOUNCE_EXISTING_GAG_ON_JOIN = 1^n");
	fputs(fp, "SHOW_JOIN_INFO_TO_PLAYER = 1^n");
	fputs(fp, "JOIN_INFO_SECONDS = 120^n");
	fputs(fp, "AUTO_GAG_ON_JOIN_ENABLED = 0^n");
	fputs(fp, "AUTO_GAG_ON_JOIN_MINUTES = 2^n");
	fputs(fp, "AUTO_GAG_ON_JOIN_TYPE = 0^n");
	fputs(fp, "AUTO_GAG_ON_JOIN_REASON = Ilk giris susturma^n");
	fputs(fp, "AUTO_GAG_ON_JOIN_ANNOUNCE_ALL = 0^n");
	fputs(fp, "AUTO_GAG_ONLY_ONCE_PER_MAP = 1^n");
	fputs(fp, "AUTO_GAG_SKIP_ADMINS = 1^n");

	fclose(fp);
}

/* =========================
   INI HELPERS
========================= */

stock iniReadString(const file[], const section[], const key[], output[], len, const defvalue[] = "")
{
	new szLine[256], szCurrentSection[64];
	new bool:inSection = false;

	new fp = fopen(file, "rt");
	if (!fp)
	{
		copy(output, len, defvalue);
		return 0;
	}

	while (!feof(fp))
	{
		fgets(fp, szLine, charsmax(szLine));
		trim(szLine);

		if (!szLine[0] || szLine[0] == ';' || szLine[0] == '#')
		{
			continue;
		}

		if (szLine[0] == '[')
		{
			new iEnd = strlen(szLine) - 1;
			if (iEnd > 0 && szLine[iEnd] == ']')
			{
				szLine[iEnd] = 0;
				copy(szCurrentSection, charsmax(szCurrentSection), szLine[1]);
				inSection = equal(szCurrentSection, section) ? true : false;
			}
			continue;
		}

		if (inSection)
		{
			new iPos = contain(szLine, "=");
			if (iPos != -1)
			{
				new szKey[64], szValue[192];
				copy(szKey, charsmax(szKey), szLine);
				szKey[iPos] = 0;
				trim(szKey);

				if (equal(szKey, key))
				{
					copy(szValue, charsmax(szValue), szLine[iPos + 1]);
					trim(szValue);
					copy(output, len, szValue);
					fclose(fp);
					return 1;
				}
			}
		}
	}

	fclose(fp);
	copy(output, len, defvalue);
	return 0;
}

stock iniReadInt(const file[], const section[], const key[], defvalue = 0)
{
	new szValue[32];
	if (iniReadString(file, section, key, szValue, charsmax(szValue), ""))
	{
		return str_to_num(szValue);
	}
	return defvalue;
}

stock Float:iniReadFloat(const file[], const section[], const key[], Float:defvalue = 0.0)
{
	new szValue[32];
	if (iniReadString(file, section, key, szValue, charsmax(szValue), ""))
	{
		return str_to_float(szValue);
	}
	return defvalue;
}

stock splitPair(const szInput[], szLeft[], iLeftLen, szRight[], iRightLen)
{
	szLeft[0] = 0;
	szRight[0] = 0;

	new iPos = contain(szInput, "|");
	if (iPos == -1)
	{
		copy(szLeft, iLeftLen, szInput);
		return;
	}

	copy(szLeft, iLeftLen, szInput);
	szLeft[iPos] = 0;
	trim(szLeft);

	copy(szRight, iRightLen, szInput[iPos + 1]);
	trim(szRight);
}

stock accessStringToFlags(const szAccess[])
{
	if (equal(szAccess, "ADMIN_IMMUNITY")) return ADMIN_IMMUNITY;
	if (equal(szAccess, "ADMIN_RESERVATION")) return ADMIN_RESERVATION;
	if (equal(szAccess, "ADMIN_KICK")) return ADMIN_KICK;
	if (equal(szAccess, "ADMIN_BAN")) return ADMIN_BAN;
	if (equal(szAccess, "ADMIN_SLAY")) return ADMIN_SLAY;
	if (equal(szAccess, "ADMIN_MAP")) return ADMIN_MAP;
	if (equal(szAccess, "ADMIN_CVAR")) return ADMIN_CVAR;
	if (equal(szAccess, "ADMIN_CFG")) return ADMIN_CFG;
	if (equal(szAccess, "ADMIN_CHAT")) return ADMIN_CHAT;
	if (equal(szAccess, "ADMIN_VOTE")) return ADMIN_VOTE;
	if (equal(szAccess, "ADMIN_PASSWORD")) return ADMIN_PASSWORD;
	if (equal(szAccess, "ADMIN_RCON")) return ADMIN_RCON;
	if (equal(szAccess, "ADMIN_LEVEL_A")) return ADMIN_LEVEL_A;
	if (equal(szAccess, "ADMIN_LEVEL_B")) return ADMIN_LEVEL_B;
	if (equal(szAccess, "ADMIN_LEVEL_C")) return ADMIN_LEVEL_C;
	if (equal(szAccess, "ADMIN_LEVEL_D")) return ADMIN_LEVEL_D;
	if (equal(szAccess, "ADMIN_LEVEL_E")) return ADMIN_LEVEL_E;
	if (equal(szAccess, "ADMIN_LEVEL_F")) return ADMIN_LEVEL_F;
	if (equal(szAccess, "ADMIN_LEVEL_G")) return ADMIN_LEVEL_G;
	if (equal(szAccess, "ADMIN_LEVEL_H")) return ADMIN_LEVEL_H;
	if (equal(szAccess, "ADMIN_MENU")) return ADMIN_MENU;
	if (equal(szAccess, "ADMIN_ADMIN")) return ADMIN_ADMIN;
	if (equal(szAccess, "ADMIN_USER")) return ADMIN_USER;

	return read_flags(szAccess);
}

/* =========================
   CHAT / HUD / LOG
========================= */

stock sendChat(const id, const input[], any:...)
{
	static szMsg[191];
	vformat(szMsg, charsmax(szMsg), input, 3);

	replace_all(szMsg, charsmax(szMsg), "&x04", "^4");
	replace_all(szMsg, charsmax(szMsg), "&x03", "^3");
	replace_all(szMsg, charsmax(szMsg), "&x01", "^1");

	if (id)
	{
		message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, id);
		write_byte(id);
		write_string(szMsg);
		message_end();
	}
	else
	{
		for (new i = 1; i <= 32; i++)
		{
			if (!is_user_connected(i))
			{
				continue;
			}

			message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, i);
			write_byte(i);
			write_string(szMsg);
			message_end();
		}
	}
}

stock showHudAction(const szAdmin[], const szPlayer[], const szType[], const szReason[])
{
	new szText[256];
	if (szReason[0])
	{
		formatex(szText, charsmax(szText), "Admin: %s^nOyuncu: %s^nTur: %s^nSebep: %s",
			szAdmin, szPlayer, szType, szReason);
	}
	else
	{
		formatex(szText, charsmax(szText), "Admin: %s^nOyuncu: %s^nDurum: %s",
			szAdmin, szPlayer, szType);
	}

	set_hudmessage(255, 50, 50, g_fHudX, g_fHudY, g_iHudEffect, g_fHudFadeIn, g_fHudHoldTime, g_fHudFadeOut, 0.0, 2);
	show_hudmessage(0, szText);
}

stock writeGagLog(const szMessage[])
{
	if (!g_bLogsEnabled || !g_szLogsFile[0])
	{
		return;
	}

	new szLogPath[256];
	get_localinfo("amxx_logs", szLogPath, charsmax(szLogPath));
	format(szLogPath, charsmax(szLogPath), "%s/%s", szLogPath, g_szLogsFile);

	new szTime[32];
	get_time("%m/%d/%Y - %H:%M:%S", szTime, charsmax(szTime));

	new fp = fopen(szLogPath, "at");
	if (!fp)
	{
		return;
	}

	fprintf(fp, "L %s: %s^n", szTime, szMessage);
	fclose(fp);
}