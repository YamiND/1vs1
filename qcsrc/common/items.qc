// WEAPON PLUGIN SYSTEM
entity weapon_info[24];
entity dummy_weapon_info;

string weapon_modelname(string wname)
{
	string model_replacement;
	model_replacement = cvar_string(strcat("sv_model_", wname));
	if (model_replacement == "")
	{
		model_replacement = wname;
	}
	return model_replacement;
};

void register_weapon_real(float id, float(float) func, float ammotype, float i, float normalweapon, float canclimb, float weapontype, float pickupbasevalue, string modelname, string shortname, string wname, vector wcolor)
{
	entity e;
#ifdef SVQC
	e = weapon_info[id - 1];
	if (e) {
		strunzone(e.model);
		strunzone(e.mdl);
		remove(e);
	}
#endif
	weapon_info[id - 1] = e = spawn();
	e.classname = "weapon_info";
	e.weapon = id;
	e.weapons = pow(2, id - 1);
	e.netname = shortname;
	e.message = wname;
	e.items = ammotype;
#ifndef MENUQC
	e.colormod = wcolor;
#endif
#ifdef SVQC
	e.weapon_func = func;
	e.model = strzone(strcat("models/weapons/g_", weapon_modelname(modelname), ".md3"));
	e.mdl = strzone(weapon_modelname(modelname));

	float animfile;
	string animfilename = strcat("models/weapons/h_", e.mdl, ".dpm.animinfo");
	animfile = fopen(animfilename, FILE_READ);
	// preset some defaults that work great for renamed zym files (which don't need an animinfo)
	e.anim_fire1  = '0 1 0.01';
	e.anim_fire2  = '1 1 0.01';
	e.anim_idle   = '2 1 0.01';
	e.anim_reload = '3 1 0.01';
	if (animfile >= 0)
	{
		anim_parseerror = FALSE;
		e.anim_fire1  = anim_parseline(animfile);
		e.anim_fire2  = anim_parseline(animfile);
		e.anim_idle   = anim_parseline(animfile);
		e.anim_reload = anim_parseline(animfile);
		fclose(animfile);
		if (anim_parseerror)
			print("Parse error in ", animfilename, ", some player animations are broken\n");
	}
#endif
	e.spawnflags = 0;
	e.model2 = strzone(strcat("wpn-", e.mdl));
	if(normalweapon > 0)
		e.spawnflags |= WEPSPAWNFLAG_NORMAL;
	if(normalweapon < 0)
		e.spawnflags |= WEPSPAWNFLAG_HIDDEN;
	if(canclimb)
		e.spawnflags |= WEPSPAWNFLAG_CANCLIMB;
	e.impulse = i;
	e.weapon_type = weapontype;
	e.bot_pickupbasevalue = pickupbasevalue;
}
float w_null(float dummy)
{
	return 0;
}
void register_weapons_done()
{
	entity wi;
	dummy_weapon_info = spawn();
	dummy_weapon_info.classname = "weapon_info";
	dummy_weapon_info.weapon = 0; // you can recognize dummies by this
	dummy_weapon_info.weapons = 0; // you can recognize dummies by this too
	dummy_weapon_info.netname = "@!#%'n Tuba";
	dummy_weapon_info.items = 0;
	dummy_weapon_info.weapon_func = w_null;
	dummy_weapon_info.mdl = "";
	dummy_weapon_info.model = "";
	dummy_weapon_info.spawnflags = 0;
	dummy_weapon_info.impulse = -1;
	dummy_weapon_info.weapon_type = WEP_TYPE_OTHER;
	dummy_weapon_info.bot_pickupbasevalue = 0;
	dummy_weapon_info.model2 = "";

	float i;
	weaponpriority_hudselector_0 = "";
	for(i = 24; i >= 1; --i)
		if(weapon_info[i-1])
			weaponpriority_hudselector_0 = strcat(weaponpriority_hudselector_0, " ", ftos(i));

	float imp;
	weaponpriority_hudselector_1 = "";
	for(i = 1; i <= 24; ++i)
	{
		wi = weapon_info[i-1];
		if(wi && wi.impulse == 0)
			weaponpriority_hudselector_1 = strcat(weaponpriority_hudselector_1, " ", ftos(i));
	}
	for(imp = 9; imp > 0; --imp)
		for(i = 1; i <= 24; ++i)
		{
			wi = weapon_info[i-1];
			if(wi && wi.impulse == imp)
				weaponpriority_hudselector_1 = strcat(weaponpriority_hudselector_1, " ", ftos(i));
		}

	weaponpriority_hudselector_0 = strzone(substring(weaponpriority_hudselector_0, 1, strlen(weaponpriority_hudselector_0) - 1));
	weaponpriority_hudselector_1 = strzone(substring(weaponpriority_hudselector_1, 1, strlen(weaponpriority_hudselector_1) - 1));
}
entity get_weaponinfo(float id)
{
	entity w;
	if(id < WEP_FIRST || id > WEP_LAST)
		return dummy_weapon_info;
	w = weapon_info[id - 1];
	if(w)
		return w;
	return dummy_weapon_info;
}
#ifndef CSQC
string W_FixWeaponOrder(string order, float complete)
{
	return fixPriorityList(order, WEP_FIRST, WEP_LAST, 230 - WEP_FIRST, complete);
}
#endif

#ifdef SVQC
#define register_weapon(id,func,ammotype,i,normalweapon,canclimb,weapontype,pickupbasevalue,modelname,shortname,wname,wclr) \
	register_weapon_real(id,func,ammotype,i,normalweapon,canclimb,weapontype,pickupbasevalue,modelname,shortname,wname,wclr)
