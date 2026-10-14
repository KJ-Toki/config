#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

// The z_gun_swing_vs_amt_penalty cvar is the amount of cooldown time you get
// when you are on your maximum m2 penalty. However, whilst testing I found that
// a magic number of ~0.7s was always added to this.
#define COOLDOWN_EXTRA_TIME 0.7

// Sometimes the ability timer doesn't get reset if the timer interval is the
// stagger time. Use an epsilon to set it slightly before the stagger is over.
#define STAGGER_TIME_EPS 0.1

enum
{
	L4D2Infected_Common = 0,
	L4D2Infected_Smoker = 1,
	L4D2Infected_Boomer,
	L4D2Infected_Hunter,
	L4D2Infected_Spitter,
	L4D2Infected_Jockey,
	L4D2Infected_Charger,
	L4D2Infected_Witch,
	L4D2Infected_Tank
};

ConVar hMaxShovePenaltyCvar;
ConVar hShovePenaltyAmtCvar;
ConVar hPounceCrouchDelayCvar;
ConVar hMaxStaggerDurationCvar;
ConVar hLeapIntervalCvar;
ConVar hPenaltyIncreaseHunterCvar;
ConVar hPenaltyIncreaseJockeyCvar;
ConVar hPenaltyIncreaseSmokerCvar;

bool g_NoHunterM2 = false;

public Plugin myinfo =
{
	name        = "L4D2 M2 Control",
	author      = "Jahze, Visor",
	version     = "1.6.1",
	description = "Blocks instant repounces and gives m2 penalty after a shove/deadstop",
	url         = "https://github.com/Attano/Equilibrium"
};

public void OnPluginStart()
{
	HookEvent("player_shoved", OutSkilled);
	
	hMaxShovePenaltyCvar = FindConVar("z_gun_swing_vs_max_penalty");
	hShovePenaltyAmtCvar = FindConVar("z_gun_swing_vs_amt_penalty");
	hPounceCrouchDelayCvar = FindConVar("z_pounce_crouch_delay");
	hMaxStaggerDurationCvar = FindConVar("z_max_stagger_duration");
	hLeapIntervalCvar = FindConVar("z_leap_interval");

	hPenaltyIncreaseHunterCvar = CreateConVar("l4d2_m2_hunter_penalty", "0", "How much penalty gets added when you shove a Hunter");
	hPenaltyIncreaseJockeyCvar = CreateConVar("l4d2_m2_jockey_penalty", "0", "How much penalty gets added when you shove a Jockey");
	hPenaltyIncreaseSmokerCvar = CreateConVar("l4d2_m2_smoker_penalty", "0", "How much penalty gets added when you shove a Smoker");
}

public void OnAllPluginsLoaded()
{
	g_NoHunterM2 = (FindPluginByFile("optional/l4d2_no_hunter_deadstops.smx") != null);
}

public Action OutSkilled(Event event, const char[] name, bool dontBroadcast)
{
	int shovee = GetClientOfUserId(event.GetInt("userid"));
	int shover = GetClientOfUserId(event.GetInt("attacker"));

	if (!IsSurvivor(shover) || !IsInfected(shovee))
	{
		return Plugin_Continue;
	}

	int penaltyIncrease;
	int zClass = GetInfectedClass(shovee);
	if (zClass == L4D2Infected_Hunter)
	{
		penaltyIncrease = GetConVarInt(hPenaltyIncreaseHunterCvar);
	}
	else if (zClass == L4D2Infected_Jockey)
	{
		penaltyIncrease = GetConVarInt(hPenaltyIncreaseJockeyCvar);
	}
	else if (zClass == L4D2Infected_Smoker)
	{
		penaltyIncrease = GetConVarInt(hPenaltyIncreaseSmokerCvar);
	}
	else
	{
		return Plugin_Continue;
	}
	
	int maxPenalty = GetConVarInt(hMaxShovePenaltyCvar);
	int penalty = GetEntProp(shover, Prop_Send, "m_iShovePenalty");

	penalty += penaltyIncrease;
	if (penalty > maxPenalty)
	{
		penalty = maxPenalty;
	}

	SetEntProp(shover, Prop_Send, "m_iShovePenalty", penalty);
	L4D2Direct_SetNextShoveTime(shover, CalcNextShoveTime(penalty, maxPenalty));

	if (zClass == L4D2Infected_Smoker || (zClass == L4D2Infected_Hunter && g_NoHunterM2))
	{
		return Plugin_Continue;
	}
	
	// Asegurarnos de que shovee sigue siendo válido antes de crear el timer
	if (shovee <= 0 || !IsClientInGame(shovee) || GetClientTeam(shovee) != 3)
	{
		return Plugin_Continue;
	}

	float staggerTime = GetConVarFloat(hMaxStaggerDurationCvar);
	CreateTimer(staggerTime - STAGGER_TIME_EPS, ResetAbilityTimer, GetClientUserId(shovee));
	
	return Plugin_Continue;
}

