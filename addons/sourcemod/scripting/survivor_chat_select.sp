#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <adminmenu>
#include <dhooks>

#define PLUGIN_VERSION "1.6.1.1"
#define PLUGIN_NAME 	"Survivor Chat Select"
#define PLUGIN_PREFIX	"\x01[\x04SCS\x01]"

#define GAMEDATA		"survivor_chat_select"

#define	 NICK		0, 0
#define	 ROCHELLE	1, 1
#define	 COACH		2, 2
#define	 ELLIS		3, 3
#define	 BILL		4, 4
#define	 ZOEY		5, 5
#define	 FRANCIS	6, 6
#define	 LOUIS		7, 7

Cookie
	g_cClientID,
	g_cClientModel;

TopMenu
	hTopMenu;

ConVar
	g_hZoey,
	g_hCookies,
	g_hBotsChange,
	g_hAdminsOnly;

int
	g_iZoey,
	g_iOrignalMapSet,
	g_iSelectedClient[MAXPLAYERS + 1];

bool
	g_bCookies,
	g_bBotsChange,
	g_bAdminsOnly,
	g_bShouldIgnoreOnce[MAXPLAYERS + 1];

static const char
	g_sSurvivorNames[8][] =
	{
		"Nick",
		"Rochelle",
		"Coach",
		"Ellis",
		"Bill",
		"Zoey",
		"Francis",
		"Louis",
	},
	g_sSurvivorModels[8][] =
	{
		"models/survivors/survivor_gambler.mdl",
		"models/survivors/survivor_producer.mdl",
		"models/survivors/survivor_coach.mdl",
		"models/survivors/survivor_mechanic.mdl",
		"models/survivors/survivor_namvet.mdl",
		"models/survivors/survivor_teenangst.mdl",
		"models/survivors/survivor_biker.mdl",
		"models/survivors/survivor_manager.mdl"
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
	vLoadGameData();

	g_cClientID = new Cookie("Player_Character", "Player's default character ID.", CookieAccess_Protected);
	g_cClientModel = new Cookie("Player_Model", "Player's default character model.", CookieAccess_Protected);

	RegConsoleCmd("sm_zoey", cmdZoeyUse, "Changes your survivor character into Zoey");
	RegConsoleCmd("sm_nick", cmdNickUse, "Changes your survivor character into Nick");
	RegConsoleCmd("sm_ellis", cmdEllisUse, "Changes your survivor character into Ellis");
	RegConsoleCmd("sm_coach", cmdCoachUse, "Changes your survivor character into Coach");
	RegConsoleCmd("sm_rochelle", cmdRochelleUse, "Changes your survivor character into Rochelle");
	RegConsoleCmd("sm_bill", cmdBillUse, "Changes your survivor character into Bill");
	RegConsoleCmd("sm_francis", cmdBikerUse, "Changes your survivor character into Francis");
	RegConsoleCmd("sm_louis", cmdLouisUse, "Changes your survivor character into Louis");
/*
	RegConsoleCmd("sm_z", cmdZoeyUse, "Changes your survivor character into Zoey");
	RegConsoleCmd("sm_n", cmdNickUse, "Changes your survivor character into Nick");
	RegConsoleCmd("sm_e", cmdEllisUse, "Changes your survivor character into Ellis");
	RegConsoleCmd("sm_c", cmdCoachUse, "Changes your survivor character into Coach");
	RegConsoleCmd("sm_r", cmdRochelleUse, "Changes your survivor character into Rochelle");
	RegConsoleCmd("sm_b", cmdBillUse, "Changes your survivor character into Bill");
	RegConsoleCmd("sm_f", cmdBikerUse, "Changes your survivor character into Francis");
	RegConsoleCmd("sm_l", cmdLouisUse, "Changes your survivor character into Louis");
*/
	RegAdminCmd("sm_csc", cmdCsc, ADMFLAG_GENERIC, "Brings up a menu to select a client's character");
	RegConsoleCmd("sm_csm", cmdCsm, "Brings up a menu to select a client's character");
	RegConsoleCmd("sm_c", cmdCsm, "Brings up a menu to select a client's character");
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("bot_player_replace", Event_BotPlayerReplace);
	HookEvent("player_bot_replace", Event_PlayerBotReplace);
	HookEvent("player_spawn", Event_PlayerSpawn);

	g_hZoey = CreateConVar("l4d_scs_zoey", "1","Prop for Zoey. 0: Rochelle (windows), 1: Zoey (linux), 2: Nick (fakezoey)", FCVAR_NOTIFY,true, 0.0, true, 2.0);
	g_hCookies = CreateConVar("l4d_scs_cookies", "1","保存玩家的模型角色喜好?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hBotsChange = CreateConVar("l4d_scs_botschange", "1","开关8人独立模型?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hAdminsOnly = CreateConVar("l4d_csm_admins_only", "0","只允许管理员使用csm命令?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	g_hZoey.AddChangeHook(vConVarChanged);
	g_hCookies.AddChangeHook(vConVarChanged);
	g_hBotsChange.AddChangeHook(vConVarChanged);
	g_hAdminsOnly.AddChangeHook(vConVarChanged);

	TopMenu topmenu;
	if(LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);

	RegAdminCmd("sm_csmtest", cmdCsmTest, ADMFLAG_ROOT);
}

public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if(topmenu == hTopMenu)
		return;

	hTopMenu = topmenu;

	TopMenuObject player_commands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

	if(player_commands != INVALID_TOPMENUOBJECT)
		AddToTopMenu(hTopMenu, "Select player's survivor", TopMenuObject_Item, InitiateMenuAdmin2, player_commands, "Select player's survivor", ADMFLAG_GENERIC);
}

public void InitiateMenuAdmin2(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayOption)
		FormatEx(buffer, maxlength, "更改玩家人物模型", "", client);
	else if(action == TopMenuAction_SelectOption)
		cmdCsc(client, 0);
}

