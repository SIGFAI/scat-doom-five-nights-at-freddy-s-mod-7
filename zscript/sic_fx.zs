// Effects: sparks when an animatronic is hit, block debris, the TNT explosion, smoke, and the kitten pilots.

// "Blood" of the animatronics: electric sparks and a puff of metal bits.
class SICHitFX : Actor
{
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
	}
	States
	{
	Spawn:
		TNT1 A 0 NoDelay
		{
			for (int i = 0; i < 10; i++)
			{
				A_SpawnParticle(random(0, 1) ? "FFE040" : "FFFFA0", SPF_FULLBRIGHT, random(10, 20), random(3, 5), 0,
					0, 0, 0, frandom(-4, 4), frandom(-4, 4), frandom(1, 6), 0, 0, -0.5);
			}
			A_SpawnItemEx("SICSparkLight");
		}
		Stop;
	}
}

// A short flash of light where the sparks fly (GLDEFS).
class SICSparkLight : Actor
{
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		RenderStyle "None";
	}
	States
	{
	Spawn:
		DEBR A 4;
		Stop;
	}
}

// A small Minecraft block chunk that flies, bounces and fades.
class SICDebris : Actor
{
	Default
	{
		Radius 3;
		Height 4;
		Gravity 0.8;
		BounceType "Doom";
		BounceFactor 0.45;
		WallBounceFactor 0.5;
		+NOBLOCKMAP
		+DROPOFF
		+THRUACTORS
		+MISSILE
		+NOTELEPORT
		+CANNOTPUSH
	}
	override void BeginPlay()
	{
		Super.BeginPlay();
		frame = random(0, 3);
		scale = (1, 1) * frandom(0.9, 1.6);
	}
	States
	{
	Spawn:
		DEBR "#" 70;
		DEBR "#" 1 A_FadeOut(0.05);
		Wait;
	Death:
		DEBR "#" 35;
		DEBR "#" 1 A_FadeOut(0.05);
		Wait;
	}
}

// Minecraft-style explosion: a white-hot boom, then grey smoke puffs.
class SICBoom : Actor
{
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		Scale 1.6;
	}
	States
	{
	Spawn:
		MCXP A 3 Bright NoDelay
		{
			for (int i = 0; i < 14; i++)
			{
				A_SpawnItemEx("SICDebris", 0, 0, 8, frandom(-6, 6), frandom(-6, 6), frandom(4, 11), frandom(0, 360), SXF_NOCHECKPOSITION);
			}
			for (int i = 0; i < 24; i++)
			{
				A_SpawnParticle(random(0, 2) ? "FFB030" : "FFF0A0", SPF_FULLBRIGHT, random(14, 26), random(4, 8), 0,
					0, 0, 8, frandom(-7, 7), frandom(-7, 7), frandom(0, 8), 0, 0, -0.4);
			}
			A_QuakeEx(2, 2, 2, 12, 0, 600, "", QF_SCALEDOWN);
		}
		MCXP B 4 Bright;
		MCXP C 4 Bright;
		MCXP D 5;
		MCXP E 5 A_SetScale(scale.x * 1.08);
		MCXP F 6 A_FadeOut(0.25);
		MCXP F 1 A_FadeOut(0.1);
		Wait;
	}
}

// Trail puff behind a flying TNT block.
class SICSmoke : Actor
{
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
	}
	States
	{
	Spawn:
		MCSM A 4 NoDelay A_ChangeVelocity(0, 0, 0.4);
		MCSM B 5;
		MCSM C 6;
		Stop;
	}
}

// 6 AM: the freed kittens throw a party around the guard, hopping and meowing under the confetti.
class SICPartyKitten : Actor
{
	Default
	{
		Radius 8;
		Height 20;
		Gravity 0.9;
		Scale 1.35;
		+NOBLOCKMAP
		+NOTELEPORT
		+FLOORCLIP
	}
	States
	{
	Spawn:
		KITN A 0 NoDelay A_SetTics(random(1, 30));
	Hop:
		KITN A 6
		{
			let p = players[consoleplayer].mo;
			if (p) A_Face(p);
			if (pos.z <= floorz + 1)
			{
				vel.z = frandom(4, 7);
				if (random(0, 3) == 0) A_StartSound("kitten/any", CHAN_VOICE, CHANF_DEFAULT, 0.6);
			}
			A_SpawnParticle(random(0, 1) ? (random(0, 1) ? "FF4040" : "40FF40") : (random(0, 1) ? "4080FF" : "FFE040"), SPF_FULLBRIGHT,
				50, 5, 0, frandom(-40, 40), frandom(-40, 40), 90, 0, 0, frandom(-1, 0), frandom(-0.05, 0.05), frandom(-0.05, 0.05), -0.05);
		}
		KITN B 6;
		Loop;
	}
}

// The kitten that was secretly driving the animatronic. It jumps out, meows and runs away from the player.
// Bullets and blasts only make it jump: nobody hurts a kitten here.
class SICKitten : Actor
{
	int life;

	Default
	{
		Radius 10;
		Height 28;
		Speed 9;
		Mass 30;
		MaxStepHeight 24;
		PainChance 256;
		Gravity 0.9;
		+SOLID
		+SHOOTABLE
		+NODAMAGE
		+NOBLOOD
		+FRIGHTENED
		+NEVERTARGET
		+DONTGIB
		+NOTELEPORT
		+FLOORCLIP
		Tag "Kitten";
		Scale 1.35;
		PainSound "kitten/any";
	}
	States
	{
	Spawn:
		KITN A 0 NoDelay
		{
			vel.z = frandom(6, 9);
			VelFromAngle(frandom(3, 5), frandom(0, 360));
			A_StartSound("kitten/any", CHAN_VOICE);
			target = players[consoleplayer].mo;
			A_FaceTarget();
		}
		KITN A 20;
	See:
		KITN AB 3
		{
			A_Chase(null, null, CHF_NOPLAYACTIVE);
			if (++life > 50) return ResolveState("Escape");
			return ResolveState(null);
		}
		Loop;
	Pain:
		KITN B 8
		{
			vel.z = 6;
			A_StartSound("kitten/any", CHAN_VOICE);
		}
		Goto See;
	Escape:
		KITN A 0
		{
			A_StartSound("kitten/any", CHAN_VOICE, CHANF_DEFAULT, 0.7);
			for (int i = 0; i < 12; i++)
			{
				A_SpawnParticle("FFFFFF", SPF_FULLBRIGHT, 18, 5, 0, 0, 0, 10, frandom(-2, 2), frandom(-2, 2), frandom(0, 3));
			}
		}
		Stop;
	}
}
