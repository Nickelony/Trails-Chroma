#include <sourcemod>
#include <clientprefs>
#include <sdktools>

#pragma newdecls required
#pragma semicolon 1

enum
{
	iRedChannel,
	iGreenChannel,
	iBlueChannel,
	iSpecialColor,
	iAlphaChannel,
	SETTINGS_SIZE
}

/* CVars */

ConVar gCV_PluginEnabled = null;
ConVar gCV_AdminsOnly = null;
ConVar gCV_CheapTrails = null;
ConVar gCV_BeamLife = null;
ConVar gCV_BeamWidth = null;
ConVar gCV_OnRespawn = null;

/* Cached CVars */

bool gB_PluginEnabled = true;
bool gB_AdminsOnly = true;
bool gB_CheapTrails = false;
float gF_BeamLife = 1.5;
float gF_BeamWidth = 1.5;
bool gB_OnRespawn = false;

/* Global variables */

int gI_BeamSprite;
int gI_SelectedTrail[MAXPLAYERS + 1];
float gF_LastPosition[MAXPLAYERS + 1][3];
bool gB_StopPlugin[MAXPLAYERS + 1];

// KeyValues globals
int gI_TrailAmount;
char gS_TrailTitle[128][128];
int gI_TrailSettings[128][SETTINGS_SIZE];

// Spectrum cycle globals
int gI_CycleColor[MAXPLAYERS + 1][4];
bool gB_RedToYellow[MAXPLAYERS + 1];
bool gB_YellowToGreen[MAXPLAYERS + 1];
bool gB_GreenToCyan[MAXPLAYERS + 1];
bool gB_CyanToBlue[MAXPLAYERS + 1];
bool gB_BlueToMagenta[MAXPLAYERS + 1];
bool gB_MagentaToRed[MAXPLAYERS + 1];

// Cheap trail globals
int gI_TickCounter[MAXPLAYERS + 1];
float gF_PlayerOrigin[MAXPLAYERS + 1][3];

Handle gH_TrailCookie;

public Plugin myinfo =
{
	name = "Trails Chroma",
	author = "Nickelony",
	description = "Adds colorful player trails with special effects.",
	version = "2.0",
	url = "steamcommunity.com/id/nickelony"
}

