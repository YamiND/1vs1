float g_balance_kill_delay;
float g_changeteam_banned;
float g_maxplayers;
float sv_spectate;
float sv_timeout_number;
float sv_maxidle;
float sv_maxidle_forcespec;

void ClientSetView(entity to) {
	if not(clienttype(self) == CLIENTTYPE_REAL)
		return;

	msg_entity = self;
	WriteByte(MSG_ONE, SVC_SETVIEW);
	WriteEntity(MSG_ONE, to);
}

void PutClientToSpot(entity spot) {
	self.deadflag = DEAD_NO;
	self.angles = spot.angles;
	self.angles_z = 0;
	self.fixangle = TRUE;
	self.crouch = FALSE;
	self.view_ofs = PL_VIEW_OFS;
	setorigin (self, spot.origin);
	ClientSetView(self);
}

/*
=============
PutClientInServer

Called when a client spawns in the server
=============
*/
.float just_connected;
void PutClientInServer()
{
	if (self.just_connected) {
		self.team = -1;
		self.just_connected = FALSE;
		if (time + 5 < game_starttime)
			announce(self, "announcer/robotic/prepareforbattle.wav");
	}
	entity e;
	FOR_EACH_PLAYER(e)
		e.entcs.SendFlags |= 16;

	if(clienttype(self) == CLIENTTYPE_BOT)
	{
		self.classname = "player";
	}
	if(gameover)
		self.classname = "observer";

	if(self.classname == "player") {
		entity spot;
		float oldteam = self.team;
		if (self.team < 0) {
			if(clienttype(self) == CLIENTTYPE_BOT)
				self.team = self.bot_forced_team;

			JoinBestTeam(self, FALSE);
		}
		if (self.team != oldteam)
			ScoreKeeper_Touch(self);

		spot = GameHook_SelectSpawnPoint();
		if(!spot) {
			if (clienttype(self) == CLIENTTYPE_REAL)
				centerprint(self, "Sorry, no spawnpoints available!\nHope your team can fix it...");

			print(self.netname, " not have place to spawn\n");
			spectator_observer_spawn(FALSE);
			return;
		}
		player_spawn(spot);
	} else if(self.classname == "observer") {
		spectator_observer_spawn(TRUE);
	}
}

float ClientInit_SendEntity(entity to, float sf)
{
	float i, t;
	WriteByte(MSG_ENTITY, ENT_CLIENT_INIT);
	WriteByte(MSG_ENTITY, sf);
	if (sf & 1) {
		for(i = 1; i <= 24; ++i)
			WriteByte(MSG_ENTITY, (get_weaponinfo(i)).impulse + 1);
	}
	if (sf & 2) {
		t = 0;
		if (g_campaign)
			t |= 1;

		if (sv_spectate)
			t |= 2;

		if (to.netaddress == "local")
			t |= 4;

		WriteByte(MSG_ENTITY, t);
	}
	if (sf & 4) {
		if(sv_foginterval && world.fog != "")
			WriteString(MSG_ENTITY, world.fog);
		else
			WriteString(MSG_ENTITY, "");
	}
	if (sf & 8) {
		WriteString(MSG_ENTITY, cvar_string("sv_vote_commands"));
	}
	if (sf & 16)
		GameMenu_Send();

	if (sf & 32) {
		WriteByte(MSG_ENTITY, teamplay);
		t = 0;
		if(teamplay) {
			CheckAllowedTeams(self);
			if(c1 >= 0) t |= 1; if(c2 >= 0) t |= 2; if(c3 >= 0) t |= 4; if(c4 >= 0) t |= 8;
		}
		WriteByte(MSG_ENTITY, t);
	}

	if(sf & 64) {
		ProjInfo_Send();
	}

	if (sf & 128) {
		WriteString(MSG_ENTITY, map_description); 
		string s;
		s = strcat("This is ^1Rexuiz^7 ", cvar_string("g_nexuizversion"));
		string profile = cvar_string("g_profile");
		if(profile != "")
			s = strcat(s, "\n^8g_profile ^3", profile, "^8");

		if (g_campaign)
			s = campaign_message;
		else {
			string motd = cvar_string("sv_motd");
			if (motd != "")
				s = strcat(s, "\n\n^8MOTD:\n^7", strreplace("\\n", "\n", cvar_string("sv_motd")));
		}
		WriteString(MSG_ENTITY, s);
	}

	return TRUE;
}

