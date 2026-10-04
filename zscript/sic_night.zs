// The night shift. A clock runs from 12 AM to 6 AM, the power drains (faster with every TNT shot), the
// animatronics come out of their spawn points, and when the power runs out the lights die, a music box
// plays and Professor Whiskers comes for the guard himself. Break him and 6 AM rings: every animatronic
// left shuts down and lets its kitten out.
// Every other map gets turned into Minecraft blocks when it loads (Minecraftify).

class SICNight : EventHandler
{
	const POWER_MAX = 1000;  // tenths of a percent

	int hourTics, clockHour, power, shotPower;
	bool powerOut, bossCome, won;
	int outTic, wonTic, bossTic;
	int broken, kittens;
	int lastWave;
	int night, nightStart, nextNight; // five nights, each one a little faster
	Vector3 startPos;                  // where the guard clocks in every night
	double startAngle;
	Array<Actor> spots;
	Actor bossSpot;
	Actor boss;
	Array<int> lights;

	// Big centre message.
	String msg, msgSub;
	int msgTic, msgLen;
	// Jumpscare.
	String scareFace;
	int scareTic, lastScare;
	// Subtitles.
	int phoneTic, bossLineTic;
	int usageTic;

	static SICNight Get() { return SICNight(EventHandler.Find("SICNight")); }

	static void Scare(String face)
	{
		let h = Get();
		if (!h || (h.lastScare && level.maptime - h.lastScare < 35 * 7) || h.won) return;
		h.scareFace = face;
		Console.PrintfEx(PRINT_NONOTIFY, "SIC_SCARE %s", face);
		h.scareTic = level.maptime;
		h.lastScare = level.maptime;
		S_StartSound("jump/scare", CHAN_AUTO, CHANF_DEFAULT, 1, ATTN_NONE);
		let p = players[consoleplayer].mo;
		if (p) p.A_QuakeEx(4, 4, 2, 18, 0, 64, "", QF_SCALEDOWN);
	}

	static void UsePower(int tenths)
	{
		let h = Get();
		if (!h || h.powerOut || h.won) return;
		h.shotPower += tenths;
		h.usageTic = level.maptime;
	}

	void Say(String big, String small = "", int seconds = 3)
	{
		msg = big;
		msgSub = small;
		msgTic = level.maptime;
		msgLen = seconds * 35;
	}

	override void WorldLoaded(WorldEvent e)
	{
		hourTics = max(35, sic_hourtics);
		night = 1;
		power = POWER_MAX;
		clockHour = -1;
		Minecraftify();
		TextureID sky = TexMan.CheckForTexture("MCSKY", TexMan.Type_Any);
		if (sky.IsValid()) level.ChangeSky(sky, sky);
		let it = level.CreateActorIterator(10);
		Actor a;
		while (a = it.Next()) spots.Push(a);
		it = level.CreateActorIterator(50);
		bossSpot = it.Next();
		phoneTic = 35;
		lastWave = 0;
		S_ChangeMusic("sounds/night_music.ogg");
	}

	override void PlayerEntered(PlayerEvent e)
	{
		let mo = players[e.PlayerNumber].mo;
		if (!mo) return;
		startPos = mo.pos;
		startAngle = mo.angle;
		mo.GiveInventory("SICTNTLauncher", 1);
		mo.GiveInventory("RocketAmmo", 40);
		mo.player.PendingWeapon = Weapon(mo.FindInventory("SICTNTLauncher"));
	}

	override void WorldThingSpawned(WorldEvent e)
	{
		if (e.Thing is "SICKitten") kittens++;
	}

	override void WorldThingDied(WorldEvent e)
	{
		if (!(e.Thing is "SICAnimatronic")) return;
		// The kitten inside is grateful: it slips the guard some TNT.
		let p = players[consoleplayer].mo;
		if (p && !won) p.GiveInventory("RocketAmmo", e.Thing is "ProfessorWhiskers" ? 10 : 3);
		if (e.Thing is "ProfessorWhiskers") { Win(); return; }
		broken++;
	}

