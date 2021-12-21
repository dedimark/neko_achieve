#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>

Handle witch_health;

bool TankSpawnFinaleVehicleLeaving;

ConVar tank_hp, tank_hp_prompt, setting_tank_hp, witch_hp, witch_max, witch_min;

public Plugin myinfo = 
{
	name = "L4D2 Tank Announcer",
	author = "Visor",
	description = "Announce in chat and via a sound when a Tank has spawned",
	version = "1.0",
	url = "https://github.com/Attano"
};

public void OnPluginStart()
{
	witch_health		= FindConVar("z_witch_health");
	tank_hp			= CreateConVar("l4d2_enabled_tank", "1", "启用坦克出现时血量跟随存活的幸存者人数而增加? 0=禁用, 1=启用.");
	tank_hp_prompt		= CreateConVar("l4d2_enabled_tank_prompt", "2", "设置坦克出现时的提示类型. 0=禁用, 1=聊天窗, 2=屏幕中下+聊天窗, 3=屏幕中下.");
	setting_tank_hp	= CreateConVar("l4d2_enabled_tank_health", "2500", "设置每一个活着的幸存者坦克所增加的血量(坦克总血量*当前难度的值,简单*0.8,普通*1.0,高级*1.5,专家*2.0).");
	witch_hp			= CreateConVar("l4d2_enabled_witch_appear", "1", "启用女巫出现时血量随机?(聊天窗) 0=禁用, 1=启用随机, 2=启用随机(禁用提示), 3=固定为随机的最低血量(女巫的默认血量为1000).");
	witch_max			= CreateConVar("l4d2_enabled_witch_maximum", "1500", "女巫出现时随机的最高血量.");
	witch_min			= CreateConVar("l4d2_enabled_witch_minimum", "800", "女巫出现时随机的最低血量.");
	
	HookEvent("round_start", Event_RoundStart);//回合开始.
	HookEvent("round_end", Event_RoundEnd);//回合结束.
	HookEvent("witch_spawn", Event_WitchSpawn, EventHookMode_Pre);
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving, EventHookMode_Pre);//救援离开.
	
	AutoExecConfig(true, "l4d2_tank_announce");//生成指定文件名的CFG.
}

//地图结束.
public void OnMapEnd()
{
	TankSpawnFinaleVehicleLeaving = false;
}

//回合结束.
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	TankSpawnFinaleVehicleLeaving = false;
}

//回合开始.
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	TankSpawnFinaleVehicleLeaving = false;
}

//救援离开时.
public void Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast)
{
	TankSpawnFinaleVehicleLeaving = true;
}

