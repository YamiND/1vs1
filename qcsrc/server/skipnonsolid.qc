#define SKIPNONSOLID_ESCAPE_STEP 0.1
void(vector start, vector end, float t, entity forent) skipnonsolid_traceline {
    float prev_trace_fract = 0;
    float tries;
    for (tries = 10; tries > 0; tries--) {
        traceline_real(start, end, t, forent);
        if(trace_fraction == 1)
            break;
        trace_fraction = prev_trace_fract + (trace_fraction * (1 - prev_trace_fract));
        if(trace_ent || !(trace_dphitq3surfaceflags & Q3SURFACEFLAG_NONSOLID))
            break;
        if (trace_endpos == start) {
            start += normalize(end - start) * SKIPNONSOLID_ESCAPE_STEP;
        } else
            start = trace_endpos;
        prev_trace_fract = trace_fraction;
    }
    if (tries == 0) print("Can't escape from nonsolid!\n");
}

void(vector start, vector mi, vector ma, vector end, float nomonst, entity forent) skipnonsolid_tracebox {
    float prev_trace_fract = 0;
    float tries;
    for (tries = 10; tries > 0; tries--) {
        tracebox_real(start, mi, ma, end, nomonst, forent);
        if(trace_fraction == 1)
            break;
        trace_fraction = prev_trace_fract + (trace_fraction * (1 - prev_trace_fract));
        if(trace_ent || !(trace_dphitq3surfaceflags & Q3SURFACEFLAG_NONSOLID))
            break;
        if (trace_endpos == start) {
            start += normalize(end - start) * SKIPNONSOLID_ESCAPE_STEP;
        } else
            start = trace_endpos;
        prev_trace_fract = trace_fraction;
    }
    if (tries == 0) print("Can't escape from nonsolid!\n");
}

void(entity ent, entity ignore, float toss_frametime, float toss_count) skipnonsolid_tracetoss {
    //Almost full copy of darkplaces tracetoss but with skipnonsolid_tracebox instead tracebox.
    float i, tries;
    vector end;
    vector velocity_save = ent.velocity;
    vector avelocity_save = ent.avelocity;
    vector origin_save = ent.origin;
    vector angles_save = ent.angles;
    for (i = 0; i < toss_count; i++) {
        ent.velocity_y = ent.velocity_y - (ent.gravity * (vlen(trace_endpos - ent.origin) / vlen(ent.velocity)));
        ent.angles = ent.angles + (ent.avelocity *  toss_frametime);
        end = ent.origin + (ent.velocity * toss_frametime);
        for (tries = 10; tries > 0; tries--) {
            tracebox_real(ent.origin, ent.mins, ent.maxs, end, FALSE, ent);
            if (trace_endpos == ent.origin)
                ent.origin += normalize(ent.velocity) * SKIPNONSOLID_ESCAPE_STEP;
            else
                ent.origin = trace_endpos;
            if(trace_fraction == 1 || trace_ent || !(trace_dphitq3surfaceflags & Q3SURFACEFLAG_NONSOLID))
                break;
        }
        if (trace_fraction < 1) break;
    }
    if (tries == 0) print("Can't escape from nonsolid!\n");
    ent.velocity = velocity_save;
    ent.avelocity = avelocity_save;
    ent.origin = origin_save;
    ent.angles = angles_save;
}

var float() skipnonsolid_ProjectileTouchHandle_NextLink;
float() skipnonsolid_ProjectileTouchHandle {
	if(!other && (trace_dphitq3surfaceflags & Q3SURFACEFLAG_NONSOLID) && !(trace_dphitcontents & self.dphitcontentsmask)) {
		//Trying correct origin
		skipnonsolid_tracebox(self.origin, self.mins, self.maxs, self.origin + (self.velocity * (1 - trace_fraction) * frametime), FALSE, self);
		if (trace_fraction == 1) // The way is clear
			setorigin(self, trace_endpos);
		else // We can't move right to trace_endpos, because we can go through solid surface.
			setorigin(self, self.origin + ((trace_endpos - self.origin) * 0.99));
		UpdateCSQCProjectile(self);
		return TRUE;
	}
	return skipnonsolid_ProjectileTouchHandle_NextLink();
}

void() skipnonsolid_init {
	if not(cvar("sv_gameplayfix_skipnonsolid"))
		return;

	traceline = skipnonsolid_traceline;
	tracebox = skipnonsolid_tracebox;
	tracetoss = skipnonsolid_tracetoss;
	skipnonsolid_ProjectileTouchHandle_NextLink = GameHookChain_ProjectileTouchHandle;
	GameHookChain_ProjectileTouchHandle = skipnonsolid_ProjectileTouchHandle;
}
