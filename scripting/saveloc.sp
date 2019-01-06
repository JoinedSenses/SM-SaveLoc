#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include "saveloc.inc"
#undef REQUIRE_PLUGIN
#include <tf2_stocks>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "0.2.0"
#define PLUGIN_DESCRIPTION "Retain position, angle, and velocity data"
#define COMMAND_PRACTICE "practice"

ConVar g_cvarRequireEnable;
ConVar g_cvarAllowOther;
ConVar g_cvarForceSameTeam;
ConVar g_cvarForceSameClass;
ConVar g_cvarWipeOnTeam;
ConVar g_cvarWipeOnClass;

// Stores up to MAX_RECENT_LOCS saves
ArrayList g_aOrigin[MAXPLAYERS+1];
ArrayList g_aAngles[MAXPLAYERS+1];
ArrayList g_aVelocity[MAXPLAYERS+1];
ArrayList g_aTime[MAXPLAYERS+1];

// Forwards
Handle g_hForwardOnEnable;
Handle g_hForwardOnSaveLoc;
Handle g_hForwardOnTeleLoc;

// int arrays for tracking
int g_iCount[MAXPLAYERS+1];
int g_iCurrent[MAXPLAYERS+1] = {-1, ...};
int g_iTarget[MAXPLAYERS+1];

// Client's current TL
float g_vOrigin[MAXPLAYERS+1][3];
float g_vAngles[MAXPLAYERS+1][3];
float g_vVelocity[MAXPLAYERS+1][3];
float g_fTime[MAXPLAYERS+1];

bool g_bTF2;
bool g_bEnabled[MAXPLAYERS+1];

public Plugin myinfo = {
	name = "Save Loc",
	author = "JoinedSenses",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "https://github.com/JoinedSenses"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	RegPluginLibrary("saveloc");
	CreateNative("SL_IsClientPracticing", Native_IsClientPracticing);
	CreateNative("SL_GetClientTotalCount", Native_GetClientTotalCount);
	CreateNative("SL_GetClientCurrentIndex", Native_GetClientCurrentIndex);
	CreateNative("SL_AddToSaves", Native_AddToSaves);
	CreateNative("SL_GetClientCurrentSave", Native_GetClientCurrentSave);
	CreateNative("SL_ClearAllSaves", Native_ClearAllSaves);
}

