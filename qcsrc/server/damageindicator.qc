float sv_damageindicator_accumulate_interval;

float DamageIndicator_SendEntity(entity to, float sf) {
	WriteByte(MSG_ENTITY, ENT_CLIENT_DMG_INDICATOR);
	float damage = self.dmg + 0.4;
	WriteByte(MSG_ENTITY, BoundToByte(damage));
	WriteShort(MSG_ENTITY, self.origin_x);
	WriteShort(MSG_ENTITY, self.origin_y);
	WriteShort(MSG_ENTITY, self.origin_z);
	return TRUE;
}

void DamageIndicator_Remove() {
	entity e;
	float i;
	for (i = 0, e = self.owner; e && i < 7; e = e.dmg_indicator, i++)
		if (e.dmg_indicator == self) {
			e.dmg_indicator = self.dmg_indicator;
			break;
		}

	if (i == 7) //something wrong with chain
		self.owner.dmg_indicator = world;

	remove(self);
}

float DamageIndicator_Customize() {
	if (self.enemy == other)
		return TRUE;

	if (other.classname == "spectator")
		if (other.enemy == self.enemy)
			return TRUE;

	return FALSE;
}

var void(entity targ, entity attacker, float damage, vector ignore) DamageIndicator_DamageForceDone_NextLink;
void DamageIndicator_DamageForceDone(entity targ, entity attacker, float damage, vector ignore) {
	DamageIndicator_DamageForceDone_NextLink(targ, attacker, damage, ignore);
	if (targ == attacker)
		return;

	if not(targ.event_damage)
		return;

	if not(targ.modelindex)
		return;

	if (targ.flags & FL_PROJECTILE)
		return;

	entity e;
	float i;
	for (i = 0, e = targ.dmg_indicator; e ;e = e.dmg_indicator, i++) {
		if (i > 5) // too much damage indicators for one entity
			return;

		if (e.enemy == attacker)
			break;
	}
	if not(e) {
		e = spawn();
		e.dmg_indicator = targ.dmg_indicator;
		e.think = DamageIndicator_Remove;
		e.owner = targ;
		e.enemy = attacker;
		e.customizeentityforclient = DamageIndicator_Customize;
		Net_LinkEntity(e, FALSE, 0, DamageIndicator_SendEntity);
		targ.dmg_indicator = e;
	}
	setorigin(e, targ.origin + 0.5 * (targ.maxs + targ.mins));
	e.SendFlags = 1;
	e.dmg = e.dmg + damage;
	e.nextthink = time + sv_damageindicator_accumulate_interval;
}

void DamageIndicator_Init() {
	if not(cvar("sv_damageindicator"))
		return;
	
	CACHE_CVAR(sv_damageindicator_accumulate_interval);
	DamageIndicator_DamageForceDone_NextLink = GameHookChain_DamageForceDone;
	GameHookChain_DamageForceDone = DamageIndicator_DamageForceDone;
}
