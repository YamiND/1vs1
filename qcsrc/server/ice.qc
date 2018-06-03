#define ICE_FRAME_TIME 0.2
string ice_model;
float g_freeze_unfroze_time;
float g_freeze_slowdown;
float sv_model_ice_scale;
float sv_model_ice_z;
float sv_model_ice_alpha;
.entity ice;
.entity last_unfrozer;
.float unfroze_progress;
.entity unfroze_pb;

void Ice_Remove() {
	if (self.ice)
		remove(self.ice);

	if (self.unfroze_pb)
		remove(self.unfroze_pb);

	if (self.ice.unfroze_pb)
		remove(self.ice.unfroze_pb);

	self.unfroze_pb = world;
	self.ice = world;
	WaypointSprite_DetachCarrier(self);
}

float Ice_DeathHandle(entity attacker, entity inflictor, float deathtype)
{
	if (IceHook_SkipDeathHandle)
	if (IceHook_SkipDeathHandle())
		return FALSE;

	PlayerClear(TRUE);
	Roundbased_NeedCheckTeams();

	if (self.deadflag == DEAD_FREEZE)
		return TRUE;

	if (deathtype)
		Obituary(attacker, inflictor, self, deathtype);

	self.deadflag = DEAD_FREEZE;
	self.health = start_health;
	if (IceHook_FrozenStatus)
		IceHook_FrozenStatus();

	if (self.ice)
		return TRUE;

	self.ice = spawn();
	self.ice.alpha = sv_model_ice_alpha;
	self.ice.scale = sv_model_ice_scale;
	self.ice.owner = self;
	self.ice.think = Ice_Think;
	self.ice.nextthink = time;
	self.ice.team = self.team;
	self.ice.colormod = TeamColor(self.team);
	WaypointSprite_AttachCarrier("helpme", self);
	setattachment(self.ice, self, "");
	setorigin(self.ice, '0 0 1' * sv_model_ice_z);
	setmodel(self.ice, ice_model);
	return TRUE;
}

void Ice_Think()
{
	self.nextthink = time + ICE_FRAME_TIME;
	if (self.owner.deadflag != DEAD_FREEZE || self.owner.ice != self)
	{
		if (self.unfroze_pb) //for self.owner.ice != self case
			remove(self.unfroze_pb);

		self.unfroze_pb = world;
		entity oldself = self;
		self = self.owner;
		Ice_Remove();
		self = oldself;
		return;
	}

	if (IceHook_SkipThink)
	if (IceHook_SkipThink())
		return;

	float oldprogress = self.unfroze_progress;
	if (self.team != self.owner.team) {
		self.team = self.owner.team;
		self.colormod = TeamColor(self.team);
	}
	entity e, unfrozer;
	unfrozer = world;
	if (self.last_unfrozer && self.last_unfrozer.deadflag == DEAD_NO && vlen(self.last_unfrozer.origin - self.owner.origin) <= 100)
	{
		unfrozer = self.last_unfrozer;
	}
	else FOR_EACH_PLAYER(e)
	{
		if (e == self.owner || e.team != self.owner.team || e.deadflag != DEAD_NO || vlen(e.origin - self.owner.origin) > 100)
			continue;

		unfrozer = e;
		break;
	}
	if (unfrozer != self.last_unfrozer)
	{
		if (self.unfroze_pb)
			remove(self.unfroze_pb);

		if (unfrozer) {
			self.unfroze_pb = ProgressBar_Create("Reviving", unfrozer);
			if not(self.owner.unfroze_pb)
				self.owner.unfroze_pb = ProgressBar_Create("Reviving", self.owner);
		} else {
			if (self.owner.unfroze_pb)
				remove(self.owner.unfroze_pb);

			self.owner.unfroze_pb = world;
			self.unfroze_pb = world;
		}
	}

	self.last_unfrozer = unfrozer;
	if (unfrozer)
	{
		self.unfroze_progress += ICE_FRAME_TIME;
		if (clienttype(unfrozer) == CLIENTTYPE_REAL)
			if (self.unfroze_pb)
				ProgressBar_SetValue(self.unfroze_pb, self.unfroze_progress / g_freeze_unfroze_time);

		if (clienttype(self.owner) == CLIENTTYPE_REAL)
			if (self.owner.unfroze_pb)
				ProgressBar_SetValue(self.owner.unfroze_pb, self.unfroze_progress / g_freeze_unfroze_time);

		unfrozer.bot_dontmove = time + ICE_FRAME_TIME * 1.5;
	}
	if (self.unfroze_progress >= g_freeze_unfroze_time)
	{
		if (clienttype(unfrozer) == CLIENTTYPE_REAL)
			centerprint(unfrozer, strcat("^4You revive ^7", self.owner.netname, "\n"));

		if (clienttype(self.owner) == CLIENTTYPE_REAL)
			centerprint(self.owner, strcat("^4You revived by ^7", unfrozer.netname, "\n"));

		bprint ("^1", self.owner.netname, "^1 was revived by ", unfrozer.netname, "\n");
		IceHook_Unfroze(unfrozer);
		self.owner.deadflag = DEAD_NO;
		return;
	}

	if (self.unfroze_progress == oldprogress)
	if (oldprogress != 0)
		self.unfroze_progress = min(0, oldprogress - ICE_FRAME_TIME);

	if (self.unfroze_progress != oldprogress)
		self.alpha = sv_model_ice_alpha * max(0.01, (g_freeze_unfroze_time - self.unfroze_progress));
}

