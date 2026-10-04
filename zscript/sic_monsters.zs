// The blocky animatronics of Whisker's Block Pizza, and their boss, Professor Whiskers.
// Like in the pizzeria at night, they move faster while the guard is not looking at them.
// When one breaks, its head pops off and the kitten that was driving it jumps out.

class SICAnimatronic : Actor
{
	String scareFace; // sprite frame shown full screen when it catches the player
	bool bobUp;

	property ScareFace: scareFace;

	Default
	{
		Monster;
		+FLOORCLIP
		+DONTHARMSPECIES
		Mass 400;
		BloodType "SICHitFX";
		SeeSound "anim/sight";
		PainSound "anim/pain";
		DeathSound "anim/death";
		ActiveSound "anim/active";
	}

	// Seen by the guard: normal speed. Not seen: much faster (they creep up on you).
	bool Watched()
	{
		let p = players[consoleplayer].mo;
		return p && abs(DeltaAngle(p.angle, p.AngleTo(self))) < 45 && p.CheckSight(self);
	}

	action void A_AnimChase()
	{
		speed = invoker.Watched() ? invoker.Default.speed : invoker.Default.speed * 1.7;
		invoker.bobUp = !invoker.bobUp;
		invoker.SpriteOffset.y = invoker.bobUp ? -2 : 0;
		A_Chase();
		// Close enough to grab the guard: that is a jumpscare, like in the pizzeria. Then it backs off.
		if (target && target.player && Distance3D(target) < radius + target.radius + 28)
		{
			SICNight.Scare(invoker.scareFace);
			invoker.A_BounceBack();
		}
	}

	action void A_Step()
	{
		A_StartSound("anim/active", CHAN_BODY, CHANF_DEFAULT, 0.55);
	}

	// Melee hit; on the player it is a jumpscare.
	action void A_AnimMelee(int dmg)
	{
		A_FaceTarget();
		if (!target || !CheckMeleeRange()) return;
		int done = target.DamageMobj(self, self, dmg, 'Melee');
		target.Thrust(4, AngleTo(target));
		A_StartSound("anim/pain", CHAN_WEAPON);
		if (target.player)
		{
			SICNight.Scare(invoker.scareFace);
			invoker.A_BounceBack();
		}
	}

	// After it got the guard, it hops back (and stays readable on screen instead of hugging the camera).
	void A_BounceBack()
	{
		if (!target) return;
		VelFromAngle(-11, AngleTo(target));
		vel.z = 4;
	}

	// Leap at the target (the chicken and the fox).
	action void A_Lunge(double speedxy, double speedz)
	{
		A_FaceTarget();
		VelFromAngle(speedxy);
		vel.z = speedz;
	}

	// Death, first frame: the head pops off, sparks, and the kitten pilot jumps out.
	action void A_PopKitten(int kittens = 1)
	{
		for (int i = 0; i < kittens; i++)
		{
			Spawn("SICKitten", pos + (0, 0, height * 0.75), ALLOW_REPLACE);
		}
		for (int i = 0; i < 20; i++)
		{
			A_SpawnParticle(random(0, 1) ? "FFE040" : "80E0FF", SPF_FULLBRIGHT, random(14, 28), random(3, 6), 0,
				0, 0, height * 0.7, frandom(-5, 5), frandom(-5, 5), frandom(2, 8), 0, 0, -0.5);
		}
		A_SpawnItemEx("SICSparkLight", 0, 0, height * 0.7);
	}

	// Death, last frame: it falls apart into blocks.
	action void A_Wreck()
	{
		for (int i = 0; i < 8; i++)
		{
			A_SpawnItemEx("SICDebris", 0, 0, 20, frandom(-4, 4), frandom(-4, 4), frandom(2, 7), frandom(0, 360), SXF_NOCHECKPOSITION);
		}
		A_StartSound("anim/death", CHAN_BODY, CHANF_DEFAULT, 0.6);
	}
}

