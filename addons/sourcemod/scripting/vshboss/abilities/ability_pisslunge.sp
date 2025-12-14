// PissLunge.sp - Instant kill lunge ability with carving animation for VSH/FF2

static bool g_bPissLunging[MAXPLAYERS + 1];
static float g_flPissLungeCooldown[MAXPLAYERS + 1];
static float g_flPissLungeEndTime[MAXPLAYERS + 1];
static bool g_bPissLungeButtonHeld[MAXPLAYERS + 1];
static bool g_bPissLungeMissed[MAXPLAYERS + 1];
static bool g_bPissLungeHit[MAXPLAYERS + 1];
static int g_iPissLungeSoundRef[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
static float g_flPissLungeStartTime[MAXPLAYERS + 1];
static float g_flPissLungeNextPushAt[MAXPLAYERS + 1];
static float g_vecPissLungeInitialAngles[MAXPLAYERS + 1][3];
static bool g_bPissLungeEnabled[MAXPLAYERS + 1];

public void PissLunge_Create(SaxtonHaleBase boss)
{
	g_bPissLunging[boss.iClient] = false;
	g_flPissLungeCooldown[boss.iClient] = 0.0;
	g_flPissLungeEndTime[boss.iClient] = 0.0;
	g_bPissLungeButtonHeld[boss.iClient] = false;
	g_bPissLungeMissed[boss.iClient] = false;
	g_bPissLungeHit[boss.iClient] = false;
	g_iPissLungeSoundRef[boss.iClient] = INVALID_ENT_REFERENCE;
	g_bPissLungeEnabled[boss.iClient] = false; // Start disabled
	
	// Default values - can be changed per boss
	boss.SetPropFloat("PissLunge", "Cooldown", 5.0);
	boss.SetPropFloat("PissLunge", "Duration", 1.0);
	boss.SetPropFloat("PissLunge", "Speed", 1100.0);
	boss.SetPropFloat("PissLunge", "Range", 100.0);
}

public void PissLunge_Destroy(SaxtonHaleBase boss)
{
	if (g_bPissLunging[boss.iClient])
		PissLunge_Stop(boss);
}

public void PissLunge_GetHudInfo(SaxtonHaleBase boss, char[] sMessage, int iLength, int iColor[4])
{
	// Only show if enabled
	if (!g_bPissLungeEnabled[boss.iClient])
		return;
	
	if (g_bPissLunging[boss.iClient])
	{
		Format(sMessage, iLength, "%s\nPiss Lunge: ACTIVE [M3]", sMessage);
	}
	else if (g_flPissLungeCooldown[boss.iClient] > GetGameTime())
	{
		float flTimeLeft = g_flPissLungeCooldown[boss.iClient] - GetGameTime();
		Format(sMessage, iLength, "%s\nPiss Lunge: %.1fs", sMessage, flTimeLeft);
	}
	else
	{
		Format(sMessage, iLength, "%s\nPiss Lunge [M3]", sMessage);
	}
}

public void PissLunge_OnButton(SaxtonHaleBase boss, int &buttons)
{
	// Only work if enabled
	if (!g_bPissLungeEnabled[boss.iClient])
		return;
	
	// Block attacks while lunging
	if (g_bPissLunging[boss.iClient])
	{
		buttons &= ~IN_ATTACK;
		buttons &= ~IN_ATTACK2;
		buttons &= ~IN_ATTACK3;
		return;
	}
	
	if (buttons & IN_ATTACK3)
		g_bPissLungeButtonHeld[boss.iClient] = true;
}

public void PissLunge_OnButtonRelease(SaxtonHaleBase boss, int button)
{
	if (button != IN_ATTACK3)
		return;
	
	// Only work if enabled
	if (!g_bPissLungeEnabled[boss.iClient])
		return;
	
	g_bPissLungeButtonHeld[boss.iClient] = false;
	
	if (GameRules_GetRoundState() == RoundState_Preround)
		return;
	
	if (TF2_IsPlayerInCondition(boss.iClient, TFCond_Dazed))
		return;
	
	// Already lunging
	if (g_bPissLunging[boss.iClient])
		return;
	
	// Check cooldown
	if (g_flPissLungeCooldown[boss.iClient] > GetGameTime())
		return;
	
	// Start lunge
	PissLunge_Start(boss);
}

void PissLunge_Start(SaxtonHaleBase boss)
{
	int iClient = boss.iClient;
	
	if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return;
	
	g_bPissLunging[iClient] = true;
	g_bPissLungeMissed[iClient] = false;
	g_bPissLungeHit[iClient] = false;
	
	float flDuration = boss.GetPropFloat("PissLunge", "Duration");
	g_flPissLungeEndTime[iClient] = GetGameTime() + flDuration;
	g_flPissLungeStartTime[iClient] = GetGameTime();
	g_flPissLungeNextPushAt[iClient] = g_flPissLungeStartTime[iClient] + 0.05;
	
	// Play lunge animation
	SDKCall_PlaySpecificSequence(iClient, "lunge");
	
	// Force third person
	SetVariantInt(1);
	AcceptEntityInput(iClient, "SetForcedTauntCam");
	
	// Add condition to prevent attacking
	TF2_AddCondition(iClient, TFCond_RestrictToMelee, TFCondDuration_Infinite);
	
	// Get forward direction and store initial angles
	GetClientEyeAngles(iClient, g_vecPissLungeInitialAngles[iClient]);
	
	// Restrict going heavily upwards/downwards (from reference code)
	if (g_vecPissLungeInitialAngles[iClient][0] > 45.0)
		g_vecPissLungeInitialAngles[iClient][0] = 45.0;
	else if (g_vecPissLungeInitialAngles[iClient][0] < -45.0)
		g_vecPissLungeInitialAngles[iClient][0] = -45.0;
	
	// Apply strong forward velocity
	float flSpeed = boss.GetPropFloat("PissLunge", "Speed");
	float vecVelocity[3];
	GetAngleVectors(g_vecPissLungeInitialAngles[iClient], vecVelocity, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(vecVelocity, flSpeed);
	
	// Add upward boost if on ground or not enough vertical velocity
	if ((GetEntityFlags(iClient) & FL_ONGROUND) == 0)
		vecVelocity[2] += 50.0;
	else if (vecVelocity[2] < 310.0)
		vecVelocity[2] = 310.0;
	
	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vecVelocity);
	
	// Play lunge start sound (piss_jump1.wav)
	char sSound[PLATFORM_MAX_PATH];
	boss.CallFunction("GetSoundAbility", sSound, sizeof(sSound), "PissLungeStart");
	if (!StrEmpty(sSound))
	{
		EmitSoundToAll(sSound, iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
		g_iPissLungeSoundRef[iClient] = EntIndexToEntRef(iClient);
	}
	
	// Start the collision check timer
	CreateTimer(0.05, Timer_PissLungeThink, GetClientUserId(iClient), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	boss.CallFunction("UpdateHudInfo", 0.0, 0.1);
}

void PissLunge_Stop(SaxtonHaleBase boss)
{
	int iClient = boss.iClient;
	
	g_bPissLunging[iClient] = false;
	
	// Stop lunge sounds
	if (g_iPissLungeSoundRef[iClient] != INVALID_ENT_REFERENCE)
	{
		int iSoundEnt = EntRefToEntIndex(g_iPissLungeSoundRef[iClient]);
		if (iSoundEnt > 0 && IsValidEntity(iSoundEnt))
		{
			char sSound[PLATFORM_MAX_PATH];
			boss.CallFunction("GetSoundAbility", sSound, sizeof(sSound), "PissLungeStart");
			if (!StrEmpty(sSound))
				StopSound(iSoundEnt, SNDCHAN_VOICE, sSound);
		}
		g_iPissLungeSoundRef[iClient] = INVALID_ENT_REFERENCE;
	}
	
	// Remove attack restriction
	TF2_RemoveCondition(iClient, TFCond_RestrictToMelee);
	
	// Don't return to first person immediately - wait for animation to finish
	// Return to first person will happen after animation completes
	
	// Apply cooldown
	float flCooldown = boss.GetPropFloat("PissLunge", "Cooldown");
	g_flPissLungeCooldown[iClient] = GetGameTime() + flCooldown;
	boss.CallFunction("UpdateHudInfo", 1.0, flCooldown);
}

public Action Timer_PissLungeThink(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if (iClient <= 0 || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return Plugin_Stop;
	
	if (!g_bPissLunging[iClient])
		return Plugin_Stop;
	
	SaxtonHaleBase boss = SaxtonHaleBase(iClient);
	
	// Grace period before checking end conditions
	if ((GetGameTime() - g_flPissLungeStartTime[iClient]) > 0.1)
	{
		// End after duration expires or touching ground/water
		if ((GetGameTime() - g_flPissLungeStartTime[iClient]) > boss.GetPropFloat("PissLunge", "Duration") || 
			(GetEntityFlags(iClient) & FL_ONGROUND) != 0 || 
			GetEntProp(iClient, Prop_Send, "m_nWaterLevel") > 1)
		{
			// Missed - play miss animation and sound
			if (!g_bPissLungeMissed[iClient] && !g_bPissLungeHit[iClient])
			{
				SDKCall_PlaySpecificSequence(iClient, "lunge_miss");
				g_bPissLungeMissed[iClient] = true;
				
				// Play miss sound (piss_laugh.wav)
				char sMissSound[PLATFORM_MAX_PATH];
				boss.CallFunction("GetSoundAbility", sMissSound, sizeof(sMissSound), "PissLungeMiss");
				if (!StrEmpty(sMissSound))
				{
					EmitSoundToAll(sMissSound, iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				}
				
				// Wait for miss animation to finish before returning to first person
				CreateTimer(1.5, Timer_ReturnToFirstPerson, GetClientUserId(iClient));
			}
			
			PissLunge_Stop(boss);
			return Plugin_Stop;
		}
	}
	
	// Check for collision with enemies if we haven't hit anyone yet
	if (!g_bPissLungeHit[iClient])
	{
		float flRange = boss.GetPropFloat("PissLunge", "Range");
		int iVictim = PissLunge_FindVictim(iClient, flRange);
		
		if (iVictim > 0)
		{
			PissLunge_CarveVictim(boss, iVictim);
			g_bPissLungeHit[iClient] = true;
			
			// Wait for carving animation to finish before returning to first person
			CreateTimer(2.0, Timer_ReturnToFirstPerson, GetClientUserId(iClient));
			
			PissLunge_Stop(boss);
			return Plugin_Stop;
		}
	}
	
	// Maintain forward momentum (from reference code)
	if (GetGameTime() >= g_flPissLungeNextPushAt[iClient])
	{
		float vecVelocity[3];
		GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vecVelocity);
		float flZ = vecVelocity[2];
		vecVelocity[2] = 0.0;
		
		// Check horizontal velocity
		float flCurrentSpeed = SquareRoot((vecVelocity[0] * vecVelocity[0]) + (vecVelocity[1] * vecVelocity[1]));
		
		if (flCurrentSpeed < 100.0)
		{
			// Re-apply forward velocity if slowing down
			float flSpeed = boss.GetPropFloat("PissLunge", "Speed");
			GetAngleVectors(g_vecPissLungeInitialAngles[iClient], vecVelocity, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(vecVelocity, flSpeed);
			
			vecVelocity[2] = flZ;
			TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vecVelocity);
		}
		
		g_flPissLungeNextPushAt[iClient] = GetGameTime() + 0.05;
	}
	
	return Plugin_Continue;
}

int PissLunge_FindVictim(int iClient, float flRange)
{
	float vecOrigin[3], vecTargetOrigin[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	
	int iTeam = GetClientTeam(iClient);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;
		
		if (i == iClient || GetClientTeam(i) == iTeam)
			continue;
		
		GetClientAbsOrigin(i, vecTargetOrigin);
		
		float flDistance = GetVectorDistance(vecOrigin, vecTargetOrigin);
		
		if (flDistance <= flRange)
		{
			return i;
		}
	}
	
	return -1;
}

void PissLunge_CarveVictim(SaxtonHaleBase boss, int iVictim)
{
	int iClient = boss.iClient;
	
	// Play carving animation
	SDKCall_PlaySpecificSequence(iClient, "carving");
	
	// Play carving sound (piss_hitv2.mp3)
	char sCarvingSound[PLATFORM_MAX_PATH];
	boss.CallFunction("GetSoundAbility", sCarvingSound, sizeof(sCarvingSound), "PissLungeCarve");
	if (!StrEmpty(sCarvingSound))
	{
		EmitSoundToAll(sCarvingSound, iClient, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	}
	
	// Create blood particle effects
	PissLunge_CreateBloodEffect(iVictim);
	
	// Turn victim into red statue (Midas effect but red)
	SetEntityRenderMode(iVictim, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iVictim, 139, 0, 0, 255); // Dark red color
	
	// Create ice statue effect prop
	PissLunge_CreateStatueEffect(iVictim);
	
	// Kill the victim
	SDKHooks_TakeDamage(iVictim, iClient, iClient, 9999.0, DMG_SLASH);
	
	// Message
	char sAttackerName[64], sVictimName[64];
	GetClientName(iClient, sAttackerName, sizeof(sAttackerName));
	GetClientName(iVictim, sVictimName, sizeof(sVictimName));
	PrintToChatAll("%s carved %s into bloody flesh!", sAttackerName, sVictimName);
}

void PissLunge_CreateBloodEffect(int iVictim)
{
	// Create blood spray particles
	float vecOrigin[3];
	GetClientAbsOrigin(iVictim, vecOrigin);
	vecOrigin[2] += 50.0; // Raise to torso height
	
	// Create multiple blood particles
	for (int i = 0; i < 5; i++)
	{
		int iParticle = CreateEntityByName("info_particle_system");
		if (iParticle > 0)
		{
			DispatchKeyValue(iParticle, "effect_name", "blood_impact_red_01");
			DispatchSpawn(iParticle);
			ActivateEntity(iParticle);
			
			TeleportEntity(iParticle, vecOrigin, NULL_VECTOR, NULL_VECTOR);
			AcceptEntityInput(iParticle, "Start");
			
			// Remove after short delay
			CreateTimer(2.0, Timer_RemoveEntity, EntIndexToEntRef(iParticle));
		}
	}
	
	// Additional blood decals
	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", vecOrigin);
	TE_WriteNum("m_nIndex", PrecacheDecal("Blood"));
	TE_SendToAll();
}

void PissLunge_CreateStatueEffect(int iVictim)
{
	float vecOrigin[3], vecAngles[3];
	GetClientAbsOrigin(iVictim, vecOrigin);
	GetClientAbsAngles(iVictim, vecAngles);
	
	// Create ice statue effect using TF2 freeze effect
	TF2_AddCondition(iVictim, TFCond_FreezeInput, 5.0);
	
	// Particle effect for the carving/blood
	int iParticle = CreateEntityByName("info_particle_system");
	if (iParticle > 0)
	{
		DispatchKeyValue(iParticle, "effect_name", "ExplosionCore_MidAir");
		DispatchSpawn(iParticle);
		ActivateEntity(iParticle);
		
		TeleportEntity(iParticle, vecOrigin, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(iParticle, "Start");
		
		CreateTimer(2.0, Timer_RemoveEntity, EntIndexToEntRef(iParticle));
	}
}

public Action Timer_RemoveEntity(Handle hTimer, int iRef)
{
	int iEntity = EntRefToEntIndex(iRef);
	if (iEntity > MaxClients && IsValidEntity(iEntity))
	{
		AcceptEntityInput(iEntity, "Kill");
	}
	return Plugin_Stop;
}

public Action Timer_ReturnToFirstPerson(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if (iClient <= 0 || !IsClientInGame(iClient))
		return Plugin_Stop;
	
	// Return to first person after animation finishes
	SetVariantInt(0);
	AcceptEntityInput(iClient, "SetForcedTauntCam");
	
	return Plugin_Stop;
}

// Function to enable PissLunge (called when rage is activated)
public void PissLunge_Enable(SaxtonHaleBase boss)
{
	g_bPissLungeEnabled[boss.iClient] = true;
	g_flPissLungeCooldown[boss.iClient] = 0.0; // Reset cooldown
	boss.CallFunction("UpdateHudInfo", 0.0, 0.1);
}

// Function to disable PissLunge  
public void PissLunge_Disable(SaxtonHaleBase boss)
{
	g_bPissLungeEnabled[boss.iClient] = false;
	boss.CallFunction("UpdateHudInfo", 0.0, 0.1);
}