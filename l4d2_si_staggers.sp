/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.

	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.

	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

// Eliminamos l4d2util para evitar el conflicto de símbolos

#define DEBUG 0

#define ENTITY_NAME_MAX_LENTH 64

#define BLOCK_BOOMER	(1 << 0)
#define BLOCK_CHARGER	(1 << 1)
#define BLOCK_WITCH		(1 << 2)

// Definimos manualmente lo que necesitamos de l4d2util
#define L4D2Infected_Boomer 2
#define L4D2Infected_Charger 6
#define L4D2Infected_Hunter 3

ConVar
	hCvarInfectedFlags;

int
	iActiveFlags;

public Plugin myinfo = 
{
	name = "L4D2 No SI Friendly Staggers",
	author = "Visor, A1m`",
	description = "Removes SI staggers caused by other SI(Boomer, Charger, Witch)",
	version = "1.3",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart()
{
	hCvarInfectedFlags = CreateConVar("l4d2_disable_si_friendly_staggers", "0", "Remove SI staggers caused by other SI(bitmask: 1-Boomer/2-Charger/4-Witch)", _, true, 0.0, true, 7.0);
	
	iActiveFlags = hCvarInfectedFlags.IntValue;
	hCvarInfectedFlags.AddChangeHook(PluginActivityChanged);
}

void PluginActivityChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iActiveFlags = hCvarInfectedFlags.IntValue;
}

public Action L4D2_OnStagger(int target, int source)
{
	if (!iActiveFlags) {
		return Plugin_Continue;
	}
	
	if (source != -1 && !IsValidEdict(source)) {
		return Plugin_Continue;
	}
	
	if (GetInfectedZClass(source) == L4D2Infected_Boomer && !(iActiveFlags & BLOCK_BOOMER)) {
		return Plugin_Continue;
	}
	
	if (source == -1 && !(iActiveFlags & BLOCK_CHARGER)) {
		return Plugin_Continue;
	}
	
	if (GetClientTeam(target) == 2 && IsSurvivorAttacked(target)) {
		return Plugin_Handled;
	}
	
	if (GetClientTeam(target) != 3) {
		return Plugin_Continue;
	}
	
	if (source == -1 && GetInfectedZClass(target) != L4D2Infected_Charger) {
		return Plugin_Handled;
	}
	
	if (source <= MaxClients && GetInfectedZClass(source) == L4D2Infected_Boomer) {
		return Plugin_Handled;
	}
	
	if ((iActiveFlags & BLOCK_WITCH) && source != -1) {
		char classname[ENTITY_NAME_MAX_LENTH];
		GetEdictClassname(source, classname, sizeof(classname));
		if (StrContains(classname, "witch") != -1) {
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

int GetInfectedZClass(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client)) {
		return GetEntProp(client, Prop_Send, "m_zombieClass");
	}

	return -1;
}

// Función auxiliar para saber si un superviviente está atacado (pinned)
// La implementamos manualmente porque IsSurvivorAttacked no está disponible
bool IsSurvivorAttacked(int client)
{
	if (!IsClientInGame(client) || GetClientTeam(client) != 2) {
		return false;
	}
	
	return (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") != -1 ||
			GetEntPropEnt(client, Prop_Send, "m_tongueOwner") != -1 ||
			GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") != -1 ||
			GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") != -1 ||
			GetEntPropEnt(client, Prop_Send, "m_carryAttacker") != -1);
}