public void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (TankSpawnFinaleVehicleLeaving)
		return;
	
	if (GetConVarInt(witch_hp) != 0 && GetConVarInt(witch_hp) <= 2)
	{
		int health = 0;
		if (GetConVarInt(witch_min) >= GetConVarInt(witch_max))
			health = GetConVarInt(witch_min);
		else health = GetRandomInt(GetConVarInt(witch_min), GetConVarInt(witch_max));
		SetConVarFlags(witch_health, GetConVarFlags(witch_health) & ~FCVAR_NOTIFY);
		SetConVarInt(witch_health, health);
		if (GetConVarInt(witch_hp) != 2)
			PrintToChatAll("\x04[提示]\x03女巫\x05出现,血量随机为\x04:\x03%d", GetConVarInt(witch_health));//聊天窗提示.
	}
	else if (GetConVarInt(witch_hp) == 3)
	{
		int health = GetConVarInt(witch_min);
		SetConVarFlags(witch_health, GetConVarFlags(witch_health) & ~FCVAR_NOTIFY);
		SetConVarInt(witch_health, health);
		if (GetConVarInt(witch_hp) != 2)
			PrintToChatAll("\x04[提示]\x03女巫\x05出现,血量为\x04:\x03%d", GetConVarInt(witch_health));//聊天窗提示.
	}
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (GetConVarInt(tank_hp) != 0 && GetConVarInt(tank_hp) == 1)
	{
		if (TankSpawnFinaleVehicleLeaving)
			return;
		
		int client = GetClientOfUserId(event.GetInt("userid"));
		
		if (client)
		{
			char difficulty[32];
			GetConVarString(FindConVar("z_difficulty"), difficulty, sizeof(difficulty));
			char slName1[32];
			FormatEx(slName1, sizeof(slName1), "%N", client);
			SplitString(slName1, "Tank", slName1, sizeof(slName1));
			
			if (StrEqual(difficulty, "Easy", false))
			{
				int health = RoundFloat(0.8 * (CountPlayersTeam() * GetConVarInt(setting_tank_hp)));
				SetEntProp(client, Prop_Data, "m_iMaxHealth", health);
				SetEntProp(client, Prop_Data, "m_iHealth", health);
				
				if (StrEqual(slName1, "DummyBot", false) || StrEqual(slName1, "DummyBot(1)", false))
					return;
					
				if(GetConVarInt(tank_hp_prompt) != 0)
				{
					if(GetConVarInt(tank_hp_prompt) == 1 || GetConVarInt(tank_hp_prompt) == 2)
					{
						PrintToChatAll("\x04[提示]\x03坦克%s\x05出现\x04,\x05难度\x04:\x03简单\x04,\x05存活\x03%d\x05名幸存者,血量调整为\x04:\x03%d", slName1, CountPlayersTeam(), GetClientHealth(GetClientOfUserId(GetEventInt(event,"userid"))));//聊天窗提示.
					}
					if(GetConVarInt(tank_hp_prompt) == 2 || GetConVarInt(tank_hp_prompt) == 3)
					{
						PrintHintTextToAll("[提示]坦克%s出现,难度:简单,存活%d名幸存者,血量调整为:%i", slName1, CountPlayersTeam(), GetClientHealth(GetClientOfUserId(GetEventInt(event,"userid"))));//屏幕中下提示.
					}
				}
			}
			else if (StrEqual(difficulty, "Normal", false))
			{
				int health = RoundFloat(1.0 * (CountPlayersTeam() * GetConVarInt(setting_tank_hp)));
				SetEntProp(client, Prop_Data, "m_iMaxHealth", health);
				SetEntProp(client, Prop_Data, "m_iHealth", health);
				
				if (StrEqual(slName1, "DummyBot", false) || StrEqual(slName1, "DummyBot(1)", false))
					return;
					
				if(GetConVarInt(tank_hp_prompt) != 0)
				{
					if(GetConVarInt(tank_hp_prompt) == 1 || GetConVarInt(tank_hp_prompt) == 2)
					{
						PrintToChatAll("\x04[提示]\x03坦克%s\x05出现\x04,\x05难度\x04:\x03普通\x04,\x05存活\x03%d\x05名幸存者,血量调整为\x04:\x03%d", slName1, CountPlayersTeam(), GetClientHealth(GetClientOfUserId(GetEventInt(event,"userid"))));//聊天窗提示.
					}
					if(GetConVarInt(tank_hp_prompt) == 2 || GetConVarInt(tank_hp_prompt) == 3)
					{
						PrintHintTextToAll("[提示]坦克%s出现,难度:普通,存活%d名幸存者,血量调整为:%i", slName1, CountPlayersTeam(), GetClientHealth(GetClientOfUserId(GetEventInt(event,"userid"))));//屏幕中下提示.
					}
				}
			}
			else if (StrEqual(difficulty, "Hard", false))
			{
				int health = RoundFloat(1.5 * (CountPlayersTeam() * GetConVarInt(setting_tank_hp)));
				SetEntProp(client, Prop_Data, "m_iMaxHealth", health);
				SetEntProp(client, Prop_Data, "m_iHealth", health);
				
				if (StrEqual(slName1, "DummyBot", false) || StrEqual(slName1, "DummyBot(1)", false))
					return;
					
				if(GetConVarInt(tank_hp_prompt) != 0)
				{
					if(GetConVarInt(tank_hp_prompt) == 1 || GetConVarInt(tank_hp_prompt) == 2)
					{
						PrintToChatAll("\x04[提示]\x03坦克%s\x05出现\x04,\x05难度\x04:\x03高级\x04,\x05存活\x03%d\x05名幸存者,血量调整为\x04:\x03%d", slName1, CountPlayersTeam(), GetClientHealth(GetClientOfUserId(GetEventInt(event,"userid"))));//聊天窗提示.
					}
					if(GetConVarInt(tank_hp_prompt) == 2 || GetConVarInt(tank_hp_prompt) == 3)
					{
						PrintHintTextToAll("[提示]坦克%s出现,难度:高级,存活%d名幸存者,血量调整为:%i", slName1, CountPlayersTeam(), GetClientHealth(GetClientOfUserId(GetEventInt(event,"userid"))));//屏幕中下提示.
					}
				}
			}
			else if (StrEqual(difficulty, "Impossible", false))
			{
				int health = RoundFloat(2.0 * (CountPlayersTeam() * GetConVarInt(setting_tank_hp)));
				SetEntProp(client, Prop_Data, "m_iMaxHealth", health);
				SetEntProp(client, Prop_Data, "m_iHealth", health);
				
				if (StrEqual(slName1, "DummyBot", false) || StrEqual(slName1, "DummyBot(1)", false))
					return;
					
				if(GetConVarInt(tank_hp_prompt) != 0)
				{
					if(GetConVarInt(tank_hp_prompt) == 1 || GetConVarInt(tank_hp_prompt) == 2)
					{
						PrintToChatAll("\x04[提示]\x03坦克%s\x05出现\x04,\x05难度\x04:\x03专家\x04,\x05存活\x03%d\x05名幸存者,血量调整为\x04:\x03%d", slName1, CountPlayersTeam(), GetClientHealth(GetClientOfUserId(GetEventInt(event,"userid"))));//聊天窗提示.
					}
					if(GetConVarInt(tank_hp_prompt) == 2 || GetConVarInt(tank_hp_prompt) == 3)
					{
						PrintHintTextToAll("[提示]坦克%s出现,难度:专家 ,存活%d名幸存者,血量调整为:%i", slName1, CountPlayersTeam(), GetClientHealth(GetClientOfUserId(GetEventInt(event,"userid"))));//屏幕中下提示.
					}
				}
			}
		}
	}
}

int CountPlayersTeam()
{
	int Count = 0;
	for (int i=1;i<=MaxClients;i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
		{
			Count++;
		}
	}
	return Count;
}