#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Promises;KiD Fearless"
#define PLUGIN_VERSION "2.00"

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "LaserDraw",
	author = PLUGIN_AUTHOR,
	description = "Draw with a laser",
	version = PLUGIN_VERSION,
	url = ""
};

enum
{
	Type_Fixed,
	Type_Feet,
	Type_CrossHair
};

enum
{
	Mode_Spec,
	Mode_Solo,
	Mode_All
};

int RainbowColors[12][4] = 
{
	{255, 0, 0, 255},
	{255, 128, 0, 255},
	{255, 255, 0, 255},
	{128, 255, 0, 255},
	{0, 255, 0, 255},
	{0, 255, 128, 255},
	{0, 255, 255, 255},
	{0, 128, 255, 255},
	{0, 0, 255, 255},
	{128, 0, 255, 255},
	{255, 0, 255, 255},
	{255, 0, 128, 255}
};

bool g_bLaserEnabled[MAXPLAYERS+1];

int g_sprite;
int g_iLaserType[MAXPLAYERS+1];
int g_iLaserShowMode[MAXPLAYERS+1];
bool g_bPivotMode[MAXPLAYERS+1];


float g_fLaserDuration[MAXPLAYERS+1] = {1.0, ...};
float g_fLaserDistance[MAXPLAYERS+1];
float g_fLaserWidth[MAXPLAYERS+1];


Handle g_hCookieLaserMode;
Handle g_hCookieDuration;
Handle g_hCookieDistance;
Handle g_hCookieShowMode;
Handle g_hCookieDefault;
Handle g_hCookieWidth;
Handle g_hCookiePivot;


public void OnPluginStart()
{
	
	CreateConVar("sm_lazer_version", PLUGIN_VERSION, "laserdraw", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	RegConsoleCmd("sm_laser", SM_LASER);
	
	RegConsoleCmd("+laser", SM_LASER_PRESS);
	RegConsoleCmd("-laser", SM_LASER_RELEASE);
	
	RegConsoleCmd("sm_laser_width", SM_WIDTH);
	RegConsoleCmd("sm_laser_duration", SM_DURATION);
	RegConsoleCmd("sm_laser_distance", SM_DISTANCE);
	RegConsoleCmd("sm_laser_pivot", SM_PIVOT);
	
	g_hCookieLaserMode = RegClientCookie("laser_mode", "ladr_mode", CookieAccess_Public);
	g_hCookieDuration = RegClientCookie("laser_duration", "ladr_duration", CookieAccess_Public);
	g_hCookieDistance = RegClientCookie("laser_distance", "ladr_distance", CookieAccess_Public);
	g_hCookieWidth = RegClientCookie("laser_width", "ladr_width", CookieAccess_Public);
	g_hCookieShowMode = RegClientCookie("laser_local", "ladr_local", CookieAccess_Public);
	g_hCookiePivot = RegClientCookie("laser_pivot", "laser_pivot", CookieAccess_Public);
	g_hCookieDefault = RegClientCookie("laser_default", "laser_default", CookieAccess_Public);
	
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if(IsClientConnected(i) && IsClientInGame(i) )
		{
			OnClientPutInServer(i);
			OnClientCookiesCached(i);
		}
	}
}

public void OnClientCookiesCached(int client)
{
	char sCookie[8];
	GetClientCookie(client, g_hCookieDefault, sCookie, sizeof(sCookie));

	if (StringToInt(sCookie) == 0)
	{
		SetCookieInt(client, g_hCookieLaserMode, 2);
		SetCookieFloat(client, g_hCookieDuration, 10.0);
		SetCookieFloat(client, g_hCookieDistance, 64.0);
		SetCookieFloat(client, g_hCookieWidth, 1.0);
		SetCookieInt(client, g_hCookieShowMode, 0);
		SetCookieInt(client, g_hCookiePivot, 0);
		SetCookieInt(client, g_hCookieDefault, 1);
	}

	GetClientCookie(client, g_hCookieLaserMode, sCookie, sizeof(sCookie));
	g_iLaserType[client] = StringToInt(sCookie);
	
	GetClientCookie(client, g_hCookieDuration, sCookie, sizeof(sCookie));
	g_fLaserDuration[client] = StringToFloat(sCookie);

	GetClientCookie(client, g_hCookieDistance, sCookie,sizeof(sCookie));
	g_fLaserDistance[client] = StringToFloat(sCookie);

	GetClientCookie(client, g_hCookieWidth, sCookie, sizeof(sCookie));
	g_fLaserWidth[client] = StringToFloat(sCookie);

	GetClientCookie(client, g_hCookieShowMode, sCookie, sizeof(sCookie));
	g_iLaserShowMode[client] = StringToInt(sCookie);

	GetClientCookie(client, g_hCookiePivot, sCookie, sizeof(sCookie));
	g_bPivotMode[client] = !!StringToInt(sCookie);
}

