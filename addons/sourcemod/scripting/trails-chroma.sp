/*
 * Trails Chroma
 * by: Nickelony
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 */

#include <clientprefs>
#include <sdktools>
#include <sourcemod>

#undef REQUIRE_EXTENSIONS
#include <tf2>
#include <tf2_stocks>

#include <trails-definitions>
#include <trails-special-effects>
#include <trails-utils>

#pragma newdecls required
#pragma semicolon 1

// #define DEBUG

ConVar gCV_PluginEnabled = null;
ConVar gCV_ForceAdminsOnly = null;
ConVar gCV_ForceCheapTrails = null;
ConVar gCV_RemoveOnRespawn = null;
ConVar gCV_AllowHide = null;

Handle gH_TrailChoiceCookie = null;
Handle gH_TrailHidingCookie = null;

EngineVersion gEV_Type = Engine_Unknown;

#include <trails\configs>
#include <trails\menus>
#include <trails\rendering>

public Plugin myinfo =
{
	name = "Trails Chroma",
	author = "Nickelony",
	description = "Adds colorful player trails with special effects.",
	version = "3.0",
	url = "https://github.com/Nickelony"
};

public void OnPluginStart()
{
	gEV_Type = GetEngineVersion();

	HookEvent("player_spawn", OnPlayerSpawn);

	RegConsoleCmd("sm_trail", Command_Trail, "Opens the 'Trail Selection' menu.");
	RegConsoleCmd("sm_trails", Command_Trail, "Opens the 'Trail Selection' menu.");
	RegConsoleCmd("sm_hide", Command_Hide, "Hides other players' trails.");

	gCV_PluginEnabled = CreateConVar("sm_trails_enabled", "1", "Enables all features of the plugin.", 0, true, 0.0, true, 1.0);
	gCV_ForceAdminsOnly = CreateConVar("sm_trails_force_admins_only", "1", "Forces all trails to be for admins only.", 0, true, 0.0, true, 1.0);
	gCV_ForceCheapTrails = CreateConVar("sm_trails_force_cheap", "0", "Forces all trails to be cheap (lower quality in exchange for more FPS).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCV_RemoveOnRespawn = CreateConVar("sm_trails_remove_on_respawn", "0", "Removes the player's trail after respawning.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCV_AllowHide = CreateConVar("sm_trails_allow_hide", "1", "Allows hiding other players' trails.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	AutoExecConfig();

	gH_TrailChoiceCookie = RegClientCookie("trail_choice", "Trail Choice Cookie", CookieAccess_Protected);
	gH_TrailHidingCookie = RegClientCookie("trail_hiding", "Trail Hiding Cookie", CookieAccess_Protected);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (AreClientCookiesCached(i))
			OnClientCookiesCached(i);
	}
}

public void OnClientCookiesCached(int client)
{
	char choiceCookie[8];
	GetClientCookie(client, gH_TrailChoiceCookie, choiceCookie, 8);

	if (IsNullStringOrEmpty(choiceCookie))
		RemoveTrail(client);
	else
		gI_SelectedTrail[client] = StringToInt(choiceCookie);

	char hidingCookie[8];
	GetClientCookie(client, gH_TrailHidingCookie, hidingCookie, 8);
	gB_IsHidingTrails[client] = StringToInt(hidingCookie) == 1;
}

public void OnMapStart()
{
	if (!LoadTrailsConfig())
		SetFailState("Failed to load \"" ... TRAILS_CONFIG_PATH... "\". File missing or invalid.");

	gI_BeamSprite = PrecacheModel(TRAILS_BEAM_SPRITE_VMT, true);

	AddFileToDownloadsTable(TRAILS_BEAM_SPRITE_VMT);
	AddFileToDownloadsTable(TRAILS_BEAM_SPRITE_VTF);
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (gCV_RemoveOnRespawn.BoolValue) // Reset trail on respawn if convar is enabled
		RemoveTrail(client);
}

public Action Command_Hide(int client, int args)
{
	if (!gCV_PluginEnabled.BoolValue || !gCV_AllowHide.BoolValue || !IsValidClient(client))
		return Plugin_Handled;

	gB_IsHidingTrails[client] = !gB_IsHidingTrails[client]; // Toggle it

	bool isCSGO = gEV_Type == Engine_CSGO;

	char fontColor[24];
	FormatEx(fontColor, 24, "<span color='%s'>", gB_IsHidingTrails[client] ? "#FF00FF" : "#FFFF00");

	char message[255];
	FormatEx(message, 255, "Other players' trails are now %s%s%s", isCSGO ? fontColor : "", gB_IsHidingTrails[client] ? "Hidden" : "Visible", isCSGO ? "</span>" : "");

	PrintCenterText(client, message);
	SetClientCookie(client, gH_TrailHidingCookie, gB_IsHidingTrails[client] ? "1" : "0");

	return Plugin_Handled;
}

public Action Command_Trail(int client, int args)
{
	if (!gCV_PluginEnabled.BoolValue || !IsValidClient(client))
		return Plugin_Handled;

	bool noPermissions = gCV_ForceAdminsOnly.BoolValue && !CheckCommandAccess(client, "sm_trails_override", ADMFLAG_RESERVATION);

	if (noPermissions)
	{
		PrintCenterText(client, "You do not have permissions to use this command.");
		return Plugin_Handled;
	}

	return OpenTrailMenu(client, 0);
}

void RemoveTrail(int client)
{
	gI_SelectedTrail[client] = TRAILS_NONE;

	char choiceCookie[8];
	IntToString(TRAILS_NONE, choiceCookie, 8);
	SetClientCookie(client, gH_TrailChoiceCookie, choiceCookie);
}

public Action OnPlayerRunCmd(int client)
{
	int choice = gI_SelectedTrail[client];

	if (!gCV_PluginEnabled.BoolValue || choice == TRAILS_NONE)
		return Plugin_Continue;

	if (gT_Trails[choice].IsCheap || gCV_ForceCheapTrails.BoolValue)
		DrawCheapTrail(client, gT_Trails[choice]);
	else
		DrawExpensiveTrail(client, gT_Trails[choice]);

	return Plugin_Continue;
}