entity client_init;
void ClientInit_Spawn()
{
	client_init = spawn();
	Net_LinkEntity(client_init, FALSE, 0, ClientInit_SendEntity);
}

/*
=============
SetNewParms
=============
*/
void SetNewParms (void)
{
	// initialize parms for a new player
	parm1 = -(86400 * 366);
	GameHook_SetNewParms();
}

/*
=============
SetChangeParms
=============
*/
void SetChangeParms (void)
{
	// save parms for level change
	parm1 = self.parm_idlesince - time;
	GameHook_SetChangeParms();
}

/*
=============
DecodeLevelParms
=============
*/
void DecodeLevelParms (void)
{
	// load parms
	self.parm_idlesince = parm1;
	if(self.parm_idlesince == -(86400 * 366))
		self.parm_idlesince = time;

	// whatever happens, allow 60 seconds of idling directly after connect for map loading
	self.parm_idlesince = max(self.parm_idlesince, time - sv_maxidle + 60);
	GameHook_DecodeLevelParms();
}

/*
=============
ClientKill

Called when a client types 'kill' in the console
=============
*/

void ClientKill_Now_TeamChange()
{
	if(self.killindicator_teamchange == -2)
	{
		player_to_spec(self);
	}
	else if(self.killindicator_teamchange == -1)
	{
		self.team = -1;
		JoinBestTeam(self, FALSE);
	}
	else
		ChangeTeam(self, self.killindicator_teamchange, FALSE);
}

void ClientKill_Now()
{
	if(self.killindicator_teamchange)
		ClientKill_Now_TeamChange();
	else
		Damage(self, self, self, 100000, DEATH_KILL, self.origin, '0 0 0');

	if(self.killindicator)
	{
		dprint("Cleaned up after a leaked kill indicator.\n");
		remove(self.killindicator);
		self.killindicator = world;
	}
}
void KillIndicator_Think()
{
	if (!self.owner.modelindex)
	{
		self.owner.killindicator = world;
		remove(self);
		return;
	}

	if(self.cnt <= 0)
	{
		self = self.owner;
		ClientKill_Now(); // no oldself needed
		return;
	}
	else
	{
		if(self.cnt <= 10)
			setmodel(self, strcat("models/sprites/", ftos(self.cnt), ".spr32"));
		if(clienttype(self.owner) == CLIENTTYPE_REAL)
		{
			if(self.cnt <= 10)
				announce(self.owner, strcat("announcer/robotic/", ftos(self.cnt), ".wav"));
			if(self.owner.killindicator_teamchange)
			{
				if(self.owner.killindicator_teamchange == -1)
					centerprint(self.owner, strcat("Changing team in ", ftos(self.cnt), " seconds"));
				else
					centerprint(self.owner, strcat("Changing to ", ColoredTeamName(self.owner.killindicator_teamchange), " in ", ftos(self.cnt), " seconds"));
			}
			else
				centerprint(self.owner, strcat("^1Suicide in ", ftos(self.cnt), " seconds"));
		}
		self.nextthink = time + 1;
		self.cnt -= 1;
	}
}

