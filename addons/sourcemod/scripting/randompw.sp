#pragma semicolon 1

#include <sourcemod>
#include <morecolors>

#define PLUGIN_VERSION "1.0.0"

public Plugin:myinfo =
{
	name = "Random Password",
	author = "Stackia",
	description = "Given a prefix, set a random password on server and print it to all players.",
	version = PLUGIN_VERSION,
	url = "http://www.keylol.com/"
};

ConVar sv_password;

public OnPluginStart()
{
	LoadTranslations("randompw.phrases");
	RegServerCmd("sm_random_pw", CommandRandomPassword, "Set a random server password.");
	RegServerCmd("sm_print_pw", CommandPrintPassword, "Print current server password to all players.");
	sv_password = FindConVar("sv_password");
}

public Action:CommandRandomPassword(int args)
{
	if (args < 1 || args > 2)
	{
		PrintToServer("[SM] Usage: sm_random_pw <prefix> [keep-original]");
		return Plugin_Handled;
	}

	if (args == 2)
	{
		decl String:keepArg[2];
		GetCmdArg(2, keepArg, sizeof(keepArg));
		new keep = StringToInt(keepArg);
		if (keep > 0) // Should keep original password
		{
			decl String:password[32];
			sv_password.GetString(password, sizeof(password));
			if (strlen(password) != 0)
			{
				return Plugin_Handled;
			}
		}
	}

	decl String:password[32];
	decl String:date[5];
	/*new String:random[4];*/

	GetCmdArg(1, password, sizeof(password));
	FormatTime(date, sizeof(date), "%m%d");
	/*for(int i = 0; i < 3; ++i)
	{
		random[i] = GetURandomInt() % 26 + 97;
	}*/
	StrCat(password, sizeof(password), date);
	/*StrCat(password, sizeof(password), random);*/
	sv_password.SetString(password);

	PrintToServer("New password: %s", password);

	return Plugin_Handled;
}

public Action:CommandPrintPassword(int args)
{
	decl String:password[32];
	sv_password.GetString(password, sizeof(password));
	CPrintToChatAll("%t", "New Password", password);
}