public void OnMapStart()
{
	g_sprite = PrecacheModel("materials/sprites/laserbeam.vmt");
}

public void OnClientPutInServer(int client)
{
	g_bLaserEnabled[client] = false;
}

public Action SM_LASER(int client, int args)
{
	OpenLaserMenu(client);
	return Plugin_Handled;
}

public Action SM_LASER_PRESS(int client, int args)
{
	g_bLaserEnabled[client] = true;
	return Plugin_Handled;
}

public Action SM_LASER_RELEASE(int client, int args)
{
	g_bLaserEnabled[client] = false;
	return Plugin_Handled;
}

public Action SM_WIDTH(int client, int args)
{
	if (args >= 1)
	{
		char strWidth[32];
		GetCmdArg(1, strWidth, 32);
		float flWidth = StringToFloat(strWidth);
		
		if (flWidth > 25.0 && (!(GetUserFlagBits(client) & ADMFLAG_ROOT)))
		{
			flWidth = 25.0;
		}
		else
		{
			if (flWidth > 256.0)
			{
				flWidth = 256.0;
			}
		}
		if (flWidth < 0.128)
		{
			flWidth = 0.128;
		}
		g_fLaserWidth[client] = flWidth;
		SetCookieFloat(client, g_hCookieWidth, g_fLaserWidth[client]);
	}

	ReplyToCommand(client, "Your laser's width is %.2f", g_fLaserWidth[client]);

	return Plugin_Handled;
}

public Action SM_DURATION(int client, int args)
{
	if (args >= 1)
	{
		char sDuration[32];
		GetCmdArg(1, sDuration, 32);
		float flDuration = StringToFloat(sDuration);
		if (flDuration > 25.0)
		{
			flDuration = 25.0;
		}
		if (flDuration < 0.0502)
		{
			flDuration = 0.0;
		}
		g_fLaserDuration[client] = flDuration;
		SetCookieFloat(client, g_hCookieDuration, g_fLaserDuration[client]);
	}
	if (g_fLaserDuration[client] == 0.0)
	{
		ReplyToCommand(client, "Your laser's duration is infinite");
	}
	else
	{
		ReplyToCommand(client, "Your laser's duration is %.2f seconds", g_fLaserDuration[client]);
	}
	return Plugin_Handled;
}

public Action SM_PIVOT(int client, int args)
{
	g_bPivotMode[client] = !g_bPivotMode[client];
	

	ReplyToCommand(client, "PivotMode: %s", g_bPivotMode[client]? "enabled" : "disabled");
	return Plugin_Handled;
}


public Action SM_DISTANCE(int client, int args)
{
	if (args >= 1)
	{
		char sDist[32];
		GetCmdArg(1, sDist, sizeof(sDist));
		float flDist = StringToFloat(sDist);

		if (flDist > 8192.0)
		{
			flDist = 8192.0;
		}
		else if (flDist < 0.0)
		{
			flDist = 0.0;
		}

		g_fLaserDistance[client] = flDist;
		SetCookieFloat(client, g_hCookieDistance, g_fLaserDistance[client]);
	}

	ReplyToCommand(client, "Your laser's fixed distance is %.2f", g_fLaserDistance[client]);
	return Plugin_Handled;
}