void ClientKill_TeamChange (float targetteam) // 0 = don't change, -1 = auto
{
	float killtime;
	entity e;
	killtime = GameHook_KillDelayMod(g_balance_kill_delay);

	self.killindicator_teamchange = targetteam;

	if(!self.killindicator)
	{
		if(killtime <= 0 || !self.modelindex || self.deadflag != DEAD_NO || FastTeamSwitchAllowed(self, targetteam))
		{
			ClientKill_Now();
		}
		else
		{
			self.killindicator = spawn();
			self.killindicator.owner = self;
			self.killindicator.scale = 0.5;
			setattachment(self.killindicator, self, "");
			setorigin(self.killindicator, '0 0 52');
			self.killindicator.think = KillIndicator_Think;
			self.killindicator.nextthink = time + (self.lip) * 0.05;
			self.killindicator.cnt = ceil(killtime);
			self.killindicator.count = bound(0, ceil(killtime), 10);
			sprint(self, strcat("^1You'll be dead in ", ftos(self.killindicator.cnt), " seconds\n"));

			for(e = world; (e = find(e, classname, "body")) != world; )
			{
				if(e.enemy != self)
					continue;
				e.killindicator = spawn();
				e.killindicator.owner = e;
				e.killindicator.scale = 0.5;
				setattachment(e.killindicator, e, "");
				setorigin(e.killindicator, '0 0 52');
				e.killindicator.think = KillIndicator_Think;
				e.killindicator.nextthink = time + (e.lip) * 0.05;
				e.killindicator.cnt = ceil(killtime);
			}
			self.lip = 0;
		}
	}
	if(self.killindicator)
	{
		if(targetteam)
			self.killindicator.colormod = TeamColor(targetteam);
		else
			self.killindicator.colormod = '0 0 0';
	}
}

void ClientKill (void)
{
	ClientKill_TeamChange(0);
}

void DoTeamChange(float destteam)
{
	float t, c0;
	if(!teamplay)
	{
		if(destteam >= 0)
			SetPlayerColors(self, destteam);
		return;
	}
	if (self.team <= 0)
	if (destteam > 0)
	if not(isJoinAllowed()) {
		centerprint_atprio(self, CENTERPRIO_MAPVOTE, PREVENT_JOIN_TEXT);
		return;
	}
	if(self.classname == "player")
	if(destteam == -1)
	{
		CheckAllowedTeams(self);
		t = FindSmallestTeam(self);
		switch(self.team)
		{
			case COLOR_TEAM1: c0 = c1; break;
			case COLOR_TEAM2: c0 = c2; break;
			case COLOR_TEAM3: c0 = c3; break;
			case COLOR_TEAM4: c0 = c4; break;
			default:          c0 = 999;
		}
		switch(t)
		{
			case 1:
				if(c0 > c1)
					destteam = COLOR_TEAM1;
				break;
			case 2:
				if(c0 > c2)
					destteam = COLOR_TEAM2;
				break;
			case 3:
				if(c0 > c3)
					destteam = COLOR_TEAM3;
				break;
			case 4:
				if(c0 > c4)
					destteam = COLOR_TEAM4;
				break;
		}
		if(destteam == -1)
			return;
	}
	if(destteam == self.team && destteam >= 0 && !self.killindicator)
		return;
	ClientKill_TeamChange(destteam);
}

void FixClientCvars(entity e)
{
	stuffcmd(e, strcat("\nin_bindmap 0 0\n", GameHook_FixClientCvars(), "\n"));
}

void Check_ForRetard(entity player) {
	string tail = cvar_string("sv_retard_nets");
	string head;
	string address_check = strcat(player.netaddress, ".");
	if (player.netname == retardplayername)
		player.retard = 1;

	while (tail != "") {
		head = car(tail);
		tail = cdr(tail);
		if (head == "")
			continue;

		if (strstrofs(address_check, head, 0) == 0) {
			player.retard = 1;
			print("Retard connected with address ", address_check, " and pattern ", head, "\n");
			break;
		}
	}
}

float ClientPreConnect_Abort() {
	if (self.just_connected)
		return FALSE;

	if(Ban_MaybeEnforceBan(self))
		return TRUE;

	self.just_connected = TRUE;
	self.team = -1;
	self.retard = -1;
	Check_ForRetard(self);
	return FALSE;
}

