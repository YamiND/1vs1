float g_nadgets_sentry_beam_range;
float g_nadgets_sentry_beam_dps;
float g_nadgets_sentry_beam_force;
float g_nadgets_sentry_beam_energyrequired;
float g_nadgets_sentry_beam_initialdelay;
float g_nadgets_sentry_beam_amount;
float g_nadgets_sentry_capture_range;
float g_nadgets_sentry_capture_damage_delay;
float g_nadgets_sentry_capture_speed;
//float g_nadgets_sentry_disown_on_death; //in nadgets.qc for some reason
float g_nadgets_sentry_health;
float g_nadgets_sentry_health_degenerate_when_damaged;
float g_nadgets_sentry_energy_regen;
float g_nadgets_sentry_levitation;
float g_nadgets_sentry_damagefactor;
float g_nadgets_sentry_damagefactor_nadgets;
float g_nadgets_sentry_repairfactor;
float g_nadgets_sentry_repairfactor_nadgets;
float g_nadgets_sentry_shock_damage;
float g_nadgets_sentry_shock_force;
float g_nadgets_sentry_shock_energy_cost;
float g_nadgets_sentry_friction;
float g_nadgets_sentry_pushfactor;

.float spawntime;

float HG_Sentry_TargetIsTaken(entity emitter, entity targ) {
	entity e;
    for(e = emitter.owner.hg_sentry_emitter_next; e; e = e.hg_sentry_emitter_next)
        if(e != emitter && e.enemy == targ)
            return TRUE;
    return FALSE;
}

float HG_Sentry_TargetIsValid(entity emitter, entity e) {
    entity sentry = emitter.owner;

    if(!sentry.realowner)
        return FALSE;

    if(PLAYER_DEAD(e))
        return FALSE;

    if(!IsDifferentTeam(e, sentry.realowner)/* && !Buffs_Present(sentry.realowner, BUFF_MEDIC) */)
        return FALSE;

    if(HG_Sentry_TargetIsTaken(emitter, e))
        return FALSE;

    vector o = sentry.origin + sentry.view_ofs;
    vector t = e.origin + e.view_ofs;

    if(vlen(o - t) > g_nadgets_sentry_beam_range)
        return FALSE;

    traceline(o, t, MOVE_NORMAL, sentry);

    if(trace_ent != e)
        return FALSE;

    return TRUE;
}

entity HG_Sentry_FindTarget(entity emitter) {
    entity sentry = emitter.owner;

    entity targ, p;
    float mindist, dist;
#if 0
    float medic = Buffs_Present(sentry.realowner, BUFF_MEDIC), medicflag;
#endif
	float diffteam;
    vector t, o = sentry.origin + sentry.view_ofs;

    mindist = g_nadgets_sentry_beam_range;

    if(!sentry.realowner)
        return world;

    FOR_EACH_PLAYER(p) if not(PLAYER_DEAD(p)) {
        diffteam = (p != sentry.realowner && IsDifferentTeam(sentry, p));

#if 0
        if(diffteam) {
            if(medicflag)
                continue;
        } else if(!medic)
            continue;
#endif
		if not(diffteam)
			continue;

        if(HG_Sentry_TargetIsTaken(emitter, p))
            continue;

        t = WarpZone_FindNearestOrigin(o, p.origin + p.view_ofs, FALSE);
        dist = WarpZone_FindNearestOrigin_length;
#if 0
		t = p.origin;
		dist = vlen(o - t);
#endif

        if(diffteam /* || (!diffteam && medicflag) */) {
            if(dist > mindist)
                continue;
        } else if(dist > g_nadgets_sentry_beam_range)
            continue;

        WarpZone_TraceLine(o, t, MOVE_NORMAL, sentry);
        //traceline(o, t, MOVE_NORMAL, sentry);

        if(trace_ent != p)
            continue;

        mindist = dist;
        targ = p;

#if 0
        if(!diffteam)
            medicflag = TRUE;
#endif
    }

    return targ;
}

