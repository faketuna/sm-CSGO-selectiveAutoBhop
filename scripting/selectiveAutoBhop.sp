#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "0.0.1"

ConVar g_cPluginEnabled;
ConVar g_cAutoBunnyHopping;
char g_sAutoBunnyHopping[2] = "0";

bool g_bPluginEnabled;
bool g_bPlayerBhop[MAXPLAYERS+1];

public Plugin myinfo =
{
    name = "Selective auto bhop",
    author = "faketuna",
    description = "",
    version = PLUGIN_VERSION,
    url = "https://short.f2a.dev/s/github"
};

public void OnPluginStart() {
    LoadTranslations("selectiveAutoBhop.phrases");

    g_cPluginEnabled        = CreateConVar("sab_enabled", "1", "Enable Disable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cAutoBunnyHopping     = FindConVar("sv_autobunnyhopping");

    RegConsoleCmd("sm_bhop", CommandBhop);

    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i) && !IsFakeClient(i)) {
            g_bPlayerBhop[i] = false;
            SendConVarValue(i, g_cAutoBunnyHopping, "0");
        }
    }
    g_cPluginEnabled.AddChangeHook(OnCvarsChanged);
    g_cAutoBunnyHopping.AddChangeHook(OnServerBhopToggled);
    HookEvent("round_start", OnRoundStart, EventHookMode_Post);
}

public Action CommandBhop(int client, int agrs) {
    SetGlobalTransTarget(client);
    if(client == -1) {
        return Plugin_Handled;
    }
    if(!g_bPluginEnabled) {
        CPrintToChat(client, "%t%t", "sab prefix", "sab cmd disabled");
        return Plugin_Handled;
    }
    g_bPlayerBhop[client] = !g_bPlayerBhop[client];
    SendConVarValue(client, g_cAutoBunnyHopping, g_bPlayerBhop[client] ? "1" : "0");
    CPrintToChat(client, "%t%t", "sab prefix", g_bPlayerBhop[client] ? "sab enabled" : "sab disabled");
    return Plugin_Handled;
}

public Action OnRoundStart(Handle event, const char[] name, bool dontBroadcast) {
    if(g_bPluginEnabled) {
        CPrintToChatAll("%t%t", "sab prefix", "sab notice");
    }
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i) && !IsFakeClient(i)) {
            if(!g_bPluginEnabled) {
                SendConVarValue(i, g_cAutoBunnyHopping, g_sAutoBunnyHopping);
                continue;
            }
            SendConVarValue(i, g_cAutoBunnyHopping, g_bPlayerBhop[i] ? "1" : "0");
        }
    }
    return Plugin_Handled;
}

public void OnPlayerConnected(int client) {
    g_bPlayerBhop[client] = false;
}

public void OnClientDisconnected(int client) {
    g_bPlayerBhop[client] = false;
}

public void OnConfigsExecuted() {
    syncValues();
}

public void syncValues() {
    g_bPluginEnabled    = g_cPluginEnabled.BoolValue;
}

public void OnCvarsChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    if(StrEqual(oldValue, newValue)) {
        return;
    }

    syncValues();
}

public void OnServerBhopToggled(ConVar convar, const char[] oldValue, const char[] newValue) {
    if(StrEqual(oldValue, newValue)) {
        return;
    }
    strcopy(g_sAutoBunnyHopping, sizeof(g_sAutoBunnyHopping), newValue);
    CreateTimer(0.01, delayedConVarSync, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action delayedConVarSync(Handle timer) {
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i) && !IsFakeClient(i)) {
            if(!g_bPluginEnabled) {
                SendConVarValue(i, g_cAutoBunnyHopping, g_sAutoBunnyHopping);
                continue;
            }
            SendConVarValue(i, g_cAutoBunnyHopping, g_bPlayerBhop[i] ? "1" : "0");
        }
    }
    return Plugin_Stop;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
    if(!g_bPluginEnabled || !g_bPlayerBhop[client] || !IsPlayerAlive(client)) {
        return Plugin_Continue;
    }
    if (buttons & IN_JUMP) {
        int entflags = GetEntityFlags(client);
        if (entflags & FL_INWATER || entflags & FL_SWIM) {
            return Plugin_Continue;
        }
        if (GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1) {
            if (validMoveType(GetEntityMoveType(client))) {
                buttons &= ~IN_JUMP;
            }
        }
    }
    return Plugin_Continue;
}

bool validMoveType(MoveType moveType) {
    switch(moveType) {
        case MOVETYPE_LADDER: {return false;}
        default: {return true;}
    }
}