public void OnPluginStart()
{
	HookEvent("player_spawn", OnPlayerSpawn);
	
	HookEntityOutput("trigger_teleport", "OnStartTouch", StartTouchTrigger);
	HookEntityOutput("trigger_teleport", "OnEndTouch", EndTouchTrigger);
	
	RegConsoleCmd("sm_trail", Command_Trail, "Opens the 'Trail Selection' menu.");
	RegConsoleCmd("sm_trails", Command_Trail, "Opens the 'Trail Selection' menu.");
	
	gCV_PluginEnabled = CreateConVar("sm_trails_enable", "1", "Enable or Disable all features of the plugin.", 0, true, 0.0, true, 1.0);
	gCV_AdminsOnly = CreateConVar("sm_trails_adminsonly", "1", "Enable trails for admins only.", 0, true, 0.0, true, 1.0);
	gCV_CheapTrails = CreateConVar("sm_trails_cheap", "0", "Force cheap trails (lower quality in exchange for more FPS).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCV_BeamLife = CreateConVar("sm_trails_life", "1.5", "Time duration of the trails.", FCVAR_NOTIFY, true, 0.0);
	gCV_BeamWidth = CreateConVar("sm_trails_width", "1.5", "Width of the trail beams.", FCVAR_NOTIFY, true, 0.0);
	gCV_OnRespawn = CreateConVar("sm_trails_respawn", "0", "Disable the player's trail after respawning.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	gCV_PluginEnabled.AddChangeHook(OnConVarChanged);
	gCV_AdminsOnly.AddChangeHook(OnConVarChanged);
	gCV_CheapTrails.AddChangeHook(OnConVarChanged);
	gCV_BeamLife.AddChangeHook(OnConVarChanged);
	gCV_BeamWidth.AddChangeHook(OnConVarChanged);
	gCV_OnRespawn.AddChangeHook(OnConVarChanged);
	
	AutoExecConfig();
	
	gH_TrailCookie = RegClientCookie("trail_cookie", "Trail Selection Cookie", CookieAccess_Protected);
	
	for(int i = MaxClients; i > 0; --i)
	{
		if(!AreClientCookiesCached(i))
		{
			continue;
		}
		
		OnClientCookiesCached(i);
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	gB_PluginEnabled = gCV_PluginEnabled.BoolValue;
	gB_AdminsOnly = gCV_AdminsOnly.BoolValue;
	gB_CheapTrails = gCV_CheapTrails.BoolValue;
	gF_BeamLife = gCV_BeamLife.FloatValue;
	gF_BeamWidth = gCV_BeamWidth.FloatValue;
	gB_OnRespawn = gCV_OnRespawn.BoolValue;
}

public void OnClientCookiesCached(int client)
{
	char[] sCookieValue = new char[8];
	GetClientCookie(client, gH_TrailCookie, sCookieValue, 8);
	gI_SelectedTrail[client] = StringToInt(sCookieValue);
}

public void OnMapStart()
{
	if(!gB_PluginEnabled)
	{
		return;
	}
	
	if(!LoadColorsConfig())
	{
		SetFailState("Failed load \"configs/trails-colors.cfg\". File missing or invalid.");
	}
	
	HookEntityOutput("trigger_teleport", "OnStartTouch", StartTouchTrigger);
	HookEntityOutput("trigger_teleport", "OnEndTouch", EndTouchTrigger);
	
	gI_BeamSprite = PrecacheModel("materials/trails/beam_01.vmt", true);
	
	AddFileToDownloadsTable("materials/trails/beam_01.vmt");
	AddFileToDownloadsTable("materials/trails/beam_01.vtf");
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(!gB_PluginEnabled)
	{
		return;
	}
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(gB_OnRespawn)
	{
		gI_SelectedTrail[client] = 0;
	}
	else
	{
		gB_StopPlugin[client] = true; // Prevent garbage on the first frame.
		CreateTimer(0.1, ResumePlugin, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

bool LoadColorsConfig()
{
	char[] sPath = new char[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/trails-colors.cfg");
	KeyValues kv = new KeyValues("trails-colors");
	
	if(!kv.ImportFromFile(sPath) || !kv.GotoFirstSubKey())
	{
		delete kv;
		return false;
	}
	
	int i = 0;
	
	do
	{
		kv.GetString("name", gS_TrailTitle[i], 128, "<MISSING TRAIL NAME>");
		
		gI_TrailSettings[i][iRedChannel] = kv.GetNum("red", 255);
		gI_TrailSettings[i][iGreenChannel] = kv.GetNum("green", 255);
		gI_TrailSettings[i][iBlueChannel] = kv.GetNum("blue", 255);
		gI_TrailSettings[i][iSpecialColor] = kv.GetNum("special", 0);
		gI_TrailSettings[i][iAlphaChannel] = kv.GetNum("alpha", 128);
		
		i++;
	}
	while(kv.GotoNextKey());
	
	delete kv;
	gI_TrailAmount = i;
	return true;
}

public Action Command_Trail(int client, int args)
{
	if(!gB_PluginEnabled || !IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if(gB_AdminsOnly && !CheckCommandAccess(client, "sm_trails_override", ADMFLAG_RESERVATION))
	{
		PrintCenterText(client, "Only admins may use this command.");
		return Plugin_Handled;
	}
	
	Menu menu = new Menu(Menu_Handler);
	menu.SetTitle("Choose a trail:");
	
	for(int i = 0; i < gI_TrailAmount; i++)
	{
		char[] sInfo = new char[16];
		IntToString(i, sInfo, 16);
		
		if(StrEqual(gS_TrailTitle[i], "/EMPTY/"))
		{
			menu.AddItem("", "", ITEMDRAW_SPACER);
		}
		else
		{
			menu.AddItem(sInfo, gS_TrailTitle[i], (gI_SelectedTrail[client] == i)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
		}
	}
	
	menu.ExitButton = true;
	menu.Display(client, 20);
	
	return Plugin_Handled;
}

public int Menu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char[] sInfo = new char[16];
		menu.GetItem(param2, sInfo, 16);
		
		MenuSelection(param1, sInfo);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

void MenuSelection(int client, char[] info)
{
	int choice = StringToInt(info);
	
	int color[3];
	color[0] = gI_TrailSettings[choice][iRedChannel];
	color[1] = gI_TrailSettings[choice][iGreenChannel];
	color[2] = gI_TrailSettings[choice][iBlueChannel];
	
	char[] sHexColor = new char[16];
	FormatEx(sHexColor, 16, "#%02x%02x%02x", color[0], color[1], color[2]);
	
	if(choice == 0)
	{
		PrintCenterText(client, "Your trail is now <font color='#FF0000'>DISABLED</font>.");
	}
	else
	{
		if(gI_SelectedTrail[client] == 0)
		{
			PrintCenterText(client, "Your trail is now <font color='#00FF00'>ENABLED</font>.\nYour beam color is: <font color='%s'>%s</font>.", sHexColor, gS_TrailTitle[choice]);
		}
		else
		{
			PrintCenterText(client, "Your beam color is now: <font color='%s'>%s</font>.", sHexColor, gS_TrailTitle[choice]);
		}
	}
	
	if(gI_TrailSettings[choice][iSpecialColor] == 1 || gI_TrailSettings[choice][iSpecialColor] == 2)
	{
		gI_CycleColor[client][0] = 0;
		gI_CycleColor[client][1] = 0;
		gI_CycleColor[client][2] = 0;
		gB_RedToYellow[client] = true;
	}
	else
	{
		gB_RedToYellow[client] = false;
		gB_YellowToGreen[client] = false;
		gB_GreenToCyan[client] = false;
		gB_CyanToBlue[client] = false;
		gB_BlueToMagenta[client] = false;
		gB_MagentaToRed[client] = false;
	}
	
	gI_SelectedTrail[client] = choice;
	SetClientCookie(client, gH_TrailCookie, info);
}

public Action OnPlayerRunCmd(int client)
{
	if(gB_CheapTrails)
	{
		ForceCheapTrails(client);
	}
	else
	{
		ForceExpensiveTrails(client);
	}
	
	return Plugin_Continue;
}

void ForceCheapTrails(int client)
{
	if(gI_TickCounter[client] == 0)
	{
		float fOrigin[3];
		GetClientAbsOrigin(client, fOrigin);
		
		gF_PlayerOrigin[client][0] = fOrigin[0];
		gF_PlayerOrigin[client][1] = fOrigin[1];
		gF_PlayerOrigin[client][2] = fOrigin[2];
	}
	
	gI_TickCounter[client]++;
	
	if(gI_TickCounter[client] <= 1)
	{
		return; //Skip 1 frame. That's 50% less sprites to render.
	}
	
	gI_TickCounter[client] = 0;
	
	CreatePlayerTrail(client, gF_PlayerOrigin[client]);
	gF_LastPosition[client] = gF_PlayerOrigin[client];
}

void ForceExpensiveTrails(int client)
{
	float fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);
	
	CreatePlayerTrail(client, fOrigin);
	gF_LastPosition[client] = fOrigin;
}

void CreatePlayerTrail(int client, float origin[3])
{
	if(!gB_PluginEnabled || !IsPlayerAlive(client) || gI_SelectedTrail[client] == 0 || gB_StopPlugin[client])
	{
		return;
	}
	
	if(gB_AdminsOnly && !CheckCommandAccess(client, "sm_trails_override", ADMFLAG_RESERVATION))
	{
		return;
	}
	
	float fFirstPos[3];
	fFirstPos[0] = origin[0];
	fFirstPos[1] = origin[1];
	fFirstPos[2] = origin[2] + 5.0;
	
	float fSecondPos[3];
	fSecondPos[0] = gF_LastPosition[client][0];
	fSecondPos[1] = gF_LastPosition[client][1];
	fSecondPos[2] = gF_LastPosition[client][2] + 5.0;
	
	int choice = gI_SelectedTrail[client];
	
	int color[4];
	color[3] = gI_TrailSettings[choice][iAlphaChannel];
	int stepsize;
	
	if(gI_TrailSettings[choice][iSpecialColor] == 1) // Spectrum trail
	{
		stepsize = 1;
		DrawSpectrumTrail(client, stepsize);
		
		color[0] = gI_CycleColor[client][0];
		color[1] = gI_CycleColor[client][1];
		color[2] = gI_CycleColor[client][2];
		
		PrintHintText(client, "%i\n%i\n%i", gI_CycleColor[client][0], gI_CycleColor[client][1], gI_CycleColor[client][2]);
	}
	else if(gI_TrailSettings[choice][iSpecialColor] == 2) // Wave trail
	{
		stepsize = 15;
		DrawSpectrumTrail(client, stepsize);
		
		color[0] = gI_CycleColor[client][0];
		color[1] = gI_CycleColor[client][1];
		color[2] = gI_CycleColor[client][2];
	}
	else if(gI_TrailSettings[choice][iSpecialColor] == 3) // Velocity trail
	{
		float fAbsVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);
		float fCurrentSpeed = SquareRoot(Pow(fAbsVelocity[0], 2.0) + Pow(fAbsVelocity[1], 2.0));
		
		DrawVelocityTrail(client, fCurrentSpeed);
		
		color[0] = gI_CycleColor[client][0];
		color[1] = gI_CycleColor[client][1];
		color[2] = gI_CycleColor[client][2];
	}
	else
	{
		color[0] = gI_TrailSettings[choice][iRedChannel];
		color[1] = gI_TrailSettings[choice][iGreenChannel];
		color[2] = gI_TrailSettings[choice][iBlueChannel];
	}
	
	TE_SetupBeamPoints(fFirstPos, fSecondPos, gI_BeamSprite, 0, 0, 0, gF_BeamLife, gF_BeamWidth, gF_BeamWidth, 10, 0.0, color, 0);
	TE_SendToAll();
}

void DrawSpectrumTrail(int client, int stepsize)
{
	if(gB_RedToYellow[client])
	{
		gB_MagentaToRed[client] = false;
		gI_CycleColor[client][0] = 255; gI_CycleColor[client][1] += stepsize; gI_CycleColor[client][2] = 0;
		
		if(gI_CycleColor[client][0] >= 255 && gI_CycleColor[client][1] >= 255 && gI_CycleColor[client][2] <= 0)
			gB_YellowToGreen[client] = true;
	}
	
	if(gB_YellowToGreen[client])
	{
		gB_RedToYellow[client] = false;
		gI_CycleColor[client][0] -= stepsize; gI_CycleColor[client][1] = 255; gI_CycleColor[client][2] = 0;
		
		if(gI_CycleColor[client][0] <= 0 && gI_CycleColor[client][1] >= 255 && gI_CycleColor[client][2] <= 0)
			gB_GreenToCyan[client] = true;
	}
	
	if(gB_GreenToCyan[client])
	{
		gB_YellowToGreen[client] = false;
		gI_CycleColor[client][0] = 0; gI_CycleColor[client][1] = 255; gI_CycleColor[client][2] += stepsize;
		
		if(gI_CycleColor[client][0] <= 0 && gI_CycleColor[client][1] >= 255 && gI_CycleColor[client][2] >= 255)
			gB_CyanToBlue[client] = true;
	}
	
	if(gB_CyanToBlue[client])
	{
		gB_GreenToCyan[client] = false;
		gI_CycleColor[client][0] = 0; gI_CycleColor[client][1] -= stepsize; gI_CycleColor[client][2] = 255;
		
		if(gI_CycleColor[client][0] <= 0 && gI_CycleColor[client][1] <= 0 && gI_CycleColor[client][2] >= 255)
			gB_BlueToMagenta[client] = true;
	}
	
	if(gB_BlueToMagenta[client])
	{
		gB_CyanToBlue[client] = false;
		gI_CycleColor[client][0] += stepsize; gI_CycleColor[client][1] = 0; gI_CycleColor[client][2] = 255;
		
		if(gI_CycleColor[client][0] >= 255 && gI_CycleColor[client][1] <= 0 && gI_CycleColor[client][2] >= 255)
			gB_MagentaToRed[client] = true;
	}
	
	if(gB_MagentaToRed[client])
	{
		gB_BlueToMagenta[client] = false;
		
		gI_CycleColor[client][0] = 255; gI_CycleColor[client][1] = 0; gI_CycleColor[client][2] -= stepsize;
		
		if(gI_CycleColor[client][0] >= 255 && gI_CycleColor[client][1] <= 0 && gI_CycleColor[client][2] <= 0)
			gB_RedToYellow[client] = true;
	}
}

void DrawVelocityTrail(int client, float currentspeed)
{
	int stepsize;
	
	if(currentspeed <= 255.0)
	{
		gI_CycleColor[client][0] = 0; gI_CycleColor[client][1] = 0; gI_CycleColor[client][2] = 255;
	}
	else if(currentspeed > 255.0 && currentspeed <= 510.0)
	{
		stepsize = RoundToFloor(currentspeed) - 255;
		gI_CycleColor[client][0] = 0; gI_CycleColor[client][1] = stepsize; gI_CycleColor[client][2] = 255;
	}
	else if(currentspeed > 510.0 && currentspeed <= 765.0)
	{
		stepsize = RoundToFloor(-currentspeed) + 510;
		gI_CycleColor[client][0] = 0; gI_CycleColor[client][1] = 255; gI_CycleColor[client][2] = stepsize;
	}
	else if(currentspeed > 765.0 && currentspeed <= 1020.0)
	{
		stepsize = RoundToFloor(currentspeed) - 765;
		gI_CycleColor[client][0] = stepsize; gI_CycleColor[client][1] = 255; gI_CycleColor[client][2] = 0;
	}
	else if(currentspeed > 1020.0 && currentspeed <= 1275.0)
	{
		stepsize = RoundToFloor(-currentspeed) + 1020;
		gI_CycleColor[client][0] = 255; gI_CycleColor[client][1] = stepsize; gI_CycleColor[client][2] = 0;
	}
	else if(currentspeed > 1275.0 && currentspeed <= 1530.0)
	{
		stepsize = RoundToFloor(currentspeed) - 1275;
		gI_CycleColor[client][0] = 255; gI_CycleColor[client][1] = 0; gI_CycleColor[client][2] = stepsize;
	}
	else if(currentspeed > 1530.0 && currentspeed <= 1655.0)
	{
		stepsize = RoundToFloor(-currentspeed) + 1530;
		gI_CycleColor[client][0] = stepsize; gI_CycleColor[client][1] = 0; gI_CycleColor[client][2] = 255;
	}
	else
	{
		gI_CycleColor[client][0] = 125; gI_CycleColor[client][1] = 0; gI_CycleColor[client][2] = 255;
	}
}

/* Don't draw the trail after touching trigger_teleport */

public int StartTouchTrigger(const char[] output, int entity, int client, float delay)
{
	if(client < 1 || client > MaxClients)
	{
		return;
	}
	
	if(!gB_PluginEnabled || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}
	
	gB_StopPlugin[client] = true;
}

public int EndTouchTrigger(const char[] output, int entity, int client, float delay)
{
	if(client < 1 || client > MaxClients)
	{
		return;
	}
	
	if(!gB_PluginEnabled || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}
	
	CreateTimer(0.1, ResumePlugin, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action ResumePlugin(Handle timer, int data)
{
	int client = GetClientFromSerial(data);
	gB_StopPlugin[client] = false;
	return Plugin_Stop;
}

stock bool IsValidClient(int client, bool nobots = true)
{
	return (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client)
			&& !IsClientSourceTV(client) && (nobots || !IsFakeClient(client)));
}