void HG_Sentry_Beam_Think(void) {
    entity targ = self.enemy.enemy;
    vector end = targ.origin + targ.view_ofs * (0.5 + 0.5 * sin(time * 5 + num_for_edict(self)));
    vector start = self.owner.origin + self.owner.view_ofs;
    vector end_transformed;

    end = WarpZone_FindNearestOrigin(start, end, TRUE);
    WarpZone_TraceLine(start, end, MOVE_NORMAL, self);

    targ = trace_ent;
    end_transformed = trace_endpos;
    end = WarpZone_UnTransformOrigin(WarpZone_trace_transform, trace_endpos);
#if 0
    traceline(start, end, MOVE_NORMAL, self);
    targ = trace_ent;
    end_transformed = trace_endpos;
#endif

    if(!self.origin)
        self.origin = end;
    else
        self.origin += (end - self.origin) * frametime * 10;

    end = self.origin;

    if(targ.takedamage == DAMAGE_AIM && time > self.cnt) {
        Damage(targ, self, self.owner.realowner, g_nadgets_sentry_beam_dps * 0.1, HG_SENTRY, end, g_nadgets_sentry_beam_force * normalize(end_transformed - WarpZone_TransformOrigin(WarpZone_trace_transform, start)));
        self.cnt = time + 0.1; // FIXME: this is inaccurate
    }

    end -= normalize(end - start) * 5;

    if(start != self.zapper_beam_start) {
        self.zapper_beam_start = start;
        self.SendFlags |= 2;
    }

    if(end != self.zapper_beam_end) {
        self.zapper_beam_end = end;
        self.SendFlags |= 4;
    }

    self.nextthink = time;
}

entity HG_Sentry_Beam_Spawn(entity emitter) {
    entity e = spawn(), sentry = emitter.owner;
    e.classname = "hg_sentry_beam";
    e.owner = sentry;
    e.enemy = emitter;
    e.team = sentry.team;
    e.zapper_beam_start = sentry.origin + sentry.view_ofs;
    e.zapper_beam_end = e.zapper_beam_start;
    e.think = HG_Sentry_Beam_Think;
    e.nextthink = time;

    Net_LinkEntity(e, FALSE, 0, W_Zapper_Beam_Send);

    return e;
}

void HG_Sentry_Emitter_Think() {
	entity sentry = self.owner;

	if(time < sentry.cnt || sentry.hg_sentry_energy < g_nadgets_sentry_beam_energyrequired) {
		if(self.zapper_beam)
			remove(self.zapper_beam);
		self.zapper_beam = world;
		self.enemy = world;
	} else if(!self.zapper_beam) {
		if(!HG_Sentry_TargetIsValid(self, self.enemy))
			self.enemy = world;

		if(!self.enemy)
			self.enemy = HG_Sentry_FindTarget(self);

		if(self.enemy)
			self.zapper_beam = HG_Sentry_Beam_Spawn(self);
	} else {
		if(self.enemy && !HG_Sentry_TargetIsValid(self, self.enemy))
			self.enemy = HG_Sentry_FindTarget(self);

		if(!self.enemy) {
			remove(self.zapper_beam);
			self.zapper_beam = world;
			self.enemy = world;
		}
	}

	self.nextthink = time;
}

entity HG_Sentry_Emitter_Spawn(entity sentry) {
    entity e = spawn();
    e.classname = "hg_sentry_emitter";
    e.owner = sentry;
    e.origin = sentry.origin + sentry.view_ofs;
    e.think = HG_Sentry_Emitter_Think;
    e.nextthink = time;
	return e;
}

void HG_Sentry_Emitter_Remove(entity emitter) {
    if(emitter.zapper_beam)
        remove(emitter.zapper_beam);
    remove(emitter);
}

void HG_Sentry_Interrupt_Capture(void) {
    if(self.hg_sentry_capture_player)
	if(self.hg_sentry_capture_player.hg_sentry_capture_pb) {
        remove(self.hg_sentry_capture_player.hg_sentry_capture_pb);
		self.hg_sentry_capture_player.hg_sentry_capture_pb = world;
	}

    self.hg_sentry_capture_player = world;
    self.hg_sentry_capture_progress = 0;
}

