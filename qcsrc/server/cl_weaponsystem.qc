/*
===========================================================================

  CLIENT WEAPONSYSTEM CODE
  Bring back W_Weaponframe

===========================================================================
*/

float g_balance_weaponswitchdelay;
float g_showweaponspawns;
float g_projectiles_newton_style_2_maxfactor;
float g_projectiles_newton_style_2_minfactor;
float g_weaponratefactor;
vector sv_qcanimation_melee_morph1angles;
vector sv_qcanimation_melee_morph2angles;
vector sv_qcanimation_melee_morph1origin;
vector sv_qcanimation_melee_morph2origin;
vector sv_qcanimation_melee2_morph1angles;
vector sv_qcanimation_melee2_morph2angles;
vector sv_qcanimation_melee2_morph1origin;
vector sv_qcanimation_melee2_morph2origin;
float sv_qcweaponanimation;
float g_akimbo_use_left_hand;
float g_shootfromcenter;
float g_shootfromclient;
float g_shootfromeye;

vector weapon_offset = '0 -10 0';
vector weapon_adjust = '10 0 -15';

.vector shotorg_visual;
.vector weapon_morph0origin;
.vector weapon_morph0angles;
.float  weapon_morph0time;
.vector weapon_morph1origin;
.vector weapon_morph1angles;
.float  weapon_morph1time;
.vector weapon_morph2origin;
.vector weapon_morph2angles;
.float  weapon_morph2time;
.vector weapon_morph3origin;
.vector weapon_morph3angles;
.float  weapon_morph3time;
.vector weapon_morph4origin;
.vector weapon_morph4angles;
.float  weapon_morph4time;

void(float fr, float t, void() func) weapon_thinkf;

#define QCWEAPONANIMATION_ORIGIN(e) (sv_qcweaponanimation ?  ((weapon_offset_x + e.view_ofs_x) * v_forward - (weapon_offset_y + e.view_ofs_y) * v_right + (weapon_offset_z + e.view_ofs_z) * v_up + weapon_adjust) : e.view_ofs)

vector shotorg_adjustfromclient(vector vecs, float y_is_right, float allowcenter)
{
	switch(self.owner.cvar_cl_gunalign)
	{
		case 1: // right
			break;

		case 2: // left
			vecs_y = -vecs_y;
			break;

		default:
		case 3:
			if(allowcenter) // 2: allow center handedness
			{
				// center
				vecs_y = 0;
				vecs_z -= 4;
			}
			else
			{
				// right
			}
			break;

		case 4:
			if(allowcenter) // 2: allow center handedness
			{
				// center
				vecs_y = 0;
				vecs_z -= 4;
			}
			else
			{
				// left
				vecs_y = -vecs_y;
			}
			break;
	}
	return vecs;
}

vector shotorg_adjust(vector vecs, float y_is_right, float visual, float akimbo_active)
{
	if (akimbo_active)
	{
		if (akimbo_active == 2)
			vecs_y = -vecs_y;
		if not(visual)
		{
			if (g_shootfromeye)
				vecs_z = 0;
			else if (g_shootfromcenter)
				vecs_z -= 4;
		}
		vecs_y = vecs_y * 1.2;
		return vecs;
	}

	if (g_shootfromeye)
	{
		if (visual)
		{
			vecs = shotorg_adjustfromclient(vecs, y_is_right, TRUE);
		}
		else
		{
			vecs_y = 0;
			vecs_z = 0;
		}
	}
	else if (g_shootfromcenter)
	{
		if (visual)
		{
			vecs = shotorg_adjustfromclient(vecs, y_is_right, TRUE);
		}
		else
		{
			vecs_y = 0;
			vecs_z -= 4;
		}
	}
	else if (g_shootfromclient)
	{
		vecs = shotorg_adjustfromclient(vecs, y_is_right, (g_shootfromclient >= 2));
	}
	return vecs;
}

float W_WeaponRateFactor()
{
	float t;
	entity oldself = self;
	self = Akimbo_Owner(self);
	t = (1.0 / g_weaponratefactor) * GameHookChain_WeaponRateFactor();
	self = oldself;
	return t;
}

float W_WeaponRateFactorFor(entity o)
{
	entity oldself = self;
	self = o;
	float f = W_WeaponRateFactor();
	self = oldself;
	return f;
}

void W_SwitchWeapon_Force(entity e, float w)
{
	W_ShowWeaponList(self);
	e.cnt = e.switchweapon;
	e.switchweapon = w;
}


// this function calculates w_shotorg and w_shotdir based on the weapon model
// offset, trueaim and antilag, and won't put w_shotorg inside a wall.
// make sure you call makevectors first (FIXME?)
.float lastshot_time;
void W_SetupShot_Dir(entity ent, vector s_forward, float recoil, string snd, float maxhits)
{
	vector vecs, vecs_visual, dv;
	entity ent_orig = ent;
	ent = Akimbo_Owner(ent);
	// Track max damage and set the stat to be sent later in g_world.qc
	if (maxhits > 0)
		Damage_RecordFires(ent, ent.weapon, maxhits);

	if(ent_orig.weaponentity.movedir_x > 0)
	{
		vecs = ent_orig.weaponentity.movedir;
		vecs_y = -vecs_y;
	}
	else
		vecs = '0 0 0';
	vecs_visual = ent_orig.weaponentity.shotorg_visual;
	vecs_visual_y = -vecs_visual_y;

	dv = v_right * vecs_y + v_up * vecs_z;
	w_shotorg = ent.origin + ent.view_ofs;

	w_shotorg_visual = w_shotorg + (v_right * vecs_visual_y + v_up * vecs_visual_z) + v_forward * 16;

	w_shotorg = w_shotorg + dv;

	// calculate the shotdir from the chosen shotorg
	if (Akimbo_Active(ent))
		w_shotdir = s_forward;
	else
	{
		float dphitcontentsmask_save = ent.dphitcontentsmask;
		if(ent.weapon == WEP_CAMPINGRIFLE)
			ent.dphitcontentsmask = DPCONTENTS_BODY | DPCONTENTS_CORPSE;
		else
			ent.dphitcontentsmask = DPCONTENTS_SOLID | DPCONTENTS_BODY | DPCONTENTS_CORPSE;

		WarpZone_TraceLine(ent.origin + ent.view_ofs, ent.origin + ent.view_ofs + s_forward * MAX_SHOT_DISTANCE, MOVE_NOMONSTERS, ent);
		ent.dphitcontentsmask = dphitcontentsmask_save;
		w_shotpoint = WarpZone_UnTransformOrigin(WarpZone_trace_transform, trace_endpos);
		w_shotdir = normalize(w_shotpoint - w_shotorg);
	}
	if (!g_norecoil)
		ent.punchangle_x = recoil * -1;

	if (ent.lastshot_time < time) {
		if (snd != "")
			sound (ent, CHAN_WEAPON, snd, VOL_BASE, ATTN_NORM);

		if (ent.items & IT_STRENGTH)
			sound (ent, CHAN_AUTO, "weapons/strength_fire.wav", VOL_BASE, ATTN_NORM);

		ent.lastshot_time = time;
	}
};

