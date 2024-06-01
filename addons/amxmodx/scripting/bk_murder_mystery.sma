#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <cstrike>
#include <fun>
#include <hamsandwich>

#define PLUGIN "[BK] Murder Mystery"
#define VERSION "1.2"
#define AUTHOR "Berk"

#define FFADE_IN 0x0000 // Just here so we don't pass 0 into the function
#define FFADE_OUT 0x0001 // Fade out (not in)
#define FFADE_MODULATE 0x0002 // Modulate (don't blend)
#define FFADE_STAYOUT 0x0004 // ignores the duration, stays faded out until //new ScreenFade message received

#define AIMINFO 630

#define set_user_freeze(%0) { set_pev( %0 , pev_flags , pev( %0 , pev_flags ) | FL_FROZEN ); }
#define set_user_unfreeze(%0) { set_pev( %0 , pev_flags , pev( %0 , pev_flags ) & ~FL_FROZEN ); }

enum {
	INNOCENT = 0,
	SHERIFF = 1,
	MURDER = 2
}

new const class_names[][] =
{
	"Innocent",
	"Sheriff",
	"Murder",
}

new const a_class_names[][] =
{
	"innocent",
	"sheriff",
	"murder",
}

new const class_model[][] =
{
	"v_innocent.mdl",
	"v_sheriff.mdl",
	"v_murder.mdl"
}

new const Float:class_speeds[] =
{
	250.0,
	265.0,
	275.0
}

new class[33]
new Float:boost[33]
new countdown
new Float:fstart_time_round, Float:ftime_round, time_round, round_started;
new inammo[33]

stock gname(id) { new name[64]; get_user_name(id, name, charsmax(name)); return name; }

public plugin_cfg()
{
	server_cmd("humans_join_team ct")
	server_cmd("mp_auto_join_team 1")
	server_cmd("mp_buytime 0")
	server_cmd("mp_freeforall 1")
	server_cmd("mp_friendlyfire 1")
	server_cmd("mp_roundtime 3.8")
	server_cmd("mp_freezetime 2.5")
	server_cmd("mp_autoteambalance 0")
	server_cmd("mp_maxmoney 0")
	server_cmd("mp_limitteams 0")
	server_cmd("sv_restart 5")
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	time_round = get_cvar_pointer("mp_roundtime");
	
	register_event("HLTV", "fw_newround", "a", "1=0", "2=0");
	register_logevent("fw_endround", 2, "1=Round_End") 
	register_event("TextMsg", "fw_restartround", "a", "2&#Game_C", "2&#Game_w");
	register_event("DeathMsg", "fw_playerkilled", "a")
	
	register_event("StatusValue", "fw_aiminfo_show", "be", "1=2", "2!0")
	register_event("StatusValue", "fw_aiminfo_hide", "be", "1=1", "2=0")
	
	register_forward( FM_ClientKill, "fw_cmdkill" );
	
	register_clcmd("drop", "fw_cmddrop")
	register_clcmd("chooseteam", "fw_cmdteam")
	register_clcmd("jointeam", "fw_cmdjoin")
	
	RegisterHam(Ham_Spawn, "player", "fw_playerspawn", 1)
	RegisterHam(Ham_TakeDamage, "player", "fw_playerdamage", 0)
	RegisterHam(Ham_Touch, "weaponbox", "fw_touchitem")
	RegisterHam(Ham_Touch, "armoury_entity", "fw_touchitem")
	RegisterHam(Ham_Touch, "weapon_shield", "fw_touchitem")
	RegisterHam( Ham_BloodColor, "player", "fw_bloodcolor" )
	RegisterHam(Ham_Killed, "player", "fw_hamkill")
	
	register_message(get_user_msgid("DeathMsg"), "death_event");
}

public death_event(msg_id,msg_dest,msg_entity)
{
	if(msg_id == get_user_msgid("DeathMsg"))
	{
		return PLUGIN_HANDLED;
	}
}

fw_deathmsg(attacker, victim, killname[])
{
	new args[3]
	args[0] = attacker
	args[1] = victim
	args[2] = get_user_weapon(attacker)
	
	set_task(0.2, "fw_deathmsg2", 0, args)
}