public Action ResetAbilityTimer(Handle timer, any userid)
{
	int shovee = GetClientOfUserId(userid);

	// Validar que el cliente sigue conectado, en juego e infectado
	if (shovee <= 0 || !IsClientInGame(shovee) || GetClientTeam(shovee) != 3)
	{
		return Plugin_Continue;
	}

	// Validar que sigue siendo un SI válido
	int zClass = GetInfectedClass(shovee);
	if (zClass < L4D2Infected_Smoker || zClass > L4D2Infected_Charger)
	{
		return Plugin_Continue;
	}

	// Validar que la entidad de habilidad sigue existiendo
	int ability = GetEntPropEnt(shovee, Prop_Send, "m_customAbility");
	if (ability == -1 || !IsValidEntity(ability))
	{
		return Plugin_Continue;
	}

	float time = GetGameTime();
	float recharge;

	if (zClass == L4D2Infected_Hunter)
	{
		recharge = GetConVarFloat(hPounceCrouchDelayCvar);
	}
	else
	{
		recharge = GetConVarFloat(hLeapIntervalCvar);
	}

	float timestamp;
	float duration;
	if (!GetInfectedAbilityTimer(shovee, timestamp, duration))
	{
		return Plugin_Continue;
	}

	duration = time + recharge + STAGGER_TIME_EPS;
	if (duration > timestamp)
	{
		SetInfectedAbilityTimer(shovee, duration, recharge);
	}
	
	return Plugin_Continue;
}

static float CalcNextShoveTime(int penalty, int max)
{
	float time = GetGameTime();
	float maxPenalty = float(max);
	float currentPenalty = float(penalty);
	float ratio = currentPenalty / maxPenalty;
	float maxTime = GetConVarFloat(hShovePenaltyAmtCvar);

	return time + ratio * maxTime + COOLDOWN_EXTRA_TIME;
}

/* ============================================================
//  STOCKS LOCALES (reemplazan a l4d2util)
// ============================================================ */

bool IsSurvivor(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

bool IsInfected(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3);
}

int GetInfectedClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

bool GetInfectedAbilityTimer(int client, float &timestamp, float &duration)
{
	int zClass = GetInfectedClass(client);
	if (zClass < L4D2Infected_Smoker || zClass > L4D2Infected_Charger)
		return false;

	int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if (ability == -1 || !IsValidEntity(ability))
		return false;

	duration = GetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer", 0);
	timestamp = GetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer", 1);

	return true;
}

bool SetInfectedAbilityTimer(int client, float timestamp, float duration)
{
	int zClass = GetInfectedClass(client);
	if (zClass < L4D2Infected_Smoker || zClass > L4D2Infected_Charger)
		return false;

	int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if (ability == -1 || !IsValidEntity(ability))
		return false;

	SetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer", duration, 0);
	SetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer", timestamp, 1);

	return true;
}