// Brick Bear: the band leader. Throws pizza slices.
class BrickBear : SICAnimatronic replaces ZombieMan
{
	Default
	{
		Health 120;
		Radius 20;
		Height 72;
		Speed 8;
		PainChance 140;
		SeeSound "bear/laugh";
		Tag "Brick Bear";
		Obituary "%o was served by Brick Bear.";
		SICAnimatronic.ScareFace "JSBEAR";
	}
	States
	{
	Spawn:
		BEAR A 10 A_Look;
		Loop;
	See:
		BEAR A 0 A_Step;
		BEAR AA 4 A_AnimChase;
		BEAR BB 4 A_AnimChase;
		Loop;
	Missile:
		BEAR C 10 A_FaceTarget;
		BEAR C 6
		{
			A_StartSound("pizza/throw", CHAN_WEAPON);
			A_SpawnProjectile("SICPizza", 56);
		}
		BEAR A 6;
		Goto See;
	Melee:
		BEAR C 6 A_FaceTarget;
		BEAR C 6 A_AnimMelee(random(3, 24));
		Goto See;
	Pain:
		BEAR D 3 Bright;
		BEAR D 5 A_Pain;
		Goto See;
	Death:
		BEAR E 6 A_PopKitten;
		BEAR E 8 A_Scream;
		BEAR E 6 A_NoBlocking;
		BEAR F 8 A_Wreck;
		BEAR F -1;
		Stop;
	}
}

// Block Bunny: shreds its guitar and fires a fan of music notes.
class BlockBunny : SICAnimatronic replaces DoomImp
{
	Default
	{
		Health 100;
		Radius 20;
		Height 76;
		Speed 9;
		PainChance 160;
		Tag "Block Bunny";
		Obituary "%o got rocked by Block Bunny.";
		SICAnimatronic.ScareFace "JSBUNNY";
	}
	States
	{
	Spawn:
		BUNN A 10 A_Look;
		Loop;
	See:
		BUNN A 0 A_Step;
		BUNN AA 4 A_AnimChase;
		BUNN BB 4 A_AnimChase;
		Loop;
	Missile:
		BUNN C 8
		{
			A_FaceTarget();
			A_StartSound("bunny/riff", CHAN_WEAPON);
		}
		BUNN C 8 Bright
		{
			A_SpawnProjectile("SICNote", 40, 8, -9);
			A_SpawnProjectile("SICNote", 40, 8, 0);
			A_SpawnProjectile("SICNote", 40, 8, 9);
		}
		BUNN A 8;
		Goto See;
	Melee:
		BUNN C 6 A_FaceTarget;
		BUNN C 6 A_AnimMelee(random(3, 24));
		Goto See;
	Pain:
		BUNN D 3 Bright;
		BUNN D 5 A_Pain;
		Goto See;
	Death:
		BUNN E 6 A_PopKitten;
		BUNN E 8 A_Scream;
		BUNN E 6 A_NoBlocking;
		BUNN F 8 A_Wreck;
		BUNN F -1;
		Stop;
	}
}

// Cluck-a-Block: leaps at you beak first.
class CluckBlock : SICAnimatronic replaces Demon
{
	Default
	{
		Health 150;
		Radius 22;
		Height 74;
		Speed 11;
		PainChance 180;
		MeleeRange 60;
		MaxTargetRange 420;
		SeeSound "chick/screech";
		Tag "Cluck-a-Block";
		Obituary "%o was pecked to pieces by Cluck-a-Block.";
		SICAnimatronic.ScareFace "JSCHICK";
	}
	States
	{
	Spawn:
		CHIK A 10 A_Look;
		Loop;
	See:
		CHIK A 0 A_Step;
		CHIK AA 3 A_AnimChase;
		CHIK BB 3 A_AnimChase;
		Loop;
	Missile:
		CHIK C 10
		{
			A_FaceTarget();
			A_StartSound("chick/screech", CHAN_VOICE);
		}
		CHIK C 14 A_Lunge(15, 5);
		Goto See;
	Melee:
		CHIK C 5 A_FaceTarget;
		CHIK C 6 A_AnimMelee(random(1, 10) * 4);
		Goto See;
	Pain:
		CHIK D 3 Bright;
		CHIK D 5 A_Pain;
		Goto See;
	Death:
		CHIK E 6 A_PopKitten;
		CHIK E 8 A_Scream;
		CHIK E 6 A_NoBlocking;
		CHIK F 8 A_Wreck;
		CHIK F -1;
		Stop;
	}
}