	override void WorldTick()
	{
		int t = level.maptime;
		if (won && t >= nextNight) StartNight();
		int nt = t - nightStart;
		if (t == phoneTic) S_StartSound("phone/call", CHAN_AUTO, CHANF_DEFAULT, 1, ATTN_NONE);

		// The clock: stuck at 5 AM while the Professor is loose ("overtime"), 6 AM once he is down.
		int h = won ? 6 : min(nt / hourTics, 5);
		if (h != clockHour)
		{
			clockHour = h;
			if (h < 6)
			{
				S_StartSound("clock/hour", CHAN_AUTO, CHANF_DEFAULT, 0.8, ATTN_NONE);
				if (h == 0) Say("12 AM", String.Format("Night %d at Whisker's Block Pizza", night), 4);
				else Say(String.Format("%d AM", h), h >= 4 ? "The power is getting low..." : "");
			}
		}

		// Power: drains over the night, and every TNT shot costs a little more.
		if (!powerOut && !won)
		{
			int drained = nt * POWER_MAX / (hourTics * 5) + shotPower;
			int was = power;
			power = max(0, POWER_MAX - drained);
			if (was / 100 != power / 100 && power > 0) S_StartSound("power/tick", CHAN_AUTO, CHANF_DEFAULT, 0.5, ATTN_NONE);
			if (power <= 0) KillPower();
		}

		if (powerOut && !won)
		{
			int k = t - outTic;
			// The lights fade out over 2 s.
			if (k <= 70) SetLights(1. - k / 70. * 0.35);
			if (k == 40) S_StartSound("power/musicbox", CHAN_AUTO, CHANF_DEFAULT, 1, ATTN_NONE);
			if (k == 35 * 4) SpawnBoss();
		}
		if (won)
		{
			int k = t - wonTic;
			if (k <= 70) SetLights(0.65 + k / 70. * 0.35);
		}

		// Night waves: near the guard, or at the map's spawn points.
		if (!powerOut && !won && t - lastWave >= sic_wavetics && nt > 35 * 6) SpawnWave();
	}

	void KillPower()
	{
		powerOut = true;
		outTic = level.maptime;
		power = 0;
		S_StartSound("power/out", CHAN_AUTO, CHANF_DEFAULT, 1, ATTN_NONE);
		Say("POWER OUT", "The security doors are open... something is coming", 4);
		// FNAF rules: no power, no doors. Door_Open (11) on the two hall doors of Whisker's Block Pizza.
		level.ExecuteSpecial(11, null, null, false, 24, 48);
		level.ExecuteSpecial(11, null, null, false, 25, 48);
		lights.Clear();
		for (int i = 0; i < level.Sectors.Size(); i++) lights.Push(level.Sectors[i].lightlevel);
	}

	void SetLights(double f)
	{
		if (int(lights.Size()) != int(level.Sectors.Size())) return;
		for (int i = 0; i < level.Sectors.Size(); i++) level.Sectors[i].SetLightLevel(int(lights[i] * f));
	}

	// The Professor shows up in front of the guard if there is room, otherwise on the stage.
	void SpawnBoss()
	{
		let mo = players[consoleplayer].mo;
		if (!mo) return;
		Actor b;
		for (int i = 0; i < 24 && !b; i++)
		{
			Vector2 xy = mo.Vec2Angle(frandom(300, 460), mo.angle + frandom(-35, 35));
			double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
			if (abs(z - mo.pos.z) > 64) continue;
			b = Actor.Spawn("ProfessorWhiskers", (xy, z), ALLOW_REPLACE);
			if (b && (!b.TestMobjLocation() || !b.CheckSight(mo))) { b.Destroy(); b = null; }
		}
		if (!b && bossSpot) b = Actor.Spawn("ProfessorWhiskers", bossSpot.pos, ALLOW_REPLACE);
		if (!b) return;
		Actor.Spawn("TeleportFog", b.pos, ALLOW_REPLACE);
		b.angle = b.AngleTo(mo);
		b.target = mo;
		b.SetState(b.SeeState);
		boss = b;
		bossTic = level.maptime;
		S_StartSound("boss/line", CHAN_AUTO, CHANF_DEFAULT, 1, ATTN_NONE);
		Say("PROFESSOR WHISKERS", "the SuperIntelligent Cat", 4);
	}

