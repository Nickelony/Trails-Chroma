////////////////////////////////
// Change this to your needs and recompile.

// Chat prefix:
#define CHAT_PREFIX "{bluegrey}[TC]{default}"

// Trail opacity:
#define TRAIL_OPACITY 128

////////////////////////////////

#include <sourcemod>
#include <sdktools>
#include <multicolors>

#pragma newdecls required
#pragma semicolon 1

/* CVars */

ConVar gCV_PluginEnabled = null;
ConVar gCV_AdminsOnly = null;
ConVar gCV_BeamLife = null;
ConVar gCV_BeamWidth = null;

/* Cached CVars */

bool gB_PluginEnabled = true;
bool gB_AdminsOnly = true;
float gF_BeamLife = 1.5;
float gF_BeamWidth = 1.5;

/* Global variables */

int gI_BeamSprite;
int gI_SelectedColor[MAXPLAYERS + 1];

int gI_CycleColor[MAXPLAYERS + 1][4];
bool gB_RedToYellow[MAXPLAYERS + 1];
bool gB_YellowToGreen[MAXPLAYERS + 1];
bool gB_GreenToCyan[MAXPLAYERS + 1];
bool gB_CyanToBlue[MAXPLAYERS + 1];
bool gB_BlueToMagenta[MAXPLAYERS + 1];
bool gB_MagentaToRed[MAXPLAYERS + 1];

bool gB_TouchingTrigger[MAXPLAYERS + 1];
float gF_LastPosition[MAXPLAYERS + 1][3];

public Plugin myinfo = 
{
	name = "Trails Chroma",
	author = "Nickelony",
	description = "Adds colorful player trails with special effects.",
	version = "1.0",
	url = "http://steamcommunity.com/id/nickelony/"
}

public void OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawnEvent);
	
	HookEntityOutput("trigger_teleport", "OnStartTouch", StartTouchTrigger);
	HookEntityOutput("trigger_teleport", "OnEndTouch", EndTouchTrigger);
	
	RegConsoleCmd("sm_trail", Command_Trail, "Opens the 'Trail Color Selection' menu.");
	RegConsoleCmd("sm_trails", Command_Trail, "Opens the 'Trail Color Selection' menu.");
	
	gCV_PluginEnabled = CreateConVar("sm_trails_enable", "1", "Enable or Disable all features of the plugin.", 0, true, 0.0, true, 1.0);
	gCV_AdminsOnly = CreateConVar("sm_trails_adminsonly", "1", "Enable trails for admins only.", 0, true, 0.0, true, 1.0);
	gCV_BeamLife = CreateConVar("sm_trails_life", "1.5", "Time duration of the trails.", FCVAR_NOTIFY, true, 0.0);
	gCV_BeamWidth = CreateConVar("sm_trails_width", "1.5", "Width of the trail beams.", FCVAR_NOTIFY, true, 0.0);
	
	gCV_PluginEnabled.AddChangeHook(OnConVarChanged);
	gCV_AdminsOnly.AddChangeHook(OnConVarChanged);
	gCV_BeamLife.AddChangeHook(OnConVarChanged);
	gCV_BeamWidth.AddChangeHook(OnConVarChanged);
	
	AutoExecConfig();
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	gB_PluginEnabled = gCV_PluginEnabled.BoolValue;
	gB_AdminsOnly = gCV_AdminsOnly.BoolValue;
	gF_BeamLife = gCV_BeamLife.FloatValue;
	gF_BeamWidth = gCV_BeamWidth.FloatValue;
}

public void OnMapStart()
{
	if(!gB_PluginEnabled)
	{
		return;
	}
	
	HookEntityOutput("trigger_teleport", "OnStartTouch", StartTouchTrigger);
	HookEntityOutput("trigger_teleport", "OnEndTouch", EndTouchTrigger);
	
	gI_BeamSprite = PrecacheModel("materials/trails/beam_01.vmt", true);
	
	AddFileToDownloadsTable("materials/trails/beam_01.vmt");
	AddFileToDownloadsTable("materials/trails/beam_01.vtf");
}

public void PlayerSpawnEvent(Event event, const char[] name, bool dontBroadcast)
{
	if(!gB_PluginEnabled)
	{
		return;
	}
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	gI_SelectedColor[client] = 0;
	gB_TouchingTrigger[client] = false;
}

