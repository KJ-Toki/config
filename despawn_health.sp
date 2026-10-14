#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

ConVar si_restore_ratio;

public Plugin myinfo = 
{
	name = "Despawn Health",
	author = "Jacob",
	description = "Gives Special Infected health back when they despawn.",
	version = "1.4",
	url = "github.com/jacob404/myplugins"
}

public void OnPluginStart()
{
	si_restore_ratio = CreateConVar("si_restore_ratio", "0.5", "How much of the clients missing HP should be restored? 1.0 = Full HP", FCVAR_PLUGIN, true, 0.0, true, 1.0);
}

public void L4D_OnEnterGhostState(int client)
{
	int CurrentHealth = GetClientHealth(client);
	int MaxHealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");
	if (CurrentHealth != MaxHealth)
	{
		int MissingHealth = MaxHealth - CurrentHealth;
		int NewHP = RoundFloat(MissingHealth * GetConVarFloat(si_restore_ratio)) + CurrentHealth;
		SetEntityHealth(client, NewHP);
	}
}