	void Win()
	{
		if (won) return;
		won = true;
		wonTic = level.maptime;
		if (!powerOut)
		{
			lights.Clear();
			for (int i = 0; i < level.Sectors.Size(); i++) lights.Push(level.Sectors[i].lightlevel);
			wonTic -= 70;
		}
		power = max(power, 1);
		S_StartSound("clock/6am", CHAN_AUTO, CHANF_DEFAULT, 1, ATTN_NONE);
		Say("6 AM", String.Format("NIGHT %d COMPLETE - every kitten is free!", night), 6);
		nextNight = level.maptime + 35 * 9;
		// Shift over: the animatronics left shut down and their kittens jump out.
		let it = ThinkerIterator.Create("SICAnimatronic");
		SICAnimatronic a;
		Array<Actor> left;
		while (a = SICAnimatronic(it.Next())) if (a.health > 0) left.Push(a);
		for (int i = 0; i < left.Size(); i++) left[i].DamageMobj(null, null, left[i].health, 'Shutdown', DMG_FORCED);
		// The freed kittens throw a party in front of the guard.
		let mo = players[consoleplayer].mo;
		if (!mo) return;
		int made = 0;
		for (int i = 0; i < 60 && made < 14; i++)
		{
			Vector2 xy = mo.Vec2Angle(frandom(90, 260), mo.angle + frandom(-50, 50));
			double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
			if (abs(z - mo.pos.z) > 48) continue;
			let k = Actor.Spawn("SICPartyKitten", (xy, z), ALLOW_REPLACE);
			if (k && !k.CheckSight(mo)) { k.Destroy(); continue; }
			made++;
		}
	}

	// The next night: power back, doors shut, the clock back to 12 AM, and the hours a little shorter.
	void StartNight()
	{
		night++;
		nightStart = level.maptime;
		won = false;
		powerOut = false;
		boss = null;
		bossTic = 0;
		shotPower = 0;
		power = POWER_MAX;
		clockHour = -1;
		lastWave = level.maptime;
		hourTics = max(35, sic_hourtics * (10 - min(night - 1, 4)) / 10);
		lights.Clear();
		let mo = players[consoleplayer].mo;
		if (mo)
		{
			mo.GiveInventory("RocketAmmo", 20);
			mo.Teleport(startPos, startAngle, TELF_SOURCEFOG | TELF_DESTFOG);
		}
		level.ExecuteSpecial(10, null, null, false, 24, 64); // Door_Close
		level.ExecuteSpecial(10, null, null, false, 25, 64);
	}

	// One animatronic: in front of the guard but not too close, or at a spawn point of the map.
	bool SpawnNear(PlayerPawn mo, Name kind)
	{
		for (int i = 0; i < 24; i++)
		{
			Vector2 xy = mo.Vec2Angle(i < 12 ? frandom(380, 760) : frandom(200, 420), mo.angle + frandom(-60, 60));
			double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
			if (abs(z - mo.pos.z) > 64) continue;
			let m = Actor.Spawn(kind, (xy, z), ALLOW_REPLACE);
			if (!m) continue;
			if (!m.TestMobjLocation() || !m.CheckSight(mo)) { m.Destroy(); continue; }
			Actor.Spawn("TeleportFog", m.pos, ALLOW_REPLACE);
			m.target = mo;
			m.SetState(m.SeeState);
			return true;
		}
		return false;
	}