public Action Command_Trail(int client, int args)
{
	if(!gB_PluginEnabled || IsFakeClient(client))
	{
		return Plugin_Handled;
	}
	
	if(!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s You must be alive to choose a trail!", CHAT_PREFIX);
		return Plugin_Handled;
	}
	
	if(gB_AdminsOnly && !CheckCommandAccess(client, "sm_trails_override", ADMFLAG_RESERVATION))
	{
		CPrintToChat(client, "%s Only admins may use this command.", CHAT_PREFIX);
		return Plugin_Handled;
	}
	
	Menu menu = new Menu(Menu_Handler);
	menu.SetTitle("Choose Trail Color:");
	
	menu.AddItem("0", "NONE", (gI_SelectedColor[client] == 0)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("1", "Red", (gI_SelectedColor[client] == 1)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("2", "Orange", (gI_SelectedColor[client] == 2)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("3", "Yellow", (gI_SelectedColor[client] == 3)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("4", "Lime", (gI_SelectedColor[client] == 4)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("5", "Green", (gI_SelectedColor[client] == 5)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("6", "Emerald", (gI_SelectedColor[client] == 6)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("7", "Cyan", (gI_SelectedColor[client] == 7)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("8", "Light Blue", (gI_SelectedColor[client] == 8)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("9", "Blue", (gI_SelectedColor[client] == 9)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("10", "Purple", (gI_SelectedColor[client] == 10)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("11", "Magenta", (gI_SelectedColor[client] == 11)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("12", "Pink", (gI_SelectedColor[client] == 12)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("13", "White", (gI_SelectedColor[client] == 13)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	
	menu.AddItem("x", "", ITEMDRAW_SPACER);
	menu.AddItem("14", "Velocity", (gI_SelectedColor[client] == 14)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("15", "Spectrum", (gI_SelectedColor[client] == 15)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	menu.AddItem("16", "Wave", (gI_SelectedColor[client] == 16)? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	
	menu.ExitButton = true;
	menu.Display(client, 20);
	
	return Plugin_Handled;
}

public int Menu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char[] info = new char[16];
		menu.GetItem(param2, info, 16);
		
		MenuSelection(param1, info);
	}
	
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

void MenuSelection(int client, char[] info)
{
	int choice;
	char[] color = new char[32];
	
	if(StrEqual(info, "1"))
	{
		choice = 1;
		FormatEx(color, 32, "{darkred}RED{default}");
		PrintTrailMessage(client, choice, color);
		gI_SelectedColor[client] = choice;
	}
	
	else if(StrEqual(info, "2"))
	{
		choice = 2;
		FormatEx(color, 32, "{orange}ORANGE{default}");
		PrintTrailMessage(client, choice, color);
		gI_SelectedColor[client] = choice;
	}
	
	else if(StrEqual(info, "3"))
	{
		choice = 3;
		FormatEx(color, 32, "{yellow}YELLOW{default}");
		PrintTrailMessage(client, choice, color);
		gI_SelectedColor[client] = choice;
	}
	
	else if(StrEqual(info, "4"))
	{
		choice = 4;
		FormatEx(color, 32, "{lime}LIME{default}");
		PrintTrailMessage(client, choice, color);
		gI_SelectedColor[client] = choice;
	}
	
	else if(StrEqual(info, "5"))
	{
		choice = 5;
		FormatEx(color, 32, "{green}GREEN{default}");
		PrintTrailMessage(client, choice, color);
		gI_SelectedColor[client] = choice;
	}
	
	else if(StrEqual(info, "6"))
	{
		choice = 6;
		FormatEx(color, 32, "{olive}EMERALD{default}");
		PrintTrailMessage(client, choice, color);
		gI_SelectedColor[client] = choice;
	}
	
	else if(StrEqual(info, "7"))
	{
		choice = 7;
		FormatEx(color, 32, "{blue}CYAN{default}");
		PrintTrailMessage(client, choice, color);
		gI_SelectedColor[client] = choice;
	}
	
	else if(StrEqual(info, "8"))
	{
		choice = 8;
		FormatEx(color, 32, "{lightblue}LIGHT BLUE{default}");
		PrintTrailMessage(client, choice, color);
		gI_SelectedColor[client] = choice;
	}
	
	else if(StrEqual(info, "9"))
	{
		choice = 9;
		FormatEx(color, 32, "{darkblue}BLUE{default}");
		PrintTrailMessage(client, choice, color);
		gI_SelectedColor[client] = choice;
	}
	
	else if(StrEqual(info, "10"))
	{
		choice = 10;
		FormatEx(color, 32, "{purple}PURPLE{default}");
		PrintTrailMessage(client, choice, color);
		gI_SelectedColor[client] = choice;
	}
	
	else if(StrEqual(info, "11"))
	{
		choice = 11;
		FormatEx(color, 32, "{orchid}MAGENTA{default}");
		PrintTrailMessage(client, choice, color);
		gI_SelectedColor[client] = choice;
	}
	
	else if(StrEqual(info, "12"))
	{
		choice = 12;
		FormatEx(color, 32, "{lightred}PINK{default}");
		PrintTrailMessage(client, choice, color);
		gI_SelectedColor[client] = choice;
	}
	
	else if(StrEqual(info, "13"))
	{
		choice = 13;
		FormatEx(color, 32, "{grey2}WHITE{default}");
		PrintTrailMessage(client, choice, color);
		gI_SelectedColor[client] = choice;
	}
	
	else if(StrEqual(info, "14"))
	{
		choice = 14;
		FormatEx(color, 32, "{darkred}Velocity {green}Trail");
		PrintSpecialMessage(client, choice, color);
		gI_SelectedColor[client] = choice;
	}
	
	else if(StrEqual(info, "15"))
	{
		choice = 15;
		FormatEx(color, 32, "{darkred}Spectrum {green}Cycle");
		PrintSpecialMessage(client, choice, color);
		
		gB_RedToYellow[client] = true;
		gI_SelectedColor[client] = choice;
	}
	
	else if(StrEqual(info, "16"))
	{
		choice = 16;
		FormatEx(color, 32, "{darkred}Wave {green}Trail");
		PrintSpecialMessage(client, choice, color);
		
		gB_RedToYellow[client] = true;
		gI_SelectedColor[client] = choice;
	}
	
	else
	{
		if(gI_SelectedColor[client] != 0)
		{
			CPrintToChat(client, "%s Your trail is now {darkred}DISABLED{default}.", CHAT_PREFIX);
		}
		
		gI_SelectedColor[client] = 0;
	}
}

void PrintTrailMessage(int client, int choice, char[] color)
{
	if(gI_SelectedColor[client] == 0)
	{
		CPrintToChat(client, "%s Your trail is now {green}ENABLED{default}.", CHAT_PREFIX);
		CPrintToChat(client, "{default}Your beam color is %s.", color);
	}
	
	if(gI_SelectedColor[client] != 0 && gI_SelectedColor[client] != choice)
	{
		CPrintToChat(client, "%s Your trail color is now %s.", CHAT_PREFIX, color);
	}
}

void PrintSpecialMessage(int client, int choice, char[] color)
{
	if(gI_SelectedColor[client] == 0)
	{
		CPrintToChat(client, "%s Your trail is now {green}ENABLED{default}.", CHAT_PREFIX);
		CPrintToChat(client, "%s {darkblue}ENABLED{default}.", color);
	}
	
	if(gI_SelectedColor[client] != 0 && gI_SelectedColor[client] != choice)
	{
		CPrintToChat(client, "%s %s {darkblue}ENABLED{default}.", CHAT_PREFIX, color);
	}
}

public Action OnPlayerRunCmd(int client)
{
	float origin[3];
	GetClientAbsOrigin(client, origin);
	
	CreatePlayerTrail(client, origin);
	gF_LastPosition[client] = origin;
}

void CreatePlayerTrail(int client, float origin[3])
{
	if(!gB_PluginEnabled || !IsPlayerAlive(client) || gB_TouchingTrigger[client])
	{
		return;
	}
	
	if(gB_AdminsOnly && !CheckCommandAccess(client, "sm_trails_override", ADMFLAG_RESERVATION))
	{
		return;
	}
	
	float pos1[3];
	pos1[0] = origin[0];
	pos1[1] = origin[1];
	pos1[2] = origin[2] + 5.0;
	
	float pos2[3];
	pos2[0] = gF_LastPosition[client][0];
	pos2[1] = gF_LastPosition[client][1];
	pos2[2] = gF_LastPosition[client][2] + 5.0;
	
	int rgba[4];
	rgba[3] = TRAIL_OPACITY;
	
	int stepsize;
	
	switch(gI_SelectedColor[client])
	{
		case 1: // Red trail
		{
			rgba[0] = 255; rgba[1] = 0; rgba[2] = 0;
		}
		
		case 2: // Orange trail
		{
			rgba[0] = 255; rgba[1] = 128; rgba[2] = 0;
		}
		
		case 3: // Yellow trail
		{
			rgba[0] = 255; rgba[1] = 255; rgba[2] = 0;
		}
		
		case 4: // Lime trail
		{
			rgba[0] = 128; rgba[1] = 255; rgba[2] = 0;
		}
		
		case 5: // Green trail
		{
			rgba[0] = 0; rgba[1] = 255; rgba[2] = 0;
		}
		
		case 6: // Emerald trail
		{
			rgba[0] = 0; rgba[1] = 255; rgba[2] = 128;
		}
		
		case 7: // Cyan trail
		{
			rgba[0] = 0; rgba[1] = 255; rgba[2] = 255;
		}
		
		case 8: // Light blue trail
		{
			rgba[0] = 0; rgba[1] = 128; rgba[2] = 255;
		}
		
		case 9: // Blue trail
		{
			rgba[0] = 0; rgba[1] = 0; rgba[2] = 255;
		}
		
		case 10: // Purple trail
		{
			rgba[0] = 128; rgba[1] = 0; rgba[2] = 255;
		}
		
		case 11: // Magenta trail
		{
			rgba[0] = 255; rgba[1] = 0; rgba[2] = 255;
		}
		
		case 12: // Pink trail
		{
			rgba[0] = 255; rgba[1] = 64; rgba[2] = 128;
		}
		
		case 13: // White trail
		{
			rgba[0] = 255; rgba[1] = 255; rgba[2] = 255;
		}
		
		case 14: // Velocity trail
		{
			float fAbsVelocity[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);
			float fCurrentSpeed = SquareRoot(Pow(fAbsVelocity[0], 2.0) + Pow(fAbsVelocity[1], 2.0));
			
			DrawVelocityTrail(client, fCurrentSpeed);
			
			rgba[0] = gI_CycleColor[client][0]; rgba[1] = gI_CycleColor[client][1]; rgba[2] = gI_CycleColor[client][2];
		}
		
		case 15: // Spectrum trail
		{
			stepsize = 1;
			DrawSpectrumTrail(client, stepsize);
			
			rgba[0] = gI_CycleColor[client][0]; rgba[1] = gI_CycleColor[client][1]; rgba[2] = gI_CycleColor[client][2];
		}
		
		case 16: // Wave trail
		{
			stepsize = 15;
			DrawSpectrumTrail(client, stepsize);
			
			rgba[0] = gI_CycleColor[client][0]; rgba[1] = gI_CycleColor[client][1]; rgba[2] = gI_CycleColor[client][2];
		}
		
		default: // None
		{
			return;
		}
	}
	
	TE_SetupBeamPoints(pos1, pos2, gI_BeamSprite, 0, 0, 0, gF_BeamLife, gF_BeamWidth, gF_BeamWidth, 10, 0.0, rgba, 0);
	TE_SendToAll(0.0);
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

void DrawVelocityTrail(int client, float fCurrentSpeed)
{
	int stepsize;
	
	if(fCurrentSpeed <= 255.0)
	{
		gI_CycleColor[client][0] = 0; gI_CycleColor[client][1] = 0; gI_CycleColor[client][2] = 255;
	}
	
	else if(fCurrentSpeed > 255.0 && fCurrentSpeed <= 510.0)
	{
		stepsize = RoundToFloor(fCurrentSpeed) - 255;
		gI_CycleColor[client][0] = 0; gI_CycleColor[client][1] = stepsize; gI_CycleColor[client][2] = 255;
	}
	
	else if(fCurrentSpeed > 510.0 && fCurrentSpeed <= 765.0)
	{
		stepsize = RoundToFloor(-fCurrentSpeed) + 510;
		gI_CycleColor[client][0] = 0; gI_CycleColor[client][1] = 255; gI_CycleColor[client][2] = stepsize;
	}
	
	else if(fCurrentSpeed > 765.0 && fCurrentSpeed <= 1020.0)
	{
		stepsize = RoundToFloor(fCurrentSpeed) - 765;
		gI_CycleColor[client][0] = stepsize; gI_CycleColor[client][1] = 255; gI_CycleColor[client][2] = 0;
	}
	
	else if(fCurrentSpeed > 1020.0 && fCurrentSpeed <= 1275.0)
	{
		stepsize = RoundToFloor(-fCurrentSpeed) + 1020;
		gI_CycleColor[client][0] = 255; gI_CycleColor[client][1] = stepsize; gI_CycleColor[client][2] = 0;
	}
	
	else if(fCurrentSpeed > 1275.0 && fCurrentSpeed <= 1530.0)
	{
		stepsize = RoundToFloor(fCurrentSpeed) - 1275;
		gI_CycleColor[client][0] = 255; gI_CycleColor[client][1] = 0; gI_CycleColor[client][2] = stepsize;
	}
	
	else if(fCurrentSpeed > 1530.0 && fCurrentSpeed <= 1660.0)
	{
		stepsize = RoundToFloor(-fCurrentSpeed) + 1530;
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
	
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}
	
	gB_TouchingTrigger[client] = true;
}

public int EndTouchTrigger(const char[] output, int entity, int client, float delay)
{
	if(client < 1 || client > MaxClients)
	{
		return;
	}
	
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}
	
	CreateTimer(0.1, BlockOffTrigger, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action BlockOffTrigger(Handle timer, any client)
{
	gB_TouchingTrigger[client] = false;
	return Plugin_Stop;
}