// Foxel: the pirate fox. Sprints out of the cove and slashes with its hook.
class Foxel : SICAnimatronic replaces Spectre
{
	Default
	{
		Health 130;
		Radius 20;
		Height 76;
		Speed 15;
		PainChance 120;
		MeleeRange 64;
		MaxTargetRange 512;
		SeeSound "fox/run";
		Tag "Foxel";
		Obituary "%o was hooked by Foxel.";
		SICAnimatronic.ScareFace "JSFOX";
	}
	States
	{
	Spawn:
		FOXL A 10 A_Look;
		Loop;
	See:
		FOXL B 0 A_StartSound("fox/run", CHAN_BODY, CHANF_NOSTOP, 0.6);
		FOXL BB 2 A_AnimChase;
		FOXL CC 2 A_AnimChase;
		Loop;
	Missile:
		FOXL D 8 A_FaceTarget;
		FOXL D 14 A_Lunge(20, 6);
		Goto See;
	Melee:
		FOXL D 5 A_FaceTarget;
		FOXL D 6 A_AnimMelee(random(1, 8) * 4);
		Goto See;
	Pain:
		FOXL E 3 Bright;
		FOXL E 5 A_Pain;
		Goto See;
	Death:
		FOXL F 6 A_PopKitten;
		FOXL F 8 A_Scream;
		FOXL F 6 A_NoBlocking;
		FOXL G 8 A_Wreck;
		FOXL G -1;
		Stop;
	}
}

// Professor Whiskers, the SuperIntelligent Cat who owns the place. Laser glasses and a remote that calls his animatronics.
class ProfessorWhiskers : SICAnimatronic replaces Cyberdemon
{
	Default
	{
		Health 2200;
		Radius 32;
		Height 110;
		Speed 9;
		PainChance 40;
		Mass 1000;
		MinMissileChance 120;
		+BOSS
		+DONTMORPH
		+NOTARGET
		SeeSound "boss/sight";
		PainSound "boss/pain";
		DeathSound "boss/death";
		ActiveSound "boss/sight";
		Tag "Professor Whiskers";
		Obituary "%o was outsmarted by Professor Whiskers.";
		SICAnimatronic.ScareFace "WHSKC0";
	}

	// The remote: calls one animatronic next to him (at most 3 at a time).
	action void A_Summon()
	{
		int alive = 0;
		let it = ThinkerIterator.Create("SICAnimatronic");
		SICAnimatronic a;
		while (a = SICAnimatronic(it.Next())) if (a.health > 0 && !a.bBoss) alive++;
		if (alive >= 3) return;
		static const Name kinds[] = { 'BrickBear', 'BlockBunny', 'CluckBlock', 'Foxel' };
		for (int i = 0; i < 6; i++)
		{
			let m = Spawn(kinds[random(0, 3)], Vec3Angle(frandom(110, 180), angle + frandom(-70, 70)), ALLOW_REPLACE);
			if (!m) continue;
			if (!m.TestMobjLocation()) { m.Destroy(); continue; }
			Spawn("TeleportFog", m.pos, ALLOW_REPLACE);
			m.target = target;
			m.SetState(m.SeeState);
			return;
		}
	}

