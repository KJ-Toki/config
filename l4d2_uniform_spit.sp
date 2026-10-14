#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define TICK_TIME       0.200072

ConVar hCvarDamagePerTick;
ConVar hCvarMaxTicks;
ConVar hCvarGodframeTicks;
StringMap hPuddles;

float damagePerTick;

int maxTicks;
int godframeTicks;

bool bLateLoad;

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax) 
{
	bLateLoad = late;
	return APLRes_Success;    
}

public Plugin myinfo = 
{
	name = "L4D2 Uniform Spit",
	author = "Visor",
	description = "Make the spit deal static amounts of DPS under all circumstances",
	version = "1.3",
	url = "https://github.com/Attano/smplugins"
};

public void OnPluginStart()
{
	hCvarDamagePerTick = CreateConVar("l4d2_spit_dmg", "-1.0", "Damage per tick the spit inflicts. -1 to skip damage adjustments");
	hCvarMaxTicks = CreateConVar("l4d2_spit_max_ticks", "28", "Maximum number of acid damage ticks");
	hCvarGodframeTicks = CreateConVar("l4d2_spit_godframe_ticks", "4", "Number of initial godframed acid ticks");

	hPuddles = new StringMap();

	if (bLateLoad) 
	{
		for (int i = 1; i <= MaxClients; i++) 
		{
			if (IsClientInGame(i)) 
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public void OnConfigsExecuted()
{
	damagePerTick = GetConVarFloat(hCvarDamagePerTick);
	maxTicks = GetConVarInt(hCvarMaxTicks);
	godframeTicks = GetConVarInt(hCvarGodframeTicks);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "insect_swarm"))
	{
		char trieKey[8];
		IndexToKey(entity, trieKey, sizeof(trieKey));

		int[] count = new int[MaxClients];
		hPuddles.SetArray(trieKey, count, MaxClients);
	}
}

public void OnEntityDestroyed(int entity)
{
	char trieKey[8];
	IndexToKey(entity, trieKey, sizeof(trieKey));

	int[] count = new int[MaxClients];
	if (hPuddles.GetArray(trieKey, count, MaxClients))
	{
		hPuddles.Remove(trieKey);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3]) 
{
	if (victim <= 0 || victim > MaxClients || GetClientTeam(victim) != 2 || !IsValidEdict(inflictor))
	{
		return Plugin_Continue;
	}

	char classname[64];
	GetEdictClassname(inflictor, classname, sizeof(classname));
	if (StrEqual(classname, "insect_swarm"))
	{
		char trieKey[8];
		IndexToKey(inflictor, trieKey, sizeof(trieKey));

		int[] count = new int[MaxClients];
		if (hPuddles.GetArray(trieKey, count, MaxClients))
		{
			count[victim]++;

			// Check to see if it's a godframed tick
			if (GetPuddleLifetime(inflictor) >= godframeTicks * TICK_TIME && count[victim] < godframeTicks)
			{
				count[victim] = godframeTicks + 1;
			}

			// Update the array with stored tickcounts
			hPuddles.SetArray(trieKey, count, MaxClients);

			// Let's see what do we have here
			if (damagePerTick > -1.0)
			{
				damage = damagePerTick;
			}
			if (godframeTicks >= count[victim] || count[victim] > maxTicks)
			{
				damage = 0.0;
			}
			if (count[victim] > maxTicks)
			{
				AcceptEntityInput(inflictor, "Kill");
			}
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;	
}

float GetPuddleLifetime(int puddle)
{
	// En Left4DHooks, el timer de la puddle está en el offset 2968
	// Usamos ITimer_GetElapsedTime que viene de left4dhooks.inc
	Address pAddr = GetEntityAddress(puddle) + view_as<Address>(2968);
	return ITimer_GetElapsedTime(view_as<IntervalTimer>(pAddr));
}

void IndexToKey(int index, char[] str, int maxlength)
{
	Format(str, maxlength, "%x", index);
}