var void(float killed) Ice_PlayerClear_NextLink;
void Ice_PlayerClear(float killed)
{
	Ice_Remove();
	Ice_PlayerClear_NextLink(killed);
}

var void(entity spot) Ice_Spawn_NextLink;
void Ice_Spawn(entity spot)
{
	Ice_DeathHandle(world, world, 0);
}

var float() Ice_SpeedMod_NextLink;
float Ice_SpeedMod() {
	float f = Ice_SpeedMod_NextLink();
	if (self.deadflag == DEAD_FREEZE)
		return g_freeze_slowdown * f;

	return f;
}

var float(entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force) Ice_PlayerDamageHandle_NextLink;
float Ice_PlayerDamageHandle(entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force)
{
	if not(self.deadflag == DEAD_FREEZE)
		return Ice_PlayerDamageHandle_NextLink(inflictor, attacker, damage, deathtype, hitloc, force);

	if (deathtype == DEATH_SLIME ||
			deathtype == DEATH_LAVA ||
			deathtype == DEATH_HURTTRIGGER)
		PutClientInServer();

	self.unfroze_progress = 0;

	return TRUE;
}

var void(entity spectatee) Ice_SpecateCopy_NextLink;
void Ice_SpecateCopy(entity spectatee) {
	self.deadflag = spectatee.deadflag;
	Ice_SpecateCopy_NextLink(spectatee);
}

void Ice_Init() {
	ice_model = strzone(cvar_string("sv_model_ice")); //strzone once and never strunzone
	precache_model(ice_model);
	CACHE_CVAR(g_freeze_unfroze_time);
	CACHE_CVAR(g_freeze_slowdown);
	if (g_freeze_unfroze_time <= 0)
		g_freeze_unfroze_time = 1;

	CACHE_CVAR(sv_model_ice_alpha);
	CACHE_CVAR(sv_model_ice_scale);
	CACHE_CVAR(sv_model_ice_z);
	GameHook_DeathHandle = Ice_DeathHandle;
	Ice_PlayerClear_NextLink = GameHookChain_PlayerClear;
	GameHookChain_PlayerClear = Ice_PlayerClear;
	Ice_SpeedMod_NextLink = GameHookChain_SpeedMod;
	GameHookChain_SpeedMod = Ice_SpeedMod;
	Ice_Spawn_NextLink = GameHookChain_Spawn;
	GameHookChain_Spawn = Ice_Spawn;
	Ice_PlayerDamageHandle_NextLink = GameHookChain_PlayerDamageHandle;
	GameHookChain_PlayerDamageHandle = Ice_PlayerDamageHandle;
	Ice_SpecateCopy_NextLink = GameHookChain_SpectateCopy;
	GameHookChain_SpectateCopy = Ice_SpecateCopy;
}