public Action cmdCsc(int client, int args)
{
	if(client == 0 || !IsClientInGame(client))
		return Plugin_Handled;

	char sUserId[16];
	char sName[MAX_NAME_LENGTH];

	Menu menu = new Menu(iCscMenuHandler);
	menu.SetTitle("目标玩家:");

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != 2)
			continue;

		FormatEx(sUserId, sizeof(sUserId), "%d", GetClientUserId(i));
		FormatEx(sName, sizeof(sName), "%N", i);
		menu.AddItem(sUserId, sName);
	}


	menu.ExitBackButton = true;
	menu.Display(client, 30);
	return Plugin_Handled;
}

public int iCscMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[16];
			if(menu.GetItem(param2, sItem, sizeof(sItem)))
			{
				g_iSelectedClient[client] = StringToInt(sItem);

				ShowMenuAdmin(client, 0);
			}
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
	Menu menu = new Menu(iShowMenuAdminMenuHandler);
	menu.SetTitle("人物:");

	menu.AddItem("0", "Nick");
	menu.AddItem("1", "Rochelle");
	menu.AddItem("2", "Coach");
	menu.AddItem("3", "Ellis");

	menu.AddItem("4", "Bill");
	menu.AddItem("5", "Zoey");
	menu.AddItem("6", "Francis");
	menu.AddItem("7", "Louis");

	menu.ExitBackButton = true;
	menu.Display(client, 30);
}

