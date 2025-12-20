// Shockwave.sp - Knockback ability for Green Rage

static bool g_bShockwaveActive[MAXPLAYERS + 1];
static float g_flShockwaveCooldown[MAXPLAYERS + 1];
static int g_iShockwaveUses[MAXPLAYERS + 1];
static bool g_bShockwaveButtonHeld[MAXPLAYERS + 1];

public void Shockwave_Create(SaxtonHaleBase boss)
{
	g_bShockwaveActive[boss.iClient] = false;
	g_flShockwaveCooldown[boss.iClient] = 0.0;
	g_iShockwaveUses[boss.iClient] = 0;
	g_bShockwaveButtonHeld[boss.iClient] = false;
	
	boss.SetPropFloat("Shockwave", "Cooldown", 8.0);
	boss.SetPropFloat("Shockwave", "Radius", 400.0);
	boss.SetPropFloat("Shockwave", "Damage", 10.0);
	boss.SetPropFloat("Shockwave", "Force", 600.0);
	boss.SetPropInt("Shockwave", "MaxUses", 3);
}

public void Shockwave_GetHudInfo(SaxtonHaleBase boss, char[] sMessage, int iLength, int iColor[4])
{
	if (!g_bShockwaveActive[boss.iClient])
		return;
	
	int iUsesLeft = boss.GetPropInt("Shockwave", "MaxUses") - g_iShockwaveUses[boss.iClient];
	
	if (iUsesLeft <= 0)
	{
		Format(sMessage, iLength, "%s\nShockwave: NO USES LEFT", sMessage);
	}
	else if (g_flShockwaveCooldown[boss.iClient] > GetGameTime())
	{
		float flTimeLeft = g_flShockwaveCooldown[boss.iClient] - GetGameTime();
		Format(sMessage, iLength, "%s\nShockwave: %.1fs [%d/%d]", sMessage, flTimeLeft, iUsesLeft, boss.GetPropInt("Shockwave", "MaxUses"));
	}
	else
	{
		Format(sMessage, iLength, "%s\nShockwave [R] [%d/%d]", sMessage, iUsesLeft, boss.GetPropInt("Shockwave", "MaxUses"));
	}
	
	// Bright green color
	iColor[0] = 50;
	iColor[1] = 255;
	iColor[2] = 50;
	iColor[3] = 255;
}

public void Shockwave_Activate(SaxtonHaleBase boss)
{
	g_bShockwaveActive[boss.iClient] = true;
	g_iShockwaveUses[boss.iClient] = 0;
}

public void Shockwave_Deactivate(SaxtonHaleBase boss)
{
	g_bShockwaveActive[boss.iClient] = false;
}

public void Shockwave_OnButton(SaxtonHaleBase boss, int &buttons)
{
	if (!g_bShockwaveActive[boss.iClient])
		return;
	
	if (buttons & IN_RELOAD)
		g_bShockwaveButtonHeld[boss.iClient] = true;
}

public void Shockwave_OnButtonRelease(SaxtonHaleBase boss, int button)
{
	if (button != IN_RELOAD)
		return;
	
	if (!g_bShockwaveActive[boss.iClient])
		return;
	
	g_bShockwaveButtonHeld[boss.iClient] = false;
	
	if (GameRules_GetRoundState() == RoundState_Preround)
		return;
	
	if (TF2_IsPlayerInCondition(boss.iClient, TFCond_Dazed))
		return;
	
	int iMaxUses = boss.GetPropInt("Shockwave", "MaxUses");
	if (g_iShockwaveUses[boss.iClient] >= iMaxUses)
		return;
	
	if (g_flShockwaveCooldown[boss.iClient] > GetGameTime())
		return;
	
	Shockwave_Trigger(boss);
	g_iShockwaveUses[boss.iClient]++;
}

