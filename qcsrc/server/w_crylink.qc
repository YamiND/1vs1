float g_balance_crylink_primary_ammo;
float g_balance_crylink_primary_animtime;
float g_balance_crylink_primary_bouncedamagefactor;
float g_balance_crylink_primary_bounces;
float g_balance_crylink_primary_damage;
float g_balance_crylink_primary_edgedamage;
float g_balance_crylink_primary_force;
float g_balance_crylink_primary_middle_fadetime;
float g_balance_crylink_primary_middle_lifetime;
float g_balance_crylink_primary_other_fadetime;
float g_balance_crylink_primary_other_lifetime;
float g_balance_crylink_primary_radius;
float g_balance_crylink_primary_refire;
float g_balance_crylink_primary_shots;
float g_balance_crylink_primary_speed;
float g_balance_crylink_primary_spread;
float g_balance_crylink_primary_star_fadetime;
float g_balance_crylink_primary_star_lifetime;
float g_balance_crylink_secondary_ammo;
float g_balance_crylink_secondary_animtime;
float g_balance_crylink_secondary_bouncedamagefactor;
float g_balance_crylink_secondary_bounces;
float g_balance_crylink_secondary_damage;
float g_balance_crylink_secondary_edgedamage;
float g_balance_crylink_secondary_force;
float g_balance_crylink_secondary_line_fadetime;
float g_balance_crylink_secondary_line_lifetime;
float g_balance_crylink_secondary_middle_fadetime;
float g_balance_crylink_secondary_middle_lifetime;
float g_balance_crylink_secondary_radius;
float g_balance_crylink_secondary_refire;
float g_balance_crylink_secondary_shots;
float g_balance_crylink_secondary_speed;
float g_balance_crylink_secondary_spread;

.float gravity;

.entity realowner;
var .float crylink_buttonatck1 = BUTTON_ATCK;
var .float crylink_buttonatck2 = BUTTON_ATCK2;

// NO bounce protection, as bounces are limited!
void W_Crylink_Touch (void)
{
	float finalhit;
	float f;
	PROJECTILE_TOUCH;
	finalhit = ((self.cnt <= 0) || (other.takedamage != DAMAGE_NO));
	if(finalhit)
		f = 1;
	else
		f = g_balance_crylink_primary_bouncedamagefactor;
	if(self.alpha)
		f *= self.alpha;
	RadiusDamage (self, self.realowner, g_balance_crylink_primary_damage * f, g_balance_crylink_primary_edgedamage * f, g_balance_crylink_primary_radius, world, g_balance_crylink_primary_force * f, self.projectiledeathtype, other);
	if (finalhit)
	{
		remove (self);
		return;
	}
	self.cnt = self.cnt - 1;
	self.angles = vectoangles(self.velocity);
	self.owner = world;
	self.projectiledeathtype |= HITTYPE_BOUNCE;
	// commented out as it causes a little hitch...
	//if(proj.cnt == 0)
	//	CSQCProjectile(proj, TRUE, PROJECTILE_CRYLINK, TRUE);
}

void W_Crylink_Touch2 (void)
{
	float finalhit;
	float f;
	PROJECTILE_TOUCH;
	finalhit = ((self.cnt <= 0) || (other.takedamage != DAMAGE_NO));
	if(finalhit)
		f = 1;
	else
		f = g_balance_crylink_secondary_bouncedamagefactor;
	if(self.alpha)
		f *= self.alpha;
	RadiusDamage (self, self.realowner, g_balance_crylink_secondary_damage * f, g_balance_crylink_secondary_edgedamage * f, g_balance_crylink_secondary_radius, world, g_balance_crylink_secondary_force * f, self.projectiledeathtype, other);
	if (finalhit)
	{
		remove (self);
		return;
	}
	self.cnt = self.cnt - 1;
	self.angles = vectoangles(self.velocity);
	self.owner = world;
	self.projectiledeathtype |= HITTYPE_BOUNCE;
	// commented out as it causes a little hitch...
	//if(proj.cnt == 0)
	//	CSQCProjectile(proj, TRUE, PROJECTILE_CRYLINK, TRUE);
}

