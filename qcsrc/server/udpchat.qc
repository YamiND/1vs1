string sv_udpchat_server;
string sv_udpchat_id;
float sv_udpchat_spamstatus;

void UDPChat_ER_Response_Callback(float argc, string response) {
	string s;
	float i, n;
	string from = argv(0);
	string peer = "";
	if (from == sv_udpchat_server)
		peer = from;

	if (peer == "")
		for (i = 1; (s = cvar_string(strcat("sv_udpchat_client", ftos(i)))) != ""; i++)
			if (from == s) {
				peer = s;
				break;
			}

	if (peer == "") {
		print("Unknown peer: ", from, "\n");
		return;
	}

	string msg = substring(response, argv_start_index(2), -1);
	float colon = strstrofs(msg, ":", 0);
	if (colon >= 0)
		bprint("\{3}", "^5\x12 ^3", substring(msg, 0, colon), "^2:^5", substring(msg, colon + 1, -1), "\n");
	else
		bprint("\{3}", "^5\x12 ", msg, "\n");

	if (sv_udpchat_server != "")
	if (peer != sv_udpchat_server)
		ER_Query(sv_udpchat_server, "extResponse udpchat " + msg);

	n = i;
	for (i = 1; i < n; i++) {
		s = cvar_string(strcat("sv_udpchat_client", ftos(i)));
		if (peer != s)
			ER_Query(s, "extResponse udpchat " + msg);
	}
}

void UDPChat_SendPacket(string msg) {
	string packet = "extResponse udpchat " + msg;
	if (sv_udpchat_server != "")
		ER_Query(sv_udpchat_server, packet);

	string s;
	float i;
	for (i = 1; (s = cvar_string(strcat("sv_udpchat_client", ftos(i)))) != ""; i++)
		for (i = 1; (s = cvar_string(strcat("sv_udpchat_client", ftos(i)))) != ""; i++)
			ER_Query(s, packet);
}

void UDPChat_ShowPlayersStatus() {
	if (time < 10)
		return;

	if not(sv_udpchat_spamstatus)
		return;

	float c = cvar("_sv_udpchat_msgsent") + 1;
	if(c >= sv_udpchat_spamstatus) {
		c = 0;
		string s = strcat(" * server ", sv_udpchat_id, " have ", ftos(player_count), "/", ftos(maxclients), " clients");
		if(currentbots > 0)
			s = strcat(s, " (", ftos(currentbots), " bots)");

		UDPChat_SendPacket(s);
	}
	cvar_set("_sv_udpchat_msgsent", ftos(c));
}

var void(entity source, string msg) UDPChat_PupblicPlayerChat_NextLink;
void UDPChat_PupblicPlayerChat(entity source, string msg) {
	if (clienttype(source) == CLIENTTYPE_REAL) {
		string _netname = strreplace(":", "_", source.netname);
		_netname = strreplace("@", "_", _netname);
		string text = strcat(strdecolorize(_netname), "#", ftos(num_for_edict(source)), "@", sv_udpchat_id, ": ", strdecolorize(msg));
		UDPChat_SendPacket(text);
		UDPChat_ShowPlayersStatus();
	}
	UDPChat_PupblicPlayerChat_NextLink(source, msg);
}

float udpchat_game_announced;
var void() UDPChat_RealClientConnect_NextLink;
void UDPChat_RealClientConnect() {
	if not(udpchat_game_announced) {
		UDPChat_SendPacket(" * server " + sv_udpchat_id + " playing " + gamemode_name + " on " + mapname);
		udpchat_game_announced = TRUE;
	}
	UDPChat_RealClientConnect_NextLink();
}

void UDPChat_Init() {
	if not(cvar("sv_udpchat"))
		return;

	sv_udpchat_server = cvar_string_zone_ifneeded("sv_udpchat_server");
	CACHE_CVAR(sv_udpchat_spamstatus);
	sv_udpchat_id = cvar_string_zone_ifneeded("sv_udpchat_id");
    ER_RegisterHandler("udpchat", UDPChat_ER_Response_Callback, world);
	UDPChat_PupblicPlayerChat_NextLink = GameHookChain_PublicPlayerChat;
	GameHookChain_PublicPlayerChat = UDPChat_PupblicPlayerChat;
	UDPChat_RealClientConnect_NextLink = GameHookChain_RealClientConnect;
	GameHookChain_RealClientConnect = UDPChat_RealClientConnect;
	registercvar("_sv_udpchat_msgsent", "0");
}