public fw_deathmsg2(args[])
{
	new weapname[32];
	get_weaponname(args[2], weapname, 31)
	replace(weapname, charsmax(weapname), "weapon_", "")
	
	message_begin(MSG_BROADCAST, get_user_msgid("DeathMsg"))
	write_byte(args[0]) // killer
	write_byte(args[1]) // victim
	write_byte(2) // headshot flag
	write_string(weapname) // killer's weapon
	message_end()
}

public plugin_precache()
{
	event_hltv()
	
	precache_sound("innocents_win.wav")
	precache_sound("murders_win.wav")
	
	precache_sound("role_youare.wav")
	precache_sound("role_innocent.wav")
	precache_sound("role_sheriff.wav")
	precache_sound("role_murder.wav")
	
	precache_sound("20_seconds.wav")
	precache_sound("starting_1.wav")
	precache_sound("starting_2.wav")
	precache_sound("starting_3.wav")
	precache_sound("punch.wav")
	
	precache_model("models/player/sheriff/sheriff.mdl")
	precache_model("models/player/innocent/innocent.mdl")
	
	new model[64]
	formatex(model, charsmax(model), "models/%s", class_model[0]); precache_model(model);
	formatex(model, charsmax(model), "models/%s", class_model[1]); precache_model(model);
	formatex(model, charsmax(model), "models/%s", class_model[2]); precache_model(model);
}

public fw_aiminfo_show(id)
{
	new target = read_data(2);
	
	new r,g,b;
		
	if(class[target] == INNOCENT)
	{
		r = 50; g = 255; b = 50;
	}
			
	if(class[target] == SHERIFF)
	{
		r = 50; g = 255; b = 255;
	}
			
	if(class[target] == MURDER)
	{
		r = 50; g = 255; b = 50;
	}
		
	set_hudmessage(r,g,b, -1.0, 0.65, 0, 0.0, 4.0, 0.0, 0.0, 4)
	show_hudmessage(id, "%s - Role: %s", gname(target), class[target] == MURDER ? "Innocent" : class_names[class[target]])
}

public fw_aiminfo_hide(id)
{
	set_hudmessage(0,0,0, -1.0, 0.65, 0, 0.0, 0.0, 0.0, 0.0, 4)
	show_hudmessage(id, "")
}

public fw_hamkill(id, killer)
{
	if(get_user_weapon(killer) == CSW_DEAGLE && killer != id)
		SetHamParamInteger(3, 2)
}

public fw_touchitem(ent, id)
{
	if(class[id] == MURDER || !is_user_alive(id))
	{
		return HAM_SUPERCEDE;
	}
}

public fw_cmdkill(id)
{
	client_print(id, print_chat, "^^0[^^2BK^^0] ^^7You can not kill yourself")
	return FMRES_SUPERCEDE;
	return FMRES_IGNORED;
}

public fw_cmddrop(id)
{
	if(class[id] != INNOCENT || !round_started)
	{
		return PLUGIN_HANDLED;
	}
	
	if(get_playersclass(SHERIFF) >= 1)
	{
		client_print(id, print_chat, "^^0[^^2BK^^0] ^^7You can not to buy deagle, because still alive sheriff")
		return PLUGIN_HANDLED;
	}
	
	if(get_playersweapon(CSW_DEAGLE) >= 1 && !(user_has_weapon(id, CSW_DEAGLE)))
	{
		client_print(id, print_chat, "^^0[^^2BK^^0] ^^7You can not to buy deagle, because someone has a deagle")
		return PLUGIN_HANDLED;
	}
	
	new money = cs_get_user_money(id)
	
	if(!(user_has_weapon(id, CSW_DEAGLE)))
	{
		if(money < 10)
		{
			client_print(id, print_chat, "^^0[^^2BK^^0] ^^7$%d required to buy deagle", 10-money)
		}
		else
		{
			client_print(id, print_chat, "^^0[^^2BK^^0] ^^7you bought deagle")
			inammo[id] = 2; set_item(id, "weapon_deagle", 1, 1);
			cs_set_user_money(id, money-10)
			remove_entity_by_classname("armoury_entity")
		}
	}
	else
	{
		if(money < 5)
		{
			client_print(id, print_chat, "^^0[^^2BK^^0] ^^7$%d required to buy deagle ammo", 5-money)
		}
		else
		{
			client_print(id, print_chat, "^^0[^^2BK^^0] ^^7you bought deagle ammo")
			inammo[id] = 3
			cs_set_user_money(id, money-5)
		}
	}
	
	return PLUGIN_HANDLED;
}

