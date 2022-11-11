/*
 * Trails Chroma - trails-utils.inc file
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

stock bool IsValidClient(int client)
{
	return 1 <= client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}

stock bool IsNullStringOrWhiteSpace(const char[] str)
{
	int strLength = strlen(str);

	char[] temp = new char[strLength];
	strcopy(temp, strLength, str);

	TrimString(temp);

	return IsNullStringOrEmpty(temp);
}

stock bool IsNullStringOrEmpty(const char[] str)
{
	return str[0] == 0;
}

stock void CopyVector(float dest[3], float src[3])
{
	dest[0] = src[0];
	dest[1] = src[1];
	dest[2] = src[2];
}

stock void CopyColor(TrailColor dest, TrailColor src, bool ignoreAlpha = false)
{
	dest.R = src.R;
	dest.G = src.G;
	dest.B = src.B;

	if (!ignoreAlpha)
		dest.A = src.A;
}

stock void NormalizeColor(TrailColor buffer)
{
	NormalizeChannel(buffer.R);
	NormalizeChannel(buffer.G);
	NormalizeChannel(buffer.B);
	NormalizeChannel(buffer.A);
}

stock void NormalizeChannel(int& channel)
{
	if (channel < 0)
		channel = 0;
	else if (channel > 255)
		channel = 255;
}

stock void ColorToInt(int buffer[4], TrailColor color)
{
	buffer[0] = color.R;
	buffer[1] = color.G;
	buffer[2] = color.B;
	buffer[3] = color.A;
}

stock bool IsBreathingTrail(Trail trail)
{
	return trail.BreathingMinAlpha != trail.BreathingMaxAlpha;
}

stock bool IsBowTrail(Trail trail)
{
	return trail.BowMinWidth != trail.BowMaxWidth;
}