public void OnPluginStart() {
	CreateConVar("sm_saveloc_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD).SetString(PLUGIN_VERSION);
	g_cvarRequireEnable = CreateConVar("sm_saveloc_requireenable", "1", "Require the client activate a toggle before using commands?", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarAllowOther = CreateConVar("sm_saveloc_allowother", "1", "Allows clients to use other players' saves?", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarForceSameTeam = CreateConVar("sm_saveloc_forceteam", "1", "Only allow client to use saves from players on their own team?", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarForceSameClass = CreateConVar("sm_saveloc_forceclass", "1", "Only allow clients to use saves from players of their own class? (TF2)", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarWipeOnTeam = CreateConVar("sm_saveloc_wipeonteam", "1", "Should the plugin wipe saves on team change?", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarWipeOnClass = CreateConVar("sm_saveloc_wipeonclass", "1", "Should the plugin wipe saves on class change?", FCVAR_NONE, true, 0.0, true, 1.0);

	char cmd[32];
	Format(cmd, sizeof(cmd),  "sm_%s", COMMAND_PRACTICE);
	RegConsoleCmd(cmd, cmdEnable, "Toggle practice mode. Not required if sm_saveloc_reqireenable is set to 0");
	RegConsoleCmd("sm_sl", cmdSaveLoc, "Save current position data - sm_sl");
	RegConsoleCmd("sm_tl", cmdTeleLoc, "Tele to stored position data - sm_tl");
	RegConsoleCmd("sm_ml", cmdSetLoc, "Select from a list of recent saves - sm_ml <optional:targetname>");
	RegConsoleCmd("sm_rl", cmdRemoveLoc, "Remove from a list of recent saves - sm_rl");

	g_hForwardOnEnable = CreateGlobalForward("SL_OnPracticeToggle", ET_Event, Param_Cell);
	g_hForwardOnSaveLoc = CreateGlobalForward("SL_OnSaveLoc", ET_Event, Param_Cell, Param_Array, Param_Array, Param_Array, Param_Float);
	g_hForwardOnTeleLoc = CreateGlobalForward("SL_OnTeleLoc", ET_Event, Param_Cell);

	LoadTranslations("common.phrases.txt");

	for (int i = 1; i <= MaxClients; i++) {
		g_aOrigin[i] = new ArrayList(3);
		g_aAngles[i] = new ArrayList(3);
		g_aVelocity[i] = new ArrayList(3);
		g_aTime[i] = new ArrayList();
	}

	char gamename[32];
	GetGameFolderName(gamename, sizeof(gamename));
	g_bTF2 = StrEqual(gamename, "tf", false);

	if (g_bTF2) {
		HookEvent("player_changeclass", eventPlayerChangeClass);
	}
	else {
		HookEvent("player_class", eventPlayerChangeClass);
	}

	HookEvent("player_team", eventPlayerChangeTeam);
	
}

public void OnMapStart() {
	for (int i = 1; i <= MaxClients; i++) {
		ClearClientSettings(i);
	}
}

public void OnClientConnected(int client) {
	ClearClientSettings(client);
}

// ----------------- Events

public Action eventPlayerChangeTeam(Event event, const char[] name, bool dontBroadcast) {
	if (!g_cvarWipeOnTeam.BoolValue) {
		return;
	}
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsFakeClient(client)) {
		ClearClientSettings(client);
	}
}

public Action eventPlayerChangeClass(Event event, const char[] name, bool dontBroadcast) {
	if (!g_cvarWipeOnClass.BoolValue) {
		return Plugin_Continue;
	}
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsFakeClient(client)) {
		ClearClientSettings(client);
	}
	return Plugin_Continue;
}

// ----------------- Commands

public Action cmdEnable(int client, int args) {
	if (!g_cvarRequireEnable.BoolValue) {
		return Plugin_Handled;
	}

	Action result;
	Call_StartForward(g_hForwardOnEnable);
	Call_PushCell(client);
	Call_Finish(result);

	if (result >= Plugin_Handled) {
		return Plugin_Handled;
	}

	g_bEnabled[client] = !g_bEnabled[client];
	PrintToChat(client, "\x01[\x03SL\x01] Practice mode\x03 %s", g_bEnabled[client] ? "enabled" : "disabled");
	ClearClientSettings(client);
	return Plugin_Handled;
}

public Action cmdSaveLoc(int client, int args) {
	if (!client) {
		return Plugin_Handled;
	}

	if (g_cvarRequireEnable.BoolValue && !IsClientPracticing(client)) {
		PrintToChat(client, "\x01[\x03SL\x01] Type /%s prior to using this command", COMMAND_PRACTICE);
		return Plugin_Handled;
	}

	float origin[3];
	GetClientAbsOrigin(client, origin);

	bool nearGround = GetClientDistanceToGround(client) <= 20.0;
	bool nearCeiling = GetClientDistanceToCeiling(client) <= 25.0;

	if (nearGround && nearCeiling) {
		PrintToChat(client, "\x01[\x03SL\x01] Unable to save here, might get stuck");
		return Plugin_Handled;
	}

	if (GetClientButtons(client) & IN_DUCK) {
		if (nearGround) {
			origin[2] += 20.0;
		}
		if (nearCeiling) {
			origin[2] -= 20.0;
		}
	}

	float angles[3];
	GetClientEyeAngles(client, angles);

	float velocity[3];
	GetClientAbsVelocity(client, velocity);

	float time = GetGameTime();

	Action result;
	Call_StartForward(g_hForwardOnSaveLoc);
	Call_PushCell(client);
	Call_PushArray(origin, sizeof(origin));
	Call_PushArray(angles, sizeof(angles));
	Call_PushArray(velocity, sizeof(velocity));
	Call_PushFloat(time);
	Call_Finish(result);

	if (result >= Plugin_Handled) {
		return Plugin_Handled;
	}

	SaveLoc(client, origin, angles, velocity, time);

	PrintToChat(client, "\x01[\x03SL\x01] Saved Loc");

	return Plugin_Handled;
}

public Action cmdTeleLoc(int client, int args) {
	if (!client) {
		return Plugin_Handled;
	}

	if (g_cvarRequireEnable.BoolValue && !IsClientPracticing(client)) {
		PrintToChat(client, "\x01[\x03SL\x01] Type /%s prior to using this command", COMMAND_PRACTICE);
		return Plugin_Handled;
	}

	if (IsZeroVector(g_vOrigin[client])) {
		PrintToChat(client, "\x01[\x03SL\x01] No teleport to retrieve");
		return Plugin_Handled;
	}

	Action result;
	Call_StartForward(g_hForwardOnTeleLoc);
	Call_PushCell(client);
	Call_Finish(result);

	if (result >= Plugin_Handled) {
		return Plugin_Handled;
	}

	TeleportEntity(client, g_vOrigin[client], g_vAngles[client], g_vVelocity[client]);
	return Plugin_Handled;
}

public Action cmdSetLoc(int client, int args) {
	if (!client) {
		return Plugin_Handled;
	}

	if (g_cvarRequireEnable.BoolValue && !IsClientPracticing(client)) {
		PrintToChat(client, "\x01[\x03SL\x01] Type /%s prior to using this command", COMMAND_PRACTICE);
		return Plugin_Handled;
	}

	char arg[32];
	int target;
	if (args && g_cvarAllowOther.BoolValue) {
		GetCmdArg(1, arg, sizeof(arg));
		if ((target = FindTarget(client, arg, true, false)) == -1) {
			return Plugin_Handled;
		}
		if (g_cvarForceSameTeam.BoolValue && GetClientTeam(client) != GetClientTeam(target)) {
			PrintToChat(client, "\x01[\x03SL\x01] Can't use saves from target on another team");
			return Plugin_Handled;
		}
		if (g_bTF2 && g_cvarForceSameClass.BoolValue && TF2_GetPlayerClass(client) != TF2_GetPlayerClass(target)) {
			PrintToChat(client, "\x01[\x03SL\x01] Can't use saves from target on another class");
			return Plugin_Handled;
		}
	}
	else {
		target = client;
	}

	ShowLocMenu(client, target);
	return Plugin_Handled;
}

public Action cmdRemoveLoc(int client, int args) {
	if (!client) {
		return Plugin_Handled;
	}

	if (g_cvarRequireEnable.BoolValue && !IsClientPracticing(client)) {
		PrintToChat(client, "\x01[\x03SL\x01] Type /%s prior to using this command", COMMAND_PRACTICE);
		return Plugin_Handled;
	}

	ShowLocMenu(client, client, true);
	return Plugin_Handled;
}

// ----------------- Menus

void ShowLocMenu(int client, int target, bool remove = false) {
	if (!remove) {
		g_iTarget[client] = target;
	}

	if (!g_iCount[target]) {
		PrintToChat(client, "%s no saves available for use", (client == target) ? "You have" : "Target has");
		return;
	}

	float origin[3];
	float time;
	char buffer[64];
	Format(buffer, sizeof(buffer), "%N's Saves", target);

	MenuAction menuflags = MENU_ACTIONS_DEFAULT;
	menuflags |= remove ? MenuAction_DisplayItem : MenuAction_DrawItem;

	Menu menu = new Menu(remove ? menuHandler_RemoveLoc : menuHandler_SetLoc, menuflags);
	menu.SetTitle(buffer);

	for (int i = 0; i < g_iCount[target]; i++) {
		GetClientSave(target, i, origin, NULL_VECTOR, NULL_VECTOR, time);

		char index[3];
		Format(index, sizeof(index), "%i", i);

		float timeDiff = (GetGameTime()-time)/60;

		char sTime[32];
		if (timeDiff > 0.0) {
			Format(sTime, sizeof(sTime), "(%0.1f minutes ago)", timeDiff);
		}

		Format(buffer, sizeof(buffer), "%0.0f, %0.0f, %0.0f %s", origin[0], origin[1], origin[2], sTime);
		menu.AddItem(index, buffer);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

int menuHandler_SetLoc(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[3];
			menu.GetItem(param2, item, sizeof(item));
			int position = StringToInt(item);

			int target = g_iTarget[param1];

			g_iCurrent[param1] = (target == param1) ? position : -1;

			GetClientSave(target, position, g_vOrigin[param1], g_vAngles[param1], g_vVelocity[param1]);

			ShowLocMenu(param1, g_iTarget[param1]);
		}
		case MenuAction_DrawItem: {
			char item[3];
			menu.GetItem(param2, item, sizeof(item));

			if (g_iTarget[param1] == param1 && g_iCurrent[param1] == StringToInt(item)) {
				return ITEMDRAW_DISABLED;
			}
		}
		case MenuAction_End: {
			delete menu;
		}
	}
	return 0;
}

int menuHandler_RemoveLoc(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[3];
			menu.GetItem(param2, item, sizeof(item));
			RemoveClientSave(param1, StringToInt(item));
			ShowLocMenu(param1, param1, true);
		}
		case MenuAction_DisplayItem: {
			char item[3];
			char buffer[64];
			menu.GetItem(param2, item, sizeof(item), _, buffer, sizeof(buffer));

			if (g_iCurrent[param1] == StringToInt(item)) {
				Format(buffer, sizeof(buffer), "%s (Current)", buffer);
				return RedrawMenuItem(buffer);
			}
		}
		case MenuAction_End: {
			delete menu;
		}
	}
	return 0;
}

// ----------------- Natives

public int Native_IsClientPracticing(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	}
	if (!IsClientConnected(client)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
	}
	return g_bEnabled[client];
}

public int Native_GetClientTotalCount(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	}
	if (!IsClientConnected(client)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
	}
	return g_iCount[client];
} 