public set_item(id, weapon[], clip, ammo)
{
	give_item(id, weapon)
	give_clip(id, clip, weapon)
	give_ammo(id, ammo, weapon)
}
	
public fw_cmdjoin(id)
{
	new argv[32]
	read_argv(1, argv, charsmax(argv))
	
	if((equal(argv, "01")) || (equal(argv, "1")))
	{
		client_print(id, print_chat, "^^0[^^2BK^^0] ^^7You can only join CT or SPEC")
		return PLUGIN_HANDLED;
	}
	
	if(cs_get_user_team(id) != CS_TEAM_SPECTATOR && !is_user_alive(id))
	{
		client_print(id, print_chat, "^^0[^^2BK^^0] ^^7You can only use Die or Spectator")
		return PLUGIN_HANDLED;
	}
}

public fw_cmdteam(id)
{
	client_print(id, print_chat, "^^0[^^2BK^^0] ^^7You can not change team")
	return PLUGIN_HANDLED;
}

public fw_playerspawn(id)
{
	set_task(0.1000, "fw_setuser", id)
}

public fw_setuser(id)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return;
		
	remove_task(id)
	
	set_task(0.1, "fw_hud", id)
	
	cs_set_user_armor(id, 200, CS_ARMOR_VESTHELM)
	set_user_class(id, INNOCENT)
	engclient_cmd(id, "weapon_knife")
	inammo[id] = 5
	boost[id] = 0.0
}

public fw_bloodcolor ( const Client )
{
	SetHamReturnInteger(-1);
	return HAM_SUPERCEDE;
}

public fw_playerdamage(victim, inflictor, attacker, Float:damage, damagebits)
{
	if(!round_started)
		return HAM_SUPERCEDE;
		
	if(attacker == victim)
		return HAM_SUPERCEDE;
		
	if(class[attacker] == INNOCENT && class[victim] == INNOCENT || class[attacker] == INNOCENT && class[victim] == SHERIFF || class[attacker] == INNOCENT && class[victim] == MURDER && get_user_weapon(attacker) == CSW_KNIFE)
		return HAM_SUPERCEDE;
	
	if(class[attacker] == SHERIFF || class[attacker] == INNOCENT && get_user_weapon(attacker) == CSW_DEAGLE)
	{
		SetHamParamFloat(4, 1000.0)
	}
	
	if(class[attacker] == MURDER)
	{
		SetHamParamFloat(4, 1000.0)
		boost[attacker] += class[victim] == SHERIFF ? 8.50 : 2.50;
	}
}

public fw_playerkilled()
{
	new killer = read_data(1);
	new victim = read_data(2);
	
	if(killer == victim)
		return;
	
	client_print(0, print_chat, "^^0[^^2MM^^0]^^7 %s^^7(%s) was killed by %s^^7(%s)", gname(victim), class_names[class[victim]], class[killer] == MURDER ? "^^0#" : gname(killer), class_names[class[killer]])
	
	if(class[killer] == class[victim] || class[killer] == SHERIFF && class[victim] == INNOCENT)
	{
		user_kill(killer, 1)
	}
}

public client_PreThink(id)
{
	if(is_user_alive(id))
	{
		set_pev(id, pev_punchangle, {0.0,0.0,0.0})
		
		if(get_user_weapon(id) == CSW_KNIFE && class[id] == MURDER)
		{
			new model[64]; formatex(model, charsmax(model), "models/%s", class_model[MURDER])
			set_pev(id, pev_viewmodel2, model)
		}
		
		if(get_user_weapon(id) == CSW_KNIFE && class[id] == INNOCENT)
		{
			new model[64]; formatex(model, charsmax(model), "models/%s", class_model[INNOCENT])
			set_pev(id, pev_viewmodel2, model)
		}
		
		if(get_user_weapon(id) == CSW_DEAGLE)
		{
			new model[64]; formatex(model, charsmax(model), "models/%s", class_model[SHERIFF])
			set_pev(id, pev_viewmodel2, model)
		}
		
		new clip, ammo
		
		if(class[id] != MURDER)
		{
			set_pev(id, pev_maxspeed, class_speeds[class[id]])
		}
		else
		{
			set_pev(id, pev_maxspeed, class_speeds[class[id]]+boost[id])
		}
		
		if(class[id] == SHERIFF)
		{
			if(user_has_weapon(id, CSW_DEAGLE))
			{
				get_user_ammo(id, get_weaponid("weapon_deagle"), clip, ammo)
				
				if(ammo < 1)
				{
					give_ammo(id, 1, "weapon_deagle")
				}
				
				if(clip > 1)
				{
					give_clip(id, 1, "weapon_deagle")
				}
			}
		}
		
		if(class[id] == INNOCENT)
		{
			if(user_has_weapon(id, CSW_DEAGLE))
			{
				get_user_ammo(id, get_weaponid("weapon_deagle"), clip, ammo)
				
				if(ammo < 1 && inammo[id] > 0)
				{
					give_ammo(id, 1, "weapon_deagle")
					inammo[id] -= 1
				}
			}
		}
	}
}

