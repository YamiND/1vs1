string wordwrap(string s, float l);
void wordwrap_sprint(string s, float l);
void wordwrap_cb(string s, float l, void(string) callback);
string wordwrap_buffer;

void wordwrap_cb(string s, float l, void(string) callback)
{
	local string c;
	local float lleft, i, j, wlen;

	s = strzone(s);
	lleft = l;
	for (i = 0;i < strlen(s);++i)
	{
		if (substring(s, i, 2) == "\\n")
		{
			callback("\n");
			lleft = l;
			++i;
		}
		else if (substring(s, i, 1) == "\n")
		{
			callback("\n");
			lleft = l;
		}
		else if (substring(s, i, 1) == " ")
		{
			if (lleft > 0)
			{
				callback(" ");
				lleft = lleft - 1;
			}
		}
		else
		{
			for (j = i+1;j < strlen(s);++j)
				//    ^^ this skips over the first character of a word, which
				//       is ALWAYS part of the word
				//       this is safe since if i+1 == strlen(s), i will become
				//       strlen(s)-1 at the end of this block and the function
				//       will terminate. A space can't be the first character we
				//       read here, and neither can a \n be the start, since these
				//       two cases have been handled above.
			{
				c = substring(s, j, 1);
				if (c == " ")
					break;
				if (c == "\\")
					break;
				if (c == "\n")
					break;
				// we need to keep this tempstring alive even if substring is
				// called repeatedly, so call strcat even though we're not
				// doing anything
				callback("");
			}
			wlen = j - i;
			if (lleft < wlen)
			{
				callback("\n");
				lleft = l;
			}
			callback(substring(s, i, wlen));
			lleft = lleft - wlen;
			i = j - 1;
		}
	}
	strunzone(s);
}


void wordwrap_buffer_put(string s)
{
	wordwrap_buffer = strcat(wordwrap_buffer, s);
}

string wordwrap(string s, float l)
{
	string r;
	wordwrap_buffer = "";
	wordwrap_cb(s, l, wordwrap_buffer_put);
	r = wordwrap_buffer;
	wordwrap_buffer = "";
	return r;
}

void wordwrap_buffer_sprint(string s)
{
	wordwrap_buffer = strcat(wordwrap_buffer, s);
	if(s == "\n")
	{
		sprint(self, wordwrap_buffer);
		wordwrap_buffer = "";
	}
}

void wordwrap_sprint(string s, float l)
{
	wordwrap_buffer = "";
	wordwrap_cb(s, l, wordwrap_buffer_sprint);
	if(wordwrap_buffer != "")
		sprint(self, strcat(wordwrap_buffer, "\n"));
	wordwrap_buffer = "";
	return;
}

entity nagger;
float Nagger_SendEntity(entity to, float sendflags)
{
	float nags, i, f, b;
	entity e;
	WriteByte(MSG_ENTITY, ENT_CLIENT_NAGGER);

	nags = 0;
	if (readycount)
		nags |= 1;

	WriteByte(MSG_ENTITY, nags);
	if(nags & 1)
	{
		for(i = 1; i <= maxclients; i += 8)
		{
			for(f = 0, e = edict_num(i), b = 1; b < 256; b *= 2, e = nextent(e))
				if(clienttype(e) != CLIENTTYPE_REAL || e.ready)
					f |= b;
			WriteByte(MSG_ENTITY, f);
		}
	}
	return TRUE;
}
void Nagger_Init()
{
	Net_LinkEntity(nagger = spawn(), FALSE, 0, Nagger_SendEntity);
}

void Nagger_ReadyCounted()
{
	if(nagger)
		nagger.SendFlags |= 1;
}

void ReadyCount();

entity GetPlayer(string name)
{
	float num;
	entity e;
	string ns;

	if(substring(name, 0, 1) == "#") {
		num = stof(substring(name, 1, 999));
		if(num >= 1 && num <= maxclients) {
			for((e = world); num > 0; --num, (e = nextent(e)))
				;
			//if(clienttype(e) == CLIENTTYPE_REAL)
			if(e.classname == "player")
				return e;
		}
	} else {
		ns = strdecolorize(name);
		FOR_EACH_REALPLAYER(e) {
			if(!strcasecmp(strdecolorize(e.netname), ns)) {
				return e;
			}
		}
	}
	return world;
}

//float ctf_clientcommand();
float readyrestart_happened;
void spawnfunc_func_breakable();

