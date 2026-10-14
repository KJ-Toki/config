#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <readyup>

#define MAXSPAWNS 8

#define ZC_SMOKER  1
#define ZC_BOOMER  2
#define ZC_HUNTER  3
#define ZC_SPITTER 4
#define ZC_JOCKEY  5
#define ZC_CHARGER 6
#define ZC_WITCH   7
#define ZC_TANK    8

bool g_bReadyUpAvailable = false;

static const char g_csSIClassName[][] =
{
	"",
	"Smoker",
	"Boomer",
	"Hunter",
	"Spitter",
	"Jockey",
	"Charger",
	"Witch",
	"Tank"
};

public Plugin myinfo = 
{
	name = "Special Infected Class Announce",
	author = "Tabun",
	description = "Report what SI classes are up when the round starts.",
	version = "1.1",
	url = ""
}

public void OnAllPluginsLoaded()
{
	g_bReadyUpAvailable = LibraryExists("readyup");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "readyup")) g_bReadyUpAvailable = false;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "readyup")) g_bReadyUpAvailable = true;
}

public void OnRoundIsLive()
{
	AnnounceSIClasses();
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	if (!g_bReadyUpAvailable)
	{
		AnnounceSIClasses();
	}
	return Plugin_Continue;
}

stock void AnnounceSIClasses()
{
	int iSpawns;
	int iSpawnClass[MAXSPAWNS + 1];

	for (int i = 1; i <= MaxClients && iSpawns < MAXSPAWNS; i++)
	{
		// Acepta infectados aunque estén en ghost mode
		if (!IsInfected(i)) continue;

		int zClass = GetEntProp(i, Prop_Send, "m_zombieClass");
		if (zClass < ZC_SMOKER || zClass > ZC_CHARGER) continue;

		iSpawnClass[iSpawns] = zClass;
		iSpawns++;
	}

	switch (iSpawns)
	{
		case 4:
		{
			PrintToSurvivors(
				"\x01Special Infected: \x04%s\x01, \x04%s\x01, \x04%s\x01, \x04%s\x01.",
				g_csSIClassName[iSpawnClass[0]],
				g_csSIClassName[iSpawnClass[1]],
				g_csSIClassName[iSpawnClass[2]],
				g_csSIClassName[iSpawnClass[3]]
			);
		}
		case 3:
		{
			PrintToSurvivors(
				"\x01Special Infected: \x04%s\x01, \x04%s\x01, \x04%s\x01.",
				g_csSIClassName[iSpawnClass[0]],
				g_csSIClassName[iSpawnClass[1]],
				g_csSIClassName[iSpawnClass[2]]
			);
		}
		case 2:
		{
			PrintToSurvivors(
				"\x01Special Infected: \x04%s\x01, \x04%s\x01.",
				g_csSIClassName[iSpawnClass[0]],
				g_csSIClassName[iSpawnClass[1]]
			);
		}
		case 1:
		{
			PrintToSurvivors(
				"\x01Special Infected: \x04%s\x01.",
				g_csSIClassName[iSpawnClass[0]]
			);
		}
	}
}

stock void PrintToSurvivors(const char[] message, any ...)
{
	char sPrint[256];
	VFormat(sPrint, sizeof(sPrint), message, 2);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidSurvivor(i)) continue;
		PrintToChat(i, "\x01%s", sPrint);
	}
}

/* ============================================================
//  STOCKS LOCALES
// ============================================================ */

bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients);
}

bool IsSurvivor(int client)
{
	return (IsValidClient(client) && IsClientInGame(client) && GetClientTeam(client) == 2);
}

bool IsInfected(int client)
{
	return (IsValidClient(client) && IsClientInGame(client) && GetClientTeam(client) == 3);
}

bool IsValidSurvivor(int client)
{
	return (IsSurvivor(client));
}