void HG_Sentry_SetOwner(entity sentry, entity newowner) {
    HG_Waypoint_Remove(sentry.hg_waypoint);

    sentry.team = (teamplay ? newowner.team : 0);
    sentry.colormap = num_for_edict(newowner);
    sentry.aiment.colormap = sentry.colormap;

    if(newowner) {
        sentry.skin = 0;
        sentry.aiment.effects &~= EF_NODRAW;
        sentry.aiment.color = '0.3 0.3 0.3' + 0.7 * TeamColor((teamplay ? sentry.team : COLOR_TEAM3));
    } else {
        sentry.skin = 1;
        sentry.aiment.effects |= EF_NODRAW;
    }

    if(sentry.realowner.classname == "player")
        sentry.realowner.hg_detonables -= 1;

    sentry.realowner = newowner;
    sentry.aiment.realowner = newowner;

    if(newowner) {
        newowner.hg_detonables += 1;
        //centerprint_spec(newowner, strcat("^3You have claimed a ^1", HG_TypeToExpandedName(HG_SENTRY), "^3!"));
        centerprint(newowner, strcat("^3You have claimed a ^1", HG_TypeToExpandedName(HG_SENTRY), "^3!"));
    }
}

void HG_Sentry_Remove(void) {
    dropentities(self);
    HG_Sentry_Interrupt_Capture();

    if(self.realowner.classname == "player")
        self.realowner.hg_detonables -= 1;

    if(self.hg_waypoint)
        WaypointSprite_Disown(self.hg_waypoint, 0.5);

    if(self.aiment) {
        stopsound(self.aiment, CHAN_PROJECTILE);
        remove(self.aiment);
    }

	entity e;
    for(e; (e = find(e, classname, "hg_sentry_emitter"));)
        if(e.owner == self)
            HG_Sentry_Emitter_Remove(e);

	if (self.hg_sentry_capture_player)
	if (self.hg_sentry_capture_player.hg_sentry_capture_pb) {
		remove(self.hg_sentry_capture_player.hg_sentry_capture_pb);
		self.hg_sentry_capture_player.hg_sentry_capture_pb = world;
	}
    remove(self);
}

void HG_Sentry_Explode(void) {
    te_blast(self.origin + self.view_ofs);
    HG_Sentry_Remove();
}

void HG_Sentry_Levitate(void) {
    // oscillation effect
    // FIXME: doesn't work properly without g_nadgets_sentry_levitation
    // TODO: maybe move this to CSQC

    float shift;
	if (g_nadgets_sentry_levitation)
	for(shift = 0; shift < PI * 2; shift += 0.1) {
        vector new_origin = self.origin + frametime * '0 0 8' * sin(self.spawntime + time + self.phase + shift);
        tracebox(new_origin, self.mins, self.maxs, new_origin, MOVE_NORMAL, self);

        if(!trace_startsolid) {
            setorigin(self, new_origin);
            break;
        }
    }

    self.phase += shift;

    // dampen velocity to prevent the sentry from moving forever, i.e. after being hook-dragged.
    self.velocity = self.velocity * (1 - frametime * g_nadgets_sentry_friction);

    if(g_nadgets_sentry_levitation && g_nadgets_sentry_pushfactor) {
        // this hack is used to benefit from the "step" elevation of MOVETYPE_WALK while dragging a levitating sentry.
        // very low .gravaity is assigned to the sentry at spawn, which makes it seem like the sentry is still floating while being dragged.

        if(self.pushltime - (time + g_maxpushtime) > frametime) {
            // hook not attached
            self.movetype = MOVETYPE_FLY;
        } else {
            // hook attached
            self.movetype = MOVETYPE_WALK;
        }
    }
}

void HG_Sentry_Orphaned_Think(void) {
    entity e;

    HG_Sentry_Levitate();

    if(self.hg_sentry_capture_player) {
        e = self.hg_sentry_capture_player;

        if(PLAYER_DEAD(e) || time - e.lastdamage < g_nadgets_sentry_capture_damage_delay || vlen(e.origin - self.origin) > g_nadgets_sentry_capture_range)
            HG_Sentry_Interrupt_Capture();
        else {
            traceline(self.origin, e.origin, MOVE_NOMONSTERS, self);
            if(trace_fraction < 1)
                HG_Sentry_Interrupt_Capture();
        }
    }

    if(!self.hg_sentry_capture_player) FOR_EACH_PLAYER(e) {
        if(PLAYER_DEAD(e))
            continue;

        if(time - e.lastdamage < g_nadgets_sentry_capture_damage_delay || vlen(e.origin - self.origin) > g_nadgets_sentry_capture_range)
            continue;

        traceline(self.origin, e.origin, MOVE_NOMONSTERS, self);
        if(trace_fraction < 1)
            continue;

        self.hg_sentry_capture_player = e;
		if not(e.hg_sentry_capture_pb)
		e.hg_sentry_capture_pb = ProgressBar_Create("Capturing", e);

        break;
    }

    if(self.hg_sentry_capture_player) {
        e = self.hg_sentry_capture_player;

        self.hg_sentry_capture_progress = approach(self.hg_sentry_capture_progress, 1.0, g_nadgets_sentry_capture_speed * frametime);
        ProgressBar_SetValue(e.hg_sentry_capture_pb, self.hg_sentry_capture_progress);

        if(self.hg_sentry_capture_progress == 1) {
            HG_Sentry_SetOwner(self, e);
            HG_Sentry_Interrupt_Capture();
        }
        //self.hg_sentry_capture_player.buff_stealth_time = time;
    }
}