	void SpawnWave()
	{
		lastWave = level.maptime;
		int alive = 0;
		let it = ThinkerIterator.Create("SICAnimatronic");
		SICAnimatronic a;
		while (a = SICAnimatronic(it.Next())) if (a.health > 0) alive++;
		if (alive >= 4) return;
		static const Name kinds[] = { 'BrickBear', 'BlockBunny', 'CluckBlock', 'Foxel' };
		let mo = players[consoleplayer].mo;
		// Two at a time when the hall is nearly empty.
		if (mo && SpawnNear(mo, kinds[random(0, 3)]))
		{
			if (alive < 2) SpawnNear(mo, kinds[random(0, 3)]);
			return;
		}
		for (int i = 0; i < 8 && spots.Size(); i++)
		{
			let s = spots[random(0, spots.Size() - 1)];
			if (mo && s.Distance2D(mo) < 256) continue;
			let m = Actor.Spawn(kinds[random(0, 3)], s.pos, ALLOW_REPLACE);
			if (!m) continue;
			if (!m.TestMobjLocation()) { m.Destroy(); continue; }
			Actor.Spawn("TeleportFog", m.pos, ALLOW_REPLACE);
			m.target = mo;
			m.SetState(m.SeeState);
			return;
		}
	}

	// ---- Every map becomes Minecraft ----


	static int NameHash(String s)
	{
		int h = 7;
		for (int i = 0; i < s.Length(); i++) h = (h * 31 + s.ByteAt(i)) & 0xFFFF;
		return h;
	}

	static String BlockFor(String n, bool flat)
	{
		n = n.MakeUpper();
		if (n.Left(2) == "MC" || n.Left(5) == "F_SKY" || n == "-") return "";
		if (n.IndexOf("NUKAGE") >= 0 || n.IndexOf("WATER") >= 0 || n.IndexOf("SLIME") >= 0 || n.IndexOf("BLOOD") >= 0 || n.Left(5) == "FWATE") return "MCWATER";
		if (n.IndexOf("LAVA") >= 0 || n.IndexOf("FIRE") >= 0 || n.IndexOf("SKIN") >= 0) return "MCOBSID";
		if (n.IndexOf("LITE") >= 0 || n.IndexOf("LIGHT") >= 0 || n.Left(4) == "TLIT" || n.Left(4) == "CEIL1") return "MCGLOW";
		if (n.IndexOf("DOOR") >= 0) return "MCIRON";
		if (n.IndexOf("GRASS") >= 0 || n.IndexOf("RROCK") >= 0 || n.IndexOf("MFLR") >= 0) return flat ? "MCGRASST" : "MCGRASS";
		if (n.IndexOf("WOOD") >= 0 || n.IndexOf("CRATE") >= 0) return "MCPLANK";
		if (n.IndexOf("BRICK") >= 0) return "MCBRICK";
		if (n.IndexOf("COMP") >= 0 || n.IndexOf("PANEL") >= 0) return "MCBOOK";
		if (n.IndexOf("METAL") >= 0 || n.IndexOf("SUPPORT") >= 0 || n.IndexOf("STEP") >= 0 || n.IndexOf("PIPE") >= 0) return "MCIRON";
		static const String WALLS[] = { "MCCOBBL", "MCSTBRK", "MCSTONE", "MCBRICK", "MCPLANK", "MCCOBBL", "MCSTBRK", "MCLOG" };
		static const String FLOORS[] = { "MCCOBBL", "MCSTONE", "MCPLANK", "MCGRASST", "MCDIRT", "MCCHECK", "MCSAND", "MCSTBRK" };
		int k = NameHash(n) % 8;
		return flat ? FLOORS[k] : WALLS[k];
	}

