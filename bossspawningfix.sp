/*

This version of Boss Percents was designed to work with my custom Ready Up plugin.
It's designed so when boss percentages are changed, it will edit the already existing
Ready Up footer, rather then endlessly stacking them ontop of one another.

It was also created so that my Witch Toggler plugin can properly display if the witch is disabled
or not on both the ready up menu aswell as when using the !boss commands.

I tried my best to comment everything so it can be very easy to understand what's going on. Just in case you want to
do some personalization for your server or config. It will also come in handy if somebody finds a bug and I need to figure
out what's going on :D Kinda makes my other plugins look bad huh :/

*/

#pragma semicolon 1
#pragma newdecls required

#include <colors>
#include <left4dhooks>
#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <readyup>
#include <witch_and_tankifier>

#define PLUGIN_VERSION "3.2.6"

public Plugin myinfo =
{
	name        = "[L4D2] Boss Percents/Vote Boss Hybrid",
	author      = "Spoon, Forgetest",
	version     = PLUGIN_VERSION,
	description = "Displays Boss Flows on Ready-Up and via command. Remade for NextMod.",
	url         = "https://github.com/spoon-l4d2"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("SetTankDisabled", Native_SetTankDisabled);
	CreateNative("SetWitchDisabled", Native_SetWitchDisabled);
	CreateNative("UpdateBossPercents", Native_UpdateBossPercents);
	CreateNative("GetStoredTankPercent", Native_GetStoredTankPercent);
	CreateNative("GetStoredWitchPercent", Native_GetStoredWitchPercent);
	CreateNative("GetReadyUpFooterIndex", Native_GetReadyUpFooterIndex);
	CreateNative("RefreshBossPercentReadyUp", Native_RefreshReadyUp);
	CreateNative("IsDarkCarniRemix", Native_IsDarkCarniRemix);

	RegPluginLibrary("l4d_boss_percent");

	// Mark optional natives as optional (in case witch_and_tankifier is not loaded)
	MarkNativeAsOptional("IsStaticWitchMap");
	MarkNativeAsOptional("IsStaticTankMap");

	return APLRes_Success;
}

// ConVars
ConVar g_hCvarGlobalPercent;
ConVar g_hCvarTankPercent;
ConVar g_hCvarWitchPercent;

// ConVar Storages
bool g_bCvarGlobalPercent;
bool g_bCvarTankPercent;
bool g_bCvarWitchPercent;

// Handles
Handle g_hUpdateFooterTimer;

// Variables
bool g_ReadyUpAvailable;
bool g_WitchTankifierAvailable;
int  g_iReadyUpFooterIndex;
bool g_bReadyUpFooterAdded;
char g_sCurrentMap[64];
bool g_bWitchDisabled;
bool g_bTankDisabled;

// Dark Carnival: Remix Work Around Variables
bool g_bIsRemix;
int  g_fDKRFirstRoundTankPercent;
int  g_fDKRFirstRoundWitchPercent;

// Percent Variables
int  g_fWitchPercent;
int  g_fTankPercent;
char g_sWitchString[80];
char g_sTankString[80];

public void OnPluginStart()
{
	LoadTranslations("l4d_boss_percent.phrases");

	g_hCvarGlobalPercent = CreateConVar("l4d_global_percent", "0", "Display boss percentages to entire team when using commands");
	g_hCvarTankPercent   = CreateConVar("l4d_tank_percent", "1", "Display Tank flow percentage in chat");
	g_hCvarWitchPercent  = CreateConVar("l4d_witch_percent", "1", "Display Witch flow percentage in chat");

	g_hCvarGlobalPercent.AddChangeHook(OnConVarChanged);
	g_hCvarTankPercent.AddChangeHook(OnConVarChanged);
	g_hCvarWitchPercent.AddChangeHook(OnConVarChanged);

	GetCvars();

	RegConsoleCmd("sm_boss", BossCmd);
	RegConsoleCmd("sm_tank", BossCmd);
	RegConsoleCmd("sm_witch", BossCmd);

	HookEvent("player_left_start_area", LeftStartAreaEvent, EventHookMode_PostNoCopy);
	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);
	HookEvent("player_say", DKRWorkaround, EventHookMode_Post);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bCvarGlobalPercent = g_hCvarGlobalPercent.BoolValue;
	g_bCvarTankPercent   = g_hCvarTankPercent.BoolValue;
	g_bCvarWitchPercent  = g_hCvarWitchPercent.BoolValue;
}

/* ========================================================
// ====================== Section #1 ======================
// ======================= Natives ========================
// ======================================================== */

public int Native_UpdateBossPercents(Handle plugin, int numParams)
{
	CreateTimer(0.1, GetBossPercents);
	UpdateReadyUpFooter(0.2);
	return 1;
}

