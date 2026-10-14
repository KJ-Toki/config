#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <colors>

#define HORDE_MIN_SIZE_AUDIAL_FEEDBACK	120
#define MAX_CHECKPOINTS					4

#define HORDE_SOUND	"/npc/mega_mob/mega_mob_incoming.wav"

ConVar hCvarNoEventHordeDuringTanks;
ConVar hCvarHordeCheckpointAnnounce;

Address pZombieManager = Address_Null;

int commonLimit;
int commonTotal;
int lastCheckpoint;

bool announcedInChat;
bool checkpointAnnounced[MAX_CHECKPOINTS];

public Plugin myinfo = 
{
	name = "L4D2 Horde Equaliser",
	author = "Visor (original idea by Sir)",
	description = "Make certain event hordes finite",
	version = "3.0.6",
	url = "https://github.com/Attano/Equilibrium"
};

public void OnPluginStart()
{
	// Cargar gamedata para encontrar ZombieManager
	GameData gamedata = new GameData("left4dhooks.l4d2");
	if (gamedata == null)
	{
		SetFailState("Failed to load \"left4dhooks.l4d2\" gamedata.");
	}

	pZombieManager = gamedata.GetAddress("ZombieManager");
	if (pZombieManager == Address_Null)
	{
		SetFailState("Couldn't find the 'ZombieManager' address");
	}

	delete gamedata;

	hCvarNoEventHordeDuringTanks = CreateConVar("l4d2_heq_no_tank_horde", "0", "Put infinite hordes on a 'hold up' during Tank fights");
	hCvarHordeCheckpointAnnounce = CreateConVar("l4d2_heq_checkpoint_sound", "1", "Play the incoming mob sound at checkpoints (each 1/4 of total commons killed off) to simulate L4D1 behaviour");

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void OnMapStart()
{
	commonLimit = L4D2_GetMapValueInt("horde_limit", -1);

	PrecacheSound(HORDE_SOUND);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	commonTotal = 0;
	lastCheckpoint = 0;
	announcedInChat = false;
	for (int i = 0; i < MAX_CHECKPOINTS; i++)
	{
		checkpointAnnounced[i] = false;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "infected", false) && IsInfiniteHordeActive())
	{
		// Don't count in boomer hordes, alarm cars and wanderers during a Tank fight
		if (GetConVarBool(hCvarNoEventHordeDuringTanks) && IsTankUp())
		{
			return;
		}
		
		// Horde too small for audial feedback
		if (commonLimit < HORDE_MIN_SIZE_AUDIAL_FEEDBACK)
		{
			return;
		}
		
		// Our job here is done
		if (commonTotal >= commonLimit)
		{
			return;
		}
		
		commonTotal++;
		if (GetConVarBool(hCvarHordeCheckpointAnnounce) && 
			(commonTotal >= ((lastCheckpoint + 1) * RoundFloat(float(commonLimit / MAX_CHECKPOINTS))))
		) {
			EmitSoundToAll(HORDE_SOUND);
			checkpointAnnounced[lastCheckpoint] = true;
			lastCheckpoint++;
		}
	}
}

public Action L4D_OnSpawnMob(int &amount)
{
	/////////////////////////////////////
	// - Called on Event Hordes.
	// - Called on Panic Event Hordes.
	// - Called on Natural Hordes.
	// - Called on Onslaught (Mini-finale or finale Scripts)

	// - Not Called on Boomer Hordes.
	// - Not Called on z_spawn mob.
	////////////////////////////////////
	
	// "Pause" the infinite horde during the Tank fight
	if (GetConVarBool(hCvarNoEventHordeDuringTanks) && IsTankUp() && IsInfiniteHordeActive())
	{
		SetPendingMobCount(0);
		amount = 0;
		return Plugin_Handled;
	}

	// Excluded map -- don't block any infinite hordes on this one
	if (commonLimit < 0)
	{
		return Plugin_Continue;
	}

	// If it's a "finite" infinite horde...
	if (IsInfiniteHordeActive())
	{
		if (!announcedInChat)
		{
			CPrintToChatAll("<{olive}EQ{default}> A {blue}finite event{default} of {olive}%i{default} commons has started! Rush or wait it out, the choice is yours!", commonLimit);
			announcedInChat = true;
		}
		
		// ...and it's overlimit...
		if (commonTotal >= commonLimit)
		{
			SetPendingMobCount(0);
			amount = 0;
			return Plugin_Handled;
		}
	}
	
	// ...or not.
	return Plugin_Continue;
}

bool IsInfiniteHordeActive()
{
	int countdown = GetHordeCountdown();
	return (countdown > -1 && countdown <= 10);
}

void SetPendingMobCount(int count)
{
	if (pZombieManager != Address_Null)
		StoreToAddress(pZombieManager + view_as<Address>(528), count, NumberType_Int32);
}

int GetHordeCountdown()
{
	return CTimer_HasStarted(L4D2Direct_GetMobSpawnTimer()) ? RoundFloat(CTimer_GetRemainingTime(L4D2Direct_GetMobSpawnTimer())) : -1;
}

bool IsTankUp()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && GetEntProp(i, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(i))
		{
			return true;
		}
	}
	return false;
}

/* ============================================================
//  STOCKS QUE ANTES VENÍAN DE l4d2lib / l4d2_direct
// ============================================================ */

stock int L4D2_GetMapValueInt(const char[] key, int defaultValue)
{
	GameData gamedata = new GameData("left4dhooks.l4d2");
	if (gamedata == null)
		return defaultValue;

	int value = gamedata.GetOffset(key);
	delete gamedata;

	return (value != -1) ? value : defaultValue;
}