	void Minecraftify()
	{
		for (int i = 0; i < level.Sectors.Size(); i++)
		{
			let s = level.Sectors[i];
			for (int p = 0; p < 2; p++)
			{
				String b = BlockFor(TexMan.GetName(s.GetTexture(p)), true);
				if (b != "") s.SetTexture(p, TexMan.CheckForTexture(b, TexMan.Type_Any));
			}
		}
		for (int i = 0; i < level.Lines.Size(); i++)
		{
			let l = level.Lines[i];
			for (int sd = 0; sd < 2; sd++)
			{
				let side = l.sidedef[sd];
				if (!side) continue;
				for (int part = 0; part < 3; part++)
				{
					TextureID tex = side.GetTexture(part);
					if (!tex.IsValid()) continue;
					String n = TexMan.GetName(tex).MakeUpper();
					if (n.Left(2) == "SW" || n.IndexOf("EXIT") >= 0) continue; // switches and exits stay readable
					String b;
					if (part == Side.mid && l.sidedef[1]) b = n.Left(2) == "MC" ? "" : "MCGLASS"; // grates and fences: glass panes
					else b = BlockFor(n, false);
					if (b != "") side.SetTexture(part, TexMan.CheckForTexture(b, TexMan.Type_Any));
				}
			}
		}
	}

	// ---- HUD ----

	ui void Txt(Font f, String s, double x, double y, double sc, int col, int align = 0, double alpha = 1.)
	{
		double w = f.StringWidth(s) * sc;
		if (align == 1) x -= w;
		else if (align == 2) x -= w / 2;
		Screen.DrawText(f, col, x, y, s, DTA_ScaleX, sc, DTA_ScaleY, sc, DTA_Alpha, alpha);
	}

	ui String HourName(int h) { return h == 0 ? "12 AM" : String.Format("%d AM", h); }