#else
// no weapon funcs here!
#define register_weapon(id,func,ammotype,i,normalweapon,canclimb,weapontype,pickupbasevalue,modelname,shortname,wname,wclr) \
	register_weapon_real(id,w_null,ammotype,i,normalweapon,canclimb,weapontype,pickupbasevalue,modelname,shortname,wname,wclr)
#endif

void RegisterWeapons()
{
	// %weaponaddpoint
	register_weapon(WEP_LASER,            w_laser,        0,                1,  1, 1, WEP_TYPE_SPLASH,  0,                      "laser",        "laser",           "Laser",                      '1 0.75 0.5');
	register_weapon(WEP_SHOTGUN,          w_shotgun,      IT_SHELLS,        2,  1, 0, WEP_TYPE_HITSCAN, BOT_PICKUP_RATING_LOW,  "shotgun",      "shotgun",         "Shotgun",                    '0.5 0.5 0');
	register_weapon(WEP_UZI,              w_uzi,          IT_NAILS,         3,  1, 0, WEP_TYPE_HITSCAN, BOT_PICKUP_RATING_MID,  "uzi",          "uzi",             "Machine Gun",                '1 1 0.0');
	register_weapon(WEP_GRENADE_LAUNCHER, w_glauncher,    IT_ROCKETS,       4,  1, 1, WEP_TYPE_SPLASH , BOT_PICKUP_RATING_MID,  "gl",           "grenadelauncher", "Mortar",                     '1 0.5 0.5');
	register_weapon(WEP_ELECTRO,          w_electro,      IT_CELLS,         5,  1, 0, WEP_TYPE_SPLASH , BOT_PICKUP_RATING_MID,  "electro",      "electro",         "Electro",                    '0.5 0.5 1');
	register_weapon(WEP_CRYLINK,          w_crylink,      IT_CELLS,         6,  1, 0, WEP_TYPE_SPLASH , BOT_PICKUP_RATING_MID,  "crylink",      "crylink",         "Crylink",                    '1 0.5 1');
	register_weapon(WEP_NEX,              w_nex,          IT_CELLS,         7,  1, 0, WEP_TYPE_HITSCAN, BOT_PICKUP_RATING_HIGH, "nex",          "nex",             "Nex",                        '0.5 1 1');
	register_weapon(WEP_HAGAR,            w_hagar,        IT_ROCKETS,       8,  1, 1, WEP_TYPE_SPLASH , BOT_PICKUP_RATING_MID,  "hagar",        "hagar",           "Hagar",                      '0.5 1 0');
	register_weapon(WEP_ROCKET_LAUNCHER,  w_rlauncher,    IT_ROCKETS,       9,  1, 1, WEP_TYPE_SPLASH , BOT_PICKUP_RATING_HIGH, "rl",           "rocketlauncher",  "Rocket Launcher",            '1 1 0.5');
	register_weapon(WEP_PORTO,            w_porto,        0,                0,  0, 0, WEP_TYPE_OTHER,   0,                      "porto" ,       "porto",           "Port-O-Launch",              '0.25 0.25 0.25');
	register_weapon(WEP_MINSTANEX,        w_minstanex,    IT_CELLS,         7, -1, 1, WEP_TYPE_HITSCAN, BOT_PICKUP_RATING_HIGH, "minstanex",    "minstanex",       "MinstaNex",                  '0.5 1 1');
	register_weapon(WEP_HOOK,             w_hook,         IT_CELLS,         0,  0, 1, WEP_TYPE_SPLASH,  0,                      "hookgun",      "hook",            "Grappling Hook",             '0.25 0.5 0.25');
	register_weapon(WEP_HLAC,             w_hlac,         IT_CELLS,         6,  1, 0, WEP_TYPE_SPLASH,  BOT_PICKUP_RATING_MID,  "hlac",         "hlac",            "Heavy Laser Assault Cannon", '0.5 1 0.5');
	register_weapon(WEP_TUBA,             w_tuba,         0,                1, -1, 0, WEP_TYPE_SPLASH,  BOT_PICKUP_RATING_MID,  "tuba",         "tuba",            "@!#%'n Tuba",                '1 1 1');
	register_weapon(WEP_CAMPINGRIFLE,     w_campingrifle, IT_NAILS,         3,  1, 0, WEP_TYPE_HITSCAN, BOT_PICKUP_RATING_MID,  "campingrifle", "campingrifle",    "Rifle",                      '0.75 1 0');
	register_weapon(WEP_FIREBALL,         w_fireball,     IT_ROCKETS,       9,  1, 0, WEP_TYPE_SPLASH,  BOT_PICKUP_RATING_MID,  "fireball",     "fireball",        "Fireball",                   '1 0.5 0');
	register_weapon(WEP_SUPERSHOTGUN,     w_supershotgun, IT_SHELLS,        8,  1, 0, WEP_TYPE_HITSCAN, BOT_PICKUP_RATING_MID,  "supershotgun", "supershotgun",    "SuperShotgun",               '0.75 0.25 0');
	register_weapon(WEP_ZAPPER,           w_zapper,       IT_CELLS,         5,  1, 0, WEP_TYPE_HITSCAN, BOT_PICKUP_RATING_MID,  "zapper",       "zapper",          "Zapper",                     '0.5 0.5 1');
	register_weapon(WEP_MELEE,            w_melee,        0,                1,  1, 0, WEP_TYPE_HITSCAN, BOT_PICKUP_RATING_MID,  "axe",          "axe",             "Axe",                        '1 0.75 0.5');

#ifdef SVQC
	if not(dummy_weapon_info)
#endif
		register_weapons_done();
}
