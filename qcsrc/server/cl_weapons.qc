void W_Reload()
{
	if not(GameHook_ReloadAllowed())
		return;

	if(self.switchweapon == self.weapon)
	if(self.weaponentity.state == WS_READY)
	{
		if (W_Melee_Possible())
			W_Melee_Attack_Check();
		else
			weapon_action(self.weapon, WR_RELOAD);
	}
	entity oldself = self;
	self = Akimbo_Ghost(self);
	if (self)
	if (self != oldself)
		W_Reload();
	self = oldself;
}

// switch between weapons
void W_SwitchWeapon(float imp)
{
	if (self.switchweapon != imp) {
		if (client_hasweapon(self, imp, TRUE, TRUE))
			W_SwitchWeapon_Force(self, imp);
		else
			W_ShowWeaponList(self);
	}
};

.float weaponcomplainindex;
float W_GetCycleWeapon(entity pl, string weaponorder, float dir, float imp, float complain)
{
	float n, i, weaponwant, first_valid, prev_valid, switchtonext, switchtolast, c;
	n = tokenize_console(weaponorder);
	switchtonext = switchtolast = 0;
	first_valid = prev_valid = 0;
	if(dir == 0)
		switchtonext = 1;

	c = 0;

	for(i = 0; i < n; ++i)
	{
		weaponwant = stof(argv(i));
		if(imp >= 0)
			if((get_weaponinfo(weaponwant)).impulse != imp)
				continue;

		++c;

		if(client_hasweapon(pl, weaponwant, TRUE, FALSE))
		{
			if(switchtonext)
				return weaponwant;
			if(!first_valid)
				first_valid = weaponwant;
			if(weaponwant == pl.switchweapon)
			{
				if(dir >= 0)
					switchtonext = 1;
				else if(prev_valid)
					return prev_valid;
				else
					switchtolast = 1;
			}
			prev_valid = weaponwant;
		} else
			W_ShowWeaponList(pl);
	}
	if(first_valid)
	{
		if(switchtolast)
			return prev_valid;
		else
			return first_valid;
	}
	// complain (but only for one weapon on the button that has been pressed)
	if(complain)
	{
		self.weaponcomplainindex += 1;
		c = mod(self.weaponcomplainindex, c) + 1;
		for(i = 0; i < n; ++i)
		{
			weaponwant = stof(argv(i));
			if(imp >= 0)
				if((get_weaponinfo(weaponwant)).impulse != imp)
					continue;

			--c;
			if(c == 0)
			{
				client_hasweapon(pl, weaponwant, TRUE, TRUE);
				break;
			}
		}
	}
	return 0;
}

void W_CycleWeapon(string weaponorder, float dir)
{
	float w;
	w = W_GetCycleWeapon(self, weaponorder, dir, -1, 1);
	if(w > 0)
		W_SwitchWeapon(w);
}

void W_NextWeaponOnImpulse(float imp)
{
	float w;
	w = W_GetCycleWeapon(self, self.cvar_cl_weaponpriority, +1, imp, 1);
	if(w > 0)
		W_SwitchWeapon(w);
}

// next weapon
void W_NextWeapon(float list)
{
	if(list == 0)
		W_CycleWeapon(weaponpriority_hudselector_0, -1);
	else if(list == 1)
		W_CycleWeapon(weaponpriority_hudselector_1, -1);
	else if(list == 2)
		W_CycleWeapon(self.cvar_cl_weaponpriority, -1);
}

// prev weapon
void W_PreviousWeapon(float list)
{
	if(list == 0)
		W_CycleWeapon(weaponpriority_hudselector_0, +1);
	else if(list == 1)
		W_CycleWeapon(weaponpriority_hudselector_1, +1);
	else if(list == 2)
		W_CycleWeapon(self.cvar_cl_weaponpriority, +1);
}

string W_FixWeaponOrder_AllowIncomplete(string order)
{
	return W_FixWeaponOrder(order, 0);
}

string W_FixWeaponOrder_ForceComplete(string order)
{
	if(order == "")
		order = cvar_string("cl_weaponpriority");
	return W_FixWeaponOrder(order, 1);
}

float w_getbestweapon(entity e)
{
	return W_GetCycleWeapon(e, e.cvar_cl_weaponpriority, 0, -1, 0);
};