	override void RenderOverlay(RenderEvent e)
	{
		double W = Screen.GetWidth(), H = Screen.GetHeight();
		double s = H / 360.;
		int t = level.maptime;

		if (powerOut && !won) Screen.Dim("000010", 0.15, 0, 0, int(W), int(H));

		// Clock, top right.
		String clock = HourName(clockHour);
		bool overtime = !won && (t - nightStart) / hourTics >= 6;
		Txt(bigfont, clock, W - 14 * s, 8 * s, 2.0 * s, won ? Font.CR_GOLD : Font.CR_WHITE, 1);
		Txt(smallfont, overtime && (t / 18) % 2 ? "OVERTIME!" : String.Format("Night %d", night), W - 14 * s, 42 * s, 1.2 * s, overtime ? Font.CR_RED : Font.CR_GRAY, 1);

		// Power, bottom left.
		int pct = (power + 9) / 10;
		int pcol = pct > 40 ? Font.CR_GREEN : (pct > 15 ? Font.CR_YELLOW : Font.CR_RED);
		Txt(smallfont, String.Format("Power left: %d%%", pct), 10 * s, H - 46 * s, 1.3 * s, pcol);
		Txt(smallfont, "Usage:", 10 * s, H - 30 * s, 1.3 * s, Font.CR_WHITE);
		int bars = powerOut ? 0 : (t - usageTic < 35 ? 4 : (t - usageTic < 105 ? 2 : 1));
		for (int i = 0; i < bars; i++)
		{
			Color c = i < 2 ? Color(255, 32, 192, 32) : (i == 2 ? Color(255, 224, 192, 32) : Color(255, 224, 32, 32));
			Screen.Clear(int((62 + i * 10) * s), int(H - 30 * s), int((62 + i * 10 + 7) * s), int(H - 19 * s), c);
		}

		// Objectives, top left.
		Txt(smallfont, won ? "Survived until 6 AM!" : (boss && boss.health > 0 ? "Break Professor Whiskers!" : "Survive until 6 AM"), 10 * s, 30 * s, 1.2 * s, won ? Font.CR_GOLD : Font.CR_ORANGE);
		Txt(smallfont, String.Format("Animatronics broken: %d", broken), 10 * s, 44 * s, 1.1 * s, Font.CR_WHITE);
		Txt(smallfont, String.Format("Kittens freed: %d", kittens), 10 * s, 56 * s, 1.1 * s, Font.CR_GOLD);

		// Boss health bar.
		if (boss && boss.health > 0)
		{
			double bw = 220 * s, bx = (W - bw) / 2, by = 54 * s;
			Txt(smallfont, "PROFESSOR WHISKERS", W / 2, by - 12 * s, 1.1 * s, Font.CR_PURPLE, 2);
			Screen.Clear(int(bx), int(by), int(bx + bw), int(by + 6 * s), "301030");
			Screen.Clear(int(bx), int(by), int(bx + bw * boss.health / double(boss.GetSpawnHealth())), int(by + 6 * s), "D040FF");
		}

		// Big message.
		if (msg != "" && t - msgTic < msgLen)
		{
			double a = clamp((msgLen - (t - msgTic)) / 20., 0., 1.);
			double big = min(3.0 * s, W * 0.8 / bigfont.StringWidth(msg));
			Txt(bigfont, msg, W / 2, H * 0.28, big, msg == "POWER OUT" ? Font.CR_RED : Font.CR_GOLD, 2, a);
			if (msgSub != "") Txt(smallfont, msgSub, W / 2, H * 0.28 + bigfont.GetHeight() * big + 6 * s, min(1.6 * s, W * 0.8 / smallfont.StringWidth(msgSub)), Font.CR_WHITE, 2, a);
		}

		// Subtitles.
		String sub = Subtitle(t);
		if (sub != "")
		{
			// Two lines, split at the space nearest the middle.
			int cut = sub.Length() / 2;
			while (cut < sub.Length() && sub.ByteAt(cut) != 32) cut++;
			String l1 = sub.Left(cut), l2 = sub.Mid(cut + 1);
			double ss = min(1.15 * s, W * 0.9 / max(smallfont.StringWidth(l1), smallfont.StringWidth(l2)));
			Screen.Dim("000000", 0.45, int(W * 0.04), int(H - 88 * s), int(W * 0.92), int(30 * s));
			Txt(smallfont, l1, W / 2, H - 84 * s, ss, Font.CR_CYAN, 2);
			Txt(smallfont, l2, W / 2, H - 70 * s, ss, Font.CR_CYAN, 2);
		}

		// Jumpscare: the face fills the screen, shaking.
		int k = t - scareTic;
		if (scareFace != "" && k >= 0 && k < 22 && scareTic > 0)
		{
			TextureID tex = TexMan.CheckForTexture(scareFace, TexMan.Type_Any, TexMan.TryAny);
			if (tex.IsValid())
			{
				Vector2 sz = TexMan.GetScaledSize(tex);
				double zoom = H * (0.85 + min(k, 6) * 0.06 + k * 0.01) / sz.y; // lunges in fast, then keeps creeping closer
				double dw = sz.x * zoom, dh = sz.y * zoom;
				double jx = (W - dw) / 2 + random(-12, 12) * s, jy = (H - dh) / 2 + H * 0.05 + random(-12, 12) * s;
				Screen.Dim("400000", 0.6, 0, 0, int(W), int(H));
				Screen.DrawTexture(tex, false, jx, jy, DTA_DestWidthF, dw, DTA_DestHeightF, dh, DTA_LeftOffset, 0, DTA_TopOffset, 0);
			}
		}
	}

	ui String Subtitle(int t)
	{
		double p = (t - phoneTic) / 35.;
		if (p >= 0 && p < 17)
		{
			if (p < 5) return "PHONE: \"Hello, hello? Uh, welcome to your first night at Whisker's Block Pizza!\"";
			if (p < 9.5) return "PHONE: \"This is Professor Whiskers. Yes, the cat. The super intelligent one.\"";
			if (p < 13) return "PHONE: \"The animatronics get a little... frisky at night.\"";
			return "PHONE: \"Just survive until six A.M. Meow.\"";
		}
		if (bossTic > 0)
		{
			double b = (t - bossTic) / 35.;
			if (b >= 0 && b < 3.5) return "WHISKERS: \"The power is out, human.\"";
			if (b >= 3.5 && b < 7.5) return "WHISKERS: \"Now... it is MY shift. Meow.\"";
		}
		return "";
	}
}