public int Native_IsDarkCarniRemix(Handle plugin, int numParams)
{
	return g_bIsRemix;
}

public int Native_SetWitchDisabled(Handle plugin, int numParams)
{
	g_bWitchDisabled = view_as<bool>(GetNativeCell(1));
	UpdateReadyUpFooter();
	return 1;
}

public int Native_SetTankDisabled(Handle plugin, int numParams)
{
	g_bTankDisabled = view_as<bool>(GetNativeCell(1));
	UpdateReadyUpFooter();
	return 1;
}

public int Native_GetStoredWitchPercent(Handle plugin, int numParams)
{
	return g_fWitchPercent;
}

public int Native_GetStoredTankPercent(Handle plugin, int numParams)
{
	return g_fTankPercent;
}

public int Native_GetReadyUpFooterIndex(Handle plugin, int numParams)
{
	if (g_ReadyUpAvailable) return g_iReadyUpFooterIndex;
	else return -1;
}

public int Native_RefreshReadyUp(Handle plugin, int numParams)
{
	if (g_ReadyUpAvailable)
	{
		UpdateReadyUpFooter();
		return true;
	}
	else return false;
}

/* ========================================================
// ====================== Section #2 ======================
// ============ Plugin Availability Checks ================
// ======================================================== */

public void OnAllPluginsLoaded()
{
	g_ReadyUpAvailable = LibraryExists("readyup");
	g_WitchTankifierAvailable = LibraryExists("witch_and_tankifier");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "readyup")) g_ReadyUpAvailable = false;
	if (StrEqual(name, "witch_and_tankifier")) g_WitchTankifierAvailable = false;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "readyup")) g_ReadyUpAvailable = true;
	if (StrEqual(name, "witch_and_tankifier")) g_WitchTankifierAvailable = true;
}

/* ========================================================
// ====================== Section #3 ======================
// ======================== Events ========================
// ======================================================== */

public void OnMapStart()
{
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	g_bIsRemix = IsDKR();
}

public void OnMapEnd()
{
	g_fDKRFirstRoundTankPercent  = -1;
	g_fDKRFirstRoundWitchPercent = -1;
	g_fWitchPercent              = -1;
	g_fTankPercent               = -1;
	g_bTankDisabled              = false;
	g_bWitchDisabled             = false;
}

public void LeftStartAreaEvent(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_ReadyUpAvailable)
	{
		PrintBossPercents();

		if (g_bIsRemix && !InSecondHalfOfRound())
		{
			g_fDKRFirstRoundTankPercent  = g_fTankPercent;
			g_fDKRFirstRoundWitchPercent = g_fWitchPercent;
		}
	}
}

public void OnRoundIsLive()
{
	PrintBossPercents();

	if (g_bIsRemix && !InSecondHalfOfRound())
	{
		g_fDKRFirstRoundTankPercent  = g_fTankPercent;
		g_fDKRFirstRoundWitchPercent = g_fWitchPercent;
	}
}

public void RoundStartEvent(Event event, const char[] name, bool dontBroadcast)
{
	g_bReadyUpFooterAdded = false;
	g_iReadyUpFooterIndex = -1;

	CreateTimer(5.0, GetBossPercents);
	UpdateReadyUpFooter(6.0);
}

/* ========================================================
// ====================== Section #4 ======================
// ============ Dark Carnival: Remix Workaround ===========
// ======================================================== */

bool IsDKR()
{
	if (StrEqual(g_sCurrentMap, "dkr_m1_motel", true) ||
		StrEqual(g_sCurrentMap, "dkr_m2_carnival", true) ||
		StrEqual(g_sCurrentMap, "dkr_m3_tunneloflove", true) ||
		StrEqual(g_sCurrentMap, "dkr_m4_ferris", true) ||
		StrEqual(g_sCurrentMap, "dkr_m5_stadium", true))
	{
		return true;
	}
	return false;
}

int GetPercentageFromText(const char[] text)
{
	int index = StrContains(text, "%", false);

	if (index > -1)
	{
		char sBuffer[12];

		if (IsCharNumeric(text[index - 3]))
		{
			return 100;
		}

		if (IsCharNumeric(text[index - 2]) && IsCharNumeric(text[index - 1]))
		{
			Format(sBuffer, sizeof(sBuffer), "%c%c", text[index - 2], text[index - 1]);
			return StringToInt(sBuffer);
		}
	}

	return -1;
}