public fw_hud(id)
{
	if(!is_user_alive(id))
		return;
		
	set_task(0.1, "fw_hud", id)
	new clip, ammo
	
	if(user_has_weapon(id, CSW_DEAGLE))
	{
		get_user_ammo(id, get_weaponid("weapon_deagle"), clip, ammo)
	}
	
	if(round_started)
	{
		set_hudmessage(160, 160, 160, -1.0, 0.02, 0, 0.0, 1.5, 0.0, 0.0, 3)
		show_hudmessage(id, "[ Murder Mystery ]^n| Sheriff %d - Innocent %d - Murder %d |", get_playersclass(SHERIFF), get_playersclass(INNOCENT), get_playersclass(MURDER))

		new r,g,b;
		
		if(class[id] == INNOCENT)
		{
			r = 50; g = 255; b = 50;
		}
			
		if(class[id] == SHERIFF)
		{
			r = 50; g = 255; b = 255;
		}
			
		if(class[id] == MURDER)
		{
			r = 255; g = 50; b = 50;
		}
			
		set_hudmessage(r, g, b, 0.02, 0.90, 0, 0.0, 1.5, 0.0, 0.0, 2)
		
		if(class[id] == INNOCENT) 
		{ 
			if(user_has_weapon(id, CSW_DEAGLE)) 
			{ 
				show_hudmessage(id, "Role: %s | Ammo: %d/%d%s", class_names[class[id]], clip, inammo[id], cs_get_user_money(id) >= 5 ? " | Buy Ammo | Press G/Drop" : ""); 
			}
			else
			{ 
				show_hudmessage(id, "Role: %s%s", class_names[class[id]], cs_get_user_money(id) >= 10 ? " | Buy Deagle | Press G/Drop" : ""); 
			}
		}
		
		if(class[id] == SHERIFF) 
		{
			show_hudmessage(id, "Role: %s | Ammo: %d/%d", class_names[class[id]], clip, ammo);
		}
		
		if(class[id] == MURDER)
		{
			show_hudmessage(id, "Role: %s | Boost: +%0.2f", class_names[class[id]], boost[id]);
		}
	}
	else
	{
		set_hudmessage(g_players() < 3 ? 255 : 120, g_players() < 3 ? 30 : 120, g_players() < 3 ? 30 : 120, -1.0, 0.02, 0, 0.0, 1.5, 0.0, 0.0, 3)
		show_hudmessage(id, "[ Murder Mystery ]^n| %s |", g_players() < 3 ? "There are not enough players for the start of the round" : "The round is expected to start.")
	}
}

public event_hltv()
{
    remove_entity_by_classname("func_breakable")
    remove_entity_by_classname("hostage_entity")
    remove_entity_by_classname("func_hostage_rescue")
    remove_entity_by_classname("func_escapezone")
    remove_entity_by_classname("func_buyzone")
    remove_entity_by_classname("scientist_entity")
    remove_entity_by_classname("func_door_rotating")
    remove_entity_by_classname("func_door")
    remove_entity_by_classname("func_bomb_target")
    remove_entity_by_classname("info_bomb_target")
    remove_entity_by_classname("func_vip_start")
    remove_entity_by_classname("func_vip_safteyzone")
    remove_entity_by_classname("armoury_entity")
}

public fw_newround()
{
	event_hltv()
	
	remove_task(111111); set_task(1.0, "fw_startround", 111111,_,_,"b");
	remove_task(101010); set_task(0.01, "fw_roundtime", 101010,_,_,"b");
	
	countdown = 20
	ftime_round = floatmul(get_pcvar_float(time_round), 60.0) - 1.0
    fstart_time_round = get_gametime()
}

