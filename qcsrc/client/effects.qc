/*
.vector fx_start;
.vector fx_end;
.float  fx_with;
.string fx_texture;
.float  fx_lifetime;

void b_draw()
{
    //Draw_CylindricLine(self.fx_start, self.fx_end, self.fx_with, self.fx_texture, 0, time * 3, '1 1 1', 0.7, DRAWFLAG_ADDITIVE);
    Draw_CylindricLine(self.fx_start, self.fx_end, self.fx_with, self.fx_texture, (self.fx_with/256), 0, '1 1 1', 1, DRAWFLAG_ADDITIVE);

}
void b_make(vector s,vector e, string t,float l,float z)
{
    entity b;
    b = spawn();
    b.fx_texture = t;
    b.fx_start = s;
    b.fx_end = e;
    b.fx_with = z;
    b.think = SUB_Remove;
    b.nextthink = time + l;
	b.draw = b_draw;

	//b.dphitcontentsmask = DPCONTENTS_SOLID | DPCONTENTS_BODY | DPCONTENTS_PLAYERCLIP;
}
*/

void cl_effetcs_lightningarc(vector from, vector to,float seglength,float drifts,float drifte,float branchfactor,float branchfactor_add)
{
    vector direction,dirnew, pos, pos_l;
    float length, steps, steplength, i,drift;

    length     = vlen(from - to);
    if(length < 1)
        return;

    steps      = floor(length / seglength);
    if(steps < 1)
    {
        te_lightning1(world,from,to);
        return;
    }

    steplength = length / steps;
    direction  = normalize(to - from);
    pos_l = from;
    if(length > seglength)
    {
        for(i = 1; i < steps; i += 1)
        {
            drift = drifts * (1 - (i / steps)) + drifte * (i / steps);
            dirnew = normalize(direction * (1 - drift) + randomvec() * drift);
            pos = pos_l +  dirnew * steplength;
            te_lightning1(world,pos_l,pos);
            //b_make(pos_l, pos,"particles/lightning2",0.25,64);
            if(random() < branchfactor)
                cl_effetcs_lightningarc(pos, pos + (dirnew * length * 0.25),seglength,drifts,drifte,min(branchfactor + branchfactor_add,1),branchfactor_add);

            pos_l = pos;
        }
        te_lightning1(world,pos_l,to);
        //b_make(pos_l, to,"particles/lightning2",0.25,64);

    }
    else
        te_lightning1(world,from,to);
        //b_make(from, to,"particles/lightning2",0.25,64);

}

void Net_ReadLightningarc()
{
	vector from, to;

    from_x = ReadCoord(); from_y = ReadCoord(); from_z = ReadCoord();
    to_x   = ReadCoord(); to_y   = ReadCoord(); to_z   = ReadCoord();

    if(CVAR(cl_effects_lightningarc_simple))
    {
        te_lightning1(world,from,to);
    }
    else
    {
        cl_effetcs_lightningarc(from,to,
				CVAR(cl_effects_lightningarc_segmentlength),
				CVAR(cl_effects_lightningarc_drift_start),
				CVAR(cl_effects_lightningarc_drift_end),
				CVAR(cl_effects_lightningarc_branchfactor_start),
				CVAR(cl_effects_lightningarc_branchfactor_add));
    }

}

void Net_ReadBlast(void) {
    vector loc;
    loc_x = ReadCoord(); loc_y = ReadCoord(); loc_z = ReadCoord();
    pointparticles(particleeffectnum("TE_TEI_BIGEXPLOSION"), loc, '0 0 0', 1);
    entity e = spawn();
    setorigin(e, loc);
    sound(e, CHAN_PROJECTILE, "weapons/rocket_impact.wav", VOL_BASE, ATTN_NORM);
    remove(e);
}

void Net_ReadBigLightningarc(void) {
	vector from, to;

    from_x = ReadCoord(); from_y = ReadCoord(); from_z = ReadCoord();
    to_x   = ReadCoord(); to_y   = ReadCoord(); to_z   = ReadCoord();

	vector vd = to - from;
	vector v1 = from;
	vector v2;
	float pert = vlen(v1) * 0.05;
	float en = particleeffectnum("RM_LIGHTNING_TEAM2");
	float i;
	for (i = 1; i <= 4; i++) {
		v2 = from + (vd * 0.2 * i) + randomvec() * pert;
		trailparticles(world, en, v1, v2);
		v1 = v2;
	}
	trailparticles(world, en, v1, to);
}