float CL_Weaponentity_CustomizeEntityForClient()
{
	self.viewmodelforclient = Akimbo_Owner(self.owner);
	if(other.classname == "spectator")
		if(other.enemy == self.viewmodelforclient)
			self.viewmodelforclient = other;

	return TRUE;
}

float CL_ExterioirWeaponentity_CustomizeEntityForClient()
{
    self.alpha = Player_CalculateAlpha(self.owner, other);
    return (self.alpha > 0);
}


/*
 * supported formats:
 *
 * 1. simple animated model, muzzlr flash handling on h_ model:
 *    h_tuba.dpm, h_tuba.dpm.framegroups - invisible model controlling the animation
 *      tags:
 *        shot = muzzle end (shot origin, also used for muzzle flashes)
 *        shell = casings ejection point (must be on the right hand side of the gun)
 *        weapon = attachment for v_tuba.md3
 *    v_tuba.md3 - first and third person model
 *    g_tuba.md3 - pickup model
 *
 * 2. fully animated model, muzzle flash handling on h_ model:
 *    h_tuba.dpm, h_tuba.dpm.framegroups - animated first person model
 *      tags:
 *        shot = muzzle end (shot origin, also used for muzzle flashes)
 *        shell = casings ejection point (must be on the right hand side of the gun)
 *        handle = corresponding to the origin of v_tuba.md3 (used for muzzle flashes)
 *    v_tuba.md3 - third person model
 *    g_tuba.md3 - pickup model
 *
 * 3. fully animated model, muzzle flash handling on v_ model:
 *    h_tuba.dpm, h_tuba.dpm.framegroups - animated first person model
 *      tags:
 *        shot = muzzle end (shot origin)
 *        shell = casings ejection point (must be on the right hand side of the gun)
 *    v_tuba.md3 - third person model
 *      tags:
 *        shot = muzzle end (for muzzle flashes)
 *    g_tuba.md3 - pickup model
 */

void CL_Weaponentity_dlc_reset() {
	setattachment(self.weaponentity, self, "weapon");
}