	States
	{
	Spawn:
		WHSK A 10 Bright A_Look;
		Loop;
	See:
		WHSK A 0 Bright A_Step;
		WHSK AA 5 Bright A_AnimChase;
		WHSK BB 5 Bright A_AnimChase;
		Loop;
	Missile:
		WHSK A 0 Bright A_Jump(50, "Remote");
		WHSK C 14 Bright
		{
			A_FaceTarget();
			A_StartSound("boss/laser", CHAN_WEAPON);
		}
		WHSK C 6 Bright
		{
			A_CustomRailgun(10, -10, "Cyan", "White", RGF_SILENT | RGF_FULLBRIGHT, 1, 0, "SICLaserPuff", 0, 0, 0, 20, 1, 0, null, 34);
			A_CustomRailgun(10, 10, "Cyan", "White", RGF_SILENT | RGF_FULLBRIGHT, 1, 0, "SICLaserPuff", 0, 0, 0, 20, 1, 0, null, 34);
		}
		WHSK A 10 Bright;
		Goto See;
	Remote:
		WHSK D 16 Bright
		{
			A_FaceTarget();
			A_StartSound("boss/sight", CHAN_VOICE);
		}
		WHSK D 12 Bright A_Summon;
		Goto See;
	Melee:
		WHSK C 8 Bright A_FaceTarget;
		WHSK C 8 Bright A_AnimMelee(random(4, 10) * 5);
		Goto See;
	Pain:
		WHSK E 4 Bright;
		WHSK E 8 Bright A_Pain;
		Goto See;
	Death:
		WHSK F 10 Bright A_Scream;
		WHSK F 10 Bright A_PopKitten(4);
		WHSK F 10 Bright A_NoBlocking;
		WHSK G 10 Bright A_Wreck;
		WHSK G -1 Bright;
		Stop;
	}
}

// Brick Bear's pizza slice: spins through the air and splats.
class SICPizza : Actor
{
	Default
	{
		Projectile;
		Radius 6;
		Height 8;
		Speed 13;
		Damage 3;
		+RANDOMIZE
		DeathSound "pizza/splat";
	}
	States
	{
	Spawn:
		PZZA ABCD 3;
		Loop;
	Death:
		PZZA A 0
		{
			for (int i = 0; i < 12; i++)
			{
				A_SpawnParticle(random(0, 1) ? "FFD030" : "D02020", 0, random(12, 22), random(3, 5), 0,
					0, 0, 0, frandom(-3, 3), frandom(-3, 3), frandom(0, 4), 0, 0, -0.5);
			}
		}
		PZZA A 4 A_FadeOut(0.3);
		Stop;
	}
}

// Block Bunny's music note: glows cyan and leaves a sparkly trail.
class SICNote : Actor
{
	Default
	{
		Projectile;
		Radius 6;
		Height 8;
		Speed 12;
		Damage 2;
		+RANDOMIZE
		+BRIGHT
		DeathSound "anim/pain";
	}
	States
	{
	Spawn:
		NOTE A 3 A_SpawnParticle("40FFFF", SPF_FULLBRIGHT, 14, 4, 0, 0, 0, 4, frandom(-0.5, 0.5), frandom(-0.5, 0.5), 0.5);
		NOTE B 3 A_SpawnParticle("A0FFFF", SPF_FULLBRIGHT, 14, 4, 0, 0, 0, 4, frandom(-0.5, 0.5), frandom(-0.5, 0.5), 0.5);
		Loop;
	Death:
		NOTE A 0
		{
			for (int i = 0; i < 10; i++)
			{
				A_SpawnParticle("40FFFF", SPF_FULLBRIGHT, random(10, 18), random(3, 5), 0, 0, 0, 0, frandom(-3, 3), frandom(-3, 3), frandom(-1, 3));
			}
		}
		NOTE A 3 A_FadeOut(0.4);
		Stop;
	}
}

// Where a laser hits: cyan sparks.
class SICLaserPuff : Actor
{
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+PUFFONACTORS
		+ALWAYSPUFF
	}
	States
	{
	Spawn:
		TNT1 A 0 NoDelay
		{
			for (int i = 0; i < 12; i++)
			{
				A_SpawnParticle(random(0, 1) ? "40FFFF" : "FFFFFF", SPF_FULLBRIGHT, random(10, 18), random(3, 6), 0,
					0, 0, 0, frandom(-4, 4), frandom(-4, 4), frandom(0, 5), 0, 0, -0.4);
			}
		}
		TNT1 A 6;
		Stop;
	}
}