/*
=============
ClientConnect

Called when a client connects to the server
=============
*/
void ClientConnect (void)
{
	if not(self.flags & FL_CLIENT) {
		if (ClientPreConnect_Abort())
			return;

		self.flags = FL_CLIENT;
	}
	if (self.retard > 0)
		self.netname = retardplayername;

	DecodeLevelParms();

	self.classname = "player_joining";
	self.team = -1; //clear engine assigned values
	if(player_count<0)
	{
		dprint("BUG player count is lower than zero, this cannot happen!\n");
		player_count = 0;
	}

	PlayerScore_Attach(self);
	ScoreKeeper_Touch(self);

	bot_clientconnect();

	if (g_campaign) {
		self.classname = "player";
		campaign_bots_may_start = 1;
	} else if (GameHook_ForbidSpectators()) {
		self.classname = "player";
	} else if (sv_spectate == 1) {
		self.classname = "observer";
	} else {
		if(teamplay)
		{
			if(g_balance_teams || g_balance_teams_force)
			{
				self.classname = "player";
			}
			else
			{
				self.classname = "observer"; // do it anyway
			}
		}
		else
		{
			self.classname = "player";
		}
	}

	self.playerid = (playerid_last = playerid_last + 1);
	chat_bubble_spawn();

	//stuffcmd(self, "set tmpviewsize $viewsize \n");

	bprint ("^4", self.netname, "^4 connected\n");
	stuffcmd(self, strcat(clientstuff, "\n"));
	stuffcmd(self, strcat("exec maps/", mapname, ".cfg\n"));
	stuffcmd(self, "cl_particles_reloadeffects\n");

	FixClientCvars(self);

	// spawnfunc_waypoint sprites
	WaypointSprite_InitClient(self);

	// get other cvars from player
	Client_GetCvars();

	attach_entcs();

	bot_relinkplayerlist();

	self.spectatortime = time;
	if(blockSpectators)
	{
		sprint(self, strcat("^7You have to become a player within the next ", ftos(g_maxplayers_spectator_blocktime), " seconds, otherwise you will be kicked, because spectators aren't allowed at this time!\n"));
	}

	self.jointime = time;
	self.allowedTimeouts = sv_timeout_number;

	if(!sv_foginterval && world.fog != "")
		stuffcmd(self, strcat("\nfog ", world.fog, "\nr_fog_exp2 0\nr_drawfog 1\n"));

	if (clienttype(self) == CLIENTTYPE_REAL)
	{
		GameHookChain_RealClientConnect();
	}
	GameHookChain_ClientConnect();
}

/*
=============
ClientDisconnect

Called when a client disconnects from the server
=============
*/
void ClientDisconnect (void)
{
	if not(self.flags & FL_CLIENT)
	{
		print("Warning: ClientDisconnect without ClientConnect\n");
		return;
	}

	bot_clientdisconnect();

	if(self.entcs)
		detach_entcs();

	bprint ("^4",self.netname);
	bprint ("^4 disconnected\n");

	self.classname = "disconnecting";

	PlayerClear(FALSE);

	// Here, everything has been done that requires this player to be a client.

	self.flags &~= FL_CLIENT;
	self.just_connected = FALSE;

	if (self.killindicator)
		remove (self.killindicator);

	WaypointSprite_PlayerGone();

	bot_relinkplayerlist();

	// remove laserdot
	if(self.weaponentity)
		if(self.weaponentity.lasertarget)
			remove(self.weaponentity.lasertarget);

	PlayerScore_Detach(self);

	if(self.clientstatus)
		strunzone(self.clientstatus);

	ClearPlayerSounds();

	self.playerid = 0;
	self.retard = 0;
	self.muted = 0;
	ReadyCount();

	// free cvars
	Client_GetCvars_Free();

	if (clienttype(self) == CLIENTTYPE_REAL)
		GameHookChain_RealClientDisconnect();

	if (teamplay) {
		AuditTeams(FALSE);
		if (autoswap_last_best == self)
			autoswap_last_best = world;
	}
}

/**
 * Determines whether the player is allowed to join. This depends on cvar
 * g_maxplayers, if it isn't used this function always return TRUE, otherwise
 * it checks whether the number of currently playing players exceeds g_maxplayers.
 * @return bool TRUE if the player is allowed to join, false otherwise
 */
float isJoinAllowed() {
	if (!g_maxplayers)
		return TRUE;

	local entity e;
	local float currentlyPlaying;
	FOR_EACH_REALCLIENT(e) {
		if (e != self) //avoid wrong self-counting in teamplay
		if (e.classname == "player" || (teamplay && e.team > 0))
			currentlyPlaying += 1;
	}
	if(currentlyPlaying < g_maxplayers)
		return TRUE;

	return FALSE;
}

/**
 * Checks whether the client is an observer or spectator, if so, he will get kicked after
 * g_maxplayers_spectator_blocktime seconds
 */