void CL_Weaponentity_Think()
{
	float tb, v_shot_idx;
	self.nextthink = time;
	if (intermission_running)
		self.frame = self.anim_idle_x;
	if (self.owner.weaponentity != self)
	{
		if (self.weaponentity)
			remove(self.weaponentity);
		remove(self);
		return;
	}
	if (PLAYER_REALLY_DEAD(self.owner))
	{
		self.model = "";
		if (self.weaponentity)
			self.weaponentity.model = "";
		return;
	}
	if (self.cnt != self.owner.weapon || self.dmg != self.owner.modelindex || self.deadflag != self.owner.deadflag)
	{
		self.cnt = self.owner.weapon;
		self.dmg = self.owner.modelindex;
		self.deadflag = self.owner.deadflag;
		if (self.owner.weaponname != "")
		{
			// if there is a child entity, hide it until we're sure we use it
			if (self.weaponentity)
				self.weaponentity.model = "";
			setmodel(self, strcat("models/weapons/v_", self.owner.weaponname, ".md3")); // precision set below
			v_shot_idx = gettagindex(self, "shot"); // used later
			self.dlc_reset = world.dlc_reset;
			if(sv_qcweaponanimation)
			{
				self.angles = '0 0 0';
				makevectors(self.angles_x * '-1 0 0' + self.angles_y * '0 1 0' + self.angles_z * '0 0 1');
				self.movedir = weapon_offset_x * v_forward - weapon_offset_y * v_right + weapon_offset_z * v_up + weapon_adjust;
				self.movedir_x += 32;
				self.spawnorigin = self.movedir;
				// oldorigin - not calculated here
			}
			else
			{
				setmodel(self, strcat("models/weapons/h_", self.owner.weaponname, ".dpm")); // precision set below
				entity e = get_weaponinfo(self.owner.weapon);
				self.anim_fire1  = e.anim_fire1;
				self.anim_fire2  = e.anim_fire2;
				self.anim_idle   = e.anim_idle;
				self.anim_reload = e.anim_reload;

				// if we have a "weapon" tag, let's attach the v_ model to it ("invisible hand" style model)
				// if we don't, this is a "real" animated model
				if(gettagindex(self, "weapon"))
				{
					if (!self.weaponentity)
						self.weaponentity = spawn();
					setmodel(self.weaponentity, strcat("models/weapons/v_", self.owner.weaponname, ".md3")); // precision does not matter
					self.dlc_reset = CL_Weaponentity_dlc_reset;
					self.dlc_reset();
				}
				else
				{
					if(self.weaponentity)
						remove(self.weaponentity);
					self.weaponentity = world;
				}

				setorigin(self,'0 0 0');
				self.angles = '0 0 0';
				self.frame = 0;
				self.viewmodelforclient = world;

				float idx;
				idx = gettagindex(self, "shot");
				if(idx)
				{
					self.movedir = gettaginfo(self, idx);
				}
				else
				{
					print("WARNING: weapon model ", self.model, " does not support the 'shot' tag, will display shots TOTALLY wrong\n");
					self.movedir = '0 0 0';
				}

				idx = gettagindex(self, "shell");
				if(idx)
				{
					self.spawnorigin = gettaginfo(self, idx);
				}
				else
				{
					print("WARNING: weapon model ", self.model, " does not support the 'shell' tag, will display casings wrong\n");
					self.spawnorigin = self.movedir;
				}

				if(v_shot_idx)
				{
					self.oldorigin = '0 0 0';
				}
				else
				{
					if(self.weaponentity)
						idx = gettagindex(self, "weapon");
					else
						idx = gettagindex(self, "handle");
					if(idx)
					{
						self.oldorigin = self.movedir - gettaginfo(self, idx);
					}
					else
					{
						print("WARNING: weapon model ", self.model, " does not support the 'handle' tag and neither does the v_ model support the 'shot' tag, will display muzzle flashes TOTALLY wrong\n");
						self.oldorigin = '0 0 0'; // there is no way to recover from this
					}
				}

				self.viewmodelforclient = Akimbo_Owner(self.owner);
			}
		}
		else
		{
			self.model = "";
			if(self.weaponentity)
				remove(self.weaponentity);
			self.weaponentity = world;
			self.movedir = '0 0 0';
			self.spawnorigin = '0 0 0';
			self.oldorigin = '0 0 0';
			self.anim_fire1  = '0 1 0.01';
			self.anim_fire2  = '0 1 0.01';
			self.anim_idle   = '0 1 0.01';
			self.anim_reload = '0 1 0.01';
		}

		self.view_ofs = '0 0 0';

		if(self.movedir_x >= 0)
		{
			vector v0;
			v0 = self.movedir;
			float akimbo_active = Akimbo_Active(self.owner);
			self.movedir = shotorg_adjust(v0, FALSE, FALSE, akimbo_active);
			self.shotorg_visual = shotorg_adjust(v0, FALSE, TRUE, akimbo_active);
			self.view_ofs = shotorg_adjust(v0, FALSE, TRUE, akimbo_active) - v0;
		}
		self.spawnorigin += self.view_ofs; // offset the casings origin by the same amount

		// check if an instant weapon switch occurred
		if (sv_qcweaponanimation)
		{
			if (self.state == WS_READY)
			{
				self.angles = '0 0 0';
				makevectors(self.angles_x * '-1 0 0' + self.angles_y * '0 1 0' + self.angles_z * '0 0 1');
				setorigin(self, QCWEAPONANIMATION_ORIGIN(self));
			}
		}
		else
			setorigin(self, self.view_ofs);
		// reset animstate now
		self.weapon_morph0time = 0;
		self.weapon_morph1time = 0;
		self.weapon_morph2time = 0;
		self.weapon_morph3time = 0;
		self.weapon_morph4time = 0;
		anim_set(self, self.anim_idle, TRUE, FALSE, TRUE);
	}

	tb = (self.effects & EF_TELEPORT_BIT);
	self.effects = self.owner.effects & EFMASK_CHEAP;
	self.effects &~= EF_LOWPRECISION;
	self.effects &~= EF_FULLBRIGHT; // can mask team color, so get rid of it
	self.effects &~= EF_TELEPORT_BIT;
	self.effects |= tb;

	self.colormap = self.owner.colormap;
	self.alpha = Player_CalculateAlpha(self.owner, self.owner);
	if (self.owner.cvar_cl_gunalpha)
		self.alpha *= self.owner.cvar_cl_gunalpha;

	if (self.weaponentity)
	{
		self.weaponentity.effects = self.effects;
		self.weaponentity.alpha = self.alpha;
		self.weaponentity.colormap = self.colormap;
	}

	self.angles = '0 0 0';
	local float f;
	f = 0;
	float useqcanimation = (sv_qcweaponanimation || self.wframe >= WFRAME_MELEE);
	if (self.state == WS_RAISE && !intermission_running && g_balance_weaponswitchdelay)
	{
		f = (self.owner.weapon_nextthink - time) * g_weaponratefactor * (1 / W_WeaponRateFactorFor(self.owner)) / g_balance_weaponswitchdelay;
		self.angles_x = -90 * f * f;
		if (useqcanimation)
		{
			makevectors(self.angles_x * '-1 0 0' + self.angles_y * '0 1 0' + self.angles_z * '0 0 1');
			setorigin(self, QCWEAPONANIMATION_ORIGIN(self));
		}
	}
	else if (self.state == WS_DROP && !intermission_running && g_balance_weaponswitchdelay)
	{
		f = 1 - (self.owner.weapon_nextthink - time) * g_weaponratefactor * (1 / W_WeaponRateFactorFor(self.owner)) / g_balance_weaponswitchdelay;
		self.angles_x = -90 * f * f;
		if (useqcanimation)
		{
			makevectors(self.angles_x * '-1 0 0' + self.angles_y * '0 1 0' + self.angles_z * '0 0 1');
			setorigin(self, QCWEAPONANIMATION_ORIGIN(self));
		}
	}
	else if (self.state == WS_CLEAR)
	{
		f = 1;
		self.angles_x = -90 * f * f;
		if (useqcanimation)
		{
			makevectors(self.angles_x * '-1 0 0' + self.angles_y * '0 1 0' + self.angles_z * '0 0 1');
			setorigin(self, QCWEAPONANIMATION_ORIGIN(self));
		}
	}
	else if (useqcanimation && time < self.owner.weapon_morph1time)
	{
		f = (time - self.owner.weapon_morph0time) / (self.owner.weapon_morph1time - self.owner.weapon_morph0time);
		f = 1 - pow(1 - f, 3);
		self.angles = self.owner.weapon_morph0angles * (1 - f) + self.owner.weapon_morph1angles * f;
		setorigin(self, self.owner.weapon_morph0origin * (1 - f) + self.owner.weapon_morph1origin * f);
	}
	else if (useqcanimation && time < self.owner.weapon_morph2time)
	{
		f = (time - self.owner.weapon_morph1time) / (self.owner.weapon_morph2time - self.owner.weapon_morph1time);
		f = 1 - pow(1 - f, 3);
		self.angles = self.owner.weapon_morph1angles * (1 - f) + self.owner.weapon_morph2angles * f;
		setorigin(self, self.owner.weapon_morph1origin * (1 - f) + self.owner.weapon_morph2origin * f);
	}
	else if (useqcanimation && time < self.owner.weapon_morph3time)
	{
		f = (time - self.owner.weapon_morph2time) / (self.owner.weapon_morph3time - self.owner.weapon_morph2time);
		f = 1 - pow(1 - f, 3);
		self.angles = self.owner.weapon_morph2angles * (1 - f) + self.owner.weapon_morph3angles * f;
		setorigin(self, self.owner.weapon_morph2origin * (1 - f) + self.owner.weapon_morph3origin * f);
	}
	else if (useqcanimation && time < self.owner.weapon_morph4time)
	{
		f = (time - self.owner.weapon_morph3time) / (self.owner.weapon_morph4time - self.owner.weapon_morph3time);
		f = 1 - pow(1 - f, 3);
		self.angles = self.owner.weapon_morph3angles * (1 - f) + self.owner.weapon_morph4angles * f;
		setorigin(self, self.owner.weapon_morph3origin * (1 - f) + self.owner.weapon_morph4origin * f);
	}
	else if (useqcanimation)
	{
		// begin a new idle morph
		self.owner.weapon_morph0time   = time;
		self.owner.weapon_morph0angles = self.angles;
		self.owner.weapon_morph0origin = self.origin;

		float r;
		float t;

		r = random();
		if (r < 0.1)
		{
			// turn gun to the left to look at it
			t = 2;
			self.owner.weapon_morph1time   = time + t * 0.2;
			self.owner.weapon_morph1angles = randomvec() * 3 + '-5 30 0';
			makevectors(self.owner.weapon_morph1angles_x * '-1 0 0' + self.owner.weapon_morph1angles_y * '0 1 0' + self.owner.weapon_morph1angles_z * '0 0 1');
			self.owner.weapon_morph1origin = QCWEAPONANIMATION_ORIGIN(self);

			self.owner.weapon_morph2time   = time + t * 0.6;
			self.owner.weapon_morph2angles = randomvec() * 3 + '-5 30 0';
			makevectors(self.owner.weapon_morph2angles_x * '-1 0 0' + self.owner.weapon_morph2angles_y * '0 1 0' + self.owner.weapon_morph2angles_z * '0 0 1');
			self.owner.weapon_morph2origin = QCWEAPONANIMATION_ORIGIN(self);

			self.owner.weapon_morph3time   = time + t;
			self.owner.weapon_morph3angles = '0 0 0';
			makevectors(self.owner.weapon_morph3angles_x * '-1 0 0' + self.owner.weapon_morph3angles_y * '0 1 0' + self.owner.weapon_morph3angles_z * '0 0 1');
			self.owner.weapon_morph3origin = QCWEAPONANIMATION_ORIGIN(self);
		}
		else if (r < 0.2)
		{
			// raise the gun a bit
			t = 2;
			self.owner.weapon_morph1time   = time + t * 0.2;
			self.owner.weapon_morph1angles = randomvec() * 3 + '30 -10 0';
			makevectors(self.owner.weapon_morph1angles_x * '-1 0 0' + self.owner.weapon_morph1angles_y * '0 1 0' + self.owner.weapon_morph1angles_z * '0 0 1');
			self.owner.weapon_morph1origin = QCWEAPONANIMATION_ORIGIN(self);

			self.owner.weapon_morph2time   = time + t * 0.5;
			self.owner.weapon_morph2angles = randomvec() * 3 + '30 -10 5';
			makevectors(self.owner.weapon_morph2angles_x * '-1 0 0' + self.owner.weapon_morph2angles_y * '0 1 0' + self.owner.weapon_morph2angles_z * '0 0 1');
			self.owner.weapon_morph2origin = QCWEAPONANIMATION_ORIGIN(self);

			self.owner.weapon_morph3time   = time + t;
			self.owner.weapon_morph3angles = '0 0 0';
			makevectors(self.owner.weapon_morph3angles_x * '-1 0 0' + self.owner.weapon_morph3angles_y * '0 1 0' + self.owner.weapon_morph3angles_z * '0 0 1');
			self.owner.weapon_morph3origin = QCWEAPONANIMATION_ORIGIN(self);
		}
		else if (r < 0.3)
		{
			// tweak it a bit
			t = 5;
			self.owner.weapon_morph1time   = time + t * 0.3;
			self.owner.weapon_morph1angles = randomvec() * 6;
			makevectors(self.owner.weapon_morph1angles_x * '-1 0 0' + self.owner.weapon_morph1angles_y * '0 1 0' + self.owner.weapon_morph1angles_z * '0 0 1');
			self.owner.weapon_morph1origin = QCWEAPONANIMATION_ORIGIN(self);

			self.owner.weapon_morph2time   = time + t * 0.7;
			self.owner.weapon_morph2angles = randomvec() * 6;
			makevectors(self.owner.weapon_morph2angles_x * '-1 0 0' + self.owner.weapon_morph2angles_y * '0 1 0' + self.owner.weapon_morph2angles_z * '0 0 1');
			self.owner.weapon_morph2origin = QCWEAPONANIMATION_ORIGIN(self);

			self.owner.weapon_morph3time   = time + t;
			self.owner.weapon_morph3angles = '0 0 0';
			makevectors(self.owner.weapon_morph3angles_x * '-1 0 0' + self.owner.weapon_morph3angles_y * '0 1 0' + self.owner.weapon_morph3angles_z * '0 0 1');
			self.owner.weapon_morph3origin = QCWEAPONANIMATION_ORIGIN(self);
		}
		else
		{
			// hold it mostly steady
			t = random() * 6 + 4;
			self.owner.weapon_morph1time   = time + t * 0.2;
			self.owner.weapon_morph1angles = randomvec() * 1;
			makevectors(self.owner.weapon_morph1angles_x * '-1 0 0' + self.owner.weapon_morph1angles_y * '0 1 0' + self.owner.weapon_morph1angles_z * '0 0 1');
			self.owner.weapon_morph1origin = QCWEAPONANIMATION_ORIGIN(self);

			self.owner.weapon_morph2time   = time + t * 0.5;
			self.owner.weapon_morph2angles = randomvec() * 1;
			makevectors(self.owner.weapon_morph2angles_x * '-1 0 0' + self.owner.weapon_morph2angles_y * '0 1 0' + self.owner.weapon_morph2angles_z * '0 0 1');
			self.owner.weapon_morph2origin = QCWEAPONANIMATION_ORIGIN(self);

			self.owner.weapon_morph3time   = time + t * 0.7;
			self.owner.weapon_morph3angles = randomvec() * 1;
			makevectors(self.owner.weapon_morph3angles_x * '-1 0 0' + self.owner.weapon_morph3angles_y * '0 1 0' + self.owner.weapon_morph3angles_z * '0 0 1');
			self.owner.weapon_morph3origin = QCWEAPONANIMATION_ORIGIN(self);
		}

		self.owner.weapon_morph4time   = time + t;
		self.owner.weapon_morph4angles = '0 0 0';
		makevectors(self.owner.weapon_morph4angles_x * '-1 0 0' + self.owner.weapon_morph4angles_y * '0 1 0' + self.owner.weapon_morph4angles_z * '0 0 1');
		self.owner.weapon_morph4origin = QCWEAPONANIMATION_ORIGIN(self);

	}
};

