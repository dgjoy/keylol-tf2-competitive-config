#pragma semicolon 1

#include <sourcemod>
#include <morecolors>

#define PLUGIN_VERSION "1.0.0"

public Plugin:myinfo =
{
	name = "Server Broadcast",
	author = "Stackia",
	description = "Broadcast a highlighted chat message from server console.",
	version = PLUGIN_VERSION,
	url = "http://www.keylol.com/"
};

public OnPluginStart()
{
	RegServerCmd("sm_broadcast", CommandBroadcast, "Broadcast a chat message from server console with color supported.");
}

public Action:CommandBroadcast(int args)
{
	if (args != 1)
	{
		PrintToServer("[SM] Usage: sm_broadcast <message>");
		return Plugin_Handled;
	}
	decl String:message[256];
	GetCmdArg(1, message, sizeof(message));
	CPrintToChatAll(message);
	return Plugin_Handled;
}