// generic weapons table
// TODO should they be macros instead?
float weapon_action(float wpn, float wrequest)
{
	return (get_weaponinfo(wpn)).weapon_func(wrequest);
};

string W_Name(float weaponid)
{
	return (get_weaponinfo(weaponid)).message;
}

float W_WeaponBit(float wpn)
{
	return (get_weaponinfo(wpn)).weapons;
}

float W_AmmoItemCode(float wpn)
{
	return (get_weaponinfo(wpn)).items;
}

void thrown_wep_think()
{
	self.solid = SOLID_TRIGGER;
	self.owner = world;
	SUB_SetFade(self, time + 20, 1);
}

// returns amount of ammo used as string, or -1 for failure, or 0 for no ammo count
string W_ThrowNewWeapon(entity own, float wpn, float doreduce, vector org, vector velo)
{
	entity oldself, wep;
	float wa, thisammo, i, j;
	string s;
	var .float ammofield;

	wep = spawn();

	setorigin(wep, org);
	wep.classname = "droppedweapon";
	wep.velocity = velo;
	wep.owner = wep.enemy = own;
	wep.flags |= FL_TOSSED;
	wep.colormap = own.colormap;

	wa = W_AmmoItemCode(wpn);
	if(wa == IT_SUPERWEAPON || wa == 0)
	{
		oldself = self;
		self = wep;
		weapon_defaultspawnfunc(wpn);
		self = oldself;
		if(startitem_failed)
			return string_null;
		wep.think = thrown_wep_think;
		wep.nextthink = time + 0.5;
		return "";
	}
	else
	{
		s = "";
		oldself = self;
		self = wep;
		weapon_defaultspawnfunc(wpn);
		self = oldself;
		if(startitem_failed)
			return string_null;
		if(doreduce)
		{
			for(i = 0, j = 1; i < 24; ++i, j *= 2)
			{
				if(wa & j)
				{
					ammofield = Item_CounterField(j);
					thisammo = min(own.ammofield, wep.ammofield);
					wep.ammofield = thisammo;
					own.ammofield -= thisammo;
					s = strcat(s, " and ", ftos(thisammo), " ", Item_CounterFieldName(j));
				}
			}
			s = substring(s, 5, -1);
		}
		wep.think = thrown_wep_think;
		wep.nextthink = time + 0.5;
		return s;
	}
}

float W_IsWeaponThrowable(float w)
{
	float wb, wa;
	wb = W_WeaponBit(w);
	if(!wb)
		return 0;
	wa = W_AmmoItemCode(w);
	if(start_weapons & wb)
	{
		if(wa == IT_SUPERWEAPON && start_items & IT_UNLIMITED_SUPERWEAPONS)
			return 0;
		if(wa != IT_SUPERWEAPON && start_items & IT_UNLIMITED_WEAPON_AMMO)
			return 0;
		// start weapons that take no ammo can't be dropped (this prevents dropping the laser, as long as it continues to use no ammo)
		if(wa == 0)
			return 0;
	}

	return 1;
}

// toss current weapon
void W_ThrowWeapon(vector velo, vector delta, float doreduce)
{
	local float w, wb;
	string a;

	w = self.weapon;
	if (w == 0)
		return; // just in case
	if not(GameHookChain_ThrowWeaponAllowed(doreduce))
		return;
	wb = W_WeaponBit(w);
	float akimbo_throw = Akimbo_Throw(wb);
	if not(akimbo_throw) {
		if not(g_pickup_items)
			return;
		if not(g_pickup_weapons)
			return;
		if(!W_IsWeaponThrowable(w))
			return;
	}

	if(self.weapons & wb != wb)
		return;

	if not(akimbo_throw) {
		self.weapons &~= wb;
		W_SwitchWeapon_Force(self, w_getbestweapon(self));
	}
	a = W_ThrowNewWeapon(self, w, doreduce, self.origin + delta, velo);
	if not(a)
		return;
	if(self.health >= 1)
	{
		if(a == "")
			sprint(self, strcat("You dropped the ^2", W_Name(w), "\n"));
		else
			sprint(self, strcat("You dropped the ^2", W_Name(w), " with ", a, "\n"));
	}
};