public fw_roundtime()
{
	if(round_started)
	{
		if(get_playersclass(INNOCENT) <= 0 && get_playersclass(SHERIFF) <= 0)
		{
			winround(MURDER)
		}
		else if(get_playersclass(MURDER) <= 0)
		{
			winround(INNOCENT)
		}
	}
	
    static szTime[6]; format_time(szTime, 5, "%M:%S", floatround(ftime_round - (get_gametime() - fstart_time_round), floatround_ceil));
    if(equal(szTime, "00:00"))
	{
        if(round_started)
		{
        	winround(INNOCENT)
        }
    }
} 

public fw_startround()
{
	if(countdown > 0 && g_players() >= 3)
	{
		if(countdown == 20)
		{
			client_cmd(0, "spk sound/20_seconds.wav")
			set_task(1.45, "fw_music", 6329)
		}
		
		client_print(0, print_center, "[ Murder Mystery ]^nStarting %d seconds after", countdown)
		countdown -= 1
		client_cmd(0, "spk sound/punch.wav")
	}
	
	if(countdown == 1)
	{
		for(new i = 0;i < get_maxplayers(); i++)
		{
			if(is_user_alive(i))
			{
				if(g_players() >= 3)
				{
					set_user_freeze(i)
					screenfade(i, 0, 0, 0, 255, FFADE_OUT, 1, 6.0)
					set_hudmessage(255, 255, 255, -1.0, 0.35, 0, 1.5, 0.05, 0.0, 0.75, 1)
					show_hudmessage(i, "|- - You are - -|^n? ? ? ? ?")
					client_cmd(i, "spk sound/role_youare.wav")
				}
			}
		}
	}
	
	if(countdown == 0)
	{
		if(g_players() >= 3)
		{
			remove_task(111111)
			set_task(0.1, "fw_distribute", 64829,_,_,"b")
		}
	}
}

public fw_music()
{
	client_cmd(0, "spk sound/starting_%d.wav", random_num(1,3))
}

public fw_distribute()
{
	new players[33]; new playersnum
	for(new i = 0; i < get_maxplayers();i++)
	{
		if(is_user_alive(i) && is_user_connected(i))
		{
			if(class[i] == INNOCENT)
			{
				players[playersnum] = i
				playersnum++;
			}
		}
	}
	
	new randint = random(playersnum);
	
	if(get_playersclass(SHERIFF) < 1)
	{
		if(class[players[randint]] == INNOCENT)
		{
			set_user_class(players[randint], SHERIFF)
		}
	}
	
	if(get_playersclass(MURDER) < 1)
	{
		if(class[players[randint]] == INNOCENT)
		{
			set_user_class(players[randint], MURDER)
		}
	}
	
	if(get_playersclass(MURDER) >= 1 && get_playersclass(SHERIFF) >= 1)
	{
		remove_task(64829)
		round_started = 1;
		client_print(0, print_chat, "^^0[^^2MM^^0]^^7 [ Innocent %d | Sheriff %d | Murder %d ]", get_playersclass(INNOCENT), get_playersclass(SHERIFF), get_playersclass(MURDER))
		fw_sendclass()
	}
}

public fw_sendclass()
{
	for(new i = 0;i < get_maxplayers(); i++)
	{
		if(is_user_alive(i))
		{
			new c[3]
			
			if(class[i] == INNOCENT) {
				c[0] = 50; c[1] = 255; c[2] = 50; }
				
			if(class[i] == SHERIFF) {
				c[0] = 50; c[1] = 255; c[2] = 255; }
				
			if(class[i] == MURDER) {
				c[0] = 255; c[1] = 50; c[2] = 50; }
				
			set_hudmessage(c[0], c[1], c[2], -1.0, 0.35, 0, 0.0, 2.5, 0.0, 0.5, 1)
			show_hudmessage(i, "|- - You are - -|^n%s", class_names[class[i]])
			
			client_cmd(i, "spk sound/role_%s.wav", a_class_names[class[i]])
			set_task(0.55, "fw_fadeout", i)
		}
	}
}

public fw_unfreeze(id)
{
	set_user_unfreeze(id)
}

public fw_fadeout(id)
{
	screenfade(id, 0, 0, 0, 255, FFADE_IN, 1, 1.0)
	set_task(1.35, "fw_unfreeze", id)
	if(class[id] == INNOCENT)
		set_task(5.00, "fw_coin", id)
}