void HG_Sentry_Think(void) {
    entity o = self.realowner;

    HG_Sentry_Levitate();

    if(o && ((teamplay && self.team != o.team) || !o.iscreature))
        o = world;

    if(!o || PLAYER_DEAD(o)) {
        if(g_nadgets_sentry_disown_on_death /* && roundstate == ROUNDSTATE_GAME */) {
            HG_Sentry_SetOwner(self, world);
        } else if(!o) {
            HG_Sentry_Explode();
            return;
        }
    }

    if(self.health < g_nadgets_sentry_health)
        self.health = approach(self.health, 0, frametime * g_nadgets_sentry_health_degenerate_when_damaged);

    if(!self.health) {
        HG_Sentry_Explode();
        return;
    }

    if(self.health < g_nadgets_sentry_health) {
        self.effects |= EF_FLAME;
    } else {
        self.effects &~= EF_FLAME;
    }

    self.hg_sentry_energy = approach(self.hg_sentry_energy, 1, frametime * g_nadgets_sentry_energy_regen);

    if(self.realowner)
        HG_Waypoint();
    else
        HG_Sentry_Orphaned_Think();

    setorigin(self.aiment, self.origin + self.view_ofs);
    self.aiment.scale = bound(0.01, self.hg_sentry_energy, 1);
    self.aiment.light_lev = 100 + self.aiment.scale * 200;

#if 0
    o = self;
    self = self.aiment;
    HealParticleEmitter(o.realowner);
    self = o;
#endif

    self.nextthink = time;
}

void HG_Sentry_Damage(entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force) {
    if(!self.realowner || IsDifferentTeam(attacker, self.realowner)) {
        if(DEATH_ISHG(deathtype))
            damage *= g_nadgets_sentry_damagefactor_nadgets;
        else
            damage *= g_nadgets_sentry_damagefactor;

        self.health = bound(0, self.health - damage, self.health);
    } else {
        if(DEATH_ISHG(deathtype))
            damage *= g_nadgets_sentry_repairfactor_nadgets;
        else
            damage *= g_nadgets_sentry_repairfactor;

        Heal(self, inflictor, attacker, damage, 0, g_nadgets_sentry_health, 0, deathtype, 0, 0, hitloc, '0 0 0');
    }

    if(self.health <= 0)
        HG_Sentry_Explode();
}

void HG_Sentry_MEODP_Death(entity attacker, entity inflictor) {
    HG_Sentry_Explode();
}