void checkSpectatorBlock() {
	if(self.classname == "spectator" || self.classname == "observer") {
		if( time > (self.spectatortime + g_maxplayers_spectator_blocktime) ) {
			sprint(self, "^7You were kicked from the server because you are spectator and spectators aren't allowed at the moment.\n");
			dropclient(self);
		}
	}
}

/*
=============
PlayerPreThink

Called every frame for each client before the physics are run
=============
*/
void PlayerPreThink (void)
{
	self.stat_game_starttime = game_starttime;
	self.stat_leadlimit = leadlimit;
	if(blockSpectators && frametime)
		// WORKAROUND: only use dropclient in server frames (frametime set). Never use it in cl_movement frames (frametime zero).
		checkSpectatorBlock();

	if (intermission_running) {
		IntermissionThink();
		return;
	}
	if(self.classname == "player") {
		player_think();
		self.spectatee_status = (self.BUTTON_ZOOM ? 256 : 0);
	} else if(self.classname == "observer") {
		spectator_observer_think();
		self.spectatee_status = num_for_edict(self);
	} else if(self.classname == "spectator") {
		spectator_think();
		float oldspectatee_status;
		oldspectatee_status = self.spectatee_status & 255;
		self.spectatee_status = num_for_edict(self.enemy) | (self.enemy.BUTTON_ZOOM ? 256 : 0);
		if((self.spectatee_status & 255) != (oldspectatee_status & 255))
			GameHook_InitSpectator();
	}
}

/*
=============
PlayerPostThink

Called every frame for each client after the physics are run
=============
*/
.float idlekick_lasttimeleft;
void PlayerPostThink (void)
{
	// Savage: Check for nameless players
	if (strlen(strdecolorize(self.netname)) < 1) {
		self.netname = "Empty Name";
		//stuffcmd(self, "seta _cl_name Player\n");
	}

	if (frametime)
	if (clienttype(self) == CLIENTTYPE_REAL)
	{
		// WORKAROUND: only use dropclient in server frames (frametime set). Never use it in cl_movement frames (frametime zero).
		float timeleft, drop, maxidle;
		if (sv_maxidle_forcespec && sv_spectate && self.classname == "player") {
			maxidle = sv_maxidle_forcespec;
			drop = FALSE;
		} else if (sv_maxidle) {
			maxidle = sv_maxidle;
			drop = TRUE;
		} else
			maxidle = 0;

		if (maxidle)
		if not(g_campaign)
		if not(GameHook_ForbidSpectators())
		if not(intermission_running) {
			timeleft = ceil(maxidle - (time - self.parm_idlesince));
			if (timeleft <= 0) {
				announce(self, "announcer/robotic/terminated.wav");
				if (drop) {
					bprint("^3", self.netname, "^3 was kicked for idling.\n");
					dropclient(self);
				} else {
					bprint("^3", self.netname, "^3 was moved to spectators for idling.\n");
					player_to_spec(self);
				}
				return;
			} else if(timeleft <= 10) {
				if(timeleft != self.idlekick_lasttimeleft)
				{
					centerprint_atprio(self, CENTERPRIO_IDLEKICK, strcat("^3Stop idling!\n^3", (drop ? "Disconnecting" : "Moving to spectators") , " in ", ftos(timeleft), "..."));
					announce(self, strcat("announcer/robotic/", ftos(timeleft), ".wav"));
				}
			} else
				centerprint_expire(self, CENTERPRIO_IDLEKICK);

			self.idlekick_lasttimeleft = timeleft;
		}
	}
	if(self.classname == "player")
		player_post_think();
}

void Client_ReadCvars()
{
	CACHE_CVAR(g_balance_kill_delay);
	CACHE_CVAR(g_changeteam_banned);
	CACHE_CVAR(g_maxplayers);
	CACHE_CVAR(g_maxplayers_spectator_blocktime);
	CACHE_CVAR(sv_spectate);
	CACHE_CVAR(sv_timeout_number);
	CACHE_CVAR(sv_maxidle);
	CACHE_CVAR(sv_maxidle_forcespec);
}