public int iShowMenuAdminMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(param2)
			{
				case 0:
					vSetCharacter(GetClientOfUserId(g_iSelectedClient[client]), NICK, false);
				case 1:
					vSetCharacter(GetClientOfUserId(g_iSelectedClient[client]), ROCHELLE, false);
				case 2:
					vSetCharacter(GetClientOfUserId(g_iSelectedClient[client]), COACH, false);
				case 3:
					vSetCharacter(GetClientOfUserId(g_iSelectedClient[client]), ELLIS, false);
				case 4:
					vSetCharacter(GetClientOfUserId(g_iSelectedClient[client]), BILL, false);
				case 5:
					vSetCharacter(GetClientOfUserId(g_iSelectedClient[client]), iGetZoeyProp(), 5, false);
				case 6:
					vSetCharacter(GetClientOfUserId(g_iSelectedClient[client]), FRANCIS, false);
				case 7:
					vSetCharacter(GetClientOfUserId(g_iSelectedClient[client]), LOUIS, false);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public Action cmdCsm(int client, int args)
{
	if(client == 0 || !IsClientInGame(client)) 
	{
		ReplyToCommand(client, "角色选择菜单仅在游戏中显示.");
		return Plugin_Handled;
	}

	if(GetClientTeam(client) != 2)
	{
		ReplyToCommand(client, "角色选择菜单仅适用于幸存者.");
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(client)) 
	{
		ReplyToCommand(client, "你必须活着才能使用角色选择菜单.");
		return Plugin_Handled;
	}

	if(g_bAdminsOnly && GetUserFlagBits(client) == 0)
	{
		ReplyToCommand(client, "只有管理员才能使用该菜单.");
		return Plugin_Handled;
	}

	Menu menu = new Menu(iCsmMenuHandler);
	menu.SetTitle("选择人物:");

	menu.AddItem("0", "Nick");
	menu.AddItem("1", "Rochelle");
	menu.AddItem("2", "Coach");
	menu.AddItem("3", "Ellis");

	menu.AddItem("4", "Bill");
	menu.AddItem("5", "Zoey");
	menu.AddItem("6", "Francis");
	menu.AddItem("7", "Louis");

	menu.ExitBackButton = true;
	menu.Display(client, 30);
	return Plugin_Handled;
}

public int iCsmMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(param2)
			{
				case 0:
					cmdNickUse(client, 0);
				case 1:
					cmdRochelleUse(client, 0);
				case 2:
					cmdCoachUse(client, 0);
				case 3:
					cmdEllisUse(client, 0);
				case 4:
					cmdBillUse(client, 0);
				case 5:
					cmdZoeyUse(client, 0);
				case 6:
					cmdBikerUse(client, 0);
				case 7:
					cmdLouisUse(client, 0);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

int iGetZoeyProp()
{
	if(g_iZoey == 2)
		return 0;
	else if(g_iZoey == 1)
		return 5;
	else
		return 1;
}

public Action cmdZoeyUse(int client, int args)
{
	vSetCharacter(client, iGetZoeyProp(), 5);
	return Plugin_Handled;
}

public Action cmdNickUse(int client, int args)
{
	vSetCharacter(client, NICK);
	return Plugin_Handled;
}

public Action cmdEllisUse(int client, int args)
{
	vSetCharacter(client, ELLIS);
	return Plugin_Handled;
}

public Action cmdCoachUse(int client, int args)
{
	vSetCharacter(client, COACH);
	return Plugin_Handled;
}

public Action cmdRochelleUse(int client, int args)
{
	vSetCharacter(client, ROCHELLE);
	return Plugin_Handled;
}

public Action cmdBillUse(int client, int args)
{
	vSetCharacter(client, BILL);
	return Plugin_Handled;
}

public Action cmdBikerUse(int client, int args)
{
	vSetCharacter(client, FRANCIS);
	return Plugin_Handled;
}

public Action cmdLouisUse(int client, int args)
{
	vSetCharacter(client, LOUIS);
	return Plugin_Handled;
}

public Action cmdCsmTest(int client, int args)
{
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	ChangeClientTeam(client, 2);
	return Plugin_Handled;
}

public void OnMapStart()
{
	static ConVar hConVar;
	if(hConVar == null)
		hConVar = FindConVar("precache_all_survivors");

	hConVar.IntValue = 1;

	for(int i; i < 8; i++)
		PrecacheModel(g_sSurvivorModels[i], true);
}

public void OnConfigsExecuted()
{
	vGetCvars();
}

public void vConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetCvars();
}

void vGetCvars()
{
	g_iZoey = g_hZoey.IntValue;
	g_bCookies = g_hCookies.BoolValue;
	g_bBotsChange= g_hBotsChange.BoolValue;
	g_bAdminsOnly = g_hAdminsOnly.BoolValue;
}

public void Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
	for(int i; i <= MaxClients; i++)
		g_bShouldIgnoreOnce[i] = false;
}