void CL_ExteriorWeaponentity_dlc_reset() {
	float tag_found;
	if (self.owner.weaponname != "")
		setmodel(self, strcat("models/weapons/v_", self.owner.weaponname, ".md3")); // precision set below
	else
		self.model = "";

	entity ao = Akimbo_Owner(self.owner);
	float akimbo_weapon = (Akimbo_Active(self.owner) == 2);
	if((tag_found = gettagindex(ao, "tag_weapon")))
	{
		self.tag_index = tag_found;
		self.tag_entity = ao;
	}
	else if (akimbo_weapon && g_akimbo_use_left_hand) {
		if (akimbo_weapon)
			setattachment(self, ao, "bip01 l hand");

		self.angles = stov(cvar_string("g_akimbo_use_left_hand_rotate"));
	} else {
		setattachment(self, ao, "bip01 r hand");
		if (akimbo_weapon)
			setorigin(self, '0 20 0');
	}
	// if that didn't find a tag, hide the exterior weapon model
	if (!self.tag_index)
		self.model = "";
}

void CL_ExteriorWeaponentity_Think()
{
	self.nextthink = time;
	if (self.owner.exteriorweaponentity != self)
	{
		remove(self);
		return;
	}
	if (PLAYER_REALLY_DEAD(self.owner))
	{
		self.model = "";
		return;
	}
	if (self.cnt != self.owner.weapon || self.dmg != self.owner.modelindex || self.deadflag != self.owner.deadflag)
	{
		self.cnt = self.owner.weapon;
		self.dmg = self.owner.modelindex;
		self.deadflag = self.owner.deadflag;
		self.dlc_reset = CL_ExteriorWeaponentity_dlc_reset;
		self.dlc_reset();
	}
	self.effects = self.owner.effects | EF_LOWPRECISION;
	self.effects = self.effects & EFMASK_CHEAP; // eat performance

	self.colormap = self.owner.colormap;
};

