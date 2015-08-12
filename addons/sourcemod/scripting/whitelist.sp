#pragma semicolon 1

#include <sourcemod>
#include <morecolors>

#define PLUGIN_VERSION "1.0.0"
#define WHITELIST_PATH "configs/player_whitelist.cfg"

public Plugin:myinfo =
{
	name = "Player Whitelist & Reserved Slots",
	author = "Stackia",
	description = "Provides basic reserved slots and player whitelist",
	version = PLUGIN_VERSION,
	url = "http://www.keylol.com/"
};

new g_adminCount = 0;
new bool:g_isAdmin[MAXPLAYERS+1];
new Handle:g_whitelistKv;

/* Handles to convars used by plugin */
ConVar sm_reserved_slots;
ConVar sm_hide_slots;
ConVar sv_visiblemaxplayers;
ConVar sm_reserve_type;
ConVar sm_reserve_maxadmins;
ConVar sm_reserve_kicktype;
ConVar sm_free_slots;

enum KickType
{
	Kick_HighestPing,
	Kick_HighestTime,
	Kick_Random,
};

enum KickReason
{
	Reason_ReservedSlot,
	Reason_NotInWhitelist,
	Reason_SqueezedOut,
	Reason_DonatorLastSlot,
};

public OnPluginStart()
{
	LoadTranslations("whitelist.phrases");

	sm_reserved_slots = CreateConVar("sm_reserved_slots", "0", "Number of reserved player slots", 0, true, 0.0);
	sm_hide_slots = CreateConVar("sm_hide_slots", "0", "If set to 1, reserved slots will hidden (subtracted from the max slot count)", 0, true, 0.0, true, 1.0);
	sv_visiblemaxplayers = FindConVar("sv_visiblemaxplayers");
	sm_reserve_type = CreateConVar("sm_reserve_type", "0", "Method of reserving slots", 0, true, 0.0, true, 2.0);
	sm_reserve_maxadmins = CreateConVar("sm_reserve_maxadmins", "1", "Maximum amount of admins to let in the server with reserve type 2", 0, true, 0.0);
	sm_reserve_kicktype = CreateConVar("sm_reserve_kicktype", "0", "How to select a client to kick (if appropriate)", 0, true, 0.0, true, 2.0);
	sm_free_slots = CreateConVar("sm_free_slots", "4", "Number of free player slots", 0, true, 0.0);

	sm_reserved_slots.AddChangeHook(SlotCountChanged);
	sm_hide_slots.AddChangeHook(SlotHideChanged);

	RegAdminCmd("sm_whitelist_add", CommandWhitelistAdd, ADMFLAG_ROOT, "Add a user to the whilelist with a time range in months, after which the user is moved out of the whitelist. e.g. sm_whitelist_add \"[U:1:217568258]\" 2");
}

public OnPluginEnd()
{
	/* 	If the plugin has been unloaded, reset visiblemaxplayers. In the case of the server shutting down this effect will not be visible */
	ResetVisibleMax();
}

public OnMapStart()
{
	if (sm_hide_slots.BoolValue)
	{
		SetVisibleMaxSlots(GetClientCount(false), GetMaxHumanPlayers() - sm_reserved_slots.IntValue);
	}
}

public OnConfigsExecuted()
{
	if (sm_hide_slots.BoolValue)
	{
		SetVisibleMaxSlots(GetClientCount(false), GetMaxHumanPlayers() - sm_reserved_slots.IntValue);
	}
}

public OnRebuildAdminCache(AdminCachePart:part)
{
	if (part == AdminCache_Admins) {
		decl String:filePath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, filePath, sizeof(filePath), WHITELIST_PATH);
		if (g_whitelistKv != INVALID_HANDLE)
		{
			CloseHandle(g_whitelistKv);
		}
		g_whitelistKv = CreateKeyValues("PlayerWhitelist");
		new now = GetTime();
		if (FileToKeyValues(g_whitelistKv, filePath))
		{
			if (!KvGotoFirstSubKey(g_whitelistKv))
			{
				return;
			}
			decl String:authId[64];
			decl String:authMethod[32];
			do
			{
				new start = KvGetNum(g_whitelistKv, "start");
				new end = KvGetNum(g_whitelistKv, "end");
				if (now >= start && now <= end)
				{
					KvGetSectionName(g_whitelistKv, authId, sizeof(authId));
					new authOffset;
					DecodeAuthMethod(authId, authMethod, authOffset);
					new AdminId:admin;
					new bool:isBound;
					if ((admin = FindAdminByIdentity(authMethod, authId[authOffset])) == INVALID_ADMIN_ID)
					{
						/* There is no binding, create the admin */
						admin = CreateAdmin();
					}
					else
					{
						isBound = true;
					}
					SetAdminFlag(admin, Admin_Custom1, true);
					if (!isBound)
					{
						if (!BindAdminIdentity(admin, authMethod, authId[authOffset]))
						{
							/* We should never reach here */
							RemoveAdmin(admin);
							LogError("[Whitelist] Failed to bind identity %s (method %s)", authId[authOffset], authMethod);
						}
					}
				}
			} while (KvGotoNextKey(g_whitelistKv));
		}
	}
}