public void Event_BotPlayerReplace(Event event, char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	if(player == 0 || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != 2) 
		return;
	
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if(bot == 0 || !IsClientInGame(bot))
	{
		vSetLeastUsedCharacter(player);
		return;
	}

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
	
	if(g_bBotsChange && IsFakeClient(player))
	{
		vSetLeastUsedCharacter(bot);
		RequestFrame(OnNextFrame_ResetVar, bot);
		return;
	}
	
	g_bShouldIgnoreOnce[bot] = true;
	RequestFrame(OnNextFrame_ResetVar, bot);
}

void OnNextFrame_ResetVar(any iBot)
{
	g_bShouldIgnoreOnce[iBot] = false;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2)
		return;

	if(g_bBotsChange && !IsPlayerAlive(client))
		RequestFrame(OnNextFrame_PlayerSpawn, userid);

	if(g_bCookies)
		CreateTimer(0.6, Timer_LoadCookie, userid, TIMER_FLAG_NO_MAPCHANGE);
}

void OnNextFrame_PlayerSpawn(any client)
{
	if((client = GetClientOfUserId(client)) == 0 || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2 || IsPlayerAlive(client))
		return;

	if(g_bBotsChange && !g_bShouldIgnoreOnce[client])
		vSetLeastUsedCharacter(client);
}

public Action Timer_LoadCookie(Handle timer, any client)
{
	if((client = GetClientOfUserId(client)) == 0 || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2)
		return;

	if(!AreClientCookiesCached(client))
	{
		PrintToChat(client, "%s 无法载入你的人物角色,请输入 \x05!csm \x01来设置你的人物角色.", PLUGIN_PREFIX);
		return;
	}

	char sID[2];
	g_cClientID.Get(client, sID, sizeof(sID));

	char sModel[64];
	g_cClientModel.Get(client, sModel, sizeof(sModel));

	if(sID[0] != 0 && sModel[0] != 0)
	{
		SetEntProp(client, Prop_Send, "m_survivorCharacter", StringToInt(sID));
		SetEntityModel(client, sModel);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(g_bBotsChange == false)
		return;

	if(classname[0] != 's' && classname[0] != 'p')
		return;

	if(strcmp(classname, "survivor_bot") == 0 || strcmp(classname, "player") == 0)
		SDKHook(entity, SDKHook_SpawnPost, Hook_SpawnPost);
}

public void Hook_SpawnPost(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, Hook_SpawnPost);
	if(!IsValidEntity(entity) || GetClientTeam(entity) == 4)
		return;	

	RequestFrame(OnNextFrame_SpawnPost, GetClientUserId(entity));
}

void OnNextFrame_SpawnPost(any client)
{
	if((client = GetClientOfUserId(client)) == 0 || g_bShouldIgnoreOnce[client] || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	vSetLeastUsedCharacter(client);
}

int iCheckLeastUsedSurvivor(int client)
{
	int i;
	int iOwn;
	int iCharBuffer;
	int iLeastChar[8];
	for(i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != 2)
			continue;
		
		if((iCharBuffer = GetEntProp(i, Prop_Send, "m_survivorCharacter")) > 7)
			continue;

		if(i == client)
			iOwn = iCharBuffer;
		else
			iLeastChar[iCharBuffer]++;
	}

	switch(g_iOrignalMapSet)
	{
		case 1:
		{
			if(iOwn > 3 && iLeastChar[iOwn] == 0)
				iCharBuffer = 8;
			else
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
		}

		case 2:
		{
			if(iOwn < 4 && iLeastChar[iOwn] == 0)
				iCharBuffer = 8;
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
		}
	}

	return iCharBuffer;
}

