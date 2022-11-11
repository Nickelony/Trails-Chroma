/*
 * Trails Chroma - configs.inc file
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

#define TRAILS_CONFIG_PATH "configs/trails-list.cfg"
#define TRAILS_MAX_COUNT 255

Trail gT_Trails[TRAILS_MAX_COUNT]; // Trails fetched from the config file
int gI_TrailCount;

bool LoadTrailsConfig()
{
	char configPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configPath, PLATFORM_MAX_PATH, TRAILS_CONFIG_PATH);
	KeyValues kv = new KeyValues("trails-list");

	if (!kv.ImportFromFile(configPath) || !kv.GotoFirstSubKey())
	{
		delete kv;
		return false;
	}

	int i = 0;

	do
	{
		/* Basic parameters */

		kv.GetString("name", gT_Trails[i].Name, 255, "<MISSING TRAIL NAME>");

		gT_Trails[i].ColorType = view_as<ColorType>(kv.GetNum("color_type", 0));

		if (gT_Trails[i].ColorType < ColorType_SolidColor && gT_Trails[i].ColorType >= MAX_COLOR_TYPES)
			gT_Trails[i].ColorType = ColorType_SolidColor;

		gT_Trails[i].Color.R = kv.GetNum("red", 0);
		gT_Trails[i].Color.G = kv.GetNum("green", 0);
		gT_Trails[i].Color.B = kv.GetNum("blue", 0);
		gT_Trails[i].Color.A = kv.GetNum("alpha", 255);

		NormalizeColor(gT_Trails[i].Color);

		gT_Trails[i].Width = kv.GetFloat("width", 1.5);

		if (gT_Trails[i].Width < 0.0)
			gT_Trails[i].Width = 0.0;

		gT_Trails[i].Duration = kv.GetFloat("duration", 1.5);

		if (gT_Trails[i].Duration < 0.0)
			gT_Trails[i].Duration = 0.0;

		gT_Trails[i].IsCheap = kv.GetNum("cheap", 0) > 0;
		gT_Trails[i].IsAdminsOnly = kv.GetNum("admins_only", 0) > 0;

		/* Special effect parameters */

		gT_Trails[i].SpectrumCycleSpeed = kv.GetNum("spectrum_cycle_speed", 1);
		NormalizeChannel(gT_Trails[i].SpectrumCycleSpeed);

		gT_Trails[i].BreathingSpeed = kv.GetNum("breathing_speed", 1);
		NormalizeChannel(gT_Trails[i].BreathingSpeed);

		gT_Trails[i].BowTransformSpeed = kv.GetFloat("bow_transform_speed", 0.1);

		if (gT_Trails[i].BowTransformSpeed < 0.01)
			gT_Trails[i].BowTransformSpeed = 0.01;

		gT_Trails[i].BreathingMinAlpha = kv.GetNum("breathing_min_alpha", gT_Trails[i].Color.A);
		NormalizeChannel(gT_Trails[i].BreathingMinAlpha);

		gT_Trails[i].BreathingMaxAlpha = kv.GetNum("breathing_max_alpha", gT_Trails[i].Color.A);
		NormalizeChannel(gT_Trails[i].BreathingMaxAlpha);

		if (gT_Trails[i].BreathingMinAlpha > gT_Trails[i].BreathingMaxAlpha) // Min > Max
			gT_Trails[i].BreathingMaxAlpha = gT_Trails[i].BreathingMinAlpha; // Effect will be disabled

		gT_Trails[i].BowMinWidth = kv.GetFloat("bow_min_width", gT_Trails[i].Width);

		if (gT_Trails[i].BowMinWidth < 0.0)
			gT_Trails[i].BowMinWidth = 0.0;

		gT_Trails[i].BowMaxWidth = kv.GetFloat("bow_max_width", gT_Trails[i].Width);

		if (gT_Trails[i].BowMinWidth > gT_Trails[i].BowMaxWidth) // Min > Max
			gT_Trails[i].BowMaxWidth = gT_Trails[i].BowMinWidth; // Effect will be disabled

		i++;
	}
	while (kv.GotoNextKey() && i < TRAILS_MAX_COUNT);

	delete kv;
	gI_TrailCount = i;
	return true;
}
