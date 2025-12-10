// Slither.sp - Fast slither ability with damage interrupt for VSH/FF2

static bool g_bSlithering[MAXPLAYERS + 1];
static float g_flSlitherCooldown[MAXPLAYERS + 1];
static int g_iSlitherDamageTaken[MAXPLAYERS + 1];
static float g_flOldSpeed[MAXPLAYERS + 1];
static bool g_bSlitherButtonHeld[MAXPLAYERS + 1];
static float g_flNextAnimReplay[MAXPLAYERS + 1];
static int g_iSlitherSoundRef[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

public void Slither_Create(SaxtonHaleBase boss)
{
	g_bSlithering[boss.iClient] = false;
	g_flSlitherCooldown[boss.iClient] = 0.0;
	g_iSlitherDamageTaken[boss.iClient] = 0;
	g_flOldSpeed[boss.iClient] = 0.0;
	g_bSlitherButtonHeld[boss.iClient] = false;
	g_flNextAnimReplay[boss.iClient] = 0.0;
	g_iSlitherSoundRef[boss.iClient] = INVALID_ENT_REFERENCE;
	
	// Default values - can be changed per boss
	boss.SetPropFloat("Slither", "Cooldown", 10.0);
	boss.SetPropFloat("Slither", "Speed", 520.0);
	boss.SetPropInt("Slither", "DamageThreshold", 25);
}

public void Slither_Destroy(SaxtonHaleBase boss)
{
	if (g_bSlithering[boss.iClient])
		Slither_Stop(boss, false);
}

public void Slither_GetHudInfo(SaxtonHaleBase boss, char[] sMessage, int iLength, int iColor[4])
{
	if (g_bSlithering[boss.iClient])
	{
		Format(sMessage, iLength, "%s\nSlither: ACTIVE [R]", sMessage);
	}
	else if (g_flSlitherCooldown[boss.iClient] > GetGameTime())
	{
		float flTimeLeft = g_flSlitherCooldown[boss.iClient] - GetGameTime();
		Format(sMessage, iLength, "%s\nSlither: %.1fs", sMessage, flTimeLeft);
	}
	else
	{
		Format(sMessage, iLength, "%s\nSlither [R]", sMessage);
	}
}

public void Slither_OnButton(SaxtonHaleBase boss, int &buttons)
{
	// Block attacks and other abilities while slithering
	if (g_bSlithering[boss.iClient])
	{
		buttons &= ~IN_ATTACK;
		buttons &= ~IN_ATTACK2;
		buttons &= ~IN_ATTACK3;
		return;
	}
	
	if (buttons & IN_RELOAD)
		g_bSlitherButtonHeld[boss.iClient] = true;
}

public void Slither_OnButtonRelease(SaxtonHaleBase boss, int button)
{
	if (button != IN_RELOAD)
		return;
	
	g_bSlitherButtonHeld[boss.iClient] = false;
	
	if (GameRules_GetRoundState() == RoundState_Preround)
		return;
	
	if (TF2_IsPlayerInCondition(boss.iClient, TFCond_Dazed))
		return;
	
	// Toggle off if already slithering
	if (g_bSlithering[boss.iClient])
	{
		Slither_Stop(boss, false);
		return;
	}
	
	// Check cooldown
	if (g_flSlitherCooldown[boss.iClient] > GetGameTime())
		return;
	
	// Start slithering
	Slither_Start(boss);
}

void Slither_Start(SaxtonHaleBase boss)
{
	int iClient = boss.iClient;
	
	if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return;
	
	g_bSlithering[iClient] = true;
	
	// Store old boss speed
	g_flOldSpeed[iClient] = boss.flSpeed;
	
	// Use much faster speed
	float flSpeed = boss.GetPropFloat("Slither", "Speed");
	boss.flSpeed = flSpeed;
	
	// Force third person
	SetVariantInt(1);
	AcceptEntityInput(iClient, "SetForcedTauntCam");
	
	// Add condition to prevent attacking
	TF2_AddCondition(iClient, TFCond_RestrictToMelee, TFCondDuration_Infinite);
	
	// Use SDK call to play the animation properly
	SDKCall_PlaySpecificSequence(iClient, "slither_loop");
	
	// Animation duration (0.6 seconds)
	g_flNextAnimReplay[iClient] = GetGameTime() + 0.6;
	
	// Only play sound if not in a TF condition that has its own sounds (like rage)
	if (!TF2_IsPlayerInCondition(iClient, TFCond_UberchargedCanteen) && 
	    !TF2_IsPlayerInCondition(iClient, TFCond_Ubercharged))
	{
		char sSound[PLATFORM_MAX_PATH];
		boss.CallFunction("GetSoundAbility", sSound, sizeof(sSound), "Slither");
		if (!StrEmpty(sSound))
		{
			// Play initial sound
			EmitSoundToAll(sSound, iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			g_iSlitherSoundRef[iClient] = EntIndexToEntRef(iClient);
		}
	}
	
	// Start the think timer
	CreateTimer(0.1, Timer_SlitherThink, GetClientUserId(iClient), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Start loop sound after a delay and keep repeating it
	CreateTimer(1.0, Timer_LoopSoundRepeater, GetClientUserId(iClient), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	boss.CallFunction("UpdateHudInfo", 0.0, 0.1);
}

void Slither_Stop(SaxtonHaleBase boss, bool bDamaged)
{
	int iClient = boss.iClient;
	
	g_bSlithering[iClient] = false;
	
	// Stop all slither sounds
	if (g_iSlitherSoundRef[iClient] != INVALID_ENT_REFERENCE)
	{
		int iSoundEnt = EntRefToEntIndex(g_iSlitherSoundRef[iClient]);
		if (iSoundEnt > 0 && IsValidEntity(iSoundEnt))
		{
			char sSound[PLATFORM_MAX_PATH];
			boss.CallFunction("GetSoundAbility", sSound, sizeof(sSound), "Slither");
			if (!StrEmpty(sSound))
				StopSound(iSoundEnt, SNDCHAN_VOICE, sSound);
			
			// Stop loop sound
			char sLoopSound[PLATFORM_MAX_PATH];
			boss.CallFunction("GetSoundAbility", sLoopSound, sizeof(sLoopSound), "SlitherLoop");
			if (!StrEmpty(sLoopSound))
				StopSound(iSoundEnt, SNDCHAN_AUTO, sLoopSound);
		}
		g_iSlitherSoundRef[iClient] = INVALID_ENT_REFERENCE;
	}
	
	// Restore boss speed
	if (g_flOldSpeed[iClient] > 0.0)
		boss.flSpeed = g_flOldSpeed[iClient];
	
	// Restore gravity
	SetEntityGravity(iClient, 1.0);
	
	// Remove attack restriction condition
	TF2_RemoveCondition(iClient, TFCond_RestrictToMelee);
	
	// Return to first person
	SetVariantInt(0);
	AcceptEntityInput(iClient, "SetForcedTauntCam");
	
	// Only apply cooldown if stopped by damage
	if (bDamaged)
	{
		float flCooldown = boss.GetPropFloat("Slither", "Cooldown");
		g_flSlitherCooldown[iClient] = GetGameTime() + flCooldown;
		boss.CallFunction("UpdateHudInfo", 1.0, flCooldown);
	}
	else
	{
		// No cooldown when manually toggled off
		g_flSlitherCooldown[iClient] = 0.0;
	}
}

public Action Timer_SlitherThink(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if (iClient <= 0 || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return Plugin_Stop;
	
	if (!g_bSlithering[iClient])
		return Plugin_Stop;
	
	SaxtonHaleBase boss = SaxtonHaleBase(iClient);
	
	// Replay animation when it ends to create loop effect
	if (GetGameTime() >= g_flNextAnimReplay[iClient])
	{
		SDKCall_PlaySpecificSequence(iClient, "slither_loop");
		g_flNextAnimReplay[iClient] = GetGameTime() + 0.6;
	}
	
	// Keep boss speed at configured value
	float flSpeed = boss.GetPropFloat("Slither", "Speed");
	if (boss.flSpeed != flSpeed)
		boss.flSpeed = flSpeed;
	
	// Wall climbing movement
	Slither_HandleMovement(iClient);
	
	return Plugin_Continue;
}

void Slither_HandleMovement(int iClient)
{
	float vecOrigin[3], vecVelocity[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vecVelocity);
	
	// Get the direction the player is moving
	float flSpeed = SquareRoot(vecVelocity[0] * vecVelocity[0] + vecVelocity[1] * vecVelocity[1]);
	
	// Get eye angles to know where player is looking
	float vecAngles[3];
	GetClientEyeAngles(iClient, vecAngles);
	
	// Get forward vector
	float vecForward[3];
	GetAngleVectors(vecAngles, vecForward, NULL_VECTOR, NULL_VECTOR);
	
	// Trace forward to find walls
	float vecTraceEnd[3];
	vecTraceEnd[0] = vecOrigin[0] + vecForward[0] * 64.0;
	vecTraceEnd[1] = vecOrigin[1] + vecForward[1] * 64.0;
	vecTraceEnd[2] = vecOrigin[2] + vecForward[2] * 64.0;
	
	Handle hTrace = TR_TraceRayFilterEx(vecOrigin, vecTraceEnd, MASK_PLAYERSOLID, RayType_EndPoint, Slither_TraceFilter, iClient);
	
	bool bOnWall = false;
	
	if (TR_DidHit(hTrace))
	{
		float vecNormal[3];
		TR_GetPlaneNormal(hTrace, vecNormal);
		
		// Check if it's a wall or ceiling (not floor)
		if (vecNormal[2] < 0.7) // Floor normal points straight up (1.0)
		{
			bOnWall = true;
			
			// Zero gravity for wall climbing
			SetEntityGravity(iClient, 0.0);
			
			// If player is moving forward, push them UP the wall
			if (flSpeed > 50.0)
			{
				// Add strong upward velocity for fast climbing
				vecVelocity[2] = 400.0; // Fast vertical climb
				
				// Also push towards the wall to stick
				vecVelocity[0] += vecNormal[0] * -200.0;
				vecVelocity[1] += vecNormal[1] * -200.0;
				
				TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vecVelocity);
			}
		}
	}
	
	delete hTrace;
	
	// If not on a wall, use normal gravity
	if (!bOnWall)
		SetEntityGravity(iClient, 1.0);
}

public bool Slither_TraceFilter(int iEntity, int iContentsMask, int iClient)
{
	return iEntity != iClient;
}

public Action Timer_StartLoopSound(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if (iClient <= 0 || !IsClientInGame(iClient) || !IsPlayerAlive(iClient) || !g_bSlithering[iClient])
		return Plugin_Stop;
	
	SaxtonHaleBase boss = SaxtonHaleBase(iClient);
	
	// Get the loop sound from boss
	char sLoopSound[PLATFORM_MAX_PATH];
	boss.CallFunction("GetSoundAbility", sLoopSound, sizeof(sLoopSound), "SlitherLoop");
	
	if (!StrEmpty(sLoopSound))
	{
		// Play the looping sound
		EmitSoundToAll(sLoopSound, iClient, SNDCHAN_AUTO, SNDLEVEL_SCREAMING);
	}
	
	return Plugin_Continue;
}

public Action Timer_LoopSoundRepeater(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if (iClient <= 0 || !IsClientInGame(iClient) || !IsPlayerAlive(iClient) || !g_bSlithering[iClient])
		return Plugin_Stop;
	
	SaxtonHaleBase boss = SaxtonHaleBase(iClient);
	
	// Get the loop sound from boss
	char sLoopSound[PLATFORM_MAX_PATH];
	boss.CallFunction("GetSoundAbility", sLoopSound, sizeof(sLoopSound), "SlitherLoop");
	
	if (!StrEmpty(sLoopSound))
	{
		// Keep playing the loop sound every few seconds
		EmitSoundToAll(sLoopSound, iClient, SNDCHAN_AUTO, SNDLEVEL_SCREAMING);
	}
	
	return Plugin_Continue;
}

public void Slither_OnTakeDamage(SaxtonHaleBase boss, int &iAttacker, int &iInflictor, float &flDamage, int &iDamageType, int &iWeapon, float vecDamageForce[3], float vecDamagePosition[3], int iDamageCustom)
{
	if (!g_bSlithering[boss.iClient])
		return;
	
	int iThreshold = boss.GetPropInt("Slither", "DamageThreshold");
	
	// Check if single hit exceeds threshold
	if (RoundToFloor(flDamage) >= iThreshold)
	{
		PrintToChatAll("%N's Slither interrupted by %d damage!", boss.iClient, RoundToFloor(flDamage));
		Slither_Stop(boss, true);
	}
}