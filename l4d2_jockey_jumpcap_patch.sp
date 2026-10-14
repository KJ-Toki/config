#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <sdktools>

#define CLEAP_ONTOUCH_OFFSET    215

Handle hCLeap_OnTouch;

bool blockJumpCap[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "L4D2 Jockey Jump-Cap Patch",
	author = "Visor",
	description = "Prevent Jockeys from being able to land caps with non-ability jumps in unfair situations",
	version = "1.3",
	url = "https://github.com/Attano/L4D2-Competitive-Framework"
};

public void OnPluginStart()
{
	hCLeap_OnTouch = DHookCreate(CLEAP_ONTOUCH_OFFSET, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, CLeap_OnTouch);
	DHookAddParam(hCLeap_OnTouch, HookParamType_CBaseEntity);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_shoved", Event_PlayerShoved);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		blockJumpCap[i] = false;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "ability_leap"))
	{
		DHookEntity(hCLeap_OnTouch, false, entity); 
	}
}

public Action Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	int shovee = GetClientOfUserId(event.GetInt("userid"));
	int shover = GetClientOfUserId(event.GetInt("attacker"));
	
	if (IsSurvivor(shover) && IsJockey(shovee))
	{
		blockJumpCap[shovee] = true;
		CreateTimer(3.0, ResetJumpcapState, shovee, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	return Plugin_Continue;
}

public Action ResetJumpcapState(Handle timer, any jockey)
{
	blockJumpCap[jockey] = false;
	return Plugin_Handled;
}

public MRESReturn CLeap_OnTouch(int ability, Handle hParams)
{
	int jockey = GetEntPropEnt(ability, Prop_Send, "m_owner");
	int survivor = DHookGetParam(hParams, 1);
	if (IsJockey(jockey) && !IsFakeClient(jockey) && IsSurvivor(survivor))
	{
		if (!IsAbilityActive(ability) && blockJumpCap[jockey])
		{
			return MRES_Supercede;
		}
	}
	return MRES_Ignored;
}

bool IsAbilityActive(int ability)
{
	return view_as<bool>(GetEntData(ability, 1148));
}

bool IsJockey(int client)
{
	return (client > 0 
		&& client <= MaxClients 
		&& IsClientInGame(client) 
		&& GetClientTeam(client) == 3 
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == 5);
}

bool IsSurvivor(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}