public int Native_GetClientCurrentIndex(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	}
	if (!IsClientConnected(client)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
	}
	return g_iCurrent[client];
}

public int Native_GetClientCurrentSave(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	}
	if (!IsClientConnected(client)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
	}

	SetNativeArray(2, g_vOrigin[client], 3);
	SetNativeArray(3, g_vAngles[client], 3);
	SetNativeArray(4, g_vVelocity[client], 3);
	SetNativeCellRef(5, g_fTime[client]);

	return g_fTime[client] > 0.0;
}

public int Native_AddToSaves(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	}
	if (!IsClientConnected(client)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
	}

	float origin[3];
	GetNativeArray(2, origin, sizeof(origin));

	float angles[3];
	GetNativeArray(3, angles, sizeof(angles));

	float velocity[3];
	GetNativeArray(4, velocity, sizeof(velocity));

	float time = GetNativeCell(5);

	SaveLoc(client, origin, angles, velocity, time);

	return g_iCount[client];
}

public int Native_ClearAllSaves(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	}
	if (!IsClientConnected(client)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
	}
	ClearClientSettings(client);
	return 1;
}

// ----------------- Internal method/stocks

bool IsClientPracticing(int client) {
	return g_bEnabled[client];
}

void SaveLoc(int client, float origin[3], float angles[3], float velocity[3], float time) {
	if (g_iCount[client] == MAX_RECENT_LOCS) {
		g_aOrigin[client].Erase(0);
		g_aAngles[client].Erase(0);
		g_aVelocity[client].Erase(0);
		g_aTime[client].Erase(0);
	}
	else {
		g_iCount[client]++;
	}

	g_iCurrent[client] = g_iCount[client]-1;
	g_aOrigin[client].PushArray(origin);
	g_aAngles[client].PushArray(angles);
	g_aVelocity[client].PushArray(velocity);
	g_aTime[client].Push(time);

	g_vOrigin[client] = origin;
	g_vAngles[client] = angles;
	g_vVelocity[client] = velocity;
	g_fTime[client] = time;

	g_iTarget[client] = client;
}

