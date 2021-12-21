#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <adminmenu>
#include <dhooks>

#define PLUGIN_VERSION "1.6.1.1"
#define PLUGIN_NAME "Survivor Chat Select"
#define PLUGIN_PREFIX "\x04[提示]"

#define GAMEDATA "survivor_chat_select"

#define MODEL_BILL "models/survivors/survivor_namvet.mdl"
#define MODEL_FRANCIS "models/survivors/survivor_biker.mdl"
#define MODEL_LOUIS "models/survivors/survivor_manager.mdl"
#define MODEL_ZOEY "models/survivors/survivor_teenangst.mdl"

#define MODEL_NICK "models/survivors/survivor_gambler.mdl"
#define MODEL_ROCHELLE "models/survivors/survivor_producer.mdl"
#define MODEL_COACH "models/survivors/survivor_coach.mdl"
#define MODEL_ELLIS "models/survivors/survivor_mechanic.mdl"

#define     NICK     	0, 0
#define     ROCHELLE    1, 1
#define     COACH     	2, 2
#define     ELLIS     	3, 3
#define     BILL     	4, 4
#define     ZOEY     	5, 5
#define     FRANCIS     6, 6
#define     LOUIS     	7, 7

Cookie g_hClientID;
Cookie g_hClientModel;

TopMenu hTopMenu;

ConVar g_hZoey;
ConVar g_hCookies;
ConVar g_hBotsChange;
ConVar g_hAdminsOnly;

int g_iZoey;
int g_iOrignalMapSet;
int g_iSelectedClient[MAXPLAYERS + 1];

bool g_bCookies;
bool g_bBotsChange;
bool g_bAdminsOnly;
bool g_bShouldIgnoreOnce[MAXPLAYERS + 1];

static const char g_sSurvivorNames[8][] =
{
	"Nick",
	"Rochelle",
	"Coach",
	"Ellis",
	"Bill",
	"Zoey",
	"Francis",
	"Louis",
};

static const char g_sSurvivorModels[8][] =
{
	MODEL_NICK,
	MODEL_ROCHELLE,
	MODEL_COACH,
	MODEL_ELLIS,
	MODEL_BILL,
	MODEL_ZOEY,
	MODEL_FRANCIS,
	MODEL_LOUIS
};

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "DeatChaos25, Mi123456 & Merudo, Lux",
	description = "Select a survivor character by typing their name into the chat.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2399163#post2399163"
}

public void OnPluginStart()
{
	LoadGameData();

	g_hClientID = new Cookie("Player_Character", "Player's default character ID.", CookieAccess_Protected);
	g_hClientModel = new Cookie("Player_Model", "Player's default character model.", CookieAccess_Protected);

	RegConsoleCmd("sm_zoey", ZoeyUse, "Changes your survivor character into Zoey");
	RegConsoleCmd("sm_nick", NickUse, "Changes your survivor character into Nick");
	RegConsoleCmd("sm_ellis", EllisUse, "Changes your survivor character into Ellis");
	RegConsoleCmd("sm_coach", CoachUse, "Changes your survivor character into Coach");
	RegConsoleCmd("sm_rochelle", RochelleUse, "Changes your survivor character into Rochelle");
	RegConsoleCmd("sm_bill", BillUse, "Changes your survivor character into Bill");
	RegConsoleCmd("sm_francis", BikerUse, "Changes your survivor character into Francis");
	RegConsoleCmd("sm_louis", LouisUse, "Changes your survivor character into Louis");

	RegAdminCmd("sm_csm", InitiateMenuAdmin, ADMFLAG_GENERIC, "Brings up a menu to select a client's character");
	RegConsoleCmd("sm_c", ShowMenu, "Brings up a menu to select a client's character");

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("bot_player_replace", Event_BotPlayerReplace, EventHookMode_Pre);
	HookEvent("player_bot_replace", Event_PlayerBotReplace, EventHookMode_Pre);

	g_hZoey = CreateConVar("l4d_scs_zoey", "1","Prop for Zoey. 0: Rochelle (windows), 1: Zoey (linux), 2: Nick (fakezoey)", FCVAR_NOTIFY,true, 0.0, true, 2.0);
	g_hCookies = CreateConVar("l4d_scs_cookies", "1","Store player's survivor? 1:Enable, 0:Disable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hBotsChange = CreateConVar("l4d_scs_botschange", "1","Change new bots to least prevalent survivor? 1:Enable, 0:Disable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hAdminsOnly = CreateConVar("l4d_csm_admins_only", "0","Changes access to the sm_csm command. 1 = Admin access only", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	g_hZoey.AddChangeHook(ConVarChanged);
	g_hCookies.AddChangeHook(ConVarChanged);
	g_hBotsChange.AddChangeHook(ConVarChanged);
	g_hAdminsOnly.AddChangeHook(ConVarChanged);
	

	//AutoExecConfig(true, "l4dscs");

	/* Account for late loading */
	TopMenu topmenu;
	if(LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);

	RegAdminCmd("sm_setleast", CmdSetLeast, ADMFLAG_ROOT);
}

public Action CmdSetLeast(int client, int args)
{
    for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			SetLeastUsedCharacter(i);
			ReEquipWeapons(i);
		}
	}

    return Plugin_Handled;
}

