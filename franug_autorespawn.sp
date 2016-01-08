#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define DATA "1.2"

#define RESPAWNT 0.5 // time for respawn

public Plugin:myinfo = 
{
	name = "SM Franug Auto Respawn",
	author = "Franc1sco franug",
	description = "",
	version = DATA,
	url = "http://steamcommunity.com/id/franug"
};


bool enable = true;

new Float:g_fDeathTime[MAXPLAYERS+1];

Handle timers, cvar_time;

public OnPluginStart()
{
	//HookEvent("round_start", Restart);
	CreateConVar("sm_franugautorespawn_version", DATA, "", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	cvar_time = CreateConVar("sm_franugautorespawn_time", "30.0", "Time after round start for enable the spawnkiller. 0.0 = disabled.");
	HookEvent("player_death", Event_Playerd2);
	HookEvent("player_spawn", spawn)
	
	AddCommandListener(OnJoinTeam, "jointeam");
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

public Action:spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!enable && IsPlayerAlive(client)) ForcePlayerSuicide(client);
}

public Action:Event_Playerd2(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(enable) CreateTimer(RESPAWNT, Resp, client);
}

public Action:Resp(Handle timer, int client)
{
	if(IsClientInGame(client) && !IsPlayerAlive(client) && GetClientTeam(client) > 1 && enable) CS_RespawnPlayer(client)
}

public Action:OnJoinTeam(client, const String:command[], numArgs)
{
	if (!IsClientInGame(client) || numArgs < 1) return Plugin_Continue;

	if(!IsPlayerAlive(client))
		if(enable) CreateTimer(RESPAWNT, Resp, client);

	return Plugin_Continue;
}

public OnClientDisconnect(client)
{
	g_fDeathTime[client] = 0.0;
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	enable = true;
	
	if(timers != INVALID_HANDLE) KillTimer(timers);
	timers = INVALID_HANDLE;
	
	float time = GetConVarFloat(cvar_time);
	
	if(time > 0.0)
		timers = CreateTimer(time, spawnkill);
}

public Action spawnkill(Handle timer)
{
	PrintToChatAll(" \x04Repeat killer detected. Disabling autorespawn for this round.");
	enable = false;
	timers = INVALID_HANDLE;
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!enable)
		return;
		
	decl String:weapon[32];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (victim && !attacker && StrEqual(weapon, "trigger_hurt"))
	{
		new Float:fGameTime = GetGameTime();
		
		if (fGameTime - g_fDeathTime[victim] - RESPAWNT < 2.0)
		{
			PrintToChatAll(" \x04Repeat killer detected. Disabling autorespawn for this round.");
			enable = false;
		}
		
		g_fDeathTime[victim] = fGameTime;
	}
}
