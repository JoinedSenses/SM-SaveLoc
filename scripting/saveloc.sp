#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define MAX_RECENT 10
#define PLUGIN_VERSION "0.1.0"
#define PLUGIN_DESCRIPTION "Retain position, angle, and velocity data"

ArrayList g_aOrigin[MAXPLAYERS+1];
ArrayList g_aAngles[MAXPLAYERS+1];
ArrayList g_aVelocity[MAXPLAYERS+1];
ArrayList g_aTime[MAXPLAYERS+1];

int g_iCount[MAXPLAYERS+1];
int g_iCurrent[MAXPLAYERS+1] = {-1, ...};

public Plugin myinfo = {
	name = "Save Loc",
	author = "JoinedSenses",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "https://github.com/JoinedSenses"
};

public void OnPluginStart() {
	CreateConVar("sm_saveloc_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD).SetString(PLUGIN_VERSION);
	
	RegConsoleCmd("sm_sl", cmdSaveLoc);
	RegConsoleCmd("sm_tl", cmdTeleLoc);
	RegConsoleCmd("sm_ml", cmdSetLoc);
	RegConsoleCmd("sm_rl", cmdRemoveLoc);

	for (int i = 1; i <= MaxClients; i++) {
		g_aOrigin[i] = new ArrayList(3);
		g_aAngles[i] = new ArrayList(3);
		g_aVelocity[i] = new ArrayList(3);
		g_aTime[i] = new ArrayList();
	}
}

public void OnMapStart() {
	for (int i = 1; i <= MaxClients; i++) {
		ClearClientSettings(i);
	}
}

public void OnClientConnected(int client) {
	ClearClientSettings(client);
}

void ClearClientSettings(int client) {
	g_aOrigin[client].Clear();
	g_aAngles[client].Clear();
	g_aVelocity[client].Clear();
	g_aTime[client].Clear();
	g_iCount[client] = 0;
	g_iCurrent[client] = -1;
}

public Action cmdSaveLoc(int client, int args) {
	if (!client) {
		return Plugin_Handled;
	}
	float origin[3];
	GetClientAbsOrigin(client, origin);

	float angles[3];
	GetClientEyeAngles(client, angles);

	float velocity[3];
	GetClientAbsVelocity(client, velocity);

	float time = GetGameTime();

	if (g_iCount[client] == MAX_RECENT) {
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

	PrintToChat(client, "Saved Loc");

	return Plugin_Handled;
}

public Action cmdTeleLoc(int client, int args) {
	if (!client) {
		return Plugin_Handled;
	}
	int current = g_iCurrent[client];
	if (current == -1) {
		PrintToChat(client, "No teleport to retrieve");
		return Plugin_Handled;
	}

	float origin[3];
	float angles[3];
	float velocity[3];
	GetClientSave(client, current, origin, angles, velocity);

	TeleportEntity(client, origin, angles, velocity);
	return Plugin_Handled;
}

public Action cmdSetLoc(int client, int args) {
	if (!client) {
		return Plugin_Handled;
	}

	ShowLocMenu(client);
	return Plugin_Handled;
}

public Action cmdRemoveLoc(int client, int args) {
	if (!client) {
		return Plugin_Handled;
	}

	ShowLocMenu(client, true);
	return Plugin_Handled;
}


void ShowLocMenu(int client, bool remove = false) {
	if (!g_iCount[client]) {
		return;
	}

	float origin[3];
	float angles[3];
	float velocity[3];
	float time;
	char buffer[64];

	MenuAction menuflags = MENU_ACTIONS_DEFAULT;
	menuflags |= remove ? MenuAction_DisplayItem : MenuAction_DrawItem;

	Menu menu = new Menu(remove ? menuHandler_RemoveLoc : menuHandler_SetLoc, menuflags);
	menu.SetTitle("Choose Location");
	for (int i = 0; i < g_iCount[client]; i++) {
		GetClientSave(client, i, origin, angles, velocity, time);
		char index[3];
		Format(index, sizeof(index), "%i", i);
		Format(buffer, sizeof(buffer), "%0.0f, %0.0f, %0.0f (%0.1f minutes ago)", origin[0], origin[1], origin[2], (GetGameTime()-time)/60);
		menu.AddItem(index, buffer);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

int menuHandler_SetLoc(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[3];
			menu.GetItem(param2, item, sizeof(item));
			g_iCurrent[param1] = StringToInt(item);
			menu.DisplayAt(param1, menu.Selection, MENU_TIME_FOREVER);
		}
		case MenuAction_DrawItem: {
			char item[3];
			menu.GetItem(param2, item, sizeof(item));
			if (g_iCurrent[param1] == StringToInt(item)) {
				return ITEMDRAW_DISABLED;
			}
		}
		case MenuAction_End: {
			if (param2 != MenuEnd_Selected) {
				delete menu;
			}
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
			ShowLocMenu(param1, true);
		}
		case MenuAction_Display: {
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

void GetClientSave(int client, int position, float origin[3], float angles[3], float velocity[3], float &time = 0.0) {
	g_aOrigin[client].GetArray(position, origin, sizeof(origin));
	g_aAngles[client].GetArray(position, angles, sizeof(angles));
	g_aVelocity[client].GetArray(position, velocity, sizeof(velocity));
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

	if (g_iCurrent[client] == g_iCount[client]) {
		g_iCurrent[client]--;
	}
}

bool GetClientAbsVelocity(int client, float velocity[3]) {
	static int offset = -1;
	
	if (offset == -1 && (offset = FindDataMapInfo(client, "m_vecAbsVelocity")) == -1) {
		ZeroVector(velocity);
		return false;
	}
	
	GetEntDataVector(client, offset, velocity);
	return true;
}

void ZeroVector(float vec[3]) {
	vec[0] = vec[1] = vec[2] = 0.0;
}