public void OpenLaserMenu(int client)
{
	Menu menu = new Menu(LaserMenu_Handler);
	menu.SetTitle("LaseMenu");
	
	char buffer[64];
	FormatEx(buffer, 64, "Paint - [%s]\n", (g_bLaserEnabled[client]) ? "x" : " ");
	menu.AddItem("0", buffer);
	
	switch(g_iLaserType[client])
	{
		case Type_Fixed:
		{
			menu.AddItem("1", "Type: View Fixed Distance");
		}
		case Type_Feet:
		{
			menu.AddItem("1", "Type: Feet");
		}
		case Type_CrossHair:
		{
			menu.AddItem("1", "Type: Crosshair");
		}
	}

	switch(g_iLaserShowMode[client])
	{
		case Mode_Spec:
		{
			menu.AddItem("2", "Mode: Spectators + You");
		}
		case Mode_Solo:
		{
			menu.AddItem("2", "Mode: Only You");
		}
		case Mode_All:
		{
			menu.AddItem("2", "Mode: Everyone");
		}
	}
	
	menu.AddItem("3", "Print commands to console");
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int LaserMenu_Handler(Handle menu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0://Paint
				{
					g_bLaserEnabled[client] = !g_bLaserEnabled[client];
				}
				case 1: // laser mode
				{
					g_iLaserType[client] = (g_iLaserType[client] + 1) % 3;
					SetCookieInt(client, g_hCookieLaserMode, g_iLaserType[client]);
				}
				case 2://lasershow
				{
					g_iLaserShowMode[client] = (g_iLaserShowMode[client] + 1) % 3;
					SetCookieInt(client, g_hCookieShowMode, g_iLaserShowMode[client]);
				}
				case 3:
				{
					PrintCommands(client);
				}
			}
			
			OpenLaserMenu(client);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public void PrintCommands(int client)
{
	PrintToChat(client, "Check your console for commands");
	PrintToConsole(client, "	Laser Commands			");
	PrintToConsole(client, "+laser				-> enable laser");
	PrintToConsole(client, "-laser 				-> disable laser");
	PrintToConsole(client, "sm_laser_width {number} 		-> sets laser width");
	PrintToConsole(client, "sm_laser_duration {number}		-> sets beam duration");
	PrintToConsole(client, "sm_laser_distance 			-> sets fixed distance distance");
	PrintToConsole(client, "sm_laser_pivot            		-> enables or disables pivot");
}

stock void PaintLasers(int client, float start[3], float end[3], int color[4])
{
	TE_SetupBeamPoints(start, end, g_sprite, 0, 0, 0, g_fLaserDuration[client], g_fLaserWidth[client] / 2.0, g_fLaserWidth[client] / 2.0, 0, 0.0, color, 0);
	
	
	switch(g_iLaserShowMode[client])
	{
		case Mode_Solo:
		{
			TE_SendToClient(client);
		}
		case Mode_All:
		{
			TE_SendToAll();
		}
		case Mode_Spec:
		{
			int targetCount = 1;
			int targets[MAXPLAYERS+1];
			targets[0] = client;
			for(int i = 1; i <= MaxClients; ++i)
			{
				if(!IsClientConnected(i) || !IsClientInGame(i) || i == client || IsPlayerAlive(i))
				{
					continue;
				}

				int specMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
				if(specMode >= 3 && specMode <= 5)
				{
					int target = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
					if (target < 1 || target > MaxClients || !IsClientConnected(i) || !IsClientInGame(target))
					{
						continue;
					}
					if(target == client)
					{
						targets[targetCount++] = i;
					}
				}
			}
			TE_Send(targets, targetCount);
		}
	}
}

stock int GetSelectedPlayer(int client)
{
	if (IsClientInGame(client))
	{
		if (IsPlayerAlive(client))
		{
			return client;
		}
		
		int specMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		if(specMode >= 3 && specMode <= 5)
		{
			int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			if (!IsValidClientIndex(target) || !IsClientInGame(target))
			{
				return 0;
			}

			int userid = GetClientUserId(target);
			g_SelectedPlayer[client] = userid;
		}
	}

	return g_SelectedPlayer[client];
}

void TraceEyeInf(int client, float pos[3]) 
{
	float vAngles[3]; 
	float vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	TR_TraceRayFilter(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceRayDontHitSelf);
	if(TR_DidHit()) 
	{
		TR_GetEndPosition(pos);
	}
}

void TraceEyeDist(int client, float pos[3]) 
{
	float vAngles[3]; 
	float vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	float vDirection[3];
	
	GetAngleVectors(vAngles, vDirection, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(vDirection, g_fLaserDistance[client]);
	
	AddVectors(vOrigin, vDirection, pos);
}

void TraceFeet(int client, float pos[3])
{
	GetClientAbsOrigin(client, pos);
}

public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	return entity != data && !(0 < entity <= MaxClients);
}

stock void SetCookieString(int client, Handle hCookie, char[] sCookie)
{
	SetClientCookie(client, hCookie, sCookie);
}

stock void SetCookieFloat(int client, Handle hCookie, float n)
{
	char sCookie[64];
	FloatToString(n, sCookie, sizeof(sCookie));
	SetClientCookie(client, hCookie, sCookie);
}

stock void SetCookieInt(int client, Handle hCookie, int n)
{
	char sCookie[64];
	IntToString(n, sCookie, sizeof(sCookie));
	SetClientCookie(client, hCookie, sCookie);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount)
{
	if (!g_bLaserEnabled[client] || IsFakeClient(client) || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	static float s_fLastLaser[MAXPLAYERS+1][3];

	float pos[3] = 0.0;	

	switch(g_iLaserType[client])
	{
		case 0:
		{
			TraceEyeDist(client, pos);
		}
		case 1:
		{
			TraceFeet(client, pos);
		}
		case 2:
		{
			TraceEyeInf(client, pos);
		}
	}
		
	if (GetVectorDistance(pos, s_fLastLaser[client]) > g_fLaserWidth[client])
	{
		PaintLasers(client, s_fLastLaser[client], pos, RainbowColors[tickcount % 12]);

		s_fLastLaser[client][0] = pos[0];
		s_fLastLaser[client][1] = pos[1];
		s_fLastLaser[client][2] = pos[2];
	}
	

	return Plugin_Continue;
}
