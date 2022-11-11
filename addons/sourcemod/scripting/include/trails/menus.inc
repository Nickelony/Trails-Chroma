/*
 * Trails Chroma - menus.inc file
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

int gI_SelectedTrail[MAXPLAYERS + 1] = { TRAILS_NONE, ... };

Action OpenTrailMenu(int client, int page)
{
	Menu menu = new Menu(Menu_Handler);
	menu.SetTitle("Choose a trail:\n ");

	char none[8];
	IntToString(TRAILS_NONE, none, 8);

	menu.AddItem(none, "None", (gI_SelectedTrail[client] == TRAILS_NONE) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

	for (int i = 0; i < gI_TrailCount; i++)
	{
		char info[8];
		IntToString(i, info, 8);

		if (StrEqual(gT_Trails[i].Name, "\\0") || StrEqual(gT_Trails[i].Name, "{null}", false) || StrEqual(gT_Trails[i].Name, "{empty}", false))
			menu.AddItem("", "", ITEMDRAW_SPACER); // Empty line support
		else
			menu.AddItem(info, gT_Trails[i].Name, (gI_SelectedTrail[client] == i) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	menu.ExitButton = true;
	menu.DisplayAt(client, page, 60);

	return Plugin_Handled;
}

int Menu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[8];
		menu.GetItem(param2, info, 8);

		MenuSelection(param1, info);
		OpenTrailMenu(param1, GetMenuSelectionPosition());
	}
	else if (action == MenuAction_End)
		delete menu;

	return 0;
}

void MenuSelection(int client, char[] info)
{
	int choice = StringToInt(info);
	bool isCSGO = gEV_Type == Engine_CSGO;

	if (choice == TRAILS_NONE)
	{
		char message[255];
		FormatEx(message, 255, "Your trail is now %sDISABLED%s.", isCSGO ? "<span color='#FF0000'>" : "", isCSGO ? "</span>" : "");

		PrintCenterText(client, message);
		DisableAllSpecialEffects(client);
	}
	else
	{
		char enabledStateMessage[100];
		FormatEx(enabledStateMessage, 100, "Your trail is now %sENABLED%s.\n", isCSGO ? "<span color='#00FF00'>" : "", isCSGO ? "</span>" : "");

		char fontColor[24];

		if (gT_Trails[choice].Color.R == 0 && gT_Trails[choice].Color.G == 0 && gT_Trails[choice].Color.B == 0)
			FormatEx(fontColor, 24, "<span color='#FFFFFF'>");
		else
			FormatEx(fontColor, 24, "<span color='#%02x%02x%02x'>", gT_Trails[choice].Color.R, gT_Trails[choice].Color.G, gT_Trails[choice].Color.B);

		char selectedTrailMessage[100];
		FormatEx(selectedTrailMessage, 100, "Your selected trail is: %s%s%s.", isCSGO ? fontColor : "", gT_Trails[choice].Name, isCSGO ? "</span>" : "");

		bool wasDisabled = gI_SelectedTrail[client] == TRAILS_NONE;

		char fullMessage[255];
		FormatEx(fullMessage, 255, "%s%s", wasDisabled ? enabledStateMessage : "", selectedTrailMessage);

		PrintCenterText(client, fullMessage);
		UpdateSpecialEffectModes(client, gT_Trails[choice]);
	}

	gI_SelectedTrail[client] = choice;
	SetClientCookie(client, gH_TrailChoiceCookie, info);
}
