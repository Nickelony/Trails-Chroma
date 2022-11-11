/*
 * Trails Chroma - trails-special-effects.inc file
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

stock void DoSpectrumCycle(TrailColor buffer, SpectrumCycleMode& mode, int stepSize = 1)
{
	switch (mode)
	{
		case SpectrumCycleMode_RedToYellow:
		{
			buffer.R = 255;
			buffer.G += stepSize;
			buffer.B = 0;

			if (buffer.R >= 255 && buffer.G >= 255 && buffer.B <= 0)
				mode = SpectrumCycleMode_YellowToGreen;
		}
		case SpectrumCycleMode_YellowToGreen:
		{
			buffer.R -= stepSize;
			buffer.G = 255;
			buffer.B = 0;

			if (buffer.R <= 0 && buffer.G >= 255 && buffer.B <= 0)
				mode = SpectrumCycleMode_GreenToCyan;
		}
		case SpectrumCycleMode_GreenToCyan:
		{
			buffer.R = 0;
			buffer.G = 255;
			buffer.B += stepSize;

			if (buffer.R <= 0 && buffer.G >= 255 && buffer.B >= 255)
				mode = SpectrumCycleMode_CyanToBlue;
		}
		case SpectrumCycleMode_CyanToBlue:
		{
			buffer.R = 0;
			buffer.G -= stepSize;
			buffer.B = 255;

			if (buffer.R <= 0 && buffer.G <= 0 && buffer.B >= 255)
				mode = SpectrumCycleMode_BlueToMagenta;
		}
		case SpectrumCycleMode_BlueToMagenta:
		{
			buffer.R += stepSize;
			buffer.G = 0;
			buffer.B = 255;

			if (buffer.R >= 255 && buffer.G <= 0 && buffer.B >= 255)
				mode = SpectrumCycleMode_MagentaToRed;
		}
		case SpectrumCycleMode_MagentaToRed:
		{
			buffer.R = 255;
			buffer.G = 0;
			buffer.B -= stepSize;

			if (buffer.R >= 255 && buffer.G <= 0 && buffer.B <= 0)
				mode = SpectrumCycleMode_RedToYellow;
		}
	}

	NormalizeColor(buffer);
}

stock void SpeedToColor(TrailColor buffer, float speed)
{
	const int fullStep = 255;

	if (speed <= fullStep) // Blue
	{
		buffer.R = 0;
		buffer.G = 0;
		buffer.B = 255;
	}
	else if (speed > fullStep && speed <= 2 * fullStep) // Blue to Cyan
	{
		buffer.R = 0;
		buffer.G = RoundToFloor(speed) - fullStep;
		buffer.B = 255;
	}
	else if (speed > 2 * fullStep && speed <= 3 * fullStep) // Cyan to Green
	{
		buffer.R = 0;
		buffer.G = 255;
		buffer.B = 255 - (RoundToFloor(speed) - 2 * fullStep);
	}
	else if (speed > 3 * fullStep && speed <= 4 * fullStep) // Green to Yellow
	{
		buffer.R = RoundToFloor(speed) - 3 * fullStep;
		buffer.G = 255;
		buffer.B = 0;
	}
	else if (speed > 4 * fullStep && speed <= 5 * fullStep) // Yellow to Red
	{
		buffer.R = 255;
		buffer.G = 255 - (RoundToFloor(speed) - 4 * fullStep);
		buffer.B = 0;
	}
	else if (speed > 5 * fullStep && speed <= 6 * fullStep) // Red to Magenta
	{
		buffer.R = 255;
		buffer.G = 0;
		buffer.B = RoundToFloor(speed) - 5 * fullStep;
	}
	else if (speed > 6 * fullStep && speed <= 6.5 * fullStep) // Magenta to Purple
	{
		buffer.R = 255 - (RoundToFloor(speed) - 6 * fullStep);
		buffer.G = 0;
		buffer.B = 255;
	}
	else if (speed > 6.5 * fullStep) // Purple
	{
		buffer.R = 128;
		buffer.G = 0;
		buffer.B = 255;
	}

	NormalizeColor(buffer);
}

stock void DoColorBreathing(int& alpha, BreathingMode& mode, int minAlpha, int maxAlpha, int stepSize = 1)
{
	switch (mode)
	{
		case BreathingMode_Inhale:
		{
			alpha += stepSize;

			if (alpha >= maxAlpha)
			{
				alpha = maxAlpha;
				mode = BreathingMode_Exhale;
			}
		}
		case BreathingMode_Exhale:
		{
			alpha -= stepSize;

			if (alpha <= minAlpha)
			{
				alpha = minAlpha;
				mode = BreathingMode_Inhale;
			}
		}
	}
}

stock void DoBowResizeCycle(float& buffer, BowMode& mode, float minWidth, float maxWidth, float stepSize = 0.1)
{
	switch (mode)
	{
		case BowMode_Expand:
		{
			buffer += stepSize;

			if (buffer >= maxWidth)
			{
				buffer = maxWidth;
				mode = BowMode_Shrink;
			}
		}
		case BowMode_Shrink:
		{
			buffer -= stepSize;

			if (buffer <= minWidth)
			{
				buffer = minWidth;
				mode = BowMode_Expand;
			}
		}
	}
}