.float cmd_floodtime;
.float cmd_floodcount;
float cmd_floodcheck()
{
	if (timeoutStatus != 2)
	{
		if(time == self.cmd_floodtime)
		{
			self.cmd_floodcount += 1;
			if(self.cmd_floodcount > 8)
				return TRUE;
		}
		else
		{
			self.cmd_floodtime = time;
			self.cmd_floodcount = 1;
		}
	}
	return FALSE;
}

void Client_MuteIfNeeded(string _name) {
	string s;
	float i;
	for (i = 0; ; ++i) {
		s = cvar_string(strcat("sv_player_mute_namepattern", ftos(i)));
		if (s == "")
			break;

		if (strstrofs(strdecolorize(_name), s, 0) >= 0) {
			print(_name, " muted with pattern ", s, "\n");
			self.muted = TRUE;
		}
	}
}

void SV_ParseClientCommand(string s) {
	string cmd;
	float tokens;
	entity e;
	if not(self.flags & FL_CLIENT)
	if (ClientPreConnect_Abort())
		return;

	tokens = tokenize_console(s);

	cmd = argv(0);
	if(cmd != "sentcvar")
	if(cmd != "pause")
	if(cmd != "prespawn")
	if(cmd != "spawn")
	if(cmd != "begin")
	{
		if(cmd_floodcheck())
			return;
	}

	if (GameHookChain_ClientCommandHandle(cmd, tokens))
		return;

	if(GameCommand_Vote(s, self)) {
		return;
	} else if(mapvote_client_command(argv(0))) {
		return;
	} else if(cmd == "autoswitch") {
		// be backwards compatible with older clients (enabled)
		self.autoswitch = ("0" != argv(1));
		local string autoswitchmsg;
		if (self.autoswitch) {
			autoswitchmsg = "on";
		} else {
			autoswitchmsg = "off";
		}
		sprint(self, strcat("^1autoswitch turned ", autoswitchmsg, "\n"));
	} else if(cmd == "sentcvar") { // new system
		if(tokens == 2) // undefined cvar: use the default value on the server then
		{
			s = strcat(substring(s, argv_start_index(0), argv_end_index(1) - argv_start_index(0)), " \"", cvar_defstring(argv(1)), "\"");
			tokens = tokenize_console(s);
		}
		Client_GetCvars_Parse();
	} else if(cmd == "spectate") {
		if not(self.flags & FL_CLIENT)
			return;
		ClientKill_TeamChange(-2);
	} else if(cmd == "join") {
		if not(self.flags & FL_CLIENT)
			return;
		if (self.classname != "player" && !lockteams)
			spectator_to_player();
	} else if( cmd == "selectteam" ) {
		if not(self.flags & FL_CLIENT)
			return;
		if( !teamplay ) {
			sprint( self, "selecteam can only be used in teamgames\n");
		} else if(g_campaign) {
		} else if(lockteams) {
			sprint( self, "^7The game has already begun, you must wait until the next map to be able to join a team.\n");
		} else if( argv(1) == "red" ) {
			DoTeamChange(COLOR_TEAM1);
		} else if( argv(1) == "blue" ) {
			DoTeamChange(COLOR_TEAM2);
		} else if( argv(1) == "yellow" ) {
			DoTeamChange(COLOR_TEAM3);
		} else if( argv(1) == "pink" ) {
			DoTeamChange(COLOR_TEAM4);
		} else if( argv(1) == "auto" ) {
			DoTeamChange(-1);
		} else {
			sprint( self, strcat( "selectteam none/red/blue/yellow/pink/auto - \"", argv(1), "\" not recognised\n" ) );
		}
	} else if(cmd == "ready") {
		if not(self.flags & FL_CLIENT)
			return;

		if(inWarmupStage || cvar("sv_ready_restart") || GameHook_ReadyAllowed())
		{
			if(!readyrestart_happened || cvar("sv_ready_restart_repeatable"))
			{
				if (self.ready) // toggle
				{
					self.ready = FALSE;
					bprint(self.netname, "^2 is ^1NOT^2 ready\n");
				}
				else
				{
					self.ready = TRUE;
					bprint(self.netname, "^2 is ready\n");
				}
				Warmup_UpdateNote();
				// cannot reset the game while a timeout is active!
				if(!timeoutStatus)
					ReadyCount();
			} else {
				sprint(self, "^1Game has already been restarted\n");
			}
		}
	} else if(cmd == "maplist") {
		sprint(self, maplist_reply);
	} else if(cmd == "lsmaps") {
		sprint(self, lsmaps_reply);
	} else if(cmd == "lsmaps2") {
		msg_entity = self;
		WriteByte(MSG_ONE, SVC_TEMPENTITY);
		WriteByte(MSG_ONE, TE_CSQC_MAPLIST);
		WriteString(MSG_ONE, lsmaps_reply2);
	} else if(cmd == "gameclient") {
		s = argv(1);
		print("Game client for ", self.netname, ": ", s, "\n");

		if (s == "xonotic") {
			self.gameclient = CLIENT_XONOTIC;
			self.muted = TRUE;
			self.netname = "Unsupported client";
			cvar_set("connections_xonotic", ftos(cvar("connections_xonotic") + 1));
		} else if (s == "rexuiz") {
			self.gameclient = CLIENT_REXUIZ;
			cvar_set("connections_rexuiz", ftos(cvar("connections_rexuiz") + 1));
		} else if (s == "nexuiz") {
			self.gameclient = CLIENT_NEXUIZ;
			cvar_set("connections_nexuiz", ftos(cvar("connections_nexuiz") + 1));
		} else if (s == "oldnexuiz") {
			self.gameclient = CLIENT_OLDNEXUIZ;
			cvar_set("connections_oldnexuiz", ftos(cvar("connections_oldnexuiz") + 1));
		}
	} else if(cmd == "records") {
		sprint(self, records_reply);
	} else if(cmd == "voice") {
		if(tokens >= 3)
			VoiceMessage(argv(1), substring(s, argv_start_index(2), argv_end_index(-1) - argv_start_index(2)));
		else
			VoiceMessage(argv(1), "");
	} else if(cmd == "say") {
		if(tokens >= 2)
		{
			chat_say(self, FALSE, world, substring(s, argv_start_index(1), argv_end_index(-1) - argv_start_index(1)), 1);
			if (substring(argv(1), 0, 1) == "/")
				GameCommand_Vote(strcat("vote call ", substring(s, strstrofs(s, "/", 0) + 1, -1)), self);
		}
	} else if(cmd == "say_team") {
		if(tokens >= 2)
			chat_say(self, TRUE, world, substring(s, argv_start_index(1), argv_end_index(-1) - argv_start_index(1)), 1);
	} else if(cmd == "tell") {
		e = GetCommandPlayerSlotTargetFromTokenizedCommand(tokens, 1);
		if(e && tokens > ParseCommandPlayerSlotTarget_firsttoken)
		{
			chat_say(self, FALSE, e, substring(s, argv_start_index(ParseCommandPlayerSlotTarget_firsttoken), argv_end_index(-1) - argv_start_index(ParseCommandPlayerSlotTarget_firsttoken)), TRUE);
		}
		else
		{
			if(tokens > ParseCommandPlayerSlotTarget_firsttoken)
				trigger_magicear_processmessage_forallears(self, -1, world, substring(s, argv_start_index(ParseCommandPlayerSlotTarget_firsttoken), argv_end_index(-1) - argv_start_index(ParseCommandPlayerSlotTarget_firsttoken)));
			sprint(self, "ERROR: usage: tell # playerid text...\n");
		}
	} else if(cmd == "info") {
		cmd = cvar_string(strcat("sv_info_", argv(1)));
		if(cmd == "")
			sprint(self, "ERROR: unsupported info command\n");
		else
			wordwrap_sprint(cmd, 1111);
	} else if(cmd == "teamstatus") {
		Score_NicePrint(self);
	} else if(cmd == "cvar_changes") {
		sprint(self, cvar_changes);
	} else if(cmd == "menu_select") {
		Menu_Select(argv(1), stof(argv(2)));
	} else if(cmd == "location_select") {
		LocationRequest_Select(stof(argv(1)), stof(argv(2)));
	} else if(cmd == "mylocation") {
		sprint(self, strcat("your location: ", vtos(self.origin), "\n"));
	} else {
		//if(ctf_clientcommand())
		//	return;
		// grep for Cmd_AddCommand_WithClientCommand to find them all
		if(cmd != "status")
		if(cmd != "max")
		if(cmd != "monster")
		if(cmd != "scrag")
		if(cmd != "wraith")
		if(cmd != "gimme")
		if(cmd != "god")
		if(cmd != "notarget")
		if(cmd != "fly")
		if(cmd != "noclip")
		if(cmd != "give")
		//if(cmd != "say") // handled above
		//if(cmd != "say_team") // handled above
		if(cmd != "kill")
		if(cmd != "pause")
		if(cmd != "ping")
		if(cmd != "name")
		if(cmd != "color")
		if(cmd != "rate")
		if(cmd != "pmodel")
		if(cmd != "playermodel")
		if(cmd != "playerskin")
		if(cmd != "prespawn")
		if(cmd != "spawn")
		if(cmd != "begin")
		if(cmd != "pings")
		if(cmd != "sv_startdownload")
		if(cmd != "download")
		if(cmd != "rate_burstsize")
		{
			print("WARNING: Invalid clientcommand by ", self.netname, ": ", s, "\n");
			return;
		}
		if (cmd == "name") {
			string name = substring(s, argv_start_index(1), -1);
			if (self.retard > 0)
				return;

			if (self.gameclient == CLIENT_XONOTIC)
				return;

			Client_MuteIfNeeded(name);
			IRC_Announce_Name(self, name);
			if (strlen(strdecolorize(name)) > 48) {
				name = substring(name, 0, 47);
				s = strcat("name ", substring(name, 0, 47), "~");
			}
		}
		clientcommand(self,s);
	}
}