void W_Crylink_Attack (void)
{
	local float counter, shots;
	local entity proj;
	local vector s;
	vector forward, right, up;

	if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
		self.ammo_cells = self.ammo_cells - g_balance_crylink_primary_ammo;

	W_SetupShot (self, 2, "weapons/crylink_fire.wav", g_balance_crylink_primary_shots);
	forward = v_forward;
	right = v_right;
	up = v_up;

	shots = g_balance_crylink_primary_shots;
	pointparticles(particleeffectnum("crylink_muzzleflash"), w_shotorg_visual, w_shotdir * 1000, shots);
	while (counter < shots)
	{
		proj = CSQCProjectile(TRUE, (proj.cnt ? PROJECTILE_CRYLINK_BOUNCING : PROJECTILE_CRYLINK), TRUE);
		proj.realowner = proj.owner = Akimbo_Owner(self);
		proj.classname = "spike";
		proj.bot_dodge = TRUE;
		proj.bot_dodgerating = g_balance_crylink_primary_damage;

		proj.movetype = MOVETYPE_BOUNCEMISSILE;
		PROJECTILE_MAKETRIGGER(proj);
		proj.projectiledeathtype = WEP_CRYLINK;
		//proj.gravity = 0.001;

		setorigin (proj, w_shotorg);

		s = '0 0 0';
		if (counter == 0)
			s = '0 0 0';
		else
		{
			makevectors('0 360 0' * (0.75 + (counter - 0.5) / (shots - 1)));
			s_y = v_forward_x;
			s_z = v_forward_y;
		}
		s = s * g_balance_crylink_primary_spread;
		proj.velocity = (w_shotdir + right * s_y + up * s_z) * g_balance_crylink_primary_speed;
//		proj.velocity = (w_shotdir + randomvec() * g_balance_crylink_primary_spread) * g_balance_crylink_primary_speed;
		W_SetupProjectileVelocity(proj);
		proj.touch = W_Crylink_Touch;
		if(counter == 0)
			SUB_SetFade(proj, time + g_balance_crylink_primary_middle_lifetime, g_balance_crylink_primary_middle_fadetime);
		else if(counter <= 3)
			SUB_SetFade(proj, time + g_balance_crylink_primary_star_lifetime, g_balance_crylink_primary_star_fadetime);
		else
			SUB_SetFade(proj, time + g_balance_crylink_primary_other_lifetime, g_balance_crylink_primary_other_fadetime);
		proj.cnt = g_balance_crylink_primary_bounces;
		//proj.scale = 1 + 1 * proj.cnt;

		proj.angles = vectoangles (proj.velocity);

		//proj.glow_size = 20;

		counter = counter + 1;
	}
}

void W_Crylink_Attack2 (void)
{
	local float counter, shots;
	local entity proj;

	if not(self.items & IT_UNLIMITED_WEAPON_AMMO)
		self.ammo_cells = self.ammo_cells - g_balance_crylink_secondary_ammo;

	W_SetupShot (self, 2, "weapons/crylink_fire2.wav", g_balance_crylink_secondary_shots);

	shots = g_balance_crylink_secondary_shots;
	pointparticles(particleeffectnum("crylink_muzzleflash"), w_shotorg_visual, w_shotdir * 1000, shots);
	while (counter < shots)
	{
		proj = CSQCProjectile(TRUE, (proj.cnt ? PROJECTILE_CRYLINK_BOUNCING : PROJECTILE_CRYLINK), TRUE);
		proj.realowner = proj.owner = Akimbo_Owner(self);
		proj.classname = "spike";
		proj.bot_dodge = TRUE;
		proj.bot_dodgerating = g_balance_crylink_secondary_damage;

		proj.movetype = MOVETYPE_BOUNCEMISSILE;
		PROJECTILE_MAKETRIGGER(proj);
		proj.projectiledeathtype = WEP_CRYLINK | HITTYPE_SECONDARY;
		//proj.gravity = 0.001;

		setorigin (proj, w_shotorg);
		proj.velocity = (w_shotdir + (((counter + 0.5) / shots) * 2 - 1) * v_right * g_balance_crylink_secondary_spread) * g_balance_crylink_secondary_speed;
		W_SetupProjectileVelocity(proj);
		proj.touch = W_Crylink_Touch2;
		if(counter == (shots - 1) / 2)
			SUB_SetFade(proj, time + g_balance_crylink_secondary_middle_lifetime, g_balance_crylink_secondary_middle_fadetime);
		else
			SUB_SetFade(proj, time + g_balance_crylink_secondary_line_lifetime, g_balance_crylink_secondary_line_fadetime);
		proj.cnt = g_balance_crylink_secondary_bounces;
		//proj.scale = 1 + 1 * proj.cnt;

		proj.angles = vectoangles (proj.velocity);

		//proj.glow_size = 20;
		counter = counter + 1;
	}
}

void spawnfunc_weapon_crylink (void)
{
	weapon_defaultspawnfunc(WEP_CRYLINK);
}