public OnClientPostAdminCheck(client)
{
	new reserved = sm_reserved_slots.IntValue;
	new limit = GetMaxHumanPlayers() - reserved;
	new clients = GetClientCount(false);
	new flags = GetUserFlagBits(client);
	new freeSlots = sm_free_slots.IntValue;

	// Whitelist
	if (clients > freeSlots && !IsFakeClient(client) && !IsDonatorOrReserved(flags))
	{
		new Handle:pack = CreateDataPack();
		WritePackCell(pack, client);
		WritePackCell(pack, Reason_NotInWhitelist);
		CreateTimer(0.1, OnTimedKick, pack);
		return;
	}

	if (clients == limit)
	{
		if (IsDonatorOrReserved(flags))
		{
			// Kick a player in free slots
			for (new i=1; i<=MaxClients; i++)
			{
				if (!IsClientConnected(i))
				{
					continue;
				}

				new iflags = GetUserFlagBits(i);

				if (IsFakeClient(i) || IsDonatorOrReserved(iflags) || CheckCommandAccess(i, "sm_reskick_immunity", ADMFLAG_RESERVATION, true))
				{
					continue;
				}

				if (IsClientInGame(i))
				{
					new Handle:pack = CreateDataPack();
					WritePackCell(pack, i);
					WritePackCell(pack, Reason_SqueezedOut);
					CreateTimer(0.1, OnTimedKick, pack);
					return;
				}
			}
		}
		else
		{
			new Handle:pack = CreateDataPack();
			WritePackCell(pack, client);
			WritePackCell(pack, Reason_DonatorLastSlot);
			CreateTimer(0.1, OnTimedKick, pack);
			return;
		}
	}

	// Welcome message
	CreateTimer(7.0, OnTimedWelcomeMessage, client);

	// Reserved slots
	if (reserved > 0)
	{
		new type = sm_reserve_type.IntValue;

		if (type == 0)
		{
			if (clients <= limit || IsFakeClient(client) || flags & ADMFLAG_ROOT || flags & ADMFLAG_RESERVATION)
			{
				if (sm_hide_slots.BoolValue)
				{
					SetVisibleMaxSlots(clients, limit);
				}

				return;
			}

			/* Kick player because there are no public slots left */
			new Handle:pack = CreateDataPack();
			WritePackCell(pack, client);
			WritePackCell(pack, Reason_ReservedSlot);
			CreateTimer(0.1, OnTimedKick, pack);
		}
		else if (type == 1)
		{
			if (clients > limit)
			{
				if (flags & ADMFLAG_ROOT || flags & ADMFLAG_RESERVATION)
				{
					new target = SelectKickClient();

					if (target)
					{
						/* Kick public player to free the reserved slot again */
						new Handle:pack = CreateDataPack();
						WritePackCell(pack, target);
						WritePackCell(pack, Reason_ReservedSlot);
						CreateTimer(0.1, OnTimedKick, pack);
					}
				}
				else
				{
					/* Kick player because there are no public slots left */
					new Handle:pack = CreateDataPack();
					WritePackCell(pack, client);
					WritePackCell(pack, Reason_ReservedSlot);
					CreateTimer(0.1, OnTimedKick, pack);
				}
			}
		}
		else if (type == 2)
		{
			if (flags & ADMFLAG_ROOT || flags & ADMFLAG_RESERVATION)
			{
				g_adminCount++;
				g_isAdmin[client] = true;
			}

			if (clients > limit && g_adminCount < sm_reserve_maxadmins.IntValue)
			{
				/* Server is full, reserved slots aren't and client doesn't have reserved slots access */

				if (g_isAdmin[client])
				{
					new target = SelectKickClient();

					if (target)
					{
						/* Kick public player to free the reserved slot again */
						new Handle:pack = CreateDataPack();
						WritePackCell(pack, target);
						WritePackCell(pack, Reason_ReservedSlot);
						CreateTimer(0.1, OnTimedKick, pack);
					}
				}
				else
				{
					/* Kick player because there are no public slots left */
					new Handle:pack = CreateDataPack();
					WritePackCell(pack, client);
					WritePackCell(pack, Reason_ReservedSlot);
					CreateTimer(0.1, OnTimedKick, pack);
				}
			}
		}
	}
}