public void DKRWorkaround(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bIsRemix) return;

	int UserID = GetEventInt(event, "userid", 0);
	if (!UserID)
	{
		char sBuffer[128];
		GetEventString(event, "text", sBuffer, sizeof(sBuffer), "");

		if (StrContains(sBuffer, "The Tank", false) > -1)
		{
			int percentage = GetPercentageFromText(sBuffer);
			g_fTankPercent = (percentage > -1) ? percentage : 0;
			g_fDKRFirstRoundTankPercent = g_fTankPercent;
		}

		if (StrContains(sBuffer, "The Witch", false) > -1)
		{
			int percentage = GetPercentageFromText(sBuffer);
			g_fWitchPercent = (percentage > -1) ? percentage : 0;
			g_fDKRFirstRoundWitchPercent = g_fWitchPercent;
		}

		ProcessBossString();
		UpdateReadyUpFooter();
	}
}

/* ========================================================
// ====================== Section #5 ======================
// ================= Percent Updater/Saver ================
// ======================================================== */

stock float GetTankFlow(int round)
{
	return L4D2Direct_GetVSTankFlowPercent(round);
}

stock float GetWitchFlow(int round)
{
	return L4D2Direct_GetVSWitchFlowPercent(round);
}

// Reemplazo local de InSecondHalfOfRound (era de l4d2util_rounds)
stock bool InSecondHalfOfRound()
{
	return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}

// Wrapper para las natives de witch_and_tankifier, con fallback
stock bool SafeIsStaticTankMap()
{
	if (g_WitchTankifierAvailable)
		return IsStaticTankMap();
	return false;
}

stock bool SafeIsStaticWitchMap()
{
	if (g_WitchTankifierAvailable)
		return IsStaticWitchMap();
	return false;
}

public Action GetBossPercents(Handle timer)
{
	if (g_bIsRemix)
	{
		if (InSecondHalfOfRound())
		{
			g_fWitchPercent = g_fDKRFirstRoundWitchPercent;
			g_fTankPercent  = g_fDKRFirstRoundTankPercent;
		}
		else
		{
			if (!L4D2Direct_GetVSWitchToSpawnThisRound(0))
			{
				if ((GetWitchFlow(0) * 100.0) < 1)
				{
					if (g_bWitchDisabled)
						g_fWitchPercent = 0;
				}
			}
			else
			{
				g_fWitchPercent = g_fDKRFirstRoundWitchPercent;
			}

			if (!L4D2Direct_GetVSTankToSpawnThisRound(0))
			{
				if ((GetTankFlow(0) * 100) < 1)
				{
					if (g_bTankDisabled)
						g_fTankPercent = 0;
				}
			}
			else
			{
				g_fTankPercent = g_fDKRFirstRoundTankPercent;
			}
		}
	}
	else
	{
		if (InSecondHalfOfRound())
		{
			if (g_fWitchPercent != 0)
				g_fWitchPercent = RoundToNearest(GetWitchFlow(1) * 100.0);

			if (g_fTankPercent != 0)
				g_fTankPercent = RoundToNearest(GetTankFlow(1) * 100.0);
		}
		else
		{
			g_fWitchPercent = 0;
			g_fTankPercent  = 0;

			if (L4D2Direct_GetVSWitchToSpawnThisRound(0))
			{
				g_fWitchPercent = RoundToNearest(GetWitchFlow(0) * 100.0);
			}

			if (L4D2Direct_GetVSTankToSpawnThisRound(0))
			{
				g_fTankPercent = RoundToNearest(GetTankFlow(0) * 100.0);
			}
		}
	}

	ProcessBossString();
	return Plugin_Stop;
}

void UpdateReadyUpFooter(float interval = 0.1)
{
	static float fPrevTime = 0.0;

	if (fPrevTime == 0.0)
		fPrevTime = GetEngineTime();

	float fTime = GetEngineTime() + interval;
	if (fTime < fPrevTime)
		return;

	fPrevTime = fTime;

	if (g_hUpdateFooterTimer == null)
		g_hUpdateFooterTimer = CreateTimer(interval, Timer_UpdateReadyUpFooter);
}