// Bringed back weapon frame
void W_WeaponFrame()
{
	vector fo, ri, up;

	makevectors(self.v_angle);
	if (GameHook_WeaponFrameHandle())
		return;
	if (!self.weaponentity || self.health < 1)
		return; // Dead player can't use weapons and injure impulse commands

	if(!self.switchweapon)
	{
		self.weapon = 0;
		self.weaponentity.state = WS_CLEAR;
		self.weaponname = "";
		self.items &~= IT_AMMO;
		return;
	}

	fo = v_forward; // save them in case the weapon think functions change it
	ri = v_right;
	up = v_up;

	// Change weapon
	if (self.weapon != self.switchweapon)
	{
		if (!g_balance_weaponswitchdelay)
		{
			if (Akimbo_Active(self) > 1)
			if not(Akimbo_HaveWeapon(self, self.switchweapon))
				return;
			weapon_action(self.weapon, WR_CLEAR);
			weapon_action(self.switchweapon, WR_SETUP);
			weapon_thinkf(WFRAME_IDLE, 0, w_ready);
		} else if (self.weaponentity.state == WS_CLEAR)
		{
			anim_set(self, self.anim_draw, FALSE, TRUE, TRUE);
			self.weaponentity.state = WS_RAISE;
			weapon_action(self.weapon, WR_CLEAR);
			weapon_action(self.switchweapon, WR_SETUP);
			// VorteX: add player model weapon select frame here
			// setcustomframe(PlayerWeaponRaise);
			weapon_thinkf(WFRAME_IDLE, g_balance_weaponswitchdelay, w_ready);
		}
		else if (self.weaponentity.state == WS_READY)
		{
#ifndef INDEPENDENT_ATTACK_FINISHED
			if(ATTACK_FINISHED(self) <= time + frametime * 0.5)
			{
#endif
			weapon_action(self.weapon, WR_CLEAR);
			// UGLY WORKAROUND: play this on CHAN_WEAPON2 so it can't cut off fire sounds
			sound (self, CHAN_WEAPON2, "weapons/weapon_switch.wav", VOL_BASE, ATTN_NORM);
			self.weaponentity.state = WS_DROP;
			// set up weapon switch think in the future, and start drop anim
			weapon_thinkf(WFRAME_DONTCHANGE, g_balance_weaponswitchdelay, w_clear);
#ifndef INDEPENDENT_ATTACK_FINISHED
			}
#endif
		}
	}

	float wb;
	wb = W_WeaponBit(self.weapon);

	// call the think code which may fire the weapon
	// and do so multiple times to resolve framerate dependency issues if the
	// server framerate is very low and the weapon fire rate very high
	local float c;
	c = 0;
	while (c < 5)
	{
		c = c + 1;
		if(wb && ((self.weapons & wb) == 0))
		{
			W_SwitchWeapon_Force(self, w_getbestweapon(self));
			wb = 0;
		}
		if(wb)
		{
			v_forward = fo;
			v_right = ri;
			v_up = up;
			if (self.bot_melee)
				W_Melee_Attack_Check();
			else
				weapon_action(self.weapon, WR_THINK);
		}
		if (time + frametime * 0.5 >= self.weapon_nextthink)
		{
			if(self.weapon_think)
			{
				v_forward = fo;
				v_right = ri;
				v_up = up;
				self.weapon_think();
			}
			else
				bprint("\{1}^1ERROR: undefined weapon think function for ", self.netname, "\n");
		}
	}

	// don't let attack_finished fall behind when not firing (must be after weapon_setup calls!)
	//if (ATTACK_FINISHED(self) < time)
	//	ATTACK_FINISHED(self) = time;

	//if (self.weapon_nextthink < time)
	//	self.weapon_nextthink = time;

	// update currentammo incase it has changed
#if 0
	if (self.items & IT_CELLS)
		self.currentammo = self.ammo_cells;
	else if (self.items & IT_ROCKETS)
		self.currentammo = self.ammo_rockets;
	else if (self.items & IT_NAILS)
		self.currentammo = self.ammo_nails;
	else if (self.items & IT_SHELLS)
		self.currentammo = self.ammo_shells;
	else
		self.currentammo = 1;
#endif
}
