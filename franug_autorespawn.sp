/*  Franug Auto Respawn
 *
 *  Copyright (C) 2017-2021 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma newdecls required

#define DATA "1.9"

bool course;

public Plugin myinfo = 
{
	name = "SM Franug Auto Respawn",
	author = "Franc1sco franug",
	description = "",
	version = DATA,
	url = "http://steamcommunity.com/id/franug"
};


bool enable = true;

float g_fDeathTime[MAXPLAYERS+1];

Handle timers, cvar_enable, cvar_time, cvar_restart, cvar_course, cvar_respawn, cvar_spawnkill;

float g_time, g_respawn;
bool g_enable, g_course, g_spawnkill;

Handle g_timer[MAXPLAYERS + 1];

public void OnPluginStart()
{
	CreateConVar("sm_franugautorespawn_version", DATA, "", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	cvar_enable = CreateConVar("sm_franugautorespawn_enable", "1", "Enable/disable plugin");
	
	cvar_course = CreateConVar("sm_franugautorespawn_course", "0", "1 = Autodisable this plugin in NO course maps. 0 = no autodisable in NO course maps");
	cvar_time = CreateConVar("sm_franugautorespawn_time", "30.0", "Time after round start for enable the spawnkiller. 0.0 = disabled.");
	
	cvar_respawn = CreateConVar("sm_franugautorespawn_respawn", "0.5", "Time after death for respawn");
	cvar_spawnkill = CreateConVar("sm_franugautorespawn_spawnkilldetection", "1", " Enable spawnkill-detection? 0 = Disable");
	
	g_enable = GetConVarBool(cvar_enable);
	g_course = GetConVarBool(cvar_course);
	g_time = GetConVarFloat(cvar_time);
	g_respawn = GetConVarFloat(cvar_respawn);
	g_spawnkill = GetConVarBool(cvar_spawnkill);
	
	HookConVarChange(cvar_enable, Changed_cvars);
	HookConVarChange(cvar_time, Changed_cvars);
	HookConVarChange(cvar_course, Changed_cvars);
	HookConVarChange(cvar_respawn, Changed_cvars);
	HookConVarChange(cvar_spawnkill, Changed_cvars);
	
	HookEvent("player_death", Event_Playerdeath);
	HookEvent("player_spawn", Event_spawn);
	
	AddCommandListener(OnJoinTeam, "jointeam");
	
	if(GetEngineVersion() == Engine_CSGO)
	{
		HookEvent("round_prestart", Event_RoundStart);
	}
	else 
	{
		HookEvent("round_start", Event_RoundStart);
		HookEvent("round_end", Event_RoundStart);
	}
	
	cvar_restart = FindConVar("mp_restartgame");
	if(cvar_restart != INVALID_HANDLE)	
		HookConVarChange(cvar_restart, Changed);
	
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

public void Changed_cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	if(convar == cvar_enable)
	{
		g_enable = GetConVarBool(cvar_enable);
	}
	else if(convar == cvar_time)
	{
		enable = true;
		if(timers != INVALID_HANDLE) KillTimer(timers);
		timers = INVALID_HANDLE;
	
		g_time = GetConVarFloat(cvar_time);
		
		float time = g_time;
	
		if(time > 0.0)
			timers = CreateTimer(time, spawnkill);
	}
	else if(convar == cvar_course)
	{
		g_course = GetConVarBool(cvar_course);
	}
	else if(convar == cvar_respawn)
	{
		g_respawn = GetConVarFloat(cvar_respawn);
	}
	else if(convar == cvar_spawnkill)
	{
		g_spawnkill = GetConVarBool(cvar_spawnkill);
	}
}

public void Changed(Handle convar, const char[] oldValue, const char[] newValue)
{
	enable = true;
	
	if(timers != INVALID_HANDLE) KillTimer(timers);
	timers = INVALID_HANDLE;
	
	float time = g_time;
	
	if(time > 0.0)
		timers = CreateTimer(time, spawnkill);
}

public void OnMapStart()
{
	enable = true;
	
	int cts = 0;
	int ts = 0;
	
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "info_player_counterterrorist")) != -1) 
	{
		cts++;
	}
	
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "info_player_terrorist")) != -1)
	{
		ts++;
	}
	
	if (ts == 0 || cts == 0)course = true;
	else course = false;
}

public Action Event_spawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (g_enable && !enable && IsPlayerAlive(client))
	{
		if(g_timer[client] != INVALID_HANDLE) KillTimer(g_timer[client]);
		g_timer[client] = INVALID_HANDLE;
		
		g_timer[client] = CreateTimer(0.5, CheckPlayer, client); 
		ForcePlayerSuicide(client);
	}
}

public Action CheckPlayer(Handle timer, int client)
{
	
	if (!enable)
	{	
		if(IsPlayerAlive(client)) ForcePlayerSuicide(client);
		
		// continue player alive
		if(IsPlayerAlive(client))
		{
			int team = GetClientTeam(client);
			
			ChangeClientTeam(client, 1);
			ChangeClientTeam(client, team);
		}
	}
	g_timer[client] = INVALID_HANDLE;
}

public Action Event_Playerdeath(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_enable)
		return;
		
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	/* this produces to respawn only on suicide or world deaths
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(IsValidClient(attacker) && attacker != client) return;
	*/
	
	if(enable) CreateTimer(g_respawn, Respawn, GetClientUserId(client));
}

public Action Respawn(Handle timer, int userid)
{
	if (!g_enable)
		return;
		
	if (g_course && !course)return;
	int client = GetClientOfUserId(userid);
	if(client == 0) return;
	
	if(IsClientInGame(client) && !IsPlayerAlive(client) && GetClientTeam(client) > 1 && enable) CS_RespawnPlayer(client)
}

public Action OnJoinTeam(int client, const char[] command, int numArgs)
{
	if (!g_enable)
		return;
		
	if (!IsClientInGame(client) || numArgs < 1) return;

	if(!IsPlayerAlive(client))
		if(enable) CreateTimer(g_respawn, Respawn, GetClientUserId(client));
}

public void OnClientDisconnect(int client)
{
	if(g_timer[client] != INVALID_HANDLE) KillTimer(g_timer[client]);
	g_timer[client] = INVALID_HANDLE;
		
	g_fDeathTime[client] = 0.0;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
		{
			OnClientDisconnect(i);
		}
		
	if (g_course && !course)return;
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

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_enable)
		return;
		
	if (!g_spawnkill)return;
	
	if (!enable)
		return;
		
	if (g_course && !course)return;
	char weapon[32];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (victim && !attacker && StrEqual(weapon, "trigger_hurt"))
	{
		float fGameTime = GetGameTime();
		
		if (fGameTime - g_fDeathTime[victim] - g_respawn < 2.0)
		{
			PrintToChatAll(" \x04Repeat killer detected. Disabling autorespawn for this round.");
			enable = false;
		}
		
		g_fDeathTime[victim] = fGameTime;
	}
}

public bool IsValidClient( int client ) 
{ 
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
        return false; 
     
    return true; 
}