void ReadyRestartForce()
{
	local entity e;
	restart_active = 1;

	bprint("^1Server is restarting...\n");

	VoteReset();

	// clear overtime
	if (checkrules_overtimesadded > 0) {
		//we have to decrease timelimit to its original value again!!
		float newTL;
		newTL = cvar("timelimit");
		newTL -= checkrules_overtimesadded * cvar("timelimit_overtime");
		cvar_set("timelimit", ftos(newTL));
	}

	checkrules_suddendeathend = checkrules_overtimesadded = checkrules_suddendeathwarning = 0;


	readyrestart_happened = 1;
	game_starttime = time + RESTART_COUNTDOWN;

	Warmup_Finish();
	//reset the .ready status of all players (also spectators)
	FOR_EACH_CLIENTSLOT(e)
		e.ready = 0;
	readycount = 0;
	Nagger_ReadyCounted(); // NOTE: this causes a resend of that entity, and will also turn off warmup state on the client

	if(cvar("teamplay_lockonrestart") && teamplay) {
		lockteams = 1;
		bprint("^1The teams are now locked.\n");
	}

	//initiate the restart-countdown-announcer entity
	restartTimer = spawn();
	restartTimer.think = restartTimer_Think;
	restartTimer.nextthink = (cvar("sv_ready_restart_after_countdown") ? game_starttime : time);

	//after a restart every players number of allowed timeouts gets reset, too
	if(cvar("sv_timeout"))
	{
		FOR_EACH_REALPLAYER(e)
			e.allowedTimeouts = cvar("sv_timeout_number");
	}
}

