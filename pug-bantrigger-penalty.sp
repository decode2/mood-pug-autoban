#include <sourcemod>
#include <sdktools>
#include <pugsetup>

#define PLUGIN_VERSION "0.1"

public Plugin myinfo ={
	
	name = "AutoBan on match disconnect for PUG",
	author = "Deco",
	description = "",
	version = PLUGIN_VERSION,
	url = "www.piu-games.com"
}

ArrayList arrayPlayersIds;
ArrayList arrayPlayersTime;
ArrayList arrayPlayerName;

ConVar cvEnable;
ConVar cvBantime;
ConVar cvTime;
ConVar cvSpectators;

public void OnPluginStart(){
	
	CreateConVar("sm_bt_version", PLUGIN_VERSION, "", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	AutoExecConfig(true, "pug-bantrigger-penalty", "sourcemod/pug-bantrigger-penalty");  //   ./<game>/cfg/sourcemod/pug-bantrigger-penalty/pug-bantrigger-penalty.cfg
	
	cvEnable = CreateConVar("sm_bt_enable", "0", "Enable or disable the functions of this plugin");
	cvBantime = CreateConVar("sm_bt_bantime", "360", "Ban time for people that disconnect on match live");
	cvTime = CreateConVar("sm_bt_time", "300", "Time to wait for people to reconnect until applying the ban");
	cvSpectators = CreateConVar("sm_bt_excludespectators", "0", "Exclude spectators from the ban countdown?");
	
	HookConVarChange(cvEnable, HookConvarChange);
	
	arrayPlayersIds = CreateArray(64);
	arrayPlayersTime  = CreateArray();
	arrayPlayerName  = CreateArray(128);
	
	CreateTimer(1.0, Timer_Checker, _, TIMER_REPEAT);
}

public void HookConvarChange(Handle hHandle, const char[] oldValue, const char[] newValue) {
	ClearArrays();
}

public OnMapStart(){
	
	ClearArrays();
}

public Action Timer_Checker(Handle timer){
	
	if(!cvEnable.BoolValue)
		return;
		
	int size = arrayPlayersTime.Length;
	
	if (size == 0){
		return;
	}
	
	char steamid[64], name[128];
	
	for (int i = 0; i < size; i++){
		
		if(GetTime() > arrayPlayersTime.Get(i)+cvTime.IntValue){
			
			arrayPlayersIds.GetString(i, steamid, sizeof(steamid));
			arrayPlayerName.GetString(i, name, sizeof(name));
			
			ServerCommand("sm_addban %i %s Partida abandonada por %s", cvBantime.IntValue, steamid, name);
			
			PrintToChatAll(" \x04[MOOD]\x03 %s\x01 fue baneado por abandonar la partida.", name);
			
			arrayPlayersTime.Erase(i);
			arrayPlayersIds.Erase(i);
			arrayPlayerName.Erase(i);
		}
	}
}

public OnClientPostAdminCheck(int client){
	
	if(!cvEnable.BoolValue)
		return;
		
	char steamid[64];
	if(!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid))){
		return; // prevent fail on auth
	}
	
	int index = arrayPlayersIds.FindString(steamid);
	
	if (index == -1){
		return;
	}
	
	arrayPlayersTime.Erase(index);
	arrayPlayersIds.Erase(index);
	arrayPlayerName.Erase(index);
	
}

public OnClientDisconnect(client){
	
	if(!cvEnable.BoolValue || CheckCommandAccess(client, "bancountdown_inmunity", ADMFLAG_ROOT)
	|| (cvSpectators.BoolValue && GetClientTeam(client) < 2))
		return;
	
	char steamid[64], name[128];
	if(!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid))){
		return; // prevent fail on auth
	}
	
	int index = arrayPlayersIds.FindString(steamid);
	
	if (index != -1){
		return; // will not add duplicated values
	}
	
	GetClientName(client, name, sizeof(name));
	
	arrayPlayersIds.PushString(steamid);
	arrayPlayersTime.Push(GetTime());
	arrayPlayerName.PushString(name);
}


void ClearArrays(){
	
	arrayPlayersIds.Clear();
	arrayPlayersTime.Clear();
	arrayPlayerName.Clear();
}


// Pug setup API
public void PugSetup_OnGameStateChanged(GameState before, GameState after){
	
	if(after == GameState_Live)
		SetConVarBool(cvEnable, true);
	else
		SetConVarBool(cvEnable, false);
}

public void OnResetMatch(){
	
	ClearArrays();
}