public void OnMapStart()
{
	FindConVar("precache_all_survivors").SetInt(1);

	for(int i; i < 8; i++)
		PrecacheModel(g_sSurvivorModels[i], true);
}

public void OnConfigsExecuted()
{
	GetCvars();
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iZoey = g_hZoey.IntValue;
	g_bCookies = g_hCookies.BoolValue;
	g_bBotsChange= g_hBotsChange.BoolValue;
	g_bAdminsOnly = g_hAdminsOnly.BoolValue;
}

void LoadGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false) 
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null) 
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
		
	SetupDetours(hGameData);

	delete hGameData;
}

void SetupDetours(GameData hGameData = null)
{
	DynamicDetour dDetour;
	dDetour = DynamicDetour.FromConf(hGameData, "CTerrorGameRules::GetSurvivorSet");
	if(dDetour == null)
		SetFailState("Failed to load 'CTerrorGameRules::GetSurvivorSet' signature.");
		
	if(!dDetour.Enable(Hook_Post, GetSurvivorSetPost))
		SetFailState("Failed to detour post 'CTerrorGameRules::GetSurvivorSet'.");
}

//https://forums.alliedmods.net/showthread.php?t=309601
public MRESReturn GetSurvivorSetPost(DHookReturn hReturn)
{
	g_iOrignalMapSet = hReturn.Value;

	if(g_bBotsChange)
	{
		hReturn.Value = 2;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

// *********************************************************************************
// Character Select functions
// *********************************************************************************

int GetZoeyProp()
{
	if(g_iZoey == 2)
		return 0; // For use with fakezoey for windows
	else if(g_iZoey == 1)
		return 5; // Linux only, or crashes the game
	else
		return 1; // For windows without fakezoey
}

public Action ZoeyUse(int client, int args)
{
	SetCharacter(client, GetZoeyProp(), 5);
}

public Action NickUse(int client, int args)
{
	SetCharacter(client, NICK);
}

public Action EllisUse(int client, int args)
{
	SetCharacter(client, ELLIS);
}

public Action CoachUse(int client, int args)
{
	SetCharacter(client, COACH);
}

public Action RochelleUse(int client, int args)
{
	SetCharacter(client, ROCHELLE);
}

public Action BillUse(int client, int args)
{
	SetCharacter(client, BILL);
}

public Action BikerUse(int client, int args)
{
	SetCharacter(client, FRANCIS);
}

public Action LouisUse(int client, int args)
{
	SetCharacter(client, LOUIS);
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if(g_bBotsChange == false)
		return;

	if(sClassname[0] != 's' && sClassname[0] != 'p')
		return;

	if(strcmp(sClassname, "survivor_bot") == 0 || strcmp(sClassname, "player") == 0)
		SDKHook(iEntity, SDKHook_SpawnPost, SpawnPost);
}

public void SpawnPost(int iEntity)// before events!
{
	SDKUnhook(iEntity, SDKHook_SpawnPost, SpawnPost);

	if(GetClientTeam(iEntity) == 4)
		return;	

	RequestFrame(NextFrame, GetClientUserId(iEntity));
}

/*
don't identity fix bots that die and respawn just find least used survivor
and
This is called before ResetVar() framehook because SpawnPost triggers before events
*/
public void NextFrame(int iClient)
{
	if((iClient = GetClientOfUserId(iClient)) == 0 || g_bShouldIgnoreOnce[iClient] || !IsClientInGame(iClient) || GetClientTeam(iClient) != 2)
		return;

	SetLeastUsedCharacter(iClient);
}

//set iclient to 0 to not ignore, for anyone using this function
int CheckLeastUsedSurvivor(int iClient)
{
	int i;
	int iLeastChar[8];
	int iCharBuffer;
	for(i = 1; i <= MaxClients; i++)
	{
		if(i == iClient || !IsClientInGame(i) || GetClientTeam(i) != 2)
			continue;
		
		if((iCharBuffer = GetEntProp(i, Prop_Send, "m_survivorCharacter")) > 7)//in SpawnPost the entprop is 8, because valve wants it to be 8 at this point
			continue;

		iLeastChar[iCharBuffer]++;
	}

	if(g_iOrignalMapSet == 1)
	{
		int iSurvivorCharIndex = iLeastChar[7];
		iCharBuffer = 7;
		for(i = 7; i >= 0; i--)
		{
			if(iLeastChar[i] < iSurvivorCharIndex)
			{
				iSurvivorCharIndex = iLeastChar[i];
				iCharBuffer = i;
			}
		}
	}
	else
	{
		int iSurvivorCharIndex = iLeastChar[0];
		iCharBuffer = 0;

		for(i = 0; i <= 7; i++)
		{
			if(iLeastChar[i] < iSurvivorCharIndex)
			{
				iSurvivorCharIndex = iLeastChar[i];
				iCharBuffer = i;
			}
		}
	}
	return iCharBuffer;
}

void SetLeastUsedCharacter(int iClient)
{
	switch(CheckLeastUsedSurvivor(iClient))
	{
		case 0:
			SetCharacterInfo(iClient, NICK);
		case 1:
			SetCharacterInfo(iClient, ROCHELLE);
		case 2:
			SetCharacterInfo(iClient, COACH);
		case 3:
			SetCharacterInfo(iClient, ELLIS);
		case 4:
			SetCharacterInfo(iClient, BILL);
		case 5:
			SetCharacterInfo(iClient, GetZoeyProp(), 5);
		case 6:
			SetCharacterInfo(iClient, FRANCIS);
		case 7:
			SetCharacterInfo(iClient, LOUIS);	
	}
}

void SetCharacter(int iClient, int iCharIndex, int iModelIndex, bool bSave=true)
{
	if(iClient == 0 || !IsClientInGame(iClient))
		return;

	if(GetClientTeam(iClient) != 2)
	{
		PrintToChat(iClient, "\x05只有幸存者才能使用该指令.");
		return;
	}
	
	SetCharacterInfo(iClient, iCharIndex, iModelIndex);

	ReEquipWeapons(iClient);

	if(bSave && g_bCookies)
	{
		char sProp[2];
		IntToString(iCharIndex, sProp, sizeof(sProp));
		g_hClientID.Set(iClient, sProp);
		g_hClientModel.Set(iClient, g_sSurvivorModels[iModelIndex]);
		PrintToChat(iClient, "%s\x05你的人物角色现在已经被设为\x03%s\x05.", PLUGIN_PREFIX, g_sSurvivorNames[iModelIndex]);
	}
}

void SetCharacterInfo(int iClient, int iCharIndex, int iModelIndex)
{
	if(GetEntProp(iClient, Prop_Send, "m_survivorCharacter") != iCharIndex)
		SetEntProp(iClient, Prop_Send, "m_survivorCharacter", iCharIndex);
	
	char sModel[PLATFORM_MAX_PATH];
	GetClientModel(iClient, sModel, sizeof(sModel));
	
	if(strcmp(sModel, g_sSurvivorModels[iModelIndex], false) != 0)
		SetEntityModel(iClient, g_sSurvivorModels[iModelIndex]);
	
	if(IsFakeClient(iClient))
		SetClientInfo(iClient, "name", g_sSurvivorNames[iModelIndex]);
}

// *********************************************************************************
// Character Select menu
// *********************************************************************************

/* This Admin Menu was taken from csm, all credits go to Mi123645 */
public Action InitiateMenuAdmin(int client, int args)
{
	if(client == 0 || !IsClientInGame(client))
		return;

	char sName[MAX_NAME_LENGTH];
	char sNumber[10];

	Menu menu = new Menu(ShowMenu2);
	menu.SetTitle("目标玩家:");

	for(int i = 1; i <= MaxClients; i++)
	{
		if(/*i == client || */!IsClientInGame(i) || GetClientTeam(i) != 2)
			continue;

		FormatEx(sName, sizeof(sName), "%N", i);
		FormatEx(sNumber, sizeof(sNumber), "%i", i);
		menu.AddItem(sNumber, sName);
	}


	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int ShowMenu2(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sNumber[4];
			menu.GetItem(param2, sNumber, sizeof(sNumber));

			g_iSelectedClient[client] = StringToInt(sNumber);

			ShowMenuAdmin(client, 0);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && hTopMenu != null)
				DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
			delete menu;
	}
}

public Action ShowMenuAdmin(int client, int args)
{
	Menu menu = new Menu(CharMenuAdmin);
	menu.SetTitle("人物:");

	menu.AddItem("0", "Nick尼克");
	menu.AddItem("1", "Rochelle罗雪儿");
	menu.AddItem("2", "Coach教练");
	menu.AddItem("3", "Ellis艾利斯");

	menu.AddItem("4", "Bill比尔");
	menu.AddItem("5", "Zoey佐伊");
	menu.AddItem("6", "Francis弗朗西斯");
	menu.AddItem("7", "Louis路易斯");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int CharMenuAdmin(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch(param2)
			{
				case 0:
					SetCharacter(g_iSelectedClient[client], NICK, false);
				case 1:
					SetCharacter(g_iSelectedClient[client], ROCHELLE, false);
				case 2:
					SetCharacter(g_iSelectedClient[client], COACH, false);
				case 3:
					SetCharacter(g_iSelectedClient[client], ELLIS, false);
				case 4:
					SetCharacter(g_iSelectedClient[client], BILL, false);
				case 5:
					SetCharacter(g_iSelectedClient[client], GetZoeyProp(), 5, false);
				case 6:
					SetCharacter(g_iSelectedClient[client], FRANCIS, false);
				case 7:
					SetCharacter(g_iSelectedClient[client], LOUIS, false);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public Action ShowMenu(int client, int args)
{
	if (client == 0) 
	{
		ReplyToCommand(client, "\x04[提示]\x05角色选择菜单仅在游戏中显示.");
		return;
	}
	if (GetClientTeam(client) != 2)
	{
		ReplyToCommand(client, "\x04[提示]\x05角色选择菜单仅适用于幸存者.");
		return;
	}
	if (!IsPlayerAlive(client)) 
	{
		ReplyToCommand(client, "\x04[提示]\x05你必须活着才能使用角色选择菜单.");
		return;
	}
	if(GetUserFlagBits(client) == 0 && g_bAdminsOnly)
	{
		ReplyToCommand(client, "\x04[提示]\x05只有管理员才能使用该菜单.");
		return;
	}

	Menu menu = new Menu(CharMenu);
	menu.SetTitle("选择人物:");

	menu.AddItem("0", "Nick尼克");
	menu.AddItem("1", "Rochelle罗雪儿");
	menu.AddItem("2", "Coach教练");
	menu.AddItem("3", "Ellis艾利斯");

	menu.AddItem("4", "Bill比尔");
	menu.AddItem("5", "Zoey佐伊");
	menu.AddItem("6", "Francis弗朗西斯");
	menu.AddItem("7", "Louis路易斯");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int CharMenu(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(param2)
			{
				case 0:
					NickUse(client, 0);
				case 1:
					RochelleUse(client, 0);
				case 2:
					CoachUse(client, 0);
				case 3:
					EllisUse(client, 0);
				case 4:
					BillUse(client, 0);
				case 5:
					ZoeyUse(client, 0);
				case 6:
					BikerUse(client, 0);
				case 7:
					LouisUse(client, 0);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

// *********************************************************************************
// Admin Menu entry
// *********************************************************************************

//// Added for admin menu
public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	/* Block us from being called twice */
	if(topmenu == hTopMenu)
		return;

	/* Save the Handle */
	hTopMenu = topmenu;

	// Find player's menu ...
	TopMenuObject player_commands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

	if(player_commands != INVALID_TOPMENUOBJECT)
		AddToTopMenu(hTopMenu, "Select player's survivor", TopMenuObject_Item, InitiateMenuAdmin2, player_commands, "Select player's survivor", ADMFLAG_GENERIC);
}

public void InitiateMenuAdmin2(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
		FormatEx(buffer, maxlength, "更改玩家人物模型", "", client);
	else if(action == TopMenuAction_SelectOption)
		InitiateMenuAdmin(client, 0);
}

// *********************************************************************************
// Cookie loading
// *********************************************************************************

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2)
		return;

	if(g_bBotsChange)
		RequestFrame(OnNextFrame_PlayerSpawn, userid);

	if(g_bCookies)
		CreateTimer(0.3, Timer_LoadCookie, userid, TIMER_FLAG_NO_MAPCHANGE);
}

void OnNextFrame_PlayerSpawn(int client)
{
	if((client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2 && !IsPlayerAlive(client))
		SetLeastUsedCharacter(client);
}

public Action Timer_LoadCookie(Handle timer, int client)
{
	if((client = GetClientOfUserId(client)) == 0 || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2)
		return;

	if(!AreClientCookiesCached(client))
	{
		PrintToChat(client, "%s\x05无法载入你的人物角色,请输入\x03!c\x05来设置你的人物角色.", PLUGIN_PREFIX);
		return;
	}

	char sID[2];
	g_hClientID.Get(client, sID, sizeof(sID));

	char sModel[64];
	g_hClientModel.Get(client, sModel, sizeof(sModel));

	if(sID[0] != 0 && sModel[0] != 0)
	{
		SetEntProp(client, Prop_Send, "m_survivorCharacter", StringToInt(sID));
		SetEntityModel(client, sModel);
	}
}

public void Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
	for(int i; i <= MaxClients; i++)
		g_bShouldIgnoreOnce[i] = false;
}

public void Event_BotPlayerReplace(Event event, char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	if(player == 0 || !IsClientInGame(player) || GetClientTeam(player) != 2 || IsFakeClient(player)) 
		return;
	
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if(bot == 0 || !IsClientInGame(bot))
		return;

	g_bShouldIgnoreOnce[bot] = false;
}

public void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast)
{
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if(bot == 0 || !IsClientInGame(bot))
		return;

	int player = GetClientOfUserId(event.GetInt("player"));
	if(player == 0 || !IsClientInGame(player) || GetClientTeam(player) != 2)
		return;
	
	if(IsFakeClient(player) && g_bBotsChange)
	{
		SetLeastUsedCharacter(bot);
		RequestFrame(ResetVar, bot);
		return;
	}
	
	g_bShouldIgnoreOnce[bot] = true;
	RequestFrame(ResetVar, bot);
}

public void ResetVar(int iBot)// this is special called after NextFrame
{
	g_bShouldIgnoreOnce[iBot] = false;
}

// *********************************************************************************
// Reequip weapons functions
// *********************************************************************************

enum
{
	iClip = 0,
	iAmmo,
	iUpgrade,
	iUpAmmo,
	iSkin,
};

// ------------------------------------------------------------------
// Save weapon details, remove weapon, create new weapons with exact same properties
// Needed otherwise there will be animation bugs after switching characters due to different weapon mount points
// ------------------------------------------------------------------
stock void ReEquipWeapons(int client)
{
	int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(!IsPlayerAlive(client) || iWeapon <= MaxClients || !IsValidEntity(iWeapon)) // Don't bother with the weapon fix if dead or unarmed
		return;

	int iSlot0 = GetPlayerWeaponSlot(client, 0);
	int iSlot1 = GetPlayerWeaponSlot(client, 1);
	int iSlot2 = GetPlayerWeaponSlot(client, 2);
	int iSlot3 = GetPlayerWeaponSlot(client, 3);
	int iSlot4 = GetPlayerWeaponSlot(client, 4);


	char sWeapon[64];
	GetClientWeapon(client, sWeapon, sizeof(sWeapon));

	//  Protection against grenade duplication exploit (throwing grenade then quickly changing character)
	if(iSlot2 > 0 && strcmp(sWeapon, "weapon_vomitjar") != 0 && strcmp(sWeapon, "weapon_pipe_bomb") != 0 && strcmp(sWeapon, "weapon_molotov") != 0)
	{
		GetEdictClassname(iSlot2, sWeapon, sizeof(sWeapon));
		DeletePlayerSlot(client, iSlot2);
		QuickGive(client, sWeapon);
	}
	
	if(iSlot3 > 0)
	{
		GetEdictClassname(iSlot3, sWeapon, sizeof(sWeapon));
		DeletePlayerSlot(client, iSlot3);
		QuickGive(client, sWeapon);
	}
	
	if(iSlot4 > 0)
	{
		GetEdictClassname(iSlot4, sWeapon, 64);
		DeletePlayerSlot(client, iSlot4);
		QuickGive(client, sWeapon);
	}
	
	if(iSlot1 > 0)
		ReEquipSlot1(client, iSlot1);

	if(iSlot0 > 0)
		ReEquipSlot0(client, iSlot0);
}

// --------------------------------------
// Extra work to save/load ammo details
// --------------------------------------
stock void ReEquipSlot0(int client, int iSlot0)
{
	int iWeapon0[5];
	char sWeapon[64];

	GetEdictClassname(iSlot0, sWeapon, 64);

	iWeapon0[iClip] = GetEntProp(iSlot0, Prop_Send, "m_iClip1");
	iWeapon0[iAmmo] = GetClientAmmo(client, sWeapon);
	iWeapon0[iUpgrade] = GetEntProp(iSlot0, Prop_Send, "m_upgradeBitVec");
	iWeapon0[iUpAmmo]  = GetEntProp(iSlot0, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
	iWeapon0[iSkin] = GetEntProp(iSlot0, Prop_Send, "m_nSkin");

	DeletePlayerSlot(client, iSlot0);
	QuickGive(client, sWeapon);

	iSlot0 = GetPlayerWeaponSlot(client, 0);
	if(iSlot0 > 0)
	{
		SetEntProp(iSlot0, Prop_Send, "m_iClip1", iWeapon0[iClip]);
		SetClientAmmo(client, sWeapon, iWeapon0[iAmmo]);
		SetEntProp(iSlot0, Prop_Send, "m_upgradeBitVec", iWeapon0[iUpgrade]);
		SetEntProp(iSlot0, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", iWeapon0[iUpAmmo]);
		SetEntProp(iSlot0, Prop_Send, "m_nSkin", iWeapon0[iSkin]);
	}
}

// --------------------------------------
// Extra work to identify melee weapon, & save/load ammo details
// --------------------------------------
stock void ReEquipSlot1(int client, int iSlot1)
{
	char sClassName[64];
	char sModelName[64];
	char sWeapon[64];

	int iAmmo1;
	int iSkin1;

	GetEdictClassname(iSlot1, sClassName, sizeof(sClassName));

	// Try to find weapon name without models
	if(strncmp(sClassName[7], "melee", 5) == 0)
		GetEntPropString(iSlot1, Prop_Data, "m_strMapSetScriptName", sWeapon, sizeof(sWeapon));
	else if(strcmp(sClassName[7], "pistol") == 0)
	{
		if(GetEntProp(iSlot1, Prop_Send, "m_hasDualWeapons") == 1)
			sWeapon = "v_dual_pistol";
		else 
			sWeapon = "weapon_pistol";
	}
	else
		sWeapon = sClassName;
		

	// IF model checking is required
	if(sWeapon[0] == '\0')
	{
		GetEntPropString(iSlot1, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

		if(StrContains(sModelName, "v_pistolA.mdl") != -1)	
			sWeapon = "weapon_pistol";
		else if(StrContains(sModelName, "v_dual_pistolA.mdl") != -1)	
			sWeapon = "v_dual_pistol";
		else if(StrContains(sModelName, "v_desert_eagle.mdl") != -1)	
			sWeapon = "weapon_pistol_magnum";
		else if(StrContains(sModelName, "v_bat.mdl") != -1)	
			sWeapon = "baseball_bat";
		else if(StrContains(sModelName, "v_cricket_bat.mdl") != -1)	
			sWeapon = "cricket_bat";
		else if(StrContains(sModelName, "v_crowbar.mdl") != -1)	
			sWeapon = "crowbar";
		else if(StrContains(sModelName, "v_fireaxe.mdl") != -1)	
			sWeapon = "fireaxe";
		else if(StrContains(sModelName, "v_katana.mdl") != -1)	
			sWeapon = "katana";
		else if(StrContains(sModelName, "v_golfclub.mdl") != -1)	
			sWeapon = "golfclub";
		else if(StrContains(sModelName, "v_machete.mdl") != -1)	
			sWeapon = "machete";
		else if(StrContains(sModelName, "v_tonfa.mdl") != -1)	
			sWeapon = "tonfa";
		else if(StrContains(sModelName, "v_electric_guitar.mdl") != -1)	
			sWeapon = "electric_guitar";
		else if(StrContains(sModelName, "v_frying_pan.mdl") != -1)	
			sWeapon = "frying_pan";
		else if(StrContains(sModelName, "v_knife_t.mdl") != -1)	
			sWeapon = "knife";
		else if(StrContains(sModelName, "v_chainsaw.mdl") != -1)	
			sWeapon = "weapon_chainsaw";
		else if(StrContains(sModelName, "v_riotshield.mdl") != -1)	
			sWeapon = "riotshield";
		else if(StrContains(sModelName, "v_pitchfork.mdl") != -1)	
			sWeapon = "pitchfork";
		else if(StrContains(sModelName, "v_shovel.mdl") != -1)	
			sWeapon = "shovel";
		else if(StrContains(sModelName, "v_foamfinger.mdl") != -1)	
			sWeapon = "b_foamfinger";			
		else if(StrContains(sModelName, "v_fubar.mdl") != -1)	
			sWeapon = "fubar";		
		else if(StrContains(sModelName, "v_paintrain.mdl") != -1)	
			sWeapon = "nail_board";
		else if(StrContains(sModelName, "v_sledgehammer.mdl") != -1)	
			sWeapon = "sledgehammer";
	}

	// IF Weapon properly identified, save then delete then reequip
	if(sWeapon[0] != '\0')
	{
		// IF Weapon uses ammo, save it
		if(strncmp(sWeapon[7], "pistol", 6) == 0 || strncmp(sWeapon[7], "chainsaw", 8) == 0)
			iAmmo1 = GetEntProp(iSlot1, Prop_Send, "m_iClip1");
	
		iSkin1 = GetEntProp(iSlot1, Prop_Send, "m_nSkin");
		
		DeletePlayerSlot(client, iSlot1);

		// Reequip weapon (special code for dual pistols)
		if(strncmp(sWeapon, "v_dual_pistol", 13) == 0)
		{
			QuickGive(client, "pistol");
			QuickGive(client, "pistol");
		}
		else
		{
			QuickGive(client, sWeapon);
			if(iSkin1 > 0)
			{
				iSlot1 = GetPlayerWeaponSlot(client, 1);
				if(iSlot1 > 0)
					SetEntProp(iSlot1, Prop_Send, "m_nSkin", iSkin1);
			}
		}

		// Restore ammo
		if(iAmmo1 >= 0)
		{
			iSlot1 = GetPlayerWeaponSlot(client, 1);
			if(iSlot1 > 0)
				SetEntProp(iSlot1, Prop_Send, "m_iClip1", iAmmo1);
		}
	}
}

stock void DeletePlayerSlot(int client, int iWeapon)
{		
	if(RemovePlayerItem(client, iWeapon)) 
		RemoveEntity(iWeapon);
}

stock void QuickGive(int client, const char[] args = "")
{
	int bits = GetUserFlagBits(client);
	int flags = GetCommandFlags("give");
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);			   
	FakeClientCommand(client, "give %s", args);
	SetCommandFlags("give", flags);
	SetUserFlagBits(client, bits);
}

// *********************************************************************************
// Get/Set ammo
// *********************************************************************************
stock int GetClientAmmo(int client, const char[] sWeapon)
{
	int iWeaponOffset = GetWeaponOffset(sWeapon);
	int iAmmoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
	
	return iWeaponOffset > 0 ? GetEntData(client, iAmmoOffset + iWeaponOffset) : 0;
}

stock void SetClientAmmo(int client, const char[] sWeapon, int iCount)
{
	int iWeaponOffset = GetWeaponOffset(sWeapon);
	int iAmmoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
	
	if(iWeaponOffset > 0) 
		SetEntData(client, iAmmoOffset+iWeaponOffset, iCount);
}

stock int GetWeaponOffset(const char[] sWeapon)
{
	int iWeaponOffset;

	if(strncmp(sWeapon[13], "m60", 3) == 0) //先验证M60避免与下面的rifle冲突
		iWeaponOffset = 12;
	else if(strncmp(sWeapon[7], "rifle", 5) == 0)
		iWeaponOffset = 24;
	else if(strncmp(sWeapon[7], "smg", 3) == 0)
		iWeaponOffset = 20;
	else if(strncmp(sWeapon[7], "pumpshotgun", 11) == 0 || strncmp(sWeapon[7], "shotgun_chrome", 14) == 0)
		iWeaponOffset = 28;
	else if(strncmp(sWeapon[7], "autoshotgun", 11) == 0|| strncmp(sWeapon[7], "shotgun_spas", 12) == 0)
		iWeaponOffset = 32;
	else if(strncmp(sWeapon[7], "hunting_rifle", 13) == 0)
		iWeaponOffset = 36;
	else if(strncmp(sWeapon[7], "sniper", 6) == 0)
		iWeaponOffset = 40;
	else if(strncmp(sWeapon[7], "grenade", 7) == 0)
		iWeaponOffset = 68;

	return iWeaponOffset;
}