void ReadyRestart()
{
	// no arena, assault support yet...
	if(GameHook_ReadyRestartHard() | gameover | intermission_running) {
		localcmd("\nrestart\n");
		return;
	} else
		localcmd("\nsv_hook_gamerestart;");

	ReadyRestartForce();

	// reset ALL scores, but only do that at the beginning
	//of the countdown if sv_ready_restart_after_countdown is off!
	//Otherwise scores could be manipulated during the countdown!
	if (!cvar("sv_ready_restart_after_countdown"))
		Score_ClearAll();
}

/**
 * Counts how many players are ready. If not enough players are ready, the function
 * does nothing. If all players are ready, the timelimit will be extended and the
 * restart_countdown variable is set to allow other functions like PlayerPostThink
 * to detect that the countdown is now active. If the cvar sv_ready_restart_after_countdown
 * is not set the map will be resetted.
 *
 * Function is called after the server receives a 'ready' sign from a player.
 */
void ReadyCount()
{
	local entity e;
	readycount = readywait = 0;

	FOR_EACH_REALPLAYER(e)
	{
		++readywait;
		if(e.ready)
			++readycount;
	}

	Nagger_ReadyCounted();

	if(readycount) // at least one is ready
	if(readycount == readywait) // and, everyone is ready
		ReadyRestart();
}

/**
 * Restarts the map after the countdown is over (and cvar sv_ready_restart_after_countdown
 * is set)
 */
void restartTimer_Think() {
	world_reset(TRUE);
	Score_ClearAll();
	remove(self);
	restart_active = 0;
	return;
}