public fw_coin(id)
{
	if(round_started)
	{
		if(!is_user_alive(id))
			return;
		
		if(cs_get_user_money(id) < 10)
		{
			cs_set_user_money(id, cs_get_user_money(id) + 1)
			client_cmd(id, "spk sound/punch.wav")
		}
		
		set_task(11.50, "fw_coin", id)
	}
}

public screenfade(id, red, green, blue, alpha, type, durabilty, Float:seconds)
{
    message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("ScreenFade"), _, id)
    write_short((1<<12)*durabilty)
    write_short(floatround((1<<12)*seconds))
    write_short(type)
    write_byte (red)
    write_byte (green)
    write_byte (blue)
    write_byte (alpha)
    message_end()
} 

public fw_endround()
{
	round_started = 0
	remove_task(64829); remove_task(101010); remove_task(111111);
}

public fw_restartround()
{
	round_started = 0
	remove_task(64829); remove_task(101010); remove_task(111111);
}

public g_players()
{
	new count; for(new i = 0;i < get_maxplayers(); i++)
	{
		if(is_user_alive(i) && is_user_connected(i))
		{
			count++
		}
	}
	
	return count;
}

public stripuser(id)
{
	engclient_cmd(id, "weapon_knife")
	strip_user_weapons(id)
}

public set_user_class(id, classid)
{
	class[id] = classid
	
	if(is_user_connected(id) && cs_get_user_team(id) != CS_TEAM_SPECTATOR && cs_get_user_team(id) != CS_TEAM_UNASSIGNED)
	{
		cs_set_user_team(id, CS_TEAM_CT)
	}
	
	if(is_user_alive(id) && is_user_connected(id)) 
	{
		stripuser(id)
		
		if(classid == SHERIFF)
		{
			give_item(id, "weapon_deagle")
			give_clip(id, 1, "weapon_deagle")
			give_ammo(id, 1, "weapon_deagle")
			cs_set_user_model(id, "sheriff")
		}
		
		if(classid == MURDER)
		{
			give_item(id, "weapon_knife")
			set_pev(id, pev_weaponmodel2, "")
			cs_set_user_model(id, "innocent")
		}
		
		if(classid == INNOCENT)
		{
			give_item(id, "weapon_knife")
			set_pev(id, pev_weaponmodel2, "")
			cs_set_user_model(id, "innocent")
		}
	}
}

public give_clip(id, clip, weapon_name[])
{
	new ent = find_ent_by_owner(-1, weapon_name, id)
	set_pdata_int(ent, 51, clip, 4);
}

public give_ammo(id, ammo, weapon_name[])
{
	if(user_has_weapon(id, get_weaponid(weapon_name))) cs_set_user_bpammo(id, get_weaponid(weapon_name), ammo)
}

public get_playersclass(classid)
{
	new cnum
	
	for(new i = 0;i < get_maxplayers();i++)
	{
		if(is_user_alive(i) && is_user_connected(i))
		{
			if(class[i] == classid)
			{
				cnum++
			}
		}
	}
	
	return cnum;
}

public get_playersweapon(wId)
{
	new cnum
	
	for(new i = 0;i < get_maxplayers();i++)
	{
		if(is_user_alive(i) && is_user_connected(i))
		{
			if(user_has_weapon(i, wId))
			{
				cnum++
			}
		}
	}
	
	return cnum;
}

public winround(classid)
{
	for(new i = 0;i < get_maxplayers();i++)
	{
		if(is_user_alive(i) && is_user_connected(i))
		{
			stripuser(i);
		}
	}
	
	server_cmd("endround")
	set_task(0.0250, "sendround", classid)
}

public sendround(classid)
{
	client_cmd(0, "stopsound")
	client_cmd(0, "spk sound/%s", classid == MURDER ? "murders_win.wav" : "innocents_win.wav")
	
	round_started = 0
	
	for(new i = 0; i < 8; i++)
	{
		if(classid == INNOCENT)
			client_print(0, print_center, "Innocent's win")
		
		if(classid == MURDER)
			client_print(0, print_center, "Murder's win")
	}
}

stock remove_entity_by_classname(const classname[])
{
    new ent = -1
    while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", classname)))
    {
        if(pev(ent, pev_spawnflags) != 1)
        {
            engfunc(EngFunc_RemoveEntity, ent)
        }
    }
}