void HG_Sentry_Trigger(void) {
    entity e, aimtarg, aimtransform;
    vector o, aimloc, aimloc_untransformed;

    makevectors(self.v_angle);
	antilag_begin(self);
    W_SetupShot(self, 0, "", -1);
    o = w_shotorg;

    WarpZone_TraceLine(o, o + w_shotdir * MAX_SHOT_DISTANCE, MOVE_NORMAL, self);

    while(trace_ent && trace_ent.classname == "hg_sentry" && !IsDifferentTeam(trace_ent, self))
        WarpZone_TraceLine(trace_endpos + w_shotdir, trace_endpos + w_shotdir * MAX_SHOT_DISTANCE, MOVE_NORMAL, self);

    aimloc = trace_endpos;
    aimtarg = trace_ent;
    aimtransform = WarpZone_trace_transform;
    aimloc_untransformed = WarpZone_UnTransformOrigin(aimtransform, aimloc);

    float c_dmg = g_nadgets_sentry_shock_damage;
    float c_frc = g_nadgets_sentry_shock_force;
    float c_cost;

#if 0
    if(Buffs_Present(self, BUFF_ADEPT))
        c_cost = CVAR(g_nadgets_sentry_adept_shock_energy_cost);
    else
#endif
        c_cost = g_nadgets_sentry_shock_energy_cost;

    float found, triggered;

    for(e = world; (e = find(e, classname, "hg_sentry"));) if(e.realowner == self) {
        ++found;

        if(e.hg_sentry_energy < c_cost)
            continue;

        o = e.origin + e.view_ofs;

        #define IS_GOOD_HIT (vlen(trace_endpos - aimloc) < 1 || (aimtarg && aimtarg.takedamage && trace_ent == aimtarg))

        WarpZone_TraceLine(o, aimloc + normalize(aimloc - o), MOVE_NORMAL, self);
		entity targ = ((trace_fraction < 1) ? trace_ent : world);

        if(!IS_GOOD_HIT) {
            // Aiming through a warpzone, sentry can hit directly
            WarpZone_TraceLine(o, aimloc, MOVE_NORMAL, self);
        }

        entity wz = warpzone_chain_begin;
        while(!IS_GOOD_HIT && wz) {
            // Sentry can hit neither directly nor through the warpzone we aimed through (if any).
            // Let's see if we can hit through another warpzone.
            WarpZone_TraceLine(o, WarpZone_UnTransformOrigin(wz, aimloc), MOVE_NORMAL, self);
            wz = wz.warpzone_chain;
        }

        if(IS_GOOD_HIT) {
            vector end_visual = WarpZone_UnTransformOrigin(WarpZone_trace_transform, trace_endpos);
            vector dir = normalize(end_visual - o);
            vector endpos = trace_endpos;
            float noimpact = (trace_dphitq3surfaceflags & Q3SURFACEFLAG_NOIMPACT);
            vector force = c_frc * dir;

			if (targ)
				Damage(targ, self, self, c_dmg, HG_SENTRY | HITTYPE_SECONDARY, endpos, force);

            dlc_sound(e, CHAN_WEAPON, ((random() > 0.5) ? "misc/arc1.wav": "misc/arc2.wav"), VOL_BASE, ATTN_NORM);
            W_Zapper_Attack2_Effect((teamplay ? self.team : COLOR_TEAM3), o, end_visual);

#if 0
            if(targ.takedamage && Buffs_Present(self, BUFF_ADEPT)) {
                var arc = CVAR(g_nadgets_sentry_adept_shock_arc);

                if(arc) {
                    ArcDamage(targ, self, c_dmg, HG_SENTRY | HITTYPE_SECONDARY | HITTYPE_BOUNCE,
                        CVAR(g_nadgets_sentry_adept_shock_arc_range), arc,
                        CVAR(g_nadgets_sentry_adept_shock_arc_force), COLOR_TEAM3, sentry_arc_hit
                    );
                }
            }
#endif

            if(targ.solid == SOLID_BSP && !noimpact)
                Damage_DamageInfo(endpos, c_dmg, 0, 0, force, WEP_ZAPPER | HITTYPE_SECONDARY, self);

            e.hg_sentry_energy = bound(0, e.hg_sentry_energy - c_cost, 1);
            ++triggered;
        }

        #undef IS_GOOD_HIT
    }
	antilag_end();

    if(triggered)
        sound(self, CHAN_WEAPON2, "weapons/rocket_mode.wav", VOL_BASE, ATTN_NORM);
    else if(found)
        sound(self, CHAN_WEAPON2, "weapons/unavailable.wav", VOL_BASE, ATTN_NORM);
}

