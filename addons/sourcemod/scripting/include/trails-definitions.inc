/*
 * Trails Chroma - trails-definitions.inc file
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

#define TRAILS_NONE -1

enum ColorType
{
	ColorType_SolidColor,
	ColorType_SpectrumCycle,
	ColorType_VelocityBased,
	MAX_COLOR_TYPES
}

enum SpectrumCycleMode
{
	SpectrumCycleMode_Off,
	SpectrumCycleMode_RedToYellow,
	SpectrumCycleMode_YellowToGreen,
	SpectrumCycleMode_GreenToCyan,
	SpectrumCycleMode_CyanToBlue,
	SpectrumCycleMode_BlueToMagenta,
	SpectrumCycleMode_MagentaToRed
}

enum BreathingMode
{
	BreathingMode_Off,
	BreathingMode_Inhale,
	BreathingMode_Exhale
}

enum BowMode
{
	BowMode_Off,
	BowMode_Expand,
	BowMode_Shrink,
}

enum struct TrailColor
{
	int R;
	int G;
	int B;
	int A;
}

enum struct Trail
{
	/* Basic parameters */

	char Name[255];
	ColorType ColorType;

	TrailColor Color;

	float Width;
	float Duration;

	bool IsCheap;
	bool IsAdminsOnly;

	/* Special effect parameters */

	int SpectrumCycleSpeed;
	int BreathingSpeed;
	float BowTransformSpeed;

	int BreathingMinAlpha;
	int BreathingMaxAlpha;

	float BowMinWidth;
	float BowMaxWidth;
}