// spawning weaponentity for client
void CL_SpawnWeaponentity()
{
	self.weaponentity = spawn();
	self.weaponentity.classname = "weaponentity";
	self.weaponentity.solid = SOLID_NOT;
	self.weaponentity.owner = self;
	setmodel(self.weaponentity, ""); // precision set when changed
	setorigin(self.weaponentity, '0 0 0');
	self.weaponentity.angles = '0 0 0';
	self.weaponentity.viewmodelforclient = Akimbo_Owner(self);
	self.weaponentity.flags = 0;
	self.weaponentity.think = CL_Weaponentity_Think;
	self.weaponentity.customizeentityforclient = CL_Weaponentity_CustomizeEntityForClient;
	self.weaponentity.nextthink = time;

	self.exteriorweaponentity = spawn();
	self.exteriorweaponentity.classname = "exteriorweaponentity";
	self.exteriorweaponentity.solid = SOLID_NOT;
	self.exteriorweaponentity.exteriorweaponentity = self.exteriorweaponentity;
	self.exteriorweaponentity.owner = self;
	setorigin(self.exteriorweaponentity, '0 0 0');
	self.exteriorweaponentity.angles = '0 0 0';
	self.exteriorweaponentity.think = CL_ExteriorWeaponentity_Think;
	self.exteriorweaponentity.customizeentityforclient = CL_ExterioirWeaponentity_CustomizeEntityForClient;
	self.exteriorweaponentity.nextthink = time;
};

.float hasweapon_complain_spam;
float client_hasweapon(entity cl, float wpn, float andammo, float complain)
{
	local float weaponbit, f;
	local entity oldself;

	if(time < cl.hasweapon_complain_spam)
		complain = 0;
	if(complain)
		cl.hasweapon_complain_spam = time + 0.2;

	if (wpn < WEP_FIRST || wpn > WEP_LAST)
	{
		if (complain)
			sprint(cl, "Invalid weapon\n");
		return FALSE;
	}
	weaponbit = W_WeaponBit(wpn);
	if (cl.weapons & weaponbit)
	{
		if (andammo)
		{
			if(cl.items & IT_UNLIMITED_WEAPON_AMMO)
			{
				f = 1;
			}
			else
			{
				oldself = self;
				self = cl;
				f = weapon_action(wpn, WR_CHECKAMMO1);
				f = f + weapon_action(wpn, WR_CHECKAMMO2);
				self = oldself;
			}
			if (!f)
			{
				if (complain)
				if(clienttype(cl) == CLIENTTYPE_REAL)
				{
					play2(cl, "weapons/unavailable.wav");
					sprint(cl, strcat("You don't have any ammo for the ^2", W_Name(wpn), "\n"));
				}
				return FALSE;
			}
		}
		return TRUE;
	}
	if (complain)
	if (clienttype(cl) == CLIENTTYPE_REAL)
	{
		// DRESK - 3/16/07
		// Report Proper Weapon Status / Modified Weapon Ownership Message
		if(weaponsInMap & weaponbit)
		{
			sprint(cl, strcat("You do not have the ^2", W_Name(wpn), "\n") );


			if(g_showweaponspawns)
			{
				entity e;
				string s;

				e = get_weaponinfo(wpn);
				s = e.model2;

				for(e = world; (e = findfloat(e, weapons, weaponbit)); )
				{
					if(e.classname == "droppedweapon")
						continue;
					if not(e.flags & FL_ITEM)
						continue;
					WaypointSprite_Spawn(
						s,
						1, 0,
						world, e.origin,
						cl, 0,
						world, enemy,
						0
					);
				}
			}
		}
		else
			sprint(cl, strcat("The ^2", W_Name(wpn), "^7 is ^1NOT AVAILABLE^7 in this map\n") );

		play2(cl, "weapons/unavailable.wav");
	}
	return FALSE;
};

