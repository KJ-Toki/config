#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>

// Enum local renombrado para evitar colisión con left4dhooks
enum
{
	SC_Nick = 0,
	SC_Rochelle,
	SC_Coach,
	SC_Ellis,
	SC_Bill,
	SC_Zoey,
	SC_Francis,
	SC_Louis,
	SC_Invalid,
	SC_Size
}

stock const int getUpAnimations[SC_Size - 1][5] =
{
	// l4d2
	// 0: Nick, 1: Rochelle, 2: Coach, 3: Ellis
	// [][4] = Flying animation from being hit by a tank
	{620, 667, 671, 672, 629}, // Nick
	{629, 674, 678, 679, 637}, // Rochelle
	{621, 656, 660, 661, 629}, // Coach
	{625, 671, 675, 676, 634}, // Ellis

	// l4d1
	// 4: Bill, 5: Zoey, 6: Francis, 7: Louis
	{528, 759, 763, 764, 537}, // Bill
	{537, 819, 823, 824, 546}, // Zoey
	{531, 762, 766, 767, 540}, // Francis
	{528, 759, 763, 764, 537}  // Louis
};

// Enum local de infected renombrado
enum
{
	ZC_Common = 0,
	ZC_Smoker = 1,
	ZC_Boomer,
	ZC_Hunter,
	ZC_Spitter,
	ZC_Jockey,
	ZC_Charger,
	ZC_Witch,
	ZC_Tank
};

bool isSurvivorStaggerBlocked[SC_Size - 1];

public Plugin myinfo =
{
	name        = "Stagger Blocker",
	author      = "Standalone (aka Manu), Visor, Sir, A1m`",
	description = "Block players from being staggered by Jockeys and Hunters for a time while getting up from a Hunter pounce & Charger pummel",
	version     = "1.5",
	url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

public void OnPluginStart()
{
	HookEvent("pounce_stopped", Event_PounceChargeEnd);
	HookEvent("charger_pummel_end", Event_PounceChargeEnd);
	HookEvent("charger_carry_end", Event_PounceChargeEnd);
	HookEvent("player_bot_replace", Event_PlayerBotReplace);
	HookEvent("bot_player_replace", Event_BotPlayerReplace);

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}

public void Event_RoundEnd(Event hEvent, const char[] eName, bool dontBroadcast)
{
	ResetStaggerBlocked();
}

public void OnMapEnd()
{
	ResetStaggerBlocked();
}

public void Event_BotPlayerReplace(Event hEvent, const char[] eName, bool dontBroadcast)
{
	int player = GetClientOfUserId(hEvent.GetInt("player"));
	int charIndex = IdentifySurvivor(player);
	if (charIndex == SC_Invalid) {
		return;
	}

	if (isSurvivorStaggerBlocked[charIndex]) {
		SDKHook(player, SDKHook_PostThink, OnThink);
	}
}

public void Event_PlayerBotReplace(Event hEvent, const char[] eName, bool dontBroadcast)
{
	int bot = GetClientOfUserId(hEvent.GetInt("bot"));
	int charIndex = IdentifySurvivor(bot);
	if (charIndex == SC_Invalid) {
		return;
	}

	if (isSurvivorStaggerBlocked[charIndex]) {
		SDKHook(bot, SDKHook_PostThink, OnThink);
	}
}

public void Event_PounceChargeEnd(Event hEvent, const char[] eName, bool dontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("victim"));
	int charIndex = IdentifySurvivor(client);
	if (charIndex == SC_Invalid) {
		return;
	}

	CreateTimer(0.2, HookOnThink, client);
	isSurvivorStaggerBlocked[charIndex] = true;
}

public Action HookOnThink(Handle hTimer, any client)
{
	if (client && IsSurvivor(client)) {
		SDKHook(client, SDKHook_PostThink, OnThink);
	}

	return Plugin_Stop;
}

public void OnThink(int client)
{
	int charIndex = IdentifySurvivorFast(client);
	if (charIndex == SC_Invalid) {
		return;
	}

	int sequence = GetEntProp(client, Prop_Send, "m_nSequence");

	if (sequence != getUpAnimations[charIndex][0]
		&& sequence != getUpAnimations[charIndex][1]
		&& sequence != getUpAnimations[charIndex][2]
		&& sequence != getUpAnimations[charIndex][3]
		&& sequence != getUpAnimations[charIndex][4]
	) {
		isSurvivorStaggerBlocked[charIndex] = false;
		SDKUnhook(client, SDKHook_PostThink, OnThink);
	}
}

public Action L4D2_OnStagger(int target, int source)
{
	if (!IsValidInfected(source)) {
		return Plugin_Continue;
	}

	int sourceClass = GetInfectedClass(source);

	if (sourceClass != ZC_Hunter && sourceClass != ZC_Jockey) {
		return Plugin_Continue;
	}

	int charIndex = IdentifySurvivor(target);
	if (charIndex == SC_Invalid) {
		return Plugin_Continue;
	}

	if (isSurvivorStaggerBlocked[charIndex]) {
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action L4D2_OnPounceOrLeapStumble(int victim, int attacker)
{
	if (!IsValidInfected(attacker)) {
		return Plugin_Continue;
	}

	int sourceClass = GetInfectedClass(attacker);
	if (sourceClass != ZC_Hunter && sourceClass != ZC_Jockey) {
		return Plugin_Continue;
	}

	int charIndex = IdentifySurvivor(victim);
	if (charIndex == SC_Invalid) {
		return Plugin_Continue;
	}

	if (isSurvivorStaggerBlocked[charIndex]) {
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

void ResetStaggerBlocked()
{
	for (int i = 0; i < (SC_Size - 1); i++) {
		isSurvivorStaggerBlocked[i] = false;
	}
}

/* ============================================================
//  STOCKS LOCALES
// ============================================================ */

stock int IdentifySurvivor(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return SC_Invalid;

	int gender = GetEntProp(client, Prop_Send, "m_Gender");
	return GenderToSurvivorIndex(gender);
}

stock int IdentifySurvivorFast(int client)
{
	int gender = GetEntProp(client, Prop_Send, "m_Gender");
	return GenderToSurvivorIndex(gender);
}

stock int GenderToSurvivorIndex(int gender)
{
	switch (gender)
	{
		case 3: return SC_Bill;      // NamVet
		case 4: return SC_Zoey;      // TeenGirl
		case 5: return SC_Francis;   // Biker
		case 6: return SC_Louis;     // Manager
		case 7: return SC_Nick;      // Gambler
		case 8: return SC_Rochelle;  // Producer
		case 9: return SC_Coach;     // Coach
		case 10: return SC_Ellis;    // Mechanic
	}
	return SC_Invalid;
}

stock bool IsSurvivor(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

stock bool IsValidInfected(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3);
}

stock int GetInfectedClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}