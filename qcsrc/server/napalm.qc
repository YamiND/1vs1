
void Napalm_Touch(void) {
    PROJECTILE_TOUCH;
}

void Napalm_Burn(void) {
    entity e, o;
    float d,/* ismedic,*/ sameteam;
    vector p;

    float dtype = self.projectiledeathtype;
    float damage = self.napalm_burn_damage;
    float edgedamage = self.napalm_burn_edgedamage;
    float dist = self.napalm_burn_radius;
    float burntime = self.napalm_burn_time;

    o = self.realowner;

    if(dtype != DEATH_HURTTRIGGER) {
        if(o.classname != "player" || o.team != self.team) {
            remove(self);
            return;
        }

        //ismedic = Buffs_Present(o, BUFF_MEDIC);
    }

    for(e = findradius(self.origin, dist); e; e = e.chain) if(e.takedamage == DAMAGE_AIM) {
        if(dtype != DEATH_HURTTRIGGER && e.classname == "player") {
            sameteam = !IsDifferentTeam(o, e);

#if 0
            if(!ismedic) {
#endif
                if(sameteam && o != e)
                    if(!cvar("g_friendlyfire"))
                            continue;

#if 0
                if(!Buffs_TenacityDamage(e, o, damage, dtype))
                    continue;
#endif
#if 0
            }
#endif
        }

        p = e.origin;
        p_x += e.mins_x + random() * (e.maxs_x - e.mins_x);
        p_y += e.mins_y + random() * (e.maxs_y - e.mins_y);
        p_z += e.mins_z + random() * (e.maxs_z - e.mins_z);
        d = vlen(self.origin - p);

        if(d < dist) {
            traceline(self.origin, p, MOVE_NOMONSTERS, self);

            if(trace_fraction < 1)
                continue;

            d = damage + (edgedamage - damage) * (vlen(self.origin - p) / dist);
            Fire_AddDamage(e, o, d * burntime, burntime, dtype);
        }
    }
}

void Napalm_Think(void) {
    if(time > self.pushltime) {
        remove(self);
        return;
    }
	if (self.waterlevel > 0) {
		remove(self);
		return;
	}

#if 0
    if(self.projectiledeathtype != DEATH_HURTTRIGGER)
        HealParticleEmitter(self.realowner);
#endif

    Napalm_Burn();

    self.nextthink = time + NAPALM_BURN_INTERVAL;
}

entity Napalm_Spawn(entity powner, vector porg, float lifetime, float lifetime_randfactor, float deathtype,
                    float burnradius, float burndamage, float burnedgedamage, float burntime) {
    entity proj = CSQCProjectile(TRUE, PROJECTILE_HG_NAPALMSHARD, TRUE);
	proj.gravity = 1;
    proj.classname = "napalm";
    proj.realowner = powner;
    proj.owner = powner;
    proj.projectiledeathtype = deathtype;
    proj.movetype = MOVETYPE_BOUNCE;
    proj.pushltime = time + lifetime + random_2() * lifetime_randfactor;
    proj.team = powner.team;
    proj.effects = EF_NODEPTHTEST;
    //proj.meodp_point_offs = '0 0 64';

    proj.napalm_burn_radius = burnradius;
    proj.napalm_burn_damage = burndamage;
    proj.napalm_burn_edgedamage = burnedgedamage;
    proj.napalm_burn_time = burntime;

    //proj.csqcprojectile_extradata = burntime;
    //proj.heal_emitter_radius = burntime;

    proj.touch = Napalm_Touch;
    proj.think = Napalm_Think;
    proj.reset = SUB_Remove;

    proj.nextthink = time;

    PROJECTILE_MAKETRIGGER(proj);
    setorigin(proj, porg);
    //Buffs_MEODP_Point_Attach(proj, Buffs_MEODP_Death_Remove_Multiple);
    return proj;
}

float napalm_init_done;

void Napalm_Init(void) {
    if(napalm_init_done) {
        return;
    }

	CSQCProjectile_Init(PROJECTILE_HG_NAPALMSHARD);
    napalm_init_done = TRUE;
}