// Weapon subs
void w_clear()
{
	if (self.weapon != -1)
		self.weapon = 0;
	if (self.weaponentity)
	{
		self.weaponentity.state = WS_CLEAR;
		self.weaponentity.effects = 0;
	}
};

void w_ready()
{
	if (self.weaponentity)
		self.weaponentity.state = WS_READY;
	weapon_thinkf(WFRAME_IDLE, 1000000, w_ready);
};

// Setup weapon for client (after this raise frame will be launched)
void weapon_setup(float windex)
{
	entity e;
	e = get_weaponinfo(windex);
	self.items &~= IT_AMMO;
	self.items = self.items | e.items;

	// the two weapon entities will notice this has changed and update their models
	self.weapon = windex;
	self.weaponname = e.mdl;
	self.bulletcounter = 0;
};

// perform weapon to attack (weaponstate and attack_finished check is here)
float weapon_prepareattack(float secondary, float attacktime)
{
	if(!GameHookChain_WeaponPrepareAttack(secondary, attacktime)) {
		return FALSE;
	}

	if(attacktime >= 0)
	{
		// don't fire if previous attack is not finished
		if (ATTACK_FINISHED(self) > time + frametime * 0.5)
			return FALSE;
		// don't fire while changing weapon
		if (self.weaponentity.state != WS_READY)
			return FALSE;
	}
	// do not even think about shooting if switching
	if(self.switchweapon != self.weapon)
		return FALSE;

	if not(player_can_fire(self, TRUE))
		return FALSE;

	if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
	if (!weapon_action(self.weapon, WR_CHECKAMMO1 + secondary))
	{
		if (Akimbo_Active(self) < 2)
			W_SwitchWeapon_Force(self, w_getbestweapon(self));
		return FALSE;
	}

	self.weaponentity.state = WS_INUSE;

	self.spawnshieldtime = min(self.spawnshieldtime, time); // kill spawn shield when you fire

	// if the weapon hasn't been firing continuously, reset the timer
	if(attacktime >= 0)
	{
		if (ATTACK_FINISHED(self) < time - frametime * 1.5)
		{
			ATTACK_FINISHED(self) = time;
			//dprint("resetting attack finished to ", ftos(time), "\n");
		}
		ATTACK_FINISHED(self) = ATTACK_FINISHED(self) + attacktime * W_WeaponRateFactor();
	}
	self.bulletcounter += 1;
	//dprint("attack finished ", ftos(ATTACK_FINISHED(self)), "\n");
	return TRUE;
};