void vSetLeastUsedCharacter(int client)
{
	switch(iCheckLeastUsedSurvivor(client))
	{
		case 0:
			vSetCharacterInfo(client, NICK);
		case 1:
			vSetCharacterInfo(client, ROCHELLE);
		case 2:
			vSetCharacterInfo(client, COACH);
		case 3:
			vSetCharacterInfo(client, ELLIS);
		case 4:
			vSetCharacterInfo(client, BILL);
		case 5:
			vSetCharacterInfo(client, iGetZoeyProp(), 5);
		case 6:
			vSetCharacterInfo(client, FRANCIS);
		case 7:
			vSetCharacterInfo(client, LOUIS);	
	}
}

void vSetCharacter(int client, int iCharIndex, int iModelIndex, bool bSave = true)
{
	if(client == 0 || !IsClientInGame(client))
		return;

	if(GetClientTeam(client) != 2)
	{
		PrintToChat(client, "只有幸存者才能使用该指令.");
		return;
	}

	if(bIsGettingUp(client))
	{
		PrintToChat(client, "起身过程中无法使用该指令.");
		return;
	}

	vSetCharacterInfo(client, iCharIndex, iModelIndex);

	if(bSave && g_bCookies)
	{
		char sProp[2];
		IntToString(iCharIndex, sProp, sizeof(sProp));
		g_cClientID.Set(client, sProp);
		g_cClientModel.Set(client, g_sSurvivorModels[iModelIndex]);
		PrintToChat(client, "%s 你的人物角色现在已经被设为 \x03%s\x01.", PLUGIN_PREFIX, g_sSurvivorNames[iModelIndex]);
	}
}

//https://github.com/LuxLuma/L4D2_Adrenaline_Recovery
static bool bIsGettingUp(int client)
{
	static char sModel[31];
	GetEntPropString(client, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	switch(sModel[29])
	{
		case 'b'://nick
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 680, 667, 671, 672, 630, 620, 627:
					return true;
			}
		}
		case 'd'://rochelle
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 687, 679, 678, 674, 638, 635, 629:
					return true;
			}
		}
		case 'c'://coach
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 669, 661, 660, 656, 630, 627, 621:
					return true;
			}
		}
		case 'h'://ellis
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 684, 676, 675, 671, 625, 635, 632:
					return true;
			}
		}
		case 'v'://bill
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 772, 764, 763, 759, 538, 535, 528:
					return true;
			}
		}
		case 'n'://zoey
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 824, 823, 819, 809, 547, 544, 537:
					return true;
			}
		}
		case 'e'://francis
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 775, 767, 766, 762, 541, 539, 531:
					return true;
			}
		}
		case 'a'://louis
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 772, 764, 763, 759, 538, 535, 528:
					return true;
			}
		}
		case 'w'://adawong
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 687, 679, 678, 674, 638, 635, 629:
					return true;
			}
		}
	}

	return false;
}

void vSetCharacterInfo(int client, int iCharIndex, int iModelIndex)
{
	if(GetEntProp(client, Prop_Send, "m_survivorCharacter") != iCharIndex)
		SetEntProp(client, Prop_Send, "m_survivorCharacter", iCharIndex);
	
	static char sModel[128];
	GetClientModel(client, sModel, sizeof(sModel));

	if(strcmp(sModel, g_sSurvivorModels[iModelIndex], false) != 0)
		SetEntityModel(client, g_sSurvivorModels[iModelIndex]);
	
	if(IsFakeClient(client))
		SetClientName(client, g_sSurvivorNames[iModelIndex]);
		
	vReEquipWeapons(client);
}

void vRemovePlayerWeapon(int client, int iSlot)
{
	RemovePlayerItem(client, iSlot);
	RemoveEntity(iSlot);
}