void Shockwave_Trigger(SaxtonHaleBase boss)
{
	int iClient = boss.iClient;
	
	if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return;
	
	// Create glow particle
	int iGlowParticle = CreateEntityByName("info_particle_system");
	if (iGlowParticle > 0)
	{
		DispatchKeyValue(iGlowParticle, "effect_name", "raygun_projectile_blue_crit");
		DispatchSpawn(iGlowParticle);
		ActivateEntity(iGlowParticle);
		
		float vecOrigin[3];
		GetClientAbsOrigin(iClient, vecOrigin);
		TeleportEntity(iGlowParticle, vecOrigin, NULL_VECTOR, NULL_VECTOR);
		
		SetVariantString("!activator");
		AcceptEntityInput(iGlowParticle, "SetParent", iClient);
		AcceptEntityInput(iGlowParticle, "Start");
		
		CreateTimer(1.0, Timer_RemoveShockwaveEntity, EntIndexToEntRef(iGlowParticle));
	}
	
	// Play sound
	char sSound[PLATFORM_MAX_PATH];
	boss.CallFunction("GetSoundAbility", sSound, sizeof(sSound), "Shockwave");
	if (strlen(sSound) > 0)
		EmitSoundToAll(sSound, iClient, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	
	// Trigger after 1 second
	CreateTimer(1.0, Timer_TriggerShockwave, GetClientUserId(iClient));
	
	// Set cooldown
	float flCooldown = boss.GetPropFloat("Shockwave", "Cooldown");
	g_flShockwaveCooldown[iClient] = GetGameTime() + flCooldown + 1.0;
	
	boss.CallFunction("UpdateHudInfo", 1.0, flCooldown + 1.0);
}

public Action Timer_TriggerShockwave(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if (iClient <= 0 || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return Plugin_Stop;
	
	SaxtonHaleBase boss = SaxtonHaleBase(iClient);
	
	float vecOrigin[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	
	float flRadius = boss.GetPropFloat("Shockwave", "Radius");
	float flDamage = boss.GetPropFloat("Shockwave", "Damage");
	float flForce = boss.GetPropFloat("Shockwave", "Force");
	
	int iTeam = GetClientTeam(iClient);
	
	// Explosion particle
	int iParticle = CreateEntityByName("info_particle_system");
	if (iParticle > 0)
	{
		DispatchKeyValue(iParticle, "effect_name", "ExplosionCore_MidAir");
		DispatchSpawn(iParticle);
		ActivateEntity(iParticle);
		TeleportEntity(iParticle, vecOrigin, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(iParticle, "Start");
		CreateTimer(2.0, Timer_RemoveShockwaveEntity, EntIndexToEntRef(iParticle));
	}
	
	// Damage nearby enemies
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;
		
		if (i == iClient || GetClientTeam(i) == iTeam)
			continue;
		
		float vecTargetOrigin[3];
		GetClientAbsOrigin(i, vecTargetOrigin);
		
		float flDistance = GetVectorDistance(vecOrigin, vecTargetOrigin);
		
		if (flDistance <= flRadius)
		{
			SDKHooks_TakeDamage(i, iClient, iClient, flDamage, DMG_BLAST);
			
			float vecDirection[3];
			SubtractVectors(vecTargetOrigin, vecOrigin, vecDirection);
			vecDirection[2] = 0.0;
			NormalizeVector(vecDirection, vecDirection);
			
			float vecVelocity[3];
			vecVelocity[0] = vecDirection[0] * flForce;
			vecVelocity[1] = vecDirection[1] * flForce;
			vecVelocity[2] = 300.0;
			
			TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, vecVelocity);
			TF2_StunPlayer(i, 0.5, 0.0, TF_STUNFLAGS_SMALLBONK, iClient);
		}
	}
	
	// Destroy buildings
	int iBuilding = MaxClients + 1;
	while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) != -1)
	{
		if (GetEntProp(iBuilding, Prop_Send, "m_iTeamNum") == iTeam)
			continue;
		
		float vecBuildingOrigin[3];
		GetEntPropVector(iBuilding, Prop_Send, "m_vecOrigin", vecBuildingOrigin);
		
		float flDistance = GetVectorDistance(vecOrigin, vecBuildingOrigin);
		
		if (flDistance <= flRadius)
		{
			SetVariantInt(GetEntProp(iBuilding, Prop_Send, "m_iMaxHealth"));
			AcceptEntityInput(iBuilding, "RemoveHealth");
		}
	}
	
	return Plugin_Stop;
}

public void Shockwave_OnTakeDamage(SaxtonHaleBase boss, int &iAttacker, int &iInflictor, float &flDamage, int &iDamageType, int &iWeapon, float vecDamageForce[3], float vecDamagePosition[3], int iDamageCustom)
{
	if (g_bShockwaveActive[boss.iClient])
	{
		flDamage *= boss.GetPropFloat("Shockwave", "DamageReduction");
	}
}

public Action Timer_RemoveShockwaveEntity(Handle hTimer, int iRef)
{
	int iEntity = EntRefToEntIndex(iRef);
	if (iEntity > MaxClients && IsValidEntity(iEntity))
		AcceptEntityInput(iEntity, "Kill");
	return Plugin_Stop;
}