void PutTeamToServer(float t) {
	entity e, oldself;
	FOR_EACH_CLIENT(e)
		if (e.team == t)
		if (e.classname != "player") {
			e.classname = "player";
			oldself = self;
			self = e;
			PutClientInServer();
			self = oldself;
		}
}

void Client_GetCvars() {
	stuffcmd(self, "sendcvar cl_retard\n"
			"sendcvar cl_autoswitch\n"
			"sendcvar cl_saboteur\n"
			"sendcvar cl_playerdetailreduction\n"
			"sendcvar scr_centertime\n"
			"sendcvar cl_gunalpha\n"
			"sendcvar cl_weaponpriority\n"
			"sendcvar cl_weaponpriority0\n"
			"sendcvar cl_weaponpriority1\n"
			"sendcvar cl_weaponpriority2\n"
			"sendcvar cl_weaponpriority3\n"
			"sendcvar cl_weaponpriority4\n"
			"sendcvar cl_weaponpriority5\n"
			"sendcvar cl_weaponpriority6\n"
			"sendcvar cl_weaponpriority7\n"
			"sendcvar cl_weaponpriority8\n"
			"sendcvar cl_weaponpriority9\n"
			"sendcvar cl_autotaunt\n"
			"sendcvar cl_voice_directional\n"
			"sendcvar cl_voice_directional_taunt_attenuation\n"
			"sendcvar cl_hitsound\n"
	);
#ifdef ALLOW_FORCEMODELS
	stuffcmd(self, "sendcvar cl_forceplayermodels\n"
			"sendcvar cl_forceplayermodelsfromnexuiz\n"
	);
#endif
	stuffcmd(self, "sendcvar cl_gunalign\n");
}

void Client_GetCvars_Parse() {
	string s = strcat1(argv(1));
	string val = strcat1(argv(2));
	if (s == "cl_retard") {
		if (stof(val)) {
			self.netname = retardplayername;
			self.retard = 1;
		}
	} else if (s == "cl_autoswitch")
		self.autoswitch = stof(val);
	else if (s == "cl_saboteur")
		self.saboteur = stof(val);
	else if (s == "cl_playerdetailreduction")
		self.cvar_cl_playerdetailreduction = stof(val);
	else if (s == "scr_centertime")
		self.cvar_scr_centertime = stof(val);
	else if (s == "cl_gunalpha")
		self.cvar_cl_gunalpha = stof(val);
	else if (s == "cl_weaponpriority") {
		unzone_ifneeded(self.cvar_cl_weaponpriority);
		self.cvar_cl_weaponpriority = strzone(W_FixWeaponOrder_ForceComplete(val));
		self.switchweapon = w_getbestweapon(self);
	} else if (substring(s, 0, 17) == "cl_weaponpriority") {
		float ind = stof(substring(s, 17, 1));
		unzone_ifneeded(self.cvar_cl_weaponpriorities[ind]);
		(self.cvar_cl_weaponpriorities[ind]) = strzone(W_FixWeaponOrder_AllowIncomplete(val));
	} else if (s == "cl_autotaunt")
		self.cvar_cl_autotaunt = stof(val);
	else if (s == "cl_voice_directional")
		self.cvar_cl_voice_directional = stof(val);
	else if (s == "cl_voice_directional_taunt_attenuation")
		self.cvar_cl_voice_directional_taunt_attenuation = stof(val);
	else if (s == "cl_hitsound")
		self.cvar_cl_hitsound = stof(val);
#ifdef ALLOW_FORCEMODELS
	else if (s == "cl_forceplayermodels")
		self.cvar_cl_forceplayermodels = stof(val);
	else if (s == "cl_forceplayermodelsfromnexuiz")
		self.cvar_cl_forceplayermodelsfromnexuiz = stof(val);
#endif
	else if (s == "cl_gunalign") {
		self.cvar_cl_gunalign = stof(val);
	}
}

void Client_GetCvars_Free() {
	unzone_ifneeded(self.cvar_cl_weaponpriority);
	self.cvar_cl_weaponpriority = "";
	float i;
	for (i = 0; i < 10; i++) {
		unzone_ifneeded(self.cvar_cl_weaponpriorities[i]);
		(self.cvar_cl_weaponpriorities[i]) = "";
	}
}
