void fireguy_idle();
void fireguy_guard();
void fireguy_walk();

void fireguy_mine_touch(void)
{
	PROJECTILE_TOUCH;
	if (other.takedamage == DAMAGE_AIM)
	if(Fire_AddDamage(other, self.realowner, self.dmg_edge, 2, self.projectiledeathtype | HITTYPE_HEADSHOT) >= 0)
	{
		remove(self);
		return;
	}
	self.projectiledeathtype |= HITTYPE_BOUNCE;
}

void fireguy_mine_think()
{
	if(time > self.pushltime)
	{
		remove(self);
		return;
	}
	if (self.waterlevel > 0) {
		remove(self);
		return;
	}

	W_Fireball_LaserPlay(0.1, self.dmg_radius, self.dmg_edge, 0, 4);

	self.nextthink = time + 0.1;
}


void fireguy_hunt() {
	self.nextthink = time;
	if (monster_check_target(fireguy_walk, fireguy_guard))
		return;

	vector v;
	float dofire;
	dofire = FALSE;
	if (self.attack_finished_single < time) {
		traceline(self.origin, self.enemy.origin, MOVE_WORLDONLY, self);
		if (trace_fraction == 1)
			dofire = TRUE;
	}
	float stay = self.owner.spawnflags & MONSTER_SPAWN_STAYSTILL;
	if (dofire) {
		movelib_beak_simple(100 * frametime);
		v = vectoangles(self.enemy.origin - self.origin);
		self.angles_y = v_y;
		makevectors(self.angles);
		vector _shotdir = self.enemy.origin - self.origin;
		vector _shotorg = self.origin + v_forward * 16;
		sound (self, CHAN_WEAPON, "weapons/fireball_fire.wav", VOL_BASE, ATTN_NORM);

		entity proj = CSQCProjectile(TRUE, PROJECTILE_FIREMINE, TRUE);
		proj.owner = proj.realowner = self;
		proj.classname = "grenade";
		proj.bot_dodge = TRUE;
		proj.bot_dodgerating = self.dmg_edge;
		proj.dmg_edge = self.dmg_edge;
		proj.dmg_radius = self.dmg_radius;
		proj.dmg_force = self.dmg_force;
		proj.movetype = MOVETYPE_BOUNCE;
		proj.projectiledeathtype = WEP_FIREBALL;
		proj.touch = fireguy_mine_touch;
		PROJECTILE_MAKETRIGGER(proj);
		setorigin(proj, _shotorg);
		proj.think = fireguy_mine_think;
		proj.nextthink = time;
		proj.damageforcescale = g_balance_fireball_primary_damageforcescale;
		proj.velocity = normalize(_shotdir) * 2000 + v_up * 50;
		proj.pushltime = time + 10;
		W_SetupProjectileVelocity(proj);
		proj.angles = vectoangles(proj.velocity);

		self.attack_finished_single = time + 3 + random();
		self.bulletcounter = time + 0.5;
	} else if (stay) {
		movelib_beak_simple(1000 * frametime);
		v = vectoangles(normalize(self.enemy.origin - self.origin));
		self.angles_y = approach_angle(self.angles_y, v_y, 360 * frametime);
	} else {
		v = monster_move_walk(250, 5, 0);
		v = vectoangles(v);
		self.angles_y = approach_angle(self.angles_y, v_y, 360 * frametime);
	}
	if (time > self.bulletcounter) {
		if (stay)
			anim_set(self, '7 1 1', TRUE, TRUE, FALSE);
		else
			anim_set(self, '13 1 1', TRUE, TRUE, FALSE);
	} else
		anim_set(self, '11 1 1', TRUE, TRUE, FALSE);
}

void fireguy_idle() {
	self.nextthink = time;
	if (monster_look_for_player(2000, 500, 0, 1, 3)) {
		return;
	}
	movelib_beak_simple(100 * frametime);
	anim_set(self, '7 1 1', TRUE, TRUE, FALSE);
}

void fireguy_guard() {
	self.angles_y = self.angles_y + frametime * 45 * random();
	if (self.angles_y > 360)
		self.angles_y = self.angles_y - 360;
	fireguy_idle();
}

void fireguy_walk() {
	self.nextthink = time;
	if (monster_look_for_player(1000, 500, 0, 1, 3)) {
		return;
	}
	if (monster_walk_finished(fireguy_idle, 100))
		return;

	anim_set(self, '13 1 1', TRUE, TRUE, FALSE);
	//self.velocity = normalize(v) * 400;
	vector v = monster_move_walk(150, 5, 0);
	//pointparticles(particleeffectnum("sparks"), self.enemy.origin, '0 0 1', 1);
	v = vectoangles(v);
	self.angles_y = approach_angle(self.angles_y, v_y, 90 * frametime);

}

void fireguy_remove() {
	remove(self.exteriorweaponentity);
}

void fireguy_spawn() {
	monster_prepare(fireguy_hunt, fireguy_walk, fireguy_idle);
	setmodel(self, "models/player/lycanthrope.zym");
	self.movetype = MOVETYPE_WALK;
	self.exteriorweaponentity = spawn();
	self.entremove = fireguy_remove;
	if (self.team > 0)
		self.colormap = 1024;
	else
		self.colormap = 1024 + 68;

	setattachment(self.exteriorweaponentity, self, "bip01 r hand");
	setmodel(self.exteriorweaponentity, "models/weapons/v_fireball.md3");
	self.takedamage = DAMAGE_AIM;
	self.solid = SOLID_BBOX;
	self.damageforcescale = 1;
	self.netname = "FireGuy";
	self.ammo_rockets = 10;
	self.flags = MONSTER_IGNOREFIRE;
	self.view_ofs = '0 0 35';
}

void fireguy_init() {
	precache_model("models/player/lycanthrope.zym");
	precache_model("models/weapons/v_fireball.md3");
	precache_sound("weapons/fireball_fire.wav");
	CSQCProjectile_Init(PROJECTILE_FIREMINE);
}

void spawnfunc_monster_fireguy_spawn() {
	setsize(self, '-16 -16 -24', '16 16 45');
	monster_init(fireguy_init);
	self.noise1 = "player/carni-lycan/coms/incoming.ogg";
	self.noise3 = "player/carni-lycan/player/pain50.ogg";
	monster_prepare_spawn(fireguy_spawn, spawnfunc_monster_fireguy_spawn);
}