public OnClientDisconnect_Post(client)
{
	if (sm_hide_slots.BoolValue)
	{
		SetVisibleMaxSlots(GetClientCount(false), GetMaxHumanPlayers() - sm_reserved_slots.IntValue);
	}

	if (g_isAdmin[client])
	{
		g_adminCount--;
		g_isAdmin[client] = false;
	}
}

public Action:OnTimedKick(Handle:timer, any:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new KickReason:reason = ReadPackCell(pack);
	CloseHandle(pack);

	if (!client || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	new String:reasonText[32];
	new freeSlots = sm_free_slots.IntValue;
	switch (reason)
	{
		case Reason_ReservedSlot:
		{
			reasonText = "Slot reserved";
		}
		case Reason_NotInWhitelist:
		{
			if (freeSlots == 0)
			{
				reasonText = "Whitelist Only";
			}
			else
			{
				reasonText = "Not In Whitelist";
			}
		}
		case Reason_SqueezedOut:
		{
			reasonText = "Squeezed Out";
		}
		case Reason_DonatorLastSlot:
		{
			reasonText = "Donator Last Slot";
		}
		default:
		{
			// Should never go here
		}
	}

	KickClient(client, "%T", reasonText, client, freeSlots);

	if (sm_hide_slots.BoolValue)
	{
		SetVisibleMaxSlots(GetClientCount(false), GetMaxHumanPlayers() - sm_reserved_slots.IntValue);
	}

	return Plugin_Handled;
}

public Action:OnTimedWelcomeMessage(Handle:timer, any:client)
{
	if (IsClientConnected(client) && IsClientInGame(client))
	{
		new flags = GetUserFlagBits(client);
		if (IsDonator(flags))
		{
			decl String:name[64];
			new String:expireDate[64];
			decl String:steamId3[64];
			GetClientName(client, name, sizeof(name));
			GetClientAuthId(client, AuthId_Steam3, steamId3, sizeof(steamId3));
			KvRewind(g_whitelistKv);
			if (KvJumpToKey(g_whitelistKv, steamId3))
			{
				new end = KvGetNum(g_whitelistKv, "end");
				FormatTime(expireDate, sizeof(expireDate), NULL_STRING, end);
			}
			CPrintToChatAll("%t", "Whitelist Welcome Message Public", name);
			CPrintToChat(client, "%T", "Whitelist Welcome Message", client, name, expireDate);
		}
		else if (!IsDonatorOrReserved(flags))
		{
			// Because the message is too long, we have to seperate it to three print command.
			CPrintToChat(client, "%T", "Welcome Message Line 1", client, sm_free_slots.IntValue);
			CPrintToChat(client, "%T", "Welcome Message Line 2", client, sm_free_slots.IntValue);
			CPrintToChat(client, "%T", "Welcome Message Line 3", client, sm_free_slots.IntValue);
		}
	}
	return Plugin_Handled;
}

public Action:CommandWhitelistAdd(int client, int args)
{
	if (args != 2)
	{
		CReplyToCommand(client, "[SM] Usage: sm_whitelist_add <user_auth_id> <valid-time-in-month>");
		return Plugin_Handled;
	}

	decl String:authId[64];
	decl String:monthArg[5];
	GetCmdArg(1, authId, sizeof(authId));
	GetCmdArg(2, monthArg, sizeof(monthArg));
	new months = StringToInt(monthArg);

	decl String:filePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filePath, sizeof(filePath), WHITELIST_PATH);
	new Handle:kv = CreateKeyValues("PlayerWhitelist");
	FileToKeyValues(kv, filePath);
	new now = GetTime();
	new start, end;
	if (KvJumpToKey(kv, authId, true))
	{
		start = KvGetNum(kv, "start");
		end = KvGetNum(kv, "end");
		if (now >= start && now <= end)
		{
			end += months * 2592000;
			KvSetNum(kv, "end", end);
		}
		else
		{
			start = now;
			end = now + months * 2592000;
			KvSetNum(kv, "start", start);
			KvSetNum(kv, "end", end);
		}
	}
	KvRewind(kv);
	KeyValuesToFile(kv, filePath);
	CloseHandle(kv);

	DumpAdminCache(AdminCache_Admins, true);

	decl String:from[64];
	decl String:to[64];
	FormatTime(from, sizeof(from), NULL_STRING, start);
	FormatTime(to, sizeof(to), NULL_STRING, end);
	CReplyToCommand(client, "%T", "Add To Whitelist Succeed", client, authId, from, to);
	return Plugin_Handled;
}

