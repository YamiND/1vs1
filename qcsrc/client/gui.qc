entity mainWindow;
float GUI_mouseButtonsPressed;
vector GUI_mouse_pos;
vector GUI_mouse_pos_old;
float GUI_alpha;
float GUI_shiftState;
float GUI_currentWindow;

void GUI_RemoveRecursive(entity me) {
	entity e;
	for(e = me.firstChild; e; e = e.nextSibling)
		if(e.Container_alpha > 0)
			e.showNotify(e);

	me.destroy(me);
	remove(me);
}

float GUI_InputEvent(float bInputType, float nPrimary, float nSecondary) {
	float r;
	r = FALSE;
	draw_reset();
	GUI_mouse_pos = globalToBoxSize(mouse_pos, draw_scale);
	if (nPrimary == K_MOUSE1) {
		if (bInputType == 0) { //Key down
			if not(GUI_mouseButtonsPressed) {
				mainWindow.mousePress(mainWindow, GUI_mouse_pos);
				GUI_mouseButtonsPressed = TRUE;
			}
			r = TRUE;
		} else { //Key up
			if (GUI_mouseButtonsPressed) {
				mainWindow.mouseRelease(mainWindow, GUI_mouse_pos);
				GUI_mouseButtonsPressed = FALSE;
			}
		}
	}
	if (bInputType == 0) {
		if(nPrimary == K_ALT) { GUI_shiftState |= S_ALT; r = TRUE; }
		if(nPrimary == K_CTRL) { GUI_shiftState |= S_CTRL; r = TRUE; }
		if(nPrimary == K_SHIFT) { GUI_shiftState |= S_SHIFT; r = TRUE; }
		if (mainWindow.keyDown(mainWindow, nPrimary, nSecondary, GUI_shiftState)) {
			return TRUE;
		} else if (nPrimary == K_ESCAPE) {
			GUI_Hide();
			return TRUE;
		}
	} else {
		if(nPrimary == K_ALT) { GUI_shiftState &~= (GUI_shiftState & S_ALT); r = TRUE; }
		if(nPrimary == K_CTRL) { GUI_shiftState &~= (GUI_shiftState & S_CTRL); r = TRUE; }
		if(nPrimary == K_SHIFT) { GUI_shiftState &~= (GUI_shiftState & S_SHIFT); r = TRUE; }
	}
	if (GUI_mouse_pos != GUI_mouse_pos_old) {
		if (GUI_mouseButtonsPressed) {
			mainWindow.mouseDrag(mainWindow, GUI_mouse_pos);
		} else
			mainWindow.mouseMove(mainWindow, GUI_mouse_pos);

		GUI_mouse_pos_old = GUI_mouse_pos;
	}
	return r;
}

void GUI_Draw_Remove() {
	float timescale = getstatf(STAT_MOVEVARS_TIMESCALE);
	if (GUI_alpha > 0) {
		if (timescale < 1)
			GUI_alpha -= 0.05;
		else
			GUI_alpha -= frametime * 5;
	} else {
		GUI_RemoveRecursive(mainWindow);
		unloadTooltips();
		mainWindow = world;
		cvar_set("con_chat", ftos(con_chat_save));
		if (CSQC_InputEvent_Callback == GUI_InputEvent)
			CSQC_InputEvent_Callback = NULL;

		return;
	}
	mainWindow.focusEnter(mainWindow);
	mainWindow.showNotify(mainWindow);
	draw_reset();
	drawBackground(SKINGFX_BACKGROUND_INGAME, GUI_alpha * SKINALPHA_BACKGROUND_INGAME, SKINALIGN_BACKGROUND_INGAME, FALSE);
	draw_reset();
	draw_alpha *= GUI_alpha;
	mainWindow.drawGUI(mainWindow);
}
void GUI_Draw() {
	float timescale = getstatf(STAT_MOVEVARS_TIMESCALE);
	if (GUI_alpha < 1) {
		if (timescale < 1)
			GUI_alpha += 0.05;
		else
			GUI_alpha += frametime * 5;
	}
	mainWindow.focusEnter(mainWindow);
	mainWindow.showNotify(mainWindow);
	draw_reset();
	drawBackground(SKINGFX_BACKGROUND_INGAME, GUI_alpha * SKINALPHA_BACKGROUND_INGAME, SKINALIGN_BACKGROUND_INGAME, FALSE);
	draw_reset();
	draw_alpha *= GUI_alpha;
	mainWindow.drawGUI(mainWindow);
	m_tooltip(mainWindow, GUI_mouse_pos);
	Mouse_Enable();
	CSQC_InputEvent_Callback = GUI_InputEvent;
	GUI_InputEvent(1, 0, 0); //workaround for old engines
}

void GUI_Draw_Set() {
	Draw2d_Post_self = self;
	Draw2d_Post = GUI_Draw;
}

void GUI_Show(float window) {
	GUI_mouseButtonsPressed = FALSE;
	GUI_shiftState = FALSE;
	GUI_currentWindow = window;
	if not(mainWindow) {
		con_chat_save = cvar("con_chat");
		con_chat_was_changed = TRUE;
		cvar_set("con_chat", "0");
		SkinInit();
		loadTooltips();
		mainWindow = spawnMainWindow(); mainWindow.configureMainWindow(mainWindow);
		mainWindow.resizeNotify(mainWindow, '0 0 0', eX * CVAR(vid_conwidth) + eY * CVAR(vid_conheight), '0 0 0', eX * CVAR(vid_conwidth) + eY * CVAR(vid_conheight));
	}
	mainWindow.draw2d = GUI_Draw_Set;
	mainWindow.draw2dflag = 1;
	entity e;
	switch (window) {
	case GUI_TEAMSELECT:
		e = GUI_teamSelectDialog;
		break;
	case GUI_GAMEMENU:
		e = GUI_gameMenuDialog;
		break;
	case GUI_GAMESETTINGS:
		e = GUI_gameSettingsDialog;
		break;
	case GUI_VCALL:
		e = GUI_voteCallDialog;
		break;
	case GUI_QUIT:
		e = GUI_quitDialog;
		break;
	case GUI_RADIO:
		e = GUI_radioDialog;
		break;
	case GUI_SAVELOAD:
		e = GUI_saveLoad;
		break;
	}
	if not(e) {
		GUI_Hide();
		return;
	}
	m_activate_window(e);
	m_setpointerfocus(e);
	mainWindow.focused = 1;
	setFocusContainer(mainWindow, e);
}

void GUI_Hide() {
	if (GUI_currentWindow == GUI_GAMEMENU || GUI_currentWindow == GUI_TEAMSELECT || GUI_currentWindow == GUI_SAVELOAD) {
		mainWindow.draw2d = GUI_Draw_Remove;
		mainWindow.draw2dflag = 1;
	} else
		GUI_Show(GUI_GAMEMENU);
}