void GetClientSave(int client, int position, float origin[3], float angles[3], float velocity[3], float &time = 0.0) {
	if (position < 0 || position > g_iCount[client]) {
		return;
	}
	if (!IsNullVector(origin)) {
		g_aOrigin[client].GetArray(position, origin, sizeof(origin));
	}
	if (!IsNullVector(angles)) {
		g_aAngles[client].GetArray(position, angles, sizeof(angles));
	}
	if (!IsNullVector(velocity)) {
		g_aVelocity[client].GetArray(position, velocity, sizeof(velocity));
	}
	time = g_aTime[client].Get(position);
}

void RemoveClientSave(int client, int position) {
	if (position < 0 || position > g_iCount[client]) {
		return;
	}

	g_aOrigin[client].Erase(position);
	g_aAngles[client].Erase(position);
	g_aVelocity[client].Erase(position);
	g_aTime[client].Erase(position);
	g_iCount[client]--;

	bool same = g_iTarget[client] == client;
	if (same && g_iCurrent[client] <= 0) {
		ZeroVector(g_vOrigin[client]);
		g_iCurrent[client] = -1;
		return;
	}
	if (same && g_iCurrent[client] == position || g_iCurrent[client] == g_iCount[client]) {
		GetClientSave(client, --g_iCurrent[client], g_vOrigin[client], g_vAngles[client], g_vVelocity[client]);
	}
}