void weapon_thinkf(float fr, float t, void() func)
{
	vector a;
	vector of, or, ou;
	float restartanim;

	if(fr == WFRAME_DONTCHANGE)
	{
		fr = self.weaponentity.wframe;
		restartanim = FALSE;
	}
	else if (fr == WFRAME_IDLE)
		restartanim = FALSE;
	else
		restartanim = TRUE;

	of = v_forward;
	or = v_right;
	ou = v_up;

	if (self.weaponentity)
	{
		self.weaponentity.wframe = fr;
		if (sv_qcweaponanimation || fr >= WFRAME_MELEE)
		{
			if (fr != WFRAME_IDLE)
			{
				self.weapon_morph0time = time;
				self.weapon_morph0angles = self.weaponentity.angles;
				self.weapon_morph0origin = self.weaponentity.origin;

				self.weapon_morph1angles = '0 0 0';
				self.weapon_morph1time = time + t;
				makevectors(self.weapon_morph1angles_x * '-1 0 0' + self.weapon_morph1angles_y * '0 1 0' + self.weapon_morph1angles_z * '0 0 1');
				self.weapon_morph1origin = QCWEAPONANIMATION_ORIGIN(self.weaponentity);

				self.weapon_morph2angles = '0 0 0';
				self.weapon_morph2time = time + t;
				makevectors(self.weapon_morph2angles_x * '-1 0 0' + self.weapon_morph2angles_y * '0 1 0' + self.weapon_morph2angles_z * '0 0 1');
				self.weapon_morph2origin = QCWEAPONANIMATION_ORIGIN(self.weaponentity);

				self.weapon_morph3angles = '0 0 0';
				self.weapon_morph3time = time + t;
				makevectors(self.weapon_morph3angles_x * '-1 0 0' + self.weapon_morph3angles_y * '0 1 0' + self.weapon_morph3angles_z * '0 0 1');
				self.weapon_morph3origin = QCWEAPONANIMATION_ORIGIN(self.weaponentity);

				self.weapon_morph4angles = '0 0 0';
				self.weapon_morph4time = time + t;
				makevectors(self.weapon_morph4angles_x * '-1 0 0' + self.weapon_morph4angles_y * '0 1 0' + self.weapon_morph4angles_z * '0 0 1');
				self.weapon_morph4origin = QCWEAPONANIMATION_ORIGIN(self.weaponentity);

				if (fr == WFRAME_FIRE1)
				{
					self.weapon_morph1angles = '5 0 0';
					self.weapon_morph1time = time + t * 0.1;
					makevectors(self.weapon_morph1angles_x * '-1 0 0' + self.weapon_morph1angles_y * '0 1 0' + self.weapon_morph1angles_z * '0 0 1');
					self.weapon_morph1origin = QCWEAPONANIMATION_ORIGIN(self.weaponentity);
					self.weapon_morph4time = time + t + 1; // delay idle effect
				}
				else if (fr == WFRAME_FIRE2)
				{
					self.weapon_morph1angles = '10 0 0';
					self.weapon_morph1time = time + t * 0.1;
					makevectors(self.weapon_morph1angles_x * '-1 0 0' + self.weapon_morph1angles_y * '0 1 0' + self.weapon_morph1angles_z * '0 0 1');
					self.weapon_morph1origin = QCWEAPONANIMATION_ORIGIN(self.weaponentity);
					self.weapon_morph4time = time + t + 1; // delay idle effect
				}
				else if (fr == WFRAME_RELOAD)
				{
					self.weapon_morph1time = time + t * 0.05;
					self.weapon_morph1angles = '-10 40 0';
					makevectors(self.weapon_morph1angles_x * '-1 0 0' + self.weapon_morph1angles_y * '0 1 0' + self.weapon_morph1angles_z * '0 0 1');
					self.weapon_morph1origin = QCWEAPONANIMATION_ORIGIN(self.weaponentity);

					self.weapon_morph2time = time + t * 0.15;
					self.weapon_morph2angles = '-10 40 5';
					makevectors(self.weapon_morph2angles_x * '-1 0 0' + self.weapon_morph2angles_y * '0 1 0' + self.weapon_morph2angles_z * '0 0 1');
					self.weapon_morph2origin = QCWEAPONANIMATION_ORIGIN(self.weaponentity);

					self.weapon_morph3time = time + t * 0.25;
					self.weapon_morph3angles = '-10 40 0';
					makevectors(self.weapon_morph3angles_x * '-1 0 0' + self.weapon_morph3angles_y * '0 1 0' + self.weapon_morph3angles_z * '0 0 1');
					self.weapon_morph3origin = QCWEAPONANIMATION_ORIGIN(self.weaponentity);
				}
				else if (fr == WFRAME_MELEE)
				{
					self.weapon_morph1time = time + t * 0.25;
					self.weapon_morph1angles = sv_qcanimation_melee_morph1angles;
					makevectors(self.weapon_morph1angles_x * '-1 0 0' + self.weapon_morph1angles_y * '0 1 0' + self.weapon_morph1angles_z * '0 0 1');
					self.weapon_morph1origin = QCWEAPONANIMATION_ORIGIN(self.weaponentity) + sv_qcanimation_melee_morph1origin;

					self.weapon_morph2time = time + t * 0.65;
					self.weapon_morph2angles = sv_qcanimation_melee_morph2angles;
					makevectors(self.weapon_morph2angles_x * '-1 0 0' + self.weapon_morph2angles_y * '0 1 0' + self.weapon_morph2angles_z * '0 0 1');
					self.weapon_morph2origin = QCWEAPONANIMATION_ORIGIN(self.weaponentity) + sv_qcanimation_melee_morph2origin;
				}
				else if (fr == WFRAME_MELEE2)
				{
					self.weapon_morph1time = time + t * 0.25;
					self.weapon_morph1angles = sv_qcanimation_melee2_morph1angles;
					makevectors(self.weapon_morph1angles_x * '-1 0 0' + self.weapon_morph1angles_y * '0 1 0' + self.weapon_morph1angles_z * '0 0 1');
					self.weapon_morph1origin = QCWEAPONANIMATION_ORIGIN(self.weaponentity) + sv_qcanimation_melee2_morph1origin;

					self.weapon_morph2time = time + t * 0.65;
					self.weapon_morph2angles = sv_qcanimation_melee2_morph2angles;
					makevectors(self.weapon_morph2angles_x * '-1 0 0' + self.weapon_morph2angles_y * '0 1 0' + self.weapon_morph2angles_z * '0 0 1');
					self.weapon_morph2origin = QCWEAPONANIMATION_ORIGIN(self.weaponentity) + sv_qcanimation_melee2_morph2origin;
				}
			}
		}
		else
		{
			if (fr == WFRAME_IDLE)
				a = self.weaponentity.anim_idle;
			else if (fr == WFRAME_FIRE1)
				a = self.weaponentity.anim_fire1;
			else if (fr == WFRAME_FIRE2)
				a = self.weaponentity.anim_fire2;
			else if (fr == WFRAME_RELOAD)
				a = self.weaponentity.anim_reload;
			a_z *= g_weaponratefactor;
			anim_set(self.weaponentity, a, restartanim == FALSE, restartanim, restartanim);
		}
	}

	v_forward = of;
	v_right = or;
	v_up = ou;

	if(self.weapon_think == w_ready && func != w_ready && self.weaponentity.state == WS_RAISE)
	{
		backtrace("Tried to override initial weapon think function - should this really happen?");
	}

	t *= W_WeaponRateFactor();

	// VorteX: haste can be added here
	if (self.weapon_think == w_ready)
	{
		self.weapon_nextthink = time;
		//dprint("started firing at ", ftos(time), "\n");
	}
	if (self.weapon_nextthink < time - frametime * 1.5 || self.weapon_nextthink > time + frametime * 1.5)
	{
		self.weapon_nextthink = time;
		//dprint("reset weapon animation timer at ", ftos(time), "\n");
	}
	self.weapon_nextthink = self.weapon_nextthink + t;
	self.weapon_think = func;
	//dprint("next ", ftos(self.weapon_nextthink), "\n");

	if (restartanim)
	if (t)
	if (!self.crouch) // shoot anim stands up, this looks bad
	{
		local vector anim;
		if (fr == WFRAME_MELEE2)
			anim = self.anim_melee2;
		else if (fr == WFRAME_MELEE || self.weapon == WEP_MELEE)
			anim = self.anim_melee;
		else
			anim = self.anim_shoot;
		anim_z = anim_y / t;
		anim_set(self, anim, FALSE, TRUE, TRUE);
	}
};