public SlotCountChanged(ConVar convar, const String:oldValue[], const String:newValue[])
{
	/* Reserved slots or hidden slots have been disabled - reset sv_visiblemaxplayers */
	new slotcount = convar.IntValue;
	if (slotcount == 0)
	{
		ResetVisibleMax();
	}
	else if (sm_hide_slots.BoolValue)
	{
		SetVisibleMaxSlots(GetClientCount(false), GetMaxHumanPlayers() - slotcount);
	}
}

public SlotHideChanged(ConVar convar, const String:oldValue[], const String:newValue[])
{
	/* Reserved slots or hidden slots have been disabled - reset sv_visiblemaxplayers */
	if (!convar.BoolValue)
	{
		ResetVisibleMax();
	}
	else
	{
		SetVisibleMaxSlots(GetClientCount(false), GetMaxHumanPlayers() - sm_reserved_slots.IntValue);
	}
}

SetVisibleMaxSlots(clients, limit)
{
	new num = clients;

	if (clients == GetMaxHumanPlayers())
	{
		num = GetMaxHumanPlayers();
	} else if (clients < limit) {
		num = limit;
	}

	sv_visiblemaxplayers.IntValue = num;
}

ResetVisibleMax()
{
	sv_visiblemaxplayers.IntValue = -1;
}

SelectKickClient()
{
	new KickType:type = KickType:sm_reserve_kicktype.IntValue;

	new Float:highestValue;
	new highestValueId;

	new Float:highestSpecValue;
	new highestSpecValueId;

	new bool:specFound;

	new Float:value;

	for (new i=1; i<=MaxClients; i++)
	{
		if (!IsClientConnected(i))
		{
			continue;
		}

		new flags = GetUserFlagBits(i);

		if (IsFakeClient(i) || flags & ADMFLAG_ROOT || flags & ADMFLAG_RESERVATION || CheckCommandAccess(i, "sm_reskick_immunity", ADMFLAG_RESERVATION, true))
		{
			continue;
		}

		value = 0.0;

		if (IsClientInGame(i))
		{
			if (!(flags & ADMFLAG_CUSTOM1))
			{
				return i;
			}

			if (type == Kick_HighestPing)
			{
				value = GetClientAvgLatency(i, NetFlow_Outgoing);
			}
			else if (type == Kick_HighestTime)
			{
				value = GetClientTime(i);
			}
			else
			{
				value = GetRandomFloat(0.0, 100.0);
			}

			if (IsClientObserver(i))
			{
				specFound = true;

				if (value > highestSpecValue)
				{
					highestSpecValue = value;
					highestSpecValueId = i;
				}
			}
		}

		if (value >= highestValue)
		{
			highestValue = value;
			highestValueId = i;
		}
	}

	if (specFound)
	{
		return highestSpecValueId;
	}

	return highestValueId;
}

// Is donator or admin
bool:IsDonatorOrReserved(flags)
{
	return flags & ADMFLAG_ROOT || flags & ADMFLAG_RESERVATION || flags & ADMFLAG_CUSTOM1;
}

bool:IsDonator(flags)
{
	return bool:(flags & ADMFLAG_CUSTOM1);
}

DecodeAuthMethod(const String:auth[], String:method[32], &offset)
{
	if ((StrContains(auth, "STEAM_") == 0) || (strncmp("0:", auth, 2) == 0) || (strncmp("1:", auth, 2) == 0))
	{
		// Steam2 Id
		strcopy(method, sizeof(method), AUTHMETHOD_STEAM);
		offset = 0;
	}
	else if (!strncmp(auth, "[U:", 3) && auth[strlen(auth) - 1] == ']')
	{
		// Steam3 Id
		strcopy(method, sizeof(method), AUTHMETHOD_STEAM);
		offset = 0;
	}
	else
	{
		if (auth[0] == '!')
		{
			strcopy(method, sizeof(method), AUTHMETHOD_IP);
			offset = 1;
		}
		else
		{
			strcopy(method, sizeof(method), AUTHMETHOD_NAME);
			offset = 0;
		}
	}
}