float w_crylink(float req)
{
	if (req == WR_AIM)
	{
		if (random() > 0.15)
			self.crylink_buttonatck1 = bot_aim(g_balance_crylink_primary_speed, 0, g_balance_crylink_primary_middle_lifetime, FALSE);
		else
			self.crylink_buttonatck2 = bot_aim(g_balance_crylink_secondary_speed, 0, g_balance_crylink_secondary_middle_lifetime, FALSE);
	}
	else if (req == WR_THINK)
	{
		if (self.crylink_buttonatck1)
		if (weapon_prepareattack(0, g_balance_crylink_primary_refire))
		{
			W_Crylink_Attack();
			weapon_thinkf(WFRAME_FIRE1, g_balance_crylink_primary_animtime, w_ready);
		}
		if (self.crylink_buttonatck2)
		if (weapon_prepareattack(1, g_balance_crylink_secondary_refire))
		{
			W_Crylink_Attack2();
			weapon_thinkf(WFRAME_FIRE2, g_balance_crylink_secondary_animtime, w_ready);
		}
	}
	else if (req == WR_PRECACHE)
	{
		precache_sound ("weapons/crylink_fire.wav");
		precache_sound ("weapons/crylink_fire2.wav");
	}
	else if (req == WR_SETUP)
		weapon_setup(WEP_CRYLINK);
	else if (req == WR_CHECKAMMO1)
		return self.ammo_cells >= g_balance_crylink_primary_ammo;
	else if (req == WR_CHECKAMMO2)
		return self.ammo_cells >= g_balance_crylink_secondary_ammo;
	else if (req == WR_SUICIDEMESSAGE)
	{
		w_deathtypestring = "succeeded at self-destructing himself with the Crylink";
	}
	else if (req == WR_KILLMESSAGE)
	{
		if(w_deathtype & HITTYPE_BOUNCE)
			w_deathtypestring = "could not hide from #'s Crylink"; // unchecked: SPLASH (SECONDARY can't be)
		else if(w_deathtype & HITTYPE_SPLASH)
			w_deathtypestring = "was too close to #'s Crylink"; // unchecked: SECONDARY
		else
			w_deathtypestring = "took a close look at #'s Crylink"; // unchecked: SECONDARY
	}
	else if (req == WR_CVAR_CACHE)
	{
		CACHE_CVAR(g_balance_crylink_primary_ammo);
		CACHE_CVAR(g_balance_crylink_primary_animtime);
		CACHE_CVAR(g_balance_crylink_primary_bouncedamagefactor);
		CACHE_CVAR(g_balance_crylink_primary_bounces);
		CACHE_CVAR(g_balance_crylink_primary_damage);
		CACHE_CVAR(g_balance_crylink_primary_edgedamage);
		CACHE_CVAR(g_balance_crylink_primary_force);
		CACHE_CVAR(g_balance_crylink_primary_middle_fadetime);
		CACHE_CVAR(g_balance_crylink_primary_middle_lifetime);
		CACHE_CVAR(g_balance_crylink_primary_other_fadetime);
		CACHE_CVAR(g_balance_crylink_primary_other_lifetime);
		CACHE_CVAR(g_balance_crylink_primary_radius);
		CACHE_CVAR(g_balance_crylink_primary_refire);
		CACHE_CVAR(g_balance_crylink_primary_shots);
		CACHE_CVAR(g_balance_crylink_primary_speed);
		CACHE_CVAR(g_balance_crylink_primary_spread);
		CACHE_CVAR(g_balance_crylink_primary_star_fadetime);
		CACHE_CVAR(g_balance_crylink_primary_star_lifetime);
		CACHE_CVAR(g_balance_crylink_secondary_ammo);
		CACHE_CVAR(g_balance_crylink_secondary_animtime);
		CACHE_CVAR(g_balance_crylink_secondary_bouncedamagefactor);
		CACHE_CVAR(g_balance_crylink_secondary_bounces);
		CACHE_CVAR(g_balance_crylink_secondary_damage);
		CACHE_CVAR(g_balance_crylink_secondary_edgedamage);
		CACHE_CVAR(g_balance_crylink_secondary_force);
		CACHE_CVAR(g_balance_crylink_secondary_line_fadetime);
		CACHE_CVAR(g_balance_crylink_secondary_line_lifetime);
		CACHE_CVAR(g_balance_crylink_secondary_middle_fadetime);
		CACHE_CVAR(g_balance_crylink_secondary_middle_lifetime);
		CACHE_CVAR(g_balance_crylink_secondary_radius);
		CACHE_CVAR(g_balance_crylink_secondary_refire);
		CACHE_CVAR(g_balance_crylink_secondary_shots);
		CACHE_CVAR(g_balance_crylink_secondary_speed);
		CACHE_CVAR(g_balance_crylink_secondary_spread);
		CSQCProjectile_Init(PROJECTILE_CRYLINK);
		CSQCProjectile_Init(PROJECTILE_CRYLINK_BOUNCING);
		if (cvar("g_balance_crylink_swap_buttons")) {
			crylink_buttonatck1 = BUTTON_ATCK2;
			crylink_buttonatck2 = BUTTON_ATCK;
		}
	}
	return TRUE;
};