vector W_CalculateProjectileVelocity(vector pvelocity, vector mvelocity)
{
	vector mdirection;
	float mspeed;
	float outspeed;
	vector outvelocity;

	mvelocity = mvelocity * g_weaponspeedfactor;

	mdirection = normalize(mvelocity);
	mspeed = vlen(mvelocity);

	if(g_projectiles_newton_style == 0)
	{
		// absolute velocity
		outvelocity = mvelocity;
	}
	else if(g_projectiles_newton_style == 1)
	{
		// true Newtonian projectiles
		outvelocity = pvelocity + mvelocity;
	}
	else if(g_projectiles_newton_style == 2)
	{
		// true Newtonian projectiles with automatic aim adjustment
		//
		// solve: |outspeed * mdirection - pvelocity| = mspeed
		// outspeed^2 - 2 * outspeed * (mdirection * pvelocity) + pvelocity^2 - mspeed^2 = 0
		// outspeed = (mdirection * pvelocity) +- sqrt((mdirection * pvelocity)^2 - pvelocity^2 + mspeed^2)
		// PLUS SIGN!
		// not defined?
		// then...
		// pvelocity^2 - (mdirection * pvelocity)^2 > mspeed^2
		// velocity without mdirection component > mspeed
		// fire at smallest possible mspeed that works?
		// |(mdirection * pvelocity) * pvelocity - pvelocity| = mspeed

		vector solution;
		solution = solve_quadratic(1, -2 * (mdirection * pvelocity), pvelocity * pvelocity - mspeed * mspeed);
		if(solution_z)
			outspeed = solution_y; // the larger one
		else
		{
			//outspeed = 0; // slowest possible shot
			outspeed = solution_x; // the real part (that is, the average!)
			//dprint("impossible shot, adjusting\n");
		}

		outspeed = bound(mspeed * g_projectiles_newton_style_2_minfactor, outspeed, mspeed * g_projectiles_newton_style_2_maxfactor);
		outvelocity = mdirection * outspeed;
	}
	else if(g_projectiles_newton_style == 3)
	{
		// pseudo-Newtonian:
		outspeed = mspeed + mdirection * pvelocity;
		outspeed = bound(mspeed * 0.7, outspeed, mspeed * 5.0);
		outvelocity = mdirection * outspeed;
	}
	else if(g_projectiles_newton_style == 4)
	{
		// tZorkian:
		outspeed = mspeed + vlen(pvelocity);
		outvelocity = mdirection * outspeed;
	}
	else
		error("g_projectiles_newton_style must be 0 (absolute), 1 (Newtonian), 2 (Newtonian + aimfix), 3 (pseudo Newtonian) or 4 (tZorkian)!");

	return outvelocity;
}

void W_SetupProjectileVelocity(entity missile)
{
	if(missile.owner == world)
		error("Unowned missile");

	missile.velocity = W_CalculateProjectileVelocity(missile.owner.velocity, missile.velocity);
	if not(missile.gravity)
	if (missile.movetype == MOVETYPE_TOSS || missile.movetype == MOVETYPE_BOUNCE)
		missile.gravity = 1;
}

void W_AttachToShotorg(entity flash, vector offset)
{
	entity xflash;
	flash.owner = self;
	flash.angles_z = random() * 360;
	if(sv_qcweaponanimation)
	{
		setorigin(flash, w_shotorg + w_shotdir * 50);
		flash.angles = vectoangles(w_shotdir);
		flash.angles_z = random() * 360;
	}
	else
	{
		setattachment(flash, self.weaponentity, "shot");
		setorigin(flash, offset);

		xflash = spawn();
		copyentity(flash, xflash);

		flash.viewmodelforclient = Akimbo_Owner(self);

		if(self.weaponentity.oldorigin_x > 0)
		{
			setattachment(xflash, self.exteriorweaponentity, "");
			setorigin(xflash, self.weaponentity.oldorigin + offset);
		}
		else
		{
			setattachment(xflash, self.exteriorweaponentity, "shot");
		}
	}
}

void W_Init()
{
	float i;
	CACHE_CVAR(g_balance_weaponswitchdelay);
	CACHE_CVAR(g_projectiles_newton_style_2_minfactor);
	CACHE_CVAR(g_projectiles_newton_style_2_maxfactor);
	CACHE_CVAR(g_showweaponspawns);
	CACHE_CVAR(sv_qcweaponanimation);
	CACHE_CVAR(g_weaponspeedfactor);
	CACHE_CVAR(g_weaponratefactor);
	CACHE_CVAR(g_akimbo_use_left_hand);
	CACHE_CVAR(g_shootfromcenter);
	CACHE_CVAR(g_shootfromclient);
	CACHE_CVAR(g_shootfromeye);
	sv_qcanimation_melee_morph1angles = stov(cvar_string("sv_qcanimation_melee_morph1angles"));
	sv_qcanimation_melee_morph2angles = stov(cvar_string("sv_qcanimation_melee_morph2angles"));
	sv_qcanimation_melee_morph1origin = stov(cvar_string("sv_qcanimation_melee_morph1origin"));
	sv_qcanimation_melee_morph2origin = stov(cvar_string("sv_qcanimation_melee_morph2origin"));
	sv_qcanimation_melee2_morph1angles = stov(cvar_string("sv_qcanimation_melee2_morph1angles"));
	sv_qcanimation_melee2_morph2angles = stov(cvar_string("sv_qcanimation_melee2_morph2angles"));
	sv_qcanimation_melee2_morph1origin = stov(cvar_string("sv_qcanimation_melee2_morph1origin"));
	sv_qcanimation_melee2_morph2origin = stov(cvar_string("sv_qcanimation_melee2_morph2origin"));
	for (i = WEP_FIRST; i <= WEP_LAST; ++i)
	{
		(get_weaponinfo(i)).weapon_func(WR_CVAR_CACHE);
	}
	Melee_Init();
	W_BallisticInit();

	ProjInfo_RegisterAuto(PROJECTILE_BULLET, '0 0 0');
	ProjInfo_RegisterAuto(PROJECTILE_BULLET_GLOWING, '0 0 0');
	ProjInfo_RegisterAuto(PROJECTILE_BULLET_BIG, '0 0 0');
}

void W_ShowWeaponList(entity pl) {
	if (clienttype(pl) == CLIENTTYPE_REAL) {
		msg_entity = pl;
		WriteByte(MSG_ONE, SVC_TEMPENTITY);
		WriteByte(MSG_ONE, TE_CSQC_WEAPONLIST);
	}
}