void ClearClientSettings(int client) {
	g_aOrigin[client].Clear();
	g_aAngles[client].Clear();
	g_aVelocity[client].Clear();
	g_aTime[client].Clear();
	g_iCount[client] = 0;
	g_iCurrent[client] = -1;
	g_iTarget[client] = client;
	g_vOrigin[client] = NULL_VECTOR;
	g_vAngles[client] = NULL_VECTOR;
	g_vVelocity[client] = NULL_VECTOR;
	g_fTime[client] = 0.0;
}

bool IsZeroVector(float vector[3]) {
	return vector[0] == 0.0 && vector[1] == 0.0 && vector[2] == 0.0;
}

float GetClientDistanceToGround(int client) {
	// Player is already standing on the ground?
	if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == 0) {
		return 0.0;
	}
	
	float fOrigin[3];
	float fGround[3] = {90.0, 0.0, 0.0};
	GetClientAbsOrigin(client, fOrigin);
	
	fOrigin[2] += 10.0;
	
	TR_TraceRayFilter(fOrigin, fGround, MASK_PLAYERSOLID, RayType_Infinite, TraceRayNoPlayers);

	if (TR_DidHit()) {
		TR_GetEndPosition(fGround);
		fOrigin[2] -= 10.0;
		return GetVectorDistance(fOrigin, fGround);
	}

	return 0.0;
}

float GetClientDistanceToCeiling(int client) {    
	float fOrigin[3];
	float fCeiling[3] = {270.0, 0.0, 0.0};
	GetClientEyePosition(client, fOrigin);
	
	fOrigin[2] += 5.0;
	
	TR_TraceRayFilter(fOrigin, fCeiling, MASK_ALL, RayType_Infinite, TraceRayNoPlayers);

	if (TR_DidHit()) {
		TR_GetEndPosition(fCeiling);
		return GetVectorDistance(fOrigin, fCeiling);
	}

	return 0.0;
}

bool TraceRayNoPlayers(int entity, int mask) {
	return entity > MaxClients;
}