void vReEquipWeapons(int client)
{
	if(!IsPlayerAlive(client))
		return;

	int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(iActiveWeapon > MaxClients && IsValidEntity(iActiveWeapon))
	{
		int iWeaponInfo[MAXPLAYERS + 1][7];

		char sWeapon[32];
		int iSlot = GetPlayerWeaponSlot(client, 0);
		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));

			iWeaponInfo[client][0] = GetEntProp(iSlot, Prop_Send, "m_iClip1");
			iWeaponInfo[client][1] = iGetOrSetPlayerAmmo(client, sWeapon);
			iWeaponInfo[client][2] = GetEntProp(iSlot, Prop_Send, "m_upgradeBitVec");
			iWeaponInfo[client][3] = GetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
			iWeaponInfo[client][4] = GetEntProp(iSlot, Prop_Send, "m_nSkin");
		
			vRemovePlayerWeapon(client, iSlot);
		
			vCheatCommand(client, "give", sWeapon);

			iSlot = GetPlayerWeaponSlot(client, 0);
			if(iSlot > MaxClients)
			{
				SetEntProp(iSlot, Prop_Send, "m_iClip1", iWeaponInfo[client][0]);
				iGetOrSetPlayerAmmo(client, sWeapon, iWeaponInfo[client][1]);

				if(iWeaponInfo[client][2] > 0)
					SetEntProp(iSlot, Prop_Send, "m_upgradeBitVec", iWeaponInfo[client][2]);

				if(iWeaponInfo[client][3] > 0)
					SetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", iWeaponInfo[client][3]);
				
				if(iWeaponInfo[client][4] > 0)
					SetEntProp(iSlot, Prop_Send, "m_nSkin", iWeaponInfo[client][4]);
			}
		}

		iSlot = GetPlayerWeaponSlot(client, 1);
		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
			if(strcmp(sWeapon[7], "melee") == 0)
				GetEntPropString(iSlot, Prop_Data, "m_strMapSetScriptName", sWeapon, sizeof(sWeapon));
			else if(strcmp(sWeapon[7], "pistol") == 0 && GetEntProp(iSlot, Prop_Send, "m_isDualWielding") > 0)
				sWeapon = "v_dual_pistol";

			if(strncmp(sWeapon[7], "pistol", 6) == 0 || strcmp(sWeapon[7], "chainsaw") == 0)
				iWeaponInfo[client][5] = GetEntProp(iSlot, Prop_Send, "m_iClip1");

			iWeaponInfo[client][6] = GetEntProp(iSlot, Prop_Send, "m_nSkin");
		
			vRemovePlayerWeapon(client, iSlot);
		
			if(strcmp(sWeapon, "v_dual_pistol") == 0)
			{
				vCheatCommand(client, "give", "weapon_pistol");
				vCheatCommand(client, "give", "weapon_pistol");
			}
			else
				vCheatCommand(client, "give", sWeapon);

			iSlot = GetPlayerWeaponSlot(client, 1);
			if(iSlot > MaxClients)
			{
				if(iWeaponInfo[client][5] != -1)
					SetEntProp(iSlot, Prop_Send, "m_iClip1", iWeaponInfo[client][5]);
				
				if(iWeaponInfo[client][6] > 0)
					SetEntProp(iSlot, Prop_Send, "m_nSkin", iWeaponInfo[client][6]);
			}
		}

		iSlot = GetPlayerWeaponSlot(client, 2);
		if(iSlot > MaxClients)
		{
			GetClientWeapon(client, sWeapon, sizeof(sWeapon));
			if(strcmp(sWeapon, "weapon_vomitjar") != 0 && strcmp(sWeapon, "weapon_pipe_bomb") != 0 && strcmp(sWeapon, "weapon_molotov") != 0)
			{
				GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
				vRemovePlayerWeapon(client, iSlot);
				vCheatCommand(client, "give", sWeapon);
			}
		}

		iSlot = GetPlayerWeaponSlot(client, 3);
		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
			vRemovePlayerWeapon(client, iSlot);
			vCheatCommand(client, "give", sWeapon);
		}

		iSlot = GetPlayerWeaponSlot(client, 4);
		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
			vRemovePlayerWeapon(client, iSlot);
			vCheatCommand(client, "give", sWeapon);
		}
		
		GetEntityClassname(iActiveWeapon, sWeapon, sizeof(sWeapon));
		FakeClientCommand(client, "use %s", sWeapon);
	}
}

