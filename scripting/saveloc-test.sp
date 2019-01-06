#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include "saveloc.inc"

bool g_bTest[MAXPLAYERS+1];
bool g_bTeleblock[MAXPLAYERS+1];

public void OnPluginStart() {
	RegAdminCmd("sm_sltest", cmdSLTest, ADMFLAG_ROOT);
}

public Action cmdSLTest(int client, int args) {
	if (!client) {
		return Plugin_Handled;
	}

	if (!SL_IsClientPracticing(client)) {
		FakeClientCommand(client, "sm_practice");
	}

	g_bTest[client] = true;

	int count = SL_GetClientTotalCount(client);
	int index = SL_GetClientCurrentIndex(client);
	PrintToChat(client, "Count: %i Index: %i", count, index);
	float origin[3];
	float angles[3];
	float velocity[3];

	GetClientAbsOrigin(client, origin);
	
	GetClientEyeAngles(client, angles);
	
	GetClientAbsVelocity(client, velocity);

	for (int i = 0; i < 3; i++) {
		SL_AddToSaves(client, origin, angles, velocity);
	}
	PrintToChat(client, "Count: %i Index: %i", count = SL_GetClientTotalCount(client), index = SL_GetClientCurrentIndex(client));

	FakeClientCommand(client, "sm_ml");
	SL_ClearAllSaves(client);

	FakeClientCommand(client, "sm_sl");

	CreateTimer(2.0, timerTele, client);

	angles[0] = -15.0;
	GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(velocity, 1000.0);

	SL_AddToSaves(client, origin, angles, velocity, GetGameTime());

	float time;
	bool result;
	result = SL_GetClientCurrentSave(client, origin, angles, velocity, time);
	PrintToChat(client, "%s {%0.2f, %0.2f, %0.2f}", result ? "True" : "False", origin[0], origin[1], origin[2]);

	g_bTeleblock[client] = true;
	FakeClientCommand(client, "sm_tl");
	g_bTeleblock[client] = false;

	return Plugin_Handled;
}

public Action SL_OnSaveLoc(int client, float origin[3], float angles[3], float velocity[3], float time) {
	if (!g_bTest[client]) {
		return Plugin_Continue;
	}
	PrintToChat(client, "Loc saved");
	return Plugin_Handled;
}

public Action SL_OnTeleLoc(int client) {
	if (!g_bTest[client]) {
		return Plugin_Continue;
	}
	PrintToChat(client, "Teleporting");

	if (g_bTeleblock[client]) {
		PrintToChat(client, "Blocking teleport");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

Action timerTele(Handle timer, int client) {
	FakeClientCommand(client, "sm_tl");
	FakeClientCommand(client, "sm_ml");
	g_bTest[client] = false;
}