HG_HOOKFUNCTION(sentry, Attack) {
    vector o = self.origin;

    entity e = spawn();
    setmodel(e, "models/rtzsentry.iqm");
    setsize(e, HG_SENTRY_MINS, HG_SENTRY_MAXS);
    setorigin(e, o);

    if(!move_out_of_solid(e, MOVE_NOMONSTERS)) {
        remove(e);
        //bigprint_spec(self, "Can't put a sentry here!", "", 1);
        centerprint(self, "Can't put a sentry here!");
        return HG_ATTACK_FAIL_COOLDOWN;
    }

	e.spawnorigin = e.origin;
    e.classname = "hg_sentry";
    e.team = self.team;
    e.realowner = self; // can't use owner here because we want to be blocked by it
    e.solid = SOLID_BBOX;
    e.movetype = (g_nadgets_sentry_levitation ? MOVETYPE_FLY : (g_nadgets_sentry_pushfactor ? MOVETYPE_WALK : MOVETYPE_TOSS));
    e.angles = '0 360 0' * random();
    e.reset = HG_Sentry_Remove;
    e.think = HG_Sentry_Think;
    e.nextthink = time;
    e.hg_type = HG_SENTRY;
    e.view_ofs = '0 0 100';
    e.takedamage = DAMAGE_AIM;
    e.colormap = num_for_edict(e.realowner);
    e.health = g_nadgets_sentry_health;
    e.event_damage = HG_Sentry_Damage;
    e.cnt = time + g_nadgets_sentry_beam_initialdelay;
    e.spawntime = time;
    e.damageforcescale = e.pushfactor = g_nadgets_sentry_pushfactor;
	if (e.pushfactor > 0)
		e.touch = push_touch;

    if(g_nadgets_sentry_levitation) {
        // also see HG_Sentry_Levitate
        e.gravity = 0.001;
    }

    self.hg_detonables += 1;

    //Buffs_MEODP_Point_Attach(e, HG_Sentry_MEODP_Death);

    entity c = spawn();
    setmodel(c, "models/ebomb.mdl");
    c.skin = 3;
    c.colormap = e.colormap;
    c.pflags = PFLAGS_FULLDYNAMIC;
    c.color = '0.3 0.3 0.3' + 0.7 * TeamColor(((self.team > 0) ? self.team : COLOR_TEAM3));
    c.owner = self;
    c.effects |= EF_DOUBLESIDED;
    dlc_sound(c, CHAN_PROJECTILE, "weapons/electro_fly.wav", 0.5, 2);

    e.aiment = c;

    entity tail = e;
	float i;
    for(i = 0; i < g_nadgets_sentry_beam_amount; ++i) {
        tail.hg_sentry_emitter_next = HG_Sentry_Emitter_Spawn(e);
        tail = tail.hg_sentry_emitter_next;
    }

    // TODO: a better sound?
    dlc_sound(self, CHAN_PROJECTILE, "weapons/grenade_stick.wav", 1, ATTN_NORM);
    return HG_ATTACK_OK;
}

HG_HOOKFUNCTION(sentry, Init) {
	CACHE_CVAR(g_nadgets_sentry_beam_range);
	CACHE_CVAR(g_nadgets_sentry_beam_dps);
	CACHE_CVAR(g_nadgets_sentry_beam_force);
	CACHE_CVAR(g_nadgets_sentry_beam_energyrequired);
	CACHE_CVAR(g_nadgets_sentry_beam_initialdelay);
	CACHE_CVAR(g_nadgets_sentry_beam_amount);
	CACHE_CVAR(g_nadgets_sentry_capture_range);
	CACHE_CVAR(g_nadgets_sentry_capture_damage_delay);
	CACHE_CVAR(g_nadgets_sentry_capture_speed);
	//float g_nadgets_sentry_disown_on_death; //in nadgets.qc for some reason
	CACHE_CVAR(g_nadgets_sentry_health);
	CACHE_CVAR(g_nadgets_sentry_health_degenerate_when_damaged);
	CACHE_CVAR(g_nadgets_sentry_energy_regen);
	CACHE_CVAR(g_nadgets_sentry_levitation);
	CACHE_CVAR(g_nadgets_sentry_damagefactor);
	CACHE_CVAR(g_nadgets_sentry_damagefactor_nadgets);
	CACHE_CVAR(g_nadgets_sentry_repairfactor);
	CACHE_CVAR(g_nadgets_sentry_repairfactor_nadgets);
	CACHE_CVAR(g_nadgets_sentry_shock_damage);
	CACHE_CVAR(g_nadgets_sentry_shock_force);
	CACHE_CVAR(g_nadgets_sentry_shock_energy_cost);
    CACHE_CVAR(g_nadgets_sentry_friction);
    CACHE_CVAR(g_nadgets_sentry_pushfactor);
    return HG_INIT_OK;
}