void vCheatCommand(int client, const char[] sCommand, const char[] sArguments = "")
{
	static int iFlagBits, iCmdFlags;
	iFlagBits = GetUserFlagBits(client);
	iCmdFlags = GetCommandFlags(sCommand);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(sCommand, iCmdFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", sCommand, sArguments);
	SetUserFlagBits(client, iFlagBits);
	SetCommandFlags(sCommand, iCmdFlags);
}

int iGetOrSetPlayerAmmo(int client, const char[] sWeapon, int iAmmo = -1)
{
	static StringMap aWeaponOffsets;
	if(aWeaponOffsets == null)
		aWeaponOffsets = aInitWeaponOffsets(aWeaponOffsets);
		
	static int iOffsetAmmo;
	if(iOffsetAmmo < 1)
		iOffsetAmmo = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");

	int offset;
	aWeaponOffsets.GetValue(sWeapon, offset);

	if(offset)
	{
		if(iAmmo != -1)
			SetEntData(client, iOffsetAmmo + offset, iAmmo);
		else
			return GetEntData(client, iOffsetAmmo + offset);
	}

	return 0;
}

StringMap aInitWeaponOffsets(StringMap aWeaponOffsets)
{
	aWeaponOffsets = new StringMap();
	aWeaponOffsets.SetValue("weapon_rifle", 12);
	aWeaponOffsets.SetValue("weapon_smg", 20);
	aWeaponOffsets.SetValue("weapon_pumpshotgun", 28);
	aWeaponOffsets.SetValue("weapon_shotgun_chrome", 28);
	aWeaponOffsets.SetValue("weapon_autoshotgun", 32);
	aWeaponOffsets.SetValue("weapon_hunting_rifle", 36);
	aWeaponOffsets.SetValue("weapon_rifle_sg552", 12);
	aWeaponOffsets.SetValue("weapon_rifle_desert", 12);
	aWeaponOffsets.SetValue("weapon_rifle_ak47", 12);
	aWeaponOffsets.SetValue("weapon_smg_silenced", 20);
	aWeaponOffsets.SetValue("weapon_smg_mp5", 20);
	aWeaponOffsets.SetValue("weapon_shotgun_spas", 32);
	aWeaponOffsets.SetValue("weapon_sniper_scout", 40);
	aWeaponOffsets.SetValue("weapon_sniper_military", 40);
	aWeaponOffsets.SetValue("weapon_sniper_awp", 40);
	aWeaponOffsets.SetValue("weapon_rifle_m60", 24);
	aWeaponOffsets.SetValue("weapon_grenade_launcher", 68);
	return aWeaponOffsets;
}

void vLoadGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false) 
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null) 
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	vSetupDetours(hGameData);

	delete hGameData;
}

void vSetupDetours(GameData hGameData = null)
{
	DynamicDetour dDetour;
	dDetour = DynamicDetour.FromConf(hGameData, "CTerrorGameRules::GetSurvivorSet");
	if(dDetour == null)
		SetFailState("Failed to load 'CTerrorGameRules::GetSurvivorSet' signature.");
		
	if(!dDetour.Enable(Hook_Post, mreGetSurvivorSetPost))
		SetFailState("Failed to detour post 'CTerrorGameRules::GetSurvivorSet'.");
}

//https://forums.alliedmods.net/showthread.php?t=309601
public MRESReturn mreGetSurvivorSetPost(DHookReturn hReturn)
{
	g_iOrignalMapSet = hReturn.Value;

	if(g_bBotsChange)
	{
		hReturn.Value = 2;
		return MRES_Supercede;
	}

	return MRES_Ignored;
}