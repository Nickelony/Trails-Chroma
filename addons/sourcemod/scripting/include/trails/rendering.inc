/*
 * Trails Chroma - rendering.inc file
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

#define TRAILS_BEAM_SPRITE_VMT "materials/trails/beam_01.vmt"
#define TRAILS_BEAM_SPRITE_VTF "materials/trails/beam_01.vtf"
#define TRAILS_GROUND_OFFSET 5.0

int gI_BeamSprite; // Model index of the beam sprite

SpectrumCycleMode gM_SpectrumCycleMode[MAXPLAYERS + 1] = { SpectrumCycleMode_Off, ... }; // Used to determine which color shift cycle is currently being processed (e.g. Red -> Yellow, Yellow -> Green etc.)
BreathingMode gM_BreathingMode[MAXPLAYERS + 1] = { BreathingMode_Off, ... }; // Used to determine whether the trail is fading in (inhale) or fading out (exhale) in the current cycle
BowMode gM_BowMode[MAXPLAYERS + 1] = { BowMode_Off, ... }; // Used to determine whether the trail is expanding or shrinking in the current cycle

float gF_LastPosition[MAXPLAYERS + 1][3]; // Used to draw the beam between the player's last cached position and their current position
bool gB_IsHidingTrails[MAXPLAYERS + 1];
bool gB_IsOddFrame[MAXPLAYERS + 1]; // Used to skip a frame for cheap trails

TrailColor gC_DynamicColor[MAXPLAYERS + 1]; // Used to store RGBA values for special effects (such as Spectrum Cycle)
int gI_DynamicAlpha[MAXPLAYERS + 1]; // Used for breathing trails
float gF_DynamicWidth[MAXPLAYERS + 1]; // Used for bow trails

void DrawCheapTrail(int client, Trail trail) // Skips 1 frame while rendering. That's 50% less sprites to render.
{
	float playerOrigin[3];
	GetClientAbsOrigin(client, playerOrigin);

	if (gB_IsOddFrame[client]) // First frame: Cache origin point
	{
		CopyVector(gF_LastPosition[client], playerOrigin);
		gB_IsOddFrame[client] = false;
	}
	else // Second frame: Render beam
	{
		gB_IsOddFrame[client] = true;
		CreatePlayerTrail(client, trail, playerOrigin, gF_LastPosition[client]);
	}
}

void DrawExpensiveTrail(int client, Trail trail)
{
	float playerOrigin[3];
	GetClientAbsOrigin(client, playerOrigin);

	CreatePlayerTrail(client, trail, playerOrigin, gF_LastPosition[client]);
	gF_LastPosition[client] = playerOrigin;
}

void CreatePlayerTrail(int client, Trail trail, float playerOrigin[3], float secondPoint[3])
{
	bool hasClientTeleported = GetVectorDistance(playerOrigin, secondPoint, false) > 50.0;

	if (!gCV_PluginEnabled.BoolValue || gI_SelectedTrail[client] == TRAILS_NONE || !IsPlayerAlive(client) || hasClientTeleported)
		return;

	bool noPermissions = gCV_ForceAdminsOnly.BoolValue && !CheckCommandAccess(client, "sm_trails_override", ADMFLAG_RESERVATION);

	if (noPermissions)
	{
		RemoveTrail(client);
		return;
	}

	if (gEV_Type == Engine_TF2 && TF2_IsPlayerInCondition(client, TFCond_Cloaked)) // If the Spy is invisible
		return;

	gC_DynamicColor[client].A = trail.Color.A;

	float start[3];
	CopyVector(start, playerOrigin);
	start[2] += TRAILS_GROUND_OFFSET; // Lift trail start slightly above ground

	float end[3];
	CopyVector(end, secondPoint);
	end[2] += TRAILS_GROUND_OFFSET; // Lift trail end slightly above ground

	TrailColor cColor;
	GetClientSpecificColorFromTrail(client, trail, cColor);

	int iColor[4];
	ColorToInt(iColor, cColor);

	float width;
	GetClientSpecificWidthFromTrail(client, trail, width);

	TE_SetupBeamPoints(start, end, gI_BeamSprite, 0, 0, 0, trail.Duration, width, width, 10, 0.0, iColor, 0);
	SendTempEntity(client);

#if defined DEBUG
	PrintHintText(client, "R: %d\nG: %d\nB: %d\nA: %d\nW: %.3f", cColor.R, cColor.G, cColor.B, cColor.A, width);
#endif
}

void GetClientSpecificWidthFromTrail(int client, Trail trail, float& buffer)
{
	if (IsBowTrail(trail))
	{
		DoBowResizeCycle(gF_DynamicWidth[client], gM_BowMode[client], trail.BowMinWidth, trail.BowMaxWidth, trail.BowTransformSpeed);
		buffer = gF_DynamicWidth[client];
	}
	else
		buffer = trail.Width;
}

void GetClientSpecificColorFromTrail(int client, Trail trail, TrailColor buffer)
{
	switch (trail.ColorType)
	{
		case ColorType_SpectrumCycle:
		{
			DoSpectrumCycle(gC_DynamicColor[client], gM_SpectrumCycleMode[client], trail.SpectrumCycleSpeed);
			CopyColor(buffer, gC_DynamicColor[client]);
		}
		case ColorType_VelocityBased:
		{
			float absVelocity[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", absVelocity);
			float playerSpeed = SquareRoot(Pow(absVelocity[0], 2.0) + Pow(absVelocity[1], 2.0));

			SpeedToColor(buffer, playerSpeed);
			buffer.A = trail.Color.A;
		}
		default:
			CopyColor(buffer, trail.Color);
	}

	if (IsBreathingTrail(trail))
	{
		DoColorBreathing(gI_DynamicAlpha[client], gM_BreathingMode[client], trail.BreathingMinAlpha, trail.BreathingMaxAlpha, trail.BreathingSpeed);
		buffer.A = gI_DynamicAlpha[client];
	}
}

void SendTempEntity(int client)
{
	int trailRecievers[MAXPLAYERS + 1];
	int trailRecieversCount = GetTrailRecievers(trailRecievers);

	if (gB_IsHidingTrails[client]) // If the player is hiding other players' trails
	{
		trailRecievers[trailRecieversCount] = client; // Add the current client to the array so they can see their own trail
		TE_Send(trailRecievers, trailRecieversCount + 1); // The client will send the trail to everyone but won't recieve any other trails
	}
	else
		TE_Send(trailRecievers, trailRecieversCount); // The client will send the trail to everyone and will revieve other players' trails as well
}

int GetTrailRecievers(int trailRecieversBuffer[MAXPLAYERS + 1])
{
	int trailRecieversCount = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !gB_IsHidingTrails[i])
			trailRecieversBuffer[trailRecieversCount++] = i;
	}

	return trailRecieversCount;
}

void UpdateSpecialEffectModes(int client, Trail trail)
{
	if (trail.ColorType == ColorType_SpectrumCycle)
	{
		gC_DynamicColor[client].R = gC_DynamicColor[client].G = gC_DynamicColor[client].B = 0;
		gM_SpectrumCycleMode[client] = SpectrumCycleMode_RedToYellow;
	}
	else
		gM_SpectrumCycleMode[client] = SpectrumCycleMode_Off;

	if (IsBreathingTrail(trail))
	{
		gC_DynamicColor[client].A = trail.BreathingMinAlpha;
		gM_BreathingMode[client] = BreathingMode_Inhale;
	}
	else
		gM_BreathingMode[client] = BreathingMode_Off;

	if (IsBowTrail(trail))
	{
		gF_DynamicWidth[client] = trail.BowMinWidth;
		gM_BowMode[client] = BowMode_Expand;
	}
	else
		gM_BowMode[client] = BowMode_Off;
}

void DisableAllSpecialEffects(int client)
{
	gM_SpectrumCycleMode[client] = SpectrumCycleMode_Off;
	gM_BreathingMode[client] = BreathingMode_Off;
	gM_BowMode[client] = BowMode_Off;
}