public Action Timer_UpdateReadyUpFooter(Handle timer)
{
	g_hUpdateFooterTimer = null;

	if (g_ReadyUpAvailable)
	{
		char p_sTankString[32];
		char p_sWitchString[32];
		bool p_bStaticTank = false;
		bool p_bStaticWitch = false;
		char p_sNewFooter[65];

		if (!g_bIsRemix)
		{
			p_bStaticTank  = SafeIsStaticTankMap();
			p_bStaticWitch = SafeIsStaticWitchMap();
		}

		if (g_fTankPercent > 0)
			Format(p_sTankString, sizeof(p_sTankString), "%T", "TankOn", LANG_SERVER, g_fTankPercent);
		else if (g_bTankDisabled)
			Format(p_sTankString, sizeof(p_sTankString), "%T", "TankDisabled", LANG_SERVER);
		else if (p_bStaticTank)
			Format(p_sTankString, sizeof(p_sTankString), "%T", "TankStatic", LANG_SERVER);
		else
			Format(p_sTankString, sizeof(p_sTankString), "%T", "TankNone", LANG_SERVER);

		if (g_fWitchPercent > 0)
			Format(p_sWitchString, sizeof(p_sWitchString), "%T", "WitchOn", LANG_SERVER, g_fWitchPercent);
		else if (g_bWitchDisabled)
			Format(p_sWitchString, sizeof(p_sWitchString), "%T", "WitchDisabled", LANG_SERVER);
		else if (p_bStaticWitch)
			Format(p_sWitchString, sizeof(p_sWitchString), "%T", "WitchStatic", LANG_SERVER);
		else
			Format(p_sWitchString, sizeof(p_sWitchString), "%T", "WitchNone", LANG_SERVER);

		if (g_bCvarWitchPercent && g_bCvarTankPercent)
			Format(p_sNewFooter, sizeof(p_sNewFooter), "%s, %s", p_sTankString, p_sWitchString);
		else if (g_bCvarWitchPercent)
			Format(p_sNewFooter, sizeof(p_sNewFooter), "%s", p_sWitchString);
		else if (g_bCvarTankPercent)
			Format(p_sNewFooter, sizeof(p_sNewFooter), "%s", p_sTankString);

		if (g_bReadyUpFooterAdded)
			EditFooterStringAtIndex(g_iReadyUpFooterIndex, p_sNewFooter);
		else
		{
			g_iReadyUpFooterIndex = AddStringToReadyFooter(p_sNewFooter);
			g_bReadyUpFooterAdded = true;
		}
	}

	return Plugin_Stop;
}

/* ========================================================
// ====================== Section #6 ======================
// ======================= Commands =======================
// ======================================================== */

public Action BossCmd(int client, int args)
{
	if (client)
	{
		PrintBossPercents(client);
		RequestFrame(PrintCurrent, GetClientUserId(client));
	}
	return Plugin_Handled;
}

public void PrintCurrent(int userid)
{
	int client = GetClientOfUserId(userid);
	if (client) FakeClientCommand(client, "say /current");
}

void ProcessBossString()
{
	bool p_bStaticTank = false;
	bool p_bStaticWitch = false;

	if (!g_bIsRemix)
	{
		p_bStaticTank  = SafeIsStaticTankMap();
		p_bStaticWitch = SafeIsStaticWitchMap();
	}

	if (g_fTankPercent > 0)
		Format(g_sTankString, sizeof(g_sTankString), "%t {red}%d%%", "TagTank", g_fTankPercent);
	else if (g_bTankDisabled)
		Format(g_sTankString, sizeof(g_sTankString), "%t {red}%t", "TagTank", "Disabled");
	else if (p_bStaticTank)
		Format(g_sTankString, sizeof(g_sTankString), "%t {red}%t", "TagTank", "StaticSpawn");
	else
		Format(g_sTankString, sizeof(g_sTankString), "%t {red}%t", "TagTank", "None");

	if (g_fWitchPercent > 0)
		Format(g_sWitchString, sizeof(g_sWitchString), "%t {red}%d%%", "TagWitch", g_fWitchPercent);
	else if (g_bWitchDisabled)
		Format(g_sWitchString, sizeof(g_sWitchString), "%t {red}%t", "TagWitch", "Disabled");
	else if (p_bStaticWitch)
		Format(g_sWitchString, sizeof(g_sWitchString), "%t {red}%t", "TagWitch", "StaticSpawn");
	else
		Format(g_sWitchString, sizeof(g_sWitchString), "%t {red}%t", "TagWitch", "None");
}

void PrintBossPercents(int client = 0)
{
	int teamflag = 0;

	if (!client)
	{
		teamflag = (1 << 4) - 2;
	}
	else if (g_bCvarGlobalPercent)
	{
		int team = GetClientTeam(client);
		if (team > 1)
			teamflag = (1 << team);
	}

	if (g_bCvarTankPercent)
	{
		if (teamflag > 0)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && !IsFakeClient(i) && (teamflag & (1 << GetClientTeam(i))))
					CPrintToChat(i, g_sTankString);
			}
		}
		else
		{
			CPrintToChat(client, g_sTankString);
		}
	}
	if (g_bCvarWitchPercent)
	{
		if (teamflag > 0)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && !IsFakeClient(i) && (teamflag & (1 << GetClientTeam(i))))
					CPrintToChat(i, g_sWitchString);
			}
		}
		else
		{
			CPrintToChat(client, g_sWitchString);
		}
	}
}